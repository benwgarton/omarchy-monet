# Monet: Design Review for Omarchy

Puts Monet in the Omarchy bar. Click the **M** to see the sites and projects
on this computer that Monet can review. Pick one and Monet opens straight into
capturing it, ready for you to mark up and hand to your agent.

- **Running sites** are found from their local ports and traced back to the
  project folder they are served from.
- **Folders** with an `index.html` are listed too. Monet serves them itself.
- **Projects that are not running yet** are shown, and Monet offers to have
  your agent start them.
- **Anything on screen** can be reviewed too: *Review what is on screen* lets
  you click a window or drag over an area with Omarchy's own picker, and Monet
  opens with the picture.
- **A review in progress** is one press away under *Keep going*. A dot on the
  icon means your notes are still out with your agent.

## Requirements

| Needs | Why | How to get it |
| --- | --- | --- |
| Omarchy 4.0 or newer | The plugin shell and `omarchy agent` | `omarchy update` |
| `monet` | The Monet: Design Review app, free | <https://iammonet.com/omarchy> |
| `jq` | Finds Monet's window | Part of Omarchy |
| `hyprctl` | Brings Monet's window forward | Part of Omarchy |
| `omarchy capture screenshot` | Picks a window or an area to review (optional) | Part of Omarchy |

Monet itself also uses:

| Needs | Why | How to get it |
| --- | --- | --- |
| `chromium` | Takes the page captures | Part of Omarchy, or the Omarchy menu: Install > Package > chromium |
| A default agent | Receives your notes and makes the changes | Setup > Defaults > Agent |

You do not have to check any of this by hand. Each time the panel opens it
looks for everything above and lists what is missing, with the command or menu
that fixes it. The same list is in `manifest.json` under `dependencies`, and
`monet doctor` prints it in a terminal.

## Install

There are two ways in, and you need only one of them.

**From the Omarchy plugin marketplace**, or straight from this repository:

```bash
omarchy plugin add https://github.com/benwgarton/omarchy-monet.git --enable
```

Omarchy shows you the address, clones this repository, checks its
`manifest.json`, and puts the **M** in the bar (it asks which section; right
is the default). If the Monet app is not on this computer yet, the panel says
so: get it from <https://iammonet.com/omarchy>.

**With the Monet installer.** `install.sh` in the bundle from that page
installs the app and copies this plugin out of the package into
`~/.config/omarchy/plugins/`. When the marketplace copy is already there, the
installer leaves it alone.

Omarchy keeps one copy of a plugin, so `omarchy plugin add` stops if the
installer's copy is already in place. Remove that copy first (below) if you
would rather have the marketplace one, which `omarchy plugin update` keeps
current.

To do it by hand, copy this folder to
`~/.config/omarchy/plugins/com.iammonet.design-review`, then:

```bash
omarchy-shell shell rescanPlugins
omarchy plugin enable com.iammonet.design-review --section right
```

## Update

A copy added from git is updated by Omarchy, which shows you the change first:

```bash
omarchy plugin update com.iammonet.design-review
```

A copy placed by the Monet installer is replaced by the next bundle's
`install.sh`.

## Remove

```bash
omarchy plugin remove com.iammonet.design-review
```

That takes the **M** out of the bar and deletes the plugin folder (a folder
copied by hand is moved to a backup instead; that is Omarchy's rule). The
Monet app stays. `uninstall.sh` in the bundle removes both.

## Use

| Do this | To |
| --- | --- |
| Click the **M** | Open or close the panel |
| Middle-click the **M** | Open Monet |
| Up / Down, or J / K | Move through the list |
| Enter or Space | Review what is selected |
| S | Pick a window or an area on screen to review |
| R | Look for sites again |
| O | Open Monet |
| Esc | Close the panel |

To open the panel from the keyboard, add a line to
`~/.config/hypr/bindings.lua`. `Super + Ctrl + M` is free in a stock Omarchy
(`Super + K` lists the keys already in use):

```lua
o.bind("SUPER + CTRL + M", "Monet", "omarchy-shell monet toggle")
```

## What it does on your computer

Nothing here uses the network, runs in the background, or needs root. There
is no setup step and no service: the plugin is these files, loaded by the
Omarchy shell.

- When the panel opens it runs `monet overview --json` once.
- It watches one small file, `~/.local/state/monet/status.json`, which Monet
  rewrites when a review changes state.
- Picking something runs `monet-open` from this folder, which starts `monet`
  and asks Hyprland to bring its window forward.
- *Review what is on screen* runs `omarchy capture screenshot smart save`,
  which saves the picture in your Pictures folder like any other screenshot,
  and passes that file to Monet.

## Files

| File | What it is |
| --- | --- |
| `manifest.json` | What Omarchy reads to load the plugin |
| `Panel.qml` | The bar icon and its panel |
| `MonetIcon.qml` | The M |
| `Model.js` | The logic, kept free of Qt so it can be tested on its own |
| `monet-open` | Opens Monet, or brings its window forward; `--pick-screen` picks a picture first |
| `preview.png` | The picture on the marketplace listing |
| `LICENSE` | MIT |

## License

MIT. See `LICENSE`. The Monet app itself is a separate download with its own
terms.
