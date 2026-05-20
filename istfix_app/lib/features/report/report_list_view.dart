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

  /// Tarihe göre (Eskiden yeniye / Yeniden eskiye) sıralama yapabilmek için eklenen ham tarih nesnesi.
  final DateTime rawDate;
  final String municipalityName;
  final String status;
  final Color baseColor;
  final String iconPath;

  ReportListItem({
    required this.id,
    required this.categoryName,
    required this.dateStr,
    required this.rawDate,
    required this.municipalityName,
    required this.status,
    required this.baseColor,
    required this.iconPath,
  });
}

/// Kullanıcının daha önce sisteme ilettiği ihbarları liste halinde sunan görünüm sınıfı.
class ReportListView extends StatefulWidget {
  // GÜNCELLEME: Test edilebilirliği sağlamak için http.Client ve FlutterSecureStorage bağımlılıkları eklendi.
  final http.Client? httpClient;
  final FlutterSecureStorage? secureStorage;

  // GÜNCELLEME: Constructor'a httpClient ve secureStorage parametreleri eklendi.
  const ReportListView({super.key, this.httpClient, this.secureStorage});

  @override
  State<ReportListView> createState() => _ReportListViewState();
}

class _ReportListViewState extends State<ReportListView> {
  // Yerel veri güvenliği için depolama yöneticisi
  // GÜNCELLEME: Sabit atama kaldırılıp late değişken yapıldı.
  late final FlutterSecureStorage _secureStorage;

  // GÜNCELLEME: API istekleri için kullanılacak HTTP istemcisi eklendi.
  late final http.Client _httpClient;

  // Arayüzde listelenecek raporların tutulduğu koleksiyon
  List<ReportListItem> _reports = [];

  // Kullanıcının seçtiği filtrelere göre ekranda gösterilecek aktif koleksiyon
  List<ReportListItem> _filteredReports = [];

  // Veri çekme işlemi sırasındaki bekleme durumunu kontrol eder
  bool _isLoading = true;

  // --- Filtreleme ve Sıralama Durumları (State) ---
  String _selectedCategory = "Tümü"; // Aktif kategori filtresi
  bool _sortDescending = true; // true: Yeniden Eskiye, false: Eskiden Yeniye

  // Uygulamada gösterilecek filtreleme kategorileri
  final List<String> _filterCategories = [
    "Tümü",
    "Yol",
    "Su",
    "Atık",
    "Aydınlatma",
    "Diğer",
  ];

