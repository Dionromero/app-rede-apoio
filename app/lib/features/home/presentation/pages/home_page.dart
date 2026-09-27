import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/services/discreet_mode_service.dart';
import '../../../../core/services/emergency_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/share_location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/support_network_map.dart';
import '../../../discreet_mode/presentation/pages/discreet_mode_page.dart';
import '../../../guidance/presentation/pages/guidance_page.dart';
import '../../../support_network/data/support_network_service.dart';
import '../../../support_network/domain/models/support_institution.dart';
import '../../../support_network/presentation/pages/support_map_page.dart';
import '../../../support_network/presentation/pages/support_network_page.dart';
import '../../../trusted_contact/presentation/pages/trusted_contact_page.dart';
import '../widgets/filtros_mapa.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static const routeName = '/inicio';

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  FiltroMapa _filtro = const FiltroMapa();

  // ── Mapa ──────────────────────────────────────────────────────────────────
  List<SupportInstitution> _instituicoes = [];
  Position? _posicao;
  bool _carregandoMapa = true;
  bool _carregandoLocalizacao = false;
  bool _mapaOffline = false;
  bool _foraDoRaio = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregarMapa());
  }

  /// Carrega os pinos. Usa a localização só se a permissão já existir:
  /// o pedido acontece quando a usuária toca em "usar minha localização".
  Future<void> _carregarMapa() async {
    final posicao = _posicao ?? await LocationService.obterPosicaoSeJaPermitido();
    final resultado = await SupportNetworkService.buscarInstituicoes(
      lat: posicao?.latitude,
      lng: posicao?.longitude,
      raioKm: AppConfig.raioBuscaKm,
    );
    if (!mounted) return;
    setState(() {
      _posicao = posicao;
      _instituicoes = resultado.instituicoes;
      _mapaOffline = resultado.offline;
      _foraDoRaio = resultado.foraDoRaio;
      _carregandoMapa = false;
    });
  }

  Future<void> _usarMinhaLocalizacao() async {
    setState(() => _carregandoLocalizacao = true);
    final erro = await LocationService.verificarPermissoes();
    final posicao = erro == null ? await LocationService.obterPosicaoAtual() : null;
    if (!mounted) return;
    setState(() => _carregandoLocalizacao = false);

    if (posicao == null) {
      _aviso(erro ?? 'Não foi possível obter sua localização agora.');
      return;
    }
    _posicao = posicao;
    await _carregarMapa();
  }

  List<SupportInstitution> get _instituicoesFiltradas => _filtro.aplicar(_instituicoes, posicao: _posicao);

  /// "Mais próximos": liga/desliga. Sem posição, pede a localização primeiro.
  Future<void> _alternarProximos() async {
    if (_posicao == null) {
      setState(() => _filtro = _filtro.copyWith(soProximos: true));
      await _usarMinhaLocalizacao();
      return;
    }
    setState(() => _filtro = _filtro.copyWith(soProximos: !_filtro.soProximos));
  }

  Future<void> _abrirFiltros() async {
    final novo = await mostrarFolhaFiltros(context, _filtro);
    if (novo != null && mounted) setState(() => _filtro = novo);
  }

  /// Abre o mapa em tela cheia (opcionalmente já com um local escolhido).
  void _explorarMapa([List<SupportInstitution>? grupo]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupportMapPage(
          instituicoes: _instituicoes,
          posicaoUsuaria: _posicao,
          categoriaInicial: _filtro.categoria,
          selecionadaInicial: grupo,
        ),
      ),
    );
  }

  /// Abre a Rede de Apoio (lista) já filtrada pela aba escolhida.
  void _abrirRedeDeApoio() {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: SupportNetworkPage.routeName),
        builder: (_) => SupportNetworkPage(categoriaInicial: _filtro.categoria),
      ),
    );
  }

  void _aviso(String texto, {Duration duracao = const Duration(seconds: 4)}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto), duration: duracao));
  }

  Future<void> _enviarLocalizacao() async {
    _aviso('Obtendo sua localização…', duracao: const Duration(seconds: 10));
    final resultado = await ShareLocationService.enviarParaQualquerContato();
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    switch (resultado) {
      case ShareResult.sucesso:
        break;
      case ShareResult.semLocalizacao:
        _aviso('Não foi possível obter sua localização. Verifique se o GPS está ativo e se a permissão foi concedida.',
            duracao: const Duration(seconds: 5));
      case ShareResult.whatsappIndisponivel:
        _aviso('WhatsApp não encontrado. Verifique se está instalado.');
      case ShareResult.falhaGeral:
        _aviso('Não foi possível compartilhar a localização neste momento.');
    }
  }

  String get _saudacao {
    final h = DateTime.now().hour;
    if (h < 5) return 'Boa noite.';
    if (h < 12) return 'Bom dia.';
    if (h < 18) return 'Boa tarde.';
    return 'Boa noite.';
  }

  String get _legendaMapa {
    if (_mapaOffline) return 'Sem conexão: mostrando os locais salvos no aparelho.';
    if (_foraDoRaio) return 'Nada a até ${AppConfig.raioBuscaKm.round()} km. Mostrando os mais próximos.';
    final n = _instituicoesFiltradas.length;
    if (n == 0) return 'Nenhum local com esses filtros. Toque em "Filtros" para mudar.';
    if (_posicao != null && _filtro.soProximos) {
      return n == 1 ? 'O local mais próximo de você. Toque no pino.' : 'Os $n locais mais próximos de você. Toque num pino.';
    }
    if (_posicao != null) return '$n locais a até ${AppConfig.raioBuscaKm.round()} km. Toque num pino.';
    return 'Toque em "Mais próximos" para ver só o que está perto de você.';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    // Cada bloco entra com um pequeno atraso: a tela "se monta" com calma.
    Widget entrada(Widget child, int ordem) => child
        .animate(delay: (70 * ordem).ms)
        .fadeIn(duration: 420.ms, curve: AppShape.curva)
        .slideY(begin: 0.06, duration: 420.ms, curve: AppShape.curva);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.xxl),
            children: [
              // ── Cabeçalho ────────────────────────────────────────────
              entrada(
                Row(
                  children: [
                    const _Monograma(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'REDE DE APOIO',
                        style: t.labelSmall?.copyWith(color: AppColors.textPrimary, letterSpacing: 1.6),
                      ),
                    ),
                    _SaidaRapida(onTap: () => _aviso('Saída rápida: em construção nesta versão.')),
                  ],
                ),
                0,
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Saudação ─────────────────────────────────────────────
              entrada(Text(_saudacao, style: AppFonts.serif(size: 38, peso: 520)), 1),
              const SizedBox(height: 6),
              entrada(
                Text(
                  'Você não está sozinha. Aqui estão caminhos de apoio perto de você, e cada passo é decisão sua.',
                  style: t.bodyLarge,
                ),
                2,
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Emergência ───────────────────────────────────────────
              entrada(_BotaoEmergencia(onTap: () => EmergencyService.confirmarELigar190(context)), 3),
              const SizedBox(height: AppSpacing.xxl),

              // ── Mapa ─────────────────────────────────────────────────
              entrada(
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: Text('Apoio perto de você', style: t.titleLarge)),
                    TextButton(
                      onPressed: _abrirRedeDeApoio,
                      // O tema dá largura infinita aos botões; dentro de Row, limitar.
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        foregroundColor: AppColors.wine,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('Ver lista'),
                    ),
                  ],
                ),
                4,
              ),
              const SizedBox(height: 4),
              entrada(
                BarraFiltrosMapa(
                  filtro: _filtro,
                  temPosicao: _posicao != null,
                  carregandoLocalizacao: _carregandoLocalizacao,
                  onProximos: _alternarProximos,
                  onFiltros: _abrirFiltros,
                ),
                4,
              ),
              const SizedBox(height: AppSpacing.sm),
              entrada(
                AnimatedSwitcher(
                  duration: AppShape.lento,
                  child: _carregandoMapa
                      ? Container(
                          key: const ValueKey('carregando'),
                          height: 300,
                          decoration: BoxDecoration(
                            color: AppColors.sandDeep,
                            borderRadius: BorderRadius.circular(AppShape.radiusLg),
                          ),
                        ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1400.ms, color: AppColors.paper)
                      : SupportNetworkMap(
                          key: const ValueKey('mapa'),
                          altura: 300,
                          instituicoes: _instituicoesFiltradas,
                          posicaoUsuaria: _posicao,
                          carregandoLocalizacao: _carregandoLocalizacao,
                          onUsarLocalizacao: _usarMinhaLocalizacao,
                          onAmpliar: _explorarMapa,
                          enquadrarAoMudar: true,
                          onSelecionar: _explorarMapa,
                          onAjustarPosicao: (p) {
                            _posicao = p;
                            _carregarMapa();
                          },
                        ),
                ),
                5,
              ),
              const SizedBox(height: AppSpacing.xs),
              AnimatedSwitcher(
                duration: AppShape.medio,
                child: Text(
                  _legendaMapa,
                  key: ValueKey(_legendaMapa),
                  style: t.bodySmall?.copyWith(color: _mapaOffline ? AppColors.emergency : null),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // ── Mais caminhos ────────────────────────────────────────
              entrada(Text('Mais caminhos', style: t.titleLarge), 6),
              const SizedBox(height: AppSpacing.sm),
              entrada(
                _ListaDeAcoes(
                  acoes: [
                    _Acao(
                      icon: Icons.favorite_border_rounded,
                      cor: AppColors.wine,
                      fundo: AppColors.wineSoft,
                      titulo: 'Pessoas de confiança',
                      descricao: 'Cadastre ou revise até 5 contatos.',
                      onTap: () => Navigator.pushNamed(context, TrustedContactPage.routeName),
                    ),
                    _Acao(
                      icon: Icons.near_me_outlined,
                      cor: AppColors.moss,
                      fundo: AppColors.mossSoft,
                      titulo: 'Enviar minha localização',
                      descricao: 'Abre o WhatsApp com sua posição atual.',
                      onTap: _enviarLocalizacao,
                    ),
                    _Acao(
                      icon: Icons.support_agent_outlined,
                      cor: AppColors.ink,
                      fundo: AppColors.inkSoft,
                      titulo: 'Ligue 180',
                      descricao: 'Orientação e denúncia, 24 horas, gratuito.',
                      onTap: () => EmergencyService.confirmarELigar180(context),
                    ),
                    _Acao(
                      icon: Icons.menu_book_outlined,
                      cor: AppColors.textPrimary,
                      fundo: AppColors.sandDeep,
                      titulo: 'Direitos e orientações',
                      descricao: 'Medida protetiva, BO, plano de segurança.',
                      onTap: () => Navigator.pushNamed(context, GuidancePage.routeName),
                    ),
                    if (DiscreetModeService.suportado)
                      _Acao(
                        icon: Icons.visibility_off_outlined,
                        cor: AppColors.ink,
                        fundo: AppColors.inkSoft,
                        titulo: 'Modo discreto',
                        descricao: 'Disfarce o ícone: calculadora, anotações e outros.',
                        onTap: () => Navigator.pushNamed(context, DiscreetModePage.routeName),
                      ),
                  ],
                ),
                7,
              ),
              const SizedBox(height: AppSpacing.xl),
              entrada(
                Text(
                  'Este app orienta e conecta. Ele não substitui o 190, o 180 nem o atendimento especializado.',
                  style: t.bodySmall?.copyWith(color: AppColors.textHint),
                ),
                8,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Peças da tela ────────────────────────────────────────────────────────────

class _Monograma extends StatelessWidget {
  const _Monograma();

  /// Símbolo da marca: a mulher em perfil pedindo silêncio.
  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipOval(
        child: Image.asset('assets/brand/simbolo-mono-512.png', width: 36, height: 36, filterQuality: FilterQuality.medium),
      ),
    );
  }
}

class _SaidaRapida extends StatelessWidget {
  const _SaidaRapida({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticsLabel: 'Saída rápida',
      escala: 0.94,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.close_rounded, size: 16, color: AppColors.textPrimary),
            SizedBox(width: 6),
            Text('Sair', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _BotaoEmergencia extends StatelessWidget {
  const _BotaoEmergencia({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticsLabel: 'Emergência: ligar 190, Polícia Militar',
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.emergency, AppColors.emergencyDeep],
          ),
          borderRadius: BorderRadius.circular(AppShape.radiusLg),
          boxShadow: [
            BoxShadow(color: AppColors.emergency.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EM RISCO AGORA',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Ligar 190', style: AppFonts.serif(size: 30, peso: 600, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(
                    'Polícia Militar. Você confirma antes de ligar.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13.5),
                  ),
                ],
              ),
            ),
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: const Icon(Icons.call_rounded, color: Colors.white, size: 24),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 1, end: 1.06, duration: 1400.ms, curve: Curves.easeInOut),
          ],
        ),
      ),
    );
  }
}

class _Acao {
  const _Acao({
    required this.icon,
    required this.cor,
    required this.fundo,
    required this.titulo,
    required this.descricao,
    required this.onTap,
  });

  final IconData icon;
  final Color cor;
  final Color fundo;
  final String titulo;
  final String descricao;
  final VoidCallback onTap;
}

/// Lista de ações num só bloco, separada por linhas finas (sem "cards" soltos).
class _ListaDeAcoes extends StatelessWidget {
  const _ListaDeAcoes({required this.acoes});

  final List<_Acao> acoes;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppShape.radiusLg),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          for (final (i, a) in acoes.indexed) ...[
            if (i > 0) const Padding(padding: EdgeInsets.only(left: 72), child: Divider()),
            Pressable(
              onTap: a.onTap,
              escala: 0.985,
              semanticsLabel: a.titulo,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: a.fundo, shape: BoxShape.circle),
                      child: Icon(a.icon, color: a.cor, size: 21),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.titulo,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(a.descricao, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.textHint),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
