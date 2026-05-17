import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:istfix_app/core/constants/color_constants.dart';

/// Sistem genelinde internet bağlantısı koptuğunda uygulamanın üzerine inen
/// ve kullanıcının hatalı işlem yapmasını engelleyen tam sayfa (Overlay) geri bildirim ekranı.
///
/// [StatelessWidget] olarak tasarlanmıştır; donanım durumunu kendi içinde dinlemez,
/// durumu ve tetikleyicileri ([onRetry]) üst sarmalayıcıdan (ConnectivityWrapper) alır.
class NoConnectionView extends StatelessWidget {
  final VoidCallback onRetry;

  const NoConnectionView({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.arkaplan,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 1),

            SvgPicture.asset(
              'assets/icons/ic_wifi_problem.svg',
              width: 180,
              height: 180,
              colorFilter: const ColorFilter.mode(
                AppColors.baglantiHata,
                BlendMode.srcIn,
              ),
            ),

            const SizedBox(height: 48),

            const Text(
              "Bağlantı Kesildi",
              style: TextStyle(
                color: AppColors.bogazGecesi,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              "İnternet bağlantınız yok.\nİstFix’i kullanmak için internet bağlantınız gereklidir.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF3B66A7),
                fontSize: 15,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 40),

            // Tekrar Dene Butonu
            // --- AKSİYON (CALL TO ACTION) ---
            // Kullanıcıyı bekletmemek adına manuel donanım taramasını başlatan tetikleyici buton.
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                // Butona tıklandığında ConnectivityWrapper'daki '_initializeHardwareMonitors' çalışır
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bogazGecesi,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Tekrar Dene",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              "Bağlantınız sağlandığında otomatik olarak devam edecek.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6C8CBA), fontSize: 13),
            ),

            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}
