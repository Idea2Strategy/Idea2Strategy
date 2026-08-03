CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE operations.rbac_catalog_versions (
    catalog_version varchar(80) PRIMARY KEY,
    content_hash varchar(128) NOT NULL UNIQUE,
    status varchar(30) NOT NULL,
    activated_at timestamptz,
    retired_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT rbac_catalog_status_valid CHECK (status IN ('DRAFT', 'ACTIVE', 'RETIRED')),
    CONSTRAINT rbac_catalog_lifecycle_valid CHECK (
        (status = 'DRAFT' AND activated_at IS NULL AND retired_at IS NULL) OR
        (status = 'ACTIVE' AND activated_at IS NOT NULL AND retired_at IS NULL) OR
        (status = 'RETIRED' AND activated_at IS NOT NULL AND retired_at IS NOT NULL
            AND retired_at >= activated_at)),
    CONSTRAINT rbac_catalog_content_hash_valid CHECK (content_hash ~ '^[0-9a-f]{64}$')
);

CREATE UNIQUE INDEX rbac_catalog_one_active
    ON operations.rbac_catalog_versions ((status)) WHERE status = 'ACTIVE';

CREATE TABLE operations.rbac_catalog_roles (
    catalog_version varchar(80) NOT NULL,
    role_id uuid NOT NULL,
    hierarchy_rank integer NOT NULL,
    role_status varchar(30) NOT NULL,
    PRIMARY KEY (catalog_version, role_id),
    CONSTRAINT rbac_catalog_role_version_fk FOREIGN KEY (catalog_version)
        REFERENCES operations.rbac_catalog_versions(catalog_version),
    CONSTRAINT rbac_catalog_role_id_fk FOREIGN KEY (role_id) REFERENCES operations.roles(id),
    CONSTRAINT rbac_catalog_role_rank_nonnegative CHECK (hierarchy_rank >= 0),
    CONSTRAINT rbac_catalog_role_status_valid CHECK (role_status IN ('ACTIVE', 'INACTIVE'))
);

CREATE TABLE operations.rbac_catalog_permissions (
    catalog_version varchar(80) NOT NULL,
    permission_id uuid NOT NULL,
    permission_status varchar(30) NOT NULL,
    PRIMARY KEY (catalog_version, permission_id),
    CONSTRAINT rbac_catalog_permission_version_fk FOREIGN KEY (catalog_version)
        REFERENCES operations.rbac_catalog_versions(catalog_version),
    CONSTRAINT rbac_catalog_permission_id_fk FOREIGN KEY (permission_id) REFERENCES operations.permissions(id),
    CONSTRAINT rbac_catalog_permission_status_valid CHECK (permission_status IN ('ACTIVE', 'INACTIVE'))
);

CREATE TABLE operations.rbac_catalog_role_permissions (
    catalog_version varchar(80) NOT NULL,
    role_id uuid NOT NULL,
    permission_id uuid NOT NULL,
    delegable boolean NOT NULL DEFAULT false,
    PRIMARY KEY (catalog_version, role_id, permission_id),
    CONSTRAINT rbac_catalog_role_permission_role_fk FOREIGN KEY (catalog_version, role_id)
        REFERENCES operations.rbac_catalog_roles(catalog_version, role_id),
    CONSTRAINT rbac_catalog_role_permission_permission_fk FOREIGN KEY (catalog_version, permission_id)
        REFERENCES operations.rbac_catalog_permissions(catalog_version, permission_id)
);

ALTER TABLE operations.operator_role_assignments
    ADD COLUMN catalog_version varchar(80),
    ADD CONSTRAINT operator_assignment_catalog_role_fk FOREIGN KEY (catalog_version, role_id)
        REFERENCES operations.rbac_catalog_roles(catalog_version, role_id) DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE operations.audit_events
    ADD COLUMN rbac_catalog_version varchar(80),
    ADD COLUMN resolved_rbac_catalog_version varchar(80),
    ADD COLUMN request_hash varchar(128),
    ADD COLUMN decision_status varchar(30),
    ADD COLUMN response_status integer,
    ADD COLUMN response_code varchar(80),
    ADD COLUMN evidence_hash varchar(128),
    ADD COLUMN request_document jsonb,
    ADD COLUMN response_document jsonb,
    ADD COLUMN before_document jsonb,
    ADD COLUMN after_document jsonb,
    ADD COLUMN evidence_document jsonb,
    ADD CONSTRAINT audit_rbac_catalog_fk FOREIGN KEY (resolved_rbac_catalog_version)
        REFERENCES operations.rbac_catalog_versions(catalog_version),
    ADD CONSTRAINT audit_operator_rbac_evidence_complete CHECK (
        target_domain <> 'OPERATOR_RBAC' OR (
            rbac_catalog_version IS NOT NULL AND request_hash ~ '^[0-9a-f]{64}$'
            AND decision_status IN ('SUCCEEDED', 'REJECTED')
            AND response_status BETWEEN 200 AND 499 AND response_code IS NOT NULL
            AND before_hash ~ '^[0-9a-f]{64}$' AND after_hash ~ '^[0-9a-f]{64}$'
            AND evidence_hash ~ '^[0-9a-f]{64}$'
            AND jsonb_typeof(request_document) = 'object'
            AND jsonb_typeof(response_document) = 'object'
            AND jsonb_typeof(before_document) = 'object'
            AND jsonb_typeof(after_document) = 'object'
            AND jsonb_typeof(evidence_document) = 'object'
            AND request_hash = encode(digest(request_document::text, 'sha256'), 'hex')
            AND before_hash = encode(digest(before_document::text, 'sha256'), 'hex')
            AND after_hash = encode(digest(after_document::text, 'sha256'), 'hex')
            AND evidence_hash = encode(digest(evidence_document::text, 'sha256'), 'hex')
            AND ((decision_status = 'SUCCEEDED' AND response_status BETWEEN 200 AND 299
                    AND resolved_rbac_catalog_version = rbac_catalog_version)
                OR (decision_status = 'REJECTED' AND response_status BETWEEN 400 AND 499
                    AND before_hash = after_hash
                    AND (resolved_rbac_catalog_version IS NULL
                        OR resolved_rbac_catalog_version = rbac_catalog_version)))));

