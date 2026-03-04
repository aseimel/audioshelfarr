import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "selectAll", "actions", "count"]

  connect() {
    this.updateUI()
  }

  toggleAll() {
    const checked = this.selectAllTarget.checked
    this.checkboxTargets.forEach(cb => cb.checked = checked)
    this.updateUI()
  }

  updateSelection() {
    const allChecked = this.checkboxTargets.length > 0 && this.checkboxTargets.every(cb => cb.checked)
    const someChecked = this.checkboxTargets.some(cb => cb.checked)

    this.selectAllTarget.checked = allChecked
    this.selectAllTarget.indeterminate = someChecked && !allChecked
    this.updateUI()
  }

  updateUI() {
    const count = this.checkboxTargets.filter(cb => cb.checked).length

    if (this.hasActionsTarget) {
      this.actionsTarget.classList.toggle("hidden", count === 0)
    }

    if (this.hasCountTarget) {
      this.countTarget.textContent = count
    }
  }
}
