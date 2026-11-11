import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="printing-preview"
// On the deck builder card page, hovering one of the user's copies shows that printing's art, set
// and prices in place of the printing being viewed; clicking pins it there so touch screens, which
// have no hover, can see it too. Clicking the pinned copy again, or leaving it unpinned, puts the
// viewed printing back.
export default class extends Controller {
  static targets = ["front", "back", "setName", "normalPrice", "foilPrice", "foilBlock", "copy"];

  connect() {
    this.original = this.snapshot();
    this.pinned = null;
  }

  preview(event) {
    this.show(this.printingFrom(event.currentTarget));
  }

  restore() {
    this.show(this.pinned ? this.printingFrom(this.pinned) : this.original);
  }

  pin(event) {
    const row = event.currentTarget;
    this.pinned = this.pinned === row ? null : row;

    this.copyTargets.forEach((copy) => {
      const active = copy === this.pinned;
      copy.classList.toggle("bg-highlight", active);
      copy.setAttribute("aria-pressed", active);
    });

    this.restore();
  }

  printingFrom(row) {
    const data = row.dataset;
    return {
      front: data.front,
      back: data.back,
      setName: data.setName,
      normalPrice: data.normalPrice,
      foilPrice: data.foilPrice,
      foilAvailable: data.foilAvailable === "true",
    };
  }

  snapshot() {
    return {
      front: this.hasFrontTarget ? this.frontTarget.src : "",
      back: this.hasBackTarget ? this.backTarget.src : "",
      setName: this.hasSetNameTarget ? this.setNameTarget.textContent : "",
      normalPrice: this.hasNormalPriceTarget ? this.normalPriceTarget.textContent : "",
      foilPrice: this.hasFoilPriceTarget ? this.foilPriceTarget.textContent : "",
      foilAvailable: this.hasFoilBlockTarget && !this.foilBlockTarget.classList.contains("hidden"),
    };
  }

  show(printing) {
    if (this.hasFrontTarget && printing.front) this.frontTarget.src = printing.front;
    if (this.hasBackTarget && printing.back) this.backTarget.src = printing.back;
    if (this.hasSetNameTarget) this.setNameTarget.textContent = printing.setName;
    if (this.hasNormalPriceTarget) this.normalPriceTarget.textContent = printing.normalPrice;
    if (this.hasFoilPriceTarget) this.foilPriceTarget.textContent = printing.foilPrice;
    if (this.hasFoilBlockTarget) this.foilBlockTarget.classList.toggle("hidden", !printing.foilAvailable);
  }
}
