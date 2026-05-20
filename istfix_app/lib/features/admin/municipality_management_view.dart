import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:istfix_app/core/constants/color_constants.dart';

class MunicipalityManagementView extends StatefulWidget {
  // GÜNCELLEME: Test ortamı için dışarıdan mocklanabilir servisler eklendi.
  final Dio? dio;
  final FlutterSecureStorage? secureStorage;

  const MunicipalityManagementView({
    super.key,
    this.dio,
    this.secureStorage,
  });

  @override
  State<MunicipalityManagementView> createState() =>
      _MunicipalityManagementViewState();
}

class _MunicipalityManagementViewState
    extends State<MunicipalityManagementView> {
  // GÜNCELLEME: Sabit atama kaldırıldı, test veya gerçek servisler initState içinde atanacak.
  late final Dio _dio;
  late final FlutterSecureStorage _storage;

  List<dynamic> _municipalities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // GÜNCELLEME: Dışarıdan mock servis verilmişse onu, verilmemişse orijinal paketleri kullan
    _dio = widget.dio ?? Dio(BaseOptions(baseUrl: "http://10.0.2.2:8000/api"));
    _storage = widget.secureStorage ?? const FlutterSecureStorage();

    _fetchMunicipalities();
  }

  // --- 1. GET: Tüm Belediyeleri Çek ---
  Future<void> _fetchMunicipalities() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final token = await _storage.read(key: "access_token");
      final response = await _dio.get(
        '/municipalities/',
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          // Gelen verinin kesinlikle bir liste olduğunu doğruluyoruz
          _municipalities = response.data is List ? response.data : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Belediye Çekme Hatası: $e");
      if (!mounted) return;
      _showErrorSnackBar("Belediyeler yüklenirken hata oluştu.");
      setState(() => _isLoading = false);
    }
  }

  // --- 2. POST: Yeni Belediye Ekle ---
  Future<void> _addMunicipality(String name, String email) async {
    try {
      final token = await _storage.read(key: "access_token");
      final response = await _dio.post(
        '/municipalities/',
        data: {"name": name, "officialEmail": email},
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      if (!mounted) return;

      if (response.statusCode == 201 || response.statusCode == 200) {
        _showSuccessSnackBar("Belediye başarıyla eklendi.");
        _fetchMunicipalities();
      }
    } catch (e) {
      debugPrint("Belediye Ekleme Hatası: $e");
      if (!mounted) return;
      _showErrorSnackBar("Ekleme başarısız oldu. Verileri kontrol edin.");
    }
  }

  // --- 3. PATCH: Belediye Güncelle ---
  Future<void> _updateMunicipality(String id, String name, String email) async {
    try {
      final token = await _storage.read(key: "access_token");
      final response = await _dio.patch(
        '/municipalities/$id',
        data: {"name": name, "officialEmail": email},
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        _showSuccessSnackBar("Belediye başarıyla güncellendi.");
        _fetchMunicipalities();
      }
    } catch (e) {
      debugPrint("Belediye Güncelleme Hatası: $e");
      if (!mounted) return;
      _showErrorSnackBar("Güncelleme başarısız oldu.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.arkaplan,
      appBar: AppBar(
        title: const Text(
          "Belediye Yönetimi",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.bogazGecesi,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.marmaraMavisi),
            )
          : _municipalities.isEmpty
          ? const Center(child: Text("Sistemde kayıtlı belediye bulunamadı."))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _municipalities.length,
              itemBuilder: (context, index) {
                final mun = _municipalities[index];

                // Güvenli Tip Dönüşümleri (Type Safety)
                final String id = mun['id']?.toString() ?? "";
                final String name =
                    mun['name']?.toString() ?? "İsimsiz Belediye";
                final String email =
                    mun['officialEmail']?.toString() ?? "E-Posta yok";

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            email,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.marmaraMavisi,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "ID: $id",
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.edit,
                        color: AppColors.bogazGecesi,
                      ),
                      onPressed: () {
                        if (id.isNotEmpty) {
                          _showEditDialog(id, name, email);
                        } else {
                          _showErrorSnackBar("Geçersiz Belediye ID'si.");
                        }
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFFC8973A),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Yeni Ekle",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // --- Ekleme Penceresi ---
  void _showAddDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Yeni Belediye Ekle"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Belediye Adı",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Resmi E-Posta",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  emailController.text.isNotEmpty) {
                Navigator.pop(context);
                _addMunicipality(
                  nameController.text.trim(),
                  emailController.text.trim(),
                );
              } else {
                _showErrorSnackBar("Lütfen tüm alanları doldurun.");
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bogazGecesi,
            ),
            child: const Text("Ekle", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- Düzenleme Penceresi ---
  void _showEditDialog(String id, String currentName, String currentEmail) {
    final TextEditingController nameController = TextEditingController(
      text: currentName,
    );
    final TextEditingController emailController = TextEditingController(
      text: currentEmail,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Belediye Düzenle"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "ID: $id",
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Belediye Adı",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Resmi E-Posta",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  emailController.text.isNotEmpty) {
                Navigator.pop(context);
                _updateMunicipality(
                  id,
                  nameController.text.trim(),
                  emailController.text.trim(),
                );
              } else {
                _showErrorSnackBar("Lütfen tüm alanları doldurun.");
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bogazGecesi,
            ),
            child: const Text(
              "Güncelle",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Yardımcı Uyarı Mesajları
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}