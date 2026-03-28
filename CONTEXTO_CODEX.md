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
│    │  1. Al iniciar: lee SIM → guarda celular_propio        │
│    │  2. Registra dispositivo en backend (POST)             │
│    │  3. Operador llena formulario con datos del cliente     │
│    │  4. Toca "Enviar" → POST /api/v1/clientes/enviar-datos │
│    ▼                                                        │
│  Backend Laravel (API)                                      │
│    │  5. Recibe datos, busca FCM token del destino          │
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
| Registra dispositivo (FCM token + numero_celular) | Guarda en `clientes_empresa` | Lista en `/clientes` |
| Envía datos del cliente | Crea `mensajes`, reenvía por FCM | Muestra en `/mensajes` |
| Recibe push, muestra diálogo | Marca estado `enviado`/`fallido` | Badge tiempo real |
| Lee número SIM → `celular_propio` | Identifica dispositivo único | Muestra servidor en tabla |

---

## Stack tecnológico

### App móvil (Flutter Android)
- Flutter 3.x / Dart
- `firebase_messaging` — push notifications FCM
- `flutter_local_notifications` — banner en foreground con canal de alta importancia
- `shared_preferences` — persistencia local de config y notificaciones
- `http` — llamadas al backend
- `uuid` — identificador único del dispositivo
- MethodChannel `facturame/device_info` — leer número SIM desde Kotlin
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

### Tablas principales

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
  {registro_iva, numero_destino, titulo, cuerpo: JSON}
  │
  ▼
Backend crea Mensaje → FcmService → envía FCM al FCM token
del cliente con numero_celular == numero_destino
  │
  ▼
Teléfono destino recibe notificación push
  └─ Toca notificación → Facturame muestra diálogo con campos del JSON
     └─ Al cerrar diálogo → badge se decrementa a 0
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

Cada teléfono se configura en ⚙️ Configuración:

| Campo | Clave SharedPrefs | Descripción |
|---|---|---|
| URL del backend | `backend_url` | `http://192.168.1.10:8000` |
| Nombre empresa | `nombre_empresa` | Mostrado en la app |
| Nombre servidor | `nombre_servidor` | Identifica el sistema (ej. SIGA1) |
| Num. Registro IVA | `num_registro` | Identifica la empresa en el backend |
| Número destino | `celularserver` | Quién recibe las notificaciones |
| Mi número celular | `celular_propio` | Número propio de ESTE teléfono (registro) |
| Nombre usuario | `nombre_usuario` | Nombre del operador |

**Importante:** `celular_propio` es el número con que este dispositivo
se registra en `clientes_empresa.numero_celular`. `celularserver` es el
número DESTINO al que se envían las notificaciones. Son distintos.

**Auto-lectura del SIM:** Al arrancar la app, si `celular_propio` está vacío,
se lee automáticamente el número del SIM vía `MethodChannel('facturame/device_info')`
→ `requestPhonePermission` + `getPhoneNumber`, y se guarda en SharedPreferences.
En el diálogo de config se muestra el icono 📶 "leído del SIM" si fue detectado.

---

## App móvil — Archivos clave

```
lib/
  main.dart                          — Pantalla principal + toda la lógica
  services/
    api_service.dart                 — HTTP calls al backend
    firebase_service.dart            — FCM + local notifications
  screens/
    notificaciones_screen.dart       — Historial de notificaciones recibidas
                                       + NotificacionLocal model
                                       + NotificacionesDB (SharedPrefs)
  helpers/
    device_uuid.dart                 — UUID único del dispositivo

android/app/src/main/
  kotlin/.../MainActivity.kt         — MethodChannel para leer SIM
  AndroidManifest.xml                — Permisos: INTERNET, POST_NOTIFICATIONS,
                                       READ_PHONE_STATE, READ_PHONE_NUMBERS
```

### Lógica de badge (notificaciones no leídas)
- `NotificacionesDB.contarNoVistas()` — cuenta notificaciones después de `notif_vista_en`
- `NotificacionesDB.marcarComoVistas()` — actualiza timestamp `notif_vista_en` a NOW
- Al **tocar** una notificación push → se muestra diálogo → al cerrarlo: `marcarComoVistas()` + `_actualizarBadge()`
- Al **abrir** pantalla de historial → `marcarComoVistas()` automáticamente

---

## Backend — Endpoints API

### Públicos (app móvil, sin auth)
```
POST /api/v1/clientes/registrar-dispositivo
  Body: {registro_iva, numero_celular, nombre_usuario, nombre_servidor,
         device_uuid, fcm_token, plataforma, version_app}

POST /api/v1/clientes/enviar-datos
  Body: {registro_iva, numero_destino, titulo, cuerpo}
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
| `/empresas` | CRUD empresas + muestra servidor(es) registrados como badges |
| `/clientes` | Lista dispositivos registrados con empresa y servidor |
| `/mensajes` | Historial mensajes + enviar modal + detalle con campos JSON |

### Notificaciones en tiempo real (frontend)
- `NotifContext.jsx` — polling cada 20s a `/mensajes/nuevos?desde=<last_check>`
- `Layout.jsx` — campanita con badge rojo en el header
- Al llegar mensajes nuevos: badge se actualiza, notificación del navegador, auto-refresh lista
- Clic campanita → navega a `/mensajes`

### Archivos React clave
```
src/
  contexts/
    NotifContext.jsx         — polling tiempo real, badge global, Web Notifications API
  components/
    Layout.jsx               — estructura, header con NotifBell (badge)
  pages/
    Login.jsx
    Dashboard.jsx
    Empresas.jsx             — CRUD + columna Servidor(es) como badges
    Clientes.jsx             — lista con nombre_servidor debajo del nombre_usuario
    Mensajes.jsx             — historial + ModalDetalle con campos JSON formateados
  lib/
    axios.js                 — cliente HTTP con interceptor de auth
