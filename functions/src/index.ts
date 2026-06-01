import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import { encodeGeohash } from "./geohash";

admin.initializeApp();
const db = admin.firestore();

// When ENFORCE_APP_CHECK=true, reject callable requests that don't carry a valid
// Firebase App Check token. This blocks abuse from outside the official apps
// (e.g. SMS-pumping via the OTP endpoint, Cloudinary signature theft).
// Kept behind a flag so it can be switched on only after App Check providers
// (Play Integrity / DeviceCheck) are registered for both apps in the console.
function assertAppCheck(context: functions.https.CallableContext): void {
  if (process.env.ENFORCE_APP_CHECK === "true" && context.app === undefined) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "This request did not originate from an authorized app."
    );
  }
}

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

// NOTE: The custom Twilio/Fast2SMS OTP system (sendTwilioSms, sendFast2Sms,
// generateAndSendOtp, verifyOtp, resetPasswordWithOtp) was removed before the
// production launch. Both apps use native Firebase Phone Auth for phone
// verification, so this parallel system was dead code that still carried live
// SMS-cost/abuse exposure and required Twilio/Fast2SMS secrets. Phone login
// resolution still happens through resolvePhoneLoginEmail below.

export const resolvePhoneLoginEmail = functions.https.onCall(async (data, context) => {
  assertAppCheck(context);
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

// Password reset is handled client-side via native Firebase Phone Auth
// (reauthenticate with the phone OTP credential, then updatePassword) — see the
// resetPasswordWithPhoneOtp flow in the apps. The old OTP-based reset was removed
// with the rest of the custom SMS system.

// BUG-6: getCloudinarySignature
// Security Rationale: Compute signature server-side using secure secret from environment
export const getCloudinarySignature = functions.https.onCall(async (data, context) => {
  // Only authenticated users may obtain a signed upload signature. Without this
  // check, anyone could mint valid Cloudinary upload credentials and abuse the account.
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "You must be signed in to upload images.");
  }
  assertAppCheck(context);

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

// ─────────────────────────────────────────────────────────────────────────────
// Advanced auth: identity-platform blocking functions
//
// Blocking functions run *inside* the create/sign-in transaction, so the checks
// here cannot be skipped by a tampered client (unlike a callable such as
// validateSession). They require Identity Platform to be enabled and the
// functions to be registered as blocking triggers in the console.
// ─────────────────────────────────────────────────────────────────────────────

// Build the canonical custom-claims object from a user's RTDB record + auth state.
// Claims are what the security rules trust, so this is the single source of truth.
function buildAuthClaims(
  existingClaims: Record<string, unknown>,
  userData: Record<string, any> | null,
  opts: { emailVerified: boolean; mfaEnrolled: boolean; activeRole?: string }
): Record<string, unknown> {
  const roles = (userData && userData.roles) || {};
  // Legacy single-role field fallback.
  const isCustomer = roles.customer === true || userData?.role === "customer" || true; // every account is at least a customer
  const isMerchant = roles.merchant === true || userData?.role === "merchant";

  const activeRole =
    opts.activeRole ||
    (typeof existingClaims.activeRole === "string" ? (existingClaims.activeRole as string) : undefined) ||
    userData?.activeRole ||
    "customer";

  return {
    ...existingClaims,
    roles: { customer: isCustomer, merchant: isMerchant },
    activeRole,
    customer: isCustomer,
    merchant: isMerchant,
    mfa: opts.mfaEnrolled,
    emailVerified: opts.emailVerified,
    // Claims schema version — lets the client detect/force a token refresh after upgrades.
    cv: 2,
  };
}

// Stable fingerprint for a sign-in context (does not store raw IP/UA in claims).
function deviceFingerprint(ipAddress?: string, userAgent?: string): string {
  return crypto
    .createHash("sha256")
    .update(`${ipAddress || "?"}|${userAgent || "?"}`)
    .digest("hex")
    .substring(0, 16);
}

// Records the signing-in device and sends a one-time alert the first time a
// device is seen. Best-effort: never blocks sign-in on failure.
async function recordDeviceAndMaybeAlert(
  uid: string,
  ipAddress?: string,
  userAgent?: string
): Promise<void> {
  try {
    const fp = deviceFingerprint(ipAddress, userAgent);
    const ref = admin.database().ref(`/known_devices/${uid}/${fp}`);
    const snap = await ref.once("value");
    const now = Date.now();

    if (snap.exists()) {
      await ref.update({ lastSeen: now });
      return;
    }

    // New device.
    await ref.set({ firstSeen: now, lastSeen: now, userAgent: userAgent || null, ip: ipAddress || null });

    // Alert the user on their existing devices (skip the very first device ever,
    // which is this account's initial login).
    const devicesSnap = await admin.database().ref(`/known_devices/${uid}`).once("value");
    if (devicesSnap.numChildren() <= 1) return;

    const tokensSnap = await admin.database().ref(`/users_devices/${uid}`).once("value");
    const tokens: string[] = [];
    tokensSnap.forEach((roleNode) => {
      const t = roleNode.child("fcmToken").val();
      if (typeof t === "string" && t.length > 0) tokens.push(t);
      return false;
    });
    if (tokens.length === 0) return;

    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: "New sign-in detected",
        body: "Your account was just accessed from a new device. If this wasn't you, secure your account.",
      },
      data: { type: "security_new_device" },
    });
  } catch (e) {
    console.error("recordDeviceAndMaybeAlert failed (non-fatal):", e);
  }
}

