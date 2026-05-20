import 'dart:async'; // GÜNCELLEME: Zamanlayıcı (Timer) için gerekli
import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:istfix_app/core/constants/color_constants.dart';
import 'package:geolocator/geolocator.dart'; // GÜNCELLEME: Konum takibi için gerekli
import 'package:istfix_app/features/map/out_of_istanbul_view.dart'; // GÜNCELLEME: Sınır dışı ekranı yönlendirmesi için gerekli

import 'package:istfix_app/features/map/map_view.dart';
import 'package:istfix_app/features/profile/profile_view.dart';
import 'package:istfix_app/features/camera/camera_view.dart';

/// İstFix uygulamasının ana navigasyon yapısını ve sekme yönetimini sağlayan kök görünüm.
/// Alt barın arkasından kamera görüntüsünün sızması için 'extendBody' mimarisi kullanılmıştır.
class MainTabView extends StatefulWidget {
  const MainTabView({super.key});

  @override
  State<MainTabView> createState() => _MainTabViewState();
}

// GÜNCELLEME: WidgetsBindingObserver mixin'i eklenerek uygulamanın ön plan/arka plan geçişleri dinlemeye alındı
class _MainTabViewState extends State<MainTabView> with WidgetsBindingObserver {
  // Mevcut aktif sekme indeksi
  int _page = 0;

  // Kamera fonksiyonlarına (fotoğraf çekme) dışarıdan erişmek için kullanılan anahtar
  final GlobalKey<CameraViewState> _cameraKey = GlobalKey<CameraViewState>();

  // Alt barın animasyonlarını kontrol etmek için kullanılan anahtar
  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();

  // GÜNCELLEME: İlk giriş doğrulaması, kilit ekranı bayrağı ve periyodik kontrol zamanlayıcısı
  bool _isCheckingLocation = true;
  Timer? _locationHeartbeatTimer;

  @override
  void initState() {
    super.initState();
    // GÜNCELLEME: Yaşam döngüsü gözlemcisi sisteme kaydedildi ve kısıtlama döngüleri tetiklendi
    WidgetsBinding.instance.addObserver(this);
    _verifyIstanbulAccess();
    _startStrictLocationHeartbeat();
  }

  @override
  void dispose() {
    // GÜNCELLEME: Bellek sızıntılarını önlemek için gözlemci ve zamanlayıcı kapatıldı
    WidgetsBinding.instance.removeObserver(this);
    _locationHeartbeatTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // GÜNCELLEME: Uygulama arka plandan ön plana döndüğünde arayüzü dondurmadan arka planda sessizce konumu sorgular
    if (state == AppLifecycleState.resumed) {
      _silentLocationCheck();
    }
  }

  // GÜNCELLEME: Kullanıcı deneyimini kesintiye uğratmadan hileli konum değişikliklerini yakalayan metot
  Future<void> _silentLocationCheck() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _forceLogoutToWarning();
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      bool isIstanbul =
          (position.latitude >= 40.70 &&
          position.latitude <= 41.65 &&
          position.longitude >= 27.90 &&
          position.longitude <= 29.95);

      if (!isIstanbul) {
        _forceLogoutToWarning();
      }
    } catch (e) {
      debugPrint("Sessiz konum doğrulama hatası: $e");
    }
  }

  // GÜNCELLEME: Uygulamanın ilk açılış anında çalışan tam ekran kilit kontrolü
  Future<void> _verifyIstanbulAccess() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isCheckingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _checkBoundary(position);
    } catch (e) {
      if (mounted) setState(() => _isCheckingLocation = false);
    }
  }

  // GÜNCELLEME: Her 3 saniyede bir koordinat durumunu sorgulayan canlı koruma kalkanı
  void _startStrictLocationHeartbeat() {
    _locationHeartbeatTimer = Timer.periodic(const Duration(seconds: 3), (
      timer,
    ) async {
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          _forceLogoutToWarning();
          return;
        }

        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        _checkBoundary(position);
      } catch (e) {
        debugPrint("Canlı konum takibi hatası: $e");
      }
    });
  }

  // GÜNCELLEME: Çekilen koordinatın İstanbul sınır kutusu (Bounding Box) içinde olup olmadığını denetler
  void _checkBoundary(Position position) {
    bool isIstanbul =
        (position.latitude >= 40.70 &&
        position.latitude <= 41.65 &&
        position.longitude >= 27.90 &&
        position.longitude <= 29.95);

    if (!isIstanbul) {
      _forceLogoutToWarning();
    } else {
      if (mounted && _isCheckingLocation) {
        setState(() => _isCheckingLocation = false);
      }
    }
  }

  // GÜNCELLEME: İhlal durumunda zamanlayıcıyı kapatıp kullanıcıyı sınır dışı uyarı ekranına fırlatır
  void _forceLogoutToWarning() {
    if (mounted) {
      _locationHeartbeatTimer?.cancel();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OutOfIstanbulView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // GÜNCELLEME: Konum teyit edilene kadar alt bar dahil tüm ekranı kapatan yükleme bariyeri
    if (_isCheckingLocation) {
      return Scaffold(
        backgroundColor: AppColors.arkaplan,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.bogazGecesi),
              const SizedBox(height: 24),
              Text(
                "İstanbul hizmet alanı kontrol ediliyor...",
                style: TextStyle(
                  color: AppColors.bogazGecesi.withOpacity(0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      // Body'nin alt navigasyon çubuğunun arkasına geçmesini sağlayarak tam ekran vizör etkisi yaratır.
      extendBody: true,
      backgroundColor: AppColors.arkaplan,

      // IndexedStack kullanarak sekmeler arası geçişte sayfa durumlarını (Örn: Harita konumu) korur.
      body: IndexedStack(
        index: _page,
        children: [
          const MapView(),
          CameraView(key: _cameraKey), // Kamera sekmesi
          const ProfileView(),
        ],
      ),

      bottomNavigationBar: CurvedNavigationBar(
        key: _bottomNavigationKey,
        index: _page,
        height: 75.0,
        color: AppColors.bogazGecesi,
        buttonBackgroundColor: const Color(0xFFC8973A),
        // Arka plan şeffaf bırakılarak kamera görüntüsünün barın arkasından görünmesi sağlanır.
        backgroundColor: Colors.transparent,
        animationCurve: Curves.easeInOutCubic,
        animationDuration: const Duration(milliseconds: 300),
        items: <Widget>[
          _buildNavIcon(
            'assets/icons/ic_map.svg',
            'assets/icons/ic_map_filled.svg',
            0,
          ),
          _buildNavIcon(
            'assets/icons/ic_camera.svg',
            'assets/icons/ic_camera_filled.svg',
            1,
          ),
          _buildNavIcon(
            'assets/icons/ic_user.svg',
            'assets/icons/ic_user_filled.svg',
            2,
          ),
        ],
        onTap: (index) {
          if (index == 1 && _page == 1) {
            // Kullanıcı zaten kamera sekmesindeyken ortadaki butona basarsa deklanşörü tetikler.
            _cameraKey.currentState?.takePicture();
          } else {
            setState(() {
              _page = index;
            });
          }
        },
      ),
    );
  }

  /// Aktif sekme durumuna göre ikonları dinamik olarak renklendiren yardımcı metod.
  Widget _buildNavIcon(String normalPath, String filledPath, int index) {
    final bool isSelected = _page == index;
    return SvgPicture.asset(
      isSelected ? filledPath : normalPath,
      width: 32,
      height: 32,
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
    );
  }
}
