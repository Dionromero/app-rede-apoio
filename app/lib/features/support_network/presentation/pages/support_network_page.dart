import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/category_tabs.dart';
import '../../data/support_network_service.dart';
import '../../domain/models/support_institution.dart';

/// Grupo de categorias exibido como chip. Um chip pode reunir várias
/// categorias do banco (ex.: "Acolhimento" = CREAS + CRAS + Centro de Referência).
typedef CategoriaFiltro = ({
  String id,
  String label,
  IconData icon,
  List<String> categorias,
});

class SupportNetworkPage extends StatefulWidget {
  const SupportNetworkPage({
    super.key,
    this.categoriaInicial,
    this.buscarLocalizacaoAoIniciar = true,
  });

  static const routeName = '/rede-apoio';

  /// Id de um chip de [SupportNetworkPage.categoriasFiltro] para abrir já filtrado.
  final String? categoriaInicial;

  /// Se deve tentar obter a localização automaticamente no carregamento inicial.
  final bool buscarLocalizacaoAoIniciar;

  static const List<CategoriaFiltro> categoriasFiltro = [
    (id: 'todos', label: 'Todos', icon: Icons.grid_view_rounded, categorias: []),
    (
      id: 'delegacias',
      label: 'Delegacias',
      icon: Icons.local_police_rounded,
      categorias: ['delegacia_mulher', 'delegacia_comum'],
    ),
    (
      id: 'acolhimento',
      label: 'Acolhimento',
      icon: Icons.favorite_rounded,
      categorias: ['centro_referencia', 'creas', 'cras', 'ong'],
    ),
    (
      id: 'juridico',
      label: 'Jurídico',
      icon: Icons.gavel_rounded,
      categorias: ['defensoria', 'ministerio_publico', 'forum'],
    ),
    (
      id: 'saude',
      label: 'Saúde',
      icon: Icons.local_hospital_rounded,
      categorias: ['hospital', 'upa'],
    ),
  ];

  @override
  State<SupportNetworkPage> createState() => _SupportNetworkPageState();
}

class _SupportNetworkPageState extends State<SupportNetworkPage> {
  static const _atrasoDigitacao = Duration(milliseconds: 400);

  final TextEditingController _buscaController = TextEditingController();
  Timer? _debounce;

  List<SupportInstitution> _instituicoes = [];
  bool _carregando = true;
  bool _offline = false;
  bool _foraDoRaio = false;
  bool _buscandoLocalizacao = false;
  String? _avisoLocalizacao;
  Position? _posicaoAtual;
  late String _filtroCategoria;

  /// Identifica a busca mais recente; respostas antigas são descartadas.
  int _buscaAtual = 0;

