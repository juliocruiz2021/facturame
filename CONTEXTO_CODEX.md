# Contexto del Proyecto - Facturame

## Que es

`facturame` es la app Flutter Android que usan los operadores para enviar datos de clientes y recibir notificaciones push.

Trabaja con:
- Backend Laravel: `push_cliente`
- Panel web React: `push_cliente`

## Estado actual

- Rama activa: `feature/confirmacion-recepcion-limpieza`
- APK de distribucion: `D:\Desarrollo_Flutter\clientes\facturame.apk`
- Produccion:
  - panel: `https://facturame.appsigasv.com`
  - api: `https://facturame.appsigasv.com/api/v1`

## Regla funcional vigente

La app sigue registrando cada telefono por empresa usando `celular_propio`, pero el backend envia por numero global.

Eso significa:
- `celular_propio` identifica ESTE telefono y se registra en `clientes_empresa`.
- `celularserver` es el numero destino al que el operador quiere enviar.
- Si el mismo numero existe en varias empresas, ese telefono puede recibir notificaciones de cualquiera de ellas.
- La app debe mostrar el mensaje sin importar de que empresa venga, siempre que el numero del equipo coincida con el destinatario.

## Flujo real

1. Al iniciar, la app registra el dispositivo con:
   - `registro_iva`
   - `celular_propio`
   - `nombre_usuario`
   - `nombre_servidor`
   - `device_uuid`
   - `fcm_token`
2. El operador llena el formulario y envia:
   - `registro_iva`
   - `numero_destino` = `celularserver`
   - `titulo`
   - `cuerpo` JSON
3. El backend busca todos los dispositivos activos con `numero_celular = numero_destino`, aunque pertenezcan a otras empresas.
4. FCM envia a todos los tokens FCM unicos encontrados.
5. La app receptora muestra el detalle usando `empresa` y `servidor` que vienen dentro del JSON del mensaje.
6. Al abrir el detalle, la app confirma recepcion con `mensaje_id` y `numero_celular`.

## Configuracion guardada en SharedPreferences

- `backend_url`
- `nombre_empresa`
- `nombre_servidor`
- `num_registro`
- `celularserver`
- `celular_propio`
- `nombre_usuario`

## Diferencia critica

- `celular_propio`
  - numero de ESTE telefono
  - sirve para registrar el dispositivo y asociar el token FCM
- `celularserver`
  - numero destino al que se enviaran las notificaciones

Regla obligatoria:
- nunca usar `celularserver` como fallback de `celular_propio`
- si `celular_propio` esta vacio, no se debe registrar el dispositivo

## Archivos clave

- `lib/main.dart`
  - pantalla principal
  - formulario
  - registro de dispositivo
  - envio al backend
- `lib/services/api_service.dart`
  - llamadas HTTP
- `lib/services/firebase_service.dart`
  - FCM
  - local notifications
- `lib/screens/notificaciones_screen.dart`
  - historial local y badge
- `lib/widgets/notif_detalle_dialog.dart`
  - parseo del cuerpo JSON
  - UI del detalle de notificacion
- `lib/services/recepcion_service.dart`
  - confirmacion de recepcion al backend
- `lib/helpers/device_uuid.dart`
  - UUID estable del equipo

## Formato del cuerpo enviado

La app envia el `cuerpo` como JSON string. Debe incluir:

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
    "monto": 150.0
  }
}
```

La pantalla de detalle y el historial dependen de ese formato.

## Endpoints que usa la app

### Publicos

- `POST /api/v1/clientes/registrar-dispositivo`
  - registra por `(empresa_id, numero_celular)`
- `POST /api/v1/clientes/enviar-datos`
  - el backend resuelve el destino por `numero_destino` global
- `POST /api/v1/clientes/confirmar-recepcion`
  - confirma por `mensaje_id + numero_celular (+ device_uuid opcional)`

### Sync de clientes compartidos

- `POST /api/v1/clientes-compartidos/sync`
- `GET /api/v1/clientes-compartidos`

## Comportamiento ya cerrado

- registro de dispositivo con `celular_propio`
- envio HTTP al backend
- push FCM
- historial local
- badge de no vistas
- detalle de notificacion
- confirmacion de recepcion
- sincronizacion de clientes compartidos por empresa

## Notas de mantenimiento

- El mensaje debe mostrarse aunque provenga de otra empresa, porque el criterio de entrega ahora es el numero del telefono.
- Si un telefono esta registrado en varias empresas, puede recibir mensajes de todas ellas.
- La empresa y el servidor que se muestran al usuario deben salir del JSON recibido, no del contexto local de configuracion.
- Si se recompila APK final, debe apuntar a `https://facturame.appsigasv.com`.
