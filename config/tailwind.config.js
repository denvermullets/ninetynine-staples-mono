const defaultTheme = require("tailwindcss/defaultTheme");

module.exports = {
  content: [
    "./public/*.html",
    "./app/helpers/**/*.rb",
    "./app/javascript/**/*.js",
    "./app/views/**/*.{erb,haml,html,slim}",
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ["Inter var", ...defaultTheme.fontFamily.sans],
      },
      colors: {
        dark: {
          50: "#141E22",
          100: "#1A262D",
          200: "#202E36",
          300: "#283943",
          400: "#2E3F49",
          500: "#859296",
        },
        accent: {
          50: "#39DB7D",
          100: "#FC3B74",
          200: "#F3A952",
          300: "#FFD439",
          400: "#C6EE52",
          500: "#FEFEFE",
        },
      },
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    require("@tailwindcss/typography"),
    require("@tailwindcss/container-queries"),
  ],
};
