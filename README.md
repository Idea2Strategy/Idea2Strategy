<p align="center">
  <img src="docs/assets/i2s-logo.svg" width="200" alt="Idea2Strategy 로고" />
</p>
<!-- Logo source: Idea2Strategy-ui@47a3334aaf7d8560296b75713d213c14fdd24d9c, src/assets/i2s-logo.svg -->

<h1 align="center">Idea2Strategy</h1>

<p align="center">
  <strong>투자 아이디어를 전략으로, 전략을 데이터로!</strong><br />
  블록으로 전략을 만들고, 백테스트와 실시간 가상 거래로 검증하는 투자 전략 실험 플랫폼입니다.
</p>

## 프로젝트 소개 📝

**Idea2Strategy**는 나만의 투자 아이디어를 직접 만들고 검증할 수 있도록 개발 중인 가상 트레이딩 봇 서비스입니다.

매수·매도 조건을 블록으로 연결해 전략을 작성하고, 검증한 전략을 하나의 버전으로 출시합니다. 출시한 전략으로 봇을 생성하면 자동 백테스트를 통해 과거 데이터에서의 결과를 살펴볼 수 있습니다.

봇은 서버에서 실시간 시장 데이터를 받아 가상 거래를 수행합니다. 사용자는 전략의 판단 기록과 거래 결과를 확인하고, 방에서 다른 봇과 성과를 비교하며 아이디어를 발전시킬 수 있습니다.

### 주요 기능

<!-- GIF 영역: 400 × 225 px. 각 img의 src를 준비한 GIF 경로로 교체하고 width와 height를 유지합니다. -->
<table>
  <tbody>
    <tr>
      <td width="440" height="225" align="center" valign="middle">
        <img src="docs/assets/feature-demo-placeholder.svg" width="400" height="225" alt="블록 기반 전략 편집기 GIF 자리" />
      </td>
      <td width="440" height="225" align="center" valign="middle">
        <img src="docs/assets/feature-demo-placeholder.svg" width="400" height="225" alt="전략 미리보기 GIF 자리" />
      </td>
    </tr>
    <tr>
      <td width="440" height="140" align="center" valign="top">
        <h4>블록 기반 전략 편집기</h4>
        <p><sub>매수·매도 조건을 블록으로 조합하고,</sub><br /><sub>규칙을 검증해 전략을 작성합니다.</sub></p>
      </td>
      <td width="440" height="140" align="center" valign="top">
        <h4>전략 미리보기</h4>
        <p><sub>편집기로 만든 전략으로 투자했을 때의</sub><br /><sub>최근 매수·매도 내역을 미리 확인합니다.</sub></p>
      </td>
    </tr>
    <tr>
      <td width="440" height="225" align="center" valign="middle">
        <img src="docs/assets/feature-demo-placeholder.svg" width="400" height="225" alt="백테스트 GIF 자리" />
      </td>
      <td width="440" height="225" align="center" valign="middle">
        <img src="docs/assets/feature-demo-placeholder.svg" width="400" height="225" alt="판단·거래 기록 조회 GIF 자리" />
      </td>
    </tr>
    <tr>
      <td width="440" height="140" align="center" valign="top">
        <h4>백테스트</h4>
        <p><sub>봇 생성 시 자동 백테스트를 수행하고,</sub><br /><sub>원하는 기간의 과거 데이터로 전략을 검증합니다.</sub></p>
      </td>
      <td width="440" height="140" align="center" valign="top">
        <h4>판단·거래 기록 조회</h4>
        <p><sub>전략의 판단 과정, 주문·체결,</sub><br /><sub>포지션과 원장 기록을 연결해 결과를 살펴봅니다.</sub></p>
      </td>
    </tr>
    <tr>
      <td width="440" height="225" align="center" valign="middle">
        <img src="docs/assets/feature-demo-placeholder.svg" width="400" height="225" alt="실시간 가상 거래 GIF 자리" />
      </td>
      <td width="440" height="225" align="center" valign="middle">
        <img src="docs/assets/feature-demo-placeholder.svg" width="400" height="225" alt="대회 GIF 자리" />
      </td>
    </tr>
    <tr>
      <td width="440" height="140" align="center" valign="top">
        <h4>실시간 가상 거래</h4>
        <p><sub>서버에서 봇을 실행·중지하고,</sub><br /><sub>시장 데이터에 따른 전략 평가와 가상 체결을 확인합니다.</sub></p>
      </td>
      <td width="440" height="140" align="center" valign="top">
        <h4>대회</h4>
        <p><sub>공통 규칙을 적용하는 대회에서 봇의 성과를 비교하고,</sub><br /><sub>평가 결과와 리더보드를 확인합니다.</sub></p>
      </td>
    </tr>
  </tbody>
