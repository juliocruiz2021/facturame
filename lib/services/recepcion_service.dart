import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_defaults.dart';
import '../helpers/device_uuid.dart';
import 'api_service.dart';

class RecepcionService {
  static Future<bool> confirmarMensaje(int? mensajeId) async {
    if (mensajeId == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final registroIva = (prefs.getString('num_registro') ?? '').trim();
    final numeroCelular = (prefs.getString('celular_propio') ?? '').trim();
    final backendUrl = (prefs.getString('backend_url') ?? '').trim();

    if (registroIva.isEmpty || numeroCelular.isEmpty) {
      return false;
    }

    final api = ApiService(
      backendUrl.isNotEmpty ? backendUrl : AppDefaults.backendUrl,
    );

    final result = await api.confirmarRecepcion(
      mensajeId: mensajeId,
      registroIva: registroIva,
      numeroCelular: numeroCelular,
      deviceUuid: await DeviceUuid.getOrCreate(),
    );

    return result.success;
  }
}
