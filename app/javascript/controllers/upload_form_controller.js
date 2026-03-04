import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dropzone", "input", "filename", "submit"]

  dragover(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.add("border-blue-500", "bg-blue-50")
  }

  dragleave(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove("border-blue-500", "bg-blue-50")
  }

  drop(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove("border-blue-500", "bg-blue-50")

    const files = event.dataTransfer.files
    if (files.length > 0) {
      this.inputTarget.files = files
      this.showFilename(files[0].name)
    }
  }

  fileSelected(event) {
    const files = event.target.files
    if (files.length > 0) {
      this.showFilename(files[0].name)
    }
  }

  showFilename(name) {
    this.filenameTarget.classList.remove("hidden")
    this.filenameTarget.querySelector("span").textContent = name
  }
}
