import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:istfix_app/core/constants/color_constants.dart';

/// Sistem genelinde konum servisleri (GPS) devre dışı bırakıldığında uygulamanın
/// üzerine inen ve coğrafi doğruluk gerektiren işlemleri (harita, ihbar) durduran tam sayfa geri bildirim ekranı.
///
/// [StatelessWidget] mimarisinde tasarlanmıştır. Donanımın aktif olma durumu bu sayfa içinde değil,
/// üst katmandaki sarmalayıcı (ConnectivityWrapper) tarafından dinlenir ve yönetilir.
class NoGpsView extends StatelessWidget {
  const NoGpsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.arkaplan,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/icons/ic_location_off.svg',
              width: 150,
              colorFilter: const ColorFilter.mode(
                AppColors.baglantiHata,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              "Konum Servisi Kapalı",
              style: TextStyle(
                color: AppColors.bogazGecesi,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // --- BİLGİLENDİRME METNİ ---
            const Text(
              "Sorunları doğru konumlandırmak için GPS gereklidir. Lütfen ayarlardan konumu açın.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF3B66A7), fontSize: 15),
            ),
            const SizedBox(height: 40),

            // --- AKSİYON (CALL TO ACTION) ---
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                // Cihazın yerel işletim sistemi ayarlarına (Native OS Settings) doğrudan yönlendirme yapar.
                // Bu sayede kullanıcı uygulamadan çıkıp ayarları aramak zorunda kalmaz.
                onPressed: () => Geolocator.openLocationSettings(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bogazGecesi,
                ),
                child: const Text(
                  "Ayarları Aç",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
