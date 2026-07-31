# Development 월비용 추정

기준일: 2026-07-29
리전: Asia Pacific (Seoul), `ap-northeast-2`
기준 시간: 월 730시간
세금, 데이터 전송, ALB LCU, S3 객체·요청, CloudWatch 로그 수집량과 Free Plan 크레딧 차감 전 금액

## 현재: Market Data Bootstrap

과거 시장 데이터 적재를 위해 먼저 생성하는 최소 구성이다.

| 항목 | 단가 | 수량 | 월 추정 |
|---|---:|---:|---:|
| EC2 `t3.micro` | USD 0.013/시간 | 1대 | USD 9.49 |
| RDS PostgreSQL `db.t4g.micro`, Single-AZ | USD 0.025/시간 | 1대 | USD 18.25 |
| Public IPv4 | USD 0.005/시간 | EC2 1개 | USD 3.65 |
| EC2 gp3 | USD 0.0912/GB-월 | 16GB | USD 1.46 |
| RDS gp3 | USD 0.131/GB-월 | 20GB | USD 2.62 |
| CloudWatch 표준 Alarm | 일반적인 USD 0.10/Alarm-월 기준 | 3개 | 약 USD 0.30 |
| RDS 관리형 비밀 | Secrets Manager 비밀 1개 | 1개 | 약 USD 0.40 |

고정 사용량 기준 합계는 대략 **USD 36.17/월**이다. 실제 청구액에는 S3 저장량·요청, 데이터 전송, CloudWatch Logs와 세금이 추가될 수 있다. AWS Free Plan 크레딧과 적용 가능한 무료 사용량은 청구액에서 차감될 수 있다.

## 향후: 전체 서비스 구성

`deployment_phase = "full"`로 변경하면 서비스 EC2, ALB, Route 53, ACM, Results S3와 ECR이 추가된다. 기존 전체 구성의 고정 사용량 추정은 약 **USD 96.83/월**이며, 실제 사양과 데이터 사용량을 확인한 뒤 다시 산정한다.

## 비용을 줄이는 운영 방법

- 애플리케이션 개발이 시작되기 전에는 전체 Development plan을 적용하지 않는다.
- 사용하지 않는 백테스트·배치 EC2는 중지한다. 중지 중에는 EC2 컴퓨팅 비용과 해당 Public IPv4 비용은 발생하지 않지만 EBS 비용은 유지된다.
- RDS는 단기 중지가 가능하지만 AWS가 최대 중지 기간 뒤 자동 재시작할 수 있으므로 장기 절감 수단으로 가정하지 않는다.
- ALB는 중지 기능이 없으므로 생성된 동안 시간당 비용과 Public IPv4 비용이 계속 발생한다.
- 7일간 실제 사용량을 측정한 뒤 EC2 가동 시간과 사양을 다시 결정한다.

## 가격 근거

- EC2, RDS, EBS, RDS Storage, ALB 단가는 AWS Price List API에서 현재 계정의 임시 자격 증명으로 조회했다.
- Public IPv4는 [Amazon VPC Pricing](https://aws.amazon.com/vpc/pricing/)의 USD 0.005/IP-시간을 사용했다.
- 서비스별 최종 청구액은 [AWS Pricing Calculator](https://calculator.aws/)와 AWS Billing에서 다시 확인한다.
