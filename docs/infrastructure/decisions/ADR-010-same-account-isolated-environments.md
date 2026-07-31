# ADR-010: 같은 AWS 계정의 환경 격리와 S3 저장 경계

- 상태: Proposed
- 작성일: 2026-07-29
- 결정자: 인프라 담당자
- 관련 질문: INFRA-Q-003, INFRA-Q-006, INFRA-Q-007, INFRA-Q-010, INFRA-Q-011, INFRA-Q-017, INFRA-Q-020, INFRA-Q-021, INFRA-Q-022
- 관련 정본 ID: decision.data.hybrid, quality.auditability, quality.failure-safety, quality.reproducibility, technology.need.object-storage, technology.need.server-runtime
- Supersedes:

## 맥락

현재는 개인 AWS 계정에 공용 Development 환경을 먼저 구축한다. 향후 서비스 공개 시 Production이 필요하지만, 초기부터 AWS Organizations와 여러 계정을 운영하면 권한·결제·Terraform bootstrap과 CI/CD 구성이 복잡해진다.

반대로 같은 VPC와 데이터 저장소를 Development와 Production이 공유하면 개발 중 변경, 데이터 삭제, Security Group 오설정과 Terraform 오작동이 Production까지 전파될 수 있다. 같은 AWS 계정을 사용하더라도 실행 리소스, 데이터, 비밀과 State를 환경별로 나누는 중간 경계가 필요하다.

S3에는 대용량 시장 데이터, 백테스트·성과 결과와 Terraform State처럼 성격과 접근 주체가 다른 객체가 함께 존재한다. 환경 격리와 별개로 버킷을 지나치게 잘게 나누지 않으면서 권한·보존·복구 정책이 다른 큰 저장 영역을 구분해야 한다.

## 선택지

### 선택지 A: 같은 AWS 계정, 환경별 리소스 완전 분리

- VPC, EC2, RDS, S3, 비밀, IAM 실행 역할과 Terraform State를 환경별로 분리한다.
- 계정 운영은 단순하게 유지하면서 환경 간 장애와 오조작 범위를 줄일 수 있다.

### 선택지 B: 환경별 AWS 계정 분리

- AWS 계정 자체가 강한 보안·결제·할당량 경계가 된다.
- AWS Organizations, 계정 bootstrap, 교차 계정 ECR·CI/CD와 운영 권한 관리가 추가된다.

### 선택지 C: 같은 VPC에서 리소스만 구분

- 구축은 가장 간단하다.
- 라우팅·Security Group·Terraform·데이터 권한 오조작이 환경을 넘을 가능성이 커진다.

## 결정

인프라 담당자는 선택지 A를 선택했다. 현재 실제 구축·운영 대상은 Development 환경 하나뿐이며 Production용 AWS 리소스, Terraform State와 권한은 지금 만들지 않는다. Production은 서비스 공개 등 실제 필요가 확인된 시점에 Development와 분리된 별도 환경으로 신규 생성한다. 팀 합의와 Terraform 검증 전까지 이 ADR은 `Proposed`로 유지한다.

현재 Development의 S3는 `시장 데이터`, `백테스트·성과 결과`, `Terraform State`의 세 버킷으로 분리한다. 세부 데이터셋마다 버킷을 추가하지 않고 각 버킷 안에서는 Prefix, 객체 메타데이터와 RDS 매니페스트로 구분한다. 향후 Production을 추가할 때 같은 세 경계를 Production 전용 버킷으로 새로 생성한다.

## 환경별 분리 경계

다음 리소스는 Development와 Production이 공유하지 않는다.

- VPC, Subnet, Route Table, Internet Gateway와 Security Group
- Application Load Balancer, ACM 인증서, 서비스 EC2와 백테스트·배치 EC2
- RDS PostgreSQL 인스턴스, DB 계정과 Flyway 이력
- 시장 데이터·백테스트·성과 결과·Terraform State S3 버킷
- SSM Parameter Store 경로와 애플리케이션 비밀
- EC2 IAM Role, Terraform 실행 역할과 배포 대상
- CloudWatch Log Group과 알림 대상
- Terraform 변수와 State

## 환경별 S3 큰 저장 경계

현재는 Development에 다음 세 버킷만 생성한다. 향후 Production을 추가할 때 동일한 세 버킷을 Production 전용으로 별도 생성하며 서로의 버킷을 공유하지 않는다.

| 버킷 경계 | 저장 내용 | 주요 접근 주체 |
|---|---|---|
| 시장 데이터 | 과거·실시간 원본, RAW·ADJUSTED·파생 Parquet, 데이터셋 리비전, 실시간 수집 청크 | Market Data Worker 쓰기, Batch·Backtest 읽기 |
| 백테스트·성과 결과 | 거래·포지션 상세, 계산·재현 데이터, 장기 성과 시계열 | Backtest·Batch 쓰기, Backend의 승인된 결과 조회 |
| Terraform State | 해당 환경의 Terraform State와 잠금 객체 | 환경별 Terraform 실행 역할만 접근 |

