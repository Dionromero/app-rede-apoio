import { useEffect } from "react";
import { LogOut } from "lucide-react";
import { instalarAtalhoEsc, sairRapido } from "../saidaRapida";

export function Cabecalho() {
  useEffect(() => instalarAtalhoEsc(), []);

  return (
    <header className="cabecalho">
      <div className="container cabecalho__linha">
        <a className="marca" href="#" aria-label="Sussurro, início">
          <img src="/img/simbolo-mono.svg" alt="" width={36} height={36} className="marca__simbolo" />
          <span className="marca__nome">Sussurro</span>
        </a>
        <nav className="menu" aria-label="Seções">
          <a href="#como-funciona">Como funciona</a>
          <a href="#privacidade">Privacidade</a>
          <a href="#sobre">Sobre</a>
        </nav>
        <button
          type="button"
          className="sair"
          onClick={sairRapido}
          title="Sai desta página na hora. Atalho: Esc três vezes."
        >
          <LogOut size={16} aria-hidden="true" />
          Sair rápido
        </button>
      </div>
    </header>
  );
}
