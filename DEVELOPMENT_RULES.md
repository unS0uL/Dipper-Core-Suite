# DEVELOPMENT_RULES.md — Dipper Core Suite Development & Audit Standard

> [!IMPORTANT]
> **ОБЯЗАТЕЛЬНЫЙ РЕГЛАМЕНТ ДЛЯ ВСЕХ AI-АГЕНТОВ И РАЗРАБОТЧИКОВ**  
> Настоящий документ является верховным стандартом качества, безопасности и архитектуры для проекта **Dipper Core Suite** и низкоуровневых модификаций Xiaomi Mi 8 (`dipper`) под управлением Android 14 (crDroid 10 / LineageOS 21).  
> **Любые изменения в кодовой базе, скриптах, конфигурациях и интерфейсах ОБЯЗАНЫ строго и безоговорочно следовать каждому правилу из этого документа.**

---

## ЧАСТЬ 1. Семь фундаментальных законов архитектуры модуля

### 1. Закон «Анти-Бутлуп» (Non-Blocking Init & Fail-Safe Boot)
* **1.1.** Скрипт `service.sh` и любые скрипты автозапуска **никогда** не должны блокировать загрузку Android.
* **1.2.** Запрещены бесконечные циклы `while/until` без верхнего предела таймаута (fail-safe timeout). Все фоновые службы (например, `audio_watchdog.sh`) обязаны отсоединяться от родительского шелла через `nohup ... &`.
* **1.3.** Все команды обязаны иметь безопасный перехват ошибок (`2>/dev/null` или запись в отладочный лог). Скрипт обязан завершаться с кодом `exit 0`, чтобы менеджер модулей (Magisk/KernelSU) не счёл модуль сбойным и не перевёл ОС в Magisk Safe Mode.
* **1.4.** **Никаких изменений в `/persist`:** разделы `/persist` и `/mnt/vendor/persist` не подлежат прямой записи/перезаписи скриптами модуля. Все оверрайды производятся исключительно в `runtime` (через DeviceConfig, sysfs, bind mounts).

### 2. Закон Строгой Обратимости (Zero-Reboot LIFO Restoration)
* **2.1.** Любое действие `enable` обязано иметь зеркальное, стопроцентно обратимое действие `disable`.
* **2.2.** Отключение фичи должно возвращать устройство в **точное стоковое состояние без необходимости перезагрузки**.
* **2.3.** **Порядок LIFO (Last-In, First-Out):** Восстановление стока в `disable` обязано происходить строго в обратном порядке по отношению к `enable`:
  - `enable`: `[1] sysfs config -> [2] pm disable сервиса -> [3] mount -o bind -> [4] pkill HAL`
  - `disable`: `[3] umount -l -> [2] pm enable сервиса -> [1] sysfs stock -> [4] pkill HAL`
* **2.4.** **Zero Residue:** При `disable` не должно оставаться фоновых подпроцессов, висячих дескрипторов или lock-файлов.

### 3. Закон Идемпотентности и Параллелизма (Idempotency & Concurrency)
* **3.1.** Повторный вызов команды с тем же состоянием (`enable` поверх уже `enabled`, или `disable` поверх `disabled`) обязан быть **безопасным холостым вызовом**:
  - Перед `mount -o bind` обязательна проверка `/proc/mounts`, исключающая вложенные каскадные маунты.
  - Перед `umount -l` обязательна проверка наличия точки монтирования.
  - Перед запуском демона обязательна проверка `pgrep`.
* **3.2.** Критические секции обязаны быть защищены от параллельного запуска (дабл-клик в WebUI, параллельный CLI-вызов) через атомарные мьютексы в RAM (`tmpfs`).

### 4. Закон Чистоты SELinux (Context Preservation & Zero AVC Denials)
* **4.1.** Любой монтируемый (`mount -o bind`) или создаваемый файл обязан иметь правильный системный контекст безопасности SELinux:
  - Конфигурации аудио для вендора (`/vendor/etc/*`): `u:object_r:vendor_configs_file:s0` (а не `system_file:s0` или `magisk_file:s0`).
  - Клавиатурные раскладки (`/system/usr/keylayout/*`): `u:object_r:system_file:s0`.
* **4.2.** При применении конфигурации обязателен явный вызов `chcon` для предотвращения скрытых блокировок `avc: denied { read }` со стороны изолированных Vendor HAL доменов.

### 5. Закон Чистого POSIX `/system/bin/sh` (Zero Warnings & Pure Portability)
* **5.1.** Строгий запрет «башизмов»:
  - Запрещено: `[[ ... ]]` $\rightarrow$ Разрешено: `[ ... ]`
  - Запрещено: `echo -n` $\rightarrow$ Разрешено: `printf '%s'`
  - Запрещено: массивы `arr=(...)`, синтаксис `<<<`, специфичные расширения Bash.
