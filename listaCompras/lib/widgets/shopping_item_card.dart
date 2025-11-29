import 'package:flutter/material.dart';
import 'package:shopping_list_app/services/database_service.dart';
import '../models/shopping_item.dart';

class ShoppingItemCard extends StatelessWidget {
  final ShoppingItem item;
  final VoidCallback onToggle;
  final Function(int) onQuantityChange;
  final VoidCallback onRemove;

  const ShoppingItemCard({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onQuantityChange,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: _buildLeading(),
        title: _buildTitle(),
        subtitle: _buildSubtitle(),
        trailing: _buildTrailing(),
      ),
    );
  }

  Widget _buildSyncStatus() {
    return FutureBuilder<Map<String, dynamic>>(
      future: DatabaseService().getSyncStatusForItem(item.id),
      builder: (context, snapshot) {
        final isSynced = snapshot.data?['isSynced'] ?? true;

        if (!isSynced) {
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Icon(Icons.cloud_off, color: Colors.orange, size: 16),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildLeading() {
    return Checkbox(
      value: item.purchased,
      onChanged: (value) => onToggle(),
      fillColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return Colors.green;
        }
        return null;
      }),
    );
  }

  Widget _buildTitle() {
    return Row(
      children: [
        Expanded(
          child: Text(
            item.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              decoration: item.purchased ? TextDecoration.lineThrough : null,
              color: item.purchased ? Colors.grey : null,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _getCategoryColor(item.category).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            item.category,
            style: TextStyle(
              fontSize: 10,
              color: _getCategoryColor(item.category),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.brand.isNotEmpty)
          Text(
            item.brand,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              'R\$${item.price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '• ${item.quantity} ${item.unit}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(width: 8),
            Text(
              'Total: R\$${item.totalPrice.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ),
        if (item.notes.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Notas: ${item.notes}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTrailing() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 16),
                onPressed: () => onQuantityChange(item.quantity - 1),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Text(
                item.quantity.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 16),
                onPressed: () => onQuantityChange(item.quantity + 1),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        _buildSyncStatus(),

        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: onRemove,
        ),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    final colors = {
      'Alimentos': Colors.orange,
      'Limpeza': Colors.blue,
      'Higiene': Colors.purple,
      'Bebidas': Colors.green,
    };
    return colors[category] ?? Colors.grey;
  }
}
