import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Prévia demonstrativa do mapa de serviços de apoio.
///
/// Exibe um mapa estilizado com ruas, pins categorizados por cor
/// e um atalho inferior para acessar a lista completa.
class SupportMapPreview extends StatelessWidget {
  const SupportMapPreview({this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 228,
            child: Stack(
              children: [
                // Fundo do mapa
                Positioned.fill(
                  child: ColoredBox(
                    color: const Color(0xFFE8F5F5),
                    child: CustomPaint(painter: _MapPainter()),
                  ),
                ),

                // Label de demonstração (canto superior esquerdo)
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      'Visualização de demonstração',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                    ),
                  ),
                ),

                // Pins do mapa — cores diferenciadas por tipo
                const _MapPin(
                  left: 56,
                  top: 66,
                  label: 'Delegacia',
                  color: AppColors.pink,
                  icon: Icons.local_police_outlined,
                ),
                const _MapPin(
                  left: 210,
                  top: 52,
                  label: 'Defensoria',
                  color: AppColors.primary,
                  icon: Icons.gavel_rounded,
                ),
                const _MapPin(
                  left: 160,
                  top: 138,
                  label: 'Acolhimento',
                  color: Color(0xFF2E7D32),
                  icon: Icons.favorite_rounded,
                ),

                // Barra inferior com atalho
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadowMedium,
                          blurRadius: 12,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.place_rounded, color: AppColors.pink, size: 20),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'Serviços de apoio próximos',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.left,
    required this.top,
    required this.label,
    required this.color,
    required this.icon,
  });

  final double left;
  final double top;
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          // Cauda do pin
          Container(
            width: 2,
            height: 5,
            color: color,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 4,
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Ruas principais (curvas)
    final roadPaint = Paint()
      ..color = const Color(0xFFBDD8DA)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final road1 = Path()
      ..moveTo(-10, size.height * .18)
      ..quadraticBezierTo(
        size.width * .38,
        size.height * .42,
        size.width + 10,
        size.height * .12,
      );
    canvas.drawPath(road1, roadPaint);

    final road2 = Path()
      ..moveTo(size.width * .08, size.height + 10)
      ..quadraticBezierTo(
        size.width * .45,
        size.height * .56,
        size.width * .85,
        -10,
      );
    canvas.drawPath(road2, roadPaint);

    // Ruas secundárias (diagonais)
    final minorPaint = Paint()
      ..color = const Color(0xFFD5E8EA)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (var offset = 20.0; offset < size.width; offset += 42) {
      canvas.drawLine(
        Offset(offset, 0),
        Offset(offset - 34, size.height),
        minorPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
