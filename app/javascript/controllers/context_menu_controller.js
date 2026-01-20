import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["menu"];
  static values = {
    editUrl: String,
    setCommanderUrl: String,
    removeCommanderUrl: String,
    removeUrl: String,
    transferUrl: String,
    swapPrintingUrl: String,
    swapSourceUrl: String,
    frameId: { type: String, default: "deck_modal" },
  };

  connect() {
    this.boundCloseMenu = this.closeMenu.bind(this);
    document.addEventListener("click", this.boundCloseMenu);
    document.addEventListener("contextmenu", this.boundCloseMenu);
  }

  disconnect() {
    document.removeEventListener("click", this.boundCloseMenu);
    document.removeEventListener("contextmenu", this.boundCloseMenu);
  }

  open(event) {
    event.preventDefault();
    event.stopPropagation();

    // Close any other open context menus
    document.querySelectorAll("[data-context-menu-target='menu']").forEach((menu) => {
      if (menu !== this.menuTarget) {
        menu.classList.add("hidden");
      }
    });

    // Position and show the menu
    const menu = this.menuTarget;
    const offset = 10; // Offset to the right of click position
    let x = event.clientX + offset;
    let y = event.clientY;

    menu.style.left = `${x}px`;
    menu.style.top = `${y}px`;
    menu.classList.remove("hidden");

    // Adjust position if menu would go off screen
    const rect = menu.getBoundingClientRect();
    if (rect.right > window.innerWidth) {
      x = event.clientX - rect.width - offset;
      menu.style.left = `${x}px`;
    }
    if (rect.bottom > window.innerHeight) {
      menu.style.top = `${y - rect.height}px`;
    }
  }

  closeMenu(event) {
    if (!this.hasMenuTarget) return;
    if (!this.menuTarget.contains(event.target)) {
      this.menuTarget.classList.add("hidden");
    }
  }

  edit(event) {
    event.preventDefault();
    this.menuTarget.classList.add("hidden");

    const url = this.editUrlValue;
    if (!url) return;

    // Use Turbo's native frame loading for proper modal behavior
    const frame = document.querySelector(`turbo-frame#${this.frameIdValue}`);
    if (frame) {
      frame.src = url;
    }
  }

  setCommander(event) {
    event.preventDefault();
    this.menuTarget.classList.add("hidden");

    const url = this.setCommanderUrlValue;
    if (!url) return;

    fetch(url, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        Accept: "text/vnd.turbo-stream.html",
      },
    })
      .then((response) => {
        if (response.ok) {
          return response.text();
        }
        throw new Error("Failed to set commander");
      })
      .then((html) => {
        Turbo.renderStreamMessage(html);
      })
      .catch((error) => {
        console.error("Error setting commander:", error);
      });
  }

  removeCommander(event) {
    event.preventDefault();
    this.menuTarget.classList.add("hidden");

    const url = this.removeCommanderUrlValue;
    if (!url) return;

    fetch(url, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        Accept: "text/vnd.turbo-stream.html",
      },
    })
      .then((response) => {
        if (response.ok) {
          return response.text();
        }
        throw new Error("Failed to remove commander");
      })
      .then((html) => {
        Turbo.renderStreamMessage(html);
      })
      .catch((error) => {
        console.error("Error removing commander:", error);
      });
  }

  removeCard(event) {
    event.preventDefault();
    this.menuTarget.classList.add("hidden");

    const url = this.removeUrlValue;
    if (!url) return;

    fetch(url, {
      method: "DELETE",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        Accept: "text/vnd.turbo-stream.html",
      },
    })
      .then((response) => {
        if (response.ok) {
          return response.text();
        }
        throw new Error("Failed to remove card");
      })
      .then((html) => {
        Turbo.renderStreamMessage(html);
      })
      .catch((error) => {
        console.error("Error removing card:", error);
      });
  }

  transferCard(event) {
    event.preventDefault();
    this.menuTarget.classList.add("hidden");

    const url = this.transferUrlValue;
    if (!url) return;

    // Open the transfer modal via Turbo frame
    const frame = document.querySelector(`turbo-frame#${this.frameIdValue}`);
    if (frame) {
      frame.src = url;
    }
  }

  swapPrinting(event) {
    event.preventDefault();
    this.menuTarget.classList.add("hidden");

    const url = this.swapPrintingUrlValue;
    if (!url) return;

    // Open the swap printing modal via Turbo frame
    const frame = document.querySelector(`turbo-frame#${this.frameIdValue}`);
    if (frame) {
      frame.src = url;
    }
  }

  swapSource(event) {
    event.preventDefault();
    this.menuTarget.classList.add("hidden");

    const url = this.swapSourceUrlValue;
    if (!url) return;

    // Open the swap source modal via Turbo frame
    const frame = document.querySelector(`turbo-frame#${this.frameIdValue}`);
    if (frame) {
      frame.src = url;
    }
  }
}
