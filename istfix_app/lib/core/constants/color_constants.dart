import 'package:flutter/material.dart';

class AppColors {
  // Ana Renkler
  static const Color bogazGecesi = Color(0xFF0B3D6B); // Zemin / Koyu Lacivert
  static const Color marmara = Color(0xFF1A5FA8); // Gradient
  static const Color marmaraMavisi = Color(0xFF2563C8); // Aksan / Pin
  static const Color halicAcigi = Color(0xFF40A8E0); // Link / Sinyal
  static const Color kubbeAltini = Color(0xFFC8973A); // Çekirdek / Altın
  static const Color tas = Color(0xFFF5F0E8); // Açık Gri / Krem
  static const Color arkaplan = Color(0xFFEEF4FB); // Genel Arkaplan

  // Kategori Renkleri
  static const Color yol = Color(0xFFE74C3C);
  static const Color aydinlatma = Color(0xFFF1C40F);
  static const Color su = Color(0xFF3498DB);
  static const Color atik = Color(0xFF14EB00);
  static const Color diger = Color(0xFFE67E22);

  // Durum (Status) Renkleri - Raporlama durum göstergelerinde
  static const Color durumIletildi = Color(0xFF2EBA1F);
  static const Color durumIletilemedi = Color(0xFFEA4335);
  static const Color durumBekliyor = Color(0xFFF39C12);
  static const Color durumDevamEdiyor = Color(0xFF00ACC1);
  static const Color durumCozuldu = Color(0xFF9B59B6);

  // Donanım ve Bağlantı Bildirim Renkleri
  static const Color baglantiHata =
      durumIletilemedi; // Kırmızı - Bağlantı Kesildi
  static const Color baglantiUyari =
      durumBekliyor; // Turuncu - Bağlantı Aranıyor
  static const Color baglantiBasari =
      durumIletildi; // Yeşil - Bağlantı Sağlandı

  // Rapor Gönderim Durum Renkleri
  static const Color raporGonderildi = durumIletildi; // Yeşil
  static const Color raporGonderilemedi = durumIletilemedi; // Kırmızı
}
