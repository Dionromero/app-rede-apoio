import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rede_apoio/core/utils/input_formatters.dart';

TextEditingValue _valor(String texto, [int? cursor]) => TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: cursor ?? texto.length),
    );

/// Simula a usuária digitando [teclas] uma a uma, no fim do campo.
String _digitar(TextInputFormatter formatter, String teclas) {
  var atual = _valor('');
  for (final tecla in teclas.split('')) {
    final pos = atual.selection.end;
    atual = formatter.formatEditUpdate(atual, _valor(atual.text.replaceRange(pos, pos, tecla), pos + 1));
  }
  return atual.text;
}

void main() {
  group('TelefoneBrInputFormatter', () {
    final f = TelefoneBrInputFormatter();

    test('formata celular e fixo enquanto digita', () {
      expect(_digitar(f, '41999998888'), '(41) 99999-8888');
      expect(_digitar(f, '4132212701'), '(41) 3221-2701');
    });

    test('monta a máscara aos poucos', () {
      expect(_digitar(f, '4'), '(4');
      expect(_digitar(f, '41'), '(41');
      expect(_digitar(f, '419'), '(41) 9');
      expect(_digitar(f, '4199999'), '(41) 9999-9');
    });

    test('ignora letras, zero inicial e dígitos além do limite', () {
      expect(_digitar(f, '41abc99999-8888'), '(41) 99999-8888');
      expect(_digitar(f, '041999998888'), '(41) 99999-8888');
      expect(_digitar(f, '419999988887'), '(41) 99999-8888');
      expect(_digitar(f, '559999988887'), '(55) 99999-8888');
    });

    test('ao colar, tira o código do país', () {
      expect(f.formatEditUpdate(_valor(''), _valor('+55 41 99999-8888')).text, '(41) 99999-8888');

      const tudoSelecionado = TextEditingValue(
        text: '(41) 99999-8888',
        selection: TextSelection(baseOffset: 0, extentOffset: 15),
      );
      expect(f.formatEditUpdate(tudoSelecionado, _valor('+55 41 3221-2701')).text, '(41) 3221-2701');
    });

    test('backspace depois do hífen apaga o dígito anterior', () {
      final r = f.formatEditUpdate(_valor('(41) 3221-2701', 10), _valor('(41) 32212701', 9));
      expect(r.text, '(41) 3222-701');
      expect(r.selection.end, 8);
    });

    test('editar no meio mantém o cursor no lugar', () {
      final r = f.formatEditUpdate(_valor('(41) 9999-8888', 7), _valor('(41) 995 99-8888', 8));
      expect(r.text, '(41) 99599-8888');
      expect(r.selection.end, 8);
    });

    test('apagar tudo deixa o campo vazio', () {
      expect(f.formatEditUpdate(_valor('(4'), _valor('(')).text, '');
    });
  });

  group('PrimeiraLetraMaiusculaInputFormatter', () {
    final f = PrimeiraLetraMaiusculaInputFormatter();

    test('deixa só a primeira letra maiúscula', () {
      expect(_digitar(f, 'maria silva'), 'Maria silva');
      expect(_digitar(f, 'élida'), 'Élida');
      expect(_digitar(f, '  joana'), '  Joana');
    });

    test('não mexe em texto vazio nem em letras que mudam de tamanho', () {
      expect(_digitar(f, '   '), '   ');
      expect(_digitar(f, 'ßa'), 'ßa');
    });
  });
}
