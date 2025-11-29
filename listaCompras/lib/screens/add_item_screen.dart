import 'package:flutter/material.dart';
import '../models/shopping_item.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../services/database_service.dart';

class AddItemScreen extends StatefulWidget {
  final String listId;
  final ConnectivityService connectivityService;
  final SyncService syncService;
  final DatabaseService databaseService;

  const AddItemScreen({
    super.key,
    required this.listId,
    required this.connectivityService,
    required this.syncService,
    required this.databaseService,
  });

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
      final isConnected = await widget.connectivityService.checkConnection();

      if (isConnected) {
        try {
          final categories = await ApiService.getCategories();
          setState(() {
            _categories = categories;
          });
        } catch (e) {
          _loadLocalCategories();
        }
      } else {
        _loadLocalCategories();
      }
    } catch (e) {
      _showError('Erro ao carregar categorias: $e');
      _loadLocalCategories();
    } finally {
      setState(() => _isLoadingCategories = false);
    }
  }

  void _loadLocalCategories() {
    setState(() {
      _categories = ['Alimentos', 'Bebidas', 'Limpeza', 'Higiene'];
    });
  }

  Future<void> _searchProducts(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final isConnected = await widget.connectivityService.checkConnection();

      if (isConnected) {
        try {
          final results = await ApiService.searchProducts(query);
          setState(() {
            _searchResults = results;
          });
        } catch (e) {
          await _searchLocalProducts(query);
        }
      } else {
        await _searchLocalProducts(query);
      }
    } catch (e) {
      _showError('Erro na busca: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _searchLocalProducts(String query) async {
    try {
      final db = await widget.databaseService.database;

      final List<Map<String, dynamic>> localResults = [];

      try {
        final items = await db.query(
          'shopping_items',
          where: 'name LIKE ? OR category LIKE ?',
          whereArgs: ['%$query%', '%$query%'],
          limit: 20,
        );

        localResults.addAll(items);
      } catch (e) {
        print('Tabela shopping_items não encontrada, usando dados de exemplo');
      }

      if (localResults.isEmpty) {
        final sampleItems = [
          {
            'id': '1',
            'name': 'Arroz',
            'category': 'Alimentos',
            'brand': 'Tio João',
            'averagePrice': 5.99,
            'unit': 'kg',
          },
          {
            'id': '2',
            'name': 'Feijão',
            'category': 'Alimentos',
            'brand': 'Camil',
            'averagePrice': 8.49,
            'unit': 'kg',
          },
          {
            'id': '3',
            'name': 'Açúcar',
            'category': 'Alimentos',
            'brand': 'União',
            'averagePrice': 4.29,
            'unit': 'kg',
          },
          {
            'id': '4',
            'name': 'Óleo de Soja',
            'category': 'Alimentos',
            'brand': 'Liza',
            'averagePrice': 7.99,
            'unit': 'litro',
          },
          {
            'id': '5',
            'name': 'Detergente',
            'category': 'Limpeza',
            'brand': 'Ypê',
            'averagePrice': 2.49,
            'unit': 'un',
          },
          {
            'id': '6',
            'name': 'Sabonete',
            'category': 'Higiene',
            'brand': 'Dove',
            'averagePrice': 2.99,
            'unit': 'un',
          },
        ];

        final filteredSample = sampleItems.where((item) {
          return item['name'].toString().toLowerCase().contains(
                query.toLowerCase(),
              ) ||
              item['category'].toString().toLowerCase().contains(
                query.toLowerCase(),
              );
        }).toList();

        localResults.addAll(filteredSample);
      }

      setState(() {
        _searchResults = localResults;
      });
    } catch (e) {
      setState(() => _searchResults = []);
    }
  }

  Future<void> _addProduct(Map<String, dynamic> product) async {
    try {
      final item = ShoppingItem(
        productId:
            product['id'] ??
            product['productId'] ??
            'local_${DateTime.now().millisecondsSinceEpoch}',
        name: product['name'] ?? product['itemName'] ?? 'Produto',
        category: product['category'] ?? '',
        brand: product['brand'] ?? '',
        price: (product['averagePrice'] ?? product['price'] ?? 0.0).toDouble(),
        quantity: 1,
        unit: product['unit'] ?? 'un',
      );

      await widget.databaseService.insertItem(
        item,
        listId: widget.listId,
        isSynced: false,
      );

      await widget.databaseService.addToSyncQueue(
        action: 'CREATE_ITEM',
        tableName: 'shopping_items',
        recordId: item.id,
        data: {...item.toMap(), 'listId': widget.listId},
      );

      if (widget.connectivityService.isConnected &&
          !widget.syncService.isSyncing) {
        await widget.syncService.syncPendingChanges();
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ ${item.name} adicionado à lista'),
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

          if (!widget.connectivityService.isConnected)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.orange.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off,
                    size: 16,
                    color: Colors.orange.shade800,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Modo offline - buscando em dados locais',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      size: 16,
                      color: Colors.orange.shade800,
                    ),
                    onPressed: () {
                      widget.connectivityService.checkConnection();
                      if (widget.connectivityService.isConnected) {
                        _loadCategories();
                        if (_searchController.text.isNotEmpty) {
                          _searchProducts(_searchController.text);
                        }
                      }
                    },
                  ),
                ],
              ),
            ),

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
          title: Text(product['name'] ?? 'Produto'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${product['category'] ?? ''} • ${product['brand'] ?? 'Sem marca'}',
              ),
              Text(
                'R\$${(product['averagePrice'] ?? product['price'] ?? 0.0).toStringAsFixed(2)}',
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
