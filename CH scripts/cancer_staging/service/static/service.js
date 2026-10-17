// Service bar on top of the review UI: who you are, send to RIS, write to the sheet.
(() => {
  "use strict";
  let state = null;
  let loadedVersion = null;
  let seenSendAt = null;

  function el(tag, props = {}, ...children) {
    const node = Object.assign(document.createElement(tag), props);
    node.append(...children);
    return node;
  }

  async function api(path, payload) {
    const options = payload === undefined ? { cache: "no-store" } : {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-Review-Token": state ? state.review_token : "" },
      body: JSON.stringify(payload),
    };
    const response = await fetch(path, options);
    const data = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(data.error || `HTTP ${response.status}`);
    return data;
  }

  const bar = el("div", { id: "cs-bar" });
  const message = el("div", { id: "cs-message", hidden: true });
  const modal = el("div", { id: "cs-modal", hidden: true });

  function say(text, isError = false) {
    message.textContent = text;
    message.className = isError ? "error" : "";
    message.hidden = !text;
  }

  function closeModal() {
    modal.hidden = true;
    modal.replaceChildren();
  }

  function openModal(title, ...content) {
    modal.replaceChildren(el("div", { className: "cs-dialog" }, el("h2", { textContent: title }), ...content));
    modal.hidden = false;
  }

  function chooseDoctor(canCancel) {
    const list = el("div", { className: "cs-names" });
    for (const doctor of state.doctors) {
      const button = el("button", { type: "button", className: "cs-name" },
        el("strong", { textContent: doctor.name }), el("span", { textContent: `${doctor.todo} 待修正` }));
      button.addEventListener("click", async () => {
        await api("/api/service/doctor", { doctor: doctor.name });
        location.reload();
      });
      list.append(button);
    }
    const parts = [el("p", { textContent: "This browser remembers the name. You see only your own sheet rows." }), list];
    if (canCancel) {
      const cancel = el("button", { type: "button", textContent: "Cancel" });
      cancel.addEventListener("click", closeModal);
      parts.push(cancel);
    }
    openModal("Choose your name", ...parts);
  }

  function signIn() {
    const userid = el("input", { type: "text", placeholder: "RIS user ID", autocomplete: "username" });
    const password = el("input", { type: "password", placeholder: "RIS password", autocomplete: "current-password" });
    const note = el("p", { className: "cs-note" });
    const ok = el("button", { type: "submit", className: "cs-primary", textContent: "Sign in" });
    const cancel = el("button", { type: "button", textContent: "Cancel" });
    cancel.addEventListener("click", closeModal);
    const form = el("form", {},
      el("p", { textContent: `Sign in with the RIS account of ${state.doctor}. WebRIS checks the user ID and `
        + "password with RIS. This page does not keep the password." }),
      el("p", { textContent: `The sign-in lets this browser send for ${state.signin_hours} hours. `
        + "Each send still asks you to confirm." }),
      userid, password, note, el("div", { className: "cs-row" }, ok, cancel));
    if (state.userid_known) userid.placeholder = "RIS user ID (leave empty: same as before)";
    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      ok.disabled = true;
      note.textContent = "Checking with RIS…";
      try {
        await api("/api/service/signin", { userid: userid.value.trim(), password: password.value });
        closeModal();
        await refresh();
        say(`Signed in. This browser can send the approved studies of ${state.doctor}.`);
      } catch (error) {
        note.textContent = error.message;
        ok.disabled = false;
      }
    });
    openModal("Sign in with RIS", form);
    (state.userid_known ? password : userid).focus();
  }

  function confirmSend(items, trigger) {
    const list = el("div", { className: "cs-send-list" });
    for (const item of items) {
      list.append(el("div", { className: "cs-send-item" },
        el("div", {}, el("strong", { textContent: item.accession }),
          el("span", { textContent: ` · ${item.study_name || ""} · ${item.study_date || ""}` })),
        el("pre", { textContent: item.staging_text })));
    }
    const ok = el("button", { type: "button", className: "cs-primary",
      textContent: items.length === 1 ? "Send this study to RIS" : `Send ${items.length} studies to RIS` });
    const cancel = el("button", { type: "button", textContent: "Cancel" });
    cancel.addEventListener("click", closeModal);
    ok.addEventListener("click", () => {
      const cases = Object.fromEntries(items.map((item) => [item.accession, item.approved_text_sha256]));
      closeModal();
      act(trigger, "/api/service/send", { cases }, sendSummary);
    });
    openModal(items.length === 1 ? "Send this study to RIS?" : `Send ${items.length} studies to RIS?`,
      el("p", { textContent: `RIS account: ${state.ris_userid} (${state.doctor}). Each RIS report keeps its `
        + "original text and gets the staging text below at the end. The service does a dry-run first." }),
      el("p", { className: "cs-warn", textContent: "You cannot undo a send from this page." }),
      list, el("div", { className: "cs-row" }, ok, cancel));
    cancel.focus();
  }

  function untilText(iso) {
    return iso ? new Date(iso).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }) : "";
  }

  function sendSummary(result) {
    if (!result) return "";
    if (result.error) return `Send failed: ${result.error}`;
    const parts = [];
    if (result.sent && result.sent.length) {
      const bad = Object.entries(result.readback || {}).filter(([, item]) => !item.ok).map(([accession]) => accession);
      parts.push(`Sent ${result.sent.length}: ${result.sent.join(", ")}.`
        + (bad.length ? ` READ-BACK FAILED for ${bad.join(", ")} — check these in RIS.` : " RIS read-back is correct."));
    }
    for (const item of result.failed || []) parts.push(`Not sent ${item.accession}: ${item.reason}`);
    if (result.sheet) {
      if (result.sheet.written.length) parts.push(`Sheet updated: ${result.sheet.written.length} row(s).`);
      for (const item of result.sheet.refused) parts.push(`Sheet not changed for ${item.accession}: ${item.reason}`);
    }
    return parts.join(" ") || result.message || "";
  }

  function isEditing() {
    const save = document.getElementById("save-edit");
    return Boolean(save && !save.disabled && save.offsetParent !== null);
  }

  function reloadSoon(text) {
    if (isEditing()) {
      say(`${text} Save or discard your edit, then reload the page.`);
    } else {
      sessionStorage.setItem("cs-message", text);
      location.reload();
    }
  }

  async function act(button, path, payload, describe) {
    button.disabled = true;
    say("Working…");
    try {
      const result = await api(path, payload);
      reloadSoon(describe(result));
    } catch (error) {
      say(error.message, true);
      button.disabled = false;
    }
  }

  function render() {
    const pill = document.querySelector(".safety-pill");
    const items = [];
    const who = el("button", { type: "button", className: "cs-who", title: "Change the name" },
      el("span", { textContent: "Doctor" }), el("strong", { textContent: state.doctor || "not chosen" }));
    who.addEventListener("click", () => chooseDoctor(true));
    items.push(who);
    if (state.doctor) {
      const waiting = state.waiting.length;
      const info = [];
      if (state.no_proposal) info.push(`${state.no_proposal} without a proposal yet`);
      if (waiting) info.push(`${waiting} waiting for RIS`);
      if (info.length) {
        items.push(el("span", { className: "cs-info", textContent: info.join(" · "),
          title: state.waiting.map((item) => `${item.accession}: ${item.note || item.phase}`).join("\n") }));
      }
      if (state.can_send) {
        const send = el("button", { type: "button", className: "cs-primary",
          textContent: state.sending ? "Sending…" : `Send approved to RIS (${state.sendable})` });
        send.disabled = state.sending || !state.sendable;
        send.addEventListener("click", () => confirmSend(state.send_list, send));
        const auto = el("input", { type: "checkbox", checked: state.auto_send });
        auto.addEventListener("change", async () => {
          if (auto.checked && !confirm("Auto-send: each study goes to RIS immediately when you click Approve, "
            + "with no other confirmation. Turn it on?")) {
            auto.checked = false;
            return;
          }
          await api("/api/service/auto_send", { enabled: auto.checked });
          await refresh();
        });
        items.push(send, el("label", { className: "cs-check" }, auto, "Auto-send on Approve"));
      } else if (state.send_open && !state.signed_in) {
        const signin = el("button", { type: "button", textContent: "Sign in with RIS to send" });
        signin.addEventListener("click", signIn);
        items.push(signin);
      } else if (state.signed_in && state.credential_saved === false) {
        items.push(el("a", { href: state.credentials_url, target: "_blank", rel: "noopener",
          textContent: "Save your RIS login (opens WebRIS)" }));
      }
      if (state.signed_in) {
        const out = el("button", { type: "button", className: "cs-link", textContent: "Sign out" });
        out.addEventListener("click", async () => {
          await api("/api/service/signout", {});
          await refresh();
          say("Signed out. This browser cannot send now.");
        });
        items.push(el("span", { className: "cs-session",
          textContent: `RIS ${state.ris_userid} · until ${untilText(state.signed_in_until)}` }), out);
      }
      if (state.sheet_write !== "off" && state.sheet_pending) {
        const write = el("button", { type: "button", textContent: `Write to sheet (${state.sheet_pending})` });
        write.addEventListener("click", () => {
          if (confirm(`Write 癌別 and 完成 of ${state.sheet_pending} finished row(s) to the Google Sheet?`)) {
            act(write, "/api/service/sheet_write", {}, (result) => sendSummary({ sheet: result }));
          }
        });
        items.push(write);
      }
    }
    bar.replaceChildren(...items);
    renderSendOne();
    if (pill) {
      pill.textContent = state.can_send
        ? (state.auto_send ? "Approve sends to RIS immediately" : "Approve, then Send to RIS")
        : "Approval only · no RIS send";
      pill.title = state.why_not || "";
      pill.classList.toggle("cs-live", Boolean(state.can_send));
    }
  }

  // "Send to RIS" next to Approve, for the study on the screen when it is approved and not sent.
  const sendOne = el("button", { type: "button", id: "cs-send-one", className: "primary-button", hidden: true,
    textContent: "Send to RIS" });
  sendOne.addEventListener("click", () => {
    const item = currentSendable();
    if (item) confirmSend([item], sendOne);
  });

  function currentSendable() {
    const accession = (document.getElementById("accession")?.textContent || "").trim();
    return state && state.can_send ? state.send_list.find((item) => item.accession === accession) : undefined;
  }

  function renderSendOne() {
    const item = currentSendable();
    sendOne.hidden = !item;
    sendOne.disabled = Boolean(state && state.sending);
    sendOne.title = item ? `Send ${item.accession} to RIS (asks to confirm)` : "";
  }

  let refreshTimer = null;
  function refreshSoon() {
    clearTimeout(refreshTimer);
    refreshTimer = setTimeout(() => refresh().catch(() => {}), 300);
  }

  async function refresh() {
    state = await api("/api/service/state");
    if (loadedVersion === null) {
      loadedVersion = state.version;
      seenSendAt = state.last_send ? state.last_send.at : null;
    }
    render();
    const sendAt = state.last_send ? state.last_send.at : null;
    if (sendAt !== seenSendAt && !state.sending) {
      seenSendAt = sendAt;
      loadedVersion = state.version;
      reloadSoon(sendSummary(state.last_send));
    } else if (state.version !== loadedVersion && !state.sending) {
      loadedVersion = state.version;
      reloadSoon("Your list changed (new rows, new proposals or sheet updates).");
    }
  }

  async function start() {
    const header = document.querySelector("header.topbar");
    header.after(bar, message);
    document.body.append(modal);
    const approve = document.getElementById("approve-text");
    if (approve) approve.after(sendOne);
    // The review UI changes these when the study on the screen or its approval changes.
    const observer = new MutationObserver(() => {
      renderSendOne();
      refreshSoon();
    });
    for (const id of ["accession", "approval-badge"]) {
      const node = document.getElementById(id);
      if (node) observer.observe(node, { childList: true, characterData: true, subtree: true });
    }
    const kept = sessionStorage.getItem("cs-message");
    if (kept) {
      sessionStorage.removeItem("cs-message");
      say(kept);
    }
    try {
      await refresh();
      if (!state.doctor) chooseDoctor(false);
    } catch (error) {
      say(`Service state is not available: ${error.message}`, true);
    }
    setInterval(() => refresh().catch(() => {}), 10000);
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start);
  else start();
})();
