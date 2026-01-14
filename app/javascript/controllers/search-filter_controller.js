import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="search-filter"
export default class extends Controller {
  static targets = ["form"];

  setPriceFilter(event) {
    event.preventDefault();
    const button = event.currentTarget;
    const value = button.dataset.value;

    // Update or create hidden field for valuable_only
    let hiddenField = this.formTarget.querySelector('input[name="valuable_only"]');
    if (!hiddenField) {
      hiddenField = document.createElement("input");
      hiddenField.type = "hidden";
      hiddenField.name = "valuable_only";
      this.formTarget.appendChild(hiddenField);
    }
    hiddenField.value = value;

    // Update button styles
    const buttons = button.parentElement.querySelectorAll("button");
    buttons.forEach((btn) => {
      if (btn === button) {
        btn.classList.remove("bg-background", "text-grey-text", "hover:bg-menu");
        btn.classList.add("bg-highlight", "text-nine-white");
      } else {
        btn.classList.remove("bg-highlight", "text-nine-white");
        btn.classList.add("bg-background", "text-grey-text", "hover:bg-menu");
      }
    });

    // Submit the form
    this.formTarget.requestSubmit();
  }

  submitForm() {
    this.formTarget.requestSubmit();
  }

  submit(event) {
    event.preventDefault();

    const currentParams = new URLSearchParams(window.location.search);
    const formData = new FormData(this.formTarget);

    formData.forEach((value, key) => {
      if (key.endsWith("[]")) {
        // prevent duplicates
        if (!currentParams.getAll(key).includes(value)) {
          currentParams.append(key, value);
        }
      } else {
        currentParams.set(key, value);
      }
    });

    const queryString = currentParams.toString();
    const actionUrl = this.formTarget.action.split("?")[0];
    const newUrl = `${actionUrl}?${queryString}`;

    fetch(newUrl, {
      method: "GET",
      headers: {
        Accept: "text/vnd.turbo-stream.html",
      },
    })
      .then((response) => response.text())
      .then((html) => {
        document.querySelector("[id='table-container']").innerHTML = html;

        const usernameValue = currentParams.get("username");
        const collectionId = currentParams.get("collection_id");

        const queryString = new URLSearchParams({
          ...(currentParams.get("code") && { code: currentParams.get("code") }),
          ...(currentParams.get("search") && { search: currentParams.get("search") }),
          ...(currentParams.getAll("rarity[]").length && {
            "rarity[]": currentParams.getAll("rarity[]"),
          }),
          ...(currentParams.getAll("mana[]").length && {
            "mana[]": currentParams.getAll("mana[]"),
          }),
          ...(currentParams.get("valuable_only") && {
            valuable_only: currentParams.get("valuable_only"),
          }),
          ...(currentParams.get("price_change_range") && {
            price_change_range: currentParams.get("price_change_range"),
          }),
        }).toString();

        const basePath = usernameValue ? `/collections/${usernameValue}` : `/boxsets`;
        const fullBasePath = collectionId ? `${basePath}/${collectionId}` : basePath;
        const pushUrl = `${window.location.origin}${fullBasePath}${
          queryString ? `?${queryString}` : ""
        }`;

        history.pushState(null, "", pushUrl);
      });
  }
}
