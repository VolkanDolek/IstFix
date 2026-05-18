// test/features/main/connectivity_wrapper_test.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';

// Projene ait importlar
import 'package:istfix_app/features/main/connectivity_wrapper.dart';
import 'package:istfix_app/features/shared/no_connection_view.dart';
import 'package:istfix_app/features/shared/no_gps_view.dart';
import 'package:istfix_app/services/connectivity_service.dart';

// Mock dosyası için
@GenerateMocks([ConnectivityService])
import 'connectivity_wrapper_test.mocks.dart';

void main() {
  late MockConnectivityService mockService;
  
  // Sahte Stream Controller'lar (Veri akışını manuel tetiklemek için)
  late StreamController<List<ConnectivityResult>> connectivityController;
  late StreamController<ServiceStatus> gpsController;

  setUp(() {
    mockService = MockConnectivityService();
    connectivityController = StreamController<List<ConnectivityResult>>.broadcast();
    gpsController = StreamController<ServiceStatus>.broadcast();

    // Akış (Stream) cevaplarını ayarla
    when(mockService.connectivityStream).thenAnswer((_) => connectivityController.stream);
    when(mockService.gpsServiceStream).thenAnswer((_) => gpsController.stream);
  });

  tearDown(() {
    connectivityController.close();
    gpsController.close();
  });

  // Test edilecek Wrapper'ı sanal bir MaterialApp içine koyan yardımcı fonksiyon
  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: ConnectivityWrapper(
        connectivityService: mockService,
        // Ana sayfa niyetine basit bir sahte widget
        child: const Center(child: Text('Ana Uygulama İçeriği')), 
      ),
    );
  }

  group('ConnectivityWrapper Widget Testleri', () {
    testWidgets('İnternet ve GPS varsa sadece ana içeriği göstermelidir', (tester) async {
      // 1. HAZIRLIK: Her şey yolunda
      when(mockService.hasInternet()).thenAnswer((_) async => true);
      when(mockService.hasGps()).thenAnswer((_) async => true);

      // 2. AKSİYON
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // 3. DOĞRULAMA: Hata ekranları OLMAMALI, ana içerik OLMALI
      expect(find.text('Ana Uygulama İçeriği'), findsOneWidget);
      expect(find.byType(NoConnectionView), findsNothing);
      expect(find.byType(NoGpsView), findsNothing);
    });

    testWidgets('İnternet yoksa NoConnectionView (İnternet Yok Perdesi) inmelidir', (tester) async {
      // 1. HAZIRLIK: İnternet koptu
      when(mockService.hasInternet()).thenAnswer((_) async => false);
      when(mockService.hasGps()).thenAnswer((_) async => true);

      // 2. AKSİYON
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // 3. DOĞRULAMA: İnternet yok ekranı görünmeli
      expect(find.byType(NoConnectionView), findsOneWidget);
      expect(find.byType(NoGpsView), findsNothing);
    });

    testWidgets('İnternet var ama GPS kapalıysa NoGpsView (Konum Yok Perdesi) inmelidir', (tester) async {
      // 1. HAZIRLIK: İnternet var, GPS yok
      when(mockService.hasInternet()).thenAnswer((_) async => true);
      when(mockService.hasGps()).thenAnswer((_) async => false);

      // 2. AKSİYON
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // 3. DOĞRULAMA: Sadece GPS yok ekranı görünmeli
      expect(find.byType(NoGpsView), findsOneWidget);
      expect(find.byType(NoConnectionView), findsNothing);
    });

    testWidgets('Uygulama açıkken anlık internet kopması yakalanmalıdır (Stream Testi)', (tester) async {
      // 1. HAZIRLIK: Başlangıçta her şey yolunda
      when(mockService.hasInternet()).thenAnswer((_) async => true);
      when(mockService.hasGps()).thenAnswer((_) async => true);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();
      
      // Başlangıçta hata ekranı yok
      expect(find.byType(NoConnectionView), findsNothing);

      // 2. AKSİYON: Arka planda aniden internet koptu sinyali gönder!
      connectivityController.add([ConnectivityResult.none]);
      await tester.pumpAndSettle(); // UI'ın güncellenmesini bekle

      // 3. DOĞRULAMA: İnternet Yok perdesi otomatik olarak inmiş olmalı
      expect(find.byType(NoConnectionView), findsOneWidget);
    });
  });
}