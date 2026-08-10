import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["sidebar", "overlay"];

  connect() {
    this.boundHandleKeydown = this.handleKeydown.bind(this);
    document.addEventListener("keydown", this.boundHandleKeydown);
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleKeydown);
  }

  handleKeydown(event) {
    if (event.key !== "Escape") return;
    if (this.overlayTarget.classList.contains("hidden")) return;

    this.close();
  }

  toggle() {
    this.sidebarTarget.classList.toggle("hidden");
    this.sidebarTarget.classList.toggle("flex");
    this.overlayTarget.classList.toggle("hidden");
  }

  close() {
    this.sidebarTarget.classList.add("hidden");
    this.sidebarTarget.classList.remove("flex");
    this.overlayTarget.classList.add("hidden");
  }
}
