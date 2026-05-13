source "${SCRIPT_DIR}/utils/definitions.sh"

install_fail2ban() {
  local pkg_manager
  pkg_manager=$(get_package_manager)
  local init_system
  init_system=$(get_init_system)

  cdss_dialog "$(trans "Встановлюємо Fail2ban")"

  case "$pkg_manager" in
    dnf)
      install() {
        sudo_or_root dnf update -y
        sudo_or_root dnf upgrade -y
        sudo_or_root dnf install -y fail2ban
      }
      ;;
    yum)
      install() {
        sudo_or_root yum update -y
        sudo_or_root yum install -y epel-release
        sudo_or_root yum install -y fail2ban
      }
      ;;
    pacman)
      install() {
        sudo_or_root pacman -Sy fail2ban --noconfirm
      }
      ;;
    xbps-install)
      install() {
        sudo_or_root xbps-install -Su fail2ban
      }
      ;;
    emerge)
      install() {
        sudo_or_root emerge -n net/security/fail2ban
      }
      ;;
    *)
      install() {
        sudo_or_root apt-get update -y
        sudo_or_root apt-get install -y fail2ban
      }
      ;;
  esac

  install >/dev/null 2>&1
  confirm_dialog "$(trans "Fail2ban успішно встановлено")"
}

fail2ban_is_active() {
  local svc_cmd
  svc_cmd=$(get_service_is_active_command)
  if $svc_cmd fail2ban >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

enable_fail2ban() {
  service_enable fail2ban
  service_start fail2ban
  confirm_dialog "$(trans "Fail2ban успішно увімкнено")"
}

disable_fail2ban() {
  service_disable fail2ban
  service_stop fail2ban
  confirm_dialog "$(trans "Fail2ban успішно вимкнено")"
}

fail2ban_installed() {
  if [[ -e "/etc/fail2ban" ]]; then
    return 0
  else
    return 1
  fi
}

configure_fail2ban() {
  fail2ban_installed
  if [[ $? == 1 ]]; then
    confirm_dialog "$(trans "Fail2ban не встановлений, будь ласка встановіть і спробуйте знову")"
  else
    cdss_dialog "$(trans "Налаштовуємо Fail2ban")"
    configure() {
      local jail_local="/etc/fail2ban/jail.local"
      if [[ ! -f "$jail_local" ]]; then
        sudo_or_root cp /etc/fail2ban/jail.conf "$jail_local"
      fi

      local cdss_conf="/etc/fail2ban/jail.d/cdss-ssh.conf"
      local tmp_conf
      tmp_conf=$(mktemp)
      echo "[ssh" >> "$tmp_conf"
      echo "enabled = true" >> "$tmp_conf"
      echo "port = ssh" >> "$tmp_conf"
      echo "filter = sshd" >> "$tmp_conf"
      echo "action = iptables[name=sshd, port=ssh, protocol=tcp]" >> "$tmp_conf"
      echo "logpath = %(sshd_log)s" >> "$tmp_conf"
      echo "backend = %(sshd_backend)s" >> "$tmp_conf"
      echo "maxretry = 3" >> "$tmp_conf"
      echo "bantime = 600" >> "$tmp_conf"
      echo "]" >> "$tmp_conf"

      sudo_or_root mv -f "$tmp_conf" "$cdss_conf"
    }
    configure >/dev/null 2>&1
    confirm_dialog "$(trans "Fail2ban успішно налаштовано")"
  fi
}
