"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onPasswordResetRequest = exports.onNewOfferAdded = exports.aggregateProductViews = exports.checkExpiredOffers = exports.onInventoryUpdate = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
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
// 5. Password Reset via RTDB Trigger (Safe & Secure password updates)
exports.onPasswordResetRequest = functions.database.ref("/password_resets/{phone}")
    .onCreate(async (snapshot, context) => {
    const data = snapshot.val();
    if (!data)
        return null;
    const phone = context.params.phone;
    const otp = data.otp;
    const newPassword = data.newPassword;
    const ref = snapshot.ref;
    try {
        // 1. Verify OTP in RTDB
        const otpSnapshot = await admin.database().ref(`/otps/${phone}`).once("value");
        if (!otpSnapshot.exists()) {
            await ref.update({ status: "error", error: "OTP not found or expired" });
            return null;
        }
        const { otp: storedOtp, expiresAt } = otpSnapshot.val();
        if (storedOtp !== otp || Date.now() > expiresAt) {
            await ref.update({ status: "error", error: "Invalid or expired OTP" });
            return null;
        }
        // Delete OTP
        await admin.database().ref(`/otps/${phone}`).remove();
        // 2. Find UID by phone in RTDB
        const phoneSnapshot = await admin.database().ref(`/phones/${phone}`).once("value");
        if (!phoneSnapshot.exists()) {
            await ref.update({ status: "error", error: "Phone number is not registered" });
            return null;
        }
        const uid = phoneSnapshot.val();
        // 3. Update password in Firebase Auth
        await admin.auth().updateUser(uid, {
            password: newPassword
        });
        await ref.update({ status: "success" });
        // Clean up reset request after 10 seconds
        setTimeout(async () => {
            try {
                await ref.remove();
            }
            catch (e) {
                console.error("Error cleaning up reset request:", e);
            }
        }, 10000);
    }
    catch (error) {
        console.error("Error during password reset:", error);
        await ref.update({ status: "error", error: error.message || "Internal server error" });
    }
    return null;
});
//# sourceMappingURL=index.js.map