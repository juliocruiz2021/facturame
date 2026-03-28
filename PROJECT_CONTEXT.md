# Project Context - Facturame

## Update 2026-03-28

- Produccion final:
  - Panel: `https://facturame.appsigasv.com`
  - Backend para la app: `https://facturame.appsigasv.com`
- La app registra cada telefono usando `celular_propio`, pero el backend ya enruta la notificacion por coincidencia global de `numero_celular`.
- Si el mismo numero existe en varias empresas, el mismo telefono puede recibir mensajes de cualquiera de ellas.
- La empresa y el servidor mostrados al usuario deben salir del JSON del mensaje recibido.
- El APK release puede compilarse con defaults de produccion por `dart-define`, pero `mi_celular` conviene dejarlo vacio porque depende de cada equipo.

## Descripcion

`Facturame` es una app Android Flutter para registrar datos de clientes, enviarlos al backend `push_cliente` y recibir notificaciones push.

## Despliegue actual

- Panel web: `https://facturame.appsigasv.com`
- Backend recomendado para la app: `https://facturame.appsigasv.com`
- La web usa mismo origen y proxya `/api` hacia Laravel en el VPS.
- El APK release final ya no necesita `usesCleartextTraffic` porque la conexion va sobre HTTPS.

## Stack

- Flutter 3.41.5 / Dart 3.11.3
- Firebase Cloud Messaging
- `http`
- `shared_preferences`
- `uuid`

## Configuracion guardada en SharedPreferences

- `backend_url`
- `nombre_empresa`
- `nombre_servidor`
- `num_registro`
- `celularserver`
- `celular_propio`
- `nombre_usuario`
- `device_uuid`

## Regla critica

- `celular_propio`
  - numero de ESTE telefono
  - se usa para registrar el dispositivo y asociar el token FCM
- `celularserver`
  - numero destino al que se enviaran las notificaciones

Nunca usar `celularserver` como fallback de `celular_propio`.

## Flujo actual

1. La app inicia y registra el dispositivo con `registro_iva`, `celular_propio`, `nombre_usuario`, `nombre_servidor`, `device_uuid` y `fcm_token`.
2. El operador envia datos usando `numero_destino = celularserver`.
3. El backend busca todos los dispositivos activos con ese `numero_celular`, aunque pertenezcan a otras empresas.
4. FCM envia a todos los tokens unicos encontrados.
5. La app receptora muestra el detalle usando `empresa` y `servidor` del JSON recibido.
6. Al abrir el detalle, la app confirma recepcion al backend.

## Endpoints usados por la app

- `POST /api/v1/clientes/registrar-dispositivo`
- `POST /api/v1/clientes/enviar-datos`
- `POST /api/v1/clientes/confirmar-recepcion`
- `POST /api/v1/clientes-compartidos/sync`
- `GET /api/v1/clientes-compartidos`

## Archivos clave

- `lib/main.dart`
- `lib/services/api_service.dart`
- `lib/services/firebase_service.dart`
- `lib/services/recepcion_service.dart`
- `lib/screens/notificaciones_screen.dart`
- `lib/widgets/notif_detalle_dialog.dart`
- `lib/helpers/device_uuid.dart`
- `lib/config/app_defaults.dart`

## APK release

El script de release vive en:

- `scripts/build_release.ps1`

Valores de produccion recomendados:

- `APP_DEFAULT_BACKEND_URL=https://facturame.appsigasv.com`
- `APP_DEFAULT_NOMBRE_EMPRESA=EMPRESA DE PRUEBA`
- `APP_DEFAULT_NUM_REGISTRO=12345-6`
- `APP_DEFAULT_NOMBRE_SERVIDOR=SIGA1`
- `APP_DEFAULT_CELULAR_DESTINO=63092051`
- `APP_DEFAULT_NOMBRE_USUARIO=OPERADOR`
- `APP_DEFAULT_MI_CELULAR=` vacio
