import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["sidebar", "overlay"];

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
