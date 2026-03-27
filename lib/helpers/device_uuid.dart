import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Genera y persiste un UUID v4 único por instalación de la app.
///
/// El UUID se crea la primera vez que se llama a [getOrCreate] y se reutiliza
/// en todas las ejecuciones posteriores. No usa IMEI, MAC ni ningún
/// identificador sensible del dispositivo.
class DeviceUuid {
  DeviceUuid._();

  static const _key = 'device_uuid';

  /// Devuelve el UUID del dispositivo.
  /// Si no existe, genera uno nuevo y lo persiste.
  static Future<String> getOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_key);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_key, id);
    }
    return id;
  }
}
