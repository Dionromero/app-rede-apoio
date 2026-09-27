import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Renderizador de Markdown simples para os guias de direitos.
///
/// Suporta o que os guias usam: títulos (#, ##, ###), listas (- e 1.),
/// citações (>), parágrafos e **negrito**. Evita dependência externa;
/// se os guias precisarem de mais recursos (links, tabelas), avaliar um pacote.
class SimpleMarkdown extends StatelessWidget {
  const SimpleMarkdown(this.texto, {this.omitirPrimeiroTitulo = false, super.key});

  final String texto;

  /// Esconde o primeiro "# Título" (quando a tela já mostra o título na AppBar).
  final bool omitirPrimeiroTitulo;

  @override
  Widget build(BuildContext context) {
    final blocos = parse(texto);
    var pulouTitulo = !omitirPrimeiroTitulo;
    final widgets = <Widget>[];

    for (final b in blocos) {
      if (!pulouTitulo && b.tipo == MdTipo.titulo1) {
        pulouTitulo = true;
        continue;
      }
      widgets.add(_bloco(context, b));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  Widget _bloco(BuildContext context, MdBloco b) {
    final tema = Theme.of(context).textTheme;
    const corpo = TextStyle(fontSize: 16, height: 1.55, color: AppColors.textPrimary);

    switch (b.tipo) {
      case MdTipo.titulo1:
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.sm),
          child: Semantics(
            header: true,
            child: _rico(b.texto, tema.headlineSmall ?? corpo),
          ),
        );
      case MdTipo.titulo2:
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xs),
          child: Semantics(
            header: true,
            child: _rico(b.texto, tema.titleLarge ?? corpo),
          ),
        );
      case MdTipo.titulo3:
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
          child: Semantics(
            header: true,
            child: _rico(b.texto, tema.titleMedium?.copyWith(fontWeight: FontWeight.w700) ?? corpo),
          ),
        );
      case MdTipo.itemLista:
      case MdTipo.itemNumerado:
        return Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xxs, bottom: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  b.tipo == MdTipo.itemNumerado ? '${b.numero}.' : '•',
                  style: corpo.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
              Expanded(child: _rico(b.texto, corpo)),
            ],
          ),
        );
      case MdTipo.citacao:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.wineSoft,
            borderRadius: BorderRadius.circular(12),
            border: const Border(left: BorderSide(color: AppColors.wine, width: 3)),
          ),
          child: _rico(b.texto, corpo),
        );
      case MdTipo.paragrafo:
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _rico(b.texto, corpo),
        );
    }
  }

  static Widget _rico(String texto, TextStyle estilo) =>
      Text.rich(TextSpan(style: estilo, children: negritoSpans(texto)));

  /// Converte "**negrito**" em spans com peso maior.
  static List<TextSpan> negritoSpans(String texto) {
    final partes = texto.split('**');
    return [
      for (var i = 0; i < partes.length; i++)
        if (partes[i].isNotEmpty)
          TextSpan(
            text: partes[i],
            style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w800) : null,
          ),
    ];
  }

  /// Quebra o texto em blocos. Público para testes.
  static List<MdBloco> parse(String texto) {
    final blocos = <MdBloco>[];
    final paragrafo = <String>[];

    void fechaParagrafo() {
      if (paragrafo.isEmpty) return;
      blocos.add(MdBloco(MdTipo.paragrafo, paragrafo.join(' ')));
      paragrafo.clear();
    }

    final numerado = RegExp(r'^(\d+)\.\s+(.*)$');
    for (final bruta in texto.split('\n')) {
      final linha = bruta.trim();
      if (linha.isEmpty) {
        fechaParagrafo();
        continue;
      }
      final m = numerado.firstMatch(linha);
      if (linha.startsWith('### ')) {
        fechaParagrafo();
        blocos.add(MdBloco(MdTipo.titulo3, linha.substring(4)));
      } else if (linha.startsWith('## ')) {
        fechaParagrafo();
        blocos.add(MdBloco(MdTipo.titulo2, linha.substring(3)));
      } else if (linha.startsWith('# ')) {
        fechaParagrafo();
        blocos.add(MdBloco(MdTipo.titulo1, linha.substring(2)));
      } else if (linha.startsWith('- ') || linha.startsWith('* ')) {
        fechaParagrafo();
        blocos.add(MdBloco(MdTipo.itemLista, linha.substring(2)));
      } else if (m != null) {
        fechaParagrafo();
        blocos.add(MdBloco(MdTipo.itemNumerado, m.group(2)!, numero: int.parse(m.group(1)!)));
      } else if (linha.startsWith('>')) {
        fechaParagrafo();
        blocos.add(MdBloco(MdTipo.citacao, linha.substring(1).trim()));
      } else {
        paragrafo.add(linha);
      }
    }
    fechaParagrafo();
    return blocos;
  }
}

enum MdTipo { titulo1, titulo2, titulo3, itemLista, itemNumerado, citacao, paragrafo }

class MdBloco {
  const MdBloco(this.tipo, this.texto, {this.numero});

  final MdTipo tipo;
  final String texto;
  final int? numero;
}
