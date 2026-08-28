#!/usr/bin/env bash
# 一键启用项目自带的 git pre-commit hook。
# 设置 git core.hooksPath 指向 scripts/hooks,以后该仓库的 git commit 自动跑检查。
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
git config core.hooksPath scripts/hooks
chmod +x scripts/hooks/pre-commit
echo "[setup] pre-commit hook 已启用 → scripts/hooks/pre-commit"
echo "[setup] 跳过方式: git commit --no-verify"
