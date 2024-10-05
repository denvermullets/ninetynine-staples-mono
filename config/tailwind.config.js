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
        menu: "#283943",
        foreground: "#1A262D",
        highlight: "#2E3F49",
        greyText: "#859296",
        background: "#141E22",
        dark: {
          200: "#202E36",
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
