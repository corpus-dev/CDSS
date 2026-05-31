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
    ((PASS+=1))
  else
    echo -e "${RED}✗${NC} $desc"
    ((FAIL+=1))
  fi
}

echo "=== Release Checklist ==="
echo ""

# 1. Distro detect не зламався
check "Distro detection" bash -c 'source utils/privileges.sh; source utils/platform_matrix.sh; [[ "$(get_distribution_id)" != "error" ]]'

# 2. Package manager не захардкоджений
check "No hardcoded package manager" bash -c '! grep -q "PACKAGE_MANAGER=\"apt-get\"" install.sh utils/definitions.sh'

# 3. Direct systemctl в прикладній логіці
check "No direct systemctl in utils/menu/bin outside platform helpers" bash -c '! grep -RIn "systemctl" utils/*.sh menu/*.sh bin/cdss 2>/dev/null | grep -v "platform_matrix.sh" | grep -v "definitions.sh" | grep -v "sudo systemctl"'

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
check "All shell syntax" bash -c 'for f in install.sh bin/cdss utils/*.sh menu/*.sh release_checklist.sh smoke_*_family.sh smoke_wsl.sh tests/*.sh; do bash -n "$f" || exit 1; done'

# 11. Privilege API checks
check "privileges.sh exists" test -f utils/privileges.sh
check "is_root() defined" grep -q "is_root()" utils/privileges.sh
check "has_sudo() defined" grep -q "has_sudo()" utils/privileges.sh
check "has_active_sudo() defined" grep -q "has_active_sudo()" utils/privileges.sh
check "require_privileges() defined" grep -q "require_privileges()" utils/privileges.sh
check "sudo_or_root() defined" grep -q "sudo_or_root()" utils/privileges.sh

# 12. No direct sudo in executable logic (except allowlist for messages)
check "No direct sudo outside privilege helper and user-facing text" bash -c '! grep -RIn "sudo " bin utils menu install.sh 2>/dev/null | grep -v "utils/privileges.sh" | grep -v "sudo_or_root" | grep -v "sudo доступ" | grep -v "sudo systemctl" | grep -v "sudo service"'

# 13. Entry points call privilege validation
check "install.sh calls require_privileges" grep -q "require_privileges" install.sh
check "bin/cdss calls require_privileges" grep -q "require_privileges" bin/cdss
check "install.sh sources privileges first" grep -q 'source_cdss_file "utils/privileges.sh"' install.sh
check "bin/cdss sources privileges" grep -q 'utils/privileges.sh' bin/cdss

# 14. All service commands covered by sudo_or_root
check "definitions.sh service_start uses sudo_or_root" grep -q "sudo_or_root rc-service" utils/definitions.sh
check "definitions.sh service_stop uses sudo_or_root" grep -q "sudo_or_root rc-service" utils/definitions.sh
check "definitions.sh service_restart uses sudo_or_root" grep -q "sudo_or_root rc-service" utils/definitions.sh
check "definitions.sh service_status uses sudo_or_root" grep -q "sudo_or_root rc-service" utils/definitions.sh

# 15. updater.sh uses sudo_or_root for /etc writes
check "updater.sh uses sudo_or_root for /etc writes" grep -q "sudo_or_root mv" utils/updater.sh

# 16. Service hardening
check "mhddos service has User=cdss" grep -q "^User=cdss" services/mhddos.service
check "distress service has User=cdss" grep -q "^User=cdss" services/distress.service
check "x100 service has User=cdss" grep -q "^User=cdss" services/x100.service
check "services use NoNewPrivileges" bash -c 'grep -q "^NoNewPrivileges=true" services/mhddos.service services/distress.service services/x100.service'
check "services use ProtectSystem" bash -c 'grep -q "^ProtectSystem=strict" services/mhddos.service services/distress.service services/x100.service'
check "security menu has no stale typos" bash -c '! grep -RInE "uufw|захит|фаервол|Faєr" menu/security_configuration.sh menu/security_settings.sh utils/ufw.sh utils/fail2ban.sh'
check "firewalld keeps SSH open" grep -q -- "--add-service=ssh" utils/platform_matrix.sh

# 17. Unit tests
check "core tests" bash tests/test_core.sh

echo ""
echo -e "Результат: ${GREEN}$PASS${NC} пройдено, ${RED}$FAIL${NC} провалено"

if [[ $FAIL -gt 0 ]]; then
  echo -e "${RED}Release не підтверджено. Виправте проблеми.${NC}"
  exit 1
fi

echo -e "${GREEN}Release підтверджено. Все готово.${NC}"
exit 0
