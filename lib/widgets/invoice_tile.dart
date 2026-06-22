import 'package:flutter/material.dart';
import '../models/invoice.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class InvoiceTile extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback? onTap;
  final VoidCallback? onExport;

  const InvoiceTile({
    super.key,
    required this.invoice,
    this.onTap,
    this.onExport,
  });

  Color get _statusColor {
    switch (invoice.status) {
      case 'paid':
        return AppTheme.paidColor;
      case 'overdue':
        return AppTheme.overdueColor;
      default:
        return AppTheme.pendingColor;
    }
  }

  String get _statusLabel {
    switch (invoice.status) {
      case 'paid':
        return 'Cobrada';
      case 'overdue':
        return 'Vencida';
      default:
        return 'Pendiente';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          invoice.number,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _statusLabel,
                            style: TextStyle(
                                color: _statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      invoice.clientName,
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                    Text(
                      formatDate(invoice.date),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrency(invoice.total),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, color: AppTheme.primaryColor),
                    onPressed: onExport,
                    tooltip: 'Exportar PDF',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
