# Kosmos Proxy — Android nightly RC report

## 1. Итоговый статус

**BLOCKED: APK не создан.** Пользовательский ребрендинг и Android presentation layer завершены локально, однако проверка и сборка заблокированы отсутствием готового Flutter/Dart/JDK/Android SDK toolchain на рабочей машине. Во время работы была начата локальная установка Flutter, Temurin JDK 17, Android command-line tools и WebP tools через Homebrew; на момент завершения скачивание Flutter и JDK ещё не было завершено. Фиктивный APK не создавался.

## 2. Что реализовано

- Единая светлая дизайн-система Космос Proxy: палитра, типографика, скругления, тени, карточки, bottom sheets, snackbar, навигация и состояния подключения.
- Переработаны onboarding, главный экран, подключение, серверы, карточка активного сервера, подписка/профили, настройки и «О приложении».
- Пользовательские ссылки заменены на сайт, поддержку, оферту и Telegram Космос Proxy.
- Обновления, которые вели бы к upstream или непубличному endpoint, отключены; update UI не отображается.
- Android-брендинг: app label, splash palette, adaptive launcher foreground, monochrome notification icon, notification channel, Quick Settings labels и foreground notification.
- Обязательная ссылка на upstream оставлена только в «Настройки → О приложении → Лицензии открытого ПО».
- VPN core, applicationId, namespace, package name и native package не менялись.

## 3. Что не удалось реализовать

- `flutter pub get`, code generation, `dart format`, `flutter analyze`, Flutter tests, Android tests/lint и APK-сборки не запускались: в исходном PATH отсутствовали `flutter`, `dart`, `java`, `sdkmanager`, `gradle`, `rustc` и `cargo`.
- APK (debug/release) не создан, подпись не проверена.
- Растровые legacy launcher WebP не пересобраны: adaptive icon уже использует обновлённый vector foreground; для конвертации WebP ожидается завершение установки локальных инструментов.

## 4. Локальные коммиты

- `2accffca feat: complete Kosmos Proxy presentation layer`
- `31283d59 wip: checkpoint initial Kosmos Proxy rebranding` (существующий checkpoint)
- `310bd3ad docs: add Kosmos Proxy design system` (существующий)
- `cf60509a chore: initialize Kosmos Proxy project rules` (существующий)

## 5. Результат flutter analyze

Не выполнен: `flutter` отсутствовал в PATH; установка Flutter не завершена.

## 6. Результаты тестов

Не выполнены: Flutter/Dart toolchain отсутствовал.

## 7. Результаты сборок

- Debug APK: не выполнена.
- Release APK: не выполнена.
- Причина: отсутствовал готовый Flutter + JDK + Android SDK toolchain.

## 8. Путь к APK

Не создан. Целевой путь после устранения блокера:
`artifacts/android/Kosmos-Proxy-release.apk`

## 9. SHA-256

Не применимо: APK не создан.

## 10. applicationId

`app.hiddify.com` (сознательно не менялся по требованию задачи).

## 11. versionName и versionCode

`4.1.2` / `40102` (из `pubspec.yaml`; Android получает значения через Flutter build).

## 12. Результат проверки подписи

Не выполнена: APK не создан. Keystore `/Users/yegorkapng/KosmosKeys/KosmosProxy-release.keystore` существует и не отслеживается Git. `android/key.properties` игнорируется и не создавался, пароль keystore не запрашивался без необходимости сборки.

## 13. Оставшиеся упоминания Hiddify и причины

- `Constants.licenseUrl` ведёт на upstream лицензию: обязательное attribution, доступно только через «Лицензии открытого ПО».
- `app.hiddify.com`, `com.hiddify.hiddify`, Dart package/imports, `hiddify-core` и deeplink `hiddify`: технические native/core identifiers. Не менялись, чтобы не повредить VPN, импорты, shortcuts и существующие установки.
- Upstream README, CI, Makefile, NOTICE/LICENSE, generated files и тестовые/технические материалы: не являются пользовательским Android UI и сохранены.

## 14. Известные проблемы

- Сборочный toolchain ещё скачивается; проверка компиляции изменений обязательна после завершения установки.
- Для release build нужно безопасно создать локальный, игнорируемый `android/key.properties` во время сборки, прочитав пароль из Keychain без вывода в консоль.
- URL `hiddify` остаётся в Android manifest и iOS scheme как совместимый технический deeplink; это не пользовательская ссылка/брендинг.

## 15. Чт�� проверить вручную на Android

1. Первый запуск: импорт ссылки/QR/deeplink, оферта и переход на `vpnkosmos.ru`.
2. VPN permission, подключение, отключение, восстановление состояния и foreground notification.
3. Выбор сервера и тест задержки, длинные названия/малый экран/увеличенный системный шрифт.
4. Настройки протокола, split tunneling и диагностику.
5. Quick Settings tile, launcher/adaptive/monochrome icons и Android 12 splash.
6. Экран «О приложении»: поддержка, Telegram, оферта, privacy и единственный upstream attribution в лицензиях.

## 16. git status --short

Чистое рабочее дерево до добавления данного отчёта.

## 17. git diff --stat

Чистый diff до добавления данного отчёта.

## 18. Ограничения релиза

`git push`, remote changes, merge в main, GitHub Release, публикация APK, Google Play upload и деплой не выполнялись.
