import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Área tocável com resposta física: encolhe levemente ao pressionar,
/// volta com uma mola suave e dá um toque háptico leve.
///
/// Use no lugar de InkWell quando o elemento for um "objeto" (card, botão
/// grande, linha de lista) — dá a sensação de clique fluido.
class Pressable extends StatefulWidget {
  const Pressable({
    required this.child,
    required this.onTap,
    this.semanticsLabel,
    this.escala = 0.97,
    this.haptico = true,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  /// Escala durante o toque (1 = sem efeito).
  final double escala;
  final bool haptico;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressionado = false;

  void _definir(bool valor) {
    if (_pressionado != valor && mounted) setState(() => _pressionado = valor);
  }

  @override
  Widget build(BuildContext context) {
    final ativo = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: ativo,
      label: widget.semanticsLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: ativo ? (_) => _definir(true) : null,
        onTapCancel: () => _definir(false),
        onTapUp: (_) => _definir(false),
        onTap: ativo
            ? () {
                if (widget.haptico) HapticFeedback.selectionClick();
                widget.onTap!();
              }
            : null,
        child: AnimatedScale(
          scale: _pressionado ? widget.escala : 1,
          duration: _pressionado ? AppShape.rapido : AppShape.medio,
          curve: _pressionado ? Curves.easeOut : Curves.easeOutBack,
          child: AnimatedOpacity(
            opacity: ativo ? 1 : 0.5,
            duration: AppShape.rapido,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
