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

  // we want the curve to be sorta in the middle of the graph
  getSuggestedMin(minPrice) {
    if (minPrice < 1) {
      return Math.max(0, minPrice - 0.05);
    } else {
      return Math.max(0, minPrice - 1);
    }
  }

  getSuggestedMax(maxPrice) {
    if (maxPrice < 1) {
      return maxPrice + 0.05;
    } else {
      return maxPrice + 1;
    }
  }

  processDate(date) {
    const parts = date.split("-");
    const month = parseInt(parts[1], 10);
    const day = parseInt(parts[2], 10);

    return `${month}/${day}`;
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

    const labels = [];
    const foilPrices = [];
    const normalPrices = [];

    if (priceHistory.foil.length > 0) {
      priceHistory.foil.forEach((card) => {
        const date = this.processDate(Object.keys(card)[0]);
        labels.push(date);
        foilPrices.push(Object.values(card)[0]);
      });
    }

    if (priceHistory.normal.length > 0) {
      priceHistory.normal.forEach((card) => {
        const date = this.processDate(Object.keys(card)[0]);
        labels.push(date);
        normalPrices.push(Object.values(card)[0]);
      });
    }

    if (labels.length === 0) {
      labels.push("No Data");
    }

    const uniqueLabels = [...new Set(labels)];

    const minPrice = Math.min(...foilPrices, ...normalPrices);
    const maxPrice = Math.max(...foilPrices, ...normalPrices);

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
          },
          {
            label: "Regular Price",
            data: normalPrices,
            backgroundColor: "#C6EE52",
            borderColor: "#C6EE52",
            borderWidth: 2,
            tension: 0.3,
            fill: false,
          },
        ].filter((dataset) => dataset.data.length > 0),
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
            suggestedMin: this.getSuggestedMin(minPrice),
            suggestedMax: this.getSuggestedMax(maxPrice),
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
