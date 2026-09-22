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
    destroyUrl: String,
    frameId: { type: String, default: "deck_modal" },
  };

  connect() {
    this.boundCloseMenu = this.closeMenu.bind(this);
    document.addEventListener("click", this.boundCloseMenu);
    document.addEventListener("contextmenu", this.boundCloseMenu);
  }

  // Appends current view state (grouping, sort, view mode) to a URL
  // so turbo stream responses preserve the user's selections
  urlWithViewState(url) {
    const deckBuilder = document.querySelector("[data-controller~='deck-builder']");
    if (!deckBuilder) return url;

    const parsed = new URL(url, window.location.origin);
    const grouping = deckBuilder.dataset.deckBuilderGroupingValue;
    const sortBy = deckBuilder.dataset.deckBuilderSortByValue;
    const viewMode = deckBuilder.dataset.deckBuilderViewModeValue;

    if (grouping) parsed.searchParams.set("grouping", grouping);
    if (sortBy) parsed.searchParams.set("sort_by", sortBy);
    if (viewMode) parsed.searchParams.set("view_mode", viewMode);

    return parsed.toString();
  }

  disconnect() {
    document.removeEventListener("click", this.boundCloseMenu);
    document.removeEventListener("contextmenu", this.boundCloseMenu);
  }

  open(event) {
    event.preventDefault();
    event.stopPropagation();
    this.showMenuAt(event.clientX, event.clientY);
  }

  // Ellipsis button on hover: same menu, anchored under the button so keyboard clicks land right too
  openFromButton(event) {
    event.preventDefault();
    event.stopPropagation();

    if (!this.menuTarget.classList.contains("hidden")) {
      this.menuTarget.classList.add("hidden");
      return;
    }

    const rect = event.currentTarget.getBoundingClientRect();
    this.showMenuAt(rect.left, rect.bottom, 0);
  }

  showMenuAt(clientX, clientY, offset = 10) {
    // Close any other open context menus
    document.querySelectorAll("[data-context-menu-target='menu']").forEach((menu) => {
      if (menu !== this.menuTarget) {
        menu.classList.add("hidden");
      }
    });

    // Position and show the menu, offset to the right of the click position
    const menu = this.menuTarget;
    let x = clientX + offset;
    let y = clientY;

    menu.style.left = `${x}px`;
    menu.style.top = `${y}px`;
    menu.classList.remove("hidden");

    // Adjust position if menu would go off screen
    const rect = menu.getBoundingClientRect();
    if (rect.right > window.innerWidth) {
      x = clientX - rect.width - offset;
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
      frame.src = this.urlWithViewState(url);
    }
  }

  setCommander(event) {
    event.preventDefault();
    event.stopPropagation();
    this.menuTarget.classList.add("hidden");

    const url = this.setCommanderUrlValue;
    if (!url) return;

    fetch(this.urlWithViewState(url), {
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

    fetch(this.urlWithViewState(url), {
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

    fetch(this.urlWithViewState(url), {
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
      frame.src = this.urlWithViewState(url);
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
      frame.src = this.urlWithViewState(url);
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
      frame.src = this.urlWithViewState(url);
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
      frame.src = this.urlWithViewState(url);
    }
  }

  viewCard(event) {
    event.preventDefault();
    event.stopPropagation();
    this.menuTarget.classList.add("hidden");

    const url = this.viewCardUrlValue;
    if (!url) return;

    Turbo.visit(this.urlWithViewState(url));
  }

  findReplacements(event) {
    event.preventDefault();
    event.stopPropagation();
    this.menuTarget.classList.add("hidden");

    const url = this.findReplacementsUrlValue;
    if (!url) return;

    const frame = document.querySelector(`turbo-frame#${this.frameIdValue}`);
    if (frame) {
      frame.src = this.urlWithViewState(url);
    }
  }

  changeCardType(event) {
    event.preventDefault();
    event.stopPropagation();
    this.menuTarget.classList.add("hidden");

    const url = this.changeCardTypeUrlValue;
    const cardType = event.currentTarget.dataset.cardType;
    if (!url || !cardType) return;

    const fullUrl = this.urlWithViewState(url);
    const separator = fullUrl.includes("?") ? "&" : "?";
    fetch(`${fullUrl}${separator}card_type=${cardType}`, {
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

    Turbo.visit(this.urlWithViewState(url));
  }

  confirmDestroy(event) {
    event.preventDefault();
    event.stopPropagation();
    this.menuTarget.classList.add("hidden");

    const url = this.destroyUrlValue;
    if (!url) return;

    const frame = document.querySelector(`turbo-frame#${this.frameIdValue}`);
    if (frame) {
      frame.src = this.urlWithViewState(url);
    }
  }
}
