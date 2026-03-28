# Contexto del Proyecto — Para OpenAI Codex / Claude

## ¿Qué es este sistema?

Sistema de notificaciones push para empresas compuesto por **tres aplicaciones** que trabajan juntas:

1. **App móvil Android "Facturame"** — Flutter — para operadores de campo
2. **API Backend "Push Cliente"** — Laravel 11 + PostgreSQL + FCM — lógica de negocio y envío push
3. **Panel web "Push Cliente"** — React + Vite — para administradores

---

## Repositorios GitHub

| Proyecto | Repo | Branch activo |
|---|---|---|
| App móvil Flutter | `juliocruiz2021/facturame` | `feature/firebase_push_setup` |
| Backend + Frontend web | `juliocruiz2021/push_cliente` | `feature/push_cliente_backend` |

---

## Rutas locales

| Proyecto | Ruta |
|---|---|
| App Flutter | `D:\Desarrollo_Flutter\clientes\app_clientes\` |
| Backend Laravel | `D:\Desarrollo_Flutter\push_cliente\backend\` |
| Frontend React | `D:\Desarrollo_Flutter\push_cliente\frontend\` |
| APK de distribución | `D:\Desarrollo_Flutter\clientes\facturame.apk` |

---

## Cómo se relacionan las tres aplicaciones

```
┌─────────────────────────────────────────────────────────────┐
│                    FLUJO COMPLETO                            │
│                                                             │
│  App Flutter (operador)                                     │
│    │  1. Al iniciar: registra dispositivo con celular_propio │
│    │  2. Operador llena formulario con datos del cliente     │
│    │  3. Toca "Enviar" → POST /api/v1/clientes/enviar-datos  │
│    │  4. Muestra SnackBar: "✓ Notificación enviada a XXXX"  │
│    ▼                                                        │
│  Backend Laravel (API)                                      │
│    │  5. Busca FCM token por numero_celular == numero_destino│
│    │  6. Envía push vía kreait/firebase-php (FCM)           │
│    │  7. Guarda mensaje en BD con estado                    │
│    ▼                                                        │
│  Teléfono destino (app Flutter)                             │
│    │  8. Recibe notificación push de Firebase               │
│    │  9. Al tocar: muestra diálogo con datos del JSON       │
│    │  10. Al cerrar diálogo: badge se decrementa            │
│                                                             │
│  Panel web React (admin)                                    │
│    │  Polling cada 20s → GET /api/v1/mensajes/nuevos        │
│    │  Badge rojo con conteo de mensajes no vistos           │
│    └─ Al llegar nuevos: notificación del navegador          │
└─────────────────────────────────────────────────────────────┘
```

### Relación entre las tres apps

| App Flutter | API Backend | Panel Web React |
|---|---|---|
| Registra dispositivo (FCM token + celular_propio) | Guarda en `clientes_empresa` | Lista en `/clientes` |
| Envía datos del cliente | Crea `mensajes`, reenvía por FCM | Muestra en `/mensajes` |
| Recibe push, muestra diálogo | Marca estado `enviado`/`fallido` | Badge tiempo real |

---

## Stack tecnológico

### App móvil (Flutter Android)
- Flutter 3.x / Dart
- `firebase_messaging` — push notifications FCM
- `flutter_local_notifications` — banner en foreground con canal de alta importancia
- `shared_preferences` — persistencia local de config y notificaciones
- `http` — llamadas al backend
- `uuid` — identificador único del dispositivo
- MethodChannel `facturame/device_info` — leer número SIM y abrir ajustes del SIM
- `MainActivity.kt` implementa el canal nativo

### Backend (Laravel 11)
- PHP 8.2 / Laravel 11
- PostgreSQL
- Laravel Sanctum (autenticación admin web)
- `kreait/firebase-php` — envío FCM
- Credenciales Firebase: `storage/app/firebase-credentials.json`

### Frontend web (React + Vite)
- React 18 + React Router v6
- TanStack Query (React Query) — data fetching y caché
- Tailwind CSS
- Axios — HTTP client con baseURL `http://127.0.0.1:8000/api/v1`
- Puerto Vite: 5200

