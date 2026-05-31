#!/usr/bin/env bash
# smoke_arch_family.sh — smoke test для Arch-family (Arch/Manjaro)
# Викликати: bash smoke_arch_family.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

RESULT_FILE="smoke_results/arch_family.result"
mkdir -p "$(dirname "$RESULT_FILE")"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/utils/privileges.sh"
source "$SCRIPT_DIR/utils/platform_matrix.sh"
source "$SCRIPT_DIR/utils/definitions.sh"

sudo_or_root() {
  "$@"
}

echo "=== Smoke Test: Arch Family ==="
echo ""

DISTRO=$(get_distribution_id 2>/dev/null || echo "unknown")
FAMILY=$(get_distribution_family 2>/dev/null || echo "unknown")
INIT=$(get_init_system 2>/dev/null || echo "unknown")
ARCH=$(get_normalized_arch 2>/dev/null || echo "unknown")
PKG=$(get_package_manager 2>/dev/null || echo "unknown")
SUPPORT=$(get_platform_support_level 2>/dev/null || echo "unknown")
CRON_PKG=$(get_cron_package_name 2>/dev/null || echo "unknown")
CRON_SVC=$(get_cron_service_name 2>/dev/null || echo "unknown")
FIREWALL=$(get_firewall_backend 2>/dev/null || echo "unknown")
export DISTRO FAMILY INIT ARCH PKG SUPPORT CRON_PKG CRON_SVC FIREWALL

PASS=0
FAIL=0

check() {
  local desc="$1"
  shift
  if "$@"; then
    echo -e "${GREEN}✓${NC} $desc"
    ((PASS+=1))
  else
    echo -e "${RED}✗${NC} $desc"
    ((FAIL+=1))
  fi
}

check "Distro ID" bash -c '[[ "$DISTRO" =~ ^(arch|manjaro)$ ]]'
check "Family = arch" bash -c '[[ "$FAMILY" == "arch" ]]'
check "Init = systemd" bash -c '[[ "$INIT" == "systemd" ]]'
check "Package manager = pacman" bash -c '[[ "$PKG" == "pacman" ]]'
check "Support level = full" [[ "$SUPPORT" == "full" ]]
check "Cron package = cronie" [[ "$CRON_PKG" == "cronie" ]]
check "Cron service = crond" [[ "$CRON_SVC" == "crond" ]]
check "Firewall = ufw" [[ "$FIREWALL" == "ufw" ]]
check "crontab available" command -v crontab >/dev/null 2>&1

MHDDOS_ARCH=$(get_normalized_arch)
MHDDOS_INIT=$(get_init_system)
if tool_supports_platform "mhddos" "arch" "$MHDDOS_ARCH" "$MHDDOS_INIT"; then
  echo -e "${GREEN}✓${NC} MHDDOS supported on this platform"
  ((PASS+=1))
else
  echo -e "${RED}✗${NC} MHDDOS NOT supported on this platform"
  ((FAIL+=1))
fi

DISTRESS_ARCH=$(get_normalized_arch)
DISTRESS_INIT=$(get_init_system)
if tool_supports_platform "distress" "arch" "$DISTRESS_ARCH" "$DISTRESS_INIT"; then
  echo -e "${GREEN}✓${NC} DISTRESS supported on this platform"
  ((PASS+=1))
else
  echo -e "${RED}✗${NC} DISTRESS NOT supported on this platform"
  ((FAIL+=1))
fi

echo ""
echo "Результат: ${GREEN}$PASS${NC} пройдено, ${RED}$FAIL${NC} провалено"

cat > "$RESULT_FILE" <<EOF
distro=$DISTRO
family=$FAMILY
init=$INIT
arch=$ARCH
pkg=$PKG
support=$SUPPORT
cron_pkg=$CRON_PKG
cron_svc=$CRON_SVC
firewall=$FIREWALL
pass=$PASS
fail=$FAIL
date=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

echo "Result saved to $RESULT_FILE"

if [[ $FAIL -gt 0 ]]; then
  echo -e "${RED}Smoke test провалено для Arch-family.${NC}"
  exit 1
fi

echo -e "${GREEN}Smoke test підтверджено для Arch-family.${NC}"
exit 0