* **5.2.** Все пути и переменные обязаны быть экранированы двойными кавычками (`"$MODDIR"`, `"$ACTION"`, `"$1"`).
* **5.3.** Динамическое определение путей: запрещены захардкоженные пути `/data/adb/modules/dipper_core_suite/` внутри скриптов — обязательно использование динамического `MODDIR=${0%/*}/..`.
* **5.4.** Полное соответствие `shellcheck -s sh` без исключений (0 ошибок, 0 предупреждений).

### 6. Закон Pre-Flight Защиты Системных Подсистем (Subsystem Guards)
* **6.1. Защита телефонии (Telephony Safety Guard):**
  - Запрещено отключать системный дозвонщик (`com.android.dialer`), если он является текущим активным приложением по умолчанию (`cmd role get-role-holders android.app.role.DIALER`).
  - Запрещено отключать стоковый дозвонщик, если в системе не обнаружено ни одной альтернативной работоспособной звонилки.
* **6.2. Изоляция датчиков (Sensors Isolation Guard):**
  - Разграничивать управление аппаратным IRQ Goodix (`soc:fingerprint_goodix/proximity_state`) и оптическим датчиком приближения AMS TMD2725.
  - Логику экранирования ложных касаний SystemUI решать на уровне `DeviceConfig` (`brightline_falsing_proximity_percent_covered_threshold`), не повреждая физическую калибровку сенсора в `persist`.

### 7. Закон Нулевого Износа Диска (Zero Disk Wear via tmpfs)
* **7.1.** Все временные файлы, lock-файлы, PID-файлы и runtime-статусы обязаны создаваться исключительно в оперативной памяти (RAM-диск `/dev/`, `tmpfs`).
* **7.2.** Запрещена циклическая непрерывная запись логов во Flash-память (`/data/`). Для логирования использовать кольцевой буфер Android Logcat (`log -p ... -t ...`).

---

## ЧАСТЬ 2. Обязательный пайплайн валидации (Verification Pipeline)

Перед коммитом любого изменения агент **ОБЯЗАН** выполнить следующий 5-шаговый контрольный цикл:

```text
[1. Shellcheck]  ──>  [2. Dry-Run Audit]  ──>  [3. Device Push]  ──>  [4. Test Suite]  ──>  [5. Release Zip]
 Strict POSIX sh        No hardcoded paths       Live Hot-Reload        64/64 PASS           Checksum & Sync
```

1. **Статический линтинг:**  
   `shellcheck -s sh scripts/*.sh *.sh tools/*.sh` $\rightarrow$ должно завершаться с кодом `0`.
2. **Аудит безопасности и дублирования:**  
   Проверка на отсутствие жестко прописанных путей (`grep -rn '/data/adb/modules' scripts/`), проверка наличия флагов в `case "$ACTION" in ... status)`.
3. **Горячая синхронизация (Hot-Reload) на тестовом устройстве:**  
   Перенос измененных файлов через `adb push` в `/data/adb/modules/dipper_core_suite/` с выставлением прав `chmod 755`.
4. **Запуск полного набора автотестов на реальном устройстве:**  
   `adb shell "su -c 'sh /data/adb/modules/dipper_core_suite/tools/test_suite.sh'"` $\rightarrow$ **100% тестов должны пройти успешно (0 FAILED)**.
5. **Сборка и проверка архива:**  
   Формирование чистого легковесного релизного ZIP без лишних служебных файлов git и docs.

---

## ЧАСТЬ 3. Карта скриптов и архитектурная матрица

| Скрипт | Назначение | Контролируемая подсистема | Метод обратимости (disable) |
|---|---|---|---|
| `scripts/toggle_fp.sh` | Пробуждение дисплея по сканеру Goodix | IRQ 334 kernel sysfs + Keylayout bind | Восстановление IRQ маски (644, 1) + umount keylayout |
| `scripts/toggle_aec.sh` | Устранение эха VoIP (No-AEC) | `/vendor/etc/audio_effects.xml` | `umount -l` + восстановление `vendor_configs_file` context |
| `scripts/toggle_watchdog.sh` | Защита от зависания аудиостека | Фоновый мониторинг `mode_ringer` | `pkill -9` демона |
| `scripts/toggle_statsd.sh` | Энергосбережение SDM845 Deep Sleep | `ctl.start statsd` / Soter kill | `resetprop ctl.stop statsd` |
| `scripts/toggle_scroll_profile.sh` | Кинематический 60Hz скролл (iOS/Android) | Schedutil + CPU Boost + GPU floor | Полное считывание и восстановление `scroll_stock.conf` |
| `scripts/toggle_dialer.sh` | Оптимизация спящего AOSP-дозвонщика | `com.android.dialer` wakelocks | `pm enable com.android.dialer` |
| `scripts/toggle_keyguard_swipe.sh` | Надежность свайпа разблокировки | SystemUI FalsingManager threshold | `device_config delete systemui ...` |
