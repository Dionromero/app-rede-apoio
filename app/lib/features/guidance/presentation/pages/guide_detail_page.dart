import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/content/app_content.dart';
import '../../../../core/content/guide_icons.dart';
import '../../../../core/services/emergency_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/simple_markdown.dart';

/// Leitura de um guia de direitos/orientação.
class GuideDetailPage extends StatelessWidget {
  const GuideDetailPage({required this.guia, super.key});

  final Guide guia;

  @override
  Widget build(BuildContext context) {
    final revisado = guia.reviewedAt;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.xl),
          children: [
            // Cabeçalho: ícone do guia e título em serifa.
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: guia.category == 'emergencia' ? AppColors.wineSoft : AppColors.inkSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                GuideIcons.de(guia),
                size: 24,
                color: guia.category == 'emergencia' ? AppColors.wine : AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(guia.title, style: AppFonts.serif(size: 30, peso: 560, height: 1.1)),
            const SizedBox(height: AppSpacing.xs),
            Text(guia.summary, style: const TextStyle(fontSize: 16, height: 1.5, color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.lg),
            SimpleMarkdown(guia.content, omitirPrimeiroTitulo: true),
            const SizedBox(height: AppSpacing.md),
            const Divider(),
            const SizedBox(height: AppSpacing.xs),

            // Situação da revisão
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  revisado != null ? Icons.verified_rounded : Icons.fact_check_outlined,
                  size: 16,
                  color: revisado != null ? AppColors.moss : AppColors.wine,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    revisado != null
                        ? 'Revisado por profissional da rede em '
                            '${revisado.day.toString().padLeft(2, '0')}/'
                            '${revisado.month.toString().padLeft(2, '0')}/${revisado.year}.'
                        : 'Aguardando revisão por profissional da rede de atendimento.',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),

            // Fonte
            if (guia.sourceUrl != null) ...[
              const SizedBox(height: AppSpacing.xs),
              InkWell(
                onTap: () => launchUrl(Uri.parse(guia.sourceUrl!), mode: LaunchMode.externalApplication),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                  child: Row(
                    children: [
                      const Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.ink),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Fonte: ${guia.sourceName ?? 'página oficial'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.ink,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.md),
            const Text(
              'Este conteúdo orienta, mas não substitui atendimento especializado.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xs, AppSpacing.screen, AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => EmergencyService.confirmarELigar190(context),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.emergency),
                  icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                  label: const Text('Emergência 190'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => EmergencyService.confirmarELigar180(context),
                  icon: const Icon(Icons.support_agent_rounded, size: 18),
                  label: const Text('Ligue 180'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
