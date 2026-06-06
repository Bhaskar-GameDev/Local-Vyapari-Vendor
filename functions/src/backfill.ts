import * as admin from "firebase-admin";
import { encodeGeohash } from "./geohash";

// Use local RTDB emulator host if not already set in the environment
if (!process.env.FIREBASE_DATABASE_EMULATOR_HOST) {
  process.env.FIREBASE_DATABASE_EMULATOR_HOST = "127.0.0.1:9000";
}
if (!process.env.FIRESTORE_EMULATOR_HOST) {
  process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
}
if (!process.env.GCLOUD_PROJECT) {
  process.env.GCLOUD_PROJECT = "local-vyapari-437e0";
}

admin.initializeApp({
  databaseURL: `http://${process.env.FIREBASE_DATABASE_EMULATOR_HOST}?ns=local-vyapari-437e0`
});

const rtdb = admin.database();
const db = admin.firestore();

async function backfill() {
  console.log("Starting backfill migration of shop profiles...");
  const shopsRef = rtdb.ref("shop");
  const snapshot = await shopsRef.once("value");
  const shops = snapshot.val();

  if (!shops) {
    console.log("No shops found in RTDB to backfill.");
    return;
  }

  const shopIds = Object.keys(shops);
  console.log(`Found ${shopIds.length} shop profiles in RTDB. Starting update...`);

  for (const shopId of shopIds) {
    const shop = shops[shopId];
    
    const latitude = shop.latitude;
    const longitude = shop.longitude;
    const name = shop.name || shop.shopName || "My Shop";
    
    let geohash = shop.geohash || "";
    if (latitude !== undefined && longitude !== undefined && latitude !== null && longitude !== null) {
      const latNum = parseFloat(latitude);
      const lngNum = parseFloat(longitude);
      if (!isNaN(latNum) && !isNaN(lngNum)) {
        geohash = encodeGeohash(latNum, lngNum, 9);
      }
    }

    const updatedShop = {
      name: name,
      ownerId: shop.ownerId || shopId,
      description: shop.description || "",
      phone: shop.phone || "",
      logoUrl: shop.logoUrl || shop.shopLogo || "",
      bannerUrl: shop.bannerUrl || shop.shopBanner || "",
      isOpen: shop.isOpen !== undefined ? shop.isOpen : true,
      isVerified: shop.isVerified !== undefined ? shop.isVerified : false,
      openingTime: shop.openingTime || null,
      closingTime: shop.closingTime || null,
      rating: shop.rating !== undefined ? parseFloat(shop.rating) : 0,
      totalReviews: shop.totalReviews !== undefined ? parseInt(shop.totalReviews) : 0,
      createdAt: shop.createdAt !== undefined ? parseInt(shop.createdAt) : Date.now(),
      latitude: latitude !== undefined && latitude !== null ? parseFloat(latitude) : null,
      longitude: longitude !== undefined && longitude !== null ? parseFloat(longitude) : null,
      geohash: geohash,
      address: shop.address || "",
      city: shop.city || "",
      state: shop.state || "",
      pincode: shop.pincode || "",
      placeId: shop.placeId || "",
    };

    // Update in RTDB (this will trigger the cloud function onShopProfileUpdate locally if running, but we also update it ourselves or let the function index it)
    await shopsRef.child(shopId).update(updatedShop);
    console.log(`Updated RTDB for shop ${shopId} (${name})`);

    // Manually index to searchable_shops to ensure Firestore is also in sync
    if (latitude !== undefined && longitude !== undefined && latitude !== null && longitude !== null) {
      const latNum = parseFloat(latitude);
      const lngNum = parseFloat(longitude);
      if (!isNaN(latNum) && !isNaN(lngNum)) {
        await db.collection("searchable_shops").doc(shopId).set({
          name: name,
          shopName: name,
          ownerId: updatedShop.ownerId,
          description: updatedShop.description,
          phone: updatedShop.phone,
          logoUrl: updatedShop.logoUrl,
          bannerUrl: updatedShop.bannerUrl,
          isOpen: updatedShop.isOpen,
          isVerified: updatedShop.isVerified,
          openingTime: updatedShop.openingTime,
          closingTime: updatedShop.closingTime,
          rating: updatedShop.rating,
          totalReviews: updatedShop.totalReviews,
          createdAt: updatedShop.createdAt,
          latitude: latNum,
          longitude: lngNum,
          geohash: geohash,
          address: updatedShop.address,
          city: updatedShop.city,
          state: updatedShop.state,
          pincode: updatedShop.pincode,
          placeId: updatedShop.placeId,
          geo: {
            geohash: geohash,
            geopoint: new admin.firestore.GeoPoint(latNum, lngNum)
          }
        }, { merge: true });
        console.log(`Indexed shop ${shopId} to searchable_shops in Firestore`);
      }
    }
  }

  console.log("Backfill migration completed successfully.");
}

backfill().then(() => {
  process.exit(0);
}).catch((err) => {
  console.error("Backfill migration failed:", err);
  process.exit(1);
});
