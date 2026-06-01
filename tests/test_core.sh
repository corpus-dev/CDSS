#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
export SCRIPT_DIR="$ROOT_DIR"
export OSARCH="x86_64"
export RED=""
export GREEN=""
export ORANGE=""
export NC=""

source "$ROOT_DIR/utils/privileges.sh"
source "$ROOT_DIR/utils/platform_matrix.sh"
source "$ROOT_DIR/utils/translate.sh"
source "$ROOT_DIR/utils/definitions.sh"
source "$ROOT_DIR/utils/mhddos.sh"
source "$ROOT_DIR/menu/security_configuration.sh"

sudo_or_root() {
  "$@"
}

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="$3"
  [[ "$expected" == "$actual" ]] || fail "$message: expected '$expected', got '$actual'"
}

assert_success() {
  "$@" || fail "command failed: $*"
}

test_localization_parser() {
  assert_eq "$ROOT_DIR/i18n/en.sh" "$(apply_localization --lang en)" "--lang en"
  assert_eq "$ROOT_DIR/i18n/en.sh" "$(apply_localization --lang=en)" "--lang=en"
  assert_eq "" "$(apply_localization --lang uk)" "--lang uk fallback"
  assert_eq "" "$(apply_localization --lang)" "trailing --lang"
}

test_config_mutation() {
  local tmp_dir config
  tmp_dir=$(mktemp -d)
  config="$tmp_dir/EnvironmentFile"
  cat > "$config" <<'CONFIG_EOF'
[mhddos]
user-id=
[/mhddos]
CONFIG_EOF

  assert_success set_config_value "$config" "mhddos" "user-id" "123"
  assert_eq "123" "$(get_config_value "$config" "mhddos" "user-id")" "set_config_value updates existing key"

  assert_success ensure_config_section "$config" "x100"
  assert_success set_config_value "$config" "x100" "cron-to-run" "0 20 * * *"
  assert_eq "0 20 * * *" "$(get_config_value "$config" "x100" "cron-to-run")" "set_config_value creates section key"

  assert_success ensure_config_key "$config" "x100" "cron-to-stop" ""
  grep -q '^\[x100\]$' "$config" || fail "x100 section missing"
  rm -rf "$tmp_dir"
}

test_arch_predicates() {
  OSARCH="x86_64"
  is_not_arm_arch || fail "x86_64 should be not-arm"
  OSARCH="armv7l"
  if is_not_arm_arch; then
    fail "armv7l should be arm"
  fi
  OSARCH="x86_64"
}

test_privilege_helpers() {
  [[ -n "$(get_real_user)" ]] || fail "get_real_user returned empty"
  if is_root; then
    assert_success sudo_or_root true
  fi
}

test_security_menu_labels() {
  firewall_installed() { return 0; }
  firewall_is_active() { return 1; }
  fail2ban_installed() { return 0; }
  fail2ban_is_active() { return 1; }
  get_firewall_display_name() { echo "UFW"; }
  display_menu() {
    SECURITY_MENU_CAPTURE="$*"
    CDSS_SELECTION="$(trans "Повернутись назад")"
  }

  SECURITY_MENU_CAPTURE=""
  security_configuration
  [[ "$SECURITY_MENU_CAPTURE" == *"$(trans "Увімкнути фаєрвол")"* ]] || fail "security menu missing enable firewall"
  [[ "$SECURITY_MENU_CAPTURE" == *"$(trans "Увімкнути захист від брутфорсу")"* ]] || fail "security menu missing enable Fail2ban"
  [[ "$SECURITY_MENU_CAPTURE" != *"uufw"* ]] || fail "security menu contains uufw typo"
  [[ "$SECURITY_MENU_CAPTURE" != *"захит"* ]] || fail "security menu contains typo"
}

test_localization_parser
test_config_mutation
test_arch_predicates
test_privilege_helpers
test_security_menu_labels

echo "tests/test_core.sh: OK"
