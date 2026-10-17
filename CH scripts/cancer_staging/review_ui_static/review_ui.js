"use strict";

const state = {
  review: null,
  summary: null,
  token: "",
  currentAccession: "",
  filter: "all",
  query: "",
  dirty: false,
  order: "group",
  sheetIndex: new Map(),
  pasteback: null,
  pasteSelected: null,  // Set of accessions to copy; null = server default (finished rows)
  catalog: null,
  form: { cancer: "" },
  formDirty: false,
  renderSeq: 0,
};
const ORDER_KEY = "cancer-staging-order";
const MODE_KEY = "cancer-staging-unfinished";

function readPreference(key, fallback) {
  try {
    return window.localStorage.getItem(key) || fallback;
  } catch (_) {
    return fallback;
  }
}

function writePreference(key, value) {
  try {
    window.localStorage.setItem(key, value);
  } catch (_) {
    // Private windows may block storage; the choice then lasts for this page only.
  }
}

const byId = (id) => document.getElementById(id);
const valueOrDash = (value) => value || "—";
const currentCase = () => state.review?.cases.find(
  (item) => String(item.source.accession) === String(state.currentAccession),
);
const isApproved = (item) => item.approval?.state === "approved"
  && item.approval.approved_text_sha256 === item.proposal.text_sha256;

const isNotApplicable = (item) => item.approval?.state === "not_applicable";
const NO_TEMPLATE = "No staging template";
const cancerGroup = (item) => item.proposal.catalog_name || NO_TEMPLATE;

// Group studies by cancer type (alphabetical, no-template group last); the
// stable sort keeps import order within a group. Display order only: the
// review file itself is not reordered.
function sortByCancerGroup(cases) {
  cases.sort((a, b) => {
    const ga = cancerGroup(a);
    const gb = cancerGroup(b);
    if (ga === gb) return 0;
    if (ga === NO_TEMPLATE) return 1;
    if (gb === NO_TEMPLATE) return -1;
    return ga.localeCompare(gb);
  });
}

// "sheet" restores the pasted (Excel) order kept in review.json.
function applyOrder() {
  if (state.order === "sheet") {
    state.review.cases.sort(
      (a, b) => state.sheetIndex.get(String(a.source.accession)) - state.sheetIndex.get(String(b.source.accession)),
    );
  } else {
    sortByCancerGroup(state.review.cases);
  }
  document.querySelectorAll(".order-option").forEach((button) => {
    button.classList.toggle("active", button.dataset.order === state.order);
  });
}

const isSent = (item) => (state.summary?.sent || []).includes(String(item.source.accession));

function setText(id, value) {
  byId(id).textContent = valueOrDash(value);
}

function showToast(message) {
  const toast = byId("toast");
  toast.textContent = message;
  toast.classList.add("show");
  window.clearTimeout(showToast.timer);
  showToast.timer = window.setTimeout(() => toast.classList.remove("show"), 1600);
}

async function copyText(text, label) {
  try {
    await navigator.clipboard.writeText(text || "");
  } catch (_) {
    const temp = document.createElement("textarea");
    temp.value = text || "";
    temp.style.position = "fixed";
    temp.style.opacity = "0";
    document.body.appendChild(temp);
    temp.select();
    document.execCommand("copy");
    temp.remove();
  }
  showToast(`${label} copied`);
}

function updateSummary(summary) {
  state.summary = summary;
  byId("approved-count").textContent = String(summary.approved);
  byId("total-count").textContent = String(summary.total);
  byId("na-count").textContent = String(summary.not_applicable || 0);
}

function filteredCases() {
  const query = state.query.toLowerCase();
  return state.review.cases.filter((item) => {
    const approved = isApproved(item);
    if (state.filter === "approved" && !approved) return false;
    if (state.filter === "pending" && (approved || isNotApplicable(item))) return false;
    if (!query) return true;
    const source = item.source;
    return [source.accession, source.chart_no, source.study_name, item.proposal.catalog_name]
      .join(" ").toLowerCase().includes(query);
  });
}

