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
  late final _repo = widget.repository ?? TrustedContactRepository.instance;

  List<TrustedContact> _contatos = [];

  bool get _noLimite => _contatos.length >= TrustedContactRepository.limite;

  /// No onboarding a tela substitui a anterior; pela Home, dá para voltar.
  bool get _noOnboarding => !Navigator.of(context).canPop();

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final contatos = await _repo.carregarTodos();
    if (mounted) setState(() => _contatos = contatos);
  }

  void _concluir() {
    if (_noOnboarding) {
      Navigator.of(context).pushReplacementNamed(HomePage.routeName);
    } else {
      Navigator.of(context).pop();
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
      _avisar('Não foi possível abrir a agenda. Use "Digitar número".');
      return;
    }
    if (escolhido == null || !mounted) return;

    final numero = TrustedContact.normalizarTelefoneBr(escolhido.selectedPhoneNumber ?? '');
    if (numero == null) {
      _avisar('Esse número não parece um telefone brasileiro com DDD.');
      return;
    }
    await _abrirFormulario(
      nome: (escolhido.fullName ?? '').trim(),
      telefone: TrustedContact(name: '', phone: numero).formattedPhone,
    );
  }

  Future<void> _abrirFormulario({String nome = '', String telefone = ''}) async {
    final adicionado = await showModalBottomSheet<TrustedContact>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _FormularioPessoa(
        nomeInicial: nome,
        telefoneInicial: telefone,
        daAgenda: telefone.isNotEmpty,
        aoAdicionar: _adicionar,
      ),
    );
    if (adicionado == null || !mounted) return;
    await _carregar();
    if (!mounted) return;
    _avisar('${adicionado.name} está na sua lista. Nada foi enviado.');
  }

  /// Devolve a mensagem de erro para o painel, ou `null` se deu certo.
  Future<String?> _adicionar(TrustedContact contato) async {
    try {
      return switch (await _repo.adicionar(contato)) {
        ResultadoAdicao.adicionado => null,
        ResultadoAdicao.duplicado => 'Esse número já está na sua lista.',
        ResultadoAdicao.limiteAtingido => 'Sua lista já tem ${TrustedContactRepository.limite} pessoas.',
      };
    } catch (e) {
      return 'Não foi possível salvar agora. Tente de novo.';
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
    final textos = Theme.of(context).textTheme;
    final vazia = _contatos.isEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.xl),
            children: [
              // ── Cabeçalho: progresso no onboarding, voltar pela Home ────
              _StepHeader(currentStep: _noOnboarding ? 1 : null, totalSteps: 2),

              const SizedBox(height: AppSpacing.xl),

              // ── Título e subtítulo ──────────────────────────────────
              Text('Pessoas de confiança', style: textos.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Até $limite pessoas que você gostaria de avisar se precisar. '
                'Nada é enviado agora.',
                style: textos.bodyLarge?.copyWith(height: 1.5, color: AppColors.textSecondary),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Lista ───────────────────────────────────────────────
              if (vazia)
                const _ListaVazia()
              else ...[
                for (final contato in _contatos)
                  _ContactTile(contato: contato, onRemove: () => _remover(contato)),
                Text(
                  '${_contatos.length} de $limite',
                  style: textos.labelMedium?.copyWith(color: AppColors.textSecondary),
                ),
              ],

              const SizedBox(height: AppSpacing.xl),

              // ── Adicionar: agenda (só no celular) ou digitando ──────
              if (_noLimite)
                const _LimitNotice()
              else ...[
                if (!kIsWeb) ...[
                  OutlinedButton.icon(
                    onPressed: _escolherDaAgenda,
                    icon: const Icon(Icons.contacts_rounded, size: 20),
                    label: const Text('Escolher da agenda'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                OutlinedButton.icon(
                  onPressed: () => _abrirFormulario(),
                  icon: const Icon(Icons.dialpad_rounded, size: 20),
                  label: const Text('Digitar número'),
                ),
              ],

              const SizedBox(height: AppSpacing.xl),

              const _AvisoPrivacidade(),
            ],
          ),
        ),

        // ── Ação principal, sempre visível ──────────────────────────
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xs, AppSpacing.screen, AppSpacing.md),
            child: vazia
                ? TextButton(
                    onPressed: _concluir,
                    child: Text(_noOnboarding ? 'Pular por agora' : 'Voltar'),
                  )
                : FilledButton(
                    onPressed: _concluir,
                    child: Text(_noOnboarding ? 'Continuar' : 'Concluir'),
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Widget: Painel para adicionar uma pessoa ───────────────────────────────

class _FormularioPessoa extends StatefulWidget {
  const _FormularioPessoa({
    required this.nomeInicial,
    required this.telefoneInicial,
    required this.daAgenda,
    required this.aoAdicionar,
  });

  final String nomeInicial;
  final String telefoneInicial;
  final bool daAgenda;

  /// Salva e devolve a mensagem de erro, ou `null` se deu certo.
  final Future<String?> Function(TrustedContact contato) aoAdicionar;

  @override
  State<_FormularioPessoa> createState() => _FormularioPessoaState();
}

class _FormularioPessoaState extends State<_FormularioPessoa> {
  final _formKey = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.nomeInicial);
  late final _telefone = TextEditingController(text: widget.telefoneInicial);
  String? _erro;
  bool _salvando = false;

  @override
  void dispose() {
    _nome.dispose();
    _telefone.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_salvando || !_formKey.currentState!.validate()) return;
    final contato = TrustedContact.fromInput(name: _nome.text, phone: _telefone.text);
    if (contato == null) return;

    setState(() {
      _salvando = true;
      _erro = null;
    });
    final erro = await widget.aoAdicionar(contato);
    if (!mounted) return;
    if (erro == null) {
      Navigator.of(context).pop(contato);
    } else {
      setState(() {
        _salvando = false;
        _erro = erro;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      // Sobe junto com o teclado.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Nova pessoa de confiança', style: textos.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.daAgenda
                    ? 'Confira os dados. Se quiser, troque o nome por um apelido, como “Mãe”.'
                    : 'Pode ser um apelido, como “Mãe”. Nada é enviado a essa pessoa agora.',
                style: textos.bodyMedium?.copyWith(height: 1.5, color: AppColors.textSecondary),
              ),

              const SizedBox(height: AppSpacing.xl),

              TextFormField(
                controller: _nome,
                autofocus: !widget.daAgenda,
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
                controller: _telefone,
                keyboardType: TextInputType.phone,
                inputFormatters: [TelefoneBrInputFormatter()],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _enviar(),
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

              if (_erro != null) ...[
                const SizedBox(height: AppSpacing.sm),
                // liveRegion: o leitor de tela anuncia o erro assim que aparece.
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _erro!,
                    style: textos.bodyMedium?.copyWith(color: AppColors.emergency),
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.xl),

              FilledButton.icon(
                onPressed: _salvando ? null : _enviar,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                label: const Text('Adicionar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widget: Cabeçalho ──────────────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.currentStep, required this.totalSteps});

  /// `null` esconde o progresso (tela aberta pela Home).
  final int? currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final passo = currentStep;
    return Row(
      children: [
        // Botão voltar, só quando há para onde voltar
        if (Navigator.of(context).canPop()) ...[
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
                  semanticLabel: 'Voltar',
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
        ],

        // Barra de progresso
        if (passo != null)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Passo $passo de $totalSteps',
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
                      final isActive = index < passo;
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

// ── Widget: Lista vazia ────────────────────────────────────────────────────

class _ListaVazia extends StatelessWidget {
  const _ListaVazia();

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.pinkSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.people_alt_rounded, color: AppColors.pink),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ninguém na lista ainda', style: textos.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Adicione alguém em quem você confia usando os botões abaixo.',
                  style: textos.bodySmall?.copyWith(height: 1.4, color: AppColors.textSecondary),
                ),
              ],
            ),
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

// ── Widget: Aviso de privacidade ───────────────────────────────────────────

class _AvisoPrivacidade extends StatelessWidget {
  const _AvisoPrivacidade();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            'A lista fica só neste aparelho. Da agenda, o app só lê quem você escolher. '
            'Você terá controle antes de qualquer compartilhamento.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
          ),
        ),
      ],
    );
  }
}
