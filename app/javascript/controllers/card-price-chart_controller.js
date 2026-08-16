import { Controller } from "@hotwired/stimulus";
import { Chart, registerables } from "chart.js";
Chart.register(...registerables);

export default class extends Controller {
  static targets = ["cardPriceChart"];
  chart = null;

  connect() {
    this.renderChart();
    window.addEventListener("resize", this.handleResize.bind(this));
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy();
    }
    window.removeEventListener("resize", this.handleResize.bind(this));
  }

  handleResize() {
    this.renderChart();
  }

  // we want the curve to be sorta in the middle of the graph. pad relative to
  // the span so a $1.62 card doesn't get an axis that runs to $3.00 - a flat
  // dollar of headroom eats half the plot once prices climb past $1
  getAxisBounds(minPrice, maxPrice) {
    if (!Number.isFinite(minPrice) || !Number.isFinite(maxPrice)) {
      return { min: 0, max: 1 };
    }

    // a card that never moves has no span to pad against, so fall back to a
    // slice of the price itself and finally to a few cents for penny cards
    const pad = Math.max((maxPrice - minPrice) * 0.15, maxPrice * 0.05, 0.05);

    return { min: Math.max(0, minPrice - pad), max: maxPrice + pad };
  }

  // chart.js drops a tick on each hard bound, which would label the axis with
  // whatever the padding worked out to ($0.09, $2.14). build the ticks ourselves
  // so the bounds stay tight but every label is a round number
  buildPriceTicks(min, max) {
    const rough = (max - min) / 6;
    const magnitude = Math.pow(10, Math.floor(Math.log10(rough)));
    const normalized = rough / magnitude;
    const step = (normalized <= 1 ? 1 : normalized <= 2 ? 2 : normalized <= 5 ? 5 : 10) * magnitude;

    const ticks = [];
    for (let value = Math.ceil(min / step) * step; value <= max + step / 1000; value += step) {
      ticks.push({ value: Math.round(value / step) * step });
    }

    return ticks;
  }

  processDate(date) {
    const parts = date.split("-");
    const month = parseInt(parts[1], 10);
    const day = parseInt(parts[2], 10);

    return `${month}/${day}`;
  }

  // history arrives as a list of single-key {date: price} objects. collapse it
  // into a date -> price lookup so both finishes can be plotted against one
  // shared axis instead of by position in their own array
  toSeries(entries) {
    const series = {};

    (entries || []).forEach((entry) => {
      const [date, price] = Object.entries(entry)[0];
      series[date] = price;
    });

    return series;
  }

  renderChart() {
    const cardPriceHistory = this.cardPriceChartTarget.dataset.cardPriceChartEvents;

    if (!cardPriceHistory) {
      console.error("No events data found.");
      return;
    }

    let priceHistory;
    if (!cardPriceHistory || cardPriceHistory.length === 0) {
      console.error("Price history data is empty.");
      return;
    } else {
      priceHistory = JSON.parse(cardPriceHistory);
    }

    // Destroy the existing chart instance if it exists
    if (this.chart) {
      this.chart.destroy();
      this.chart = null;
    }

    const foilSeries = this.toSeries(priceHistory.foil);
    const normalSeries = this.toSeries(priceHistory.normal);

    // the two finishes are tracked independently, so their dates can diverge -
    // a finish that starts late or skips a day used to shift every later point.
    // build one sorted axis off the union and look each finish up by date. ISO
    // dates sort lexicographically, so no parsing needed
    const dates = [...new Set([...Object.keys(foilSeries), ...Object.keys(normalSeries)])].sort();
    const foilPrices = dates.map((date) => (date in foilSeries ? foilSeries[date] : null));
    const normalPrices = dates.map((date) => (date in normalSeries ? normalSeries[date] : null));

    const uniqueLabels = dates.length > 0 ? dates.map((date) => this.processDate(date)) : ["No Data"];

    const plottedPrices = [...foilPrices, ...normalPrices].filter((price) => price !== null);
    const priceBounds = this.getAxisBounds(Math.min(...plottedPrices), Math.max(...plottedPrices));

    // Fix canvas height before initializing a new chart
    const canvas = this.cardPriceChartTarget;
    const fixedHeight = 275;
    canvas.style.height = `${fixedHeight}px`;

    // Custom plugin to draw a vertical crosshair line on hover
    const verticalLinePlugin = {
      id: "verticalLine",
      afterDraw: (chart) => {
        if (chart.tooltip?._active?.length) {
          const activePoint = chart.tooltip._active[0];
          const ctx = chart.ctx;
          const x = activePoint.element.x;
          const topY = chart.scales.y.top;
          const bottomY = chart.scales.y.bottom;

          ctx.save();
          ctx.beginPath();
          ctx.moveTo(x, topY);
          ctx.lineTo(x, bottomY);
          ctx.lineWidth = 1;
          ctx.strokeStyle = "rgba(255, 255, 255, 0.3)";
          ctx.stroke();
          ctx.restore();
        }
      },
    };

    // Create a new chart instance
    this.chart = new Chart(canvas.getContext("2d"), {
      type: "line",
      data: {
        labels: uniqueLabels,
        datasets: [
          {
            label: "Foil Price",
            data: foilPrices,
            backgroundColor: "#39DB7D",
            borderColor: "#39DB7D",
            borderWidth: 2,
            tension: 0.3,
            fill: false,
            spanGaps: true,
          },
          {
            label: "Regular Price",
            data: normalPrices,
            backgroundColor: "#C6EE52",
            borderColor: "#C6EE52",
            borderWidth: 2,
            tension: 0.3,
            fill: false,
            spanGaps: true,
          },
          // a finish with no history at all is all nulls, not an empty array -
          // it would otherwise claim a legend entry it never draws a line for
        ].filter((dataset) => dataset.data.some((price) => price !== null)),
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: "index",
          intersect: false,
        },
        scales: {
          y: {
            // hard bounds, not suggested - suggestedMin/Max let chart.js round
            // outward to the next nice tick, which is what pinned the floor to
            // $0.00 and the ceiling a full dollar above the highest price
            min: priceBounds.min,
            max: priceBounds.max,
            afterBuildTicks: (axis) => {
              axis.ticks = this.buildPriceTicks(axis.min, axis.max);
            },
            border: {
              display: true,
            },
            grid: {
              color: "#2E3F49",
              display: true,
            },
            ticks: {
              precision: 2,
              display: true,
              callback: function (value) {
                return "$" + value.toFixed(2);
              },
            },
          },
          x: {
            border: {
              display: true,
            },
            grid: {
              color: "#2E3F49",
              display: false,
            },
            ticks: {
              display: true,
              minRotation: 45,
              maxRotation: 90,
            },
          },
        },
        plugins: {
          legend: {
            display: true,
            position: "top",
            align: "end",
            labels: {
              usePointStyle: true,
              pointStyle: "circle",
              boxWidth: 6,
              boxHeight: 6,
            },
          },
          tooltip: {
            enabled: true,
            mode: "index",
            intersect: false,
            callbacks: {
              label: function (context) {
                return context.dataset.label + ": $" + context.parsed.y.toFixed(2);
              },
            },
          },
        },
        elements: {
          line: {
            borderWidth: 4,
          },
          point: {
            radius: 0,
            hoverRadius: 6,
            pointHitRadius: 8,
          },
        },
      },
      plugins: [verticalLinePlugin],
    });
  }
}
