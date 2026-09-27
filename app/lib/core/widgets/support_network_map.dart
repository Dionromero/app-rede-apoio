import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

import '../../features/support_network/domain/models/support_institution.dart';
import '../config/app_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Mapa da rede de apoio (OpenStreetMap via flutter_map).
///
/// - Mostra um pino por endereço; instituições no mesmo endereço viram um pino
///   com contador (ex.: Casa da Mulher Brasileira + Delegacia da Mulher).
/// - Pinos com coordenada aproximada ficam semitransparentes.
/// - A posição da usuária só aparece se [posicaoUsuaria] for informada; o
///   pedido de permissão fica com quem usa o widget (botão [onUsarLocalizacao]).
class SupportNetworkMap extends StatefulWidget {
  const SupportNetworkMap({
    required this.instituicoes,
    this.posicaoUsuaria,
    this.onSelecionar,
    this.onUsarLocalizacao,
    this.onAmpliar,
    this.carregandoLocalizacao = false,
    this.altura,
    this.bordaArredondada = true,
    super.key,
  });

  final List<SupportInstitution> instituicoes;
  final Position? posicaoUsuaria;

  /// Toque em um pino. Recebe todas as instituições daquele endereço.
  final ValueChanged<List<SupportInstitution>>? onSelecionar;

  /// Botão "minha localização". Se `null`, o botão não aparece.
  final VoidCallback? onUsarLocalizacao;

  /// Botão "ampliar" (abrir em tela cheia). Se `null`, não aparece.
  final VoidCallback? onAmpliar;
  final bool carregandoLocalizacao;

  /// Altura fixa. `null` = ocupa todo o espaço disponível.
  final double? altura;
  final bool bordaArredondada;

  /// Centro de Curitiba, usado quando não há posição da usuária.
  static const centroPiloto = LatLng(-25.4284, -49.2733);

  /// Servidor de tiles. Os tiles públicos do OSM servem para o piloto;
  /// em produção, troque por um provedor de tiles (ver opções de build no README).
  static const tileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  @override
  State<SupportNetworkMap> createState() => _SupportNetworkMapState();
}

class _SupportNetworkMapState extends State<SupportNetworkMap> {
  final _controller = MapController();
  bool _mapaPronto = false;

  LatLng? get _usuaria {
    final p = widget.posicaoUsuaria;
    return p == null ? null : LatLng(p.latitude, p.longitude);
  }

  @override
  void didUpdateWidget(covariant SupportNetworkMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final antes = oldWidget.posicaoUsuaria;
    final agora = widget.posicaoUsuaria;
    final mudou = agora != null &&
        (antes == null || antes.latitude != agora.latitude || antes.longitude != agora.longitude);
    if (mudou && _mapaPronto) {
      _controller.move(LatLng(agora.latitude, agora.longitude), 13.5);
    }
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

    final mapa = FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: usuaria ?? SupportNetworkMap.centroPiloto,
        initialZoom: usuaria != null ? 13.5 : 12,
        minZoom: 4,
        maxZoom: 18,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () => _mapaPronto = true,
      ),
      children: [
        TileLayer(
          urlTemplate: SupportNetworkMap.tileUrl,
          userAgentPackageName: 'br.com.redeapoio.rede_apoio',
          maxZoom: 19,
        ),
        MarkerLayer(
          markers: [
            for (final grupo in grupos)
              Marker(
                point: LatLng(grupo.first.latitude!, grupo.first.longitude!),
                width: 48,
                height: 56,
                alignment: Alignment.topCenter,
                child: _PinInstituicao(
                  grupo: grupo,
                  onTap: widget.onSelecionar == null ? null : () => widget.onSelecionar!(grupo),
                ),
              ),
            if (usuaria != null)
              Marker(
                point: usuaria,
                width: 28,
                height: 28,
                child: const _PinUsuaria(),
              ),
          ],
        ),
        RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [
            TextSourceAttribution(
              'OpenStreetMap contributors',
              onTap: () => launchUrl(
                Uri.parse('https://www.openstreetmap.org/copyright'),
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
        Positioned(
          right: 10,
          top: 10,
          child: Column(
            children: [
              if (widget.onAmpliar != null)
                _BotaoMapa(
                  icon: Icons.open_in_full_rounded,
                  tooltip: 'Ampliar mapa',
                  onTap: widget.onAmpliar!,
                ),
              if (widget.onAmpliar != null && widget.onUsarLocalizacao != null)
                const SizedBox(height: AppSpacing.xs),
              if (widget.onUsarLocalizacao != null)
                _BotaoMapa(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Usar minha localização',
                  carregando: widget.carregandoLocalizacao,
                  onTap: widget.onUsarLocalizacao!,
                ),
            ],
          ),
        ),
        if (grupos.isEmpty)
          Positioned(
            left: 12,
            right: 60,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Nenhum local desta categoria no mapa.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ),
      ],
    );

    final comBorda = widget.bordaArredondada
        ? ClipRRect(borderRadius: BorderRadius.circular(22), child: conteudo)
        : conteudo;

    return Semantics(
      label: 'Mapa com ${widget.instituicoes.length} locais da rede de apoio em '
          '${AppConfig.cidadePadrao}. A lista completa está abaixo.',
      child: widget.altura == null ? comBorda : SizedBox(height: widget.altura, child: comBorda),
    );
  }
}

class _PinInstituicao extends StatelessWidget {
  const _PinInstituicao({required this.grupo, this.onTap});

  final List<SupportInstitution> grupo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final principal = grupo.first;
    final aproximado = grupo.every((i) => i.hasApproximateLocation);
    final cor = principal.themeColor;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: aproximado ? 0.75 : 1,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(color: AppColors.shadowMedium, blurRadius: 6, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Icon(principal.icon, color: Colors.white, size: 20),
                ),
                // "Ponta" do pino
                CustomPaint(size: const Size(12, 8), painter: _PontaPino(cor)),
              ],
            ),
            if (grupo.length > 1)
              Positioned(
                right: 0,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    '${grupo.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
      ),
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
        ),
      ),
    );
  }
}

class _BotaoMapa extends StatelessWidget {
  const _BotaoMapa({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.carregando = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool carregando;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: IconButton(
        tooltip: tooltip,
        onPressed: carregando ? null : onTap,
        icon: carregando
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(icon, color: AppColors.primary, size: 20),
      ),
    );
  }
}
