import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:istfix_app/core/constants/color_constants.dart';
import 'package:istfix_app/services/auth_service.dart';

/// Kullanıcının mevcut şifresini doğrulayarak yeni bir şifre belirlemesini sağlayan görünüm sınıfı.
class ChangePasswordView extends StatefulWidget {
  const ChangePasswordView({super.key});

  @override
  State<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<ChangePasswordView> {
  // Form girdi denetleyicileri
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Durum ve görünürlük değişkenleri
  bool _isOldPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isLoading =
      false; // İşlem sırasında kullanıcıya geri bildirim sağlamak için kullanılır

  // Şifre karmaşıklık ve doğrulama kriterleri
  bool _hasOldPassword = false;
  bool _hasMinLength = false;
  bool _hasUpperAndNumber = false;
  bool _passwordsMatch = false;

  @override
  void initState() {
    super.initState();
    // Girdi değişikliklerini anlık olarak takip etmek için dinleyiciler atanır
    _oldPasswordController.addListener(_validateForm);
    _newPasswordController.addListener(_validateForm);
    _confirmPasswordController.addListener(_validateForm);
  }

  @override
  void dispose() {
    // Bellek sızıntılarını önlemek için denetleyiciler ve dinleyiciler serbest bırakılır
    _oldPasswordController.removeListener(_validateForm);
    _newPasswordController.removeListener(_validateForm);
    _confirmPasswordController.removeListener(_validateForm);
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Formdaki girdilerin iş kurallarına uygunluğunu denetler ve arayüzü günceller.
  void _validateForm() {
    final oldPassword = _oldPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    setState(() {
      // Mevcut şifre alanı boş olmamalıdır
      _hasOldPassword = oldPassword.isNotEmpty;

      // Yeni şifre en az 8 karakter uzunluğunda olmalıdır
      _hasMinLength = newPassword.length >= 8;

      // Yeni şifre en az bir büyük harf ve bir rakam içermelidir (Regex kontrolü)
      final hasUpper = newPassword.contains(RegExp(r'[A-Z]'));
      final hasNumber = newPassword.contains(RegExp(r'[0-9]'));

      _hasUpperAndNumber = hasUpper && hasNumber;

      // Yeni şifre ve onay şifresi birbiriyle tam olarak eşleşmelidir
      _passwordsMatch =
          newPassword.isNotEmpty &&
          confirmPassword.isNotEmpty &&
          newPassword == confirmPassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Tüm kriterler sağlandığında buton aktif hale gelir
    final bool isFormValid =
        _hasOldPassword &&
        _hasMinLength &&
        _hasUpperAndNumber &&
        _passwordsMatch;

    return Scaffold(
      backgroundColor: AppColors.arkaplan,
      appBar: _buildAppBar(context),
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
                        const SizedBox(height: 32),
                        // Görsel kimliği pekiştiren kilit ikonu
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
                          "Şifrenizi Güncelleyin",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.bogazGecesi,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Güvenliğiniz için lütfen mevcut şifrenizi\nve yeni şifrenizi giriniz.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.bogazGecesi,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Şifre Giriş Alanları
                        _buildInputLabel("Mevcut Şifre*"),
                        const SizedBox(height: 4),
                        _buildTextField(
                          controller: _oldPasswordController,
                          hintText: "Mevcut şifrenizi girin",
                          isPasswordVisible: _isOldPasswordVisible,
                          showEyeIcon: true,
                          onVisibilityToggle: () => setState(
                            () =>
                                _isOldPasswordVisible = !_isOldPasswordVisible,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInputLabel("Yeni Şifre*"),
                        const SizedBox(height: 4),
                        _buildTextField(
                          controller: _newPasswordController,
                          hintText: "Yeni şifrenizi girin",
                          isPasswordVisible: _isNewPasswordVisible,
                          showEyeIcon: true,
                          onVisibilityToggle: () => setState(
                            () =>
                                _isNewPasswordVisible = !_isNewPasswordVisible,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInputLabel("Yeni Şifre Tekrar*"),
                        const SizedBox(height: 4),
                        _buildTextField(
                          controller: _confirmPasswordController,
                          hintText: "Şifrenizi tekrar girin",
                          isPasswordVisible: false,
                          showEyeIcon: false,
                        ),
                        const SizedBox(height: 16),

                        // Kriter Takip Listesi
                        _buildValidationItem("En az 8 karakter", _hasMinLength),
                        _buildValidationItem(
                          "En az 1 büyük harf ve 1 rakam",
                          _hasUpperAndNumber,
                        ),
                        _buildValidationItem(
                          "Şifreler eşleşiyor",
                          _passwordsMatch,
                        ),
                        const SizedBox(height: 32),

                        // İşlem Onay Butonu
                        SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: (isFormValid && !_isLoading)
                                ? () async {
                                    setState(() => _isLoading = true);
                                    try {
                                      final authService = AuthService();
                                      // Servis katmanı üzerinden şifre güncelleme isteği gönderilir
                                      await authService.changePassword(
                                        _oldPasswordController.text,
                                        _newPasswordController.text,
                                      );
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Şifreniz başarıyla güncellendi.',
                                            ),
                                            backgroundColor:
                                                AppColors.marmaraMavisi,
                                          ),
                                        );
                                        Navigator.pop(
                                          context,
                                        ); // Başarılı işlem sonrası bir önceki sayfaya dönülür
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        // Hata durumunda kullanıcıya geri bildirim verilir
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
                                    "Şifreyi Kaydet",
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
                        // Marka kimliğini alt kısımda konumlandırır
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

  /// Sayfa başlığı ve navigasyon kontrolünü içeren üst bar.
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
        "Şifre Değiştir",
        style: TextStyle(
          color: AppColors.bogazGecesi,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  /// Şifre kriterlerinin karşılanma durumunu görselleştiren öğe.
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

  /// Girdi alanları için standartlaştırılmış başlık etiketi.
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

  /// Tasarım sistemine uygun, özelleştirilmiş metin giriş alanı.
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required bool isPasswordVisible,
    required bool showEyeIcon,
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
        obscureText: !isPasswordVisible, // Şifre gizleme kontrolü
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
          // Şifre görünürlüğünü değiştiren interaktif ikon
          suffixIcon: showEyeIcon
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

  /// Uygulamanın marka logosunu (IstFix) stilize edilmiş şekilde oluşturur.
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
