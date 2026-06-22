class QuarterTaxSummary {
  final int year;
  final int quarter;
  final double totalIncome;
  final double totalExpense;
  final double vatCollected;
  final double vatPaid;
  final double irpfRetained;

  const QuarterTaxSummary({
    required this.year,
    required this.quarter,
    required this.totalIncome,
    required this.totalExpense,
    required this.vatCollected,
    required this.vatPaid,
    required this.irpfRetained,
  });

  factory QuarterTaxSummary.fromMap(int year, int quarter, Map<String, double> data) =>
      QuarterTaxSummary(
        year: year,
        quarter: quarter,
        totalIncome: data['total_income'] ?? 0,
        totalExpense: data['total_expense'] ?? 0,
        vatCollected: data['vat_collected'] ?? 0,
        vatPaid: data['vat_paid'] ?? 0,
        irpfRetained: data['irpf_retained'] ?? 0,
      );

  // Modelo 303: IVA a ingresar (positivo) o devolver (negativo)
  double get vatResult => vatCollected - vatPaid;

  // Rendimiento neto estimado
  double get netIncome => totalIncome - totalExpense;

  // Modelo 130: pago fraccionado IRPF (20% rendimiento neto menos IRPF ya retenido)
  double get irpfInstallment =>
      ((netIncome * 0.20) - irpfRetained).clamp(0.0, double.infinity);

  String get quarterLabel => 'T$quarter/$year';

  static (DateTime, DateTime) quarterRange(int year, int quarter) {
    final startMonth = (quarter - 1) * 3 + 1;
    return (
      DateTime(year, startMonth, 1),
      DateTime(year, startMonth + 3, 0, 23, 59, 59),
    );
  }

  static int currentQuarter() => ((DateTime.now().month - 1) ~/ 3) + 1;
}
