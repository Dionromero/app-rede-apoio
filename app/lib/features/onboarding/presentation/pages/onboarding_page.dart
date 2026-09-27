import 'package:flutter/material.dart';

import '../../../home/presentation/pages/home_page.dart';
import '../../../trusted_contact/presentation/pages/trusted_contact_page.dart';
import '../../../../core/theme/app_spacing.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  static const routeName = '/';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Icon(
                Icons.shield_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Uma rede de apoio mais perto de você',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Encontre serviços, cadastre uma pessoa de confiança e acesse canais oficiais.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(
                    context,
                    TrustedContactPage.routeName,
                  );
                },
                child: const Text('Configurar aplicativo'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, HomePage.routeName);
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Acessar ajuda agora'),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Em emergência imediata, ligue para 190.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
