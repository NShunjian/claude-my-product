import 'api_client.dart';
import 'models.dart';

class VersionApi {
  VersionApi(this._c);
  final ApiClient _c;

  Future<SystemVersion> getSystemVersion() async {
    final env = await _c.get<Map<String, dynamic>>('/api/version');
    return SystemVersion.fromJson(env);
  }
}
