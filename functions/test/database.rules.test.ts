import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { readFileSync } from "fs";
import { resolve } from "path";

// Security-rules tests for database.rules.json. They run against the Realtime
// Database emulator (see `npm run test:rules`) and lock in the Phase-1 hardening:
//   - a user cannot self-grant `verified` without a real phone/email token,
//   - a vendor cannot self-mark their shop `isVerified`,
//   - a vendor cannot forge shop/product ratings (server-owned),
//   - product prices/stock cannot be negative,
//   - offer discounts stay within 0–100,
//   - identity boundaries (own uid only) still hold.

const VENDOR = "vendor-uid";
const OTHER = "other-uid";

let testEnv: RulesTestEnvironment;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "demo-localvyapari",
    database: {
      rules: readFileSync(resolve(__dirname, "../../database.rules.json"), "utf8"),
      host: "127.0.0.1",
      port: 9000,
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearDatabase();
});

// Seed data bypassing rules (admin-equivalent), e.g. server-written ratings.
async function seed(path: string, value: unknown): Promise<void> {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.database().ref(path).set(value);
  });
}

describe("users/{uid}/verified", () => {
  it("rejects self-granting verified=true without a phone/email token", async () => {
    const db = testEnv.authenticatedContext(VENDOR, {}).database();
    await assertFails(db.ref(`users/${VENDOR}/verified`).set(true));
  });

  it("allows verified=true when the token carries a phone number", async () => {
    const db = testEnv
      .authenticatedContext(VENDOR, { phone_number: "+919000000001" })
      .database();
    await assertSucceeds(db.ref(`users/${VENDOR}/verified`).set(true));
  });

  it("allows verified=true when the email is verified", async () => {
    const db = testEnv
      .authenticatedContext(VENDOR, { email_verified: true })
      .database();
    await assertSucceeds(db.ref(`users/${VENDOR}/verified`).set(true));
  });

  it("always allows setting verified=false", async () => {
    const db = testEnv.authenticatedContext(VENDOR, {}).database();
    await assertSucceeds(db.ref(`users/${VENDOR}/verified`).set(false));
  });

  it("forbids writing another user's record", async () => {
    const db = testEnv.authenticatedContext(VENDOR, {}).database();
    await assertFails(db.ref(`users/${OTHER}/verified`).set(false));
  });
});

describe("shop/{uid}", () => {
  it("lets a vendor create their shop with isVerified=false", async () => {
    const db = testEnv.authenticatedContext(VENDOR, {}).database();
    await assertSucceeds(
      db.ref(`shop/${VENDOR}`).set({
        name: "Test Shop",
        description: "Welcome",
        address: "MG Road",
        phone: "+919000000001",
        isOpen: true,
        isVerified: false,
      })
    );
  });

  it("forbids a vendor self-verifying their shop (isVerified=true)", async () => {
    await seed(`shop/${VENDOR}`, { name: "Test Shop", isVerified: false });
    const db = testEnv.authenticatedContext(VENDOR, {}).database();
    await assertFails(db.ref(`shop/${VENDOR}/isVerified`).set(true));
  });

  it("forbids a vendor forging their shop rating", async () => {
    await seed(`shop/${VENDOR}`, { name: "Test Shop", rating: 4, totalReviews: 2 });
    const db = testEnv.authenticatedContext(VENDOR, {}).database();
    await assertFails(db.ref(`shop/${VENDOR}/rating`).set(5));
    await assertFails(db.ref(`shop/${VENDOR}/totalReviews`).set(9999));
  });

  it("allows ordinary profile edits (name/address)", async () => {
    await seed(`shop/${VENDOR}`, { name: "Old", isVerified: false });
    const db = testEnv.authenticatedContext(VENDOR, {}).database();
    await assertSucceeds(
      db.ref(`shop/${VENDOR}`).update({ name: "New Name", address: "New St" })
    );
  });

  it("forbids writing another vendor's shop", async () => {
    const db = testEnv.authenticatedContext(VENDOR, {}).database();
    await assertFails(db.ref(`shop/${OTHER}/name`).set("hijack"));
  });
});

describe("products/{uid}/{productId}", () => {
  it("lets a vendor add a product with a valid price/stock", async () => {
    const db = testEnv.authenticatedContext(VENDOR, {}).database();
    await assertSucceeds(
      db.ref(`products/${VENDOR}/p1`).set({
        name: "Rice",
        category: "Grocery",
        actualPrice: 50,
        stockQuantity: 10,
        isActive: true,
      })
    );
  });

  it("rejects a negative price and negative stock", async () => {
    const db = testEnv.authenticatedContext(VENDOR, {}).database();
    await assertFails(db.ref(`products/${VENDOR}/p1/actualPrice`).set(-1));
    await assertFails(db.ref(`products/${VENDOR}/p1/stockQuantity`).set(-5));
  });

  it("forbids a vendor forging a product rating", async () => {
    await seed(`products/${VENDOR}/p1`, {
      name: "Rice",
      actualPrice: 50,
      rating: 4.5,
      totalRatings: 3,
    });
    const db = testEnv.authenticatedContext(VENDOR, {}).database();
    await assertFails(db.ref(`products/${VENDOR}/p1/rating`).set(5));
    await assertFails(db.ref(`products/${VENDOR}/p1/totalRatings`).set(9999));
    await assertFails(db.ref(`products/${VENDOR}/p1/avgRating`).set(5));
  });
});

describe("offers/{uid}/{offerId}", () => {
  it("allows a discount within 0–100", async () => {
    const db = testEnv.authenticatedContext(VENDOR, {}).database();
    await assertSucceeds(
      db.ref(`offers/${VENDOR}/o1`).set({
        title: "Sale",
        discountPercentage: 25,
        isActive: true,
      })
    );
  });

  it("rejects a discount above 100", async () => {
    const db = testEnv.authenticatedContext(VENDOR, {}).database();
    await assertFails(db.ref(`offers/${VENDOR}/o1/discountPercentage`).set(150));
  });
});

describe("phones/{phone}", () => {
  it("lets a user claim a phone for their own uid", async () => {
    const db = testEnv.authenticatedContext(VENDOR, {}).database();
    await assertSucceeds(db.ref("phones/+919000000001").set(VENDOR));
  });

  it("forbids claiming a phone for someone else's uid", async () => {
    const db = testEnv.authenticatedContext(VENDOR, {}).database();
    await assertFails(db.ref("phones/+919000000001").set(OTHER));
  });
});
