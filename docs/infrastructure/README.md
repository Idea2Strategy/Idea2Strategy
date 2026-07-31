# 인프라 작업 기록

상태: **작업 중(Working Draft)**

이 디렉터리는 인프라 담당자가 질문, 조사 근거, 구조 제안, 팀 합의를 누적하는 작업 공간이다. 아직 합의되지 않은 내용을 운영 확정안처럼 다루지 않는다.

## 문서 지도

- [questions.md](questions.md): 열린 질문, 조사 결과, 다음 행동
- [architecture.md](architecture.md): 현재 제약과 인프라 구조 초안
- [backend-and-aws-architecture.md](backend-and-aws-architecture.md): 최신 Backend 리포·실행 App·AWS 3 EC2 배치 기준
- [architecture-diagrams.md](architecture-diagrams.md): 최신 구조도와 서버·RDS·S3 해설
- [aws-architecture-beginner-guide.md](aws-architecture-beginner-guide.md): 현재 구축·미구축 AWS 구성과 비전공자용 설명 가이드
- [decisions/README.md](decisions/README.md): 결정 기록(ADR) 작성 및 승인 규칙
- [decisions/template.md](decisions/template.md): 새 결정 기록 템플릿

## 문서의 권한

제품 정책과 계약의 정본은 `specs/**`, `contracts/**`, 정본 DBML에 있다. 이 디렉터리의 문서는 인프라 논의를 위한 작업 기록이며 정본을 대체하지 않는다.

문서 상태는 다음처럼 사용한다.

| 상태 | 의미 |
|---|---|
| Open | 답을 찾아야 하는 질문 |
| Investigating | 후보와 근거를 조사 중 |
| Proposed | 검토 가능한 제안이 작성됨 |
| Accepted | 팀이 결정했으며 근거와 영향이 기록됨 |
| Superseded | 더 새로운 결정으로 대체됨 |

`Accepted`로 바꿀 때는 승인자, 승인일, 근거, 영향, 롤백 방법을 기록한다. 보호된 정본의 변경이 필요한 결정은 저장소 거버넌스 승인을 별도로 거친다.

## 질의응답 운영 방식

1. 질문을 `questions.md`에 고유 ID로 등록한다.
2. 답변은 사실, 가정, 선택지를 구분하고 근거 링크를 남긴다.
3. 구조나 비용에 영향을 주는 선택은 ADR 초안을 만든다.
4. 팀 합의 전에는 ADR을 `Proposed`로 유지한다.
5. 결정 후 `architecture.md`와 관련 질문의 상태를 함께 갱신한다.

## 현재 범위

초기 논의 범위는 개발 환경, 실행 환경, 데이터 저장 경계, 네트워크·보안, 관측성, CI/CD, 백업·복구, 비용과 운영 책임이다. 실제 클라우드 리소스나 배포 구성은 해당 결정이 승인된 뒤 별도 변경으로 구현한다.

현재 목표 구조의 기준은 Core·Trading·Compute EC2 세 대다. 공개 진입점, Queue 제품과 Redis 운영 제품은 아직 결정하지 않았으며 기존 2 EC2·ALB·로컬 Redis 문서는 결정 이력으로만 본다.
