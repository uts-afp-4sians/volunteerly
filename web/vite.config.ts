import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";

// Project Pages are served from https://uts-afp-4sians.github.io/volunteerly/,
// so assets must resolve under that sub-path.
export default defineConfig({
  base: "/volunteerly/",
  plugins: [react(), tailwindcss()],
});
