import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]
  static values = {
    editUrl: String,
    frameId: { type: String, default: "deck_modal" }
  }

  connect() {
    this.boundCloseMenu = this.closeMenu.bind(this)
    document.addEventListener("click", this.boundCloseMenu)
    document.addEventListener("contextmenu", this.boundCloseMenu)
  }

  disconnect() {
    document.removeEventListener("click", this.boundCloseMenu)
    document.removeEventListener("contextmenu", this.boundCloseMenu)
  }

  open(event) {
    event.preventDefault()
    event.stopPropagation()

    // Close any other open context menus
    document.querySelectorAll("[data-context-menu-target='menu']").forEach(menu => {
      if (menu !== this.menuTarget) {
        menu.classList.add("hidden")
      }
    })

    // Position and show the menu
    const menu = this.menuTarget
    let x, y

    // If triggered by a button click, position near the button
    if (event.type === "click" && event.currentTarget) {
      const buttonRect = event.currentTarget.getBoundingClientRect()
      x = buttonRect.right
      y = buttonRect.top
    } else {
      // Right-click: position at mouse
      x = event.clientX
      y = event.clientY
    }

    menu.style.left = `${x}px`
    menu.style.top = `${y}px`
    menu.classList.remove("hidden")

    // Adjust position if menu would go off screen
    const rect = menu.getBoundingClientRect()
    if (rect.right > window.innerWidth) {
      menu.style.left = `${x - rect.width}px`
    }
    if (rect.bottom > window.innerHeight) {
      menu.style.top = `${y - rect.height}px`
    }
  }

  closeMenu(event) {
    if (!this.hasMenuTarget) return
    if (!this.menuTarget.contains(event.target)) {
      this.menuTarget.classList.add("hidden")
    }
  }

  edit(event) {
    event.preventDefault()
    this.menuTarget.classList.add("hidden")

    const url = this.editUrlValue
    if (!url) return

    // Use Turbo's native frame loading for proper modal behavior
    const frame = document.querySelector(`turbo-frame#${this.frameIdValue}`)
    if (frame) {
      frame.src = url
    }
  }
}
