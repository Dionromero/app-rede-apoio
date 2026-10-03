import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../app/app.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../../trusted_contact/presentation/pages/trusted_contact_page.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  static const routeName = '/';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final alturaTela = MediaQuery.sizeOf(context).height;

    // Atraso dentro do efeito (e não em animate(delay:)), sem Timer pendente.
    Widget entrada(Widget filho, int ordem) => filho
        .animate()
        .fadeIn(delay: (90 * ordem).ms, duration: AppShape.lento)
        .slideY(begin: 0.05, delay: (90 * ordem).ms, duration: AppShape.lento, curve: AppShape.curva);

    return Scaffold(
      backgroundColor: AppColors.sand,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, restricoes) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: AppSpacing.lg),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: restricoes.maxHeight - AppSpacing.lg * 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ilustração da marca: a mulher em perfil pedindo silêncio.
                  entrada(
                    ExcludeSemantics(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppShape.radiusLg),
                        child: Image.asset(
                          'assets/brand/ilustracao-1024.png',
                          height: (alturaTela * 0.36).clamp(200.0, 340.0).toDouble(),
                          width: double.infinity,
                          fit: BoxFit.cover,
                          alignment: const Alignment(0, -0.2),
                        ),
                      ),
                    ),
                    0,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  entrada(
                    Text(
                      'Uma rede de apoio mais perto de você.',
                      style: AppFonts.serif(size: 32, peso: 560, height: 1.1),
                    ),
                    1,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  entrada(
                    Text(
                      'Encontre serviços em Curitiba, cadastre pessoas de confiança e '
                      'acesse canais oficiais. Sem cadastro e sem login.',
                      style: t.bodyLarge?.copyWith(color: AppColors.textSecondary, height: 1.5),
                    ),
                    2,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  entrada(
                    Column(
                      children: [
                        FilledButton(
                          onPressed: () {
                            BoasVindas.marcarComoVista();
                            Navigator.pushReplacementNamed(context, TrustedContactPage.routeName);
                          },
                          child: const Text('Configurar aplicativo'),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        OutlinedButton(
                          onPressed: () {
                            BoasVindas.marcarComoVista();
                            Navigator.pushReplacementNamed(context, HomePage.routeName);
                            const ButtonStyle(backgroundColor: WidgetStatePropertyAll(AppColors.wine));
                          },
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: AppColors.wineSoft),
                          child: const Text('Acessar ajuda agora'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Em emergência imediata, ligue para 190.',
                          textAlign: TextAlign.center,
                          style: t.bodySmall?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
