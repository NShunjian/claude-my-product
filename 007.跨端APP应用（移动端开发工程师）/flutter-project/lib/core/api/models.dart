// ===== User / Auth =====
enum Gender { male, female, other }

// V1.2 金额核算审计:服务端 Jackson WRITE_BIGDECIMAL_AS_PLAIN 把 BigDecimal
// 序列化成 plain 字符串(不是 JSON number),旧的 `as num?` 在收到 "12.34"
// 时会抛 `type String is not subtype of num?` 崩溃。这个 helper 同时吃
// `num` / `String` / null,任意一边失效回退到 [fallback]。
double _numToDouble(dynamic v, {double fallback = 0}) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  if (v is String) {
    final d = double.tryParse(v);
    if (d != null && d.isFinite) return d;
  }
  return fallback;
}

Gender? genderFromString(String? s) {
  if (s == null) return null;
  for (final g in Gender.values) {
    if (g.name == s) return g;
  }
  return null;
}

class User {
  User({
    required this.id,
    required this.uuid,
    required this.username,
    this.displayName,
    this.avatar,
    this.gender,
    this.age,
    required this.createdAt,
  });

  final int id;
  final String uuid;
  final String username;
  final String? displayName;
  final String? avatar;
  final Gender? gender;
  final int? age;
  final String createdAt;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        uuid: json['uuid'] as String,
        username: json['username'] as String,
        displayName: json['displayName'] as String?,
        avatar: json['avatar'] as String?,
        gender: genderFromString(json['gender'] as String?),
        age: json['age'] as int?,
        createdAt: json['createdAt'] as String,
      );
}

class Credentials {
  Credentials({required this.username, required this.password});
  final String username;
  final String password;
  Map<String, dynamic> toJson() => {'username': username, 'password': password};
}

class AuthResponse {
  AuthResponse({required this.user, required this.token});
  final User user;
  final String token;

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        user: User.fromJson(json['user'] as Map<String, dynamic>),
        token: json['token'] as String,
      );
}

class UpdateProfileInput {
  UpdateProfileInput({this.displayName, this.avatar, this.gender, this.age});
  final String? displayName;
  final String? avatar;
  final Gender? gender;
  final int? age;

  Map<String, dynamic> toJson() => {
        if (displayName != null) 'displayName': displayName,
        if (avatar != null) 'avatar': avatar,
        if (gender != null) 'gender': gender!.name,
        if (age != null) 'age': age,
      };
}

// ===== Books =====
enum BookType { personal, shared, business }
enum BookRole { owner, admin, editor, viewer }

BookType bookTypeFromString(String s) =>
    BookType.values.firstWhere((e) => e.name == s, orElse: () => BookType.personal);
BookRole bookRoleFromString(String s) =>
    BookRole.values.firstWhere((e) => e.name == s, orElse: () => BookRole.viewer);

