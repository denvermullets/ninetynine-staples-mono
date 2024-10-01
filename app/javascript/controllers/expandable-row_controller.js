import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["content"];

  toggle(event) {
    // Get the card ID from the clicked element
    console.log("hi");
    const cardId = event.currentTarget.dataset.cardId;
    console.log("cardId: ", cardId);

    // Find the corresponding content target that matches the card ID
    const contentRow = this.contentTargets.find((content) => {
      return content.dataset.cardId === cardId;
    });
    console.log("contentRow: ", contentRow);

    // Toggle the visibility of the matching content row
    if (contentRow) {
      contentRow.classList.toggle("hidden");
    }
  }
}
