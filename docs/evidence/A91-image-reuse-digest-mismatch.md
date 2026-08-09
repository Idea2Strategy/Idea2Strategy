# A91 — 이미지 재사용 경로의 digest 불일치 결함

A91 완료 증거가 **아니다**. 원장이 A91 을 완료로 세는 파일은 `docs/evidence/A91.md` 이고,
이 파일은 그 전에 고쳐야 할 결함 하나를 확정한 기록이다.

## 언제 · 어디서

- 2026-08-08. `.github/workflows/development-release.yml`, `build` 잡.
- 실패한 실행:
  [31249771785](https://github.com/Idea2Strategy/Idea2Strategy/actions/runs/31249771785)
- 같은 커밋에서 `force_rebuild_all_images=true` 로 통과한 실행:
  [31250145271](https://github.com/Idea2Strategy/Idea2Strategy/actions/runs/31250145271)

## 증상

`force_rebuild_all_images` 를 주지 않으면 `build` 가 실패한다.

```
Server-side reuse digest mismatch
```

위치는 `.github/workflows/development-release.yml:418`. 재사용 경로는 이전 성공 릴리스에서
바뀌지 않은 이미지를 다시 만들지 않고 그대로 승계하려 한다. 그 경로가 계산한 digest 와
레지스트리가 실제로 들고 있는 digest 가 어긋나 있었다.

## 무엇이 확실하고 무엇이 아직 아닌가

확실한 것: 같은 루트 커밋에서 `force_rebuild_all_images=true` 를 주면 아홉 개 이미지 전부
다시 빌드되고 `build` 가 성공한다. 즉 소스에는 문제가 없고, 실패는 **재사용 판정** 안에만
있다. 회피책이 있으므로 릴리스가 막히지는 않는다.

확실하지 않은 것: 왜 어긋났는지다. 후보는 두 가지다. 하나는 재사용 판정이 매니페스트
리스트(multi-arch index) 의 digest 와 단일 플랫폼 이미지의 digest 를 비교하는 경우 —
`arm64` 대상이 섞이면 두 값이 원래 다르다. 다른 하나는 이전 성공 릴리스 이후 ECR 수명주기
정책이 태그를 지워 승계 대상이 사라진 경우다. 로그만으로는 갈라내지 못했다.

## 2026-08-08 재현 — 이미지 이름이 나왔다

`force_rebuild_all_images=false` 로 올린 실행
[31258805821](https://github.com/Idea2Strategy/Idea2Strategy/actions/runs/31258805821) 에서
같은 실패가 재현되었고, 이번에는 어느 이미지인지 로그가 말한다.

```
Exception: .../ps1:56
  56 |  throw "Server-side reuse digest mismatch: $name/$tag"
     | Server-side reuse digest mismatch:
     | admin-mcp/rc-1010b5b7bcc2f7b24cb93bf03fda8755f72c9485-31258805821
```

같은 실행에서 `backtest-api`·`backtest-worker` 는 `Loaded image:` 까지 통과했고 ECR 로그인도
성공했다. 즉 자격증명·네트워크 문제가 아니고, **재사용 판정 자체**가 어긋난다.

`admin-mcp` 가 아홉 이미지 중 알파벳 첫 번째이므로 "admin-mcp 만의 문제" 라고 단정할 수는 없다 —
첫 번째에서 멈췄을 뿐일 수 있다. 다만 조사 시작점이 하나로 좁혀졌다: `admin-mcp` 의 기대 digest
와 관찰 digest 를 그 지점에서 찍어 보는 것이 §다음에 할 것 1번의 가장 짧은 형태다.

**재현이 두 번 모두 재사용 경로에서만 났다**는 것도 확인되었다. `force_rebuild_all_images=true`
로 올린 실행은 통과한다(31250145271, 31257037186). 그러므로 결함 범위는 재사용 판정에 한정되고
소스나 빌드에는 없다.

## 왜 회피책으로 끝내면 안 되는가

매번 전체 재빌드는 릴리스 한 번을 15분 이상 늘린다. 그것만이면 감수할 수 있다. 문제는
재사용 경로가 **틀린 digest 를 계산할 수 있다**는 사실 자체다. 지금은 불일치를 감지해
멈췄지만, 같은 계산이 우연히 일치하는 방향으로 틀리면 릴리스가 의도한 이미지가 아닌 것을
배포하고도 통과한다. A91 은 배포·복구·릴리스 파이프라인을 신뢰할 수 있다고 말하는 카드이고,
그 말을 하려면 이 비교가 왜 어긋났는지 알아야 한다.

## 다음에 할 것

1. `development-release.yml:400-430` 의 재사용 판정이 비교하는 두 값을 로그에 남긴다 —
   기대 digest, 관찰 digest, 그리고 그 값을 어느 API(`DescribeImages` 대 `BatchGetImage`,
   매니페스트 리스트 대 플랫폼 매니페스트)에서 읽었는지까지.
2. 아홉 이미지 각각에 대해 ECR 이 실제로 들고 있는 digest 를 조회해 어느 이미지가
   어긋났는지 특정한다. 전부인지 일부인지가 위 두 후보를 갈라낸다.
3. 원인이 매니페스트 리스트라면 비교 대상을 한쪽으로 고정한다. 수명주기 정책이라면
   재사용 승계 전에 태그 존재를 먼저 확인하고, 없으면 조용히 실패하지 않고 그 이미지만
   다시 빌드한다.
4. 고친 뒤 `force_rebuild_all_images` 없이 릴리스를 두 번 연속 통과시킨다. 두 번째가
   재사용 경로를 실제로 타는 실행이다.

---

# 2026-08-09 — 원인 확정. 후보 두 개 모두 아니었다

세 번째 재현이 났다(`force_rebuild_all_images=false`, 실행
[31293415523](https://github.com/Idea2Strategy/Idea2Strategy/actions/runs/31293415523),
`admin-mcp/rc-db3e333f483575eb5f2cf914cb54d5ba6b64fce9-31293415523`). 이번에는 릴리스를 또 올리는
대신, 그 비교를 **로컬에서 재현**했다. ECR 은 읽기만 했고 쓰지 않았다.

## 관측

`idea2strategy-dev/admin-mcp` 의 최신 태그에 대해, 워크플로가 하던 방식과 바이트를 보존하는 방식을
같은 매니페스트에 대해 나란히 해시했다.

```
registry digest = sha256:6a783df66035b6082e6271fdd955b7988906285f390173354010dae1683bd43f
워크플로 방식     = sha256:318ea06188daf703ffaff8429eb3e2a6f483fb29e81c45f3441f0902f9f233d6  bytes=1742  불일치
줄 재결합+UTF-8   = sha256:6a783df66035b6082e6271fdd955b7988906285f390173354010dae1683bd43f  bytes=1787  일치
줄 재결합+개행 1  = sha256:a6a4e8a158c09bf780df0d1c9296cc322b0a0b4de695529348d6de0ec9b96c6d  bytes=1788  불일치
```

## 원인

이미지 digest 는 **매니페스트 바이트의 SHA-256** 이다. ECR 이 돌려주는 매니페스트는 여러 줄로
정렬(pretty-print)되어 있고, 워크플로는 그것을

```powershell
aws ecr batch-get-image ... --output text | Set-Content -NoNewline $manifestPath
```

로 저장했다. PowerShell 파이프라인은 출력을 **줄 단위 문자열 배열**로 넘기고 `-NoNewline` 은 그
배열을 이어 붙일 때 구분자를 넣지 않는다. 그래서 줄 구분자 45개가 사라진 1742바이트가 파일에
남고, `put-image` 는 **재사용하려던 것과 다른 매니페스트**를 새 태그로 등록했다. 그 뒤의 digest
비교는 정확히 제 역할을 해서 그것을 거부한 것이다.

즉 비교가 틀린 것이 아니라, 비교 대상이 실제로 달랐다. 앞서 적어 둔 후보 두 개(매니페스트 리스트
digest 혼동, 수명주기 정책이 태그를 지움)는 **둘 다 아니었다.** 매니페스트는 단일 플랫폼
`application/vnd.docker.distribution.manifest.v2+json` 이고, 승계 대상 태그는 존재했다.

## 고침

`.github/workflows/development-release.yml` 의 재사용 경로가 매니페스트를 줄 배열로 받아
개행으로 다시 잇고 BOM 없이 쓴다. `Set-Content` 는 쓰지 않는다. 그리고 불일치 예외가 이제 양쪽
digest 와 원본 태그를 함께 말한다 — 한쪽만으로는 어느 쪽이 움직였는지 알 수 없었다.

`scripts/test-development-release-workflow.ps1` 가 그 모양을 고정한다. 이 검사는 고치기 전 파일에
대해 실제로 실패하는 것을 확인했다(회귀를 못 잡는 검사가 아니다).

## 남은 것

위 §다음에 할 것 4번만 남았다 — `force_rebuild_all_images` 없이 릴리스를 **두 번 연속** 통과시킨다.
두 번째 실행이 재사용 경로를 실제로 타는 실행이다. hjcud 의 INT03 1회 여정이 끝난 뒤에 예약한다
(릴리스 워크플로는 한 번에 한 사람, 루트 #451).

전체 재빌드가 릴리스마다 붙던 15분 이상은 이것으로 사라진다.
