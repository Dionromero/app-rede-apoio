import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/input_formatters.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../data/trusted_contact_repository.dart';
import '../../domain/trusted_contact.dart';

class TrustedContactPage extends StatefulWidget {
  const TrustedContactPage({super.key, this.repository});

  static const routeName = '/pessoa-de-confianca';

  /// Usado nos testes. Por padrão, [TrustedContactRepository.instance].
  final TrustedContactRepository? repository;

  @override
  State<TrustedContactPage> createState() => _TrustedContactPageState();
}

class _TrustedContactPageState extends State<TrustedContactPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  late final _repo = widget.repository ?? TrustedContactRepository.instance;

  List<TrustedContact> _contatos = [];

  bool get _noLimite => _contatos.length >= TrustedContactRepository.limite;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final contatos = await _repo.carregarTodos();
    if (mounted) setState(() => _contatos = contatos);
  }

  void _continuar() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed(HomePage.routeName);
    }
  }

  void _avisar(String mensagem) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensagem),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: AppColors.primary,
        ),
      );
  }

  /// Abre o seletor de contatos do sistema. O app recebe só o número escolhido
  /// e não precisa de permissão para ler a agenda.
  Future<void> _escolherDaAgenda() async {
    final Contact? escolhido;
    try {
      escolhido = await FlutterNativeContactPicker().selectPhoneNumber();
    } catch (e) {
      _avisar('Não foi possível abrir a agenda. Digite o contato abaixo.');
      return;
    }
    if (escolhido == null || !mounted) return;

    final numero = TrustedContact.normalizarTelefoneBr(escolhido.selectedPhoneNumber ?? '');
    if (numero == null) {
      _avisar('Esse número não parece um telefone brasileiro com DDD.');
      return;
    }
    setState(() {
      _nameController.text = (escolhido!.fullName ?? '').trim();
      _phoneController.text = TrustedContact(name: '', phone: numero).formattedPhone;
    });
    _avisar('Confira o nome e toque em "Adicionar à lista".');
  }

  Future<void> _adicionar() async {
    if (!_formKey.currentState!.validate()) return;
    final contato = TrustedContact.fromInput(
      name: _nameController.text,
      phone: _phoneController.text,
    );
    if (contato == null) return;

    final ResultadoAdicao resultado;
    try {
      resultado = await _repo.adicionar(contato);
    } catch (e) {
      _avisar('Não foi possível salvar agora. Tente de novo.');
      return;
    }
    if (!mounted) return;

    switch (resultado) {
      case ResultadoAdicao.adicionado:
        _nameController.clear();
        _phoneController.clear();
        await _carregar();
        if (!mounted) return;
        _avisar('${contato.name} está na sua lista. Nada foi enviado.');
      case ResultadoAdicao.duplicado:
        _avisar('Esse número já está na sua lista.');
      case ResultadoAdicao.limiteAtingido:
        _avisar('Sua lista já tem ${TrustedContactRepository.limite} pessoas.');
    }
  }

  Future<void> _remover(TrustedContact contato) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remover ${contato.name}?'),
        content: const Text('A pessoa sai da sua lista. Nada é enviado a ela.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmou != true) return;
    await _repo.remover(contato.phone);
    await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    const limite = TrustedContactRepository.limite;
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
                  'Suas pessoas de confiança',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Escolha até $limite pessoas que você gostaria de avisar no futuro. '
                  'Nenhuma localização ou mensagem será enviada agora.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.55,
                      ),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // ── Lista de pessoas cadastradas ────────────────────────
                if (_contatos.isNotEmpty) ...[
                  Text(
                    'Cadastradas (${_contatos.length} de $limite)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final contato in _contatos)
                    _ContactTile(contato: contato, onRemove: () => _remover(contato)),
                  const SizedBox(height: AppSpacing.xl),
                ],

                if (_noLimite)
                  const _LimitNotice()
                else ...[
                  // ── Importar da agenda (só no celular) ──────────────────
                  if (!kIsWeb) ...[
                    OutlinedButton.icon(
                      onPressed: _escolherDaAgenda,
                      icon: const Icon(Icons.contacts_rounded, size: 20),
                      label: const Text('Escolher da agenda'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

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
                    onPressed: _adicionar,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                    label: const Text('Adicionar à lista'),
                  ),
                ],

                const SizedBox(height: AppSpacing.sm),

                // ── Botão secundário ────────────────────────────────────
                TextButton(
                  onPressed: _continuar,
                  child: Text(_contatos.isEmpty ? 'Pular por agora' : 'Continuar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widget: Pessoa cadastrada ──────────────────────────────────────────────

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contato, required this.onRemove});

  final TrustedContact contato;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.pinkSoft,
            foregroundColor: AppColors.pink,
            child: Text(contato.name.characters.first.toUpperCase()),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contato.name,
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  contato.formattedPhone,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Remover ${contato.name}',
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Widget: Aviso de limite ────────────────────────────────────────────────

class _LimitNotice extends StatelessWidget {
  const _LimitNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.pinkSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'Sua lista está completa (${TrustedContactRepository.limite} pessoas). '
        'Para incluir outra, remova alguém.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
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
              'Esta versão ainda não envia localização, SMS ou WhatsApp. '
              'Da agenda, o app só lê o contato que você escolher, e a lista '
              'fica salva apenas neste aparelho.',
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
