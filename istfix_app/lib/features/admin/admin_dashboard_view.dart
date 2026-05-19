import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:istfix_app/core/constants/color_constants.dart';
import 'package:istfix_app/services/auth_service.dart';
import 'package:istfix_app/features/auth/welcome_view.dart';

/// Sistem yöneticilerinin (Admin) gelen tüm raporları görüntülediği,
/// arama/filtreleme yapabildiği ve rapor durumlarını yönettiği ana kontrol paneli.
class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  // --- Servis ve Kontrolcü Tanımlamaları ---
  final Dio _dio = Dio(BaseOptions(baseUrl: "http://10.0.2.2:8000/api"));
  final _storage = const FlutterSecureStorage();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  // --- Durum Yönetimi (State Variables) ---
  List<dynamic> _reports = []; // API'den gelen orijinal liste
  List<dynamic> _filteredReports = []; // Arama çubuğuna göre filtrelenmiş liste
  bool _isLoading = true; // Sayfa yüklenme durumu

  // --- Admin'in Seçebileceği Standart Durumlar ---
  // Dropdown menüsünde listelenecek ve backend'e gönderilecek standart formatlar
  final Map<String, String> _adminStatusOptions = {
    "Pending": "Bekliyor",
    "InProgress": "İşleme Alındı",
    "Resolved": "Çözüldü",
    "Rejected": "Reddedildi",
  };

  // --- ÇEVİRİ VE RENK FONKSİYONLARI ---

  /// Backend'den gelen durum metnini küçük harfe çevirerek rengini bulur.
  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'pending') return AppColors.durumBekliyor;
    if (s == 'emaildelivered') return AppColors.durumIletildi;
    if (s == 'inprogress' || s == 'in_progress')
      return AppColors.durumDevamEdiyor;
    if (s == 'resolved') return AppColors.durumCozuldu;
    if (s == 'rejected') return AppColors.durumIletilemedi;
    return Colors.grey; // Eşleşmeyen yepyeni bir durum gelirse
  }

  /// Backend'den gelen durum metnini küçük harfe çevirerek Türkçesini bulur.
  String _getStatusTranslation(String status) {
    final s = status.toLowerCase();
    if (s == 'pending') return "Bekliyor";
    if (s == 'emaildelivered') return "İletildi";
    if (s == 'inprogress' || s == 'in_progress') return "İşleme Alındı";
    if (s == 'resolved') return "Çözüldü";
    if (s == 'rejected') return "Reddedildi";
    return status; // Çevirisi yoksa orijinali kalsın
  }

  /// Yapay zeka tarafından belirlenen kategori ismine göre uygun UI rengini döndürür.
  Color _getCategoryColor(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('yol')) return AppColors.yol;
    if (cat.contains('aydınlatma') || cat.contains('aydinlatma'))
      return AppColors.aydinlatma;
    if (cat.contains('su')) return AppColors.su;
    if (cat.contains('çevre') || cat.contains('cevre')) return AppColors.atik;
    return AppColors.diger;
  }

  @override
  void initState() {
    super.initState();
    _fetchReports(); // Sayfa yüklendiğinde verileri getir
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- Çekirdek İşlevler (Core Functions) ---

  /// Raporlar içerisinde 'Rapor ID' veya 'Belediye ID'ye göre metin tabanlı arama yapar.
  void _filterReports(String query) {
    if (query.isEmpty) {
      setState(() => _filteredReports = _reports);
      return;
    }

    setState(() {
      _filteredReports = _reports.where((report) {
        final String reportId = report['id']?.toString().toLowerCase() ?? "";
        final String munId =
            report['MUNICIPALITYId']?.toString().toLowerCase() ?? "";

        return reportId.contains(query.toLowerCase()) ||
            munId.contains(query.toLowerCase());
      }).toList();
    });
  }

  /// REST API üzerinden yetkili kullanıcıya (Admin) ait tüm raporları asenkron olarak çeker.
  Future<void> _fetchReports() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final token = await _storage.read(key: "access_token");
      final response = await _dio.get(
        '/reports/me',
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _reports = response.data is List ? response.data : [];
          _filteredReports = _reports;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(
        "Raporlar veri tabanından çekilirken bir hata oluştu.",
      );
      setState(() => _isLoading = false);
    }
  }

  /// İlgili raporun durumunu güncelleyerek (PATCH) sunucuyla senkronize eder.
  Future<void> _updateReportStatus(String reportId, String newStatus) async {
    try {
      final token = await _storage.read(key: "access_token");
      final response = await _dio.patch(
        '/reports/$reportId/status',
        data: {"status": newStatus},
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Rapor durumu başarıyla güncellendi!"),
            backgroundColor: Colors.green,
          ),
        );
        _fetchReports(); // Arayüzü tazelemek için verileri yeniden çek
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(
        "Güncelleme işlemi başarısız oldu. Lütfen bağlantınızı kontrol edin.",
      );
    }
  }

  // --- YENİ: RAPOR SİLME FONKSİYONLARI ---

  /// Raporu kalıcı olarak silmek için kullanıcıdan onay ister.
  Future<void> _confirmDeleteReport(String reportId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Raporu Sil",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Bu raporu sistemden kalıcı olarak silmek istediğinize emin misiniz? Bu işlem geri alınamaz.",
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Kalıcı Olarak Sil",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _deleteReport(reportId);
    }
  }

  /// REST API üzerinden belirtilen raporu kalıcı olarak siler.
  Future<void> _deleteReport(String reportId) async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: "access_token");
      final response = await _dio.delete(
        '/reports/$reportId',
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Rapor sistemden başarıyla silindi."),
            backgroundColor: Colors.green,
          ),
        );
        _fetchReports(); // Listeyi güncelle
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar("Rapor silinirken bir hata oluştu.");
      setState(() => _isLoading = false);
    }
  }

  /// Aktif admin oturumunu sonlandırır, önbelleği temizler ve giriş sayfasına yönlendirir.
  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Oturumu Sonlandır"),
        content: const Text(
          "Yönetim panelinden çıkış yapmak istediğinize emin misiniz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              "Çıkış Yap",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      setState(() => _isLoading = true);
      await _authService.logout();
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeView()),
        (route) => false,
      );
    }
  }

  // --- Görünüm (UI) Katmanı ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.arkaplan,
      appBar: AppBar(
        title: const Text(
          "Rapor Yönetimi",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.bogazGecesi,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: Colors.white),
            tooltip: "Sistemden Çıkış Yap",
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Arama ve Filtreleme Modülü
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterReports,
              decoration: InputDecoration(
                hintText: "Rapor ID veya Belediye ID ile hızlı arama...",
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.bogazGecesi,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _filterReports("");
                          FocusScope.of(context).unfocus(); // Klavyeyi kapat
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.bogazGecesi,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          // 2. Dinamik Rapor Listesi Modülü
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.marmaraMavisi,
                    ),
                  )
                : _filteredReports.isEmpty
                ? const Center(
                    child: Text(
                      "Filtreleme kriterlerine uygun rapor bulunamadı.",
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _filteredReports.length,
                    itemBuilder: (context, index) {
                      final report = _filteredReports[index];
                      final String reportId = report['id']?.toString() ?? "";
                      final String status =
                          report['processingStatus']?.toString() ?? "Pending";
                      final String category =
                          report['classification']?['categoryLabel']
                              ?.toString() ??
                          "Kategori Yok";
                      final String desc =
                          report['writtenDescription']?.toString() ??
                          "Kullanıcı açıklaması belirtilmemiş.";
                      final String municipalityId =
                          report['MUNICIPALITYId']?.toString() ??
                          "Henüz Atanmamış";

                      final Color catColor = _getCategoryColor(category);

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border(
                              left: BorderSide(color: catColor, width: 5),
                            ),
                          ),
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.label_important,
                                          size: 18,
                                          color: catColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            category,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: catColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildStatusChip(status),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                desc,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              const Divider(height: 24, thickness: 1),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Sistem Rapor ID:",
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          reportId,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                            color: AppColors.bogazGecesi,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          "Hedef Belediye ID:",
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          municipalityId,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                            color: AppColors.marmaraMavisi,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // --- GÜNCELLENEN KISIM: Buton gibi görünen Sil ve Yönet Row Yapısı ---
                                  Row(
                                    children: [
                                      // Rapor Silme Butonu (Arka planı olan şık Elevated Button)
                                      ElevatedButton(
                                        onPressed: () {
                                          if (reportId.isNotEmpty) {
                                            _confirmDeleteReport(reportId);
                                          } else {
                                            _showErrorSnackBar(
                                              "Geçersiz işlem: Rapor sistem kimliği (ID) bulunamadı.",
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors
                                              .red
                                              .shade500, // Katı kırmızı arka plan
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 10,
                                          ), // Yönet butonuyla uyumlu yükseklik
                                          elevation: 0,
                                          minimumSize: Size
                                              .zero, // İçeriğe göre büzülmesine izin ver
                                        ),
                                        child: const Icon(
                                          Icons.delete_outline,
                                          size: 20,
                                          color:
                                              Colors.white, // İkon rengi beyaz
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 8,
                                      ), // İki buton arası boşluk açıldı
                                      // Mevcut Rapor Yönetimi Butonu
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          if (reportId.isNotEmpty) {
                                            _showStatusUpdateDialog(
                                              reportId,
                                              status,
                                            );
                                          } else {
                                            _showErrorSnackBar(
                                              "Geçersiz işlem: Rapor sistem kimliği (ID) bulunamadı.",
                                            );
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.edit_note,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                        label: const Text(
                                          "Yönet",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFFC8973A,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          elevation: 0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- Yardımcı Widget'lar (Helper Widgets) ---

  /// Rapor durumlarını (Status) görsel olarak temsil eden dinamik arayüz bileşeni.
  Widget _buildStatusChip(String status) {
    final Color sColor = _getStatusColor(status);
    final String sText = _getStatusTranslation(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: sColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sColor, width: 1.5),
      ),
      child: Text(
        sText,
        style: TextStyle(
          color: sColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Adminin rapor durumunu değiştirmesini sağlayan akıllı Dialog penceresi.
  void _showStatusUpdateDialog(String reportId, String currentStatus) {
    // Dropdown seçeneklerimizi bir kopyaya alıyoruz
    Map<String, String> currentDropdownOptions = Map.from(_adminStatusOptions);

    String selectedStatus = currentStatus;
    bool foundMatch = false;

    // Backend'den gelen statü (Örn: "inprogress" veya "IN_PROGRESS")
    // bizim listemizle uyuşuyorsa ("InProgress"), standarda çevir
    for (String key in currentDropdownOptions.keys) {
      if (key.toLowerCase() == currentStatus.toLowerCase()) {
        selectedStatus = key;
        foundMatch = true;
        break;
      }
    }

    // Backend bizim listemizde hiç olmayan farklı bir şey yollamışsa
    // Dropdown hata vermesin diye o değeri de geçici olarak seçeneklere ekliyoruz.
    if (!foundMatch) {
      currentDropdownOptions[selectedStatus] = _getStatusTranslation(
        selectedStatus,
      );
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                "İşlem Durumunu Güncelle",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.bogazGecesi,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Bu rapor için yeni operasyonel durumu seçiniz:",
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.bogazGecesi.withOpacity(0.5),
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedStatus,
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: AppColors.bogazGecesi,
                        ),
                        items: currentDropdownOptions.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  color: _getStatusColor(entry.key),
                                  size: 14,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  entry.value,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => selectedStatus = value);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "İptal Et",
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Sadece durum gerçekten değiştirildiyse API isteği at
                    if (selectedStatus.toLowerCase() !=
                        currentStatus.toLowerCase()) {
                      _updateReportStatus(reportId, selectedStatus);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.bogazGecesi,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "Değişikliği Kaydet",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
