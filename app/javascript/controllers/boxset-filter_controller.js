import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="boxset-filter"
export default class extends Controller {
  static targets = ["form"];

  submit(event) {
    event.preventDefault();

    const currentParams = new URLSearchParams(window.location.search);

    const formData = new FormData(this.formTarget);
    formData.forEach((value, key) => {
      currentParams.set(key, value);
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
        history.pushState(null, "", `${window.location.origin}/boxsets?${queryString}`);
      });
  }
}
