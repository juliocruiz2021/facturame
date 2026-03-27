import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceHelper {
  static const _keyDeviceUuid = 'device_uuid';

  static Future<String> getOrCreateUuid() async {
    final prefs = await SharedPreferences.getInstance();
    var uuid = prefs.getString(_keyDeviceUuid);
    if (uuid == null || uuid.isEmpty) {
      uuid = const Uuid().v4();
      await prefs.setString(_keyDeviceUuid, uuid);
    }
    return uuid;
  }
}
