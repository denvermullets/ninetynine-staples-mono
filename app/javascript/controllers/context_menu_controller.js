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
    editStagedUrl: String,
    viewCardUrl: String,
    viewCombosUrl: String,
    findReplacementsUrl: String,
    changeCardTypeUrl: String,
    deleteUrl: String,
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
    event.stopPropagation();
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
    event.stopPropagation();
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
    event.stopPropagation();
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
    event.stopPropagation();
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
    event.stopPropagation();
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
    event.stopPropagation();
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
    event.stopPropagation();
    this.menuTarget.classList.add("hidden");

    const url = this.swapSourceUrlValue;
    if (!url) return;

    // Open the swap source modal via Turbo frame
    const frame = document.querySelector(`turbo-frame#${this.frameIdValue}`);
    if (frame) {
      frame.src = url;
    }
  }

  editStaged(event) {
    event.preventDefault();
    event.stopPropagation();
    this.menuTarget.classList.add("hidden");

    const url = this.editStagedUrlValue;
    if (!url) return;

    // Open the edit staged modal via Turbo frame
    const frame = document.querySelector(`turbo-frame#${this.frameIdValue}`);
    if (frame) {
      frame.src = url;
    }
  }

  viewCard(event) {
    event.preventDefault();
    event.stopPropagation();
    this.menuTarget.classList.add("hidden");

    const url = this.viewCardUrlValue;
    if (!url) return;

    // Open the view card modal via Turbo frame
    const frame = document.querySelector(`turbo-frame#${this.frameIdValue}`);
    if (frame) {
      frame.src = url;
    }
  }

  findReplacements(event) {
    event.preventDefault();
    event.stopPropagation();
    this.menuTarget.classList.add("hidden");

    const url = this.findReplacementsUrlValue;
    if (!url) return;

    const frame = document.querySelector(`turbo-frame#${this.frameIdValue}`);
    if (frame) {
      frame.src = url;
    }
  }

  changeCardType(event) {
    event.preventDefault();
    event.stopPropagation();
    this.menuTarget.classList.add("hidden");

    const url = this.changeCardTypeUrlValue;
    const cardType = event.currentTarget.dataset.cardType;
    if (!url || !cardType) return;

    fetch(`${url}&card_type=${cardType}`, {
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
        throw new Error("Failed to change card type");
      })
      .then((html) => {
        Turbo.renderStreamMessage(html);
      })
      .catch((error) => {
        console.error("Error changing card type:", error);
      });
  }

  viewCombos(event) {
    event.preventDefault();
    event.stopPropagation();
    this.menuTarget.classList.add("hidden");

    const url = this.viewCombosUrlValue;
    if (!url) return;

    Turbo.visit(url);
  }

  deleteDeck(event) {
    event.preventDefault();
    event.stopPropagation();
    this.menuTarget.classList.add("hidden");

    const url = this.deleteUrlValue;
    if (!url) return;

    if (!confirm("Are you sure you want to delete this deck? This cannot be undone.")) return;

    fetch(url, {
      method: "DELETE",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        Accept: "text/html",
      },
    })
      .then((response) => {
        if (response.redirected) {
          Turbo.visit(response.url);
        } else if (response.ok) {
          window.location.reload();
        } else {
          throw new Error("Failed to delete deck");
        }
      })
      .catch((error) => {
        console.error("Error deleting deck:", error);
      });
  }
}
