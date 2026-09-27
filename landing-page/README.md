# Landing page

Esta pasta receberá a landing page em **React com TypeScript (TSX)**. Ela será a porta pública do projeto e direcionará para o download do aplicativo quando existir uma versão distribuível.

## Objetivo

Explicar a proposta com linguagem clara, apresentar limites de segurança e orientar para canais oficiais em caso de risco imediato.

## Conteúdo planejado

- Explicação breve da Rede de Apoio e do projeto extensionista.
- Link ou QR Code de download do aplicativo.
- Destaque para 190 e 180, com aviso de que são canais oficiais.
- Como funcionam contatos de confiança e rede de apoio.
- Política de privacidade, limitações e contato do projeto.

## Página /acompanhar

Página em que a pessoa de confiança acompanha a localização ao vivo, sem instalar o app. Recebe o token no fragmento da URL (`/acompanhar#t=<viewer_token>`) e consulta a RPC `location_share_view` a cada 15 s. Contrato, estados e exemplo em [API para o front](../README.md#api-para-o-front). Depois de publicada, o endereço vai para o app em `--dart-define=TRACKING_PAGE_URL=...`.

## Limites

Não coletar relatos, localização, documentos, provas ou dados sensíveis na landing page. Ela não substitui atendimento de emergência.

## Próximo passo

Inicializar o projeto React com TypeScript, definir identidade visual acessível e construir uma página responsiva antes de qualquer formulário de contato.
