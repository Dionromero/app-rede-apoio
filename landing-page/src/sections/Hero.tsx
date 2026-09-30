import { Download, MapPin } from "lucide-react";

export function Hero() {
  return (
    <section className="hero">
      <div className="container hero__grade">
        <div className="hero__texto">
          <p className="rotulo">Piloto em Curitiba · gratuito · sem login</p>
          <h1 className="titulo-xl">Uma rede de apoio mais perto de você.</h1>
          <p className="hero__lead">
            O Sussurro é uma rede de apoio às mulheres no bolso. Ele mostra onde buscar atendimento em Curitiba, avisa pessoas de confiança
            com a sua localização e explica seus direitos em linguagem simples. Tudo sem cadastro.
          </p>
          <div className="hero__acoes">
            <span className="botao botao--primario botao--desativado" aria-disabled="true">
              <Download size={18} aria-hidden="true" />
              Android · em breve
            </span>
            <a className="botao botao--secundario" href="#como-funciona">
              <MapPin size={18} aria-hidden="true" />
              Como funciona
            </a>
          </div>
          <p className="hero__nota">
            O app está em fase de testes. Quando a versão pública sair, o download aparece aqui.
          </p>
        </div>
        <figure className="hero__arte">
          <img
            src="/img/ilustracao.svg"
            alt="Ilustração de uma mulher de perfil, de olhos fechados, com o dedo indicador sobre os lábios."
            width={520}
            height={520}
          />
        </figure>
      </div>
    </section>
  );
}