// Runs before a new account is created: stamps default claims so the user's very
// first ID token already carries the correct roles (no race with onUserCreated).
export const beforeUserCreated = functions.auth.user().beforeCreate((user) => {
  return {
    customClaims: buildAuthClaims({}, null, {
      emailVerified: user.emailVerified === true,
      mfaEnrolled: (user.multiFactor?.enrolledFactors?.length || 0) > 0,
      activeRole: "customer",
    }),
  };
});

// Runs before every sign-in: enforces account status at the token level and
// refreshes roles/mfa/emailVerified claims so the rules always see current state.
export const beforeUserSignedIn = functions.auth.user().beforeSignIn(async (user, context) => {
  const uid = user.uid;

  const userSnap = await admin.database().ref(`/users/${uid}`).once("value");
  const userData = userSnap.exists() ? userSnap.val() : null;

  // Hard block suspended/banned accounts — they can't obtain a token at all.
  if (userData && (userData.status === "suspended" || userData.status === "banned")) {
    throw new functions.auth.HttpsError("permission-denied", "This account has been suspended.");
  }

  // Fire-and-forget device tracking / new-device alert.
  await recordDeviceAndMaybeAlert(uid, context.ipAddress, context.userAgent);

  const mfaEnrolled = (user.multiFactor?.enrolledFactors?.length || 0) > 0;

  return {
    customClaims: buildAuthClaims((user.customClaims as Record<string, unknown>) || {}, userData, {
      emailVerified: user.emailVerified === true,
      mfaEnrolled,
    }),
  };
});

export const assignMerchantRole = functions.https.onCall(async (data, context) => {
  assertAppCheck(context);
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "The function must be called while authenticated.");
  }

  const uid = context.auth.uid;

  // Gate 1: a shop profile must exist and be reasonably complete (name + address),
  // so a tap-through can't mint an empty merchant account.
  const shopSnap = await admin.database().ref(`/shop/${uid}`).once("value");
  if (!shopSnap.exists()) {
    throw new functions.https.HttpsError("not-found", "No shop profile found. Please set up your shop first.");
  }
  const shop = shopSnap.val();
  const shopName = (shop.name || shop.shopName || "").toString().trim();
  const shopAddress = (shop.address || "").toString().trim();
  if (shopName.length < 2 || shopAddress.length < 3) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Please complete your shop profile (name and address) before becoming a merchant."
    );
  }

  // Gate 2: the account must have a verified contact channel — a verified phone
  // (set during phone-OTP linking) or a verified email. Prevents drive-by
  // self-promotion from unverified accounts.
  const userSnap = await admin.database().ref(`/users/${uid}`).once("value");
  const userData = userSnap.exists() ? userSnap.val() : {};
  const phoneVerified = userData.verified === true || typeof context.auth.token.phone_number === "string";
  const emailVerified = context.auth.token.email_verified === true;
  if (!phoneVerified && !emailVerified) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Please verify your phone number or email before becoming a merchant."
    );
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

// NOTE: migrateUserRoles (a one-time legacy-role migration) was removed before the
// production launch. It iterated over every user and rewrote roles/custom claims,
// and was callable by any authenticated user — an expensive, abusable operation.
// If a future migration is needed, run it as an admin-only script, not a public callable.

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
  assertAppCheck(context);
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

// ─────────────────────────────────────────────────────────────────────────────
// Advanced auth: device & session management
// Devices are tracked in RTDB (/known_devices/{uid}) by the beforeSignIn blocking
// function. These callables let the user review and revoke them.
// ─────────────────────────────────────────────────────────────────────────────

// Lists the devices that have signed in to this account.
export const listMyDevices = functions.https.onCall(async (data, context) => {
  assertAppCheck(context);
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  }
  const snap = await admin.database().ref(`/known_devices/${context.auth.uid}`).once("value");
  const devices: Array<Record<string, unknown>> = [];
  snap.forEach((child) => {
    const v = child.val() || {};
    devices.push({
      id: child.key,
      firstSeen: v.firstSeen || null,
      lastSeen: v.lastSeen || null,
      userAgent: v.userAgent || null,
    });
    return false;
  });
  // Most recently active first.
  devices.sort((a, b) => Number(b.lastSeen || 0) - Number(a.lastSeen || 0));
  return { devices };
});

// Removes a single device record (and any push token it could be alerted on).
// Note: Firebase refresh tokens are per-user, not per-device, so this stops
// future new-device alerts for that fingerprint; use signOutEverywhere to
// actually invalidate active sessions.
export const revokeDevice = functions.https.onCall(async (data, context) => {
  assertAppCheck(context);
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  }
  const deviceId = typeof data?.deviceId === "string" ? data.deviceId : "";
  if (!deviceId) {
    throw new functions.https.HttpsError("invalid-argument", "deviceId is required.");
  }
  await admin.database().ref(`/known_devices/${context.auth.uid}/${deviceId}`).remove();
  return { success: true };
});

