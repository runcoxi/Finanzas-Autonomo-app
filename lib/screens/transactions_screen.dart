import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Movimientos'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: _FilterBar(provider: provider),
            ),
          ),
          body: provider.loading
              ? const Center(child: CircularProgressIndicator())
              : provider.transactions.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('No hay movimientos este mes',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => provider.init(),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: provider.transactions.length,
                        itemBuilder: (ctx, i) {
                          final t = provider.transactions[i];
                          return TransactionTile(
                            transaction: t,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AddTransactionScreen(transaction: t),
                              ),
                            ),
                            onDelete: () => provider.deleteTransaction(t.id!),
                          );
                        },
                      ),
                    ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
            ),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  final TransactionProvider provider;
  const _FilterBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          _chip(context, 'Todos', 'all'),
          const SizedBox(width: 8),
          _chip(context, 'Ingresos', 'income'),
          const SizedBox(width: 8),
          _chip(context, 'Gastos', 'expense'),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, String value) {
    final selected = provider.filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => provider.setFilter(value),
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
    );
  }
}