---

## Base de datos (PostgreSQL)

```
empresas
  id, nombre, registro_iva, activo, timestamps

clientes_empresa
  id, empresa_id, numero_celular, nombre_usuario, nombre_servidor,
  device_uuid, fcm_token, plataforma, version_app, activo, timestamps

mensajes
  id, empresa_id, cliente_empresa_id, numero_destino, titulo, cuerpo,
  payload_json (jsonb), estado (pendiente|enviado|fallido),
  proveedor, enviado_at, timestamps

admin_users
  id, name, email, password, timestamps

personal_access_tokens (Sanctum)
logs_auditoria
```

---

## Flujo completo del sistema

```
Operador (Facturame app)
  │ llena formulario: nombre, DUI, registro IVA, giro, dirección,
  │ celular, email, concepto, monto
  │
  ▼
POST /api/v1/clientes/enviar-datos
  {registro_iva, numero_destino: celularserver, titulo, cuerpo: JSON}
  │
  ▼
Backend busca clientes_empresa donde numero_celular == numero_destino
  → obtiene fcm_token del destinatario
  → FcmService envía FCM a ese token
  │
  ▼
Teléfono destino recibe notificación push
  └─ Toca notificación → diálogo con campos del JSON
     └─ Al cerrar → badge decrementado
```

### JSON enviado como `cuerpo` del mensaje
```json
{
  "empresa": "NOMBRE EMPRESA",
  "servidor": "SIGA1",
  "data": {
    "nombre": "JUAN PEREZ",
    "dui": "12345678",
    "registro_iva": "12345-6",
    "giro": "COMERCIAL",
    "direccion": "CALLE 1",
    "celular": "76543210",
    "email": "juan@email.com",
    "concepto": "FACTURA",
    "monto": 150.00
  }
}
```

---

## App móvil — Configuración por celular

| Campo | Clave SharedPrefs | Descripción |
|---|---|---|
| URL del backend | `backend_url` | `http://192.168.1.10:8000` |
| Nombre empresa | `nombre_empresa` | Mostrado en la app |
| Nombre servidor | `nombre_servidor` | Identifica el sistema (ej. SIGA1) |
| Num. Registro IVA | `num_registro` | Identifica la empresa en el backend |
| Número destino | `celularserver` | Número al que SE ENVÍAN las notificaciones |
| Mi número celular | `celular_propio` | Número PROPIO de ESTE teléfono (registro en BD) |
| Nombre usuario | `nombre_usuario` | Nombre del operador |

### CRÍTICO — celular_propio vs celularserver

- `celular_propio` = número de ESTE teléfono → se guarda en `clientes_empresa.numero_celular`
- `celularserver` = número DESTINO → a quien se envían las notificaciones
- **NUNCA usar celularserver como fallback para celular_propio**: causaría que el operador sobreescriba el FCM token del destinatario en la BD, y las notificaciones llegarían al operador en vez del destino.
- Si `celular_propio` está vacío → el dispositivo NO se registra → aparece aviso naranja.

### Obtener número propio en configuración

El campo "Mi número celular" tiene un ícono 📱 verde. Al tocarlo:
1. Si el SIM expone el número → lo pega en el campo y lo copia al portapapeles
2. Si el SIM no lo expone → abre **Ajustes → Acerca del teléfono** para verlo manualmente
3. Si el permiso no estaba concedido → muestra diálogo de Android + aviso para reintentar

Métodos usados en Kotlin (`MainActivity.kt`):
- `TelephonyManager.getLine1Number()` (intento 1)
- `SubscriptionManager.activeSubscriptionInfoList` (intento 2, Android 5.1+)
- `openSimSettings` → abre `Settings.ACTION_DEVICE_INFO_SETTINGS`

