# CDSS

CDSS - це Bash-утиліта для встановлення, оновлення та керування набором мережевих інструментів Cyber Corps на Linux. Скрипт визначає дистрибутив, архітектуру та init-систему, встановлює потрібні базові пакети, створює системні служби, веде конфігурацію в одному файлі та надає інтерактивне меню.

> Використовуйте CDSS лише на власних системах або в середовищах, де у вас є явний дозвіл на запуск відповідних мережевих дій.

#### [English version](/README-EN.md)

## Встановлення

Рекомендований варіант:

```bash
curl -fsSLo install.sh https://raw.githubusercontent.com/corpus-dev/CDSS/main/install.sh
# Перегляньте install.sh перед запуском
sudo bash install.sh
```

Швидкий варіант:

```bash
curl -sL https://raw.githubusercontent.com/corpus-dev/CDSS/main/install.sh | sudo bash -s
```

> **Примітка:** CDSS можна запускати від `root` без встановленого `sudo`. Якщо ви root — `sudo` не потрібен. Для non-root користувачів потрібен `sudo`.

Після встановлення:

- робоча директорія: `/opt/cybercorps`
- команда запуску: `/usr/local/bin/cdss`
- основна конфігурація: `/opt/cybercorps/services/EnvironmentFile`
- основний лог для `mhddos` і `distress`: `/var/log/cdss.log`
- X100-лог: `/opt/cybercorps/x100-for-docker/put-your-ovpn-files-here/x100-log-short.txt`

Інсталятор встановлює базові пакети `dialog`, `git`, `curl`, `sudo`, перевіряє/ставить cron-пакет для дистрибутива і клонує репозиторій у `/opt/cybercorps`.

## Команди

```bash
cdss
```

Запускає інтерактивне меню, перевіряє оновлення та застосовує патч конфігурації.

```bash
cdss --lang en
```

Запускає меню англійською мовою.

```bash
cdss --auto-install
```

Автоматично встановлює захист, firewall backend, DISTRESS, а на підтримуваних не-ARM32 системах також MHDDOS; запускає MHDDOS, вмикає його автозапуск, застосовує розширення діапазону TCP-портів і показує статус.

```bash
cdss --restore
```

Зупиняє активні служби, зберігає `EnvironmentFile`, безпечно видаляє поточну інсталяцію, завантажує актуальний `install.sh`, перевстановлює CDSS і відновлює конфігурацію.

```bash
cdss config
```

Показує поточний `services/EnvironmentFile`.

```bash
cdss --uninstall
```

Зупиняє `mhddos`, `distress`, `x100`, вимикає автозапуск, видаляє systemd service-файли, symlink `/usr/local/bin/cdss` і директорію встановлення після перевірки безпечного шляху.

## Головне Меню

CDSS має чотири основні розділи:

- `Статус атаки` - показ активної служби та останніх рядків логу.
- `Розширення портів` - створює `/etc/sysctl.d/99-cdss-port-range.conf` з `net.ipv4.ip_local_port_range=16384 65535` і застосовує `sysctl --system`.
- `DDOS` - встановлення та керування інструментами `MHDDOS`, `DISTRESS`, `X100`.
- `Налаштування безпеки` - встановлення та керування firewall backend і Fail2ban.

## Інструменти

| Інструмент | Підтримка | Що робить CDSS |
|---|---|---|
| MHDDOS | `amd64`, `arm64`; не підтримує `386`, `arm32`, Void/runit | Завантажує `mhddos_proxy_linux`, генерує `mhddos.service`, керує запуском, статусом, автозапуском і cron-розкладом. |
| DISTRESS | `amd64`, `arm64`, `arm32`; systemd/openrc; не підтримує `386` і runit | Завантажує `distress`, генерує `distress.service`, керує запуском, статусом, автозапуском і cron-розкладом. |
| X100 | Docker + systemd + `amd64`/`arm64` | Встановлює/перевіряє Docker, завантажує `x100-for-docker.tar.gz`, налаштовує `x100-config.txt`, створює `x100.service`, керує запуском, статусом, автозапуском і cron-розкладом. |

