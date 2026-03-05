import { Controller } from "@hotwired/stimulus";
import { subscribeToCoachSession } from "channels/coach_session_channel";
import ConvaiClient from "lib/voice/convai_client";

function csrfToken() {
  return document.querySelector('meta[name="csrf-token"]')?.content || "";
}

export default class extends Controller {
  static targets = [
    "panel",
    "mainContent",
    "navButton",
    "messages",
    "input",
    "form",
    "status",
    "phaseLabel",
    "speakerButton",
    "micButton",
  ];

  static values = {
    sessionsUrl: String,
    voiceSignedUrl: String,
    voiceTranscribeUrl: String,
    voiceSynthesizeUrl: String,
    context: Object,
    phase: String,
    autoOpen: Boolean,
  };

  connect() {
    this.sessionId = null;
    this.subscription = null;
    this.voiceClient = null;
    this.speakerOn = false;
    this.micOn = false;
    this.streamingBubble = null;
    this.latestTipId = null;

    this.renderStatus("");
    this.updateVoiceButtons();
    this.openFromEvent = () => this.open();
    window.addEventListener("coach:open", this.openFromEvent);

    if (this.autoOpenValue) {
      this.open();
    }
  }

  disconnect() {
    window.removeEventListener("coach:open", this.openFromEvent);
    this.subscription?.unsubscribe();
    this.subscription = null;
    this.voiceClient?.disconnect();
    this.voiceClient = null;
  }

  async toggle() {
    if (this.panelTarget.classList.contains("hidden")) {
      await this.open();
    } else {
      this.close();
    }
  }

  async open() {
    this.panelTarget.classList.remove("hidden");
    if (this.hasMainContentTarget) {
      this.mainContentTarget.classList.add("hidden");
    }
    if (this.hasNavButtonTarget) {
      this.navButtonTarget.classList.add("bottom-nav-active");
    }
    this.phaseLabelTarget.textContent = this.phaseValue.replace(/_/g, " ");
    await this.ensureSession();
  }

  close() {
    this.panelTarget.classList.add("hidden");
    if (this.hasMainContentTarget) {
      this.mainContentTarget.classList.remove("hidden");
    }
    if (this.hasNavButtonTarget) {
      this.navButtonTarget.classList.remove("bottom-nav-active");
    }
  }

