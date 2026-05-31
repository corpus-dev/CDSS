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

echo "smoke_wsl.sh: OK"
