# Git hooks

零依赖的 git hooks,放在 `scripts/hooks/`,通过 `git config core.hooksPath` 启用。

## pre-commit

改动 `frontend-react/**` → 跑 `oxlint` + `tsc -b`
改动 `backend/**` → 跑 `tsc --noEmit`

任一失败 → 阻止 commit,需修复后重试。

## 启用(每个 clone 跑一次)

```bash
./scripts/hooks/install.sh
```

或者手动:

```bash
git config core.hooksPath scripts/hooks
chmod +x scripts/hooks/pre-commit
```

## 跳过(紧急情况)

```bash
git commit --no-verify
```
