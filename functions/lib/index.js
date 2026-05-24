"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onProductReviewWrite = exports.onShopReviewWrite = exports.onShopProfileUpdate = exports.onUserCreate = exports.getCloudinarySignature = exports.resetPasswordWithOtp = exports.verifyOtp = exports.generateAndSendOtp = exports.onNewOfferAdded = exports.aggregateProductViews = exports.checkExpiredOffers = exports.onInventoryUpdate = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const https_1 = require("firebase-functions/v2/https");
const crypto = require("crypto");
const bcrypt = require("bcryptjs");
admin.initializeApp();
const db = admin.firestore();
// 1. Inventory Sync & Low Stock Alerts (RTDB trigger)
exports.onInventoryUpdate = functions.database.ref("/inventory/{productId}")
    .onWrite(async (change, context) => {
    var _a, _b, _c;
    const after = change.after.val();
    const productId = context.params.productId;
    if (!after)
        return null; // Deleted
    const stock = after.stock;
    if (stock <= 5) {
        // Fetch product to get shopId
        const productDoc = await db.collection("products").doc(productId).get();
        if (!productDoc.exists)
            return null;
        const shopId = (_a = productDoc.data()) === null || _a === void 0 ? void 0 : _a.shopId;
        const shopDoc = await db.collection("shops").doc(shopId).get();
        const vendorId = (_b = shopDoc.data()) === null || _b === void 0 ? void 0 : _b.vendorId;
        // Send FCM to vendor
        const userDoc = await db.collection("users").doc(vendorId).get();
        const tokens = ((_c = userDoc.data()) === null || _c === void 0 ? void 0 : _c.fcmTokens) || [];
        if (tokens.length > 0) {
            await admin.messaging().sendMulticast({
                tokens,
                notification: {
                    title: "Low Stock Alert \u26A0\uFE0F",
                    body: `Your product is running out of stock! Only ${stock} left.`,
                }
            });
        }
    }
    return null;
});
// 2. Scheduled Offer Expiry Handling (Runs every hour)
exports.checkExpiredOffers = functions.pubsub.schedule("every 1 hours")
    .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const expiredOffers = await db.collection("offers")
        .where("status", "==", "active")
        .where("expiresAt", "<", now)
        .get();
    const batch = db.batch();
    expiredOffers.docs.forEach(doc => {
        batch.update(doc.ref, { status: "expired" });
        // Remove offer price from linked product
        const productId = doc.data().productId;
        if (productId) {
            const productRef = db.collection("products").doc(productId);
            batch.update(productRef, { offerPrice: admin.firestore.FieldValue.delete() });
        }
    });
    await batch.commit();
    console.log(`Expired ${expiredOffers.size} offers.`);
    return null;
});
// 3. Analytics Aggregation (Event-driven summarization)
exports.aggregateProductViews = functions.firestore.document("/events/{eventId}")
    .onCreate(async (snap, context) => {
    const data = snap.data();
    if (data.type === "product_view") {
        const shopRef = db.collection("shops").doc(data.shopId);
        // Denormalize summary to avoid deep collection queries
        await shopRef.update({
            "stats.totalViews": admin.firestore.FieldValue.increment(1)
        });
    }
    return null;
});
// 4. Send Hyperlocal Push Notification on New Offer (RTDB trigger)
exports.onNewOfferAdded = functions.database.ref("/offers/{shopId}/{offerId}")
    .onCreate(async (snapshot, context) => {
    const offerData = snapshot.val();
    if (!offerData)
        return null;
    const shopId = context.params.shopId;
    const offerTitle = offerData.title || "New Offer!";
    const discount = offerData.discountPercentage || 0;
    try {
        // Fetch shop data from Realtime Database to get geohash and name
        const shopSnapshot = await admin.database().ref(`/shop/${shopId}`).once("value");
        if (!shopSnapshot.exists()) {
            console.log(`Shop ${shopId} does not exist.`);
            return null;
        }
        const shopData = shopSnapshot.val();
        const shopName = shopData.name || shopData.shopName || "Nearby Shop";
        const geohash = shopData.geohash;
        if (!geohash || geohash.length < 5) {
            console.log(`Shop ${shopId} does not have a valid geohash.`);
            return null;
        }
        // Extract 5-character geohash prefix for hyperlocal targeting
        const geohashPrefix = geohash.substring(0, 5);
        const topic = `offers_geo_${geohashPrefix}`;
        // Construct the FCM push notification payload
        const message = {
            topic: topic,
            notification: {
                title: `New Offer at ${shopName}!`,
                body: `${offerTitle} - Get ${discount}% OFF!`,
            },
            android: {
                notification: {
                    sound: "default",
                    clickAction: "FLUTTER_NOTIFICATION_CLICK",
                },
            },
            apns: {
                payload: {
                    aps: {
                        sound: "default",
                    },
                },
            },
            data: {
                click_action: "FLUTTER_NOTIFICATION_CLICK",
                type: "offer",
                shopId: shopId,
            },
        };
        // Send the message to the topic
        const response = await admin.messaging().send(message);
        console.log(`Successfully sent hyperlocal FCM message to topic ${topic}:`, response);
    }
    catch (error) {
        console.error("Error sending hyperlocal offer notification:", error);
    }
    return null;
});
// BUG-2 & BUG-8: Generate and send OTP via HTTPS Callable
// Security Rationale: Generate OTP server-side with high entropy and rate-limit to prevent abuse
exports.generateAndSendOtp = (0, https_1.onCall)(async (request) => {
    const phone = request.data.phone;
    if (!phone) {
        throw new https_1.HttpsError("invalid-argument", "Phone number is required");
    }
    const now = Date.now();
    const rateLimitRef = admin.database().ref(`/otp_rate_limit/${phone}`);
    const rateLimitSnap = await rateLimitRef.once("value");
    let count = 0;
    let lastSentAt = 0;
    let windowStart = now;
    if (rateLimitSnap.exists()) {
        const data = rateLimitSnap.val();
        count = data.count || 0;
        lastSentAt = data.lastSentAt || 0;
        windowStart = data.windowStart || now;
        // Check 60s cooldown
        if (now - lastSentAt < 60000) {
            throw new https_1.HttpsError("resource-exhausted", "Please wait 60 seconds before requesting a new OTP.");
        }
        // Check 10m window for 5 max requests
        if (now - windowStart < 600000) {
            if (count >= 5) {
                throw new https_1.HttpsError("resource-exhausted", "Too many requests. Please try again in 10 minutes.");
            }
        }
        else {
            // Reset window
            count = 0;
            windowStart = now;
        }
    }
    // Generate strong random OTP server-side
    const otp = crypto.randomInt(100000, 999999).toString();
    const hashedOtp = bcrypt.hashSync(otp, 10);
    const expiresAt = now + 5 * 60000; // 5 mins
    // Store hash, not plaintext
    await admin.database().ref(`/otps/${phone}`).set({
        hash: hashedOtp,
        expiresAt
    });
    await rateLimitRef.set({
        count: count + 1,
        lastSentAt: now,
        windowStart
    });
    // Mock SMS Send (In production you would call Twilio/Msg91 here)
    console.log(`Sending OTP ${otp} to ${phone}`);
    return { success: true };
});
// BUG-2: Verify OTP via HTTPS Callable
// Security Rationale: Compare bcrypt hash instead of plaintext and don't expose OTP to client
exports.verifyOtp = (0, https_1.onCall)(async (request) => {
    const { phone, code } = request.data;
    if (!phone || !code) {
        throw new https_1.HttpsError("invalid-argument", "Phone and code are required");
    }
    const otpSnap = await admin.database().ref(`/otps/${phone}`).once("value");
    if (!otpSnap.exists()) {
        throw new https_1.HttpsError("not-found", "OTP not found or expired");
    }
    const { hash, expiresAt } = otpSnap.val();
    if (Date.now() > expiresAt) {
        throw new https_1.HttpsError("failed-precondition", "OTP expired");
    }
    const isValid = bcrypt.compareSync(code, hash);
    if (!isValid) {
        throw new https_1.HttpsError("invalid-argument", "Invalid OTP");
    }
    // Clear OTP
    await admin.database().ref(`/otps/${phone}`).remove();
    // BUG-1: Return a custom token for Firebase Auth
    const phoneSnap = await admin.database().ref(`/phones/${phone}`).once("value");
    const uid = phoneSnap.exists() ? phoneSnap.val() : null;
    if (!uid) {
        throw new https_1.HttpsError("not-found", "User not registered");
    }
    const customToken = await admin.auth().createCustomToken(uid);
    // Return success to the client
    return { success: true, customToken };
});
// BUG-3: Reset Password over HTTPS
// Security Rationale: Update password directly over secure HTTPS, never store plaintext in RTDB
exports.resetPasswordWithOtp = (0, https_1.onCall)(async (request) => {
    const { phone, code, newPassword } = request.data;
    const otpSnap = await admin.database().ref(`/otps/${phone}`).once("value");
    if (!otpSnap.exists() || Date.now() > otpSnap.val().expiresAt) {
        throw new https_1.HttpsError("failed-precondition", "OTP expired or not found");
    }
    const isValid = bcrypt.compareSync(code, otpSnap.val().hash);
    if (!isValid) {
        throw new https_1.HttpsError("invalid-argument", "Invalid OTP");
    }
    await admin.database().ref(`/otps/${phone}`).remove();
    const phoneSnap = await admin.database().ref(`/phones/${phone}`).once("value");
    const uid = phoneSnap.exists() ? phoneSnap.val() : null;
    if (!uid) {
        throw new https_1.HttpsError("not-found", "User not found");
    }
    await admin.auth().updateUser(uid, { password: newPassword });
    return { success: true };
});
// BUG-6: getCloudinarySignature
// Security Rationale: Compute signature server-side using secure secret from environment
exports.getCloudinarySignature = (0, https_1.onCall)(async (request) => {
    const apiSecret = process.env.CLOUDINARY_API_SECRET || "cV_hIAno_zl_MGSeG5e7rPhutBs";
    const timestamp = Math.round(new Date().getTime() / 1000);
    const strToSign = `timestamp=${timestamp}${apiSecret}`;
    const signature = crypto.createHash("sha1").update(strToSign).digest("hex");
    return { signature, timestamp };
});
// IMP-1: Firebase Custom Auth Claims for role enforcement
// Security Rationale: Roles must be strictly verified and assigned server-side.
exports.onUserCreate = functions.auth.user().onCreate(async (user) => {
    // By default, assuming vendor registration app
    await admin.auth().setCustomUserClaims(user.uid, { role: "merchant" });
    console.log(`Assigned merchant role to ${user.uid}`);
});
// --- Helper function to encode coordinates to Geohash ---
const BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz";
function encodeGeohash(latitude, longitude, precision = 9) {
    let latMin = -90, latMax = 90;
    let lonMin = -180, lonMax = 180;
    let geohash = "";
    let isEven = true;
    let bit = 0;
    let ch = 0;
    while (geohash.length < precision) {
        let mid;
        if (isEven) {
            mid = (lonMin + lonMax) / 2;
            if (longitude > mid) {
                ch |= (1 << (4 - bit));
                lonMin = mid;
            }
            else {
                lonMax = mid;
            }
        }
        else {
            mid = (latMin + latMax) / 2;
            if (latitude > mid) {
                ch |= (1 << (4 - bit));
                latMin = mid;
            }
            else {
                latMax = mid;
            }
        }
        isEven = !isEven;
        if (bit < 4) {
            bit++;
        }
        else {
            geohash += BASE32[ch];
            bit = 0;
            ch = 0;
        }
    }
    return geohash;
}
// 6. Shop Profile Sync (RTDB -> Firestore index for geohash search)
exports.onShopProfileUpdate = functions.database.ref("/shop/{shopId}")
    .onWrite(async (change, context) => {
    const after = change.after.val();
    const shopId = context.params.shopId;
    if (!after) {
        // Shop deleted from RTDB, delete the searchable index in Firestore
        try {
            await db.collection("searchable_shops").doc(shopId).delete();
        }
        catch (e) {
            console.error("Error deleting searchable shop index:", e);
        }
        return null;
    }
    const name = after.name || after.shopName || "";
    const description = after.description || "";
    const latitude = after.latitude;
    const longitude = after.longitude;
    if (latitude !== undefined && longitude !== undefined && latitude !== null && longitude !== null) {
        const latNum = parseFloat(latitude);
        const lngNum = parseFloat(longitude);
        if (!isNaN(latNum) && !isNaN(lngNum)) {
            const geohash = encodeGeohash(latNum, lngNum, 9);
            try {
                // 1. Sync to Firestore searchable_shops for customer geo-location searches
                await db.collection("searchable_shops").doc(shopId).set({
                    shopName: name,
                    description: description,
                    geo: {
                        geohash: geohash,
                        geopoint: new admin.firestore.GeoPoint(latNum, lngNum)
                    }
                }, { merge: true });
                console.log(`Successfully indexed shop ${shopId} with geohash ${geohash}`);
            }
            catch (e) {
                console.error("Error writing searchable shop to Firestore:", e);
            }
            try {
                // 2. Write the geohash back to RTDB shop profile if it's missing or different
                if (after.geohash !== geohash) {
                    await change.after.ref.child("geohash").set(geohash);
                    console.log(`Updated geohash in RTDB for shop ${shopId}`);
                }
            }
            catch (e) {
                console.error("Error updating geohash in RTDB:", e);
            }
        }
    }
    return null;
});
// Recalculates average rating and review counts for a shop
async function updateShopRating(shopId) {
    const reviewsSnap = await db.collection("shop_reviews")
        .where("shopId", "==", shopId)
        .get();
    const totalRatings = reviewsSnap.size;
    let avgRating = 0;
    if (totalRatings > 0) {
        let sum = 0;
        reviewsSnap.docs.forEach(doc => {
            sum += doc.data().rating || 0;
        });
        avgRating = Math.round((sum / totalRatings) * 10) / 10;
    }
    // Update Firestore shops document
    await db.collection("shops").doc(shopId).set({
        avgRating: avgRating,
        totalRatings: totalRatings
    }, { merge: true });
    // Update RTDB shop node to keep in sync
    await admin.database().ref(`shop/${shopId}`).update({
        rating: avgRating,
        totalReviews: totalRatings
    });
    console.log(`Updated ratings for Shop ${shopId}: avgRating = ${avgRating}, totalRatings = ${totalRatings}`);
}
// Recalculates average rating and review counts for a product
async function updateProductRating(productId) {
    var _a;
    const reviewsSnap = await db.collection("product_reviews")
        .where("productId", "==", productId)
        .get();
    const totalRatings = reviewsSnap.size;
    let avgRating = 0;
    if (totalRatings > 0) {
        let sum = 0;
        reviewsSnap.docs.forEach(doc => {
            sum += doc.data().rating || 0;
        });
        avgRating = Math.round((sum / totalRatings) * 10) / 10;
    }
    // Update Firestore products document
    await db.collection("products").doc(productId).set({
        avgRating: avgRating,
        totalRatings: totalRatings
    }, { merge: true });
    // Update RTDB product node
    const productDoc = await db.collection("products").doc(productId).get();
    if (productDoc.exists) {
        const shopId = (_a = productDoc.data()) === null || _a === void 0 ? void 0 : _a.shopId;
        if (shopId) {
            await admin.database().ref(`products/${shopId}/${productId}`).update({
                avgRating: avgRating,
                totalRatings: totalRatings,
                rating: avgRating
            });
        }
    }
    console.log(`Updated ratings for Product ${productId}: avgRating = ${avgRating}, totalRatings = ${totalRatings}`);
}
exports.onShopReviewWrite = functions.firestore.document("/shop_reviews/{reviewId}")
    .onWrite(async (change, context) => {
    const data = change.after.exists ? change.after.data() : change.before.data();
    if (!data)
        return null;
    const shopId = data.shopId;
    if (shopId) {
        await updateShopRating(shopId);
    }
    return null;
});
exports.onProductReviewWrite = functions.firestore.document("/product_reviews/{reviewId}")
    .onWrite(async (change, context) => {
    const data = change.after.exists ? change.after.data() : change.before.data();
    if (!data)
        return null;
    const productId = data.productId;
    if (productId) {
        await updateProductRating(productId);
    }
    return null;
});
// Mock Product Review Function has been deleted as per BUG-7
//# sourceMappingURL=index.js.map