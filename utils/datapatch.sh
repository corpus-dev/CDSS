set -uo pipefail

apply_patch() {
  local config_file="$1"

  if [[ -z "$config_file" ]] || [[ ! -f "$config_file" ]]; then
    echo "Config file '$config_file' not found or empty"
    return 1
  fi

  echo -e "${GREEN}Застосовую патч конфігурації з дефолтними значеннями...${NC}"

  ensure_config_section "$config_file" "distress"
  ensure_config_key "$config_file" "distress" "interface" ""
  ensure_config_key "$config_file" "distress" "udp-packet-size" "1252"
  ensure_config_key "$config_file" "distress" "direct-udp-mixed-flood-packets-per-conn" "30"
  ensure_config_key "$config_file" "distress" "enable-icmp-flood" "0"
  ensure_config_key "$config_file" "distress" "enable-packet-flood" "0"
  ensure_config_key "$config_file" "distress" "source" "cdss"

  local use_my_ip
  use_my_ip=$(get_config_value "$config_file" "distress" "use-my-ip")
  if [[ "$use_my_ip" == "0" ]]; then
    set_config_value "$config_file" "distress" "disable-udp-flood" "0"
  else
    set_config_value "$config_file" "distress" "disable-udp-flood" "1"
  fi

  ensure_config_key "$config_file" "distress" "proxies-path" ""
  ensure_config_key "$config_file" "distress" "cron-to-run" ""
  ensure_config_key "$config_file" "distress" "cron-to-stop" ""

  ensure_config_section "$config_file" "mhddos"
  ensure_config_key "$config_file" "mhddos" "source" "cdss"
  ensure_config_key "$config_file" "mhddos" "use-my-ip" "0"
  ensure_config_key "$config_file" "mhddos" "cron-to-run" ""
  ensure_config_key "$config_file" "mhddos" "cron-to-stop" ""

  ensure_config_section "$config_file" "x100"
  ensure_config_key "$config_file" "x100" "cron-to-run" ""
  ensure_config_key "$config_file" "x100" "cron-to-stop" ""

  return 0
}
