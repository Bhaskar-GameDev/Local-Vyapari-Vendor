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
