import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="rating-slider"
export default class extends Controller {
  static targets = ["slider", "value", "track"];
  static values = {
    min: { type: Number, default: 1 },
    max: { type: Number, default: 10 },
  };

  connect() {
    this.updateDisplay();
  }

  update() {
    this.updateDisplay();
  }

  updateDisplay() {
    const value = parseInt(this.sliderTarget.value, 10);

    // Update value display
    if (this.hasValueTarget) {
      this.valueTarget.textContent = value || "-";
    }

    // Update track color based on value
    if (this.hasTrackTarget) {
      this.trackTarget.style.background = this.getGradient(value);
    }

    // Update slider thumb color
    this.sliderTarget.style.setProperty("--thumb-color", this.getColor(value));
  }

  getColor(value) {
    if (value <= 3) return "#ef4444"; // red
    if (value <= 5) return "#f97316"; // orange
    if (value <= 7) return "#eab308"; // yellow
    return "#22c55e"; // green
  }

  getGradient(value) {
    const percentage = ((value - this.minValue) / (this.maxValue - this.minValue)) * 100;
    const color = this.getColor(value);
    return `linear-gradient(to right, ${color} 0%, ${color} ${percentage}%, #374151 ${percentage}%, #374151 100%)`;
  }
}
