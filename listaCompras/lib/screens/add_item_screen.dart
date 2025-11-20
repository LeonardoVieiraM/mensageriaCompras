import 'package:flutter/material.dart';
import '../models/shopping_item.dart';
import '../services/api_service.dart';

class AddItemScreen extends StatefulWidget {
  final String listId;

  const AddItemScreen({super.key, required this.listId});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  List<String> _categories = [];
  bool _isSearching = false;
  bool _isLoadingCategories = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final categories = await ApiService.getCategories();
      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
      });
    } catch (e) {
      setState(() => _isLoadingCategories = false);
      _showError('Erro ao carregar categorias: $e');
    }
  }

  Future<void> _searchProducts(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await ApiService.searchProducts(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });

      print('🔍 Busca por "$query" encontrou ${results.length} resultados');
    } catch (e) {
      setState(() => _isSearching = false);
      _showError('Erro na busca: $e');
    }
  }

  Future<void> _addProduct(Map<String, dynamic> product) async {
    try {
      final item = ShoppingItem(
        productId: product['id'],
        name: product['name'],
        category: product['category'],
        brand: product['brand'] ?? '',
        price: (product['averagePrice'] ?? 0.0).toDouble(),
        quantity: 1,
        unit: product['unit'] ?? 'un',
      );

      await ApiService.addItemToList(widget.listId, item);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ ${product['name']} adicionado à lista'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Erro ao adicionar produto: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar Item'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Barra de Pesquisa
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar produtos...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchResults = []);
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: _searchProducts,
            ),
          ),

          // Resultados da Busca
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isNotEmpty
                ? _buildSearchResults()
                : _buildCategories(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final product = _searchResults[index];
        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shopping_basket, color: Colors.green),
          ),
          title: Text(product['name']),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${product['category']} • ${product['brand'] ?? 'Sem marca'}',
              ),
              Text(
                'R\$${product['averagePrice']?.toStringAsFixed(2) ?? '0.00'}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.green),
            onPressed: () => _addProduct(product),
          ),
        );
      },
    );
  }

  Widget _buildCategories() {
    if (_isLoadingCategories) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Categorias',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        ..._categories.map((category) {
          return ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getCategoryColor(category),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.category, color: Colors.white),
            ),
            title: Text(category),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _searchController.text = category;
              _searchProducts(category);
            },
          );
        }),
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