  async ensureSession() {
    if (this.sessionId) {
      return;
    }

    const response = await fetch(this.sessionsUrlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken(),
      },
      body: JSON.stringify({
        phase: this.phaseValue,
        context: this.contextValue || {},
      }),
    });

    if (!response.ok) {
      this.renderStatus("Unable to start coach session.");
      return;
    }

    const payload = await response.json();
    this.sessionId = payload.session.id;
    this.renderHistory(payload.messages || []);
    this.subscribe();
  }

  subscribe() {
    if (!this.sessionId || this.subscription) {
      return;
    }

    this.subscription = subscribeToCoachSession(this.sessionId, {
      connected: () => this.renderStatus("Connected"),
      disconnected: () => this.renderStatus("Disconnected"),
      received: (data) => this.handleStreamEvent(data),
    });
  }

  renderHistory(messages) {
    this.messagesTarget.innerHTML = "";
    messages.forEach((message) => this.appendMessageBubble(message.role, message.content));
    this.scrollMessagesToBottom();
  }

  appendMessageBubble(role, content) {
    const bubble = document.createElement("div");
    bubble.className = role === "user"
      ? "ml-auto max-w-[85%] rounded-2xl bg-accent-500 px-4 py-2.5 text-sm text-white"
      : "max-w-[85%] rounded-2xl bg-dark-surface border border-dark-border px-4 py-2.5 text-sm text-dark-text";
    bubble.textContent = content;
    this.messagesTarget.appendChild(bubble);
    this.scrollMessagesToBottom();
    return bubble;
  }

  async sendMessage(event) {
    event.preventDefault();
    const content = this.inputTarget.value.trim();
    if (!content) {
      return;
    }

    await this.ensureSession();
    this.inputTarget.value = "";
    this.appendMessageBubble("user", content);
    this.renderStatus("Coach is thinking...");

    if (this.voiceClient && this.speakerOn) {
      this.voiceClient.sendText(content);
    }

    const response = await fetch(`/coach_sessions/${this.sessionId}/coach_messages`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken(),
      },
      body: JSON.stringify({
        context: this.contextValue || {},
        coach_message: {
          content: content,
          modality: this.micOn ? "voice" : "text",
        },
      }),
    });

    if (!response.ok) {
      this.renderStatus("Coach message failed. Try again.");
      return;
    }

    const payload = await response.json();
    if (!this.subscription && payload.message) {
      this.appendMessageBubble("assistant", payload.message.content);
      this.handleActions(payload.actions || []);
      this.renderStatus("");
    }
  }

  handleStreamEvent(data) {
    if (!data?.event) {
      return;
    }

    switch (data.event) {
      case "stream_started":
        this.renderStatus("Coach is thinking...");
        this.streamingBubble = this.appendMessageBubble("assistant", "");
        break;
      case "assistant_delta":
        if (!this.streamingBubble) {
          this.streamingBubble = this.appendMessageBubble("assistant", "");
        }
        this.streamingBubble.textContent += data.delta;
        this.scrollMessagesToBottom();
        break;
      case "assistant_done":
        if (!this.streamingBubble) {
          this.streamingBubble = this.appendMessageBubble("assistant", data.message?.content || "");
        } else if (data.message?.content) {
          this.streamingBubble.textContent = data.message.content;
        }
        this.streamingBubble = null;
        this.handleActions(data.actions || []);
        this.renderStatus("");
        break;
      case "error":
        this.streamingBubble = null;
        this.renderStatus(data.message || "Coach error");
        break;
      default:
        break;
    }
  }

  async handleActions(actions) {
    if (!Array.isArray(actions)) {
      return;
    }

    for (const action of actions) {
      if (action.type === "recommend_tip" && action.status === "ok" && action.tip) {
        this.latestTipId = action.tip.id;
        this.renderTipActionCard(action.tip);
      } else if (action.type === "save_tip" && action.status === "ok" && action.tip) {
        this.appendMessageBubble("assistant", `Saved "${action.tip.title}" to your tips.`);
      } else if (action.type === "dismiss_tip" && action.status === "ok" && action.tip) {
        this.appendMessageBubble("assistant", `Dismissed "${action.tip.title}".`);
      } else if (action.type === "complete_onboarding" && action.status === "ok") {
        await this.completeOnboarding(action.redirect_path);
      }
    }
  }

  renderTipActionCard(tip) {
    const card = document.createElement("div");
    card.className = "rounded-xl border border-accent-500/40 bg-accent-500/10 p-3";
    card.innerHTML = `
      <p class="text-xs text-accent-400 mb-1">Coach recommendation</p>
      <h4 class="text-white font-semibold text-sm">${tip.title}</h4>
      <p class="text-caption text-xs mt-1">${tip.content}</p>
      <div class="mt-3 flex gap-2">
        <button type="button" class="coach-tip-save px-3 py-1 rounded bg-accent-500 text-white text-xs" data-tip-id="${tip.id}">Save</button>
        <button type="button" class="coach-tip-dismiss px-3 py-1 rounded border border-dark-border text-caption text-xs" data-tip-id="${tip.id}">Dismiss</button>
      </div>
    `;

    card.querySelector(".coach-tip-save")?.addEventListener("click", (event) => this.saveTipFromCard(event));
    card.querySelector(".coach-tip-dismiss")?.addEventListener("click", (event) => this.dismissTipFromCard(event));

    this.messagesTarget.appendChild(card);
    this.scrollMessagesToBottom();
  }

  async saveTipFromCard(event) {
    const tipId = event.currentTarget.getAttribute("data-tip-id");
    await this.tipActionRequest("save", tipId);
  }

  async dismissTipFromCard(event) {
    const tipId = event.currentTarget.getAttribute("data-tip-id");
    await this.tipActionRequest("dismiss", tipId);
  }

  async tipActionRequest(action, tipId) {
    if (!this.sessionId) {
      return;
    }

    const response = await fetch(`/coach_sessions/${this.sessionId}/coach_tip_actions/${action}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken(),
      },
      body: JSON.stringify({ tip_id: tipId }),
    });

    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      this.renderStatus(payload.error || "Tip action failed");
      return;
    }

    if (action === "save") {
      this.appendMessageBubble("assistant", `Saved "${payload.tip.title}" to your collection.`);
    } else if (action === "dismiss") {
      this.appendMessageBubble("assistant", `Dismissed "${payload.tip.title}".`);
    }
    this.renderStatus("");
  }

  async completeOnboarding(redirectPath) {
    const response = await fetch(`/coach_sessions/${this.sessionId}/complete_onboarding`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken(),
      },
      body: JSON.stringify({ profile: {} }),
    });

    if (!response.ok) {
      this.renderStatus("Failed to complete onboarding.");
      return;
    }

    const payload = await response.json();
    const target = redirectPath || payload.redirect_path;
    if (target) {
      window.location.href = target;
    }
  }

  async toggleSpeaker() {
    await this.ensureSession();
    if (!this.sessionId) {
      return;
    }

    if (this.speakerOn) {
      this.voiceClient?.disconnect();
      this.voiceClient = null;
      this.speakerOn = false;
      this.micOn = false;
      this.updateVoiceButtons();
      return;
    }

    try {
      this.voiceClient = new ConvaiClient({
        signedUrlEndpoint: this.voiceSignedUrlValue,
        coachSessionId: this.sessionId,
        onEvent: (event) => this.handleVoiceEvent(event),
        onError: () => this.renderStatus("Voice connection error"),
      });
      await this.voiceClient.connect();
      this.speakerOn = true;
      this.updateVoiceButtons();
      this.renderStatus("Voice connected");
    } catch (error) {
      this.renderStatus(error.message || "Voice unavailable");
      this.voiceClient = null;
      this.speakerOn = false;
      this.micOn = false;
      this.updateVoiceButtons();
    }
  }

  async toggleMic() {
    if (!this.speakerOn) {
      await this.toggleSpeaker();
    }
    if (!this.voiceClient || !this.speakerOn) {
      return;
    }

    if (this.micOn) {
      this.voiceClient.stopMicrophone();
      this.micOn = false;
    } else {
      try {
        await this.voiceClient.startMicrophone();
        this.micOn = true;
      } catch (_error) {
        this.renderStatus("Microphone permission denied");
      }
    }

    this.updateVoiceButtons();
  }

  handleVoiceEvent(event) {
    if (event.type === "agent_response" && event.agent_response_event?.agent_response) {
      this.appendMessageBubble("assistant", event.agent_response_event.agent_response);
    } else if (event.type === "voice_disconnected") {
      this.speakerOn = false;
      this.micOn = false;
      this.updateVoiceButtons();
    }
  }

  updateVoiceButtons() {
    if (this.hasSpeakerButtonTarget) {
      this.speakerButtonTarget.classList.toggle("coach-icon-btn-active", this.speakerOn);
    }
    if (this.hasMicButtonTarget) {
      this.micButtonTarget.classList.toggle("coach-icon-btn-active", this.micOn);
    }
  }

  renderStatus(message) {
    if (!this.hasStatusTarget) {
      return;
    }
    this.statusTarget.textContent = message;
    this.statusTarget.classList.toggle("hidden", !message);
  }

  scrollMessagesToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight;
  }
}
