import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/contact_messenger.dart';
import '../../../core/services/location_service.dart';
import '../../trusted_contact/domain/trusted_contact.dart';
import '../domain/location_share_session.dart';
import 'location_share_repository.dart';

/// Orquestra o "Avisar pessoa de confiança" com localização ao vivo.
///
/// A interface só precisa:
/// ```dart
/// final ctrl = LocationShareController();
/// // ouvir: AnimatedBuilder / ListenableBuilder(listenable: ctrl, ...)
/// await ctrl.iniciar(contato: contato, minutos: 30);   // após confirmação da usuária
/// await ctrl.encerrar();                               // botão "Parar de compartilhar"
/// ctrl.status; ctrl.sessao?.remaining; ctrl.mensagemErro;
/// ```
///
/// LIMITAÇÃO ATUAL: a posição é enviada enquanto o app está aberto. Com a tela
/// bloqueada ou o app em segundo plano, o Android pode pausar o envio.
/// Envio em segundo plano exige um serviço em primeiro plano (próxima etapa).
class LocationShareController extends ChangeNotifier {
  LocationShareController({LocationShareRepository? repository})
      : _repo = repository ?? LocationShareRepository.instance;

  /// Instância do app inteiro: o compartilhamento continua enquanto a usuária
  /// navega entre as telas (a Home mostra uma faixa com "Parar").
  static final instancia = LocationShareController();

  final LocationShareRepository _repo;

  LocationShareStatus _status = LocationShareStatus.inativo;
  LocationShareSession? _sessao;
  DateTime? _ultimoEnvio;
  String? _mensagemErro;
  Timer? _timer;
  bool _enviando = false;
  bool _descartado = false;

  LocationShareStatus get status => _status;
  LocationShareSession? get sessao => _sessao;

  /// Com quem o compartilhamento atual foi iniciado.
  TrustedContact? get contato => _contato;
  TrustedContact? _contato;
  DateTime? get ultimoEnvio => _ultimoEnvio;
  String? get mensagemErro => _mensagemErro;
  bool get emAndamento =>
      _status == LocationShareStatus.ativo || _status == LocationShareStatus.instavel;

  /// Cria a sessão, envia a primeira posição e abre o WhatsApp/SMS do contato
  /// com o link. Chame SOMENTE depois de a usuária confirmar na interface.
  ///
  /// Lança [LocationShareException] se não for possível iniciar; nesse caso
  /// ofereça o envio da localização atual (ShareLocationService) como alternativa.
  Future<void> iniciar({
    required TrustedContact contato,
    required int minutos,
    String? rotulo,
  }) async {
    if (emAndamento) return;
    if (!AppConfig.compartilhamentoAoVivoDisponivel) {
      _falhar(const LocationShareException(
        'pagina_nao_configurada',
        'O acompanhamento ao vivo ainda não está disponível. Envie sua localização atual.',
      ));
    }

    _mensagemErro = null;
    _contato = contato;
    _definir(LocationShareStatus.iniciando);

    try {
      _sessao = await _repo.iniciar(durationMin: minutos, label: rotulo);
    } on LocationShareException catch (e) {
      _falhar(e);
    }

    await _enviarPosicao();
    _timer = Timer.periodic(AppConfig.intervaloEnvioLocalizacao, (_) => _enviarPosicao());
    if (_status == LocationShareStatus.iniciando) _definir(LocationShareStatus.ativo);

    await ContactMessenger.abrirWhatsAppOuSms(
      numeroDigitos: contato.whatsappNumber,
      mensagem: ContactMessenger.mensagemAcompanhamento(_sessao!.viewerUrl(), minutos),
    );
  }

  /// Encerra na hora. A posição é apagada do servidor.
  Future<void> encerrar() async {
    _timer?.cancel();
    _timer = null;
    final sessao = _sessao;
    if (sessao != null) {
      try {
        await _repo.encerrar(sessao);
      } catch (e) {
        // Sem internet: a sessão expira sozinha no prazo definido.
        debugPrint('Falha ao encerrar no servidor: $e');
      }
    }
    _definir(LocationShareStatus.encerrado);
  }

  Future<void> _enviarPosicao() async {
    final sessao = _sessao;
    if (sessao == null || _enviando) return;
    if (sessao.isExpired) {
      _timer?.cancel();
      _definir(LocationShareStatus.encerrado);
      return;
    }

    _enviando = true;
    try {
      final pos = await LocationService.obterPosicaoAtual();
      if (pos == null) {
        _definir(LocationShareStatus.instavel);
        return;
      }
      final ativo = await _repo.enviarPosicao(
        sessao: sessao,
        latitude: pos.latitude,
        longitude: pos.longitude,
        precisaoMetros: pos.accuracy,
      );
      if (!ativo) {
        _timer?.cancel();
        _definir(LocationShareStatus.encerrado);
        return;
      }
      _ultimoEnvio = DateTime.now();
      if (_status != LocationShareStatus.iniciando) _definir(LocationShareStatus.ativo);
    } on LocationShareException catch (e) {
      _mensagemErro = e.mensagem;
      _definir(LocationShareStatus.instavel);
    } finally {
      _enviando = false;
    }
  }

  Never _falhar(LocationShareException e) {
    _mensagemErro = e.mensagem;
    _definir(LocationShareStatus.erro);
    throw e;
  }

  void _definir(LocationShareStatus novo) {
    _status = novo;
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    _timer?.cancel();
    final sessao = _sessao;
    if (emAndamento && sessao != null) {
      // Melhor esforço: não deixar a sessão aberta se a tela for descartada.
      unawaited(_repo.encerrar(sessao).catchError((_) {}));
    }
    super.dispose();
  }
}
