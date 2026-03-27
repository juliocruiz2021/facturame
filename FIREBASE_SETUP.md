# Firebase Cloud Messaging — Guía de Configuración

## Información del proyecto

| Campo | Valor |
|---|---|
| Package Android | `com.empresa.app_clientes` |
| App name | Facturame |
| Plataforma | Android (minSdk 21) |

---

## Paso 1 — Crear proyecto en Firebase Console

1. Ir a https://console.firebase.google.com
2. Clic en **"Agregar proyecto"**
3. Nombre sugerido: `facturame-prod` (o el que prefieras)
4. Desactivar Google Analytics si no es necesario
5. Clic en **"Crear proyecto"**

---

## Paso 2 — Registrar la app Android

1. En el panel del proyecto, clic en el ícono Android **( )**
2. Completar el formulario:

   | Campo | Valor |
   |---|---|
   | Nombre del paquete Android | `com.empresa.app_clientes` |
   | Alias de la app (opcional) | `Facturame` |
   | Certificado SHA-1 (opcional) | No necesario para FCM básico |

3. Clic en **"Registrar app"**

---

## Paso 3 — Descargar google-services.json

1. En el paso siguiente de Firebase Console, descargar el archivo `google-services.json`
2. **Colocar el archivo en:**

   ```
   D:\Desarrollo_Flutter\clientes\app_clientes\android\app\google-services.json
   ```

   > ⚠️ Sin este archivo la app **no compilará**.

3. Verificar que el package name dentro del JSON sea `com.empresa.app_clientes`:
   ```json
   {
     "client": [{
       "client_info": {
         "android_client_info": {
           "package_name": "com.empresa.app_clientes"
         }
       }
     }]
   }
   ```

---

## Paso 4 — Habilitar Cloud Messaging

1. En Firebase Console → tu proyecto → **Cloud Messaging**
2. Verificar que FCM esté habilitado (normalmente lo está por defecto)

---

## Paso 5 — Compilar y probar

```bash
cd D:\Desarrollo_Flutter\clientes\app_clientes
flutter pub get
flutter build apk --release
```

O instalar directamente:
```bash
flutter run
```

---

## Verificación del token FCM

Al iniciar la app, en los logs de debug verás:
```
[FCM] Permission: authorized
```

Si el registro IVA está configurado en la app, también verás la llamada al backend en los logs del servidor Laravel.

---

## Archivos modificados para Firebase

| Archivo | Cambio |
|---|---|
| `android/settings.gradle.kts` | Plugin `com.google.gms.google-services v4.4.2` |
| `android/app/build.gradle.kts` | Aplicado plugin `com.google.gms.google-services` |
| `android/app/src/main/AndroidManifest.xml` | `POST_NOTIFICATIONS` + canal FCM `facturame_channel` |
| `pubspec.yaml` | `firebase_core ^3.8.0`, `firebase_messaging ^15.1.6` |
| `lib/main.dart` | `Firebase.initializeApp()` en `main()` |
| `lib/services/firebase_service.dart` | Servicio FCM completo |

---

## Estructura del servicio FCM

```
FirebaseService
├── initialize()           — Permisos + handlers foreground/background/tap
├── getToken()             — Token FCM del dispositivo
├── onTokenRefresh()       — Listener para refrescos de token
├── onForegroundMessage    — Stream de mensajes en foreground (SnackBar)
└── onNotificationTap      — Stream de taps en notificaciones (navegación futura)
```

---

## Flujo del token

```
App inicia
  └─► Firebase.initializeApp()
  └─► FirebaseService.initialize()
        └─► Solicitar permiso POST_NOTIFICATIONS (Android 13+)
  └─► FirebaseService.getToken()
        └─► token válido?
              ├─► Sí → ApiService.registrarDispositivo(token, uuid, ...)
              └─► No → Esperar refresh automático
  └─► onTokenRefresh → re-registrar automáticamente
```

---

## Seguridad

- El `google-services.json` contiene claves públicas de Firebase. Es seguro incluirlo en el repo.
- El token FCM **no se loguea** en producción (`kReleaseMode` silencia `debugPrint`).
- El `device_uuid` se genera localmente (UUID v4), no usa IMEI ni MAC.
- La URL del backend se configura en la app, no está hardcodeada.
