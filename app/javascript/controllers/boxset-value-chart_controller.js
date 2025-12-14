import { Controller } from "@hotwired/stimulus";
import { Chart, registerables } from "chart.js";
Chart.register(...registerables);

export default class extends Controller {
  static targets = ["boxsetValueChart"];
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
    const valueHistory = this.boxsetValueChartTarget.dataset.boxsetValueChartEvents;

    if (!valueHistory) {
      console.error("No value history data found.");
      return;
    }

    let history;
    try {
      history = JSON.parse(valueHistory);
    } catch (e) {
      console.error("Failed to parse value history:", e);
      return;
    }

    if (!history.normal && !history.foil) {
      console.error("Value history data is empty.");
      return;
    }

    // Destroy existing chart if it exists
    if (this.chart) {
      this.chart.destroy();
      this.chart = null;
    }

    const labels = [];
    const foilValues = [];
    const normalValues = [];

    if (history.foil && history.foil.length > 0) {
      history.foil.forEach((entry) => {
        const date = this.processDate(Object.keys(entry)[0]);
        labels.push(date);
        foilValues.push(Object.values(entry)[0]);
      });
    }

    if (history.normal && history.normal.length > 0) {
      history.normal.forEach((entry) => {
        const date = this.processDate(Object.keys(entry)[0]);
        if (!labels.includes(date)) {
          labels.push(date);
        }
        normalValues.push(Object.values(entry)[0]);
      });
    }

    if (labels.length === 0) {
      console.error("No data to display");
      return;
    }

    const uniqueLabels = [...new Set(labels)];
    const allValues = [...foilValues, ...normalValues];
    const minValue = Math.min(...allValues);
    const maxValue = Math.max(...allValues);

    // Set canvas height
    const canvas = this.boxsetValueChartTarget;
    const fixedHeight = 125;
    canvas.style.height = `${fixedHeight}px`;

    // Create chart
    this.chart = new Chart(canvas.getContext("2d"), {
      type: "line",
      data: {
        labels: uniqueLabels,
        datasets: [
          {
            label: "Foil Total",
            data: foilValues,
            backgroundColor: "#39DB7D",
            borderColor: "#39DB7D",
            borderWidth: 2,
            tension: 0.3,
            fill: false,
          },
          {
            label: "Normal Total",
            data: normalValues,
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
            hoverRadius: 0,
          },
        },
      },
    });
  }
}
