import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/transaction.dart';

class TransactionProvider extends ChangeNotifier {
  final _db = DatabaseHelper();

  List<FinancialTransaction> _transactions = [];
  DateTime _selectedMonth = DateTime.now();
  String _filter = 'all'; // 'all' | 'income' | 'expense'
  Map<String, double> _monthlySummary = {};
  List<Map<String, dynamic>> _last6Months = [];
  List<Map<String, dynamic>> _categoryExpenses = [];
  bool _loading = false;

  List<FinancialTransaction> get transactions => _transactions;
  DateTime get selectedMonth => _selectedMonth;
  String get filter => _filter;
  Map<String, double> get monthlySummary => _monthlySummary;
  List<Map<String, dynamic>> get last6Months => _last6Months;
  List<Map<String, dynamic>> get categoryExpenses => _categoryExpenses;
  bool get loading => _loading;

  double get totalIncome => _monthlySummary['total_income'] ?? 0;
  double get totalExpense => _monthlySummary['total_expense'] ?? 0;
  double get balance => totalIncome - totalExpense;
  double get vatCollected => _monthlySummary['vat_collected'] ?? 0;
  double get vatPaid => _monthlySummary['vat_paid'] ?? 0;
  double get vatBalance => vatCollected - vatPaid;

  Future<void> init() async {
    _loading = true;
    notifyListeners();
    await _loadAll();
    _loading = false;
    notifyListeners();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadTransactions(),
      _loadSummary(),
      _loadLast6Months(),
      _loadCategoryExpenses(),
    ]);
  }

  Future<void> _loadTransactions() async {
    final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);
    _transactions = await _db.getTransactions(
      from: start,
      to: end,
      type: _filter == 'all' ? null : _filter,
    );
  }

  Future<void> _loadSummary() async {
    _monthlySummary = await _db.getMonthlySummary(_selectedMonth);
  }

  Future<void> _loadLast6Months() async {
    _last6Months = await _db.getLast6MonthsSummary();
  }

  Future<void> _loadCategoryExpenses() async {
    _categoryExpenses = await _db.getCategoryExpenses(_selectedMonth);
  }

  void setMonth(DateTime month) {
    _selectedMonth = month;
    _loadAll().then((_) => notifyListeners());
  }

  void setFilter(String filter) {
    _filter = filter;
    _loadTransactions().then((_) => notifyListeners());
  }

  Future<void> addTransaction(FinancialTransaction t) async {
    await _db.insertTransaction(t);
    await _loadAll();
    notifyListeners();
  }

  Future<void> updateTransaction(FinancialTransaction t) async {
    await _db.updateTransaction(t);
    await _loadAll();
    notifyListeners();
  }

  Future<void> deleteTransaction(int id) async {
    await _db.deleteTransaction(id);
    await _loadAll();
    notifyListeners();
  }
}
