# Landing page

Página pública do Rede de Apoio, feita em **React + TypeScript (Vite)**. Usa a mesma
identidade visual do app: cores, fontes (Fraunces e Atkinson Hyperlegible, servidas pelo
próprio site) e a ilustração em `public/img/`.

## Rodar e gerar

```bash
cd landing-page
npm install
npm run dev      # http://localhost:5173
npm run build    # gera dist/ (roda o TypeScript antes)
```

## Publicar na Vercel

1. Em vercel.com, **Add New → Project** e importe o repositório do GitHub.
2. Em **Root Directory**, escolha `landing-page`. A Vercel reconhece o Vite sozinha
   (build `npm run build`, saída `dist`).
3. Deploy. Cada push na branch principal publica de novo.

O `vercel.json` envia cabeçalhos de privacidade (`Referrer-Policy: no-referrer`, entre outros).

## Página /acompanhar (localização ao vivo)

`acompanhar/index.html` + `src/acompanhar/`. A pessoa de confiança abre o link que recebe no
WhatsApp (`/acompanhar/#t=<token>`) e vê o ponto no mapa, atualizado a cada 15 s pela RPC
`location_share_view`. O token fica depois do `#`: não vai para o servidor da Vercel nem para logs.

Estados: aguardando a primeira posição, ativo (mapa + "Abrir no Google Maps"), sem atualização
há mais de 2 min, encerrado, expirado e link inválido. Sempre com "Ligar 190".

**Ligar ao app:** depois de publicar, gere o app com o endereço da página:

```bash
flutter build apk --release --dart-define=TRACKING_PAGE_URL=https://SEU-SITE.vercel.app/acompanhar/
```

Sem esse valor, a opção "Ao vivo" não aparece no app (ele não envia um link que não abre).

## Decisões

- **Saída rápida:** botão "Sair rápido" no topo e atalho **Esc três vezes**. Troca a página por uma
  pesquisa comum usando `location.replace`, para ela não ficar no botão "voltar".
- **Sem rastreadores:** nada de analytics, fontes do Google ou scripts de terceiros.
- **`noindex`:** o site não aparece no Google enquanto o app estiver em piloto. Tire a meta
  `robots` do `index.html` quando o app for público.
- **Download:** por enquanto é "Android · em breve". Quando houver versão pública, troque o
  `<span>` desativado em `src/sections/Hero.tsx` por um link.

## Objetivo (planejamento original)

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
