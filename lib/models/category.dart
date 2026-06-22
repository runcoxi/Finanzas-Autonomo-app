import 'package:flutter/material.dart';

class Category {
  final int? id;
  final String name;
  final String type;
  final String iconName;
  final int colorValue;

  const Category({
    this.id,
    required this.name,
    required this.type,
    required this.iconName,
    required this.colorValue,
  });

  Color get color => Color(colorValue);

  IconData get icon {
    const icons = <String, IconData>{
      'work': Icons.work,
      'business_center': Icons.business_center,
      'school': Icons.school,
      'shopping_cart': Icons.shopping_cart,
      'attach_money': Icons.attach_money,
      'home_work': Icons.home_work,
      'computer': Icons.computer,
      'directions_car': Icons.directions_car,
      'campaign': Icons.campaign,
      'menu_book': Icons.menu_book,
      'gavel': Icons.gavel,
      'health_and_safety': Icons.health_and_safety,
      'receipt': Icons.receipt,
    };
    return icons[iconName] ?? Icons.category;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'icon': iconName,
        'color': colorValue,
      };

  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'] as int?,
        name: map['name'] as String,
        type: map['type'] as String,
        iconName: map['icon'] as String,
        colorValue: map['color'] as int,
      );
}

final List<Category> defaultCategories = [
  const Category(name: 'Servicios profesionales', type: 'income', iconName: 'work', colorValue: 0xFF2E7D32),
  const Category(name: 'Consultoría', type: 'income', iconName: 'business_center', colorValue: 0xFF1565C0),
  const Category(name: 'Formación', type: 'income', iconName: 'school', colorValue: 0xFF6A1B9A),
  const Category(name: 'Ventas', type: 'income', iconName: 'shopping_cart', colorValue: 0xFF00838F),
  const Category(name: 'Otros ingresos', type: 'income', iconName: 'attach_money', colorValue: 0xFF558B2F),
  const Category(name: 'Oficina y suministros', type: 'expense', iconName: 'home_work', colorValue: 0xFFC62828),
  const Category(name: 'Software y suscripciones', type: 'expense', iconName: 'computer', colorValue: 0xFFAD1457),
  const Category(name: 'Transporte', type: 'expense', iconName: 'directions_car', colorValue: 0xFFE65100),
  const Category(name: 'Marketing y publicidad', type: 'expense', iconName: 'campaign', colorValue: 0xFF6A1B9A),
  const Category(name: 'Formación y libros', type: 'expense', iconName: 'menu_book', colorValue: 0xFF00695C),
  const Category(name: 'Asesoría y legal', type: 'expense', iconName: 'gavel', colorValue: 0xFF37474F),
  const Category(name: 'Seguridad Social', type: 'expense', iconName: 'health_and_safety', colorValue: 0xFF1565C0),
  const Category(name: 'Otros gastos', type: 'expense', iconName: 'receipt', colorValue: 0xFF795548),
];
