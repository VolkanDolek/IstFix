// test/features/admin/admin_main_tab_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Projene ait import
import 'package:istfix_app/features/admin/admin_main_tab_view.dart';

void main() {
  // Test için gerçek karmaşık sayfalar yerine, sadece içi yazı dolu basit sayfalar kullanıyoruz.
  // Bu sayede API istekleri veya karmaşık durum yönetimleriyle (Dio, SecureStorage) uğraşmıyoruz.
  final List<Widget> mockPages = [
    const Center(child: Text('Sahte Raporlar Sayfası')),
    const Center(child: Text('Sahte Belediyeler Sayfası')),
    const Center(child: Text('Sahte Vatandaşlar Sayfası')),
  ];

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: AdminMainTabView(
        mockPages: mockPages,
      ),
    );
  }

  group('AdminMainTabView Widget Testleri', () {
    testWidgets('Sayfa ilk açıldığında 1. sekme (Raporlar) görünür olmalıdır', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // 1. DOĞRULAMA: Menü butonları ekranda mı?
      expect(find.text('Raporlar'), findsOneWidget);
      expect(find.text('Belediyeler'), findsOneWidget);
      expect(find.text('Vatandaşlar'), findsOneWidget);

      // 2. DOĞRULAMA: İlk sekmenin (0. index) içeriği ekranda görünür mü?
      expect(find.text('Sahte Raporlar Sayfası'), findsOneWidget);
    });

    testWidgets('Belediyeler sekmesine tıklandığında sayfa içeriği değişmelidir', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // 1. AKSİYON: Alt menüden 'Belediyeler' yazısına tıkla
      await tester.tap(find.text('Belediyeler'));
      await tester.pumpAndSettle(); // Sayfa geçiş animasyonunu bekle

      // 2. DOĞRULAMA: Artık ekranda belediyeler sayfası olmalı, raporlar sayfası gizlenmiş (Offstage) olmalı
      expect(find.text('Sahte Belediyeler Sayfası'), findsOneWidget);
      expect(find.text('Sahte Raporlar Sayfası'), findsNothing);
    });

    testWidgets('Vatandaşlar sekmesine tıklandığında sayfa içeriği değişmelidir', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // 1. AKSİYON: Alt menüden 'Vatandaşlar' yazısına tıkla
      await tester.tap(find.text('Vatandaşlar'));
      await tester.pumpAndSettle();

      // 2. DOĞRULAMA: Vatandaşlar sayfası aktif olmalı
      expect(find.text('Sahte Vatandaşlar Sayfası'), findsOneWidget);
      expect(find.text('Sahte Raporlar Sayfası'), findsNothing);
    });
  });
}