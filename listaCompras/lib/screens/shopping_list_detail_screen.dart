import 'package:flutter/material.dart';
import '../models/shopping_list.dart';
import '../models/shopping_item.dart';
import '../services/api_service.dart';
import 'add_item_screen.dart';
import '../widgets/shopping_item_card.dart';

class ShoppingListDetailScreen extends StatefulWidget {
  final ShoppingList list;

  const ShoppingListDetailScreen({super.key, required this.list});

  @override
  State<ShoppingListDetailScreen> createState() => _ShoppingListDetailScreenState();
}

class _ShoppingListDetailScreenState extends State<ShoppingListDetailScreen> {
  late ShoppingList _list;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _list = widget.list;
  }

  Future<void> _refreshList() async {
    setState(() => _isLoading = true);
    try {
      final lists = await ApiService.getShoppingLists();
      final updatedList = lists.firstWhere(
        (l) => l.id == _list.id,
        orElse: () => _list,
      );
      setState(() {
        _list = updatedList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackbar('Erro ao atualizar: $e');
    }
  }

  Future<void> _addItem() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddItemScreen(listId: _list.id),
      ),
    );

    if (result == true) {
      await _refreshList();
    }
  }

  Future<void> _toggleItemPurchase(ShoppingItem item) async {
    try {
      final updatedItem = item.copyWith(purchased: !item.purchased);
      await ApiService.updateItemInList(_list.id, updatedItem);
      await _refreshList();
    } catch (e) {
      _showErrorSnackbar('Erro ao atualizar item: $e');
    }
  }

  Future<void> _updateItemQuantity(ShoppingItem item, int newQuantity) async {
    if (newQuantity <= 0) {
      await _removeItem(item);
      return;
    }

    try {
      final updatedItem = item.copyWith(quantity: newQuantity);
      await ApiService.updateItemInList(_list.id, updatedItem);
      await _refreshList();
    } catch (e) {
      _showErrorSnackbar('Erro ao atualizar quantidade: $e');
    }
  }

  Future<void> _removeItem(ShoppingItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover Item'),
        content: Text('Deseja remover "${item.name}" da lista?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.removeItemFromList(_list.id, item.id);
        await _refreshList();
        _showSuccessSnackbar('Item removido');
      } catch (e) {
        _showErrorSnackbar('Erro ao remover item: $e');
      }
    }
  }

  Future<void> _checkoutList() async {
    if (_list.purchasedItems == 0) {
      _showErrorSnackbar('Adicione itens à lista antes do checkout');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar Compra'),
        content: Text(
          'Deseja finalizar a lista "${_list.name}"?\n\n'
          'Total: R\$${_list.estimatedTotal.toStringAsFixed(2)}\n'
          'Itens: ${_list.purchasedItems}/${_list.totalItems}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.checkoutList(_list.id);
        await _refreshList();
        _showSuccessSnackbar('Checkout realizado! Processando...');
        
        // Mostrar mensagem sobre processamento assíncrono
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Checkout iniciado! Notificação e analytics em processamento...'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        _showErrorSnackbar('Erro no checkout: $e');
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final purchasedItems = _list.items.where((item) => item.purchased).toList();
    final pendingItems = _list.items.where((item) => !item.purchased).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_list.name),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          if (_list.status == 'active' && _list.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.check_circle),
              onPressed: _checkoutList,
              tooltip: 'Finalizar Compra',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshList,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      
      body: Column(
        children: [
          // Header com estatísticas
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Total', '${_list.totalItems}'),
                _buildStatItem('Comprados', '${_list.purchasedItems}'),
                _buildStatItem('Faltam', '${_list.totalItems - _list.purchasedItems}'),
                _buildStatItem(
                  'Total', 
                  'R\$${_list.estimatedTotal.toStringAsFixed(2)}',
                  isMoney: true,
                ),
              ],
            ),
          ),
          
          // Lista de Itens
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _list.items.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _refreshList,
                        child: CustomScrollView(
                          slivers: [
                            // Itens Pendentes
                            if (pendingItems.isNotEmpty)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'Itens Pendentes (${pendingItems.length})',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                              ),
                            
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final item = pendingItems[index];
                                  return ShoppingItemCard(
                                    item: item,
                                    onToggle: () => _toggleItemPurchase(item),
                                    onQuantityChange: (newQuantity) => 
                                        _updateItemQuantity(item, newQuantity),
                                    onRemove: () => _removeItem(item),
                                  );
                                },
                                childCount: pendingItems.length,
                              ),
                            ),
                            
                            // Itens Comprados
                            if (purchasedItems.isNotEmpty)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'Itens Comprados (${purchasedItems.length})',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ),
                            
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final item = purchasedItems[index];
                                  return ShoppingItemCard(
                                    item: item,
                                    onToggle: () => _toggleItemPurchase(item),
                                    onQuantityChange: (newQuantity) => 
                                        _updateItemQuantity(item, newQuantity),
                                    onRemove: () => _removeItem(item),
                                  );
                                },
                                childCount: purchasedItems.length,
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
      
      floatingActionButton: _list.status == 'active'
          ? FloatingActionButton(
              onPressed: _addItem,
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildStatItem(String label, String value, {bool isMoney = false}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isMoney ? Colors.green : Colors.blue,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_basket_outlined, 
              size: 100, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Lista Vazia',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Adicione itens para começar suas compras',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _addItem,
            icon: const Icon(Icons.add),
            label: const Text('Adicionar Primeiro Item'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}