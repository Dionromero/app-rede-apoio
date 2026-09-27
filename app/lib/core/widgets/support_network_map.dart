import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

import '../../features/support_network/domain/models/support_institution.dart';
import '../config/app_config.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Mapa da rede de apoio (OpenStreetMap via flutter_map).
///
/// - Tiles em tons suaves (dessaturados e aquecidos) para combinar com o app.
/// - Um pino por endereço; instituições no mesmo endereço viram um pino com
///   contador. Pinos com coordenada aproximada ficam semitransparentes.
/// - [selecionadaId] destaca um pino e move a câmera até ele com animação.
/// - [rota] desenha a linha do trajeto (com animação de "traçado") e
///   enquadra origem e destino.
/// - A posição da usuária só aparece se [posicaoUsuaria] for informada; o
///   pedido de permissão fica com quem usa o widget ([onUsarLocalizacao]).
/// - A margem de erro da posição aparece como um círculo. Se ela passar de
///   [LocationService.precisaoAceitavelM], surge o aviso "Localização
///   aproximada" com "Ajustar": a usuária toca onde está e o widget devolve
///   a nova posição em [onAjustarPosicao].
class SupportNetworkMap extends StatefulWidget {
  const SupportNetworkMap({
    required this.instituicoes,
    this.posicaoUsuaria,
    this.onSelecionar,
    this.onToqueNoMapa,
    this.onUsarLocalizacao,
    this.onAmpliar,
    this.carregandoLocalizacao = false,
    this.altura,
    this.bordaArredondada = true,
    this.selecionadaId,
    this.rota,
    this.espacoInferior = 0,
    this.mostrarControles = true,
    this.onAjustarPosicao,
    this.margemSuperior = 12,
    this.enquadrarAoMudar = false,
    super.key,
  });

  final List<SupportInstitution> instituicoes;
  final Position? posicaoUsuaria;

  /// Toque em um pino. Recebe todas as instituições daquele endereço.
  final ValueChanged<List<SupportInstitution>>? onSelecionar;

  /// Toque numa área vazia do mapa (ex.: para fechar o painel).
  final VoidCallback? onToqueNoMapa;

  /// Botão "minha localização". Se `null`, o botão não aparece.
  final VoidCallback? onUsarLocalizacao;

  /// Botão "ampliar" (abrir em tela cheia). Se `null`, não aparece.
  final VoidCallback? onAmpliar;
  final bool carregandoLocalizacao;

  /// Altura fixa. `null` = ocupa todo o espaço disponível.
  final double? altura;
  final bool bordaArredondada;

  /// Id da instituição em destaque.
  final String? selecionadaId;

  /// Pontos da rota a desenhar (lat/lng), ou `null`.
  final List<LatLng>? rota;

  /// Altura coberta por painéis na parte de baixo; a câmera centraliza
  /// o conteúdo acima dela.
  final double espacoInferior;
  final bool mostrarControles;

  /// Recebe a posição escolhida no mapa. Se `null`, não há "Ajustar".
  final ValueChanged<Position>? onAjustarPosicao;

  /// Enquadra a câmera nos pinos (e na usuária) sempre que a lista de
  /// instituições muda. Útil quando o mapa mostra poucos locais filtrados.
  final bool enquadrarAoMudar;

  /// Distância do topo para os avisos (ex.: abaixo de uma barra sobreposta).
  final double margemSuperior;

  /// Centro de Curitiba, usado quando não há posição da usuária.
  static const centroPiloto = LatLng(-25.4284, -49.2733);

  /// Servidor de tiles. Os tiles públicos do OSM servem para o piloto;
  /// em produção, troque por um provedor de tiles (ver opções de build no README).
  static const tileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  /// Filtro que dessatura e aquece os tiles (tons de papel/areia).
  static const ColorFilter filtroSuave = ColorFilter.matrix(<double>[
    0.62, 0.30, 0.06, 0, 18, //
    0.20, 0.68, 0.10, 0, 14, //
    0.18, 0.28, 0.50, 0, 10, //
    0, 0, 0, 1, 0,
  ]);

