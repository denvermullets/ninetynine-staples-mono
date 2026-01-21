import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="choose-printing"
export default class extends Controller {
  select(event) {
    const button = event.currentTarget;
    const printingId = button.dataset.printingId;
    const printingName = button.dataset.printingName;
    const printingImage = button.dataset.printingImage;
    const printingSet = button.dataset.printingSet;

    // Dispatch a global event with the selected printing data
    window.dispatchEvent(
      new CustomEvent("printing:selected", {
        detail: {
          printingId,
          printingName,
          printingImage,
          printingSet,
        },
      })
    );

    // Close the modal
    const dialog = this.element.closest("dialog");
    if (dialog) {
      dialog.close();
    }
  }
}
