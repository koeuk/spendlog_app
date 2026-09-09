import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../models/budget.dart';
import '../models/budget_summary.dart';
import '../models/category.dart';
import '../models/dashboard.dart';
import '../models/expense.dart';
import '../models/expense_filters.dart';
import '../models/activity.dart';
import '../models/admin.dart';
import '../models/branding.dart';
import '../models/income.dart';
import '../models/recurring.dart';
import '../models/report.dart';
import '../models/savings.dart';
import '../models/user.dart';

/// Every data call the app makes, one thin method per endpoint. Shapes follow
/// docs/API.md in the backend repo; anything clever (currency conversion,
/// budget upserts) happens server-side, so these stay dumb on purpose.
class SpendLogRepository {
  SpendLogRepository(this._client);

  final ApiClient _client;

  // ------------------------------------------------------------ dashboard

  Future<Dashboard> dashboard({String? month}) async {
    final response = await _client.dio.get(
      '/dashboard',
      queryParameters: {'budget_month': ?month, 'breakdown_month': ?month},
    );

    return Dashboard.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  // ------------------------------------------------------------- expenses

  Future<({List<Expense> items, bool hasMore})> expenses({
    int page = 1,
    ExpenseFilters? filters,
  }) async {
    final response = await _client.dio.get(
      '/expenses',
      queryParameters: {
        'page': page,
        'filter[item]': ?filters?.search,
        'filter[category]': ?filters?.categoryUuid,
        'filter[from]': ?filters?.from,
        'filter[to]': ?filters?.to,
      },
    );

    final data = response.data as Map<String, dynamic>;
    final items = (data['data'] as List<dynamic>)
        .map((e) => Expense.fromJson(e as Map<String, dynamic>))
        .toList();

    return (
      items: items,
      hasMore: (data['links'] as Map<String, dynamic>?)?['next'] != null,
    );
  }

  Future<void> createExpense({
    required String item,
    required String price,
    required String spentOn,
    String? categoryUuid,
    String? newCategory,
    String currency = 'USD',
  }) async {
    await _client.dio.post(
      '/expenses',
      data: {
        'item': item,
        'price': price,
        'spent_on': spentOn,
        'category_uuid': ?categoryUuid,
        'new_category': ?newCategory,
        if (currency != 'USD') 'currency': currency,
      },
    );
  }

  Future<void> updateExpense(
    String uuid, {
    required String item,
    required String price,
    required String spentOn,
    String? categoryUuid,
    String currency = 'USD',
  }) async {
    await _client.dio.patch(
      '/expenses/$uuid',
      data: {
        'item': item,
        'price': price,
        'spent_on': spentOn,
        'category_uuid': ?categoryUuid,
        if (currency != 'USD') 'currency': currency,
      },
    );
  }

  Future<void> deleteExpense(String uuid) =>
      _client.dio.delete('/expenses/$uuid');

  // -------------------------------------------------------------- incomes

  /// The caller's sources, most used first — the picker's list. A new one
  /// is created by simply saving an income with it.
  Future<List<String>> incomeSources() async {
    final response = await _client.dio.get('/incomes/sources');

    return ((response.data as Map<String, dynamic>)['data'] as List<dynamic>).cast<String>();
  }

  Future<({List<Income> items, bool hasMore})> incomes({
    String? from,
    String? to,
    int page = 1,
    int perPage = 50,
  }) async {
    final response = await _client.dio.get(
      '/incomes',
      queryParameters: {
        'page': page,
        'per_page': perPage,
        'filter[from]': ?from,
        'filter[to]': ?to,
      },
    );

    final data = response.data as Map<String, dynamic>;
    final items = (data['data'] as List<dynamic>)
        .map((e) => Income.fromJson(e as Map<String, dynamic>))
        .toList();

    return (
      items: items,
      hasMore: (data['links'] as Map<String, dynamic>?)?['next'] != null,
    );
  }

  Future<IncomeSummary> incomeSummary(String month) async {
    final response = await _client.dio.get(
      '/incomes/summary',
      queryParameters: {'month': month},
    );

    return IncomeSummary.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<void> createIncome({
    required String source,
    required String amount,
    required String receivedOn,
    String? note,
    String currency = 'USD',
  }) async {
    await _client.dio.post(
      '/incomes',
      data: {
        'source': source,
        'amount': amount,
        'received_on': receivedOn,
        'note': note,
        if (currency != 'USD') 'currency': currency,
      },
    );
  }

  Future<void> updateIncome(
    String uuid, {
    required String source,
    required String amount,
    required String receivedOn,
    String? note,
    String currency = 'USD',
  }) async {
    await _client.dio.patch(
      '/incomes/$uuid',
      data: {
        'source': source,
        'amount': amount,
        'received_on': receivedOn,
        'note': note,
        if (currency != 'USD') 'currency': currency,
      },
    );
  }

  Future<void> deleteIncome(String uuid) =>
      _client.dio.delete('/incomes/$uuid');

  // ------------------------------------------------------------ recurring

  /// Every rule, active first then by next run; [kind] narrows to
  /// expense | income.
  Future<List<RecurringRule>> recurringRules({String? kind}) async {
    final response = await _client.dio.get(
      '/recurring',
      queryParameters: {'kind': ?kind},
    );

    return ((response.data as Map<String, dynamic>)['data'] as List<dynamic>)
        .map((e) => RecurringRule.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<RecurringRule> recurringRule(String uuid) async {
    final response = await _client.dio.get('/recurring/$uuid');

    return RecurringRule.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// [kind] is expense | income and cannot change afterwards. The category
  /// only travels with expense rules — the server forbids it on income. The
  /// server runs the rule at once, so a start date of today (or earlier, up
  /// to a year back) yields its rows before this returns.
  Future<RecurringRule> createRecurringRule({
    required String kind,
    required String title,
    required String amount,
    required String frequency,
    required String startsOn,
    String? categoryUuid,
    String? endsOn,
    String? note,
    bool active = true,
    String currency = 'USD',
  }) async {
    final response = await _client.dio.post(
      '/recurring',
      data: {
        'kind': kind,
        'title': title,
        'amount': amount,
        if (kind == 'expense') 'category_uuid': categoryUuid,
        'frequency': frequency,
        'starts_on': startsOn,
        'ends_on': _blankToNull(endsOn),
        'active': active,
        'note': _blankToNull(note),
        if (currency != 'USD') 'currency': currency,
      },
    );

    return RecurringRule.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<RecurringRule> updateRecurringRule(
    String uuid, {
    required String kind,
    required String title,
    required String amount,
    required String frequency,
    required String startsOn,
    String? categoryUuid,
    String? endsOn,
    String? note,
    bool active = true,
    String currency = 'USD',
  }) async {
    final response = await _client.dio.patch(
      '/recurring/$uuid',
      data: {
        'title': title,
        'amount': amount,
        if (kind == 'expense') 'category_uuid': categoryUuid,
        'frequency': frequency,
        'starts_on': startsOn,
        // Sent even when null: that is how an end date gets cleared on edit.
        'ends_on': _blankToNull(endsOn),
        'active': active,
        'note': _blankToNull(note),
        if (currency != 'USD') 'currency': currency,
      },
    );

    return RecurringRule.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// The rows a rule already created stay put; only the template goes.
  Future<void> deleteRecurringRule(String uuid) =>
      _client.dio.delete('/recurring/$uuid');

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  // -------------------------------------------------------------- savings

  /// The month against its plan, plus the all-time balance.
  Future<SavingsSummary> savingsSummary(String month) async {
    final response = await _client.dio.get(
      '/savings/summary',
      queryParameters: {'month': month},
    );

    return SavingsSummary.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// The month's deposits and withdrawals, newest first. No pagination — a
  /// month's worth of entries is a short list by nature.
  Future<List<SavingsEntry>> savingsEntries(String month) async {
    final response = await _client.dio.get(
      '/savings',
      queryParameters: {'month': month},
    );

    return ((response.data as Map<String, dynamic>)['data'] as List<dynamic>)
        .map((e) => SavingsEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// The stored plan row for the month, or null when none is set. Only the
  /// uuid is worth the call — the amount is already in the summary — but that
  /// uuid is what DELETE needs.
  Future<SavingsPlan?> savingsPlan(String month) async {
    final response = await _client.dio.get(
      '/savings/plan',
      queryParameters: {'month': month},
    );

    final data = (response.data as Map<String, dynamic>)['data'];

    return data is Map<String, dynamic> ? SavingsPlan.fromJson(data) : null;
  }

  /// Upserts the month's plan, the way POST /budgets does its slot. There is
  /// no separate update call, by design.
  Future<void> setSavingsPlan({
    required String month,
    required String amount,
    String currency = 'USD',
  }) async {
    await _client.dio.post(
      '/savings/plan',
      data: {
        'month': month,
        'amount': amount,
        if (currency != 'USD') 'currency': currency,
      },
    );
  }

  Future<void> deleteSavingsPlan(String uuid) =>
      _client.dio.delete('/savings/plan/$uuid');

  /// [type] is deposit | withdraw; [amount] is always positive — the server
  /// applies the sign. A withdrawal past the all-time balance comes back as a
  /// 422 whose `errors.amount` says so.
  Future<void> addSavingsEntry({
    required String type,
    required String amount,
    required String savedOn,
    String? note,
    String currency = 'USD',
  }) async {
    await _client.dio.post(
      '/savings/entries',
      data: {
        'type': type,
        'amount': amount,
        'saved_on': savedOn,
        'note': note,
        if (currency != 'USD') 'currency': currency,
      },
    );
  }

  Future<void> updateSavingsEntry(
    String uuid, {
    required String type,
    required String amount,
    required String savedOn,
    String? note,
    String currency = 'USD',
  }) async {
    await _client.dio.patch(
      '/savings/entries/$uuid',
      data: {
        'type': type,
        'amount': amount,
        'saved_on': savedOn,
        // Sent even when null: that is how a note gets cleared on edit.
        'note': note,
        if (currency != 'USD') 'currency': currency,
      },
    );
  }

  Future<void> deleteSavingsEntry(String uuid) =>
      _client.dio.delete('/savings/entries/$uuid');

  // -------------------------------------------------------------- reports

  /// [period] is week | month | year | all; [at] anchors it (`2026-08` for a
  /// month, `2026-08-17` for a week, `2026` for a year) and is ignored for all.
  Future<Report> report({String period = 'month', String? at}) async {
    final response = await _client.dio.get(
      '/reports',
      queryParameters: {'period': period, 'at': ?at},
    );

    return Report.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  // ----------------------------------------------------------- categories

  Future<List<Category>> categories() async {
    final response = await _client.dio.get('/categories');

    return ((response.data as Map<String, dynamic>)['data'] as List<dynamic>)
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Creating and editing need the `categories:write` ability *and* the admin
  /// policy behind it — a non-admin's token never carries the ability, so the
  /// screen hides these rather than offering a guaranteed 403.
  Future<void> createCategory({
    required String name,
    required String color,
    required String icon,
  }) async {
    await _client.dio.post(
      '/categories',
      data: {'name': name, 'color': color, 'icon': icon},
    );
  }

  Future<void> updateCategory(
    String uuid, {
    required String name,
    required String color,
    required String icon,
  }) async {
    await _client.dio.patch(
      '/categories/$uuid',
      data: {'name': name, 'color': color, 'icon': icon},
    );
  }

  /// `409` when expenses or budgets still reference it — the foreign keys
  /// restrict rather than cascade, so a busy category is a conflict.
  Future<void> deleteCategory(String uuid) =>
      _client.dio.delete('/categories/$uuid');

  // -------------------------------------------------------------- budgets

  Future<BudgetSummary> budgetSummary(String month) async {
    final response = await _client.dio.get(
      '/budgets/summary',
      queryParameters: {'month': month},
    );

    return BudgetSummary.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<List<Budget>> budgets(String month) async {
    final response = await _client.dio.get(
      '/budgets',
      queryParameters: {'month': month},
    );

    return ((response.data as Map<String, dynamic>)['data'] as List<dynamic>)
        .map((e) => Budget.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Upserts the (category, month) slot — omit the category for the overall
  /// budget. No separate update call exists, by design.
  Future<void> setBudget({
    required String month,
    required String amount,
    String? categoryUuid,
    String currency = 'USD',
  }) async {
    await _client.dio.post(
      '/budgets',
      data: {
        'month': month,
        'amount': amount,
        'category_uuid': ?categoryUuid,
        if (currency != 'USD') 'currency': currency,
      },
    );
  }

  Future<void> deleteBudget(String uuid) =>
      _client.dio.delete('/budgets/$uuid');

  // ------------------------------------------------------------- branding

  /// Public: no token needed, so the sign-in screen can wear it too.
  Future<Branding> branding() async {
    final response = await _client.dio.get('/branding');

    return Branding.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  // ------------------------------------------------------------- activity

  /// The caller's own log, or everyone's when [everyone] (admins only —
  /// the server refuses it otherwise).
  Future<({List<ActivityEntry> items, bool hasMore})> activity({
    int page = 1,
    bool everyone = false,
  }) async {
    final response = await _client.dio.get(
      '/activity',
      queryParameters: {
        'page': page,
        'per_page': 50,
        if (everyone) 'scope': 'all',
      },
    );

    final data = response.data as Map<String, dynamic>;

    return (
      items: (data['data'] as List<dynamic>)
          .map((e) => ActivityEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMore: (data['links'] as Map<String, dynamic>?)?['next'] != null,
    );
  }

  // ---------------------------------------------------------------- admin

  /// The admin desk. Every call is double-gated server-side: the token needs
  /// the users:*/settings:write abilities (which only admin permissions can
  /// grant), and the policies rule again per row.
  Future<List<AdminUser>> adminUsers() async {
    final response = await _client.dio.get(
      '/admin/users',
      queryParameters: {'per_page': 100},
    );

    return ((response.data as Map<String, dynamic>)['data'] as List<dynamic>)
        .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveAdminUser({
    String? uuid,
    required String name,
    required String email,
    String? username,
    String? password,
    required String role,
    required String status,
  }) async {
    final payload = {
      'name': name,
      'email': email,
      'username': username ?? '',
      // Blank on edit means "keep it" — the request drops the empty field.
      if (password != null && password.isNotEmpty) ...{
        'password': password,
        'password_confirmation': password,
      },
      'role': role,
      'status': status,
    };

    uuid == null
        ? await _client.dio.post('/admin/users', data: payload)
        : await _client.dio.patch('/admin/users/$uuid', data: payload);
  }

  Future<void> deleteAdminUser(String uuid) =>
      _client.dio.delete('/admin/users/$uuid');

  /// An admin setting someone's photo; the same store the profile uses.
  Future<AdminUser> uploadAdminUserAvatar(
    String uuid, {
    required List<int> bytes,
    required String filename,
  }) async {
    final response = await _client.dio.post(
      '/admin/users/$uuid/avatar',
      data: FormData.fromMap({
        'avatar': MultipartFile.fromBytes(bytes, filename: filename),
      }),
    );

    return AdminUser.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<AdminUser> removeAdminUserAvatar(String uuid) async {
    final response = await _client.dio.delete('/admin/users/$uuid/avatar');

    return AdminUser.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// Published entries for everyone; drafts included for admins.
  Future<List<FaqEntry>> faqs() async {
    final response = await _client.dio.get('/faqs');

    return ((response.data as Map<String, dynamic>)['data'] as List<dynamic>)
        .map((e) => FaqEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveFaq({
    String? uuid,
    required String question,
    required String answer,
    required String status,
  }) async {
    final payload = {'question': question, 'answer': answer, 'status': status};

    uuid == null
        ? await _client.dio.post('/admin/faqs', data: payload)
        : await _client.dio.patch('/admin/faqs/$uuid', data: payload);
  }

  Future<void> deleteFaq(String uuid) =>
      _client.dio.delete('/admin/faqs/$uuid');

  Future<BrandingSettings> brandingSettings() async {
    final response = await _client.dio.get('/admin/settings/branding');

    return BrandingSettings.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// Multipart on POST, since it can carry the marks. Each image is replaced
  /// when bytes are given, cleared with its remove flag, or left alone.
  Future<BrandingSettings> updateBranding({
    required String appName,
    String? copyrightHolder,
    ({List<int> bytes, String filename})? logo,
    ({List<int> bytes, String filename})? favicon,
    bool removeLogo = false,
    bool removeFavicon = false,
  }) async {
    final response = await _client.dio.post(
      '/admin/settings/branding',
      data: FormData.fromMap({
        'app_name': appName,
        'copyright_holder': copyrightHolder ?? '',
        if (logo != null) 'logo': MultipartFile.fromBytes(logo.bytes, filename: logo.filename),
        if (favicon != null)
          'favicon': MultipartFile.fromBytes(favicon.bytes, filename: favicon.filename),
        if (removeLogo) 'remove_logo': '1',
        if (removeFavicon) 'remove_favicon': '1',
      }),
    );

    return BrandingSettings.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<ColorSettings> colorSettings() async {
    final response = await _client.dio.get('/admin/settings/colors');

    return ColorSettings.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<ColorSettings> updateColors({
    required String buttonColor,
    required String bodyColor,
  }) async {
    final response = await _client.dio.put(
      '/admin/settings/colors',
      data: {'button_color': buttonColor, 'body_color': bodyColor},
    );

    return ColorSettings.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<SpendingSettings> spendingSettings() async {
    final response = await _client.dio.get('/admin/settings/spending');

    return SpendingSettings.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<SpendingSettings> updateSpendingSettings({
    required bool enabled,
    required String warning,
    required String advice,
    double? khrPerUsd,
    String? defaultCurrency,
  }) async {
    final response = await _client.dio.put(
      '/admin/settings/spending',
      data: {
        'enabled': enabled,
        'warning': warning,
        'advice': advice,
        'khr_per_usd': ?khrPerUsd,
        'default_currency': ?defaultCurrency,
      },
    );

    return SpendingSettings.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  // -------------------------------------------------------------- profile

  /// The profile photo, as multipart. Bytes rather than a path so the same
  /// call works wherever the picker runs, the web included. Open to every
  /// signed-in account — no ability, no permission — so it never 403s.
  Future<User> uploadAvatar({
    required List<int> bytes,
    required String filename,
  }) async {
    final response = await _client.dio.post(
      '/profile/avatar',
      data: FormData.fromMap({
        'avatar': MultipartFile.fromBytes(bytes, filename: filename),
      }),
    );

    return User.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<User> removeAvatar() async {
    final response = await _client.dio.delete('/profile/avatar');

    return User.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<User> updateProfile({
    required String name,
    required String email,
    String? username,
    String? phone,
  }) async {
    // Blank strings, not omitted keys: the server treats blank as "clear it",
    // and an omitted username or phone would leave the old value in place.
    final response = await _client.dio.patch(
      '/profile',
      data: {
        'name': name,
        'email': email,
        'username': username ?? '',
        'phone': phone ?? '',
      },
    );

    return User.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<void> changePassword({
    required String password,
    required String passwordConfirmation,
  }) async {
    await _client.dio.put(
      '/password',
      data: {
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
  }
}