  @override
  State<SupportNetworkMap> createState() => _SupportNetworkMapState();
}

class _SupportNetworkMapState extends State<SupportNetworkMap> with SingleTickerProviderStateMixin {
  final _controller = MapController();
  late final AnimationController _camera = AnimationController(vsync: this, duration: AppShape.lento);
  bool _mapaPronto = false;

  /// Modo "toque onde você está".
  bool _ajustando = false;

  void _escolherPonto(LatLng ponto) {
    HapticFeedback.selectionClick();
    setState(() => _ajustando = false);
    widget.onAjustarPosicao?.call(LocationService.posicaoEscolhida(ponto.latitude, ponto.longitude));
  }

  LatLng? get _usuaria {
    final p = widget.posicaoUsuaria;
    return p == null ? null : LatLng(p.latitude, p.longitude);
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  // ── Câmera animada ────────────────────────────────────────────────────────

  void _animarPara(LatLng destino, double zoom) {
    if (!_mapaPronto) return;
    final inicio = _controller.camera;
    final latTween = Tween<double>(begin: inicio.center.latitude, end: destino.latitude);
    final lngTween = Tween<double>(begin: inicio.center.longitude, end: destino.longitude);
    final zoomTween = Tween<double>(begin: inicio.zoom, end: zoom);
    final curva = CurvedAnimation(parent: _camera, curve: Curves.easeInOutCubic);

    void passo() {
      _controller.move(LatLng(latTween.evaluate(curva), lngTween.evaluate(curva)), zoomTween.evaluate(curva));
    }

    _camera
      ..stop()
      ..reset();
    _camera.removeListener(_ultimoPasso ?? () {});
    _ultimoPasso = passo;
    _camera.addListener(passo);
    _camera.forward();
  }

  VoidCallback? _ultimoPasso;

  void _enquadrar(List<LatLng> pontos) {
    if (!_mapaPronto || pontos.length < 2) return;
    final destino = CameraFit.coordinates(
      coordinates: pontos,
      padding: EdgeInsets.fromLTRB(48, 96, 48, widget.espacoInferior + 48),
      maxZoom: 16.5,
    ).fit(_controller.camera);
    _animarPara(destino.center, destino.zoom);
  }

  /// Enquadra todos os pinos e a usuária. Com um ponto só, aproxima nele.
  void _enquadrarConteudo() {
    final pontos = <LatLng>[
      for (final i in widget.instituicoes)
        if (i.latitude != null && i.longitude != null) LatLng(i.latitude!, i.longitude!),
      if (_usuaria != null) _usuaria!,
    ];
    if (pontos.length >= 2) {
      _enquadrar(pontos);
    } else if (pontos.length == 1) {
      _animarPara(pontos.first, 15);
    }
  }

  static String _assinatura(List<SupportInstitution> lista) => lista.map((i) => i.id).join(',');

  LatLng? _pontoSelecionado() {
    for (final i in widget.instituicoes) {
      if (i.id == widget.selecionadaId && i.latitude != null && i.longitude != null) {
        return LatLng(i.latitude!, i.longitude!);
      }
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant SupportNetworkMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    final rota = widget.rota;
    if (rota != null && rota.length >= 2 && !identical(rota, oldWidget.rota)) {
      _enquadrar([...rota, if (_usuaria != null) _usuaria!]);
      return;
    }

    if (widget.selecionadaId != null && widget.selecionadaId != oldWidget.selecionadaId) {
      final ponto = _pontoSelecionado();
      if (ponto != null) {
        // Centraliza o pino acima do painel inferior.
        final zoom = math.max(_controller.camera.zoom, 14.5);
        final deslocamento = widget.espacoInferior / 2;
        final pixel = _controller.camera.projectAtZoom(ponto, zoom);
        final centro = _controller.camera.unprojectAtZoom(pixel + Offset(0, deslocamento), zoom);
        _animarPara(centro, zoom);
      }
      return;
    }

    if (widget.enquadrarAoMudar &&
        (_assinatura(widget.instituicoes) != _assinatura(oldWidget.instituicoes) ||
            widget.posicaoUsuaria != oldWidget.posicaoUsuaria)) {
      _enquadrarConteudo();
      return;
    }

    final antes = oldWidget.posicaoUsuaria;
    final agora = widget.posicaoUsuaria;
    final mudou = agora != null &&
        (antes == null || antes.latitude != agora.latitude || antes.longitude != agora.longitude);
    if (mudou) _animarPara(LatLng(agora.latitude, agora.longitude), 13.5);
  }

  /// Agrupa instituições com a mesma coordenada (arredondada a ~1 m).
  List<List<SupportInstitution>> _agruparPorEndereco() {
    final grupos = <String, List<SupportInstitution>>{};
    for (final inst in widget.instituicoes) {
      if (inst.latitude == null || inst.longitude == null) continue;
      final chave = '${inst.latitude!.toStringAsFixed(5)},${inst.longitude!.toStringAsFixed(5)}';
      grupos.putIfAbsent(chave, () => []).add(inst);
    }
    return grupos.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final grupos = _agruparPorEndereco();
    final usuaria = _usuaria;
    final rota = widget.rota;

    final selecionadoInicial = _mapaPronto ? null : _pontoSelecionado();
    final mapa = FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: selecionadoInicial ?? usuaria ?? SupportNetworkMap.centroPiloto,
        initialZoom: selecionadoInicial != null ? 15 : (usuaria != null ? 13.5 : 12),
        minZoom: 4,
        maxZoom: 18,
        backgroundColor: AppColors.sandDeep,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onTap: (_, ponto) {
          if (_ajustando) {
            _escolherPonto(ponto);
          } else {
            widget.onToqueNoMapa?.call();
          }
        },
        onMapReady: () {
          _mapaPronto = true;
          if (widget.enquadrarAoMudar && widget.selecionadaId == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _enquadrarConteudo();
            });
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: SupportNetworkMap.tileUrl,
          userAgentPackageName: 'br.com.redeapoio.rede_apoio',
          maxZoom: 19,
          tileBuilder: (context, tile, _) => ColorFiltered(
            colorFilter: SupportNetworkMap.filtroSuave,
            child: tile,
          ),
        ),
        if (usuaria != null && !_ajustando && widget.posicaoUsuaria!.accuracy > 25)
          CircleLayer(
            circles: [
              CircleMarker(
                point: usuaria,
                radius: widget.posicaoUsuaria!.accuracy,
                useRadiusInMeter: true,
                color: AppColors.ink.withValues(alpha: 0.10),
                borderColor: AppColors.ink.withValues(alpha: 0.35),
                borderStrokeWidth: 1.5,
              ),
            ],
          ),
        if (rota != null && rota.length >= 2) _LinhaDaRota(pontos: rota, key: ValueKey(rota)),
        MarkerLayer(
          markers: [
            for (var i = 0; i < grupos.length; i++)
              Marker(
                point: LatLng(grupos[i].first.latitude!, grupos[i].first.longitude!),
                width: 52,
                height: 60,
                alignment: Alignment.topCenter,
                child: _PinInstituicao(
                  grupo: grupos[i],
                  selecionado: grupos[i].any((g) => g.id == widget.selecionadaId),
                  esmaecido: widget.selecionadaId != null &&
                      !grupos[i].any((g) => g.id == widget.selecionadaId),
                  atraso: Duration(milliseconds: math.min(i * 12, 360)),
                  onTap: widget.onSelecionar == null ? null : () => widget.onSelecionar!(grupos[i]),
                ),
              ),
            if (usuaria != null && !_ajustando)
              Marker(point: usuaria, width: 34, height: 34, child: const _PinUsuaria()),
          ],
        ),
        RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          popupBackgroundColor: AppColors.surface,
          attributions: [
            TextSourceAttribution(
              'OpenStreetMap contributors',
              onTap: () => launchUrl(
                Uri.parse('https://www.openstreetmap.org/copyright'),
                mode: LaunchMode.externalApplication,
              ),
            ),
            if (rota != null)
              TextSourceAttribution(
                'openrouteservice.org',
                onTap: () => launchUrl(
                  Uri.parse('https://openrouteservice.org'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
          ],
        ),
      ],
    );

    final conteudo = Stack(
      children: [
        Positioned.fill(child: mapa),
        if (widget.mostrarControles)
          Positioned(
            right: 12,
            top: 12,
            child: Column(
              children: [
                if (widget.onAmpliar != null)
                  _BotaoMapa(
                    icon: Icons.open_in_full_rounded,
                    tooltip: 'Abrir mapa em tela cheia',
                    onTap: widget.onAmpliar!,
                  ),
                if (widget.onAmpliar != null && widget.onUsarLocalizacao != null)
                  const SizedBox(height: 8),
                if (widget.onUsarLocalizacao != null)
                  _BotaoMapa(
                    icon: Icons.near_me_outlined,
                    tooltip: 'Usar minha localização',
                    carregando: widget.carregandoLocalizacao,
                    ativo: usuaria != null,
                    onTap: widget.onUsarLocalizacao!,
                  ),
              ],
            ),
          ),
        Positioned(
          left: 12,
          right: widget.mostrarControles ? 64 : 12,
          top: widget.margemSuperior,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_ajustando)
                _AvisoMapa(
                  key: const ValueKey('ajustando'),
                  icone: Icons.touch_app_outlined,
                  texto: 'Toque no mapa onde você está.',
                  acao: 'Cancelar',
                  onAcao: () => setState(() => _ajustando = false),
                )
              else if (widget.posicaoUsuaria != null &&
                  widget.onAjustarPosicao != null &&
                  LocationService.ehAproximada(widget.posicaoUsuaria!))
                _AvisoMapa(
                  key: const ValueKey('aproximada'),
                  icone: Icons.location_searching_rounded,
                  texto: 'Localização aproximada '
                      '(${LocationService.formatarPrecisao(widget.posicaoUsuaria!.accuracy)}).',
                  acao: 'Ajustar',
                  onAcao: () => setState(() => _ajustando = true),
                ),
              if (grupos.isEmpty) ...[
                if (_ajustando || (widget.posicaoUsuaria != null && widget.onAjustarPosicao != null &&
                    LocationService.ehAproximada(widget.posicaoUsuaria!)))
                  const SizedBox(height: 8),
                const _AvisoMapa(texto: 'Nenhum local desta categoria no mapa.'),
              ],
            ],
          ),
        ),
      ],
    );

    final comBorda = widget.bordaArredondada
        ? ClipRRect(borderRadius: BorderRadius.circular(AppShape.radiusLg), child: conteudo)
        : conteudo;

    return Semantics(
      label: 'Mapa com ${widget.instituicoes.length} locais da rede de apoio em '
          '${AppConfig.cidadePadrao}. A lista completa está disponível em "Ver lista".',
      child: widget.altura == null ? comBorda : SizedBox(height: widget.altura, child: comBorda),
    );
  }
}

