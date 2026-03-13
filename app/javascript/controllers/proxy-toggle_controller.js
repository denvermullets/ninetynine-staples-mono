import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="proxy-toggle"
export default class extends Controller {
  static targets = ["button", "knob"];

  toggle(event) {
    event.preventDefault();

    const form = document.getElementById("search-form");
    if (!form) return;

    let hiddenField = form.querySelector('input[name="hide_proxies"]');
    if (!hiddenField) {
      hiddenField = document.createElement("input");
      hiddenField.type = "hidden";
      hiddenField.name = "hide_proxies";
      form.appendChild(hiddenField);
    }

    const showingProxies = hiddenField.value === "false";
    hiddenField.value = showingProxies ? "true" : "false";

    // Update toggle switch appearance
    if (hiddenField.value === "false") {
      this.buttonTarget.classList.remove("bg-background", "border", "border-highlight");
      this.buttonTarget.classList.add("bg-highlight");
      this.knobTarget.classList.remove("translate-x-1");
      this.knobTarget.classList.add("translate-x-6");
    } else {
      this.buttonTarget.classList.remove("bg-highlight");
      this.buttonTarget.classList.add("bg-background", "border", "border-highlight");
      this.knobTarget.classList.remove("translate-x-6");
      this.knobTarget.classList.add("translate-x-1");
    }

    this.buttonTarget.setAttribute("aria-checked", hiddenField.value === "false");
    form.requestSubmit();
  }
}
