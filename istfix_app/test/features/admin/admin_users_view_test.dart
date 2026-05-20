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
      // 1. HAZIRLIK: API'den biri admin diğeri normal 2 adet sahte vatandaş dönsün
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
          "isAdmin": true // Bu kullanıcı admin
        }
      ];

      when(mockDio.get(any, options: anyNamed('options')))
          .thenAnswer((_) async => _createMockResponse(mockUsers, 200));

      // 2. AKSİYON
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle(); // Yükleme bitsin ve liste çizilsin

      // 3. DOĞRULAMA: Gelen veriler ekranda mı?
      expect(find.text('Ahmet Yılmaz'), findsOneWidget);
      expect(find.text('ahmet@mail.com'), findsOneWidget);
      
      expect(find.text('Zeynep Demir'), findsOneWidget);
      // Zeynep admin olduğu için ekranda ADMİN etiketi görünmeli
      expect(find.text('ADMİN'), findsOneWidget);
    });

    testWidgets('Arama kutusuna metin yazıldığında kullanıcı listesi filtrelenmelidir', (tester) async {
      // 1. HAZIRLIK: 2 kullanıcı dönsün
      final mockUsers = [
        {"id": "USR-1", "name": "Ahmet Yılmaz", "emailAddress": "ahmet@mail.com"},
        {"id": "USR-2", "name": "Zeynep Demir", "emailAddress": "zeynep@mail.com"}
      ];

      when(mockDio.get(any, options: anyNamed('options')))
          .thenAnswer((_) async => _createMockResponse(mockUsers, 200));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Ahmet Yılmaz'), findsOneWidget);
      expect(find.text('Zeynep Demir'), findsOneWidget);

      // 2. AKSİYON: Arama kutusuna 'Zeynep' yazalım
      await tester.enterText(find.byType(TextField), 'Zeynep');
      await tester.pumpAndSettle(); // Filtreleme tamamlansın

      // 3. DOĞRULAMA: Sadece Zeynep kalmalı, Ahmet gizlenmeli
      expect(find.text('Zeynep Demir'), findsOneWidget);
      expect(find.text('Ahmet Yılmaz'), findsNothing);
    });

    testWidgets('Hesabı Sil butonuna tıklandığında onay dialogu açılmalı ve silme işlemi yapılmalıdır', (tester) async {
      // 1. HAZIRLIK: 1 kullanıcı gelsin
      final mockUsers = [
        {"id": "USR-999", "name": "Silinecek Kullanıcı", "emailAddress": "sil@mail.com"}
      ];

      when(mockDio.get(any, options: anyNamed('options')))
          .thenAnswer((_) async => _createMockResponse(mockUsers, 200));
      
      // Delete işlemi başarılı (200) dönsün
      when(mockDio.delete(any, options: anyNamed('options')))
          .thenAnswer((_) async => _createMockResponse({}, 200));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // 2. AKSİYON: 'Hesabı Sil' butonuna tıkla
      await tester.tap(find.widgetWithText(ElevatedButton, 'Hesabı Sil'));
      await tester.pumpAndSettle();

      // Dialog penceresinin açıldığını doğrula
      expect(find.text('Kullanıcıyı Sil'), findsOneWidget);
      expect(find.textContaining('hesabını sistemden kalıcı olarak silmek istediğinize emin misiniz?'), findsOneWidget);

      // 'Kalıcı Olarak Sil' butonuna tıkla
      await tester.tap(find.widgetWithText(ElevatedButton, 'Kalıcı Olarak Sil'));
      await tester.pumpAndSettle();

      // 3. DOĞRULAMA: DELETE isteği atılmış olmalı
      verify(mockDio.delete(any, options: anyNamed('options'))).called(1);
      
      // SnackBar (Başarılı) mesajı çıkmalı
      expect(find.text('Kullanıcı hesabı sistemden başarıyla silindi.'), findsOneWidget);
    });
  });
}