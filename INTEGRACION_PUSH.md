# Integración Push — Facturame v1.1

## Descripción

La versión 1.1 reemplaza el envío por WhatsApp con envío HTTP al backend `push_cliente`. La app registra su dispositivo en el backend para recibir notificaciones push vía FCM y envía los datos del cliente directamente a la API.

## Cambios respecto a v1.0

| Aspecto | v1.0 | v1.1 |
|---|---|---|
| Envío de datos | WhatsApp (`wa.me`) | HTTP POST al backend |
| Confirmación | Retorno desde WhatsApp | SnackBar inmediato |
| Push | No | Firebase Cloud Messaging |
| Dependencias | `url_launcher` | `firebase_core`, `firebase_messaging`, `http`, `uuid` |

## Configuración requerida

### 1. Firebase Console

1. Crear proyecto en https://console.firebase.google.com
2. Agregar app Android con package `com.empresa.app_clientes`
3. Descargar `google-services.json`
4. Colocar en: `android/app/google-services.json`

### 2. URL del backend

En la app, abrir Configuración (engranaje) y configurar:

| Campo | Descripción | Ejemplo |
|---|---|---|
| URL del backend | Dirección del servidor Laravel | `http://192.168.1.100:8000` |
| Número de registro | Registro IVA de la empresa | `12345-6` |
| Número destino | Número del operador registrado | `63092051` |
| Nombre usuario | Identificador del registrador | `VENDEDOR 1` |

> **Para emulador Android:** usar `http://10.0.2.2:8000`
> **Para dispositivo físico en red local:** usar la IP de tu PC

### 3. Iniciar el backend

```bash
cd D:\Desarrollo_Flutter\push_cliente\backend
C:\xampp\php\php.exe artisan serve --host=0.0.0.0 --port=8000
```

## Flujo de la app

```
Inicio de app
  └─► Firebase.initializeApp()
  └─► FcmService.initialize()
  └─► ApiService.registrarDispositivo(...)
        registro_iva + numero_celular + nombre_usuario + device_uuid + fcm_token

Usuario llena formulario → Confirmar
  └─► ApiService.enviarDatos(...)
        registro_iva + numero_destino + titulo + cuerpo (JSON)
  └─► SnackBar verde (éxito) / rojo (error)
  └─► Dialogo: ¿Nuevo cliente?
```

## Endpoints del backend usados

| Endpoint | Auth | Descripción |
|---|---|---|
| `POST /api/v1/clientes/registrar-dispositivo` | Público | Registra el dispositivo FCM |
| `POST /api/v1/clientes/enviar-datos` | Público | Envía datos del cliente al backend |

## Archivos nuevos en la app

```
lib/
  helpers/
    device_helper.dart       — UUID único del dispositivo
  services/
    api_service.dart         — Llamadas HTTP al backend
    fcm_service.dart         — Inicialización y manejo FCM
android/app/
  google-services.json       — PENDIENTE: descargar de Firebase Console
```

## Seguridad

- No se hardcodean URLs ni tokens en el código
- La URL del backend se configura vía SharedPreferences
- Los errores HTTP se muestran al usuario sin exponer stack traces
- El FCM token se regenera automáticamente si expira
- El `device_uuid` persiste entre sesiones (generado una sola vez)
