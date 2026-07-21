# Git Flow design

Date: 2026-07-22
Status: approved correction

## Branch roles

- `develop` is the default and ongoing integration branch on GitHub and GitLab before the first complete release.
- Contributors create purpose-named `feature/*`, `fix/*`, `docs/*`, or `chore/*` branches and open pull/merge requests into `develop`.
- Direct work may not target `main` during pre-release development.
- `main` contains release history only. The first product merge into `main` occurs when the complete service is accepted as `v1.0.0`.
- A release pull/merge request targets `main` from the exact verified `develop` commit. The resulting `main` commit receives the matching semantic version tag.
- After `v1.0.0`, urgent production fixes use `hotfix/*` from `main`; the accepted result is merged into both `main` and `develop`.

## Repository-specific application

- GitHub keeps the root repository with the `ui` submodule. Its current `main` remains at `8d890b9bf553286171c0421a6c997dc2314005b7` until the first complete release.
- GitHub `develop` begins from the verified collaboration baseline. The temporary `feature/collaboration-harness` branch is removed after `develop` points to the same commit.
- GitLab keeps the monolithic workspace. Its verified monolithic commit moves to `develop`.
- The mistakenly published GitLab `main` is removed only after the self-managed GitLab project reports `develop` as its default branch.
- GitHub and GitLab use different commit IDs where the monolithic conversion changes the tree. Local sync metadata records the logical pair without storing credentials.

## Pull and merge request targets

- Ordinary GitHub pull requests and GitLab merge requests target `develop`.
- A request targeting `main` is valid only when it is explicitly a release or post-release hotfix.
- Automated suggestions must not use the hosting service's default target without checking this policy.

## Safe correction order

1. Update and verify the shared collaboration policy on the existing GitHub review branch.
2. Rename the clean GitHub worktree branch to `develop`, push it, and verify the remote SHA.
3. Remove the now-redundant temporary GitHub feature branch.
4. Apply the same policy commit to the GitLab monolithic workspace, rename its local branch to `develop`, and push it.
5. Change both hosting projects' default branches to `develop` using authenticated APIs without printing or persisting credentials.
6. Verify the GitLab default branch, then delete the mistaken GitLab `main` ref.
7. Verify GitHub `main` is unchanged, both default branches are `develop`, both workspaces are clean, and DBML/UI structure remains unchanged.

If either host refuses the default-branch change, stop before deleting any branch and require the project owner to change it in the web settings.
