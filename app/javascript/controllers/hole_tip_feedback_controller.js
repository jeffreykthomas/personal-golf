import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["button", "message"];

  connect() {
    this.originalButtonText = this.hasButtonTarget ? this.buttonTarget.textContent.trim() : "";
    this.baseButtonClass = this.hasButtonTarget ? this.buttonTarget.className : "";
    this.baseMessageClass = this.hasMessageTarget ? this.messageTarget.className : "";
    this.resetTimer = null;
  }

  disconnect() {
    this.clearResetTimer();
  }

  submitStart() {
    this.clearResetTimer();

    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = true;
      this.buttonTarget.textContent = "Saving tip...";
      this.buttonTarget.classList.add("opacity-70", "cursor-not-allowed");
    }

    this.setMessage("Saving your tip...", "loading");
  }

  submitEnd(event) {
    const { success, fetchResponse } = event.detail;

    if (success) {
      if (this.hasButtonTarget) {
        this.buttonTarget.textContent = "Tip saved! ⛳";
      }
      this.setMessage("Tip saved! Redirecting...", "success");
    } else {
      const message = fetchResponse?.status === 422
        ? "Please review the highlighted fields."
        : "Could not save the tip. Please try again.";

      this.setMessage(message, "error");
      this.resetAfterError();
    }
  }

  resetAfterError() {
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = false;
      this.buttonTarget.textContent = this.originalButtonText || "Add Tip";
      this.buttonTarget.classList.remove("opacity-70", "cursor-not-allowed");
      if (this.baseButtonClass) {
        this.buttonTarget.className = this.baseButtonClass;
      }
    }

    this.clearResetTimer();
    this.resetTimer = setTimeout(() => {
      if (this.hasMessageTarget) {
        this.messageTarget.textContent = "";
        if (this.baseMessageClass) {
          this.messageTarget.className = this.baseMessageClass;
        }
      }
    }, 4000);
  }

  setMessage(text, tone) {
    if (!this.hasMessageTarget) return;

    const toneClass = {
      loading: "text-blue-400",
      success: "text-green-400",
      error: "text-red-400",
    }[tone] || "";

    const baseClass = this.baseMessageClass || "text-caption mt-2";
    this.messageTarget.className = toneClass ? `${baseClass} ${toneClass}` : baseClass;
    this.messageTarget.textContent = text;
  }

  clearResetTimer() {
    if (this.resetTimer) {
      clearTimeout(this.resetTimer);
      this.resetTimer = null;
    }
  }
}
