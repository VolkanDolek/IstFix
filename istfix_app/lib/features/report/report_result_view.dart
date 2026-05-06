import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:istfix_app/core/constants/color_constants.dart';

/// Rapor gönderim işleminden sonra kullanıcıya gösterilen tam sayfa geri bildirim ekranı.
class ReportResultView extends StatelessWidget {
  final bool isSuccess; // Başarılı mı, hatalı mı?
  final String title; // Kalın puntoyla yazılacak ana başlık
  final String message; // Alt bilgi ve açıklama metni
  final String?
  category; // Başarılı durumlarda gösterilecek yapay zeka kategorisi

  const ReportResultView({
    super.key,
    required this.isSuccess,
    required this.title,
    required this.message,
    this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.arkaplan, // Tasarımdaki açık mavi/gri zemin
      appBar: AppBar(
        backgroundColor: AppColors.bogazGecesi,
        elevation: 0,
        centerTitle: true,
        // Geri dönüş butonunu kaldırıyoruz (Kullanıcı mecbur 'Haritaya Dön'e basacak)
        automaticallyImplyLeading: false,
        title: const Text(
          "Rapor Sonucu",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Dinamik Durum İkonu
            SvgPicture.asset(
              isSuccess
                  ? 'assets/icons/ic_check_circle_filled.svg'
                  : 'assets/icons/ic_warning_circle.svg',
              width: 150,
              height: 150,
            ),
            const SizedBox(height: 36),

            // 2. Ana Başlık
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.bogazGecesi,
                fontSize: 22,
                fontWeight: FontWeight.w800, // Ekstra kalın
              ),
            ),
            const SizedBox(height: 14),

            // 3. Detay Metni
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF3B66A7),
                fontSize: 15,
                height: 1.4, // Satır arası boşluğu
              ),
            ),
            const SizedBox(height: 20),

            // 4. (Opsiyonel) Kategori Bilgisi
            if (category != null) ...[
              Text(
                category!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.bogazGecesi,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            const SizedBox(height: 50),

            // 5. Haritaya Dönüş Butonu
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  // Geçmişteki tüm sayfaları temizleyerek en başa (Haritaya) döner
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bogazGecesi,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "Haritaya Dön",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Ekranın alt kısımlarına yapışmasını engellemek için esneklik
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}
