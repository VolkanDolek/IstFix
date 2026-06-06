// test/features/report/report_detail_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:istfix_app/features/report/report_detail_view.dart';

@GenerateNiceMocks([MockSpec<Dio>(), MockSpec<FlutterSecureStorage>()])
import 'report_detail_view_test.mocks.dart';

void main() {
  late MockDio mockDio;
  late MockFlutterSecureStorage mockSecureStorage;
  const String testReportId = "12345";

  setUp(() {
    mockDio = MockDio();
    mockSecureStorage = MockFlutterSecureStorage();

    // Varsayılan olarak sahte bir token döndür
    when(
      mockSecureStorage.read(key: anyNamed('key')),
    ).thenAnswer((_) async => 'sahte_jwt_token');
  });

  // SnackBar'ın test ortamında güvenle çizilebilmesi için Scaffold eklendi
  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: Scaffold(
        body: ReportDetailView(
          reportId: testReportId,
          dio: mockDio,
          secureStorage: mockSecureStorage,
        ),
      ),
    );
  }

  Response<dynamic> _createMockResponse(dynamic data, int statusCode) {
    return Response<dynamic>(
      requestOptions: RequestOptions(path: ''),
      data: data,
      statusCode: statusCode,
    );
  }

  group('ReportDetailView Widget Testleri', () {
    testWidgets(
      'API 404 (Bulunamadı) hatası verince ekranda hata uyarı sayfası çıkmalıdır',
      (tester) async {
        // 1. HAZIRLIK: Sunucunun 404 vermesini simüle et
        when(mockDio.get(any, options: anyNamed('options'))).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: ''),
            response: Response(
              requestOptions: RequestOptions(path: ''),
              statusCode: 404,
            ),
            type: DioExceptionType.badResponse,
          ),
        );

        // 2. AKSİYON: Widget'ı yükle
        await tester.pumpWidget(createWidgetUnderTest());

        // Sayfanın yüklenmesini ve SnackBar/Hata sayfasının animasyonlarının tamamlanmasını bekle
        await tester.pumpAndSettle();

        // 3. DOĞRULAMA: Sayfa yüklenemedi hatası ekrana geldi mi?
        expect(find.text('Rapor detayları yüklenemedi.'), findsOneWidget);
        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text('Rapor veritabanında bulunamadı (404).'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Backendden gelen rapor detayı başarıyla parse edilip çizilmelidir',
      (tester) async {
        final mockJsonResponse = {
          "id": testReportId,
          "classification": {
            "categoryLabel": "Kaldırım Hasarı",
            "confidenceScore": 0.92,
          },
          "municipality": {"name": "Beşiktaş Belediyesi"},
          "writtenDescription": "Kaldırım tamamen çökmüş.",
          "latitude": 41.0422,
          "longitude": 29.0083,
          "submissionTimestamp": "2026-05-19T10:30:00Z",
          "processingStatus": "resolved",
        };

        when(
          mockDio.get(any, options: anyNamed('options')),
        ).thenAnswer((_) async => _createMockResponse(mockJsonResponse, 200));

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Kaldırım Hasarı'), findsOneWidget);
        expect(find.text('%92'), findsOneWidget);
        expect(find.text('Beşiktaş Belediyesi'), findsOneWidget);
        expect(find.text('Kaldırım tamamen çökmüş.'), findsOneWidget);
        expect(find.text('41.0422° K, 29.0083° D'), findsOneWidget);
        expect(find.text('Sorun başarıyla çözüldü.'), findsOneWidget);
      },
    );
  });
}
