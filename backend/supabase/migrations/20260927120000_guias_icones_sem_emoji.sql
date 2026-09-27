-- Identidade visual: guias deixam de usar emoji.
-- `guides.icon` passa a guardar uma chave lógica; o app desenha o ícone
-- (app/lib/core/content/guide_icons.dart). Idempotente.
UPDATE public.guides g
SET icon = v.chave, updated_at = now()
FROM (VALUES
  ('emergencia',            'alerta'),
  ('plano-de-seguranca',    'bussola'),
  ('boletim-de-ocorrencia', 'documento'),
  ('medida-protetiva',      'escudo'),
  ('lei-maria-da-penha',    'balanca'),
  ('apoio-financeiro',      'carteira'),
  ('seguranca-digital',     'celular')
) AS v(slug, chave)
WHERE g.slug = v.slug AND g.icon IS DISTINCT FROM v.chave;

COMMENT ON COLUMN public.guides.icon IS
  'Chave lógica do ícone (alerta, bussola, documento, escudo, balanca, carteira, celular). Nunca emoji.';
