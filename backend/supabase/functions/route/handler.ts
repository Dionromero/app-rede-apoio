// Lógica da função de rotas, separada do Deno.serve para poder ser testada
// em Node (node --test) sem o runtime do Supabase.
//
// Privacidade: a origem é a posição da usuária. Ela vai só para o
// provedor de rotas (necessário para calcular a rota), sem IP nem identificação,
// e NUNCA é gravada em log ou banco.

export type Modo = "a_pe" | "carro" | "onibus";

export interface Ponto {
  lat: number;
  lng: number;
}

export interface PassoRota {
  instrucao: string;
  distancia_m: number;
  duracao_s: number;
  via: string | null;
  linha_transit?: string | null;
  ponto_embarque?: string | null;
  ponto_desembarque?: string | null;
  num_paradas?: number | null;
  is_transit?: boolean;
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
  googleApiKey?: string | undefined;
  fetch: typeof fetch;
  /** Limite simples por origem, por instância da função. */
  limitador?: Limitador;
}

const PERFIS: Record<"a_pe" | "carro", string> = {
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

/** Decodifica polylines retornadas pelo Google Maps em pares [lat, lng]. */
export function decodificarPolyline(encoded: string): [number, number][] {
  const points: [number, number][] = [];
  let index = 0, len = encoded.length;
  let lat = 0, lng = 0;

  while (index < len) {
    let b, shift = 0, result = 0;
    do {
      b = encoded.charCodeAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    const dlat = (result & 1) !== 0 ? ~(result >> 1) : result >> 1;
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = encoded.charCodeAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    const dlng = (result & 1) !== 0 ? ~(result >> 1) : result >> 1;
    lng += dlng;

    points.push([
      Math.round((lat / 1e5) * 1e6) / 1e6,
      Math.round((lng / 1e5) * 1e6) / 1e6,
    ]);
  }
  return points;
}

function removerHtml(html: string): string {
  return html.replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim();
}

/** Converte a resposta GeoJSON do OpenRouteService no formato do app. */
export function converterRespostaOrs(modo: "a_pe" | "carro", ors: unknown): RespostaRota {
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

/** Converte a resposta da Google Directions API (mode=transit) no formato do app. */
export function converterRespostaGoogleTransit(dados: any): RespostaRota {
  const routes = dados.routes ?? [];
  if (!Array.isArray(routes) || routes.length === 0) {
    throw new Error("resposta_sem_geometria");
  }

  const primeiraRota = routes[0];
  const overviewPolyline = primeiraRota.overview_polyline?.points ?? "";
  const geometria = decodificarPolyline(overviewPolyline);

  const perna = primeiraRota.legs?.[0] ?? {};
  const distancia_m = Math.round(Number(perna.distance?.value ?? 0));
  const duracao_s = Math.round(Number(perna.duration?.value ?? 0));

  const rawSteps = perna.steps ?? [];
  const passos: PassoRota[] = [];

  for (const s of rawSteps) {
    const modoStep = s.travel_mode;
    const instrucaoLimpa = removerHtml(s.html_instructions ?? "");
    const stepDistM = Math.round(Number(s.distance?.value ?? 0));
    const stepDurS = Math.round(Number(s.duration?.value ?? 0));

    if (modoStep === "TRANSIT") {
      const transit = s.transit_details;
      const line = transit?.line;
      const shortName = line?.short_name;
      const lineName = line?.name;
      const linhaCompleta = shortName && lineName
        ? `${shortName} (${lineName})`
        : (shortName || lineName || "Ônibus");

      const depStop = transit?.departure_stop?.name;
      const arrStop = transit?.arrival_stop?.name;
      const numStops = transit?.num_stops;

      passos.push({
        instrucao: `Pegue o ônibus ${linhaCompleta}${depStop ? ` em ${depStop}` : ""}`,
        distancia_m: stepDistM,
        duracao_s: stepDurS,
        via: linhaCompleta,
        linha_transit: linhaCompleta,
        ponto_embarque: depStop ?? null,
        ponto_desembarque: arrStop ?? null,
        num_paradas: numStops ? Math.round(Number(numStops)) : null,
        is_transit: true,
      });
    } else {
      passos.push({
        instrucao: instrucaoLimpa || "Caminhe até o destino",
        distancia_m: stepDistM,
        duracao_s: stepDurS,
        via: null,
        is_transit: false,
      });
    }
  }

  return {
    modo: "onibus",
    distancia_m,
    duracao_s,
    geometria,
    passos,
    atribuicao: "Dados do transporte público: Google Directions · URBS Curitiba",
  };
}

/** Limite de requisições por origem numa janela de 1 minuto (memória da instância). */
export class Limitador {
  private registros = new Map<string, number[]>();
  private maxPorMinuto: number;
  private agora: () => number;

  constructor(maxPorMinuto = 20, agora: () => number = Date.now) {
    this.maxPorMinuto = maxPorMinuto;
    this.agora = agora;
  }

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
  if (modo !== "a_pe" && modo !== "carro" && modo !== "onibus") {
    return erro(400, "modo_invalido", "Use modo 'a_pe', 'carro' ou 'onibus'.");
  }
  if (distanciaKm(de, para) > DISTANCIA_MAXIMA_KM) {
    return erro(400, "distancia_excedida", `A rota no app vale para até ${DISTANCIA_MAXIMA_KM} km.`);
  }

  // 1. Transporte Público (Ônibus) via Google Directions API
  if (modo === "onibus") {
    if (!deps.googleApiKey) {
      return erro(503, "rotas_indisponiveis", "O cálculo de rotas de ônibus ainda não foi configurado no servidor.");
    }

    let respostaGoogle: Response;
    try {
      const url = `https://maps.googleapis.com/maps/api/directions/json?origin=${de.lat},${de.lng}&destination=${para.lat},${para.lng}&mode=transit&language=pt-BR&key=${deps.googleApiKey}`;
      respostaGoogle = await deps.fetch(url);
    } catch {
      return erro(502, "servico_indisponivel", "Não foi possível falar com o serviço de rotas de ônibus.");
    }

    if (!respostaGoogle.ok) {
      return erro(502, "erro_no_servico", "O serviço de rotas de ônibus respondeu com erro.");
    }

    const dados = await respostaGoogle.json();
    if (dados.status === "ZERO_RESULTS") {
      return erro(404, "rota_nao_encontrada", "Nenhuma linha de transporte público direta encontrada.");
    }
    if (dados.status !== "OK") {
      return erro(502, "erro_no_servico", "Não foi possível calcular a rota de ônibus.");
    }

    try {
      return json(200, converterRespostaGoogleTransit(dados));
    } catch {
      return erro(502, "resposta_invalida", "Resposta inesperada do serviço de ônibus.");
    }
  }

  // 2. A pé e Carro via OpenRouteService
  if (!deps.apiKey) {
    return erro(503, "rotas_indisponiveis", "O cálculo de rotas ainda não foi configurado.");
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
