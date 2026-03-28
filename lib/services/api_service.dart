import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiResult {
  final bool success;
  final String message;

  const ApiResult({required this.success, required this.message});
}

class SyncContactosResult {
  final bool success;
  final String message;
  final List<Map<String, dynamic>> contactos;

  const SyncContactosResult({
    required this.success,
    required this.message,
    required this.contactos,
  });
}

class ApiService {
  final String baseUrl;
  static const _timeout = Duration(seconds: 15);

  ApiService(this.baseUrl);

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<ApiResult> registrarDispositivo({
    required String registroIva,
    required String numeroCelular,
    required String nombreUsuario,
    required String nombreServidor,
    required String deviceUuid,
    required String fcmToken,
    String version = '1.1.0',
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/v1/clientes/registrar-dispositivo'),
            headers: _headers,
            body: jsonEncode({
              'registro_iva': registroIva,
              'numero_celular': numeroCelular,
              'nombre_usuario': nombreUsuario,
              'nombre_servidor': nombreServidor,
              'device_uuid': deviceUuid,
              'fcm_token': fcmToken,
              'plataforma': 'android',
              'version_app': version,
            }),
          )
          .timeout(_timeout);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return ApiResult(
        success: res.statusCode == 201,
        message: body['message']?.toString() ?? '',
      );
    } catch (e) {
      return ApiResult(success: false, message: 'Error de conexión: $e');
    }
  }

  Future<ApiResult> enviarDatos({
    required String registroIva,
    required String numeroDestino,
    required String titulo,
    required String cuerpo,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/v1/clientes/enviar-datos'),
            headers: _headers,
            body: jsonEncode({
              'registro_iva': registroIva,
              'numero_destino': numeroDestino,
              'titulo': titulo,
              'cuerpo': cuerpo,
            }),
          )
          .timeout(_timeout);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return ApiResult(
        success: res.statusCode == 200 || res.statusCode == 201,
        message: body['message']?.toString() ?? '',
      );
    } catch (e) {
      return ApiResult(success: false, message: 'Error de conexión: $e');
    }
  }

  Future<ApiResult> confirmarRecepcion({
    required int mensajeId,
    required String registroIva,
    required String numeroCelular,
    String? deviceUuid,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/v1/clientes/confirmar-recepcion'),
            headers: _headers,
            body: jsonEncode({
              'mensaje_id': mensajeId,
              'registro_iva': registroIva,
              'numero_celular': numeroCelular,
              'device_uuid': deviceUuid,
            }),
          )
          .timeout(_timeout);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return ApiResult(
        success: res.statusCode == 200,
        message: body['message']?.toString() ?? '',
      );
    } catch (e) {
      return ApiResult(success: false, message: 'Error de conexiÃ³n: $e');
    }
  }

  Future<SyncContactosResult> syncContactosCompartidos({
    required String registroIva,
    required List<Map<String, dynamic>> contactos,
    String? numeroCelular,
    String? nombreUsuario,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/v1/clientes-compartidos/sync'),
            headers: _headers,
            body: jsonEncode({
              'registro_iva': registroIva,
              'numero_celular': numeroCelular,
              'nombre_usuario': nombreUsuario,
              'contactos': contactos,
            }),
          )
          .timeout(_timeout);

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final rawContactos = (body['contactos'] as List<dynamic>? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      return SyncContactosResult(
        success: res.statusCode == 200,
        message: body['message']?.toString() ?? '',
        contactos: rawContactos,
      );
    } catch (e) {
      return SyncContactosResult(
        success: false,
        message: 'Error de conexiÃ³n: $e',
        contactos: const [],
      );
    }
  }
}
