# Finanzas Autónomo

Flutter app for a self-employed person (autónomo) in Spain to track income/expenses,
issue invoices, scan receipts with AI, and estimate taxes (Modelo 130, IVA, IRPF).
Targets Android (native) and web (PWA, installed on iPhone via Safari — no Apple
dev account available, so iOS is web-only).

## Deployment (web/PWA)

- GitHub: https://github.com/runcoxi/Finanzas-Autonomo-app (same account as other
  Vercel-hosted projects)
- Live URL: https://finanzas-autonomo-app.vercel.app/
- Vercel project "finanzas-autonomo-app" — **Root Directory must be `deploy`**, not
  `web`. `web/` is the Flutter source template; `deploy/` is the built static output
  that actually gets served. This is a recurring gotcha — if the site ever shows a
  blank page in production, check this setting first before debugging code.
- Deploy flow (no CI; built locally then committed):
  ```
  flutter build web --release
  rm -rf deploy && mkdir deploy && cp -r build/web/* deploy/
  # recreate deploy/vercel.json (headers for sw cache + wasm content-type) — see git log
  git add -A && git commit -m "..." && git push
  ```
  Vercel auto-deploys on push to `main`.
- First cold load is ~12MB (canvaskit + main.dart.js + sqlite3.wasm) so it can take
  several seconds — `web/index.html` has a loading spinner (`#app-loading`, removed
  on the `flutter-first-frame` event) so this doesn't look like a broken/blank page.

## Web platform caveats

- **sqflite doesn't work on web by default.** Fixed via `sqflite_common_ffi_web`:
  `databaseFactory = databaseFactoryFfiWeb` is set in `main.dart` when `kIsWeb`.
  Requires `web/sqlite3.wasm` and `web/sqflite_sw.js` (generated via
  `dart run sqflite_common_ffi_web:setup`, already committed). Without this the
  app hangs forever on a black/blank screen at startup (DB open never resolves).
- **`dart:io File` doesn't work on web.** The ticket scanner (`scan_ticket_screen.dart`,
  `gemini_service.dart`) uses `Uint8List` bytes end-to-end instead of `File`/`Image.file`,
  which works identically on Android.
- DB schema is at version 3 (see `database_helper.dart` `_onUpgrade`): v2 added
  `transactions.image` (compressed receipt photo BLOB), v3 added the `clients` table.

## Other Android-related folders on this machine (do not confuse)

- `C:\Users\PcVip\Desktop\FinanzApp-Android` — a **different, unrelated** app
  ("FinanzApp Pro" — simple WebView+HTML finance tracker). Not this project.
- `C:\Users\PcVip\Desktop\ControlaTusFinanzas` — also a different, unrelated app.
