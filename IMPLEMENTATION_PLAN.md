# План реалізації безпечного оновлення CDSS

## Мета

Виправити середовище, у якому працюють вбудовані updater-и модулів `mhddos`, `distress` і `x100`, не дублюючи їхню логіку оновлення та не пошкоджуючи наявні активні версії CDSS і модулів.

Користувач запускає тільки:

```bash
cdss
```

Скрипт сам визначає, чи він працює від `root`, чи має виконувати системні операції через `sudo`.

## Основні правила

- Tracked-файли CDSS примусово синхронізуються з публічним `origin/main`.
- Користувацькі налаштування модулів не стираються.
- Untracked runtime-файли модулів і X100-каталог не видаляються.
- Updater-и модулів не дублюються в CDSS.
- Активні модулі не зупиняються неявно під час звичайного запуску `cdss`.
- `ProtectSystem=strict`, `User=cdss` і `NoNewPrivileges=true` зберігаються.
- Усі privileged-операції виконуються через `sudo_or_root`.
- Будь-яка часткова помилка залишає попередню робочу версію.
- Версійний гейт оновлення (`version.txt` + throttle 300 с) зберігається.
- Після будь-якого force-sync власність дерева CDSS — `cdss:cdss`.
- `reload_runtime_files` виконується після force-sync, щоб сесія працювала на новому коді.

## 1. Інвентаризація updater-ів

Перед змінами зафіксувати для кожного підтримуваного модуля:

- executable або runtime-каталог, який updater замінює;
- батьківський каталог, у якому виконується atomic replace;
- спосіб визначення нової версії;
- поведінку updater-а при помилці;
- необхідність restart після оновлення;
- роботу на systemd, openrc та WSL.

Таблиця початкових шляхів:

| Модуль | Runtime | Service | Очікуваний writable path |
|---|---|---|---|
| MHDDOS | `bin/mhddos_proxy_linux` | `mhddos.service` | `$SCRIPT_DIR/bin` |
| DISTRESS | `bin/distress` | `distress.service` | `$SCRIPT_DIR/bin` |
| X100 | `x100-for-docker` | `x100.service` | `$SCRIPT_DIR/x100-for-docker` |

У першому релізі шляхи не переносити.

Результати інвентаризації (зафіксовано до змін):

| Модуль | Updater (функція) | Спосіб визначення нової версії | Replace | Поведінка при помилці | Restart після оновлення |
|---|---|---|---|---|---|
| MHDDOS | `install_mhddos` (utils/mhddos.sh:3) | GitHub `releases/latest` (без фіксації версії) | in-place перезапис `curl -Lo` у `$SCRIPT_DIR/bin/` | повідомлення + `return 1`, старий бінарник лишається | лише явна дія користувача |
| DISTRESS | `install_distress` (utils/distress.sh:3) | GitHub `releases/latest` (без фіксації версії) | in-place перезапис `curl -Lo` у `$SCRIPT_DIR/bin/` | повідомлення + `return 1`, старий бінарник лишається | лише явна дія користувача |
| X100 | `install_x100` (utils/x100.sh:273) | raw-URL гілки `main` (без фіксації версії) | `tar xzf` у `$SCRIPT_DIR/x100-for-docker/` (untracked у дереві CDSS) | повідомлення + `return 1`, старий каталог лишається | лише явна дія користувача |

Обмеження релізу (зафіксовано):

- Service-файли модулів встановлюються symlink'ами в `/etc/systemd/system` тільки на systemd (`create_symlink`, menu/ddos_tool_managment.sh:41). На openrc/runit модулі не працюють як сервіси — відоме обмеження, у першому релізі не виправляти.
- Updater-и модулів викликаються з меню та з `--auto-install` і є re-entrant; CDSS їхню логіку не дублює.

## 2. Root/sudo-контракт

Перевірити й використовувати наявні `require_privileges`, `sudo_or_root` і `get_real_user`.

Підтримати всі сценарії:

```text
root + clean install
non-root + clean install
root + in-place update
non-root + in-place update
```

Очікувана поведінка:

- при `EUID=0` команди виконуються напряму;
- при non-root системні команди виконуються через `sudo`;
- користувач запускає `cdss`, а не обов’язково `sudo cdss`;
- при відсутності sudo CDSS показує зрозумілу помилку;
- не використовувати прямі `chown`, `chmod`, `mv`, `install` або `systemctl` для системних шляхів поза `sudo_or_root`.

