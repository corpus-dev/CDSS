#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
export SCRIPT_DIR="$ROOT_DIR"
export OSARCH="$(uname -m)"
export RED=""
export GREEN=""
export ORANGE=""
export NC=""

source "$ROOT_DIR/utils/privileges.sh"
source "$ROOT_DIR/utils/platform_matrix.sh"
source "$ROOT_DIR/utils/translate.sh"
source "$ROOT_DIR/utils/definitions.sh"
source "$ROOT_DIR/utils/dialog.sh"
source "$ROOT_DIR/utils/datapatch.sh"
source "$ROOT_DIR/utils/scheduler.sh"
source "$ROOT_DIR/utils/updater.sh"
source "$ROOT_DIR/utils/runtime_environment.sh"
source "$ROOT_DIR/utils/mhddos.sh"
source "$ROOT_DIR/utils/distress.sh"
source "$ROOT_DIR/utils/x100.sh"

echo "WSL smoke"
echo "distro=$(get_distribution_id)"
echo "family=$(get_distribution_family)"
echo "init=$(get_init_system || true)"
echo "arch=$(get_normalized_arch)"
echo "support=$(get_platform_support_level)"

apply_localization --lang=en >/dev/null
validate_cron_schedule "0 20 * * *"
is_not_arm_arch || true

declare -F transf >/dev/null
declare -F force_sync_cdss >/dev/null
declare -F backup_module_settings >/dev/null
declare -F merge_environment_file >/dev/null
declare -F ensure_runtime_update_environment >/dev/null
declare -F repair_runtime >/dev/null

transf_out="$(transf "Hello %s" "WSL")"
if [[ "$transf_out" != "Hello WSL" ]]; then
  echo "smoke_wsl.sh: FAIL transf output: $transf_out"
  exit 1
fi

if [[ "$(get_module_readwrite_paths mhddos)" != "${SCRIPT_DIR} ${SCRIPT_DIR}/bin /var/log /tmp" ]]; then
  echo "smoke_wsl.sh: FAIL mhddos ReadWritePaths"
  exit 1
fi

if [[ "$(get_module_readwrite_paths x100)" != "${SCRIPT_DIR}/x100-for-docker /var/log /tmp" ]]; then
  echo "smoke_wsl.sh: FAIL x100 ReadWritePaths"
  exit 1
fi

grep -q '^ReadWritePaths=/opt/cybercorps /opt/cybercorps/bin /var/log /tmp$' "$ROOT_DIR/services/mhddos.service"
grep -q '^ReadWritePaths=/opt/cybercorps /opt/cybercorps/bin /var/log /tmp$' "$ROOT_DIR/services/distress.service"
grep -q '^ReadWritePaths=/opt/cybercorps/x100-for-docker /var/log /tmp$' "$ROOT_DIR/services/x100.service"

echo "smoke_wsl.sh: OK"
