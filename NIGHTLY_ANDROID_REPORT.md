# Kosmos Proxy — Android nightly RC report

## 1. Итоговый статус

**READY: подписанный release APK создан и проверен.**

## 2. Что реализовано

- Завершён пользовательский ребрендинг и единая светлая presentation layer Космос Proxy: дизайн-система, onboarding, главная, серверы, профиль/подписка, настройки, поддержка, диалоги и состояния подключения.
- Пользовательские ссылки заменены на ресурсы Космос Proxy; обязательное upstream-attribution оставлено в лицензиях открытого ПО.
- Android branding включает `Kosmos Proxy` app label, splash/adaptive assets, notification labels и foreground notification.
- Восстановлена штатная Android-зависимость VPN-ядра: `hiddify-lib-android` v4.1.0 извлечён локально в игнорируемый `android/app/libs/hiddify-core.aar` согласно `make android-libs`.
- Нативные идентификаторы и VPN-архитектура не менялись.

## 3. Toolchain

Подтверждён portable локальный toolchain:

- Flutter 3.38.5 / Dart 3.10.4;
- Temurin JDK 17.0.20 с `javac`;
- Android SDK 36.0.0, Build Tools 36.0.0, NDK 28.2.13676358, CMake 3.22.1.

`flutter doctor -v`: Android toolchain — **OK**, все Android licenses accepted. Xcode/Chrome warnings не относятся к Android RC.

## 4. Локальные коммиты

- `46b34f59 docs: add Android RC nightly report` (перезаписан финальными фактами в рабочем дереве)
- `2accffca feat: complete Kosmos Proxy presentation layer`
- `31283d59 wip: checkpoint initial Kosmos Proxy rebranding`
- `310bd3ad docs: add Kosmos Proxy design system`
- `cf60509a chore: initialize Kosmos Proxy project rules`

## 5. Результат flutter analyze

Выполнен на Flutter 3.38.5: **240 issues, exit code 1**.

Это upstream lint/backlog: преимущественно generated protobuf, старые `unused_import`, directives ordering, deprecated API и тестовые dependency hints. Ошибок компиляции, вызванных текущими UI-изменениями, анализ не показал.

## 6. Результаты тестов

- `flutter test`: **PASS**, 25 тестов.
- `android/gradlew test lint --no-daemon`: часть доступных unit tests прошла, однако общий task завершился ошибкой upstream dependency: `:mobile_scanner:compileDebugUnitTestKotlin`, Jetifier не поддерживает class file major version 68 в `net.bytebuddy:byte-buddy:1.17.7`. Это не блокирует сборку APK; debug и signed release успешно собраны.

## 7. Результаты сборок

- Debug APK: **PASS** — `flutter build apk --debug --android-skip-build-dependency-validation`.
- Signed release APK: **PASS** — `flutter build apk --release --android-skip-build-dependency-validation`.
- Дополнительные нефатальные предупреждения: deprecated Java API у `in_app_review`, font-tree-shaking family warning и SDK XML version warning.

## 8. Путь к APK

- Release: `artifacts/android/Kosmos-Proxy-release.apk`
- Debug: `artifacts/android/Kosmos-Proxy-debug.apk`

## 9. SHA-256 и размер

- Release: `e15be0f8e75b774cdc76379e03d19274922e681f0853bf5e95180c2e1b88baae`, **337,641,691 bytes**.
- Debug: `f94cd142a4ec1f4390a1abe73ff026a0c4974833a74a52b077b2601d7cd1318d`, **439,447,792 bytes**.

## 10. applicationId, versionName и versionCode

- applicationId: `app.hiddify.com` (сознательно сохранён).
- versionName: `4.1.2`.
- versionCode: `40102`.
- Тип финальной сборки: universal signed release APK.

## 11. Результат проверки подписи

`apksigner verify --verbose --print-certs` — **PASS**:

- APK Signature Scheme v2: verified;
- один signer;
- RSA 4096-bit;
- certificate SHA-256: `dcb06dae5838e57f51b07ad7a6565c6bfed5692203fc37af2296e284e0927aa0`.

Постоянный keystore и `android/key.properties` не отслеживаются Git; пароль не выводился и не сохранялся в репозитории.

## 12. Оставшиеся упоминания Hiddify и причины

- `app.hiddify.com`, `com.hiddify.hiddify`, Dart package/imports, `hiddify-core` и deeplink `hiddify`: технические native/core identifiers, оставлены для совместимости VPN, импортов, shortcuts и существующих установок.
- LICENSE/NOTICE, upstream documentation, CI, Makefile, generated files и тестовые материалы: юридические, технические или upstream-материалы; не являются пользовательским Android UI.
- Android core AAR сохранён как техническая зависимость и загружается штатным Makefile-механизмом.

## 13. Известные проблемы

1. `flutter analyze` имеет 240 существующих lint/info/warning issues.
2. Общий Android `test lint` блокируется `mobile_scanner` / Jetifier на byte-buddy class-file 68; APK-сборки проходят.
3. Release APK большой (универсальный, содержит ABI `armeabi-v7a`, `arm64-v8a`, `x86_64` и VPN core). Для поставки можно отдельно выбрать ABI APK из `build/app/outputs/apk/release/`.
4. Ручной Android smoke test на физическом устройстве не выполнялся в этой сессии.

## 14. Что проверить вручную на Android

1. Первый запуск, импорт ссылки/QR/deeplink и переходы на сайт/поддержку/оферту.
2. VPN permission, connect/disconnect, восстановление состояния и foreground notification.
3. Выбор сервера, тест задержки, длинные названия, малый экран и увеличенный системный шрифт.
4. Настройки протокола, split tunneling и диагностику.
5. Quick Settings tile, launcher/adaptive/monochrome icons и Android 12 splash.
6. Экран «О приложении»: пользовательские ссылки и upstream attribution только в лицензиях.

## 15. git status --short

На момент отчёта:

```text
 M android/gradle.properties
 M lib/features/app/widget/app.dart
 M lib/features/proxy/active/active_proxy_card.dart
 M lib/features/proxy/overview/proxies_overview_page.dart
?? artifacts/
```

`android/key.properties` и `android/app/libs/hiddify-core.aar` игнорируются, в статус не попадают.

## 16. git diff --stat

```text
 android/gradle.properties                          |  6 +++-
 lib/features/app/widget/app.dart                   |  2 +-
 lib/features/proxy/active/active_proxy_card.dart   | 33 ++++++++++++-----
 lib/features/proxy/overview/proxies_overview_page.dart | 42 ++++++++++++++--------
 4 files changed, 58 insertions(+), 25 deletions(-)
```

## 17. Ограничения релиза

`git push`, изменение remote, merge в main, GitHub Release, публикация APK, Google Play upload и deployment **не выполнялись**.
