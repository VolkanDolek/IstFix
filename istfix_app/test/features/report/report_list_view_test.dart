// test/features/report/report_list_view_test.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Projene ait importlar
import 'package:istfix_app/features/report/report_list_view.dart';

// Mock dosyası için
@GenerateMocks([http.Client, FlutterSecureStorage])
import 'report_list_view_test.mocks.dart';

void main() {
  late MockClient mockHttpClient;
  late MockFlutterSecureStorage mockSecureStorage;

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
      home: ReportListView(
        httpClient: mockHttpClient,
        secureStorage: mockSecureStorage,
      ),
    );
  }

  // Yardımcı Fonksiyon: UTF-8 destekli sahte HTTP Response oluşturur
  http.Response _createMockResponse(Object data, int statusCode) {
    final jsonString = jsonEncode(data);
    // Türkçe karakterlerin (Ç, Ş, vb.) patlamaması için utf8'e çevirip byte olarak veriyoruz
    return http.Response.bytes(utf8.encode(jsonString), statusCode, headers: {
      'content-type': 'application/json; charset=utf-8'
    });
  }

  group('ReportListView Widget Testleri', () {
    testWidgets('Rapor listesi boş geldiğinde (Empty State) boş durum ekranını göstermelidir', (tester) async {
      when(mockHttpClient.get(any, headers: anyNamed('headers')))
          .thenAnswer((_) async => _createMockResponse([], 200));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Daha önce gönderilmiş raporunuz bulunmamaktadır.'), findsOneWidget);
    });

    testWidgets('API hata (500) verdiğinde uygulamanın çökmeden boş liste göstermelidir', (tester) async {
      when(mockHttpClient.get(any, headers: anyNamed('headers')))
          .thenAnswer((_) async => http.Response('Internal Server Error', 500));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Daha önce gönderilmiş raporunuz bulunmamaktadır.'), findsOneWidget);
    });

    testWidgets('Backendden gelen verileri başarıyla işleyip listelemelidir', (tester) async {
      final mockJsonResponse = [
        {
          "id": 101,
          "classification": {"categoryLabel": "Çukur (Yol)"},
          "municipality": {"name": "Kadıköy Belediyesi"},
          "submissionTimestamp": "2026-05-19T10:30:00Z",
          "processingStatus": "in_progress"
        }
      ];

      when(mockHttpClient.get(any, headers: anyNamed('headers')))
          .thenAnswer((_) async => _createMockResponse(mockJsonResponse, 200));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(); 
      await tester.pump(const Duration(seconds: 1)); 

      expect(find.text('Çukur (Yol)'), findsOneWidget); 
      expect(find.text('Kadıköy Belediyesi'), findsOneWidget); 
      expect(find.text('İşleme Alındı'), findsOneWidget); 
    });

    testWidgets('Tümü filtresinden Yol filtresine geçişte liste filtrelenmelidir', (tester) async {
      final mockJsonResponse = [
        {
          "id": 1,
          "classification": {"categoryLabel": "Asfalt Bozukluğu (Yol)"},
          "processingStatus": "Pending"
        },
        {
          "id": 2,
          "classification": {"categoryLabel": "Su Patlağı"},
          "processingStatus": "Pending"
        }
      ];

      when(mockHttpClient.get(any, headers: anyNamed('headers')))
          .thenAnswer((_) async => _createMockResponse(mockJsonResponse, 200));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Asfalt Bozukluğu (Yol)'), findsOneWidget);
      expect(find.text('Su Patlağı'), findsOneWidget);

      await tester.tap(find.text('Yol'));
      await tester.pump(); 

      expect(find.text('Asfalt Bozukluğu (Yol)'), findsOneWidget);
      expect(find.text('Su Patlağı'), findsNothing);
    });
  });
}