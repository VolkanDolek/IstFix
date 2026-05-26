// test/services/auth_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Test edilecek servis
import 'package:istfix_app/services/auth_service.dart';

@GenerateNiceMocks([MockSpec<Dio>(), MockSpec<FlutterSecureStorage>()])
import 'auth_service_test.mocks.dart';

void main() {
  late MockDio mockDio;
  late MockFlutterSecureStorage mockSecureStorage;
  late AuthService authService;

  setUp(() {
    mockDio = MockDio();
    mockSecureStorage = MockFlutterSecureStorage();

    // Test edilecek servise sahte bağımlılıkları enjekte ediyoruz
    authService = AuthService(dio: mockDio, secureStorage: mockSecureStorage);
  });

  Response<dynamic> _createMockResponse(dynamic data, int statusCode) {
    return Response<dynamic>(
      requestOptions: RequestOptions(path: ''),
      data: data,
      statusCode: statusCode,
    );
  }

  group('AuthService Birim (Unit) Testleri', () {
    test(
      'Başarılı giriş (200 OK) senaryosunda token ve rol yerel hafızaya yazılmalıdır',
      () async {
        // 1. HAZIRLIK: Login ve Profil isteklerinin sahte yanıtlarını hazırla
        final loginResponseData = {"access_token": "mock_access_token_123"};
        final profileResponseData = {"isAdmin": true};

        // İlk atılan post isteğine loginResponseData döndür
        when(
          mockDio.post(
            any,
            data: anyNamed('data'),
            options: anyNamed('options'),
          ),
        ).thenAnswer((_) async => _createMockResponse(loginResponseData, 200));

        // Hemen ardından atılan get profil isteğine profileResponseData döndür
        when(mockDio.get(any, options: anyNamed('options'))).thenAnswer(
          (_) async => _createMockResponse(profileResponseData, 200),
        );

        // 2. AKSİYON: Giriş fonksiyonunu tetikle
        final result = await authService.login("test@test.com", "123456");

        // 3. DOĞRULAMA: Süreçlerin başarı durumlarını ve storage yazımlarını kontrol et
        expect(result, true);
        verify(
          mockSecureStorage.write(
            key: "access_token",
            value: "mock_access_token_123",
          ),
        ).called(1);
        verify(
          mockSecureStorage.write(key: "is_admin", value: "true"),
        ).called(1);
      },
    );

    test(
      'Hatalı giriş (401 Unauthorized) durumunda kullanıcıya özel hata fırlatılmalıdır',
      () async {
        // 1. HAZIRLIK: Dio'nun 401 hatası fırlatmasını sağla
        when(
          mockDio.post(
            any,
            data: anyNamed('data'),
            options: anyNamed('options'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: ''),
            response: Response(
              requestOptions: RequestOptions(path: ''),
              statusCode: 401,
            ),
            type: DioExceptionType.badResponse,
          ),
        );

        // 2. AKSİYON & DOĞRULAMA: Özel hata mesajının fırlatıldığını teyit et
        expect(
          () async => await authService.login("wrong@test.com", "wrong_pass"),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'description',
              contains('Bilgileriniz hatalı'),
            ),
          ),
        );
      },
    );

    test(
      'Hesap kilitlendiğinde (403 Forbidden) kilitlenme uyarı mesajı fırlatılmalıdır',
      () async {
        // 1. HAZIRLIK: Dio'nun 403 hatası fırlatmasını sağla (data map'ini ekleyerek null hatasını önlüyoruz)
        when(
          mockDio.post(
            any,
            data: anyNamed('data'),
            options: anyNamed('options'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: ''),
            response: Response(
              requestOptions: RequestOptions(path: ''),
              statusCode: 403,
              data: {
                'detail':
                    'Çok fazla hatalı deneme yaptınız. Hesabınız geçici olarak kilitlenmiştir.',
              }, // GÜNCELLEME: data eklendi
            ),
            type: DioExceptionType.badResponse,
          ),
        );

        // 2. AKSİYON & DOĞRULAMA
        expect(
          () async => await authService.login("locked@test.com", "123"),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'description',
              contains('Hesabınız geçici olarak kilitlenmiştir'),
            ),
          ),
        );
      },
    );

    test(
      'Çıkış yapıldığında (logout) lokal hafızadaki tüm hassas anahtarlar temizlenmelidir',
      () async {
        // 1. HAZIRLIK: Hafızada eski bir token varmış gibi davran
        when(
          mockSecureStorage.read(key: "access_token"),
        ).thenAnswer((_) async => "eski_token");
        when(
          mockDio.post(any, options: anyNamed('options')),
        ).thenAnswer((_) async => _createMockResponse({}, 200));

        // 2. AKSİYON
        await authService.logout();

        // 3. DOĞRULAMA: delete metotlarının çağrıldığını doğrula
        verify(mockSecureStorage.delete(key: "access_token")).called(1);
        verify(mockSecureStorage.delete(key: "remember_me")).called(1);
        verify(mockSecureStorage.delete(key: "is_admin")).called(1);
      },
    );
  });
}
