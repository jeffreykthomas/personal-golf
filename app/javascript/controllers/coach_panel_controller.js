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
    this.streamingBubbleByRequestId = new Map();
    this.subscriptionConnected = false;
    this.subscriptionConnectedPromise = null;
    this.resolveSubscriptionConnected = null;
    this.requestIdsWithStreamEvents = new Set();
    this.completedRequestIds = new Set();
    this.lastDeltaSequenceByRequestId = new Map();
    this.latestTipId = null;
    this.activePromptCardSlot = null;

    this.renderStatus("");
    this.autoGrowInput();
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
    this.subscriptionConnected = false;
    this.subscriptionConnectedPromise = null;
    this.resolveSubscriptionConnected = null;
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

    this.subscriptionConnected = false;
    this.subscriptionConnectedPromise = new Promise((resolve) => {
      this.resolveSubscriptionConnected = resolve;
    });

    this.subscription = subscribeToCoachSession(this.sessionId, {
      connected: () => {
        this.subscriptionConnected = true;
        this.resolveSubscriptionConnected?.();
        this.resolveSubscriptionConnected = null;
        this.renderStatus("Connected");
      },
      disconnected: () => {
        this.subscriptionConnected = false;
        this.renderStatus("Disconnected");
      },
      received: (data) => this.handleStreamEvent(data),
    });
  }

  renderHistory(messages) {
    const spacer = this.messagesTarget.firstElementChild;
    this.messagesTarget.innerHTML = "";
    if (spacer) this.messagesTarget.appendChild(spacer);
    this.activePromptCardSlot = null;
    messages.forEach((message) => {
      this.appendMessageBubble(message.role, message.content);
      if (message.role === "assistant" && message.prompt) {
        this.renderInlinePromptCard(message.prompt, { isLatest: false });
      }
    });
    this.scrollMessagesToBottom();
  }

  appendMessageBubble(role, content) {
    const bubble = document.createElement("div");
    bubble.className = role === "user"
      ? "ml-auto max-w-[85%] rounded-2xl bg-accent-500 px-4 py-2.5 text-sm text-white whitespace-pre-wrap"
      : "max-w-[85%] rounded-2xl bg-dark-surface border border-dark-border px-4 py-2.5 text-sm text-dark-text whitespace-pre-wrap";
    bubble.textContent = content;
    this.appendToMessages(bubble);
    return bubble;
  }

  renderInlinePromptCard(prompt, { isLatest = true } = {}) {
    if (!prompt) return null;
    if (prompt.kind !== "persona_question" && prompt.kind !== "persona_dilemma") {
      return null;
    }

    if (this.activePromptCardSlot && this.activePromptCardSlot.element?.isConnected) {
      this.disablePromptCard(this.activePromptCardSlot.element, "Replaced by a newer question");
    }

    if (prompt.kind === "persona_dilemma") {
      return this.renderDilemmaCard(prompt, { isLatest });
    }

    return this.renderQuestionCard(prompt, { isLatest });
  }

  renderQuestionCard(prompt, { isLatest = true } = {}) {
    const isMulti = !!prompt.multi_select;
    const card = document.createElement("div");
    card.className = "max-w-[92%] rounded-2xl border border-dark-border bg-dark-surface/70 px-4 py-3 mt-1 space-y-3";
    card.dataset.personaSlot = prompt.slot || "";
    card.dataset.personaKind = prompt.kind;

    const header = document.createElement("div");
    header.className = "flex items-center justify-between gap-2";

    const label = document.createElement("p");
    label.className = "text-[11px] uppercase tracking-wide text-accent-400 font-semibold";
    label.textContent = prompt.label || "Quick question";

    const hint = document.createElement("p");
    hint.className = "text-[11px] text-dark-text-muted";
    hint.textContent = isMulti
      ? `Pick up to ${prompt.max_options || prompt.options?.length || 3}`
      : "Pick one";
    header.append(label, hint);

    const question = document.createElement("p");
    question.className = "text-sm text-dark-text leading-snug";
    question.textContent = prompt.short_prompt || prompt.question || "";

    const chipsRow = document.createElement("div");
    chipsRow.className = "flex flex-wrap gap-2";
    const selected = new Set();
    const chipButtons = [];
    const options = this.normalizeOptions(prompt.options);

    options.forEach((option) => {
      const chip = document.createElement("button");
      chip.type = "button";
      chip.dataset.value = option.id;
      chip.className = this.personaChipClass(false);
      chip.textContent = option.label;
      chip.style.minHeight = "44px";
      chip.addEventListener("click", () => {
        if (card.dataset.disabled === "true") return;
        if (isMulti) {
          if (selected.has(option.id)) {
            selected.delete(option.id);
          } else {
            const max = prompt.max_options || options.length || 3;
            if (selected.size >= max) {
              const oldest = selected.values().next().value;
              selected.delete(oldest);
              const oldChip = chipButtons.find((b) => b.dataset.value === oldest);
              if (oldChip) oldChip.className = this.personaChipClass(false);
            }
            selected.add(option.id);
          }
          chip.className = this.personaChipClass(selected.has(option.id));
          submitButton.disabled = selected.size === 0 && !freeformInput.value.trim();
        } else {
          this.submitPersonaAnswer(prompt, [option], freeformInput.value.trim(), card);
        }
      });
      chipsRow.appendChild(chip);
      chipButtons.push(chip);
    });

    const freeformWrap = document.createElement("div");
    freeformWrap.className = prompt.allow_freeform ? "flex flex-col gap-2" : "hidden";
    const freeformInput = document.createElement("input");
    freeformInput.type = "text";
    freeformInput.placeholder = "Or type your own…";
    freeformInput.className = "w-full bg-dark-bg border border-dark-border rounded-lg px-3 py-2 text-sm text-dark-text placeholder-dark-text-muted focus-ring";
    freeformInput.addEventListener("input", () => {
      submitButton.disabled = !isMulti
        ? !freeformInput.value.trim()
        : selected.size === 0 && !freeformInput.value.trim();
    });
    freeformInput.addEventListener("keydown", (event) => {
      if (event.key === "Enter") {
        event.preventDefault();
        const text = freeformInput.value.trim();
        if (!text && (!isMulti || selected.size === 0)) return;
        const chosen = Array.from(selected).map((id) => options.find((o) => o.id === id) || { id, label: id });
        this.submitPersonaAnswer(prompt, chosen, text, card);
      }
    });
    freeformWrap.appendChild(freeformInput);

    const actionsRow = document.createElement("div");
    actionsRow.className = "flex items-center justify-between gap-2 pt-1";

    const skipButton = document.createElement("button");
    skipButton.type = "button";
    skipButton.className = "text-xs text-dark-text-muted hover:text-white transition-colors";
    skipButton.textContent = "Skip for now";
    skipButton.style.minHeight = "44px";
    skipButton.addEventListener("click", () => {
      if (card.dataset.disabled === "true") return;
      this.submitPersonaSkip(prompt, card);
    });

    const submitButton = document.createElement("button");
    submitButton.type = "button";
    submitButton.className = "px-3 py-1.5 rounded-full bg-accent-500 text-white text-xs font-semibold disabled:opacity-50 disabled:cursor-not-allowed";
    submitButton.textContent = isMulti ? "Save selections" : "Send";
    submitButton.style.minHeight = "44px";
    submitButton.disabled = true;
    if (!isMulti && !prompt.allow_freeform) {
      submitButton.classList.add("hidden");
    }
    submitButton.addEventListener("click", () => {
      if (card.dataset.disabled === "true") return;
      const text = freeformInput.value.trim();
      const chosen = Array.from(selected).map((id) => options.find((o) => o.id === id) || { id, label: id });
      if (chosen.length === 0 && !text) return;
      this.submitPersonaAnswer(prompt, chosen, text, card);
    });

    actionsRow.append(skipButton, submitButton);

    card.append(header, question, chipsRow);
    if (prompt.allow_freeform) card.append(freeformWrap);
    card.append(actionsRow);

    this.appendToMessages(card);
    if (isLatest) {
      this.activePromptCardSlot = { slot: prompt.slot, element: card };
    }
    return card;
  }

  renderDilemmaCard(prompt, { isLatest = true } = {}) {
    const card = document.createElement("div");
    card.className = "max-w-[94%] rounded-2xl border border-dark-border bg-dark-surface/70 px-4 py-3 mt-1 space-y-3";
    card.dataset.personaDilemma = prompt.dilemma_id || "";
    card.dataset.personaKind = prompt.kind;

    const header = document.createElement("div");
    header.className = "flex items-center justify-between gap-2";

    const label = document.createElement("p");
    label.className = "text-[11px] uppercase tracking-wide text-accent-400 font-semibold";
    label.textContent = prompt.label || "Quick scenario";

    const hint = document.createElement("p");
    hint.className = "text-[11px] text-dark-text-muted";
    hint.textContent = "Pick the closest";
    header.append(label, hint);

    const titleEl = document.createElement("p");
    titleEl.className = "text-sm text-dark-text font-semibold";
    titleEl.textContent = prompt.title || "";

    if (prompt.scenario && prompt.scenario.trim()) {
      const scenarioEl = document.createElement("p");
      scenarioEl.className = "text-sm text-dark-text leading-snug whitespace-pre-wrap";
      scenarioEl.textContent = prompt.scenario;
      card.append(header, titleEl, scenarioEl);
    } else {
      card.append(header, titleEl);
    }

    const promptEl = document.createElement("p");
    promptEl.className = "text-xs text-dark-text-muted italic";
    promptEl.textContent = prompt.short_prompt || "";
    card.append(promptEl);

    const optionsCol = document.createElement("div");
    optionsCol.className = "flex flex-col gap-2";
    const options = this.normalizeOptions(prompt.options);
    options.forEach((option) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = this.dilemmaOptionClass();
      button.style.minHeight = "44px";
      button.textContent = option.label;
      button.dataset.optionId = option.id;
      button.addEventListener("click", () => {
        if (card.dataset.disabled === "true") return;
        this.submitDilemmaAnswer(prompt, option, freeformInput.value.trim(), card);
      });
      optionsCol.appendChild(button);
    });
    card.append(optionsCol);

    let freeformInput;
    if (prompt.allow_freeform) {
      const freeformWrap = document.createElement("div");
      freeformWrap.className = "flex flex-col gap-2";
      freeformInput = document.createElement("input");
      freeformInput.type = "text";
      freeformInput.placeholder = "Or describe what you'd actually do…";
      freeformInput.className = "w-full bg-dark-bg border border-dark-border rounded-lg px-3 py-2 text-sm text-dark-text placeholder-dark-text-muted focus-ring";
      freeformInput.addEventListener("keydown", (event) => {
        if (event.key === "Enter") {
          event.preventDefault();
          const text = freeformInput.value.trim();
          if (!text) return;
          this.submitDilemmaAnswer(prompt, null, text, card);
        }
      });
      freeformWrap.appendChild(freeformInput);
      card.append(freeformWrap);
    } else {
      freeformInput = { value: "" };
    }

    const actionsRow = document.createElement("div");
    actionsRow.className = "flex items-center justify-between gap-2 pt-1";

    const skipButton = document.createElement("button");
    skipButton.type = "button";
    skipButton.className = "text-xs text-dark-text-muted hover:text-white transition-colors";
    skipButton.textContent = "Skip this one";
    skipButton.style.minHeight = "44px";
    skipButton.addEventListener("click", () => {
      if (card.dataset.disabled === "true") return;
      this.submitPersonaSkip(prompt, card);
    });

    const sendFreeform = document.createElement("button");
    sendFreeform.type = "button";
    sendFreeform.className = "px-3 py-1.5 rounded-full bg-accent-500 text-white text-xs font-semibold disabled:opacity-50 disabled:cursor-not-allowed";
    sendFreeform.textContent = "Send my answer";
    sendFreeform.style.minHeight = "44px";
    if (!prompt.allow_freeform) {
      sendFreeform.classList.add("hidden");
    } else {
      sendFreeform.disabled = true;
      freeformInput.addEventListener("input", () => {
        sendFreeform.disabled = !freeformInput.value.trim();
      });
      sendFreeform.addEventListener("click", () => {
        if (card.dataset.disabled === "true") return;
        const text = freeformInput.value.trim();
        if (!text) return;
        this.submitDilemmaAnswer(prompt, null, text, card);
      });
    }

    actionsRow.append(skipButton, sendFreeform);
    card.append(actionsRow);

    this.appendToMessages(card);
    if (isLatest) {
      this.activePromptCardSlot = { slot: prompt.dilemma_id, element: card };
    }
    return card;
  }

  normalizeOptions(rawOptions) {
    return (rawOptions || []).map((option) => {
      if (typeof option === "string") {
        return { id: option, label: option };
      }
      return { id: option.id || option.label, label: option.label || option.id };
    });
  }

  personaChipClass(active) {
    const base = "px-3 py-1.5 rounded-full text-xs font-medium border transition-colors";
    return active
      ? `${base} bg-accent-500 border-accent-500 text-white`
      : `${base} bg-dark-bg/40 border-dark-border text-dark-text hover:bg-dark-bg/80`;
  }

  dilemmaOptionClass() {
    return "w-full text-left px-3 py-2.5 rounded-xl border border-dark-border bg-dark-bg/40 text-sm text-dark-text hover:bg-dark-bg/80 hover:border-accent-500/60 transition-colors";
  }

  disablePromptCard(card, reason) {
    if (!card) return;
    card.dataset.disabled = "true";
    card.classList.add("opacity-50", "pointer-events-none");
    card.querySelectorAll("button, input").forEach((el) => {
      el.disabled = true;
    });
    if (reason) {
      const note = document.createElement("p");
      note.className = "text-[11px] text-dark-text-muted italic";
      note.textContent = reason;
      card.appendChild(note);
    }
  }

  async submitPersonaAnswer(prompt, chosenOptions, freeform, cardElement) {
    const options = (chosenOptions || []).filter(Boolean);
    const cleanValues = options.map((o) => (typeof o === "string" ? o : o.label));
    const cleanFreeform = (freeform || "").trim();
    if (cleanValues.length === 0 && !cleanFreeform) return;

    const summaryParts = [];
    if (cleanValues.length > 0) summaryParts.push(cleanValues.join(", "));
    if (cleanFreeform) summaryParts.push(cleanFreeform);
    const summary = summaryParts.join(" — ");

    this.disablePromptCard(cardElement, `You shared: ${summary}`);
    if (this.activePromptCardSlot?.element === cardElement) {
      this.activePromptCardSlot = null;
    }

    await this.dispatchCoachMessage(summary, {
      persona_answer: {
        kind: "persona_question",
        slot: prompt.slot,
        value: cleanValues,
        freeform: cleanFreeform || null,
        skipped: false,
      },
    });
  }

  async submitDilemmaAnswer(prompt, option, freeform, cardElement) {
    const cleanFreeform = (freeform || "").trim();
    if (!option && !cleanFreeform) return;

    const summary = option ? option.label : cleanFreeform;
    const echoed = option && cleanFreeform ? `${option.label} — ${cleanFreeform}` : summary;

    this.disablePromptCard(cardElement, `You chose: ${summary}`);
    if (this.activePromptCardSlot?.element === cardElement) {
      this.activePromptCardSlot = null;
    }

    await this.dispatchCoachMessage(echoed, {
      persona_answer: {
        kind: "persona_dilemma",
        dilemma_id: prompt.dilemma_id,
        option_id: option ? option.id : null,
        freeform: cleanFreeform || null,
        skipped: false,
      },
    });
  }

  async submitPersonaSkip(prompt, cardElement) {
    this.disablePromptCard(cardElement, "Skipped for now");
    if (this.activePromptCardSlot?.element === cardElement) {
      this.activePromptCardSlot = null;
    }

    if (prompt.kind === "persona_dilemma") {
      await this.dispatchCoachMessage(`Skip — ${prompt.title || "this scenario"}`, {
        persona_answer: {
          kind: "persona_dilemma",
          dilemma_id: prompt.dilemma_id,
          skipped: true,
        },
      });
    } else {
      await this.dispatchCoachMessage(`Skip — ${prompt.label || "this question"}`, {
        persona_answer: {
          kind: "persona_question",
          slot: prompt.slot,
          skipped: true,
        },
      });
    }
  }

  async dispatchCoachMessage(content, extraContext = {}) {
    await this.ensureSession();
    if (!this.sessionId) return;
    await this.waitForSubscriptionReady();

    const requestId = this.createRequestId();
    this.requestIdsWithStreamEvents.delete(requestId);
    this.completedRequestIds.delete(requestId);
    this.lastDeltaSequenceByRequestId.delete(requestId);

    this.appendMessageBubble("user", content);
    this.scrollMessagesToBottom();
    this.renderStatus("Coach is thinking...");

    const baseContext = this.contextValue || {};
    const mergedContext = { ...baseContext, ...extraContext };

    const response = await fetch(`/coach_sessions/${this.sessionId}/coach_messages`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken(),
      },
      body: JSON.stringify({
        request_id: requestId,
        context: mergedContext,
        coach_message: {
          content,
          modality: "text",
        },
      }),
    });

    if (!response.ok) {
      this.renderStatus("Coach message failed. Try again.");
      return;
    }

    const payload = await response.json();
    const streamed = this.requestIdsWithStreamEvents.has(requestId) || this.completedRequestIds.has(requestId);
    if (!streamed && payload.message) {
      this.appendMessageBubble("assistant", payload.message.content);
      if (payload.message.prompt || payload.prompt) {
        this.renderInlinePromptCard(payload.message.prompt || payload.prompt);
      }
      this.handleActions(payload.actions || []);
      this.renderStatus("");
    }
  }

  async sendMessage(event) {
    event.preventDefault();
    const content = this.inputTarget.value.trim();
    if (!content) {
      return;
    }

    await this.ensureSession();
    if (!this.sessionId) {
      return;
    }
    await this.waitForSubscriptionReady();

    const requestId = this.createRequestId();
    this.requestIdsWithStreamEvents.delete(requestId);
    this.completedRequestIds.delete(requestId);
    this.lastDeltaSequenceByRequestId.delete(requestId);

    this.inputTarget.value = "";
    this.autoGrowInput();
    this.appendMessageBubble("user", content);
    this.scrollMessagesToBottom();
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
        request_id: requestId,
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
    const streamed = this.requestIdsWithStreamEvents.has(requestId) || this.completedRequestIds.has(requestId);
    if (!streamed && payload.message) {
      this.appendMessageBubble("assistant", payload.message.content);
      if (payload.message.prompt || payload.prompt) {
        this.renderInlinePromptCard(payload.message.prompt || payload.prompt);
      }
      this.handleActions(payload.actions || []);
      this.renderStatus("");
    }
  }

  handleStreamEvent(data) {
    if (!data?.event) {
      return;
    }

    const requestId = data.request_id;

    switch (data.event) {
      case "stream_started":
        if (!requestId) {
          return;
        }
        this.requestIdsWithStreamEvents.add(requestId);
        this.lastDeltaSequenceByRequestId.set(requestId, -1);
        this.renderStatus("Coach is thinking...");
        this.ensureStreamingBubble(requestId);
        break;
      case "assistant_delta":
        if (!requestId || this.completedRequestIds.has(requestId)) {
          return;
        }
        this.requestIdsWithStreamEvents.add(requestId);
        const incomingSequence = Number.isInteger(data.sequence) ? data.sequence : null;
        const previousSequence = this.lastDeltaSequenceByRequestId.get(requestId) ?? -1;
        if (incomingSequence !== null && incomingSequence <= previousSequence) {
          return;
        }
        if (incomingSequence !== null) {
          this.lastDeltaSequenceByRequestId.set(requestId, incomingSequence);
        }
        const bubble = this.ensureStreamingBubble(requestId);
        bubble.textContent += data.delta;
        this.scrollToBottomIfNearBottom();
        break;
      case "assistant_done":
        if (!requestId) {
          return;
        }
        if (this.completedRequestIds.has(requestId)) {
          return;
        }
        this.requestIdsWithStreamEvents.add(requestId);
        this.completedRequestIds.add(requestId);
        const completedBubble = this.streamingBubbleByRequestId.get(requestId);
        if (!completedBubble) {
          this.appendMessageBubble("assistant", data.message?.content || "");
        } else if (data.message?.content) {
          completedBubble.textContent = data.message.content;
        }
        this.streamingBubbleByRequestId.delete(requestId);
        if (data.message?.prompt) {
          this.renderInlinePromptCard(data.message.prompt);
        }
        this.handleActions(data.actions || []);
        this.renderStatus("");
        this.scrollMessagesToBottom();
        break;
      case "error":
        if (requestId) {
          this.streamingBubbleByRequestId.delete(requestId);
        }
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

    this.appendToMessages(card);
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

  autoGrowInput() {
    if (!this.hasInputTarget) {
      return;
    }

    this.inputTarget.style.height = "auto";
    this.inputTarget.style.height = `${this.inputTarget.scrollHeight}px`;
  }

  handleInputKeydown(event) {
    if (event.key !== "Enter" || event.shiftKey || event.isComposing) {
      return;
    }

    event.preventDefault();
    if (this.hasFormTarget) {
      this.formTarget.requestSubmit();
    }
  }

  appendToMessages(node) {
    this.messagesTarget.appendChild(node);
  }

  ensureStreamingBubble(requestId) {
    const existing = this.streamingBubbleByRequestId.get(requestId);
    if (existing) {
      return existing;
    }

    const bubble = this.appendMessageBubble("assistant", "");
    this.streamingBubbleByRequestId.set(requestId, bubble);
    return bubble;
  }

  scrollToBottomIfNearBottom() {
    const el = this.messagesTarget;
    const threshold = 150;
    const isNearBottom = el.scrollHeight - el.scrollTop - el.clientHeight < threshold;
    if (isNearBottom) {
      this.scrollMessagesToBottom();
    }
  }

  waitForSubscriptionReady(timeoutMs = 1200) {
    if (this.subscriptionConnected || !this.subscriptionConnectedPromise) {
      return Promise.resolve();
    }

    return Promise.race([
      this.subscriptionConnectedPromise,
      new Promise((resolve) => window.setTimeout(resolve, timeoutMs)),
    ]);
  }

  createRequestId() {
    if (window.crypto?.randomUUID) {
      return window.crypto.randomUUID();
    }
    return `req_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
  }

  scrollMessagesToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight;
  }
}
