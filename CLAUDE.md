# Claude Context - facturame

## What this repo is

`facturame` is the Flutter Android app used to register customer data, send it to `push_cliente`, and receive push notifications.

Production:
- Panel: `https://facturame.appsigasv.com`
- Backend used by the app: `https://facturame.appsigasv.com`
- APK output: `D:\Desarrollo_Flutter\clientes\facturame.apk`
- Active branch: `feature/confirmacion-recepcion-limpieza`

## Current mobile rules

### Device identity

- `celular_propio` is the number of THIS phone.
- `celularserver` is the destination number to which notifications are sent.
- Never use `celularserver` as fallback for `celular_propio`.

### Notification delivery model

- The app still registers per company using `celular_propio`.
- The backend now routes notifications by global `numero_celular`, not by destination company.
- A phone can receive notifications from multiple companies if the same number is registered in more than one company.
- The dialog shown to the user must use `empresa` and `servidor` from the incoming JSON payload, not the local app settings.

### Receipt confirmation

- When opening a notification detail, the app confirms receipt to the backend using `mensaje_id`, `numero_celular`, and optional `device_uuid`.

## Important files

- `lib/main.dart`
- `lib/services/api_service.dart`
- `lib/services/firebase_service.dart`
- `lib/services/recepcion_service.dart`
- `lib/screens/notificaciones_screen.dart`
- `lib/widgets/notif_detalle_dialog.dart`
- `lib/helpers/device_uuid.dart`
- `lib/config/app_defaults.dart`
- `scripts/build_release.ps1`

## Build and distribution

Use:

```powershell
.\scripts\build_release.ps1 `
  -BackendUrl 'https://facturame.appsigasv.com' `
  -NombreEmpresa 'EMPRESA DE PRUEBA' `
  -NumRegistro '12345-6' `
  -NombreServidor 'SIGA1' `
  -CelularDestino '63092051'
```

Notes:
- `MiCelular` should usually be left empty in distributable APKs because it depends on the target phone.
- The script already runs `flutter analyze`, `flutter test`, builds the APK and installs it over ADB if a device is connected.

## Docs to read first

- `README.md`
- `PROJECT_CONTEXT.md`
- `CONTEXTO_CODEX.md`
- `FIREBASE_SETUP.md`
- `INTEGRACION_PUSH.md`

## Current state already closed

- production defaults supported by `dart-define`
- HTTPS production backend
- push notifications working
- receipt confirmation working
- shared client sync working
- history and badge working

## Safe next areas to improve

- offline queue
- refactor `main.dart`
- more UI-level tests
- polish multi-company testing flows
