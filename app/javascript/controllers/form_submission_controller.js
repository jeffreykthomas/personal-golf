import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['form'];

  submit(event) {
    const form = this.hasFormTarget ? this.formTarget : event.target.form || this.element;
    form?.requestSubmit();
  }
}
