import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/discreet_mode/presentation/pages/discreet_mode_page.dart';
import '../features/guidance/presentation/pages/guidance_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/onboarding/presentation/pages/onboarding_page.dart';
import '../features/support_network/presentation/pages/support_network_page.dart';
import '../features/trusted_contact/presentation/pages/trusted_contact_page.dart';

class RedeApoioApp extends StatelessWidget {
  const RedeApoioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rede de Apoio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: OnboardingPage.routeName,
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
