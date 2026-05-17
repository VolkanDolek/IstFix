import 'package:flutter/material.dart';
import 'package:istfix_app/core/constants/color_constants.dart';
import 'package:istfix_app/features/admin/admin_main_tab_view.dart';
import 'package:istfix_app/features/auth/login_view.dart';
import 'package:istfix_app/features/main/main_tab_view.dart';
import 'package:istfix_app/services/auth_service.dart';

/// Uygulamanın ilk açılışında oturum durumunu ve kullanıcı rolünü
/// denetleyerek doğru arayüze yönlendiren köprü widget.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _authService.shouldAutoLogin(),
      builder: (context, snapshot) {
        // Oturum durumu henüz yerel hafızadan (Secure Storage) okunurken yüklendi ekranı gösterilir
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.arkaplan,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.bogazGecesi),
            ),
          );
        }

        // Eğer geçerli bir token var ve "Beni Hatırla" seçilmişse
        if (snapshot.data == true) {
          return FutureBuilder<bool>(
            future: _authService.checkIsAdmin(),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: AppColors.arkaplan,
                  body: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.bogazGecesi,
                    ),
                  ),
                );
              }

              // Kullanıcı admin ise yönetim paneline, değilse citizen tab barına yönlendirilir
              final bool isAdmin = roleSnapshot.data ?? false;
              if (isAdmin) {
                return const AdminMainTabView();
              } else {
                return const MainTabView();
              }
            },
          );
        }

        // Aktif bir oturum bulunamadıysa kullanıcı doğrudan giriş ekranına yönlendirilir
        return const LoginView();
      },
    );
  }
}