class Book {
  Book({
    required this.uuid,
    required this.name,
    this.description,
    required this.type,
    required this.currency,
    required this.isDefault,
    required this.isArchived,
    required this.role,
    required this.ownerUuid,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uuid;
  final String name;
  final String? description;
  final BookType type;
  final String currency;
  final bool isDefault;
  final bool isArchived;
  final BookRole role;
  final String ownerUuid;
  final String createdAt;
  final String updatedAt;

  factory Book.fromJson(Map<String, dynamic> json) => Book(
        uuid: json['uuid'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        type: bookTypeFromString(json['type'] as String),
        currency: json['currency'] as String? ?? 'CNY',
        isDefault: json['isDefault'] as bool? ?? false,
        isArchived: json['isArchived'] as bool? ?? false,
        role: bookRoleFromString(json['role'] as String? ?? 'viewer'),
        ownerUuid: json['ownerUuid'] as String? ?? '',
        createdAt: json['createdAt'] as String,
        updatedAt: json['updatedAt'] as String,
      );
}

class BookMember {
  BookMember({
    required this.userUuid,
    required this.username,
    this.displayName,
    this.avatar,
    required this.role,
    required this.joinedAt,
    this.invitedByUuid,
  });

  final String userUuid;
  final String username;
  final String? displayName;
  final String? avatar;
  final BookRole role;
  final String joinedAt;
  final String? invitedByUuid;

  factory BookMember.fromJson(Map<String, dynamic> json) => BookMember(
        userUuid: json['userUuid'] as String,
        username: json['username'] as String,
        displayName: json['displayName'] as String?,
        avatar: json['avatar'] as String?,
        role: bookRoleFromString(json['role'] as String? ?? 'viewer'),
        joinedAt: json['joinedAt'] as String,
        invitedByUuid: json['invitedByUuid'] as String?,
      );
}

class CreateBookInput {
  CreateBookInput({required this.name, this.description, this.type, this.currency});
  final String name;
  final String? description;
  final BookType? type;
  final String? currency;
  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null) 'description': description,
        if (type != null) 'type': type!.name,
        if (currency != null) 'currency': currency,
      };
}

class UpdateBookInput {
  UpdateBookInput({this.name, this.description, this.type, this.isArchived});
  final String? name;
  final String? description;
  final BookType? type;
  final bool? isArchived;
  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (type != null) 'type': type!.name,
        if (isArchived != null) 'isArchived': isArchived,
      };
}

class AddMemberInput {
  AddMemberInput({required this.username, required this.role});
  final String username;
  final BookRole role;
  Map<String, dynamic> toJson() => {'username': username, 'role': role.name};
}

class UpdateMemberRoleInput {
  UpdateMemberRoleInput(this.role);
  final BookRole role;
  Map<String, dynamic> toJson() => {'role': role.name};
}

// ===== Accounts =====
enum AccountType { cash, debit, credit, wallet, investment, other }

AccountType accountTypeFromString(String s) =>
    AccountType.values.firstWhere((e) => e.name == s, orElse: () => AccountType.other);

class Account {
  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.initialBalance,
    required this.balance,
    required this.currency,
    required this.isDefault,
    required this.isArchived,
    required this.sortOrder,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String name;
  final AccountType type;
  final String icon;
  final double initialBalance;
  final double balance;
  final String currency;
  final bool isDefault;
  /// 已归档账户：true 表示隐藏,records 仍生效、报表仍计入
  final bool isArchived;
  final int sortOrder;
  final String? note;
  final String createdAt;

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'].toString(),
        name: json['name'] as String,
        type: accountTypeFromString(json['type'] as String? ?? 'other'),
        icon: json['icon'] as String? ?? '',
        initialBalance: _numToDouble(json['initialBalance']),
        balance: _numToDouble(json['balance']),
        currency: json['currency'] as String? ?? 'CNY',
        isDefault: json['isDefault'] as bool? ?? false,
        isArchived: json['isArchived'] as bool? ?? false,
        sortOrder: json['sortOrder'] as int? ?? 0,
        note: json['note'] as String?,
        createdAt: json['createdAt'] as String,
      );
}

class CreateAccountInput {
  CreateAccountInput({
    required this.name,
    required this.type,
    required this.icon,
    required this.initialBalance,
    required this.currency,
    required this.isDefault,
    this.note,
  });
  final String name;
  final AccountType type;
  final String icon;
  final double initialBalance;
  final String currency;
  final bool isDefault;
  final String? note;
  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type.name,
        'icon': icon,
        'initialBalance': initialBalance,
        'currency': currency,
        'isDefault': isDefault,
        if (note != null) 'note': note,
      };
}

// ===== Categories =====
enum CategoryType { expense, income }

class Category {
  Category({
    required this.id,
    required this.type,
    required this.name,
    required this.icon,
    required this.color,
    required this.sortOrder,
    required this.isPreset,
    this.createdAt,
  });

