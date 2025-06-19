import { Controller } from "@hotwired/stimulus";

// connects to data-controller="multiselect"
export default class extends Controller {
  static targets = ["item"]; // Elements that represent selectable options

  connect() {
    // tracks selection state per group as { groupName: Set(values) }
    this.selected = {};
    // ensures form submission context regardless of controller nesting
    this.form = this.element.closest("form");
    // target location for syncing selections to actual form inputs
    this.hiddenFieldsContainer = this.form.querySelector("#filter-hidden-fields");

    // prepopulate the `selected` structure based on declared groups, preparing for future interaction
    this.itemTargets.forEach((item) => {
      const group = item.dataset.multiselectGroup;
      if (!this.selected[group]) {
        // avoids conditionally handling undefined groups later on
        this.selected[group] = new Set();
      }
    });
  }

  toggle(event) {
    const item = event.currentTarget;
    const group = item.dataset.multiselectGroup;
    const value = item.dataset.value;

    // defensive check to ensure structural integrity of the DOM
    // outlines div where there's a markup misconfiguration
    if (!group || !value) {
      console.warn("🚨 Invalid multiselect item clicked", {
        element: item,
        group,
        value,
      });
      item.style.outline = "2px solid red";
      return;
    }

    // lazily initialize group if somehow it wasn't prepared on connect (e.g., dynamically injected content)
    if (!this.selected[group]) {
      this.selected[group] = new Set();
    }

    const groupSet = this.selected[group];

    // toggling logic that also manages visual feedback to reflect selection state
    if (groupSet.has(value)) {
      groupSet.delete(value);
      // removing highlight
      item.classList.remove("accent-50");
    } else {
      groupSet.add(value);
      // marks selected item
      item.classList.add("accent-50");
    }

    // resyncs form input representation with internal state
    this.updateHiddenFields();
    // forces form submission (triggers turbo reload)
    this.form.requestSubmit();
  }

  updateHiddenFields() {
    // clears previous state to avoid duplicate inputs
    this.hiddenFieldsContainer.innerHTML = "";

    // converts the internal selection map into hidden input fields that standard form submission can serialize
    for (const group in this.selected) {
      this.selected[group].forEach((value) => {
        const input = document.createElement("input");
        input.type = "hidden";
        // enables multiple selections per group in conventional form POST
        input.name = `${group}[]`;
        input.value = value;
        // ensures selections persist when submitted
        this.hiddenFieldsContainer.appendChild(input);
      });
    }
  }
}
