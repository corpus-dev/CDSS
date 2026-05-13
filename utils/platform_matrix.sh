#!/usr/bin/env bash
# platform_matrix.sh — центральне джерело правди про підтримку платформ
# Цей файл містить всі mapping-и для distro, arch, init, package, cron, firewall.

# ============================================================
# Distro detection (розширена, з ID_LIKE та family)
# ============================================================

get_distribution_id() {
  if [[ -r /etc/os-release ]]; then
    local dist_id
    dist_id="$(. /etc/os-release && echo "$ID")"
    dist_id=$(echo "$dist_id" | tr '[:upper:]' '[:lower:]')
    echo "$dist_id"
  else
    echo "unknown"
  fi
}

get_distribution_like() {
  if [[ -r /etc/os-release ]]; then
    local dist_like
    dist_like="$(. /etc/os-release && echo "$ID_LIKE")"
    dist_like=$(echo "$dist_like" | tr '[:upper:]' '[:lower:]')
    echo "$dist_like"
  else
    echo ""
  fi
}

get_distribution_family() {
  local dist_id
  dist_id=$(get_distribution_id)
  local dist_like
  dist_like=$(get_distribution_like)

  case "$dist_id" in
    debian|ubuntu|kali|parrot)
      echo "debian"
      ;;
    fedora|rocky|almalinux|ol|centos)
      echo "rhel"
      ;;
    arch|manjaro)
      echo "arch"
      ;;
    void)
      echo "void"
      ;;
    gentoo)
      echo "gentoo"
      ;;
    *)
      if echo "$dist_like" | grep -q "debian"; then
        echo "debian"
      elif echo "$dist_like" | grep -q "rhel\|fedora\|centos"; then
        echo "rhel"
      elif echo "$dist_like" | grep -q "arch"; then
        echo "arch"
      elif echo "$dist_like" | grep -q "void"; then
        echo "void"
      else
        echo "unknown"
      fi
      ;;
  esac
}

is_debian_family() {
  [[ "$(get_distribution_family)" == "debian" ]]
}

is_rhel_family() {
  [[ "$(get_distribution_family)" == "rhel" ]]
}

is_arch_family() {
  [[ "$(get_distribution_family)" == "arch" ]]
}

is_void_family() {
  [[ "$(get_distribution_family)" == "void" ]]
}

# ============================================================
# Arch detection (нормалізований)
# ============================================================

get_normalized_arch() {
  local raw_arch
  raw_arch=$(uname -m 2>/dev/null || echo "unknown")

  case "$raw_arch" in
    x86_64)
      echo "amd64"
      ;;
    i386|i686)
      echo "386"
      ;;
    aarch64)
      echo "arm64"
      ;;
    armv6|armv7|armv8|armhf|arm32)
      echo "arm32"
      ;;
    *)
      echo "$raw_arch"
      ;;
  esac
}

is_amd64() {
  [[ "$(get_normalized_arch)" == "amd64" ]]
}

is_arm64() {
  [[ "$(get_normalized_arch)" == "arm64" ]]
}

is_arm32() {
  [[ "$(get_normalized_arch)" == "arm32" ]]
}

is_386() {
  [[ "$(get_normalized_arch)" == "386" ]]
}

# ============================================================
# Init detection
# ============================================================

get_init_system() {
  if command -v systemctl >/dev/null 2>&1; then
    if systemctl is-system-running >/dev/null 2>&1 || systemctl list-units --type=service >/dev/null 2>&1; then
      echo "systemd"
      return 0
    fi
  fi

  if command -v rc-service >/dev/null 2>&1; then
    echo "openrc"
    return 0
  fi

  if command -v sv >/dev/null 2>&1 && [[ -d /etc/runit/runlevel1 ]]; then
    echo "runit"
    return 0
  fi

  echo "unknown"
  return 1
}

assert_supported_init_for_distribution() {
  local dist_id
  dist_id=$(get_distribution_id)
  local init_system
  init_system=$(get_init_system)

  case "$dist_id" in
    void)
      if [[ "$init_system" == "runit" ]]; then
        echo "$(trans "Void Linux використовує runit. Повна підтримка сервісів — partial support.")"
        return 1
      fi
      ;;
  esac

  return 0
}

# ============================================================
# Package manager mapping (data-driven, не fallback)
# ============================================================

get_package_manager() {
  local dist_id
  dist_id=$(get_distribution_id)
  local dist_family
  dist_family=$(get_distribution_family)

  case "$dist_id" in
    debian|ubuntu|kali|parrot)
      echo "apt-get"
      ;;
    fedora|rocky|almalinux|ol)
      echo "dnf"
      ;;
    centos)
      echo "yum"
      ;;
    arch|manjaro)
      echo "pacman"
      ;;
    void)
      echo "xbps-install"
      ;;
    gentoo)
      echo "emerge"
      ;;
    *)
      case "$dist_family" in
        debian)
          echo "apt-get"
          ;;
        rhel)
          echo "dnf"
          ;;
        arch)
          echo "pacman"
          ;;
        void)
          echo "xbps-install"
          ;;
        *)
          echo "unknown"
          return 1
          ;;
      esac
      ;;
  esac
}

