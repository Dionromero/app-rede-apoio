# Supabase — Rede de Apoio

Piloto atual: **Curitiba/PR**. Contrato da API para o front: [API para o front](../../README.md#api-para-o-front).

## Regras do banco

- **Toda mudança é uma migration nova** em `migrations/`, com nome `AAAAMMDDHHMMSS_descricao.sql`. Nunca edite uma migration que já foi aplicada.
- As migrations são **idempotentes**: rodar de novo não duplica dados nem quebra.
- Tabelas com dados sensíveis (`location_shares`, `institution_review_queue`) têm RLS ativo **sem política pública**. O front só usa as funções RPC.
- Depois de mudar o banco, atualize a seção "API para o front" do README principal e rode `tests/api_test.sql`.

## Aplicar as migrations

### Acesso

Peça a quem administra a organização no Supabase um convite com papel **Developer** (Settings → Team → Invite) e a senha do banco por canal privado. Não use "Reset database password": troca a senha de todo mundo.

### Opção A — Supabase CLI (recomendado)

Rode **sempre de dentro de `backend/`**. A CLI procura a pasta `supabase/` subindo a partir do diretório atual; fora de `backend/`, ela cria uma pasta `supabase/` nova, que não está no `.gitignore`.

Não precisa instalar a CLI: com Node, `npx supabase` baixa e roda. Na primeira vez:

```bash
cd backend
npx supabase login
npx supabase link --project-ref xozcsujnjzoinqhifgfm   # pede a senha do banco
```

A cada migration nova:

```bash
npx supabase migration list          # compara Local x Remote
npx supabase db push --dry-run       # mostra o que seria aplicado, sem aplicar
npx supabase db push                 # aplica só as migrations novas
```

O histórico de produção foi sincronizado em 26/09/2026: as 7 migrations até `20260926120000` estão registradas como aplicadas.

Para um banco local de desenvolvimento: `npx supabase start` e `npx supabase db reset` (precisa do Docker).

### Opção B — SQL Editor do painel (evite)

Colar uma migration no SQL Editor aplica o SQL, mas **não registra** no histórico da CLI. Se usar este caminho, registre logo em seguida, senão o próximo `db push` tenta aplicar a migration de novo:

```bash
npx supabase migration repair --status applied <versão>
```

### Limpeza automática da localização

A migration de localização tenta agendar a limpeza com **pg_cron** a cada 15 min. Se o painel avisar que o pg_cron não está habilitado, ative em **Database → Extensions → pg_cron** e rode a migration de novo. Mesmo sem pg_cron, a limpeza roda a cada nova sessão criada.

## Função de rotas (`functions/route`)

Calcula a rota dentro do app usando o OpenRouteService.

1. Crie uma conta gratuita em [openrouteservice.org](https://openrouteservice.org) e gere uma chave (plano gratuito com limite diário; confira no painel da HeiGIT).
2. Guarde a chave como segredo e publique a função:

```bash
cd backend
supabase secrets set ORS_API_KEY=<sua-chave>
supabase functions deploy route
```

Sem a chave, a função responde 503 e o app oferece "Abrir no GPS do celular". Testes (sem rede): `npx tsx --test supabase/functions/route/handler_test.ts`.

## Testar

Cole `tests/api_test.sql` no SQL Editor e rode. Ele simula o app (papel `anon`), testa todo o contrato e desfaz tudo no final (`ROLLBACK`), então é seguro em produção. Se tudo passar, o resultado é `ok: todos os testes passaram`. Se algo quebrar, aparece um erro `FALHOU: ...`.

Pela CLI, de dentro de `backend/` (não pede senha):

```bash
npx supabase db query --linked -f supabase/tests/api_test.sql
```

Com psql, aparecem também os 4 avisos `ok: ...` de cada grupo de testes (o painel e a CLI não mostram avisos):

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/api_test.sql
```

## Curadoria dos dados (obrigatória em produção)

A base é **curada**: nenhum dado vindo de busca automática é publicado sem revisão humana.

- **Instituições:** cada uma tem `source_name`, `source_url`, `verified_at` e `verified_by`. O app mostra "Verificado em dd/mm/aaaa" ou "Dados a confirmar". Registros sem verificação há mais de 180 dias aparecem na view `institutions_stale`.
- **Fila de revisão:** novas instituições, alterações e reverificações entram em `institution_review_queue` com status `pendente`. Só quem tem a `service_role` (painel/admin) lê e aprova.
- **Coordenadas:** `location_precision = 'aproximada'` indica posição estimada. O app usa o endereço na rota "Como chegar" nesses casos.
- **Canais de emergência:** tabela `emergency_channels`, com fonte e data de verificação.
- **Guias de direitos:** tabela `guides`. `reviewed_at` fica vazio até um profissional da rede de atendimento revisar o texto.
- **Sigilo:** a categoria `casa_abrigo` nunca é retornada. Endereços de abrigos não devem ser cadastrados.

Rotina mensal sugerida:

1. `select * from institutions_stale;` e `select * from institution_review_queue where status = 'pendente';`
2. Conferir cada item na fonte oficial e, se possível, por telefone.
3. Atualizar o registro (`verified_at = now()`, `verified_by = '<nome>'`) e marcar a pendência como `aprovado` ou `rejeitado`.

Para mudar dados em produção, prefira uma migration nova (fica registrado no Git) a editar pelo painel.

## Fontes oficiais usadas no levantamento de Curitiba

**Base principal (25/09/2026):** [IPPUC — GeoCuritiba, Equipamentos Urbanos](https://geocuritiba.ippuc.org.br/server/rest/services/Publico_GeoCuritiba_Equipamentos_Urbanos/MapServer), serviço público de mapas da Prefeitura com endereço, telefone, horário e coordenadas oficiais. Camadas usadas: 34 (CRAS), 38 (CREAS), 105 (Defensoria Pública), 108 (Centro de Referência de Atendimento à Mulher), 129 (Hospitais públicos), 130 (UPAs) e 143 (Polícia Civil). Para atualizar a base, consulte a camada com `/query?where=1%3D1&outFields=*&f=json` e compare com o banco.

**Levantamento inicial (24/09/2026):**

- [Prefeitura — Rede de Atenção às mulheres em situação de violências](https://mulhereigualdade.curitiba.pr.gov.br/conteudo/rede-de-atencao-as-mulheres-em-situacao-de-violencias/12)
- [Prefeitura — Portal Locais: Casa da Mulher Brasileira](https://locais.curitiba.pr.gov.br/centro-de-referencia-de-atendimento-a-mulher-casa-da-mulher-brasileira/2117)
- [TJPR/CEVID — Onde procurar ajuda](https://www.tjpr.jus.br/web/cevid/onde-procurar-ajuda)
- [Polícia Científica do PR — Hospitais de referência em violência sexual](https://www.policiacientifica.pr.gov.br/sites/policia-cientifica/arquivos_restritos/files/documento/2026-04/hospitais_de_referencia-_violencia_sexual-1.pdf)
- [FAS — Endereços dos CRAS](https://fas.curitiba.pr.gov.br/conteudo.aspx?idf=75) (próxima importação)
