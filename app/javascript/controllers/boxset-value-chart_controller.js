import { Controller } from "@hotwired/stimulus";
import { Chart, registerables } from "chart.js";
Chart.register(...registerables);

export default class extends Controller {
  static targets = ["normalChart", "foilChart"];
  normalChart = null;
  foilChart = null;

  connect() {
    this.renderCharts();
    window.addEventListener("resize", this.handleResize.bind(this));
  }

  disconnect() {
    if (this.normalChart) {
      this.normalChart.destroy();
    }
    if (this.foilChart) {
      this.foilChart.destroy();
    }
    window.removeEventListener("resize", this.handleResize.bind(this));
  }

  handleResize() {
    this.renderCharts();
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

  renderCharts() {
    this.renderNormalChart();
    this.renderFoilChart();
  }

  renderNormalChart() {
    if (!this.hasNormalChartTarget) return;

    const normalData = this.normalChartTarget.dataset.boxsetValueChartNormal;
    if (!normalData) return;

    let history;
    try {
      history = JSON.parse(normalData);
    } catch (e) {
      console.error("Failed to parse normal value history:", e);
      return;
    }

    if (!history || history.length === 0) return;

    // Destroy existing chart if it exists
    if (this.normalChart) {
      this.normalChart.destroy();
      this.normalChart = null;
    }

    const labels = [];
    const values = [];

    history.forEach((entry) => {
      const date = this.processDate(Object.keys(entry)[0]);
      labels.push(date);
      values.push(Object.values(entry)[0]);
    });

    if (labels.length === 0) return;

    const minValue = Math.min(...values);
    const maxValue = Math.max(...values);

    const canvas = this.normalChartTarget;
    const fixedHeight = 125;
    canvas.style.height = `${fixedHeight}px`;

    this.normalChart = new Chart(canvas.getContext("2d"), {
      type: "line",
      data: {
        labels: labels,
        datasets: [
          {
            label: "Normal Total",
            data: values,
            backgroundColor: "#C6EE52",
            borderColor: "#C6EE52",
            borderWidth: 2,
            tension: 0.3,
            fill: false,
          },
        ],
      },
      options: this.getChartOptions(minValue, maxValue),
    });
  }

  renderFoilChart() {
    if (!this.hasFoilChartTarget) return;

    const foilData = this.foilChartTarget.dataset.boxsetValueChartFoil;
    if (!foilData) return;

    let history;
    try {
      history = JSON.parse(foilData);
    } catch (e) {
      console.error("Failed to parse foil value history:", e);
      return;
    }

    if (!history || history.length === 0) return;

    // Destroy existing chart if it exists
    if (this.foilChart) {
      this.foilChart.destroy();
      this.foilChart = null;
    }

    const labels = [];
    const values = [];

    history.forEach((entry) => {
      const date = this.processDate(Object.keys(entry)[0]);
      labels.push(date);
      values.push(Object.values(entry)[0]);
    });

    if (labels.length === 0) return;

    const minValue = Math.min(...values);
    const maxValue = Math.max(...values);

    const canvas = this.foilChartTarget;
    const fixedHeight = 125;
    canvas.style.height = `${fixedHeight}px`;

    this.foilChart = new Chart(canvas.getContext("2d"), {
      type: "line",
      data: {
        labels: labels,
        datasets: [
          {
            label: "Foil Total",
            data: values,
            backgroundColor: "#39DB7D",
            borderColor: "#39DB7D",
            borderWidth: 2,
            tension: 0.3,
            fill: false,
          },
        ],
      },
      options: this.getChartOptions(minValue, maxValue),
    });
  }

  getChartOptions(minValue, maxValue) {
    return {
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
          hoverRadius: 5,
          pointHitRadius: 15,
        },
      },
    };
  }
}
