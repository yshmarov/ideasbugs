/*
 * ideasbugs widget — self-contained, no framework, no build step.
 *
 * Reads its config from the <script type="application/json"
 * data-ideasbugs-config> the server renders — re-read on every render so
 * a Turbo visit always reflects the current page's config.
 *
 * A floating button (or any host element carrying `data-ideasbugs-open`)
 * opens a small modal form: type, optional section, message, optional
 * screenshots. The form POSTs multipart form data to the mounted engine with
 * the page's CSRF token. Esc or the backdrop closes it.
 */
(function () {
  "use strict";

  var config = readConfig();
  if (!config || window.__ideasbugsLoaded) return;
  window.__ideasbugsLoaded = true;

  var Z = 2147483000;
  var overlay = null;
  var lastFocused = null;
  var savedOverflow = null;

  // The lock lives on <html>, which survives Turbo body swaps — so a swap can
  // drop the overlay without closeForm() running; render() releases it then.
  function lockScroll() {
    savedOverflow = document.documentElement.style.overflow;
    document.documentElement.style.overflow = "hidden";
  }

  function unlockScroll() {
    if (savedOverflow === null) return;
    document.documentElement.style.overflow = savedOverflow;
    savedOverflow = null;
  }

  function ready(fn) {
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", fn);
    } else {
      fn();
    }
  }

  ready(function () {
    // Document-level listeners survive Turbo navigations; register them once.
    document.addEventListener("keydown", handleKeydown);
    document.addEventListener("click", handleOpenerClick, true);

    // The button lives in <body>, which Turbo replaces on every visit, so
    // re-run the per-page setup on each visit. render() also runs now for the
    // initial (or non-Turbo) load.
    render();
    document.addEventListener("turbo:load", render);
  });

  function readConfig() {
    var el = document.querySelector("script[data-ideasbugs-config]");
    if (!el) return null;
    try {
      return JSON.parse(el.textContent);
    } catch (e) {
      return null;
    }
  }

  function render() {
    // Re-read on each visit: the config block is data (not an executed
    // script), so it reflects the page Turbo just rendered.
    config = readConfig() || config;
    if (overlay && !document.body.contains(overlay)) {
      overlay = null;
      unlockScroll();
    }
    injectStyles();
    if (config.showButton !== false) buildButton();
  }

  function handleOpenerClick(event) {
    var opener = event.target && event.target.closest
      ? event.target.closest("[data-ideasbugs-open]")
      : null;
    if (!opener) return;
    event.preventDefault();
    event.stopPropagation();
    openForm();
  }

  function handleKeydown(event) {
    if (event.key === "Escape" && overlay) closeForm();
  }

  // --- floating button --------------------------------------------------------

  function buildButton() {
    if (document.getElementById("idb-button")) return;
    var button = document.createElement("button");
    button.id = "idb-button";
    button.type = "button";
    button.setAttribute("data-ideasbugs-open", "");
    button.textContent = config.buttonLabel || config.labels.button;
    document.body.appendChild(button);
  }

  // --- form -------------------------------------------------------------------

  function openForm() {
    if (overlay) return;
    lastFocused = document.activeElement;

    overlay = document.createElement("div");
    overlay.id = "idb-overlay";
    overlay.addEventListener("mousedown", function (event) {
      if (event.target === overlay) closeForm();
    });

    var dialog = document.createElement("div");
    dialog.id = "idb-dialog";
    dialog.setAttribute("role", "dialog");
    dialog.setAttribute("aria-modal", "true");
    dialog.setAttribute("aria-labelledby", "idb-title");
    if (config.rtl) dialog.setAttribute("dir", "rtl");

    dialog.appendChild(header());
    dialog.appendChild(form());
    overlay.appendChild(dialog);
    document.body.appendChild(overlay);
    lockScroll();

    // Keep Tab (and Shift+Tab) cycling inside the dialog while it is open.
    overlay.addEventListener("keydown", trapFocus);

    var first = dialog.querySelector("select, textarea, input");
    if (first) first.focus();
  }

  function closeForm() {
    if (!overlay) return;
    overlay.remove();
    overlay = null;
    unlockScroll();
    if (lastFocused && lastFocused.focus) lastFocused.focus();
  }

  function trapFocus(event) {
    if (event.key !== "Tab" || !overlay) return;
    var focusable = overlay.querySelectorAll("button, select, textarea, input, a[href]");
    if (!focusable.length) return;
    var first = focusable[0];
    var last = focusable[focusable.length - 1];
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  }

  function header() {
    var head = document.createElement("div");
    head.className = "idb-head";

    var title = document.createElement("h2");
    title.id = "idb-title";
    title.textContent = config.labels.title;

    var close = document.createElement("button");
    close.type = "button";
    close.className = "idb-x";
    close.setAttribute("aria-label", config.labels.close);
    close.textContent = "×";
    close.addEventListener("click", closeForm);

    head.appendChild(title);
    head.appendChild(close);
    return head;
  }

  function form() {
    var form = document.createElement("form");
    form.addEventListener("submit", function (event) {
      event.preventDefault();
      submit(form);
    });

    if (config.kinds.length > 1) form.appendChild(kindField());
    if (config.sections.length > 0) form.appendChild(sectionField());
    form.appendChild(messageField());
    if (config.screenshots.enabled) form.appendChild(screenshotsField());

    var error = document.createElement("p");
    error.className = "idb-error";
    // The alert region exists (empty) before any text lands in it, so
    // screen readers announce the message showError() later drops in.
    error.setAttribute("role", "alert");
    error.hidden = true;
    form.appendChild(error);

    var actions = document.createElement("div");
    actions.className = "idb-actions";

    var cancel = document.createElement("button");
    cancel.type = "button";
    cancel.className = "idb-secondary";
    cancel.textContent = config.labels.cancel;
    cancel.addEventListener("click", closeForm);

    var save = document.createElement("button");
    save.type = "submit";
    save.className = "idb-primary";
    save.textContent = config.labels.submit;

    actions.appendChild(cancel);
    actions.appendChild(save);
    form.appendChild(actions);
    return form;
  }

  function field(labelText, control) {
    var wrap = document.createElement("label");
    wrap.className = "idb-field";
    var caption = document.createElement("span");
    caption.textContent = labelText;
    wrap.appendChild(caption);
    wrap.appendChild(control);
    return wrap;
  }

  function kindField() {
    var select = document.createElement("select");
    select.name = "kind";
    config.kinds.forEach(function (kind) {
      var option = document.createElement("option");
      option.value = kind.value;
      option.textContent = kind.label;
      select.appendChild(option);
    });
    return field(config.labels.kind, select);
  }

  function sectionField() {
    var select = document.createElement("select");
    select.name = "section";
    var blank = document.createElement("option");
    blank.value = "";
    blank.textContent = config.labels.sectionAny;
    select.appendChild(blank);
    config.sections.forEach(function (section) {
      var option = document.createElement("option");
      option.value = section;
      option.textContent = section;
      select.appendChild(option);
    });
    return field(config.labels.section, select);
  }

  function messageField() {
    var textarea = document.createElement("textarea");
    textarea.name = "message";
    textarea.rows = 5;
    textarea.placeholder = config.labels.messagePlaceholder;
    return field(config.labels.message, textarea);
  }

  function screenshotsField() {
    var input = document.createElement("input");
    input.type = "file";
    input.name = "screenshots";
    input.multiple = true;
    input.accept = "image/*";
    var wrap = field(config.labels.screenshots, input);
    var hint = document.createElement("span");
    hint.className = "idb-hint";
    hint.textContent = config.labels.screenshotsHint;
    wrap.appendChild(hint);
    return wrap;
  }

  // --- submit -------------------------------------------------------------------

  function submit(form) {
    var message = form.querySelector("textarea[name=message]").value.trim();
    if (!message) return showError(form, config.labels.errorBlank);

    var files = fileList(form);
    if (files.length > config.screenshots.max) {
      return showError(form, config.labels.errorTooMany);
    }
    for (var i = 0; i < files.length; i++) {
      if (files[i].size > config.screenshots.maxSize) {
        return showError(form, config.labels.errorTooLarge);
      }
    }

    var data = new FormData();
    var kindSelect = form.querySelector("select[name=kind]");
    data.append("feedback[kind]", kindSelect ? kindSelect.value : config.kinds[0].value);
    var sectionSelect = form.querySelector("select[name=section]");
    if (sectionSelect && sectionSelect.value) data.append("feedback[section]", sectionSelect.value);
    data.append("feedback[message]", message);
    data.append("feedback[page_url]", window.location.href);
    files.forEach(function (file) {
      data.append("feedback[screenshots][]", file);
    });

    var save = form.querySelector(".idb-primary");
    save.disabled = true;

    fetch(config.endpoint, {
      method: "POST",
      headers: csrfHeaders(),
      body: data,
      credentials: "same-origin"
    })
      .then(function (response) {
        if (response.ok) return thanks();
        return response
          .json()
          .catch(function () { return {}; })
          .then(function (body) {
            var messages = body && body.errors;
            showError(form, (messages && messages[0]) || config.labels.errorSave);
          });
      })
      .catch(function () {
        showError(form, config.labels.errorSave);
      })
      .finally(function () {
        save.disabled = false;
      });
  }

  function fileList(form) {
    var input = form.querySelector("input[type=file]");
    return input ? Array.prototype.slice.call(input.files) : [];
  }

  function csrfHeaders() {
    var meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? { "X-CSRF-Token": meta.content } : {};
  }

  function showError(form, text) {
    var error = form.querySelector(".idb-error");
    error.textContent = text;
    error.hidden = false;
  }

  function thanks() {
    if (!overlay) return;
    var dialog = overlay.querySelector("#idb-dialog");
    dialog.textContent = "";
    var note = document.createElement("p");
    note.className = "idb-thanks";
    // Success is a status, not an alert. Insert the region empty and fill it
    // afterwards: screen readers announce text landing in an existing polite
    // region, but may skip a node that arrives already carrying its text.
    note.setAttribute("aria-live", "polite");
    dialog.appendChild(note);
    setTimeout(function () {
      note.textContent = config.labels.thanks;
    }, 0);
    setTimeout(closeForm, 1600);
  }

  // --- styles -------------------------------------------------------------------

  function injectStyles() {
    var css = [
      "#idb-button{position:fixed;bottom:16px;right:16px;z-index:" + Z + ";",
      "padding:10px 16px;border:0;border-radius:999px;cursor:pointer;",
      "background:#2563eb;color:#fff;font:600 14px/1 system-ui,-apple-system,sans-serif;",
      "box-shadow:0 4px 14px rgba(0,0,0,.25)}",
      "#idb-button:hover{background:#1d4ed8}",
      "#idb-overlay{position:fixed;inset:0;z-index:" + (Z + 1) + ";background:rgba(0,0,0,.45);",
      "display:flex;align-items:center;justify-content:center;padding:16px}",
      "#idb-dialog{width:100%;max-width:420px;max-height:90vh;overflow:auto;overscroll-behavior:contain;",
      "background:#fff;color:#1c2024;border-radius:14px;padding:20px;",
      "font:14px/1.5 system-ui,-apple-system,sans-serif;box-shadow:0 20px 60px rgba(0,0,0,.35)}",
      "#idb-dialog .idb-head{display:flex;align-items:center;justify-content:space-between;margin:0 0 12px}",
      "#idb-dialog h2{margin:0;font-size:17px}",
      "#idb-dialog .idb-x{border:0;background:none;font-size:22px;line-height:1;cursor:pointer;color:inherit;padding:2px 6px}",
      "#idb-dialog .idb-field{display:block;margin-bottom:12px}",
      "#idb-dialog .idb-field>span{display:block;margin-bottom:4px;font-weight:600}",
      "#idb-dialog select,#idb-dialog textarea,#idb-dialog input[type=file]{width:100%;box-sizing:border-box;",
      "padding:8px;border:1px solid #d1d5db;border-radius:8px;background:inherit;color:inherit;font:inherit}",
      "#idb-dialog input[type=file]{padding:6px;color:#6b7280;font-size:13px}",
      "#idb-dialog input[type=file]::file-selector-button{margin-inline-end:10px;padding:6px 12px;",
      "border:1px solid #d1d5db;border-radius:6px;background:none;color:#1c2024;font:inherit;cursor:pointer}",
      "#idb-dialog textarea{resize:vertical}",
      "#idb-dialog .idb-hint{display:block;margin-top:4px;font-size:12px;color:#6b7280;font-weight:400}",
      "#idb-dialog .idb-error{color:#dc2626;margin:0 0 12px}",
      "#idb-dialog .idb-actions{display:flex;justify-content:flex-end;gap:8px}",
      "#idb-dialog button{padding:8px 14px;border-radius:8px;cursor:pointer;font:inherit}",
      "#idb-dialog .idb-secondary{border:1px solid #d1d5db;background:none;color:inherit}",
      "#idb-dialog .idb-primary{border:0;background:#2563eb;color:#fff;font-weight:600}",
      "#idb-dialog .idb-primary:disabled{opacity:.6;cursor:default}",
      "#idb-dialog .idb-thanks{margin:8px 0;text-align:center;font-size:15px}",
      "@media (prefers-color-scheme:dark){",
      "#idb-dialog{background:#1a1f26;color:#e6e8ea}",
      "#idb-dialog select,#idb-dialog textarea,#idb-dialog input[type=file]{border-color:#2a313a}",
      "#idb-dialog input[type=file]{color:#9aa2ab}",
      "#idb-dialog input[type=file]::file-selector-button{border-color:#2a313a;color:#e6e8ea}",
      "#idb-dialog .idb-secondary{border-color:#2a313a}",
      "#idb-dialog .idb-hint{color:#9aa2ab}",
      "}",
      // Full-screen dialog on small screens; 16px controls prevent iOS focus-zoom.
      "@media (max-width:480px){",
      "#idb-dialog{position:fixed;top:0;right:0;bottom:0;left:0;width:100%;max-width:100%;",
      "height:100dvh;max-height:100dvh;border-radius:0;margin:0}",
      "#idb-dialog select,#idb-dialog textarea,#idb-dialog input,",
      "#idb-dialog input[type=file]{font-size:16px}",
      "#idb-dialog .idb-actions{padding-bottom:calc(0px + env(safe-area-inset-bottom))}",
      "}"
    ].join("");
    // Re-inject only when the CSS changed. Turbo keeps <head> across visits, so
    // a stale <style> would otherwise pin old CSS after a shipped update, even
    // while fresh widget.js runs — as self-freshening as the fingerprinted URL.
    var existing = document.getElementById("idb-styles");
    if (existing && existing.textContent === css) return;
    if (existing) existing.remove();

    var style = document.createElement("style");
    style.id = "idb-styles";
    style.textContent = css;
    document.head.appendChild(style);
  }
})();
