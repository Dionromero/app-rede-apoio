import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/category_tabs.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/support_network_map.dart';
import '../../data/route_service.dart';
import '../../data/support_network_service.dart';
import '../../domain/models/route_plan.dart';
import '../../domain/models/support_institution.dart';
import 'support_network_page.dart';

/// Explorar o mapa da rede de apoio em tela cheia.
///
/// Toque num pino → painel com o local. "Como chegar" → a rota é calculada
/// e desenhada no próprio mapa (a pé ou de carro), com tempo, distância e
/// passo a passo. A navegação por voz fica com o GPS do celular.
class SupportMapPage extends StatefulWidget {
  const SupportMapPage({
    required this.instituicoes,
    this.posicaoUsuaria,
    this.categoriaInicial = 'todos',
    this.selecionadaInicial,
    super.key,
  });

  final List<SupportInstitution> instituicoes;
  final Position? posicaoUsuaria;
  final String categoriaInicial;

  /// Grupo de instituições (mesmo endereço) já selecionado ao abrir.
  final List<SupportInstitution>? selecionadaInicial;

  /// Compatibilidade: abre detalhes (1 local) ou a lista do endereço.
  static Future<void> mostrarGrupo(BuildContext context, List<SupportInstitution> grupo) async {
    if (grupo.length == 1) return InstitutionDetailsSheet.show(context, grupo.first);
    final escolhida = await showModalBottomSheet<SupportInstitution>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(child: _ListaDoEndereco(grupo: grupo, onEscolher: (i) => Navigator.pop(ctx, i))),
    );
    if (escolhida != null && context.mounted) await InstitutionDetailsSheet.show(context, escolhida);
  }

  @override
  State<SupportMapPage> createState() => _SupportMapPageState();
}

enum _Painel { nenhum, grupo, local, rota }

class _SupportMapPageState extends State<SupportMapPage> {
  late String _filtro = widget.categoriaInicial;
  Position? _posicao;
  bool _carregandoLocalizacao = false;

  List<SupportInstitution> _grupo = const [];
  SupportInstitution? _selecionada;

  TravelMode _modo = TravelMode.aPe;
  RoutePlan? _rota;
  bool _calculandoRota = false;
  String? _erroRota;

  _Painel get _painel {
    if (_rota != null || _calculandoRota || _erroRota != null) return _Painel.rota;
    if (_selecionada != null) return _Painel.local;
    if (_grupo.length > 1) return _Painel.grupo;
    return _Painel.nenhum;
  }

  @override
  void initState() {
    super.initState();
    _posicao = widget.posicaoUsuaria;
    final inicial = widget.selecionadaInicial;
    if (inicial != null && inicial.isNotEmpty) {
      _grupo = inicial;
      if (inicial.length == 1) _selecionada = inicial.first;
    }
  }

  List<SupportInstitution> get _visiveis {
    final categorias = SupportNetworkPage.categoriasFiltro.firstWhere((c) => c.id == _filtro).categorias;
    if (categorias.isEmpty) return widget.instituicoes;
    return widget.instituicoes.where((i) => categorias.contains(i.category)).toList();
  }

  // ── Ações ─────────────────────────────────────────────────────────────────

  void _selecionarGrupo(List<SupportInstitution> grupo) {
    setState(() {
      _limparRota();
      _grupo = grupo;
      _selecionada = grupo.length == 1 ? grupo.first : null;
    });
  }

  void _fechar() {
    if (_painel == _Painel.rota) {
      setState(_limparRota);
    } else {
      setState(() {
        _selecionada = null;
        _grupo = const [];
      });
    }
  }

  void _limparRota() {
    _rota = null;
    _erroRota = null;
    _calculandoRota = false;
  }

