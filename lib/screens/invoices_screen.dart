import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/invoice_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/invoice_tile.dart';
import 'add_invoice_screen.dart';

class InvoicesScreen extends StatelessWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<InvoiceProvider>(
      builder: (context, provider, _) {
        final invoices = provider.invoices;
        return Scaffold(
          appBar: AppBar(title: const Text('Facturas')),
          body: provider.loading
              ? const Center(child: CircularProgressIndicator())
              : invoices.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.description, size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('No hay facturas todavía',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => provider.init(),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: invoices.length,
                        itemBuilder: (ctx, i) {
                          final inv = invoices[i];
                          return Dismissible(
                            key: Key('inv_${inv.id}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              color: Colors.red[700],
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            confirmDismiss: (_) => showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('Eliminar factura'),
                                content: Text('¿Eliminar factura ${inv.number}?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const Text('Eliminar',
                                        style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            ),
                            onDismissed: (_) => provider.deleteInvoice(inv.id!),
                            child: InvoiceTile(
                              invoice: inv,
                              onTap: () => _showInvoiceOptions(context, provider, inv),
                              onExport: () {
                                final settings =
                                    context.read<SettingsProvider>().settings;
                                provider.exportPdf(inv, settings);
                              },
                            ),
                          );
                        },
                      ),
                    ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddInvoiceScreen()),
            ),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _showInvoiceOptions(
      BuildContext context, InvoiceProvider provider, invoice) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Editar factura'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AddInvoiceScreen(invoice: invoice)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('Marcar como cobrada'),
              onTap: () {
                Navigator.pop(ctx);
                provider.updateStatus(invoice.id!, 'paid');
              },
            ),
            ListTile(
              leading: const Icon(Icons.warning, color: Colors.orange),
              title: const Text('Marcar como vencida'),
              onTap: () {
                Navigator.pop(ctx);
                provider.updateStatus(invoice.id!, 'overdue');
              },
            ),
            ListTile(
              leading: const Icon(Icons.hourglass_empty),
              title: const Text('Marcar como pendiente'),
              onTap: () {
                Navigator.pop(ctx);
                provider.updateStatus(invoice.id!, 'pending');
              },
            ),
          ],
        ),
      ),
    );
  }
}
