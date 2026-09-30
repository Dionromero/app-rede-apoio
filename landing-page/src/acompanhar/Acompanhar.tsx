import { useEffect, useState } from "react";
import { Clock, ExternalLink, MapPinOff, Phone, RefreshCw, ShieldAlert } from "lucide-react";
import { buscarPosicao, tokenDoLink, type Posicao } from "./api";
import { Mapa } from "./Mapa";

const INTERVALO_MS = 15_000;

function tempoDesde(iso: string | null, agora: number): string {
  if (!iso) return "";
  const s = Math.max(0, Math.round((agora - new Date(iso).getTime()) / 1000));
  if (s < 60) return `há ${s} s`;
  const m = Math.round(s / 60);
  return m < 60 ? `há ${m} min` : `há ${Math.round(m / 60)} h`;
}

function tempoAte(iso: string | null, agora: number): string {
  if (!iso) return "";
  const m = Math.max(0, Math.round((new Date(iso).getTime() - agora) / 60000));
  return m <= 1 ? "menos de 1 min" : `${m} min`;
}

function hora(iso: string | null): string {
  return iso ? new Date(iso).toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" }) : "";
}

export function Acompanhar() {
  const [token] = useState(tokenDoLink);
  const [dados, setDados] = useState<Posicao | null>(null);
  const [falhou, setFalhou] = useState(false);
  const [agora, setAgora] = useState(Date.now());

  // Busca a posição a cada 15 s enquanto o compartilhamento estiver ativo.
  useEffect(() => {
    if (!token) return;
    let parar = false;
    let timer: number | undefined;
    const controle = new AbortController();

    const ciclo = async () => {
      try {
        const p = await buscarPosicao(token, controle.signal);
        if (parar) return;
        setDados(p);
        setFalhou(false);
        if (p.status === "ativo" || p.status === "aguardando") timer = window.setTimeout(ciclo, INTERVALO_MS);
      } catch {
        if (parar) return;
        setFalhou(true);
        timer = window.setTimeout(ciclo, INTERVALO_MS);
      }
    };
    ciclo();
    return () => {
      parar = true;
      controle.abort();
      window.clearTimeout(timer);
    };
  }, [token]);

  // Relógio para "atualizado há X s".
  useEffect(() => {
    const t = window.setInterval(() => setAgora(Date.now()), 5000);
    return () => window.clearInterval(t);
  }, []);

  const nome = dados?.label?.trim() || "Sua pessoa de confiança";
  const temPosicao = dados?.status === "ativo" && dados.latitude != null && dados.longitude != null;
  const desatualizado =
    temPosicao && dados.updated_at != null && agora - new Date(dados.updated_at).getTime() > 2 * 60_000;

  return (
    <div className="acomp">
      <header className="acomp__topo">
        <img src="/img/simbolo-mono.svg" alt="" width={32} height={32} />
        <span>Sussurro</span>
      </header>

      <main className="acomp__corpo">
        {!token && (
          <Aviso
            icone={<MapPinOff size={22} />}
            titulo="Link incompleto"
            texto="Abra o link exatamente como você recebeu, sem cortar o final."
          />
        )}

        {token && !dados && !falhou && <p className="acomp__carregando">Carregando localização…</p>}

        {token && !dados && falhou && (
          <Aviso
            icone={<RefreshCw size={22} />}
            titulo="Sem conexão"
            texto="Não conseguimos buscar a localização. Tentando de novo a cada 15 segundos."
          />
        )}

        {dados?.status === "inexistente" && (
          <Aviso
            icone={<MapPinOff size={22} />}
            titulo="Compartilhamento não encontrado"
            texto="O link pode estar errado ou o compartilhamento já foi apagado."
          />
        )}

        {(dados?.status === "encerrado" || dados?.status === "expirado") && (
          <Aviso
            icone={<Clock size={22} />}
            titulo={dados.status === "encerrado" ? "Compartilhamento encerrado" : "O tempo do compartilhamento acabou"}
            texto={`${nome} parou de compartilhar às ${hora(dados.updated_at)}. A localização foi apagada do servidor.`}
          />
        )}

        {dados?.status === "aguardando" && (
          <Aviso
            icone={<RefreshCw size={22} />}
            titulo="Aguardando a primeira localização"
            texto={`${nome} começou a compartilhar. O ponto aparece aqui assim que o celular dela enviar a posição.`}
          />
        )}

        {temPosicao && (
          <>
            <section className="acomp__cabeca">
              <p className="rotulo">Localização ao vivo</p>
              <h1 className="acomp__titulo">{nome} está compartilhando a localização com você.</h1>
              <p className={`acomp__meta${desatualizado ? " acomp__meta--alerta" : ""}`}>
                {desatualizado ? "Sem atualização " : "Atualizado "}
                {tempoDesde(dados.updated_at, agora)}
                {dados.accuracy_m ? ` · precisão de ${Math.round(dados.accuracy_m)} m` : ""}
                {" · termina em "}
                {tempoAte(dados.expires_at, agora)}
              </p>
              {desatualizado && (
                <p className="acomp__dica">
                  O celular dela pode estar sem internet, sem bateria ou com o app fechado.
                </p>
              )}
            </section>

            <Mapa latitude={dados.latitude!} longitude={dados.longitude!} precisao={dados.accuracy_m} />

            <div className="acomp__acoes">
              <a
                className="botao botao--secundario"
                href={`https://www.google.com/maps/search/?api=1&query=${dados.latitude},${dados.longitude}`}
                target="_blank"
                rel="noreferrer noopener"
              >
                <ExternalLink size={18} aria-hidden="true" />
                Abrir no Google Maps
              </a>
            </div>
          </>
        )}

        <section className="acomp__ajuda">
          <ShieldAlert size={22} aria-hidden="true" className="acomp__ajuda-icone" />
          <div>
            <strong>Acha que ela está em perigo?</strong>
            <p>
              {temPosicao
                ? "Ligue 190 e informe o endereço que aparece no mapa."
                : "Ligue 190 e informe onde ela pode estar."}{" "}
              Não vá sozinha ao local e não confronte o agressor.
            </p>
            <a className="botao botao--emergencia" href="tel:190">
              <Phone size={18} aria-hidden="true" />
              Ligar 190
            </a>
          </div>
        </section>
      </main>

      <footer className="acomp__rodape">
        Esta página não guarda nada no seu navegador. A localização só fica disponível enquanto ela compartilha.
      </footer>
    </div>
  );
}

function Aviso({ icone, titulo, texto }: { icone: React.ReactNode; titulo: string; texto: string }) {
  return (
    <section className="aviso-estado" role="status">
      <span className="aviso-estado__icone">{icone}</span>
      <h1>{titulo}</h1>
      <p>{texto}</p>
    </section>
  );
}