  @override
  void initState() {
    super.initState();
    // GÜNCELLEME: Dışarıdan mock verildiyse onu, verilmediyse orijinal paketleri kullanıyoruz.
    _secureStorage = widget.secureStorage ?? const FlutterSecureStorage();
    _httpClient = widget.httpClient ?? http.Client();

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
    final String cat = category.toLowerCase();

    // GÜNCELLEME: Modelin sorun bulamadığı kategori senaryosu yakalanır
    if (cat.contains('tespit edilemedi')) {
      return {
        'color': AppColors.sorunTespitEdilemedi,
        'iconPath': 'assets/icons/ic_image_question.svg',
      };
    } else if (cat.contains('yol')) {
      return {'color': AppColors.yol, 'iconPath': 'assets/icons/ic_road.svg'};
    } else if (cat.contains('su')) {
      return {
        'color': AppColors.su,
        'iconPath': 'assets/icons/ic_water_drop.svg',
      };
    } else if (cat.contains('çevre') ||
        cat.contains('cevre') ||
        cat.contains('atık') ||
        cat.contains('atik')) {
      return {'color': AppColors.atik, 'iconPath': 'assets/icons/ic_trash.svg'};
    } else if (cat.contains('aydınlatma') || cat.contains('aydinlatma')) {
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

  /// Kullanıcının seçtiği kategoriye ve sıralama yönüne göre ana listeyi filtreler.
  void _applyFilters() {
    List<ReportListItem> result = List.from(_reports);

    // 1. Kategori Bazlı Filtreleme
    if (_selectedCategory != "Tümü") {
      result = result.where((r) {
        final String cat = r.categoryName.toLowerCase();
        final String search = _selectedCategory.toLowerCase();

        // "Atık" filtresi seçildiğinde hem atık hem çevre etiketli
        // ve Türkçe/İngilizce karakter varyasyonlu raporları getirir.
        if (search == "atık" || search == "atik") {
          return cat.contains("çevre") ||
              cat.contains("cevre") ||
              cat.contains("atık") ||
              cat.contains("atik");
        }
        // Türkçe karakter (ı/i) varyasyonları için Aydınlatma kalkanı
        if (search == "aydınlatma" || search == "aydinlatma") {
          return cat.contains("aydınlatma") || cat.contains("aydinlatma");
        }

        return cat.contains(search);
      }).toList();
    }

    // 2. Zaman Damgasına (Timestamp) Göre Sıralama
    result.sort((a, b) {
      if (_sortDescending) {
        return b.rawDate.compareTo(a.rawDate); // En güncel kayıtlar en üstte
      } else {
        return a.rawDate.compareTo(b.rawDate); // En eski kayıtlar en üstte
      }
    });

    setState(() {
      _filteredReports = result;
    });
  }

  /// Kullanıcının oluşturduğu raporları güvenli bir şekilde backend üzerinden çeker ve durumu günceller.
  Future<void> _fetchReports() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final token = await _getToken();
      final url = Uri.parse('http://10.0.2.2:8000/api/reports/me');

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
        final List<dynamic> data = json.decode(response.body);

        // Gelen JSON verisi Map edilerek uygulama içi veri modeline dönüştürülür
        final List<ReportListItem> fetchedReports = data.map((item) {
          String catName = item['classification']?['categoryLabel'] ?? "Diğer";
          final styles = _getCategoryStyles(catName);
          String muniName = item['municipality']?['name'] ?? "Belirleniyor...";

          // Sıralama algoritmasının kullanabilmesi için tarih verisi DateTime nesnesine dönüştürülür
          DateTime parsedDate =
              DateTime.tryParse(item['submissionTimestamp'] ?? "") ??
              DateTime.now();

          return ReportListItem(
            id: item['id'].toString(),
            categoryName: catName,
            dateStr: _formatDate(item['submissionTimestamp'] ?? ""),
            rawDate: parsedDate,
            municipalityName: muniName,
            status: item['processingStatus'] ?? "Pending",
            baseColor: styles['color'],
            iconPath: styles['iconPath'],
          );
        }).toList();

        if (mounted) {
          setState(() {
            _reports = fetchedReports;
          });
          // Veriler başarıyla çekildikten sonra varsayılan filtrelemeyi uygula
          _applyFilters();
        }
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
      body: Column(
        children: [
          // Rapor listesi boş değilse üst filtreleme alanını göster
          if (!_isLoading && _reports.isNotEmpty) _buildFilterBar(),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.bogazGecesi,
                    ),
                  )
                : _reports.isEmpty
                ? _buildEmptyState(
                    "Daha önce gönderilmiş raporunuz bulunmamaktadır.",
                  )
                : _filteredReports.isEmpty
                ? _buildEmptyState("Seçilen kategoriye uygun rapor bulunamadı.")
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    itemCount: _filteredReports.length,
                    itemBuilder: (context, index) =>
                        _buildReportCard(_filteredReports[index]),
                  ),
          ),
        ],
      ),
    );
  }

  /// Kullanıcıya yatay düzlemde kaydırılabilir filtreleme seçenekleri (Choice Chips) sunar.
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Tarih Sıralama Butonu (Toggle)
          Tooltip(
            message: _sortDescending ? "Yeniden Eskiye" : "Eskiden Yeniye",
            child: InkWell(
              onTap: () {
                setState(() {
                  _sortDescending = !_sortDescending;
                  _applyFilters();
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.arkaplan,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      _sortDescending
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      size: 16,
                      color: AppColors.bogazGecesi,
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: AppColors.bogazGecesi,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Kategoriler için yatay kaydırılabilir seçim alanı
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filterCategories.map((category) {
                  final bool isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      checkmarkColor: Colors.white,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategory = category;
                            _applyFilters();
                          });
                        }
                      },
                      selectedColor: AppColors.bogazGecesi,
                      backgroundColor: AppColors.arkaplan,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.bogazGecesi,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.bogazGecesi
                              : Colors.grey.shade300,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// İhbar listesi boş olduğunda (kullanıcının hiç raporu yoksa veya filtre sonucu boşsa) gösterilen boş durum (Empty State) arayüzü.
  Widget _buildEmptyState(String message) {
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
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
    } else if (safeStatus == "inprogress" ||
        safeStatus == "in_progress" ||
        safeStatus.contains("işleme") ||
        safeStatus.contains("isleme")) {
      displayStatus = "İşleme Alındı";
      statusColor = AppColors.durumDevamEdiyor;
    } else if (safeStatus == "emaildispatchfailed" ||
        safeStatus == "rejected" ||
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
