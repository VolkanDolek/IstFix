// test/features/report/map_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart'; // GÜNCELLEME: http yerine dio eklendi
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Projene ait importlar
import 'package:istfix_app/features/map/map_view.dart';
import 'package:istfix_app/features/report/report_list_view.dart';
import 'package:istfix_app/features/report/report_detail_view.dart';

// GÜNCELLEME: MockHttpClient yerine MockDio üretiyoruz
@GenerateNiceMocks([MockSpec<Dio>(), MockSpec<FlutterSecureStorage>()])
import 'map_view_test.mocks.dart';

void main() {
  late MockDio mockDio;
  late MockFlutterSecureStorage mockSecureStorage;

  setUp(() {
    mockDio = MockDio();
    mockSecureStorage = MockFlutterSecureStorage();

    // Varsayılan olarak sahte bir token döndür
    when(
      mockSecureStorage.read(key: anyNamed('key')),
    ).thenAnswer((_) async => 'sahte_jwt_token_harita');
  });

  // Test edilecek sayfayı sanal bir MaterialApp içine koyan yardımcı fonksiyon
  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: MapView(
        dio: mockDio, // GÜNCELLEME: httpClient yerine dio parametresi veriliyor
        secureStorage: mockSecureStorage,
      ),
    );
  }

  // GÜNCELLEME: Dio Response nesnesi üreten yardımcı fonksiyon
  Response<dynamic> _createMockResponse(dynamic data, int statusCode) {
    return Response<dynamic>(
      requestOptions: RequestOptions(path: ''),
      data:
          data, // Dio otomatik parse ettiği için doğrudan listeyi/objeyi veriyoruz
      statusCode: statusCode,
    );
  }

  group('MapView Widget Testleri', () {
    testWidgets(
      'Harita ekranı açıldığında AppBar ve Lejant doğru çizilmelidir',
      (tester) async {
        // GÜNCELLEME: Dio.get isteği mocklandı
        when(
          mockDio.get(any, options: anyNamed('options')),
        ).thenAnswer((_) async => _createMockResponse([], 200));

        await tester.pumpWidget(createWidgetUnderTest());

        // Harita animasyonlarını atlatmak için manuel bekleme
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('IstFix'), findsOneWidget);
        expect(find.text('Liste'), findsOneWidget);
        expect(find.byType(FlutterMap), findsOneWidget);

        // Lejant kontrolleri
        expect(find.text('Yol'), findsOneWidget);
        expect(find.text('Su'), findsOneWidget);
        expect(find.text('Atık'), findsOneWidget);
        expect(find.text('Aydınlatma'), findsOneWidget);
      },
    );

    testWidgets(
      'Backendden gelen veriler harita üzerinde Marker (Pin) olarak çizilmelidir',
      (tester) async {
        final mockJsonResponse = [
          {
            "id": "R1",
            "latitude": 41.015,
            "longitude": 28.979,
            "classification": {"categoryLabel": "Yol Sorunu"},
          },
          {
            "id": "R2",
            "latitude": 41.025,
            "longitude": 28.989,
            "classification": {"categoryLabel": "Su Sorunu"},
          },
        ];

        when(
          mockDio.get(any, options: anyNamed('options')),
        ).thenAnswer((_) async => _createMockResponse(mockJsonResponse, 200));

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(MarkerLayer), findsWidgets);
      },
    );

    testWidgets(
      'AppBar üzerindeki Liste butonuna basıldığında ReportListView sayfasına geçilmelidir',
      (tester) async {
        when(
          mockDio.get(any, options: anyNamed('options')),
        ).thenAnswer((_) async => _createMockResponse([], 200));

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Sağ üstteki 'Liste' butonuna tıkla
        await tester.tap(find.widgetWithText(ElevatedButton, 'Liste'));

        // Sayfa geçişini bekle
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(ReportListView), findsOneWidget);
      },
    );

    testWidgets(
      'Haritadaki bir pine (Marker) tıklandığında ReportDetailView sayfasına geçilmelidir',
      (tester) async {
        // 1. HAZIRLIK: API'den 1 adet rapor dönsün
        final mockJsonResponse = [
          {
            "id": "REP-99",
            "latitude": 41.015,
            "longitude": 28.979,
            "classification": {"categoryLabel": "Çevre Kirliliği"},
          },
        ];

        when(
          mockDio.get(any, options: anyNamed('options')),
        ).thenAnswer((_) async => _createMockResponse(mockJsonResponse, 200));

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // 2. AKSİYON: Haritaya çizilen o pini (GestureDetector'ü) bul ve tıkla
        final markerFinder = find.descendant(
          of: find.byType(MarkerLayer),
          matching: find.byType(GestureDetector),
        );

        expect(markerFinder, findsWidgets); // Pin haritada var mı kontrolü

        await tester.tap(markerFinder.first); // Pine tıkla

        // Sayfa geçiş animasyonunu manuel bekle
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // 3. DOĞRULAMA: Detay sayfası (ReportDetailView) açıldı mı?
        expect(find.byType(ReportDetailView), findsOneWidget);
      },
    );

    testWidgets(
      'API (Sunucu) çökerse harita boş kalmalı ama uygulama çökmemelidir',
      (tester) async {
        // 1. HAZIRLIK: Sunucu hatası simülasyonu (DioException fırlatılır)
        when(mockDio.get(any, options: anyNamed('options'))).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: ''),
            response: Response(
              requestOptions: RequestOptions(path: ''),
              statusCode: 500,
            ),
            type: DioExceptionType.badResponse,
          ),
        );

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // 2. DOĞRULAMA: Uygulama çökmedi, harita (FlutterMap) ekranda duruyor
        expect(find.byType(FlutterMap), findsOneWidget);
      },
    );
  });
}
