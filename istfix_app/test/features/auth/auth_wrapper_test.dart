// test/features/auth/auth_wrapper_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// Proje içi bağımlılıklar
import 'package:istfix_app/features/auth/auth_wrapper.dart';
import 'package:istfix_app/services/auth_service.dart';
import 'package:istfix_app/features/auth/login_view.dart';
import 'package:istfix_app/features/main/main_tab_view.dart';
import 'package:istfix_app/features/admin/admin_main_tab_view.dart';

// Mockito'nun otomatik üreteceği sahte sınıfların yolu
@GenerateMocks([AuthService])
import 'auth_wrapper_test.mocks.dart';

void main() {
  // Testler boyunca kullanılacak sahte (mock) servis nesnesi
  late MockAuthService mockAuthService;

  /// Her testten önce ('testWidgets' blokları) otomatik olarak çalışır.
  /// Ortamı sıfırlar ve temiz bir test başlangıcı sağlar.
  setUp(() {
    mockAuthService = MockAuthService();
  });

  /// Test edilecek ana widget'ı bir MaterialApp içine sararak döndüren yardımcı fonksiyon.
  /// Flutter'da navigasyon ve tema işlemlerinin test ortamında çökmemesi için bu sarmalama (wrapper) şarttır.
  Widget createWidgetUnderTest() {
    return MaterialApp(home: AuthWrapper(authService: mockAuthService));
  }

  group('AuthWrapper Widget Testleri (Routing & Auth Logic)', () {
    testWidgets(
      '1. Giriş yapılmamışsa (Token yoksa) LoginView sayfasına yönlendirmelidir',
      (WidgetTester tester) async {
        // [ARRANGE - HAZIRLIK]
        // Cihazın yerel hafızasında token bulunamadığı senaryoyu simüle ediyoruz.
        when(mockAuthService.shouldAutoLogin()).thenAnswer((_) async => false);

        // [ACT - AKSİYON]
        // Widget'ı sanal test ekranına çizdiriyoruz.
        await tester.pumpWidget(createWidgetUnderTest());

        // FutureBuilder'ın asenkron işlemini bitirmesi için kareyi (frame) ilerletiyoruz.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // [ASSERT - DOĞRULAMA]
        // Ekranda sadece LoginView widget'ının bulunduğunu teyit ediyoruz.
        expect(find.byType(LoginView), findsOneWidget);
      },
    );

    testWidgets(
      '2. Normal Vatandaş giriş yapmışsa MainTabView sayfasına yönlendirmelidir',
      (WidgetTester tester) async {
        // [ARRANGE - HAZIRLIK]
        // Geçerli bir token var (true) VE kullanıcı admin değil (false).
        when(mockAuthService.shouldAutoLogin()).thenAnswer((_) async => true);
        when(mockAuthService.checkIsAdmin()).thenAnswer((_) async => false);

        // [ACT - AKSİYON]
        await tester.pumpWidget(createWidgetUnderTest());

        // ÖNEMLİ NOT: Burada 'pumpAndSettle()' kullanılmamıştır!
        // Çünkü MainTabView içinde harita (flutter_map) veya animasyonlu bar (curved_navigation_bar)
        // gibi sonsuz döngüye sahip animasyonlar bulunabilir. pumpAndSettle bunların bitmesini
        // sonsuza kadar bekleyip 'Timeout' hatası verir. Bu yüzden zamanı manuel (pump ile) ilerletiyoruz.
        await tester
            .pump(); // İlk Future (shouldAutoLogin) için ekranı güncelle
        await tester.pump(
          const Duration(milliseconds: 100),
        ); // İkinci Future (checkIsAdmin) ve navigasyon için bekle

        // [ASSERT - DOĞRULAMA]
        // Vatandaş ekranının başarıyla çizildiğini teyit ediyoruz.
        expect(find.byType(MainTabView), findsOneWidget);
      },
    );

    testWidgets(
      '3. Admin yetkilisi giriş yapmışsa AdminMainTabView sayfasına yönlendirmelidir',
      (WidgetTester tester) async {
        // [ARRANGE - HAZIRLIK]
        // Geçerli bir token var (true) VE kullanıcı admin rolüne sahip (true).
        when(mockAuthService.shouldAutoLogin()).thenAnswer((_) async => true);
        when(mockAuthService.checkIsAdmin()).thenAnswer((_) async => true);

        // [ACT - AKSİYON]
        await tester.pumpWidget(createWidgetUnderTest());

        // Yönlendirmenin (FutureBuilder iç içe yapısının) tamamlanması için kare atlatıyoruz.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // [ASSERT - DOĞRULAMA]
        // Sistemin güvenli bir şekilde yönetim paneline (Admin) yönlendirdiğini doğruluyoruz.
        expect(find.byType(AdminMainTabView), findsOneWidget);
      },
    );
  });
}
