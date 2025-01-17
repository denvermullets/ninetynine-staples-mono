import { Controller } from "@hotwired/stimulus";
import { Chart, registerables } from "chart.js";
Chart.register(...registerables);

export default class extends Controller {
  static targets = ["cardPriceChart"];
  chart = null;

  connect() {
    console.log("hi");
    this.renderChart();
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy();
    }
  }

  getSuggestedMin(minPrice) {
    if (minPrice < 1) {
      return Math.max(0, minPrice - 0.05);
    } else if (minPrice < 30) {
      return Math.max(0, minPrice - 5);
    } else {
      return Math.max(0, minPrice - 20);
    }
  }

  getSuggestedMax(maxPrice) {
    if (maxPrice < 1) {
      return maxPrice + 0.2;
    } else if (maxPrice < 30) {
      return maxPrice + 5;
    } else {
      return maxPrice + 20;
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
    console.log("cardPriceHistory: ", cardPriceHistory);

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
      console.log("priceHistory: ", priceHistory);
    }

    const labels = [];
    const foilPrices = [];
    const normalPrices = [];

    // Parse the data for labels and prices
    priceHistory.foil.forEach((card) => {
      const date = this.processDate(Object.keys(card)[0]);

      labels.push(date);
      foilPrices.push(Object.values(card)[0]);
    });

    priceHistory.normal.forEach((card) => {
      normalPrices.push(Object.values(card)[0]);
    });

    console.log("foilPrices: ", foilPrices);
    console.log("normalPrices: ", normalPrices);
    console.log("labels: ", labels);

    const minPrice = Math.min(...foilPrices, ...normalPrices);
    const maxPrice = Math.max(...foilPrices, ...normalPrices);

    this.chart = new Chart(this.canvasContext(), {
      type: "line",
      data: {
        labels: labels,
        datasets: [
          {
            label: "Foil Price",
            data: foilPrices,
            backgroundColor: "#39DB7D",
            borderColor: "#39DB7D", // Foil line color
            borderWidth: 2,
            tension: 0.6, // Smooth lines
            fill: false, // No area fill
          },
          {
            label: "Normal Price",
            data: normalPrices,
            backgroundColor: "#C6EE52",
            borderColor: "#C6EE52", // Normal line color
            borderWidth: 2,
            tension: 0.4, // Smooth lines
            fill: false, // No area fill
          },
        ],
      },
      options: {
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
            enabled: true, // Enable tooltips
          },
        },
        elements: {
          line: {
            borderWidth: 4,
          },
          point: {
            radius: 1,
            hoverRadius: 8, // Increase point size on hover
          },
        },
      },
    });
  }

  canvasContext() {
    return this.cardPriceChartTarget.getContext("2d");
  }
}
