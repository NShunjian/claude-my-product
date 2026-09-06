import 'api_client.dart';
import 'models.dart';

class RecordsQuery {
  RecordsQuery({
    this.month,
    this.from,
    this.to,
    this.type,
    this.categoryId,
    this.accountId,
    this.bookId,
  });
  final String? month; // YYYY-MM
  final String? from;
  final String? to;
  final RecordType? type;
  final String? categoryId;
  final String? accountId;
  final String? bookId;

  Map<String, String> toQuery() => {
        if (month != null) 'month': month!,
        if (from != null) 'from': from!,
        if (to != null) 'to': to!,
        if (type != null) 'type': type!.name,
        if (categoryId != null) 'categoryId': categoryId!,
        if (accountId != null) 'accountId': accountId!,
        if (bookId != null) 'bookId': bookId!,
      };
}

class RecordsApi {
  RecordsApi(this._c);
  final ApiClient _c;

  Future<List<Record>> listRecords({RecordsQuery? q}) async {
    final env = await _c.get<Map<String, dynamic>>(
      '/api/records',
      query: q?.toQuery(),
    );
    final items = (env['items'] as List? ?? []).cast<Map<String, dynamic>>();
    return items.map(Record.fromJson).toList();
  }

  Future<Record> createRecord(CreateRecordInput input) async {
    final env = await _c.post<Map<String, dynamic>>(
      '/api/records',
      data: input.toJson(),
    );
    return Record.fromJson(env['record'] as Map<String, dynamic>);
  }

  Future<Record> updateRecord(String id, UpdateRecordInput input) async {
    final env = await _c.patch<Map<String, dynamic>>(
      '/api/records/$id',
      data: input.toJson(),
    );
    return Record.fromJson(env['record'] as Map<String, dynamic>);
  }

  Future<void> deleteRecord(String id) => _c.delete('/api/records/$id');
}
