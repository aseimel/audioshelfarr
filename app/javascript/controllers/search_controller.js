import { Controller } from "@hotwired/stimulus"

// Stimulus controller for debounced search
// Connects to data-controller="search"
export default class extends Controller {
  static targets = ["input", "results", "spinner"]
  static values = {
    url: String,
    debounce: { type: Number, default: 300 }
  }

  connect() {
    this.timeout = null
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  search() {
    const query = this.inputTarget.value.trim()

    // Clear existing timeout
    if (this.timeout) {
      clearTimeout(this.timeout)
    }

    // If query is empty, clear results
    if (query.length === 0) {
      this.resultsTarget.innerHTML = ""
      this.hideSpinner()
      return
    }

    // Don't search for very short queries
    if (query.length < 2) {
      return
    }

    // Show spinner
    this.showSpinner()

    // Debounce the search
    this.timeout = setTimeout(() => {
      this.performSearch(query)
    }, this.debounceValue)
  }

  async performSearch(query) {
    const url = `${this.urlValue}?q=${encodeURIComponent(query)}`

    try {
      const response = await fetch(url, {
        headers: {
          "Accept": "text/vnd.turbo-stream.html"
        }
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      }
    } catch (error) {
      console.error("Search failed:", error)
    } finally {
      this.hideSpinner()
    }
  }

  showSpinner() {
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove("hidden")
    }
  }

  hideSpinner() {
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.add("hidden")
    }
  }
}
