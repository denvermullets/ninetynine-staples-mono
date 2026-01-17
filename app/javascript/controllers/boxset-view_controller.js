import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["groupingSelect", "tableButton", "visualButton"];
  static values = {
    viewMode: { type: String, default: "table" },
    grouping: { type: String, default: "none" },
    groupingAllowed: { type: Boolean, default: false },
    loadPath: String,
  };

  connect() {
    this.updateButtonStyles();
    this.updateGroupingVisibility();
  }

  setViewMode(event) {
    const newMode = event.currentTarget.dataset.viewMode;
    if (newMode === this.viewModeValue) return;

    this.viewModeValue = newMode;
    this.updateButtonStyles();
    this.updateGroupingVisibility();
    this.refreshBoxset();
  }

  changeGrouping(event) {
    this.groupingValue = event.target.value;
    this.refreshBoxset();
  }

  updateButtonStyles() {
    const activeClasses = ["bg-highlight", "text-nine-white"];
    const inactiveClasses = ["bg-background", "text-grey-text", "hover:bg-menu"];

    [this.tableButtonTarget, this.visualButtonTarget].forEach((button, index) => {
      if (!button) return;
      const isActive =
        (index === 0 && this.viewModeValue === "table") ||
        (index === 1 && this.viewModeValue === "visual");

      if (isActive) {
        button.classList.remove(...inactiveClasses);
        button.classList.add(...activeClasses);
      } else {
        button.classList.remove(...activeClasses);
        button.classList.add(...inactiveClasses);
      }
    });
  }

  updateGroupingVisibility() {
    const container = document.getElementById("grouping-container");
    if (container) {
      // Only show grouping when in visual mode AND a boxset is selected
      const shouldShow = this.viewModeValue === "visual" && this.groupingAllowedValue;
      container.classList.toggle("hidden", !shouldShow);
    }
  }

  refreshBoxset() {
    const currentParams = new URLSearchParams(window.location.search);

    // Get code from URL or from data attribute (for default boxset)
    const code = currentParams.get("code") || this.element.dataset.boxsetViewDefaultCode;

    const queryParams = new URLSearchParams({
      view_mode: this.viewModeValue,
      ...(this.viewModeValue === "visual" && { grouping: this.groupingValue }),
      ...(currentParams.get("search") && { search: currentParams.get("search") }),
      ...(code && { code: code }),
      ...(currentParams.get("valuable_only") && { valuable_only: currentParams.get("valuable_only") }),
      ...(currentParams.get("sort") && { sort: currentParams.get("sort") }),
      ...(currentParams.get("direction") && { direction: currentParams.get("direction") }),
    }).toString();

    const url = `${this.loadPathValue}?${queryParams}`;

    fetch(url, {
      headers: {
        Accept: "text/vnd.turbo-stream.html",
      },
    })
      .then((response) => response.text())
      .then((html) => {
        Turbo.renderStreamMessage(html);

        // Update browser URL
        const updatedParams = new URLSearchParams(window.location.search);
        updatedParams.set("view_mode", this.viewModeValue);
        if (this.viewModeValue === "visual") {
          updatedParams.set("grouping", this.groupingValue);
        } else {
          updatedParams.delete("grouping");
        }

        const pushUrl = `${window.location.pathname}?${updatedParams.toString()}`;
        history.pushState(null, "", pushUrl);
      });
  }
}
