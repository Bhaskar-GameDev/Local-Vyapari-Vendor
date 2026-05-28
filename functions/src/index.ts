import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import * as bcrypt from "bcryptjs";

admin.initializeApp();
const db = admin.firestore();

// 1. Inventory Sync & Low Stock Alerts (RTDB trigger)
export const onInventoryUpdate = functions.database.ref("/inventory/{productId}")
  .onWrite(async (change, context) => {
    const after = change.after.val();
    const productId = context.params.productId;

    if (!after) return null; // Deleted

    const stock = after.stock;
    if (stock <= 5) {
      // Fetch product to get shopId
      const productDoc = await db.collection("products").doc(productId).get();
      if (!productDoc.exists) return null;
      
      const shopId = productDoc.data()?.shopId;
      const shopDoc = await db.collection("shops").doc(shopId).get();
      const vendorId = shopDoc.data()?.vendorId;

      // Send FCM to vendor
      const tokenSnapshot = await admin.database().ref(`/users_devices/${vendorId}/merchant/fcmToken`).once("value");
      const token = tokenSnapshot.val();

      if (token) {
        await admin.messaging().send({
          token: token,
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
export const checkExpiredOffers = functions.pubsub.schedule("every 1 hours")
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
export const aggregateProductViews = functions.firestore.document("/events/{eventId}")
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
export const onNewOfferAdded = functions.database.ref("/offers/{shopId}/{offerId}")
  .onCreate(async (snapshot, context) => {
    const offerData = snapshot.val();
    if (!offerData) return null;

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
    } catch (error) {
      console.error("Error sending hyperlocal offer notification:", error);
    }

    return null;
  });

async function sendTwilioSms(phone: string, otp: string): Promise<boolean> {
  const accountSid = process.env.TWILIO_ACCOUNT_SID;
  const authToken = process.env.TWILIO_AUTH_TOKEN;
  const fromNumber = process.env.TWILIO_FROM_NUMBER;

  if (!accountSid || !authToken || !fromNumber) {
    console.error("❌ Twilio credentials are not set in environment variables");
    return false;
  }

  const url = `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`;
  const auth = Buffer.from(`${accountSid}:${authToken}`).toString("base64");

  const params = new URLSearchParams();
  params.append("To", phone);
  params.append("From", fromNumber);
  params.append("Body", `Your Local Vyapari verification OTP code is: ${otp}. Valid for 5 minutes.`);

  try {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Authorization": `Basic ${auth}`,
        "Content-Type": "application/x-www-form-urlencoded"
      },
      body: params.toString()
    });

    if (response.ok) {
      console.log(`✅ Twilio SMS sent successfully to ${phone}`);
      return true;
    } else {
      const errText = await response.text();
      console.error(`❌ Twilio SMS failed: ${errText}`);
      return false;
    }
  } catch (e) {
    console.error(`❌ Exception during Twilio SMS send: ${e}`);
    return false;
  }
}

async function sendFast2Sms(phone: string, otp: string): Promise<boolean> {
  const apiKey = process.env.FAST2SMS_API_KEY;
  if (!apiKey) {
    console.error("❌ Fast2SMS API Key is not set in environment variables");
    return false;
  }

  let cleanedPhone = phone.replace(/\D/g, "");
  if (cleanedPhone.startsWith("91") && cleanedPhone.length === 12) {
    cleanedPhone = cleanedPhone.substring(2);
  }

  const url = `https://www.fast2sms.com/dev/bulkV2?authorization=${apiKey}&route=otp&variables_values=${otp}&numbers=${cleanedPhone}`;

  try {
    const response = await fetch(url);
    const resData: any = await response.json();
    if (resData && resData.return === true) {
      console.log(`✅ Fast2SMS SMS sent successfully to ${phone}`);
      return true;
    } else {
      console.error(`❌ Fast2SMS failed: ${resData?.message || JSON.stringify(resData)}`);
      return false;
    }
  } catch (e) {
    console.error(`❌ Exception during Fast2SMS send: ${e}`);
    return false;
  }
}

// BUG-2 & BUG-8: Generate and send OTP via HTTPS Callable
// Security Rationale: Generate OTP server-side with high entropy and rate-limit to prevent abuse
export const generateAndSendOtp = functions.https.onCall(async (data, context) => {
  const phone = data.phone;
  console.log("Generating OTP for phone:", phone);
  if (!phone) {
    throw new functions.https.HttpsError("invalid-argument", "Phone number is required");
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
      throw new functions.https.HttpsError("resource-exhausted", "Please wait 60 seconds before requesting a new OTP.");
    }
    
    // Check 10m window for 5 max requests
    if (now - windowStart < 600000) {
      if (count >= 5) {
        throw new functions.https.HttpsError("resource-exhausted", "Too many requests. Please try again in 10 minutes.");
      }
    } else {
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

  // Send SMS (Real or Mock Gateway)
  const gateway = process.env.SMS_GATEWAY || "mock";
  if (gateway.toLowerCase() === "twilio") {
    await sendTwilioSms(phone, otp);
  } else if (gateway.toLowerCase() === "fast2sms") {
    await sendFast2Sms(phone, otp);
  } else {
    console.log(`[MOCK SMS] Sending OTP ${otp} to ${phone}`);
  }
  
  return { success: true };
});

// BUG-2: Verify OTP via HTTPS Callable
// Security Rationale: Compare bcrypt hash instead of plaintext and don't expose OTP to client
export const verifyOtp = functions.https.onCall(async (data, context) => {
  const { phone, code } = data;
  if (!phone || !code) {
    throw new functions.https.HttpsError("invalid-argument", "Phone and code are required");
  }

  const otpSnap = await admin.database().ref(`/otps/${phone}`).once("value");
  if (!otpSnap.exists()) {
    throw new functions.https.HttpsError("not-found", "OTP not found or expired");
  }

  const { hash, expiresAt } = otpSnap.val();
  if (Date.now() > expiresAt) {
    throw new functions.https.HttpsError("failed-precondition", "OTP expired");
  }

  const isValid = bcrypt.compareSync(code, hash);
  if (!isValid) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid OTP");
  }

  // Clear OTP
  await admin.database().ref(`/otps/${phone}`).remove();

  // BUG-1: Return a custom token for Firebase Auth
  const phoneSnap = await admin.database().ref(`/phones/${phone}`).once("value");
  const uid = phoneSnap.exists() ? phoneSnap.val() : null;
  
  if (!uid) {
    throw new functions.https.HttpsError("not-found", "User not registered");
  }
  
  const customToken = await admin.auth().createCustomToken(uid);

  // Return success to the client
  return { success: true, customToken };
});

export const resolvePhoneLoginEmail = functions.https.onCall(async (data, context) => {
  const phone = data.phone;
  if (!phone) {
    throw new functions.https.HttpsError("invalid-argument", "Phone number is required");
  }

  const phoneSnap = await admin.database().ref(`/phones/${phone}`).once("value");
  const uid = phoneSnap.exists() ? phoneSnap.val() : null;
  if (!uid) {
    throw new functions.https.HttpsError("not-found", "This phone number is not registered");
  }

  const userSnap = await admin.database().ref(`/users/${uid}`).once("value");
  if (!userSnap.exists()) {
    throw new functions.https.HttpsError("not-found", "No user record found for this phone number");
  }

  const userData = userSnap.val() as { email?: string; roles?: Record<string, boolean>; role?: string };
  const hasValidRole = (userData.roles && (userData.roles.customer || userData.roles.merchant)) ||
                       (userData.role === "merchant" || userData.role === "customer");

  if (!hasValidRole) {
    throw new functions.https.HttpsError("permission-denied", "Access denied for this account.");
  }

  if (typeof userData.email !== "string" || userData.email.length === 0) {
    throw new functions.https.HttpsError("not-found", "No email found linked to this phone number");
  }

  return { email: userData.email };
});

// BUG-3: Reset Password over HTTPS
// Security Rationale: Update password directly over secure HTTPS, never store plaintext in RTDB
export const resetPasswordWithOtp = functions.https.onCall(async (data, context) => {
  const { phone, code, newPassword } = data;
  
  const otpSnap = await admin.database().ref(`/otps/${phone}`).once("value");
  if (!otpSnap.exists() || Date.now() > otpSnap.val().expiresAt) {
    throw new functions.https.HttpsError("failed-precondition", "OTP expired or not found");
  }
  
  const isValid = bcrypt.compareSync(code, otpSnap.val().hash);
  if (!isValid) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid OTP");
  }

  await admin.database().ref(`/otps/${phone}`).remove();

  const phoneSnap = await admin.database().ref(`/phones/${phone}`).once("value");
  const uid = phoneSnap.exists() ? phoneSnap.val() : null;
  if (!uid) {
    throw new functions.https.HttpsError("not-found", "User not found");
  }

  await admin.auth().updateUser(uid, { password: newPassword });
  return { success: true };
});

// BUG-6: getCloudinarySignature
// Security Rationale: Compute signature server-side using secure secret from environment
export const getCloudinarySignature = functions.https.onCall(async (data, context) => {
  const apiSecret = process.env.CLOUDINARY_API_SECRET; 
  const apiKey = process.env.CLOUDINARY_API_KEY;
  const cloudName = process.env.CLOUDINARY_CLOUD_NAME;
  
  if (!apiSecret || !apiKey || !cloudName) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Cloudinary configuration is missing on the server."
    );
  }
  
  const timestamp = Math.round(new Date().getTime() / 1000);
  
  const strToSign = `timestamp=${timestamp}${apiSecret}`;
  const signature = crypto.createHash("sha1").update(strToSign).digest("hex");
  
  return { signature, timestamp, apiKey, cloudName };
});