function renderCaseList() {
  const list = byId("case-list");
  list.replaceChildren();
  const cases = filteredCases();
  if (!cases.length) {
    const empty = document.createElement("p");
    empty.className = "muted";
    empty.textContent = "No matching studies.";
    list.appendChild(empty);
    return;
  }
  let group = null;
  cases.forEach((item) => {
    if (state.order === "group" && cancerGroup(item) !== group) {
      group = cancerGroup(item);
      const members = cases.filter((other) => cancerGroup(other) === group);
      const heading = document.createElement("h3");
      heading.className = "case-group";
      const done = members.filter((other) => isApproved(other) || isNotApplicable(other)).length;
      heading.textContent = `${group} · ${done}/${members.length} done`;
      list.appendChild(heading);
    }
    const source = item.source;
    const button = document.createElement("button");
    button.type = "button";
    button.className = `case-card${String(source.accession) === String(state.currentAccession) ? " active" : ""}`;
    const top = document.createElement("div");
    top.className = "case-card-top";
    const accession = document.createElement("strong");
    accession.textContent = state.order === "sheet"
      ? `#${state.sheetIndex.get(String(source.accession)) + 1} · ${source.accession}`
      : source.accession;
    const status = document.createElement("span");
    const na = isNotApplicable(item);
    status.className = `case-status${isApproved(item) ? " approved" : ""}${na ? " na" : ""}`;
    status.title = isApproved(item) ? "Approved" : (na ? "Not applicable (N/A)" : "Pending");
    top.append(accession, status);
    const study = document.createElement("p");
    study.textContent = source.study_name || "Unnamed study";
    const stage = document.createElement("small");
    stage.textContent = `${item.proposal.t || "?"}${item.proposal.n || "?"}${item.proposal.m || "?"} · Stage ${item.proposal.stage || "N/A"}`
      + (isSent(item) ? " · sent to RIS" : "");
    button.append(top, study, stage);
    button.addEventListener("click", () => selectCase(source.accession));
    list.appendChild(button);
  });
}

function renderList(id, values, emptyText) {
  const list = byId(id);
  list.replaceChildren();
  if (!values.length) {
    const item = document.createElement("li");
    item.textContent = emptyText;
    list.appendChild(item);
    return;
  }
  values.forEach((value) => {
    const item = document.createElement("li");
    item.textContent = value;
    list.appendChild(item);
  });
}

function setMessage(message = "", isError = false) {
  const node = byId("action-message");
  node.textContent = message;
  node.classList.toggle("error", isError);
}

// ---- Template form: the cancer-tnm website's fields, rendered server-side ----

const cancerById = (id) => state.catalog?.cancers.find((cancer) => cancer.id === id);
const optionCodes = (options) => Object.keys(options || {}).sort();  // website sorts codes too

function formFromProposal(item) {
  const proposal = item.proposal;
  const site = proposal.site_form;
  if (site) {
    const form = { cancer: proposal.catalog_id, modality: site.method };
    ["T", "N", "M", "T_RL", "T_location", "N_location", "N_location_R", "N_location_L",
      "M_location", "liver", "characters", "number"].forEach((key) => {
      if (site[key] !== undefined && site[key] !== "") form[key] = site[key];
    });
    if (proposal.stage_resolution) form.stage = proposal.stage_resolution.chosen;
    return form;
  }
  if (proposal.catalog_id && proposal.t) {
    return { cancer: proposal.catalog_id, T: proposal.t, N: proposal.n, M: proposal.m };
  }
  return { cancer: "" };
}

function resetFormForCancer(cancerId) {
  const cancer = cancerById(cancerId);
  const pick = (options, preferred) => (preferred in (options || {}) ? preferred : optionCodes(options)[0] || "");
  state.form = {
    cancer: cancerId,
    modality: state.form.modality,
    T: pick(cancer?.T, "Tx"),
    N: pick(cancer?.N, "N0"),
    M: pick(cancer?.M, "M0"),
  };
}

function field(label, control, note = "") {
  const wrap = document.createElement("label");
  wrap.className = "tf-field";
  const title = document.createElement("span");
  title.textContent = label;
  wrap.append(title, control);
  if (note) {
    const small = document.createElement("small");
    small.textContent = note;
    wrap.appendChild(small);
  }
  return wrap;
}

function selectControl(values, current, onChange, { blank = null, labels = null } = {}) {
  const select = document.createElement("select");
  if (blank !== null) values = ["", ...values];
  values.forEach((value) => {
    const option = document.createElement("option");
    option.value = value;
    const text = value === "" ? blank : (labels ? labels(value) : value);
    option.textContent = text.length > 90 ? `${text.slice(0, 88)}…` : text;
    option.title = text;
    select.appendChild(option);
  });
  select.value = current ?? "";
  select.addEventListener("change", () => onChange(select.value));
  return select;
}

// Cancer templates in the website's menu order, grouped like its menu
// (LUNG, H & N, GI, GU, OGS); the server supplies order and groups.
function cancerSelect(current, onChange) {
  const select = document.createElement("select");
  const blank = document.createElement("option");
  blank.value = "";
  blank.textContent = "— choose a cancer template —";
  select.appendChild(blank);
  let group = null;
  let optgroup = null;
  state.catalog.cancers.forEach((cancer) => {
    if (cancer.group !== group) {
      group = cancer.group;
      optgroup = document.createElement("optgroup");
      optgroup.label = group;
      select.appendChild(optgroup);
    }
    const option = document.createElement("option");
    option.value = cancer.id;
    option.textContent = cancer.name;
    optgroup.appendChild(option);
  });
  select.value = current || "";
  select.addEventListener("change", () => onChange(select.value));
  return select;
}

