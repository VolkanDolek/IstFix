import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dio/dio.dart'; // GÜNCELLEME: http yerine dio eklendi
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:istfix_app/core/constants/color_constants.dart';
import 'package:istfix_app/core/network/api_client.dart'; // GÜNCELLEME: Merkezi API kalkanı eklendi
import 'package:istfix_app/features/auth/login_view.dart';
import 'package:istfix_app/services/auth_service.dart';
import 'package:istfix_app/features/auth/kvkk_view.dart';
import 'package:istfix_app/features/profile/change_password_view.dart';

/// Kullanıcı profil bilgilerinin görüntülendiği, oturum yönetiminin ve
/// yasal metinlerin erişilebilir olduğu görünüm katmanı.
class ProfileView extends StatefulWidget {
  // GÜNCELLEME: Test ortamı için dışarıdan mocklanabilir parametreler eklendi
  final Dio? dio;
  final FlutterSecureStorage? secureStorage;
  final AuthService? authService;

  const ProfileView({
    super.key,
    this.dio,
    this.secureStorage,
    this.authService,
  });

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  // Veri erişimi ve kimlik doğrulama servis bağımlılıkları
  // GÜNCELLEME: Sabit atamalar kaldırılıp late değişken yapıldı
  late final FlutterSecureStorage _secureStorage;
  late final AuthService _authService;

  // GÜNCELLEME: Merkezi API İstemcisi
  late final Dio _dio;

  // Profil verileri ve yüklenme durumu
  String _firstName = "...";
  String _email = "...";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // GÜNCELLEME: Dışarıdan mock verildiyse onu, verilmediyse orijinal üretim nesnelerini bağlıyoruz
    _secureStorage = widget.secureStorage ?? const FlutterSecureStorage();
    _authService = widget.authService ?? AuthService();
    _dio = widget.dio ?? ApiClient().dio;

    _fetchUserData();
  }

  /// Kimliği doğrulanmış kullanıcının temel profil verilerini backend servisinden
  /// asenkron olarak çeker ve arayüzü günceller.
  Future<void> _fetchUserData() async {
    try {
      final token = await _secureStorage.read(key: 'access_token');

      // GÜNCELLEME: İstek merkezi kalkan üzerinden (Dio ile) atılıyor
      final response = await _dio.get(
        '/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        // Dio JSON parse işlemini otomatik yapar, json.decode'a gerek kalmaz
        final data = response.data;
        final fullName = data['name'] ?? "Kullanıcı";

        if (mounted) {
          setState(() {
            // UI bütünlüğü için sadece kullanıcının ilk adını ayrıştırıyoruz
            _firstName = fullName.split(' ').first;
            _email = data['emailAddress'] ?? "";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Profil verisi çekilemedi: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Kullanıcının oturumunu sonlandırmadan önce kazara çıkışları
  /// önlemek amacıyla bir onay mekanizması sunar.
  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Çıkış Yap",
          style: TextStyle(
            color: AppColors.bogazGecesi,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text("Oturumunuzu kapatmak istediğinize emin misiniz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Vazgeç", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              await _authService.logout();
              if (mounted) {
                // Güvenlik amacıyla tüm navigasyon yığınını temizleyerek giriş ekranına yönlendirir
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginView()),
                  (route) => false,
                );
              }
            },
            child: const Text(
              "Çıkış Yap",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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
      appBar: AppBar(
        backgroundColor: AppColors.bogazGecesi,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Profilim",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.bogazGecesi),
            )
          : Column(
              children: [
                const SizedBox(height: 40),

                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      color: AppColors.bogazGecesi,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _firstName.isNotEmpty
                            ? _firstName[0].toUpperCase()
                            : "?",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  _firstName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.bogazGecesi,
                  ),
                ),
                Text(
                  _email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6C8CBA),
                  ),
                ),

                const SizedBox(height: 40),

                _buildProfileOption(
                  icon: 'assets/icons/ic_document.svg',
                  title: "KVKK Aydınlatma Metni",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const KvkkView()),
                  ),
                ),

                _buildProfileOption(
                  icon: 'assets/icons/ic_key.svg',
                  title: "Şifre değiştir",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChangePasswordView(),
                    ),
                  ),
                ),

                _buildProfileOption(
                  icon: 'assets/icons/ic_logout.svg',
                  title: "Çıkış Yap",
                  isLogout: true,
                  onTap: _showLogoutConfirmation,
                ),
              ],
            ),
    );
  }

  /// Profil sayfasındaki navigasyon ve işlem menüleri için
  /// standartlaştırılmış tasarım yapısını oluşturan yardımcı bileşen.
  Widget _buildProfileOption({
    required String icon,
    required String title,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isLogout
                      ? Colors.red.withOpacity(0.1)
                      : AppColors.bogazGecesi.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    icon,
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      isLogout ? Colors.red : AppColors.bogazGecesi,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isLogout ? Colors.red : AppColors.bogazGecesi,
                  ),
                ),
              ),

              SvgPicture.asset(
                'assets/icons/ic_chevron_right.svg',
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  isLogout
                      ? Colors.red.withOpacity(0.5)
                      : AppColors.bogazGecesi.withOpacity(0.5),
                  BlendMode.srcIn,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
