# AWS 개발자 계정 등록 및 사용 안내

## 적용 대상

- `kcrmin`
- `hoyow`
- `hjcud`
- `SeoDongWi`
- `pjy`

모든 사용자는 `Idea2StrategyDevelopmentSsmUsers` IAM 그룹에 속하며 같은 개발 권한을 사용한다. IAM 사용자와 그룹 소속은 Terraform으로 관리하지만, 콘솔 로그인 프로필과 초기 비밀번호는 Terraform 및 Git에 저장하지 않는다.

## 관리자가 사용자별로 전달할 정보

다음 정보는 공개 채널이 아닌 개인 메시지로 각각 전달한다.

- IAM 사용자 이름
- AWS 계정 ID: `418553863687`
- IAM 사용자 로그인 주소: `https://418553863687.signin.aws.amazon.com/console`
- 일회용 초기 비밀번호
- AWS 리전: `ap-northeast-2`

초기 비밀번호는 사용자마다 다르게 만들고 첫 로그인 시 변경을 강제한다. 이메일 주소는 IAM 사용자 생성이나 로그인에 필요하지 않다.

## 최초 등록

1. 관리자가 전달한 IAM 사용자 로그인 주소를 연다.
2. 본인의 IAM 사용자 이름과 초기 비밀번호로 로그인한다.
3. 안내에 따라 초기 비밀번호를 본인만 아는 비밀번호로 변경한다.
4. AWS Console 오른쪽 위의 사용자 이름을 누르고 `Security credentials`로 이동한다.
5. `Multi-factor authentication (MFA)`에서 가상 MFA 장치를 등록한다.
6. 로그아웃한 뒤 사용자 이름, 새 비밀번호, MFA 코드로 다시 로그인한다.

개발 리소스 조회와 SSM 접속 등 대부분의 권한은 MFA 인증 세션에서만 허용된다.

## AWS CLI 로그인

AWS CLI v2와 Session Manager Plugin을 설치한 뒤 본인 PC에서 다음 명령을 실행한다.

```powershell
aws login --profile idea2strategy-dev --region ap-northeast-2
aws sts get-caller-identity --profile idea2strategy-dev
```

브라우저가 열리면 본인의 IAM 사용자와 MFA로 승인한다. `get-caller-identity` 결과의 `Arn`이 본인의 IAM 사용자여야 한다.

장기 Access Key는 발급하지 않는다. `aws login`으로 생성되는 단기 세션을 사용하고, 만료되면 같은 명령으로 다시 로그인한다.

## 배치 EC2 접속

```powershell
aws ssm start-session `
  --target i-08d1f00a9add629c3 `
  --region ap-northeast-2 `
  --profile idea2strategy-dev
```

SSH 포트와 개인 키를 사용하지 않고 AWS Systems Manager Session Manager를 통해 접속한다.

## RDS 접속용 터널

RDS는 외부에 공개하지 않는다. 로컬 애플리케이션이나 DB 도구에서 접근할 때 배치 EC2를 경유하는 SSM 포트 포워딩을 연다.

```powershell
aws ssm start-session `
  --target i-08d1f00a9add629c3 `
  --document-name AWS-StartPortForwardingSessionToRemoteHost `
  --parameters "host=<RDS 엔드포인트>,portNumber=5432,localPortNumber=15432" `
  --region ap-northeast-2 `
  --profile idea2strategy-dev
```

터널이 열린 동안 DB 도구는 `127.0.0.1:15432`에 접속한다. PostgreSQL 사용자와 비밀번호는 IAM 사용자 계정과 별개이며, 담당자가 별도로 전달한 DB 계정을 사용한다.

## 허용되는 주요 작업

- 지정된 배치 EC2에 SSM으로 접속
- 개발용 S3 버킷의 객체 조회, 업로드 및 삭제
- 개발용 ECR 이미지 업로드 및 다운로드
- EC2, RDS, ALB, CloudWatch, Route 53 및 ACM 상태 조회
- `/idea2strategy/dev/` 경로의 SSM Parameter 조회

EC2 생성·삭제·시작·중지, RDS 변경, Route 53 변경, IAM 권한 변경과 같은 인프라 관리자 작업은 허용되지 않는다.

## 보안 주의사항

- 초기 비밀번호, MFA 복구 정보 및 세션 자격 증명을 Git, 메신저 단체방 또는 문서에 기록하지 않는다.
- 다른 사람과 IAM 사용자를 공유하지 않는다.
- S3 객체 삭제 권한이 있으므로 삭제 전 버킷과 객체 경로를 다시 확인한다.
- SSM 작업이 끝나면 셸과 포트 포워딩 세션을 종료한다.
- 접근이 더 이상 필요하지 않으면 인프라 담당자에게 계정 비활성화를 요청한다.