get_base_packages_for_distribution() {
  local dist_family
  dist_family=$(get_distribution_family)

  case "$dist_family" in
    debian)
      echo "dialog git curl sudo"
      ;;
    rhel)
      echo "dialog git curl sudo"
      ;;
    arch)
      echo "dialog git curl sudo"
      ;;
    void)
      echo "dialog git curl sudo"
      ;;
    gentoo)
      echo "dialog git curl sudo"
      ;;
    *)
      echo "unknown"
      return 1
      ;;
  esac
}

# ============================================================
# Cron package/service mapping
# ============================================================

get_cron_package_name() {
  local dist_family
  dist_family=$(get_distribution_family)

  case "$dist_family" in
    debian)
      echo "cron"
      ;;
    rhel)
      echo "cronie"
      ;;
    arch)
      echo "cronie"
      ;;
    void)
      echo "busybox-cron"
      ;;
    *)
      echo "unknown"
      return 1
      ;;
  esac
}

get_cron_service_name() {
  local dist_family
  dist_family=$(get_distribution_family)
  local init_system
  init_system=$(get_init_system)

  case "$dist_family" in
    debian)
      echo "cron"
      ;;
    rhel)
      echo "crond"
      ;;
    arch)
      echo "crond"
      ;;
    void)
      if [[ "$init_system" == "runit" ]]; then
        echo "busybox-cron"
      else
        echo "crond"
      fi
      ;;
    *)
      echo "unknown"
      return 1
      ;;
  esac
}

platform_service_is_active() {
  local service_name="$1"
  local init_system
  init_system=$(get_init_system)

  case "$init_system" in
    systemd)
      command -v systemctl >/dev/null 2>&1 && sudo_or_root systemctl is-active "$service_name" >/dev/null 2>&1
      ;;
    openrc)
      command -v rc-service >/dev/null 2>&1 && sudo_or_root rc-service "$service_name" status >/dev/null 2>&1
      ;;
    runit)
      command -v sv >/dev/null 2>&1 && sudo_or_root sv status "$service_name" >/dev/null 2>&1
      ;;
    *)
      return 1
      ;;
  esac
}

platform_service_start() {
  local service_name="$1"
  local init_system
  init_system=$(get_init_system)

  case "$init_system" in
    systemd)
      command -v systemctl >/dev/null 2>&1 && sudo_or_root systemctl start "$service_name" >/dev/null 2>&1
      ;;
    openrc)
      command -v rc-service >/dev/null 2>&1 && sudo_or_root rc-service "$service_name" start >/dev/null 2>&1
      ;;
    runit)
      command -v sv >/dev/null 2>&1 && sudo_or_root sv start "$service_name" >/dev/null 2>&1
      ;;
    *)
      return 1
      ;;
  esac
}

ensure_cron_installed() {
  local cron_pkg
  cron_pkg=$(get_cron_package_name)
  if [[ "$cron_pkg" == "unknown" ]]; then
    return 1
  fi

  local pkg_manager
  pkg_manager=$(get_package_manager)
  if ! command -v crontab >/dev/null 2>&1; then
    case "$pkg_manager" in
    apt-get)
        sudo_or_root apt-get install -y "$cron_pkg"
        ;;
      dnf|yum)
        sudo_or_root "$pkg_manager" install -y "$cron_pkg"
        ;;
      pacman)
        sudo_or_root pacman -Sy "$cron_pkg" --noconfirm
        ;;
      xbps-install)
        sudo_or_root xbps-install -S "$cron_pkg"
        ;;
      *)
        return 1
        ;;
    esac
  fi
}

ensure_cron_running() {
  local cron_svc
  cron_svc=$(get_cron_service_name)
  if [[ "$cron_svc" == "unknown" ]]; then
    echo -e "${RED}$(trans "Не вдалося визначити cron service для цього дистрибутиву")${NC}"
    return 1
  fi

  if ! platform_service_is_active "$cron_svc"; then
    echo -e "${GREEN}$(trans "Запуск cron service: $cron_svc")${NC}"
    if platform_service_start "$cron_svc"; then
      echo -e "${GREEN}$(trans "Cron service '$cron_svc' запущено")${NC}"
      return 0
    else
      echo -e "${RED}$(trans "Не вдалося запустити cron service '$cron_svc'. Перевірте вручну.")${NC}"
      return 1
    fi
  fi

  echo -e "${GREEN}$(trans "Cron service '$cron_svc' вже активний")${NC}"
  return 0
}

# ============================================================
# Firewall backend mapping
# ============================================================

