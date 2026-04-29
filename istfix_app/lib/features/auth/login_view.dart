import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:istfix_app/core/constants/color_constants.dart';
import 'package:istfix_app/features/auth/register_view.dart';
import 'package:istfix_app/services/auth_service.dart';

/// Kullanıcı kimlik doğrulama süreçlerini yöneten görünüm katmanı.
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  // Form denetleyicileri ve servisler
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  // Durum değişkenleri
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  /// Mevcut kullanıcı bilgilerini sisteme gönderir ve doğrular.
  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showErrorDialog("Lütfen e-posta ve şifrenizi giriniz.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await _authService.login(email, password);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Giriş başarılı! Hoş geldiniz."),
            backgroundColor: Colors.green,
          ),
        );
        // Ana sayfa yönlendirmesi buraya eklenecek.
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString().replaceAll("Exception: ", ""));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Operasyonel hataları kullanıcıya bildiren modal pencere.
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "Hata",
          style: TextStyle(color: AppColors.bogazGecesi),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              "Tamam",
              style: TextStyle(color: AppColors.halicAcigi),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.arkaplan,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 80),
                        Text(
                          "Giriş Yap",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.bogazGecesi,
                          ),
                        ),
                        const SizedBox(height: 40),

                        _buildInputLabel("E-posta Adresi"),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _emailController,
                          hintText: "E-posta adresinizi girin",
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 20),

                        _buildInputLabel("Şifre"),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _passwordController,
                          hintText: "********",
                          isPassword: true,
                          isPasswordVisible: _isPasswordVisible,
                          onVisibilityToggle: () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible,
                          ),
                        ),

                        // Şifre sıfırlama yönlendirmesi
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () {},
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                "Şifreni mi unuttun ?",
                                style: TextStyle(
                                  color: AppColors.halicAcigi,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.bogazGecesi,
                                ),
                              )
                            : ElevatedButton(
                                onPressed: _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.bogazGecesi,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  "Giriş Yap",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                        const SizedBox(height: 20),

                        // Kayıt sayfasına geçiş alanı (Link stili)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Hesabın yok mu? ",
                              style: TextStyle(color: AppColors.bogazGecesi),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => const RegisterView(),
                                  ),
                                );
                              },
                              child: const Text(
                                "Kayıt Ol",
                                style: TextStyle(
                                  color: AppColors.halicAcigi,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.halicAcigi,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 60,
                        ), // Link ile logo arası minimum güvenli boşluk
                        const Spacer(), // Logoyu en alta iter
                        _buildBrandLogo(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Marka logosunu özelleştirilmiş TextSpan ile oluşturur.
  Widget _buildBrandLogo() {
    return Center(
      child: RichText(
        text: const TextSpan(
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
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
    );
  }

  /// Form alanları için açıklayıcı etiket.
  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        color: AppColors.bogazGecesi,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  /// Tasarıma uygun özelleştirilmiş metin giriş alanı.
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onVisibilityToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.bogazGecesi.withOpacity(0.5),
          width: 1.2,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && !isPasswordVisible,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.bogazGecesi, fontSize: 16),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: AppColors.bogazGecesi.withOpacity(0.5)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: InputBorder.none,
          suffixIcon: isPassword
              ? GestureDetector(
                  onTap: onVisibilityToggle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: SvgPicture.asset(
                      isPasswordVisible
                          ? 'assets/icons/ic_eye_show.svg'
                          : 'assets/icons/ic_eye_hide.svg',
                      colorFilter: const ColorFilter.mode(
                        AppColors.bogazGecesi,
                        BlendMode.srcIn,
                      ),
                      width: 24,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