function chipGroup(label, values, selected, onChange, disabled = false) {
  const wrap = document.createElement("div");
  wrap.className = "tf-field tf-wide";
  const title = document.createElement("span");
  title.textContent = label;
  const box = document.createElement("div");
  box.className = "tf-chips";
  const chosen = new Set(Array.isArray(selected) ? selected : (selected ? [selected] : []));
  values.forEach((value) => {
    const chip = document.createElement("label");
    chip.className = `tf-chip${chosen.has(value) ? " on" : ""}`;
    const input = document.createElement("input");
    input.type = "checkbox";
    input.checked = chosen.has(value);
    input.disabled = disabled;
    input.addEventListener("change", () => {
      if (input.checked) chosen.add(value); else chosen.delete(value);
      onChange(values.filter((item) => chosen.has(item)));  // keep website order
    });
    chip.append(input, document.createTextNode(value));
    box.appendChild(chip);
  });
  wrap.append(title, box);
  return wrap;
}

function setFormValue(key, value) {
  if (value === "" || (Array.isArray(value) && value.length === 0)) delete state.form[key];
  else state.form[key] = value;
  if (key === "M" && value === "M0") delete state.form.M_location;
  if (["T", "N", "M"].includes(key)) delete state.form.stage;  // a new TNM needs a fresh conflict choice
  renderTemplateForm();
  renderFromForm();
}

function renderTemplateForm() {
  const box = byId("template-fields");
  box.replaceChildren();
  if (!state.catalog) return;
  const form = state.form;
  box.appendChild(field("Template", cancerSelect(form.cancer, (value) => {
    resetFormForCancer(value);
    renderTemplateForm();
    if (value) renderFromForm();
  })));
  const cancer = cancerById(form.cancer);
  if (!cancer) return;
  const describe = (options) => (code) => `${code} · ${options[code]}`.replace(/\s+/g, " ");
  box.appendChild(field("Imaging modality", selectControl(
    state.catalog.modalities, form.modality, (value) => setFormValue("modality", value),
  )));
  const isHcc = cancer.id === "HCC";
  if (isHcc) {
    box.appendChild(chipGroup("Associated liver features", state.catalog.hcc_liver, form.liver,
      (value) => setFormValue("liver", value)));
  }
  box.appendChild(field("T · tumor invasion", selectControl(
    optionCodes(cancer.T), form.T, (value) => setFormValue("T", value), { labels: describe(cancer.T) },
  ), cancer.T[form.T] || ""));
  if (isHcc) {
    box.appendChild(chipGroup("Tumor characteristics", state.catalog.hcc_characters, form.characters,
      (value) => setFormValue("characters", value)));
    const number = document.createElement("input");
    number.type = "text";
    number.placeholder = "1, 2, 3 or multiple";
    number.value = form.number || "";
    number.addEventListener("change", () => setFormValue("number", number.value.trim()));
    box.appendChild(field("Number", number));
    box.appendChild(chipGroup("Tumor location", cancer.T_location || [], form.T_location,
      (value) => setFormValue("T_location", value)));
  } else {
    if (cancer.T_RL) {
      box.appendChild(field("Side", selectControl(state.catalog.sides, form.T_RL,
        (value) => setFormValue("T_RL", value), { blank: "—" })));
    }
    if ((cancer.T_location || []).length) {
      box.appendChild(field("Tumor location", selectControl(cancer.T_location, form.T_location,
        (value) => setFormValue("T_location", value), { blank: "—" })));
    }
  }
  box.appendChild(field("N · LAP", selectControl(
    optionCodes(cancer.N), form.N, (value) => setFormValue("N", value), { labels: describe(cancer.N) },
  ), cancer.N[form.N] || ""));
  if (!isHcc && cancer.N_RL) {
    box.appendChild(chipGroup("Right LAP level", cancer.N_location || [], form.N_location_R,
      (value) => setFormValue("N_location_R", value)));
    box.appendChild(chipGroup("Left LAP level", cancer.N_location || [], form.N_location_L,
      (value) => setFormValue("N_location_L", value)));
  } else if (!isHcc && (cancer.N_location || []).length) {
    box.appendChild(chipGroup("LAP location", cancer.N_location, form.N_location,
      (value) => setFormValue("N_location", value)));
  }
  box.appendChild(field("M · metastasis", selectControl(
    optionCodes(cancer.M), form.M, (value) => setFormValue("M", value), { labels: describe(cancer.M) },
  ), cancer.M[form.M] || ""));
  if ((cancer.M_location || []).length) {
    box.appendChild(chipGroup("Metastasis location", cancer.M_location, form.M_location,
      (value) => setFormValue("M_location", value), form.M === "M0"));
  }
}

