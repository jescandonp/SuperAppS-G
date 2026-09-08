import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  // Sin esto, Vite resuelve el junction de dev (C:\tmp\sg-superapp-web-dev) a la ruta real del
  // repo, que contiene "&" (ProyectoS&G) - ese caracter rompe el parseo de un script generado por
  // Vite y la app carga en blanco. preserveSymlinks mantiene la ruta del junction, sin el "&".
  resolve: {
    preserveSymlinks: true
  }
});

