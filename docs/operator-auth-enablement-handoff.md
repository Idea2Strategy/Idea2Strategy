# 운영자 인증 켜기 — 자격증명 담당자 인수인계

INT05(운영자 E2E)를 하려면 먼저 배포된 환경에서 운영자 인증이 켜져야 한다. 그 과정에
**사람만 할 수 있는 두 단계**가 있고, 이 문서는 그 두 단계만 다룬다. 나머지는 이 문서를 받은
사람이 "끝났다"고 알려주면 `kcrmin` 세션이 이어서 처리한다.

받는 사람에게 필요한 것: AWS Development 계정(`418553863687`, `ap-northeast-2`) 접근 권한과
MFA. 코드 지식은 필요 없다.

## 왜 사람이 해야 하는가

두 단계가 각각 다루는 값 때문이다. 하나는 Cognito 사용자 비밀번호와 MFA 등록이고, 다른
하나는 운영자 subject HMAC 키와 데이터베이스 비밀번호다. 에이전트는 이런 값을 읽거나 입력
하지 않는다. 나머지 단계(Terraform 변수 채우기, 릴리스 재실행, 시험 수행)에는 자격증명이
없으므로 에이전트가 한다.

## 지금 상태

`enable_operator_auth = false` 다. 그래서 배포된 EC2 에서
`OPERATOR_AUTH_ENABLED=false`, `OPERATOR_RBAC_READ_ENABLED=false` 이고, 운영자 로그인 경로가
아예 꺼져 있다. Cognito 사용자 풀은 이미 만들어져 있으나 **운영자 계정이 0개**다
(2026-08-06 확인).

`deployment_phase` 가 `full` 이므로 운영자 subject HMAC 키는 **이미 생성되어 있다**
(`random_password.operator_subject_hmac`, `infra/.../runtime.tf:36`). 새로 만들 필요 없이
읽어 쓰면 된다. 순서상 막힌 곳은 없다.

---

# 1단계 — Cognito 운영자 계정 만들기 (MFA 필수)

| 항목 | 값 |
| --- | --- |
| 사용자 풀 ID | `ap-northeast-2_xxeN2Ej7A` |
| 앱 클라이언트 ID | `3ua45375gjr2f0cvsfh9jd11pq` |
| 리전 | `ap-northeast-2` |

콘솔에서 하는 편이 빠르다. Cognito → 위 사용자 풀 → 사용자 → 사용자 생성.

MFA 는 반드시 등록한다. 선택이 아니다 — Terraform precondition 이 MFA 보증(`acr`/`amr`
클레임 또는 지정된 MFA 클레임)을 요구하고, 그것을 만족하지 못하는 토큰은 backend 가 거부한다.
MFA 없이 만든 계정으로는 시험이 안 된다.

만든 뒤 **다음 두 값**을 기록해 둔다. 2단계에서 필요하다.

- **issuer**: `https://cognito-idp.ap-northeast-2.amazonaws.com/ap-northeast-2_xxeN2Ej7A`
  (고정값이다. 위 표의 풀 ID 로 만들어진다.)
- **subject**: 만든 사용자의 `sub` 속성(UUID 형태). 콘솔의 사용자 상세에서 보인다.

비밀번호와 MFA 시드는 어디에도 적지 않는다. 본인만 알면 된다.

---

# 2단계 — 일회성 `operator bootstrap` 실행

RBAC 카탈로그(권한 19개, 역할 2개)와 최초 운영자 계정·역할배정을 데이터베이스에 한 번
심는 작업이다. HTTP 경로가 아니라 CLI 명령이고, 승인된 SSM 호스트 안에서만 실행한다.

## 절대 하지 말 것

issuer, subject, Cognito 토큰, HMAC 키, 계산한 다이제스트, 데이터베이스 비밀번호, 그리고
**완성된 manifest 파일**을 다음 어디에도 두지 않는다.

- Git 커밋 / PR 본문 / PR 첨부
- 이슈 댓글, 채팅
- CI 로그, Terraform state
- 공유 드라이브

**이 작업을 요청한 사람에게도 보내지 않는다.** `kcrmin` 도 포함이다. 아래
"끝나면 알려줄 것" 세 줄에 비밀값이 필요한 항목이 하나도 없다 — 이어지는 작업은
`proposals/.../catalog.json` 에 이미 있는 값과 Terraform 변수만 쓴다. 그러니 키를
전달해야 할 상황이 생기면 그건 절차를 잘못 읽은 것이므로 멈추고 물어보는 편이 맞다.

키가 한 번 채팅이나 메일에 나오면 그 시점에 유출이다. 되돌리는 방법은
`random_password.operator_subject_hmac` 을 재생성해 시크릿을 갱신하고 부트스트랩을 다시
하는 것뿐이므로, 애초에 내보내지 않는 것이 훨씬 싸다.

