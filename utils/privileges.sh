#!/usr/bin/env bash
set -uo pipefail

trans() {
  echo "$@"
}

is_root() {
  [[ "$(id -u)" -eq 0 ]]
}

get_real_user() {
  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER:-}" != "root" ]]; then
    echo "$SUDO_USER"
  elif [[ -n "${CDSS_REAL_USER:-}" ]]; then
    echo "$CDSS_REAL_USER"
  elif [[ -n "${USER:-}" ]]; then
    echo "$USER"
  else
    id -un 2>/dev/null || echo "root"
  fi
}

has_sudo() {
  command -v sudo >/dev/null 2>&1
}

has_active_sudo() {
  has_sudo && sudo -n true >/dev/null 2>&1
}

require_privileges() {
  if is_root; then
    return 0
  fi

  if ! has_sudo; then
    echo -e "${RED:-}$(trans "Потрібен sudo або root доступ. CDSS не працюватиме без прав.")${NC:-}"
    echo -e "${RED:-}$(trans "Запустіть як root або додайте sudo доступ.")${NC:-}"
    exit 1
  fi

  if sudo -v; then
    return 0
  fi

  echo -e "${RED:-}$(trans "Не вдалося підтвердити sudo доступ для поточного користувача.")${NC:-}"
  echo -e "${RED:-}$(trans "Запустіть як root або додайте користувача до sudoers.")${NC:-}"
  exit 1
}

sudo_or_root() {
  if is_root; then
    logger "CDSS: root command: $*" 2>/dev/null || true
    "$@"
  else
    logger "CDSS: sudo command: $*" 2>/dev/null || true
    sudo "$@"
  fi
}

ensure_cdss_service_user() {
  local nologin_shell="/usr/sbin/nologin"
  if [[ ! -x "$nologin_shell" ]]; then
    if [[ -x /sbin/nologin ]]; then
      nologin_shell="/sbin/nologin"
    else
      nologin_shell="/bin/false"
    fi
  fi

  if ! id cdss >/dev/null 2>&1; then
    if command -v useradd >/dev/null 2>&1; then
      sudo_or_root useradd --system --home-dir /var/lib/cdss --create-home --shell "$nologin_shell" cdss
    elif command -v adduser >/dev/null 2>&1; then
      sudo_or_root adduser -S -D -H -h /var/lib/cdss -s "$nologin_shell" cdss
    else
      echo -e "${RED:-}$(trans "Не знайдено useradd/adduser для створення системного користувача cdss.")${NC:-}"
      return 1
    fi
  fi

  sudo_or_root mkdir -p /var/lib/cdss
  sudo_or_root touch /var/log/cdss.log
  sudo_or_root chown cdss:cdss /var/lib/cdss /var/log/cdss.log
  sudo_or_root chmod 755 /var/lib/cdss
  sudo_or_root chmod 644 /var/log/cdss.log
}
