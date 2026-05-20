// test/features/auth/login_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// Projene ait importlar
import 'package:istfix_app/features/auth/login_view.dart';
import 'package:istfix_app/features/main/main_tab_view.dart';
import 'package:istfix_app/features/admin/admin_main_tab_view.dart';
import 'package:istfix_app/services/auth_service.dart';

// Mock dosyası için
@GenerateMocks([AuthService])
import 'login_view_test.mocks.dart';

void main() {
  late MockAuthService mockAuthService;

  setUp(() {
    mockAuthService = MockAuthService();
  });

  // Test edilecek sayfayı sanal bir MaterialApp içine koyan yardımcı fonksiyon
  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: LoginView(authService: mockAuthService),
    );
  }

  group('LoginView Widget Testleri', () {
    testWidgets('Boş alan bırakılıp Giriş butonuna basıldığında Hata dialogu çıkmalıdır', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Hiçbir şey yazmadan doğrudan "Giriş Yap" butonuna (ElevatedButton) bas
      await tester.tap(find.widgetWithText(ElevatedButton, 'Giriş Yap'));
      await tester.pumpAndSettle(); 

      // DOĞRULAMA: Ekranda uyarı mesajı çıkmalı
      expect(find.text('Lütfen e-posta ve şifrenizi giriniz.'), findsOneWidget);
    });

    testWidgets('Başarılı Vatandaş (Citizen) girişinde MainTabView sayfasına yönlendirmelidir', (tester) async {
      when(mockAuthService.login(any, any, rememberMe: anyNamed('rememberMe')))
          .thenAnswer((_) async => true);
      when(mockAuthService.checkIsAdmin()).thenAnswer((_) async => false);

      await tester.pumpWidget(createWidgetUnderTest());

      // TextField'ları bul ve doldur
      await tester.enterText(find.byType(TextField).first, 'vatandas@istfix.com');
      await tester.enterText(find.byType(TextField).last, 'sifre123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Giriş Yap'));
      
      // GÜNCELLEME: Haritanın sonsuz yüklenmesini beklememek için manuel zaman atlatması yapıyoruz.
      await tester.pump(); 
      await tester.pump(const Duration(seconds: 1)); 

      // DOĞRULAMA: Yönlendirme yapılmış ve ana sayfa açılmış olmalı
      expect(find.byType(MainTabView), findsOneWidget);
    });

    testWidgets('Başarılı Admin girişinde AdminMainTabView sayfasına yönlendirmelidir', (tester) async {
      when(mockAuthService.login(any, any, rememberMe: anyNamed('rememberMe')))
          .thenAnswer((_) async => true);
      when(mockAuthService.checkIsAdmin()).thenAnswer((_) async => true);

      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(find.byType(TextField).first, 'admin@istfix.com');
      await tester.enterText(find.byType(TextField).last, 'admin123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Giriş Yap'));
      
      // GÜNCELLEME: Haritanın sonsuz yüklenmesini beklememek için manuel zaman atlatması yapıyoruz.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // DOĞRULAMA: Admin paneli açılmış olmalı
      expect(find.byType(AdminMainTabView), findsOneWidget);
    });

    testWidgets('Hatalı girişte (Exception) sunucudan gelen hata mesajı dialog olarak çıkmalıdır', (tester) async {
      when(mockAuthService.login(any, any, rememberMe: anyNamed('rememberMe')))
          .thenThrow(Exception('E-posta veya şifre hatalı.'));

      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(find.byType(TextField).first, 'yanlis@mail.com');
      await tester.enterText(find.byType(TextField).last, 'yanlis');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Giriş Yap'));
      await tester.pumpAndSettle();

      // DOĞRULAMA: Dialog açıldı mı ve içinde hata mesajı var mı?
      expect(find.text('E-posta veya şifre hatalı.'), findsOneWidget);
    });
  });
}