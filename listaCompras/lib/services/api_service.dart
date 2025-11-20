import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/shopping_list.dart';
import '../models/shopping_item.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:3000/api';
  static String? _authToken;

  static void setAuthToken(String token) {
    _authToken = token;
    print('✅ Token definido: ${token.substring(0, 20)}...');
  }

  static Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  // ========== LIST SERVICE ==========

  static Future<List<ShoppingList>> getShoppingLists() async {
    try {
      // ✅ USA A NOVA ROTA /user-lists DO LIST SERVICE DIRETAMENTE
      final url = 'http://localhost:3002/user-lists';
      print('🔄 [LIST-SERVICE] Buscando listas de: $url');

      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 10));

      print('📡 [LIST-SERVICE] Status: ${response.statusCode}');
      print('📡 [LIST-SERVICE] Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data is Map && data['success'] == true) {
          if (data['data'] is List) {
            final listsData = data['data'] as List<dynamic>;
            final lists = listsData.map((listData) {
              return ShoppingList.fromMap(listData as Map<String, dynamic>);
            }).toList();
            print('✅ Listas carregadas: ${lists.length}');
            return lists;
          } else {
            print('⚠️ Data não é uma lista');
            return [];
          }
        } else {
          print('❌ Success é false: ${data['message']}');
          return [];
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Erro ao buscar listas: $e');
      return [];
    }
  }

  static Future<ShoppingList> createShoppingList(
    String name,
    String description,
  ) async {
    try {
      final url = '$baseUrl/lists/';
      print('🔄 [GATEWAY] Criando lista em: $url');

      final response = await http
          .post(
            Uri.parse(url),
            headers: _headers,
            body: json.encode({'name': name, 'description': description}),
          )
          .timeout(const Duration(seconds: 10));

      print('📡 [GATEWAY] Create Status: ${response.statusCode}');
      print('📡 [GATEWAY] Create Response: ${response.body}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('✅ Lista criada com sucesso!');
          return ShoppingList.fromMap(data['data'] as Map<String, dynamic>);
        } else {
          throw Exception('Create failed: ${data['message']}');
        }
      } else {
        throw Exception('HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erro ao criar lista: $e');
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

  static Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await http.get(Uri.parse('$baseUrl/items/categories'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
    }
    throw Exception('Falha ao carregar categorias');
  }

  // ========== LIST ITEMS OPERATIONS ==========

  static Future<ShoppingList> addItemToList(
    String listId,
    ShoppingItem item,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/lists/$listId/items'),
      headers: _headers,
      body: json.encode({
        'itemId': item.productId,
        'quantity': item.quantity,
        'notes': item.notes,
      }),
    );

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return ShoppingList.fromMap(data['data']);
      }
    }
    throw Exception('Falha ao adicionar item à lista');
  }

  static Future<ShoppingList> updateItemInList(
    String listId,
    ShoppingItem item,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/lists/$listId/items/${item.id}'),
      headers: _headers,
      body: json.encode({
        'quantity': item.quantity,
        'purchased': item.purchased,
        'notes': item.notes,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return ShoppingList.fromMap(data['data']);
      }
    }
    throw Exception('Falha ao atualizar item');
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
      print('🔐 [GATEWAY] Tentando login em: $url');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'identifier': identifier, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      print('📡 [GATEWAY] Login Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('✅ Login bem-sucedido!');
          return data['data'];
        } else {
          print('❌ Login falhou: ${data['message']}');
          throw Exception(data['message']);
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
        throw Exception('Erro de conexão: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Login Exception: $e');
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
