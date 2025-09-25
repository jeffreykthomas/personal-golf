import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="tabs"
export default class extends Controller {
  static targets = ['tab', 'panel'];
  static values = { active: String };

  connect() {
    if (!this.hasActiveValue && this.tabTargets.length > 0) {
      this.activeValue = this.tabTargets[0].dataset.tab;
    }
    this.update();
  }

  switch(event) {
    const tabName = event.currentTarget.dataset.tab;
    this.activeValue = tabName;
    this.update();
  }

  update() {
    this.tabTargets.forEach((el) => {
      const isActive = el.dataset.tab === this.activeValue;
      el.classList.toggle('active', isActive);
    });
    this.panelTargets.forEach((el) => {
      const isActive = el.dataset.tab === this.activeValue;
      el.classList.toggle('active', isActive);
      // Keep Tailwind 'hidden' class in sync so panels actually show/hide
      el.classList.toggle('hidden', !isActive);
      el.hidden = !isActive;
    });
  }
}
