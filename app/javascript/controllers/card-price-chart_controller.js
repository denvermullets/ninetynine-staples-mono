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
            beginAtZero: true,
            border: {
              display: true,
            },
            grid: {
              display: true, // Show grid lines on y-axis
            },
            ticks: {
              precision: 2, // Only show whole numbers
              display: true, // Show y-axis labels
            },
          },
          x: {
            border: {
              display: true,
            },
            grid: {
              display: false, // Hide grid lines on x-axis
            },
            ticks: {
              display: true, // Show x-axis labels
              minRotation: 45, // Minimum rotation angle for labels
              maxRotation: 90,
            },
          },
        },
        plugins: {
          legend: {
            display: true, // Show legend
            position: "top",
            align: "end", // Align legend to the right
            labels: {
              usePointStyle: true, // Use dots instead of boxes
              pointStyle: "circle", // Style of the legend points
              boxWidth: 6, // Smaller dot size in legend
              boxHeight: 6,
            },
          },
          tooltip: {
            enabled: true, // Enable tooltips
          },
        },
        elements: {
          line: {
            borderWidth: 2, // Adjust the line width if necessary
          },
          point: {
            radius: 1, // Show points on the line
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