  Future<Position?> _garantirLocalizacao() async {
    if (_posicao != null) return _posicao;
    setState(() => _carregandoLocalizacao = true);
    final erro = await LocationService.verificarPermissoes();
    final posicao = erro == null ? await LocationService.obterPosicaoAtual() : null;
    if (!mounted) return null;
    setState(() {
      _carregandoLocalizacao = false;
      if (posicao != null) _posicao = posicao;
    });
    if (posicao == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro ?? 'Não foi possível obter sua localização agora.')),
      );
    }
    return posicao;
  }

  Future<void> _calcularRota([TravelMode? modo]) async {
    final destino = _selecionada;
    if (destino == null || destino.latitude == null || destino.longitude == null) return;
    if (modo != null) _modo = modo;

    setState(() {
      _calculandoRota = true;
      _erroRota = null;
    });

    final posicao = await _garantirLocalizacao();
    if (!mounted) return;
    if (posicao == null) {
      setState(() {
        _calculandoRota = false;
        _erroRota = 'Precisamos da sua localização para traçar a rota no app. '
            'Você ainda pode abrir o caminho no GPS do celular.';
      });
      return;
    }

    try {
      final plano = await RouteService.calcular(
        de: LatLng(posicao.latitude, posicao.longitude),
        para: LatLng(destino.latitude!, destino.longitude!),
        modo: _modo,
      );
      if (!mounted || _selecionada != destino) return;
      HapticFeedback.lightImpact();
      setState(() {
        _rota = plano;
        _calculandoRota = false;
      });
    } on RouteException catch (e) {
      if (!mounted) return;
      setState(() {
        _calculandoRota = false;
        _erroRota = e.mensagem;
      });
    }
  }

  /// Posição escolhida no mapa. Se havia rota aberta, recalcula a partir dela.
  void _ajustarPosicao(Position posicao) {
    final modo = _rota?.modo;
    final rotaAberta = _painel == _Painel.rota;
    setState(() {
      _posicao = posicao;
      _limparRota();
    });
    if (rotaAberta) _calcularRota(modo);
  }

  Future<void> _usarLocalizacao() async {
    _posicao = null;
    await _garantirLocalizacao();
  }

  // ── Interface ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final painel = _painel;
    final espacoInferior = switch (painel) {
      _Painel.nenhum => 0.0,
      _Painel.grupo => 260.0,
      _Painel.local => 250.0,
      _Painel.rota => 330.0,
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: PopScope(
        canPop: painel == _Painel.nenhum,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _fechar();
        },
        child: Scaffold(
          backgroundColor: AppColors.sandDeep,
          body: Stack(
            children: [
              Positioned.fill(
                child: SupportNetworkMap(
                  instituicoes: _visiveis,
                  posicaoUsuaria: _posicao,
                  bordaArredondada: false,
                  mostrarControles: false,
                  selecionadaId: _selecionada?.id ?? (_grupo.isNotEmpty ? _grupo.first.id : null),
                  rota: _rota?.pontos,
                  espacoInferior: espacoInferior,
                  onSelecionar: _selecionarGrupo,
                  onToqueNoMapa: painel == _Painel.nenhum ? null : _fechar,
                  onAjustarPosicao: _ajustarPosicao,
                  margemSuperior: MediaQuery.paddingOf(context).top + 64,
                ),
              ),

              // Barra superior: voltar + abas de categoria.
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      _BotaoRedondo(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Voltar',
                        onTap: () => Navigator.maybePop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AnimatedOpacity(
                          duration: AppShape.medio,
                          opacity: painel == _Painel.rota ? 0 : 1,
                          child: IgnorePointer(
                            ignoring: painel == _Painel.rota,
                            child: CategoryTabs(
                              sobreMapa: true,
                              itens: [for (final c in SupportNetworkPage.categoriasFiltro) (c.id, c.label)],
                              selecionado: _filtro,
                              onSelecionar: (id) => setState(() {
                                _filtro = id;
                                _selecionada = null;
                                _grupo = const [];
                                _limparRota();
                              }),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: AppShape.medio).slideY(begin: -0.3, curve: AppShape.curva),
              ),

              // Botão de localização, acima do painel.
              AnimatedPositioned(
                duration: AppShape.medio,
                curve: AppShape.curva,
                right: 16,
                bottom: espacoInferior + 16 + MediaQuery.paddingOf(context).bottom,
                child: _BotaoRedondo(
                  icon: Icons.near_me_outlined,
                  tooltip: 'Usar minha localização',
                  carregando: _carregandoLocalizacao,
                  ativo: _posicao != null,
                  onTap: _usarLocalizacao,
                ),
              ),

              // Painel inferior.
              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedSwitcher(
                  duration: AppShape.medio,
                  switchInCurve: AppShape.curva,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(anim),
                      child: child,
                    ),
                  ),
                  child: switch (painel) {
                    _Painel.nenhum => const SizedBox.shrink(key: ValueKey('nenhum')),
                    _Painel.grupo => _Folha(
                        key: const ValueKey('grupo'),
                        child: _ListaDoEndereco(
                          grupo: _grupo,
                          onEscolher: (i) => setState(() => _selecionada = i),
                        ),
                      ),
                    _Painel.local => _Folha(
                        key: ValueKey('local-${_selecionada!.id}'),
                        child: _PainelLocal(
                          instituicao: _selecionada!,
                          temOutrosNoEndereco: _grupo.length > 1,
                          onVoltarAoEndereco: () => setState(() => _selecionada = null),
                          onComoChegar: () => _calcularRota(),
                          onDetalhes: () => InstitutionDetailsSheet.show(context, _selecionada!),
                          onFechar: _fechar,
                        ),
                      ),
                    _Painel.rota => _Folha(
                        key: const ValueKey('rota'),
                        child: _PainelRota(
                          instituicao: _selecionada!,
                          modo: _modo,
                          rota: _rota,
                          carregando: _calculandoRota,
                          erro: _erroRota,
                          onModo: (m) => _calcularRota(m),
                          onFechar: _fechar,
                        ),
                      ),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Peças do painel ──────────────────────────────────────────────────────────

class _Folha extends StatelessWidget {
  const _Folha({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppShape.radiusLg)),
        boxShadow: [BoxShadow(color: AppColors.shadowMedium, blurRadius: 24, offset: Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 10, AppSpacing.screen, AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _ListaDoEndereco extends StatelessWidget {
  const _ListaDoEndereco({required this.grupo, required this.onEscolher});

  final List<SupportInstitution> grupo;
  final ValueChanged<SupportInstitution> onEscolher;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MESMO ENDEREÇO', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        Text('${grupo.length} serviços aqui', style: AppFonts.serif(size: 22)),
        const SizedBox(height: 8),
        for (final (i, inst) in grupo.indexed)
          Pressable(
            onTap: () => onEscolher(inst),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: i == 0 ? null : const Border(top: BorderSide(color: AppColors.hairline)),
              ),
              child: Row(
                children: [
                  _IconeCategoria(instituicao: inst),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(inst.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                        Text(inst.categoryLabel, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
                ],
              ),
            ),
          ).animate(delay: (40 * i).ms).fadeIn().slideX(begin: 0.05),
      ],
    );
  }
}

class _PainelLocal extends StatelessWidget {
  const _PainelLocal({
    required this.instituicao,
    required this.temOutrosNoEndereco,
    required this.onVoltarAoEndereco,
    required this.onComoChegar,
    required this.onDetalhes,
    required this.onFechar,
  });

  final SupportInstitution instituicao;
  final bool temOutrosNoEndereco;
  final VoidCallback onVoltarAoEndereco;
  final VoidCallback onComoChegar;
  final VoidCallback onDetalhes;
  final VoidCallback onFechar;

  @override
  Widget build(BuildContext context) {
    final i = instituicao;
    final corpo = Theme.of(context).textTheme.bodyMedium;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (temOutrosNoEndereco) ...[
              _BotaoTexto(icon: Icons.arrow_back_rounded, tooltip: 'Outros serviços do endereço', onTap: onVoltarAoEndereco),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(i.categoryLabel.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: i.themeColor)),
                  const SizedBox(height: 4),
                  Text(i.name, style: AppFonts.serif(size: 23, peso: 580)),
                ],
              ),
            ),
            _BotaoTexto(icon: Icons.close_rounded, tooltip: 'Fechar', onTap: onFechar),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          [i.address, if (i.formattedDistance != null) '${i.hasApproximateLocation ? '~' : ''}${i.formattedDistance}']
              .join('  ·  '),
          style: corpo,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: i.is24Hours ? AppColors.moss : AppColors.textHint,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(i.formattedOpeningHours, style: corpo, maxLines: 2)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onComoChegar,
                icon: const Icon(Icons.route_outlined, size: 20),
                label: const Text('Como chegar'),
              ),
            ),
            if (i.phone != null) ...[
              const SizedBox(width: 10),
              _BotaoQuadrado(
                icon: Icons.call_outlined,
                tooltip: 'Ligar para ${i.phone}',
                onTap: () => SupportNetworkService.ligar(i.phone!),
              ),
            ],
            const SizedBox(width: 10),
            _BotaoQuadrado(icon: Icons.info_outline_rounded, tooltip: 'Detalhes', onTap: onDetalhes),
          ],
        ),
      ],
    );
  }
}