Контракт власності git-репозиторію:

- Після встановлення дерево `/opt/cybercorps` належить `cdss:cdss` (install.sh:197).
- Усі git-команди force-sync виконуються через `sudo_or_root`.
- Зберігати `git config --global safe.directory` для `SCRIPT_DIR` (install.sh:198-200, utils/updater.sh:131-132) — обов'язково, бо root виконує git у репозиторії користувача `cdss`.
- Після успішного force-sync: `sudo_or_root chown -R cdss:cdss "$SCRIPT_DIR"` (зберігає поточну поведінку utils/updater.sh:130).
- Обґрунтування: root-owned об'єкти `.git` або worktree зламають наступні non-root операції; єдина власність `cdss:cdss` + `safe.directory` працює і для root, і для non-root запуску.

Відомі дефекти привілеїв, які виправляються в межах цього плану:

- utils/x100.sh:331 — голий `chown -R cdss:cdss` без `sudo_or_root` і без перевірки помилки → перевести на `sudo_or_root`.
- utils/x100.sh:345-347 — голий `find | xargs chmod` → перевести на `sudo_or_root`.
- menu/main_menu.sh:25 — `log_cancel_event` викликається, але не визначений ніде → визначити функцію (запис події в `/var/log/cdss.log` через `sudo_or_root tee`) або прибрати виклик.

## 3. Force-sync CDSS

У `utils/updater.sh` замінити неконтрольований сценарій `git pull --all` на контрольований force-sync:

1. Перевірити безпечний шлях і git-репозиторій.
2. Зберегти поточний commit.
3. Створити backup локального tracked diff для діагностики.
4. Зберегти список untracked-файлів.
5. Перевірити доступність `origin/main`.
6. Виконати `git fetch origin main`.
7. При помилці `fetch` нічого не змінювати.
8. Виконати `git reset --hard origin/main`.
9. Не виконувати `git clean -fd`.
10. `sudo_or_root chown -R cdss:cdss "$SCRIPT_DIR"` (контракт власності, §2).

Збереження наявної логіки навколо force-sync:

- Версійний гейт: force-sync виконується тільки якщо `version.txt` з GitHub відрізняється від локального (utils/updater.sh:51-82). Якщо версії рівні — git-операції не виконуються, але runtime-міграція (§6) все одно запускається.
- Throttle 300 с через `CDSS_DEPLOYMENT_VERSION` у `/etc/environment` (utils/updater.sh:35-49) зберігається.
- `write_version` викликається і при успіху, і при мережевій помилці (уникнення retry-spam) — зберігається.
- Крок 5 («перевірити доступність `origin/main`») реалізується як `git ls-remote --exit-code origin main` через `sudo_or_root`.
- Backup локального tracked diff та список untracked-файлів зберігаються у `/var/lib/cdss/last-update-backup/` (файли `tracked.diff`, `untracked.txt`, `commit`) через `sudo_or_root`.
- Якщо `origin` відсутній або перейменований (fork) — зрозуміле повідомлення, поточна версія не змінюється.

Локальні зміни коду CDSS, service-шаблонів і скриптів перезаписуються. Backup потрібен лише для rollback і діагностики, а не для автоматичного повторного застосування.

Помилки доступу до публічного GitHub, мережі, DNS, TLS або пошкодженого `.git` повинні залишати поточну робочу версію.

## 4. Збереження налаштувань модулів

До force-sync зберегти:

```text
services/EnvironmentFile
```

Після синхронізації:

1. Прочитати новий upstream-шаблон.
2. Зберегти старі значення секцій `mhddos`, `distress` і `x100`.
3. Прийняти нові upstream-ключі та дефолти.
4. Повторно застосувати користувацькі значення.
5. Зберегти cron-параметри.
6. Виконати `apply_patch`.
7. Регенерувати service-файли з оновленого конфігу.

Пріоритет:

```text
нова upstream-структура + старі користувацькі значення
```

Крайові випадки merge:

- Ключ зі старого файлу, якого немає в новій upstream-структурі → зберігається (користувацькі дані не видаляються).
- Ключ у новій upstream-структурі, якого не було в старому файлі → upstream-дефолт.
- Зламаний/нечитаний старий EnvironmentFile → новий шаблон застосовується як є, backup зберігається, причина логується.
- Реалізувати як окрему функцію `merge_environment_file` на базі `get_config_value`/`set_config_value` (utils/definitions.sh).
- Спеціалізована логіка `apply_patch` (похідний ключ `disable-udp-flood` від `use-my-ip`, utils/datapatch.sh:21-27) зберігається і виконується після merge.