시장 데이터와 결과 객체는 덮어쓰지 않고 새 객체·리비전으로 발행한다. 공식 객체는 RDS에 S3 Key, 해시, 공급자·피드, 조정 방식, 버전, 생성 규칙과 계보를 매니페스트로 등록한다. `OHLCV`, 틱, 호가 같은 대량 데이터 본문은 RDS에 저장하지 않는다.

모든 버킷에는 Block Public Access, 서버 측 암호화, Versioning과 TLS 강제를 적용한다. 버킷 접근은 IAM Role을 사용하며 EC2에 장기 Access Key를 저장하지 않는다. Terraform State 버킷에는 업무 데이터를 저장하지 않고 EC2 애플리케이션 역할의 접근을 금지하며 `use_lockfile = true` 기반 잠금을 사용한다.

버킷 안의 임시 객체와 공식 객체는 Prefix로 구분한다. 보존 기간과 Storage Class 전환은 실제 데이터 양과 복구 요구를 확인한 뒤 버킷별 Lifecycle 정책으로 정한다.

## 공유 가능한 배포 자산

- Terraform 모듈과 Docker Compose 템플릿은 같은 Git 소스를 사용한다.
- ECR Repository는 빌드 산출물 저장소로 공유할 수 있다.
- Production 배포는 Development에서 검증한 동일 Docker 이미지 Digest를 사용한다.
- 환경별 설정과 비밀을 Docker 이미지 안에 포함하지 않는다.
- Route 53 Hosted Zone은 도메인 권한 경계로 공유하되 Development와 Production 레코드는 분리한다.

## Production 생성

- Production 리소스가 이미 존재하는 것처럼 운영하거나 다이어그램에 실선으로 표시하지 않는다.
- Production 구축 승인 후 별도 Terraform Root Configuration과 State로 VPC부터 신규 생성한다.
- Production RDS는 검토된 `B` Baseline Migration으로 신규 생성한다.
- 이후 Development에서 먼저 검증한 같은 `V` Migration만 Production에 순차 적용한다.
- Development 사용자·봇·거래 데이터를 Production DB에 자동 복사하지 않는다.
- Production에 필요한 검증된 불변 시장 데이터는 별도 S3 이관 작업으로 복사하고 해시를 검증한 뒤 매니페스트에 등록한다.

## 권한 경계

- Development 애플리케이션 역할은 Production RDS·S3·Parameter Store를 읽거나 쓸 수 없다.
- Production 애플리케이션 역할도 Development 업무 데이터에 접근하지 않는다.
- Development Terraform 역할은 Production State와 리소스를 변경할 수 없다.
- Production Terraform·배포 역할은 별도 승인 경로에서만 사용한다.
- 환경 이름 태그와 리소스 이름만으로 격리를 주장하지 않고 IAM Policy와 Terraform State 경계로 강제한다.

## 결과와 영향

- 단순성 효과: AWS 계정과 결제 관리는 하나로 유지한다.
- 안전 효과: Development 장애·삭제·스키마 실험이 Production 리소스에 직접 영향을 주지 않는다.
- 비용 영향: Production 생성 시 EC2·RDS·S3 데이터가 별도로 필요해 리소스 비용이 중복된다.
- 데이터 영향: 대용량 과거 시장 데이터를 환경 간 공유하지 않으므로 Production 초기 이관 시간과 저장 비용이 발생한다.
- 저장소 영향: 버킷 수를 데이터셋마다 늘리지 않고 환경별 세 개로 제한하면서 권한과 Lifecycle의 큰 경계를 분명히 한다.
- 배포 효과: 동일 이미지 Digest와 Terraform 모듈을 사용해 환경 차이와 재빌드 차이를 줄인다.
- 한계: 같은 AWS 계정의 루트·관리자 권한이나 계정 전체 제한은 여전히 두 환경에 공통 영향을 준다.

## 확장과 롤백

Production 중요도, 팀 규모, 규제·감사 요구 또는 계정 전체 장애 위험이 커지면 별도 AWS 계정 분리를 새 ADR로 검토한다. 코드와 State가 환경별로 이미 분리되어 있으므로 새 계정에 같은 Terraform Root를 적용하고 데이터를 별도 이관하는 방식으로 이동할 수 있어야 한다.

Production 생성 중 검증이 실패하면 Development를 변경하지 않고 미완성 Production 리소스만 폐기 후 다시 생성한다. 기존 Development RDS나 S3를 Production으로 이름만 바꾸거나 승격하지 않는다.

## 후속 작업

- [ ] Development Terraform Root Configuration과 변수·State 구현
- [ ] 향후 Production Root Configuration을 별도로 추가할 수 있는 공통 모듈 경계 설계
- [ ] 환경별 Terraform State 버킷의 이름·bootstrap 순서·삭제 보호 IAM 결정
- [ ] 시장 데이터·결과 버킷의 Prefix와 RDS 매니페스트 규칙 결정
- [ ] 버킷별 Versioning·암호화·TLS Bucket Policy와 Lifecycle 검증
- [ ] 환경별 리소스 이름·태그·Parameter Store 경로 규칙 결정
- [ ] ECR 이미지 Digest 승격과 Production 배포 승인 절차 결정
- [ ] Production S3 시장 데이터 이관·해시 검증 절차 결정
- [ ] Production 권한을 가진 인프라 담당자·PL의 IAM 역할 결정
