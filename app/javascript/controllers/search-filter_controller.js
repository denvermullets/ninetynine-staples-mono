import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="search-filter"
export default class extends Controller {
  static targets = ["form"];

  submit(event) {
    event.preventDefault();

    const currentParams = new URLSearchParams(window.location.search);
    console.log("currentParams: ", currentParams);

    const formData = new FormData(this.formTarget);
    formData.forEach((value, key) => {
      console.log("params ;", key, value);
      currentParams.set(key, value);
    });
    console.log("formData: ", formData);

    const queryString = currentParams.toString();
    console.log("queryString: ", queryString);
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
        const queryString = new URLSearchParams({
          ...(currentParams.get("code") && { code: currentParams.get("code") }),
          ...(currentParams.get("search") && { search: currentParams.get("search") }),
        }).toString();

        const basePath = usernameValue ? `/collections/${usernameValue}` : `/boxsets`;
        const pushUrl = `${window.location.origin}${basePath}${
          queryString ? `?${queryString}` : ""
        }`;

        history.pushState(null, "", pushUrl);
      });
  }
}
