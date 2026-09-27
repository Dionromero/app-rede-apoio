import 'package:flutter/services.dart';

/// Máscara de telefone brasileiro enquanto a usuária digita:
/// "(41) 3221-2701" (fixo, 10 dígitos) ou "(41) 99999-8888" (celular, 11).
///
/// Só muda a exibição. Para salvar, use `TrustedContact.normalizarTelefoneBr`.
class TelefoneBrInputFormatter extends TextInputFormatter {
  static const _maxDigitos = 11;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digitosAntigos = _digitos(oldValue.text);
    var digitos = _digitos(newValue.text);
    var digitosAntesDoCursor = _digitos(
      newValue.text.substring(0, newValue.selection.end.clamp(0, newValue.text.length)),
    ).length;

    // Backspace logo depois de um separador ("-", ")", " "): apaga o dígito anterior.
    final apagouSoSeparador =
        newValue.text.length < oldValue.text.length && digitos == digitosAntigos;
    if (apagouSoSeparador && digitosAntesDoCursor > 0) {
      digitos = digitos.replaceRange(digitosAntesDoCursor - 1, digitosAntesDoCursor, '');
      digitosAntesDoCursor--;
    }

    // DDD nunca começa com 0 ("041..." vira "41...").
    final semZeros = digitos.replaceFirst(RegExp(r'^0+'), '');
    digitosAntesDoCursor -= digitos.length - semZeros.length;
    digitos = semZeros;

    if (digitos.length > _maxDigitos) {
      // Número já completo e a usuária digitou mais um: ignora o dígito extra.
      final digitouUmCaractere =
          oldValue.selection.isCollapsed && newValue.text.length == oldValue.text.length + 1;
      if (digitouUmCaractere) return oldValue;
      // Colou "+55 41 99999-8888": tira o código do país.
      if (digitos.startsWith('55') && digitos.length <= _maxDigitos + 2) {
        digitos = digitos.substring(2);
      }
      digitos = digitos.substring(0, digitos.length.clamp(0, _maxDigitos));
      digitosAntesDoCursor = digitos.length;
    }

    final texto = _formatar(digitos);
    final cursor = _posicaoDepoisDe(texto, digitosAntesDoCursor.clamp(0, digitos.length));
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }

  static String _digitos(String texto) => texto.replaceAll(RegExp(r'\D'), '');

  static String _formatar(String d) {
    if (d.isEmpty) return '';
    if (d.length <= 2) return '($d';
    final ddd = d.substring(0, 2);
    final resto = d.substring(2);
    if (resto.length <= 4) return '($ddd) $resto';
    final corte = resto.length == 9 ? 5 : 4;
    return '($ddd) ${resto.substring(0, corte)}-${resto.substring(corte)}';
  }

  /// Posição no texto formatado logo depois do n-ésimo dígito.
  static int _posicaoDepoisDe(String texto, int n) {
    if (n == 0) return texto.isEmpty ? 0 : 1;
    var vistos = 0;
    for (var i = 0; i < texto.length; i++) {
      if (RegExp(r'\d').hasMatch(texto[i]) && ++vistos == n) return i + 1;
    }
    return texto.length;
  }
}

/// Deixa maiúscula a primeira letra do texto. Diferente de `textCapitalization`,
/// que só vale no teclado virtual, funciona também com teclado físico e na web.
class PrimeiraLetraMaiusculaInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final texto = newValue.text;
    final i = texto.indexOf(RegExp(r'\S'));
    if (i == -1) return newValue;
    final maiuscula = texto[i].toUpperCase();
    // Algumas letras mudam de tamanho ("ß" vira "SS"); nesse caso não mexe.
    if (maiuscula == texto[i] || maiuscula.length != 1) return newValue;
    return newValue.copyWith(text: texto.replaceRange(i, i + 1, maiuscula));
  }
}
