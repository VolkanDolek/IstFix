import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:istfix_app/core/constants/color_constants.dart';
import 'package:istfix_app/features/auth/forgot_password_new_view.dart';
import 'package:istfix_app/services/auth_service.dart';

/// Şifre sıfırlama akışının ikinci adımı: Kullanıcının e-posta adresine
/// gönderilen 4 haneli güvenlik kodunu girdiği doğrulama ekranı.
class ForgotPasswordVerifyView extends StatefulWidget {
  final String email;

  const ForgotPasswordVerifyView({super.key, required this.email});

  @override
  State<ForgotPasswordVerifyView> createState() =>
      _ForgotPasswordVerifyViewState();
}

class _ForgotPasswordVerifyViewState extends State<ForgotPasswordVerifyView> {
  // 4 haneli doğrulama kodunun her bir hanesini tutan veri yapısı
  final List<String> _codeDigits = ["", "", "", ""];

  // Asenkron ağ işlemleri sırasında kullanıcı etkileşimini kısıtlayan durum bayrağı
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    // Tüm basamaklar doldurulduğunda doğrulama butonunu aktif hale getirir
    final bool isCodeComplete = _codeDigits.every((digit) => digit.isNotEmpty);

    return Scaffold(
      backgroundColor: AppColors.arkaplan,
      appBar: _buildAppBar(context),
      body: SafeArea(
        // Cihaz klavyesi açıldığında arayüzün dinamik olarak yeniden boyutlandırılmasını sağlar
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 60),

                        SvgPicture.asset(
                          'assets/icons/ic_mail.svg',
                          width: 48,
                          height: 48,
                          colorFilter: const ColorFilter.mode(
                            AppColors.marmaraMavisi,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(height: 24),

                        const Text(
                          "E-postanızı Kontrol Edin",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.bogazGecesi,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Text(
                          "Doğrulama kodunu şu adrese gönderdik:\n${widget.email}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.bogazGecesi,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 32),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            4,
                            (index) => _buildCodeBox(context, index),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Doğrulama İşlemi Butonu
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            onPressed: (isCodeComplete && !_isLoading)
                                ? () async {
                                    setState(() => _isLoading = true);
                                    final fullCode = _codeDigits.join();

                                    try {
                                      final authService = AuthService();

                                      // 1. Girilen 4 haneli güvenlik kodunu backend servisi üzerinden doğrular
                                      await authService.verifyResetCode(
                                        widget.email,
                                        fullCode,
                                      );

                                      // 2. Doğrulama başarılı ise kullanıcıyı yeni şifre belirleme ekranına aktarır
                                      if (mounted) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ForgotPasswordNewView(
                                                  email: widget.email,
                                                  code: fullCode,
                                                ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      // Ağ hatası veya geçersiz kod durumunda kullanıcıya görsel geri bildirim sunulur
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
                                : const Text(
                                    "Doğrula",
                                    style: TextStyle(
                                      color: Colors.white,
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

  /// 4 haneli güvenlik kodunun her bir hanesi için bağımsız, otomatik odaklanma (auto-focus)
  /// yeteneğine sahip metin giriş kutuları oluşturur.
  Widget _buildCodeBox(BuildContext context, int index) {
    return Container(
      width: 52,
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.marmaraMavisi.withOpacity(0.8),
          width: 1.2,
        ),
      ),
      child: Center(
        child: TextField(
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.marmaraMavisi,
          ),
          decoration: const InputDecoration(
            counterText: "",
            border: InputBorder.none,
          ),
          onChanged: (value) {
            setState(() {
              _codeDigits[index] = value;
            });

            // Kullanıcı veri girdikçe veya sildikçe bir sonraki/önceki kutuya otomatik geçiş sağlar
            if (value.length == 1 && index < 3) {
              FocusScope.of(context).nextFocus();
            } else if (value.isEmpty && index > 0) {
              FocusScope.of(context).previousFocus();
            }
          },
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
