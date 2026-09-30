import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "leaflet/dist/leaflet.css";
import "../styles.css";
import "./acompanhar.css";
import { Acompanhar } from "./Acompanhar";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <Acompanhar />
  </StrictMode>,
);
