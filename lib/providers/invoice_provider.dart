import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/invoice.dart';
import '../models/settings.dart';
import '../utils/pdf_generator.dart';

class InvoiceProvider extends ChangeNotifier {
  final _db = DatabaseHelper();

  List<Invoice> _invoices = [];
  bool _loading = false;

  List<Invoice> get invoices => _invoices;
  bool get loading => _loading;

  List<Invoice> get pendingInvoices =>
      _invoices.where((i) => i.status == 'pending').toList();
  List<Invoice> get paidInvoices =>
      _invoices.where((i) => i.status == 'paid').toList();
  List<Invoice> get overdueInvoices =>
      _invoices.where((i) => i.status == 'overdue').toList();

  Future<void> init() async {
    _loading = true;
    notifyListeners();
    await _load();
    _loading = false;
    notifyListeners();
  }

  Future<void> _load() async {
    _invoices = await _db.getInvoices();
  }

  Future<String> nextInvoiceNumber() =>
      _db.getNextInvoiceNumber(DateTime.now().year);

  Future<void> addInvoice(Invoice invoice) async {
    await _db.insertInvoice(invoice);
    await _load();
    notifyListeners();
  }

  Future<void> updateInvoice(Invoice invoice) async {
    await _db.updateInvoice(invoice);
    await _load();
    notifyListeners();
  }

  Future<void> updateStatus(int id, String status) async {
    await _db.updateInvoiceStatus(id, status);
    await _load();
    notifyListeners();
  }

  Future<void> deleteInvoice(int id) async {
    await _db.deleteInvoice(id);
    await _load();
    notifyListeners();
  }

  Future<void> exportPdf(Invoice invoice, AppSettings settings) async {
    await PdfGenerator.shareInvoicePdf(invoice, settings);
  }
}
