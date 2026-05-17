import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:istfix_app/features/shared/no_connection_view.dart';
import 'package:istfix_app/features/shared/no_gps_view.dart';
import 'package:istfix_app/services/connectivity_service.dart';

/// Uygulama genelinde donanım durumunu izleyen ve kesintisiz navigasyon akışı
/// sağlamak için hata ekranlarını overlay (perde) olarak yöneten global bileşen.
class ConnectivityWrapper extends StatefulWidget {
  final Widget child;

  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  // Donanım durum bayrakları
  bool _isConnected = true;
  bool _isGpsEnabled = true;

  // Servis ve Abonelik yönetimi
  final ConnectivityService _connectivityService = ConnectivityService();
  StreamSubscription? _connectivitySub;
  StreamSubscription? _gpsSub;

  @override
  void initState() {
    super.initState();
    _initializeHardwareMonitors();
  }

  /// Donanım servislerini başlatır ve anlık değişimleri dinler.
  Future<void> _initializeHardwareMonitors() async {
    final connected = await _connectivityService.hasInternet();
    final gpsEnabled = await _connectivityService.hasGps();

    if (mounted) {
      setState(() {
        _isConnected = connected;
        _isGpsEnabled = gpsEnabled;
      });
    }

    // Ağ bağlantı değişimlerini dinler
    _connectivitySub = _connectivityService.connectivityStream.listen((
      results,
    ) {
      final connected = results.any((r) => r != ConnectivityResult.none);
      if (mounted) {
        setState(() => _isConnected = connected);
      }
    });

    // GPS servis durum değişimlerini dinler
    _gpsSub = _connectivityService.gpsServiceStream.listen((status) {
      if (mounted) {
        setState(() => _isGpsEnabled = status == ServiceStatus.enabled);
      }
    });
  }

  @override
  void dispose() {
    // Bellek sızıntılarını önlemek için abonelikler sonlandırılır.
    _connectivitySub?.cancel();
    _gpsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    /// [Stack] yapısı sayesinde 'child' (Navigator) her zaman ağaçta tutulur.
    /// Bağlantı sağlandığında hata perdeleri kalkar ve kullanıcı kaldığı sayfadan devam eder.
    return Material(
      child: Stack(
        children: [
          // Ana Uygulama Katmanı (Harita, Profil, vb.)
          widget.child,

          // İnternet kesintisi durumunda uygulamanın üzerine inen hata perdesi.
          if (!_isConnected)
            NoConnectionView(onRetry: _initializeHardwareMonitors),

          // İnternet var ancak GPS kapalıysa gösterilen uyarı perdesi.
          if (_isConnected && !_isGpsEnabled) const NoGpsView(),
        ],
      ),
    );
  }
}
