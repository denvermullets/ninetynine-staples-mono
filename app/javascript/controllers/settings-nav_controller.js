import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="settings-nav"
// Sidebar sections on the settings page: one panel shows at a time and the section lives in the URL
// hash so a reload or shared link lands on the same one.
export default class extends Controller {
  static targets = ["link", "panel"];
  static classes = ["active"];

  connect() {
    const section = window.location.hash.slice(1);
    if (this.panelTargets.some((panel) => panel.dataset.section === section)) this.show(section);
  }

  select(event) {
    event.preventDefault();
    const { section } = event.currentTarget.dataset;

    this.show(section);
    history.replaceState(history.state, "", `#${section}`);
  }

  show(section) {
    this.panelTargets.forEach((panel) => {
      panel.classList.toggle("hidden", panel.dataset.section !== section);
    });

    this.linkTargets.forEach((link) => {
      const active = link.dataset.section === section;
      this.activeClasses.forEach((name) => link.classList.toggle(name, active));
      if (active) link.setAttribute("aria-current", "page");
      else link.removeAttribute("aria-current");
    });
  }
}
