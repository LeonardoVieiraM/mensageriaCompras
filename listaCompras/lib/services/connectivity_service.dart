import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

import 'package:http/http.dart' as http;

class ConnectivityService with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  bool _isConnected = true;
  bool _isChecking = false;
  Timer? _connectionTimer;

  bool get isConnected => _isConnected;
  bool get isChecking => _isChecking;

  ConnectivityService() {
    _init();
  }

  Future<void> _init() async {
    await _checkConnection();
    
    _connectionTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
      await _checkConnection();
    });

    _connectivity.onConnectivityChanged.listen((result) async {
      await _checkConnection();
    });
  }

  Future<bool> _checkConnection() async {
    if (_isChecking) return _isConnected;
    
    _isChecking = true;
    notifyListeners();

    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      bool connectivityStatus = connectivityResult != ConnectivityResult.none;
      
      bool realConnection = await _testRealConnection();
      
      final newStatus = connectivityStatus && realConnection;
      
      if (newStatus != _isConnected) {
        print('Status de conexão mudou: ${_isConnected ? "Online" : "Offline"} -> ${newStatus ? "Online" : "Offline"}');
        _isConnected = newStatus;
        notifyListeners();
        
        if (_isConnected) {
          _onConnectionRestored();
        } else {
          _onConnectionLost();
        }
      }
      
      return _isConnected;
    } catch (e) {
      print('Erro ao verificar conectividade: $e');
      return false;
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  Future<bool> _testRealConnection() async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:3000/health'),
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: 3));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void _onConnectionRestored() {
    print('Conexão restaurada! Disparando sincronização...');
    Future.delayed(Duration(seconds: 2), () {
      notifyListeners();
    });
  }

  void _onConnectionLost() {
    print('Conexão perdida! Modo offline ativado.');
  }

  Future<bool> checkConnection() async {
    return await _checkConnection();
  }

  void simulateOffline() {
    if (_isConnected) {
      _isConnected = false;
      print('Simulando modo offline');
      notifyListeners();
      _onConnectionLost();
    }
  }

  void simulateOnline() {
    if (!_isConnected) {
      _isConnected = true;
      print('Simulando modo online');
      notifyListeners();
      _onConnectionRestored();
    }
  }

  @override
  void dispose() {
    _connectionTimer?.cancel();
    super.dispose();
  }
}