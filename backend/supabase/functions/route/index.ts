// Supabase Edge Function: rota entre a usuária e uma instituição.
//
// Deploy:
//   supabase secrets set ORS_API_KEY=<sua chave do openrouteservice.org>
//   supabase secrets set GOOGLE_MAPS_API_KEY=<sua chave do Google Cloud>
//   supabase functions deploy route
//
// Chamada (o app usa supabase.functions.invoke('route', body: {...})):
//   POST /functions/v1/route
//   { "de": {"lat": -25.43, "lng": -49.27}, "para": {"lat": -25.40, "lng": -49.25}, "modo": "onibus" }
//
// Contrato completo: docs/API.md.

import { handleRequest, Limitador } from "./handler.ts";

const limitador = new Limitador(20);

Deno.serve((req: Request) =>
  handleRequest(req, {
    apiKey: Deno.env.get("ORS_API_KEY"),
    googleApiKey: Deno.env.get("GOOGLE_MAPS_API_KEY"),
    fetch,
    limitador,
  })
);
