#!/usr/bin/env bash
set -uo pipefail

export GREEN='\033[0;32m'
export RED='\033[0;31m'
export NC='\033[0m'
export ORANGE='\033[0;33m'

WORKING_DIR="/opt/cybercorps"
INSTALL_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd -P)"
RAW_BASE_URL="${CDSS_RAW_BASE_URL:-https://raw.githubusercontent.com/corpus-dev/CDSS/main}"
BOOTSTRAP_DIR=""

cleanup_bootstrap_dir() {
  if [[ -n "${BOOTSTRAP_DIR:-}" && -d "$BOOTSTRAP_DIR" ]]; then
    rm -rf "$BOOTSTRAP_DIR"
  fi
}

source_cdss_file() {
  local rel_path="$1"
  local required="${2:-required}"
  local local_path="${INSTALL_SOURCE_DIR}/${rel_path}"

  if [[ -f "$local_path" ]]; then
    if source "$local_path"; then
      return 0
    fi

    if [[ "$required" == "required" ]]; then
      echo -e "${RED}Failed to load required CDSS installer helper: ${rel_path}${NC}"
      exit 1
    fi

    return 1
  fi

  if ! command -v curl >/dev/null 2>&1; then
    if [[ "$required" == "required" ]]; then
      echo -e "${RED}curl is required to bootstrap CDSS installer helpers.${NC}"
      exit 1
    fi
    return 1
  fi

  if [[ -z "$BOOTSTRAP_DIR" ]]; then
    BOOTSTRAP_DIR="$(mktemp -d)"
    trap cleanup_bootstrap_dir EXIT
  fi

  local download_path="${BOOTSTRAP_DIR}/${rel_path}"
  mkdir -p "$(dirname "$download_path")"

  if curl -fsSL "${RAW_BASE_URL}/${rel_path}" -o "$download_path"; then
    if source "$download_path"; then
      return 0
    fi
  fi

  if [[ "$required" == "required" ]]; then
    echo -e "${RED}Failed to load required CDSS installer helper: ${rel_path}${NC}"
    exit 1
  fi

  return 1
}

export SCRIPT_DIR="$INSTALL_SOURCE_DIR"

source_cdss_file "utils/privileges.sh"
source_cdss_file "utils/platform_matrix.sh"

if ! source_cdss_file "utils/translate.sh" optional; then
  trans() { echo "$@"; }
fi

install_cdss_command() {
  sudo_or_root chmod +x "$WORKING_DIR/bin/cdss"
  sudo_or_root ln -sf "$WORKING_DIR/bin/cdss" /usr/local/bin/cdss
}

dist_id=$(get_distribution_id)
dist_family=$(get_distribution_family)
init_system=$(get_init_system)
arch=$(get_normalized_arch)
support_level=$(get_platform_support_level)

require_privileges

if [[ "$support_level" == "unsupported" ]]; then
  echo -e "${RED}$(trans "Дистрибутив '$dist_id' не підтримується. Встановлення призупинено.")${NC}"
  echo -e "${RED}$(trans "Сімейство: $dist_family. Init: $init_system. Arch: $arch.")${NC}"
  exit 1
fi

if [[ "$support_level" == "partial" ]]; then
  echo -e "${ORANGE}$(trans "Дистрибутив '$dist_id' має partial support. Деякі функції можуть бути обмежені.")${NC}"
  echo -e "${ORANGE}$(trans "Сімейство: $dist_family. Init: $init_system. Arch: $arch.")${NC}"
  echo -e "${ORANGE}$(trans "Натисніть Enter для продовження або Ctrl+C для виходу.")${NC}"
  read -n 1 -s || exit 1
fi

ensure_cdss_service_user

pkg_manager=$(get_package_manager)
if [[ "$pkg_manager" == "unknown" ]]; then
  echo -e "${RED}$(trans "Менеджер пакетів не знайдено для '$dist_id'")${NC}"
  exit 1
fi

assert_supported_init_for_distribution || true

base_packages=$(get_base_packages_for_distribution)
if [[ "$base_packages" == "unknown" ]]; then
  echo -e "${RED}$(trans "Базові пакети не визначено для сімейства '$dist_family'")${NC}"
  exit 1
fi

ensure_cron_installed || true
ensure_cron_running || true

if ! sudo_or_root "$pkg_manager" update -y; then
  echo -e "${RED}$(trans "Оновлення індексу пакетів не вдалося. Встановлення зупинено.")${NC}"
  exit 1
fi
for pkg in $base_packages; do
  echo -e "${GREEN}$(trans "Встановлюємо $pkg")${NC}"
  case "$pkg_manager" in
    apt-get)
      sudo_or_root apt-get install -y "$pkg"
      ;;
    dnf|yum)
      sudo_or_root "$pkg_manager" install -y "$pkg"
      ;;
    pacman)
      sudo_or_root pacman -Sy "$pkg" --noconfirm
      ;;
    xbps-install)
      sudo_or_root xbps-install -S "$pkg"
      ;;
    emerge)
      sudo_or_root "$pkg_manager" -n "$pkg"
      ;;
    *)
      echo -e "${RED}$(trans "Невідомий пакет менеджер: $pkg_manager")${NC}"
      exit 1
      ;;
  esac
done

if [[ -d "$WORKING_DIR" ]] && [[ "$(ls -A "$WORKING_DIR")" ]]; then
  echo -e "${GREEN}$(trans "CDSS вже встановлено. Запускаємо оновлення...")${NC}"
  export SCRIPT_DIR="${WORKING_DIR}"
  source "${WORKING_DIR}/utils/updater.sh"
  source "${WORKING_DIR}/utils/translate.sh"
  update_cdss
  install_cdss_command
else
  sudo_or_root mkdir -p "$WORKING_DIR"
  sudo_or_root chown "$(get_real_user)" "$WORKING_DIR"
  echo -e "${GREEN}$(trans "Клонуємо CDSS...")${NC}"
  if ! git clone https://github.com/corpus-dev/CDSS.git "$WORKING_DIR"; then
    echo -e "${RED}$(trans "git clone CDSS не вдався.")${NC}"
    exit 1
  fi
  if ! cd "$WORKING_DIR" || ! git checkout main; then
    echo -e "${RED}$(trans "git checkout main не вдався.")${NC}"
    exit 1
  fi

  source "$WORKING_DIR/utils/definitions.sh"
  source "$WORKING_DIR/utils/datapatch.sh"
  apply_patch "$WORKING_DIR/services/EnvironmentFile"

  install_cdss_command
  echo -e "${GREEN}$(trans "CDSS встановлено! Запустіть команду 'cdss' для початку.")${NC}"
fi
