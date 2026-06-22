import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/tax_calculator.dart';

class TaxScreen extends StatefulWidget {
  const TaxScreen({super.key});

  @override
  State<TaxScreen> createState() => _TaxScreenState();
}

class _TaxScreenState extends State<TaxScreen> {
  int _year = DateTime.now().year;
  int _quarter = QuarterTaxSummary.currentQuarter();
  QuarterTaxSummary? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await DatabaseHelper().getQuarterlySummary(_year, _quarter);
    setState(() {
      _summary = QuarterTaxSummary.fromMap(_year, _quarter, data);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Impuestos')),
      body: Column(
        children: [
          // Selector de año y trimestre
          Container(
            color: AppTheme.primaryColor,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                // Año
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                      onPressed: () {
                        setState(() => _year--);
                        _load();
                      },
                    ),
                    Text(
                      '$_year',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: Colors.white),
                      onPressed: _year < DateTime.now().year
                          ? () {
                              setState(() => _year++);
                              _load();
                            }
                          : null,
                    ),
                  ],
                ),
                // Trimestres
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(4, (i) {
                    final q = i + 1;
                    final selected = _quarter == q;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _quarter = q);
                        _load();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'T$q',
                          style: TextStyle(
                            color: selected ? AppTheme.primaryColor : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          // Contenido
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _summary == null
                    ? const Center(child: Text('Error cargando datos'))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _TaxContent(summary: _summary!),
                      ),
          ),
        ],
      ),
    );
  }
}

class _TaxContent extends StatelessWidget {
  final QuarterTaxSummary summary;
  const _TaxContent({required this.summary});

  @override
  Widget build(BuildContext context) {
    final (startDate, endDate) = QuarterTaxSummary.quarterRange(
        summary.year, summary.quarter);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${summary.quarterLabel}  ·  ${formatDate(startDate)} – ${formatDate(endDate)}',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),

        // Modelo 303 – IVA
        _TaxCard(
          title: 'Modelo 303 — IVA',
          subtitle: 'Declaración trimestral de IVA',
          color: AppTheme.vatColor,
          rows: [
            _TaxRow('IVA repercutido (cobrado a clientes)', summary.vatCollected,
                isIncome: true),
            _TaxRow('IVA deducible (pagado a proveedores)', summary.vatPaid,
                isExpense: true),
          ],
          result: summary.vatResult,
          resultLabel: summary.vatResult >= 0
              ? 'A ingresar a Hacienda'
              : 'A devolver por Hacienda',
        ),
        const SizedBox(height: 16),

        // Modelo 130 – IRPF
        _TaxCard(
          title: 'Modelo 130 — IRPF',
          subtitle: 'Pago fraccionado trimestral',
          color: AppTheme.irpfColor,
          rows: [
            _TaxRow('Ingresos (base imponible)', summary.totalIncome,
                isIncome: true),
            _TaxRow('Gastos deducibles', summary.totalExpense, isExpense: true),
            _TaxRow('Rendimiento neto', summary.netIncome),
            _TaxRow('IRPF retenido por clientes', summary.irpfRetained,
                isExpense: true),
          ],
          result: summary.irpfInstallment,
          resultLabel: summary.irpfInstallment > 0
              ? 'Pago fraccionado estimado (20%)'
              : 'Sin pago fraccionado',
        ),
        const SizedBox(height: 16),

        // Resumen anual acumulado
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Información fiscal del trimestre',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(),
                const Text(
                  '• El Modelo 303 se presenta antes del día 20 del mes siguiente al trimestre.\n'
                  '• El Modelo 130 se presenta antes del día 20 del mes siguiente al trimestre.\n'
                  '• Los cálculos son estimados. Consulta con tu asesor fiscal.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TaxRow {
  final String label;
  final double amount;
  final bool isIncome;
  final bool isExpense;

  _TaxRow(this.label, this.amount, {this.isIncome = false, this.isExpense = false});
}

class _TaxCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final List<_TaxRow> rows;
  final double result;
  final String resultLabel;

  const _TaxCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.rows,
    required this.result,
    required this.resultLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: color, fontSize: 15)),
                Text(subtitle,
                    style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 12)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ...rows.map((row) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                              child: Text(row.label,
                                  style: const TextStyle(fontSize: 13))),
                          Text(
                            formatCurrency(row.amount),
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: row.isIncome
                                  ? AppTheme.incomeColor
                                  : row.isExpense
                                      ? AppTheme.expenseColor
                                      : null,
                            ),
                          ),
                        ],
                      ),
                    )),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(resultLabel,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Text(
                      formatCurrency(result.abs()),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: result >= 0 ? AppTheme.expenseColor : AppTheme.incomeColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
