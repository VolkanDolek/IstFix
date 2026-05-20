// test/date_helper_test.dart
import 'package:flutter_test/flutter_test.dart';

// Test edeceğimiz çekirdek fonksiyon (Senin kodundan alındı)
String formatDate(String isoString) {
  try {
    DateTime date = DateTime.parse(isoString);
    List<String> aylar = [
      "",
      "Ocak",
      "Şubat",
      "Mart",
      "Nisan",
      "Mayıs",
      "Haziran",
      "Temmuz",
      "Ağustos",
      "Eylül",
      "Ekim",
      "Kasım",
      "Aralık",
    ];
    return "${date.day} ${aylar[date.month]} ${date.year}";
  } catch (e) {
    return isoString; // Hata durumunda ham metni dön
  }
}

void main() {
  group('Tarih Formatlama (Date Helper) Testleri', () {
    test('Geçerli bir ISO tarihi doğru Türkçe formata çevrilmeli', () {
      // Hazırlık (Arrange)
      String rawDate = "2026-05-15T14:30:00Z";

      // Aksiyon (Act)
      String result = formatDate(rawDate);

      // Beklenti/Doğrulama (Assert)
      expect(result, "15 Mayıs 2026");
    });

    test(
      'Bozuk bir tarih metni verildiğinde uygulamanın çökmemesi ve metni aynen dönmesi gerekir',
      () {
        String badDate = "hatali-tarih-verisi";
        String result = formatDate(badDate);
        expect(result, "hatali-tarih-verisi");
      },
    );

    test('Yılbaşı (1 Ocak) geçişi doğru hesaplanmalı', () {
      String newYear = "2027-01-01T00:00:00Z";
      String result = formatDate(newYear);
      expect(result, "1 Ocak 2027");
    });
  });
}
