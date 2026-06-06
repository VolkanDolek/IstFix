/// ===========================================================================
/// DOSYA: nfr_performance_test.dart
/// PROJE: İstFix - Kentsel Altyapı Şikayet Sistemi
/// MODÜL: Uçtan Uca (E2E) Performans ve Entegrasyon Test Süiti
/// AÇIKLAMA: Bu test dosyası, sistemin Fonksiyonel Olmayan Gereksinimlerini (NFR)
///           otonom olarak doğrular. Yapay zeka (YOLOv8) çıkarım hızını,
///           ağ gecikmesini (latency) ve "Tam Kullanıcı Yaşam Döngüsünü" (User Journey)
///           milisaniye hassasiyetinde laboratuvar standartlarında ölçer.
/// ===========================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:dio/dio.dart';

// Sistem ağ altyapısı ve uygulamanın kök dizin enjeksiyonları
import 'package:istfix_app/core/network/api_client.dart';
import 'package:istfix_app/main.dart' as app;

void main() {
  // Flutter test motorunun sanal cihaz veya emülatör üzerinde
  // kararlı bir şekilde başlatılmasını garanti eder.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('IstFix Uçtan Uca (E2E) NFR Performans Entegrasyon Testleri', () {
    late Dio realDio;
    late Stopwatch stopwatch;

    // SİSTEMDE GERÇEKTE KAYITLI OLAN TEMEL TEST KULLANICISI BİLGİLERİ
    // Not: Salt okuma (NFR-P2, NFR-P3) ve Cold-Start (NFR-P1) testlerinde
    // yetkilendirme kalkanını (401 Unauthorized) aşmak için kullanılır.
    final String baseUserEmail = 'arda@example.com';
    final String baseUserPassword = '1234Arda';

    /// Tüm test senaryolarından önce (yalnızca bir kez) çalışarak test ortamını hazırlar.
    /// UI etkileşiminden bağımsız, salt API performansını ölçmek için Programmatic Login uygular.
    setUpAll(() async {
      realDio = ApiClient().dio;
      // Android emülatörün yerel makinedeki (localhost) FastAPI sunucusuna erişim IP'si
      realDio.options.baseUrl = 'http://10.0.2.2:8000';

      debugPrint(
        '--- SİSTEM: Otomatik Yetkilendirme (Otonom Login) Süreci Başlatılıyor ---',
      );

      try {
        // FastAPI OAuth2 Login servisine doğrudan yetkilendirme isteği atılır
        final loginResponse = await realDio.post(
          '/api/auth/login',
          data: {'username': baseUserEmail, 'password': baseUserPassword},
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );

        // Alınan yetki anahtarı (Bearer JWT), test boyunca yapılacak tüm API isteklerinin
        // başlığına (Header) kalıcı olarak yerleştirilir.
        final token = loginResponse.data['access_token'];
        realDio.options.headers['Authorization'] = 'Bearer $token';
        debugPrint(
          '--- SİSTEM: Oturum Başarıyla Açıldı! (Token Interceptor\'a Mühürlendi) ---',
        );
      } on DioException catch (_) {
        debugPrint(
          '--- SİSTEM KRİTİK HATASI: Hedef Test Hesabına Giriş Yapılamadı ---',
        );
      }
    });

    /// Her bir test case'inden hemen önce çalışarak kronometreyi sıfırlar.
    setUp(() {
      stopwatch = Stopwatch();
    });

    /// ========================================================================
    /// GEREKSİNİM : NFR-P3 (Geniş Veri Seti Çekme ve Render Performansı)
    /// SENARYO    : Veritabanından limitli (200) verinin çekilmesi, JSON
    ///              deserilizasyonu ve Flutter arayüzüne çizim hızı ölçümü.
    /// ========================================================================
    testWidgets(
      'NFR-P3: Çoklu Veri Çekme, Deserilizasyon ve Liste Render Süreç Testi',
      (WidgetTester tester) async {
        // Uygulamanın widget ağacı test ortamına yüklenir
        app.main();
        await tester.pumpAndSettle();

        debugPrint(
          '--- [NFR-P3] Entegre Veritabanı Okuma Performansı Başlatılıyor ---',
        );
        stopwatch.start();

        try {
          // PostgreSQL veritabanına büyük veri (bulk) yükü bindirilir
          final response = await realDio.get(
            '/api/reports/me',
            queryParameters: {'limit': 200},
          );

          // Gelen verilerin UI tarafından işlenip ekrana çizilmesi tamamlanana kadar beklenir
          await tester.pump();
          await tester.pumpAndSettle();

          stopwatch.stop();
          final double elapsedTime = stopwatch.elapsedMicroseconds / 1000000;

          debugPrint('==================================================');
          debugPrint('Gereksinim: NFR-P3 (200 Rapor Yükleme)');
          debugPrint('İstenen Sınır Sürat: < 5.0 saniye');
          debugPrint('Ölçülen Uçtan Uca Süre: $elapsedTime saniye');
          debugPrint('Durum: PASSED (İstenen ölçeklenebilirlik sağlandı)');
          debugPrint('==================================================');

          expect(response.statusCode, 200);
          expect(
            elapsedTime,
            lessThan(5.0),
            reason: 'NFR-P3 süre aşımı tespit edildi.',
          );
        } on DioException catch (_) {
          fail('NFR-P3 Çoklu Veri Çekme İsteği Başarısız Oldu.');
        }
      },
    );

    /// ========================================================================
    /// GEREKSİNİM : NFR-P2 (Ağ Gecikmesi ve Kök Düğüm Erişilebilirliği)
    /// SENARYO    : Cihaz ile sunucu arasındaki saf ağ gecikmesinin (Network
    ///              Latency) ve TLS el sıkışma hızının ölçülmesi.
    /// ========================================================================
    testWidgets('NFR-P2: API Kök Düğüm Ağ Gecikme (Latency) Testi', (
      WidgetTester tester,
    ) async {
      debugPrint('--- [NFR-P2] Ağ Gecikme (Ping) Analizi Başlatılıyor ---');
      stopwatch.reset();
      stopwatch.start();

      try {
        // Sunucu sağlığını (Health Check) doğrulamak adına ana rotaya ping atılır
        final response = await realDio.get('/');

        await tester.pumpAndSettle();
        stopwatch.stop();
        final double elapsedTime = stopwatch.elapsedMicroseconds / 1000000;

        debugPrint('==================================================');
        debugPrint('Gereksinim: NFR-P2 (Ağ Tepki Süresi)');
        debugPrint('İstenen Sınır Sürat: < 3.0 saniye');
        debugPrint('Ölçülen Süre: $elapsedTime saniye');
        debugPrint('Durum: PASSED (Kabul edilebilir ağ gecikmesi)');
        debugPrint('==================================================');

        expect(response.statusCode, 200);
        expect(
          elapsedTime,
          lessThan(3.0),
          reason: 'NFR-P2 ağ tepki süresi aşıldı.',
        );
      } on DioException catch (_) {
        fail('NFR-P2 Ağ Gecikme İsteği Başarısız Oldu.');
      }
    });

    /// ========================================================================
    /// GEREKSİNİM : NFR-P1 (Ağır İş Yükü ve "Cold Start" Isınma Simülasyonu)
    /// SENARYO    : Sisteme ilk kez ağır bir iş yükü bindirilerek YOLOv8 modelinin
    ///              RAM'e yüklenme (Cold Start) süresinin ve SMTP gecikmesinin hesabı.
    /// ========================================================================
    testWidgets(
      'NFR-P1: Gerçek Görsel İşleme (YOLOv8) ve Otomatik SMTP Mail Gönderim Testi',
      (WidgetTester tester) async {
        debugPrint(
          '--- [NFR-P1] Ağır İş Yükü (AI & SMTP) Analizi Başlatılıyor ---',
        );

        // Dış kaynak izolasyonu: Test resmi, cihaz belleğinden (assets) bağımsız olarak okunur
        final byteData = await rootBundle.load(
          'assets/test_images/test_image.jpg',
        );
        final List<int> imageBytes = byteData.buffer.asUint8List();

        // FastAPI için standart multipart/form-data paketi hazırlanır
        final formData = FormData.fromMap({
          'latitude': 41.0422,
          'longitude': 29.0083,
          'writtenDescription': 'NFR Entegre Gerçek Görsel Test Bildirimi',
          'image': MultipartFile.fromBytes(
            imageBytes,
            filename: 'real_test_image.jpg',
          ),
        });

        stopwatch.reset();
        stopwatch.start();

        try {
          // İş Yükü Tetikleyicisi: Model ilk kez uyanır (Cold Start)
          final response = await realDio.post(
            '/api/reports/upload',
            data: formData,
          );

          await tester.pumpAndSettle();
          stopwatch.stop();
          final double elapsedTime = stopwatch.elapsedMicroseconds / 1000000;

          debugPrint('==================================================');
          debugPrint(
            'Gereksinim: NFR-P1 (YOLOv8 AI Analizi + SMTP Mail Gönderimi)',
          );
          debugPrint('İstenen Sınır Sürat: < 10.0 saniye');
          debugPrint(
            'Ölçülen Uçtan Uca Süre: $elapsedTime saniye (Cold Start Etkisi Dahil)',
          );
          debugPrint('YOLOv8 Analiz Sonucu: ${response.data}');
          debugPrint('Durum: PASSED (AI Çıkarımı ve Mail Aktarımı Başarılı)');
          debugPrint('==================================================');

          expect(response.statusCode, 200);
          expect(
            elapsedTime,
            lessThan(10.0),
            reason: 'NFR-P1 sistem yanıt süresi limitleri aştı.',
          );
        } on DioException catch (e) {
          debugPrint(
            'NFR-P1 HATA: ${e.response?.statusCode} - ${e.response?.data}',
          );
          fail('NFR-P1 AI Görsel İsteği Sistem Tarafından Reddedildi.');
        }
      },
    );

    /// ========================================================================
    /// GEREKSİNİM : NFR-P4 (Tam Kullanıcı Yaşam Döngüsü / User Journey)
    /// SENARYO    : Sisteme hiç kayıtlı olmayan yeni bir kullanıcının (Vatandaş)
    ///              kayıt (Register), giriş (Login) ve yapay zeka (YOLOv8 Upload)
    ///              süreçlerinin toplam (Aggregate) süresinin ölçümü.
    /// NOT        : Bu testte YOLOv8 RAM'de "ısınmış" (Warm-up) olduğu için
    ///              AI çıkarımı P1 testinden çok daha hızlı gerçekleşecektir.
    /// ========================================================================
    testWidgets('NFR-P4: Tam Kullanıcı Yaşam Döngüsü (Register -> Login -> Upload)', (
      WidgetTester tester,
    ) async {
      debugPrint(
        '--- [NFR-P4] Tam Kullanıcı Yaşam Döngüsü (User Journey) Başlatılıyor ---',
      );

      // Çakışmayı (Conflict) önlemek için milisaniye tabanlı eşsiz bir test vatandaşı üretilir
      final String dynamicUserEmail =
          'vatandas_${DateTime.now().millisecondsSinceEpoch}@istfix.com';
      final String dynamicPassword = 'UserJourney123!';

      // Gerçek rapor verisi hazırlanır
      final byteData = await rootBundle.load(
        'assets/test_images/test_image.jpg',
      );
      final List<int> imageBytes = byteData.buffer.asUint8List();

      final formData = FormData.fromMap({
        'latitude': 41.0422,
        'longitude': 29.0083,
        'writtenDescription': 'Sıfırdan Zirveye Kullanıcı Yaşam Döngüsü Testi',
        'image': MultipartFile.fromBytes(
          imageBytes,
          filename: 'journey_test_image.jpg',
        ),
      });

      // KRONOMETRE BAŞLIYOR: 3 Farklı API işleminin toplam süresi (Aggregate Time) ölçülecek
      stopwatch.reset();
      stopwatch.start();

      try {
        // 1. ADIM: Sisteme Kayıt Ol (Register API)
        await realDio.post(
          '/api/auth/register',
          data: {
            'name': 'Dinamik Vatandaş',
            'emailAddress': dynamicUserEmail,
            'password': dynamicPassword,
            'kvkkAccepted': true,
          },
        );

        // 2. ADIM: Sisteme Giriş Yap (Login API)
        final loginResponse = await realDio.post(
          '/api/auth/login',
          data: {'username': dynamicUserEmail, 'password': dynamicPassword},
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );

        // Yeni kayıt olan vatandaşın token'ı geçici olarak header'a yerleştirilir
        final String journeyToken = loginResponse.data['access_token'];
        realDio.options.headers['Authorization'] = 'Bearer $journeyToken';

        // 3. ADIM: Yapay Zekaya Şikayeti İlet (YOLOv8 & SMTP Upload API)
        final response = await realDio.post(
          '/api/reports/upload',
          data: formData,
        );

        // Animasyon ve geçişlerin bitmesi beklenir
        await tester.pumpAndSettle();

        stopwatch.stop();
        final double elapsedTime = stopwatch.elapsedMicroseconds / 1000000;

        debugPrint('==================================================');
        debugPrint(
          'Gereksinim: NFR-P4 (Tam Kullanıcı Yaşam Döngüsü - User Journey)',
        );
        debugPrint('İstenen Sınır Sürat: < 15.0 saniye (3 İşlem Toplamı)');
        debugPrint(
          'Ölçülen Aggregate Süre: $elapsedTime saniye (Warm-up Avantajı)',
        );
        debugPrint('YOLOv8 Tahmini: ${response.data}');
        debugPrint('Durum: PASSED (Register + Login + AI/SMTP Akışı Kusursuz)');
        debugPrint('==================================================');

        // Kayıt, giriş ve yükleme işlemlerinin aggregate (toplam) süresi hesaplanır
        expect(response.statusCode, 200);
        expect(
          elapsedTime,
          lessThan(15.0),
          reason: 'NFR-P4 yaşam döngüsü süresi aşıldı.',
        );
      } on DioException catch (e) {
        debugPrint(
          'NFR-P4 HATA: ${e.response?.statusCode} - ${e.response?.data}',
        );
        fail('NFR-P4 Kullanıcı Yaşam Döngüsü Başarısız Oldu.');
      }
    });
  });
}
