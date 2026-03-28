import 'dart:convert';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const _channelId = 'facturame_channel';
const _channelName = 'Facturame Notificaciones';

final FlutterLocalNotificationsPlugin _localNotif =
    FlutterLocalNotificationsPlugin();

/// Handler de mensajes en background/terminado — debe ser función top-level.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background: ${message.messageId}');
}

/// Callback top-level requerido por flutter_local_notifications.
@pragma('vm:entry-point')
void _onLocalNotifResponse(NotificationResponse response) {
  final payload = response.payload ?? '';
  FirebaseService._localTapCtrl.add(payload);
}

/// Servicio centralizado de Firebase Cloud Messaging.
class FirebaseService {
  FirebaseService._();

  static final _messaging = FirebaseMessaging.instance;

  static final _foregroundCtrl = StreamController<RemoteMessage>.broadcast();
  static final _tapCtrl = StreamController<RemoteMessage>.broadcast();

  // Stream para taps en notificaciones locales (foreground).
  // El payload es el cuerpo del mensaje (JSON string).
  static final _localTapCtrl = StreamController<String>.broadcast();

  static Stream<RemoteMessage> get onForegroundMessage =>
      _foregroundCtrl.stream;
  static Stream<RemoteMessage> get onNotificationTap => _tapCtrl.stream;
  static Stream<String> get onLocalNotificationTap => _localTapCtrl.stream;

  static Future<void> initialize() async {
    // ── Crear canal Android con importancia ALTA ───────────────────────────
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotif
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);

    // Inicializar plugin con callback de tap.
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotifResponse,
    );

    // Handler de mensajes cuando la app está en background/terminada.
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // Solicitar permiso en Android 13+ (API 33+).
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    // Mensajes en foreground → mostrar notificación local con payload.
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('[FCM] Foreground: ${message.notification?.title}');
      _mostrarNotificacionLocal(message);
      _foregroundCtrl.add(message);
    });

    // App en background → usuario tocó la notificación.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint(
        '[FCM] Opened from background: ${message.notification?.title}',
      );
      _tapCtrl.add(message);
    });

    // App terminada → usuario tocó la notificación.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      Future.delayed(
        const Duration(milliseconds: 1500),
        () => _tapCtrl.add(initial),
      );
    }
  }

  static void _mostrarNotificacionLocal(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;

    final payload = jsonEncode({
      'titulo': n.title ?? 'NotificaciÃ³n',
      'cuerpo': n.body ?? '',
      'mensaje_id': message.data['mensaje_id'],
    });

    _localNotif.show(
      message.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
      ),
      payload: payload,
    );
  }

  static Future<String?> getToken() => _messaging.getToken();

  static void onTokenRefresh(void Function(String newToken) callback) {
    _messaging.onTokenRefresh.listen(callback);
  }
}
