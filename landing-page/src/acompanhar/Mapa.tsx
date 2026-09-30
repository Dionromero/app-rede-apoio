import { useEffect, useRef } from "react";
import L from "leaflet";

type Props = { latitude: number; longitude: number; precisao: number | null };

/** Mapa com o ponto da pessoa e o círculo de precisão. Segue o ponto a cada atualização. */
export function Mapa({ latitude, longitude, precisao }: Props) {
  const elemento = useRef<HTMLDivElement>(null);
  const mapa = useRef<L.Map | null>(null);
  const ponto = useRef<L.CircleMarker | null>(null);
  const circulo = useRef<L.Circle | null>(null);

  useEffect(() => {
    if (!elemento.current || mapa.current) return;
    const m = L.map(elemento.current, { zoomControl: true, attributionControl: true }).setView(
      [latitude, longitude],
      16,
    );
    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      referrerPolicy: "no-referrer",
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
    }).addTo(m);
    m.attributionControl.setPrefix("Leaflet");
    circulo.current = L.circle([latitude, longitude], {
      radius: precisao ?? 0,
      color: "#2F5D62",
      weight: 1.5,
      fillColor: "#2F5D62",
      fillOpacity: 0.12,
    }).addTo(m);
    ponto.current = L.circleMarker([latitude, longitude], {
      radius: 9,
      color: "#FFFFFF",
      weight: 3,
      fillColor: "#7A2E3A",
      fillOpacity: 1,
    }).addTo(m);
    mapa.current = m;
    return () => {
      m.remove();
      mapa.current = null;
    };
    // O mapa é criado uma vez; as posições novas entram no efeito abaixo.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    const pos: L.LatLngExpression = [latitude, longitude];
    ponto.current?.setLatLng(pos);
    circulo.current?.setLatLng(pos).setRadius(precisao ?? 0);
    mapa.current?.panTo(pos, { animate: true });
  }, [latitude, longitude, precisao]);

  return <div ref={elemento} className="mapa" role="img" aria-label="Mapa com a localização compartilhada" />;
}
