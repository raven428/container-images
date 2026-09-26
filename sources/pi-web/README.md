# `@raven428/pi-web`

<!-- cspell:ignore autoscroll enum jmfederico lezer patchset subkey subsession toolArgs toolContent -->

Patched build of [pi-web](https://github.com/jmfederico/pi-web), published to GitHub Packages as `@raven428/pi-web`. The upstream tag and patchset number live in `vars.sh`. Release versions use `<upstream>-p<PATCHSET>` and `<upstream>-p<PATCHSET>-<UTC_DATE>-<VERSION_SUFFIX>`; pull requests use `<upstream>-p<PATCHSET>-dev.<VERSION_SUFFIX>`.

## List of patches

- `01-prompt-send-chord` – new "Ctrl+Enter sends message" Enter-key preference: Enter/Shift+Enter always insert a line break, Ctrl+Enter (⌘+Enter on macOS) sends
- `02-chat-card-disclosure` – configurable disclosure (`none`/`live`/`last`/`all`) for thinking, skill, and tool-result/details/diff/input transcript cards, plus the eighth `eventsGroup` subkey for the summarizing events group card
  - `ui.disclosure.thinking` – `none` (default) | `live` | `last` | `all`
  - `ui.disclosure.skillInvocation` – `none` (default) | `live` | `last` | `all`
  - `ui.disclosure.toolResult` – `none` (default) | `live` | `last` | `all`
  - `ui.disclosure.toolDetails` – `none` (default) | `live` | `last` | `all`
  - `ui.disclosure.toolDiff` – `none` | `live` | `last` | `all` (default)
  - `ui.disclosure.toolArgs` – `none` (default) | `live` | `last` | `all`
  - `ui.disclosure.toolContent` – `none` | `live` | `last` | `all` (default)
  - `ui.disclosure.eventsGroup` – `live` (default) | `last` | `all` (`none` is not accepted); `live` and `last` for `toolArgs`/`toolContent` target the last call that has that card

```json
{
  "ui": {
    "disclosure": {
      "thinking": "all",
      "skillInvocation": "none",
      "toolResult": "last",
      "toolDetails": "none",
      "toolDiff": "all",
      "toolArgs": "none",
      "toolContent": "all",
      "eventsGroup": "last"
    }
  }
}
```

- `03-agent-session-title` – disable PI WEB's extra model request for automatic session naming and forward pi.dev extension-driven title changes live to the browser
- `04-panel-collapse-persistence` – persist navigation/workspace panel collapsed state, navigation section (`machines`/`projects`/`workspaces`/`sessions`) collapsed state, and the archived sessions section's expanded state across tab reloads
- `05-function-key-shortcuts` – allow lone function keys (`F1`-`F24`) as shortcut activators, not just Ctrl/Cmd/Alt chords
- `06-spawn-thinking-level` – add a `thinkingLevel` enum parameter to `spawn_subsession`/`spawn_session`, plus a `provider/model-id:level` suffix on their `model` parameter (the suffix wins over `thinkingLevel` when both are set); omitting both inherits the spawning session's level, while an explicit `model` without a level lets pi apply its own default for that model; an unsupported level is clamped to the nearest one the target model supports with a note in the result, and the actual level the child runs with is always reported back
- `07-tool-input-cards` – add highlighted JSON `Arguments` cards for tools except `edit`/`write`/`bash`/`read` and `Written content` cards for `write` with path-based highlighting and line numbers; cap expanded Details/Result/diff/Arguments/Written content and standalone result cards at half the window height with scrolling; keep streaming Result output pinned to the bottom until the reader scrolls up
- `08-ask-user-markdown` – render question text, question details, and custom ask_user answers as Markdown in forms and transcript records
- `08-ask-user-markdown.patch1` – alternative using `<formatted-text>` for ask_user Markdown; not applied automatically, manually use it instead of `08-ask-user-markdown.patch`
