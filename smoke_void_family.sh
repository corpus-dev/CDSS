#!/usr/bin/env bash
# smoke_void_family.sh — smoke test для Void Linux (runit)
# Викликати: bash smoke_void_family.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

RESULT_FILE="smoke_results/void_family.result"
mkdir -p "$(dirname "$RESULT_FILE")"

echo "=== Smoke Test: Void Linux ==="
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

PASS=0
FAIL=0

check() {
  local desc="$1"
  shift
  if "$@"; then
    echo -e "${GREEN}✓${NC} $desc"
    ((PASS++))
  else
    echo -e "${RED}✗${NC} $desc"
    ((FAIL++))
  fi
}

check "Distro ID = void" [[ "$DISTRO" == "void" ]]
check "Family = void" [[ "$FAMILY" == "void" ]]
check "Package manager = xbps-install" [[ "$PKG" == "xbps-install" ]]
check "Support level = partial" [[ "$SUPPORT" == "partial" ]]
check "Cron package = busybox-cron" [[ "$CRON_PKG" == "busybox-cron" ]]
check "Firewall = ufw" [[ "$FIREWALL" == "ufw" ]]
check "crontab available" command -v crontab >/dev/null 2>&1

if [[ "$INIT" == "runit" ]]; then
  check "Init = runit" true
  echo -e "${ORANGE}⚠${NC} Void uses runit — partial support (no service autostart)"
else
  check "Init != runit" true
fi

MHDDOS_ARCH=$(get_normalized_arch)
MHDDOS_INIT=$(get_init_system)
if tool_supports_platform "mhddos" "void" "$MHDDOS_ARCH" "$MHDDOS_INIT"; then
  echo -e "${GREEN}✓${NC} MHDDOS supported on this platform"
  ((PASS++))
else
  echo -e "${RED}✗${NC} MHDDOS NOT supported on this platform (void+runit limitation)"
  ((FAIL++))
fi

DISTRESS_ARCH=$(get_normalized_arch)
DISTRESS_INIT=$(get_init_system)
if tool_supports_platform "distress" "void" "$DISTRESS_ARCH" "$DISTRESS_INIT"; then
  echo -e "${GREEN}✓${NC} DISTRESS supported on this platform"
  ((PASS++))
else
  echo -e "${RED}✗${NC} DISTRESS NOT supported on this platform"
  ((FAIL++))
fi

X100_ARCH=$(get_normalized_arch)
X100_INIT=$(get_init_system)
if tool_supports_platform "x100" "void" "$X100_ARCH" "$X100_INIT"; then
  echo -e "${GREEN}✓${NC} X100 supported on this platform"
  ((PASS++))
else
  echo -e "${RED}✗${NC} X100 NOT supported on this platform (runtu ≠ systemd)"
  ((FAIL++))
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
  echo -e "${RED}Smoke test провалено для Void Linux (partial support confirmed).${NC}"
  exit 1
fi

echo -e "${GREEN}Smoke test підтверджено для Void Linux.${NC}"
exit 0
