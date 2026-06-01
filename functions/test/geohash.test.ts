import { encodeGeohash, BASE32 } from "../src/geohash";

// Unit tests for the pure geohash encoder used to index shop locations.
// No firebase-admin boot required — this is the template for testing the rest of
// the pure helpers; trigger functions need firebase-functions-test (already a
// devDependency) wrapping admin.

describe("encodeGeohash", () => {
  it("produces the canonical hash for a known landmark", () => {
    // Authoritative reference vector: (39.92324, 116.3906) → "wx4g0" at
    // precision 5 (widely published geohash test point, Beijing).
    expect(encodeGeohash(39.92324, 116.3906, 5)).toBe("wx4g0");
    // Regression anchor for a San Francisco coordinate at precision 7.
    expect(encodeGeohash(37.7955, -122.3937, 7)).toBe("9q8znb7");
  });

  it("respects the requested precision (length == precision)", () => {
    for (const p of [1, 5, 9, 12]) {
      expect(encodeGeohash(12.9716, 77.5946, p)).toHaveLength(p);
    }
  });

  it("defaults to 9 characters", () => {
    expect(encodeGeohash(12.9716, 77.5946)).toHaveLength(9);
  });

  it("only emits valid base32 characters", () => {
    const hash = encodeGeohash(-33.8688, 151.2093, 11);
    for (const c of hash) {
      expect(BASE32).toContain(c);
    }
  });

  it("is deterministic for the same input", () => {
    const a = encodeGeohash(28.6139, 77.209, 10);
    const b = encodeGeohash(28.6139, 77.209, 10);
    expect(a).toBe(b);
  });

  it("nearby points share a longer prefix than distant ones", () => {
    const bengaluru = encodeGeohash(12.9716, 77.5946, 9);
    const nearby = encodeGeohash(12.9726, 77.5956, 9);
    const sydney = encodeGeohash(-33.8688, 151.2093, 9);

    const sharedPrefix = (x: string, y: string) => {
      let i = 0;
      while (i < x.length && x[i] === y[i]) i++;
      return i;
    };

    expect(sharedPrefix(bengaluru, nearby))
      .toBeGreaterThan(sharedPrefix(bengaluru, sydney));
  });

  it("handles the origin and the poles without throwing", () => {
    expect(() => encodeGeohash(0, 0)).not.toThrow();
    expect(() => encodeGeohash(90, 180)).not.toThrow();
    expect(() => encodeGeohash(-90, -180)).not.toThrow();
  });
});
