import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://posture.miskoune.com',
  build: {
    // emit /about/index.html rather than /about.html — matches the nginx
    // try_files rule used by the miskoune boxes
    format: 'directory',
  },
});
