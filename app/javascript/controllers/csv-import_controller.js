import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sourceRadio", "existingSection", "newSection", "fileInput", "fileName", "submitButton"]

  toggleSource(event) {
    const isNew = event.target.value === "new"
    this.existingSectionTarget.classList.toggle("hidden", isNew)
    this.newSectionTarget.classList.toggle("hidden", !isNew)
  }

  fileSelected() {
    const file = this.fileInputTarget.files[0]
    if (file) {
      this.fileNameTarget.textContent = file.name
    } else {
      this.fileNameTarget.textContent = "No file selected"
    }
  }

  submit() {
    this.submitButtonTarget.disabled = true
    this.submitButtonTarget.textContent = "Importing..."
  }
}
