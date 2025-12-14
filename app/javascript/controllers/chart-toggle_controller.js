import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["chart", "button"];

  toggle() {
    this.chartTarget.classList.toggle("hidden");

    // Optional: Change button appearance when chart is visible
    if (this.chartTarget.classList.contains("hidden")) {
      this.buttonTarget.classList.remove("bg-highlight");
      this.buttonTarget.classList.add("bg-foreground");
    } else {
      this.buttonTarget.classList.remove("bg-foreground");
      this.buttonTarget.classList.add("bg-highlight");
    }
  }
}
