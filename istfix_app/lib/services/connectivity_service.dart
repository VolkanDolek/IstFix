import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';

/// Cihazın donanımsal erişilebilirlik durumlarını (İnternet ve GPS)
/// merkezi olarak takip eden servis sınıfı.
class ConnectivityService {
  final _connectivity = Connectivity();

  /// İnternet bağlantı değişikliklerini yayınlayan akış.
  Stream<List<ConnectivityResult>> get connectivityStream =>
      _connectivity.onConnectivityChanged;

  /// GPS servis durum değişikliklerini (Açık/Kapalı) yayınlayan akış.
  Stream<ServiceStatus> get gpsServiceStream =>
      Geolocator.getServiceStatusStream();

  /// Anlık internet bağlantı kontrolü.
  Future<bool> hasInternet() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }

  /// Anlık GPS (Konum Servisi) kontrolü.
  Future<bool> hasGps() async {
    return await Geolocator.isLocationServiceEnabled();
  }
}
