/// Camada de dados do Sussurro — tudo o que o front precisa importar.
///
/// ```dart
/// import 'package:rede_apoio/api.dart';
/// ```
///
/// Contrato e regras: README.md, seção "API para o front".
library;

// Configuração
export 'core/config/app_config.dart';
export 'core/config/supabase_config.dart';

// Conteúdo: canais de emergência, categorias e guias de direitos (com cache offline)
export 'core/content/app_content.dart';
export 'core/content/app_content_repository.dart';

// Ações do aparelho: discador, WhatsApp/SMS, GPS
export 'core/services/contact_messenger.dart';
export 'core/services/emergency_service.dart';
export 'core/services/location_service.dart';
export 'core/services/share_location_service.dart';

// Rede de apoio (instituições próximas, busca e rotas)
export 'features/support_network/data/support_network_service.dart';
export 'features/support_network/domain/models/support_institution.dart';
export 'features/support_network/data/route_service.dart';
export 'features/support_network/domain/models/route_plan.dart';
export 'features/support_network/data/street_view_service.dart';

// Pessoa de confiança (salva só no aparelho)
export 'features/trusted_contact/data/trusted_contact_repository.dart';
export 'features/trusted_contact/domain/trusted_contact.dart';

// Localização ao vivo para a pessoa de confiança
export 'features/location_share/data/location_share_controller.dart';
export 'features/location_share/data/location_share_repository.dart';
export 'features/location_share/domain/location_share_session.dart';
