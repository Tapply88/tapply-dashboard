import type { Config } from 'tailwindcss';

const config: Config = {
  content: ['./src/**/*.{js,ts,jsx,tsx,mdx}'],
  theme: {
    extend: {
      colors: {
        navy: {
          DEFAULT: '#092762',
          soft: '#1B3A7A',
          50: '#EDF0F7',
        },
        cream: '#F7F6F2',
        paper: '#FFFFFF',
        grey: {
          DEFAULT: '#CFCFCF',
          light: '#E8E8E6',
        },
        ink: '#1A1A1A',
        sage: {
          DEFAULT: '#5B8266',
          light: '#EAF1EC',
        },
        rust: {
          DEFAULT: '#B54834',
          light: '#F7EAE7',
        },
      },
      fontFamily: {
        sans: ['var(--font-sans)', 'sans-serif'],
        serif: ['var(--font-serif)', 'serif'],
        mono: ['var(--font-mono)', 'monospace'],
      },
      borderRadius: {
        card: '14px',
      },
    },
  },
  plugins: [],
};

export default config;
