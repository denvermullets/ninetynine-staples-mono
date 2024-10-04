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
        contentRow.scrollIntoView({ behavior: "smooth", block: "start" });
      }
    }
  }
}
