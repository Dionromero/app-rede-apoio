import 'package:flutter_test/flutter_test.dart';
import 'package:rede_apoio/core/services/location_service.dart';

void main() {
  test('formata a margem de erro da localização', () {
    expect(LocationService.formatarPrecisao(84), '±80 m');
    expect(LocationService.formatarPrecisao(1234), '±1,2 km');
    expect(LocationService.formatarPrecisao(15300), '±15 km');
  });

  test('posição escolhida no mapa é exata e não gera aviso', () {
    final p = LocationService.posicaoEscolhida(-25.43, -49.27);
    expect(p.latitude, -25.43);
    expect(p.accuracy, 0);
    expect(LocationService.ehAproximada(p), isFalse);
  });
}
