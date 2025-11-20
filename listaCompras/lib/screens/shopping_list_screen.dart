import 'package:flutter/material.dart';
import '../models/shopping_list.dart';
import '../services/api_service.dart';
import 'shopping_list_form_screen.dart';
import 'shopping_list_detail_screen.dart';
import '../widgets/shopping_list_card.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  List<ShoppingList> _lists = [];
  String _filter = 'all'; // all, active, completed
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists() async {
    setState(() => _isLoading = true);
    try {
      final lists = await ApiService.getShoppingLists();
      setState(() {
        _lists = lists;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackbar('Erro ao carregar listas: $e');
    }
  }

  List<ShoppingList> get _filteredLists {
    switch (_filter) {
      case 'active':
        return _lists.where((list) => list.status == 'active').toList();
      case 'completed':
        return _lists.where((list) => list.status == 'completed').toList();
      default:
        return _lists;
    }
  }

  Future<void> _deleteList(ShoppingList list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja excluir "${list.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.deleteShoppingList(list.id);
        await _loadLists();
        _showSuccessSnackbar('Lista excluída');
      } catch (e) {
        _showErrorSnackbar('Erro ao excluir: $e');
      }
    }
  }

  Future<void> _openListForm([ShoppingList? list]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShoppingListFormScreen(list: list),
      ),
    );

    if (result == true) {
      await _loadLists();
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredLists = _filteredLists;
    final stats = _calculateStats();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Listas de Compras'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(Icons.list),
                    SizedBox(width: 8),
                    Text('Todas'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'active',
                child: Row(
                  children: [
                    Icon(Icons.shopping_cart),
                    SizedBox(width: 8),
                    Text('Ativas'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'completed',
                child: Row(
                  children: [
                    Icon(Icons.check_circle),
                    SizedBox(width: 8),
                    Text('Concluídas'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          // Card de Estatísticas
          if (_lists.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.green, Colors.greenAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    Icons.list,
                    'Total',
                    stats['total'].toString(),
                  ),
                  _buildStatItem(
                    Icons.shopping_cart,
                    'Ativas',
                    stats['active'].toString(),
                  ),
                  _buildStatItem(
                    Icons.check_circle,
                    'Concluídas',
                    stats['completed'].toString(),
                  ),
                  _buildStatItem(
                    Icons.attach_money,
                    'Gasto Total',
                    'R\$${stats['totalSpent'].toStringAsFixed(2)}',
                  ),
                ],
              ),
            ),

          // Lista de Compras
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredLists.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadLists,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: filteredLists.length,
                      itemBuilder: (context, index) {
                        final list = filteredLists[index];
                        return ShoppingListCard(
                          list: list,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ShoppingListDetailScreen(list: list),
                            ),
                          ),
                          onEdit: () => _openListForm(list),
                          onDelete: () => _deleteList(list),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openListForm(),
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Nova Lista'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 32),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    switch (_filter) {
      case 'active':
        message = 'Nenhuma lista ativa';
        icon = Icons.shopping_cart_outlined;
        break;
      case 'completed':
        message = 'Nenhuma lista concluída';
        icon = Icons.check_circle_outline;
        break;
      default:
        message = 'Nenhuma lista de compras';
        icon = Icons.shopping_basket;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 100, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _openListForm(),
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Criar primeira lista'),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculateStats() {
    return {
      'total': _lists.length,
      'active': _lists.where((list) => list.status == 'active').length,
      'completed': _lists.where((list) => list.status == 'completed').length,
      'totalSpent': _lists.fold(0.0, (sum, list) => sum + list.totalSpent),
    };
  }
}
