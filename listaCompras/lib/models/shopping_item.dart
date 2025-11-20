import 'package:uuid/uuid.dart';

class ShoppingItem {
  final String id;
  final String productId;
  final String name;
  final String category;
  final String brand;
  final double price;
  final int quantity;
  final String unit;
  final bool purchased;
  final String notes;
  final DateTime addedAt;
  final DateTime updatedAt;

  ShoppingItem({
    String? id,
    required this.productId,
    required this.name,
    this.category = '',
    this.brand = '',
    required this.price,
    this.quantity = 1,
    this.unit = 'un',
    this.purchased = false,
    this.notes = '',
    DateTime? addedAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       addedAt = addedAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'name': name,
      'category': category,
      'brand': brand,
      'price': price,
      'quantity': quantity,
      'unit': unit,
      'purchased': purchased,
      'notes': notes,
      'addedAt': addedAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ShoppingItem.fromMap(Map<String, dynamic> map) {
    try {
      print('🔄 [SHOPPING-ITEM] Convertendo map para ShoppingItem');
      print('📦 Map data: $map');

      String itemId =
          map['id'] as String? ?? map['itemId'] as String? ?? const Uuid().v4();

      return ShoppingItem(
        id: itemId, 
        productId:
            map['itemId'] as String? ?? map['productId'] as String? ?? '',
        name: map['itemName'] as String? ?? map['name'] as String? ?? '',
        category: map['category'] as String? ?? '',
        brand: map['brand'] as String? ?? '',
        price: (map['estimatedPrice'] ?? map['price'] ?? 0.0).toDouble(),
        quantity: (map['quantity'] ?? 1).toInt(),
        unit: map['unit'] as String? ?? 'un',
        purchased: map['purchased'] == true || map['purchased'] == 1,
        notes: map['notes'] as String? ?? '',
        addedAt: map['addedAt'] != null
            ? DateTime.parse(map['addedAt'] as String)
            : DateTime.now(),
        updatedAt: map['updatedAt'] != null
            ? DateTime.parse(map['updatedAt'] as String)
            : DateTime.now(),
      );
    } catch (e) {
      print('❌ Erro no fromMap ShoppingItem: $e');
      print('❌ Map data: $map');
      rethrow;
    }
  }

  ShoppingItem copyWith({
    String? name,
    String? category,
    String? brand,
    double? price,
    int? quantity,
    String? unit,
    bool? purchased,
    String? notes,
  }) {
    return ShoppingItem(
      id: id,
      productId: productId,
      name: name ?? this.name,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      purchased: purchased ?? this.purchased,
      notes: notes ?? this.notes,
      addedAt: addedAt,
      updatedAt: DateTime.now(),
    );
  }

  double get totalPrice => price * quantity;
}