// "Log out everywhere": invalidates all refresh tokens for the account and
// clears the device registry. Clients must call getIdToken(true) afterwards;
// other sessions are forced to re-authenticate once their ID token expires
// (or immediately if the client verifies tokens with checkRevoked).
export const signOutEverywhere = functions.https.onCall(async (data, context) => {
  assertAppCheck(context);
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  }
  const uid = context.auth.uid;
  await admin.auth().revokeRefreshTokens(uid);
  await admin.database().ref(`/known_devices/${uid}`).remove();
  await admin.database().ref(`/users/${uid}/security/lastGlobalSignOut`).set(Date.now());
  return { success: true };
});

// Step-up gate for sensitive operations. The client must reauthenticate
// immediately before calling this so the ID token's auth_time is fresh; we
// reject if the most recent authentication is older than maxAgeSeconds.
export const assertRecentAuth = functions.https.onCall(async (data, context) => {
  assertAppCheck(context);
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  }
  const maxAgeSeconds = typeof data?.maxAgeSeconds === "number" ? data.maxAgeSeconds : 300;
  const authTime = Number(context.auth.token.auth_time || 0); // seconds since epoch
  const ageSeconds = Math.floor(Date.now() / 1000) - authTime;
  if (authTime === 0 || ageSeconds > maxAgeSeconds) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Please re-enter your credentials to continue."
    );
  }
  return { ok: true, ageSeconds };
});

// 17. Send Push Notification on New Chat Message (RTDB trigger)
export const onChatMessageCreated = functions.database.ref("/chats/{uid1}/{uid2}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const messageVal = snapshot.val();
    if (!messageVal) return null;

    const uid1 = context.params.uid1;
    const uid2 = context.params.uid2;

    const senderId: string = messageVal.senderId || uid1;
    // Fallback to uid2 when receiverId is not written into the message (e.g. customer app omits it)
    const receiverId: string = messageVal.receiverId || uid2;
    const text: string = messageVal.text || "";

    // Only process the copy written under the sender's uid to avoid duplicate triggers.
    if (uid1 !== senderId) {
      console.log("Duplicate trigger ignored: uid1 is not senderId");
      return null;
    }

    console.log(`New message from ${senderId} to ${receiverId}: ${text}`);

    // Determine roles: if the sender is the vendor, the receiver is the customer, and vice versa.
    const vendorId: string = messageVal.vendorId || messageVal.shopId || uid2;
    const isSenderVendor = (senderId === vendorId);
    const receiverRole = isSenderVendor ? "customer" : "merchant";

    // Fetch FCM token for the receiver (try their primary role first, then the other).
    let tokenSnap = await admin.database()
      .ref(`/users_devices/${receiverId}/${receiverRole}/fcmToken`).once("value");
    let token: string | null = tokenSnap.val();

    if (!token) {
      const fallbackRole = receiverRole === "merchant" ? "customer" : "merchant";
      tokenSnap = await admin.database()
        .ref(`/users_devices/${receiverId}/${fallbackRole}/fcmToken`).once("value");
      token = tokenSnap.val();
    }

    if (!token) {
      console.log(`No FCM token found for receiver ${receiverId}`);
      return null;
    }

    // Resolve the sender's display name.
    // 1. Check the conversation node stored under the receiver's view (most reliable for name).
    // 2. Fall back to the users/ node or shop/ node.
    let senderName = "Customer";
    const convSnap = await admin.database()
      .ref(`/chats/${receiverId}/${senderId}/userName`).once("value");
    if (convSnap.exists() && convSnap.val()) {
      senderName = convSnap.val();
    } else if (isSenderVendor) {
      const shopSnap = await admin.database().ref(`/shop/${senderId}`).once("value");
      if (shopSnap.exists()) {
        const s = shopSnap.val();
        senderName = s.name || s.shopName || "Merchant";
      }
    } else {
      const userSnap = await admin.database().ref(`/users/${senderId}`).once("value");
      if (userSnap.exists()) {
        const u = userSnap.val();
        senderName = u.name || u.displayName || u.email || "Customer";
      }
    }

    const payload = {
      token,
      notification: {
        title: senderName,
        body: text,
      },
      android: {
        notification: {
          sound: "default",
          channelId: "chat_messages",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        payload: {
          aps: { sound: "default" },
        },
      },
      // Data payload lets the app navigate directly to the right chat when tapped.
      data: {
        type: "chat",
        senderId: senderId,
        receiverId: receiverId,
        userId: senderId,   // convenience alias used by the Flutter client
        userName: senderName,
        shopId: isSenderVendor ? senderId : receiverId,
      },
    };

    try {
      const response = await admin.messaging().send(payload);
      console.log(`Chat notification sent to ${receiverId} (${receiverRole}):`, response);
    } catch (error) {
      console.error("Error sending chat notification:", error);
    }
    return null;
  });


