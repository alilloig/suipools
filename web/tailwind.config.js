/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        display: ["Oswald", "sans-serif"],
      },
      colors: {
        pitch: {
          DEFAULT: "#1a472a",
          light: "#2d6a4f",
          dark: "#0f2d1a",
        },
        gold: {
          DEFAULT: "#d4af37",
          light: "#e6c966",
          dark: "#b8992f",
        },
        status: {
          success: "#4baf4b",
          warning: "#ffa500",
          error: "#ff6b6b",
          info: "#6b9bd2",
        },
      },
      animation: {
        "fade-in": "fade-in 0.6s ease-out forwards",
        "fade-in-up": "fade-in-up 0.7s ease-out forwards",
        "glow-pulse": "glow-pulse 3s ease-in-out infinite",
        "pitch-lines": "pitch-lines 20s linear infinite",
      },
      keyframes: {
        "fade-in": {
          "0%": { opacity: "0" },
          "100%": { opacity: "1" },
        },
        "fade-in-up": {
          "0%": { opacity: "0", transform: "translateY(20px)" },
          "100%": { opacity: "1", transform: "translateY(0)" },
        },
        "glow-pulse": {
          "0%, 100%": { opacity: "0.4" },
          "50%": { opacity: "0.8" },
        },
        "pitch-lines": {
          "0%": { backgroundPosition: "0 0" },
          "100%": { backgroundPosition: "0 40px" },
        },
      },
    },
  },
  plugins: [],
};
