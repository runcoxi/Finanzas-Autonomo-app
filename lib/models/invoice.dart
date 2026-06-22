class InvoiceItem {
  final int? id;
  final int? invoiceId;
  final String description;
  final double quantity;
  final double unitPrice;
  final double vatRate;

  const InvoiceItem({
    this.id,
    this.invoiceId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.vatRate = 21,
  });

  double get subtotal => quantity * unitPrice;
  double get vatAmount => subtotal * vatRate / 100;
  double get total => subtotal + vatAmount;

  Map<String, dynamic> toMap() => {
        'id': id,
        'invoice_id': invoiceId,
        'description': description,
        'quantity': quantity,
        'unit_price': unitPrice,
        'vat_rate': vatRate,
      };

  factory InvoiceItem.fromMap(Map<String, dynamic> map) => InvoiceItem(
        id: map['id'] as int?,
        invoiceId: map['invoice_id'] as int?,
        description: map['description'] as String,
        quantity: (map['quantity'] as num).toDouble(),
        unitPrice: (map['unit_price'] as num).toDouble(),
        vatRate: (map['vat_rate'] as num).toDouble(),
      );

  InvoiceItem copyWith({
    String? description,
    double? quantity,
    double? unitPrice,
    double? vatRate,
  }) =>
      InvoiceItem(
        id: id,
        invoiceId: invoiceId,
        description: description ?? this.description,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        vatRate: vatRate ?? this.vatRate,
      );
}

class Invoice {
  final int? id;
  final String number;
  final String clientName;
  final String clientNif;
  final String clientAddress;
  final double irpfRate;
  final DateTime date;
  final DateTime? dueDate;
  final String status; // 'pending' | 'paid' | 'overdue'
  final String? notes;
  final List<InvoiceItem> items;

  const Invoice({
    this.id,
    required this.number,
    required this.clientName,
    required this.clientNif,
    required this.clientAddress,
    this.irpfRate = 15,
    required this.date,
    this.dueDate,
    this.status = 'pending',
    this.notes,
    this.items = const [],
  });

  double get baseAmount => items.fold(0, (s, i) => s + i.subtotal);
  double get totalVat => items.fold(0, (s, i) => s + i.vatAmount);
  double get irpfAmount => baseAmount * irpfRate / 100;
  double get total => baseAmount + totalVat - irpfAmount;

  Map<String, dynamic> toMap() => {
        'id': id,
        'number': number,
        'client_name': clientName,
        'client_nif': clientNif,
        'client_address': clientAddress,
        'irpf_rate': irpfRate,
        'date': date.toIso8601String(),
        'due_date': dueDate?.toIso8601String(),
        'status': status,
        'notes': notes,
      };

  factory Invoice.fromMap(Map<String, dynamic> map, List<InvoiceItem> items) =>
      Invoice(
        id: map['id'] as int?,
        number: map['number'] as String,
        clientName: map['client_name'] as String,
        clientNif: map['client_nif'] as String,
        clientAddress: map['client_address'] as String,
        irpfRate: (map['irpf_rate'] as num).toDouble(),
        date: DateTime.parse(map['date'] as String),
        dueDate: map['due_date'] != null
            ? DateTime.parse(map['due_date'] as String)
            : null,
        status: map['status'] as String,
        notes: map['notes'] as String?,
        items: items,
      );

  Invoice copyWith({
    int? id,
    String? number,
    String? clientName,
    String? clientNif,
    String? clientAddress,
    double? irpfRate,
    DateTime? date,
    DateTime? dueDate,
    String? status,
    String? notes,
    List<InvoiceItem>? items,
  }) =>
      Invoice(
        id: id ?? this.id,
        number: number ?? this.number,
        clientName: clientName ?? this.clientName,
        clientNif: clientNif ?? this.clientNif,
        clientAddress: clientAddress ?? this.clientAddress,
        irpfRate: irpfRate ?? this.irpfRate,
        date: date ?? this.date,
        dueDate: dueDate ?? this.dueDate,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        items: items ?? this.items,
      );
}
