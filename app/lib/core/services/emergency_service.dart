import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Serviço para ações de emergência: ligação 190, 180 e discagem direta.
///
/// Todas as chamadas abrem o discador nativo do dispositivo com o número
/// pré-preenchido. A confirmação final é da usuária (exigência do sistema
/// operacional e regra de segurança do projeto).
class EmergencyService {
  const EmergencyService._();

  /// Abre o discador com o número 190 (Polícia Militar).
  ///
  /// Retorna `true` se o discador foi aberto com sucesso.
  static Future<bool> ligar190() => discar('190');

  /// Abre o discador com o número 180 (Central de Atendimento à Mulher).
  ///
  /// Retorna `true` se o discador foi aberto com sucesso.
  static Future<bool> ligar180() => discar('180');

  /// Abre o discador com um número (ex.: canal vindo de `get_app_bootstrap`).
  ///
  /// Não usa `canLaunchUrl`: no Android 11+ ele pode responder `false` mesmo
  /// com discador disponível. Se retornar `false`, a interface DEVE mostrar o
  /// número em destaque para a usuária discar manualmente.
  static Future<bool> discar(String numero) async {
    final uri = Uri(scheme: 'tel', path: numero);
    try {
      return await launchUrl(uri);
    } catch (_) {
      // Dispositivo pode não suportar chamadas (ex.: tablet sem SIM).
    }
    return false;
  }

  /// Exibe diálogo de confirmação antes de abrir o discador para o 190.
  ///
  /// Retorna `true` se a usuária confirmou e o discador foi aberto.
  static Future<bool> confirmarELigar190(BuildContext context) async {
    final confirmou = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.phone_in_talk_rounded, color: AppColors.emergency),
            SizedBox(width: AppSpacing.sm),
            Text('Ligar para 190'),
          ],
        ),
        content: const Text(
          'Você será direcionada ao discador para ligar para a Polícia Militar.\n\n'
          'A ligação só será iniciada quando você confirmar no próprio discador.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.emergency,
              minimumSize: const Size(64, 44),
            ),
            child: const Text('Ligar agora'),
          ),
        ],
      ),
    );

    if (confirmou == true) {
      return ligar190();
    }
    return false;
  }

  /// Exibe diálogo de confirmação antes de abrir o discador para o 180.
  ///
  /// Retorna `true` se a usuária confirmou e o discador foi aberto.
  static Future<bool> confirmarELigar180(BuildContext context) async {
    final confirmou = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.support_agent_rounded, color: AppColors.ink),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: Text('Ligar para o Ligue 180')),
          ],
        ),
        content: const Text(
          'A Central de Atendimento à Mulher funciona 24 horas, '
          'com ligação gratuita e sigilosa.\n\n'
          'Você pode pedir orientação, denunciar e ser encaminhada '
          'para serviços de apoio.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text('Ligar agora'),
          ),
        ],
      ),
    );

    if (confirmou == true) {
      return ligar180();
    }
    return false;
  }
}
