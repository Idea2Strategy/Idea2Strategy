# 운영자 인증 — 발급·준비 요청

운영자 E2E(INT05)를 하려면 배포된 환경에서 운영자 인증을 켜야 한다. 켜는 명령은 `kcrmin` 이
직접 실행한다. **이 문서는 그 전에 발급·준비되어야 하는 것만 적는다.**

대상: AWS Development 계정 `418553863687`, 리전 `ap-northeast-2`.

---

## 요청 1 — Cognito 운영자 계정 (MFA 등록)

| 항목 | 값 |
| --- | --- |
| 사용자 풀 ID | `ap-northeast-2_xxeN2Ej7A` |
| 앱 클라이언트 ID | `3ua45375gjr2f0cvsfh9jd11pq` |

현재 이 풀에 운영자 계정이 **0개**다.

- 계정 1개를 만들고 **MFA 를 등록**한다. MFA 는 선택이 아니다 — Terraform 이 MFA 보증
  클레임(`acr`/`amr` 또는 지정된 MFA 클레임)을 요구하고, 그것이 없는 토큰은 backend 가
  거부한다. MFA 없는 계정으로는 시험이 성립하지 않는다.
- 계정은 시험을 수행할 사람이 로그인할 것이므로, 초기 비밀번호를 발급하고 본인이 직접
  비밀번호와 MFA 를 설정하게 하는 방식이 낫다.

**알려줄 값: 그 사용자의 `sub` (UUID 형태).** 비밀이 아니다. 콘솔 사용자 상세에 보인다.

비밀번호와 MFA 시드는 알려주지 않는다.

---

## 요청 2 — IAM 권한 (MFA 세션 기준)

`kcrmin` 의 세션이 아래를 할 수 있어야 한다. `developer-access.tf` 가 대부분의 동작에
`aws:MultiFactorAuthPresent` 를 걸어두었으므로, MFA 를 넣은 세션에서 되는지로 확인한다.

| 동작 | 대상 |
| --- | --- |
| `secretsmanager:GetSecretValue` | `idea2strategy-dev/runtime/core-internal` |
| `secretsmanager:GetSecretValue` | `idea2strategy-dev/database/backend-runtime` |
| `ssm:GetParameter` | `/idea2strategy/dev/database/host`, `/port`, `/name` |
| `ssm:StartSession` | EC2 인스턴스 `idea2strategy-dev-core` |

두 시크릿은 각각 운영자 subject HMAC 키와 DB 접속 비밀번호를 담고 있다. 값을 대신 읽어
전달하지 말고 **읽을 권한만** 준다. 채팅이나 메일로 나온 키는 그 시점에 유출이고, 되돌리려면
키를 재생성하고 부트스트랩을 다시 해야 한다.

---

## 요청 3 — CLI 를 실행할 방법 (이게 지금 비어 있다)

부트스트랩은 HTTP 경로가 아니라 CLI 명령이다.

```
idea2strategy operator bootstrap --manifest <file> --expected-sha256 <hash>
```

**그런데 이 CLI 를 AWS 에서 실행할 경로가 아직 없다.** 릴리스가 만드는 이미지 9개
(`admin-mcp`, `backend-api`, `backend-batch`, `backend-worker`, `backtest-api`,
`backtest-worker`, `market-gateway`, `pipeline-worker`, `trading-worker`) 에 CLI 가 없고,
`scripts/` 와 워크플로에도 이것을 실행하는 경로가 없다. 확인한 사실이다.

그래서 **어떻게 실행할지 정하는 것 자체가 준비물**이다. 셋 중 하나면 된다.

1. 로컬에서 `./gradlew :apps:idea2strategy-cli:installDist` 로 배포본을 만들고,
   `idea2strategy-dev-core` 인스턴스에 올려 SSM 세션에서 실행한다. (가장 빠름)
2. 그 인스턴스에 JDK 21 을 두고 소스에서 빌드한다.
3. CLI 를 담은 이미지를 만들어 릴리스에 추가한다. (제일 깔끔하지만 릴리스 변경이 따름)

어느 쪽으로 갈지와, 1·2번이면 파일을 올릴 방법(S3 경유 등)을 알려주면 된다.

전제: 그 인스턴스는 이미 RDS 에 닿는다(backend 가 거기서 붙어 있다). 별도 네트워크 작업은
필요 없다.

---

## 요청하지 않는 것

- **키·비밀번호 값 자체.** 위 요청 2는 권한이고 값이 아니다.
- **권한 UUID 목록.** 카탈로그(권한 19개, 역할 2개)는 이미
  `proposals/development-operator-rbac-bootstrap/catalog.json` 에 정해져 있다.
- **Terraform 변수 수정.** `enable_operator_auth` 를 포함한 변수 작업은 `kcrmin` 이 한다.

---

## 준비되면 알려줄 세 줄

1. Cognito 계정 생성 완료 — MFA 등록 여부와 그 사용자의 `sub`
2. 요청 2의 네 가지 권한이 MFA 세션에서 확인되었는지
3. 요청 3에서 택한 방법(1·2·3 중 하나)과, 파일을 올릴 방법

이 세 줄에 비밀값이 하나도 없다. 받으면 `kcrmin` 이 이어서 실행한다.

실행 절차 상세는 `docs/operator-auth-enablement-handoff.md` 에 있다 — 그 문서는 이 요청을
받는 사람이 읽을 필요가 없다.
