import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="filter-dropdown"
export default class extends Controller {
  static targets = ["input", "dropdown", "tableContainer"];
  static values = {
    options: Array,
    url: String,
  };

  connect() {
    this.filterOptions();
    this.boundHandleClickOutside = this.handleClickOutside.bind(this);
  }

  openDropdown() {
    this.dropdownTarget.classList.remove("hidden");
    // Add click event listener to the document
    document.addEventListener("click", this.boundHandleClickOutside);
  }

  closeDropdown() {
    this.dropdownTarget.classList.add("hidden");
    // Remove click event listener from the document
    document.removeEventListener("click", this.boundHandleClickOutside);
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.closeDropdown();
    }
  }

  toggle() {
    if (this.dropdownTarget.classList.contains("hidden")) {
      this.openDropdown();
    } else {
      this.closeDropdown();
    }
  }

  search() {
    this.filterOptions();
    this.dropdownTarget.classList.remove("hidden");
  }

  filterOptions() {
    const query = this.inputTarget.value.toLowerCase();
    const filteredOptions = this.optionsValue.filter(
      (option) =>
        option.name.toLowerCase().includes(query) || option.code.toLowerCase().includes(query)
    );
    this.dropdownTarget.innerHTML = this.optionsTemplate(filteredOptions);
  }

  select(event) {
    const selectedName = event.target.textContent.trim();
    console.log("selectedName: ", selectedName);
    console.log("this.optionsValue: ", this.optionsValue);
    const selectedOption = this.optionsValue.find((option) => option.name === selectedName);
    this.inputTarget.value = selectedName;
    this.dropdownTarget.classList.add("hidden");

    // Trigger Turbo request to load table data

    console.log("selectedOption: ", selectedOption);
    this.loadTableData(selectedOption.code);
  }

  optionsTemplate(options) {
    if (options.length === 0) {
      return '<div class="p-2 text-gray-500">No results found</div>';
    }

    return options
      .map(
        (option) => `
      <div class="p-2 hover:bg-gray-100 cursor-pointer" data-action="click->filter-dropdown#select">
        ${option.name}
      </div>
    `
      )
      .join("");
  }

  loadTableData(code) {
    console.log("urlVal", this.urlValue);
    const url = `${this.urlValue}?code=${code}`;

    fetch(url)
      .then((response) => response.text())
      .then((html) => {
        console.log("?", html);
        Turbo.renderStreamMessage(html);
      });
  }
}
