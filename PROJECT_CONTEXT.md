# Project Context — Facturame

## Descripción

**Facturame** es una app Android para registrar datos de clientes y enviarlos al backend `push_cliente`. En versiones anteriores enviaba los datos por WhatsApp; desde la v1.1 los envía directamente al backend vía HTTP y puede recibir notificaciones push.

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
| `backend_url` | `http://10.0.2.2:8000` | URL del backend push_cliente |
| `nombre_empresa` | `EMPRESA DE PRUEBA` | Nombre de la empresa |
| `nombre_servidor` | `SIGA1` | Identificador del servidor |
| `num_registro` | _(vacío)_ | Registro IVA de la empresa |
| `celularserver` | `63092051` | Número del operador destino |
| `nombre_usuario` | `OPERADOR` | Nombre del usuario registrador |
| `device_uuid` | _(generado)_ | UUID único del dispositivo |

---

## Endpoints del backend usados

| Endpoint | Auth | Cuándo |
|---|---|---|
| `POST /api/v1/clientes/registrar-dispositivo` | Público | Al iniciar la app |
| `POST /api/v1/clientes/enviar-datos` | Público | Al enviar datos del cliente |

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
   └─► Tap → _tapSub → TODO: navegación
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

---

## Pendiente

- [ ] Colocar `android/app/google-services.json` (descargar de Firebase Console)
- [ ] Configurar `backend_url` en la app con la IP real del servidor
- [ ] Implementar navegación en `onNotificationTap` (`_tapSub`)
- [ ] Agregar `flutter_local_notifications` para iconos/canal personalizados en foreground
- [ ] Build de release y APK para distribución
