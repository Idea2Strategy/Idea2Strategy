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

## 인수인계 문서

위 5단계 중 ①②(Cognito 운영자 생성, 일회성 `operator bootstrap`)는 자격증명을 다루므로
사람이 수행한다. 그 두 단계만 떼어 그대로 따라할 수 있게 쓴 것이
`docs/operator-auth-enablement-handoff.md` 다. 이 파일은 왜 막혔는지를, 그 파일은 무엇을
하는지를 담는다.

---

# 2026-08-08 후속 — 인증은 켜졌고, 이제 막는 것은 TOTP 등록이다

## 켜진 것

릴리스 [31259186323](https://github.com/Idea2Strategy/Idea2Strategy/actions/runs/31259186323)
적용으로 운영자 인증이 배포되었다. core 인스턴스가 `i-03bb3f4a492227874` 로 교체되었고
(13:36:50Z 기동), 컨테이너에서 확인한 값이다.

```
OPERATOR_AUTH_ENABLED=true
OPERATOR_RBAC_READ_ENABLED=true
OPERATOR_RBAC_CATALOG_VERSION=development-operator-rbac-v1
OPERATOR_AUTH_MFA_CLAIM_NAME=https://ideatostrategy.com/claims/mfa
OPERATOR_AUTH_ALLOWED_MFA_CLAIM_VALUES=cognito:mfa-required
IDEA2STRATEGY_OPERATOR_*_PERMISSION_ID 15개
```

`/api/v1/operations/cases` 가 404 에서 400 으로 바뀌었다 — 컨트롤러가 등록되었다는 뜻이다.

부트스트랩도 끝났다. `operator bootstrap` 이 `{"ok":true,"replayed":false}` 로 RBAC 카탈로그
(권한 19개·역할 2개)와 최초 운영자 계정을 심었고, 심은 `catalogVersion` 과 배포된
`OPERATOR_RBAC_CATALOG_VERSION` 이 같다.

## 그런데 로그인을 완료할 수 없다

Cognito 사용자는 존재하고 비밀번호도 설정되었다(`UserStatus: CONFIRMED`). 그러나 **TOTP 기기가
등록되어 있지 않다.**

```
UserMFASettingList : (비어 있음)
PreferredMfaSetting: (없음)
UserLastModifiedDate: 2026-08-08T21:51:40+09:00   ← 이후 변동 없음
```

로그인하면 managed login 이 **"To complete sign-in, enter the code from your authenticator app"**
를 보여준다. 등록 화면(QR)이 아니라 **인증 화면**이다. 사용자는 QR 을 한 번도 본 적이 없다고
확인했다. 없는 기기의 코드를 요구하므로 어떤 값도 통하지 않는다.

## 배제한 것들

추측을 줄이려고 하나씩 확인했다.

**MFA 선호가 잘못 남아 있는 것이 아니다.** `admin-set-user-mfa-preference` 로
`software-token-mfa-settings Enabled=false` 를 적용했다(종료코드 0). 그런데 `UserMFASettingList`
와 `UserLastModifiedDate` 가 **변하지 않았다** — 되돌릴 상태가 애초에 없었다는 뜻이다.

**classic hosted UI 의 TOTP 미지원이 아니다.** 처음에 그렇게 의심했으나
`describe-user-pool-domain` 이 `ManagedLoginVersion: 2` 를 돌려준다. managed login 은 TOTP 등록을
지원한다. 이 가설은 틀렸다.

**프론트가 등록을 가로채는 것이 아니다.** `ui/src` 에 `MFA_SETUP`·`associateSoftwareToken`·
`verifySoftwareToken`·`SOFTWARE_TOKEN_MFA` 가 하나도 없다. 프론트는 OAuth code flow 로 위임만
한다. 따라서 등록 단계는 Cognito 쪽 책임이다.

**pre-token lambda 가 던져서 흐름이 끊긴 것이 아니다.** `/aws/lambda/idea2strategy-dev-operator-pre-token`
에 최근 3시간 119개 이벤트가 있고 **오류가 하나도 없다**(전부 START/END/REPORT).

**CloudTrail 은 답을 주지 못한다.** `AssociateSoftwareToken`·`VerifySoftwareToken`·`InitiateAuth`
조회가 모두 0건인데, Cognito 의 사용자 인증 API 는 CloudTrail 에 기록되지 않는다. 0건은
"일어나지 않았다" 가 아니라 **"알 수 없다"** 다.

## lambda 가 성공한다는 사실이 별개 문제에 증거를 더한다

pre-token lambda 가 오류 없이 119회 돌았다는 것은 **토큰이 실제로 발급되고 있다**는 뜻이다.
그 lambda 의 허용 trigger 목록에 `TokenGeneration_NewPasswordChallenge` 가 있고, 그 지점은
**MFA 보다 앞선 토큰 발급 지점**이다. 그리고 lambda 는 trigger source 를 보지 않고
`cognito:mfa-required` 를 무조건 붙인다(`index.mjs:27`).

즉 21:51 의 비밀번호 강제 변경 시점에 발급된 토큰이 **MFA 를 수행하지 않은 채 MFA 보증
클레임을 달고 나왔을 가능성**이 있다. lambda 가 event 를 로깅하지 않아 어느 trigger source
였는지는 단정할 수 없다 — 그래서 "가능성" 이라고 쓴다. 확인 방법은 lambda 에
`triggerSource` 로깅을 한 줄 추가하는 것이고, 그것 자체가 INT08 이 요구하는 감사 가시성이다.

**이것은 INT08(보안·개인정보 검토) 항목이다.** MFA 보증이 실제 MFA 수행과 분리되어 있다면,
`operator_auth_allowed_mfa_claim_values` 로 세운 방어가 이름만 남는다.

## 남은 선택지

| 방법 | 비용 | 비고 |
| --- | --- | --- |
| 시크릿 창에서 재시도 | 없음 | 이전 세션이 챌린지 상태를 붙들고 있을 가능성. 먼저 시도 중 |
| 프론트에 등록 단계 구현 | `ui` 변경 | `AssociateSoftwareToken`/`VerifySoftwareToken`. `hjcud` 소유 |
| API 로 직접 등록 | **불가(에이전트)** | 세션이 필요하고 세션은 SRP = 비밀번호를 요구한다 |
| 사용자 삭제·재생성 | **높음** | `sub` 가 바뀌면 `HMAC(issuer+sub)` 가 어긋나 **부트스트랩을 다시 해야 한다** |

마지막 항목이 이 문서에서 가장 중요한 경고다. 운영자 계정 레코드가 `sub` 에 묶여 있으므로
Cognito 사용자를 지우고 다시 만드는 것은 부트스트랩 재실행을 포함한다. 다른 방법이 모두
막힌 뒤에만 고른다.

---

# 2026-08-08 확정 — MFA 보증 클레임이 실제 MFA 없이 발급된다

앞 절에서 "가능성" 으로 적은 것이 **실측으로 확인되었다.** 추측이 아니다.

## 관찰

풀 MFA 를 `OPTIONAL` 로 내린 상태에서 `USER_PASSWORD_AUTH` 로 로그인했다. **MFA 챌린지가 없었고
MFA 를 수행하지 않았다.** 그런데 돌아온 액세스 토큰의 클레임에 이것이 들어 있다.

```
"https://ideatostrategy.com/claims/mfa": "cognito:mfa-required"
"scope": "aws.cognito.signin.user.admin"
"auth_time": 1786198649
```

같은 토큰의 `ChallengeParameters` 는 비어 있고 `AuthenticationResult` 가 바로 반환되었다 — 즉
어떤 챌린지도 거치지 않았다.

## 왜 이렇게 되는가

`infra/terraform/environments/development/lambda/operator-pre-token/index.mjs` 가 허용된 trigger
source 이면 **조건 없이** 클레임을 붙인다.

```javascript
claimsToAddOrOverride: {
  aud: clientId,
  [ASSURANCE_CLAIM]: "cognito:mfa-required",
}
```

`event` 어디에도 "이 인증이 MFA 를 거쳤는가" 를 보지 않는다. 허용 목록에
`TokenGeneration_Authentication` 이 있으므로, MFA 없는 비밀번호 인증도 그 경로를 탄다.

## 결과 — 방어가 이름만 남는다

backend 는 `OPERATOR_AUTH_ALLOWED_MFA_CLAIM_VALUES=cognito:mfa-required` 로 MFA 보증을 요구한다.
그런데 그 클레임이 **MFA 수행과 무관하게 항상 붙으므로**, 이 검사는 어떤 토큰도 걸러내지 못한다.
`operator_auth_maximum_mfa_age`(기본 PT10M)도 같은 이유로 의미를 잃는다 — 없었던 MFA 의 나이를
재는 것이다.

풀을 `ON` 으로 되돌리면 Cognito 가 MFA 를 강제하므로 실질 위험은 줄지만, **backend 쪽 검사가
그것을 확인하는 것은 아니다.** Cognito 설정이 유일한 방어선이 되고, 설정 하나가 바뀌면(예: A92
같은 드리프트) 애플리케이션은 아무것도 눈치채지 못한다.

## 고치는 방향

lambda 가 실제 MFA 여부를 보고 클레임을 붙여야 한다. Cognito 의 pre-token-generation 이벤트에는
그 정보가 직접 오지 않으므로 두 가지 중 하나다.

1. **`amr` 를 쓴다.** Cognito 가 발급하는 토큰의 `amr` 에는 MFA 를 수행한 경우
   `mfa`·`swk`·`software_token_mfa` 등이 들어간다. lambda 가 클레임을 만들지 말고, backend 가
   `operator_auth_allowed_amr_values` 로 **Cognito 가 스스로 채운 `amr`** 를 검사하게 한다.
   이 저장소에는 그 변수가 이미 있다(`variables.tf:479`, 현재 기본값 `[]`).
2. **lambda 가 판별한다.** `event.request` 의 정보로 MFA 여부를 확인할 수 있는 경우에만 클레임을
   붙이고, 아니면 붙이지 않는다. 그리고 `triggerSource` 를 로깅해 감사 가능하게 한다.

**1번이 낫다.** 클레임을 우리가 만들지 않고 IdP 가 채운 값을 쓰면, 애플리케이션의 검사가 실제
인증 사실에 묶인다. 지금 구조는 우리가 만든 클레임을 우리가 검사하는 자기 참조다.

## 어느 카드에 속하나

**INT08(보안·개인정보·법적 표현 검토).** 그 문서의 "권한 우회" 축에 해당하며, A90 이 아니다 —
A90 은 "같은 인증 주체·RBAC 를 쓰는가" 이고 이것은 "그 인증이 주장하는 보증이 참인가" 다.

A92(풀 MFA 복구)를 닫을 때 함께 확인해야 한다. 풀을 `ON` 으로 되돌리는 것만으로는 이 결함이
해소되지 않는다 — 그것은 Cognito 가 MFA 를 강제하게 하는 것이고, backend 의 검사가 유효해지는
것은 아니다.
