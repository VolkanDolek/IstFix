import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:istfix_app/core/constants/color_constants.dart';

/// Kullanıcının daha önce gönderdiği bir raporun tüm ayrıntılarını (fotoğraf,
/// AI sınıflandırması, belediye bilgisi ve güncel işlem durumu) gösteren detay ekranı.
class ReportDetailView extends StatefulWidget {
  final String reportId; // Detayları çekilecek raporun benzersiz kimliği

  // GÜNCELLEME: Test edilebilirliği sağlamak için http.Client ve FlutterSecureStorage eklendi.
  final http.Client? httpClient;
  final FlutterSecureStorage? secureStorage;

  // GÜNCELLEME: Constructor güncellendi.
  const ReportDetailView({
    super.key,
    required this.reportId,
    this.httpClient,
    this.secureStorage,
  });

  @override
  State<ReportDetailView> createState() => _ReportDetailViewState();
}

class _ReportDetailViewState extends State<ReportDetailView> {
  // Kimlik doğrulama verileri ve durum yönetimi değişkenleri
  // GÜNCELLEME: Sabit atama kaldırılıp late değişken yapıldı.
  late final FlutterSecureStorage _secureStorage;
  // GÜNCELLEME: API istekleri için HTTP istemcisi eklendi.
  late final http.Client _httpClient;

  bool _isLoading = true;
  Map<String, dynamic>? _reportData;

  @override
  void initState() {
    super.initState();
    // GÜNCELLEME: Dışarıdan mock verildiyse onu, verilmediyse orijinal paketleri kullanıyoruz.
    _secureStorage = widget.secureStorage ?? const FlutterSecureStorage();
    _httpClient = widget.httpClient ?? http.Client();

    _fetchReportDetails();
  }

