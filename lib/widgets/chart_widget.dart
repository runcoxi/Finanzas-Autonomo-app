import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class MonthlyBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const MonthlyBarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('Sin datos'));
    }

    double maxVal = 0;
    for (final d in data) {
      final inc = (d['income'] as num).toDouble();
      final exp = (d['expense'] as num).toDouble();
      if (inc > maxVal) maxVal = inc;
      if (exp > maxVal) maxVal = exp;
    }
    if (maxVal == 0) maxVal = 100;

    final groups = <BarChartGroupData>[];
    for (var i = 0; i < data.length; i++) {
      groups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: (data[i]['income'] as num).toDouble(),
            color: AppTheme.incomeColor,
            width: 10,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
          BarChartRodData(
            toY: (data[i]['expense'] as num).toDouble(),
            color: AppTheme.expenseColor,
            width: 10,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
        barsSpace: 4,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _legend('Ingresos', AppTheme.incomeColor),
            const SizedBox(width: 16),
            _legend('Gastos', AppTheme.expenseColor),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxVal * 1.25,
              barGroups: groups,
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                      final month = data[idx]['month'] as String;
                      // month is "2024-01"
                      final parts = month.split('-');
                      if (parts.length < 2) return const SizedBox.shrink();
                      final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]));
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(formatShortMonth(dt),
                            style: const TextStyle(fontSize: 10)),
                      );
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
            ),
          ),
        ),
      ],
    );
  }

  Widget _legend(String label, Color color) {
    return Row(children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ]);
  }
}

class CategoryPieChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const CategoryPieChart({super.key, required this.data});

  static const _colors = [
    Color(0xFFC62828), Color(0xFFAD1457), Color(0xFFE65100),
    Color(0xFF6A1B9A), Color(0xFF00695C), Color(0xFF37474F),
    Color(0xFF1565C0), Color(0xFF795548),
  ];

  @override
  Widget build(BuildContext context) {
    final nonZero = data.where((d) => (d['total'] as num).toDouble() > 0).toList();
    if (nonZero.isEmpty) {
      return const Center(child: Text('Sin gastos este mes'));
    }

    final total = nonZero.fold<double>(0, (s, d) => s + (d['total'] as num).toDouble());

    final sections = <PieChartSectionData>[];
    for (var i = 0; i < nonZero.length; i++) {
      final val = (nonZero[i]['total'] as num).toDouble();
      final pct = (val / total * 100);
      sections.add(PieChartSectionData(
        value: val,
        color: _colors[i % _colors.length],
        title: '${pct.toStringAsFixed(0)}%',
        radius: 70,
        titleStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
      ));
    }

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 30, sectionsSpace: 2)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: List.generate(nonZero.length, (i) {
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10, color: _colors[i % _colors.length]),
              const SizedBox(width: 4),
              Text(nonZero[i]['category'] as String, style: const TextStyle(fontSize: 11)),
            ]);
          }),
        ),
      ],
    );
  }
}
