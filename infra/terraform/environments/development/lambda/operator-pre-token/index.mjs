const ASSURANCE_CLAIM = "https://ideatostrategy.com/claims/mfa";
const ALLOWED_TRIGGER_SOURCES = new Set([
  "TokenGeneration_HostedAuth",
  "TokenGeneration_Authentication",
  "TokenGeneration_NewPasswordChallenge",
  "TokenGeneration_RefreshTokens",
]);

export const handler = async (event) => {
  if (event.version !== "2_0" && event.version !== "2") {
    throw new Error("OPERATOR_TOKEN_EVENT_VERSION_INVALID");
  }
  if (!ALLOWED_TRIGGER_SOURCES.has(event.triggerSource)) {
    throw new Error("OPERATOR_TOKEN_TRIGGER_SOURCE_INVALID");
  }
  const clientId = event.callerContext?.clientId;
  if (typeof clientId !== "string" || clientId.length === 0) {
    throw new Error("OPERATOR_TOKEN_CLIENT_INVALID");
  }

  event.response = event.response ?? {};
  event.response.claimsAndScopeOverrideDetails = {
    ...(event.response.claimsAndScopeOverrideDetails ?? {}),
    accessTokenGeneration: {
      claimsToAddOrOverride: {
        aud: clientId,
        [ASSURANCE_CLAIM]: "cognito:mfa-required",
      },
    },
  };
  return event;
};
