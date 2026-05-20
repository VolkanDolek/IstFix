// test/features/admin/municipality_management_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Projene ait importlar
import 'package:istfix_app/features/admin/municipality_management_view.dart';

// NiceMocks ile eksik metodlarda uygulamanın çökmesini engelliyoruz
@GenerateNiceMocks([
  MockSpec<Dio>(),
  MockSpec<FlutterSecureStorage>(),
])
import 'municipality_management_view_test.mocks.dart';

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
      home: MunicipalityManagementView(
        dio: mockDio,
        secureStorage: mockSecureStorage,
      ),
    );
  }

  // Dio için sahte başarılı (200/201) yanıt üreten yardımcı fonksiyon
  Response<dynamic> _createMockResponse(dynamic data, int statusCode) {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: data,
      statusCode: statusCode,
    );
  }

  group('MunicipalityManagementView Widget Testleri', () {
    testWidgets('Sayfa açıldığında API den belediyeler çekilmeli ve ekrana çizilmelidir', (tester) async {
      // 1. HAZIRLIK: API'den 2 adet sahte belediye dönsün
      final mockMunicipalities = [
        {"id": "MUN-1", "name": "Beşiktaş Belediyesi", "officialEmail": "iletisim@besiktas.bel.tr"},
        {"id": "MUN-2", "name": "Kadıköy Belediyesi", "officialEmail": "iletisim@kadikoy.bel.tr"}
      ];

      when(mockDio.get(any, options: anyNamed('options')))
          .thenAnswer((_) async => _createMockResponse(mockMunicipalities, 200));

      // 2. AKSİYON
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle(); // Yükleme bitsin ve liste çizilsin

      // 3. DOĞRULAMA: Gelen veriler ekranda mı?
      expect(find.text('Beşiktaş Belediyesi'), findsOneWidget);
      expect(find.text('iletisim@besiktas.bel.tr'), findsOneWidget);
      
      expect(find.text('Kadıköy Belediyesi'), findsOneWidget);
      expect(find.text('ID: MUN-2'), findsOneWidget);
    });

    testWidgets('Yeni Ekle butonuna tıklandığında dialog açılmalı ve POST isteği atılmalıdır', (tester) async {
      // 1. HAZIRLIK: Başlangıçta boş bir liste dönsün
      when(mockDio.get(any, options: anyNamed('options')))
          .thenAnswer((_) async => _createMockResponse([], 200));
      
      // Post işlemi başarılı (201) dönsün
      when(mockDio.post(any, data: anyNamed('data'), options: anyNamed('options')))
          .thenAnswer((_) async => _createMockResponse({}, 201));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // 2. AKSİYON: 'Yeni Ekle' butonuna tıkla
      await tester.tap(find.text('Yeni Ekle'));
      await tester.pumpAndSettle();

      // Dialog penceresinin açıldığını doğrula
      expect(find.text('Yeni Belediye Ekle'), findsOneWidget);

      // Formu doldur
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Şişli Belediyesi');
      await tester.enterText(textFields.at(1), 'info@sisli.bel.tr');
      await tester.pumpAndSettle();

      // 'Ekle' butonuna tıkla
      await tester.tap(find.widgetWithText(ElevatedButton, 'Ekle'));
      await tester.pumpAndSettle();

      // 3. DOĞRULAMA: POST isteği atılmış olmalı
      verify(mockDio.post(
        any,
        data: {"name": "Şişli Belediyesi", "officialEmail": "info@sisli.bel.tr"},
        options: anyNamed('options'),
      )).called(1);
      
      expect(find.text('Belediye başarıyla eklendi.'), findsOneWidget);
    });

    testWidgets('Düzenle (Kalem) butonuna tıklandığında dialog açılmalı ve PATCH isteği atılmalıdır', (tester) async {
      // 1. HAZIRLIK
      final mockMunicipalities = [
        {"id": "MUN-99", "name": "Eski Belediye", "officialEmail": "eski@bel.tr"}
      ];

      when(mockDio.get(any, options: anyNamed('options')))
          .thenAnswer((_) async => _createMockResponse(mockMunicipalities, 200));
      
      when(mockDio.patch(any, data: anyNamed('data'), options: anyNamed('options')))
          .thenAnswer((_) async => _createMockResponse({}, 200));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // 2. AKSİYON
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      // Dialog penceresinin açıldığını doğrula
      expect(find.text('Belediye Düzenle'), findsOneWidget);

      // GÜNCELLEME: Sadece dialog içindeki öğeleri arıyoruz (Çakışmayı önlemek için)
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('ID: MUN-99')), findsOneWidget);
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Eski Belediye')), findsOneWidget);

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Yeni Belediye');
      await tester.enterText(textFields.at(1), 'yeni@bel.tr');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Güncelle'));
      await tester.pumpAndSettle();

      // 3. DOĞRULAMA
      verify(mockDio.patch(
        '/municipalities/MUN-99',
        data: {"name": "Yeni Belediye", "officialEmail": "yeni@bel.tr"},
        options: anyNamed('options'),
      )).called(1);
      
      expect(find.text('Belediye başarıyla güncellendi.'), findsOneWidget);
    });
  });
}