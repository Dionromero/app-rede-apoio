import { BookOpen, EyeOff, MapPinned, Users, type LucideIcon } from "lucide-react";

type Recurso = { icone: LucideIcon; titulo: string; texto: string; cor: "vinho" | "tinta" | "musgo" };

const recursos: Recurso[] = [
  {
    icone: MapPinned,
    titulo: "Mapa da rede de proteção",
    texto:
      "Delegacias da mulher, CRAS, CREAS, Defensoria, UPAs e hospitais de Curitiba, com endereço e telefone conferidos em fontes oficiais. Mostra os mais próximos e traça a rota a pé ou de carro.",
    cor: "vinho",
  },
  {
    icone: Users,
    titulo: "Pessoas de confiança",
    texto:
      "Cadastre até cinco contatos. Com um toque, o app abre o WhatsApp com a sua localização pronta para enviar. Os contatos ficam só no seu celular.",
    cor: "tinta",
  },
  {
    icone: BookOpen,
    titulo: "Direitos e orientações",
    texto:
      "Como pedir uma medida protetiva, registrar um boletim de ocorrência e montar um plano de segurança. Textos curtos, em revisão por profissionais da rede.",
    cor: "musgo",
  },
  {
    icone: EyeOff,
    titulo: "Modo discreto",
    texto:
      "Troque o ícone e o nome do app por uma calculadora, um bloco de anotações, um app de treinos ou de receitas. O botão \"Sair\" fecha tudo na hora.",
    cor: "vinho",
  },
];

export function ComoFunciona() {
  return (
    <section id="como-funciona" className="secao">
      <div className="container">
        <p className="rotulo">Como funciona</p>
        <h2 className="titulo-l">Quatro coisas, bem feitas.</h2>
        <p className="secao__lead">
          O app não substitui o atendimento especializado. Ele encurta o caminho até ele.
        </p>
        <ul className="recursos">
          {recursos.map(({ icone: Icone, titulo, texto, cor }) => (
            <li key={titulo} className="recurso">
              <span className={`recurso__icone recurso__icone--${cor}`}>
                <Icone size={22} aria-hidden="true" />
              </span>
              <h3>{titulo}</h3>
              <p>{texto}</p>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
