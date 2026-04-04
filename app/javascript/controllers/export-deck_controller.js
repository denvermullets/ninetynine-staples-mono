import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["textarea", "status"];

  async copy() {
    const text = this.textareaTarget.value;

    try {
      await navigator.clipboard.writeText(text);
      this.statusTarget.classList.remove("hidden");
      setTimeout(() => this.statusTarget.classList.add("hidden"), 2000);
    } catch {
      // Fallback: select text so user can copy manually
      this.textareaTarget.select();
    }
  }
}
