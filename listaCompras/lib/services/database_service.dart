import 'dart:convert';
import 'dart:async';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/shopping_list.dart';
import '../models/shopping_item.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'shopping_list_offline.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
      onConfigure: (db) async {
        // Ativar chaves estrangeiras
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Tabela de listas
    await db.execute('''
      CREATE TABLE shopping_lists(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        estimatedTotal REAL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isSynced INTEGER DEFAULT 1,
        serverId TEXT,
        lastModified INTEGER DEFAULT 0
      )
    ''');

    // Tabela de itens
    await db.execute('''
      CREATE TABLE shopping_items(
        id TEXT PRIMARY KEY,
        listId TEXT NOT NULL,
        productId TEXT NOT NULL,
        name TEXT NOT NULL,
        category TEXT,
        brand TEXT,
        price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        unit TEXT NOT NULL,
        purchased INTEGER DEFAULT 0,
        notes TEXT,
        addedAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isSynced INTEGER DEFAULT 1,
        serverId TEXT,
        lastModified INTEGER DEFAULT 0,
        FOREIGN KEY (listId) REFERENCES shopping_lists (id) ON DELETE CASCADE
      )
    ''');

    // Tabela de fila de sincronização
    await db.execute('''
      CREATE TABLE sync_queue(
        id TEXT PRIMARY KEY,
        action TEXT NOT NULL,
        tableName TEXT NOT NULL,
        recordId TEXT NOT NULL,
        data TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        retryCount INTEGER DEFAULT 0,
        lastAttempt TEXT,
        lastModified INTEGER DEFAULT 0
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_lists_synced ON shopping_lists(isSynced)',
    );
    await db.execute(
      'CREATE INDEX idx_items_synced ON shopping_items(isSynced)',
    );
    await db.execute('CREATE INDEX idx_items_listId ON shopping_items(listId)');
    await db.execute(
      'CREATE INDEX idx_sync_queue_timestamp ON sync_queue(timestamp)',
    );
  }

  int _getCurrentTimestamp() {
    return DateTime.now().millisecondsSinceEpoch;
  }

  Future<String> insertList(ShoppingList list, {bool isSynced = true}) async {
    final db = await database;
    final timestamp = _getCurrentTimestamp();

    await db.insert('shopping_lists', {
      'id': list.id,
      'name': list.name,
      'description': list.description,
      'status': list.status,
      'estimatedTotal': list.estimatedTotal,
      'createdAt': list.createdAt.toIso8601String(),
      'updatedAt': list.updatedAt.toIso8601String(),
      'isSynced': isSynced ? 1 : 0,
      'lastModified': timestamp,
    });

    return list.id;
  }

  Future<List<ShoppingList>> getLists() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'shopping_lists',
      orderBy: 'updatedAt DESC',
    );

    List<ShoppingList> lists = [];
    for (var map in maps) {
      final items = await getItemsByListId(map['id']);
      lists.add(
        ShoppingList.fromMap({
          ...map,
          'items': items.map((item) => item.toMap()).toList(),
        }),
      );
    }
    return lists;
  }

  Future<int> updateList(ShoppingList list, {bool isSynced = true}) async {
    final db = await database;
    final timestamp = _getCurrentTimestamp();

    return await db.update(
      'shopping_lists',
      {
        'name': list.name,
        'description': list.description,
        'status': list.status,
        'estimatedTotal': list.estimatedTotal,
        'updatedAt': list.updatedAt.toIso8601String(),
        'isSynced': isSynced ? 1 : 0,
        'lastModified': timestamp,
      },
      where: 'id = ?',
      whereArgs: [list.id],
    );
  }

  Future<int> deleteList(String id) async {
    final db = await database;

    try {
      await db.delete('shopping_items', where: 'listId = ?', whereArgs: [id]);

      final result = await db.delete(
        'shopping_lists',
        where: 'id = ?',
        whereArgs: [id],
      );

      print('Lista $id excluída do banco local');
      return result;
    } catch (e) {
      print('Erro ao excluir lista $id: $e');
      rethrow;
    }
  }

  Future<String> insertItem(
    ShoppingItem item, {
    String? listId,
    bool isSynced = true,
  }) async {
    final db = await database;
    final timestamp = _getCurrentTimestamp();

    await db.insert('shopping_items', {
      'id': item.id,
      'listId': listId ?? item.productId, // fallback
      'productId': item.productId,
      'name': item.name,
      'category': item.category,
      'brand': item.brand,
      'price': item.price,
      'quantity': item.quantity,
      'unit': item.unit,
      'purchased': item.purchased ? 1 : 0,
      'notes': item.notes,
      'addedAt': item.addedAt.toIso8601String(),
      'updatedAt': item.updatedAt.toIso8601String(),
      'isSynced': isSynced ? 1 : 0,
      'lastModified': timestamp,
    });

    return item.id;
  }

  Future<List<ShoppingItem>> getItemsByListId(String listId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'shopping_items',
      where: 'listId = ?',
      whereArgs: [listId],
      orderBy: 'purchased ASC, name ASC',
    );
    return maps.map((map) => ShoppingItem.fromMap(map)).toList();
  }

  Future<int> updateItem(ShoppingItem item, {bool isSynced = true}) async {
    final db = await database;
    final timestamp = _getCurrentTimestamp();

    return await db.update(
      'shopping_items',
      {
        'name': item.name,
        'category': item.category,
        'brand': item.brand,
        'price': item.price,
        'quantity': item.quantity,
        'unit': item.unit,
        'purchased': item.purchased ? 1 : 0,
        'notes': item.notes,
        'updatedAt': item.updatedAt.toIso8601String(),
        'isSynced': isSynced ? 1 : 0,
        'lastModified': timestamp,
      },
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteItem(String id) async {
    final db = await database;
    return await db.delete('shopping_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<String> addToSyncQueue({
    required String action,
    required String tableName,
    required String recordId,
    required Map<String, dynamic> data,
  }) async {
    final db = await database;
    final queueId = '${_getCurrentTimestamp()}_$recordId';
    final timestamp = _getCurrentTimestamp();

    await db.insert('sync_queue', {
      'id': queueId,
      'action': action,
      'tableName': tableName,
      'recordId': recordId,
      'data': json.encode(data),
      'timestamp': DateTime.now().toIso8601String(),
      'retryCount': 0,
      'lastModified': timestamp,
    });

    return queueId;
  }

  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final db = await database;
    return await db.query('sync_queue', orderBy: 'timestamp ASC');
  }

  Future<int> removeFromSyncQueue(String id) async {
    final db = await database;
    return await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateRetryCount(String id, int retryCount) async {
    final db = await database;
    return await db.update(
      'sync_queue',
      {
        'retryCount': retryCount,
        'lastAttempt': DateTime.now().toIso8601String(),
        'lastModified': _getCurrentTimestamp(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markListAsSynced(String id) async {
    final db = await database;
    await db.update(
      'shopping_lists',
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markItemAsSynced(String id) async {
    final db = await database;
    await db.update(
      'shopping_items',
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<ShoppingList>> getUnsyncedLists() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'shopping_lists',
      where: 'isSynced = ?',
      whereArgs: [0],
    );

    List<ShoppingList> lists = [];
    for (var map in maps) {
      final items = await getItemsByListId(map['id']);
      lists.add(
        ShoppingList.fromMap({
          ...map,
          'items': items.map((item) => item.toMap()).toList(),
        }),
      );
    }
    return lists;
  }

  Future<List<ShoppingItem>> getUnsyncedItems() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'shopping_items',
      where: 'isSynced = ?',
      whereArgs: [0],
    );
    return maps.map((map) => ShoppingItem.fromMap(map)).toList();
  }

  Future<Map<String, dynamic>> getSyncStats() async {
    final db = await database;

    final unsyncedListsCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM shopping_lists WHERE isSynced = 0',
          ),
        ) ??
        0;

    final unsyncedItemsCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM shopping_items WHERE isSynced = 0',
          ),
        ) ??
        0;

    final queueCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM sync_queue'),
        ) ??
        0;

    return {
      'unsyncedLists': unsyncedListsCount,
      'unsyncedItems': unsyncedItemsCount,
      'queueItems': queueCount,
      'totalLists':
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM shopping_lists'),
          ) ??
          0,
      'totalItems':
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM shopping_items'),
          ) ??
          0,
    };
  }

  Future<Map<String, dynamic>> getSyncStatusForList(String listId) async {
    final db = await database;
    final result = await db.query(
      'shopping_lists',
      columns: ['isSynced'],
      where: 'id = ?',
      whereArgs: [listId],
    );

    return {
      'isSynced': result.isNotEmpty ? result.first['isSynced'] == 1 : true,
    };
  }

  Future<Map<String, dynamic>> getSyncStatusForItem(String itemId) async {
    final db = await database;
    final result = await db.query(
      'shopping_items',
      columns: ['isSynced'],
      where: 'id = ?',
      whereArgs: [itemId],
    );

    return {
      'isSynced': result.isNotEmpty ? result.first['isSynced'] == 1 : true,
    };
  }
}
