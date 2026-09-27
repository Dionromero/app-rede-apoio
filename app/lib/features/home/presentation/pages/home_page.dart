import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/services/emergency_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/share_location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/action_card.dart';
import '../../../../core/widgets/support_network_map.dart';
import '../../../guidance/presentation/pages/guidance_page.dart';
import '../../../support_network/data/support_network_service.dart';
import '../../../support_network/domain/models/support_institution.dart';
import '../../../support_network/presentation/pages/support_map_page.dart';
import '../../../support_network/presentation/pages/support_network_page.dart';
import '../../../trusted_contact/presentation/pages/trusted_contact_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static const routeName = '/inicio';

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _filter = 'todos';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(erro ?? 'Não foi possível obter sua localização agora.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    _posicao = posicao;
    await _carregarMapa();
  }

  List<SupportInstitution> get _instituicoesFiltradas {
    final categorias = SupportNetworkPage.categoriasFiltro
        .firstWhere((c) => c.id == _filter)
        .categorias;
    if (categorias.isEmpty) return _instituicoes;
    return _instituicoes.where((i) => categorias.contains(i.category)).toList();
  }

  void _ampliarMapa() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupportMapPage(
          instituicoes: _instituicoesFiltradas,
          posicaoUsuaria: _posicao,
        ),
      ),
    );
  }

  /// Abre a Rede de Apoio já filtrada pelo chip escolhido na tela inicial.
  void _abrirRedeDeApoio() {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: SupportNetworkPage.routeName),
        builder: (_) => SupportNetworkPage(categoriaInicial: _filter),
      ),
    );
  }

  void _showPending(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature é uma demonstração visual nesta versão.'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _enviarLocalizacao() async {
    // Mostrar indicação de carregamento
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Text('Obtendo localização…'),
          ],
        ),
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    final resultado = await ShareLocationService.enviarParaQualquerContato();

    if (!mounted) return;

    // Limpar snackbar de carregamento
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    switch (resultado) {
      case ShareResult.sucesso:
        // WhatsApp aberto com sucesso — nada mais a fazer
        break;
      case ShareResult.semLocalizacao:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Não foi possível obter sua localização. '
              'Verifique se o GPS está ativo e se a permissão foi concedida.',
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      case ShareResult.whatsappIndisponivel:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'WhatsApp não encontrado. Verifique se está instalado.',
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      case ShareResult.falhaGeral:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Não foi possível compartilhar a localização neste momento.',
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.xxl),
            children: [
              // ── Cabeçalho ────────────────────────────────────────────
              Row(
                children: [
                  // Logo / ícone do app
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.pinkSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.volunteer_activism_rounded,
                      color: AppColors.pink,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Rede de Apoio',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                    ),
                  ),
                  // Botão de saída rápida
                  Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => _showPending('Saída rápida'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Título da seção ───────────────────────────────────────
              Text(
                'Apoio perto de você',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Encontre serviços e canais de orientação. Você decide cada próximo passo.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const SizedBox(height: AppSpacing.md),

              // ── Filtros ───────────────────────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: SupportNetworkPage.categoriasFiltro
                      .map(
                        (cat) => Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xs),
                          child: _FilterChip(
                            label: cat.label,
                            selected: _filter == cat.id,
                            onSelected: () => setState(() => _filter = cat.id),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // ── Mapa da rede de apoio ─────────────────────────────────
              if (_carregandoMapa)
                Container(
                  height: 280,
                  decoration: BoxDecoration(
                    color: AppColors.blueSoft,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(strokeWidth: 2.5),
                )
              else
                SupportNetworkMap(
                  altura: 280,
                  instituicoes: _instituicoesFiltradas,
                  posicaoUsuaria: _posicao,
                  carregandoLocalizacao: _carregandoLocalizacao,
                  onUsarLocalizacao: _usarMinhaLocalizacao,
                  onAmpliar: _ampliarMapa,
                  onSelecionar: (grupo) => SupportMapPage.mostrarGrupo(context, grupo),
                ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _mapaOffline
                          ? 'Sem conexão: mostrando locais salvos no aparelho.'
                          : _foraDoRaio
                              ? 'Nada a até ${AppConfig.raioBuscaKm.round()} km: mostrando os mais próximos.'
                              : _posicao != null
                              ? 'Locais a até ${AppConfig.raioBuscaKm.round()} km. Toque em um pino.'
                              : 'Use o botão de localização do mapa para ver o que está perto.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _mapaOffline ? const Color(0xFFE65100) : AppColors.textSecondary,
                          ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _abrirRedeDeApoio,
                    // O tema deixa botões com largura infinita; dentro de Row isso quebra.
                    style: TextButton.styleFrom(minimumSize: const Size(0, 40)),
                    icon: const Icon(Icons.list_rounded, size: 18),
                    label: const Text('Ver lista'),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // ── Card de Emergência 190 ────────────────────────────────
              _EmergencyCard(
                onTap: () => EmergencyService.confirmarELigar190(context),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Outras opções ─────────────────────────────────────────
              Text(
                'Outras opções',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),

              const SizedBox(height: AppSpacing.sm),

              ActionCard(
                icon: Icons.people_alt_rounded,
                title: 'Pessoa de confiança',
                description: 'Cadastrar ou revisar um contato escolhido.',
                accentColor: AppColors.pink,
                iconBackgroundColor: AppColors.pinkSoft,
                onTap: () => Navigator.pushNamed(
                  context,
                  TrustedContactPage.routeName,
                ),
              ),
              ActionCard(
                icon: Icons.location_on_rounded,
                title: 'Enviar localização',
                description: 'Compartilhar sua posição atual via WhatsApp.',
                accentColor: const Color(0xFF2E7D32),
                iconBackgroundColor: const Color(0xFFE8F5E9),
                onTap: () => _enviarLocalizacao(),
              ),
              ActionCard(
                icon: Icons.support_agent_rounded,
                title: 'Ligue 180',
                description: 'Canal oficial de orientação e denúncia.',
                accentColor: AppColors.primary,
                iconBackgroundColor: AppColors.blueSoft,
                onTap: () => EmergencyService.confirmarELigar180(context),
              ),
              ActionCard(
                icon: Icons.menu_book_rounded,
                title: 'Orientações e direitos',
                description: 'Informações sobre proteção e atendimento.',
                onTap: () => Navigator.pushNamed(context, GuidancePage.routeName),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widget: Chip de filtro ──────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: selected ? AppColors.blueSoft : AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Widget: Card de Emergência ──────────────────────────────────────────────

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.emergency,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        splashColor: Colors.white.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
          child: Row(
            children: [
              // Ícone com fundo semi-transparente
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phone_in_talk_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergência — 190',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Abrir ligação para a Polícia Militar.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
