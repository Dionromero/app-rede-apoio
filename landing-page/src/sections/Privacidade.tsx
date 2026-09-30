import { Check } from "lucide-react";

const pontos = [
  ["Sem conta e sem login.", "O app não pede nome, e-mail nem o seu telefone."],
  ["Contatos só no aparelho.", "As pessoas de confiança ficam guardadas com criptografia no próprio celular. Nada vai para o servidor."],
  ["Localização não é guardada.", "Sua posição serve para achar os locais próximos e calcular a rota, e não fica registrada."],
  ["Sem anúncios e sem rastreadores.", "Nem no app, nem neste site."],
];

export function Privacidade() {
  return (
    <section id="privacidade" className="secao secao--papel">
      <div className="container privacidade">
        <div>
          <p className="rotulo">Privacidade</p>
          <h2 className="titulo-l">Feito para não deixar rastro.</h2>
          <p className="secao__lead">
            Quem precisa deste app muitas vezes divide o celular com quem a agride. Por isso ele guarda
            o mínimo possível, e o que guarda fica com você.
          </p>
        </div>
        <ul className="pontos">
          {pontos.map(([titulo, texto]) => (
            <li key={titulo}>
              <span className="pontos__marca">
                <Check size={16} aria-hidden="true" />
              </span>
              <span>
                <strong>{titulo}</strong> {texto}
              </span>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
