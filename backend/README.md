# Backend — Rede de Apoio

O backend é **100% Supabase**: banco PostgreSQL + PostGIS, API REST gerada pelo PostgREST e funções RPC em SQL. Não há servidor próprio para hospedar.

O front (app Flutter e página de acompanhamento) **só consome a API** descrita em [API para o front](../README.md#api-para-o-front). Ele nunca acessa tabelas sensíveis diretamente.

## Estrutura

```text
backend/
├── supabase/
│   ├── config.toml            # Configuração do Supabase CLI
│   ├── migrations/            # TODA mudança de banco é uma migration nova (nunca editar as antigas)
│   │   ├── 20260920120000_schema_inicial.sql
│   │   ├── 20260920120100_guias_iniciais.sql
│   │   ├── 20260924120000_busca_curadoria.sql
│   │   ├── 20260924120100_base_curitiba.sql
│   │   ├── 20260925120000_canais_categorias_conteudo.sql
│   │   ├── 20260925120100_compartilhamento_localizacao.sql
│   │   └── 20260926120000_rede_curitiba_ippuc.sql
│   ├── functions/
│   │   └── route/             # Edge Function: rota no app via OpenRouteService
│   ├── tests/
│   │   └── api_test.sql       # Testes do contrato da API (roda em transação e desfaz)
│   └── README.md              # Como aplicar, testar e fazer curadoria
└── legacy-node/               # API Node/Express antiga (ARQUIVADA, não usar)
```

## O que cada parte da API faz

| Funcionalidade | API | Migration |
| --- | --- | --- |
| Rede de apoio próxima | RPC `search_institutions` | `busca_curadoria`, `base_curitiba` |
| Botão de emergência (telefones) | RPC `get_emergency_channels` | `canais_categorias_conteudo` |
| Direitos e orientações | tabela `guides` / RPC `get_app_bootstrap` | `guias_iniciais`, `canais_categorias_conteudo` |
| Pacote offline do app | RPC `get_app_bootstrap` | `canais_categorias_conteudo` |
| Rota até a instituição dentro do app | Edge Function `route` | `functions/route` |
| Avisar a pessoa de confiança com localização ao vivo | RPCs `location_share_*` | `compartilhamento_localizacao` |

A pessoa de confiança **não fica no servidor**: nome e telefone são salvos só no celular, criptografados.

## Aplicar e testar

Veja [supabase/README.md](supabase/README.md).

## Por que não há mais Node

A API Node/Express (em `legacy-node/`) nunca foi usada pelo app, exigia hospedar Node + Redis e tinha uma falha de segurança no compartilhamento de localização (o mesmo token servia para enviar e para ver). A decisão de 25/09/2026 foi manter só o Supabase. A pasta fica como referência e pode ser apagada.
