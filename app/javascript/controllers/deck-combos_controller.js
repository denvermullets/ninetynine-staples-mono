import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["combo", "filterBtn", "cardImage"];
  static values = { filter: { type: String, default: "all" } };

  filter(event) {
    const value = event.currentTarget.dataset.filter;
    this.filterValue = value;
    this.applyFilter();
    this.updateFilterButtons();
  }

  toggle(event) {
    const comboEl = event.currentTarget.closest("[data-combo-type]");
    const body = comboEl.querySelector("[data-combo-body]");
    const chevron = event.currentTarget.querySelector("[data-chevron]");

    if (body.classList.contains("hidden")) {
      body.classList.remove("hidden");
      chevron?.classList.add("rotate-180");
    } else {
      body.classList.add("hidden");
      chevron?.classList.remove("rotate-180");
    }
  }

  toggleCard(event) {
    event.stopPropagation();
    const img = event.currentTarget;
    const isDesktop = window.matchMedia("(min-width: 768px)").matches;

    // Mobile: w-24 (small) <-> w-56 (large)
    // Desktop: md:w-56 (large default) <-> shrink to w-24 then back
    if (isDesktop) {
      if (img.classList.contains("md:w-56")) {
        img.classList.remove("md:w-56");
        img.classList.add("md:w-24");
      } else {
        img.classList.remove("md:w-24");
        img.classList.add("md:w-56");
      }
    } else {
      if (img.classList.contains("w-24")) {
        img.classList.remove("w-24");
        img.classList.add("w-56");
      } else {
        img.classList.remove("w-56");
        img.classList.add("w-24");
      }
    }
  }

  applyFilter() {
    this.comboTargets.forEach((el) => {
      const type = el.dataset.comboType;
      if (this.filterValue === "all") {
        el.classList.remove("hidden");
      } else if (this.filterValue === "complete" && type === "included") {
        el.classList.remove("hidden");
      } else if (
        this.filterValue === "missing" &&
        type === "almost_included"
      ) {
        el.classList.remove("hidden");
      } else {
        el.classList.add("hidden");
      }
    });
  }

  updateFilterButtons() {
    this.filterBtnTargets.forEach((btn) => {
      const isActive = btn.dataset.filter === this.filterValue;
      if (isActive) {
        btn.classList.add("bg-accent-50/20", "text-accent-50", "border-accent-50/50");
        btn.classList.remove("text-grey-text", "border-highlight");
      } else {
        btn.classList.remove("bg-accent-50/20", "text-accent-50", "border-accent-50/50");
        btn.classList.add("text-grey-text", "border-highlight");
      }
    });
  }
}
