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
        nineGreen: {
          50: "#E9FBF4",
          100: "#C1F5E1",
          200: "#9AEFCE",
          300: "#72E9BA",
          400: "#4BE2A7",
          500: "#23DC94",
          600: "#1CB076",
          700: "#158459",
          800: "#0E583B",
          900: "#072C1E",
        },
        nineTeal: {
          50: "#F0F4F4",
          100: "#D5E1E0",
          200: "#BACECB",
          300: "#A0BBB7",
          400: "#85A8A3",
          500: "#6A958F",
          600: "#557772",
          700: "#405956",
          800: "#2A3C39",
          900: "#151E1D",
        },
        nineCyan: {
          50: "#F2F2F3",
          100: "#D9DBDD",
          200: "#C1C3C8",
          300: "#A9ACB2",
          400: "#91959C",
          500: "#797E86",
          600: "#60646C",
          700: "#484B51",
          800: "#303236",
          900: "#18191B",
        },
        darkGray: {
          50: "#F1F1F3",
          100: "#D8D8DF",
          200: "#BFC0CA",
          300: "#A6A7B5",
          400: "#8D8EA0",
          500: "#74758B",
          600: "#5D5E6F",
          700: "#464653",
          800: "#2E2F38",
          900: "#17171C",
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
