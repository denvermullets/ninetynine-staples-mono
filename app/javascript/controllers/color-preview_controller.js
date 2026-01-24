import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="color-preview"
export default class extends Controller {
  static targets = ["colorPicker", "colorText", "preview", "nameInput"];

  connect() {
    this.updatePreview();
  }

  syncFromPicker() {
    this.colorTextTarget.value = this.colorPickerTarget.value;
    this.updatePreview();
  }

  syncFromText() {
    const color = this.colorTextTarget.value;
    if (/^#[0-9A-Fa-f]{6}$/.test(color)) {
      this.colorPickerTarget.value = color;
    }
    this.updatePreview();
  }

  updateName() {
    this.updatePreview();
  }

  updatePreview() {
    const color = this.colorTextTarget.value || "#6366f1";
    const name = this.hasNameInputTarget ? this.nameInputTarget.value || "Tag Name" : "Tag Name";

    this.previewTarget.style.backgroundColor = color;
    this.previewTarget.textContent = name;

    // Update text color based on background luminance
    if (this.isLightColor(color)) {
      this.previewTarget.classList.remove("text-white");
      this.previewTarget.classList.add("text-foreground");
    } else {
      this.previewTarget.classList.remove("text-foreground");
      this.previewTarget.classList.add("text-white");
    }
  }

  // Calculate relative luminance to determine if color is light or dark
  isLightColor(hex) {
    if (!hex || !/^#[0-9A-Fa-f]{6}$/.test(hex)) return false;

    const r = parseInt(hex.slice(1, 3), 16) / 255;
    const g = parseInt(hex.slice(3, 5), 16) / 255;
    const b = parseInt(hex.slice(5, 7), 16) / 255;

    // Convert to linear RGB
    const toLinear = (c) => (c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4));

    const luminance = 0.2126 * toLinear(r) + 0.7152 * toLinear(g) + 0.0722 * toLinear(b);

    return luminance > 0.5;
  }
}
