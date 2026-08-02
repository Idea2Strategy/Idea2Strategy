# COM A-13/A-15/A-17/A-19 canonical 적용 요청

담당 제품 권한자: `user:kcrmin`

연결 이슈:

- COM A-13: [#130](https://github.com/Idea2Strategy/Idea2Strategy/issues/130)
- COM A-15: [#128](https://github.com/Idea2Strategy/Idea2Strategy/issues/128)
- COM A-17: [#129](https://github.com/Idea2Strategy/Idea2Strategy/issues/129)
- COM A-19: [#132](https://github.com/Idea2Strategy/Idea2Strategy/issues/132)

## 요청 목적

아래 네 proposal은 제품 권한자의 의미 결정과 DBML hold 해제 답변을 받았고, 격리된 proposal 경로에서 검증되었습니다. 이 PR은 보호된 canonical 파일을 비권한자가 직접 수정하지 않으면서, 제품 권한자가 동일 PR 브랜치에 canonical 적용 커밋을 추가하고 최종 HEAD를 GitHub에서 검토·승인할 수 있도록 만드는 작업 요청입니다.

이 문서 자체는 `db/schema.dbml`, `contracts/**`, `specs/**`를 변경하지 않으며 canonical 적용 완료를 주장하지 않습니다.

## 승인된 proposal 기준

| 항목 | proposal exact commit | proposal 경로 | 승인 이슈 |
| --- | --- | --- | --- |
| A-13 운영자 RBAC | `1c5f00becb3bd769248ed03060ef483a3dbf37de` | `proposals/operator-rbac/` | #130 |
| A-15 위임 Strategy scope | `7cfbba5648435b22ca4cdc7b41cfb44bac2048ba` | `proposals/delegated-strategy-scope/` | #128 |
| A-17 transactional outbox | `52870121a008bb90d980c1b46c208f7127f0a25b` | `proposals/com-a17-outbox-contract/` | #129 |
| A-19 사용자 사건함 | `b7e2142b9315df1fd0cdf318f4b5ae50bcfa7e41` | `proposals/com-a19-case-contract/` | #132 |

proposal 브랜치를 rebase하거나 force-push하지 않고 위 exact commit을 검토 기준으로 유지합니다.

## `kcrmin`에게 요청하는 작업

1. 이 PR 브랜치 `codex/com-a13-a19-authority-review`를 checkout합니다.
2. 각 proposal의 `schema.draft.dbml`과 proposal 기준 canonical DBML의 차이만 현재 `db/schema.dbml`에 적용합니다.
3. 아래 계약을 canonical `contracts/**` 경로에 등록합니다.
   - `contract.operations.operator-rbac.v1`
   - `contract.identity.delegated-strategy-scope.v1`
   - `contract.operations.transactional-outbox.v1`
   - `contract.operations.user-case.v1`
4. proposal validator가 canonical 경로를 검증하도록 전환하고 root 검증을 실행합니다.
5. canonical 적용 커밋을 이 PR 브랜치에 직접 push합니다.
6. 반드시 canonical 커밋이 포함된 최종 HEAD를 다시 확인한 뒤 GitHub `Approve` 리뷰를 제출하고 merge합니다.

PR의 최초 문서-only HEAD에 대한 승인만으로 canonical 변경을 승인한 것으로 간주하지 않습니다. canonical 파일이 추가된 뒤 변경된 최종 HEAD에 대한 리뷰가 필요합니다.

## 필수 검증

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/initialize-local-harness.ps1 -Verify
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-collaboration-policy.ps1
npm.cmd run dbml:validate
npm.cmd run dbml:validate:a12
stackcord contract check
stackcord contract impact --json
stackcord context audit --json
```

proposal별 validator와 root CI도 모두 통과해야 합니다. 중앙 DBML은 네 proposal의 additive delta를 합친 뒤 테이블·열·참조·인덱스 중복과 현재 `develop` 대비 차이를 다시 검증합니다.

## 후속 병합 순서

1. 이 PR에서 canonical DBML·계약 적용 및 제품 권한자 최종 HEAD 승인
2. backend A-13, A-15, A-17 기반 PR
3. backend A-14, A-16, A-18, A-19
4. A-20 → A-21 → A-22
5. UI A-23

canonical PR이 merge되기 전까지 backend 후보 브랜치는 구현·검증 준비 상태이며 merge 대상으로 표시하지 않습니다.
