import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:istfix_app/core/constants/color_constants.dart';
import 'package:istfix_app/features/main/main_tab_view.dart';

/// Kullanıcının İstanbul il sınırları dışında olması durumunda gösterilen
/// kısıtlayıcı erişim sayfası.
class OutOfIstanbulView extends StatelessWidget {
  const OutOfIstanbulView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.arkaplan,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/icons/ic_warning_circle.svg',
                width: 120,
                height: 120,
                colorFilter: ColorFilter.mode(
                  Colors.red.shade600,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                "Hizmet Alanı Dışındasınız",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.bogazGecesi,
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                "İstFix uygulaması yalnızca İstanbul il sınırları içerisindeki altyapı sorunlarını "
                "raporlamak amacıyla kullanılabilmektedir. Mevcut konumunuz hizmet alanı dışındadır.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.marmara,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),

              // Kullanıcı tekrar denemek istediğinde ana yapıyı baştan başlatırız.
              // Bu sayede MapView yeniden yüklenir ve güncel GPS verisiyle kontrol yapılır.
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const MainTabView()),
                      (route) => false,
                    );
                  },
                  icon: SvgPicture.asset(
                    'assets/icons/ic_gps_fixed.svg',
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.bogazGecesi,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  label: const Text(
                    "Konumumu Tekrar Doğrula",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Uygulamayı tamamen kapatma seçeneği
              TextButton(
                onPressed: () => SystemNavigator.pop(),
                child: const Text(
                  "Uygulamadan Çık",
                  style: TextStyle(
                    color: AppColors.halicAcigi,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
