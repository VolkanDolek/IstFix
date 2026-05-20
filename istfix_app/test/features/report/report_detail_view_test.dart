// test/features/report/report_detail_view_test.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Projene ait importlar
import 'package:istfix_app/features/report/report_detail_view.dart';

// Mock dosyası için
@GenerateMocks([http.Client, FlutterSecureStorage])
import 'report_detail_view_test.mocks.dart';

void main() {
  late MockClient mockHttpClient;
  late MockFlutterSecureStorage mockSecureStorage;
  const String testReportId = "12345";

  setUp(() {
    mockHttpClient = MockClient();
    mockSecureStorage = MockFlutterSecureStorage();

    // Varsayılan olarak sahte bir token döndür
    when(mockSecureStorage.read(key: anyNamed('key')))
        .thenAnswer((_) async => 'sahte_jwt_token');
  });

  // Test edilecek sayfayı sanal bir MaterialApp içine koyan yardımcı fonksiyon
  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: ReportDetailView(
        reportId: testReportId,
        httpClient: mockHttpClient,
        secureStorage: mockSecureStorage,
      ),
    );
  }

  // Yardımcı Fonksiyon: UTF-8 destekli sahte HTTP Response oluşturur
  http.Response _createMockResponse(Object data, int statusCode) {
    final jsonString = jsonEncode(data);
    return http.Response.bytes(utf8.encode(jsonString), statusCode, headers: {
      'content-type': 'application/json; charset=utf-8'
    });
  }

  group('ReportDetailView Widget Testleri', () {
    testWidgets('API 404 (Bulunamadı) hatası verince ekranda hata uyarı sayfası çıkmalıdır', (tester) async {
      // 1. HAZIRLIK: API 404 dönüyor
      when(mockHttpClient.get(any, headers: anyNamed('headers')))
          .thenAnswer((_) async => _createMockResponse({"detail": "Not found"}, 404));

      // 2. AKSİYON
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(); // API isteğini bekle

      // 3. DOĞRULAMA: Hata arayüzü ve SnackBar çıkmalı
      expect(find.text('Rapor detayları yüklenemedi.'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Rapor veritabanında bulunamadı (404).'), findsOneWidget);
    });

    testWidgets('Backendden gelen rapor detayı başarıyla parse edilip çizilmelidir', (tester) async {
      // 1. HAZIRLIK: Başarılı bir rapor detay JSON'ı dönüyor
      final mockJsonResponse = {
        "id": testReportId,
        "classification": {
          "categoryLabel": "Kaldırım Hasarı",
          "confidenceScore": 0.92 // %92 olarak ekranda görünmeli
        },
        "municipality": {
          "name": "Beşiktaş Belediyesi"
        },
        "writtenDescription": "Kaldırım tamamen çökmüş.",
        "latitude": 41.0422,
        "longitude": 29.0083,
        "submissionTimestamp": "2026-05-19T10:30:00Z",
        "processingStatus": "resolved" // Çözüldü olarak görünmeli
      };

      when(mockHttpClient.get(any, headers: anyNamed('headers')))
          .thenAnswer((_) async => _createMockResponse(mockJsonResponse, 200));

      // 2. AKSİYON
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(); // Animasyonları atla
      await tester.pump(const Duration(seconds: 1)); // SingleChildScrollView render olsun

      // 3. DOĞRULAMA: Gelen veriler ekrana doğru yerleşmiş mi?
      expect(find.text('Kaldırım Hasarı'), findsOneWidget);
      expect(find.text('%92'), findsOneWidget);
      expect(find.text('Beşiktaş Belediyesi'), findsOneWidget);
      expect(find.text('Kaldırım tamamen çökmüş.'), findsOneWidget);
      expect(find.text('41.0422° K, 29.0083° D'), findsOneWidget); // Konum formatlama kontrolü
      
      // Çözüldü durumu için gösterilen banner mesajını kontrol et
      expect(find.text('Sorun başarıyla çözüldü.'), findsOneWidget);
    });
  });
}