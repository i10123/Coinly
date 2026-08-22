#!/usr/bin/env bash
# Бэкап-проверка безопасности перед коммитом.
# Не зависит от того, вспомнил ли основной агент вызвать security-reviewer сам.
set -uo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$REPO_ROOT" || exit 0

DIFF=$(git diff --cached)

if [ -z "$DIFF" ]; then
  exit 0
fi

# --- Классификация: "фича/чувствительное" vs "мелкая правка" ---

SENSITIVE_PATTERN='route|endpoint|controller|auth|login|password|token|session|payment|webhook|upload|admin|\.env|api[_-]?key|secret|sql|query|schema|cors|rls|supabase|firebase|role|permission'

FEATURE_CHANGE=0

if echo "$DIFF" | grep -qiE "$SENSITIVE_PATTERN"; then
  FEATURE_CHANGE=1
fi

CHANGED_LINES=$(echo "$DIFF" | grep -cE '^[+-][^+-]' || true)
if [ "${CHANGED_LINES:-0}" -gt 60 ]; then
  FEATURE_CHANGE=1
fi

NEW_FILES=$(git diff --cached --name-status | grep -cE '^A' || true)
if [ "${NEW_FILES:-0}" -gt 0 ]; then
  FEATURE_CHANGE=1
fi

if [ "$FEATURE_CHANGE" -eq 0 ]; then
  echo "[security-review] Мелкая правка, ревью пропущено."
  exit 0
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "[security-review] ⚠️  codex CLI не найден в PATH — не могу запустить независимую проверку."
  echo "    Изменение выглядит чувствительным (auth/payments/sql/upload/...)."
  echo "    Запусти ревью вручную или установи Codex CLI. Коммит НЕ заблокирован, но будь внимателен."
  exit 0
fi

echo "[security-review] Обнаружены чувствительные изменения — запускаю независимый security-reviewer..."

TMP_DIFF=$(mktemp)
echo "$DIFF" > "$TMP_DIFF"

PROMPT="Проверь приложенный diff по чек-листу security/CHECKLIST.md в этом репозитории. Diff:

$(cat "$TMP_DIFF")"

REPORT=$(codex exec --profile security-reviewer "$PROMPT" 2>&1)
STATUS=$?

rm -f "$TMP_DIFF"

echo "----------------------------------------"
echo "$REPORT"
echo "----------------------------------------"

if [ $STATUS -ne 0 ]; then
  echo "[security-review] ⚠️  Не удалось получить отчёт (ошибка запуска codex exec)."
  echo "    Коммит не заблокирован автоматически — но проверь вручную."
  exit 0
fi

if echo "$REPORT" | grep -qiE 'КРИТИЧНО|ВЫСОКИЙ|CRITICAL|HIGH'; then
  echo ""
  echo "❌ Найдены критичные/высокие проблемы безопасности. Коммит заблокирован."
  echo "   Исправь замечания выше и закоммить заново, либо запусти ревью вручную:"
  echo "   codex exec --profile security-reviewer \"...\""
  exit 1
fi

echo "✅ Критичных проблем не найдено."
exit 0
