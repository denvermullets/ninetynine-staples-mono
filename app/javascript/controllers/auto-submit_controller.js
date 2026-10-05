import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="auto-submit"
// Submits the form it sits on, so a GET filter form can apply on change without a button.
// requestSubmit rather than submit() so Turbo sees the submission and drives the frame.
export default class extends Controller {
  submit() {
    this.element.requestSubmit();
  }
}
