import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/pressable.dart';
import '../../data/street_view_service.dart';
import '../../domain/models/support_institution.dart';

/// Card para exibição da foto da fachada (Google Street View) ou atalho para o panorama 360°.
///
/// Permite à mulher reconhecer visualmente o local de atendimento antes de chegar,
/// identificando entradas, placas e características da rua com antecedência.
class StreetViewCard extends StatefulWidget {
  const StreetViewCard({
    required this.instituicao,
    this.chaveApiOverride,
    super.key,
  });

  final SupportInstitution instituicao;

  /// Permite injetar uma chave explicitamente nos testes ou telas.
  final String? chaveApiOverride;

  @override
  State<StreetViewCard> createState() => _StreetViewCardState();
}

class _StreetViewCardState extends State<StreetViewCard> {
  bool _erroCarregamentoImagem = false;

  void _abrirPanorama(double lat, double lng) {
    StreetViewService.abrirNoStreetView(
      latitude: lat,
      longitude: lng,
    );
  }

  @override
  Widget build(BuildContext context) {
    final inst = widget.instituicao;
    final lat = inst.latitude;
    final lng = inst.longitude;
    if (lat == null || lng == null) {
      return const SizedBox.shrink();
    }

    final urlImagem = _erroCarregamentoImagem
        ? null
        : StreetViewService.urlImagemEstatica(
            latitude: lat,
            longitude: lng,
            chaveApi: widget.chaveApiOverride,
          );

    if (urlImagem != null) {
      return _CardComImagem(
        urlImagem: urlImagem,
        instituicao: inst,
        onTap: () => _abrirPanorama(lat, lng),
        onError: () => setState(() => _erroCarregamentoImagem = true),
      );
    }

    return _CardSemImagem(
      instituicao: inst,
      onTap: () => _abrirPanorama(lat, lng),
    );
  }
}

class _CardComImagem extends StatelessWidget {
  const _CardComImagem({
    required this.urlImagem,
    required this.instituicao,
    required this.onTap,
    required this.onError,
  });

  final String urlImagem;
  final SupportInstitution instituicao;
  final VoidCallback onTap;
  final VoidCallback onError;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.streetview_rounded, size: 16, color: AppColors.ink),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Fachada do local (Street View)',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppShape.radius),
          child: Pressable(
            onTap: onTap,
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    urlImagem,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      WidgetsBinding.instance.addPostFrameCallback((_) => onError());
                      return const SizedBox.shrink();
                    },
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: AppColors.sandDeep,
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        ),
                      );
                    },
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                        ],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  left: AppSpacing.sm,
                  right: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                  child: Row(
                    children: [
                      Icon(Icons.panorama_photosphere_rounded, size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Toque para abrir visão 360°',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Icon(Icons.open_in_new_rounded, size: 14, color: Colors.white70),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (instituicao.hasApproximateLocation) ...[
          const SizedBox(height: 4),
          const Text(
            'A coordenada no mapa é aproximada; confira a numeração do prédio ao chegar.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

class _CardSemImagem extends StatelessWidget {
  const _CardSemImagem({
    required this.instituicao,
    required this.onTap,
  });

  final SupportInstitution instituicao;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.sandDeep.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppShape.radius),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.streetview_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reconhecer fachada no Street View',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Veja a entrada e a rua em 360° no Google Maps antes de ir para reconhecer o local com segurança.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                  ),
                  if (instituicao.hasApproximateLocation) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Ponto aproximado: procure pela placa e numeração indicada.',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.ink),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.ink),
          ],
        ),
      ),
    );
  }
}