</table>

## 팀원 👨‍💻👩‍💻

프로젝트에 참여한 팀원과 담당 역할입니다.

| Leader | Frontend | Backend | Backend | Infrastructure | DB / Data |
| :---: | :---: | :---: | :---: | :---: | :---: |
| <a href="https://github.com/kcrmin"><img src="https://avatars.githubusercontent.com/u/73128364?v=4" width="120" height="120" alt="민경철 GitHub 프로필" /></a> | <a href="https://github.com/SeoDongWi"><img src="https://avatars.githubusercontent.com/u/255266197?v=4" width="120" height="120" alt="서동위 GitHub 프로필" /></a> | <a href="https://github.com/hjcud"><img src="https://avatars.githubusercontent.com/u/16863475?v=4" width="120" height="120" alt="손현준 GitHub 프로필" /></a> | <a href="https://github.com/pjy008008"><img src="https://avatars.githubusercontent.com/u/69574758?v=4" width="120" height="120" alt="박준유 GitHub 프로필" /></a> | <a href="https://github.com/Juwon-Na"><img src="https://avatars.githubusercontent.com/u/258857238?v=4" width="120" height="120" alt="나주원 GitHub 프로필" /></a> | <a href="https://github.com/dertz569"><img src="https://avatars.githubusercontent.com/u/105340411?v=4" width="120" height="120" alt="황영우 GitHub 프로필" /></a> |
| [민경철](https://github.com/kcrmin) | [서동위](https://github.com/SeoDongWi) | [손현준](https://github.com/hjcud) | [박준유](https://github.com/pjy008008) | [나주원](https://github.com/Juwon-Na) | [황영우](https://github.com/dertz569) |
| 백엔드 설계·구현<br />거래·원장 처리<br />서비스 연동 | 블록형 편집기<br />화면·UX 설계<br />서비스 UI 구현 | 전략·봇·주문<br />체결·성과 기능<br />서버 설계·구현 | 전략·봇·주문<br />체결·성과 기능<br />서버 설계·구현 | 서버·컨테이너<br />배포 환경 구축<br />운영 구조 설계 | 시장 데이터 수집<br />저장·모델 설계<br />실시간 구조 설계 |

## 프로젝트 기술 스택 💡

### 프론트엔드

![React](https://img.shields.io/badge/React_19-20232A?style=for-the-badge&logo=react&logoColor=61DAFB)
![TypeScript](https://img.shields.io/badge/TypeScript_7-3178C6?style=for-the-badge&logo=typescript&logoColor=white)
![Vite](https://img.shields.io/badge/Vite_8-646CFF?style=for-the-badge&logo=vite&logoColor=white)
![React Router](https://img.shields.io/badge/React_Router_7-CA4245?style=for-the-badge&logo=reactrouter&logoColor=white)

- **React · TypeScript · Vite**로 화면을 구성하고, **Lightweight Charts · Three.js**로 차트와 시각화를 구현합니다.
- **Node.js 24 · pnpm 11**, **Vitest · Testing Library · Playwright · MSW**를 사용합니다.

### 백엔드

![Java](https://img.shields.io/badge/Java_21-ED8B00?style=for-the-badge)
![Spring Boot](https://img.shields.io/badge/Spring_Boot_4.1-6DB33F?style=for-the-badge&logo=springboot&logoColor=white)
![Gradle](https://img.shields.io/badge/Gradle-02303A?style=for-the-badge&logo=gradle&logoColor=white)
![Flyway](https://img.shields.io/badge/Flyway_11-CC0200?style=for-the-badge&logo=flyway&logoColor=white)

- **Java 21 · Spring Boot 4.1** 기반으로 사용자 API, 전략·봇 제어, 실시간 전략 평가와 가상 체결을 처리합니다.
- **JPA · jOOQ · Flyway**로 데이터 접근과 마이그레이션을 관리하고, **JUnit · Testcontainers**로 검증합니다.

### 데이터 파이프라인·백테스트

![Python](https://img.shields.io/badge/Python_3.12-3776AB?style=for-the-badge&logo=python&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)
![pandas](https://img.shields.io/badge/pandas-150458?style=for-the-badge&logo=pandas&logoColor=white)
![Apache Parquet](https://img.shields.io/badge/Apache_Parquet-50ABF1?style=for-the-badge&logo=apacheparquet&logoColor=white)

- **Python · FastAPI** 기반 API와 워커가 백테스트를 실행하고 결과를 제공합니다.
- **Alpaca SDK · pandas · NumPy · PyArrow**로 시장 데이터를 수집·가공하고, **Parquet**와 데이터셋 Manifest로 보관합니다.
- **pytest · Ruff · mypy**로 테스트, 코드 검사와 타입 검사를 수행합니다.

### 데이터베이스·스토리지

![PostgreSQL](https://img.shields.io/badge/PostgreSQL_16-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)
![Redis](https://img.shields.io/badge/Redis_7.4-FF4438?style=for-the-badge&logo=redis&logoColor=white)
![Valkey](https://img.shields.io/badge/Valkey_Serverless-18BDB3?style=for-the-badge&logo=valkey&logoColor=white)
![Amazon S3](https://img.shields.io/badge/Amazon_S3-569A31?style=for-the-badge)
![MinIO](https://img.shields.io/badge/MinIO-C72E49?style=for-the-badge&logo=minio&logoColor=white)

- **PostgreSQL 16 · Amazon RDS**: 계정, 전략, 봇, 거래 원장과 실행 상태를 저장합니다.
- **Redis 7.4 · Valkey Serverless**: 시장 이벤트와 최신 상태를 관리합니다. 로컬에서는 Redis, AWS 환경에서는 Valkey를 사용합니다.
- **Amazon S3**: 시장 데이터·Parquet, 백테스트 결과와 프론트엔드 정적 파일을 보관합니다.
- **MinIO**: 로컬 개발에서 시장 데이터와 백테스트 결과를 저장하는 S3 호환 객체 저장소입니다.

### 인프라·협업

![AWS](https://img.shields.io/badge/AWS-232F3E?style=for-the-badge)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-844FBA?style=for-the-badge&logo=terraform&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=for-the-badge&logo=githubactions&logoColor=white)

버전은 저장소의 빌드·의존성 설정을 기준으로 정리했습니다. 서비스별 실행 방법은 각 저장소의 README와 [개발 시작 가이드](docs/development-start-guide.md)를 참고해 주세요.

## 프로젝트 아키텍처 🏛

### 사용자 이용 흐름

```mermaid
flowchart LR
    EDIT["블록으로 전략 작성"] --> CHECK["규칙 검증·버전 출시"]
    CHECK --> BOT["봇 생성"]
    BOT --> BACKTEST["자동 백테스트"]
    BOT --> LIVE["실시간 가상 거래"]
    BACKTEST --> REVIEW["결과·기록 확인"]
    LIVE --> REVIEW
    BOT --> ROOM["방 참여·봇 비교"]
    ROOM --> RANK["평가·리더보드"]
```

### 서비스 구성

| 저장소 | 주요 역할 |
| :--- | :--- |
| **root(현재 저장소)** | 제품 정의·계약, DBML, 인프라, Docker 실행 구성, 서브모듈 통합 |
| [ui](https://github.com/Idea2Strategy/Idea2Strategy-ui) | 전략 편집기, 봇 대시보드, 백테스트, 방·성과, 계정·운영 화면 |
| [backend](https://github.com/Idea2Strategy/Idea2Strategy-backend) | 사용자 API, 계정·권한, 전략·봇 제어, 방·성과, 운영 배치와 Admin MCP |
| [trading-engine](https://github.com/Idea2Strategy/Idea2Strategy-trading-engine) | 실시간 시세 수신, 지표·전략 평가, 가상 주문·체결, 포지션·원장 |
| [backtest-engine](https://github.com/Idea2Strategy/Idea2Strategy-backtest-engine) | 백테스트 API·워커, 과거 데이터 기반 전략 실행과 결과 생성 |
| [data-pipeline](https://github.com/Idea2Strategy/Idea2Strategy-data-pipeline) | 시장 데이터 수집·검증, 기업행사 처리, Parquet·Manifest 발행 |

### Development 인프라

[현재 Development 설계](docs/infrastructure/architecture.md)를 요약한 구성도입니다.

```mermaid
flowchart TB
    USER["사용자"] --> EDGE["Route 53 · CloudFront<br/>WAF · ACM"]
    EDGE --> FRONT["Private S3<br/>React 프론트엔드"]
    EDGE -->|"/api/* · /ws/*"| CORE["Core EC2<br/>사용자 API · 워커<br/>백테스트 조회"]
    CORE --> DB[("RDS PostgreSQL<br/>공식 상태 · 원장 · Manifest")]
    CORE --> QUEUE["SQS<br/>명령 · 백테스트 작업"]
    CORE --> CACHE[("Valkey Serverless<br/>시장 이벤트 · 최신 상태")]
    QUEUE --> BT["Backtest ASG<br/>백테스트 워커"]
    BT --> DB
    BT --> RESULTS[("S3<br/>백테스트 결과")]
    ALPACA["Alpaca 시장 데이터"] --> TRADING["Trading EC2<br/>시세 수신 · 전략 평가<br/>가상 체결"]
    TRADING --> CACHE
    TRADING --> DB
    ALPACA --> PIPELINE["Fargate Spot<br/>데이터 파이프라인"]
    PIPELINE --> MARKET[("S3<br/>과거 데이터 · Parquet")]
    PIPELINE --> DB
    MARKET --> BT
```

Core는 상시 실행하고, Trading은 시장 시간에 맞춰 실행합니다. 백테스트 워커는 ASG로 분리하며, 데이터 파이프라인은 작업이 있을 때 실행합니다. 공식 상태는 PostgreSQL에, 대용량 시장 데이터와 결과는 S3에 저장합니다.

### CI/CD

```mermaid
flowchart LR
    PR["Pull Request"] --> CI["GitHub Actions<br/>테스트 · 스키마 · 인프라 검증"]
    CI --> REVIEW["리뷰 후 develop 통합"]
    REVIEW --> RELEASE["Development 릴리스<br/>수동 실행"]
    RELEASE --> BUILD["서비스 이미지 · 프론트엔드 빌드"]
    BUILD --> ARTIFACT["ECR 이미지 digest<br/>S3 릴리스 경로 고정"]
    ARTIFACT --> PLAN["Terraform plan 생성·검토"]
    PLAN --> APPLY["승인한 plan 적용"]
    APPLY --> DEPLOY["서비스 배포 · 상태 검증"]
```

PR 검증은 [CI 워크플로](.github/workflows/ci.yml), 배포 절차는 [Development 릴리스](.github/workflows/development-release.yml)와 [프론트엔드 릴리스](.github/workflows/development-frontend-release.yml)에 정의되어 있습니다.