class _PainelRota extends StatelessWidget {
  const _PainelRota({
    required this.instituicao,
    required this.modo,
    required this.rota,
    required this.carregando,
    required this.erro,
    required this.onModo,
    required this.onFechar,
  });

  final SupportInstitution instituicao;
  final TravelMode modo;
  final RoutePlan? rota;
  final bool carregando;
  final String? erro;
  final ValueChanged<TravelMode> onModo;
  final VoidCallback onFechar;

  @override
  Widget build(BuildContext context) {
    final corpo = Theme.of(context).textTheme.bodyMedium;
    final plano = rota;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _BotaoTexto(icon: Icons.arrow_back_rounded, tooltip: 'Voltar ao local', onTap: onFechar),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Até ${instituicao.name}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SeletorModo(modo: modo, onModo: carregando ? null : onModo),
        const SizedBox(height: 16),

        // Resumo: carregando / erro / rota.
        AnimatedSwitcher(
          duration: AppShape.medio,
          child: carregando
              ? const Column(
                  key: ValueKey('carregando'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Esqueleto(largura: 140, altura: 34),
                    SizedBox(height: 8),
                    _Esqueleto(largura: 220, altura: 14),
                  ],
                )
              : erro != null
                  ? Text(erro!, key: const ValueKey('erro'), style: corpo)
                  : plano == null
                      ? const SizedBox.shrink()
                      : Column(
                          key: ValueKey('rota-${plano.modo}-${plano.distanciaM}'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(plano.duracaoFormatada, style: AppFonts.serif(size: 36, peso: 600)),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    '${plano.distanciaFormatada} · chega ${plano.chegadaPrevista()}',
                                    style: corpo,
                                  ),
                                ),
                              ],
                            ).animate().fadeIn().slideY(begin: 0.2),
                            if (plano.passos.isNotEmpty) _PassoAPasso(passos: plano.passos),
                          ],
                        ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () => SupportNetworkService.abrirNoMapa(instituicao, modo: modo),
          icon: const Icon(Icons.navigation_outlined, size: 20),
          label: Text(erro != null ? 'Abrir no GPS do celular' : 'Iniciar navegação no GPS'),
        ),
      ],
    );
  }
}

