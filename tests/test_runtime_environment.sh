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
source "$ROOT_DIR/utils/updater.sh"
source "$ROOT_DIR/utils/runtime_environment.sh"

sudo_or_root() {
  "$@"
}

log_cdss_event() {
  :
}

cdss_dialog() {
  echo "$*"
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

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

make_base_service_file() {
  local target="$1"
  local module="$2"
  local exec_start="/bin/true"

  if [[ "$module" == "mhddos" ]]; then
    exec_start="${SCRIPT_DIR}/bin/mhddos_proxy_linux --placeholder"
  elif [[ "$module" == "distress" ]]; then
    exec_start="${SCRIPT_DIR}/bin/distress --placeholder"
  else
    exec_start="/bin/true"
  fi

  cat > "$target" <<EOF
[Unit]
Description=CDSS ${module} test service
After=network.target

[Service]
Type=simple
User=cdss
ExecStart=${exec_start}
Restart=on-failure
NoNewPrivileges=true
ProtectSystem=strict

[Install]
WantedBy=multi-user.target
ReadWritePaths=/var/log /tmp
EOF
}

test_module_paths() {
  assert_eq "${SCRIPT_DIR} ${SCRIPT_DIR}/bin /var/log /tmp" "$(get_module_readwrite_paths mhddos)" "mhddos ReadWritePaths"
  assert_eq "${SCRIPT_DIR} ${SCRIPT_DIR}/bin /var/log /tmp" "$(get_module_readwrite_paths distress)" "distress ReadWritePaths"
  assert_eq "${SCRIPT_DIR}/x100-for-docker /var/log /tmp" "$(get_module_readwrite_paths x100)" "x100 ReadWritePaths"
}

test_validate_service_file() {
  local svc_dir="$TMP_DIR/validate"
  mkdir -p "$svc_dir"
  local old_script_dir="$SCRIPT_DIR"
  SCRIPT_DIR="$svc_dir"

  make_base_service_file "$svc_dir/mhddos.service" "mhddos"
  sed -i "s|^ReadWritePaths=.*|ReadWritePaths=${SCRIPT_DIR} ${SCRIPT_DIR}/bin /var/log /tmp|" "$svc_dir/mhddos.service"

  assert_success validate_service_file "$svc_dir/mhddos.service" "mhddos"

  sed -i "s|^ReadWritePaths=.*|ReadWritePaths=/var/log /tmp|" "$svc_dir/mhddos.service"
  if validate_service_file "$svc_dir/mhddos.service" "mhddos"; then
    fail "validate_service_file accepted non-canonical ReadWritePaths"
  fi

  SCRIPT_DIR="$old_script_dir"
}

test_service_file_set_directive() {
  local svc_dir="$TMP_DIR/set_directive"
  mkdir -p "$svc_dir"
  local old_script_dir="$SCRIPT_DIR"
  SCRIPT_DIR="$svc_dir"
  export CDSS_SERVICE_BACKUP_DIR="$TMP_DIR/service-backups"

  make_base_service_file "$svc_dir/distress.service" "distress"
  assert_success service_file_set_directive "$svc_dir/distress.service" "ReadWritePaths" "${SCRIPT_DIR} ${SCRIPT_DIR}/bin /var/log /tmp"
  assert_eq "${SCRIPT_DIR} ${SCRIPT_DIR}/bin /var/log /tmp" "$(grep -m1 '^ReadWritePaths=' "$svc_dir/distress.service" | cut -d'=' -f2-)" "ReadWritePaths updated"

  SCRIPT_DIR="$old_script_dir"
}

test_backup_and_merge_environment_file() {
  local runtime_dir="$TMP_DIR/runtime"
  local backup_dir="$TMP_DIR/backup"
  mkdir -p "$runtime_dir/services" "$backup_dir"
  local old_script_dir="$SCRIPT_DIR"
  SCRIPT_DIR="$runtime_dir"
  export CDSS_BACKUP_DIR="$backup_dir"

  cat > "$runtime_dir/services/EnvironmentFile" <<'EOF'
[mhddos]
user-id=old-value
EOF

  assert_success backup_module_settings
  [[ -f "$backup_dir/EnvironmentFile" ]] || fail "backup EnvironmentFile missing"
  assert_eq "old-value" "$(get_config_value "$backup_dir/EnvironmentFile" "mhddos" "user-id")" "backup value"

  cat > "$backup_dir/EnvironmentFile" <<'EOF'
[mhddos]
user-id=restored-value
EOF

  assert_success merge_environment_file
  assert_eq "restored-value" "$(get_config_value "$runtime_dir/services/EnvironmentFile" "mhddos" "user-id")" "merged value"

  SCRIPT_DIR="$old_script_dir"
}

test_ensure_module_service_policy() {
  local runtime_dir="$TMP_DIR/policy"
  mkdir -p "$runtime_dir/services"
  local old_script_dir="$SCRIPT_DIR"
  SCRIPT_DIR="$runtime_dir"
  export CDSS_SERVICE_BACKUP_DIR="$TMP_DIR/policy-backups"

  make_base_service_file "$runtime_dir/services/mhddos.service" "mhddos"
  make_base_service_file "$runtime_dir/services/distress.service" "distress"

  local status=0
  ensure_module_service_policy || status=$?
  assert_eq "0" "$status" "ensure_module_service_policy should report changes"

  assert_eq "${SCRIPT_DIR} ${SCRIPT_DIR}/bin /var/log /tmp" "$(grep -m1 '^ReadWritePaths=' "$runtime_dir/services/mhddos.service" | cut -d'=' -f2-)" "mhddos policy ReadWritePaths"
  assert_eq "${SCRIPT_DIR} ${SCRIPT_DIR}/bin /var/log /tmp" "$(grep -m1 '^ReadWritePaths=' "$runtime_dir/services/distress.service" | cut -d'=' -f2-)" "distress policy ReadWritePaths"

  status=0
  ensure_module_service_policy || status=$?
  assert_eq "1" "$status" "ensure_module_service_policy should report no further changes"

  SCRIPT_DIR="$old_script_dir"
}

test_ensure_module_runtime_permissions() {
  local runtime_dir="$TMP_DIR/permissions"
  mkdir -p "$runtime_dir/bin" "$runtime_dir/x100-for-docker"
  local old_script_dir="$SCRIPT_DIR"
  SCRIPT_DIR="$runtime_dir"

  echo "#!/usr/bin/env bash" > "$runtime_dir/bin/mhddos_proxy_linux"
  echo "#!/usr/bin/env bash" > "$runtime_dir/bin/distress"
  echo "#!/usr/bin/env bash" > "$runtime_dir/x100-for-docker/script.bash"
  chmod 600 "$runtime_dir/bin/mhddos_proxy_linux" "$runtime_dir/bin/distress" "$runtime_dir/x100-for-docker/script.bash"

  assert_success ensure_module_runtime_permissions

  [[ -x "$runtime_dir/bin/mhddos_proxy_linux" ]] || fail "mhddos_proxy_linux not executable"
  [[ -x "$runtime_dir/bin/distress" ]] || fail "distress not executable"
  [[ -x "$runtime_dir/x100-for-docker/script.bash" ]] || fail "x100 script.bash not executable"

  SCRIPT_DIR="$old_script_dir"
}

test_repair_runtime_non_systemd() {
  local old_get_init_system
  old_get_init_system="$(declare -f get_init_system)"
  get_init_system() {
    echo "openrc"
  }

  local output
  output="$(repair_runtime)"
  eval "$old_get_init_system"

  [[ "$output" == *"only supported on systemd"* || "$output" == *"підтримується тільки на systemd"* ]] || fail "repair_runtime non-systemd message missing: $output"
}

test_force_sync_cdss() {
  if ! command -v git >/dev/null 2>&1; then
    echo "SKIP: git not available"
    return 0
  fi

  local tmp="$TMP_DIR/git"
  local origin="$tmp/origin.git"
  local stale_origin="$tmp/stale-origin.git"
  local work="$tmp/work"
  local upstream="$tmp/upstream"
  mkdir -p "$tmp"

  export GIT_CONFIG_GLOBAL="$tmp/gitconfig"
  export GIT_CONFIG_SYSTEM="/dev/null"
  git config --global user.email "test@example.com"
  git config --global user.name "CDSS Test"
  git config --global init.defaultBranch main

  git init --bare "$origin" >/dev/null 2>&1
  git init --bare "$stale_origin" >/dev/null 2>&1
  git init "$work" >/dev/null 2>&1
  git -C "$work" checkout -b main >/dev/null 2>&1

  mkdir -p "$work/bin" "$work/services" "$work/utils" "$work/menu"
  echo "# CDSS" > "$work/README.md"
  echo "#!/usr/bin/env bash" > "$work/bin/cdss"
  echo "[mhddos]" > "$work/services/EnvironmentFile"
  echo "# utils" > "$work/utils/placeholder"
  echo "# menu" > "$work/menu/placeholder"

  git -C "$work" add -A
  git -C "$work" commit -m "initial" >/dev/null 2>&1
  git -C "$work" remote add origin "$stale_origin"
  git -C "$work" push origin main >/dev/null 2>&1
  git -C "$work" push "$origin" main >/dev/null 2>&1

  git clone "$origin" "$upstream" >/dev/null 2>&1
  echo "upstream-update" >> "$upstream/README.md"
  git -C "$upstream" commit -am "upstream update" >/dev/null 2>&1
  git -C "$upstream" push origin main >/dev/null 2>&1

  echo "local-dirty-change" >> "$work/README.md"

  local old_script_dir="$SCRIPT_DIR"
  SCRIPT_DIR="$work"
  export CDSS_BACKUP_DIR="$tmp/backup"
  export CDSS_GIT_URL="$origin"
  mkdir -p "$CDSS_BACKUP_DIR"

  assert_success force_sync_cdss

  grep -q "upstream-update" "$work/README.md" || fail "force_sync_cdss did not apply upstream change"
  if grep -q "local-dirty-change" "$work/README.md"; then
    fail "force_sync_cdss did not discard local dirty change"
  fi

  local dirty
  dirty="$(git -C "$work" status --porcelain)"
  assert_eq "" "$dirty" "worktree should be clean after force_sync_cdss"

  SCRIPT_DIR="$old_script_dir"
}

test_ensure_canonical_update_sources() {
  local tmp="$TMP_DIR/canonical-sources"
  local work="$tmp/work"
  local local_origin="$tmp/local-origin.git"
  mkdir -p "$tmp"

  git init --bare "$local_origin" >/dev/null 2>&1
  git init "$work" >/dev/null 2>&1
  git -C "$work" checkout -b main >/dev/null 2>&1
  git -C "$work" config user.email "test@example.com"
  git -C "$work" config user.name "CDSS Test"

  echo "test" > "$work/README.md"
  git -C "$work" add -A
  git -C "$work" commit -m "initial" >/dev/null 2>&1
  git -C "$work" remote add origin "$local_origin"
  git -C "$work" push origin main >/dev/null 2>&1

  local old_script_dir="$SCRIPT_DIR"
  local old_cdss_git_url="${CDSS_GIT_URL:-}"
  SCRIPT_DIR="$work"
  export CDSS_GIT_URL="https://github.com/corpus-dev/CDSS.git"

  assert_success ensure_canonical_update_sources
  assert_eq "https://github.com/corpus-dev/CDSS.git" "$(git -C "$work" remote get-url origin)" "local origin replaced with canonical upstream"

  if [[ -n "$old_cdss_git_url" ]]; then
    export CDSS_GIT_URL="$old_cdss_git_url"
  else
    unset CDSS_GIT_URL
  fi
  SCRIPT_DIR="$old_script_dir"
}

test_ensure_cdss_update_cron() {
  local calls=0
  cron_has_job() {
    return 1
  }
  cron_install_job() {
    calls=$((calls + 1))
    [[ "$2" == "*/5 * * * *" ]] && [[ "$3" == *"--update-only"* ]]
  }

  assert_success ensure_cdss_update_cron
  assert_eq "1" "$calls" "update-only cron installed"

  unset -f cron_has_job cron_install_job
}

test_ensure_git_update_config() {
  if ! command -v git >/dev/null 2>&1; then
    echo "SKIP: git not available"
    return 0
  fi

  local tmp="$TMP_DIR/git-update-config"
  mkdir -p "$tmp"

  local old_git_config_global="${GIT_CONFIG_GLOBAL:-}"
  local old_git_config_system="${GIT_CONFIG_SYSTEM:-}"
  export GIT_CONFIG_GLOBAL="$tmp/gitconfig"
  export GIT_CONFIG_SYSTEM="/dev/null"

  assert_success ensure_git_update_config
  assert_eq "true" "$(git config --global pull.autostash)" "pull.autostash enabled"

  if [[ -n "$old_git_config_global" ]]; then
    export GIT_CONFIG_GLOBAL="$old_git_config_global"
  else
    unset GIT_CONFIG_GLOBAL
  fi
  if [[ -n "$old_git_config_system" ]]; then
    export GIT_CONFIG_SYSTEM="$old_git_config_system"
  else
    unset GIT_CONFIG_SYSTEM
  fi
}

test_module_paths
test_validate_service_file
test_service_file_set_directive
test_backup_and_merge_environment_file
test_ensure_module_service_policy
test_ensure_module_runtime_permissions
test_repair_runtime_non_systemd
test_ensure_canonical_update_sources
test_ensure_cdss_update_cron
test_ensure_git_update_config
test_force_sync_cdss

echo "tests/test_runtime_environment.sh: OK"
