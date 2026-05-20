import 'package:flutter/material.dart';
import 'package:istfix_app/core/constants/color_constants.dart';
import 'package:istfix_app/features/admin/admin_dashboard_view.dart';
import 'package:istfix_app/features/admin/municipality_management_view.dart';
import 'package:istfix_app/features/admin/admin_users_view.dart';

class AdminMainTabView extends StatefulWidget {
  // GÜNCELLEME: Test ortamı için dışarıdan sahte (mock) sayfalar verilmesine olanak sağlandı.
  final List<Widget>? mockPages;

  // GÜNCELLEME: Constructor güncellendi.
  const AdminMainTabView({super.key, this.mockPages});

  @override
  State<AdminMainTabView> createState() => _AdminMainTabViewState();
}

class _AdminMainTabViewState extends State<AdminMainTabView> {
  int _currentIndex = 0;

  // Admin sekmelerinin listesi
  // GÜNCELLEME: Sayfaların durumunu test/gerçek senaryoya göre başlatmak için 'late final' yapıldı.
  late final List<Widget> _adminPages;

  // GÜNCELLEME: Sayfa yüklenirken dışarıdan verilmiş sayfalar varsa onları, yoksa orijinalini kullanıyoruz.
  @override
  void initState() {
    super.initState();
    _adminPages = widget.mockPages ?? [
      const AdminDashboardView(), // Sekme 0: Tüm Raporların Listesi
      const MunicipalityManagementView(), // Sekme 1: Belediye Ekleme/Düzenleme
      const AdminUsersView(), // Sekme 2: Kullanıcı (Vatandaş) Yönetimi
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.arkaplan,

      // Sayfa durumlarını korumak için IndexedStack mimarisi kullanıyoruz
      body: IndexedStack(index: _currentIndex, children: _adminPages),

      // Admin için uygun, temiz ve net bir alt menü tasarımı
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: AppColors.bogazGecesi,
          selectedItemColor: const Color(0xFFC8973A), // İstFix Sarısı
          unselectedItemColor: Colors.white70,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          type: BottomNavigationBarType
              .fixed, // Sekme boyutlarını sabitlemek için
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              activeIcon: Icon(Icons.analytics),
              label: "Raporlar",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_outlined),
              activeIcon: Icon(Icons.account_balance),
              label: "Belediyeler",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_alt_outlined),
              activeIcon: Icon(Icons.people_alt),
              label: "Vatandaşlar",
            ),
          ],
        ),
      ),
    );
  }
}