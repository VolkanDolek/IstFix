// test/features/admin/admin_users_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Projene ait importlar
import 'package:istfix_app/features/admin/admin_users_view.dart';

// NiceMocks ile eksik metodlarda uygulamanın çökmesini engelliyoruz
@GenerateNiceMocks([
  MockSpec<Dio>(),
  MockSpec<FlutterSecureStorage>(),
])
import 'admin_users_view_test.mocks.dart';

void main() {
  late MockDio mockDio;
  late MockFlutterSecureStorage mockSecureStorage;

  setUp(() {
    mockDio = MockDio();
    mockSecureStorage = MockFlutterSecureStorage();

    // Sahte bir admin token'ı döndür
    when(mockSecureStorage.read(key: anyNamed('key')))
        .thenAnswer((_) async => 'sahte_admin_token');
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: AdminUsersView(
        dio: mockDio,
        secureStorage: mockSecureStorage,
      ),
    );
  }

  // Dio için sahte başarılı (200) yanıt üreten yardımcı fonksiyon
  Response<dynamic> _createMockResponse(dynamic data, int statusCode) {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: data,
      statusCode: statusCode,
    );
  }

  group('AdminUsersView Widget Testleri', () {
    testWidgets('Sayfa açıldığında API den kullanıcılar çekilmeli ve ekrana çizilmelidir', (tester) async {
      final mockUsers = [
        {
          "id": "USR-1001",
          "name": "Ahmet Yılmaz",
          "emailAddress": "ahmet@mail.com",
          "isAdmin": false
        },
        {
          "id": "USR-1002",
          "name": "Zeynep Demir",
          "emailAddress": "zeynep@mail.com",
          "isAdmin": true
        }
      ];

      when(mockDio.get(any, options: anyNamed('options')))
          .thenAnswer((_) async => _createMockResponse(mockUsers, 200));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle(); 

      expect(find.text('Ahmet Yılmaz'), findsOneWidget);
      expect(find.text('ahmet@mail.com'), findsOneWidget);
      
      expect(find.text('Zeynep Demir'), findsOneWidget);
      expect(find.text('ADMİN'), findsOneWidget);
    });

    // YENİ EKLENEN TEST SENARYOSU
    testWidgets('Admin olan kullanıcılarda silme butonu gizlenmeli ve Silinemez etiketi çıkmalıdır', (tester) async {
      // 1. HAZIRLIK: 1 normal, 1 admin kullanıcı gelsin
      final mockUsers = [
        {"id": "USR-1", "name": "Normal Vatandaş", "isAdmin": false},
        {"id": "USR-2", "name": "Sistem Yöneticisi", "isAdmin": true}
      ];

      when(mockDio.get(any, options: anyNamed('options')))
          .thenAnswer((_) async => _createMockResponse(mockUsers, 200));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // 2. DOĞRULAMA
      // Ekranda sadece 1 tane "Hesabı Sil" butonu olmalı (O da Normal Vatandaş için)
      expect(find.widgetWithText(ElevatedButton, 'Hesabı Sil'), findsOneWidget);
      
      // Ekranda 1 tane "Silinemez" yazısı olmalı (O da Sistem Yöneticisi için)
      expect(find.text('Silinemez'), findsOneWidget);
      
      // Ayrıca kilit ikonunun da ekranda olduğunu doğrulayalım
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('Arama kutusuna metin yazıldığında kullanıcı listesi filtrelenmelidir', (tester) async {
      final mockUsers = [
        {"id": "USR-1", "name": "Ahmet Yılmaz", "emailAddress": "ahmet@mail.com"},
        {"id": "USR-2", "name": "Zeynep Demir", "emailAddress": "zeynep@mail.com"}
      ];

      when(mockDio.get(any, options: anyNamed('options')))
          .thenAnswer((_) async => _createMockResponse(mockUsers, 200));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Zeynep');
      await tester.pumpAndSettle(); 

      expect(find.text('Zeynep Demir'), findsOneWidget);
      expect(find.text('Ahmet Yılmaz'), findsNothing);
    });

    testWidgets('Hesabı Sil butonuna tıklandığında onay dialogu açılmalı ve silme işlemi yapılmalıdır', (tester) async {
      final mockUsers = [
        {"id": "USR-999", "name": "Silinecek Kullanıcı", "emailAddress": "sil@mail.com", "isAdmin": false}
      ];

      when(mockDio.get(any, options: anyNamed('options')))
          .thenAnswer((_) async => _createMockResponse(mockUsers, 200));
      
      when(mockDio.delete(any, options: anyNamed('options')))
          .thenAnswer((_) async => _createMockResponse({}, 200));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Hesabı Sil'));
      await tester.pumpAndSettle();

      expect(find.text('Kullanıcıyı Sil'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Kalıcı Olarak Sil'));
      await tester.pumpAndSettle();

      verify(mockDio.delete(any, options: anyNamed('options'))).called(1);
      
      expect(find.text('Kullanıcı hesabı sistemden başarıyla silindi.'), findsOneWidget);
    });
  });
}