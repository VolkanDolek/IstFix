// test/features/report/report_list_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart'; // GÜNCELLEME: http yerine dio eklendi
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Projene ait importlar
import 'package:istfix_app/features/report/report_list_view.dart';

// Mock dosyası için
// GÜNCELLEME: MockHttpClient yerine NiceMocks ile MockDio üretiyoruz
@GenerateNiceMocks([MockSpec<Dio>(), MockSpec<FlutterSecureStorage>()])
import 'report_list_view_test.mocks.dart';

void main() {
  late MockDio mockDio;
  late MockFlutterSecureStorage mockSecureStorage;

  setUp(() {
    mockDio = MockDio();
    mockSecureStorage = MockFlutterSecureStorage();

    // Varsayılan olarak sahte bir token döndür
    when(
      mockSecureStorage.read(key: anyNamed('key')),
    ).thenAnswer((_) async => 'sahte_jwt_token');
  });

  // Test edilecek sayfayı sanal bir MaterialApp içine koyan yardımcı fonksiyon
  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: ReportListView(
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

  group('ReportListView Widget Testleri', () {
    testWidgets(
      'Rapor listesi boş geldiğinde (Empty State) boş durum ekranını göstermelidir',
      (tester) async {
        when(
          mockDio.get(any, options: anyNamed('options')),
        ).thenAnswer((_) async => _createMockResponse([], 200));

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.text('Daha önce gönderilmiş raporunuz bulunmamaktadır.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'API hata (500) verdiğinde uygulamanın çökmeden boş liste göstermelidir',
      (tester) async {
        // GÜNCELLEME: Sunucu 500 hatası simülasyonu DioException ile değiştirildi
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

        expect(
          find.text('Daha önce gönderilmiş raporunuz bulunmamaktadır.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('Backendden gelen verileri başarıyla işleyip listelemelidir', (
      tester,
    ) async {
      final mockJsonResponse = [
        {
          "id": 101,
          "classification": {"categoryLabel": "Çukur (Yol)"},
          "municipality": {"name": "Kadıköy Belediyesi"},
          "submissionTimestamp": "2026-05-19T10:30:00Z",
          "processingStatus": "in_progress",
        },
      ];

      when(
        mockDio.get(any, options: anyNamed('options')),
      ).thenAnswer((_) async => _createMockResponse(mockJsonResponse, 200));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Çukur (Yol)'), findsOneWidget);
      expect(find.text('Kadıköy Belediyesi'), findsOneWidget);
      expect(find.text('İşleme Alındı'), findsOneWidget);
    });

    testWidgets(
      'Tümü filtresinden Yol filtresine geçişte liste filtrelenmelidir',
      (tester) async {
        final mockJsonResponse = [
          {
            "id": 1,
            "classification": {"categoryLabel": "Asfalt Bozukluğu (Yol)"},
            "processingStatus": "Pending",
          },
          {
            "id": 2,
            "classification": {"categoryLabel": "Su Patlağı"},
            "processingStatus": "Pending",
          },
        ];

        when(
          mockDio.get(any, options: anyNamed('options')),
        ).thenAnswer((_) async => _createMockResponse(mockJsonResponse, 200));

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Asfalt Bozukluğu (Yol)'), findsOneWidget);
        expect(find.text('Su Patlağı'), findsOneWidget);

        await tester.tap(find.text('Yol'));
        await tester.pump();

        expect(find.text('Asfalt Bozukluğu (Yol)'), findsOneWidget);
        expect(find.text('Su Patlağı'), findsNothing);
      },
    );
  });
}
