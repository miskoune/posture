import tailwindcss from '@tailwindcss/vite';
import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://posture.miskoune.com',
  build: {
    // emit /about/index.html rather than /about.html — matches the nginx
    // try_files rule used by the miskoune boxes
    format: 'directory',
  },
  vite: {
    plugins: [tailwindcss()],
    server: {
      // dev only, and it never reaches the built site: lets the dev server
      // answer to the tailnet MagicDNS name so the preview opens on a phone.
      // The server still binds to loopback — a small TCP forwarder republishes
      // it on tailscale0.
      allowedHosts: ['miskoune'],
    },
  },
});
