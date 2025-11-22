import { Controller } from "@hotwired/stimulus";

//
// this controller handles the selection of rarity and/or color filters
// connects to data-controller="multiselect"
//

export default class extends Controller {
  static targets = ["item"]; // Elements that represent selectable options

  connect() {
    // tracks selection state per group as { groupName: Set(values) }
    this.selected = {};
    // ensures form submission context regardless of controller nesting
    this.form = this.element.closest("form");
    // target location for syncing selections to actual form inputs
    this.hiddenFieldsContainer = this.form.querySelector("#filter-hidden-fields");

    // get current URL params to restore selection state
    const urlParams = new URLSearchParams(window.location.search);

    // prepopulate the `selected` structure based on declared groups, preparing for future interaction
    this.itemTargets.forEach((item) => {
      const group = item.dataset.multiselectGroup;
      const value = item.dataset.value;

      if (!this.selected[group]) {
        // avoids conditionally handling undefined groups later on
        this.selected[group] = new Set();
      }

      // restore selection state from URL params
      // handle both array params (?rarity[]=a&rarity[]=b) and comma-separated (?rarity[]=a,b)
      const paramValues = urlParams.getAll(`${group}[]`).flatMap(v => v.split(','));
      if (paramValues.includes(value)) {
        this.selected[group].add(value);
        item.dataset.selected = "";
        console.log(`Restored: ${group}=${value}`);
      }
    });

    // sync hidden fields with restored state
    this.updateHiddenFields();
  }

  toggle(event) {
    let item = event.currentTarget;

    // In case click came from inside (like <i>), find the actual button
    if (!item.dataset.multiselectGroup || !item.dataset.value) {
      item = item.closest("[data-multiselect-target='item']");
    }

    const group = item.dataset.multiselectGroup;
    const value = item.dataset.value;

    // defensive check to ensure structural integrity of the DOM
    if (!group || !value) {
      console.warn("🚨 Invalid multiselect item clicked", { element: item, group, value });
      item.style.outline = "2px solid red";
      return;
    }

    // lazily initialize group if somehow it wasn't prepared on connect
    if (!this.selected[group]) {
      this.selected[group] = new Set();
    }

    const groupSet = this.selected[group];
    const isSelected = groupSet.has(value);

    console.log(`Toggle: ${group}=${value}, wasSelected=${isSelected}, setSize=${groupSet.size}`);

    // toggling logic that also manages visual feedback to reflect selection state
    if (isSelected) {
      groupSet.delete(value);
      delete item.dataset.selected;
    } else {
      groupSet.add(value);
      item.dataset.selected = "";
    }

    console.log(`After toggle: setSize=${groupSet.size}, values=${Array.from(groupSet).join(',')}`);

    // clear URL params to prevent Turbo from merging them with form submission
    const cleanUrl = window.location.pathname;
    history.replaceState(null, '', cleanUrl);

    // resyncs form input representation with internal state
    this.updateHiddenFields();
    // forces form submission (triggers turbo reload)
    this.form.requestSubmit();
  }

  updateHiddenFields() {
    // clears previous state to avoid duplicate inputs
    this.hiddenFieldsContainer.innerHTML = "";

    // also remove any existing hidden fields for our groups from the entire form
    for (const group in this.selected) {
      const existingFields = this.form.querySelectorAll(`input[type="hidden"][name="${group}[]"]`);
      existingFields.forEach(field => {
        if (field.parentElement !== this.hiddenFieldsContainer) {
          field.remove();
          console.log(`Removed existing hidden field: ${group}[]`);
        }
      });
    }

    // converts the internal selection map into hidden input fields
    // uses single comma-separated value per group to avoid browser/Turbo duplication
    for (const group in this.selected) {
      const values = Array.from(this.selected[group]);
      if (values.length > 0) {
        const input = document.createElement("input");
        input.type = "hidden";
        input.name = `${group}[]`;
        input.value = values.join(',');
        this.hiddenFieldsContainer.appendChild(input);
        console.log(`Hidden field created: ${group}[]=${values.join(',')}`);
      } else {
        console.log(`No hidden field for ${group} (empty)`);
      }
    }
  }
}
