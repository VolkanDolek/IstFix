import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/gestures.dart';
import 'package:istfix_app/core/constants/color_constants.dart';
import 'package:istfix_app/features/auth/login_view.dart';
import 'package:istfix_app/features/auth/kvkk_view.dart';
import 'package:istfix_app/services/auth_service.dart';

/// Yeni kullanıcı kaydı ve şifre kriterlerinin denetlendiği görünüm sınıfı.
class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  // Girdi denetleyicileri
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final AuthService _authService = AuthService();

  // Arayüz durum değişkenleri
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isKvkkAccepted = false;

  // Şifre doğrulama durumları
  bool _hasMinLength = false;
  bool _hasUpperAndNumber = false;
  bool _passwordsMatch = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validateForm);
    _confirmPasswordController.addListener(_validateForm);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_validateForm);
    _confirmPasswordController.removeListener(_validateForm);
    _firstNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Şifre kriterlerini ve eşleşme durumunu anlık olarak denetler.
  void _validateForm() {
    final password = _passwordController.text;
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

  /// Kayıt bilgilerini doğrular ve sisteme iletir.
  Future<void> _handleRegister() async {
    if (!(_hasMinLength &&
        _hasUpperAndNumber &&
        _passwordsMatch &&
        _isKvkkAccepted)) {
      _showErrorDialog(
        "Lütfen tüm kriterleri ve KVKK onayını sağladığınızdan emin olun.",
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await _authService.register(
        _firstNameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Hesabınız başarıyla oluşturuldu.")),
        );
        _navigateToLogin();
      }
    } catch (e) {
      _showErrorDialog(e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Giriş ekranına yönlendirme yapar.
  void _navigateToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginView()),
    );
  }

  /// Hata mesajlarını bildiren iletişim kutusu.
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
    final bool isFormValid =
        _hasMinLength &&
        _hasUpperAndNumber &&
        _passwordsMatch &&
        _isKvkkAccepted;

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
                        const SizedBox(height: 50),
                        const Text(
                          "Kayıt Ol",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.bogazGecesi,
                          ),
                        ),

                        const SizedBox(height: 32),

                        _buildInputLabel("Ad"),
                        const SizedBox(height: 4),
                        _buildTextField(
                          controller: _firstNameController,
                          hintText: "Adınızı girin",
                        ),
                        const SizedBox(height: 10),

                        _buildInputLabel("E-posta Adresi"),
                        const SizedBox(height: 4),
                        _buildTextField(
                          controller: _emailController,
                          hintText: "E-posta adresinizi girin",
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 10),

                        _buildInputLabel("Şifre"),
                        const SizedBox(height: 4),
                        _buildTextField(
                          controller: _passwordController,
                          hintText: "********",
                          isPassword: true,
                          isPasswordVisible: _isPasswordVisible,
                          showEyeIcon: true,
                          onVisibilityToggle: () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible,
                          ),
                        ),

                        // Dinamik doğrulama maddeleri
                        const SizedBox(height: 4),
                        _buildValidationItem("En az 8 karakter", _hasMinLength),
                        _buildValidationItem(
                          "En az 1 büyük harf ve 1 rakam",
                          _hasUpperAndNumber,
                        ),
                        _buildValidationItem(
                          "Şifreler eşleşiyor",
                          _passwordsMatch,
                        ),
                        const SizedBox(height: 8),

                        _buildInputLabel("Şifre Tekrar"),
                        const SizedBox(height: 4),
                        _buildTextField(
                          controller: _confirmPasswordController,
                          hintText: "********",
                          isPassword: true,
                          isPasswordVisible: false,
                          showEyeIcon: false,
                        ),

                        const SizedBox(height: 12),
                        _buildKvkkCheckbox(),
                        const SizedBox(height: 16),

                        _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.bogazGecesi,
                                ),
                              )
                            : SizedBox(
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: isFormValid
                                      ? _handleRegister
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.bogazGecesi,
                                    disabledBackgroundColor: AppColors
                                        .bogazGecesi
                                        .withOpacity(0.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    "Kayıt OL",
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

                        const SizedBox(height: 12),
                        // Giriş sayfasına geçiş alanı (Link stili)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Zaten hesabın var mı? ",
                              style: TextStyle(
                                color: AppColors.bogazGecesi,
                                fontSize: 13,
                              ),
                            ),
                            GestureDetector(
                              onTap: _navigateToLogin,
                              child: const Text(
                                "Giriş Yap",
                                style: TextStyle(
                                  color: AppColors.halicAcigi,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.halicAcigi,
                                ),
                              ),
                            ),
                          ],
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

  Widget _buildKvkkCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 20,
          width: 20,
          child: Checkbox(
            value: _isKvkkAccepted,
            activeColor: AppColors.bogazGecesi,
            onChanged: (bool? value) {
              setState(() => _isKvkkAccepted = value ?? false);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.bogazGecesi,
                height: 1.2,
              ),
              children: [
                TextSpan(
                  text: "KVKK Aydınlatma Metni",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                    color: AppColors.halicAcigi,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const KvkkView(),
                        ),
                      );
                    },
                ),
                const TextSpan(text: "’ni okudum ve kabul ediyorum."),
              ],
            ),
          ),
        ),
      ],
    );
  }

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

  /// Şifre kriterlerinin görselleştirildiği liste öğesi.
  Widget _buildValidationItem(String text, bool isValid) {
    final Color color = isValid
        ? AppColors.halicAcigi
        : AppColors.halicAcigi.withOpacity(0.4);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: color, size: 12),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }

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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
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
          color: AppColors.bogazGecesi.withOpacity(0.5),
          width: 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        obscureText: isPassword && !isPasswordVisible,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.bogazGecesi, fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          hintText: hintText,
          hintStyle: TextStyle(
            color: AppColors.bogazGecesi.withOpacity(0.5),
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
}
