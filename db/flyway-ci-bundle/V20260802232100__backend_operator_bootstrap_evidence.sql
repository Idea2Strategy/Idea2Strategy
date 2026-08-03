DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM operations.operator_bootstrap_receipts) THEN
        RAISE EXCEPTION 'existing bootstrap receipts require reviewed forward-fix';
    END IF;
END $$;

CREATE FUNCTION operations.guard_operator_bootstrap_audit_immutable()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.target_domain = 'OPERATOR_BOOTSTRAP' THEN
        RAISE EXCEPTION 'operator bootstrap audit evidence is immutable';
    END IF;
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END $$;

CREATE TRIGGER guard_operator_bootstrap_audit_before_change
BEFORE UPDATE OR DELETE ON operations.audit_events
FOR EACH ROW EXECUTE FUNCTION operations.guard_operator_bootstrap_audit_immutable();

CREATE FUNCTION operations.require_complete_operator_bootstrap_evidence()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM operations.operator_accounts account
        JOIN operations.operator_role_assignments assignment
          ON assignment.id = NEW.operator_role_assignment_id
         AND assignment.operator_account_id = account.id
        JOIN operations.rbac_catalog_versions catalog
          ON catalog.catalog_version = assignment.catalog_version
        JOIN operations.audit_events audit
          ON audit.id = NEW.audit_event_id
        WHERE account.id = NEW.operator_account_id
          AND account.external_identity_key_version = NEW.external_identity_key_version
          AND account.created_at = NEW.applied_at
          AND account.mfa_enrolled_at = NEW.applied_at
          AND assignment.catalog_version = NEW.catalog_version
          AND assignment.granted_by_operator_id = NEW.operator_account_id
          AND assignment.granted_at = NEW.applied_at
          AND catalog.status = 'ACTIVE'
          AND catalog.activated_at = NEW.applied_at
          AND audit.action_type = 'OPERATOR_BOOTSTRAP'
          AND audit.actor_type = 'DEPLOYMENT'
          AND audit.reason_code = 'BOOTSTRAP_DEPLOYMENT'
          AND audit.target_domain = 'OPERATOR_BOOTSTRAP'
          AND audit.target_id = NEW.operator_account_id
          AND audit.correlation_id = NEW.correlation_id
          AND audit.occurred_at = NEW.applied_at
          AND audit.idempotency_key = 'operator-bootstrap:' || NEW.bootstrap_key
          AND audit.decision_status = 'SUCCEEDED'
          AND audit.response_status = 200
          AND audit.response_code = 'OPERATOR_BOOTSTRAP_APPLIED'
          AND audit.request_document ->> 'bootstrapKey' = NEW.bootstrap_key
          AND audit.request_document ->> 'manifestHash' = NEW.manifest_hash
          AND audit.request_document ->> 'catalogVersion' = NEW.catalog_version
          AND audit.request_document ->> 'catalogContentHash' = catalog.content_hash
          AND audit.evidence_document ->> 'databaseRole' = audit.request_document ->> 'expectedDatabaseRole'
          AND audit.evidence_document ->> 'grantProvenance' = audit.request_document ->> 'grantProvenance'
          AND audit.response_document ->> 'operatorAccountId' = NEW.operator_account_id::text
          AND audit.response_document ->> 'operatorRoleAssignmentId' = NEW.operator_role_assignment_id::text
          AND audit.response_document ->> 'catalogVersion' = NEW.catalog_version
          AND (audit.response_document ->> 'externalIdentityKeyVersion')::smallint = NEW.external_identity_key_version
          AND audit.response_document ->> 'status' = 'ACTIVE'
          AND audit.evidence_document ->> 'deploymentActorId' = audit.actor_id::text
          AND audit.evidence_document ->> 'technicalGrantorOperatorId' = NEW.operator_account_id::text
          AND audit.evidence_document ->> 'grantMode' = 'BOOTSTRAP_DEPLOYMENT'
          AND length(audit.evidence_document ->> 'databaseRole') > 0
          AND length(audit.evidence_document ->> 'grantProvenance') > 0
          AND audit.request_hash = encode(digest(audit.request_document::text, 'sha256'), 'hex')
          AND audit.before_hash = encode(digest(audit.before_document::text, 'sha256'), 'hex')
          AND audit.after_hash = encode(digest(audit.after_document::text, 'sha256'), 'hex')
          AND audit.evidence_hash = encode(digest(audit.evidence_document::text, 'sha256'), 'hex')
    ) THEN
        RAISE EXCEPTION 'operator bootstrap receipt requires complete deployment evidence';
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER require_complete_operator_bootstrap_evidence_before_insert
BEFORE INSERT ON operations.operator_bootstrap_receipts
FOR EACH ROW EXECUTE FUNCTION operations.require_complete_operator_bootstrap_evidence();

COMMENT ON FUNCTION operations.require_complete_operator_bootstrap_evidence() IS
    'Binds the immutable receipt to its catalog, self-granted technical assignment, deployment actor, dedicated database role, correlation, and DB-time audit evidence.';