## 5. Runtime environment helper

Додати:

```text
utils/runtime_environment.sh
```

Функції:

```bash
ensure_runtime_update_environment
ensure_module_runtime_permissions
ensure_module_service_policy
ensure_runtime_service_reload
```

Helper повинен лише:

- перевіряти runtime-шляхи;
- виправляти дозволені власники та права;
- перевіряти `ReadWritePaths`;
- виправляти service-файли;
- виконувати `daemon-reload`;
- логувати результат.

Helper не повинен завантажувати або встановлювати модулі.

Не використовувати безумовно:

```bash
chown -R cdss:cdss /opt/cybercorps
ReadWritePaths=/opt/cybercorps
```

Змінювати тільки явно визначені runtime-шляхи.

Канонічні `ReadWritePaths` (єдине значення для всіх writer'ів):

| Модуль | ReadWritePaths |
|---|---|
| mhddos | `${SCRIPT_DIR}/bin /var/log /tmp` |
| distress | `${SCRIPT_DIR}/bin /var/log /tmp` |
| x100 | `${SCRIPT_DIR}/x100-for-docker /var/log /tmp` |

Ці значення мають збігатися в усіх місцях запису:

- шаблони `services/mhddos.service`, `services/distress.service`, `services/x100.service`;
- `regenerate_mhddos_service_file` (utils/mhddos.sh:228);
- `regenerate_distress_service_file` (utils/distress.sh:226);
- `regenerate_x100_service_file` (utils/x100.sh:540);
- `ensure_module_service_policy` (utils/runtime_environment.sh).

Канонічні права runtime-файлів (виправляє `ensure_module_runtime_permissions`):

- `bin/mhddos_proxy_linux`, `bin/distress` → `cdss:cdss`, 755;
- `x100-for-docker/` → `cdss:cdss` (каталоги 755, файли 644, `*.bash` 755).

`ensure_module_service_policy` покриває всі три модулі (поточний sed-патч у `update_cdss` покриває лише mhddos+distress, utils/updater.sh:137 — виправити).

Інтеграція з `reload_runtime_files`:

- `utils/runtime_environment.sh` додати до списку runtime-файлів.
- Об'єднати два дублікати `reload_runtime_files` (bin/cdss:32-63 та utils/updater.sh:165-192; їхні списки різні) в одну канонічну реалізацію з однаковим списком.
- `reload_runtime_files` виконується після force-sync (див. §6).

## 6. Інтеграція запуску

Для звичайного `cdss` і `--auto-install` використовувати спільний порядок:

```text
require_privileges
початкове source runtime-файлів
якщо версія застаріла (гейт version.txt + throttle 300 с):
    backup module settings
    force-sync CDSS
    restore/merge module settings
reload_runtime_files (завжди, після force-sync)
apply_patch
ensure_runtime_update_environment
daemon-reload if needed
main_menu
```

Важливо: `reload_runtime_files` має виконуватися після force-sync, а не до нього — інакше поточна сесія продовжить використовувати старі функції, завантажені до оновлення.

Runtime migration повинна запускатися навіть якщо:

- CDSS уже актуальна;
- `git fetch` або force-sync завершився помилкою;
- установка була створена старою версією CDSS.

## 7. Активні модулі

Під час звичайного запуску `cdss`:

- не зупиняти активні модулі;
- не змінювати їхні параметри;
- не замінювати їхні executable через CDSS;
- не виконувати неявний restart;
- застосовувати нову service-політику до наступного запуску.

Для окремого контрольованого ремонту передбачити:

```bash
cdss --repair-runtime
```

Специфікація `--repair-runtime`:

- Окремий режим `bin/cdss` (як `--restore`/`--uninstall`), виконується до меню.
- Область дії: усі три service-и (mhddos, distress, x100).
- Алгоритм:
  1. Зафіксувати стан кожного service (active/inactive) до ремонту.
  2. `ensure_runtime_update_environment` (права, канонічні `ReadWritePaths`, service-файли).
  3. Атомарне оновлення service-файлів і symlink'ів у `/etc/systemd/system` (§8) + `daemon-reload`.
  4. Перезапуск «за потреби» = service зараз active І (його unit-файл на диску змінився під час цього запуску АБО service у стані `failed`). Неактивні service не запускаються.
  5. Перевірка: active service лишаються active (`service_is_active`), неактивні лишаються неактивними.
  6. Rollback: якщо active service не став active після перезапуску → відновити service-файл з backup, `daemon-reload`, повторний перезапуск, зрозуміле повідомлення з точною причиною.
- Тільки systemd; на openrc/runit — зрозуміле повідомлення про відсутність підтримки і безпечний no-op.

## 8. Atomic operations і rollback

Для service-файлів:

1. Створити тимчасовий файл.
2. Перевірити його структуру (мінімум):
   - наявність секцій `[Unit]` і `[Service]`;
   - `ExecStart=` присутній і не дорівнює `placeholder`;
   - `ReadWritePaths=` присутній і збігається з канонічним значенням модуля (§5);
   - `User=cdss`, `NoNewPrivileges=true`, `ProtectSystem=strict` присутні.
3. Створити backup у `/var/lib/cdss/service-backups/<unit>.service.<timestamp>` через `sudo_or_root`.
4. Виконати atomic rename.
5. Виконати `daemon-reload`.
6. Перевірити стан unit-файла: `sudo_or_root systemctl cat <unit>` повертає 0.

Symlink'и в `/etc/systemd/system`:

- перед `rm` перевірити, що цільовий service-файл існує;
- після `ln -sf` перевірити, що symlink розгортається на наявний файл;
- при помилці відновити попередню ціль symlink (запам'ятати до заміни).

При помилці після force-sync:

- відновити старий commit (`git reset --hard <old_commit>` через `sudo_or_root` + `chown -R cdss:cdss`);
- відновити `EnvironmentFile` з backup;
- відновити service-файли з backup;
- `daemon-reload`;
- не видаляти untracked runtime-файли;
- зберегти точну причину в `/var/log/cdss.log`.

## 9. Локалізація

Провести аудит усього коду:

- українська та англійська таблиці;
- відсутні ключі;
- зайві ключі;
- fallback;
- параметри в повідомленнях;
- escape-послідовності;
- `dialog` і звичайний CLI-вивід;
- повідомлення root/sudo;
- Git/network/rollback/systemd помилки;
- повідомлення runtime migration;
- чиста установка та оновлення на WSL.

Нові повідомлення не повинні містити жорстко зашитий текст лише однією мовою.

Механізм параметризованих повідомлень:

- Наразі `trans "…: $var"` не перекладається ніколи: змінна розгортається до пошуку ключа, а ключі en.sh з `\$var` (~30 шт.) не збігаються з розгорнутим значенням і є мертвими.
- Ввести функцію `transf` (translate + format): `transf "Шаблон з %s" "$arg1" "$arg2"` — перекладає шаблон, потім підставляє аргументи через `printf`.
- Усі параметризовані повідомлення переписати на `transf` з `%s`; відповідні ключі i18n/en.sh переписати як англійські шаблони з `%s`; мертві ключі з `\$var` видалити.

Покриття ключів (результат аудиту):

- Додати всі відсутні ключі: 98 рядків `trans` у коді не мають ключа в i18n/en.sh (~68 статичних + ~30 параметризованих).
- Видалити 46 зайвих ключів i18n/en.sh: ~30 мертвих `\$var` (замінюються `%s`-шаблонами) та ~16 легасі/дублі («Налаштування безпеки» ×2, «Управління ддос інструментами» ×2, варіанти «фаервол/фаєрвол», «Встановлюємо Docker»/«Встановлюємо докер», «Встановлена версія», «Встановлення ддос інструментів», «Інтерфейс: », «Назва інтерфейсу (ensXXX, ethX, тощо.)», «Для збору особистої статистики…», «Не можливо виконати дію», «X100 не встановлений, будь ласка встановіть і спробуйте знову», «Docker успішно встановлено», «Встановлюємо Fail2ban», «Налаштовуємо Fail2ban», «Встановлюємо UFW фаєрвол», «Налаштовуємо UFW фаєрвол», «Фаєрвол UFW встановлено і деактивовано», «Фаєрвол UFW налаштовано і активовано», «UFW не встановлений…», «UFW успішно увімкнено/вимкнено»).
- Повний перелік генерується автоматичним key-coverage check (див. §10).

Автоматизація:

- Додати key-coverage check: кожен ключ `trans`/`transf` у коді (bin/, utils/, menu/, install.sh) має існувати в i18n/en.sh, і навпаки — без сиротних ключів.
- Нові повідомлення, додані під час реалізації, додаються в i18n/en.sh в тому самому коміті.

## 10. Тести

### Static/shell

- bash syntax усіх змінених скриптів;
- перевірка `sudo_or_root` для privileged-команд;
- перевірка service-шаблонів;
- відсутність `git clean -fd`;
- відсутність небезпечного глобального `chown`;
- наявність обох локалізацій.

### Сценарії

Перевірити:

- root clean install;
- non-root clean install через `cdss`;
- root in-place update;
- non-root in-place update через `cdss`;
- актуальну CDSS;
- застарілу CDSS;
- локальні tracked-зміни;
- збереження `EnvironmentFile`;
- збереження untracked-модулів;
- активний і неактивний модуль;
- недоступний GitHub;
- помилку `fetch`;
- відсутність sudo;
- відсутність systemd;
- пошкоджений service-файл;
- rollback;
- повторний ідемпотентний запуск.

### Harness

- Статичні перевірки: розширити `scripts/check.sh` та `release_checklist.sh`:
  - наявність `sudo_or_root` для git-команд у `utils/updater.sh`;
  - відсутність голих `chown`/`chmod`/`mv`/`systemctl` поза `sudo_or_root` (allowlist: utils/privileges.sh, рядки-повідомлення);
  - i18n key-coverage check (окремий скрипт `tests/i18n_coverage.sh`);
  - канонічні `ReadWritePaths` (§5) збігаються в усіх місцях запису;
  - `utils/runtime_environment.sh` присутній у списку `reload_runtime_files`; `reload_runtime_files` має єдину реалізацію.
- Сценарії, що тестуються stub'ами (systemctl, мережа, `sudo_or_root`), — у `tests/` як окремі test-функції (розширення tests/test_core.sh або нові файли).
- Повні WSL-сценарії (§11) — ручний runbook з чек-листом; те, що можна перевірити автоматично, — асерами в smoke_wsl.sh.

## 11. WSL-перевірка

Припущення: сценарії з активним модулем виконуються на WSL2 з увімкненим systemd; сценарій «відсутність systemd» — на WSL без systemd.

### Чиста установка

Перевірити:

- залежності;
- автоматичне визначення root/sudo;
- користувача `cdss`;
- права runtime-файлів;
- service-файли;
- CLI та dialog;
- поведінку без systemd;
- українську та англійську локалізацію.

### In-place update

Створити старий стан із:

- root-owned runtime-файлами;
- відсутніми `ReadWritePaths`;
- локальними tracked-змінами;
- користувацькими module settings;
- активним модулем.

Запустити:

```bash
cdss
```

Перевірити:

- force-sync коду;
- збереження налаштувань;
- збереження untracked payloads;
- автоматичну runtime-міграцію;
- відсутність неочікуваного restart;
- коректність наступного запуску;
- rollback;
- повторну ідемпотентну міграцію.

## 12. Критерії приймання

Рішення готове до релізу, якщо:

- `cdss` сам визначає root або sudo;
- clean install і in-place update працюють у root/sudo-сценаріях;
- tracked-код CDSS force-sync-иться з `origin/main`;
- налаштування модулів не втрачаються;
- untracked runtime-файли не видаляються;
- вбудовані updater-и модулів не дублюються;
- активні модулі не зупиняються неявно;
- старий стан можна відновити після часткової помилки;
- sandbox не послаблюється ширше необхідного;
- українська й англійська локалізації коректно відображаються;
- WSL clean-install та in-place update проходять повністю;
- i18n key-coverage check проходить: 0 відсутніх і 0 сиротних ключів;
- канонічні `ReadWritePaths` (§5) збігаються в усіх місцях запису;
- `reload_runtime_files` — єдина реалізація, включає `utils/runtime_environment.sh`, виконується після force-sync;
- git-команди, `chown`, `chmod`, `mv`, `systemctl` виконуються тільки через `sudo_or_root`;
- власність дерева CDSS після оновлення — `cdss:cdss`.

Перший реліз реалізувати без перенесення runtime-файлів у нову структуру каталогів. Таке перенесення можливе лише окремим backward-compatible етапом після підтвердження поведінки updater-ів усіх модулів.
