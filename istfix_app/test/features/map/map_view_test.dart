// test/features/map/map_view_test.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Projene ait importlar
import 'package:istfix_app/features/map/map_view.dart';
import 'package:istfix_app/features/report/report_list_view.dart';

// Mock dosyası için
@GenerateMocks([http.Client, FlutterSecureStorage])
import 'map_view_test.mocks.dart';

void main() {
  late MockClient mockHttpClient;
  late MockFlutterSecureStorage mockSecureStorage;

  setUp(() {
    mockHttpClient = MockClient();
    mockSecureStorage = MockFlutterSecureStorage();

    // Varsayılan olarak sahte bir token döndür
    when(mockSecureStorage.read(key: anyNamed('key')))
        .thenAnswer((_) async => 'sahte_jwt_token_harita');
  });

  // Test edilecek sayfayı sanal bir MaterialApp içine koyan yardımcı fonksiyon
  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: MapView(
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

  group('MapView Widget Testleri', () {
    testWidgets('Harita ekranı açıldığında AppBar ve Lejant(Renk bilgileri) doğru çizilmelidir', (tester) async {
      when(mockHttpClient.get(any, headers: anyNamed('headers')))
          .thenAnswer((_) async => _createMockResponse([], 200));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(); 
      await tester.pump(const Duration(seconds: 1)); 

      expect(find.text('IstFix'), findsOneWidget); 
      expect(find.text('Liste'), findsOneWidget); 
      expect(find.byType(FlutterMap), findsOneWidget); 

      expect(find.text('Yol'), findsOneWidget);
      expect(find.text('Su'), findsOneWidget);
      expect(find.text('Atık'), findsOneWidget);
      expect(find.text('Aydınlatma'), findsOneWidget);
    });

    testWidgets('Backendden gelen veriler harita üzerinde Marker (Pin) olarak çizilmelidir', (tester) async {
      final mockJsonResponse = [
        {
          "id": 1,
          "latitude": 41.015,
          "longitude": 28.979,
          "classification": {"categoryLabel": "Yol Sorunu"}
        },
        {
          "id": 2,
          "latitude": 41.025,
          "longitude": 28.989,
          "classification": {"categoryLabel": "Su Sorunu"}
        }
      ];

      when(mockHttpClient.get(any, headers: anyNamed('headers')))
          .thenAnswer((_) async => _createMockResponse(mockJsonResponse, 200));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(MarkerLayer), findsWidgets);
    });

    testWidgets('AppBar üzerindeki Liste butonuna basıldığında ReportListView sayfasına geçilmelidir', (tester) async {
      when(mockHttpClient.get(any, headers: anyNamed('headers')))
          .thenAnswer((_) async => _createMockResponse([], 200));

      await tester.pumpWidget(createWidgetUnderTest());
      
      // GÜNCELLEME: Sonsuz bekleyen pumpAndSettle kaldırıldı
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); 

      // Sağ üstteki 'Liste' butonuna tıkla
      await tester.tap(find.widgetWithText(ElevatedButton, 'Liste'));
      
      // GÜNCELLEME: Sayfa geçişini manuel atlat
      await tester.pump(); 
      await tester.pump(const Duration(seconds: 1)); 

      expect(find.byType(ReportListView), findsOneWidget);
    });

    testWidgets('API (Sunucu) çökerse harita boş kalmalı ama uygulama çökmemelidir (Hata Yönetimi)', (tester) async {
      when(mockHttpClient.get(any, headers: anyNamed('headers')))
          .thenAnswer((_) async => http.Response('Server Error', 500));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(FlutterMap), findsOneWidget);
    });
  });
}