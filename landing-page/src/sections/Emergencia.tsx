import { Phone } from "lucide-react";

const canais = [
  { numero: "190", nome: "Polícia Militar", detalhe: "Risco imediato, agressão acontecendo agora.", destaque: true },
  { numero: "180", nome: "Central de Atendimento à Mulher", detalhe: "Orientação e denúncia. 24 horas, gratuito e sigiloso." },
  { numero: "153", nome: "Guarda Municipal de Curitiba", detalhe: "Patrulha Maria da Penha: para quem tem medida protetiva descumprida." },
];

export function Emergencia() {
  return (
    <section className="emergencia" aria-labelledby="titulo-emergencia">
      <div className="container">
        <h2 id="titulo-emergencia" className="emergencia__titulo">
          Está em perigo agora? Não espere pelo app.
        </h2>
        <ul className="emergencia__lista">
          {canais.map((c) => (
            <li key={c.numero}>
              <a className={`canal${c.destaque ? " canal--destaque" : ""}`} href={`tel:${c.numero}`}>
                <span className="canal__numero">{c.numero}</span>
                <span className="canal__texto">
                  <strong>{c.nome}</strong>
                  <span>{c.detalhe}</span>
                </span>
                <Phone size={20} aria-hidden="true" className="canal__icone" />
              </a>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
