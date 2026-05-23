import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

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
      const userDoc = await db.collection("users").doc(vendorId).get();
      const tokens = userDoc.data()?.fcmTokens || [];

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

// 5. Password Reset via RTDB Trigger (Safe & Secure password updates)
export const onPasswordResetRequest = functions.database.ref("/password_resets/{phone}")
  .onCreate(async (snapshot, context) => {
    const data = snapshot.val();
    if (!data) return null;

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
        } catch (e) {
          console.error("Error cleaning up reset request:", e);
        }
      }, 10000);

    } catch (error: any) {
      console.error("Error during password reset:", error);
      await ref.update({ status: "error", error: error.message || "Internal server error" });
    }

    return null;
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
async function updateProductRating(productId: string) {
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
    const shopId = productDoc.data()?.shopId;
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
    if (productId) {
      await updateProductRating(productId);
    }
    return null;
  });

export const addMockProductReview = functions.https.onRequest(async (req, res) => {
  const { productId, rating, comment } = req.query;
  if (!productId) {
    res.status(400).send("Missing productId");
    return;
  }
  const ref = await db.collection("product_reviews").add({
    productId,
    rating: parseFloat(rating as string) || 5,
    comment: comment || "Great product!",
    userId: "mock_user_id",
    userDisplayName: "Test Customer",
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });
  res.status(200).send(`Added mock review: ${ref.id}`);
});



