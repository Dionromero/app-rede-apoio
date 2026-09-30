import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../trusted_contact/domain/trusted_contact.dart';

/// Para onde a usuária quer mandar a localização.
sealed class DestinoLocalizacao {
  const DestinoLocalizacao();
}

/// Uma pessoa de confiança, pelo WhatsApp (com SMS de reserva).
class ParaContato extends DestinoLocalizacao {
  const ParaContato(this.contato);
  final TrustedContact contato;
}

/// Todas as pessoas de confiança de uma vez, por SMS.
class ParaTodosPorSms extends DestinoLocalizacao {
  const ParaTodosPorSms(this.contatos);
  final List<TrustedContact> contatos;
}

/// Localização ao vivo para uma pessoa de confiança (página /acompanhar).
class AoVivoCom extends DestinoLocalizacao {
  const AoVivoCom(this.contato);
  final TrustedContact contato;
}

/// Qualquer contato, escolhido no próprio WhatsApp.
class ParaOutroNoWhatsApp extends DestinoLocalizacao {
  const ParaOutroNoWhatsApp();
}

/// Folha "Enviar minha localização para…". Retorna `null` se fechar.
/// Com [aoVivoDisponivel], a usuária escolhe entre "Posição agora" e "Ao vivo".
Future<DestinoLocalizacao?> escolherDestinoLocalizacao(
  BuildContext context,
  List<TrustedContact> contatos, {
  bool aoVivoDisponivel = false,
}) {
  return showModalBottomSheet<DestinoLocalizacao>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppShape.radiusLg)),
    ),
    builder: (_) => _Folha(contatos: contatos, aoVivoDisponivel: aoVivoDisponivel),
  );
}

class _Folha extends StatefulWidget {
  const _Folha({required this.contatos, required this.aoVivoDisponivel});

  final List<TrustedContact> contatos;
  final bool aoVivoDisponivel;

  @override
  State<_Folha> createState() => _FolhaState();
}

class _FolhaState extends State<_Folha> {
  bool _aoVivo = false;

  @override
  Widget build(BuildContext context) {
    final contatos = widget.contatos;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Enviar minha localização', style: AppFonts.serif(size: 24, peso: 600)),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              _aoVivo
                  ? 'A pessoa recebe um link e vê você se mover no mapa, até você parar ou o tempo acabar.'
                  : 'Vai um link do mapa com o lugar onde você está agora. Você confirma o envio no WhatsApp ou no SMS.',
              style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.textSecondary),
            ),
            if (widget.aoVivoDisponivel && contatos.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: AppColors.ink,
                  selectedForegroundColor: AppColors.paper,
                  minimumSize: const Size(0, 44),
                ),
                segments: const [
                  ButtonSegment(value: false, label: Text('Posição agora'), icon: Icon(Icons.place_outlined)),
                  ButtonSegment(value: true, label: Text('Ao vivo'), icon: Icon(Icons.podcasts_rounded)),
                ],
                selected: {_aoVivo},
                onSelectionChanged: (s) => setState(() => _aoVivo = s.first),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            for (final c in contatos)
              _Opcao(
                icone: _aoVivo ? Icons.podcasts_rounded : Icons.favorite_border_rounded,
                cor: AppColors.wine,
                fundo: AppColors.wineSoft,
                titulo: c.name,
                subtitulo: _aoVivo ? 'Acompanhar ao vivo, pelo WhatsApp' : 'WhatsApp',
                onTap: () => Navigator.pop(context, _aoVivo ? AoVivoCom(c) : ParaContato(c)),
              ),
            if (!_aoVivo && contatos.length > 1)
              _Opcao(
                icone: Icons.sms_outlined,
                cor: AppColors.ink,
                fundo: AppColors.inkSoft,
                titulo: 'Avisar todas as pessoas (${contatos.length})',
                subtitulo: 'Uma mensagem de SMS para todas de uma vez',
                onTap: () => Navigator.pop(context, ParaTodosPorSms(contatos)),
              ),
            if (!_aoVivo)
              _Opcao(
                icone: Icons.person_search_outlined,
                cor: AppColors.textPrimary,
                fundo: AppColors.sandDeep,
                titulo: 'Outro contato',
                subtitulo: 'Escolher no WhatsApp',
                onTap: () => Navigator.pop(context, const ParaOutroNoWhatsApp()),
              ),
          ],
        ),
      ),
    );
  }
}

class _Opcao extends StatelessWidget {
  const _Opcao({
    required this.icone,
    required this.cor,
    required this.fundo,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  final IconData icone;
  final Color cor;
  final Color fundo;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Semantics(
        button: true,
        label: '$titulo, $subtitulo',
        child: ExcludeSemantics(
          child: Pressable(
            onTap: onTap,
            escala: 0.98,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppShape.radius),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(12)),
                    child: Icon(icone, size: 20, color: cor),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        Text(subtitulo, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