  /// Belirtilen rapor ID'sini kullanarak backend (FastAPI) üzerinden güncel verileri çeker.
  /// JWT tabanlı yetkilendirme ve çeşitli HTTP hata kodlarını (404, 422 vb.) yönetir.
  Future<void> _fetchReportDetails() async {
    try {
      final token = await _secureStorage.read(key: 'access_token');
      final url = Uri.parse(
        'http://10.0.2.2:8000/api/reports/${widget.reportId}',
      );

      // GÜNCELLEME: Sabit http paketi yerine enjekte edilen _httpClient kullanıldı.
      final response = await _httpClient
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _reportData = json.decode(response.body);
            _isLoading = false;
          });
        }
      } else if (response.statusCode == 404) {
        throw Exception("Rapor veritabanında bulunamadı (404).");
      } else if (response.statusCode == 422) {
        throw Exception("Gönderilen ID formatı hatalı (422).");
      } else {
        throw Exception("Sunucu hatası: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Detay çekme hatası: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll("Exception: ", "")),
            backgroundColor: AppColors.durumIletilemedi,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// ISO 8601 formatındaki tarih verisini yerel dile ve saat dilimine uygun,
  /// okunabilir bir biçime (Örn: 17 Şubat 2026, 22:15) dönüştürür.
  String _formatDateTime(String? isoString) {
    if (isoString == null) return "Bilinmiyor";
    try {
      DateTime date = DateTime.parse(isoString).toLocal();
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
      String hour = date.hour.toString().padLeft(2, '0');
      String minute = date.minute.toString().padLeft(2, '0');
      return "${date.day} ${aylar[date.month]} ${date.year}, $hour:$minute";
    } catch (e) {
      return isoString;
    }
  }

  /// Enlem ve boylam değerlerini standart haritacılık notasyonuna göre formatlar.
  String _formatLocation(double? lat, double? lng) {
    if (lat == null || lng == null) return "Konum alınamadı";
    return "${lat.toStringAsFixed(4)}° K, ${lng.toStringAsFixed(4)}° D";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.arkaplan,
      appBar: AppBar(
        backgroundColor: AppColors.bogazGecesi,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/icons/ic_chevron_left.svg',
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            width: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Rapor Detayı",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.bogazGecesi),
            )
          : _reportData == null
          ? _buildErrorState()
          : _buildContent(),
    );
  }

  /// Backend'den gelen verilerin ayrıştırıldığı ve görsellerin URL temizliğinin yapıldığı ana içerik bileşeni.
  Widget _buildContent() {
    // Fotoğraf URL'indeki ters bölü işaretlerini düzeltir ve emülatör IP yönlendirmesini yönetir
    final String rawImageUrl = (_reportData?['photoUrl'] ?? "").replaceAll(
      '\\',
      '/',
    );

    String imageUrl = "";
    if (rawImageUrl.isNotEmpty) {
      String safeUrl = rawImageUrl;

      if (safeUrl.contains('localhost')) {
        safeUrl = safeUrl.replaceAll('localhost', '10.0.2.2');
      } else if (safeUrl.contains('127.0.0.1')) {
        safeUrl = safeUrl.replaceAll('127.0.0.1', '10.0.2.2');
      }

      if (safeUrl.startsWith('/') && !safeUrl.startsWith('http')) {
        safeUrl = safeUrl.substring(1);
      }

      imageUrl = safeUrl.startsWith('http')
          ? safeUrl
          : 'http://10.0.2.2:8000/$safeUrl';
    }

    // Görüntülenecek metin verilerinin güvenli bir şekilde atanması
    final String category =
        _reportData?['classification']?['categoryLabel'] ?? "Diğer";
    final double confidence =
        (_reportData?['classification']?['confidenceScore'] ?? 0.0) * 100;
    final String municipality =
        _reportData?['municipality']?['name'] ?? "Belirleniyor...";
    final String description =
        _reportData?['writtenDescription'] ?? "Açıklama bulunmuyor.";
    final String dateStr = _formatDateTime(_reportData?['submissionTimestamp']);
    final String locationStr = _formatLocation(
      _reportData?['latitude'],
      _reportData?['longitude'],
    );
    final String status = _reportData?['processingStatus'] ?? "Pending";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Rapor Görseli: 4:3 oranında sabitlenmiş ve yuvarlatılmış köşelerle gösterilir
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Container(
                color: Colors.grey.shade300,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildImagePlaceholder(),
                      )
                    : _buildImagePlaceholder(),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Bilgi Kartı: Tüm rapor meta verilerini içeren yapılandırılmış alan
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF3B66A7).withOpacity(0.6),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDetailRow("Tarih", dateStr),
                _buildDetailRow("Kategori", category),
                _buildDetailRow(
                  "Güven Skoru",
                  "%${confidence.toStringAsFixed(0)}",
                ),
                _buildDetailRow("Belediye", municipality),
                _buildDetailRow("Konum", locationStr),
                _buildDescriptionBlock("Açıklama", description),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Durum Çubuğu: Backend'den gelen işleme durumunu görselleştirir
          _buildStatusBanner(status),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// Etiket ve değer ikilisini dikey çizgilerle ayıran standart bir bilgi satırı oluşturur.
  Widget _buildDetailRow(String label, String value, {bool isLast = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.bogazGecesi,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.bogazGecesi,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            color: const Color(0xFF3B66A7).withOpacity(0.3),
            height: 1,
            thickness: 1,
          ),
      ],
    );
  }

  /// Çok satırlı açıklamalar için genişletilmiş, dikey hizalı bir metin bloğu oluşturur.
  Widget _buildDescriptionBlock(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.bogazGecesi,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.bogazGecesi,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// Raporun güncel durumuna (İletildi, Çözüldü, Bekliyor vb.) göre
  /// dinamik renk ve ikon ataması yapan geri bildirim çubuğu.
  Widget _buildStatusBanner(String status) {
    Color bgColor;
    Color textColor;
    String iconPath;
    String message;

    final String safeStatus = status.trim().toLowerCase();

    if (safeStatus == "emaildelivered" ||
        safeStatus.contains("iletildi") ||
        safeStatus.contains("i̇letildi")) {
      bgColor = AppColors.durumIletildi.withOpacity(0.2);
      textColor = AppColors.durumIletildi;
      iconPath = 'assets/icons/ic_check_circle.svg';
      message = "E-posta başarıyla iletildi.";
    } else if (safeStatus == "inprogress" ||
        safeStatus == "in_progress" ||
        safeStatus.contains("işleme") ||
        safeStatus.contains("isleme")) {
      bgColor = AppColors.durumDevamEdiyor.withOpacity(0.2);
      textColor = AppColors.durumDevamEdiyor;
      iconPath = 'assets/icons/ic_progress_circle.svg';
      message = "Raporunuz işleme alındı, süreç devam ediyor.";
    } else if (safeStatus == "emaildispatchfailed" ||
        safeStatus == "rejected" ||
        safeStatus.contains("iletilemedi") ||
        safeStatus.contains("i̇letilemedi")) {
      bgColor = AppColors.durumIletilemedi.withOpacity(0.2);
      textColor = AppColors.durumIletilemedi;
      iconPath = 'assets/icons/ic_warning_circle.svg';
      message = "E-posta iletilemedi!";
    } else if (safeStatus == "resolved" || safeStatus == "çözüldü") {
      bgColor = AppColors.durumCozuldu.withOpacity(0.2);
      textColor = AppColors.durumCozuldu;
      iconPath = 'assets/icons/ic_resolved_circle.svg';
      message = "Sorun başarıyla çözüldü.";
    } else {
      bgColor = AppColors.durumBekliyor.withOpacity(0.2);
      textColor = AppColors.durumBekliyor;
      iconPath = 'assets/icons/ic_pending_circle.svg';
      message = "Raporunuz işleniyor, lütfen bekleyin.";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            iconPath,
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(textColor, BlendMode.srcIn),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Görsel yüklenemediğinde veya URL boş olduğunda gösterilen yer tutucu (placeholder).
  Widget _buildImagePlaceholder() {
    return const Center(
      child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
    );
  }

  /// Veri çekme başarısız olduğunda kullanıcıya gösterilen hata ekranı ve yeniden deneme butonu.
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            "Rapor detayları yüklenemedi.",
            style: TextStyle(color: AppColors.tas, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchReportDetails,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bogazGecesi,
            ),
            child: const Text("Tekrar Dene"),
          ),
        ],
      ),
    );
  }
}