class _PassoAPasso extends StatelessWidget {
  const _PassoAPasso({required this.passos});

  final List<RouteStep> passos;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(
          'Passo a passo (${passos.length})',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.wine),
        ),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: passos.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, i) {
                final p = passos[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        child: p.isTransit
                            ? const Icon(Icons.directions_bus_rounded, size: 20, color: AppColors.wine)
                            : Text('${i + 1}', style: AppFonts.serif(size: 16, color: AppColors.textHint)),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.instrucao, style: Theme.of(context).textTheme.bodyMedium),
                            if (p.isTransit && p.numParadas != null && p.numParadas! > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '${p.numParadas} paradas${p.pontoDesembarque != null ? ' · Descer em ${p.pontoDesembarque}' : ''}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.wine, fontWeight: FontWeight.w600),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (p.distanciaM > 0)
                        Text(RoutePlan.formatarDistancia(p.distanciaM), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SeletorModo extends StatelessWidget {
  const _SeletorModo({required this.modo, required this.onModo});

  final TravelMode modo;
  final ValueChanged<TravelMode>? onModo;

  @override
  Widget build(BuildContext context) {
    const icones = {
      TravelMode.aPe: Icons.directions_walk_rounded,
      TravelMode.carro: Icons.directions_car_outlined,
      TravelMode.onibus: Icons.directions_bus_rounded,
    };
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.sand, borderRadius: BorderRadius.circular(14)),
      child: LayoutBuilder(
        builder: (context, c) {
          final largura = (c.maxWidth - 0) / TravelMode.values.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: AppShape.medio,
                curve: Curves.easeOutBack,
                left: largura * TravelMode.values.indexOf(modo),
                top: 0,
                bottom: 0,
                width: largura,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: Offset(0, 2))],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final m in TravelMode.values)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: m == modo,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onModo == null || m == modo
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  onModo!(m);
                                },
                          child: SizedBox(
                            height: 40,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(icones[m], size: 18,
                                    color: m == modo ? AppColors.textPrimary : AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  m.rotulo,
                                  style: TextStyle(
                                    fontWeight: m == modo ? FontWeight.w700 : FontWeight.w400,
                                    color: m == modo ? AppColors.textPrimary : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Esqueleto extends StatelessWidget {
  const _Esqueleto({required this.largura, required this.altura});

  final double largura;
  final double altura;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: largura,
      height: altura,
      decoration: BoxDecoration(color: AppColors.sandDeep, borderRadius: BorderRadius.circular(8)),
    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: AppColors.paper);
  }
}

class _IconeCategoria extends StatelessWidget {
  const _IconeCategoria({required this.instituicao});

  final SupportInstitution instituicao;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: instituicao.softThemeColor, shape: BoxShape.circle),
      child: Icon(instituicao.icon, size: 19, color: instituicao.themeColor),
    );
  }
}

class _BotaoRedondo extends StatelessWidget {
  const _BotaoRedondo({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.carregando = false,
    this.ativo = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool carregando;
  final bool ativo;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: carregando ? null : onTap,
        escala: 0.9,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: ativo ? AppColors.ink : AppColors.paper,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.hairline),
            boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: Center(
            child: carregando
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                : Icon(icon, size: 20, color: ativo ? Colors.white : AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _BotaoTexto extends StatelessWidget {
  const _BotaoTexto({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, color: AppColors.textSecondary),
    );
  }
}

class _BotaoQuadrado extends StatelessWidget {
  const _BotaoQuadrado({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        escala: 0.92,
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: AppColors.sand,
            borderRadius: BorderRadius.circular(AppShape.radius),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Icon(icon, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