---

## App móvil — Archivos clave

```
lib/
  main.dart                          — Pantalla principal + toda la lógica
  services/
    api_service.dart                 — HTTP calls al backend
    firebase_service.dart            — FCM + local notifications
  screens/
    notificaciones_screen.dart       — Historial + NotificacionLocal + NotificacionesDB
  helpers/
    device_uuid.dart                 — UUID único del dispositivo

android/app/src/main/
  kotlin/.../MainActivity.kt         — MethodChannel: getPhoneNumber, requestPhonePermission,
                                       openSimSettings
  AndroidManifest.xml                — Permisos: INTERNET, POST_NOTIFICATIONS,
                                       READ_PHONE_STATE, READ_PHONE_NUMBERS
```

### Badge (notificaciones no leídas)
- `NotificacionesDB.marcarComoVistas()` → actualiza timestamp `notif_vista_en`
- `NotificacionesDB.contarNoVistas()` → cuenta notificaciones más recientes que el timestamp
- Badge baja cuando: se abre historial O se cierra el diálogo de detalle push

### Confirmación de envío
- Éxito: SnackBar verde `✓ Notificación enviada a XXXXXXXX`
- Error: SnackBar rojo `✗ Error al enviar: <mensaje>`
- Sin celular_propio: SnackBar naranja `⚠ Configura "Mi número celular"...`

---

## Backend — Endpoints API

### Públicos (app móvil, sin auth)
```
POST /api/v1/clientes/registrar-dispositivo
  Body: {registro_iva, numero_celular, nombre_usuario, nombre_servidor,
         device_uuid, fcm_token, plataforma, version_app}
  Llave única: (empresa_id, numero_celular) → updateOrCreate

POST /api/v1/clientes/enviar-datos
  Body: {registro_iva, numero_destino, titulo, cuerpo}
  Busca: clientes_empresa WHERE numero_celular = numero_destino
```

### Protegidos (Sanctum, panel web)
```
POST   /api/v1/auth/login
POST   /api/v1/auth/logout
GET    /api/v1/auth/me

GET    /api/v1/dashboard
GET    /api/v1/empresas          — lista, con clientes:nombre_servidor
POST   /api/v1/empresas
PUT    /api/v1/empresas/{id}
DELETE /api/v1/empresas/{id}

GET    /api/v1/clientes          — lista con empresa eager loaded

POST   /api/v1/mensajes/enviar
GET    /api/v1/mensajes/historial?registro_iva&estado&fecha_desde&fecha_hasta&search&page
GET    /api/v1/mensajes/nuevos?desde=<ISO>  — para polling tiempo real
```

---

## Frontend web — Páginas

| Ruta | Descripción |
|---|---|
| `/login` | Autenticación admin |
| `/dashboard` | Estadísticas generales |
| `/empresas` | CRUD empresas + Servidor(es) como badges |
| `/clientes` | Lista dispositivos con empresa y nombre_servidor |
| `/mensajes` | Historial + enviar modal + ModalDetalle con campos JSON |

### Notificaciones en tiempo real
- `NotifContext.jsx` — polling 20s, badge global, Web Notifications API
- `Layout.jsx` — campanita con badge rojo
- `Mensajes.jsx` — banner de nuevos mensajes + auto-refresh

---

## Estado actual — Lo que YA funciona

### App móvil
- [x] Envía datos al backend vía HTTP
- [x] Registro de dispositivo con `celular_propio` (nunca con `celularserver`)
- [x] Si `celular_propio` vacío: NO registra + aviso naranja al usuario
- [x] Notificación push llega al teléfono DESTINO (no al operador)
- [x] Al enviar: SnackBar confirma "✓ Notificación enviada a XXXXXXXX"
- [x] Al tocar notificación: diálogo con campos JSON (empresa, servidor, DUI, IVA, giro…)
- [x] Al cerrar diálogo: badge decrementado
- [x] Historial de notificaciones recibidas
- [x] Botón 📱 en config para obtener número propio (copia al portapapeles si puede leerlo, abre Ajustes si no)
- [x] FCM token refresh automático (solo si celular_propio configurado)

