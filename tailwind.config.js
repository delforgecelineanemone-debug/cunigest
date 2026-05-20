/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./docs/**/*.{html,js,jsx}"],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        display: ['"Instrument Serif"', 'ui-serif', 'Georgia', 'serif'],
      },
      colors: {
        jade: { 50:'#E6F4EE', 100:'#CDE9DD', 200:'#9DD3BB', 300:'#5FBE96', 400:'#2BA37B', 500:'#0F8C66', 600:'#0D7256', 700:'#0A5944', 800:'#073E30', 900:'#04261D' },
        ink: { DEFAULT: '#1A1F1B', soft: '#2A3530', muted: '#5C6660', faint:'#9AA29D' },
        paper: { DEFAULT:'#FAF9F5', raised:'#F2F0E9', card:'#FFFFFF', deep:'#EBE7DA' },
        line: { DEFAULT:'#E5E3DC', soft:'#EFEDE7' },
        repro: '#7C5CDB',
        health: '#E24B4A',
        feed: '#D85A30',
        finance: '#B47416',
        tools: '#1565C0',
        admin: '#546E7A',
        ok: '#2D9B5A',
        warn: '#E8A02C',
        bad: '#D63B3A',
      },
      boxShadow: {
        card: '0 1px 2px rgba(26,31,27,0.04), 0 4px 12px -2px rgba(26,31,27,0.06)',
        phone: '0 40px 80px -20px rgba(26,31,27,0.35), 0 8px 24px rgba(26,31,27,0.08)',
        glow: '0 0 0 1px rgba(15,140,102,0.10), 0 12px 40px -6px rgba(15,140,102,0.25)',
      },
      animation: {
        'pulse-soft': 'pulseSoft 2.4s ease-in-out infinite',
        'shimmer': 'shimmer 2.4s linear infinite',
      },
      keyframes: {
        pulseSoft: { '0%,100%':{opacity:.55}, '50%':{opacity:1} },
        shimmer: { '0%':{backgroundPosition:'-200% 0'}, '100%':{backgroundPosition:'200% 0'} },
      }
    }
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography')
  ]
}
