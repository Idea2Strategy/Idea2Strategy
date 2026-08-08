# INT05 — 운영자 E2E 가 지금 막혀 있는 정확한 지점

이 파일은 INT05 완료 증거가 **아니다**. 완료 증거는 `docs/evidence/INT05.md` 가 될 것이고,
이 파일은 그것을 쓸 수 없는 이유를 확정한 기록이다. 원장은 이 파일을 완료로 세지 않는다.

## 언제 · 어디서

- 2026-08-08. AWS Development(`418553863687`, `ap-northeast-2`).
- 루트 `9371714`. 근거는 릴리스 실행
  [31250145271](https://github.com/Idea2Strategy/Idea2Strategy/actions/runs/31250145271)
  (`c4b78e7`) 의 `prepare-and-plan` 로그와 트래킹되는 Terraform 소스다.

## 관찰한 사실

`vars.TF_VARS_JSON` 이 그대로 넘기는 값 두 개가 서로 어긋나 있다.

```
"enable_operator_auth": false,
"enable_cognito_operator_identity": true,
```

Cognito 운영자 식별은 켜져 있는데 운영자 인증은 꺼져 있다. `enable_operator_auth` 는
`development-release.yml` 의 어느 정규화도 건드리지 않는다 — 워크플로가 손대는 것은
`trading_market_data_feed`(:598), `trading_runtime_artifacts` 의 두 항목(:596-597),
`aws_profile`·`aws_region`(:613-614) 뿐이다. 따라서 저장소 변수의 `false` 가 그대로
`ec2-user-data.sh.tftpl:314` 의 `OPERATOR_AUTH_ENABLED` 와 `:330` 의
`OPERATOR_RBAC_READ_ENABLED` 로 내려간다. 배포된 운영자 경로는 꺼진 상태이므로 INT05 를
수행할 대상이 없다.

## 플래그만 켜서는 안 되는 이유

`infra/terraform/environments/development/runtime.tf:145-178` 의 precondition 이
`enable_operator_auth = true` 를 받는 순간 다음을 **전부** 요구한다.

- OIDC 신뢰: `operator_auth_issuer`, `operator_auth_jwk_set_uri`, `operator_auth_audience`;
- MFA 보증: `operator_auth_allowed_acr_values` ∪ `operator_auth_allowed_amr_values` 가
  비지 않거나, `operator_auth_mfa_claim_name` 과 허용 클레임 값이 함께 있어야 한다;
- `operator_rbac_catalog_version`;
- RBAC 권한 UUID 4개: catalog read, assignment read, grant, revoke;
- 운영자 케이스·제재 권한 UUID 13개(`runtime.tf:160-174`).

현재 TF_VARS_JSON 에는 그중 `operator_auth_issuer`, `operator_auth_audience`,
`operator_rbac_catalog_read_permission_id`, `operator_rbac_assignment_read_permission_id`
네 개만 있다. 나머지 15개 UUID 와 catalog version, MFA 보증 설정이 없다. 플래그만 켜면
plan 이 precondition 에서 멈춘다. 즉 이것은 "플래그 한 줄" 작업이 아니다.

## 값을 어디서 가져오는가

`proposals/development-operator-rbac-bootstrap/` 이 이미 그 값을 정해 두었다.
`catalog.json` 에 권한 19개, `runtime-guard-inputs.json` 에 권한별 Spring 프로퍼티·코드
가드 매핑이 있다. UUID 선택은 보수적이다 — 계정 제재 ID 는 backend 기본값, 케이스 ID 는
`OperatorCaseConfiguration` 의 fallback 순서(`a200...018`–`a200...028`), 경쟁 ID 는 승인된
migration 행(`e300...001`, `e300...002`) 을 그대로 쓰고, 신규 UUIDv4 를 받은 것은 identity
가 없던 RBAC 권한 4개와 개발용 역할 2개뿐이다.

그 제안은 스스로 "isolated proposal only; not approved, integrated, executable, or
releasable" 이라고 적고 있으며, 루트 `21437cb2` 에서 `stackcord governance check --json`
이 `unknown` 을 돌려준 상태로 남아 있다.

## 남은 작업이 자격증명을 요구한다

제안의 `bootstrap-manifest.template.json` 은 의도적으로 실행 불가능하다. 비어 있는 값이
운영자 신원 그 자체다.

- 일회성 명령이 기대하는 데이터베이스 세션 `current_user`;
- 운영자 issuer/subject HMAC 키 버전과 64-hex 다이제스트;
- 최초 운영자 계정과 역할 배정 ID;
- 배포 actor·correlation·audit-event ID.

제안은 issuer, subject, Cognito 토큰, HMAC 키, 다이제스트, 데이터베이스 비밀번호, 완성된
manifest 를 Git·Terraform state·CI 로그·이슈 댓글·PR 산출물에 두지 말라고 못 박고,
승인된 일회성 SSM 호스트 안에서 `VersionedOperatorSubjectHmac` 로 다이제스트를 유도한 뒤
`operator bootstrap --manifest <private-path> --expected-sha256 <hash>` 를 한 번 실행하라고
한다.

**그 단계는 사람이 해야 한다.** HMAC 키·데이터베이스 비밀번호·Cognito 운영자 자격증명을
다루는 일이고, 에이전트가 대신 넣을 수 있는 값이 아니다. 이 파일이 INT05 를 완료로
주장하지 않는 이유가 여기에 있다.

## 그래서 INT05 를 열려면

1. Cognito 사용자 풀 `ap-northeast-2_xxeN2Ej7A` 에 MFA 를 갖춘 운영자 계정을 만든다.
   (2026-08-06 확인 시점에 운영자 수는 0 이었다.)
2. `proposals/development-operator-rbac-bootstrap/` 를 권한 게이트를 통과시켜 채택하고,
   승인된 SSM 호스트에서 일회성 `operator bootstrap` 을 실행해 자격증명 없는 수령증만
   보관한다.
3. `vars.TF_VARS_JSON` 에 `operator_rbac_catalog_version`, 나머지 RBAC/케이스/제재 UUID
   15개, MFA 보증 설정을 넣고 `enable_operator_auth` 를 `true` 로 바꾼다.
4. 릴리스를 다시 올려 plan 이 `runtime.tf:145` precondition 을 통과하는지 확인한다.
5. 그 다음에 INT05 를 수행하고 `docs/evidence/INT05.md` 를 쓴다.

1번과 2번이 자격증명을 요구하므로 담당자(`kcrmin`)가 직접 수행한다.

## 결함이 아니었던 것 하나

같은 로그에서 `trading_runtime_artifacts["provider-rights"]` 가
`runtime/trading/alpaca-iex-rights.json` 을 가리키는데 `trading_market_data_feed` 는
`sip` 이었다. 불일치로 보였지만 결함이 아니다.
`development-release.yml:596-597` 이 그 두 항목을 방금 만든 부트스트랩 수령증으로 덮어쓰고,
`scripts/verify-development-database-bootstrap-receipt.ps1:188` 이 수령증의 provider-rights
`local_path` 가 정확히 `alpaca-sip-rights.json` 이기를 요구한다. TF_VARS_JSON 의 iex 값은
tfvars 에 쓰이기 전에 교체되는 죽은 값이다. 기록해 두는 이유는, 다음에 같은 로그를 읽는
사람이 같은 오판을 반복하지 않게 하기 위해서다.
