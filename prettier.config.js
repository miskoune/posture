import { prettierConfig } from '@miskoune/config';

export default {
  ...prettierConfig,
  plugins: [...(prettierConfig.plugins || []), 'prettier-plugin-astro'],
  overrides: [
    ...(prettierConfig.overrides || []),
    {
      files: '*.astro',
      options: {
        parser: 'astro',
      },
    },
  ],
};
