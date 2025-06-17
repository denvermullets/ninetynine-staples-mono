// Connects to data-controller="multiselect"
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["item"];

  connect() {
    this.selected = {
      rarity: new Set(),
      mana: new Set(),
    };
  }

  toggle(event) {
    const item = event.currentTarget;
    const group = item.dataset.multiselectGroup;
    const value = item.dataset.value;

    const groupSet = this.selected[group];
    if (groupSet.has(value)) {
      groupSet.delete(value);
      item.classList.remove("accent-50");
    } else {
      groupSet.add(value);
      item.classList.add("accent-50");
    }

    this.submitForm(group);
  }

  submitForm(group) {
    const form = document.createElement("form");
    form.method = "GET";
    form.action = `/cards/filter_${group}`;
    form.setAttribute("data-turbo-frame", `${group}_filters`);

    this.selected[group].forEach((value) => {
      const input = document.createElement("input");
      input.type = "hidden";
      input.name = `${group}[]`;
      input.value = value;
      form.appendChild(input);
    });

    document.body.appendChild(form);
    form.submit();
    form.remove();
  }
}