/// Linha da rota com "contorno" claro e animação de desenho.
class _LinhaDaRota extends StatelessWidget {
  const _LinhaDaRota({required this.pontos, super.key});

  final List<LatLng> pontos;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOutCubic,
      builder: (context, t, _) {
        final n = math.max(2, (pontos.length * t).ceil());
        final visiveis = pontos.sublist(0, math.min(n, pontos.length));
        return PolylineLayer(
          polylines: [
            Polyline(points: visiveis, strokeWidth: 9, color: Colors.white.withValues(alpha: 0.9)),
            Polyline(points: visiveis, strokeWidth: 5, color: AppColors.wine),
          ],
        );
      },
    );
  }
}

class _PinInstituicao extends StatelessWidget {
  const _PinInstituicao({
    required this.grupo,
    required this.selecionado,
    required this.esmaecido,
    required this.atraso,
    this.onTap,
  });

  final List<SupportInstitution> grupo;
  final bool selecionado;
  final bool esmaecido;
  final Duration atraso;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final principal = grupo.first;
    final aproximado = grupo.every((i) => i.hasApproximateLocation);
    final cor = principal.themeColor;
    final opacidade = esmaecido ? 0.45 : (aproximado ? 0.8 : 1.0);

    return Semantics(
      button: true,
      label: grupo.length > 1 ? '${grupo.length} serviços: ${principal.name} e outros' : principal.name,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          duration: AppShape.medio,
          opacity: opacidade,
          child: AnimatedScale(
            duration: AppShape.medio,
            curve: Curves.easeOutBack,
            scale: selecionado ? 1.22 : 1,
            alignment: Alignment.bottomCenter,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: AppShape.medio,
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selecionado ? AppColors.textPrimary : cor,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.paper, width: 2.5),
                        boxShadow: const [
                          BoxShadow(color: AppColors.shadowMedium, blurRadius: 8, offset: Offset(0, 3)),
                        ],
                      ),
                      child: Icon(principal.icon, color: Colors.white, size: 19),
                    ),
                    CustomPaint(
                      size: const Size(12, 8),
                      painter: _PontaPino(selecionado ? AppColors.textPrimary : cor),
                    ),
                  ],
                ),
                if (grupo.length > 1)
                  Positioned(
                    right: 2,
                    top: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cor, width: 1.5),
                      ),
                      child: Text(
                        '${grupo.length}',
                        style: TextStyle(color: cor, fontSize: 10.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      )
          .animate(delay: atraso)
          .fadeIn(duration: AppShape.medio)
          .scale(begin: const Offset(0.5, 0.5), alignment: Alignment.bottomCenter, curve: Curves.easeOutBack),
    );
  }
}

