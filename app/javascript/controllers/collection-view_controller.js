import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["statsBar", "groupingSelect", "tableButton", "visualButton"];
  static values = {
    viewMode: { type: String, default: "table" },
    grouping: { type: String, default: "none" },
    loadPath: String,
    username: String,
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
    this.updateStatsBarVisibility();
    this.refreshCollection();
  }

  changeGrouping(event) {
    this.groupingValue = event.target.value;
    this.refreshCollection();
  }

  updateButtonStyles() {
    const activeClasses = ["bg-highlight", "text-nine-white"];
    const inactiveClasses = ["bg-background", "text-grey-text", "hover:bg-menu"];

    if (this.hasTableButtonTarget) {
      if (this.viewModeValue === "table") {
        this.tableButtonTarget.classList.remove(...inactiveClasses);
        this.tableButtonTarget.classList.add(...activeClasses);
      } else {
        this.tableButtonTarget.classList.remove(...activeClasses);
        this.tableButtonTarget.classList.add(...inactiveClasses);
      }
    }

    if (this.hasVisualButtonTarget) {
      if (this.viewModeValue === "visual") {
        this.visualButtonTarget.classList.remove(...inactiveClasses);
        this.visualButtonTarget.classList.add(...activeClasses);
      } else {
        this.visualButtonTarget.classList.remove(...activeClasses);
        this.visualButtonTarget.classList.add(...inactiveClasses);
      }
    }
  }

  updateGroupingVisibility() {
    if (this.hasGroupingSelectTarget) {
      const container = this.groupingSelectTarget.closest(".grouping-container");
      if (container) {
        container.classList.toggle("hidden", this.viewModeValue !== "visual");
      }
    }
  }

  updateStatsBarVisibility() {
    if (this.hasStatsBarTarget) {
      this.statsBarTarget.classList.toggle("hidden", this.viewModeValue === "visual");
    }
  }

  refreshCollection() {
    const currentParams = new URLSearchParams(window.location.search);

    // Build query params like filter-dropdown does
    const queryParams = new URLSearchParams({
      view_mode: this.viewModeValue,
      ...(this.viewModeValue === "visual" && { grouping: this.groupingValue }),
      ...(this.usernameValue && { username: this.usernameValue }),
      ...(currentParams.get("search") && { search: currentParams.get("search") }),
      ...(currentParams.get("code") && { code: currentParams.get("code") }),
      ...(currentParams.get("collection_id") && { collection_id: currentParams.get("collection_id") }),
      ...(currentParams.get("valuable_only") && { valuable_only: currentParams.get("valuable_only") }),
      ...(currentParams.get("sort") && { sort: currentParams.get("sort") }),
      ...(currentParams.get("direction") && { direction: currentParams.get("direction") }),
    }).toString();

    const url = `${this.loadPathValue}?${queryParams}`;

    fetch(url)
      .then((response) => response.text())
      .then((html) => {
        Turbo.renderStreamMessage(html);

        // Update hidden form fields
        this.updateHiddenFormFields();

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

  updateHiddenFormFields() {
    const searchForm = document.getElementById("search-form");
    if (!searchForm) return;

    const viewModeField = searchForm.querySelector('input[name="view_mode"]');
    const groupingField = searchForm.querySelector('input[name="grouping"]');

    if (viewModeField) {
      viewModeField.value = this.viewModeValue;
    }
    if (groupingField) {
      groupingField.value = this.viewModeValue === "visual" ? this.groupingValue : "";
    }
  }
}
