# ADR-013: Free Plan 배치 EC2 증설과 호스트 안전장치

상태: **Accepted**

날짜: 2026-07-30

## 배경

과거 시장 데이터 수집용 `t3.micro` 배치 EC2에서 SSM Agent가 오프라인이 되었고,
인스턴스는 중지 상태로 확인되었다. 직접적인 OOM 로그는 현재 부팅의 커널 로그에서
확인되지 않았지만, 기존 메모리 1GiB와 루트 EBS 16GiB는 Alpaca SIP 과거 데이터 수집,
Parquet 변환·압축 및 임시 파일 보관에 부족하다.

현재 AWS 계정은 Free Plan이므로 Free Tier eligible 인스턴스 범위 안에서 증설해야 한다.

## 결정

- Development 배치 EC2는 `m7i-flex.large`를 사용한다.
  - 2 vCPU
  - 메모리 8GiB
  - x86_64
  - 현재 계정과 서울 리전에서 Free Tier eligible 확인
- 배치 EC2 루트 EBS는 암호화된 `gp3 100GiB`로 확장한다.
  - 3,000 IOPS
  - 125MiB/s
- 서비스 EC2와 배치 EC2의 루트 볼륨 크기 변수를 분리한다.
- 배치 EC2에 4GiB Swap을 만들고 `vm.swappiness=10`을 적용한다.
- Terraform이 관리하는 SSM Association으로 파일시스템 확장과 Swap 설정을
  재실행 가능하고 멱등한 방식으로 유지한다.
- CloudWatch `mem_used_percent`가 5분 연속 80% 이상이면 경보 상태가 되도록 한다.
- 중지된 EC2의 임시 퍼블릭 IPv4 연결 상태 차이만으로 인스턴스를 교체하지 않도록
  해당 속성의 드리프트를 무시한다.

## 파이프라인 동시성 경계

이 결정은 서버 자원과 호스트 안전장치만 확정한다. 파이프라인의 수집·변환·업로드
동시성은 애플리케이션 코드에서 별도로 구현하고 측정한다.

초기 목표값은 다음과 같다.

- Alpaca 수집 Worker: 4
- Parquet 변환 Worker: 1, 측정 후 최대 2
- S3 업로드 Worker: 4
- RDS Manifest Writer: 1
- 전체 백필 오케스트레이터: 1

현재 `market_hist_script`는 가격 유형, 종목, 180일 Chunk를 순차 순회하므로 서버를
증설하는 것만으로 위 병렬도가 자동 적용되지는 않는다.

## 적용 결과

- 기존 EC2 ID와 루트 EBS를 유지한 인플레이스 변경
- Terraform 적용 결과: 생성 1, 변경 1, 삭제 0
- 루트 파일시스템: 약 96GiB 사용 가능
- RAM: 약 7.6GiB
- Swap: 4GiB
- SSM Agent: Online
- EC2 상태 검사: 정상
- 변경 전 16GiB EBS 복구 스냅샷 생성

## 롤백과 후속 작업

- 인스턴스 유형은 EC2를 중지한 뒤 더 작은 유형으로 되돌릴 수 있다.
- EBS는 축소할 수 없으므로 100GiB보다 작은 새 볼륨이 필요하면 복구 스냅샷 또는
  별도 마이그레이션으로 새 볼륨을 만들어야 한다.
- 전체 백필 전 대표 종목 표본 실행에서 메모리, Swap, CPU, EBS 및 HTTP 429를 측정한다.
- Free Plan 종료 또는 크레딧 소진 전에 Paid Plan 전환 여부를 다시 결정한다.
