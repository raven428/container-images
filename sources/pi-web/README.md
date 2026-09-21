# `@raven428/pi-web`

<!-- cspell:ignore jmfederico patchset subkey -->

Patched build of [pi-web](https://github.com/jmfederico/pi-web), published to GitHub Packages as `@raven428/pi-web`. The upstream tag and patchset number live in `vars.sh`. Release versions use `<upstream>-p<PATCHSET>` and `<upstream>-p<PATCHSET>-<UTC_DATE>-<VERSION_SUFFIX>`; pull requests use `<upstream>-p<PATCHSET>-dev.<VERSION_SUFFIX>`.

## List of patches

- `01-prompt-send-chord` – new "Ctrl+Enter sends message" Enter-key preference: Enter/Shift+Enter always insert a line break, Ctrl+Enter (⌘+Enter on macOS) sends
- `02-chat-card-disclosure` – configurable disclosure (`none`/`live`/`last`/`all`) for thinking, skill, and tool-result/details/diff transcript cards, plus a sixth `eventsGroup` subkey for the summarizing events group card
  - `ui.disclosure.thinking` – `"none"` (default) | `"live"` | `"last"` | `"all"`
  - `ui.disclosure.skillInvocation` – `"none"` (default) | `"live"` | `"last"` | `"all"`
  - `ui.disclosure.toolResult` – `"none"` (default) | `"live"` | `"last"` | `"all"`
  - `ui.disclosure.toolDetails` – `"none"` (default) | `"live"` | `"last"` | `"all"`
  - `ui.disclosure.toolDiff` – `"none"` | `"live"` | `"last"` | `"all"` (default)
  - `ui.disclosure.eventsGroup` – `"live"` (default) | `"last"` | `"all"` (`"none"` is not accepted)

```json
{
  "ui": {
    "disclosure": {
      "thinking": "all",
      "skillInvocation": "none",
      "toolResult": "last",
      "toolDetails": "none",
      "toolDiff": "all",
      "eventsGroup": "last"
    }
  }
}
```

- `03-agent-session-title` – disable PI WEB's extra model request for automatic session naming and forward pi.dev extension-driven title changes live to the browser
- `04-panel-collapse-persistence` – persist navigation/workspace panel collapsed state, navigation section (`machines`/`projects`/`workspaces`/`sessions`) collapsed state, and the archived sessions section's expanded state across tab reloads
- `05-function-key-shortcuts` – allow lone function keys (`F1`-`F24`) as shortcut activators, not just Ctrl/Cmd/Alt chords