class _PontaPino extends CustomPainter {
  const _PontaPino(this.cor);

  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = cor);
  }

  @override
  bool shouldRepaint(covariant _PontaPino oldDelegate) => oldDelegate.cor != cor;
}

class _PinUsuaria extends StatelessWidget {
  const _PinUsuaria();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulso suave, repetido.
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.ink.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .scale(begin: const Offset(0.5, 0.5), end: const Offset(1.1, 1.1), duration: 1800.ms)
            .fadeOut(duration: 1800.ms),
        Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            color: AppColors.ink,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [BoxShadow(color: AppColors.shadowMedium, blurRadius: 6)],
          ),
        ),
      ],
    );
  }
}

class _BotaoMapa extends StatelessWidget {
  const _BotaoMapa({
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
      child: Material(
        color: ativo ? AppColors.ink : AppColors.paper,
        shape: const CircleBorder(side: BorderSide(color: AppColors.hairline)),
        elevation: 2,
        shadowColor: AppColors.shadowMedium,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: carregando ? null : onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: AnimatedSwitcher(
                duration: AppShape.rapido,
                child: carregando
                    ? const SizedBox(
                        key: ValueKey('carregando'),
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
                      )
                    : Icon(
                        icon,
                        key: ValueKey(icon),
                        color: ativo ? Colors.white : AppColors.textPrimary,
                        size: 20,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Faixa de aviso sobre o mapa, com ação opcional à direita.
class _AvisoMapa extends StatelessWidget {
  const _AvisoMapa({required this.texto, this.icone, this.acao, this.onAcao, super.key});

  final String texto;
  final IconData? icone;
  final String? acao;
  final VoidCallback? onAcao;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 6, acao == null ? 12 : 4, 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(AppShape.radiusSm),
        border: Border.all(color: AppColors.hairline),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 16, color: AppColors.wine),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(texto, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.3)),
          ),
          if (acao != null)
            TextButton(
              onPressed: onAcao,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                foregroundColor: AppColors.wine,
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              child: Text(acao!),
            ),
        ],
      ),
    ).animate().fadeIn(duration: AppShape.medio).slideY(begin: -0.2, duration: AppShape.medio, curve: AppShape.curva);
  }
}
