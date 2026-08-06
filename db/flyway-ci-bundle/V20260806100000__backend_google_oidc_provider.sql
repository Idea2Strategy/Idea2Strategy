INSERT INTO identity.auth_providers (id, code, display_name, provider_type, issuer, is_active)
VALUES (2, 'GOOGLE', 'Google', 'OIDC', 'https://accounts.google.com', true)
ON CONFLICT (code) DO UPDATE
SET display_name = EXCLUDED.display_name,
    provider_type = EXCLUDED.provider_type,
    issuer = EXCLUDED.issuer,
    is_active = true,
    updated_at = now();
