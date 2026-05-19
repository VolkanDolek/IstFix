import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Kimlik doğrulama işlemlerini (Giriş, Kayıt, Çıkış) yöneten servis sınıfı.
class AuthService {
  // Android emülatör üzerinden yerel makinedeki backend'e erişmek için 10.0.2.2 kullanılır.
  // iOS Simulator için '127.0.0.1'
  // Gerçek cihazla test için bilgisayarının yerel IP adresi
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: "http://10.0.2.2:8000/api",
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 3),
    ),
  );

  final _storage = const FlutterSecureStorage();

  /// Kullanıcı girişini doğrular ve oturum tercihlerini yönetir.
  /// [rememberMe] parametresi ile oturumun kalıcı olup olmayacağı belirlenir.
  Future<bool> login(
    String email,
    String password, {
    bool rememberMe = false,
  }) async {
    try {
      // FastAPI OAuth2 Login servisi "application/x-www-form-urlencoded" formatı
      // ve "username" alanı beklediği için özel olarak yapılandırıldı.
      final response = await _dio.post(
        "/auth/login",
        data: {"username": email, "password": password},
        options: Options(
          contentType: Headers.formUrlEncodedContentType, // Form formatı
        ),
      );

      if (response.statusCode == 200) {
        String token = response.data['access_token'];

        // Kimlik doğrulama anahtarını güvenli depolama birimine yazar.
        await _storage.write(key: "access_token", value: token);

        // Kullanıcının "Beni Hatırla" tercihini asenkron okuma için saklar.
        await _storage.write(key: "remember_me", value: rememberMe.toString());

        // --- KULLANICI ROLÜNÜ ÇEK VE KAYDET ---
        // Başarılı giriş sonrası, rotalama mimarisini yönetebilmek adına
        // '/auth/me' endpoint'inden aktif kullanıcının isAdmin durumu çekilir.
        try {
          final profileResponse = await _dio.get(
            "/auth/me",
            options: Options(headers: {"Authorization": "Bearer $token"}),
          );

          final bool isAdmin = profileResponse.data['isAdmin'] ?? false;
          await _storage.write(key: "is_admin", value: isAdmin.toString());
        } catch (e) {
          // Ağ hatası veya profilin çekilememesi durumunda,
          // güvenlik önlemi olarak standart yetki (citizen) atanır.
          await _storage.write(key: "is_admin", value: "false");
        }

        return true;
      }
      return false;
    } on DioException catch (e) {
      _handleDioError(e);
      return false; // Hata fırlatılmazsa false dön
    }
  }

  /// Uygulama açılışında geçerli bir oturumun ve otomatik giriş
  /// tercihinin olup olmadığını kontrol eder.
  Future<bool> shouldAutoLogin() async {
    final token = await _storage.read(key: "access_token");
    final rememberMe = await _storage.read(key: "remember_me");
    return token != null && rememberMe == 'true';
  }

  // --- YETKİ KONTROLÜ ---
  /// Mevcut oturumdaki kullanıcının yetkili (Admin) olup olmadığını yerel hafızadan okur.
  /// Bu metod, hem Login hem de Auto-Login sürecinde doğru panellere yönlendirme yapmak için kullanılır.
  Future<bool> checkIsAdmin() async {
    final adminStatus = await _storage.read(key: "is_admin");
    return adminStatus == 'true';
  }

  /// Yeni kullanıcı kaydı oluşturur.
  Future<bool> register(String name, String email, String password) async {
    try {
      // Pydantic (CitizenCreate) şemasına tam uyumlu JSON body gönderimi
      final response = await _dio.post(
        "/auth/register",
        data: {
          "name": name,
          "emailAddress":
              email, // Backend'deki isimlendirme (email -> emailAddress)
          "password": password,
          "kvkkAccepted": true, // Zorunlu KVKK alanı
        },
      );

      // Backend genellikle başarılı kayıt sonrası 201 (Created) veya 200 döner.
      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      }
      return false;
    } on DioException catch (e) {
      // Backend'den gelen spesifik hata mesajını yakala
      if (e.response?.statusCode == 400 || e.response?.statusCode == 409) {
        final errorMessage =
            e.response?.data['detail'] ??
            "Bu e-posta adresi zaten bir hesaba bağlı. Lütfen farklı bir adres deneyiniz.";
        throw Exception(errorMessage);
      }
      _handleDioError(e);
      return false;
    }
  }

  /// Mevcut oturumu sonlandırır ve tüm güvenlik anahtarları ile kullanıcı tercihlerini temizler.
  Future<void> logout() async {
    try {
      final token = await _storage.read(key: "access_token");
      if (token != null) {
        await _dio.post(
          "/auth/logout",
          options: Options(headers: {"Authorization": "Bearer $token"}),
        );
      }
    } catch (_) {
      // Ağ hatası, sunucu tarafında hata olsa bile yerel temizliğe devam edilir.
    } finally {
      // Oturum verilerini ve kullanıcı tercihlerini tamamen siler.
      await _storage.delete(key: "access_token");
      await _storage.delete(key: "remember_me");
      // Çıkış yaparken admin bilgisini temizler.
      await _storage.delete(key: "is_admin");
    }
  }

  /// Kullanıcıya e-posta üzerinden 4 haneli şifre sıfırlama kodu gönderir.
  Future<bool> forgotPassword(String email) async {
    try {
      final response = await _dio.post(
        "/citizens/forgot-password",
        data: {"email": email},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      final errorMessage =
          e.response?.data['detail'] ?? "Mail gönderilirken bir sorun oluştu.";
      throw Exception(errorMessage);
    }
  }

  /// Girilen 4 haneli kodun doğruluğunu teyit eder.
  Future<bool> verifyResetCode(String email, String code) async {
    try {
      final response = await _dio.post(
        "/citizens/verify-reset-code",
        data: {"email": email, "code": code},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      String errorMessage =
          "Girdiğiniz doğrulama kodu hatalı veya süresi dolmuş.";

      if (e.response?.data != null && e.response?.data['detail'] is String) {
        errorMessage = e.response?.data['detail'];
      }

      throw Exception(errorMessage);
    }
  }

  /// Gelen 4 haneli kod ile kullanıcının şifresini sıfırlar.
  Future<bool> resetPassword(
    String email,
    String code,
    String newPassword,
  ) async {
    try {
      final response = await _dio.post(
        "/citizens/reset-password",
        data: {"email": email, "code": code, "newPassword": newPassword},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      final errorMessage =
          e.response?.data['detail'] ?? "Şifre sıfırlanırken bir sorun oluştu.";
      throw Exception(errorMessage);
    }
  }

  /// Profil içerisinden mevcut şifreyi doğrulayarak şifre değişikliği yapar.
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    try {
      final token = await _storage.read(key: "access_token");
      if (token == null) {
        throw Exception("Oturum süreniz dolmuş, lütfen tekrar giriş yapın.");
      }

      final response = await _dio.patch(
        "/citizens/change-password",
        data: {"oldPassword": oldPassword, "newPassword": newPassword},
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      final errorMessage =
          e.response?.data['detail'] ??
          "Şifre güncellenirken bir sorun oluştu.";
      throw Exception(errorMessage);
    }
  }

  /// Oturum durumunu ve token varlığını kontrol eden yardımcı metodlar.
  Future<bool> isLoggedIn() async =>
      await _storage.read(key: "access_token") != null;
  Future<String?> getToken() async => await _storage.read(key: "access_token");

  /// Dio hatalarını merkezi olarak yöneten dahili metod.
  void _handleDioError(DioException e) {
    if (e.response?.statusCode == 403) {
      // Backend'den gelen "X dakika süreyle kilitlendi" detayını alabilirsek onu göster, yoksa varsayılan metin.
      final detail = e.response?.data['detail'];
      throw Exception(
        detail ??
            "Çok fazla hatalı deneme yaptınız. Hesabınız geçici olarak kilitlenmiştir.",
      );
    }
    if (e.response?.statusCode == 401) {
      throw Exception(
        "Bilgileriniz hatalı. Lütfen kontrol edip tekrar deneyiniz.",
      );
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      throw Exception(
        "Sunucuya bağlanırken bir sorun oluştu. İnternetinizi kontrol ediniz.",
      );
    }

    // Bilinmeyen hatalar için backend detayını göstermeye çalış
    final fallbackDetail =
        e.response?.data?['detail'] ??
        "İşlem sırasında beklenmedik bir hata oluştu.";
    throw Exception(fallbackDetail.toString());
  }
}
