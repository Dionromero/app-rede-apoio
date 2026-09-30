import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_theme.dart';
import '../features/discreet_mode/presentation/pages/discreet_mode_page.dart';
import '../features/guidance/presentation/pages/guidance_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/onboarding/presentation/pages/onboarding_page.dart';
import '../features/support_network/presentation/pages/support_network_page.dart';
import '../features/trusted_contact/presentation/pages/trusted_contact_page.dart';

/// Controla se a tela de boas-vindas já foi vista neste aparelho.
abstract final class BoasVindas {
  static const _chave = 'boas_vindas_vista';

  static Future<bool> jaVista() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_chave) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> marcarComoVista() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_chave, true);
    } catch (_) {
      // Sem armazenamento: a tela volta a aparecer, sem outro prejuízo.
    }
  }
}

class RedeApoioApp extends StatelessWidget {
  const RedeApoioApp({this.mostrarBoasVindas = true, super.key});

  /// `false` depois do primeiro uso: o app abre direto na tela inicial.
  final bool mostrarBoasVindas;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sussurro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Uma rota inicial só (sem empilhar '/' embaixo de '/inicio', que
      // faria o "voltar" da tela inicial cair nas boas-vindas).
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute<void>(
          settings: RouteSettings(name: mostrarBoasVindas ? OnboardingPage.routeName : HomePage.routeName),
          builder: (_) => mostrarBoasVindas ? const OnboardingPage() : const HomePage(),
        ),
      ],
      routes: {
        OnboardingPage.routeName: (_) => const OnboardingPage(),
        HomePage.routeName: (_) => const HomePage(),
        TrustedContactPage.routeName: (_) => const TrustedContactPage(),
        SupportNetworkPage.routeName: (_) => const SupportNetworkPage(),
        GuidancePage.routeName: (_) => const GuidancePage(),
        DiscreetModePage.routeName: (_) => const DiscreetModePage(),
      },
    );
  }
}