function renderStage(result, error = "") {
  const box = byId("template-stage");
  box.replaceChildren();
  box.classList.toggle("error", Boolean(error));
  if (error) {
    box.textContent = error;
    return;
  }
  if (!result) return;
  const text = document.createElement("span");
  text.textContent = `${result.form.T}${result.form.N}${result.form.M} → Stage ${result.stage}`;
  box.appendChild(text);
  if (result.candidates.length) {
    const note = document.createElement("span");
    note.textContent = " · catalog conflict, choose:";
    box.append(note, selectControl(result.candidates, result.stage, (value) => {
      state.form.stage = value;
      renderFromForm();
    }));
  }
}

async function renderFromForm() {
  const item = currentCase();
  if (!item || !state.form.cancer) return;
  const request = ++state.renderSeq;
  try {
    const { response, data } = await postJson(
      "/api/render", { accession: item.source.accession, entry: state.form },
    );
    if (request !== state.renderSeq) return;  // a newer change is on its way
    if (!response.ok) throw new Error(data.error || `Render failed (${response.status})`);
    if (!state.form.modality) state.form.modality = data.form.method;
    byId("staging-text").value = data.text;
    state.formDirty = true;
    renderStage(data);
    updateDirtyState();
  } catch (error) {
    if (request === state.renderSeq) renderStage(null, error.message);
  }
}

function updateDirtyState() {
  const item = currentCase();
  if (!item) return;
  const text = byId("staging-text").value;
  state.dirty = state.formDirty || text !== item.proposal.staging_text;
  byId("save-edit").disabled = !state.dirty || !text.trim();
  byId("discard-edit").disabled = !state.dirty;
  byId("approve-text").disabled = state.dirty || !text.trim() || isApproved(item);
  byId("not-applicable").disabled = state.dirty;
  byId("edit-state").textContent = state.dirty ? "Unsaved edits" : "Saved";
  byId("text-length").textContent = `${text.length.toLocaleString()} characters`;
  if (state.dirty) setMessage("Save edits before approval. Saving changed text invalidates any prior approval.");
  else if (byId("action-message").textContent.startsWith("Save edits")) setMessage();
}

function renderCurrentCase() {
  const item = currentCase();
  if (!item) return;
  const source = item.source;
  const proposal = item.proposal;
  const approved = isApproved(item);
  const index = state.review.cases.indexOf(item);

  byId("empty-state").hidden = true;
  byId("review-pane").hidden = false;
  setText("study-name", source.study_name);
  setText("study-subtitle", `${proposal.catalog_name || "Unmapped cancer type"} · Reviewed by ${source.review_doctor || "—"}`);
  setText("case-position", `Study ${index + 1} of ${state.review.cases.length}`);
  setText("accession", source.accession);
  setText("chart-no", source.chart_no);
  setText("study-date", source.study_date);
  setText("report-date", source.report_date);
  setText("original-report", source.report_txt);
  setText("pathology-report", source.patho_txt);
  setText("clinical-diagnosis", source.dx_txt);
  setText("case-notes", [source.notes_txt, source.notes2_txt, source.notes3_txt].filter(Boolean).join("\n"));
  setText("t-value", proposal.t);
  setText("n-value", proposal.n);
  setText("m-value", proposal.m);
  setText("stage-value", proposal.stage);
  setText("tnm-stage", `${proposal.t || "?"}${proposal.n || "?"}${proposal.m || "?"}`);
  setText("cancer-type", proposal.catalog_name);
  renderList(
    "evidence-list",
    Object.entries(proposal.evidence || {}).map(([key, value]) => `${key}: ${value}`),
    "No explicit evidence recorded.",
  );
  renderList("assumption-list", proposal.assumptions || [], "No assumptions recorded.");
  const warnings = proposal.warnings || [];
  byId("warning-panel").hidden = warnings.length === 0;
  renderList("warning-list", warnings, "");

  const badge = byId("approval-badge");
  const notApplicable = isNotApplicable(item);
  badge.textContent = approved ? "Approved" : (notApplicable ? "Not applicable" : "Pending");
  badge.className = `badge ${approved ? "approved" : (notApplicable ? "na" : "pending")}`;
  byId("staging-text").value = proposal.staging_text || "";
  state.form = formFromProposal(item);
  state.formDirty = false;
  state.renderSeq += 1;  // drop any render still in flight for the previous study
  renderTemplateForm();
  renderStage(null, "");
  if (proposal.catalog_id && proposal.t) {
    byId("template-stage").textContent = `Saved: ${proposal.t}${proposal.n}${proposal.m} → Stage ${proposal.stage || "N/A"}`;
  }
  byId("text-sha").textContent = proposal.text_sha256 ? `SHA ${proposal.text_sha256.slice(0, 12)}…` : "No text SHA";
  // Sent text is final and N/A studies are never sent (the server refuses
  // changes too): lock the editor.
  const sent = isSent(item);
  const locked = sent || notApplicable;
  byId("staging-text").readOnly = locked;
  byId("template-fields").querySelectorAll("select, input").forEach((control) => { control.disabled = locked; });
  byId("revoke-approval").hidden = !(approved || notApplicable) || sent;
  byId("revoke-approval").textContent = notApplicable ? "Undo N/A" : "Revoke approval";
  byId("approve-text").hidden = approved || locked;
  byId("not-applicable").hidden = approved || locked;
  byId("save-edit").hidden = locked;
  byId("discard-edit").hidden = locked;
  byId("prev-case").disabled = index === 0;
  byId("next-case").disabled = index === state.review.cases.length - 1;
  state.dirty = false;
  if (sent) {
    setMessage(`Sent to RIS ${new Date(item.execution.at).toLocaleString()}. This text is locked; correct it in RIS directly if needed.`);
  } else if (notApplicable) {
    setMessage(`Not applicable (N/A) since ${new Date(item.approval.marked_at).toLocaleString()}: never sent to RIS; pasted back as 其他癌 / 已備註. Undo N/A to edit.`);
  } else {
    setMessage(approved ? `Approved ${new Date(item.approval.approved_at).toLocaleString()}` : "");
  }
  updateDirtyState();
  renderCaseList();
}