// IMP-1: Firebase Custom Auth Claims for role enforcement
// Security Rationale: Roles must be strictly verified and assigned server-side.
export const onUserCreated = functions.auth.user().onCreate(async (user) => {
  const uid = user.uid;
  const email = user.email || "";

  // Initialize roles in RTDB
  await admin.database().ref(`/users/${uid}`).update({
    email: email,
    roles: {
      customer: true
    },
    activeRole: "customer",
    createdAt: admin.database.ServerValue.TIMESTAMP
  });

  // Set Custom User Claims
  await admin.auth().setCustomUserClaims(uid, {
    roles: {
      customer: true
    },
    activeRole: "customer",
    customer: true,
    merchant: false
  });

  console.log(`Initialized user ${uid} with customer role and claims.`);
});

export const onUserCreate = onUserCreated;

export const assignMerchantRole = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "The function must be called while authenticated.");
  }

  const uid = context.auth.uid;

  // Check if shop profile exists for this user
  const shopSnap = await admin.database().ref(`/shop/${uid}`).once("value");
  if (!shopSnap.exists()) {
    throw new functions.https.HttpsError("not-found", "No shop profile found. Please set up your shop first.");
  }

  // Update roles and activeRole in RTDB
  await admin.database().ref(`/users/${uid}`).update({
    "roles/merchant": true,
    "activeRole": "merchant"
  });

  // Fetch current user claims to preserve them or just set them directly
  const userRecord = await admin.auth().getUser(uid);
  const existingClaims = userRecord.customClaims || {};
  const existingRoles = existingClaims.roles || {};

  // Set new claims
  await admin.auth().setCustomUserClaims(uid, {
    ...existingClaims,
    roles: {
      ...existingRoles,
      merchant: true
    },
    activeRole: "merchant",
    merchant: true
  });

  console.log(`Assigned merchant role to user ${uid}`);
  return { success: true };
});

