import 'api_client.dart';
import 'models.dart';

class ReportsApi {
  ReportsApi(this._c);
  final ApiClient _c;

  Future<MonthlyReport> getMonthly({
    required String month,
    String? bookId,
  }) async {
    final env = await _c.get<Map<String, dynamic>>(
      '/api/reports/monthly',
      query: {
        'month': month,
        if (bookId != null) 'bookId': bookId,
      },
    );
    return MonthlyReport.fromJson(env);
  }

  Future<YearlyReport> getYearly({
    required int year,
    String? bookId,
  }) async {
    final env = await _c.get<Map<String, dynamic>>(
      '/api/reports/yearly',
      query: {
        'year': year.toString(),
        if (bookId != null) 'bookId': bookId,
      },
    );
    return YearlyReport.fromJson(env);
  }
}
