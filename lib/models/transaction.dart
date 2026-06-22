import 'dart:typed_data';

class FinancialTransaction {
  final int? id;
  final String title;
  final double amount;
  final String type; // 'income' | 'expense'
  final String category;
  final double vatRate;
  final double irpfRate;
  final DateTime date;
  final String? notes;
  final Uint8List? image;

  const FinancialTransaction({
    this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    this.vatRate = 0,
    this.irpfRate = 0,
    required this.date,
    this.notes,
    this.image,
  });

  bool get isIncome => type == 'income';
  double get vatAmount => amount * vatRate / 100;
  double get irpfAmount => amount * irpfRate / 100;
  double get totalWithVat => amount + vatAmount;
  double get netAmount => isIncome ? amount - irpfAmount : amount;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'type': type,
        'category': category,
        'vat_rate': vatRate,
        'irpf_rate': irpfRate,
        'date': date.toIso8601String(),
        'notes': notes,
        'image': image,
      };

  factory FinancialTransaction.fromMap(Map<String, dynamic> map) =>
      FinancialTransaction(
        id: map['id'] as int?,
        title: map['title'] as String,
        amount: (map['amount'] as num).toDouble(),
        type: map['type'] as String,
        category: map['category'] as String,
        vatRate: (map['vat_rate'] as num).toDouble(),
        irpfRate: (map['irpf_rate'] as num).toDouble(),
        date: DateTime.parse(map['date'] as String),
        notes: map['notes'] as String?,
        image: map['image'] as Uint8List?,
      );

  FinancialTransaction copyWith({
    int? id,
    String? title,
    double? amount,
    String? type,
    String? category,
    double? vatRate,
    double? irpfRate,
    DateTime? date,
    String? notes,
    Uint8List? image,
  }) =>
      FinancialTransaction(
        id: id ?? this.id,
        title: title ?? this.title,
        amount: amount ?? this.amount,
        type: type ?? this.type,
        category: category ?? this.category,
        vatRate: vatRate ?? this.vatRate,
        irpfRate: irpfRate ?? this.irpfRate,
        date: date ?? this.date,
        notes: notes ?? this.notes,
        image: image ?? this.image,
      );
}
