import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["content"];

  toggle(event) {
    const cardId = event.currentTarget.dataset.cardId;

    const contentRow = this.contentTargets.find((content) => {
      return content.dataset.cardId === cardId;
    });

    if (contentRow) {
      contentRow.classList.toggle("hidden");

      if (!contentRow.classList.contains("hidden")) {
        // leaving some room so the scroll isn't just to the TOP
        const offset = 100;
        const elementPosition = contentRow.getBoundingClientRect().top + window.scrollY;
        const offsetPosition = elementPosition - offset;

        window.scrollTo({ top: offsetPosition, behavior: "smooth" });
      }
    }
  }
}
