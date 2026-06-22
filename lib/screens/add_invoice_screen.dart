import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/invoice.dart';
import '../providers/invoice_provider.dart';
import '../utils/formatters.dart';

class AddInvoiceScreen extends StatefulWidget {
  final Invoice? invoice;
  const AddInvoiceScreen({super.key, this.invoice});

  @override
  State<AddInvoiceScreen> createState() => _AddInvoiceScreenState();
}

class _AddInvoiceScreenState extends State<AddInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numberCtrl = TextEditingController();
  final _clientNameCtrl = TextEditingController();
  final _clientNifCtrl = TextEditingController();
  final _clientAddressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  double _irpfRate = 15;
  DateTime _date = DateTime.now();
  DateTime? _dueDate;
  List<_ItemFormData> _items = [];

  bool get _isEditing => widget.invoice != null;

  static const _irpfRates = [0.0, 7.0, 15.0, 19.0, 21.0];
  static const _vatRates = [0.0, 4.0, 10.0, 21.0];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final inv = widget.invoice!;
      _numberCtrl.text = inv.number;
      _clientNameCtrl.text = inv.clientName;
      _clientNifCtrl.text = inv.clientNif;
      _clientAddressCtrl.text = inv.clientAddress;
      _notesCtrl.text = inv.notes ?? '';
      _irpfRate = inv.irpfRate;
      _date = inv.date;
      _dueDate = inv.dueDate;
      _items = inv.items
          .map((i) => _ItemFormData(
                description: i.description,
                quantity: i.quantity,
                unitPrice: i.unitPrice,
                vatRate: i.vatRate,
              ))
          .toList();
    } else {
      _items = [_ItemFormData()];
      _loadNextNumber();
    }
  }

  Future<void> _loadNextNumber() async {
    final number = await context.read<InvoiceProvider>().nextInvoiceNumber();
    if (mounted) setState(() => _numberCtrl.text = number);
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _clientNameCtrl.dispose();
    _clientNifCtrl.dispose();
    _clientAddressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _baseAmount =>
      _items.fold(0, (s, i) => s + i.quantity * i.unitPrice);
  double get _totalVat =>
      _items.fold(0, (s, i) => s + i.quantity * i.unitPrice * i.vatRate / 100);
  double get _irpfAmount => _baseAmount * _irpfRate / 100;
  double get _total => _baseAmount + _totalVat - _irpfAmount;

  Future<void> _pickDate({bool isDue = false}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isDue ? (_dueDate ?? _date.add(const Duration(days: 30))) : _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isDue) {
          _dueDate = picked;
        } else {
          _date = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Añade al menos una línea')));
      return;
    }

    final provider = context.read<InvoiceProvider>();
    final invoice = Invoice(
      id: widget.invoice?.id,
      number: _numberCtrl.text.trim(),
      clientName: _clientNameCtrl.text.trim(),
      clientNif: _clientNifCtrl.text.trim(),
      clientAddress: _clientAddressCtrl.text.trim(),
      irpfRate: _irpfRate,
      date: _date,
      dueDate: _dueDate,
      status: widget.invoice?.status ?? 'pending',
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      items: _items
          .map((i) => InvoiceItem(
                description: i.description,
                quantity: i.quantity,
                unitPrice: i.unitPrice,
                vatRate: i.vatRate,
              ))
          .toList(),
    );

    if (_isEditing) {
      await provider.updateInvoice(invoice);
    } else {
      await provider.addInvoice(invoice);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar factura' : 'Nueva factura'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Datos de la factura
            _SectionHeader(title: 'Datos de la factura'),
            TextFormField(
              controller: _numberCtrl,
              decoration: const InputDecoration(labelText: 'Número de factura'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          labelText: 'Fecha', suffixIcon: Icon(Icons.calendar_today)),
                      child: Text(formatDate(_date)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(isDue: true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          labelText: 'Vencimiento', suffixIcon: Icon(Icons.event)),
                      child: Text(_dueDate != null ? formatDate(_dueDate!) : 'Sin vencimiento'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // IRPF
            DropdownButtonFormField<double>(
              value: _irpfRate,
              decoration: const InputDecoration(labelText: 'Retención IRPF'),
              items: _irpfRates
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(r == 0 ? 'Sin retención' : '${r.toInt()}%'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _irpfRate = v ?? 15),
            ),
            const SizedBox(height: 20),

            // Cliente
            _SectionHeader(title: 'Datos del cliente'),
            TextFormField(
              controller: _clientNameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre / Razón social'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clientNifCtrl,
              decoration: const InputDecoration(labelText: 'NIF / CIF'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clientAddressCtrl,
              decoration: const InputDecoration(labelText: 'Dirección'),
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // Líneas
            _SectionHeader(title: 'Líneas de la factura'),
            ..._items.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;
              return _ItemRow(
                key: ValueKey(i),
                item: item,
                vatRates: _vatRates,
                onChanged: () => setState(() {}),
                onRemove: _items.length > 1
                    ? () => setState(() => _items.removeAt(i))
                    : null,
              );
            }),
            TextButton.icon(
              onPressed: () => setState(() => _items.add(_ItemFormData())),
              icon: const Icon(Icons.add),
              label: const Text('Añadir línea'),
            ),
            const SizedBox(height: 16),

            // Notas
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Totales
            _TotalsCard(
              base: _baseAmount,
              vat: _totalVat,
              irpf: _irpfAmount,
              total: _total,
              irpfRate: _irpfRate,
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[700]),
      ),
    );
  }
}

class _ItemFormData {
  String description;
  double quantity;
  double unitPrice;
  double vatRate;

  _ItemFormData({
    this.description = '',
    this.quantity = 1,
    this.unitPrice = 0,
    this.vatRate = 21,
  });
}

class _ItemRow extends StatelessWidget {
  final _ItemFormData item;
  final List<double> vatRates;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  const _ItemRow({
    super.key,
    required this.item,
    required this.vatRates,
    required this.onChanged,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item.description,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                    onChanged: (v) {
                      item.description = v;
                      onChanged();
                    },
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: onRemove,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item.quantity.toString(),
                    decoration: const InputDecoration(labelText: 'Cantidad'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      item.quantity = double.tryParse(v.replaceAll(',', '.')) ?? 1;
                      onChanged();
                    },
                    validator: (v) {
                      final n = double.tryParse(v?.replaceAll(',', '.') ?? '');
                      return (n == null || n <= 0) ? 'Inválido' : null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: item.unitPrice > 0 ? item.unitPrice.toStringAsFixed(2) : '',
                    decoration: const InputDecoration(labelText: 'Precio (€)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      item.unitPrice = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                      onChanged();
                    },
                    validator: (v) {
                      final n = double.tryParse(v?.replaceAll(',', '.') ?? '');
                      return (n == null || n < 0) ? 'Inválido' : null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: DropdownButtonFormField<double>(
                    value: item.vatRate,
                    decoration: const InputDecoration(labelText: 'IVA'),
                    items: vatRates
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text('${r.toInt()}%'),
                            ))
                        .toList(),
                    onChanged: (v) {
                      item.vatRate = v ?? 21;
                      onChanged();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Subtotal: ${formatCurrency(item.quantity * item.unitPrice)}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  final double base, vat, irpf, total, irpfRate;
  const _TotalsCard({
    required this.base,
    required this.vat,
    required this.irpf,
    required this.total,
    required this.irpfRate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _row('Base imponible', formatCurrency(base)),
            _row('IVA', formatCurrency(vat)),
            if (irpfRate > 0)
              _row('IRPF (-${irpfRate.toInt()}%)', '- ${formatCurrency(irpf)}',
                  color: Colors.purple),
            const Divider(),
            _row('TOTAL', formatCurrency(total), bold: true),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    final style = TextStyle(
        fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}