// Duplicate validateSession removed (new implementation exists at the end of the file)

export const migrateUserRoles = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be authenticated to run migration.");
  }

  const usersSnap = await admin.database().ref("/users").once("value");
  if (!usersSnap.exists()) {
    return { migrated: 0 };
  }

  const users = usersSnap.val();
  let count = 0;

  for (const uid of Object.keys(users)) {
    const userData = users[uid];
    const legacyRole = userData.role;

    if (legacyRole && !userData.roles) {
      const roles: Record<string, boolean> = {
        customer: true
      };
      if (legacyRole === "merchant") {
        roles.merchant = true;
      }

      await admin.database().ref(`/users/${uid}`).update({
        roles: roles,
        activeRole: legacyRole
      });

      await admin.auth().setCustomUserClaims(uid, {
        roles: roles,
        activeRole: legacyRole,
        customer: roles.customer || false,
        merchant: roles.merchant || false
      });

      count++;
    }
  }

  return { migrated: count };
});

// --- Helper function to encode coordinates to Geohash ---
const BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz";
function encodeGeohash(latitude: number, longitude: number, precision: number = 9): string {
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
      } else {
        lonMax = mid;
      }
    } else {
      mid = (latMin + latMax) / 2;
      if (latitude > mid) {
        ch |= (1 << (4 - bit));
        latMin = mid;
      } else {
        latMax = mid;
      }
    }

    isEven = !isEven;
    if (bit < 4) {
      bit++;
    } else {
      geohash += BASE32[ch];
      bit = 0;
      ch = 0;
    }
  }
  return geohash;
}

