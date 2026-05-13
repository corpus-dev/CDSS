#!/usr/bin/env bash
#
# scripts/check.sh — базова валiдацiя shell-коду
#
# Запускає:
#   1. bash -n для всiх .sh файлів
#   2. ShellCheck (якщо доступний)
#   3. Перевiряє наявнiсть config/scheduler/service helper-ів

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
ERRORS=0

echo "========================================"
echo "CDSS Shell Code Validation"
echo "========================================"
echo ""

# Крок 1: bash -n syntax check
echo "[1/3] Syntax check (bash -n)..."
echo "---"

while read -r file; do
  if bash -n "$file" 2>/dev/null; then
    echo "  OK: $file"
  else
    echo "  FAIL: $file"
    bash -n "$file" 2>&1 || true
    ((ERRORS++)) || true
  fi
done < <(find "$SCRIPT_DIR" -name "*.sh" -type f | sort)

echo ""

# Крок 2: ShellCheck (якщо доступний)
echo "[2/3] ShellCheck..."
echo "---"

if command -v shellcheck >/dev/null 2>&1; then
  while read -r file; do
    if shellcheck "$file" 2>/dev/null; then
      echo "  OK: $file"
    else
      echo "  WARN: $file (shellcheck found issues)"
      shellcheck "$file" 2>&1 || true
    fi
  done < <(find "$SCRIPT_DIR" -name "*.sh" -type f | sort)
else
  echo "  ShellCheck не встановлено. Запустіть: apt install shellcheck"
  echo "  Це НЕ повна перевiрка, але bash -n пройшов."
fi

echo ""

# Крок 3: Перевірка наявності helper-ів
echo "[3/3] Helper-coverage check..."
echo "---"

REQUIRED_HELPERS=(
  "assert_safe_script_dir"
  "safe_remove_path"
  "get_config_value"
  "set_config_value"
  "ensure_config_section"
  "ensure_config_key"
  "escape_for_execstart"
  "service_is_active"
  "service_start"
  "service_stop"
  "service_restart"
  "service_enable"
  "service_disable"
  "service_daemon_reload"
  "validate_cron_schedule"
  "cron_list"
  "cron_install_job"
  "cron_remove_job"
  "cron_has_job"
  "read_env_value"
  "write_env_value"
)

for helper in "${REQUIRED_HELPERS[@]}"; do
  if grep -rq "^${helper}()" "$SCRIPT_DIR" --include="*.sh" 2>/dev/null; then
    echo "  OK: $helper"
  else
    echo "  MISSING: $helper"
    ((ERRORS++)) || true
  fi
done

echo ""
echo "========================================"

if [[ "$ERRORS" -gt 0 ]]; then
  echo "RESULT: $ERRORS issues found"
  exit 1
else
  echo "RESULT: All checks passed"
  exit 0
fi
