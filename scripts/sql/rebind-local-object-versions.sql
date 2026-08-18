\set ON_ERROR_STOP on

CREATE TEMP TABLE local_object_versions (
    object_key text PRIMARY KEY,
    provider_version_id text NOT NULL
);
\copy local_object_versions (object_key, provider_version_id) FROM '/tmp/local-object-versions.tsv' WITH (FORMAT text)

UPDATE storage.objects target
SET storage_provider = 'S3',
    bucket_name = :'local_bucket',
    provider_version_id = source.provider_version_id
FROM local_object_versions source
WHERE source.object_key = target.object_key;

-- Division by zero deliberately fails the restore if even one catalog object cannot
-- be addressed through the immutable local S3 contract used by the Backtest worker.
SELECT 1 / CASE WHEN count(*) = 0 THEN 1 ELSE 0 END AS all_objects_versioned
FROM storage.objects
WHERE storage_provider <> 'S3'
   OR bucket_name <> :'local_bucket'
   OR provider_version_id IS NULL
   OR provider_version_id = '';
