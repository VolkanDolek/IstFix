// test/features/profile/profile_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:istfix_app/features/profile/profile_view.dart';
import 'package:istfix_app/services/auth_service.dart';
import 'package:istfix_app/features/auth/kvkk_view.dart';
import 'package:istfix_app/features/profile/change_password_view.dart';

// Mockito ile gerekli tüm servis bağımlılıklarını simüle ediyoruz
@GenerateNiceMocks([
  MockSpec<Dio>(),
  MockSpec<FlutterSecureStorage>(),
  MockSpec<AuthService>(),
])
import 'profile_view_test.mocks.dart';

void main() {
  late MockDio mockDio;
  late MockFlutterSecureStorage mockSecureStorage;
  late MockAuthService mockAuthService;

  setUp(() {
    mockDio = MockDio();
    mockSecureStorage = MockFlutterSecureStorage();
    mockAuthService = MockAuthService();

    // Güvenli depolamadan sahte token okuma davranışını ayarla
    when(
      mockSecureStorage.read(key: anyNamed('key')),
    ).thenAnswer((_) async => 'sahte_jwt_token_profil');
  });

  // Test edilecek sayfayı sanal bir MaterialApp ve Scaffold içine koyan yardımcı fonksiyon
  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: Scaffold(
        body: ProfileView(
          dio: mockDio,
          secureStorage: mockSecureStorage,
          authService: mockAuthService,
        ),
      ),
    );
  }

  // Dio Response nesnesi üreten yardımcı fonksiyon
  Response<dynamic> _createMockResponse(dynamic data, int statusCode) {
    return Response<dynamic>(
      requestOptions: RequestOptions(path: ''),
      data: data,
      statusCode: statusCode,
    );
  }

  group('ProfileView Widget Testleri', () {
    testWidgets(
      'Kullanıcı verileri API üzerinden çekilip ekrana doğru formatta yazılmalıdır',
      (tester) async {
        // 1. HAZIRLIK: API'den dönecek örnek profil bilgisi (İsim soyisim ve mail)
        final mockProfileResponse = {
          "name": "Berşan Volkan",
          "emailAddress": "bersan@example.com",
        };

        when(mockDio.get(any, options: anyNamed('options'))).thenAnswer(
          (_) async => _createMockResponse(mockProfileResponse, 200),
        );

        // 2. AKSİYON: Ekranı yükle
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle(); // Yüklenme animasyonunun bitmesini bekle

        // 3. DOĞRULAMA: Sadece ilk adın yazıldığını ("Berşan") ve mailin geldiğini doğrula
        expect(find.text('Berşan'), findsWidgets); // Profil adı ve avatar harfi
        expect(find.text('bersan@example.com'), findsOneWidget);
        expect(find.text('KVKK Aydınlatma Metni'), findsOneWidget);
        expect(find.text('Şifre değiştir'), findsOneWidget);
        expect(find.text('Çıkış Yap'), findsOneWidget);
      },
    );

    testWidgets(
      'KVKK Aydınlatma Metni seçeneğine tıklandığında KvkkView sayfasına yönlendirmelidir',
      (tester) async {
        final mockProfileResponse = {
          "name": "Berşan",
          "emailAddress": "b@b.com",
        };
        when(mockDio.get(any, options: anyNamed('options'))).thenAnswer(
          (_) async => _createMockResponse(mockProfileResponse, 200),
        );

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // KVKK satırını bul ve tıkla
        await tester.tap(find.text('KVKK Aydınlatma Metni'));
        await tester.pumpAndSettle();

        // Ekranın KvkkView yönüne değiştiğini doğrula
        expect(find.byType(KvkkView), findsOneWidget);
      },
    );

    testWidgets(
      'Şifre Değiştir seçeneğine tıklandığında ChangePasswordView sayfasına yönlendirmelidir',
      (tester) async {
        final mockProfileResponse = {
          "name": "Berşan",
          "emailAddress": "b@b.com",
        };
        when(mockDio.get(any, options: anyNamed('options'))).thenAnswer(
          (_) async => _createMockResponse(mockProfileResponse, 200),
        );

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // Şifre değiştir satırını bul ve tıkla
        await tester.tap(find.text('Şifre değiştir'));
        await tester.pumpAndSettle();

        expect(find.byType(ChangePasswordView), findsOneWidget);
      },
    );

    testWidgets(
      'Çıkış Yap seçeneğine tıklandığında onay diyalog kutusu (AlertDialog) açılmalıdır',
      (tester) async {
        final mockProfileResponse = {
          "name": "Berşan",
          "emailAddress": "b@b.com",
        };
        when(mockDio.get(any, options: anyNamed('options'))).thenAnswer(
          (_) async => _createMockResponse(mockProfileResponse, 200),
        );

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // Çıkış yap seçeneğine bas
        await tester.tap(find.text('Çıkış Yap'));
        await tester.pump(); // Diyalog kutusunun açılma animasyonunu başlat

        // Ekranda AlertDialog belirdi mi kontrol et
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.text('Oturumunuzu kapatmak istediğinize emin misiniz?'),
          findsOneWidget,
        );
      },
    );
  });
}
