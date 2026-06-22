import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction.dart';
import '../models/invoice.dart';
import '../models/category.dart';
import '../models/client.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'finanzas_autonomo.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE transactions ADD COLUMN image BLOB');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS clients (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          nif TEXT,
          address TEXT
        )
      ''');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        icon TEXT NOT NULL,
        color INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        vat_rate REAL NOT NULL DEFAULT 0,
        irpf_rate REAL NOT NULL DEFAULT 0,
        date TEXT NOT NULL,
        notes TEXT,
        image BLOB
      )
    ''');

    await db.execute('''
      CREATE TABLE clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        nif TEXT,
        address TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        number TEXT NOT NULL UNIQUE,
        client_name TEXT NOT NULL,
        client_nif TEXT NOT NULL,
        client_address TEXT NOT NULL,
        irpf_rate REAL NOT NULL DEFAULT 15,
        date TEXT NOT NULL,
        due_date TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        description TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        vat_rate REAL NOT NULL DEFAULT 21,
        FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    final batch = db.batch();
    for (final cat in defaultCategories) {
      batch.insert('categories', cat.toMap()..remove('id'));
    }
    await batch.commit();
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  Future<Map<String, String>> getSettings() async {
    final db = await database;
    final rows = await db.query('settings');
    return {for (final r in rows) r['key'] as String: r['value'] as String};
  }

  Future<void> saveSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Categories ────────────────────────────────────────────────────────────

  Future<List<Category>> getCategories({String? type}) async {
    final db = await database;
    final rows = type != null
        ? await db.query('categories', where: 'type = ?', whereArgs: [type])
        : await db.query('categories', orderBy: 'name ASC');
    return rows.map(Category.fromMap).toList();
  }

  // ── Clients ───────────────────────────────────────────────────────────────

  Future<List<Client>> getClients() async {
    final db = await database;
    final rows = await db.query('clients', orderBy: 'name ASC');
    return rows.map(Client.fromMap).toList();
  }

  Future<void> upsertClient(Client c) async {
    if (c.name.trim().isEmpty) return;
    final db = await database;
    final existing = await db.query('clients',
        where: 'name = ?', whereArgs: [c.name], limit: 1);
    if (existing.isEmpty) {
      await db.insert('clients', c.toMap()..remove('id'));
    } else {
      await db.update('clients', {'nif': c.nif, 'address': c.address},
          where: 'name = ?', whereArgs: [c.name]);
    }
  }

  // ── Transactions ──────────────────────────────────────────────────────────

  Future<List<FinancialTransaction>> getTransactions({
    DateTime? from,
    DateTime? to,
    String? type,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (from != null) {
      conditions.add('date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      conditions.add('date <= ?');
      args.add(to.toIso8601String());
    }
    if (type != null) {
      conditions.add('type = ?');
      args.add(type);
    }

    final rows = await db.query(
      'transactions',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date DESC',
    );
    return rows.map(FinancialTransaction.fromMap).toList();
  }

  Future<int> insertTransaction(FinancialTransaction t) async {
    final db = await database;
    final map = t.toMap()..remove('id');
    return db.insert('transactions', map);
  }

  Future<void> updateTransaction(FinancialTransaction t) async {
    final db = await database;
    await db.update('transactions', t.toMap(),
        where: 'id = ?', whereArgs: [t.id]);
  }

  Future<void> deleteTransaction(int id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, double>> getMonthlySummary(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type='income' THEN amount ELSE 0 END),0) as total_income,
        COALESCE(SUM(CASE WHEN type='expense' THEN amount ELSE 0 END),0) as total_expense,
        COALESCE(SUM(CASE WHEN type='income' THEN amount*vat_rate/100 ELSE 0 END),0) as vat_collected,
        COALESCE(SUM(CASE WHEN type='expense' THEN amount*vat_rate/100 ELSE 0 END),0) as vat_paid,
        COALESCE(SUM(CASE WHEN type='income' THEN amount*irpf_rate/100 ELSE 0 END),0) as irpf_retained
      FROM transactions WHERE date BETWEEN ? AND ?
    ''', [start.toIso8601String(), end.toIso8601String()]);
    return result.first
        .map((k, v) => MapEntry(k, (v as num).toDouble()))
        .cast<String, double>();
  }

  Future<List<Map<String, dynamic>>> getLast6MonthsSummary() async {
    final db = await database;
    final start = DateTime(DateTime.now().year, DateTime.now().month - 5, 1);
    return db.rawQuery('''
      SELECT
        strftime('%Y-%m', date) as month,
        COALESCE(SUM(CASE WHEN type='income' THEN amount ELSE 0 END),0) as income,
        COALESCE(SUM(CASE WHEN type='expense' THEN amount ELSE 0 END),0) as expense
      FROM transactions WHERE date >= ?
      GROUP BY strftime('%Y-%m', date) ORDER BY month ASC
    ''', [start.toIso8601String()]);
  }

  Future<List<Map<String, dynamic>>> getCategoryExpenses(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    final db = await database;
    return db.rawQuery('''
      SELECT category, COALESCE(SUM(amount),0) as total
      FROM transactions
      WHERE type='expense' AND date BETWEEN ? AND ?
      GROUP BY category ORDER BY total DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);
  }

  Future<Map<String, double>> getQuarterlySummary(int year, int quarter) async {
    final startMonth = (quarter - 1) * 3 + 1;
    final start = DateTime(year, startMonth, 1);
    final end = DateTime(year, startMonth + 3, 0, 23, 59, 59);
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type='income' THEN amount ELSE 0 END),0) as total_income,
        COALESCE(SUM(CASE WHEN type='expense' THEN amount ELSE 0 END),0) as total_expense,
        COALESCE(SUM(CASE WHEN type='income' THEN amount*vat_rate/100 ELSE 0 END),0) as vat_collected,
        COALESCE(SUM(CASE WHEN type='expense' THEN amount*vat_rate/100 ELSE 0 END),0) as vat_paid,
        COALESCE(SUM(CASE WHEN type='income' THEN amount*irpf_rate/100 ELSE 0 END),0) as irpf_retained
      FROM transactions WHERE date BETWEEN ? AND ?
    ''', [start.toIso8601String(), end.toIso8601String()]);
    return result.first
        .map((k, v) => MapEntry(k, (v as num).toDouble()))
        .cast<String, double>();
  }

  // ── Invoices ──────────────────────────────────────────────────────────────

  Future<List<Invoice>> getInvoices() async {
    final db = await database;
    final invoiceMaps = await db.query('invoices', orderBy: 'date DESC');
    final invoices = <Invoice>[];
    for (final map in invoiceMaps) {
      final id = map['id'] as int;
      final itemMaps = await db.query('invoice_items',
          where: 'invoice_id = ?', whereArgs: [id]);
      invoices.add(Invoice.fromMap(map, itemMaps.map(InvoiceItem.fromMap).toList()));
    }
    return invoices;
  }

  Future<int> insertInvoice(Invoice invoice) async {
    final db = await database;
    final invoiceMap = invoice.toMap()..remove('id');
    final id = await db.insert('invoices', invoiceMap);
    for (final item in invoice.items) {
      final itemMap = item.toMap()
        ..remove('id')
        ..['invoice_id'] = id;
      await db.insert('invoice_items', itemMap);
    }
    return id;
  }

  Future<void> updateInvoice(Invoice invoice) async {
    final db = await database;
    await db.update('invoices', invoice.toMap(),
        where: 'id = ?', whereArgs: [invoice.id]);
    await db.delete('invoice_items',
        where: 'invoice_id = ?', whereArgs: [invoice.id]);
    for (final item in invoice.items) {
      final itemMap = item.toMap()
        ..remove('id')
        ..['invoice_id'] = invoice.id;
      await db.insert('invoice_items', itemMap);
    }
  }

  Future<void> updateInvoiceStatus(int id, String status) async {
    final db = await database;
    await db.update('invoices', {'status': status},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteInvoice(int id) async {
    final db = await database;
    await db.delete('invoices', where: 'id = ?', whereArgs: [id]);
  }

  Future<String> getNextInvoiceNumber(int year) async {
    final db = await database;
    final result = await db.rawQuery(
        "SELECT COUNT(*) as cnt FROM invoices WHERE number LIKE '$year-%'");
    final count = (result.first['cnt'] as int) + 1;
    return '$year-${count.toString().padLeft(4, '0')}';
  }
}
