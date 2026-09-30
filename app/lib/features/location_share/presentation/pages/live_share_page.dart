import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../trusted_contact/domain/trusted_contact.dart';
import '../../data/location_share_controller.dart';
import '../../data/location_share_repository.dart';
import '../../domain/location_share_session.dart';

/// Compartilhar a localização ao vivo com uma pessoa de confiança.
///
/// Usa [LocationShareController.instancia]: sair desta tela NÃO para o
/// compartilhamento (a Home mostra a faixa "Compartilhando ao vivo").
class LiveSharePage extends StatefulWidget {
  const LiveSharePage({required this.contato, super.key});

  final TrustedContact contato;

  @override
  State<LiveSharePage> createState() => _LiveSharePageState();
}

class _LiveSharePageState extends State<LiveSharePage> {
  final _ctrl = LocationShareController.instancia;
  int _minutos = AppConfig.duracoesCompartilhamento[1];

  Future<void> _comecar() async {
    HapticFeedback.mediumImpact();
    try {
      await _ctrl.iniciar(contato: widget.contato, minutos: _minutos);
    } on LocationShareException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  Future<void> _parar() async {
    HapticFeedback.mediumImpact();
    await _ctrl.encerrar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Localização ao vivo')),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: _ctrl,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xs, AppSpacing.screen, AppSpacing.xxl),
            children: _ctrl.emAndamento || _ctrl.status == LocationShareStatus.iniciando
                ? _emAndamento(context)
                : _configurar(context),
          ),
        ),
      ),
    );
  }

  List<Widget> _configurar(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return [
      Text(
        '${widget.contato.name} vai ver onde você está, no mapa, enquanto durar o compartilhamento.',
        style: AppFonts.serif(size: 24, peso: 600, height: 1.15),
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'O app abre o WhatsApp com um link. Você confirma o envio. A posição é atualizada a cada '
        '${AppConfig.intervaloEnvioLocalizacao.inSeconds} segundos e apagada do servidor quando termina.',
        style: t.bodyLarge?.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: AppSpacing.xl),
      Text('Por quanto tempo?', style: t.titleMedium),
      const SizedBox(height: AppSpacing.xs),
      SegmentedButton<int>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: AppColors.ink,
          selectedForegroundColor: AppColors.paper,
          minimumSize: const Size(0, 48),
        ),
        segments: [
          for (final m in AppConfig.duracoesCompartilhamento)
            ButtonSegment(value: m, label: Text(m == 60 ? '1 hora' : '$m min')),
        ],
        selected: {_minutos},
        onSelectionChanged: (s) => setState(() => _minutos = s.first),
      ),
      const SizedBox(height: AppSpacing.lg),
      if (_ctrl.status == LocationShareStatus.encerrado)
        const _Nota(icone: Icons.check_circle_outline_rounded, texto: 'O último compartilhamento foi encerrado.'),
      const _Nota(
        icone: Icons.phone_android_rounded,
        texto: 'Deixe o app aberto: com a tela bloqueada, o celular pode pausar o envio.',
      ),
      const SizedBox(height: AppSpacing.md),
      FilledButton.icon(
        onPressed: _comecar,
        icon: const Icon(Icons.share_location_rounded),
        label: Text('Compartilhar com ${widget.contato.name}'),
      ),
    ];
  }

  List<Widget> _emAndamento(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final sessao = _ctrl.sessao;
    final instavel = _ctrl.status == LocationShareStatus.instavel;
    final restante = sessao?.remaining.inMinutes ?? 0;
    final ultimo = _ctrl.ultimoEnvio;
    return [
      Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: instavel ? AppColors.wineSoft : AppColors.mossSoft,
          borderRadius: BorderRadius.circular(AppShape.radiusLg),
        ),
        child: Row(
          children: [
            Icon(
              instavel ? Icons.wifi_off_rounded : Icons.podcasts_rounded,
              color: instavel ? AppColors.wine : AppColors.moss,
              size: 28,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _ctrl.status == LocationShareStatus.iniciando
                        ? 'Começando…'
                        : instavel
                            ? 'Tentando enviar sua posição'
                            : 'Compartilhando ao vivo',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    [
                      if (restante > 0) 'termina em ${restante < 1 ? 'menos de 1' : restante} min',
                      if (ultimo != null)
                        'último envio às ${ultimo.hour.toString().padLeft(2, '0')}:${ultimo.minute.toString().padLeft(2, '0')}',
                    ].join(' · '),
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (instavel && _ctrl.mensagemErro != null) ...[
        const SizedBox(height: AppSpacing.xs),
        Text(_ctrl.mensagemErro!, style: t.bodySmall?.copyWith(color: AppColors.wine)),
      ],
      const SizedBox(height: AppSpacing.lg),
      const _Nota(
        icone: Icons.phone_android_rounded,
        texto: 'Mantenha o app aberto. Você pode usar as outras telas: o compartilhamento continua.',
      ),
      const _Nota(
        icone: Icons.delete_outline_rounded,
        texto: 'Ao parar, a posição é apagada do servidor e o link deixa de mostrar o mapa.',
      ),
      const SizedBox(height: AppSpacing.md),
      FilledButton.icon(
        onPressed: _parar,
        style: FilledButton.styleFrom(backgroundColor: AppColors.emergency),
        icon: const Icon(Icons.stop_circle_outlined),
        label: const Text('Parar de compartilhar'),
      ),
    ];
  }
}

class _Nota extends StatelessWidget {
  const _Nota({required this.icone, required this.texto});

  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 20, color: AppColors.ink),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 14.5, height: 1.45, color: AppColors.textSecondary))),
        ],
      ),
    );
  }
}
