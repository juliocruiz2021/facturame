import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Handler de mensajes en background — debe ser función top-level.
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background: ${message.messageId}');
}

class FcmService {
  static final _messaging = FirebaseMessaging.instance;

  /// Inicializa FCM: permisos, handlers.
  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Mensaje en foreground: solo log (en producción usar flutter_local_notifications)
    FirebaseMessaging.onMessage.listen((msg) {
      debugPrint('FCM foreground: ${msg.notification?.title} — ${msg.notification?.body}');
    });
  }

  /// Devuelve el token FCM actual, o null si no está disponible.
  static Future<String?> getToken() => _messaging.getToken();

  /// Escucha refreshes del token.
  static void onTokenRefresh(void Function(String) callback) {
    _messaging.onTokenRefresh.listen(callback);
  }
}