명령 자체는 manifest·자격증명·다이제스트·actor 를 출력하지 않도록 만들어져 있다
(`backend/apps/idea2strategy-cli/README.md`). 사람이 실수로 붙여넣는 것만 막으면 된다.

## 2-1. manifest 준비

템플릿: `proposals/development-operator-rbac-bootstrap/bootstrap-manifest.template.json`

이미 채워져 있는 것은 그대로 둔다 — 권한 19개, 역할 2개, `initialRoleId`,
`catalogVersion`(`development-operator-rbac-v1`), `catalogContentHash`,
`bootstrapKey`, `grantProvenance`. 손대면 검증에 걸린다.

채워야 할 칸은 **7개**다. 그중 5개는 그냥 새 UUID 를 만들어 넣으면 된다.

| 칸 | 무엇을 넣나 |
| --- | --- |
| `operatorAccountId` | 새 UUIDv4 |
| `operatorRoleAssignmentId` | 새 UUIDv4 |
| `deploymentActorId` | 새 UUIDv4 |
| `correlationId` | 새 UUIDv4 |
| `auditEventId` | 새 UUIDv4 |
| `expectedDatabaseRole` | 접속할 DB 롤 이름 (아래 2-2) |
| `externalIdentityKeyHmac` | 64자 소문자 hex 다이제스트 (아래 2-3) |

UUID 5개는 아무 도구로 만들어도 된다.

```bash
python -c "import uuid;[print(uuid.uuid4()) for _ in range(5)]"
```

## ⚠️ 2-1b. 키 버전을 반드시 고쳐라

템플릿에 `"externalIdentityKeyVersion": 0` 으로 적혀 있는데, **배포된 환경은 1을 쓴다**
(`infra/terraform/environments/development/templates/ec2-user-data.sh.tftpl:329` 에
`OPERATOR_AUTH_CURRENT_HMAC_KEY_VERSION=1`).

`0` 으로 두면 부트스트랩은 성공하지만 backend 가 버전 1로 조회하므로 운영자 로그인이 매칭에
실패한다. 오류 메시지가 원인을 알려주지 않는 종류의 실패다.

**`"externalIdentityKeyVersion": 1` 로 바꾼다.**

(참고: backend CLI 의 통합 시험도 `externalIdentityKeyVersion: 1` 을 쓴다. 템플릿의 `0` 이
잘못된 값이다. 이 불일치는 별도로 고칠 예정이다.)

## 2-2. `expectedDatabaseRole`

CLI 는 접속한 세션의 `current_user` 가 이 값과 정확히 같은지 확인하고, 다르면 거부한다
(`JdbcOperatorBootstrapAdapter:42`). 즉 "어느 롤로 접속할지"를 적는 칸이다.

운영자·RBAC 테이블은 backend 소유이므로 **`idea2strategy_backend_runtime`** 으로 접속하고
같은 이름을 적는다. 비밀번호는 Secrets Manager 의
`idea2strategy-dev/database/backend-runtime` 에 있다.

## 2-3. `externalIdentityKeyHmac` 계산

HMAC-SHA-256 이고, 키와 입력이 정해져 있다.

**키**: Secrets Manager 시크릿 `idea2strategy-dev/runtime/core-internal` 의
`OPERATOR_AUTH_CURRENT_HMAC_KEY` 필드. base64 문자열이고, **키 바이트는 그것을 base64
디코딩한 값**이다 — 문자열 자체가 아니다.

Terraform 이 `base64encode(...)` 로 넣고(`runtime.tf:72`) backend 가
`Base64.getDecoder().decode(...)` 로 되돌린다(`OperatorTrustConfiguration:77`). 디코딩을
빼먹으면 다이제스트가 조용히 다른 값이 나오고, 부트스트랩은 성공하는데 로그인만 안 되는
형태로 실패한다.

**입력**: `VersionedOperatorSubjectHmac.canonical(issuer, subject)` 과 같아야 한다 —
4바이트 big-endian issuer 길이 + issuer UTF-8 + 4바이트 big-endian subject 길이 +
subject UTF-8.

SSM 호스트에서:

```bash
python3 - <<'PY'
import base64, hashlib, hmac, struct, os
key     = base64.b64decode(os.environ['I2S_HMAC_KEY'])  # base64 디코딩한 바이트가 키다
issuer  = os.environ['I2S_ISSUER'].encode('utf-8')
subject = os.environ['I2S_SUBJECT'].encode('utf-8')
canonical = struct.pack('>I', len(issuer)) + issuer + struct.pack('>I', len(subject)) + subject
print(hmac.new(key, canonical, hashlib.sha256).hexdigest())
PY
```

환경변수는 그 셸에만 넣고, 끝나면 히스토리를 지운다. 출력된 64자 hex 를
`externalIdentityKeyHmac` 에 넣는다.

