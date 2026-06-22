import 'package:intl/intl.dart';

final _currency = NumberFormat.currency(locale: 'es_ES', symbol: '€', decimalDigits: 2);
final _dateFormat = DateFormat('dd/MM/yyyy', 'es_ES');
final _monthYear = DateFormat('MMMM yyyy', 'es_ES');
final _shortMonth = DateFormat('MMM', 'es_ES');

String formatCurrency(double amount) => _currency.format(amount);
String formatDate(DateTime date) => _dateFormat.format(date);
String formatMonthYear(DateTime date) => _monthYear.format(date);
String formatShortMonth(DateTime date) => _shortMonth.format(date);

String capitalizeFirst(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
