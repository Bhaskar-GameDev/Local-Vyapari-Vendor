// Pure geohash encoding — no firebase-admin/functions imports, so it can be unit
// tested without booting the Admin SDK. Used by onShopProfileUpdate to index shop
// locations for proximity search.

export const BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz";

/**
 * Encodes a (latitude, longitude) pair into a geohash string of the given
 * precision (default 9 chars ≈ ~4.8m cell).
 */
export function encodeGeohash(
  latitude: number,
  longitude: number,
  precision = 9
): string {
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
