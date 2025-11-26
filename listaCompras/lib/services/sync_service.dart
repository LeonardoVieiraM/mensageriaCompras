// services/sync_service.dart
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

  // Callback para notificar a UI sobre progresso
  Function(String message)? onSyncProgress;
  Function(bool success)? onSyncComplete;

  SyncService(this._connectivityService);

  Future<bool> syncPendingChanges() async {
    if (_isSyncing) {
      print('⏳ Sincronização já em andamento...');
      return false;
    }

    _isSyncing = true;
    _notifyProgress('Verificando conexão...');

    try {
      // Verificar conectividade
      final isConnected = await _connectivityService.checkConnection();
      if (!isConnected) {
        _notifyProgress('📵 Sem conexão - sincronização adiada');
        return false;
      }

      _notifyProgress('🔄 Iniciando sincronização...');

      // 1. Obter estatísticas para debug
      final stats = await _dbService.getSyncStats();
      print('📊 Estatísticas de sincronização: $stats');

      // 2. Processar fila de operações
      final queueSuccess = await _processSyncQueue();
      
      // 3. Sincronizar dados não sincronizados
      final dataSuccess = await _syncUnsyncedData();

      // 4. Verificar se há conflitos
      await _checkForConflicts();

      final success = queueSuccess && dataSuccess;
      
      if (success) {
        _notifyProgress('✅ Sincronização concluída com sucesso!');
      } else {
        _notifyProgress('⚠️ Sincronização parcialmente concluída');
      }

      onSyncComplete?.call(success);
      return success;

    } catch (e) {
      print('❌ Erro crítico na sincronização: $e');
      _notifyProgress('❌ Erro na sincronização: $e');
      onSyncComplete?.call(false);
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _processSyncQueue() async {
    final queue = await _dbService.getSyncQueue();
    
    if (queue.isEmpty) {
      _notifyProgress('📭 Fila de sincronização vazia');
      return true;
    }

    _notifyProgress('📋 Processando ${queue.length} itens na fila...');

    int processed = 0;
    int failed = 0;

    for (var item in queue) {
      try {
        final data = json.decode(item['data']);
        final recordId = item['recordId'];
        final action = item['action'];
        final retryCount = item['retryCount'] ?? 0;
        
        _notifyProgress('🔄 $action: ${_getEntityName(item['tableName'])}');

        bool success = await _executeSyncAction(action, data, recordId);

        if (success) {
          // Remover da fila após sucesso
          await _dbService.removeFromSyncQueue(item['id']);
          processed++;
          print('✅ $action concluído: $recordId');
        } else {
          // Incrementar contador de tentativas
          await _dbService.updateRetryCount(item['id'], retryCount + 1);
          failed++;
          
          if (retryCount >= 2) { // 3 tentativas no total
            print('❌ Removendo da fila após 3 tentativas: $recordId');
            await _dbService.removeFromSyncQueue(item['id']);
          } else {
            print('⚠️ $action falhou, tentativa ${retryCount + 1}: $recordId');
          }
        }

      } catch (e) {
        print('❌ Erro ao processar item da fila: $e');
        failed++;
        final retryCount = (item['retryCount'] ?? 0) + 1;
        await _dbService.updateRetryCount(item['id'], retryCount);
      }
    }

    _notifyProgress('📊 Fila: $processed processados, $failed falhas');
    return failed == 0;
  }

  Future<bool> _executeSyncAction(String action, Map<String, dynamic> data, String recordId) async {
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
          print('❌ Ação desconhecida: $action');
          return false;
      }
    } catch (e) {
      print('❌ Erro na ação $action: $e');
      return false;
    }
  }

  Future<bool> _syncCreateList(Map<String, dynamic> data) async {
    try {
      final list = ShoppingList.fromMap(data);
      final createdList = await ApiService.createShoppingList(list.name, list.description);
      
      // Atualizar ID local com o ID do servidor se necessário
      if (createdList.id != list.id) {
        // Aqui você pode querer atualizar referências locais
        print('🆔 Lista criada no servidor com ID: ${createdList.id}');
      }
      
      await _dbService.markListAsSynced(list.id);
      return true;
    } catch (e) {
      print('❌ Erro ao sincronizar criação de lista: $e');
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
      // Se a lista não existir no servidor, criar
      if (e.toString().contains('não encontrada') || e.toString().contains('404')) {
        print('🔄 Lista não encontrada no servidor, criando...');
        return await _syncCreateList(data);
      }
      print('❌ Erro ao sincronizar atualização de lista: $e');
      return false;
    }
  }

  Future<bool> _syncDeleteList(Map<String, dynamic> data) async {
    try {
      await ApiService.deleteShoppingList(data['id']);
      return true;
    } catch (e) {
      // Se a lista já não existir no servidor, considerar sucesso
      if (e.toString().contains('não encontrada') || e.toString().contains('404')) {
        print('📭 Lista já não existe no servidor');
        return true;
      }
      print('❌ Erro ao sincronizar exclusão de lista: $e');
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
      print('❌ Erro ao sincronizar criação de item: $e');
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
      // Se o item não existir no servidor, criar
      if (e.toString().contains('não encontrado') || e.toString().contains('404')) {
        print('🔄 Item não encontrado no servidor, criando...');
        return await _syncCreateItem(data);
      }
      print('❌ Erro ao sincronizar atualização de item: $e');
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
      // Se o item já não existir no servidor, considerar sucesso
      if (e.toString().contains('não encontrado') || e.toString().contains('404')) {
        print('📭 Item já não existe no servidor');
        return true;
      }
      print('❌ Erro ao sincronizar exclusão de item: $e');
      return false;
    }
  }

  Future<bool> _syncUnsyncedData() async {
    try {
      _notifyProgress('📦 Sincronizando dados não sincronizados...');

      // Sincronizar listas não sincronizadas
      final unsyncedLists = await _dbService.getUnsyncedLists();
      int listSuccess = 0;
      
      for (var list in unsyncedLists) {
        try {
          await ApiService.updateShoppingList(list);
          await _dbService.markListAsSynced(list.id);
          listSuccess++;
        } catch (e) {
          print('❌ Erro ao sincronizar lista ${list.id}: $e');
        }
      }

      // Sincronizar itens não sincronizados
      final unsyncedItems = await _dbService.getUnsyncedItems();
      int itemSuccess = 0;
      
      for (var item in unsyncedItems) {
        try {
          // Buscar lista do item
          final lists = await _dbService.getLists();
          final list = lists.firstWhere(
            (l) => l.items.any((i) => i.id == item.id),
            orElse: () => lists.isNotEmpty ? lists.first : ShoppingList(name: 'Temp'),
          );

          await ApiService.updateItemInList(list.id, item);
          await _dbService.markItemAsSynced(item.id);
          itemSuccess++;
        } catch (e) {
          print('❌ Erro ao sincronizar item ${item.id}: $e');
        }
      }

      _notifyProgress('📊 Dados: $listSuccess listas, $itemSuccess itens sincronizados');
      return true;

    } catch (e) {
      print('❌ Erro ao sincronizar dados não sincronizados: $e');
      return false;
    }
  }

  Future<void> _checkForConflicts() async {
    // Implementação básica de detecção de conflitos
    // Em uma implementação real, você compararia timestamps
    // entre servidor e local para detectar conflitos
    
    _notifyProgress('🔍 Verificando conflitos...');
    
    try {
      // Buscar dados do servidor para comparação
      final serverLists = await ApiService.getShoppingLists();
      final localLists = await _dbService.getLists();

      int conflicts = 0;
      
      for (var serverList in serverLists) {
        final localList = localLists.firstWhere(
          (l) => l.id == serverList.id,
          orElse: () => ShoppingList(name: ''),
        );

        if (localList.name.isNotEmpty) {
          // Verificar se há diferenças significativas
          final serverUpdated = DateTime.parse(serverList.updatedAt.toString());
          final localUpdated = localList.updatedAt;

          if (serverUpdated.isAfter(localUpdated)) {
            // Servidor tem versão mais recente
            conflicts++;
            await _resolveConflict(serverList, localList, 'server_wins');
          } else if (localUpdated.isAfter(serverUpdated)) {
            // Local tem versão mais recente
            conflicts++;
            await _resolveConflict(localList, serverList, 'local_wins');
          }
        }
      }

      if (conflicts > 0) {
        _notifyProgress('⚠️ $conflicts conflitos resolvidos');
      } else {
        _notifyProgress('✅ Nenhum conflito detectado');
      }

    } catch (e) {
      print('❌ Erro ao verificar conflitos: $e');
    }
  }

  Future<void> _resolveConflict(ShoppingList winningList, ShoppingList losingList, String resolution) async {
    print('🔄 Resolvendo conflito: $resolution');
    
    if (resolution == 'server_wins') {
      // Atualizar local com dados do servidor
      await _dbService.updateList(winningList, isSynced: true);
    } else {
      // Enviar dados locais para servidor
      await ApiService.updateShoppingList(winningList);
      await _dbService.markListAsSynced(winningList.id);
    }
  }

  // ========== MÉTODOS AUXILIARES ==========

  String _getEntityName(String tableName) {
    switch (tableName) {
      case 'shopping_lists': return 'Lista';
      case 'shopping_items': return 'Item';
      default: return tableName;
    }
  }

  void _notifyProgress(String message) {
    print('🔄 [SYNC] $message');
    onSyncProgress?.call(message);
  }

  // ========== MÉTODOS PÚBLICOS PARA UI ==========

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
    _notifyProgress('🔄 Sincronização forçada...');
    await syncPendingChanges();
  }

  Future<void> clearSyncQueue() async {
    final queue = await _dbService.getSyncQueue();
    for (var item in queue) {
      await _dbService.removeFromSyncQueue(item['id']);
    }
    _notifyProgress('🧹 Fila de sincronização limpa');
  }
}