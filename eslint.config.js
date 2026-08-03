import { eslintConfig } from '@miskoune/config';
import eslintPluginAstro from 'eslint-plugin-astro';

export default [
  ...eslintConfig,
  ...eslintPluginAstro.configs.recommended,
  { ignores: ['.astro/**', 'dist/**'] },
  {
    files: ['**/*.astro'],
    settings: {
      // @miskoune/config registers eslint-plugin-import-x, so the rules and
      // settings live under `import-x/`, not `import/`.
      'import-x/resolver': {
        typescript: true,
      },
    },
    rules: {
      // `astro:*` are virtual modules with no file on disk.
      'import-x/no-unresolved': ['error', { ignore: ['^astro:'] }],
    },
  },
];
