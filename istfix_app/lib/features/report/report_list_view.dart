import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:istfix_app/core/constants/color_constants.dart';
import 'package:istfix_app/features/report/report_detail_view.dart';

/// Rapor listesinde görüntülenecek her bir öğenin veri modelini temsil eder.
/// Backend'den gelen karmaşık JSON verisinin arayüzde kullanılabilir, basitleştirilmiş halidir.
class ReportListItem {
  final String id;
  final String categoryName;
  final String dateStr;
  final String municipalityName;
  final String status;
  final Color baseColor;
  final String iconPath;

  ReportListItem({
    required this.id,
    required this.categoryName,
    required this.dateStr,
    required this.municipalityName,
    required this.status,
    required this.baseColor,
    required this.iconPath,
  });
}

/// Kullanıcının daha önce sisteme ilettiği ihbarları liste halinde sunan görünüm sınıfı.
class ReportListView extends StatefulWidget {
  const ReportListView({super.key});

  @override
  State<ReportListView> createState() => _ReportListViewState();
}

class _ReportListViewState extends State<ReportListView> {
  // Yerel veri güvenliği için depolama yöneticisi
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Arayüzde listelenecek raporların tutulduğu koleksiyon
  List<ReportListItem> _reports = [];

  // Veri çekme işlemi sırasındaki bekleme durumunu kontrol eder
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Görünüm belleğe yüklendiğinde asenkron veri çekme işlemi başlatılır
    _fetchReports();
  }

  /// Güvenli depolamadan, yetkilendirilmiş kullanıcıya ait erişim anahtarını (JWT) getirir.
  Future<String> _getToken() async {
    try {
      return await _secureStorage.read(key: 'access_token') ?? "";
    } catch (e) {
      debugPrint("Token okuma hatası: $e");
      return "";
    }
  }

  /// ISO 8601 formatında gelen zaman damgasını, kullanıcı dostu Türkçe formata (Örn: 15 Mayıs 2026) çevirir.
  String _formatDate(String isoString) {
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
      // Çeviri başarısız olursa gelen ham veriyi döndürür
      return isoString;
    }
  }

  /// Gelen kategori ismini analiz ederek, tasarım standartlarına uygun renk ve SVG ikon yolunu belirler.
  Map<String, dynamic> _getCategoryStyles(String category) {
    if (category.contains('Yol Sorunu')) {
      return {'color': AppColors.yol, 'iconPath': 'assets/icons/ic_road.svg'};
    } else if (category.contains('Su Sorunu')) {
      return {
        'color': AppColors.su,
        'iconPath': 'assets/icons/ic_water_drop.svg',
      };
    } else if (category.contains('Çevre Kirliliği') ||
        category.contains('Atık')) {
      return {'color': AppColors.atik, 'iconPath': 'assets/icons/ic_trash.svg'};
    } else if (category.contains('Aydınlatma Sorunu')) {
      return {
        'color': AppColors.aydinlatma,
        'iconPath': 'assets/icons/ic_lightbulb.svg',
      };
    }
    // Eşleşmeyen kategoriler için varsayılan stil
    return {
      'color': AppColors.diger,
      'iconPath': 'assets/icons/ic_settings.svg',
    };
  }

  /// Kullanıcının oluşturduğu raporları güvenli bir şekilde backend üzerinden çeker ve durumu günceller.
  Future<void> _fetchReports() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final token = await _getToken();
      final url = Uri.parse('http://10.0.2.2:8000/api/reports/me');

      final response = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        // Gelen JSON verisi Map edilerek uygulama içi veri modeline dönüştürülür
        final List<ReportListItem> fetchedReports = data.map((item) {
          String catName = item['classification']?['categoryLabel'] ?? "Diğer";
          final styles = _getCategoryStyles(catName);
          String muniName = item['municipality']?['name'] ?? "Belirleniyor...";

          return ReportListItem(
            id: item['id'].toString(),
            categoryName: catName,
            dateStr: _formatDate(item['submissionTimestamp']),
            municipalityName: muniName,
            status: item['processingStatus'],
            baseColor: styles['color'],
            iconPath: styles['iconPath'],
          );
        }).toList();

        if (mounted) setState(() => _reports = fetchedReports);
      } else {
        if (mounted) setState(() => _reports = []);
      }
    } catch (e) {
      debugPrint("Veri çekme hatası: $e");
      if (mounted) setState(() => _reports = []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
            height: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Raporlarım",
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
          : _reports.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _reports.length,
              itemBuilder: (context, index) =>
                  _buildReportCard(_reports[index]),
            ),
    );
  }

  /// İhbar listesi boş olduğunda (kullanıcının hiç raporu yoksa) gösterilen estetik boş durum (Empty State) arayüzü.
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/icons/ic_inbox.svg',
            width: 72,
            height: 72,
            colorFilter: ColorFilter.mode(
              AppColors.bogazGecesi.withOpacity(0.4),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Daha önce gönderilmiş raporunuz bulunmamaktadır.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  /// Rapor özet bilgilerini içeren, tıklanabilir durum yönetimli kart arayüzü.
  Widget _buildReportCard(ReportListItem report) {
    String displayStatus = "Bekliyor";
    Color statusColor = AppColors.durumBekliyor;

    // Gelen durumu küçük harfe çevirerek büyük/küçük harf duyarlılığını (case sensitivity) ortadan kaldırıyoruz
    final String safeStatus = report.status.trim().toLowerCase();

    // Güvenli eşleştirme: Backend'den ne gelirse gelsin küçük harfle kontrol edilir
    if (safeStatus == "emaildelivered" ||
        safeStatus.contains("iletildi") ||
        safeStatus.contains("i̇letildi")) {
      displayStatus = "İletildi";
      statusColor = AppColors.durumIletildi;
    } else if (safeStatus == "emaildispatchfailed" ||
        safeStatus.contains("iletilemedi") ||
        safeStatus.contains("i̇letilemedi")) {
      displayStatus = "İletilemedi";
      statusColor = AppColors.durumIletilemedi;
    } else if (safeStatus == "resolved" || safeStatus == "çözüldü") {
      displayStatus = "Çözüldü";
      statusColor = AppColors.durumCozuldu;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReportDetailView(reportId: report.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF3B66A7).withOpacity(0.5),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 65,
              height: 65,
              decoration: BoxDecoration(
                color: report.baseColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: SvgPicture.asset(
                  report.iconPath,
                  colorFilter: ColorFilter.mode(
                    report.baseColor,
                    BlendMode.srcIn,
                  ),
                  width: 32,
                  height: 32,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.categoryName,
                    style: const TextStyle(
                      color: AppColors.bogazGecesi,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    report.dateStr,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    report.municipalityName,
                    style: const TextStyle(
                      color: Color(0xFF6C8CBA),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                displayStatus,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
