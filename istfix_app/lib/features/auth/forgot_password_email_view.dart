import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:istfix_app/core/constants/color_constants.dart';
import 'package:istfix_app/features/auth/forgot_password_verify_view.dart';
import 'package:istfix_app/services/auth_service.dart';

/// Kullanıcının şifresini unuttuğu durumlarda, doğrulama kodunun
/// gönderileceği e-posta adresini girdiği başlangıç ekranı.
class ForgotPasswordEmailView extends StatefulWidget {
  const ForgotPasswordEmailView({super.key});

  @override
  State<ForgotPasswordEmailView> createState() =>
      _ForgotPasswordEmailViewState();
}

class _ForgotPasswordEmailViewState extends State<ForgotPasswordEmailView> {
  // Form denetleyicisi ve kimlik doğrulama servis bağımlılıkları
  final TextEditingController _emailController = TextEditingController();
  final AuthService _authService = AuthService();

  // API isteği süresince kullanıcı etkileşimini kısıtlamak için kullanılan durum bayrağı
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // E-posta giriş alanındaki değişiklikleri dinleyerek butonun aktiflik durumunu (isButtonActive) günceller
    _emailController.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _emailController.dispose();
    super.dispose();
  }

  /// Metin alanı her değiştiğinde arayüzü yeniden çizerek butonun durumunu günceller.
  void _onEmailChanged() {
    setState(() {});
  }

  /// Kullanıcının girdiği e-posta adresine şifre sıfırlama bağlantısı/kodu gönderilmesi
  /// için backend servisi ile iletişim kurar ve başarılıysa bir sonraki adıma yönlendirir.
  Future<void> _handlePasswordResetRequest() async {
    setState(() => _isLoading = true);

    try {
      await _authService.forgotPassword(_emailController.text.trim());

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ForgotPasswordVerifyView(email: _emailController.text.trim()),
        ),
      );
    } catch (e) {
      if (mounted) {
        // Hata durumunda kullanıcıya görsel geri bildirim (SnackBar) sağlar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll("Exception: ", "")),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Gönder butonu, e-posta alanı doluysa ve arka planda işlem sürmüyorsa aktif olur
    final bool isButtonActive = _emailController.text.isNotEmpty && !_isLoading;

    return Scaffold(
      backgroundColor: AppColors.arkaplan,
      appBar: _buildAppBar(context),
      body: SafeArea(
        // Ekran klavye açıldığında taşma yapmaması için esnek (responsive) kaydırma yapısı
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
                        const SizedBox(height: 120),

                        _buildInputLabel("E-posta Adresi"),
                        const SizedBox(height: 4),
                        _buildTextField(
                          controller: _emailController,
                          hintText: "E-posta adresinizi girin",
                          keyboardType: TextInputType.emailAddress,
                        ),

                        const SizedBox(height: 16),

                        // İstek Gönderme Butonu
                        SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: isButtonActive
                                ? _handlePasswordResetRequest
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.bogazGecesi,
                              disabledBackgroundColor: AppColors.bogazGecesi
                                  .withOpacity(0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    "Doğrulama Kodu Gönder",
                                    style: TextStyle(
                                      color: isButtonActive
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.6),
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),

                        const Spacer(),
                        _buildBrandLogo(),
                        const SizedBox(height: 16),
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

  /// Ekranın üst kısmında yer alan, kurumsal renklere sahip ve geri dönüş işlevi sunan navigasyon çubuğu.
  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.arkaplan,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: SvgPicture.asset(
          'assets/icons/ic_chevron_left.svg',
          colorFilter: const ColorFilter.mode(
            AppColors.bogazGecesi,
            BlendMode.srcIn,
          ),
          width: 24,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        "Şifremi Unuttum",
        style: TextStyle(
          color: AppColors.bogazGecesi,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  /// Form elemanlarının üstünde gösterilen açıklayıcı tipografi.
  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        color: AppColors.bogazGecesi,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// Proje tasarım sistemine (Design System) uygun, standartlaştırılmış metin giriş alanı bileşeni.
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
  }) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.marmaraMavisi.withOpacity(0.8),
          width: 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.bogazGecesi, fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          hintText: hintText,
          hintStyle: TextStyle(
            color: AppColors.marmaraMavisi.withOpacity(0.6),
            fontSize: 14,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  /// Uygulamanın alt bilgi (footer) alanında yer alan markalama bileşeni.
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
}
