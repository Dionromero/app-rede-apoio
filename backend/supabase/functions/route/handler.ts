// Lógica da função de rotas, separada do Deno.serve para poder ser testada
// em Node (node --test) sem o runtime do Supabase.
//
// Privacidade: a origem é a posição da usuária. Ela vai só para o
// OpenRouteService (necessário para calcular a rota), sem IP nem identificação,
// e NUNCA é gravada em log ou banco.

export type Modo = "a_pe" | "carro";

export interface Ponto {
  lat: number;
  lng: number;
}

export interface PassoRota {
  instrucao: string;
  distancia_m: number;
  duracao_s: number;
  via: string | null;
}

export interface RespostaRota {
  modo: Modo;
  distancia_m: number;
  duracao_s: number;
  /** Pontos da linha da rota, em [lat, lng]. */
  geometria: [number, number][];
  passos: PassoRota[];
  atribuicao: string;
}

export interface Dependencias {
  apiKey: string | undefined;
  fetch: typeof fetch;
  /** Limite simples por origem, por instância da função. */
  limitador?: Limitador;
}

const PERFIS: Record<Modo, string> = {
  a_pe: "foot-walking",
  carro: "driving-car",
};

/** Distância máxima entre origem e destino (km). A rede é municipal. */
export const DISTANCIA_MAXIMA_KM = 80;

export const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json; charset=utf-8" },
  });
}

function erro(status: number, codigo: string, mensagem: string): Response {
  return json(status, { erro: codigo, mensagem });
}

function pontoValido(p: unknown): p is Ponto {
  if (typeof p !== "object" || p === null) return false;
  const { lat, lng } = p as Record<string, unknown>;
  return typeof lat === "number" && typeof lng === "number" &&
    Number.isFinite(lat) && Number.isFinite(lng) &&
    lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
}

export function distanciaKm(a: Ponto, b: Ponto): number {
  const R = 6371;
  const rad = (g: number) => (g * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 +
    Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}

/** Converte a resposta GeoJSON do OpenRouteService no formato do app. */
export function converterRespostaOrs(modo: Modo, ors: unknown): RespostaRota {
  const feature = (ors as { features?: unknown[] })?.features?.[0] as
    | { geometry?: { coordinates?: number[][] }; properties?: Record<string, unknown> }
    | undefined;
  const coords = feature?.geometry?.coordinates;
  const props = feature?.properties ?? {};
  const resumo = (props.summary ?? {}) as { distance?: number; duration?: number };
  if (!Array.isArray(coords) || coords.length < 2) {
    throw new Error("resposta_sem_geometria");
  }

  const segmentos = (props.segments ?? []) as { steps?: Record<string, unknown>[] }[];
  const passos: PassoRota[] = segmentos.flatMap((s) => s.steps ?? []).map((p) => ({
    instrucao: String(p.instruction ?? ""),
    distancia_m: Math.round(Number(p.distance ?? 0)),
    duracao_s: Math.round(Number(p.duration ?? 0)),
    via: typeof p.name === "string" && p.name !== "-" && p.name.trim() !== "" ? p.name : null,
  })).filter((p) => p.instrucao.length > 0);

  return {
    modo,
    distancia_m: Math.round(Number(resumo.distance ?? 0)),
    duracao_s: Math.round(Number(resumo.duration ?? 0)),
    // ORS devolve [lng, lat]; o app usa [lat, lng]. 6 casas ≈ 10 cm.
    geometria: coords.map((c) => [
      Math.round(c[1] * 1e6) / 1e6,
      Math.round(c[0] * 1e6) / 1e6,
    ]),
    passos,
    atribuicao: "© openrouteservice.org · © OpenStreetMap contributors",
  };
}

/** Limite de requisições por origem numa janela de 1 minuto (memória da instância). */
export class Limitador {
  private registros = new Map<string, number[]>();
  constructor(private maxPorMinuto = 20, private agora: () => number = Date.now) {}

  permitir(chave: string): boolean {
    const t = this.agora();
    const recentes = (this.registros.get(chave) ?? []).filter((x) => t - x < 60_000);
    if (recentes.length >= this.maxPorMinuto) {
      this.registros.set(chave, recentes);
      return false;
    }
    recentes.push(t);
    this.registros.set(chave, recentes);
    if (this.registros.size > 5000) this.registros.clear(); // evita crescer sem limite
    return true;
  }
}

export async function handleRequest(req: Request, deps: Dependencias): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return erro(405, "metodo_invalido", "Use POST.");

  if (!deps.apiKey) {
    return erro(503, "rotas_indisponiveis", "O cálculo de rotas ainda não foi configurado.");
  }

  const origem = (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim() || "desconhecida";
  if (deps.limitador && !deps.limitador.permitir(origem)) {
    return erro(429, "muitas_requisicoes", "Muitas rotas em pouco tempo. Tente de novo em um minuto.");
  }

  let corpo: Record<string, unknown>;
  try {
    corpo = await req.json();
  } catch {
    return erro(400, "json_invalido", "Corpo da requisição inválido.");
  }

  const { de, para } = corpo;
  const modo = corpo.modo as Modo;
  if (!pontoValido(de) || !pontoValido(para)) {
    return erro(400, "coordenada_invalida", "Informe 'de' e 'para' com lat e lng válidos.");
  }
  if (!(modo in PERFIS)) {
    return erro(400, "modo_invalido", "Use modo 'a_pe' ou 'carro'.");
  }
  if (distanciaKm(de, para) > DISTANCIA_MAXIMA_KM) {
    return erro(400, "distancia_excedida", `A rota no app vale para até ${DISTANCIA_MAXIMA_KM} km.`);
  }

  let resposta: Response;
  try {
    resposta = await deps.fetch(
      `https://api.openrouteservice.org/v2/directions/${PERFIS[modo]}/geojson`,
      {
        method: "POST",
        headers: {
          Authorization: deps.apiKey,
          "Content-Type": "application/json",
          Accept: "application/geo+json, application/json",
        },
        body: JSON.stringify({
          coordinates: [[de.lng, de.lat], [para.lng, para.lat]],
          language: "pt",
          instructions: true,
          units: "m",
        }),
      },
    );
  } catch {
    return erro(502, "servico_indisponivel", "Não foi possível falar com o serviço de rotas.");
  }

  if (resposta.status === 429 || resposta.status === 403) {
    return erro(429, "limite_do_servico", "O limite diário de rotas foi atingido. Use 'Abrir no GPS'.");
  }
  if (resposta.status === 404) {
    return erro(404, "rota_nao_encontrada", "Não encontramos um caminho até este local.");
  }
  if (!resposta.ok) {
    return erro(502, "erro_no_servico", "O serviço de rotas respondeu com erro.");
  }

  try {
    return json(200, converterRespostaOrs(modo, await resposta.json()));
  } catch {
    return erro(502, "resposta_invalida", "O serviço de rotas devolveu uma resposta inesperada.");
  }
}
