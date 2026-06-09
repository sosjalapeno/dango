import { defineConfig } from 'astro/config';

export default defineConfig({
  server: {
    allowedHosts: ['macbook', '.ts.net'],
  },
});
