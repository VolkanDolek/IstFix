import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:istfix_app/core/constants/color_constants.dart';
import 'package:istfix_app/features/auth/login_view.dart';
import 'package:istfix_app/services/auth_service.dart';

/// Şifre sıfırlama akışının son adımı: Kullanıcının yeni şifresini belirlediği ekran.
/// E-posta adresi ve doğrulama kodu, güvenlik doğrulamasından geçtikten sonra bu ekrana aktarılır.
class ForgotPasswordNewView extends StatefulWidget {
  final String email;
  final String code;

  const ForgotPasswordNewView({
    super.key,
    required this.email,
    required this.code,
  });

  @override
  State<ForgotPasswordNewView> createState() => _ForgotPasswordNewViewState();
}

class _ForgotPasswordNewViewState extends State<ForgotPasswordNewView> {
  // Form girişlerini okumak ve yönetmek için kullanılan denetleyiciler
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Arayüz etkileşim durumları
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  // Şifre güvenlik politikalarının (Regex ve eşleşme) anlık durum bayrakları
  bool _hasMinLength = false;
  bool _hasUpperAndNumber = false;
  bool _passwordsMatch = false;

  @override
  void initState() {
    super.initState();
    // Kullanıcının her tuş vuruşunda şifre kurallarını anlık olarak (real-time) denetlemek için dinleyiciler eklenir
    _newPasswordController.addListener(_validateForm);
    _confirmPasswordController.addListener(_validateForm);
  }

  @override
  void dispose() {
    // Bellek sızıntılarını (memory leak) önlemek için sayfa kapatıldığında kaynaklar temizlenir
    _newPasswordController.removeListener(_validateForm);
    _confirmPasswordController.removeListener(_validateForm);
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Şifrenin belirlenen güvenlik standartlarına uyup uymadığını doğrular.
  /// Kriterler: En az 8 karakter, 1 büyük harf, 1 rakam ve her iki alanın eşleşmesi.
  void _validateForm() {
    final password = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    setState(() {
      _hasMinLength = password.length >= 8;
      final hasUpper = password.contains(RegExp(r'[A-Z]'));
      final hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasUpperAndNumber = hasUpper && hasNumber;

      _passwordsMatch =
          password.isNotEmpty &&
          confirmPassword.isNotEmpty &&
          password == confirmPassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Tüm güvenlik ve eşleşme kuralları sağlandığında form geçerli kabul edilir
    final bool isFormValid =
        _hasMinLength && _hasUpperAndNumber && _passwordsMatch;

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
                        const SizedBox(height: 40),

                        SvgPicture.asset(
                          'assets/icons/ic_lock.svg',
                          width: 48,
                          height: 48,
                          colorFilter: const ColorFilter.mode(
                            AppColors.marmaraMavisi,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(height: 20),

                        const Text(
                          "Yeni Şifre Oluştur",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.bogazGecesi,
                          ),
                        ),
                        const SizedBox(height: 8),

                        const Text(
                          "Yeni şifreniz daha önce kullandığınız\nşifrelerden farklı olmalıdır.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.bogazGecesi,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 32),

                        _buildInputLabel("Yeni Şifre*"),
                        const SizedBox(height: 4),
                        _buildTextField(
                          controller: _newPasswordController,
                          hintText: "Yeni şifrenizi girin",
                          isPassword: true,
                          isPasswordVisible: _isPasswordVisible,
                          showEyeIcon: true,
                          onVisibilityToggle: () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible,
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildInputLabel("Şifre Tekrar*"),
                        const SizedBox(height: 4),
                        _buildTextField(
                          controller: _confirmPasswordController,
                          hintText: "Şifrenizi tekrar girin",
                          isPassword: true,
                          isPasswordVisible: false,
                          showEyeIcon: false,
                        ),

                        const SizedBox(height: 16),

                        // Anlık durumlarına göre renk değiştiren güvenlik kuralı bildirimleri
                        _buildValidationItem("En az 8 karakter", _hasMinLength),
                        _buildValidationItem(
                          "En az 1 büyük harf ve 1 rakam",
                          _hasUpperAndNumber,
                        ),
                        _buildValidationItem(
                          "Şifreler eşleşiyor",
                          _passwordsMatch,
                        ),

                        const SizedBox(height: 24),

                        // Form Kaydetme Butonu
                        SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: (isFormValid && !_isLoading)
                                ? () async {
                                    setState(() => _isLoading = true);
                                    try {
                                      final authService = AuthService();
                                      // Yeni şifre, doğrulanan email ve kod ile birlikte backend servisine iletilir
                                      await authService.resetPassword(
                                        widget.email,
                                        widget.code,
                                        _newPasswordController.text,
                                      );

                                      if (mounted) {
                                        // Başarılı işlem sonrası kullanıcıya yeşil bir onay bildirimi gösterilir
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Şifreniz başarıyla sıfırlandı! Giriş yapabilirsiniz.',
                                            ),
                                            backgroundColor:
                                                AppColors.marmaraMavisi,
                                          ),
                                        );
                                        // Güvenlik amacıyla aradaki tüm şifre sıfırlama sayfaları (stack) silinir ve Login'e yönlendirilir
                                        Navigator.pushAndRemoveUntil(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const LoginView(),
                                          ),
                                          (route) => route.isFirst,
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              e.toString().replaceAll(
                                                "Exception: ",
                                                "",
                                              ),
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() => _isLoading = false);
                                      }
                                    }
                                  }
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
                                    "Kaydet ve Giriş Yap",
                                    style: TextStyle(
                                      color: isFormValid
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

  /// Ekranın üst kısmında yer alan ve geri dönüş işlevi sunan navigasyon çubuğu.
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

  /// Şifre kurallarını (uzunluk, harf/rakam, eşleşme) gösteren ve durum geçerliliğine
  /// göre dinamik olarak renk (şeffaf/opak) değiştiren bilgilendirme öğesi.
  Widget _buildValidationItem(String text, bool isValid) {
    final Color color = isValid
        ? AppColors.halicAcigi
        : AppColors.halicAcigi.withOpacity(0.4);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: color, size: 14),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }

  /// Form alanları için açıklayıcı etiket.
  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        color: AppColors.bogazGecesi,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  /// Proje standartlarına uygun, şifre gizleme/gösterme özelliklerine sahip metin giriş alanı.
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool isPassword = false,
    bool isPasswordVisible = false,
    bool showEyeIcon = false,
    VoidCallback? onVisibilityToggle,
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
        obscureText: isPassword && !isPasswordVisible,
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
          suffixIconConstraints: const BoxConstraints(
            minHeight: 24,
            minWidth: 40,
          ),
          // Şifre alanında maskelemeyi açıp kapatmak için kullanılan göz ikonu
          suffixIcon: (isPassword && showEyeIcon)
              ? GestureDetector(
                  onTap: onVisibilityToggle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: SvgPicture.asset(
                      isPasswordVisible
                          ? 'assets/icons/ic_eye_show.svg'
                          : 'assets/icons/ic_eye_hide.svg',
                      colorFilter: const ColorFilter.mode(
                        AppColors.bogazGecesi,
                        BlendMode.srcIn,
                      ),
                      width: 20,
                    ),
                  ),
                )
              : null,
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
