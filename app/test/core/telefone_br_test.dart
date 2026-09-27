import 'package:flutter_test/flutter_test.dart';
import 'package:rede_apoio/core/utils/telefone_br.dart';

void main() {
  group('TelefoneBr.paraDiscagem', () {
    test('fixo e celular com DDD viram +55', () {
      expect(TelefoneBr.paraDiscagem('(41) 3265-6977'), '+554132656977');
      expect(TelefoneBr.paraDiscagem('(41) 98778-1044'), '+5541987781044');
    });

    test('celular antigo sem o 9 ganha o 9', () {
      expect(TelefoneBr.paraDiscagem('(41) 8778-1044'), '+5541987781044');
    });

    test('tira 0 + operadora e aceita número já com +55', () {
      expect(TelefoneBr.paraDiscagem('0 41 3265-6977'), '+554132656977');
      expect(TelefoneBr.paraDiscagem('0 15 41 3265-6977'), '+554132656977');
      expect(TelefoneBr.paraDiscagem('+55 41 3265-6977'), '+554132656977');
      expect(TelefoneBr.paraDiscagem('55 41 98778-1044'), '+5541987781044');
    });

    test('DDD 55 (RS) não é confundido com código do país', () {
      expect(TelefoneBr.paraDiscagem('(55) 3222-1234'), '+555532221234');
    });

    test('curtos e 0800 ficam como estão', () {
      expect(TelefoneBr.paraDiscagem('190'), '190');
      expect(TelefoneBr.paraDiscagem('180'), '180');
      expect(TelefoneBr.paraDiscagem('0800 644 0180'), '08006440180');
    });

    test('número local sem DDD fica só com dígitos', () {
      expect(TelefoneBr.paraDiscagem('3265-6977'), '32656977');
    });
  });

  test('formata para exibir', () {
    expect(TelefoneBr.formatar('4132656977'), '(41) 3265-6977');
    expect(TelefoneBr.formatar('(41) 8778-1044'), '(41) 98778-1044');
    expect(TelefoneBr.formatar('190'), '190');
  });
}
