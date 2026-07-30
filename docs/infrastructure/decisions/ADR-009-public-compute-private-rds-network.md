# ADR-009: Public ALB·EC2와 Private RDS 네트워크

- 상태: Proposed
- 작성일: 2026-07-29
- 결정자: 인프라 담당자
- 관련 질문: INFRA-Q-003, INFRA-Q-006, INFRA-Q-015, INFRA-Q-020
- 관련 정본 ID: quality.failure-safety, technology.need.server-runtime
- Supersedes:

## 맥락

초기 Development는 모의투자 서비스 EC2와 백테스트·배치 EC2 두 대를 사용한다. 서비스 EC2는 사용자 HTTPS 요청과 SIP 실시간 연결을 처리하고, 배치 EC2는 Alpaca 과거 데이터 수집, 백테스트와 배치 작업을 처리한다. 두 서버 모두 외부 서비스와 ECR·SSM 같은 AWS API로 나갈 수 있어야 한다.

배치 EC2를 Private Subnet에 두면 인터넷 아웃바운드를 위해 NAT Gateway나 더 복잡한 네트워크 구성이 필요하다. 현재 단계에서는 무중단 운영보다 단순한 재구성과 낮은 운영 복잡도를 우선하며, 외부 인바운드는 Security Group과 SSM 관리 경계로 차단할 수 있다.

## 선택지

### 선택지 A: ALB·두 EC2 Public Subnet, RDS Private Subnet

- 두 EC2가 Internet Gateway를 통해 직접 아웃바운드 통신한다.
- 인터넷 인바운드는 ALB의 80·443만 허용한다.
- 서비스 EC2는 ALB Security Group에서 오는 Caddy Target 포트만 받고 배치 EC2는 인바운드를 허용하지 않는다.
- NAT Gateway가 필요하지 않아 비용과 구성이 단순하다.

### 선택지 B: 서비스 EC2 Public, 배치 EC2와 RDS Private

- 배치 EC2의 외부 통신을 위해 NAT Gateway를 사용한다.
- 컴퓨트 네트워크 경계는 더 강하지만 NAT 비용과 라우팅·장애 지점이 추가된다.

### 선택지 C: 모든 EC2 Private, ALB와 NAT Gateway 사용

- 외부 요청은 ALB만 받고 모든 EC2는 Private Subnet에 둔다.
- 컴퓨트 네트워크 경계는 강하지만 NAT 비용과 라우팅·운영 복잡도가 증가한다.

## 결정

인프라 담당자는 선택지 A를 선택했다. 팀 합의와 Terraform 검증 전까지 이 ADR은 `Proposed`로 유지한다.

### VPC와 Subnet

- 서울 `ap-northeast-2`에 초기 Development 전용 VPC 하나를 만든다.
- Public Subnet은 Internet Gateway로 향하는 기본 경로를 가진다.
- 인터넷 공개 Application Load Balancer를 서로 다른 가용 영역의 Public Subnet 2개에 연결한다.
- 두 EC2를 Public Subnet에 배치한다.
- RDS DB Subnet Group은 서로 다른 가용 영역의 Private Subnet으로 구성한다.
- Private DB Subnet에는 Internet Gateway 기본 경로를 두지 않는다.
- 초기에는 NAT Gateway와 Bastion Host를 만들지 않는다.

### 외부 인바운드

- Route 53 A/AAAA Alias 레코드는 Application Load Balancer를 가리킨다.
- ALB Security Group은 인터넷에서 TCP 80·443만 허용하고 80 요청을 HTTPS로 전환한다.
- ALB는 ACM 인증서로 TLS를 종료하고 Target Group 헬스 체크와 WebSocket 전달을 담당한다.
- 서비스 EC2 Security Group은 ALB Security Group에서 오는 Caddy Target 포트 8080만 허용한다.
- 백테스트·배치 EC2 Security Group은 인터넷 인바운드를 허용하지 않는다.
- 두 EC2 모두 TCP 22를 인터넷에 공개하지 않는다.
- Caddy는 Target 포트 8080에서 Frontend·API·WebSocket 내부 경로를 분기하고 애플리케이션·Redis 컨테이너 포트를 직접 공개하지 않는다.

### 관리와 아웃바운드