function selectCase(accession) {
  if (state.dirty && !window.confirm("Discard unsaved staging-text edits?")) return;
  state.currentAccession = String(accession);
  renderCurrentCase();
  window.scrollTo({ top: 0, behavior: "smooth" });
}

function replaceCase(updated) {
  const index = state.review.cases.findIndex(
    (item) => String(item.source.accession) === String(updated.source.accession),
  );
  if (index >= 0) state.review.cases[index] = updated;
}

const SERVER_DOWN = `Cannot reach the review server at ${window.location.origin}. It may have stopped: `
  + "in CH scripts\\cancer_staging run `uv run python main.py review-ui`, then reload this page.";

async function serverFetch(url, options) {
  try {
    return await fetch(url, options);
  } catch (_) {
    throw new Error(SERVER_DOWN);  // network failure: the server is not running
  }
}

// POST with the review token. A restarted server issues a new token, so on
// "Invalid review token" fetch the current one and retry once.
async function postJson(url, payload) {
  for (let attempt = 0; attempt < 2; attempt += 1) {
    const response = await serverFetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-Review-Token": state.token },
      body: JSON.stringify(payload),
    });
    const data = await response.json();
    if (response.status === 403 && data.error === "Invalid review token" && attempt === 0) {
      const fresh = await serverFetch("/api/review", { cache: "no-store" });
      state.token = (await fresh.json()).review_token;
      continue;
    }
    return { response, data };
  }
  throw new Error("Invalid review token");
}

async function mutate(action, payload, accession = state.currentAccession) {
  const { response, data } = await postJson(
    `/api/cases/${encodeURIComponent(accession)}/${action}`, payload,
  );
  if (!response.ok) throw new Error(data.error || `Request failed (${response.status})`);
  replaceCase(data.case);
  updateSummary(data.summary);
  return data.case;
}

async function saveEdit() {
  const item = currentCase();
  if (!item || !state.dirty) return;
  if (isApproved(item) && !window.confirm("Saving this change will revoke the existing approval. Continue?")) return;
  setMessage("Saving…");
  try {
    if (state.formDirty) {
      // Form fields (T/N/M digest) plus the text, including any hand tweak.
      await mutate("form", {
        entry: state.form,
        staging_text: byId("staging-text").value,
        expected_sha256: item.proposal.text_sha256 || "",
      });
    } else {
      await mutate("text", {
        staging_text: byId("staging-text").value,
        expected_sha256: item.proposal.text_sha256,
      });
    }
    renderCurrentCase();
    setMessage("Edits saved. Exact-text approval is now pending.");
  } catch (error) {
    setMessage(`${error.message}. Reload the page before retrying.`, true);
  }
}

// After approving, return to the top and hand keyboard focus to the study
// list (on the just-approved card) so the next study is one step away.
function focusCaseList() {
  const card = document.querySelector("#case-list .case-card.active")
    || document.querySelector("#case-list .case-card");
  if (card) {
    card.focus({ preventScroll: true });
    // Bring the card into view inside the list only; scrolling the page to
    // the card would fight the scroll to the top below.
    const rail = card.closest(".case-rail");
    if (rail && rail.scrollHeight > rail.clientHeight) {
      const offset = card.getBoundingClientRect().top - rail.getBoundingClientRect().top;
      rail.scrollTop += offset - rail.clientHeight / 3;
    }
  }
  window.scrollTo({ top: 0, behavior: "smooth" });
}