CREATE FUNCTION operations.guard_rbac_catalog_immutable() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN RAISE EXCEPTION 'RBAC catalog rows are append-only'; END IF;
    IF OLD.status = 'RETIRED' OR
       (OLD.status = 'ACTIVE' AND NOT (NEW.status = 'RETIRED'
            AND NEW.catalog_version = OLD.catalog_version
            AND NEW.content_hash = OLD.content_hash
            AND NEW.activated_at = OLD.activated_at
            AND NEW.created_at = OLD.created_at)) THEN
        RAISE EXCEPTION 'active or retired RBAC catalog is immutable';
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER guard_rbac_catalog_version_update
BEFORE UPDATE OR DELETE ON operations.rbac_catalog_versions
FOR EACH ROW EXECUTE FUNCTION operations.guard_rbac_catalog_immutable();

CREATE FUNCTION operations.guard_rbac_catalog_snapshot() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE snapshot_status varchar(30);
DECLARE snapshot_version varchar(80);
BEGIN
    snapshot_version := CASE WHEN TG_OP = 'DELETE' THEN OLD.catalog_version ELSE NEW.catalog_version END;
    SELECT status INTO snapshot_status FROM operations.rbac_catalog_versions
    WHERE catalog_version = snapshot_version;
    IF snapshot_status IN ('ACTIVE', 'RETIRED') THEN
        RAISE EXCEPTION 'active or retired RBAC catalog snapshot is immutable';
    END IF;
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END $$;

CREATE TRIGGER guard_rbac_catalog_roles_snapshot BEFORE INSERT OR UPDATE OR DELETE
ON operations.rbac_catalog_roles FOR EACH ROW EXECUTE FUNCTION operations.guard_rbac_catalog_snapshot();
CREATE TRIGGER guard_rbac_catalog_permissions_snapshot BEFORE INSERT OR UPDATE OR DELETE
ON operations.rbac_catalog_permissions FOR EACH ROW EXECUTE FUNCTION operations.guard_rbac_catalog_snapshot();
CREATE TRIGGER guard_rbac_catalog_mappings_snapshot BEFORE INSERT OR UPDATE OR DELETE
ON operations.rbac_catalog_role_permissions FOR EACH ROW EXECUTE FUNCTION operations.guard_rbac_catalog_snapshot();

CREATE FUNCTION operations.require_active_assignment_catalog() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.catalog_version IS NULL OR NOT EXISTS (
        SELECT 1 FROM operations.rbac_catalog_versions
        WHERE catalog_version = NEW.catalog_version AND status = 'ACTIVE') THEN
        RAISE EXCEPTION 'new operator assignment requires the active RBAC catalog';
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER require_active_assignment_catalog_before_insert
BEFORE INSERT ON operations.operator_role_assignments
FOR EACH ROW EXECUTE FUNCTION operations.require_active_assignment_catalog();

CREATE FUNCTION operations.guard_operator_rbac_audit_immutable() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.target_domain = 'OPERATOR_RBAC' THEN
        RAISE EXCEPTION 'operator RBAC audit evidence is immutable';
    END IF;
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END $$;

CREATE TRIGGER guard_operator_rbac_audit_before_change
BEFORE UPDATE OR DELETE ON operations.audit_events
FOR EACH ROW EXECUTE FUNCTION operations.guard_operator_rbac_audit_immutable();

COMMENT ON TABLE operations.rbac_catalog_versions IS
    'A13 additive version metadata only. Actual role, permission, hierarchy and delegability values are external reviewed seed/config and are not seeded here.';
