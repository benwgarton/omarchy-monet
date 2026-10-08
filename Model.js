// Pure logic for the Monet bar plugin: turning what the `monet` command
// reports into the rows, labels and launch arguments the panel shows. Nothing
// here touches Qt, so it is unit tested under node in the Monet repository.

var PLUGIN_ID = "com.iammonet.design-review"

// What the plugin itself runs. The panel looks for each of these every time it
// opens and says plainly which are missing; `manifest.json` lists the same
// under `dependencies`. `monet` then reports on what the app needs.
var DEPENDENCIES = [
  {
    command: "monet",
    label: "The Monet: Design Review app",
    fix: "Install the monet package, then open this panel again."
  },
  {
    command: "jq",
    label: "jq, to find Monet's window",
    fix: "Run: omarchy pkg add jq"
  },
  {
    command: "hyprctl",
    label: "Hyprland, to bring Monet's window forward",
    fix: "This plugin is made for the Omarchy desktop."
  }
]

// One shell line that prints the name of every dependency that is installed.
function dependencySweep() {
  var names = []
  for (var i = 0; i < DEPENDENCIES.length; i++) names.push(DEPENDENCIES[i].command)
  return "for c in " + names.join(" ") + "; do command -v \"$c\" >/dev/null 2>&1 && echo \"$c\"; done; true"
}

function isObject(value) {
  return !!value && typeof value === "object" && !Array.isArray(value)
}

function parseJson(text) {
  try {
    var value = JSON.parse(String(text || ""))
    return isObject(value) ? value : null
  } catch (error) {
    return null
  }
}

// Dependencies of the plugin that are not installed. `found` is the sweep's
// output: one command name per line.
function missingCommands(found) {
  var present = {}
  var lines = String(found || "").split("\n")
  for (var i = 0; i < lines.length; i++) present[lines[i].trim()] = true
  var missing = []
  for (var j = 0; j < DEPENDENCIES.length; j++) {
    var dependency = DEPENDENCIES[j]
    if (!present[dependency.command]) {
      missing.push({ label: dependency.label, fix: dependency.fix, required: true })
    }
  }
  return missing
}

function monetInstalled(found) {
  var lines = String(found || "").split("\n")
  for (var i = 0; i < lines.length; i++) if (lines[i].trim() === "monet") return true
  return false
}

// What the app says it is missing, from the `doctor` part of the overview.
function missingFromDoctor(report) {
  var checks = report && Array.isArray(report.checks) ? report.checks : []
  var missing = []
  for (var i = 0; i < checks.length; i++) {
    var check = checks[i]
    if (check && check.ok === false) {
      missing.push({
        label: String(check.label || check.id || "Dependency"),
        fix: String(check.fix || ""),
        required: check.required !== false
      })
    }
  }
  return missing
}

// Same words as the start screen in the app.
function badge(candidate) {
  if (candidate.needs_server) return "Not running"
  if (candidate.in_browser) return "Open in your browser"
  return candidate.kind === "server" ? "Running now" : "On this computer"
}

// Arguments for `monet` that open a review of this candidate.
function reviewArguments(candidate) {
  var args = []
  if (candidate.url) args.push("--review-url", String(candidate.url))
  if (candidate.project_dir) args.push("--review-dir", String(candidate.project_dir))
  if (candidate.title) args.push("--review-title", String(candidate.title))
  return args
}

// Rows for the "Review a site" list, from the `pickup` part of the overview.
function pickupRows(report) {
  var candidates = report && Array.isArray(report.candidates) ? report.candidates : []
  var rows = []
  for (var i = 0; i < candidates.length; i++) {
    var candidate = candidates[i]
    if (!isObject(candidate)) continue
    rows.push({
      title: String(candidate.title || candidate.url || candidate.project_dir || "Untitled"),
      detail: String(candidate.detail || candidate.url || candidate.project_dir || ""),
      badge: badge(candidate),
      // A project that is not running yet cannot be captured. Monet opens on
      // its start screen instead, which offers to have the agent start it.
      arguments: candidate.needs_server ? [] : reviewArguments(candidate),
      ready: !candidate.needs_server
    })
  }
  return rows
}

