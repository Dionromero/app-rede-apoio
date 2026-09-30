export function Rodape() {
  return (
    <footer className="rodape">
      <div className="container rodape__linha">
        <p className="rodape__aviso">
          Este app orienta e conecta. Ele não substitui o 190, o 180 nem o atendimento especializado.
        </p>
        <p className="rodape__meta">
          © {new Date().getFullYear()} Sussurro · Projeto de extensão da Gran Faculdade · Curitiba/PR
        </p>
      </div>
    </footer>
  );
}
