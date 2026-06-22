import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/database_helper.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../services/gemini_service.dart';
import '../utils/formatters.dart';
import 'scan_ticket_screen.dart';

class AddTransactionScreen extends StatefulWidget {
  final FinancialTransaction? transaction;
  const AddTransactionScreen({super.key, this.transaction});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _type = 'income';
  String? _category;
  double _vatRate = 0;
  double _irpfRate = 0;
  DateTime _date = DateTime.now();
  List<Category> _categories = [];
  Uint8List? _image;

  bool get _isEditing => widget.transaction != null;

  static const _vatRates = [0.0, 4.0, 10.0, 21.0];
  static const _irpfRates = [0.0, 1.0, 7.0, 15.0, 19.0, 21.0];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final t = widget.transaction!;
      _titleCtrl.text = t.title;
      _amountCtrl.text = t.amount.toStringAsFixed(2);
      _notesCtrl.text = t.notes ?? '';
      _type = t.type;
      _category = t.category;
      _vatRate = t.vatRate;
      _irpfRate = t.irpfRate;
      _date = t.date;
      _image = t.image;
    }
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await DatabaseHelper().getCategories(type: _type);
    setState(() => _categories = cats);
    if (_category == null && cats.isNotEmpty) {
      setState(() => _category = cats.first.name);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _amount => double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _vatAmount => _amount * _vatRate / 100;
  double get _irpfAmount => _amount * _irpfRate / 100;
  double get _total => _amount + _vatAmount;
  double get _net => _type == 'income' ? _amount - _irpfAmount : _amount;

  Future<void> _scanTicket() async {
    final result = await Navigator.push<ExtractedTicketData>(
      context,
      MaterialPageRoute(builder: (_) => const ScanTicketScreen()),
    );
    if (result == null || !mounted) return;

    setState(() {
      // Use concepto if available, otherwise fall back to proveedor
      final title = (result.concepto?.isNotEmpty == true)
          ? result.concepto!
          : (result.proveedor ?? '');
      if (title.isNotEmpty) _titleCtrl.text = title;

      if (result.importeBase != null) {
        _amountCtrl.text = result.importeBase!.toStringAsFixed(2);
      }
      if (result.vatRate != null) _vatRate = result.vatRate!;
      if (result.irpfRate != null) _irpfRate = result.irpfRate!;
      if (result.fecha != null) _date = result.fecha!;

      // Combine proveedor + numero_factura + notas into the notes field
      final parts = <String>[
        if (result.proveedor?.isNotEmpty == true)
          'Proveedor: ${result.proveedor}',
        if (result.numeroFactura?.isNotEmpty == true)
          'Factura: ${result.numeroFactura}',
        if (result.notas?.isNotEmpty == true) result.notas!,
      ];
      if (parts.isNotEmpty) _notesCtrl.text = parts.join(' · ');

      if (result.image != null) _image = result.image;

      // Scanning a receipt implies an expense
      if (!_isEditing) {
        _type = 'expense';
        _category = null;
        _irpfRate = 0;
      }
    });

    if (!_isEditing) _loadCategories();

    if (result.image != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Foto guardada con este movimiento'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una categoría')),
      );
      return;
    }

    final provider = context.read<TransactionProvider>();
    final t = FinancialTransaction(
      id: widget.transaction?.id,
      title: _titleCtrl.text.trim(),
      amount: _amount,
      type: _type,
      category: _category!,
      vatRate: _vatRate,
      irpfRate: _irpfRate,
      date: _date,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      image: _image,
    );

    if (_isEditing) {
      await provider.updateTransaction(t);
    } else {
      await provider.addTransaction(t);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar movimiento' : 'Nuevo movimiento'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.document_scanner),
              tooltip: 'Escanear ticket con IA',
              onPressed: _scanTicket,
            ),
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
            // Tipo
            Card(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: _TypeButton(
                        label: 'Ingreso',
                        icon: Icons.arrow_upward,
                        selected: _type == 'income',
                        color: Colors.green,
                        onTap: () {
                          setState(() {
                            _type = 'income';
                            _category = null;
                          });
                          _loadCategories();
                        },
                      ),
                    ),
                    Expanded(
                      child: _TypeButton(
                        label: 'Gasto',
                        icon: Icons.arrow_downward,
                        selected: _type == 'expense',
                        color: Colors.red,
                        onTap: () {
                          setState(() {
                            _type = 'expense';
                            _category = null;
                            _irpfRate = 0;
                          });
                          _loadCategories();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_image != null) ...[
              GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    child: InteractiveViewer(child: Image.memory(_image!)),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Image.memory(_image!,
                          height: 140, width: double.infinity, fit: BoxFit.cover),
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 18),
                            tooltip: 'Quitar foto',
                            onPressed: () => setState(() => _image = null),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Concepto
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Concepto'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Introduce un concepto' : null,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),

            // Importe base
            TextFormField(
              controller: _amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Importe base (sin IVA)',
                suffixText: '€',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Introduce un importe';
                final n = double.tryParse(v.replaceAll(',', '.'));
                if (n == null || n <= 0) return 'Importe inválido';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Categoría
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c.name, child: Text(c.name)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 12),

            // IVA
            DropdownButtonFormField<double>(
              value: _vatRate,
              decoration: const InputDecoration(labelText: 'IVA'),
              items: _vatRates
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(r == 0 ? 'Sin IVA (0%)' : '${r.toInt()}%'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _vatRate = v ?? 0),
            ),
            const SizedBox(height: 12),

            // IRPF (solo en ingresos)
            if (_type == 'income')
              DropdownButtonFormField<double>(
                value: _irpfRate,
                decoration: const InputDecoration(labelText: 'Retención IRPF'),
                items: _irpfRates
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r == 0 ? 'Sin retención (0%)' : '${r.toInt()}%'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _irpfRate = v ?? 0),
              ),
            if (_type == 'income') const SizedBox(height: 12),

            // Fecha
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fecha',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(formatDate(_date)),
              ),
            ),
            const SizedBox(height: 12),

            // Notas
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Resumen
            if (_amount > 0) _TotalsPreview(
              amount: _amount,
              vatAmount: _vatAmount,
              irpfAmount: _irpfAmount,
              total: _total,
              net: _net,
              type: _type,
              vatRate: _vatRate,
              irpfRate: _irpfRate,
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? color : Colors.grey, size: 18),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: selected ? color : Colors.grey,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

class _TotalsPreview extends StatelessWidget {
  final double amount, vatAmount, irpfAmount, total, net;
  final String type;
  final double vatRate, irpfRate;

  const _TotalsPreview({
    required this.amount,
    required this.vatAmount,
    required this.irpfAmount,
    required this.total,
    required this.net,
    required this.type,
    required this.vatRate,
    required this.irpfRate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumen', style: Theme.of(context).textTheme.labelLarge),
            const Divider(),
            _row('Base imponible', formatCurrency(amount)),
            if (vatRate > 0) _row('IVA (${vatRate.toInt()}%)', formatCurrency(vatAmount)),
            _row('Total factura', formatCurrency(total), bold: true),
            if (type == 'income' && irpfRate > 0) ...[
              _row('IRPF (-${irpfRate.toInt()}%)', '- ${formatCurrency(irpfAmount)}',
                  color: Colors.purple),
              _row('Cobro neto', formatCurrency(net),
                  bold: true, color: Colors.green[700]!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
