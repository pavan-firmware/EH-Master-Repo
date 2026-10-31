/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        vscode: {
          bg: '#1E1E1E',
          sidebar: '#181818',
          panel: '#252526',
          input: '#1F1F1F',
          border: '#3C3C3C',
          hover: '#2A2D2E',
          accent: '#007ACC',
          accentHover: '#0062A3',
          text: '#CCCCCC',
          muted: '#9D9D9D',
          success: '#4EC9B0',
          warning: '#CCA700',
          error: '#F48771',
        },
        brand: {
          50: '#e0f2fe',
          100: '#bae6fd',
          500: '#007ACC',
          600: '#0062A3',
          700: '#004c80',
          900: '#00264d',
        },
        surface: {
          darker: '#181818',
          dark: '#1E1E1E',
          card: '#252526',
          border: '#3C3C3C',
          muted: '#9D9D9D',
        },
      },
      fontFamily: {
        sans: ['Segoe UI', 'system-ui', '-apple-system', 'sans-serif'],
        mono: ['Cascadia Code', 'Consolas', 'Courier New', 'monospace'],
      },
    },
  },
  plugins: [],
};

