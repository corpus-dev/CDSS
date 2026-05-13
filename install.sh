#!/usr/bin/env bash

export GREEN='\033[0;32m'
export RED='\033[0;31m'
export NC='\033[0m'
export ORANGE='\033[0;33m'

WORKING_DIR="/opt/cybercorps"

source "$(dirname "$0")/utils/platform_matrix.sh"

if [[ -f "$(dirname "$0")/utils/translate.sh" ]]; then
  source "$(dirname "$0")/utils/translate.sh"
else
  trans() { echo "$@"; }
fi

require_privileges

dist_id=$(get_distribution_id)
dist_family=$(get_distribution_family)
init_system=$(get_init_system)
arch=$(get_normalized_arch)
support_level=$(get_platform_support_level)

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

sudo_or_root "$pkg_manager" update -y
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
  source "${WORKING_DIR}/utils/updater.sh"
  source "${WORKING_DIR}/utils/translate.sh"
  export SCRIPT_DIR="${WORKING_DIR}/"
  update_cdss
else
  sudo_or_root mkdir -p "$WORKING_DIR"
  sudo_or_root chown "$(whoami)" "$WORKING_DIR"
  echo -e "${GREEN}$(trans "Клонуємо CDSS...")${NC}"
  git clone https://github.com/corpus-dev/CDSS.git "$WORKING_DIR"
  cd "$WORKING_DIR" && git checkout main

  source "$WORKING_DIR/utils/definitions.sh"
  source "$WORKING_DIR/utils/datapatch.sh"
  apply_patch "$WORKING_DIR/services/EnvironmentFile"

  sudo_or_root chmod +x "$WORKING_DIR/bin/cdss"
  sudo_or_root ln -sf "$WORKING_DIR/bin/cdss" /usr/local/bin/cdss
  echo -e "${GREEN}$(trans "CDSS встановлено! Запустіть команду 'cdss' для початку.")${NC}"
fi
