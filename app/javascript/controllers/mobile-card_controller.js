import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["content", "chevron", "chart", "chartToggle", "chartToggleText", "fullImage"];
  static values = { cardId: String, expanded: Boolean, imageExpanded: Boolean };

  connect() {
    this.expandedValue = false;
    this.imageExpandedValue = false;
  }

  toggle(event) {
    // Don't toggle if clicking on a button, link, select, or within a form
    if (
      event.target.closest("button") ||
      event.target.closest("a") ||
      event.target.closest("select") ||
      event.target.closest("form")
    ) {
      return;
    }

    this.expandedValue = !this.expandedValue;

    if (this.hasContentTarget) {
      if (this.expandedValue) {
        // Expand
        this.contentTarget.classList.remove("hidden");
        this.contentTarget.style.maxHeight = "0px";
        // Force reflow then animate to full height
        requestAnimationFrame(() => {
          this.contentTarget.style.maxHeight = this.contentTarget.scrollHeight + "px";
          // After animation, set to auto for dynamic content (chart, images)
          setTimeout(() => {
            if (this.expandedValue) {
              this.contentTarget.style.maxHeight = "none";
            }
          }, 260);
        });
      } else {
        // Collapse with animation
        this.contentTarget.style.maxHeight = this.contentTarget.scrollHeight + "px";
        // Force reflow
        requestAnimationFrame(() => {
          this.contentTarget.style.maxHeight = "0px";
        });
        // Wait for animation to complete before hiding
        setTimeout(() => {
          if (!this.expandedValue) {
            this.contentTarget.classList.add("hidden");
          }
        }, 260);
      }
    }

    // Rotate chevron
    if (this.hasChevronTarget) {
      this.chevronTarget.style.transform = this.expandedValue
        ? "rotate(180deg)"
        : "rotate(0deg)";
    }
  }

  toggleChart(event) {
    event.stopPropagation();

    if (this.hasChartTarget) {
      const isHidden = this.chartTarget.classList.contains("hidden");

      if (isHidden) {
        this.chartTarget.classList.remove("hidden");
        if (this.hasChartToggleTextTarget) {
          this.chartToggleTextTarget.textContent = "Hide price history";
        }
      } else {
        this.chartTarget.classList.add("hidden");
        if (this.hasChartToggleTextTarget) {
          this.chartToggleTextTarget.textContent = "Show price history";
        }
      }

      // Update content max-height to accommodate chart
      this.updateContentHeight();
    }
  }

  toggleImage(event) {
    event.stopPropagation();

    if (this.hasFullImageTarget) {
      this.imageExpandedValue = !this.imageExpandedValue;

      if (this.imageExpandedValue) {
        this.fullImageTarget.classList.remove("hidden");
      } else {
        this.fullImageTarget.classList.add("hidden");
      }

      // Update content max-height to accommodate image
      this.updateContentHeight();
    }
  }

  updateContentHeight() {
    // No longer needed since we use maxHeight: none after expansion
    // Content will automatically adjust to fit chart/images
  }
}
