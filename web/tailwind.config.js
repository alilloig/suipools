/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
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
    },
  },
  plugins: [],
};
