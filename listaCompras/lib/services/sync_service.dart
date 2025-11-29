import 'dart:convert';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/connectivity_service.dart';
import '../models/shopping_list.dart';
import '../models/shopping_item.dart';

class SyncService {
  final DatabaseService _dbService = DatabaseService();
  final ConnectivityService _connectivityService;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  Function(String message)? onSyncProgress;
  Function(bool success)? onSyncComplete;

  SyncService(this._connectivityService);

  Future<bool> syncPendingChanges() async {
    if (_isSyncing) {
      print('Sincronização já em andamento...');
      return false;
    }

    _isSyncing = true;
    _notifyProgress('Verificando conexão...');

    try {
      final isConnected = await _connectivityService.checkConnection();
      if (!isConnected) {
        _notifyProgress('Sem conexão - sincronização adiada');
        return false;
      }

      _notifyProgress('Iniciando sincronização...');

      await _dbService.getSyncStats();

      final queueSuccess = await _processSyncQueue();

      final dataSuccess = await _syncUnsyncedData();

      await _checkForConflicts();

      final success = queueSuccess && dataSuccess;

      if (success) {
        _notifyProgress('Sincronização concluída com sucesso!');
      } else {
        _notifyProgress('Sincronização parcialmente concluída');
      }

      onSyncComplete?.call(success);
      return success;
    } catch (e) {
      _notifyProgress('Erro na sincronização: $e');
      onSyncComplete?.call(false);
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _processSyncQueue() async {
    final queue = await _dbService.getSyncQueue();

    if (queue.isEmpty) {
      _notifyProgress('Fila de sincronização vazia');
      return true;
    }

    _notifyProgress('Processando ${queue.length} itens na fila...');

    int processed = 0;
    int failed = 0;

    for (var item in queue) {
      try {
        final data = json.decode(item['data']);
        final recordId = item['recordId'];
        final action = item['action'];
        final retryCount = item['retryCount'] ?? 0;

        _notifyProgress('$action: ${_getEntityName(item['tableName'])}');

        bool success = await _executeSyncAction(action, data, recordId);

        if (success) {
          await _dbService.removeFromSyncQueue(item['id']);
          processed++;
        } else {
          await _dbService.updateRetryCount(item['id'], retryCount + 1);
          failed++;

          if (retryCount >= 2) {
            await _dbService.removeFromSyncQueue(item['id']);
          }
        }
      } catch (e) {
        failed++;
        final retryCount = (item['retryCount'] ?? 0) + 1;
        await _dbService.updateRetryCount(item['id'], retryCount);
      }
    }

    _notifyProgress('Fila: $processed processados, $failed falhas');
    return failed == 0;
  }

  Future<bool> _executeSyncAction(
    String action,
    Map<String, dynamic> data,
    String recordId,
  ) async {
    try {
      switch (action) {
        case 'CREATE_LIST':
          return await _syncCreateList(data);
        case 'UPDATE_LIST':
          return await _syncUpdateList(data);
        case 'DELETE_LIST':
          return await _syncDeleteList(data);
        case 'CREATE_ITEM':
          return await _syncCreateItem(data);
        case 'UPDATE_ITEM':
          return await _syncUpdateItem(data);
        case 'DELETE_ITEM':
          return await _syncDeleteItem(data);
        default:
          return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> _syncCreateList(Map<String, dynamic> data) async {
    try {
      final list = ShoppingList.fromMap(data);
      await ApiService.createShoppingList(list.name, list.description);

      await _dbService.markListAsSynced(list.id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _syncUpdateList(Map<String, dynamic> data) async {
    try {
      final list = ShoppingList.fromMap(data);
      await ApiService.updateShoppingList(list);
      await _dbService.markListAsSynced(list.id);
      return true;
    } catch (e) {
      if (e.toString().contains('não encontrada') ||
          e.toString().contains('404')) {
        return await _syncCreateList(data);
      }
      return false;
    }
  }

  Future<bool> _syncDeleteList(Map<String, dynamic> data) async {
    try {
      await ApiService.deleteShoppingList(data['id']);
      return true;
    } catch (e) {
      if (e.toString().contains('não encontrada') ||
          e.toString().contains('404') ||
          e.toString().contains('Falha ao excluir lista')) {
        return true;
      }
      return false;
    }
  }

  Future<bool> _syncCreateItem(Map<String, dynamic> data) async {
    try {
      final item = ShoppingItem.fromMap(data);
      final listId = data['listId'];

      await ApiService.addItemToList(listId, item);
      await _dbService.markItemAsSynced(item.id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _syncUpdateItem(Map<String, dynamic> data) async {
    try {
      final item = ShoppingItem.fromMap(data);
      final listId = data['listId'];

      await ApiService.updateItemInList(listId, item);
      await _dbService.markItemAsSynced(item.id);
      return true;
    } catch (e) {
      if (e.toString().contains('não encontrado') ||
          e.toString().contains('404')) {
        return await _syncCreateItem(data);
      }
      return false;
    }
  }

  Future<bool> _syncDeleteItem(Map<String, dynamic> data) async {
    try {
      final listId = data['listId'];
      final itemId = data['itemId'];

      await ApiService.removeItemFromList(listId, itemId);
      return true;
    } catch (e) {
      if (e.toString().contains('não encontrado') ||
          e.toString().contains('404')) {
        return true;
      }
      return false;
    }
  }

  Future<bool> _syncUnsyncedData() async {
    try {
      _notifyProgress('Sincronizando dados não sincronizados...');

      final unsyncedLists = await _dbService.getUnsyncedLists();
      int listSuccess = 0;

      for (var list in unsyncedLists) {
        await ApiService.updateShoppingList(list);
        await _dbService.markListAsSynced(list.id);
        listSuccess++;
      }

      final unsyncedItems = await _dbService.getUnsyncedItems();
      int itemSuccess = 0;

      for (var item in unsyncedItems) {
        final lists = await _dbService.getLists();
        final list = lists.firstWhere(
          (l) => l.items.any((i) => i.id == item.id),
          orElse: () =>
              lists.isNotEmpty ? lists.first : ShoppingList(name: 'Temp'),
        );

        await ApiService.updateItemInList(list.id, item);
        await _dbService.markItemAsSynced(item.id);
        itemSuccess++;
      }

      _notifyProgress(
        'Dados: $listSuccess listas, $itemSuccess itens sincronizados',
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _checkForConflicts() async {
    _notifyProgress('Verificando conflitos...');

    final serverLists = await ApiService.getShoppingLists();
    final localLists = await _dbService.getLists();

    int conflicts = 0;

    for (var serverList in serverLists) {
      final localList = localLists.firstWhere(
        (l) => l.id == serverList.id,
        orElse: () => ShoppingList(name: ''),
      );

      if (localList.name.isNotEmpty) {
        final serverUpdated = DateTime.parse(serverList.updatedAt.toString());
        final localUpdated = localList.updatedAt;

        if (serverUpdated.isAfter(localUpdated)) {
          conflicts++;
          await _resolveConflict(serverList, localList, 'server_wins');
        } else if (localUpdated.isAfter(serverUpdated)) {
          conflicts++;
          await _resolveConflict(localList, serverList, 'local_wins');
        }
      }
    }

    if (conflicts > 0) {
      _notifyProgress('$conflicts conflitos resolvidos');
    } else {
      _notifyProgress('Nenhum conflito detectado');
    }
  }

  Future<void> _resolveConflict(
    ShoppingList winningList,
    ShoppingList losingList,
    String resolution,
  ) async {
    if (resolution == 'server_wins') {
      await _dbService.updateList(winningList, isSynced: true);
    } else {
      await ApiService.updateShoppingList(winningList);
      await _dbService.markListAsSynced(winningList.id);
    }
  }

  String _getEntityName(String tableName) {
    switch (tableName) {
      case 'shopping_lists':
        return 'Lista';
      case 'shopping_items':
        return 'Item';
      default:
        return tableName;
    }
  }

  void _notifyProgress(String message) {
    onSyncProgress?.call(message);
  }

  Future<Map<String, dynamic>> getSyncStatus() async {
    final stats = await _dbService.getSyncStats();
    final isConnected = await _connectivityService.checkConnection();

    return {
      'isSyncing': _isSyncing,
      'isConnected': isConnected,
      'unsyncedLists': stats['unsyncedLists'],
      'unsyncedItems': stats['unsyncedItems'],
      'queueItems': stats['queueItems'],
      'totalLists': stats['totalLists'],
      'totalItems': stats['totalItems'],
    };
  }

  Future<void> forceSync() async {
    _notifyProgress('Sincronização forçada...');
    await syncPendingChanges();
  }

  Future<void> clearSyncQueue() async {
    final queue = await _dbService.getSyncQueue();
    for (var item in queue) {
      await _dbService.removeFromSyncQueue(item['id']);
    }
    _notifyProgress('Fila de sincronização limpa');
  }
}
