# App Rede de Apoio (Flutter)

Aplicativo mobile em Flutter/Dart. Visão geral do projeto e fluxograma: [README principal](../README.md).

## Estado atual

- Android validado em emulador; também roda no Chrome (`flutter run -d chrome`) para testes rápidos.
- iOS ainda não gerado (requer macOS e Xcode).
- 90 testes passando (`flutter test`).

## Como está organizado

```text
lib/
├── api.dart          # Camada de dados: o ÚNICO import que as telas precisam
├── main.dart         # Inicializa o Supabase e abre o app
├── app/              # MaterialApp e rotas
├── core/
│   ├── config/       # AppConfig (variáveis de build) e SupabaseConfig
│   ├── content/      # Canais de emergência, categorias e guias (bootstrap + cache offline)
│   ├── services/     # GPS, discador, WhatsApp/SMS
│   ├── theme/        # Cores e tema
│   ├── utils/        # Normalização de texto (busca sem acento)
│   └── widgets/      # Mapa (SupportNetworkMap), Markdown simples, cards
└── features/         # Cada funcionalidade: data/ domain/ presentation/
    ├── home/             # Tela inicial com mapa
    ├── onboarding/       # Primeiro uso
    ├── support_network/  # Rede de apoio: lista, mapa em tela cheia, detalhes
    ├── guidance/         # Direitos e orientações
    ├── trusted_contact/  # Pessoa de confiança (salva só no aparelho)
    └── location_share/   # Localização ao vivo (dados prontos; tela a fazer)
assets/offline/       # Conteúdo embutido para o primeiro uso sem internet
test/                 # Testes de modelos, busca offline, camada de dados e telas
```

Contrato de cada classe da camada de dados: [API para o front](../README.md#api-para-o-front).

## Comandos

```powershell
flutter pub get
flutter analyze
flutter test
flutter run                 # escolhe o aparelho conectado
flutter run -d chrome       # navegador
flutter build apk --debug
```

Variáveis de build (`--dart-define`):
- `GOOGLE_MAPS_API_KEY` (opcional: carrega foto da fachada via Google Street View Static API na ficha da instituição; se omitido, abre panorama 360° gratuito no Google Maps)
- `TRACKING_PAGE_URL` (liga a localização ao vivo)
- `MAP_TILE_URL` (servidor de mapas)

Detalhes no README principal.

## Pacotes e por que estão aqui

| Pacote | Uso | Observação |
| --- | --- | --- |
| `supabase_flutter` | Acesso ao backend | Só com a chave pública `anon`, protegida por RLS |
| `flutter_map` + `latlong2` | Mapa OpenStreetMap | Sem chave de API; exige atribuição "OpenStreetMap contributors" |
| `geolocator`, `permission_handler` | Localização | Permissão pedida só quando a usuária toca em "usar minha localização" |
| `url_launcher` | Discador, WhatsApp, SMS, mapas | O envio final é sempre confirmado pela usuária |
| `flutter_secure_storage` | Pessoas de confiança criptografadas | Keystore/Keychain; nada vai ao servidor |
| `flutter_native_contact_picker` | "Escolher da agenda" na tela de pessoas de confiança | Seletor do sistema: sem permissão de contatos e sem rede; o app recebe só o número escolhido. BSD-3. Pacote pequeno (v0.0.12, autor não verificado); código revisado em 26/09/2026 |
| `shared_preferences` | Cache do conteúdo (canais e guias) | Só conteúdo público |
| `flutter_animate` | Animações de entrada, pinos e painéis | Equivalente ao Framer Motion no Flutter |

## Sistema visual

- Cores em `core/theme/app_colors.dart` (vinho, azul-petróleo, musgo, areia). Os nomes antigos (`pink`, `primary`...) apontam para os novos tons.
- Títulos: `AppFonts.serif(size: ...)` (Fraunces). Texto: Atkinson Hyperlegible, padrão do tema.
- Toque com resposta física: envolva em `Pressable` em vez de `InkWell`.
- Durações e curvas: `AppShape.rapido`, `medio`, `lento` e `AppShape.curva`.
- Abas de categoria: `CategoryTabs`.

## Cuidados conhecidos

- **Botões dentro de `Row`:** o tema dá largura infinita aos botões (`minimumSize: Size.fromHeight(...)`). Dentro de uma `Row`, defina `minimumSize` no `styleFrom` (ex.: `Size(0, 40)`) ou envolva em `Expanded`; senão a tela fica branca com `BoxConstraints forces an infinite width`.
- **`latlong2` exporta uma classe `Path`** que conflita com a do `dart:ui`: importe com `hide Path` (ou `show LatLng`).
- **Discador:** não use `canLaunchUrl` para `tel:`; no Android 11+ ele pode responder `false`. Use `EmergencyService.discar()` e mostre o número se falhar.
