# Project Context — Facturame

## Descripción

**Facturame** es una app Android para registrar datos de clientes y enviarlos al backend `push_cliente`. En versiones anteriores enviaba los datos por WhatsApp; desde la v1.1 los envía directamente al backend vía HTTP y puede recibir notificaciones push.

### Despliegue actual

- Panel web: `https://facturame.appsigasv.com`
- Backend recomendado para la app: `https://facturame.appsigasv.com`
- La web usa mismo origen y proxya `/api` hacia Laravel en el VPS.
- El APK release final ya no necesita `usesCleartextTraffic` porque la conexiÃ³n queda sobre HTTPS.

---

## Stack tecnológico

| Capa | Tecnología |
|---|---|
| Framework | Flutter 3.41.5 / Dart 3.11.3 |
| Plataforma | Android (minSdk 21 / targetSdk según flutter) |
| Push notifications | Firebase Cloud Messaging |
| HTTP client | `http ^1.2.2` |
| Almacenamiento local | `shared_preferences ^2.2.2` |
| UUID del dispositivo | `uuid ^4.5.1` |

---

## Arquitectura

```
app_clientes/
├── lib/
│   ├── main.dart                    — Punto de entrada, UI, lógica de negocio
│   ├── services/
│   │   ├── firebase_service.dart    — FCM: permisos, streams, token
│   │   └── api_service.dart         — HTTP calls al backend push_cliente
│   └── helpers/
│       └── device_uuid.dart         — UUID único persistente del dispositivo
├── android/
│   ├── app/
│   │   ├── google-services.json     — Firebase config (requiere descarga manual)
│   │   ├── build.gradle.kts         — Plugin google-services
│   │   └── src/main/
│   │       └── AndroidManifest.xml  — Permisos + canal FCM
│   └── settings.gradle.kts          — Classpath google-services
└── pubspec.yaml                     — Dependencias
```

---

## Configuración en la app (SharedPreferences)

| Key | Default | Descripción |
|---|---|---|
| `backend_url` | `http://192.168.1.10:8000` | URL del backend push_cliente |
| `nombre_empresa` | `EMPRESA DE PRUEBA` | Nombre de la empresa |
| `nombre_servidor` | `SIGA1` | Identificador del servidor |
| `num_registro` | _(vacío)_ | Registro IVA de la empresa |
| `celularserver` | `63092051` | Número del operador destino |
| `nombre_usuario` | `OPERADOR` | Nombre del usuario registrador |
| `device_uuid` | _(generado)_ | UUID único del dispositivo |

Los defaults del instalador release también pueden inyectarse con `--dart-define` usando:
`APP_DEFAULT_BACKEND_URL`, `APP_DEFAULT_NOMBRE_EMPRESA`, `APP_DEFAULT_NUM_REGISTRO`,
`APP_DEFAULT_NOMBRE_SERVIDOR`, `APP_DEFAULT_CELULAR_DESTINO`, `APP_DEFAULT_NOMBRE_USUARIO`.

---

## Endpoints del backend usados

| Endpoint | Auth | Cuándo |
|---|---|---|
| `POST /api/v1/clientes/registrar-dispositivo` | Público | Al iniciar la app |
| `POST /api/v1/clientes/enviar-datos` | Público | Al enviar datos del cliente |
| `POST /api/v1/clientes/confirmar-recepcion` | Público | Al abrir el detalle de una notificación |
| `POST /api/v1/clientes-compartidos/sync` | Público | Al iniciar, reanudar y guardar clientes |

---

## Flujo principal

```
1. Inicio
   ├─► Cargar configuración (SharedPreferences)
   ├─► Firebase.initializeApp()
   └─► _inicializarPush()
         ├─► FirebaseService.initialize()
         ├─► Suscribir a onForegroundMessage → SnackBar azul
         ├─► Suscribir a onNotificationTap → preparado para nav futura
         ├─► DeviceUuid.getOrCreate()
         └─► ApiService.registrarDispositivo(...)

2. Registro de cliente
   ├─► Usuario llena formulario
   ├─► Diálogo de confirmación
   └─► ApiService.enviarDatos(registro_iva, numero_destino, titulo, cuerpo)
         ├─► Éxito → SnackBar verde → ¿Nuevo cliente?
         └─► Error → SnackBar rojo

3. Recepción de push
   ├─► Foreground → SnackBar azul con título y cuerpo
   ├─► Background → Notificación del sistema (automática)
   └─► Tap → diálogo de detalle + confirmación de recepción al backend
```

---

## Campos del formulario

| Campo | Obligatorio | Mayúsculas |
|---|---|---|
| Nombres del cliente | Sí | Sí |
| DUI | No | — |
| Registro IVA | No | Sí |
| Giro | No | Sí |
| Dirección | Sí | Sí |
| Celular | No | — |
| Email | No | — |
| Concepto | Sí | Sí |
| Monto | Sí | — |

---

## Historial de versiones

| Versión | Descripción |
|---|---|
| 1.0.0+1 | Envío por WhatsApp (`url_launcher`) |
| 1.1.0+2 | Reemplazo WhatsApp → HTTP POST + FCM básico |
| 1.1.0+2* | FCM completo: streams foreground/tap, `FirebaseService`, `DeviceUuid` |
| 1.1.0+2** | Confirmación de recepción + sincronización compartida de clientes |

---

## Pendiente

- [ ] Múltiples destinos desde la app móvil
- [ ] Modo offline con cola de reintentos
- [ ] Seguir modularizando `main.dart`
