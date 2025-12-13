import { Controller } from "@hotwired/stimulus";
import { Chart, registerables } from "chart.js";
Chart.register(...registerables);

export default class extends Controller {
  static targets = ["collectionHistoryChart"];
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

  getSuggestedMin(minValue) {
    if (minValue < 1) {
      return Math.max(0, minValue - 0.05);
    } else {
      return Math.max(0, minValue - minValue * 0.1);
    }
  }

  getSuggestedMax(maxValue) {
    if (maxValue < 1) {
      return maxValue + 0.05;
    } else {
      return maxValue + maxValue * 0.1;
    }
  }

  processDate(date) {
    const parts = date.split("-");
    const month = parseInt(parts[1], 10);
    const day = parseInt(parts[2], 10);
    return `${month}/${day}`;
  }

  renderChart() {
    const historyData = this.collectionHistoryChartTarget.dataset.collectionHistoryChartEvents;

    if (!historyData) {
      console.error("No history data found.");
      return;
    }

    let history;
    try {
      history = JSON.parse(historyData);
    } catch (e) {
      console.error("Failed to parse history data:", e);
      return;
    }

    if (Object.keys(history).length === 0) {
      console.error("History data is empty.");
      return;
    }

    // Destroy existing chart if it exists
    if (this.chart) {
      this.chart.destroy();
      this.chart = null;
    }

    // Sort dates and extract labels and values
    const sortedEntries = Object.entries(history).sort((a, b) => a[0].localeCompare(b[0]));
    const labels = sortedEntries.map(([date]) => this.processDate(date));
    const values = sortedEntries.map(([_, value]) => parseFloat(value));

    const minValue = Math.min(...values);
    const maxValue = Math.max(...values);

    // Set canvas height
    const canvas = this.collectionHistoryChartTarget;
    const fixedHeight = 150;
    canvas.style.height = `${fixedHeight}px`;

    // Create chart
    this.chart = new Chart(canvas.getContext("2d"), {
      type: "line",
      data: {
        labels: labels,
        datasets: [
          {
            label: "Collection Value",
            data: values,
            backgroundColor: "#39DB7D",
            borderColor: "#39DB7D",
            borderWidth: 2,
            tension: 0.3,
            fill: false,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          y: {
            suggestedMin: this.getSuggestedMin(minValue),
            suggestedMax: this.getSuggestedMax(maxValue),
            border: {
              display: true,
            },
            grid: {
              color: "#2E3F49",
              display: false,
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
              display: false,
            },
            grid: {
              color: "#2E3F49",
              display: false,
            },
            ticks: {
              display: false,
            },
          },
        },
        plugins: {
          legend: {
            display: false,
          },
          tooltip: {
            enabled: true,
            callbacks: {
              label: function (context) {
                return "Value: $" + context.parsed.y.toFixed(2);
              },
            },
          },
        },
        elements: {
          line: {
            borderWidth: 4,
          },
          point: {
            radius: 1,
            hoverRadius: 8,
          },
        },
      },
    });
  }
}
