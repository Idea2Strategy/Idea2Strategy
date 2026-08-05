import assert from "node:assert/strict";
import test from "node:test";
import { handler } from "./index.mjs";

const event = (triggerSource = "TokenGeneration_HostedAuth") => ({
  version: "2_0",
  triggerSource,
  callerContext: { clientId: "operator-browser-client" },
  response: {
    claimsAndScopeOverrideDetails: {
      idTokenGeneration: { claimsToAddOrOverride: { existing: "preserved" } },
    },
  },
});

test("adds exact audience and namespaced MFA evidence without reserved claims", async () => {
  const transformed = await handler(event());
  const access = transformed.response.claimsAndScopeOverrideDetails.accessTokenGeneration;
  assert.deepEqual(access.claimsToAddOrOverride, {
    aud: "operator-browser-client",
    "https://ideatostrategy.com/claims/mfa": "cognito:mfa-required",
  });
  assert.equal("acr" in access.claimsToAddOrOverride, false);
  assert.equal("amr" in access.claimsToAddOrOverride, false);
  assert.equal(
    transformed.response.claimsAndScopeOverrideDetails.idTokenGeneration.claimsToAddOrOverride.existing,
    "preserved",
  );
});

test("retains the same bounded evidence on refresh for backend auth_time freshness checks", async () => {
  const transformed = await handler(event("TokenGeneration_RefreshTokens"));
  assert.equal(
    transformed.response.claimsAndScopeOverrideDetails.accessTokenGeneration
      .claimsToAddOrOverride["https://ideatostrategy.com/claims/mfa"],
    "cognito:mfa-required",
  );
});

test("supports the admin invitation password-change completion under pool-wide MFA", async () => {
  const transformed = await handler(event("TokenGeneration_NewPasswordChallenge"));
  assert.equal(
    transformed.response.claimsAndScopeOverrideDetails.accessTokenGeneration
      .claimsToAddOrOverride["https://ideatostrategy.com/claims/mfa"],
    "cognito:mfa-required",
  );
});

for (const [name, mutate, code] of [
  ["wrong event version", (value) => { value.version = "1"; }, "OPERATOR_TOKEN_EVENT_VERSION_INVALID"],
  ["unsupported source", (value) => { value.triggerSource = "TokenGeneration_ClientCredentials"; }, "OPERATOR_TOKEN_TRIGGER_SOURCE_INVALID"],
  ["missing client", (value) => { delete value.callerContext.clientId; }, "OPERATOR_TOKEN_CLIENT_INVALID"],
]) {
  test(`fails closed for ${name}`, async () => {
    const value = event();
    mutate(value);
    await assert.rejects(() => handler(value), { message: code });
  });
}
