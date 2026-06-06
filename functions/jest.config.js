/** @type {import('ts-jest').JestConfigWithTsJest} */
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  testMatch: ["**/test/**/*.test.ts"],
  // Rules tests need the database emulator; they run via `npm run test:rules`
  // (jest.rules.config.js) under `firebase emulators:exec`, not the default run.
  testPathIgnorePatterns: ["/node_modules/", "\\.rules\\.test\\.ts$"],
};
