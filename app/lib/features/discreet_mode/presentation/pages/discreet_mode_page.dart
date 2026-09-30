import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/services/discreet_mode_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/pressable.dart';

/// Escolha do ícone da tela inicial: o do Sussurro ou o disfarce.
class DiscreetModePage extends StatefulWidget {
  const DiscreetModePage({super.key});

  static const routeName = '/modo-discreto';

  @override
  State<DiscreetModePage> createState() => _DiscreetModePageState();
}

class _DiscreetModePageState extends State<DiscreetModePage> {
  Disfarce? _atual;
  Disfarce? _salvando;

  @override
  void initState() {
    super.initState();
    DiscreetModeService.atual().then((d) {
      if (mounted) setState(() => _atual = d);
    });
  }

  Future<void> _escolher(Disfarce escolha) async {
    if (_salvando != null || escolha.atalho == _atual?.atalho) return;
    HapticFeedback.selectionClick();
    setState(() => _salvando = escolha);
    final ok = await DiscreetModeService.definir(escolha);
    if (!mounted) return;
    setState(() {
      _salvando = null;
      if (ok) _atual = escolha;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            !ok
                ? 'Não foi possível trocar o ícone neste aparelho.'
                : escolha.ehPadrao
                    ? 'Pronto. O ícone do Sussurro volta em alguns segundos.'
                    : 'Pronto. Em alguns segundos o app aparece como "${escolha.nome}".',
          ),
        ),
      );
  }

  Widget _grade(List<Disfarce> itens) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.05,
      children: [
        for (final d in itens)
          _OpcaoIcone(
            imagem: d.imagem,
            nome: d.nome,
            selecionado: _atual?.atalho == d.atalho,
            carregando: _salvando?.atalho == d.atalho,
            onTap: () => _escolher(d),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final suportado = DiscreetModeService.suportado;

    return Scaffold(
      appBar: AppBar(title: const Text('Modo discreto')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xs, AppSpacing.screen, AppSpacing.xxl),
          children: [
            Text(
              'Esconda o app de quem mexe no seu celular.',
              style: AppFonts.serif(size: 26, peso: 600, color: AppColors.textPrimary, height: 1.15),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Escolha um disfarce: a tela inicial passa a mostrar outro ícone e outro nome, '
              'como uma calculadora. Por dentro, o app continua igual.',
              style: t.bodyLarge?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (!suportado)
              const _Nota(
                icone: Icons.info_outline_rounded,
                texto: 'A troca de ícone está disponível no app instalado no Android.',
              )
            else ...[
              Text('Disfarces', style: t.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              _grade(DiscreetModeService.disfarces).animate().fadeIn(duration: AppShape.medio),
              const SizedBox(height: AppSpacing.lg),
              Text('Ícone original', style: t.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              _grade(const [DiscreetModeService.padrao]),
            ],
            const SizedBox(height: AppSpacing.xl),
            Text('Bom saber', style: t.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            const _Nota(
              icone: Icons.schedule_rounded,
              texto: 'O ícone pode levar alguns segundos para mudar. Em alguns celulares o '
                  'atalho sai da tela inicial: procure o novo nome na lista de apps e '
                  'arraste de volta.',
            ),
            const _Nota(
              icone: Icons.touch_app_outlined,
              texto: 'Ao abrir pelo disfarce, o app abre normalmente. O disfarce protege de '
                  'uma olhada rápida na tela, não de quem abre o app.',
            ),
            const _Nota(
              icone: Icons.logout_rounded,
              texto: 'Se alguém se aproximar, toque em "Sair" no topo da tela inicial: '
                  'o app fecha na hora.',
            ),
            const _Nota(
              icone: Icons.chat_bubble_outline_rounded,
              texto: 'Mensagens com sua localização ficam no WhatsApp ou no SMS. '
                  'Se for preciso, apague a conversa depois de enviar.',
            ),
          ],
        ),
      ),
    );
  }
}

class _OpcaoIcone extends StatelessWidget {
  const _OpcaoIcone({
    required this.imagem,
    required this.nome,
    required this.selecionado,
    required this.carregando,
    required this.onTap,
  });

  final String imagem;
  final String nome;
  final bool selecionado;
  final bool carregando;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selecionado,
      label: 'Ícone $nome',
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppShape.medio,
          curve: AppShape.curva,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selecionado ? AppColors.paper : AppColors.sandDeep.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppShape.radiusLg),
            border: Border.all(
              color: selecionado ? AppColors.wine : AppColors.hairline,
              width: selecionado ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(imagem, width: 64, height: 64),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(nome, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.xxs),
              SizedBox(
                height: 20,
                child: carregando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.wine),
                      )
                    : selecionado
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_rounded, size: 16, color: AppColors.wine),
                              SizedBox(width: 4),
                              Text('Em uso', style: TextStyle(fontSize: 13, color: AppColors.wine)),
                            ],
                          ).animate().fadeIn(duration: AppShape.rapido)
                        : null,
              ),
            ],
          ),
        ),
      ),
    );
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
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.inkSoft, borderRadius: BorderRadius.circular(10)),
            child: Icon(icone, size: 18, color: AppColors.ink),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(texto, style: const TextStyle(fontSize: 14.5, height: 1.45, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
