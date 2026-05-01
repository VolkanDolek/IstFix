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

  /// Kullanıcı giriş işlemini gerçekleştirir ve JWT token'ı güvenli depolamaya kaydeder.
  Future<bool> login(String email, String password) async {
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
        await _storage.write(key: "jwt_token", value: token);
        return true;
      }
      return false;
    } on DioException catch (e) {
      _handleDioError(e);
      return false; // Hata fırlatılmazsa false dön
    }
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

  /// Mevcut oturumu sonlandırır ve yerel verileri temizler.
  Future<void> logout() async {
    try {
      final token = await _storage.read(key: "jwt_token");
      if (token != null) {
        await _dio.post(
          "/auth/logout",
          options: Options(headers: {"Authorization": "Bearer $token"}),
        );
      }
    } catch (_) {
      // Sunucu tarafında hata olsa bile yerel temizliğe devam edilir.
    } finally {
      await _storage.delete(key: "jwt_token");
    }
  }

  /// Oturum durumunu ve token varlığını kontrol eden yardımcı metodlar.
  Future<bool> isLoggedIn() async =>
      await _storage.read(key: "jwt_token") != null;
  Future<String?> getToken() async => await _storage.read(key: "jwt_token");

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
