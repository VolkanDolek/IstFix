import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:istfix_app/core/constants/color_constants.dart';

/// Sistem yöneticilerinin (Admin) kayıtlı tüm vatandaşları görüntülediği,
/// arama yapabildiği ve gerektiğinde kullanıcı hesaplarını kalıcı olarak sildiği kontrol paneli.
class AdminUsersView extends StatefulWidget {
  // GÜNCELLEME: Test ortamı için dışarıdan mocklanabilir servisler eklendi.
  final Dio? dio;
  final FlutterSecureStorage? secureStorage;

  const AdminUsersView({super.key, this.dio, this.secureStorage});

  @override
  State<AdminUsersView> createState() => _AdminUsersViewState();
}

class _AdminUsersViewState extends State<AdminUsersView> {
  // --- Servis ve Kontrolcü Tanımlamaları ---
  // GÜNCELLEME: Sabit atama kaldırıldı, test veya gerçek servisler initState içinde atanacak
  late final Dio _dio;
  late final FlutterSecureStorage _storage;
  final TextEditingController _searchController = TextEditingController();

  // --- Durum Yönetimi (State Variables) ---
  List<dynamic> _users =
      []; // API üzerinden çekilen orijinal kullanıcı veri seti
  List<dynamic> _filteredUsers =
      []; // Arama kriterlerine göre filtrelenmiş aktif veri seti
  bool _isLoading =
      true; // Sayfanın ve verilerin yüklenme durumunu kontrol eder

  @override
  void initState() {
    super.initState();
    // GÜNCELLEME: Dışarıdan mock servis verilmişse onu, verilmemişse orijinal paketleri kullan
    _dio = widget.dio ?? Dio(BaseOptions(baseUrl: "http://10.0.2.2:8000/api"));
    _storage = widget.secureStorage ?? const FlutterSecureStorage();
    
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- Çekirdek İşlevler (Core Functions) ---

  /// Sistemde kayıtlı vatandaşlar içerisinde 'İsim' veya 'E-posta' parametrelerine göre metin tabanlı arama gerçekleştirir.
  void _filterUsers(String query) {
    if (query.isEmpty) {
      setState(() => _filteredUsers = _users);
      return;
    }

    setState(() {
      _filteredUsers = _users.where((user) {
        final String name = user['name']?.toString().toLowerCase() ?? "";
        final String email =
            user['emailAddress']?.toString().toLowerCase() ?? "";

        final q = query.toLowerCase();
        return name.contains(q) || email.contains(q);
      }).toList();
    });
  }

  /// REST API üzerinden sistemde kayıtlı tüm vatandaşların (Citizens) verilerini asenkron olarak çeker.
  Future<void> _fetchUsers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final token = await _storage.read(key: "access_token");
      final response = await _dio.get(
        '/citizens/',
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _users = response.data is List ? response.data : [];
          _filteredUsers = _users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(
        "Kullanıcı listesi sunucudan çekilirken bir hata meydana geldi.",
      );
      setState(() => _isLoading = false);
    }
  }

  /// Kullanıcı hesabını kalıcı olarak silmeden önce yönetici onayını alan uyarı penceresini tetikler.
  Future<void> _confirmDeleteUser(String userId, String userName) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Kullanıcıyı Sil",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "$userName adlı kullanıcının hesabını sistemden kalıcı olarak silmek istediğinize emin misiniz? Bu operasyon geri alınamaz.",
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
      _deleteUser(userId);
    }
  }

  /// REST API üzerinden belirtilen kullanıcının (Citizen) kaydını sistemden kalıcı olarak siler.
  Future<void> _deleteUser(String userId) async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: "access_token");
      final response = await _dio.delete(
        '/citizens/$userId',
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Kullanıcı hesabı sistemden başarıyla silindi."),
            backgroundColor: Colors.green,
          ),
        );
        _fetchUsers(); // Veri setini güncel tutmak için listeyi yeniler
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar("Kullanıcı silinirken sistemsel bir hata oluştu.");
      setState(() => _isLoading = false);
    }
  }

  // --- Görünüm (UI) Katmanı ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.arkaplan,
      appBar: AppBar(
        title: const Text(
          "Kullanıcı Yönetimi",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.bogazGecesi,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. Arama ve Filtreleme Modülü
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterUsers,
              decoration: InputDecoration(
                hintText: "İsim veya E-posta ile kullanıcı ara...",
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.bogazGecesi,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _filterUsers("");
                          FocusScope.of(context).unfocus();
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

          // 2. Dinamik Kullanıcı Listesi Modülü
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.marmaraMavisi,
                    ),
                  )
                : _filteredUsers.isEmpty
                ? const Center(
                    child: Text("Sistemde kayıtlı kullanıcı bulunamadı."),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      final String userId = user['id']?.toString() ?? "";
                      final String name = user['name']?.toString() ?? "";
                      final String email =
                          user['emailAddress']?.toString() ??
                          "E-posta belirtilmemiş";
                      final bool isAdmin = user['isAdmin'] == true;

                      final String displayName = name.trim().isEmpty
                          ? "İsimsiz Kullanıcı"
                          : name.trim();

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
                              // Yönetici hesapları için kurumsal mavi, standart kullanıcılar için yeşil kenarlık uygulanır
                              left: BorderSide(
                                color: isAdmin
                                    ? AppColors.marmaraMavisi
                                    : AppColors.durumIletildi,
                                width: 5,
                              ),
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
                                        CircleAvatar(
                                          backgroundColor: isAdmin
                                              ? AppColors.marmaraMavisi
                                                    .withOpacity(0.2)
                                              : AppColors.durumIletildi
                                                    .withOpacity(0.2),
                                          child: Icon(
                                            isAdmin
                                                ? Icons.admin_panel_settings
                                                : Icons.person,
                                            color: isAdmin
                                                ? AppColors.marmaraMavisi
                                                : AppColors.durumIletildi,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                displayName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: AppColors.bogazGecesi,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                email,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.black54,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Kullanıcının yetki düzeyini görselleştiren sistem etiketi
                                  if (isAdmin)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.marmaraMavisi
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.marmaraMavisi,
                                        ),
                                      ),
                                      child: const Text(
                                        "ADMİN",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.marmaraMavisi,
                                        ),
                                      ),
                                    ),
                                ],
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
                                          "Sistem ID:",
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          userId,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                            color: AppColors.bogazGecesi,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // GÜNCELLEME: Rol tabanlı imha kısıtlaması katmanı
                                  // Kart sahibi sivil vatandaş ise silme aksiyonunu sağlayan buton işlenir
                                  if (!isAdmin)
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        if (userId.isNotEmpty) {
                                          _confirmDeleteUser(
                                            userId,
                                            displayName,
                                          );
                                        } else {
                                          _showErrorSnackBar(
                                            "Geçersiz işlem: Kullanıcı ID bulunamadı.",
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade500,
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
                                      icon: const Icon(
                                        Icons.person_remove_rounded,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                      label: const Text(
                                        "Hesabı Sil",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  // Kart sahibi üst düzey yönetici (Admin) ise hiyerarşik güvenliği sağlamak için imha butonu bloke edilir
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.lock_outline,
                                            size: 16,
                                            color: Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Silinemez",
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
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

  /// Operasyonel süreçlerde karşılaşılan hataları kullanıcıya bildiren dinamik arayüz elemanı.
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