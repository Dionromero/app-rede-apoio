import { Cabecalho } from "./sections/Cabecalho";
import { Hero } from "./sections/Hero";
import { Emergencia } from "./sections/Emergencia";
import { ComoFunciona } from "./sections/ComoFunciona";
import { Privacidade } from "./sections/Privacidade";
import { Sobre } from "./sections/Sobre";
import { Rodape } from "./sections/Rodape";

export default function App() {
  return (
    <>
      <a className="pular" href="#conteudo">
        Pular para o conteúdo
      </a>
      <Cabecalho />
      <main id="conteudo">
        <Hero />
        <Emergencia />
        <ComoFunciona />
        <Privacidade />
        <Sobre />
      </main>
      <Rodape />
    </>
  );
}
