# Local Flyway placeholder

루트의 인프라 전용 실행이 앱 소스 없이도 가능하도록 유지하는 빈 fallback 경로다.

실제 `apps` 프로필은 `.env.docker`의 `BACKEND_MIGRATION_DIR`가 가리키는
Backend 멀티 모듈의 `db-migration/src/main/resources/db/migration`을 사용해야 한다.
