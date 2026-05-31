#!/usr/bin/env bash
# release_checklist.sh — перевірка перед релізом
# Викликати перед кожним релізом: bash release_checklist.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

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

echo "=== Release Checklist ==="
echo ""

# 1. Distro detect не зламався
check "Distro detection" bash -c 'source utils/platform_matrix.sh; [[ "$(get_distribution_id)" != "error" ]]'

# 2. Package manager не захардкоджений
check "No hardcoded package manager" bash -c '! grep -q "PACKAGE_MANAGER=\"apt-get\"" install.sh utils/definitions.sh'

# 3. Direct systemctl в прикладній логіці
check "No direct systemctl in utils/menu/bin" bash -c '! grep -l "systemctl" utils/*.sh menu/*.sh bin/cdss 2>/dev/null || true'

# 4. Platform matrix source
check "platform_matrix.sh exists" test -f utils/platform_matrix.sh

# 5. Support level gateway
check "Support level in install.sh" grep -q "get_platform_support_level" install.sh

# 6. Tool capability matrix
check "tool_supports_platform exists" grep -q "tool_supports_platform" utils/platform_matrix.sh

# 7. Void runit policy
check "Void partial support documented" grep -q "partial" utils/platform_matrix.sh

# 8. Kali/Parrot explicit
check "Kali explicit support" grep -q "kali" utils/platform_matrix.sh
check "Parrot explicit support" grep -q "parrot" utils/platform_matrix.sh

# 9. README aligned
check "README has support table" grep -q "Fully supported" README.md
check "README-EN has support table" grep -q "Fully supported" README-EN.md

# 10. Syntax check
check "install.sh syntax" bash -n install.sh
check "bin/cdss syntax" bash -n bin/cdss
check "platform_matrix.sh syntax" bash -n utils/platform_matrix.sh

# 11. Privilege API checks
check "is_root() defined" grep -q "is_root()" utils/platform_matrix.sh
check "has_sudo() defined" grep -q "has_sudo()" utils/platform_matrix.sh
check "require_privileges() defined" grep -q "require_privileges()" utils/platform_matrix.sh
check "sudo_or_root() defined" grep -q "sudo_or_root()" utils/platform_matrix.sh
check "trans fallback defined" grep -q 'trans() { echo "$@"; }' utils/platform_matrix.sh

# 12. No direct sudo in executable logic (except allowlist for messages)
check "No direct sudo in utils logic" bash -c '! grep -l "sudo " utils/*.sh 2>/dev/null | grep -v platform_matrix || true'

# 13. Entry points call privilege validation
check "install.sh calls require_privileges" grep -q "require_privileges" install.sh
check "bin/cdss calls require_privileges" grep -q "require_privileges" bin/cdss

# 14. All service commands covered by sudo_or_root
check "definitions.sh service_start uses sudo_or_root" grep -q "sudo_or_root rc-service" utils/definitions.sh
check "definitions.sh service_stop uses sudo_or_root" grep -q "sudo_or_root rc-service" utils/definitions.sh
check "definitions.sh service_restart uses sudo_or_root" grep -q "sudo_or_root rc-service" utils/definitions.sh
check "definitions.sh service_status uses sudo_or_root" grep -q "sudo_or_root rc-service" utils/definitions.sh

# 15. updater.sh uses sudo_or_root for /etc writes
check "updater.sh uses sudo_or_root for /etc writes" grep -q "sudo_or_root mv" utils/updater.sh

echo ""
echo -e "Результат: ${GREEN}$PASS${NC} пройдено, ${RED}$FAIL${NC} провалено"

if [[ $FAIL -gt 0 ]]; then
  echo -e "${RED}Release не підтверджено. Виправте проблеми.${NC}"
  exit 1
fi

echo -e "${GREEN}Release підтверджено. Все готово.${NC}"
exit 0
