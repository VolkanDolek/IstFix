import 'package:flutter/material.dart';
import 'package:istfix_app/core/constants/color_constants.dart';
import 'package:istfix_app/features/auth/welcome_view.dart';
import 'package:istfix_app/features/main/main_tab_view.dart';
import 'package:istfix_app/features/admin/admin_main_tab_view.dart';
import 'package:istfix_app/features/main/connectivity_wrapper.dart';
import 'package:istfix_app/services/auth_service.dart';

// =========================================================================
// GÜNCELLEME: GLOBAL NAVIGATOR ANAHTARI
// Bu anahtar sayesinde uygulamanın UI ağacında (context) olmasak bile
// auth_service.dart içindeki Dio Interceptor'dan yönlendirme yapabiliriz.
// =========================================================================
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Uygulamanın başlangıç noktası (Entry Point).
///
/// Asenkron operasyonlar (kimlik doğrulama, yerel depolama okuma vb.)
/// tamamlandıktan sonra [IstFixApp] kök widget'ını ayağa kaldırır.
void main() async {
  // Donanım servislerinin ve asenkron Flutter motoru bağlamalarının
  // UI çizilmeden önce hazır ve güvenli durumda olmasını garanti eder.
  WidgetsFlutterBinding.ensureInitialized();

  // --- OTURUM VE YETKİ YÖNETİMİ (SESSION & RBAC INITIALIZATION) ---
  final authService = AuthService();

  // 1. Kullanıcının cihazında geçerli bir JWT token olup olmadığını kontrol eder.
  final bool canAutoLogin = await authService.shouldAutoLogin();

  // 2. Eğer aktif bir oturum varsa, kullanıcının rolünü (Admin/Citizen) sorgular.
  bool isAdmin = false;
  if (canAutoLogin) {
    isAdmin = await authService.checkIsAdmin();
  }

  // Uygulamayı tespit edilen oturum ve yetki parametreleriyle başlatır.
  runApp(IstFixApp(isLoggedIn: canAutoLogin, isAdmin: isAdmin));
}

/// İstFix uygulamasının kök (Root) bileşeni.
///
/// Global temalandırma, temel yönlendirme mantığı (Routing) ve
/// bağlantı dinleyicisi (Connectivity Interceptor) gibi üst düzey yapılandırmaları barındırır.
class IstFixApp extends StatelessWidget {
  /// Cihazda aktif ve geçerli bir kullanıcı oturumu olup olmadığını belirtir.
  final bool isLoggedIn;

  /// Oturum açan kullanıcının sistem yöneticisi (Admin) yetkilerine sahip olup olmadığını belirtir.
  final bool isAdmin;

  const IstFixApp({super.key, required this.isLoggedIn, this.isAdmin = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // GÜNCELLEME: Tanımladığımız anahtarı Material App'e bağlıyoruz
      navigatorKey: navigatorKey,

      title: 'IstFix',
      debugShowCheckedModeBanner: false,

      // --- GLOBAL TEMA YAPILANDIRMASI (MATERIAL 3) ---
      theme: ThemeData(
        // Kurumsal marka kimliğine uygun dinamik renk şeması oluşturulur.
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.bogazGecesi,
          primary: AppColors.bogazGecesi,
          secondary: AppColors.marmaraMavisi,
        ),
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),

      // --- GLOBAL SARMALAYICI (WRAPPER / INTERCEPTOR) ---
      // [builder] parametresi, uygulamanın tüm Navigator hiyerarşisinin en üstünde yer alır.
      // ConnectivityWrapper ile internet bağlantısı anlık dinlenir ve bağlantı koptuğunda
      // kullanıcının mevcut sayfa durumu (State) bozulmadan uyarı ekranı gösterilir.
      builder: (context, child) {
        return ConnectivityWrapper(child: child!);
      },

      // =========================================================================
      // GÜNCELLEME: ROTALAR (ROUTES)
      // Dio Interceptor 403 hatası aldığında pushNamedAndRemoveUntil('/login')
      // yapabilsin diye bu rotayı öğretiyoruz.
      // =========================================================================
      routes: {'/login': (context) => const WelcomeView()},

      // --- ROL TABANLI YÖNLENDİRME (RBAC ROUTING) ---
      // Kullanıcının oturum ve yetki durumuna göre başlangıç ekranını dinamik olarak belirler:
      // 1. Admin yetkisi varsa -> Yönetici Paneli (AdminMainTabView)
      // 2. Standart vatandaş yetkisi varsa -> Vatandaş Paneli (MainTabView)
      // 3. Geçerli bir oturum yoksa -> Karşılama/Giriş Ekranı (WelcomeView)
      home: isLoggedIn
          ? (isAdmin ? const AdminMainTabView() : const MainTabView())
          : const WelcomeView(),
    );
  }
}
