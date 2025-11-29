import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';

class ConnectivityStatus extends StatefulWidget {
  final ConnectivityService connectivityService;
  final SyncService syncService;

  const ConnectivityStatus({
    super.key,
    required this.connectivityService,
    required this.syncService,
  });

  @override
  State<ConnectivityStatus> createState() => _ConnectivityStatusState();
}

class _ConnectivityStatusState extends State<ConnectivityStatus> {
  String _lastSyncStatus = '';

  @override
  void initState() {
    super.initState();
    widget.connectivityService.addListener(_onConnectivityChanged);
    widget.syncService.onSyncProgress = _onSyncProgress;
    widget.syncService.onSyncComplete = _onSyncComplete;
  }

  @override
  void dispose() {
    widget.connectivityService.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  void _onConnectivityChanged() {
    if (widget.connectivityService.isConnected) {
      _triggerSync();
    }
    setState(() {});
  }

  void _onSyncProgress(String message) {
    setState(() {
      _lastSyncStatus = message;
    });
  }

  void _onSyncComplete(bool success) {
    setState(() {
      _lastSyncStatus = success ? 'Sincronização concluída!' : 'Falha na sincronização';
    });
  }

  void _triggerSync() {
    if (!widget.syncService.isSyncing) {
      widget.syncService.syncPendingChanges();
    }
  }

  void _manualSync() {
    if (!widget.syncService.isSyncing && widget.connectivityService.isConnected) {
      widget.syncService.forceSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.connectivityService.isConnected;
    final isSyncing = widget.syncService.isSyncing;
    final isChecking = widget.connectivityService.isChecking;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: isConnected ? 0 : 50,
          color: isConnected ? Colors.green : Colors.orange,
          child: isConnected ? null : Column(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.signal_wifi_off,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'MODO OFFLINE - Trabalhando localmente',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 16),
                    if (isChecking)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (isSyncing || _lastSyncStatus.isNotEmpty)
          Container(
            height: 40,
            color: isSyncing ? Colors.blue : 
                  _lastSyncStatus.contains('✅') ? Colors.green : 
                  _lastSyncStatus.contains('❌') ? Colors.red : Colors.grey,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSyncing)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _lastSyncStatus,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                  ),
                ),
                if (!isSyncing && _lastSyncStatus.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.close, size: 16, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _lastSyncStatus = '';
                      });
                    },
                  ),
              ],
            ),
          ),

        if (!isConnected && !isSyncing)
          Container(
            height: 40,
            color: Colors.orange[700],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sync_problem, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  'Clique para tentar reconectar',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                SizedBox(width: 16),
                TextButton(
                  onPressed: _manualSync,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.orange[900],
                  ),
                  child: Text('Tentar Novamente'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}