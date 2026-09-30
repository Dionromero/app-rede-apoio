import { SUPABASE_ANON_KEY, SUPABASE_URL } from "../config";

export type Status = "ativo" | "aguardando" | "encerrado" | "expirado" | "inexistente";

export interface Posicao {
  status: Status;
  label: string | null;
  latitude: number | null;
  longitude: number | null;
  accuracy_m: number | null;
  updated_at: string | null;
  expires_at: string | null;
}

/** Token que vem no link, depois do "#t=". Fica fora da URL enviada ao servidor. */
export function tokenDoLink(): string | null {
  const m = window.location.hash.match(/[#&]t=([A-Za-z0-9_-]{16,})/);
  return m ? m[1] : null;
}

/** RPC location_share_view (ver backend/supabase/migrations/…_compartilhamento_localizacao.sql). */
export async function buscarPosicao(token: string, sinal?: AbortSignal): Promise<Posicao> {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/location_share_view`, {
    method: "POST",
    headers: {
      apikey: SUPABASE_ANON_KEY,
      Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ viewer_token: token }),
    signal: sinal,
    referrerPolicy: "no-referrer",
  });
  if (!r.ok) throw new Error(`HTTP ${r.status}`);
  const linhas = (await r.json()) as Posicao[];
  if (!linhas.length) throw new Error("resposta vazia");
  return linhas[0];
}
