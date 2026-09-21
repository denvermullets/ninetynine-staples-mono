import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="deck-compare"
//
// Nothing about a comparison is saved, so the form is the state: every option
// change writes into it and re-submits it, and Turbo renders the stream that
// comes back. Tab switching is the one thing that costs no request.
export default class extends Controller {
  static targets = [
    "form",
    "viewModeInput",
    "tabInput",
    "sourceInput",
    "sourceButton",
    "sourcePanel",
    "cardPreview",
    "cardPreviewName",
    "tab",
    "pane",
  ];

  static activeClasses = ["bg-accent-50/20", "text-accent-50", "border-accent-50"];

  toggleSource(event) {
    const { side, source } = event.currentTarget.dataset;
    const onSide = (element) => element.dataset.side === side;

    this.sourceInputTargets.filter(onSide).forEach((input) => {
      input.value = source;
    });
    this.sourcePanelTargets.filter(onSide).forEach((panel) => {
      panel.classList.toggle("hidden", panel.dataset.source !== source);
    });
    this.sourceButtonTargets.filter(onSide).forEach((button) => {
      this.setActive(button, button.dataset.source === source);
    });
  }

  // bound to the grouping and sort selects, which sit outside the form and
  // join it with the form="deck_compare_form" attribute
  changeOption() {
    this.formTarget.requestSubmit();
  }

  setViewMode(event) {
    this.viewModeInputTarget.value = event.currentTarget.dataset.mode;
    this.formTarget.requestSubmit();
  }

  // written to the form as well, so the next re-submit comes back on this tab
  switchTab(event) {
    const tab = event.currentTarget.dataset.tab;
    this.tabInputTarget.value = tab;

    this.paneTargets.forEach((pane) => {
      pane.classList.toggle("hidden", pane.dataset.tab !== tab);
    });
    this.tabTargets.forEach((button) => {
      this.setActive(button, button.dataset.tab === tab);
    });
  }

  previewCard(event) {
    const imageUrl = event.currentTarget.dataset.cardImage;
    const cardName = event.currentTarget.dataset.cardName;

    if (this.hasCardPreviewTarget && imageUrl) {
      this.cardPreviewTarget.src = imageUrl;
      this.cardPreviewTarget.classList.remove("hidden");
    }

    if (this.hasCardPreviewNameTarget && cardName) {
      this.cardPreviewNameTarget.textContent = cardName;
    }
  }

  setActive(element, active) {
    this.constructor.activeClasses.forEach((name) => {
      element.classList.toggle(name, active);
    });
    element.classList.toggle("text-grey-text", !active);
  }
}
