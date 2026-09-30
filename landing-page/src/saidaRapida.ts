/**
 * Saída rápida: troca a página por uma pesquisa comum, sem deixar esta
 * página no botão "voltar" (location.replace). Mesma ideia do botão
 * "Sair" do app.
 */
export function sairRapido() {
  window.location.replace("https://www.google.com/search?q=previs%C3%A3o+do+tempo+curitiba");
}

/** Três toques em Esc também saem (atalho comum em sites de apoio). */
export function instalarAtalhoEsc() {
  let toques: number[] = [];
  const aoTeclar = (e: KeyboardEvent) => {
    if (e.key !== "Escape") return;
    const agora = Date.now();
    toques = [...toques.filter((t) => agora - t < 1500), agora];
    if (toques.length >= 3) sairRapido();
  };
  window.addEventListener("keydown", aoTeclar);
  return () => window.removeEventListener("keydown", aoTeclar);
}
