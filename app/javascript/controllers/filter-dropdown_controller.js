import { Controller } from "@hotwired/stimulus";

//
// this is the controller handling the dropdown w/boxset information
//

// Connects to data-controller="filter-dropdown"
export default class extends Controller {
  static targets = ["input", "dropdown", "tableContainer"];
  static values = {
    options: Array,
    url: String,
    username: String,
    collection: String,
    defaultCode: String,
  };

  connect() {
    // if the user is coming from a preloaded url, select the option if found
    // only prefill dropdown if code is explicitly in URL (not from default)
    const urlCode = new URLSearchParams(window.location.search).get("code");

    this.filterOptions(urlCode);
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

  filterOptions(code) {
    // if the user is coming with a param already we just set the dropdown, no need to load
    if (code) {
      const selectedOption = this.optionsValue.find((option) => option.code === code);
      if (selectedOption) {
        this.inputTarget.value = selectedOption.name;
        this.dropdownTarget.classList.add("hidden");
        return;
      }
    }

    const query = this.inputTarget.value.toLowerCase();
    const filteredOptions = this.optionsValue.filter(
      (option) =>
        option.name.toLowerCase().includes(query) || option.code.toLowerCase().includes(query)
    );
    this.dropdownTarget.innerHTML = this.optionsTemplate(filteredOptions);
  }

  select(event) {
    const selectedName = event.target.textContent.trim();
    const selectedOption = this.optionsValue.find((option) => option.name === selectedName);
    this.inputTarget.value = selectedName;
    this.dropdownTarget.classList.add("hidden");

    // trigger Turbo request to load table data
    this.loadTableData(selectedOption.code);
  }

  optionsTemplate(options) {
    if (options.length === 0) {
      return '<div class="p-2 text-gray-500">No results found</div>';
    }

    return options
      .map(
        (option) => `
      <div class="p-2 w-auto hover:bg-foreground cursor-pointer flex items-center text-grey-text" data-action="click->filter-dropdown#select">
        <i class="ss ss-${option.keyrune_code} ss-fw ss-2x mr-2 m-0 text-grey-text" style="margin-inline-start: 0 !important;"></i>${option.name}
      </div>
    `
      )
      .join("");
  }

  loadTableData(code) {
    // handling if there's params on the url and then push the history
    const currentParams = new URLSearchParams(window.location.search);
    const queryParams = new URLSearchParams({
      code,
      ...(currentParams.get("search") && { search: currentParams.get("search") }),
      ...(currentParams.get("valuable_only") && {
        valuable_only: currentParams.get("valuable_only"),
      }),
      ...(this.usernameValue && { username: this.usernameValue }),
    }).toString();

    const url = `${this.urlValue}?${queryParams}`;

    fetch(url)
      .then((response) => response.text())
      .then((html) => {
        Turbo.renderStreamMessage(html);

        // lots of logic to set the url, lol
        const updatedParams = new URLSearchParams({
          code: code,
          ...(currentParams.get("search") && { search: currentParams.get("search") }),
          ...(currentParams.get("valuable_only") && {
            valuable_only: currentParams.get("valuable_only"),
          }),
        }).toString();

        const basePath = this.usernameValue ? `/collections/${this.usernameValue}` : `/boxsets`;
        const fullBasePath = this.collectionValue
          ? `${basePath}/${this.collectionValue}`
          : basePath;
        const pushUrl = `${window.location.origin}${fullBasePath}${
          updatedParams ? `?${updatedParams}` : ""
        }`;

        history.pushState(null, "", pushUrl);
      });
  }
}
