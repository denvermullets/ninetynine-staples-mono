import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="tag-toggle"
export default class extends Controller {
  connect() {
    const checkbox = this.element.parentElement.querySelector('input[type="checkbox"]');
    if (checkbox) {
      checkbox.addEventListener("change", () => this.toggle(checkbox));
    }
  }

  toggle(checkbox) {
    const color = this.element.dataset.color;
    const useLightText = this.element.dataset.lightText === "true";

    if (checkbox.checked) {
      this.element.style.backgroundColor = color;
      this.element.style.borderColor = color;
      this.element.classList.remove("text-grey-text", "border-highlight", "hover:border-accent-50");
      // Use dark text for light backgrounds, white text for dark backgrounds
      if (useLightText) {
        this.element.classList.add("text-foreground");
        this.element.classList.remove("text-white");
      } else {
        this.element.classList.add("text-white");
        this.element.classList.remove("text-foreground");
      }
    } else {
      this.element.style.backgroundColor = "";
      this.element.style.borderColor = "";
      this.element.classList.add("text-grey-text", "border-highlight", "hover:border-accent-50");
      this.element.classList.remove("text-white", "text-foreground");
    }
  }
}
