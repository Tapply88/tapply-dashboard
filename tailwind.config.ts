import type { Config } from 'tailwindcss';
const config: Config = {
  content: ['./src/**/*.{js,ts,jsx,tsx,mdx}'],
  theme: {
    extend: {
      colors: {
        navy: {
          DEFAULT: '#623609',
          soft: '#8B5A2E',
          50: '#F0E7DE',
        },
        cream: '#D6CFC6',
        paper: '#FFFFFF',
        grey: {
          DEFAULT: '#C4BBAF',
          light: '#E6DED4',
        },
        ink: '#2A1D12',
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
