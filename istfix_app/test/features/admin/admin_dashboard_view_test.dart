// test/features/admin/admin_dashboard_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Projene ait importlar
import 'package:istfix_app/features/admin/admin_dashboard_view.dart';
import 'package:istfix_app/services/auth_service.dart';

// NiceMocks ile eksik metodlarda çökmesini engelliyoruz
@GenerateNiceMocks([
  MockSpec<Dio>(),
  MockSpec<FlutterSecureStorage>(),
  MockSpec<AuthService>(),
])
import 'admin_dashboard_view_test.mocks.dart';

void main() {
  late MockDio mockDio;
  late MockFlutterSecureStorage mockSecureStorage;
  late MockAuthService mockAuthService;

  setUp(() {
    mockDio = MockDio();
    mockSecureStorage = MockFlutterSecureStorage();
    mockAuthService = MockAuthService();

    // Sahte bir admin token'ı döndür
    when(
      mockSecureStorage.read(key: anyNamed('key')),
    ).thenAnswer((_) async => 'sahte_admin_token');
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: AdminDashboardView(
        dio: mockDio,
        secureStorage: mockSecureStorage,
        authService: mockAuthService,
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

  group('AdminDashboardView Widget Testleri', () {
    testWidgets(
      'Sayfa açıldığında API den raporlar çekilmeli ve ekrana çizilmelidir',
      (tester) async {
        // 1. HAZIRLIK: API'den 2 adet sahte rapor dönsün
        final mockReports = [
          {
            "id": "REP-1001",
            "processingStatus": "Pending",
            "classification": {"categoryLabel": "Yol Sorunu"},
            "writtenDescription": "Kaldırım taşı çökmüş.",
            "MUNICIPALITYId": "MUN-BESIKTAS",
          },
          {
            "id": "REP-1002",
            "processingStatus": "Resolved",
            "classification": {"categoryLabel": "Su Sorunu"},
            "writtenDescription": "Boru patlamış.",
            "MUNICIPALITYId": "MUN-KADIKOY",
          },
        ];

        when(
          mockDio.get(any, options: anyNamed('options')),
        ).thenAnswer((_) async => _createMockResponse(mockReports, 200));

        // 2. AKSİYON
        await tester.pumpWidget(createWidgetUnderTest());
        await tester
            .pumpAndSettle(); // Yükleme animasyonu bitsin ve liste çizilsin

        // 3. DOĞRULAMA: Gelen veriler ekranda mı?
        expect(find.text('REP-1001'), findsOneWidget);
        expect(find.text('Kaldırım taşı çökmüş.'), findsOneWidget);
        expect(
          find.text('Bekliyor'),
          findsOneWidget,
        ); // Status çevirisi kontrolü

        expect(find.text('REP-1002'), findsOneWidget);
        expect(
          find.text('Çözüldü'),
          findsOneWidget,
        ); // Status çevirisi kontrolü
      },
    );

    testWidgets(
      'Arama kutusuna metin yazıldığında liste doğru şekilde filtrelenmelidir',
      (tester) async {
        // 1. HAZIRLIK: 2 rapor dönsün
        final mockReports = [
          {"id": "REP-1001", "MUNICIPALITYId": "MUN-BESIKTAS"},
          {"id": "REP-1002", "MUNICIPALITYId": "MUN-KADIKOY"},
        ];

        when(
          mockDio.get(any, options: anyNamed('options')),
        ).thenAnswer((_) async => _createMockResponse(mockReports, 200));

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // İki rapor da ekranda olmalı
        expect(find.text('REP-1001'), findsOneWidget);
        expect(find.text('REP-1002'), findsOneWidget);

        // 2. AKSİYON: Arama kutusuna 'KADIKOY' yazalım
        await tester.enterText(find.byType(TextField), 'KADIKOY');
        await tester.pumpAndSettle(); // Filtreleme işlemi tamamlansın

        // 3. DOĞRULAMA: Sadece Kadıköy olan kalmalı, diğeri gizlenmeli
        expect(find.text('REP-1001'), findsNothing);
        expect(find.text('REP-1002'), findsOneWidget);
      },
    );

    testWidgets(
      'Yönet butonuna tıklandığında dialog açılmalı ve durum güncellenmelidir',
      (tester) async {
        // 1. HAZIRLIK: 1 rapor gelsin
        final mockReports = [
          {"id": "REP-1001", "processingStatus": "Pending"},
        ];

        when(
          mockDio.get(any, options: anyNamed('options')),
        ).thenAnswer((_) async => _createMockResponse(mockReports, 200));

        // Patch (Güncelleme) işlemi başarılı dönsün
        when(
          mockDio.patch(
            any,
            data: anyNamed('data'),
            options: anyNamed('options'),
          ),
        ).thenAnswer((_) async => _createMockResponse({}, 200));

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // 2. AKSİYON: 'Yönet' butonuna tıkla
        await tester.tap(find.widgetWithText(ElevatedButton, 'Yönet'));
        await tester.pumpAndSettle();

        // Dialog penceresinin açıldığını doğrula
        expect(find.text('İşlem Durumunu Güncelle'), findsOneWidget);

        // GÜNCELLEME: Ambiguous hatasını önlemek için yazıya değil direkt DropdownButton'a tıklıyoruz.
        await tester.tap(find.byType(DropdownButton<String>));
        await tester.pumpAndSettle();

        // Menü açıldıktan sonra 'Çözüldü' seçeneğini seç
        await tester.tap(find.text('Çözüldü').last);
        await tester.pumpAndSettle();

        // Şimdi 'Değişikliği Kaydet' butonuna tıkla
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Değişikliği Kaydet'),
        );
        await tester.pumpAndSettle();

        // 3. DOĞRULAMA: Durum değiştiği için Patch isteği atılmış olmalı
        verify(
          mockDio.patch(
            any,
            data: anyNamed('data'),
            options: anyNamed('options'),
          ),
        ).called(1);
        // SnackBar (Başarılı) mesajı çıkmalı
        expect(
          find.text('Rapor durumu başarıyla güncellendi!'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Çıkış yap (Logout) butonuna basıldığında oturum sonlandırılmalı',
      (tester) async {
        // 1. HAZIRLIK
        when(
          mockDio.get(any, options: anyNamed('options')),
        ).thenAnswer((_) async => _createMockResponse([], 200));

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // 2. AKSİYON: AppBar'daki çıkış ikonuna tıkla
        await tester.tap(find.byTooltip('Sistemden Çıkış Yap'));
        await tester.pumpAndSettle();

        // Dialog ekranı açıldı mı?
        expect(find.text('Oturumu Sonlandır'), findsOneWidget);

        // Çıkış Yap butonunu onayla
        await tester.tap(find.widgetWithText(ElevatedButton, 'Çıkış Yap'));
        await tester.pumpAndSettle();

        // 3. DOĞRULAMA: AuthService'in logout fonksiyonu tetiklenmiş mi?
        verify(mockAuthService.logout()).called(1);
      },
    );
  });
}
