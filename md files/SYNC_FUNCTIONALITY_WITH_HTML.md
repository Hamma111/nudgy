When this file is referenced, sync the functionality map HTML page (`functionality-map.html`) with the current state of the codebase.

## Instructions

1. **Read the current codebase** — scan all Swift source files under `Sources/Nudge/` to identify every feature, service, setting, and capability.
2. **Read the existing `functionality-map.html`** — understand the current structure, sections, and listed features.
3. **Diff and update** — add any new features, remove features that no longer exist, and update descriptions for features that have changed. Preserve the existing visual design, CSS, and HTML structure.
4. **Update stats** — update the stats bar numbers (source file count, hook events, popup presets, dependencies) if they have changed.
5. **Update the "Last synced" timestamp** — the JS at the bottom auto-generates this, so no manual change needed.

## What counts as a "feature"

- Any user-facing capability, setting toggle, or behavior
- Any service, manager, or system component
- Hook events and their handlers
- Notification styles, popup presets, session states
- Security measures, privacy features
- Supported terminal apps in WindowFocuser

## Design rules

- Use the `frontend-design` skill aesthetic (see `/Users/umar/.claude/skills/frontend-design/SKILL.md`)
- Maintain the dark theme, DM Sans + JetBrains Mono fonts, and section-based card layout
- Keep feature cards concise: name, 1-2 sentence description, file tags, setting tags
- New sections should follow the existing pattern: section-icon + section-title + feature-grid
