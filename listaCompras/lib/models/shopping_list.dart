import 'package:shopping_list_app/models/shopping_item.dart';
import 'package:uuid/uuid.dart';

class ShoppingList {
  final String id;
  final String name;
  final String description;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ShoppingItem> items;
  final double estimatedTotal;

  ShoppingList({
    String? id,
    required this.name,
    this.description = '',
    this.status = 'active',
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ShoppingItem>? items,
    this.estimatedTotal = 0.0,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now(),
       items = items ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'items': items.map((item) => item.toMap()).toList(),
      'estimatedTotal': estimatedTotal,
    };
  }

  factory ShoppingList.fromMap(Map<String, dynamic> map) {
    try {
      List<ShoppingItem> items = [];
      if (map['items'] != null) {
        final itemsData = map['items'] as List<dynamic>;
        items = itemsData.map((itemData) {
          return ShoppingItem.fromMap(itemData as Map<String, dynamic>);
        }).toList();
      }

      return ShoppingList(
        id: map['id'] as String? ?? const Uuid().v4(),
        name: map['name'] as String? ?? '',
        description: map['description'] as String? ?? '',
        status: map['status'] as String? ?? 'active',
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'] as String)
            : DateTime.now(),
        updatedAt: map['updatedAt'] != null
            ? DateTime.parse(map['updatedAt'] as String)
            : DateTime.now(),
        items: items,
        estimatedTotal:
            (map['estimatedTotal'] ?? map['summary']?['estimatedTotal'] ?? 0.0)
                .toDouble(),
      );
    } catch (e) {
      rethrow;
    }
  }

  ShoppingList copyWith({
    String? name,
    String? description,
    String? status,
    List<ShoppingItem>? items,
    double? estimatedTotal,
  }) {
    return ShoppingList(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      items: items ?? this.items,
      estimatedTotal: estimatedTotal ?? this.estimatedTotal,
    );
  }

  int get totalItems => items.length;
  int get purchasedItems => items.where((item) => item.purchased).length;
  double get totalSpent => items
      .where((item) => item.purchased)
      .fold(0.0, (sum, item) => sum + (item.price * item.quantity));
}
