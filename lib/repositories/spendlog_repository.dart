import '../api/api_client.dart';
import '../models/budget.dart';
import '../models/budget_summary.dart';
import '../models/category.dart';
import '../models/dashboard.dart';
import '../models/expense.dart';
import '../models/user.dart';

/// Every data call the app makes, one thin method per endpoint. Shapes follow
/// docs/API.md in the backend repo; anything clever (currency conversion,
/// budget upserts) happens server-side, so these stay dumb on purpose.
class SpendLogRepository {
  SpendLogRepository(this._client);

  final ApiClient _client;

  // ------------------------------------------------------------ dashboard

  Future<Dashboard> dashboard({String? month}) async {
    final response = await _client.dio.get('/dashboard', queryParameters: {
      'budget_month': ?month,
      'breakdown_month': ?month,
    });

    return Dashboard.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  // ------------------------------------------------------------- expenses

  Future<({List<Expense> items, bool hasMore})> expenses({int page = 1}) async {
    final response = await _client.dio.get('/expenses', queryParameters: {'page': page});

    final data = response.data as Map<String, dynamic>;
    final items = (data['data'] as List<dynamic>)
        .map((e) => Expense.fromJson(e as Map<String, dynamic>))
        .toList();

    return (items: items, hasMore: (data['links'] as Map<String, dynamic>?)?['next'] != null);
  }

  Future<void> createExpense({
    required String item,
    required String price,
    required String spentOn,
    String? categoryUuid,
    String? newCategory,
    String currency = 'USD',
  }) async {
    await _client.dio.post('/expenses', data: {
      'item': item,
      'price': price,
      'spent_on': spentOn,
      'category_uuid': ?categoryUuid,
      'new_category': ?newCategory,
      if (currency != 'USD') 'currency': currency,
    });
  }

  Future<void> updateExpense(
    String uuid, {
    required String item,
    required String price,
    required String spentOn,
    String? categoryUuid,
    String currency = 'USD',
  }) async {
    await _client.dio.patch('/expenses/$uuid', data: {
      'item': item,
      'price': price,
      'spent_on': spentOn,
      'category_uuid': ?categoryUuid,
      if (currency != 'USD') 'currency': currency,
    });
  }

  Future<void> deleteExpense(String uuid) => _client.dio.delete('/expenses/$uuid');

  // ----------------------------------------------------------- categories

  Future<List<Category>> categories() async {
    final response = await _client.dio.get('/categories');

    return ((response.data as Map<String, dynamic>)['data'] as List<dynamic>)
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // -------------------------------------------------------------- budgets

  Future<BudgetSummary> budgetSummary(String month) async {
    final response =
        await _client.dio.get('/budgets/summary', queryParameters: {'month': month});

    return BudgetSummary.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<List<Budget>> budgets(String month) async {
    final response = await _client.dio.get('/budgets', queryParameters: {'month': month});

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
  }) async {
    await _client.dio.post('/budgets', data: {
      'month': month,
      'amount': amount,
      'category_uuid': ?categoryUuid,
    });
  }

  Future<void> deleteBudget(String uuid) => _client.dio.delete('/budgets/$uuid');

  // -------------------------------------------------------------- profile

  Future<User> updateProfile({
    required String name,
    required String email,
    String? username,
  }) async {
    final response = await _client.dio.patch('/profile', data: {
      'name': name,
      'email': email,
      'username': username ?? '',
    });

    return User.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<void> changePassword({
    required String password,
    required String passwordConfirmation,
  }) async {
    await _client.dio.put('/password', data: {
      'password': password,
      'password_confirmation': passwordConfirmation,
    });
  }
}