**이 스크립트는 backend 와 같은 값을 내는지 확인했다.** backend 시험 픽스처의 키(32바이트
`0x02` 반복)와 `("https://operator.example", "subject-1")` 로 양쪽을 돌려 비교했다.

```
python: 05ae856e8771d4134579cd9efb19870687a91ffd35f0e9fe7831f28e907be5af
java:   05ae856e8771d4134579cd9efb19870687a91ffd35f0e9fe7831f28e907be5af
```

Java 쪽은 `VersionedOperatorSubjectHmac.canonical`/`digest` 와 같은 코드
(`ByteBuffer.putInt` → big-endian, `HmacSHA256`, `HexFormat.of()` → 소문자)를 jshell 로
그대로 실행한 것이다. 실제 키만 위 방식으로 넣으면 된다.

## 2-4. 카탈로그 해시 확인

manifest 의 `catalogContentHash` 가
`proposals/development-operator-rbac-bootstrap/CHECKSUMS.sha256` 의 `catalog.json` 항목과
같은지 확인한다. 다르면 멈추고 알려준다 — 카탈로그가 바뀌었다는 뜻이므로 그대로 심으면 안 된다.

## 2-5. 완성된 manifest 의 SHA-256

명령이 이 값을 별도로 받아 파일과 대조한다. 파일 내용을 출력하지 말고 해시만 구한다.

```bash
sha256sum <완성된-manifest-경로>
```

## 2-6. 실행

CLI 빌드(한 번):

```bash
./gradlew :apps:idea2strategy-cli:installDist
```

실행:

```bash
export I2S_BOOTSTRAP_JDBC_URL='jdbc:postgresql://<rds-endpoint>:5432/idea2strategy_runtime'
export I2S_BOOTSTRAP_DB_USER='idea2strategy_backend_runtime'
export I2S_BOOTSTRAP_DB_PASSWORD='<시크릿에서 읽은 값>'
idea2strategy operator bootstrap \
  --manifest <완성된-manifest-경로> \
  --expected-sha256 <2-5에서 구한 소문자 hex>
```

데이터베이스는 부트스트랩 전 상태여야 한다. 이미 심어져 있으면 명령이 거부한다 — 그건 정상
동작이고, 그 경우 이 단계는 이미 끝난 것이다.

명령이 거부하는 것들(전부 의도된 동작): 1 MiB 초과 파일, 중복 JSON 키, 모르는 필드,
`--expected-sha256` 불일치, `current_user` 불일치.

## 2-7. 정리

- 성공 응답(`{"ok":true,...}`)만 보관한다. 자격증명이 없는 수령증이다.
- 완성된 manifest 파일은 확인 후 **안전하게 삭제**한다.
- `I2S_BOOTSTRAP_*` 와 `I2S_HMAC_KEY` 등 환경변수를 지우고 셸 히스토리를 비운다.

---

# 끝나면 알려줄 것

이 세 줄만 알려주면 된다. **어떤 비밀값도 포함하지 않는다.**

1. Cognito 운영자 계정 생성 완료 — MFA 등록 여부(예/아니오)
2. `operator bootstrap` 종료 코드 (`0` 이면 성공) 와 `{"ok":true,...}` 응답의
   `command` 필드
3. `externalIdentityKeyVersion` 에 최종적으로 넣은 값 (`1` 이어야 한다)

받으면 `kcrmin` 세션이 이어서 한다.

- `vars.TF_VARS_JSON` 에 `operator_rbac_catalog_version`, 나머지 RBAC·케이스·제재 권한
  UUID 15개, MFA 보증 설정을 넣고 `enable_operator_auth` 를 `true` 로 바꾼다.
  (UUID 값은 `proposals/.../catalog.json` 에 이미 있으므로 전달받을 필요가 없다.)
- 릴리스를 올려 plan 이 `infra/.../runtime.tf:145` precondition 을 통과하는지 확인한다.
- INT05 를 수행하고 `docs/evidence/INT05.md` 를 쓴다.

# 막히면

증상별로 원인이 갈린다.

| 증상 | 원인 |
| --- | --- |
| `current_user` 불일치로 거부 | `expectedDatabaseRole` 과 접속 롤이 다르다 (2-2) |
| `--expected-sha256` 불일치 | manifest 를 고친 뒤 해시를 다시 안 구했다 (2-5) |
| 이미 부트스트랩됨 | 이 단계는 끝난 상태다. 그대로 알려준다 |
| 부트스트랩은 성공했는데 로그인이 안 됨 | 둘 중 하나다. ① `externalIdentityKeyVersion` 이 `0` 이다 (2-1b) ② HMAC 키를 base64 디코딩하지 않았다 (2-3) |

배경과 왜 이것이 INT05 의 차단인지는 `docs/evidence/INT05-operator-auth-blocker.md` 에 있다.