Під час запуску одного інструмента CDSS зупиняє інші активні інструменти, щоб одночасно не працювали кілька служб.

## Конфігурація

Основний файл конфігурації:

```text
/opt/cybercorps/services/EnvironmentFile
```

У ньому є секції:

- `[mhddos]` - `user-id`, `lang`, `copies`, `threads`, `proxies`, `ifaces`, `use-my-ip`, `extra-key`, `source`, `cron-to-run`, `cron-to-stop`.
- `[distress]` - `user-id`, `use-my-ip`, `use-tor`, `concurrency`, `interface`, flood-параметри, `proxies-path`, `source`, `cron-to-run`, `cron-to-stop`.
- `[x100]` - `itArmyUserId`, `initialDistressScale`, `ignoreBundledFreeVpn`, `cron-to-run`, `cron-to-stop`.

Меню налаштувань оновлює цей файл і регенерує відповідний `ExecStart` у service-файлі.

## Автозапуск І Розклад

CDSS підтримує:

- systemd/openrc автозапуск для `mhddos`, `distress`, `x100`, якщо платформа підтримується;
- root/system cron-розклад запуску та зупинки для кожного інструмента;
- службові cron-маркери формату `# CDSS:<job_id>`.

На Void Linux з runit підтримка часткова: enable/disable для сервісів недоступні, частина сценаріїв потребує ручної перевірки.

## Безпека Системи

Systemd-сервіси запускаються від системного користувача `cdss` з `NoNewPrivileges=true`, `ProtectSystem=strict` та явно дозволеними writable-шляхами для логів, тимчасових файлів і X100 runtime-директорії.

Розділ безпеки встановлює та налаштовує:

- firewall backend із `platform_matrix.sh`: `ufw` для Debian/Arch/Void family, `firewalld` для RHEL family;
- Fail2ban із конфігом `/etc/fail2ban/jail.d/cdss-ssh.conf`;
- правила firewall з deny incoming, allow outgoing і дозволом SSH-порту `22`.

## Підтримка Платформ

| Дистрибутив | Family | Init | Статус | Примітки |
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
| CentOS | rhel | systemd | Partial support | CentOS Stream визначається як full, інші CentOS - partial. |
| Void Linux | void | runit | Partial support | Обмеження для сервісів і автозапуску. |
| Gentoo | gentoo | varies | Unsupported | Інсталяція зупиняється. |

Архітектури нормалізуються так: `x86_64 -> amd64`, `i386/i686 -> 386`, `aarch64 -> arm64`, `armv6/armv7/armv8/armhf/arm32 -> arm32`.

## Оновлення

CDSS перевіряє `version.txt` у GitHub і зберігає timestamp останньої перевірки в `/etc/environment` як `CDSS_DEPLOYMENT_VERSION`. Якщо минуло більше 5 хвилин, запускається `git pull --all` у директорії встановлення і, для systemd, регенеруються service-файли.

## Перевірка Перед Релізом

У репозиторії є:

```bash
bash release_checklist.sh
```

Скрипт перевіряє platform matrix, відсутність жорстко заданого package manager, наявність support table у README, і синтаксис ключових Bash-файлів.

## Troubleshooting

### `sudo: command not found`
Якщо ви запускаєте CDSS від non-root і `sudo` не встановлено — скрипт виведе помилку і завершиться. Встановіть `sudo` або запустіть як `root`.

### Немає прав на `/opt/cybercorps`
Якщо root створив директорію, а подальший non-root update не має прав — переконайтеся, що `cdss` запускається від одного й того ж користувача.

### Service manager не дозволяє керування службами
На Void Linux з runit підтримка часткова: enable/disable для сервісів недоступні. На Gentoo — повна відсутність підтримки.

### Cron недоступний
Якщо cron-пакет не встановлено, автоматичні завдання не працюватимуть. Встановіть cron-пакет вручну: `apt-get install cron`, `dnf install cronie`, тощо.
