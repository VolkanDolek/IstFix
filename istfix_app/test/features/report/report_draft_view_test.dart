// test/features/report/report_draft_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart'; // GÜNCELLEME: http yerine dio eklendi
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:istfix_app/features/report/report_draft_view.dart';

// GÜNCELLEME: Test ortamında Dio'yu mocklayabilmek için ekleme yapıldı
@GenerateNiceMocks([MockSpec<Dio>(), MockSpec<FlutterSecureStorage>()])
import 'report_draft_view_test.mocks.dart';

void main() {
  // GÜNCELLEME: MockDio tanımı eklendi
  late MockDio mockDio;
  late MockFlutterSecureStorage mockSecureStorage;

  setUp(() {
    mockDio = MockDio();
    mockSecureStorage = MockFlutterSecureStorage();
    when(
      mockSecureStorage.read(key: anyNamed('key')),
    ).thenAnswer((_) async => 'sahte_token');
  });

  // Basit bir test konumu
  final mockPosition = Position(
    latitude: 41.0,
    longitude: 29.0,
    timestamp: DateTime.now(),
    accuracy: 0,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: ReportDraftView(
        imagePath:
            'test_image.jpg', // Test dosya yolu (dosya sisteminde olmasına gerek yok, widget için yeterli)
        position: mockPosition,
        secureStorage: mockSecureStorage,
        dio: mockDio, // GÜNCELLEME: Yenilenen sayfaya mockDio enjekte ediliyor
      ),
    );
  }

  group('ReportDraftView Widget Testleri', () {
    testWidgets('Sayfa yüklendiğinde gerekli UI elemanları görünmelidir', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // UI elemanlarını kontrol et
      expect(find.text("Rapor Taslağı"), findsOneWidget);
      expect(find.text("Açıklama ekleyin (isteğe bağlı)"), findsOneWidget);
      expect(find.text("Gönder"), findsOneWidget);
    });

    testWidgets(
      'Gönder butonuna tıklandığında açıklama yazısı eklenebilmelidir',
      (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        final descriptionField = find.byType(TextField);
        await tester.enterText(descriptionField, "Burada bir sorun var!");

        expect(find.text("Burada bir sorun var!"), findsOneWidget);
      },
    );
  });
}
