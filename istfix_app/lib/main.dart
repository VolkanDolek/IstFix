import 'package:flutter/material.dart';
import 'package:istfix_app/core/constants/color_constants.dart';
import 'package:istfix_app/features/auth/welcome_view.dart';

void main() {
  runApp(const IstFixApp());
}

class IstFixApp extends StatelessWidget {
  const IstFixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IstFix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Uygulamanın genelinde senin "Boğaz Gecesi" rengini temel alıyoruz
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.bogazGecesi),
        useMaterial3: true,
      ),
      home: const WelcomeView(),
    );
  }
}
