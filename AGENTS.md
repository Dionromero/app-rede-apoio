# Guia para agentes de desenvolvimento

Este arquivo é o ponto de entrada para qualquer IA ou desenvolvedor que for continuar o projeto.

## Contexto rápido

**Rede de Apoio** é um projeto extensionista brasileiro para facilitar o acesso de mulheres à rede de proteção, a contatos de confiança e a canais oficiais. É uma ferramenta de orientação e conexão; não substitui polícia, Justiça, saúde, assistência social ou atendimento humano especializado.

Leia também:

- [README.md](README.md): visão geral, execução e fluxo de interface.
- [docs/ARQUITETURA.md](docs/ARQUITETURA.md): arquitetura, decisões e funcionalidades.
- [docs/API.md](docs/API.md): contrato da API que o front consome.
- [docs/AMBIENTE-ANDROID.md](docs/AMBIENTE-ANDROID.md): instalação, emulador, validação e diagnóstico do Android.
- [docs/CONTEXTO-PARA-IAS.md](docs/CONTEXTO-PARA-IAS.md): produto, limites e decisões.
- [docs/ESCOPO.md](docs/ESCOPO.md): recorte acadêmico e MVP.
- [docs/PENDENCIAS.md](docs/PENDENCIAS.md): trabalho pendente e prioridades.

## Estado atual (25/09/2026)

- Backend 100% Supabase em `backend/supabase/migrations/` (a API Node em `backend/legacy-node/` está arquivada).
- Camada de dados pronta em `app/lib/api.dart`: rede de apoio, canais de emergência, guias, pessoa de confiança (só no aparelho) e localização ao vivo.
- Telas funcionando: onboarding, início com mapa OpenStreetMap, rede de apoio (lista, mapa em tela cheia, detalhes) e direitos e orientações.
- Parciais: cadastro da pessoa de confiança (não salva ainda) e "Enviar localização" (não usa o contato salvo).
- A fazer: tela de localização ao vivo, página web `/acompanhar`, saída rápida.
- Piloto: Curitiba/PR. Não há integração com polícia, BO ou órgãos públicos.
- Fluxograma atualizado no [README.md](README.md).

## Regras inegociáveis de segurança

1. A ajuda imediata não pode depender de login, cadastro ou internet.
2. Nunca alegar que uma ação automática acionou polícia, emergência ou boletim de ocorrência.
3. Localização só pode ser coletada e compartilhada mediante consentimento explícito, específico e revogável.
4. Não persistir localização contínua, relatos, documentos ou evidências sem arquitetura de segurança, LGPD, retenção mínima e revisão humana.
5. Falhas de rede, permissões e integrações são estados normais da interface e devem ter uma saída segura.
6. Não prometer “invisibilidade total” diante de um agressor; comunicar os limites de segurança com honestidade.
7. Integrações com órgãos públicos dependem de parceria, canal oficial e validação jurídica/técnica. Não simular esse envio.

## Convenções técnicas

- Flutter: organize código em `app/lib/features/`, `app/lib/core/` e `app/lib/app/`. Em cada feature: `data/` (acesso a dados), `domain/` (modelos) e `presentation/` (telas).
- Telas só usam o que está exportado em `app/lib/api.dart`; não chamam o Supabase diretamente.
- Banco: toda mudança é uma migration nova em `backend/supabase/migrations/`; atualize `docs/API.md` e rode `backend/supabase/tests/api_test.sql`.
- Linguagens: Dart no app, TypeScript (`.ts`/`.tsx`) na web e SQL só nas migrations. O app roda em Android e web (Chrome, para testes); não adicione outras plataformas Flutter sem necessidade.
- Landing page e página `/acompanhar`: React com TypeScript (TSX), em `landing-page/`.
- Todo pacote novo exige justificativa de privacidade, manutenção e licença.
- Não versionar APKs, caches, arquivos locais do Android, chaves, tokens ou arquivos `.env`.
- Antes de concluir uma mudança Flutter, rode `flutter analyze` e `flutter test` dentro de `app/`.
- Espaçamentos: use `AppSpacing` (`app/lib/core/theme/app_spacing.dart`), grade de 4 pt com margem lateral de 20 (`AppSpacing.screen`). Não use números soltos em `EdgeInsets`, `SizedBox` ou `spacing`.
- Botões dentro de `Row` precisam de `minimumSize` explícito (o tema usa largura infinita) ou de `Expanded`. Veja "Cuidados conhecidos" em `app/README.md`.
- Ao mudar telas ou fluxos, atualize o fluxograma do `README.md`.
- Atualize `docs/PENDENCIAS.md` quando uma etapa for concluída ou o escopo mudar.

## Próxima entrega recomendada

1. Ligar a tela de cadastro da pessoa de confiança ao `TrustedContactRepository` e usar o contato salvo em "Enviar localização".
2. Tela "Avisar pessoa de confiança" com confirmação, escolha de 15/30/60 min e botão "Parar" (usa `LocationShareController`).
3. Página web `/acompanhar` (contrato em `docs/API.md`).
4. Saída rápida e aviso de limites do app no primeiro uso.
