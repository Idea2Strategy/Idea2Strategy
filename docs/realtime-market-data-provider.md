# 미국 주식 시장 데이터 Provider 결정

> 기준일: 2026-07-31
> 상태: 과거·실시간 provider와 실시간 수집 방식 확정. 운영 활성화 전 서비스 사용 범위에 대한 데이터 권리는 별도 확인한다.

## 결정

- 과거 시장 데이터는 `Alpaca SIP`를 사용한다.
- 과거 데이터는 원본과 adjusted 데이터를 Parquet dataset으로 보존하며, 백테스트는 고정된 dataset manifest를 사용한다.
- 실시간 시장 데이터는 `Alpaca Algo Trader Plus`의 SIP feed를 사용한다.
- 현재 공식 게시 가격은 월 99달러이며, 실제 결제 시점의 Alpaca 요금과 조건을 다시 확인한다.
- 실시간 대상은 플랫폼이 제공하는 미국 주식·ETF 약 550종목이다.
- 550종목은 REST polling이 아니라 하나의 `market-gateway`가 SIP WebSocket으로 구독한다.
- 최초 구성은 Java·Spring `market-gateway` 1개와 Java·Spring `trading-worker` 풀이다.

## 실시간 처리 흐름

```text
Alpaca Algo Trader Plus SIP WebSocket
  → market-gateway
  → 내부 quote·trade·bar·market-status 사건으로 정규화
  → Redis Streams 및 종목별 최신값 cache
  → trading-worker
  → 전략 평가·가상 주문·체결·판단 로그
```

- `market-gateway`가 Alpaca 인증, 550종목 구독, 구독 승인 확인, 연결 상태와 데이터 신선도 감시를 담당한다.
- 거래, 호가, 분봉과 전략 실행에 필요한 시장 상태·수정 사건을 내부의 provider-neutral 계약으로 변환한다.
- `trading-worker`는 Alpaca SDK나 feed 형식에 직접 의존하지 않고 정규화된 내부 사건만 소비한다.
- 연결이 끊기면 지수 backoff로 재연결하고 전체 구독을 복원한다.
- 재연결 사이에 누락된 구간은 Alpaca REST API로 조회해 보충한 뒤 중복·역순·수정 사건을 검사한다.
- 시세가 stale 상태이거나 누락 구간 복구가 끝나지 않은 종목은 새 주문을 만들지 않는다.
- 계정 추가 생성이나 복수 연결로 provider 제한을 우회하지 않는다.

## 과거 데이터와 실시간 데이터의 구분

- 같은 Alpaca를 사용하더라도 과거 백테스트 dataset과 실시간 feed는 별도 입력으로 관리한다.
- 과거 데이터는 10년치 Parquet dataset과 immutable manifest로 재현성을 보장한다.
- 실시간 데이터는 SIP WebSocket 사건과 최신 상태를 Redis에 전달하며, 운영 원장과 판단 로그에 사용한 provider·feed·정책 버전을 남긴다.
- `market_data.providers` 및 관련 metadata에서 과거 feed와 실시간 feed를 구분한다.
- 예시 식별자는 과거 dataset이 `ALPACA_SIP_HISTORICAL_*`, 실시간 feed가 `ALPACA_SIP_REALTIME_*`이다. 정확한 코드값은 구현 계약에서 확정한다.
- 전략의 시작 전 지표 warm-up이나 연결 복구에는 필요한 과거 구간만 조회하며, 실시간 처리 중 매번 전체 Parquet를 탐색하지 않는다.

## 데이터 권리와 합법성 경계

Algo Trader Plus 구독은 SIP 데이터 접근 상품이며, Idea2Strategy가 해당 데이터를 제3자에게 표시·전송·다운로드하게 할 권한까지 자동으로 보장한다고 간주하지 않는다. Alpaca는 별도 안내에서 API 데이터 재배포를 허용하지 않는다고 명시하고 있다.

- 원시 실시간 시세를 UI, 공개 API, CLI 또는 파일 다운로드로 제공하지 않는다.
- 운영 전 Alpaca에 Idea2Strategy의 정확한 사용 형태를 서면으로 설명하고 허용 범위를 확인한다.
- 확인 범위에는 서버 내부 전략 계산, 가상 주문·체결 결과 표시, 봇 상태와 성과 표시, 실시간 가격·차트 표시 여부가 포함되어야 한다.
- 실시간 가격이나 차트를 사용자에게 직접 표시해야 한다면 명시적인 권리 또는 별도 계약을 확보하기 전에는 기능을 활성화하지 않는다.
- 승인된 provider, feed, 계약 버전과 허용 기능을 설정·DB metadata로 관리한다.
- 운영 환경은 필요한 권리 확인 상태가 없거나 만료되면 실시간 `market-gateway` 또는 권리 대상 기능의 기동을 차단한다.
- 외부 AI용 CLI에도 원시 시장 데이터를 노출하지 않는다.

## 구현 체크포인트

- SIP WebSocket 550종목 구독과 구독 승인 검증
- 재연결, 재구독, 누락 구간 REST 복구
- timestamp, sequence와 event identity 기반 중복·역순 처리
- correction·cancel·시장 상태 사건 처리
- Redis Streams 발행과 최신값 cache의 원자적 갱신
- 종목별 데이터 age 및 consumer lag 관측
- stale·gap·provider 장애 시 주문 차단
- provider·feed·권리·정규화 계약 버전 기록
- 운영 권리 gate와 만료 처리

## 공식 근거

- Alpaca Market Data API 요금제: https://docs.alpaca.markets/us/docs/about-market-data-api
- Alpaca 실시간 주식 데이터: https://docs.alpaca.markets/docs/real-time-stock-pricing-data
- Alpaca API 데이터 재배포 안내: https://alpaca.markets/support/redistribute-alpaca-api