// 6. Shop Profile Sync (RTDB -> Firestore index for geohash search)
export const onShopProfileUpdate = functions.database.ref("/shop/{shopId}")
  .onWrite(async (change, context) => {
    const after = change.after.val();
    const shopId = context.params.shopId;

    if (!after) {
      // Shop deleted from RTDB, delete the searchable index in Firestore
      try {
        await db.collection("searchable_shops").doc(shopId).delete();
      } catch (e) {
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
        } catch (e) {
          console.error("Error writing searchable shop to Firestore:", e);
        }

        try {
          // 2. Write the geohash back to RTDB shop profile if it's missing or different
          if (after.geohash !== geohash) {
            await change.after.ref.child("geohash").set(geohash);
            console.log(`Updated geohash in RTDB for shop ${shopId}`);
          }
        } catch (e) {
          console.error("Error updating geohash in RTDB:", e);
        }
      }
    }

    return null;
  });

// Recalculates average rating and review counts for a shop
async function updateShopRating(shopId: string) {
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
async function updateProductRating(productId: string, shopId?: string) {
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

  // Resolve shopId
  let resolvedShopId = shopId;
  if (!resolvedShopId) {
    // Fallback 1: check review documents
    for (const doc of reviewsSnap.docs) {
      if (doc.data().shopId) {
        resolvedShopId = doc.data().shopId;
        break;
      }
    }
  }

  if (!resolvedShopId) {
    // Fallback 2: check Firestore products collection
    const productDoc = await db.collection("products").doc(productId).get();
    if (productDoc.exists) {
      resolvedShopId = productDoc.data()?.shopId;
    }
  }

  if (!resolvedShopId) {
    // Fallback 3: scan RTDB products node
    const productsSnap = await admin.database().ref("products").once("value");
    if (productsSnap.exists()) {
      const productsData = productsSnap.val();
      for (const sId of Object.keys(productsData)) {
        if (productsData[sId][productId]) {
          resolvedShopId = sId;
          break;
        }
      }
    }
  }

  if (resolvedShopId) {
    // Update RTDB product node
    await admin.database().ref(`products/${resolvedShopId}/${productId}`).update({
      avgRating: avgRating,
      totalRatings: totalRatings,
      rating: avgRating
    });
    console.log(`Updated RTDB product: ${resolvedShopId}/${productId} with rating ${avgRating}`);
  } else {
    console.log(`Could not find shopId for product ${productId}, RTDB update skipped.`);
  }

  console.log(`Updated ratings for Product ${productId}: avgRating = ${avgRating}, totalRatings = ${totalRatings}`);
}

export const onShopReviewWrite = functions.firestore.document("/shop_reviews/{reviewId}")
  .onWrite(async (change, context) => {
    const data = change.after.exists ? change.after.data() : change.before.data();
    if (!data) return null;
    const shopId = data.shopId;
    if (shopId) {
      await updateShopRating(shopId);
    }
    return null;
  });

export const onProductReviewWrite = functions.firestore.document("/product_reviews/{reviewId}")
  .onWrite(async (change, context) => {
    const data = change.after.exists ? change.after.data() : change.before.data();
    if (!data) return null;
    const productId = data.productId;
    const shopId = data.shopId;
    if (productId) {
      await updateProductRating(productId, shopId);
    }
    return null;
  });

// Mock Product Review Function has been deleted as per BUG-7

// Validate session and ensure claims are in sync
export const validateSession = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be authenticated.");
  }

  const uid = context.auth.uid;
  const targetRole = data.targetRole || "customer";
  const deviceInfo = data.deviceInfo || {};

  // 1. Fetch user data from Realtime Database
  const userSnap = await admin.database().ref(`/users/${uid}`).once("value");
  if (!userSnap.exists()) {
    throw new functions.https.HttpsError("not-found", "User record not found in database.");
  }

  const userData = userSnap.val();

  // 2. Check for Account Suspension/Ban
  if (userData.status === "suspended" || userData.status === "banned") {
    throw new functions.https.HttpsError("permission-denied", "This account has been suspended.");
  }

  // 3. Validate and Update Role Access
  const roles = userData.roles || {};
  const isMerchant = roles.merchant === true || userData.role === "merchant";
  let isCustomer = roles.customer === true || userData.role === "customer";

  let hasRole = targetRole === "customer" ? isCustomer : isMerchant;

  if (!hasRole) {
    // If they want to access customer app and they are already a merchant, we grant them customer role dynamically
    if (targetRole === "customer" && isMerchant) {
      isCustomer = true;
      roles.customer = true;
      roles.merchant = true;
      await admin.database().ref(`/users/${uid}/roles`).update({
        customer: true,
        merchant: true
      });
      hasRole = true;
    } else {
      throw new functions.https.HttpsError("permission-denied", `User does not possess the '${targetRole}' role.`);
    }
  }

  // 4. Create Active Session Record in Firestore
  const sessionRef = db.collection("sessions").doc();
  await sessionRef.set({
    sessionId: sessionRef.id,
    uid: uid,
    deviceInfo: deviceInfo,
    lastActive: admin.firestore.FieldValue.serverTimestamp(),
    status: "active"
  });

  // 5. Ensure Claims are In-Sync with database roles
  const userRecord = await admin.auth().getUser(uid);
  const existingClaims = userRecord.customClaims || {};
  const currentRoles = {
    customer: isCustomer,
    merchant: isMerchant
  };

  await admin.auth().setCustomUserClaims(uid, {
    ...existingClaims,
    roles: currentRoles,
    activeRole: targetRole,
    customer: currentRoles.customer,
    merchant: currentRoles.merchant
  });

  return { success: true, sessionId: sessionRef.id };
});

