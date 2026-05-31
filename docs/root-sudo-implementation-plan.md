# План повної реалізації root/sudo handling у CDSS

Мета: CDSS має стабільно працювати у трьох основних сценаріях:

- запуск від `root` без встановленого `sudo`;
- запуск від звичайного користувача з доступним `sudo`;
- запуск від користувача, який має root-права або може виконувати привілейовані дії через налаштований механізм підвищення прав.

## Етап 1. Повний аудит привілеїв

1. Знайти всі прямі виклики `sudo`, `systemctl`, `rc-service`, `rc-update`, `sv`, `crontab`, пакетних менеджерів і файлових операцій у системних директоріях.
2. Розділити знайдені місця на категорії:
   - системні пакети: `apt-get`, `dnf`, `yum`, `pacman`, `xbps-install`, `emerge`;
   - service management: `systemctl`, `rc-service`, `rc-update`, `sv`;
   - system config writes: `/etc`, `/usr/local/bin`, `/var/log`, `/opt/cybercorps`;
   - cron management: `crontab -l`, `crontab <file>`;
   - network/security tools: `ufw`, `firewall-cmd`, `fail2ban`.
3. Зафіксувати кожне місце, де команда зараз запускається без `sudo_or_root`.
4. Перевірити, чи всі файли, які source-яться до визначення helper-а, не використовують privileged commands раніше часу.

Очікуваний результат: список усіх точок підвищення прав і місць, які можуть зламатися на root-only системі без `sudo`.

## Етап 2. Єдина модель визначення прав

1. Винести privilege helper у файл, який гарантовано source-иться найраніше, наприклад `utils/platform_matrix.sh` або окремий `utils/privileges.sh`.
2. Реалізувати функції:
   - `is_root()` - повертає true, якщо `id -u == 0`;
   - `has_sudo()` - перевіряє наявність `sudo`;
   - `require_privileges()` - зупиняє виконання лише якщо користувач не root і `sudo` недоступний;
   - `sudo_or_root()` - запускає команду напряму під root або через `sudo` для non-root.
3. Забезпечити fallback для раннього старту, коли переклади ще не завантажені: `trans() { echo "$@"; }`.
4. Уніфікувати повідомлення помилок для всіх entrypoint-ів.

Очікуваний результат: один канонічний privilege API без дублювання логіки в різних файлах.

## Етап 3. Міграція всіх privileged calls

1. Замінити всі прямі `sudo ...` на `sudo_or_root ...`.
2. Для service commands:
   - systemd: `sudo_or_root systemctl ...`;
   - OpenRC enable/disable: `sudo_or_root rc-update ...`;
   - OpenRC start/stop/status: перевірити, чи потрібен `sudo_or_root rc-service ...` для non-root;
   - runit: перевірити, чи потрібен `sudo_or_root sv ...` для керування службами.
3. Для пакетних менеджерів у `platform_matrix.sh`, `fail2ban.sh`, `x100.sh`, `install.sh` використовувати тільки `sudo_or_root`.
4. Для запису в `/etc`, `/usr/local/bin`, `/var/log`, `/opt/cybercorps` використовувати `sudo_or_root` або писати у temp-файл і переносити через `sudo_or_root mv`.
5. Для cron використовувати `sudo_or_root crontab`, щоб root-only і sudo-сценарії поводились однаково.

Очікуваний результат: у коді немає прямих privileged `sudo`, окрім текстових підказок користувачу.

## Етап 4. Поведінка entrypoint-ів

1. В `install.sh`:
   - source privilege helper до першого privileged action;
   - викликати `require_privileges` перед встановленням пакетів;
   - не вимагати `sudo`, якщо процес уже root.
2. В `bin/cdss`:
   - завантажувати кольори, `trans` fallback і privilege helper до перевірки прав;
   - викликати `require_privileges` перед меню або системними операціями;
   - гарантувати, що `--restore`, `--uninstall`, `--auto-install`, `config` не падають через відсутній `sudo` під root.
3. Перевірити, що source-порядок `utils` не створює залежностей від helper-а до його визначення.

Очікуваний результат: `sudo` не є обов'язковою залежністю, якщо CDSS запущено від root.

## Етап 5. Права на робочу директорію

1. Перевірити логіку створення `/opt/cybercorps`.
2. Для root-запуску вирішити цільового власника директорії:
   - якщо запускає root, лишати root-власника або явно документувати поведінку;
   - якщо запускає non-root із sudo, можна робити `chown "$(whoami)" "$WORKING_DIR"`.
3. Перевірити, що `git clone`, `git pull`, `chmod`, symlink і service generation працюють після вибраної ownership-моделі.
4. Уникнути ситуації, коли root створив директорію, а подальший non-root update не має прав.

Очікуваний результат: зрозуміла й стабільна ownership-модель для `/opt/cybercorps`.

## Етап 6. Тестова матриця

Перевірити щонайменше такі сценарії:

1. `root` без `sudo`:
   - `bash install.sh`;
   - `cdss`;
   - `cdss --auto-install`;
   - `cdss config`;
   - `cdss --restore`;
   - `cdss --uninstall`.
2. non-root із `sudo`:
   - ті самі команди;
   - перевірити, що `sudo` викликається тільки через helper.
3. non-root без `sudo`:
   - очікувана зрозуміла помилка перед системними змінами.
4. Платформи/init:
   - Debian/Ubuntu systemd;
   - RHEL-family systemd;
   - Arch/Manjaro systemd;
   - Void/runit partial support;
   - OpenRC, якщо є доступне тестове середовище.

Очікуваний результат: поведінка підтверджена не лише статичним пошуком, а й запуском ключових команд.

## Етап 7. Автоматизовані перевірки

1. Додати в `release_checklist.sh` перевірку:
   - немає прямих `sudo` у виконуваній логіці, окрім allowlist для README/повідомлень;
   - `sudo_or_root` визначений;
   - `install.sh` і `bin/cdss` викликають privilege validation.
2. Додати smoke-test або shell-test для симуляції:
   - `id -u == 0`;
   - `id -u != 0` + `sudo` available;
   - `id -u != 0` + `sudo` missing.
3. Перевірити `bash -n` для:
   - `install.sh`;
   - `bin/cdss`;
   - `utils/platform_matrix.sh`;
   - `utils/definitions.sh`;
   - `utils/scheduler.sh`;
   - усіх файлів у `utils/` і `menu/`.

Очікуваний результат: regressions у privilege handling ловляться перед релізом.

## Етап 8. Документація

1. Оновити README:
   - CDSS можна запускати від root без встановленого `sudo`;
   - для non-root потрібен `sudo`;
   - описати ownership `/opt/cybercorps`;
   - описати очікувану поведінку на minimal/root-only системах.
2. Додати troubleshooting:
   - `sudo: command not found`;
   - немає прав на `/opt/cybercorps`;
   - service manager не дозволяє керування службами;
   - cron недоступний.

Очікуваний результат: користувач розуміє, який режим запуску підтримується і що робити при помилках.

## Етап 9. Критерії готовності

Реалізацію можна вважати повною, якщо:

- під root CDSS не викликає `sudo`;
- під non-root CDSS використовує `sudo` тільки через `sudo_or_root`;
- non-root без `sudo` отримує ранню зрозумілу помилку;
- прямі privileged calls покриті helper-ом;
- `release_checklist.sh` ловить нові прямі `sudo`;
- README описує root-only і sudo-сценарії;
- smoke-тести пройдені на мінімум одній systemd-системі.
