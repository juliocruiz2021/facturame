# Facturame

App Android Flutter para registrar datos de clientes, enviarlos al backend `push_cliente` y recibir notificaciones push.

## Produccion actual

- Panel: `https://facturame.appsigasv.com`
- Backend de la app: `https://facturame.appsigasv.com`
- APK de distribucion: `D:\Desarrollo_Flutter\clientes\facturame.apk`
- Rama activa: `feature/confirmacion-recepcion-limpieza`

## Lo importante hoy

- La app registra el telefono usando `celular_propio`.
- El backend ya no enruta por empresa destino, sino por coincidencia global de `numero_celular`.
- Si el mismo numero existe en varias empresas, ese mismo telefono puede recibir notificaciones de cualquiera de ellas.
- La empresa y el servidor que se muestran al usuario salen del JSON del mensaje recibido.

## Requisitos

- Flutter 3.41.x / Dart 3.11.x
- Android Studio o VS Code con Flutter
- `android/app/google-services.json`
- Backend `push_cliente`

## Setup rapido

```bash
flutter pub get
flutter run
```

## Build release con defaults embebidos

Script disponible:

```powershell
.\scripts\build_release.ps1 `
  -BackendUrl 'https://facturame.appsigasv.com' `
  -NombreEmpresa 'EMPRESA DE PRUEBA' `
  -NumRegistro '12345-6' `
  -NombreServidor 'SIGA1' `
  -CelularDestino '63092051'
```

El script:
- corre `flutter analyze`
- corre `flutter test`
- genera el APK release
- lo copia a `D:\Desarrollo_Flutter\clientes\facturame.apk`
- si el celular esta conectado por USB, lo instala automaticamente

## Configuracion de la app

Campos principales:

- URL del backend
- Nombre empresa
- Nombre servidor
- Numero de registro
- Numero destino
- Mi numero celular
- Nombre usuario

## Regla critica

- `Mi numero celular` = numero de ESTE telefono
- `Numero destino` = numero al que se enviaran las notificaciones

Nunca usar `Numero destino` como reemplazo de `Mi numero celular`.

## Archivos clave

- `lib/main.dart`
- `lib/services/api_service.dart`
- `lib/services/firebase_service.dart`
- `lib/services/recepcion_service.dart`
- `lib/screens/notificaciones_screen.dart`
- `lib/widgets/notif_detalle_dialog.dart`
- `lib/helpers/device_uuid.dart`
- `lib/config/app_defaults.dart`

## Documentacion

- [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md)
- [CONTEXTO_CODEX.md](CONTEXTO_CODEX.md)
- [FIREBASE_SETUP.md](FIREBASE_SETUP.md)
- [INTEGRACION_PUSH.md](INTEGRACION_PUSH.md)