get_firewall_backend() {
  local dist_family
  dist_family=$(get_distribution_family)

  case "$dist_family" in
    debian)
      echo "ufw"
      ;;
    rhel)
      echo "firewalld"
      ;;
    arch)
      echo "ufw"
      ;;
    void)
      echo "ufw"
      ;;
    *)
      echo "unknown"
      return 1
      ;;
  esac
}

install_firewall_backend() {
  local backend
  backend=$(get_firewall_backend)
  if [[ "$backend" == "unknown" ]]; then
    return 1
  fi

  local pkg_manager
  pkg_manager=$(get_package_manager)

  case "$backend" in
    ufw)
      case "$pkg_manager" in
        apt-get)
          sudo_or_root apt-get install -y ufw
          ;;
        dnf|yum)
          sudo_or_root "$pkg_manager" install -y ufw
          ;;
        pacman)
          sudo_or_root pacman -Sy ufw --noconfirm
          ;;
        xbps-install)
          sudo_or_root xbps-install -S ufw
          ;;
        *)
          return 1
          ;;
      esac
      ;;
    firewalld)
      case "$pkg_manager" in
        dnf|yum)
          sudo_or_root "$pkg_manager" install -y firewalld
          ;;
        *)
          return 1
          ;;
      esac
      ;;
    *)
      return 1
      ;;
  esac
}

configure_firewall_backend() {
  local backend
  backend=$(get_firewall_backend)
  if [[ "$backend" == "unknown" ]]; then
    return 1
  fi

  case "$backend" in
    ufw)
      sudo_or_root ufw default deny incoming
      sudo_or_root ufw default allow outgoing
      sudo_or_root ufw enable
      ;;
    firewalld)
      service_enable firewalld
      service_start firewalld
      sudo_or_root firewall-cmd --permanent --set-default-zone=dmz
      ;;
    *)
      return 1
      ;;
  esac
}

# ============================================================
# Support level matrix
# ============================================================

get_platform_support_level() {
  local dist_id
  dist_id=$(get_distribution_id)
  local dist_family
  dist_family=$(get_distribution_family)
  local init_system
  init_system=$(get_init_system)
  local arch
  arch=$(get_normalized_arch)

  local os_name=""
  if [[ -r /etc/os-release ]]; then
    os_name="$(. /etc/os-release && echo "$NAME")"
    os_name=$(echo "$os_name" | tr '[:upper:]' '[:lower:]')
  fi

  case "$dist_id" in
    ubuntu|debian|fedora|kali|parrot)
      echo "full"
      ;;
    rocky|almalinux|ol|arch|manjaro)
      echo "full"
      ;;
    centos)
      if echo "$os_name" | grep -qi "stream"; then
        echo "full"
      else
        echo "partial"
      fi
      ;;
    void)
      echo "partial"
      ;;
    gentoo)
      echo "unsupported"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

# ============================================================
# Tool capability matrix
# ============================================================

tool_supports_platform() {
  local tool_name="$1"
  local dist_family="$2"
  local arch="$3"
  local init_system="$4"

  case "$tool_name" in
    mhddos)
      if [[ "$arch" == "arm32" || "$arch" == "386" ]]; then
        return 1
      fi
      if [[ "$dist_family" == "void" && "$init_system" == "runit" ]]; then
        return 1
      fi
      return 0
      ;;
    distress)
      if [[ "$arch" == "386" ]]; then
        return 1
      fi
      if [[ "$init_system" == "runit" ]]; then
        return 1
      fi
      return 0
      ;;
    x100)
      if ! command -v docker >/dev/null 2>&1; then
        return 1
      fi
      if [[ "$arch" == "arm32" || "$arch" == "386" ]]; then
        return 1
      fi
      if [[ "$init_system" != "systemd" ]]; then
        return 1
      fi
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# ============================================================
# Explicit distro support list
# ============================================================

get_supported_distributions() {
  echo "ubuntu debian fedora rocky almalinux ol kali parrot arch manjaro"
}

get_partial_support_distributions() {
  echo "centos void"
}

get_unsupported_distributions() {
  echo "gentoo"
}

# ============================================================
# Privilege helper — canonical privilege API
# ============================================================

trans() { echo "$@"; }

is_root() {
  [[ "$(id -u)" -eq 0 ]]
}

has_sudo() {
  command -v sudo >/dev/null 2>&1
}

require_privileges() {
  if is_root; then
    return 0
  fi

  if has_sudo; then
    return 0
  fi

  echo -e "${RED}$(trans "Потрібен sudo або root доступ. CDSS не працюватиме без прав.")${NC}"
  echo -e "${RED}$(trans "Запустіть як root або додайте sudo доступ.")${NC}"
  exit 1
}

sudo_or_root() {
  if is_root; then
    "$@"
  else
    sudo "$@"
  fi
}
