/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#2B6CB0',
          light: '#EBF4FF',
          dark: '#63B3ED',
        },
        success: '#38A169',
        danger: '#E53E3E',
        warning: '#ED8936',
        'bg-page': '#F7FAFC',
        'bg-card': '#FFFFFF',
        'text-primary': '#1A202C',
        'text-secondary': '#718096',
        divider: '#E2E8F0',
      },
      fontFamily: {
        sans: [
          '-apple-system',
          'BlinkMacSystemFont',
          'SF Pro Display',
          'Segoe UI',
          'Roboto',
          'Helvetica Neue',
          'Arial',
          'sans-serif',
        ],
      },
    },
  },
  plugins: [],
}
