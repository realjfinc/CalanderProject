# Calander local Figma builder

This unpublished development plugin runs inside Figma Desktop using its Plugin API. It makes no MCP, REST API, or network requests. It builds editable frames and reusable controls for 46 mobile screens in both Light and Dark themes.

## Run

1. Open CalanderProject in **Figma Desktop**.
2. Open **Plugins → Development → Import plugin from manifest…**.
3. Select **manifest.json** in this folder.
4. Run **Plugins → Development → Calander — Build mobile designs**.

The plugin adds a page named **Calander · Complete mobile designs**. Existing work is preserved. Light screens sit above their matching Dark screens. Use Present mode to scroll longer forms and follow the core navigation links. The controls represent designs, not working authentication or calendar services.

If you run it again, it opens the existing generated page instead of duplicating it. Rename that page if you deliberately want another copy. If a run fails, the partially built page is preserved and the error is shown in Figma.

## Files

- `manifest.json` and `code.js` are all Figma needs. Keep them together.
- `runtime.js` and `build.py` are the editable source and local packaging script.
- The source screen content is in `../figma-progress.json`.

The package is syntax-checked locally. Actual Figma rendering and prototype behavior still need inspection after the first run in Figma Desktop.