```

---

## Estado actual del sistema — Lo que YA funciona

### App móvil
- [x] Envía datos del cliente al backend vía HTTP
- [x] Al arrancar: lee número SIM automáticamente y guarda en config si estaba vacío
- [x] Cada dispositivo se registra con su PROPIO número (celular_propio ≠ celularserver)
- [x] Recibe push FCM, banner en Android (canal alta importancia)
- [x] Al tocar notificación → diálogo con campos JSON (empresa, servidor, DUI, IVA, giro, etc.)
- [x] Al cerrar el diálogo → badge decrementado a 0
- [x] Badge de mensajes no leídos en AppBar (campanita)
- [x] Historial de notificaciones recibidas
- [x] FCM token refresh automático

### Backend
- [x] Registra/actualiza dispositivos con FCM token
- [x] Recibe datos del operador y envía push FCM al número destino
- [x] Historial de mensajes con filtros y paginación
- [x] Endpoint `/mensajes/nuevos` para polling del frontend
- [x] CRUD empresas con eager load de servidores registrados
- [x] Autenticación Sanctum para panel web

### Panel web
- [x] Login, dashboard, empresas, clientes, mensajes
- [x] Polling tiempo real (badge + notificación navegador)
- [x] ModalDetalle muestra campos del JSON formateados (no raw JSON)
- [x] Columna nombre_servidor en Clientes y Empresas
- [x] Servidores registrados como badges en página Empresas

---

## Lo que FALTA / Pendiente

- [ ] **Múltiples empresas destino**: operador solo puede enviar a UN número destino. Para selección dinámica habría que cambiar el flujo
- [ ] **Configuración desde el servidor**: los ajustes se configuran manualmente en la app
- [ ] **Push web (PWA)**: notificaciones del navegador requieren panel abierto (polling). Se podría implementar Web Push con service workers
- [ ] **Confirmación de recepción**: el sistema no sabe si el destino realmente vio la notificación
- [ ] **Modo offline**: sin internet los datos se pierden (no hay cola local)

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
# Acceder: http://localhost:5200
# Credenciales: admin@pushcliente.com / password (o el usuario creado)
```

### App Flutter
```bash
cd D:\Desarrollo_Flutter\clientes\app_clientes
flutter build apk --release
# APK en: build\app\outputs\flutter-apk\app-release.apk
# APK copiado a: D:\Desarrollo_Flutter\clientes\facturame.apk
```

### Instalar APK por ADB
```bash
# Ruta ADB en Windows:
# C:\Users\julio\AppData\Local\Android\Sdk\platform-tools\adb.exe

adb devices
adb -s <device_id> install -r build\app\outputs\flutter-apk\app-release.apk
```

---

## Variables de entorno importantes

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
- Credenciales backend: `backend/storage/app/firebase-credentials.json`
- App Android: `android/app/google-services.json`

---

## Notas técnicas importantes

1. **Docker en puerto 8000**: Docker Desktop intercepta `localhost:8000` (IPv6). Siempre usar `127.0.0.1:8000` desde el frontend.

2. **`ilike` en PostgreSQL**: el backend usa `ilike` para búsquedas case-insensitive. No usar `like`.

3. **Canal FCM en Android**: el canal `facturame_channel` debe crearse con `Importance.HIGH` en código (no solo en AndroidManifest) para que aparezca el banner visual.

4. **Modelo AdminUser**: la autenticación del panel web usa `App\Models\AdminUser`, NO `App\Models\User`.

5. **Parseo JSON en notificación**: el `cuerpo` del mensaje es un JSON string. En la app se parsea con `jsonDecode(cuerpo)` y se extrae `json['data']` para los campos de la factura. `json['empresa']` y `json['servidor']` están al nivel raíz.

6. **celular_propio vs celularserver**:
   - `celular_propio` = número de ESTE teléfono (se registra como `numero_celular` en BD)
   - `celularserver` = número DESTINO al que se envían las notificaciones
   - Son campos distintos. El error histórico era usar `celularserver` para ambos.

7. **esFactura en frontend**: detecta si el mensaje es solicitud de factura con `!!(data.nombre || data.dui || data.registro_iva || data.giro || data.concepto)`.

8. **SIM auto-read race condition**: `requestPhonePermission` en Kotlin retorna inmediatamente (sin esperar que el usuario acepte el diálogo). Si es la primera vez, el permiso puede no estar concedido cuando se llama `getPhoneNumber`. En la segunda apertura de la app ya funciona porque el permiso fue otorgado.

9. **Badge en app móvil**: usa un timestamp `notif_vista_en` en SharedPreferences. Se actualiza al abrir el historial O al cerrar el diálogo de detalle de una notificación recibida por push.
