import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="commander-filter"
export default class extends Controller {
  static targets = ["ownedButton"];

  toggleOwned(event) {
    event.preventDefault();
    const button = event.currentTarget;
    const currentParams = new URLSearchParams(window.location.search);
    const isCurrentlyOwned = currentParams.get("owned_only") === "true";

    // Toggle the owned_only parameter
    if (isCurrentlyOwned) {
      currentParams.delete("owned_only");
      button.classList.remove("bg-highlight", "text-nine-white");
      button.classList.add("bg-background", "text-grey-text", "hover:bg-menu");
    } else {
      currentParams.set("owned_only", "true");
      button.classList.remove("bg-background", "text-grey-text", "hover:bg-menu");
      button.classList.add("bg-highlight", "text-nine-white");
    }

    // Build the URL for the fetch request
    const queryString = currentParams.toString();
    const fetchUrl = `/load_commanders${queryString ? `?${queryString}` : ""}`;

    fetch(fetchUrl, {
      method: "GET",
      headers: {
        Accept: "text/vnd.turbo-stream.html",
      },
    })
      .then((response) => response.text())
      .then((html) => {
        Turbo.renderStreamMessage(html);

        // Update browser URL
        const pushUrl = `/commanders${queryString ? `?${queryString}` : ""}`;
        history.pushState(null, "", pushUrl);
      });
  }
}
