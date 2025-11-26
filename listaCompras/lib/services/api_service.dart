import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/shopping_list.dart';
import '../models/shopping_item.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:3000/api';
    } else {
      return 'http://localhost:3000/api';
    }
  }

  static String? _authToken;

  static void setAuthToken(String token) {
    _authToken = token;
    print('Token definido: ${token.substring(0, 20)}...');
  }

  static Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  // ========== LIST SERVICE ==========

  static Future<T> _withRetry<T>(
    Future<T> Function() apiCall, {
    String? operation,
  }) async {
    int attempts = 0;
    final maxAttempts = 3;

    while (attempts < maxAttempts) {
      try {
        return await apiCall();
      } catch (e) {
        attempts++;
        print('Tentativa $attempts/$maxAttempts falhou para $operation: $e');

        if (attempts == maxAttempts) {
          rethrow;
        }

        await Future.delayed(Duration(seconds: attempts * 2));
        print('Tentando novamente $operation...');
      }
    }

    throw Exception('Todas as tentativas falharam para $operation');
  }

  static Future<List<ShoppingList>> getShoppingLists() async {
    return await _withRetry(() async {
      final url = 'http://localhost:3002/user-lists';
      print('[LIST-SERVICE] Buscando listas de: $url');

      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data['success'] == true) {
          if (data['data'] is List) {
            final listsData = data['data'] as List<dynamic>;
            final lists = listsData.map((listData) {
              return ShoppingList.fromMap(listData as Map<String, dynamic>);
            }).toList();
            return lists;
          }
        }
      }
      throw Exception('Falha ao buscar listas: ${response.statusCode}');
    }, operation: 'getShoppingLists');
  }

  static Future<ShoppingList> createShoppingList(
    String name,
    String description,
  ) async {
    try {
      final url = '$baseUrl/lists/';
      print('[GATEWAY] Criando lista em: $url');

      final response = await http
          .post(
            Uri.parse(url),
            headers: _headers,
            body: json.encode({'name': name, 'description': description}),
          )
          .timeout(const Duration(seconds: 10));

      print('[GATEWAY] Create Status: ${response.statusCode}');
      print('[GATEWAY] Create Response: ${response.body}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('Lista criada com sucesso!');
          return ShoppingList.fromMap(data['data'] as Map<String, dynamic>);
        } else {
          throw Exception('Create failed: ${data['message']}');
        }
      } else {
        throw Exception('HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      print('Erro ao criar lista: $e');
      rethrow;
    }
  }

  static Future<ShoppingList> updateShoppingList(ShoppingList list) async {
    final response = await http.put(
      Uri.parse('$baseUrl/lists/${list.id}'),
      headers: _headers,
      body: json.encode({
        'name': list.name,
        'description': list.description,
        'status': list.status,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return ShoppingList.fromMap(data['data']);
      }
    }
    throw Exception('Falha ao atualizar lista');
  }

  static Future<void> deleteShoppingList(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/lists/$id'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao excluir lista');
    }
  }

  // ========== ITEM SERVICE ==========

  static Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    final response = await http.get(
      Uri.parse('$baseUrl/items/search?q=$query&limit=20'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
    }
    throw Exception('Falha na busca de produtos');
  }

  static Future<List<String>> getCategories() async {
    try {
      print('[GATEWAY] Buscando categorias...');

      final response = await http
          .get(Uri.parse('$baseUrl/items/categories'), headers: _headers)
          .timeout(const Duration(seconds: 10));

      print('[GATEWAY] Categories Status: ${response.statusCode}');
      print('[GATEWAY] Categories Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (data['data'] is List) {
            final categories = List<String>.from(data['data']);
            print('Categorias carregadas: ${categories.length}');
            return categories;
          } else {
            throw Exception('Formato de categorias inválido');
          }
        } else {
          throw Exception('Falha ao carregar categorias: ${data['message']}');
        }
      } else {
        throw Exception('HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      print('Erro ao carregar categorias: $e');
      rethrow;
    }
  }

  // ========== LIST ITEMS OPERATIONS ==========

  static Future<ShoppingList> addItemToList(
    String listId,
    ShoppingItem item,
  ) async {
    try {
      print('[GATEWAY] Adicionando item à lista: $listId');

      final response = await http.post(
        Uri.parse('$baseUrl/lists/$listId/items'),
        headers: _headers,
        body: json.encode({
          'itemId': item.productId,
          'quantity': item.quantity,
          'notes': item.notes,
        }),
      );

      print('[GATEWAY] Add Item Status: ${response.statusCode}');
      print('[GATEWAY] Add Item Response: ${response.body}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('Item adicionado com sucesso!');

          if (data['data'] != null) {
            return ShoppingList.fromMap(data['data'] as Map<String, dynamic>);
          } else {
            throw Exception('Dados da resposta estão vazios');
          }
        } else {
          throw Exception('Add item failed: ${data['message']}');
        }
      } else {
        throw Exception('HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      print('Erro ao adicionar item: $e');
      rethrow;
    }
  }

  static Future<ShoppingList> updateItemInList(
    String listId,
    ShoppingItem item,
  ) async {
    try {
      print('[GATEWAY] Atualizando item na lista: $listId');
      print('Item ID: ${item.id}');
      print('Item quantity: ${item.quantity}');
      print('Item purchased: ${item.purchased}');

      final response = await http.put(
        Uri.parse('$baseUrl/lists/$listId/items/${item.id}'),
        headers: _headers,
        body: json.encode({
          'quantity': item.quantity,
          'purchased': item.purchased,
          'notes': item.notes,
        }),
      );

      print('[GATEWAY] Update Item Status: ${response.statusCode}');
      print('[GATEWAY] Update Item Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('Item atualizado com sucesso!');
          return ShoppingList.fromMap(data['data'] as Map<String, dynamic>);
        } else {
          throw Exception('Update failed: ${data['message']}');
        }
      } else {
        throw Exception('HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      print('Erro ao atualizar item: $e');
      rethrow;
    }
  }

  static Future<ShoppingList> removeItemFromList(
    String listId,
    String itemId,
  ) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/lists/$listId/items/$itemId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return ShoppingList.fromMap(data['data']);
      }
    }
    throw Exception('Falha ao remover item');
  }

  // ========== CHECKOUT ==========

  static Future<void> checkoutList(String listId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/lists/$listId/checkout'),
      headers: _headers,
    );

    if (response.statusCode == 202) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return;
      }
    }
    throw Exception('Falha no checkout');
  }

  // ========== AUTH ==========

  static Future<Map<String, dynamic>> login(
    String identifier,
    String password,
  ) async {
    try {
      final url = '$baseUrl/auth/login';
      print('[GATEWAY] Tentando login em: $url');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'identifier': identifier, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      print('[GATEWAY] Login Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('Login bem-sucedido!');
          return data['data'];
        } else {
          print('Login falhou: ${data['message']}');
          throw Exception(data['message']);
        }
      } else {
        print('HTTP Error: ${response.statusCode}');
        throw Exception('Erro de conexão: ${response.statusCode}');
      }
    } catch (e) {
      print('Login Exception: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> register(
    String email,
    String username,
    String password,
    String firstName,
    String lastName,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'username': username,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
      }),
    );

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return data['data'];
      }
    }
    throw Exception('Registro falhou');
  }
}
