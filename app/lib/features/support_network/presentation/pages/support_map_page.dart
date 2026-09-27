import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/widgets/support_network_map.dart';
import '../../domain/models/support_institution.dart';
import 'support_network_page.dart';
import '../../../../core/theme/app_spacing.dart';

/// Mapa da rede de apoio em tela cheia (aberto pelo botão "ampliar" da Home).
class SupportMapPage extends StatelessWidget {
  const SupportMapPage({
    required this.instituicoes,
    this.posicaoUsuaria,
    super.key,
  });

  final List<SupportInstitution> instituicoes;
  final Position? posicaoUsuaria;

  /// Abre a lista de instituições de um endereço ou os detalhes, se for uma só.
  static Future<void> mostrarGrupo(BuildContext context, List<SupportInstitution> grupo) async {
    if (grupo.length == 1) {
      return InstitutionDetailsSheet.show(context, grupo.first);
    }
    final escolhida = await showModalBottomSheet<SupportInstitution>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.xs),
              child: Text(
                '${grupo.length} serviços neste endereço',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            for (final inst in grupo)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: inst.softThemeColor,
                  child: Icon(inst.icon, color: inst.themeColor, size: 20),
                ),
                title: Text(inst.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(inst.categoryLabel),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(ctx, inst),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (escolhida != null && context.mounted) {
      await InstitutionDetailsSheet.show(context, escolhida);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa da rede de apoio')),
      body: SupportNetworkMap(
        instituicoes: instituicoes,
        posicaoUsuaria: posicaoUsuaria,
        bordaArredondada: false,
        onSelecionar: (grupo) => mostrarGrupo(context, grupo),
      ),
    );
  }
}
