extend_ports() {
  local port_range_string="net.ipv4.ip_local_port_range=16384 65535"
  local sysctl_d_file="/etc/sysctl.d/99-cdss-port-range.conf"

  if ! command -v sysctl >/dev/null 2>&1; then
    confirm_dialog "$(trans "sysctl не знайдено. Не можливо виконати дію.")"
    return 1
  fi

  if [[ -f "$sysctl_d_file" ]]; then
    if grep -q "$port_range_string" "$sysctl_d_file"; then
      confirm_dialog "$(trans "Наразі всі порти розширено")"
      return 0
    fi
  fi

  local tmp_file
  tmp_file=$(mktemp)
  echo "$port_range_string" > "$tmp_file"

sudo_or_root mv -f "$tmp_file" "$sysctl_d_file"
sudo_or_root sysctl --system >/dev/null 2>&1 || true

  confirm_dialog "$(trans "Порти успішно розширено")"
}
