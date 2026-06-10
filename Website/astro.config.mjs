import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://getdango.pages.dev',
  server: {
    allowedHosts: ['macbook', '.ts.net'],
  },
});
