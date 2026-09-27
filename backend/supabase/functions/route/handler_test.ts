// Testes da função de rotas. Rodam em Node ou Deno, sem rede:
//   npx tsx --test backend/supabase/functions/route/handler_test.ts
//   deno test backend/supabase/functions/route/handler_test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { converterRespostaOrs, distanciaKm, handleRequest, Limitador } from "./handler.ts";

const CASA_MULHER = { lat: -25.40468353, lng: -49.25013167 };
const CENTRO = { lat: -25.4284, lng: -49.2733 };

const orsExemplo = {
  type: "FeatureCollection",
  features: [{
    geometry: { coordinates: [[-49.2733, -25.4284], [-49.26, -25.415], [-49.25013167, -25.40468353]] },
    properties: {
      summary: { distance: 3456.7, duration: 2489.2 },
      segments: [{
        steps: [
          { instruction: "Siga para o norte na Rua XV de Novembro", distance: 120.4, duration: 86.1, name: "Rua XV de Novembro" },
          { instruction: "Vire à direita", distance: 3336.3, duration: 2403.1, name: "-" },
          { instruction: "Chegou ao destino", distance: 0, duration: 0, name: "" },
        ],
      }],
    },
  }],
};

function req(body: unknown, headers: Record<string, string> = {}) {
  return new Request("http://localhost/route", {
    method: "POST",
    headers: { "Content-Type": "application/json", ...headers },
    body: JSON.stringify(body),
  });
}

function fetchFalso(status: number, body: unknown, capturar?: (u: string, i: RequestInit) => void) {
  return (async (url: string, init: RequestInit) => {
    capturar?.(url, init);
    return new Response(JSON.stringify(body), { status });
  }) as unknown as typeof fetch;
}

test("converte GeoJSON do ORS: inverte para [lat, lng] e arredonda", () => {
  const r = converterRespostaOrs("a_pe", orsExemplo);
  assert.equal(r.distancia_m, 3457);
  assert.equal(r.duracao_s, 2489);
  assert.deepEqual(r.geometria[0], [-25.4284, -49.2733]);
  assert.equal(r.passos.length, 3);
  assert.equal(r.passos[0].via, "Rua XV de Novembro");
  assert.equal(r.passos[1].via, null, "nome '-' vira null");
});

test("resposta sem geometria gera erro", () => {
  assert.throws(() => converterRespostaOrs("carro", { features: [] }));
});

test("fluxo feliz: chama o perfil certo, com chave no header e idioma pt", async () => {
  let url = "";
  let init: RequestInit = {};
  const resp = await handleRequest(
    req({ de: CENTRO, para: CASA_MULHER, modo: "a_pe" }),
    { apiKey: "chave-teste", fetch: fetchFalso(200, orsExemplo, (u, i) => { url = u; init = i; }) },
  );
  assert.equal(resp.status, 200);
  assert.match(url, /\/v2\/directions\/foot-walking\/geojson$/);
  assert.equal((init.headers as Record<string, string>).Authorization, "chave-teste");
  const enviado = JSON.parse(String(init.body));
  assert.equal(enviado.language, "pt");
  assert.deepEqual(enviado.coordinates[0], [CENTRO.lng, CENTRO.lat]);
  const corpo = await resp.json();
  assert.equal(corpo.modo, "a_pe");
  assert.equal(resp.headers.get("Access-Control-Allow-Origin"), "*");
});

test("modo carro usa driving-car", async () => {
  let url = "";
  await handleRequest(req({ de: CENTRO, para: CASA_MULHER, modo: "carro" }), {
    apiKey: "k", fetch: fetchFalso(200, orsExemplo, (u) => { url = u; }),
  });
  assert.match(url, /driving-car/);
});

test("sem chave configurada responde 503", async () => {
  const r = await handleRequest(req({ de: CENTRO, para: CASA_MULHER, modo: "a_pe" }), {
    apiKey: undefined, fetch: fetchFalso(200, orsExemplo),
  });
  assert.equal(r.status, 503);
});

test("valida entrada: coordenada, modo e distância", async () => {
  const deps = { apiKey: "k", fetch: fetchFalso(200, orsExemplo) };
  assert.equal((await handleRequest(req({ de: { lat: 200, lng: 0 }, para: CASA_MULHER, modo: "a_pe" }), deps)).status, 400);
  assert.equal((await handleRequest(req({ de: CENTRO, para: CASA_MULHER, modo: "aviao" }), deps)).status, 400);
  const saoPaulo = { lat: -23.55, lng: -46.63 };
  const longe = await handleRequest(req({ de: saoPaulo, para: CASA_MULHER, modo: "carro" }), deps);
  assert.equal(longe.status, 400);
  assert.equal((await longe.json()).erro, "distancia_excedida");
});

test("erros do serviço viram mensagens amigáveis", async () => {
  const limite = await handleRequest(req({ de: CENTRO, para: CASA_MULHER, modo: "a_pe" }), {
    apiKey: "k", fetch: fetchFalso(429, {}),
  });
  assert.equal(limite.status, 429);
  const semRota = await handleRequest(req({ de: CENTRO, para: CASA_MULHER, modo: "a_pe" }), {
    apiKey: "k", fetch: fetchFalso(404, {}),
  });
  assert.equal((await semRota.json()).erro, "rota_nao_encontrada");
});

test("limitador bloqueia depois do máximo por minuto", async () => {
  let agora = 0;
  const lim = new Limitador(2, () => agora);
  assert.ok(lim.permitir("a"));
  assert.ok(lim.permitir("a"));
  assert.ok(!lim.permitir("a"));
  assert.ok(lim.permitir("b"), "outra origem não é afetada");
  agora = 61_000;
  assert.ok(lim.permitir("a"), "libera depois de 1 minuto");

  const r = await handleRequest(
    req({ de: CENTRO, para: CASA_MULHER, modo: "a_pe" }, { "x-forwarded-for": "1.2.3.4" }),
    { apiKey: "k", fetch: fetchFalso(200, orsExemplo), limitador: new Limitador(0) },
  );
  assert.equal(r.status, 429);
});

test("OPTIONS responde CORS (Flutter web)", async () => {
  const r = await handleRequest(new Request("http://x/route", { method: "OPTIONS" }), {
    apiKey: "k", fetch: fetchFalso(200, {}),
  });
  assert.equal(r.status, 200);
  assert.ok(r.headers.get("Access-Control-Allow-Headers")?.includes("apikey"));
});

test("distância entre centro e Casa da Mulher ≈ 3,3 km", () => {
  const d = distanciaKm(CENTRO, CASA_MULHER);
  assert.ok(d > 3 && d < 4, String(d));
});