async function approveCurrent() {
  const item = currentCase();
  if (!item || state.dirty || isApproved(item)) return;
  byId("approve-text").disabled = true;
  try {
    // Approval stays bound to the exact saved text via its SHA.
    await mutate("approve", { expected_sha256: item.proposal.text_sha256 });
    renderCurrentCase();
    setMessage("Exact staging text approved. No RIS submission was made.");
    focusCaseList();
  } catch (error) {
    updateDirtyState();
    setMessage(`${error.message}. Reload the page before retrying.`, true);
  }
}

async function revokeApproval() {
  const item = currentCase();
  const undoingNa = item && isNotApplicable(item);
  if (!undoingNa && !window.confirm("Revoke approval for this study? The staging text will be kept.")) return;
  try {
    await mutate("revoke", {});
    renderCurrentCase();
    setMessage(undoingNa ? "N/A undone; the study is pending again." : "Approval revoked; text remains saved.");
  } catch (error) {
    setMessage(error.message, true);
  }
}

// One click, like Approve: unsupported studies are closed as N/A.
async function markNotApplicable() {
  const item = currentCase();
  if (!item || state.dirty || isApproved(item) || isNotApplicable(item)) return;
  byId("not-applicable").disabled = true;
  try {
    await mutate("not_applicable", {});
    renderCurrentCase();
    focusCaseList();
  } catch (error) {
    updateDirtyState();
    setMessage(error.message, true);
  }
}

function sheetSelect(row, field, options) {
  const select = document.createElement("select");
  const defaultValue = row[`default_${field}`] ?? row[field];
  const auto = document.createElement("option");
  auto.value = "";
  auto.textContent = `Auto (${defaultValue || "blank"})`;
  select.appendChild(auto);
  options.forEach((value) => {
    const option = document.createElement("option");
    option.value = value;
    option.textContent = value;
    select.appendChild(option);
  });
  const chosen = row[`${field === "cancer_type" ? "cancer" : "status"}_source`] === "chosen";
  select.value = chosen ? row[field] : "";
  select.disabled = !row.in_review;
  select.addEventListener("change", () => saveSheetChoice(row.accession, field, select.value));
  return select;
}

function renderPasteback() {
  const data = state.pasteback;
  const body = byId("pasteback-rows");
  body.replaceChildren();
  const allSelected = data.rows.length > 0 && data.rows.every((row) => row.selected);
  byId("paste-select-all").checked = allSelected;
  byId("paste-select-all").indeterminate = !allSelected && data.rows.some((row) => row.selected);
  data.rows.forEach((row, rowIndex) => {
    const tr = document.createElement("tr");
    tr.dataset.index = String(rowIndex);
    tr.className = [row.sent ? "sent" : "", row.selected ? "" : "outside"].join(" ").trim();
    let ris = row.sent ? "Sent" : (row.not_applicable ? "N/A" : (row.in_review ? "Not sent" : "—"));
    if (!row.selected) ris += " · not copied";
    else if (!row.finished) ris += data.unfinished === "empty" ? " · blank line" : " · sheet values";
    const pick = document.createElement("td");
    const box = document.createElement("input");
    box.type = "checkbox";
    box.checked = row.selected;
    box.setAttribute("aria-label", `Copy row ${row.input_row ?? ""}`);
    // Mouse clicks go through drag-to-invert (a click is a one-row drag);
    // keyboard toggles (event.detail === 0) use the change event.
    box.addEventListener("click", (event) => { if (event.detail > 0) event.preventDefault(); });
    box.addEventListener("change", () => toggleCopyRows([row.accession], box.checked));
    pick.appendChild(box);
    tr.appendChild(pick);
    const cells = [
      String(row.input_row ?? ""),
      row.accession,
      row.study_name || (row.in_review ? "" : "not imported"),
      ris,
    ];
    cells.forEach((text, index) => {
      const td = document.createElement("td");
      td.textContent = text;
      if (index === 1 && row.in_review) {
        td.className = "link-cell";
        td.title = "Open this study";
        td.addEventListener("click", () => {
          showView("review");
          selectCase(row.accession);
        });
      }
      tr.appendChild(td);
    });
    const cancerCell = document.createElement("td");
    cancerCell.appendChild(sheetSelect(row, "cancer_type", data.options.cancer_types));
    if (row.suggested_cancer_type && row.suggested_cancer_type !== row.cancer_type) {
      const hint = document.createElement("small");
      hint.textContent = `Suggested: ${row.suggested_cancer_type}`;
      cancerCell.appendChild(hint);
    }
    const statusCell = document.createElement("td");
    statusCell.appendChild(sheetSelect(row, "status", data.options.statuses));
    tr.append(cancerCell, statusCell);
    body.appendChild(tr);
  });
  byId("pasteback-text").value = data.tsv;
  document.querySelectorAll(".mode-option").forEach((button) => {
    button.classList.toggle("active", button.dataset.mode === data.unfinished);
  });
  byId("copy-pasteback").disabled = data.block_length === 0;
  byId("pasteback-help").textContent = data.block_length
    ? `Copies ${data.block_length} lines (癌別, 完成), one per ticked row, in sheet order. In the sheet keep the same filter and sort you copied from, click the 癌別 cell of row ${data.block_start_row}, and paste. `
      + (data.unfinished === "empty"
        ? "A ticked row that is not finished is a blank line (it clears those two cells)."
        : "A ticked row that is not finished repeats its current sheet values.")
      + " Finished = sent to RIS (完成) or a value chosen below. Drag across rows to invert their ticks."
    : "No row is ticked: tick rows to copy (or drag across them).";
  const notSent = data.rows.filter((row) => row.in_review && !row.sent).length;
  const warnings = [];
  if (data.gaps.length) {
    warnings.push(`Rows ${data.gaps.join(", ")} of the pasted block were not imported, so this block would be misaligned. Re-import the full block before pasting.`);
  }
  if (data.skipped_rows.length) {
    warnings.push(`Row(s) ${data.skipped_rows.join(", ")} are unticked between ticked rows and get no line, so paste only where those rows are hidden (e.g. a filtered view).`);
  }
  if (notSent) warnings.push(`${notSent} of ${data.rows.length} rows are not sent to RIS yet.`);
  byId("pasteback-warning").hidden = warnings.length === 0;
  byId("pasteback-warning").textContent = warnings.join(" ");
}

