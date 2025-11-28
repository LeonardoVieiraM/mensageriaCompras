import 'package:flutter/material.dart';
import 'package:shopping_list_app/services/database_service.dart';
import '../models/shopping_list.dart';

class ShoppingListCard extends StatelessWidget {
  final ShoppingList list;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ShoppingListCard({
    super.key,
    required this.list,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: _buildLeading(),
        title: _buildTitle(),
        subtitle: _buildSubtitle(),
        trailing: _buildTrailing(),
        onTap: onTap,
      ),
    );
  }

  Widget _buildLeading() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: _getStatusColor(), width: 2),
      ),
      child: Icon(_getStatusIcon(), color: _getStatusColor(), size: 24),
    );
  }

  Widget _buildTitle() {
    return FutureBuilder<Map<String, dynamic>>(
      future: DatabaseService().getSyncStatusForList(list.id),
      builder: (context, snapshot) {
        final isSynced = snapshot.data?['isSynced'] ?? true;

        return Row(
          children: [
            Expanded(
              child: Text(
                list.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: list.status == 'completed' ? Colors.grey : null,
                ),
              ),
            ),
            // Ícone de status de sincronização
            if (!isSynced)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.cloud_off, color: Colors.orange, size: 16),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getStatusText(),
                style: TextStyle(
                  fontSize: 10,
                  color: _getStatusColor(),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubtitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (list.description.isNotEmpty)
          Text(
            list.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.shopping_basket, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              '${list.purchasedItems}/${list.totalItems} itens',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(width: 16),
            Icon(Icons.attach_money, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              'R\$${list.estimatedTotal.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        if (list.updatedAt != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.update, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'Atualizada: ${_formatDate(list.updatedAt)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTrailing() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        if (value == 'edit') onEdit();
        if (value == 'delete') onDelete();
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, color: Colors.blue),
              SizedBox(width: 8),
              Text('Editar'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red),
              SizedBox(width: 8),
              Text('Excluir'),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    switch (list.status) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (list.status) {
      case 'active':
        return Icons.shopping_cart;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.shopping_basket;
    }
  }

  String _getStatusText() {
    switch (list.status) {
      case 'active':
        return 'Ativa';
      case 'completed':
        return 'Concluída';
      case 'cancelled':
        return 'Cancelada';
      default:
        return list.status;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Hoje';
    } else if (difference.inDays == 1) {
      return 'Ontem';
    } else if (difference.inDays < 7) {
      return 'Há ${difference.inDays} dias';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
