#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
export SCRIPT_DIR="$ROOT_DIR"

source "$ROOT_DIR/utils/translate.sh"
source "$ROOT_DIR/i18n/en.sh"

FAIL=0

fail() {
  echo "FAIL: $1"
  FAIL=1
}

if ! declare -F transf >/dev/null 2>&1; then
  fail "transf is not defined"
fi

single_out="$(transf "Hello %s" "world")"
if [[ "$single_out" != "Hello world" ]]; then
  fail "transf single placeholder failed: got '$single_out'"
fi

double_out="$(transf "%s and %s" "a" "b")"
if [[ "$double_out" != "a and b" ]]; then
  fail "transf multiple placeholders failed: got '$double_out'"
fi

files=("$ROOT_DIR/install.sh" "$ROOT_DIR/bin/cdss")
while IFS= read -r file; do
  files+=("$file")
done < <(
  find "$ROOT_DIR/utils" "$ROOT_DIR/menu" -type f -name '*.sh' -print | sort
)

re='(trans|transf) "[^"]*"'
missing=0
declare -A used_templates=()

for file in "${files[@]}"; do
  while IFS= read -r line; do
    if [[ "$line" =~ $re ]]; then
      match="${BASH_REMATCH[0]}"
      template="${match#*\"}"
      template="${template%\"*}"
      used_templates["$template"]=1
      if [[ -z "${localization[$template]:-}" ]]; then
        echo "MISSING: $template (in ${file#"$ROOT_DIR"/})"
        missing=1
      fi
    fi
  done < "$file"
done

if [[ "$missing" -ne 0 ]]; then
  fail "i18n key coverage failed"
fi

unused=0
for key in "${!localization[@]}"; do
  if [[ -z "${used_templates[$key]:-}" ]]; then
    echo "UNUSED: $key"
    unused=1
  fi
done

if [[ "$unused" -ne 0 ]]; then
  fail "i18n key coverage has unused keys"
fi

if grep -InE '(^|[^A-Za-z0-9_])trans "[^"]*\$' "${files[@]}" >/tmp/cdss_i18n_param_check.txt 2>/dev/null; then
  cat /tmp/cdss_i18n_param_check.txt
  fail "parameterized trans() calls still present; use transf()"
fi

if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi

echo "tests/i18n_coverage.sh: OK"
