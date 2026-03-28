# Facturame

App Android para registro de clientes y envío de datos al backend `push_cliente` con soporte de notificaciones push via Firebase Cloud Messaging.

## Requisitos

- Flutter 3.41.x / Dart 3.11.x
- Android Studio o VS Code con extensión Flutter
- Archivo `android/app/google-services.json` (ver [FIREBASE_SETUP.md](FIREBASE_SETUP.md))
- Backend `push_cliente` corriendo (ver [push_cliente](https://github.com/juliocruiz2021/push_cliente))

## Setup rápido

```bash
# 1. Instalar dependencias
flutter pub get

# 2. Colocar google-services.json en android/app/ (ver FIREBASE_SETUP.md)

# 3. Ejecutar en dispositivo conectado
flutter run

# 4. Build APK de release
flutter build apk --release
# APK en: build/app/outputs/flutter-apk/app-release.apk
```

## Build release con defaults embebidos

Para generar un APK ya preconfigurado para produccion:

```powershell
.\scripts\build_release.ps1 `
  -BackendUrl 'https://api.tu-dominio.com' `
  -NombreEmpresa 'TU EMPRESA' `
  -NumRegistro '12345-6' `
  -NombreServidor 'SIGA1' `
  -CelularDestino '70001111'
```

La app mantiene la configuracion editable, pero el instalador ya llega con esos valores cargados por defecto.

## Configuración de la app

Al abrir la app, tocar el ícono ⚙️ y configurar:

| Campo | Descripción |
|---|---|
| URL del backend | IP del servidor Laravel (ej. `http://192.168.1.x:8000`) |
| Número de registro | Registro IVA de la empresa (debe existir en el backend) |
| Número destino | Número del operador que recibirá las notificaciones |

> Para emulador Android usar `http://10.0.2.2:8000`

## Estructura

```
lib/
├── main.dart                    — UI y lógica principal
├── services/
│   ├── firebase_service.dart    — Firebase Cloud Messaging
│   └── api_service.dart         — HTTP calls al backend
└── helpers/
    └── device_uuid.dart         — UUID único del dispositivo
```

## Documentación

- [FIREBASE_SETUP.md](FIREBASE_SETUP.md) — Cómo configurar Firebase
- [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) — Arquitectura y contexto
- [INTEGRACION_PUSH.md](INTEGRACION_PUSH.md) — Integración con backend

## Repositorio

https://github.com/juliocruiz2021/facturame
