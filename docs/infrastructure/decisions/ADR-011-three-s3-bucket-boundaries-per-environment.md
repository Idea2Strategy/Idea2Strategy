# ADR-011: 환경별 S3 버킷 3개 경계

- 상태: Superseded
- 작성일: 2026-07-29
- 통합일: 2026-07-29
- 결정자: 인프라 담당자
- 관련 질문: INFRA-Q-007, INFRA-Q-011, INFRA-Q-017, INFRA-Q-021, INFRA-Q-022
- Superseded by: [ADR-010](ADR-010-same-account-isolated-environments.md)

## 통합 사유

환경별 S3 버킷 경계는 Development와 Production의 리소스·권한·데이터 격리 방식에서 분리할 수 없는 하위 결정이다. 두 결정을 별도로 관리하면 환경 경계와 저장소 경계가 서로 다르게 변경될 위험이 있으므로 활성 결정은 ADR-010 하나로 통합한다.

환경마다 `시장 데이터`, `백테스트·성과 결과`, `Terraform State`의 세 S3 버킷을 두는 기존 내용은 변경하지 않았다. 이 문서는 결정 이력을 보존하기 위한 참조이며 앞으로의 변경과 후속 작업은 [ADR-010](ADR-010-same-account-isolated-environments.md)에서 관리한다.
