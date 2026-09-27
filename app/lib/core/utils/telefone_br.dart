/// Prepara telefones brasileiros para o discador.
///
/// Por que existe: os números da base vêm como "(41) 3265-6977". Discar
/// "4132656977" (DDD sem o 0 e sem a operadora) faz várias operadoras
/// responderem "o número que você ligou está incorreto". O formato
/// internacional (+55 DDD número) funciona em qualquer operadora e em
/// qualquer cidade, então é o que usamos.
abstract final class TelefoneBr {
  static final _naoDigito = RegExp(r'\D');

  /// Número pronto para `tel:`. Exemplos:
  /// - "(41) 3265-6977"   → "+554132656977"
  /// - "(41) 8778-1044"   → "+5541987781044" (celular antigo: acrescenta o 9)
  /// - "0 15 41 3265-6977" → "+554132656977" (tira 0 + operadora)
  /// - "190", "0800 644 0180" → sem mudança (curtos e 0800 não usam +55)
  static String paraDiscagem(String bruto) {
    final digitos = bruto.replaceAll(_naoDigito, '');
    if (digitos.isEmpty) return bruto.trim();

    // Serviços curtos (190, 180, 153, 192, 100...) e números especiais.
    if (digitos.length <= 5) return digitos;
    if (RegExp(r'^0[3589]00').hasMatch(digitos)) return digitos;
    if (RegExp(r'^[3589]00\d{7}$').hasMatch(digitos)) return '0$digitos';

    var nacional = digitos;
    if (bruto.trim().startsWith('+') || (nacional.startsWith('55') && nacional.length >= 12)) {
      nacional = nacional.substring(2); // já tinha código do país
    } else if (nacional.startsWith('0')) {
      // 0 + DDD + número (11/12 dígitos) ou 0 + operadora + DDD + número (13/14).
      nacional = nacional.length >= 13 ? nacional.substring(3) : nacional.substring(1);
    }

    // Celular salvo sem o 9 (DDD + 8 dígitos começando com 6-9).
    if (nacional.length == 10 && '6789'.contains(nacional[2])) {
      nacional = '${nacional.substring(0, 2)}9${nacional.substring(2)}';
    }

    // DDD + número: 10 (fixo) ou 11 (celular) dígitos.
    if (nacional.length == 10 || nacional.length == 11) return '+55$nacional';

    // Número local sem DDD (8 ou 9 dígitos): o discador resolve na área atual.
    return digitos;
  }

  /// Formato para exibir: "(41) 3265-6977", "(41) 98778-1044", "190".
  static String formatar(String bruto) {
    final d = paraDiscagem(bruto).replaceAll(_naoDigito, '');
    if (d.length <= 5) return d;
    if (d.startsWith('0') && d.length == 11) return '${d.substring(0, 4)} ${d.substring(4, 7)} ${d.substring(7)}';
    final nacional = d.startsWith('55') && d.length >= 12 ? d.substring(2) : d;
    if (nacional.length == 11) {
      return '(${nacional.substring(0, 2)}) ${nacional.substring(2, 7)}-${nacional.substring(7)}';
    }
    if (nacional.length == 10) {
      return '(${nacional.substring(0, 2)}) ${nacional.substring(2, 6)}-${nacional.substring(6)}';
    }
    return bruto;
  }
}
