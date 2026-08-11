import { Controller } from "@hotwired/stimulus";
import { Chart, registerables } from "chart.js";

Chart.register(...registerables);

// Charts for the collection analytics dashboard.
//
// One controller serves both forms: a doughnut for colour identity and bars for the mana
// curve and the release-year timeline. Everything else on the dashboard is a CSS meter.
//
// Colours are read off document.documentElement at build time rather than hardcoded, because
// this app has two themes and theme_controller.js swaps them by setting data-theme on <html>
// without firing an event. A MutationObserver on that one attribute is the only notification
// available. Note theme_controller re-sets the attribute when its save fails, so expect two
// rebuilds on a network error - both correct, both cheap.
//
// Rebuilding rather than patching chart.options is deliberate: patching means a second code
// path touching every themed option, which drifts the moment someone adds one. A theme flip
// is a once-per-session click.
//
// Deliberately no window resize listener. Chart.js responsive:true installs its own
// ResizeObserver and disposes of it in destroy(). The other chart controllers in this app add
// one and never remove it - removeEventListener with a fresh .bind() is a no-op - so every
// Turbo visit leaks a listener and a chart rebuild.
export default class extends Controller {
  static targets = ["canvas", "swatch"];

  static values = {
    type: { type: String, default: "bar" },
    labels: Array,
    series: Array,
    tooltips: Array,
    // semantic keys ("white", "blue"...), never hexes - the hex depends on the theme, which
    // the server does not know
    palette: { type: Array, default: [] },
  };

  // A 7-slice doughnut is an all-pairs form and no palette can separate all 21 pairs under
  // colour-vision deficiency. These clear the adjacent-pair, lightness, chroma and 3:1
  // contrast checks against both surfaces (dark #141e22, e-ink #dfdfdf); the remaining gap is
  // covered by the panel's HTML legend, which carries a mana glyph and a count per row so
  // identity never rests on hue alone.
  static PALETTES = {
    dark: {
      white: "#a49807",
      blue: "#2694eb",
      black: "#7857ab",
      red: "#fc3f0a",
      green: "#1d9a68",
      colorless: "#126f96",
      multicolor: "#925b0c",
    },
    light: {
      white: "#8a8011",
      blue: "#2779bc",
      black: "#5e3594",
      red: "#8d2a30",
      green: "#118d29",
      // chroma 0.087 against a 0.10 floor, on purpose: pushing it up gives a saturated teal
      // that stops reading as "colorless", and a true grey separates worse
      colorless: "#00707f",
      multicolor: "#7a4300",
    },
  };

  connect() {
    this.observer = new MutationObserver(() => this.rebuild());
    this.observer.observe(document.documentElement, {
      attributeFilter: ["data-theme"],
    });
    this.rebuild();
  }

  disconnect() {
    this.observer?.disconnect();
    this.observer = null;
    this.chart?.destroy();
    this.chart = null;
  }

  rebuild() {
    this.chart?.destroy();
    this.chart = null;

    if (!this.hasCanvasTarget || this.seriesValue.length === 0) return;

    this.paintSwatches();
    this.chart = new Chart(this.canvasTarget.getContext("2d"), this.config());
  }

  // theme ---------------------------------------------------------------------

  get theme() {
    return document.documentElement.getAttribute("data-theme") === "light"
      ? "light"
      : "dark";
  }

  cssVar(name, fallback) {
    const value = getComputedStyle(document.documentElement)
      .getPropertyValue(name)
      .trim();

    return value || fallback;
  }

  // grid, ticks and bar fill ride the same tokens the meter panels use, so the charts follow
  // the theme without a second set of colour definitions
  get ink() {
    return {
      text: this.cssVar("--color-grey-text", "#859296"),
      grid: this.cssVar("--color-highlight", "#2e3f49"),
      accent: this.cssVar("--color-accent-50", "#39db7d"),
      // the panel is bg-foreground, so arcs separated by a ring of it read as a gap rather
      // than as an eighth colour
      surface: this.cssVar("--color-foreground", "#1a262d"),
    };
  }

  get colors() {
    const palette = this.constructor.PALETTES[this.theme];

    return this.paletteValue.map((key) => palette[key] || this.ink.accent);
  }

  paintSwatches() {
    if (!this.hasSwatchTarget) return;

    const colors = this.colors;

    this.swatchTargets.forEach((swatch, index) => {
      swatch.style.backgroundColor = colors[index] || this.ink.accent;
    });
  }

  // config --------------------------------------------------------------------

  config() {
    return this.typeValue === "doughnut" ? this.doughnut() : this.bar();
  }

  // tooltips arrive pre-formatted from Ruby, so number_to_currency stays the one place money
  // gets rendered and the charts cannot drift from the meter panels beside them
  get tooltip() {
    const tooltips = this.tooltipsValue;

    return {
      displayColors: false,
      callbacks: {
        label: (context) => tooltips[context.dataIndex] || context.formattedValue,
      },
    };
  }

  doughnut() {
    const ink = this.ink;

    return {
      type: "doughnut",
      data: {
        labels: this.labelsValue,
        datasets: [
          {
            data: this.seriesValue,
            backgroundColor: this.colors,
            borderColor: ink.surface,
            borderWidth: 2,
            hoverOffset: 6,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: "62%",
        // the panel's own legend carries glyphs and counts, so Chart.js's would be a second,
        // colour-only copy of it
        plugins: { legend: { display: false }, tooltip: this.tooltip },
      },
    };
  }

  bar() {
    const ink = this.ink;

    return {
      type: "bar",
      data: {
        labels: this.labelsValue,
        datasets: [
          {
            data: this.seriesValue,
            backgroundColor: ink.accent,
            // rounding both ends would detach the bar from zero and misread the magnitude
            borderRadius: 4,
            borderSkipped: "bottom",
            maxBarThickness: 44,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false }, tooltip: this.tooltip },
        scales: {
          x: {
            border: { display: false },
            grid: { display: false },
            ticks: { color: ink.text, autoSkip: true, maxRotation: 0 },
          },
          y: {
            beginAtZero: true,
            border: { display: false },
            grid: { color: ink.grid, drawTicks: false },
            // these are card counts
            ticks: { color: ink.text, precision: 0 },
          },
        },
      },
    };
  }
}
