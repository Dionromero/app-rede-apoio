import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Duas páginas: a landing (/) e o acompanhamento ao vivo (/acompanhar/).
export default defineConfig({
  plugins: [react()],
  build: {
    rollupOptions: {
      input: {
        principal: "index.html",
        acompanhar: "acompanhar/index.html",
      },
    },
  },
});
