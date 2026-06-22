import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/summary_card.dart';
import '../widgets/chart_widget.dart';
import '../widgets/transaction_tile.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Finanzas Autónomo'),
            actions: [
              IconButton(
                icon: const Icon(Icons.person),
                tooltip: 'Mi perfil',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),
          body: provider.loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => provider.init(),
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _MonthSelector(provider: provider),
                      const SizedBox(height: 12),
                      _SummaryGrid(provider: provider),
                      const SizedBox(height: 16),
                      _SectionTitle(title: 'Últimos 6 meses'),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: MonthlyBarChart(data: provider.last6Months),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (provider.categoryExpenses.isNotEmpty) ...[
                        _SectionTitle(title: 'Gastos por categoría'),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: CategoryPieChart(data: provider.categoryExpenses),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (provider.transactions.isNotEmpty) ...[
                        _SectionTitle(title: 'Movimientos recientes'),
                        const SizedBox(height: 4),
                        ...provider.transactions.take(5).map(
                              (t) => TransactionTile(
                                transaction: t,
                                onDelete: () => provider.deleteTransaction(t.id!),
                              ),
                            ),
                      ],
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _MonthSelector extends StatelessWidget {
  final TransactionProvider provider;
  const _MonthSelector({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            final m = provider.selectedMonth;
            provider.setMonth(DateTime(m.year, m.month - 1));
          },
        ),
        Text(
          capitalizeFirst(formatMonthYear(provider.selectedMonth)),
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            final m = provider.selectedMonth;
            final next = DateTime(m.year, m.month + 1);
            if (next.isBefore(DateTime.now().add(const Duration(days: 31)))) {
              provider.setMonth(next);
            }
          },
        ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final TransactionProvider provider;
  const _SummaryGrid({required this.provider});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.6,
      children: [
        SummaryCard(
          title: 'Ingresos',
          amount: provider.totalIncome,
          icon: Icons.arrow_upward,
          color: AppTheme.incomeColor,
        ),
        SummaryCard(
          title: 'Gastos',
          amount: provider.totalExpense,
          icon: Icons.arrow_downward,
          color: AppTheme.expenseColor,
        ),
        SummaryCard(
          title: 'Balance neto',
          amount: provider.balance,
          icon: Icons.account_balance_wallet,
          color: provider.balance >= 0 ? AppTheme.incomeColor : AppTheme.expenseColor,
        ),
        SummaryCard(
          title: 'IVA pendiente',
          amount: provider.vatBalance,
          icon: Icons.receipt_long,
          color: AppTheme.vatColor,
          subtitle: provider.vatBalance >= 0 ? 'A ingresar a Hacienda' : 'A tu favor',
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[700]),
    );
  }
}
