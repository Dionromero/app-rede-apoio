import 'package:flutter/material.dart';

import '../../../../core/content/app_content.dart';
import '../../../../core/content/app_content_repository.dart';
import '../../../../core/content/guide_icons.dart';
import '../../../../core/services/emergency_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/category_tabs.dart';
import 'guide_detail_page.dart';

/// Lista dos guias de direitos e orientações (vindos de `get_app_bootstrap`,
/// com cache offline).
class GuidancePage extends StatefulWidget {
  const GuidancePage({super.key});

  static const routeName = '/orientacoes';

  @override
  State<GuidancePage> createState() => _GuidancePageState();
}

class _GuidancePageState extends State<GuidancePage> {
  AppContent? _conteudo;
  bool _carregando = true;
  String _categoria = 'todas';

  static const _nomesCategorias = {
    'emergencia': 'Emergência',
    'seguranca': 'Segurança',
    'direitos': 'Direitos',
    'financeiro': 'Apoio financeiro',
  };

  static String nomeCategoria(String id) =>
      _nomesCategorias[id] ??
      (id.isEmpty ? 'Outros' : id[0].toUpperCase() + id.substring(1));

  AppContentRepository get _repo => AppContentRepository.instance;

  @override
  void initState() {
    super.initState();
    _conteudo = _repo.atual;
    _carregando = _conteudo == null;
    _carregar();
  }

  Future<void> _carregar() async {
    AppContent conteudo;
    try {
      conteudo = await _repo.carregar();
    } catch (_) {
      conteudo = await _repo.carregarEmbutido();
    }
    if (!mounted) return;
    setState(() {
      _conteudo = conteudo;
      _carregando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final conteudo = _conteudo;
    final guias = conteudo?.guides ?? const <Guide>[];
    final categorias = <String>{for (final g in guias) g.category}.toList();
    final filtrados = _categoria == 'todas'
        ? guias
        : guias.where((g) => g.category == _categoria).toList();
    final algumSemRevisao = guias.any((g) => !g.isReviewed);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Direitos e orientações')),
      body: _carregando && conteudo == null
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
          : RefreshIndicator(
              onRefresh: _carregar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen,
                    AppSpacing.xs, AppSpacing.screen, AppSpacing.xl),
                children: [
                  Text(
                    'Informação para você entender seus direitos e decidir os próximos passos.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  if (algumSemRevisao)
                    const _Aviso(
                      icon: Icons.fact_check_outlined,
                      texto:
                          'Conteúdo em revisão por profissionais da rede de atendimento. '
                          'Em caso de dúvida, ligue 180.',
                    ),
                  if (conteudo != null &&
                      conteudo.origin != ContentOrigin.servidor)
                    const _Aviso(
                      icon: Icons.cloud_off_rounded,
                      texto:
                          'Sem conexão: mostrando o conteúdo salvo no aparelho.',
                    ),

                  // Filtro por tema: mesmas abas da Home, do mapa e da lista.
                  CategoryTabs(
                    itens: [
                      for (final id in ['todas', ...categorias])
                        (id, id == 'todas' ? 'Todos' : nomeCategoria(id)),
                    ],
                    selecionado: _categoria,
                    onSelecionar: (id) => setState(() => _categoria = id),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  for (final guia in filtrados) _GuiaCard(guia: guia),

                  const SizedBox(height: AppSpacing.sm),
                  const _RodapeEmergencia(),
                ],
              ),
            ),
    );
  }
}

class _GuiaCard extends StatelessWidget {
  const _GuiaCard({required this.guia});

  final Guide guia;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppShape.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppShape.radiusLg),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => GuideDetailPage(guia: guia)),
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppShape.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: guia.category == 'emergencia'
                        ? AppColors.wineSoft
                        : AppColors.inkSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ExcludeSemantics(
                    child: Icon(
                      GuideIcons.de(guia),
                      size: 22,
                      color: guia.category == 'emergencia'
                          ? AppColors.wine
                          : AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _GuidancePageState.nomeCategoria(guia.category)
                            .toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: guia.category == 'emergencia'
                              ? AppColors.wine
                              : AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        guia.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        guia.summary,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icon, required this.texto});

  final IconData icon;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.wineSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.wine),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(texto,
                style:
                    const TextStyle(fontSize: 12.5, color: AppColors.wineDeep)),
          ),
        ],
      ),
    );
  }
}

/// Atalhos para 190 e 180, sempre visíveis no fim das telas de conteúdo.
class _RodapeEmergencia extends StatelessWidget {
  const _RodapeEmergencia();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => EmergencyService.confirmarELigar190(context),
            style: FilledButton.styleFrom(backgroundColor: AppColors.emergency),
            icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
            label: const Text('190'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => EmergencyService.confirmarELigar180(context),
            style: FilledButton.styleFrom(backgroundColor: AppColors.wineSoft),
            icon: const Icon(Icons.support_agent_rounded, size: 18),
            label: const Text('Ligue 180'),
          ),
        ),
      ],
    );
  }
}
