import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Handler de mensajes en background/terminado — debe ser función top-level.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Firebase ya está inicializado en este punto.
  debugPrint('[FCM] Background: ${message.messageId}');
}

/// Servicio centralizado de Firebase Cloud Messaging.
///
/// Expone dos streams:
/// - [onForegroundMessage]: notificaciones recibidas con la app abierta.
/// - [onNotificationTap]: notificaciones que el usuario tocó (background/terminado).
class FirebaseService {
  FirebaseService._();

  static final _messaging = FirebaseMessaging.instance;

  // ── Streams ──────────────────────────────────────────────────────────────────
  static final _foregroundCtrl =
      StreamController<RemoteMessage>.broadcast();
  static final _tapCtrl =
      StreamController<RemoteMessage>.broadcast();

  /// Stream de notificaciones recibidas con la app en foreground.
  static Stream<RemoteMessage> get onForegroundMessage =>
      _foregroundCtrl.stream;

  /// Stream de notificaciones que el usuario tocó desde background o estado
  /// terminado. Preparado para navegación futura.
  static Stream<RemoteMessage> get onNotificationTap => _tapCtrl.stream;

  // ── Inicialización ────────────────────────────────────────────────────────────

  /// Inicializa FCM: permisos, handlers de background, foreground y tap.
  static Future<void> initialize() async {
    // Handler de mensajes cuando la app está en background/terminada.
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // Solicitar permiso en Android 13+ (API 33+).
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    // Mensajes recibidos con la app en foreground.
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint(
          '[FCM] Foreground: ${message.notification?.title} — ${message.notification?.body}');
      _foregroundCtrl.add(message);
    });

    // App estaba en background y el usuario tocó la notificación.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('[FCM] Opened from background: ${message.notification?.title}');
      _tapCtrl.add(message);
    });

    // App estaba terminada y el usuario tocó la notificación para abrirla.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      debugPrint(
          '[FCM] Opened from terminated: ${initial.notification?.title}');
      // Delay para asegurar que la UI esté lista antes de emitir.
      Future.delayed(const Duration(milliseconds: 1500),
          () => _tapCtrl.add(initial));
    }
  }

  // ── Token ────────────────────────────────────────────────────────────────────

  /// Devuelve el token FCM actual del dispositivo, o null si no está disponible.
  static Future<String?> getToken() => _messaging.getToken();

  /// Registra un callback que se invoca cada vez que el token FCM cambia.
  /// Esto ocurre cuando Firebase rota el token por seguridad.
  static void onTokenRefresh(void Function(String newToken) callback) {
    _messaging.onTokenRefresh.listen(callback);
  }
}