  final String id;
  final CategoryType type;
  final String name;
  final String icon;
  final String color;
  final int sortOrder;
  final bool isPreset;
  final String? createdAt;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'].toString(),
        type: json['type'] == 'income' ? CategoryType.income : CategoryType.expense,
        name: json['name'] as String,
        icon: json['icon'] as String? ?? '',
        color: json['color'] as String? ?? '#727782',
        sortOrder: json['sortOrder'] as int? ?? 0,
        isPreset: json['isPreset'] as bool? ?? false,
        // 后端 Long(Unix 秒);预设分类可能没有 → null。统一 toString 兼容 ISO 字符串。
        createdAt: json['createdAt']?.toString(),
      );
}

class CreateCategoryInput {
  CreateCategoryInput({
    required this.type,
    required this.name,
    required this.icon,
    required this.color,
  });
  final CategoryType type;
  final String name;
  final String icon;
  final String color;
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'name': name,
        'icon': icon,
        'color': color,
      };
}

class UpdateCategoryInput {
  UpdateCategoryInput({this.name, this.icon, this.color, this.sortOrder});
  final String? name;
  final String? icon;
  final String? color;
  final int? sortOrder;
  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
        if (sortOrder != null) 'sortOrder': sortOrder,
      };
}

// ===== Records =====
enum RecordType { expense, income, transfer }
enum RecordSource { manual, import, ocr, auto, sync }

RecordType recordTypeFromString(String s) =>
    RecordType.values.firstWhere((e) => e.name == s, orElse: () => RecordType.expense);
RecordSource? recordSourceFromString(String? s) {
  if (s == null) return null;
  for (final r in RecordSource.values) {
    if (r.name == s) return r;
  }
  return null;
}

