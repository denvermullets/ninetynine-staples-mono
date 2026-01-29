import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="theme"
export default class extends Controller {
  static targets = ["radio"];
  static values = { url: String };

  async toggle(event) {
    const theme = event.target.value;

    // Update the DOM immediately for instant feedback
    document.documentElement.setAttribute("data-theme", theme);

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
            .content,
        },
        body: JSON.stringify({ theme }),
      });

      if (!response.ok) {
        throw new Error("Failed to save theme preference");
      }

      this.showToast(
        theme === "dark" ? "Switched to Dark Mode" : "Switched to E-ink Mode",
        "success"
      );
    } catch (error) {
      console.error("Error saving theme preference:", error);
      // Revert the theme on error
      const previousTheme = theme === "dark" ? "light" : "dark";
      document.documentElement.setAttribute("data-theme", previousTheme);
      this.radioTargets.forEach((radio) => {
        radio.checked = radio.value === previousTheme;
      });
      this.showToast("Failed to save theme preference", "error");
    }
  }

  showToast(message, type) {
    const toastContainer = document.getElementById("toasts");
    if (!toastContainer) return;

    const toast = document.createElement("div");
    toast.className = `px-4 py-2 rounded-lg shadow-lg ${
      type === "success"
        ? "bg-accent-50 text-background"
        : "bg-red-500 text-white"
    }`;
    toast.setAttribute("data-controller", "toast");
    toast.textContent = message;
    toastContainer.appendChild(toast);
  }
}
