# Local Flyway placeholder

Backend 소스가 생기기 전까지 로컬 인프라만 실행할 수 있도록 유지하는 빈 경로다.

실제 `backend-apps` 프로필은 `.env.docker`의 `BACKEND_MIGRATION_DIR`가 가리키는
Backend 멀티 모듈의 `db-migration/src/main/resources/db/migration`을 사용해야 한다.