  @override
  void initState() {
    super.initState();
    final inicial = widget.categoriaInicial;
    _filtroCategoria = SupportNetworkPage.categoriasFiltro.any((c) => c.id == inicial)
        ? inicial!
        : 'todos';
    _buscaController.addListener(_aoDigitar);

    // Mostra resultados imediatamente e, em paralelo, tenta a localização
    // para reordenar por distância quando ela chegar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _buscar();
      if (widget.buscarLocalizacaoAoIniciar) {
        _atualizarLocalizacao();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _buscaController.dispose();
    super.dispose();
  }

  List<String> get _categoriasSelecionadas => SupportNetworkPage.categoriasFiltro
      .firstWhere((c) => c.id == _filtroCategoria)
      .categorias;

  void _aoDigitar() {
    setState(() {}); // atualiza o botão de limpar
    _debounce?.cancel();
    _debounce = Timer(_atrasoDigitacao, _buscar);
  }

  void _selecionarCategoria(String id) {
    if (id == _filtroCategoria) return;
    setState(() => _filtroCategoria = id);
    _buscar();
  }

  Future<void> _buscar() async {
    final idBusca = ++_buscaAtual;
    setState(() => _carregando = true);

    final resultado = await SupportNetworkService.buscarInstituicoes(
      texto: _buscaController.text,
      categorias: _categoriasSelecionadas,
      lat: _posicaoAtual?.latitude,
      lng: _posicaoAtual?.longitude,
      // Com texto digitado, procura em toda a base (ela pode buscar um local distante).
      raioKm: _buscaController.text.trim().isEmpty ? AppConfig.raioBuscaKm : null,
    );

    if (!mounted || idBusca != _buscaAtual) return;
    setState(() {
      _instituicoes = resultado.instituicoes;
      _offline = resultado.offline;
      _foraDoRaio = resultado.foraDoRaio;
      _carregando = false;
    });
  }

  Future<void> _atualizarLocalizacao() async {
    if (_buscandoLocalizacao) return;
    setState(() {
      _buscandoLocalizacao = true;
      _avisoLocalizacao = null;
    });

    Position? posicao;
    try {
      // Tempo suficiente para a usuária responder ao pedido de permissão.
      posicao = await LocationService.obterPosicaoAtual().timeout(
        const Duration(seconds: 20),
        onTimeout: () => null,
      );
    } catch (_) {
      posicao = null;
    }

    if (!mounted) return;
    setState(() {
      _buscandoLocalizacao = false;
      if (posicao != null) _posicaoAtual = posicao;
      if (_posicaoAtual == null) {
        _avisoLocalizacao = 'Sem localização: resultados em ordem alfabética.';
      }
    });

    if (posicao != null) _buscar();
  }

  void _limparFiltros() {
    _debounce?.cancel();
    _buscaController.removeListener(_aoDigitar);
    _buscaController.clear();
    _buscaController.addListener(_aoDigitar);
    setState(() => _filtroCategoria = 'todos');
    _buscar();
  }

  void _abrirDetalhes(SupportInstitution inst) {
    InstitutionDetailsSheet.show(context, inst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.xs),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Voltar',
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rede de Apoio',
                          style: AppFonts.serif(size: 26, peso: 600, height: 1.1),
                        ),
                        Text(
                          'Pontos de atendimento e proteção',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _buscar,
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Atualizar locais',
                  ),
                ],
              ),
            ),

            // ── Barra de Busca ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: AppSpacing.xs),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppShape.radius),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _buscaController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) {
                    _debounce?.cancel();
                    _buscar();
                  },
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome, bairro ou serviço...',
                    hintStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                    suffixIcon: _buscaController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            tooltip: 'Limpar busca',
                            onPressed: () => _buscaController.clear(),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                  ),
                ),
              ),
            ),

            // ── Abas de categoria (mesmo componente da Home e do mapa) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xs, 0, AppSpacing.xs),
              child: CategoryTabs(
                itens: [for (final c in SupportNetworkPage.categoriasFiltro) (c.id, c.label)],
                selecionado: _filtroCategoria,
                onSelecionar: _selecionarCategoria,
              ),
            ),

            // ── Avisos: offline / localização ──────────────────────────
            if (_offline)
              const _AvisoBanner(
                icon: Icons.cloud_off_rounded,
                texto: 'Sem conexão: mostrando a lista essencial salva no aparelho '
                    '(${SupportNetworkService.cidadePiloto}).',
              ),
            if (_buscandoLocalizacao)
              const _AvisoBanner(
                icon: Icons.my_location_rounded,
                texto: 'Obtendo sua localização para ordenar por distância...',
                neutro: true,
              )
            else if (_avisoLocalizacao != null)
              _AvisoBanner(
                icon: Icons.location_off_rounded,
                texto: _avisoLocalizacao!,
                acao: 'Usar localização',
                onAcao: _atualizarLocalizacao,
              )
            else if (_posicaoAtual != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xxs, AppSpacing.screen, AppSpacing.xs),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.moss,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        _foraDoRaio
                            ? 'Nada a até ${AppConfig.raioBuscaKm.round()} km: mostrando os mais próximos'
                            : 'Locais a até ${AppConfig.raioBuscaKm.round()} km, do mais perto ao mais longe',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.moss,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Lista de Locais ────────────────────────────────────────
            Expanded(
              child: _carregando && _instituicoes.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(strokeWidth: 2.5),
                          SizedBox(height: AppSpacing.md),
                          Text(
                            'Buscando rede de apoio...',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : _instituicoes.isEmpty
                      ? _ListaVazia(onLimpar: _limparFiltros)
                      : Stack(
                          children: [
                            ListView.separated(
                              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xxs, AppSpacing.screen, AppSpacing.xl),
                              itemCount: _instituicoes.length,
                              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                              itemBuilder: (context, index) {
                                final inst = _instituicoes[index];
                                return _InstituicaoCard(
                                  key: ValueKey(inst.id),
                                  instituicao: inst,
                                  onTap: () => _abrirDetalhes(inst),
                                )
                                    .animate()
                                    .fadeIn(delay: (math.min(index, 8) * 45).ms, duration: AppShape.medio)
                                    .slideY(
                                      begin: 0.06,
                                      delay: (math.min(index, 8) * 45).ms,
                                      duration: AppShape.lento,
                                      curve: AppShape.curva,
                                    );
                              },
                            ),
                            if (_carregando)
                              const Positioned(
                                top: 0,
                                left: 20,
                                right: 20,
                                child: LinearProgressIndicator(minHeight: 2),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widget: Aviso em faixa ───────────────────────────────────────────────────

class _AvisoBanner extends StatelessWidget {
  const _AvisoBanner({
    required this.icon,
    required this.texto,
    this.acao,
    this.onAcao,
    this.neutro = false,
  });

  final IconData icon;
  final String texto;
  final String? acao;
  final VoidCallback? onAcao;
  final bool neutro;

  @override
  Widget build(BuildContext context) {
    final cor = neutro ? AppColors.ink : AppColors.wine;
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xxs, AppSpacing.screen, AppSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: neutro ? AppColors.inkSoft : AppColors.wineSoft,
        borderRadius: BorderRadius.circular(AppShape.radiusSm),
        border: Border.all(color: neutro ? AppColors.border : AppColors.hairline),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cor),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(texto, style: TextStyle(fontSize: 12, color: cor)),
          ),
          if (acao != null && onAcao != null)
            TextButton(
              onPressed: onAcao,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 36), // tema usa largura infinita
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(acao!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

// ── Widget: Lista vazia ──────────────────────────────────────────────────────

class _ListaVazia extends StatelessWidget {
  const _ListaVazia({required this.onLimpar});

  final VoidCallback onLimpar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Nenhum local encontrado',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Tente outra palavra ou categoria. Se precisar de orientação agora, '
              'o Ligue 180 funciona 24 horas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: onLimpar,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Ver todas as instituições'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppShape.radiusSm)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widget: Selo de verificação ──────────────────────────────────────────────

class _SeloVerificacao extends StatelessWidget {
  const _SeloVerificacao({required this.instituicao});

  final SupportInstitution instituicao;

  @override
  Widget build(BuildContext context) {
    final verificado = instituicao.isVerified();
    final cor = verificado ? AppColors.moss : AppColors.wine;
    return Row(
      children: [
        Icon(
          verificado ? Icons.verified_rounded : Icons.error_outline_rounded,
          size: 15,
          color: cor,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            instituicao.verificationLabel(),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cor),
          ),
        ),
      ],
    );
  }
}

// ── Widget: Card de Instituição ──────────────────────────────────────────────

class _InstituicaoCard extends StatelessWidget {
  const _InstituicaoCard({
    required this.instituicao,
    required this.onTap,
    super.key,
  });

  final SupportInstitution instituicao;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final temTelefone = instituicao.phone != null;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppShape.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppShape.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppShape.radiusLg),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Topo do card: Categoria, Ícone e Distância
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: instituicao.softThemeColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      instituicao.icon,
                      color: instituicao.themeColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          instituicao.categoryLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: instituicao.themeColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          instituicao.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (instituicao.formattedDistance != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                      decoration: BoxDecoration(
                        color: AppColors.inkSoft,
                        borderRadius: BorderRadius.circular(AppShape.radiusSm),
                      ),
                      child: Text(
                        instituicao.hasApproximateLocation
                            ? '~${instituicao.formattedDistance!}'
                            : instituicao.formattedDistance!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: AppSpacing.sm),

              // Endereço
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.place_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      '${instituicao.address} — ${instituicao.city}, ${instituicao.state}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),

              // Público atendido
              if (instituicao.targetAudience != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.groups_outlined, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        instituicao.targetAudience!,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: AppSpacing.xs),

              // Horário
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: instituicao.is24Hours ? AppColors.moss : AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      instituicao.formattedOpeningHours,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: instituicao.is24Hours ? FontWeight.w700 : FontWeight.w500,
                        color: instituicao.is24Hours ? AppColors.moss : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xs),
              _SeloVerificacao(instituicao: instituicao),

              const SizedBox(height: AppSpacing.md),

              // Botões de Ação rápida
              Row(
                children: [
                  if (temTelefone) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => SupportNetworkService.ligar(instituicao.phone!),
                        icon: const Icon(Icons.phone_rounded, size: 16),
                        label: Text(
                          instituicao.phone!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppShape.radiusSm)),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => SupportNetworkService.abrirNoMapa(instituicao),
                      icon: const Icon(Icons.directions_rounded, size: 16),
                      label: const Text('Como chegar', style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        backgroundColor: instituicao.themeColor,
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppShape.radiusSm)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── BottomSheet: Detalhes da Instituição ─────────────────────────────────────

/// Detalhes de uma instituição em bottom sheet. Usado na lista e no mapa.
class InstitutionDetailsSheet extends StatelessWidget {
  const InstitutionDetailsSheet({required this.instituicao, super.key});

  final SupportInstitution instituicao;

  static Future<void> show(BuildContext context, SupportInstitution instituicao) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InstitutionDetailsSheet(instituicao: instituicao),
    );
  }

  @override
  Widget build(BuildContext context) {
    final telefones = [instituicao.phone, instituicao.phone2].whereType<String>().toList();
    const rotulo = TextStyle(fontSize: 12, color: AppColors.textSecondary);
    const valor = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.xxl),
          children: [
            // Barra de puxar
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Cabeçalho
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: instituicao.softThemeColor,
                    borderRadius: BorderRadius.circular(AppShape.radius),
                  ),
                  child: Icon(instituicao.icon, color: instituicao.themeColor, size: 28),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        instituicao.categoryLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: instituicao.themeColor,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        instituicao.name,
                        style: AppFonts.serif(size: 22, peso: 600, height: 1.15),
                      ),
                      if (instituicao.subcategory != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(instituicao.subcategory!, style: rotulo),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),
            _SeloVerificacao(instituicao: instituicao),
            const SizedBox(height: AppSpacing.xs),

            // Endereço
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.place_rounded, color: AppColors.ink),
              title: const Text('Endereço', style: rotulo),
              subtitle: Text(
                '${instituicao.address}\n${instituicao.city} - ${instituicao.state}'
                '${instituicao.zipCode != null ? ' • CEP: ${instituicao.zipCode}' : ''}'
                '${instituicao.hasApproximateLocation ? '\nPosição no mapa aproximada: confira o endereço.' : ''}',
                style: valor,
              ),
            ),

            // Público atendido
            if (instituicao.targetAudience != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.groups_rounded, color: AppColors.ink),
                title: const Text('Quem é atendido', style: rotulo),
                subtitle: Text(instituicao.targetAudience!, style: valor),
              ),

            // Horário
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_rounded, color: AppColors.ink),
              title: const Text('Horário de atendimento', style: rotulo),
              subtitle: Text(
                instituicao.formattedOpeningHours,
                style: valor.copyWith(
                  color: instituicao.is24Hours ? AppColors.moss : AppColors.textPrimary,
                ),
              ),
            ),

            // Telefones
            if (telefones.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_rounded, color: AppColors.ink),
                title: const Text('Telefones', style: rotulo),
                subtitle: Text(telefones.join('  •  '), style: valor),
              ),

            // Serviços Oferecidos
            if (instituicao.services.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Serviços disponíveis:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: instituicao.servicesLabels.map((label) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Fonte oficial
            if (instituicao.sourceUrl != null) ...[
              const SizedBox(height: AppSpacing.md),
              InkWell(
                onTap: () => SupportNetworkService.abrirFonte(instituicao.sourceUrl!),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      const Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.ink),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Fonte: ${instituicao.sourceName ?? 'página oficial'}',
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

            const SizedBox(height: AppSpacing.xl),

            // Ações principais
            Row(
              children: [
                if (instituicao.phone != null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => SupportNetworkService.ligar(instituicao.phone!),
                      icon: const Icon(Icons.phone_rounded),
                      label: const Text('Ligar'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => SupportNetworkService.abrirNoMapa(instituicao),
                    icon: const Icon(Icons.directions_rounded),
                    label: const Text('Como chegar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: instituicao.themeColor,
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
