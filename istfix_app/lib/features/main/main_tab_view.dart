import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:istfix_app/core/constants/color_constants.dart';

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

class _MainTabViewState extends State<MainTabView> {
  // Mevcut aktif sekme indeksi
  int _page = 0;

  // Kamera fonksiyonlarına (fotoğraf çekme) dışarıdan erişmek için kullanılan anahtar
  final GlobalKey<CameraViewState> _cameraKey = GlobalKey<CameraViewState>();

  // Alt barın animasyonlarını kontrol etmek için kullanılan anahtar
  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
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