### Backend
- [x] Registra/actualiza dispositivos (llave: empresa_id + numero_celular)
- [x] Busca destinatario por numero_celular == numero_destino
- [x] Envía FCM al token correcto
- [x] Historial con filtros y paginación
- [x] Endpoint `/mensajes/nuevos` para polling
- [x] CRUD empresas con servers registrados

### Panel web
- [x] Login, dashboard, empresas, clientes, mensajes
- [x] Polling tiempo real (badge + notificación navegador)
- [x] ModalDetalle con campos JSON formateados
- [x] nombre_servidor en Clientes y Empresas

---

## Lo que FALTA / Pendiente

- [ ] **Múltiples destinos**: operador solo puede enviar a UN número destino
- [ ] **Confirmación de recepción**: no se sabe si el destino vio la notificación
- [ ] **Modo offline**: sin internet los datos se pierden
- [ ] **Push web (PWA)**: notificaciones del navegador solo funcionan con panel abierto

---

## Cómo correr el proyecto localmente

### Backend Laravel
```bash
cd D:\Desarrollo_Flutter\push_cliente\backend
C:\xampp\php\php.exe artisan serve --host=0.0.0.0 --port=8000
```

### Frontend React
```bash
cd D:\Desarrollo_Flutter\push_cliente\frontend
npm run dev -- --port 5200
# http://localhost:5200 — admin@pushcliente.com / password
```

### App Flutter
```bash
cd D:\Desarrollo_Flutter\clientes\app_clientes
flutter build apk --release
# APK → build\app\outputs\flutter-apk\app-release.apk
# Copia → D:\Desarrollo_Flutter\clientes\facturame.apk
```

### ADB
```bash
# Flutter:  C:\Users\julio\AppData\Local\Programs\flutter\bin\flutter.bat
# ADB:      C:\Users\julio\AppData\Local\Android\Sdk\platform-tools\adb.exe
adb devices
adb -s <device_id> install -r facturame.apk
```

---

## Variables de entorno

### Backend `.env`
```
DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=push_cliente
FRONTEND_URL=http://localhost:5200
```

### Frontend `.env.local`
```
VITE_API_URL=http://127.0.0.1:8000/api/v1
```

### Firebase
- Backend: `backend/storage/app/firebase-credentials.json`
- Android: `android/app/google-services.json`

---

## Notas técnicas importantes

1. **Docker puerto 8000**: usar `127.0.0.1:8000` no `localhost:8000` (IPv6).

2. **`ilike` PostgreSQL**: usar `ilike` para búsquedas, no `like`.

3. **Canal FCM Android**: crear `facturame_channel` con `Importance.HIGH` en código Dart, no solo AndroidManifest.

4. **Modelo AdminUser**: autenticación web usa `App\Models\AdminUser`, NO `App\Models\User`.

5. **Parseo JSON notificación**: `cuerpo` es string JSON. Parsear con `jsonDecode(cuerpo)`. `empresa` y `servidor` están al nivel raíz; los datos de factura en `json['data']`.

6. **celular_propio NUNCA puede ser celularserver**: el bug histórico era usar el número destino como número propio. Esto sobreescribía el FCM token del jefe con el del operador.

7. **esFactura (frontend)**: `!!(data.nombre || data.dui || data.registro_iva || data.giro || data.concepto)`.

8. **SIM no expone número**: en muchos operadores de Centroamérica `TelephonyManager.getLine1Number()` devuelve null. Se usa `SubscriptionManager` como fallback. Si ambos fallan, se abre Settings para que el usuario lo vea y escriba manualmente.

9. **Badge app móvil**: timestamp `notif_vista_en` en SharedPrefs. Se resetea al abrir historial o al cerrar diálogo de detalle push.