// Drag across rows (or click one) to invert the ticks of every row touched.
const drag = { active: false, start: -1, end: -1 };

function dragRowIndex(event) {
  const tr = event.target.closest ? event.target.closest("#pasteback-rows tr") : null;
  return tr ? Number(tr.dataset.index) : -1;
}

function paintDrag() {
  const low = Math.min(drag.start, drag.end);
  const high = Math.max(drag.start, drag.end);
  byId("pasteback-rows").querySelectorAll("tr").forEach((tr) => {
    const index = Number(tr.dataset.index);
    tr.classList.toggle("drag-touched", drag.active && index >= low && index <= high);
  });
}

function wireDragInvert() {
  const body = byId("pasteback-rows");
  body.addEventListener("pointerdown", (event) => {
    if (event.button !== 0 || event.target.closest("select, .link-cell")) return;
    const index = dragRowIndex(event);
    if (index < 0 || !state.pasteback) return;
    event.preventDefault();  // no text selection while dragging
    Object.assign(drag, { active: true, start: index, end: index });
    paintDrag();
  });
  body.addEventListener("pointerover", (event) => {
    if (!drag.active) return;
    const index = dragRowIndex(event);
    if (index >= 0 && index !== drag.end) {
      drag.end = index;
      paintDrag();
    }
  });
  window.addEventListener("pointerup", () => {
    if (!drag.active) return;
    const low = Math.min(drag.start, drag.end);
    const high = Math.max(drag.start, drag.end);
    drag.active = false;
    paintDrag();
    invertCopyRows(state.pasteback.rows.slice(low, high + 1).map((row) => row.accession));
  });
  window.addEventListener("pointercancel", () => {
    drag.active = false;
    paintDrag();
  });
}

async function loadPasteback() {
  try {
    const mode = readPreference(MODE_KEY, "empty") === "keep" ? "keep" : "empty";
    const selected = state.pasteSelected === null
      ? ""
      : `&selected=${[...state.pasteSelected].map(encodeURIComponent).join(",")}`;
    const response = await serverFetch(`/api/pasteback?unfinished=${mode}${selected}`, { cache: "no-store" });
    if (!response.ok) throw new Error(`Could not load paste-back (${response.status})`);
    state.pasteback = await response.json();
    renderPasteback();
  } catch (error) {
    byId("pasteback-warning").hidden = false;
    byId("pasteback-warning").textContent = error.message;
  }
}

function ensurePasteSelection() {
  if (state.pasteSelected === null) {
    // First manual change: start from the server's default selection.
    state.pasteSelected = new Set(state.pasteback.rows.filter((row) => row.selected).map((row) => row.accession));
  }
}

function toggleCopyRows(accessions, checked) {
  ensurePasteSelection();
  accessions.forEach((accession) => {
    if (checked) state.pasteSelected.add(accession); else state.pasteSelected.delete(accession);
  });
  loadPasteback();
}

function invertCopyRows(accessions) {
  ensurePasteSelection();
  accessions.forEach((accession) => {
    if (state.pasteSelected.has(accession)) state.pasteSelected.delete(accession);
    else state.pasteSelected.add(accession);
  });
  loadPasteback();
}

async function saveSheetChoice(accession, field, value) {
  if (value && state.pasteSelected !== null) state.pasteSelected.add(accession);  // a chosen value is meant to be copied
  try {
    await mutate("sheet", { [field]: value }, accession);
    renderCaseList();
    await loadPasteback();
    showToast("Saved");
  } catch (error) {
    showToast(error.message);
    await loadPasteback();
  }
}

