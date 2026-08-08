# INT06 장애·재기동·중복 전달 시험

- 실행 일시: 2026-08-09 (KST)
- 판정: **PASS**
- 루트 기준 커밋: `c264fb1d9e4ae4af62cd4c716f89c477563b36b6`
- trading-engine 기준 커밋: `bd43f5ff532d7879699fd8195be1dce2ff5d35c2`

## 검증 환경

로컬 Docker Desktop 29.6.2에서 Testcontainers 2.0.5를 사용했다. 실제 Redis
`7.4-alpine`과 PostgreSQL `17-alpine` 컨테이너를 기동해 테스트했으며, 캐시된
결과가 재사용되지 않도록 Gradle의 `--rerun-tasks` 옵션을 적용했다.

## 실행 명령

`trading-engine` 서브모듈에서 다음 명령을 실행했다.

```powershell
.\gradlew.bat :apps:trading-worker:test --tests com.idea2strategy.trading.worker.market.MarketEventStreamE2ETest --tests com.idea2strategy.trading.worker.runtime.EvaluationLoopE2ETest --tests com.idea2strategy.trading.worker.control.BotControlIntegrationE2ETest --tests com.idea2strategy.trading.worker.runtime.BasicMarketSignalStateTest.tradingDayIndexSurvivesARestart --rerun-tasks --no-daemon --console=plain
```

```powershell
.\gradlew.bat :modules:trading-persistence:test --tests com.idea2strategy.trading.persistence.e2e.FBundleRestartRecoveryE2ETest.restartAndRedeliveryLeaveTheSameOfficialState --rerun-tasks --no-daemon --console=plain
```

## 결과

| 테스트 묶음 | 통과 | 실패 | 건너뜀 |
| --- | ---: | ---: | ---: |
| `MarketEventStreamE2ETest` | 7 | 0 | 0 |
| `EvaluationLoopE2ETest` | 11 | 0 | 0 |
| `BotControlIntegrationE2ETest` | 8 | 0 | 0 |
| `tradingDayIndexSurvivesARestart` | 1 | 0 | 0 |
| `restartAndRedeliveryLeaveTheSameOfficialState` | 1 | 0 | 0 |
| **합계** | **28** | **0** | **0** |

두 Gradle 실행은 각각 `BUILD SUCCESSFUL`로 끝났고, 선택한 28개 테스트가 모두
실제로 다시 실행됐다.

## 확인한 장애 시나리오와 불변 조건

| 시나리오 | 관찰한 결과 | 대표 테스트 |
| --- | --- | --- |
| 소비자 처리 도중 replica가 사라져 Redis pending entry가 남음 | 다른 replica가 entry를 회수해 최종 주문이 정확히 하나로 수렴함 | `anEntryLeftPendingByADeadReplicaIsReclaimedAndConvergesOnOneOrder` |
| 해석할 수 없거나 반복 실패하는 시장 이벤트 | 해석 불가 entry는 유실되지 않고 pending 상태를 유지하며, poison entry는 설정된 재시도 횟수 뒤 dead-letter stream으로 이동함 | `anUndecodableEntryIsLeftPendingRatherThanLost`, `aPoisonEntryMovesToTheDeadLetterStreamAfterTheConfiguredAttempts` |
| 이미 확인한 시장 이벤트가 다시 전달됨 | 확인 완료 entry는 재전달되지 않고, 늦거나 중복된 이벤트도 공식 상태를 바꾸지 않음 | `anAcknowledgedEntryIsNotDeliveredAgain`, `aRedeliveredOrLateMarketEventChangesNothing` |
| worker 재기동 뒤 동일 시장 이벤트 재전달 | 평가·batch·intent·order·reservation이 중복 생성되지 않고 canonical effect가 하나로 유지됨 | `aMarketEventRedeliveredAfterProcessRestartHasOneCanonicalEffect` |
| worker 재기동 뒤 one-shot 실행 한도 복구 | canonical intent로부터 실행 한도를 복원해 추가 실행을 차단함 | `workerRestartRestoresTheOneShotExecutionLimitFromCanonicalIntents` |
| bot 제어 명령의 lease 만료·중복·순서 역전 | 만료 lease의 재전달은 새 상태를 쓰지 않고, stop은 한 번만 정산되며 뒤늦은 run이 bot을 되살리지 않음 | `aRunCommandRedeliveredAfterALapsedLeaseWritesNothingNew`, `aSecondStopCommandSettlesOnlyOnce`, `aRunCommandArrivingAfterTheStopDoesNotReviveTheBot` |
| 프로세스 재기동 뒤 거래일 및 F-bundle 상태 복구 | 거래일 인덱스가 유지되고 주문·체결·예약·원장이 재전달 전후 동일함 | `tradingDayIndexSurvivesARestart`, `restartAndRedeliveryLeaveTheSameOfficialState` |

## 결론과 범위

INT06에서 요구한 기능 수준의 장애·재기동·중복 전달 검증은 통과했다. 발견된
소스 결함은 없었으며, 이번 작업에는 제품 코드 변경이 필요하지 않았다.

이 증빙은 로컬 컨테이너 환경에서 Redis/PostgreSQL을 실제로 사용한 결정적
통합시험 결과다. AWS/EC2 인스턴스 강제 종료, 노드 자체 유실, 운영 백업 복구,
성능·부하 시험까지 통과했다고 주장하지 않는다. 해당 범위는 별도의 운영 복구 및
성능 준비 작업에서 검증해야 한다.
