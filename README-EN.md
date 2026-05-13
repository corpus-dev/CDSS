# CDSS

CDSS is a Bash utility for installing, updating, and managing the Cyber Corps Linux toolset. It detects the distribution, architecture, and init system, installs required base packages, creates service files, keeps configuration in one file, and exposes an interactive menu.

> Use CDSS only on systems you own or in environments where you have explicit authorization to run the related network actions.

#### [Українська версія](/README.md)

## Installation

Recommended method:

```bash
curl -fsSLo install.sh https://raw.githubusercontent.com/corpus-dev/CDSS/main/install.sh
# Review install.sh before running it
sudo bash install.sh
```

Fast method:

```bash
curl -sL https://raw.githubusercontent.com/corpus-dev/CDSS/main/install.sh | sudo bash -s
```

> **Note:** CDSS can run as `root` without installed `sudo`. If you are root — `sudo` is not required. For non-root users, `sudo` is required.

After installation:

- working directory: `/opt/cybercorps`
- command symlink: `/usr/local/bin/cdss`
- main configuration: `/opt/cybercorps/services/EnvironmentFile`
- main log for `mhddos` and `distress`: `/var/log/cdss.log`
- X100 log: `/opt/cybercorps/x100-for-docker/put-your-ovpn-files-here/x100-log-short.txt`

The installer installs the base packages `dialog`, `git`, `curl`, `sudo`, checks/installs the distribution-specific cron package, and clones the repository into `/opt/cybercorps`.

## Commands

```bash
cdss
```

Starts the interactive menu, checks for updates, and applies the configuration patch.

```bash
cdss --lang en
```

Starts the menu in English.

```bash
cdss --auto-install
```

Automatically installs protection, the firewall backend, DISTRESS, and on supported non-ARM32 systems also MHDDOS; starts MHDDOS, enables its autostart, applies the TCP port-range extension, and shows status.

```bash
cdss --restore
```

Stops active services, backs up `EnvironmentFile`, safely removes the current installation, downloads the current `install.sh`, reinstalls CDSS, and restores the configuration.

```bash
cdss config
```

Prints the current `services/EnvironmentFile`.

```bash
cdss --uninstall
```

Stops `mhddos`, `distress`, and `x100`, disables autostart, removes systemd service files, removes `/usr/local/bin/cdss`, and deletes the installation directory after safe-path checks.

## Main Menu

CDSS has four main sections:

- `Attack status` - shows the active service and recent log lines.
- `Port extension` - creates `/etc/sysctl.d/99-cdss-port-range.conf` with `net.ipv4.ip_local_port_range=16384 65535` and applies `sysctl --system`.
- `DDOS` - installs and manages `MHDDOS`, `DISTRESS`, and `X100`.
- `Security settings` - installs and manages the firewall backend and Fail2ban.

## Tools

| Tool | Support | What CDSS does |
|---|---|---|
| MHDDOS | `amd64`, `arm64`; does not support `386`, `arm32`, Void/runit | Downloads `mhddos_proxy_linux`, generates `mhddos.service`, manages start/stop/status, autostart, and cron schedules. |
| DISTRESS | `amd64`, `arm64`, `arm32`; systemd/openrc; does not support `386` or runit | Downloads `distress`, generates `distress.service`, manages start/stop/status, autostart, and cron schedules. |
| X100 | Docker + systemd + `amd64`/`arm64` | Installs/checks Docker, downloads `x100-for-docker.zip`, configures `x100-config.txt`, creates `x100.service`, manages start/stop/status, autostart, and cron schedules. |

When one tool is started, CDSS stops the other active tools so multiple services are not running at the same time.

## Configuration

Main configuration file:

```text
/opt/cybercorps/services/EnvironmentFile
```

It contains these sections:

- `[mhddos]` - `user-id`, `lang`, `copies`, `threads`, `proxies`, `ifaces`, `use-my-ip`, `source`, `cron-to-run`, `cron-to-stop`.
- `[distress]` - `user-id`, `use-my-ip`, `use-tor`, `concurrency`, `interface`, flood-related options, `proxies-path`, `source`, `cron-to-run`, `cron-to-stop`.
- `[x100]` - `itArmyUserId`, `initialDistressScale`, `ignoreBundledFreeVpn`, `cron-to-run`, `cron-to-stop`.

The settings menu updates this file and regenerates the related service-file `ExecStart`.

## Autostart And Scheduling

CDSS supports:

- systemd/openrc autostart for `mhddos`, `distress`, and `x100` when the platform supports it;
- cron-based start and stop schedules for each tool;
- cron markers in the `# CDSS:<job_id>` format.

Void Linux with runit is partially supported: service enable/disable is not available and some flows need manual checks.

## System Security

The security section installs and configures:

- firewall backend from `platform_matrix.sh`: `ufw` for Debian/Arch/Void families and `firewalld` for RHEL family;
- Fail2ban with `/etc/fail2ban/jail.d/cdss-ssh.conf`;
- firewall rules with deny incoming, allow outgoing, and SSH port `22` allowed.

## Platform Support

| Distribution | Family | Init | Status | Notes |
|---|---|---|---|---|
| Ubuntu | debian | systemd | Fully supported | |
| Debian | debian | systemd | Fully supported | |
| Fedora | rhel | systemd | Fully supported | |
| Rocky Linux | rhel | systemd | Fully supported | |
| AlmaLinux | rhel | systemd | Fully supported | |
| Oracle Linux (`ol`) | rhel | systemd | Fully supported | |
| Kali Linux | debian | systemd | Fully supported | |
| Parrot Security OS | debian | systemd | Fully supported | |
| Arch Linux | arch | systemd | Fully supported | |
| Manjaro | arch | systemd | Fully supported | |
| CentOS | rhel | systemd | Partial support | CentOS Stream is detected as full; other CentOS variants are partial. |
| Void Linux | void | runit | Partial support | Service and autostart limitations. |
| Gentoo | gentoo | varies | Unsupported | Installation stops. |

Architecture normalization: `x86_64 -> amd64`, `i386/i686 -> 386`, `aarch64 -> arm64`, `armv6/armv7/armv8/armhf/arm32 -> arm32`.

## Updates

CDSS checks GitHub `version.txt` and stores the last-check timestamp in `/etc/environment` as `CDSS_DEPLOYMENT_VERSION`. If more than 5 minutes have passed, it runs `git pull --all` inside the installation directory and, on systemd, regenerates service files.

## Release Check

The repository includes:

```bash
bash release_checklist.sh
```

It checks the platform matrix, absence of a hardcoded package manager, README support tables, and Bash syntax for key files.

## Troubleshooting

### `sudo: command not found`
If you run CDSS as non-root and `sudo` is not installed — the script will print an error and exit. Install `sudo` or run as `root`.

### No permissions on `/opt/cybercorps`
If root created the directory and subsequent non-root updates lack permissions — make sure `cdss` is run from the same user consistently.

### Service manager denies service management
On Void Linux with runit, support is partial: service enable/disable is unavailable. On Gentoo — full unsupported.

### Cron unavailable
If the cron package is not installed, automatic jobs will not work. Install the cron package manually: `apt-get install cron`, `dnf install cronie`, etc.
