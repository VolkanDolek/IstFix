import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:istfix_app/main.dart';

/// Uygulama genelindeki tüm API isteklerini yöneten merkezi (Singleton) ağ sınıfı.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  late final Dio dio;
  final _storage = const FlutterSecureStorage();

  // Her yerden aynı örneğe (instance) ulaşılmasını sağlar
  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: "http://10.0.2.2:8000/api",
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    // BÜTÜN UYGULAMAYI KORUYAN MERKEZİ KALKAN BURADA!
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, handler) async {
          if ((e.response?.statusCode == 401 ||
                  e.response?.statusCode == 403) &&
              !e.requestOptions.path.contains("/auth/login")) {
            // Temizlik
            await _storage.delete(key: "access_token");
            await _storage.delete(key: "remember_me");
            await _storage.delete(key: "is_admin");

            // Kullanıcıyı nerede olursa olsun Login'e fırlat
            navigatorKey.currentState?.pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          }
          return handler.next(e);
        },
      ),
    );
  }
}
