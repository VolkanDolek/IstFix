import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final _connectivity = Connectivity();

  // Bağlantı durumunu sürekli dinleyen akış (stream)
  Stream<List<ConnectivityResult>> get connectivityStream =>
      _connectivity.onConnectivityChanged;

  // Anlık kontrol (Kritik aksiyonlar öncesi kontrol için)
  Future<bool> hasConnection() async {
    final result = await _connectivity.checkConnectivity();
    // Eğer listede 'none' yoksa bağlantı var demektir
    return !result.contains(ConnectivityResult.none);
  }
}