// 17. Send Push Notification on New Chat Message (RTDB trigger)
export const onChatMessageCreated = functions.database.ref("/chats/{uid1}/{uid2}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const messageVal = snapshot.val();
    if (!messageVal) return null;

    const uid1 = context.params.uid1;
    const uid2 = context.params.uid2;

    const senderId = messageVal.senderId;
    const receiverId = messageVal.receiverId;
    const text = messageVal.text || "";

    // To prevent duplicate triggers (since the message is written under both chats/sender/receiver/messages and chats/receiver/sender/messages),
    // we only process the event where the first parameter `uid1` equals the `senderId`.
    if (uid1 !== senderId) {
      console.log("Duplicate trigger ignored: uid1 is not senderId");
      return null;
    }

    console.log(`New message from ${senderId} to ${receiverId}: ${text}`);

    // Determine receiver's expected role. 
    // If senderId == vendorId/shopId, sender is merchant, receiver is customer.
    // If senderId != vendorId/shopId (sender is customer), receiver is merchant.
    const vendorId = messageVal.vendorId || messageVal.shopId || uid2;
    const isSenderVendor = (senderId === vendorId);
    const role = isSenderVendor ? "customer" : "merchant";

    // Fetch token for the receiver
    let tokenSnapshot = await admin.database().ref(`/users_devices/${receiverId}/${role}/fcmToken`).once("value");
    let token = tokenSnapshot.val();

    if (!token) {
      // Fallback: check the other role just in case
      const otherRole = role === "customer" ? "merchant" : "customer";
      tokenSnapshot = await admin.database().ref(`/users_devices/${receiverId}/${otherRole}/fcmToken`).once("value");
      token = tokenSnapshot.val();
    }

    if (!token) {
      console.log(`No FCM token found for receiver ${receiverId}`);
      return null;
    }

    // Fetch sender's name to display in notification
    let senderName = "New Message";
    if (isSenderVendor) {
      // Sender is vendor/merchant. Get shop name.
      const shopSnapshot = await admin.database().ref(`/shop/${senderId}`).once("value");
      if (shopSnapshot.exists()) {
        const shopData = shopSnapshot.val();
        senderName = shopData.name || shopData.shopName || "Merchant";
      }
    } else {
      // Sender is customer. Get user email/name from users.
      const senderSnap = await admin.database().ref(`/users/${senderId}`).once("value");
      if (senderSnap.exists()) {
        const senderData = senderSnap.val();
        senderName = senderData.name || senderData.email || "Customer";
      }
    }

    const messagePayload = {
      token: token,
      notification: {
        title: senderName,
        body: text,
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
        type: "chat",
        senderId: senderId,
        receiverId: receiverId,
        shopId: isSenderVendor ? senderId : receiverId,
      },
    };

    try {
      const response = await admin.messaging().send(messagePayload);
      console.log(`Successfully sent chat notification to ${receiverId}:`, response);
    } catch (error) {
      console.error("Error sending chat notification:", error);
    }
    return null;
  });