var STATE_LABELS = {
  marking_up: "Marking up",
  with_agent: "With your agent",
  checking: "Checking the changes",
  checked: "Checked"
}

function noteCount(count) {
  return count + (count === 1 ? " note" : " notes")
}

// The review Monet last reported, from its status file. Null when there is
// nothing to show.
function reviewSummary(status) {
  var review = status && status.review
  if (!isObject(review) || !review.project) return null
  var state = STATE_LABELS[review.state] || ""
  var notes = Math.max(0, Math.floor(Number(review.open_notes) || 0))
  var detail = review.summary ? String(review.summary) : state
  if (!review.summary && notes > 0) detail = (state ? state + " · " : "") + noteCount(notes)
  return { project: String(review.project), state: state, detail: detail }
}

// Arguments for `monet` that go back to the review in progress. Empty when
// Monet did not say which review it is: Monet then opens where it was left.
function continueArguments(status) {
  var review = status && status.review
  var id = isObject(review) ? Number(review.project_id) : 0
  return id > 0 && Math.floor(id) === id ? ["--review-project", String(id)] : []
}

// "agent" while the notes are out with the agent, otherwise "idle". The bar
// icon carries a dot for "agent" so an unfinished handoff is not forgotten.
function barState(status) {
  var review = status && status.review
  if (!isObject(review)) return "idle"
  return review.state === "with_agent" || review.state === "checking" ? "agent" : "idle"
}

function tooltip(status) {
  var summary = reviewSummary(status)
  if (!summary) return "Monet: Design Review"
  return "Monet · " + summary.project + (summary.detail ? " · " + summary.detail : "")
}

// Everything the panel shows, from the text `monet overview --json` printed.
// Null when the text is not an overview, so the panel can say Monet did not
// answer rather than show an empty list as if nothing were running.
function overview(text) {
  var report = parseJson(text)
  if (!report || !isObject(report.doctor) || !isObject(report.pickup)) return null
  return {
    missing: missingFromDoctor(report.doctor),
    rows: pickupRows(report.pickup),
    status: isObject(report.status) ? report.status : null
  }
}

// What the keyboard cursor can land on, top to bottom.
function targets(summary, rows) {
  var list = []
  if (summary) list.push({ kind: "continue", index: 0 })
  for (var i = 0; i < (rows || []).length; i++) list.push({ kind: "site", index: i })
  list.push({ kind: "screen", index: 0 })
  list.push({ kind: "open", index: 0 })
  return list
}

// Where a kind of target sits in the list, or -1.
function targetIndex(list, kind) {
  for (var i = 0; i < (list || []).length; i++) if (list[i].kind === kind) return i
  return -1
}

// Arguments for the helper script that first lets the user pick a window or
// an area with Omarchy's own screenshot picker, then opens Monet on the picture.
var PICK_SCREEN_ARGUMENTS = ["--pick-screen"]

function clampIndex(index, length) {
  if (length <= 0) return 0
  return Math.max(0, Math.min(length - 1, Math.floor(Number(index) || 0)))
}

// A file:// URL as a plain path. Empty when it is not a local file.
function filePath(url) {
  var text = String(url || "")
  if (text.indexOf("file://") !== 0) return ""
  var path = text.slice("file://".length).split("?")[0].split("#")[0]
  try {
    return decodeURIComponent(path)
  } catch (error) {
    return path
  }
}

// Where Monet writes its state, honoring XDG_STATE_HOME as Monet does.
function statusPath(stateHome, home) {
  var base = String(stateHome || "")
  if (base.charAt(0) !== "/") base = String(home || "") + "/.local/state"
  return base.replace(/\/+$/, "") + "/monet/status.json"
}

// The plugin's own folder, for its helper script: beside this file, or failing
// that where Omarchy installs plugins, which is always under the home folder.
function pluginDirectory(resolvedUrl, home) {
  var beside = filePath(resolvedUrl)
  if (beside) return beside.replace(/\/[^\/]*$/, "")
  return String(home || "").replace(/\/+$/, "") + "/.config/omarchy/plugins/" + PLUGIN_ID
}
