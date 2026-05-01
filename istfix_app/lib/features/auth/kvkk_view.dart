import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:istfix_app/core/constants/color_constants.dart';

/// [KvkkView], İstFix Açık Rıza Beyanı metnini kurumsal kimliğe uygun şekilde sunar.
/// Tasarım gereği metin kaydırılabilir, alttaki marka imzası sabittir.
class KvkkView extends StatelessWidget {
  const KvkkView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/icons/ic_chevron_left.svg',
            colorFilter: const ColorFilter.mode(
              AppColors.bogazGecesi,
              BlendMode.srcIn,
            ),
            width: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "KVKK Aydınlatma Metni",
          style: TextStyle(
            color: AppColors.bogazGecesi,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: Column(
        children: [
          // Kaydırılabilir Resmi Metin Alanı
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20.0,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch, // Metni genişliğe yayar
                children: [
                  const Text(
                    "İstFix Kişisel Veri İşleme Açık Rıza Beyanı",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.bogazGecesi,
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildSectionTitle("1. Veri Sorumlusu Bilgileri"),
                  _buildArticleBody(
                    "İstFix olarak, Kişisel Verilerin Korunması Kanunu (KVKK) kapsamında kişisel verilerinizin güvenliğini sağlamak ve gizliliğinizi korumak en temel önceliğimizdir.",
                  ),

                  _buildSectionTitle("2. İşlenecek Kişisel Veriler"),
                  _buildArticleBody(
                    "Uygulamamız üzerinden altyapı sorunlarını bildirme ve raporlama faaliyetleriniz kapsamında aşağıdaki kişisel verileriniz işlenecektir:",
                  ),
                  _buildBulletPoint("Kimlik bilgileri: Ad"),
                  _buildBulletPoint("İletişim bilgileri: E-posta adresi"),
                  _buildBulletPoint(
                    "Konum bilgileri: Şikayete konu olan altyapı sorununun (hasar, arıza vb.) tespit edildiği GPS konumu",
                  ),
                  _buildBulletPoint(
                    "Görsel veriler: Sorunu bildirmek amacıyla uygulama üzerinden çektiğiniz veya sisteme yüklediğiniz fotoğraf ve videolar",
                  ),
                  const SizedBox(height: 8),

                  _buildSectionTitle("3. İşleme Amaçları"),
                  _buildArticleBody(
                    "Kişisel verileriniz, aşağıdaki amaçlarla işlenmektedir:",
                  ),
                  _buildBulletPoint(
                    "Altyapı sorunlarının tespit edilmesi, görsel analizi ve doğru konumlandırılması",
                  ),
                  _buildBulletPoint(
                    "Kategori tabanlı şablon motorumuz aracılığıyla (üçüncü taraf yapay zeka metin API'lerine aktarım yapılmaksızın) standartlaştırılmış ve güvenli şikayet metinlerinin oluşturulması",
                  ),
                  _buildBulletPoint(
                    "Şikayetlerin çözüme kavuşturulması amacıyla ilgili kurumlara iletilmesi",
                  ),
                  _buildBulletPoint(
                    "Kullanıcı hesabınızın oluşturulması, yönetimi ve raporlarınızın durum takibinin sağlanması",
                  ),
                  _buildBulletPoint(
                    "Hukuki yükümlülüklerin yerine getirilmesi",
                  ),
                  const SizedBox(height: 8),

                  _buildSectionTitle(
                    "4. Verilerin Aktarılacağı Kişi ve Kuruluşlar",
                  ),
                  _buildArticleBody(
                    "Kişisel verileriniz, yalnızca raporladığınız sorunların çözülmesi ve yasal süreçlerin işletilmesi amacıyla aşağıdaki kişi ve kuruluşlara aktarılabilir:",
                  ),
                  _buildBulletPoint(
                    "İlgili belediyeler, kamu kurumları ve yetkili altyapı hizmet sağlayıcıları",
                  ),
                  _buildBulletPoint(
                    "Gerekli durumlarda hukuki merciler ve düzenleyici kurumlar",
                  ),
                  const SizedBox(height: 4),
                  _buildArticleBody(
                    "(Not: Görüntü işleme ve şikayet metni oluşturma süreçleri sistem içi mimarimizde gerçekleştiğinden, verileriniz bu amaçlarla dış API servis sağlayıcılarıyla paylaşılmamaktadır.)",
                    isItalic: true,
                  ),

                  _buildSectionTitle("5. Saklama Süresi"),
                  _buildArticleBody(
                    "Kişisel verileriniz, şikayet süreçlerinin tamamlanması ve yasal saklama süreleri boyunca güvenle işlenecek, bu sürelerin sonunda veya talebiniz üzerine (yasal bir engel bulunmadığı takdirde) imha edilecektir.",
                  ),

                  _buildSectionTitle("6. Haklarınız"),
                  _buildArticleBody(
                    "KVKK’nın 11. maddesi kapsamında aşağıdaki haklara sahipsiniz:",
                  ),
                  _buildBulletPoint(
                    "Kişisel verilerinizin işlenip işlenmediğini öğrenme",
                  ),
                  _buildBulletPoint(
                    "Eksik veya yanlış işlenen verilerin düzeltilmesini isteme",
                  ),
                  _buildBulletPoint(
                    "Verilerinizin silinmesini veya yok edilmesini talep etme",
                  ),
                  _buildBulletPoint(
                    "Kanuna aykırı işleme nedeniyle zarara uğramanız halinde tazminat talep etme",
                  ),
                  const SizedBox(height: 8),

                  _buildSectionTitle("7. Açık Rıza Beyanı"),
                  _buildArticleBody(
                    "Yukarıda belirtilen bilgilendirme kapsamında, kişisel verilerimin İstFix tarafından işlenmesine, saklanmasına ve altyapı sorunlarının çözümü amacıyla belirtilen yetkili kişi ve kuruluşlara (belediyeler ve kamu kurumları) aktarılmasına açık rıza gösteriyorum.",
                    isBold: true,
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // --- STANDART ALT LOGO BÖLÜMÜ (32px Boyut) ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 16, top: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Center(
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                  ),
                  children: [
                    TextSpan(
                      text: "Ist",
                      style: TextStyle(color: AppColors.bogazGecesi),
                    ),
                    TextSpan(
                      text: "Fix",
                      style: TextStyle(color: AppColors.marmaraMavisi),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Başlıklar için sola dayalı, vurgulu yardımcı widget
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(
        title,
        textAlign: TextAlign.left,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: AppColors.bogazGecesi,
        ),
      ),
    );
  }

  /// Madde içerikleri için iki yana yaslı (justify) yardımcı widget
  Widget _buildArticleBody(
    String text, {
    bool isItalic = false,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        textAlign: TextAlign.justify,
        style: TextStyle(
          fontSize: 12,
          height: 1.5,
          color: Colors.black87,
          fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
          fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  /// Liste elemanları için özel yardımcı widget
  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, left: 8.0, right: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "• ",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.marmaraMavisi,
            ),
          ),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