function showView(view) {
  const pasteback = view === "pasteback";
  if (pasteback && state.dirty && !window.confirm("Discard unsaved staging-text edits?")) return;
  if (pasteback) renderCurrentCase();  // drops unsaved edits
  byId("pasteback-pane").hidden = !pasteback;
  byId("review-pane").hidden = pasteback;
  byId("pasteback-toggle").textContent = pasteback ? "Back to review" : "Sheet paste-back";
  if (pasteback) loadPasteback();
}

function moveCase(delta) {
  const item = currentCase();
  const index = state.review.cases.indexOf(item);
  const next = state.review.cases[index + delta];
  if (next) selectCase(next.source.accession);
}

function wireEvents() {
  byId("case-search").addEventListener("input", (event) => {
    state.query = event.target.value.trim();
    renderCaseList();
  });
  document.querySelectorAll(".filter").forEach((button) => button.addEventListener("click", () => {
    state.filter = button.dataset.filter;
    document.querySelectorAll(".filter").forEach((item) => item.classList.toggle("active", item === button));
    renderCaseList();
  }));
  document.querySelectorAll(".order-option").forEach((button) => button.addEventListener("click", () => {
    state.order = button.dataset.order;
    writePreference(ORDER_KEY, state.order);
    applyOrder();
    renderCurrentCase();
  }));
  byId("pasteback-toggle").addEventListener("click", () => {
    showView(byId("pasteback-pane").hidden ? "pasteback" : "review");
  });
  byId("copy-pasteback").addEventListener("click", () => {
    if (state.pasteback) copyText(state.pasteback.tsv, `${state.pasteback.block_length} lines`);
  });
  wireDragInvert();
  byId("paste-select-all").addEventListener("change", (event) => {
    if (state.pasteback) toggleCopyRows(state.pasteback.rows.map((row) => row.accession), event.target.checked);
  });
  document.querySelectorAll(".mode-option").forEach((button) => button.addEventListener("click", () => {
    writePreference(MODE_KEY, button.dataset.mode);
    loadPasteback();
  }));
  byId("staging-text").addEventListener("input", updateDirtyState);
  byId("discard-edit").addEventListener("click", renderCurrentCase);
  byId("save-edit").addEventListener("click", saveEdit);
  byId("approve-text").addEventListener("click", approveCurrent);
  byId("revoke-approval").addEventListener("click", revokeApproval);
  byId("not-applicable").addEventListener("click", markNotApplicable);
  byId("prev-case").addEventListener("click", () => moveCase(-1));
  byId("next-case").addEventListener("click", () => moveCase(1));
  byId("copy-accession").addEventListener("click", () => copyText(currentCase().source.accession, "Accession"));
  byId("copy-chart").addEventListener("click", () => copyText(currentCase().source.chart_no, "Chart number"));
  byId("copy-study-date").addEventListener("click", () => copyText(currentCase().source.study_date, "Study date"));
  byId("copy-report-date").addEventListener("click", () => copyText(currentCase().source.report_date, "Report date"));
  byId("copy-report").addEventListener("click", () => copyText(currentCase().source.report_txt, "Original report"));
  byId("copy-staging").addEventListener("click", () => copyText(byId("staging-text").value, "Staging text"));
  document.addEventListener("keydown", (event) => {
    if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "s") {
      event.preventDefault();
      saveEdit();
    }
    if ((event.ctrlKey || event.metaKey) && event.key === "Enter" && !state.dirty) {
      event.preventDefault();
      approveCurrent();
    }
  });
}

async function init() {
  wireEvents();
  try {
    const response = await fetch("/api/review", { cache: "no-store" });
    if (!response.ok) throw new Error(`Could not load review (${response.status})`);
    const data = await response.json();
    state.review = data.review;
    // review.json keeps the pasted sheet order; remember it before sorting.
    state.sheetIndex = new Map(
      state.review.cases.map((item, index) => [String(item.source.accession), index]),
    );
    state.order = readPreference(ORDER_KEY, "group") === "sheet" ? "sheet" : "group";
    state.summary = data.summary;
    applyOrder();
    state.token = data.review_token;
    updateSummary(data.summary);
    try {
      const catalog = await fetch("/api/catalog", { cache: "no-store" });
      if (catalog.ok) state.catalog = await catalog.json();
    } catch (_) {
      // The text editor still works without the template form.
    }
    if (!state.review.cases.length) {
      byId("empty-state").querySelector("h2").textContent = "No studies in review.json";
      return;
    }
    state.currentAccession = String(state.review.cases[0].source.accession);
    renderCurrentCase();
  } catch (error) {
    byId("empty-state").querySelector("h2").textContent = "Review UI could not start";
    byId("empty-state").querySelector("p").textContent = error.message;
  }
}

init();
