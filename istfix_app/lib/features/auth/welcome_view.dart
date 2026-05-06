import 'package:flutter/material.dart';
import 'package:istfix_app/core/constants/color_constants.dart';
import 'package:istfix_app/features/auth/login_view.dart';
import 'package:istfix_app/features/auth/register_view.dart';

/// [WelcomeView], uygulamanın açılış ekranıdır ve marka kimliğini yansıtır.
class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.arkaplan,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            // Tüm içeriği ekranın tam ortasında kompakt bir şekilde toplar
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              /// Marka logosu ve tipografisi.
              _buildLogoSection(),

              const SizedBox(height: 24),

              /// Uygulama sloganı.
              const Text(
                "İstanbul’daki altyapı sorunlarını\nkolayca bildirin",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.bogazGecesi,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),

              // Sabit boşluk kullanılarak butonlar merkeze yaklaştırıldı.
              const SizedBox(height: 48),

              /// Giriş ve Kayıt aksiyon butonları.
              _buildPrimaryButton(
                context,
                label: "Giriş Yap",
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginView()),
                ),
              ),

              const SizedBox(height: 16),

              _buildSecondaryButton(
                context,
                label: "Kayıt Ol",
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegisterView()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Logo boyutunu görsel denge için optimize ettik.
  Widget _buildLogoSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/logos/istfix_logo_512x512.png',
          height: 110,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 8),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              letterSpacing: -1.2,
            ),
            children: [
              TextSpan(
                text: "Ist",
                style: TextStyle(color: AppColors.bogazGecesi),
              ),
              TextSpan(
                text: "Fix",
                style: TextStyle(color: AppColors.marmaraMavisi),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(
    BuildContext context, {
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 46, // Login ve Register sayfalarındaki buton boyutuyla eşitlendi
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.bogazGecesi,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              8,
            ), // Yuvarlaklık diğer formlarla eşitlendi
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(
    BuildContext context, {
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 46, // Login ve Register sayfalarındaki buton boyutuyla eşitlendi
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.bogazGecesi, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              8,
            ), // Yuvarlaklık diğer formlarla eşitlendi
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.bogazGecesi,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