class Record {
  Record({
    required this.id,
    required this.type,
    this.categoryId,
    required this.accountId,
    this.toAccountId,
    required this.amount,
    required this.currency,
    this.note,
    required this.recordDate,
    this.source,
    this.clientId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final RecordType type;
  final String? categoryId;
  final String accountId;
  final String? toAccountId;
  final double amount;
  final String currency;
  final String? note;
  final String recordDate; // YYYY-MM-DD
  final RecordSource? source;
  final String? clientId;
  final String createdAt;
  final String updatedAt;

  factory Record.fromJson(Map<String, dynamic> json) => Record(
        id: json['id'].toString(),
        type: recordTypeFromString(json['type'] as String? ?? 'expense'),
        categoryId: json['categoryId']?.toString(),
        accountId: json['accountId'].toString(),
        toAccountId: json['toAccountId']?.toString(),
        amount: _numToDouble(json['amount']),
        currency: json['currency'] as String? ?? 'CNY',
        note: json['note'] as String?,
        recordDate: json['recordDate'] as String,
        source: recordSourceFromString(json['source'] as String?),
        clientId: json['clientId'] as String?,
        createdAt: json['createdAt'] as String,
        updatedAt: json['updatedAt'] as String,
      );
}

/// 创建记录的判别联合 — 与 uniapp 的 CreateInput 一致
sealed class CreateRecordInput {
  Map<String, dynamic> toJson();
}

class CreateExpenseInput extends CreateRecordInput {
  CreateExpenseInput({
    required this.amount,
    required this.accountId,
    required this.categoryId,
    required this.recordDate,
    this.note,
    this.currency = 'CNY',
    this.clientId,
  });
  final double amount;
  final String accountId;
  final String categoryId;
  final String recordDate;
  final String? note;
  final String currency;
  final String? clientId;
  @override
  Map<String, dynamic> toJson() => {
        'type': 'expense',
        'amount': amount,
        'accountId': accountId,
        'categoryId': categoryId,
        'recordDate': recordDate,
        if (note != null) 'note': note,
        'currency': currency,
        if (clientId != null) 'clientId': clientId,
      };
}

class CreateIncomeInput extends CreateRecordInput {
  CreateIncomeInput({
    required this.amount,
    required this.accountId,
    required this.categoryId,
    required this.recordDate,
    this.note,
    this.currency = 'CNY',
    this.clientId,
  });
  final double amount;
  final String accountId;
  final String categoryId;
  final String recordDate;
  final String? note;
  final String currency;
  final String? clientId;
  @override
  Map<String, dynamic> toJson() => {
        'type': 'income',
        'amount': amount,
        'accountId': accountId,
        'categoryId': categoryId,
        'recordDate': recordDate,
        if (note != null) 'note': note,
        'currency': currency,
        if (clientId != null) 'clientId': clientId,
      };
}

class CreateTransferInput extends CreateRecordInput {
  CreateTransferInput({
    required this.amount,
    required this.accountId,
    required this.toAccountId,
    required this.recordDate,
    this.note,
    this.currency = 'CNY',
    this.clientId,
  });
  final double amount;
  final String accountId;
  final String toAccountId;
  final String recordDate;
  final String? note;
  final String currency;
  final String? clientId;
  @override
  Map<String, dynamic> toJson() => {
        'type': 'transfer',
        'amount': amount,
        'accountId': accountId,
        'toAccountId': toAccountId,
        'recordDate': recordDate,
        if (note != null) 'note': note,
        'currency': currency,
        if (clientId != null) 'clientId': clientId,
      };
}

class UpdateRecordInput {
  UpdateRecordInput({
    this.amount,
    this.categoryId,
    this.accountId,
    this.toAccountId,
    this.note,
    this.recordDate,
  });
  final double? amount;
  final String? categoryId;
  final String? accountId;
  final String? toAccountId;
  final String? note;
  final String? recordDate;
  Map<String, dynamic> toJson() => {
        if (amount != null) 'amount': amount,
        if (categoryId != null) 'categoryId': categoryId,
        if (accountId != null) 'accountId': accountId,
        if (toAccountId != null) 'toAccountId': toAccountId,
        if (note != null) 'note': note,
        if (recordDate != null) 'recordDate': recordDate,
      };
}

// ===== Reports =====
class CategoryAggregate {
  CategoryAggregate({
    required this.categoryId,
    required this.amount,
    this.name,
    this.icon,
    this.color,
  });
  final String? categoryId;
  final double amount;
  // 后端 /monthly 与 /yearly 在每条分类聚合里直接带 name/icon/color,
  // 不需要再去 /categories 按 id 反查(categoryId 经常是 'income-兼职' 这种 slug,
  // 不是 UUID,根本对不上 categories 列表)。
  final String? name;
  final String? icon;
  final String? color;
  factory CategoryAggregate.fromJson(Map<String, dynamic> json) => CategoryAggregate(
        categoryId: json['categoryId']?.toString(),
        // 后端字段是 total,老 Flutter 代码读 amount(uniapp MonthlyPoint 也是 total);
        // 兼容老字段名。
        amount: _numToDouble(json['total'] ?? json['amount']),
        name: json['name'] as String?,
        icon: json['icon'] as String?,
        color: json['color'] as String?,
      );
}

class DailyDataPoint {
  DailyDataPoint({required this.date, required this.income, required this.expense});
  final String date;
  final double income;
  final double expense;
  factory DailyDataPoint.fromJson(Map<String, dynamic> json) => DailyDataPoint(
        // 后端字段是 `day`(当月第几天,int);旧字段名 `date` 保留兼容。优先 `date`,
        // 缺失时用 day.toString() 兜底,避免 'type Null is not subtype of String' 崩溃。
        date: (json['date'] as String?) ?? json['day']?.toString() ?? '',
        income: _numToDouble(json['income']),
        expense: _numToDouble(json['expense']),
      );
}

class MonthlyReport {
  MonthlyReport({
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
    required this.netSavings,
    required this.incomeByCategory,
    required this.expenseByCategory,
    required this.dailyData,
    this.lastMonth,
  });
  final String month;
  final double totalIncome;
  final double totalExpense;
  final double netSavings;
  final List<CategoryAggregate> incomeByCategory;
  final List<CategoryAggregate> expenseByCategory;
  final List<DailyDataPoint> dailyData;
  final MonthlyComparison? lastMonth;

  factory MonthlyReport.fromJson(Map<String, dynamic> json) => MonthlyReport(
        month: json['month'] as String,
        totalIncome: _numToDouble(json['totalIncome']),
        totalExpense: _numToDouble(json['totalExpense']),
        netSavings: _numToDouble(json['netSavings']),
        incomeByCategory: ((json['incomeByCategory'] as List?) ?? [])
            .map((e) => CategoryAggregate.fromJson(e as Map<String, dynamic>))
            .toList(),
        expenseByCategory: ((json['expenseByCategory'] as List?) ?? [])
            .map((e) => CategoryAggregate.fromJson(e as Map<String, dynamic>))
            .toList(),
        dailyData: ((json['dailyData'] as List?) ?? [])
            .map((e) => DailyDataPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        lastMonth: json['lastMonth'] is Map<String, dynamic>
            ? MonthlyComparison.fromJson(json['lastMonth'] as Map<String, dynamic>)
            : null,
      );
}

class MonthlyComparison {
  MonthlyComparison({
    required this.income,
    required this.expense,
    this.netSavings,
  });
  final double income;
  final double expense;
  // 后端直接给 netSavings,uniapp monthlyNetChangePct 用这个值,不要用
  // income-expense 推算(后端字段比 Flutter 自己算更准)。
  final double? netSavings;
  factory MonthlyComparison.fromJson(Map<String, dynamic> json) =>
      MonthlyComparison(
        // 后端字段是 totalIncome/totalExpense/netSavings,老代码读 income/expense;
        // 兼容老字段名。
        income: _numToDouble(json['totalIncome'] ?? json['income']),
        expense: _numToDouble(json['totalExpense'] ?? json['expense']),
        netSavings: json['netSavings'] == null
            ? null
            : _numToDouble(json['netSavings']),
      );
}

class MonthlyDataPoint {
  MonthlyDataPoint({
    required this.month,
    required this.income,
    required this.expense,
  });
  final int month;
  final double income;
  final double expense;
  factory MonthlyDataPoint.fromJson(Map<String, dynamic> json) => MonthlyDataPoint(
        month: json['month'] as int,
        income: _numToDouble(json['income']),
        expense: _numToDouble(json['expense']),
      );
}

class YearlyReport {
  YearlyReport({
    required this.year,
    required this.totalIncome,
    required this.totalExpense,
    required this.netSavings,
    required this.monthlyData,
    required this.incomeByCategory,
    required this.expenseByCategory,
  });
  final int year;
  final double totalIncome;
  final double totalExpense;
  final double netSavings;
  final List<MonthlyDataPoint> monthlyData;
  final List<CategoryAggregate> incomeByCategory;
  final List<CategoryAggregate> expenseByCategory;

  factory YearlyReport.fromJson(Map<String, dynamic> json) => YearlyReport(
        year: json['year'] as int,
        totalIncome: _numToDouble(json['totalIncome']),
        totalExpense: _numToDouble(json['totalExpense']),
        netSavings: _numToDouble(json['netSavings']),
        monthlyData: ((json['monthlyData'] as List?) ?? [])
            .map((e) => MonthlyDataPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        incomeByCategory: ((json['incomeByCategory'] as List?) ?? [])
            .map((e) => CategoryAggregate.fromJson(e as Map<String, dynamic>))
            .toList(),
        expenseByCategory: ((json['expenseByCategory'] as List?) ?? [])
            .map((e) => CategoryAggregate.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SystemVersion {
  SystemVersion({required this.version});
  final String version;
  factory SystemVersion.fromJson(Map<String, dynamic> json) =>
      SystemVersion(version: json['version'] as String);
}
