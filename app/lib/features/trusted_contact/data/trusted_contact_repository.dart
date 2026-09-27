import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/trusted_contact.dart';

/// Resultado de [TrustedContactRepository.adicionar].
enum ResultadoAdicao { adicionado, duplicado, limiteAtingido }

/// Guarda as pessoas de confiança (até [limite]) no armazenamento seguro do
/// aparelho (Keystore no Android, Keychain no iOS). Nada vai para o servidor.
///
/// Uso no front:
/// ```dart
/// final repo = TrustedContactRepository.instance;
/// final contato = TrustedContact.fromInput(name: nome, phone: telefone);
/// if (contato == null) { /* mostrar erro de validação */ }
/// final resultado = await repo.adicionar(contato!); // ResultadoAdicao
/// final todos = await repo.carregarTodos(); // [] se não houver
/// await repo.remover(contato.phone);
/// ```
class TrustedContactRepository {
  TrustedContactRepository({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static final instance = TrustedContactRepository();

  /// Rede pequena, fácil de revisar antes de avisar alguém.
  static const limite = 5;

  static const _chave = 'trusted_contacts_v2';

  final FlutterSecureStorage _storage;

  Future<List<TrustedContact>> carregarTodos() async {
    try {
      final texto = await _storage.read(key: _chave);
      if (texto == null) return [];
      return (jsonDecode(texto) as List)
          .map((item) => TrustedContact.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      debugPrint('Não foi possível ler as pessoas de confiança: $e');
      return [];
    }
  }

  Future<ResultadoAdicao> adicionar(TrustedContact contato) async {
    final contatos = await carregarTodos();
    if (contatos.any((c) => c.phone == contato.phone)) return ResultadoAdicao.duplicado;
    if (contatos.length >= limite) return ResultadoAdicao.limiteAtingido;
    await _salvarTodos([...contatos, contato]);
    return ResultadoAdicao.adicionado;
  }

  /// Remove pelo telefone normalizado (ex.: '5541999998888').
  Future<void> remover(String phone) async {
    final contatos = await carregarTodos();
    await _salvarTodos(contatos.where((c) => c.phone != phone).toList());
  }

  Future<void> _salvarTodos(List<TrustedContact> contatos) => _storage.write(
        key: _chave,
        value: jsonEncode(contatos.map((c) => c.toJson()).toList()),
      );
}