- EC2 관리는 AWS Systems Manager Session Manager와 SSM 배포 명령을 사용한다.
- 두 EC2는 SSM·ECR·S3와 외부 데이터 공급자에 HTTPS로 아웃바운드 통신한다.
- 배치 EC2의 Public IPv4는 외부 진입점이 아니라 아웃바운드 통신을 위한 주소다.
- S3 Gateway Endpoint는 필요성과 Terraform 단순성을 비교한 뒤 추가할 수 있지만 이 결정의 선행 조건은 아니다.

### 데이터 저장소

- RDS는 `Publicly Accessible=false`로 생성한다.
- RDS Security Group은 서비스 EC2와 배치 EC2 Security Group에서 오는 PostgreSQL 연결만 허용한다.
- Redis는 서비스 EC2 Docker 네트워크 내부에서만 접근하며 호스트 공개 포트로 바인딩하지 않는다.
- S3 버킷은 퍼블릭 액세스 차단을 적용하고 EC2 IAM Role로 접근한다.

## 결과와 영향

- 비용 효과: NAT Gateway 고정 비용과 처리 비용은 피하지만 ALB 시간·LCU와 퍼블릭 IPv4 비용이 추가된다.
- 운영 효과: 외부 데이터와 AWS API를 위한 별도 NAT 라우팅 없이 두 EC2를 운영할 수 있다.
- 보안 효과: 인터넷 인바운드는 ALB로 모이고 서비스 EC2는 ALB Security Group의 Target 요청만 받으며 DB와 Redis는 외부에 공개되지 않는다.
- 가용성 효과: ALB 헬스 체크와 Target Group 경계를 확보해 향후 서비스 EC2를 추가하기 쉽다. 다만 초기 Target이 한 대이므로 EC2 장애 자체를 제거하지는 못한다.
- 위험: 배치 EC2에 Public IPv4가 존재하므로 Security Group 오설정이 곧 노출 위험이 될 수 있다.
- 장애 영향: Internet Gateway나 EC2 아웃바운드 문제는 외부 데이터 수집과 배포·관리 연결에 영향을 준다.
- 확장 영향: 배치 EC2를 Private Subnet으로 옮길 때 NAT Gateway 또는 필요한 VPC Endpoint와 새 라우팅이 필요하다.

## 검증과 관측

- Terraform 검증에서 RDS의 공개 접근 비활성화와 허용된 Security Group 경로를 확인한다.
- Route 53 Alias, ACM 인증서, ALB Listener·Target Group과 헬스 체크 상태를 확인한다.
- 배포 후 외부에서 서비스 EC2·배치 EC2와 RDS 포트에 직접 접속할 수 없음을 확인한다.
- ALB를 경유한 HTTPS와 WebSocket 요청이 Caddy의 올바른 경로로 전달되는지 확인한다.
- SSM Session Manager로 두 EC2에 접속할 수 있고 ECR 이미지 Pull과 S3 접근이 가능한지 확인한다.
- AWS Config 또는 정기 점검으로 22번 포트, RDS 공개 접근과 광범위한 인바운드 규칙이 생기지 않았는지 확인한다.

## 확장과 롤백

보안 요구, 팀 규모 또는 배치 서버 수가 증가하면 배치 EC2를 Private Subnet으로 재생성하고 NAT Gateway 또는 필요한 VPC Endpoint를 추가한다. 애플리케이션 상태를 EC2 로컬 디스크에 의존하지 않고 RDS와 S3에 유지하므로 네트워크 위치 변경은 새 EC2 생성과 Docker Compose 재배포로 수행한다.

현재 구성이 동작하지 않으면 Terraform에서 원래 리소스를 파괴하기 전에 새 Subnet과 EC2를 병렬 생성해 SSM·ECR·S3·외부 데이터·RDS 연결을 검증한 뒤 전환한다.

## 후속 작업

- [ ] VPC와 Public·Private Subnet CIDR 결정
- [ ] 두 가용 영역과 EC2·RDS Subnet 배치 결정
- [ ] ALB Listener·Target Group·헬스 체크 경로와 ACM DNS 검증 구성
- [ ] Security Group 규칙과 EC2 IAM Role을 Terraform으로 작성
- [ ] SSM Session Manager와 SSM 배포 명령 검증
- [ ] 외부에서 배치 EC2·RDS·Redis 접근 차단 검증
- [ ] 두 EC2 Public IPv4 고정 필요 여부 결정
