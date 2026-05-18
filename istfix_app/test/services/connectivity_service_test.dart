// test/services/connectivity_service_test.dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:istfix_app/services/connectivity_service.dart';

// Mock sınıfların otomatik üretilmesi için:
@GenerateMocks([Connectivity])
import 'connectivity_service_test.mocks.dart';

void main() {
  late ConnectivityService connectivityService;
  late MockConnectivity mockConnectivity;

  setUp(() {
    mockConnectivity = MockConnectivity();
    // Refaktör yaptığımız constructor sayesinde sahte nesneyi içeri sızdırıyoruz
    connectivityService = ConnectivityService(connectivity: mockConnectivity);
  });

  group('ConnectivityService Testleri', () {
    test(
      'hasInternet() - Wi-Fi veya Mobil Veri bağlıysa TRUE dönmeli',
      () async {
        // 1. HAZIRLIK: İnternet varmış gibi davran
        when(
          mockConnectivity.checkConnectivity(),
        ).thenAnswer((_) async => [ConnectivityResult.wifi]);

        // 2. AKSİYON
        final result = await connectivityService.hasInternet();

        // 3. DOĞRULAMA
        expect(result, isTrue);
      },
    );

    test('hasInternet() - İnternet yoksa (none) FALSE dönmeli', () async {
      // 1. HAZIRLIK: Cihaz uçak modundaymış gibi davran
      when(
        mockConnectivity.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.none]);

      // 2. AKSİYON
      final result = await connectivityService.hasInternet();

      // 3. DOĞRULAMA
      expect(result, isFalse);
    });

    test('connectivityStream - Bağlantı değişikliklerini doğru yayınlamalı', () {
      // 1. HAZIRLIK: İnternet gidip gelmesini simüle edeceğimiz bir boru (stream) oluştur
      final streamController = StreamController<List<ConnectivityResult>>();
      when(
        mockConnectivity.onConnectivityChanged,
      ).thenAnswer((_) => streamController.stream);

      // 3. DOĞRULAMA: Servisten çıkan verilerin sırasıyla bizim beklediğimiz gibi olup olmadığına bak (expectLater)
      expectLater(
        connectivityService.connectivityStream,
        emitsInOrder([
          [ConnectivityResult.mobile], // Önce mobil veri geldi
          [ConnectivityResult.none], // Sonra internet koptu
        ]),
      );

      // 2. AKSİYON: Sahte değişiklikleri tetikle
      streamController.add([ConnectivityResult.mobile]);
      streamController.add([ConnectivityResult.none]);
      streamController.close();
    });
  });
}
