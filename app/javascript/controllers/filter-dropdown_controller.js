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
    this.highlightedIndex = -1;
  }

  handleKeydown(event) {
    // Open dropdown and populate options if not already open
    if (this.dropdownTarget.classList.contains("hidden")) {
      if (event.key === "ArrowDown" || event.key === "ArrowUp") {
        event.preventDefault();
        this.filterOptions();
        this.openDropdown();
        // Set initial highlight on first option for ArrowDown
        if (event.key === "ArrowDown") {
          this.highlightedIndex = 0;
        } else {
          // ArrowUp starts from the last option
          const options = this.dropdownTarget.querySelectorAll("[data-action='click->filter-dropdown#select']");
          this.highlightedIndex = options.length - 1;
        }
        const options = this.dropdownTarget.querySelectorAll("[data-action='click->filter-dropdown#select']");
        this.updateHighlight(options);
        return;
      }
    }

    const options = this.dropdownTarget.querySelectorAll("[data-action='click->filter-dropdown#select']");
    if (options.length === 0) return;

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault();
        this.highlightedIndex = (this.highlightedIndex + 1) % options.length;
        this.updateHighlight(options);
        break;
      case "ArrowUp":
        event.preventDefault();
        this.highlightedIndex = this.highlightedIndex <= 0 ? options.length - 1 : this.highlightedIndex - 1;
        this.updateHighlight(options);
        break;
      case "Enter":
        event.preventDefault();
        if (this.highlightedIndex >= 0 && options[this.highlightedIndex]) {
          options[this.highlightedIndex].click();
        }
        break;
      case "Escape":
        event.preventDefault();
        this.closeDropdown();
        break;
    }
  }

  updateHighlight(options) {
    options.forEach((option, index) => {
      if (index === this.highlightedIndex) {
        option.classList.add("bg-highlight");
        option.scrollIntoView({ block: "nearest" });
      } else {
        option.classList.remove("bg-highlight");
      }
    });
  }

  openDropdown() {
    this.dropdownTarget.classList.remove("hidden");
    this.highlightedIndex = -1;
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
    this.highlightedIndex = -1;
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
    const isCommandersPage = window.location.pathname.includes("/commanders");

    const queryParams = new URLSearchParams({
      code,
      ...(currentParams.get("search") && { search: currentParams.get("search") }),
      ...(currentParams.get("valuable_only") && {
        valuable_only: currentParams.get("valuable_only"),
      }),
      ...(currentParams.get("owned_only") && {
        owned_only: currentParams.get("owned_only"),
      }),
      ...(currentParams.get("sort") && { sort: currentParams.get("sort") }),
      ...(currentParams.get("direction") && { direction: currentParams.get("direction") }),
      ...(currentParams.get("view_mode") && { view_mode: currentParams.get("view_mode") }),
      ...(currentParams.get("grouping") && { grouping: currentParams.get("grouping") }),
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
          ...(currentParams.get("owned_only") && {
            owned_only: currentParams.get("owned_only"),
          }),
          ...(currentParams.get("sort") && { sort: currentParams.get("sort") }),
          ...(currentParams.get("direction") && { direction: currentParams.get("direction") }),
          ...(currentParams.get("view_mode") && { view_mode: currentParams.get("view_mode") }),
          ...(currentParams.get("grouping") && { grouping: currentParams.get("grouping") }),
        }).toString();

        let basePath;
        if (isCommandersPage) {
          basePath = `/commanders`;
        } else if (this.usernameValue) {
          basePath = `/collections/${this.usernameValue}`;
        } else {
          basePath = `/boxsets`;
        }
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
