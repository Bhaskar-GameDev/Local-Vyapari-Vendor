/** @type {import('ts-jest').JestConfigWithTsJest} */
// Separate config for security-rules tests. These require the Realtime Database
// emulator, so they are only run via `npm run test:rules` (which wraps this in
// `firebase emulators:exec`), never by the default emulator-free `npm test`.
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  testMatch: ["**/test/**/*.rules.test.ts"],
  // The emulator boot + multiple round-trips can exceed jest's 5s default.
  testTimeout: 20000,
};
