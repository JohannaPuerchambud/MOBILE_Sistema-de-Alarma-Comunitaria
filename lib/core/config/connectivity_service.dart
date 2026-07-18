import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkUnavailableException implements Exception {
  final String message;

  const NetworkUnavailableException([
    this.message =
        'No tienes conexión a internet. Revisa tu conexión e inténtalo nuevamente.',
  ]);

  @override
  String toString() => message;
}

class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();

  Stream<bool> get connectionChanges =>
      _connectivity.onConnectivityChanged.map(_hasNetworkRoute).distinct();

  Future<bool> hasNetworkRoute() async {
    final results = await _connectivity.checkConnectivity();
    return _hasNetworkRoute(results);
  }

  Future<void> ensureConnected() async {
    if (!await hasNetworkRoute()) {
      throw const NetworkUnavailableException();
    }
  }

  bool _hasNetworkRoute(List<ConnectivityResult> results) =>
      results.isNotEmpty && !results.contains(ConnectivityResult.none);

  static String friendlyMessage(
    Object error, {
    String fallback = 'No se pudo completar la operación.',
  }) {
    if (error is NetworkUnavailableException) return error.message;

    final detail = error.toString().toLowerCase();
    if (detail.contains('failed host lookup') ||
        detail.contains('socketexception') ||
        detail.contains('connection refused') ||
        detail.contains('network is unreachable') ||
        detail.contains('clientexception')) {
      return 'No hay conexión con el servidor. Revisa tu internet e inténtalo nuevamente.';
    }
    if (detail.contains('timeout')) {
      return 'El servidor está tardando en responder. Puede estar iniciando; inténtalo nuevamente en unos segundos.';
    }
    return fallback;
  }
}
