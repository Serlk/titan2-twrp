English: [INSTALL.md](INSTALL.md)

# Установка TWRP на Unihertz Titan 2

TWRP 3.7.1 для Titan 2: экран, тач, аппаратная клавиатура, adb, sideload, fastbootd, прошивка и
бэкапы разделов, **расшифровка `/data` вашим PIN-кодом блокировки**.

Готового образа `vendor_boot` в релизе нет: в нём были бы файлы Unihertz и MediaTek. В релизе
только часть TWRP и скрипт, который вставляет её в **ваш собственный** `vendor_boot`.

> **Внимание.** Нужен разблокированный загрузчик. Прочитайте инструкцию целиком до начала. Всё, что
> вы делаете, — на свой страх и риск.

---

## 1. Что нужно

| Что | Зачем |
|---|---|
| Titan 2 (MT6878), прошивка **V01.00.14** (сток Android 16 или crDroid/GSI поверх её vendor) | TWRP собран и проверен на ней |
| Разблокированный загрузчик | иначе телефон не примет изменённый vendor_boot |
| ПК с Linux, Windows или macOS: свежие `platform-tools` (adb/fastboot) и **Python 3** | сборка вашего образа и прошивка |
| Root на телефоне (Magisk/KernelSU) — желательно | снять свой vendor_boot и бэкапы из шага 3 |
| Файлы релиза | `twrp-titan2-recovery-<дата>.lz4`, `titan2-twrp-vendor-boot.py`, `SHA256SUMS` |

Сверьте контрольные суммы: `sha256sum -c SHA256SUMS`.

---

## 2. Чего никогда не делать

- **Не прошивайте и не стирайте** `preloader`, `lk`, `seccfg`, `tee`, `nvram`, `nvdata`, `nvcfg`,
  `protect1`, `protect2`, `proinfo`, `md*`. Там IMEI, калибровки и ключи TEE, потеря безвозвратна.
- **Не переключайте слот в TWRP** (Reboot → слот A/B). На этом телефоне это не работает, а в слоте B
  старые загрузчики.
- **Не нажимайте Format Data / Wipe**, если расшифровка не удалась: это сотрёт всё. Лучше соберите
  лог (шаг 7) и спросите в теме.
- **В первый раз не входите в recovery через `adb reboot recovery`.** Android при этом записывает
  загрузчику команду «загрузиться в recovery», а LK выполняет её *раньше*, чем смотрит на кнопки:
  пока команда записана, телефон каждый раз грузится в recovery, и меню кнопками (и fastboot)
  недоступно. TWRP стирает команду, когда вы перезагружаетесь из его меню. Первый раз входите
  кнопками (шаг 5).

---

## 3. Резервная копия (не пропускайте)

С root в Android или через adb в TWRP **до ввода PIN**:

```
adb exec-out su -c 'dd if=/dev/block/by-name/vendor_boot_a' > vendor_boot_a.img
adb exec-out su -c 'dd if=/dev/block/by-name/init_boot_a'   > init_boot_a.img
adb exec-out su -c 'dd if=/dev/block/by-name/protect1'      > protect1.img
adb exec-out su -c 'dd if=/dev/block/by-name/protect2'      > protect2.img
adb exec-out su -c 'dd if=/dev/block/by-name/metadata'      > metadata.img
adb exec-out su -c 'dd if=/dev/block/by-name/nvram'       > nvram.img
adb exec-out su -c 'dd if=/dev/block/by-name/nvdata'      > nvdata.img
adb exec-out su -c 'dd if=/dev/block/by-name/nvcfg'       > nvcfg.img
adb exec-out su -c 'dd if=/dev/block/by-name/proinfo'     > proinfo.img
```

(`exec-out` не портит двоичные данные. В TWRP adb уже root: уберите `su -c`, то есть
`adb exec-out dd if=/dev/block/by-name/vendor_boot_a > vendor_boot_a.img`.)

Зачем каждый:

| Образ | Зачем |
|---|---|
| `vendor_boot_a` | ваш стоковый vendor_boot: вход для шага 4 и путь назад |
| `init_boot_a` | проверка размера в шаге 4 |
| `protect1`, `protect2` | хранилище TEE (записи Gatekeeper и KeyMint). Расшифровка в TWRP запускает TEE, и он их обновляет; если Android после TWRP перестанет принимать PIN, это возвращается отсюда |
| `metadata` | ключ шифрования метаданных `/data` |
| `nvram`, `nvdata`, `nvcfg`, `proinfo` | IMEI и калибровки — храните в любом случае |

Храните образы не на телефоне. Активный слот: `adb shell getprop ro.boot.slot_suffix` (обычно
`_a`; если `_b`, везде ниже замените `_a` на `_b`).

Без root: возьмите `vendor_boot.img` и `init_boot.img` из официального пакета прошивки **ровно той
версии**, что стоит на телефоне («О телефоне»). В vendor_boot другой версии модули ядра не
подойдут к вашему ядру.

---

## 4. Соберите свой образ

```
python3 titan2-twrp-vendor-boot.py vendor_boot_a.img twrp-titan2-recovery-<дата>.lz4 vendor_boot-twrp.img --init-boot init_boot_a.img
```

Скрипт оставляет от вашего vendor_boot всё, кроме части recovery, и проверяет ограничение
загрузчика на 64 МБ рамдисков (если его превысить, телефон не загрузится совсем). Если что-то не
так, он ничего не записывает. В конце должно быть `... KiB free` и `written vendor_boot-twrp.img`.

---

## 5. Прошивка и вход в TWRP

```
adb reboot bootloader
fastboot getvar current-slot          # a
fastboot flash vendor_boot_a vendor_boot-twrp.img
fastboot reboot
```

Android грузится как раньше: TWRP читается только при загрузке в recovery.

Вход в TWRP: выключите телефон, зажмите **громкость вверх + питание**, пока не появится меню
загрузчика («Select Boot Mode»). Громкостью вверх выберите **Recovery Mode**, громкостью вниз
подтвердите.

---

## 6. Первый запуск

1. TWRP сам расшифрует метаданные `/data` и спросит **PIN** блокировки экрана (или
   графический ключ/пароль). Введите его — станет доступна внутренняя память.
2. Выходите из TWRP через **Reboot → System**. Перед каждой перезагрузкой и выключением TWRP
   исправляет SELinux-метки записей TEE, которые он трогал, и Android принимает PIN как обычно.
3. Файлы копируйте через `adb pull /sdcard/...` и `adb push`: MTP выключен.

---

## 7. Если что-то пошло не так

| Проблема | Что делать |
|---|---|
| Телефон каждый раз грузится в TWRP | перезагрузитесь из меню TWRP (Reboot → System). Если TWRP не работает, но есть adb: `adb shell dd if=/dev/zero of=/dev/block/by-name/misc bs=2048 count=1` (стирает только команду загрузки), затем `adb reboot` |
| «Wrong PIN» в Android после TWRP | не вводите PIN много раз подряд (Gatekeeper начнёт задержки). Подключите adb и посмотрите `logcat \| grep -i gatekeeper`; записи TEE лежат на `protect1` (`/mnt/vendor/protect_f/tee`): `restorecon -RF /mnt/vendor/protect_f/tee` или восстановление записи из вашего `protect1.img` |
| TWRP не расшифровывает | `adb pull /tmp/recovery.log` и `adb logcat`; ничего не форматируйте |
| Вернуть стоковый recovery | `fastboot flash vendor_boot_a vendor_boot_a.img` (ваш бэкап) |
| Не попасть в fastboot | при выключенном телефоне зажать громкость вниз и питание |

Исходники и как это устроено: [README.md](../README.md).
