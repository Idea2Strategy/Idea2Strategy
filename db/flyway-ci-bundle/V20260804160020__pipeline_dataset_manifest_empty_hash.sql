ALTER TABLE market_data.dataset_manifests
    ADD COLUMN object_count bigint NOT NULL DEFAULT 0,
    ADD CONSTRAINT dataset_manifest_object_count_nonnegative CHECK (object_count >= 0);

UPDATE market_data.dataset_manifests manifest
   SET object_count = (
       SELECT count(*) FROM market_data.dataset_objects object
        WHERE object.dataset_manifest_id = manifest.id
   );

DROP INDEX IF EXISTS market_data.uq_dataset_manifests_dataset_hash;
DROP INDEX IF EXISTS market_data.dataset_manifests_dataset_hash_idx;
CREATE UNIQUE INDEX uq_dataset_manifests_dataset_hash
    ON market_data.dataset_manifests(dataset_hash)
    WHERE object_count > 0;

CREATE OR REPLACE FUNCTION market_data.maintain_dataset_manifest_object_count()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        UPDATE market_data.dataset_manifests
           SET object_count = object_count - 1
         WHERE id = OLD.dataset_manifest_id;
        RETURN OLD;
    END IF;
    IF TG_OP = 'UPDATE' AND OLD.dataset_manifest_id <> NEW.dataset_manifest_id THEN
        UPDATE market_data.dataset_manifests
           SET object_count = object_count - 1
         WHERE id = OLD.dataset_manifest_id;
    END IF;
    IF TG_OP = 'INSERT' OR OLD.dataset_manifest_id <> NEW.dataset_manifest_id THEN
        UPDATE market_data.dataset_manifests
           SET object_count = object_count + 1
         WHERE id = NEW.dataset_manifest_id;
    END IF;
    RETURN NEW;
END
$$;

CREATE TRIGGER dataset_manifest_object_count_maintain
AFTER INSERT OR DELETE OR UPDATE OF dataset_manifest_id
ON market_data.dataset_objects
FOR EACH ROW EXECUTE FUNCTION market_data.maintain_dataset_manifest_object_count();

COMMENT ON COLUMN market_data.dataset_manifests.dataset_hash IS
    'Hash of the manifest content object set; zero-object manifests share the empty-set hash.';
COMMENT ON COLUMN market_data.dataset_manifests.object_count IS
    'Transactionally maintained object count used to exclude zero-object manifests from content uniqueness.';
