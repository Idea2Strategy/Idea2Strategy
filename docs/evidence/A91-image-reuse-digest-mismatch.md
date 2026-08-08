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
