import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/input_formatters.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../domain/trusted_contact.dart';

class TrustedContactPage extends StatefulWidget {
  const TrustedContactPage({super.key});

  static const routeName = '/pessoa-de-confianca';

  @override
  State<TrustedContactPage> createState() => _TrustedContactPageState();
}

class _TrustedContactPageState extends State<TrustedContactPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _continueToHome() {
    Navigator.pushReplacementNamed(context, HomePage.routeName);
  }

  void _saveContact() {
    if (!_formKey.currentState!.validate()) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Contato salvo apenas nesta demonstração local.'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.primary,
      ),
    );
    _continueToHome();
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
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.xxl),
              children: [
                // ── Cabeçalho com progresso ─────────────────────────────
                const _StepHeader(currentStep: 1, totalSteps: 2),

                const SizedBox(height: AppSpacing.xxl),

                // ── Ícone ilustrativo ───────────────────────────────────
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.pinkSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.people_alt_rounded,
                    color: AppColors.pink,
                    size: 32,
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ── Título e subtítulo ──────────────────────────────────
                Text(
                  'Cadastre uma pessoa de confiança',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Escolha alguém que você gostaria de avisar no futuro. '
                  'Nenhuma localização ou mensagem será enviada agora.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.55,
                      ),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // ── Campos do formulário ────────────────────────────────
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [PrimeiraLetraMaiusculaInputFormatter()],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nome da pessoa',
                    hintText: 'Ex.: Maria Silva',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 2) {
                      return 'Informe um nome para continuar.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.md),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [TelefoneBrInputFormatter()],
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Telefone',
                    hintText: '(00) 00000-0000',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (value) {
                    if (TrustedContact.normalizarTelefoneBr(value ?? '') == null) {
                      return 'Informe um telefone válido.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.lg),

                // ── Aviso de consentimento ──────────────────────────────
                _ConsentBanner(),

                const SizedBox(height: AppSpacing.xxl),

                // ── Botão primário (CTA) ────────────────────────────────
                FilledButton.icon(
                  onPressed: _saveContact,
                  icon: const Icon(Icons.check_rounded, size: 20),
                  label: const Text('Salvar contato'),
                ),

                const SizedBox(height: AppSpacing.sm),

                // ── Botão secundário ────────────────────────────────────
                TextButton(
                  onPressed: _continueToHome,
                  child: const Text('Pular por agora'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widget: Cabeçalho com barra de progresso ────────────────────────────────

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.currentStep, required this.totalSteps});

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Botão voltar
        Material(
          color: AppColors.pinkSoft,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => Navigator.maybePop(context),
            borderRadius: BorderRadius.circular(12),
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                Icons.arrow_back_rounded,
                color: AppColors.pink,
                size: 20,
              ),
            ),
          ),
        ),

        const SizedBox(width: AppSpacing.md),

        // Barra de progresso
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Passo $currentStep de $totalSteps',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  children: List.generate(totalSteps, (index) {
                    final isActive = index < currentStep;
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(right: index < totalSteps - 1 ? AppSpacing.xxs : 0),
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.pink : AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Widget: Banner de consentimento ────────────────────────────────────────

class _ConsentBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.blueSoft,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: AppColors.primary, width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Você terá controle antes de qualquer compartilhamento. '
              'Esta versão ainda não envia localização, SMS ou WhatsApp.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.55,
                    fontSize: 13,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
