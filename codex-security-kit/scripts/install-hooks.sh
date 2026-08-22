#!/usr/bin/env bash
# Устанавливает security-precommit.sh как git pre-commit хук в текущем репозитории.
set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "Это не git-репозиторий (или git не найден). Запусти внутри проекта после 'git init'."
  exit 1
}

SRC="$REPO_ROOT/scripts/security-precommit.sh"
DEST="$REPO_ROOT/.git/hooks/pre-commit"

if [ ! -f "$SRC" ]; then
  echo "Не найден $SRC — убедись, что скрипт лежит в scripts/security-precommit.sh"
  exit 1
fi

cp "$SRC" "$DEST"
chmod +x "$DEST"

echo "✅ Хук установлен: $DEST"
echo "   Теперь при 'git commit' чувствительные изменения будут автоматически проверяться."
