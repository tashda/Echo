# Managing Custom Editor Fonts

This guide documents the steps required to add or remove typefaces that are available to the SQL editor and the Settings window preview. Follow the checklist whenever the set of bundled fonts changes.

> **Prerequisites**
>
> * All fonts are distributed as `.ttf` files.
> * The font files must carry a license that allows redistribution in the app.

## Project structure overview

| Location | Purpose |
| --- | --- |
| `Echo/Resources/Fonts/` | Bundled font files that are copied into the app bundle during build. |
| `Echo.xcodeproj` | Contains the “Copy Fonts” build phase and file references. |
| `Echo/Sources/Infrastructure/Utilities/FontRegistrar.swift` | Runtime font registration helper. |
| `Echo/Sources/UI/Settings/SettingsWindow.swift` | Lists selectable editor fonts and handles Settings preview logic. |
| `Echo/Sources/Domain/Settings/SQLEditorTheme.swift` | Normalises stored font names when themes are resolved. |

## Adding a font

1. **Drop the `.ttf` file into the repo**
   * Place the file under `Echo/Resources/Fonts/`.
   * Keep the original filename (e.g. `MyFont-Regular.ttf`).

2. **Update the Xcode project**
   * Open `Echo.xcodeproj` in Xcode.
   * In the *Project navigator*, locate `Echo/Resources/Fonts`.
   * Drag the new `.ttf` into that group and choose “Create folder references” so the build phase receives the real file path.
   * Verify that the “Copy Fonts” build phase (`Targets → Echo → Build Phases`) automatically lists the file under the phase output. This phase copies the files to `Contents/Resources/Fonts`.

3. **Register the font at runtime**
   * No additional code is required if the file is in the folder. `FontRegistrar` enumerates `*.ttf` in the `Fonts` subdirectory and loads them using `CTFontManagerRegisterFontsForURL`.

4. **Expose the font in Settings**
   * In `SettingsWindow.swift`, extend the `editorFontOptions` array with the new font. Supply:
     * `id`: a unique identifier (usually matches the PostScript name).
     * `postScriptName`: the canonical PostScript name (can be discovered using macOS “Font Book” or logging the names printed by `FontRegistrar` in DEBUG builds).
     * `displayName`: the human-friendly label.
   * Example:
     ```swift
     EditorFontOption(id: "MyFont-Regular", postScriptName: "MyFont-Regular", displayName: "My Font")
     ```

5. **Handle legacy settings (optional)**
   * If the font has previously been stored under another PostScript name, update `SQLEditorTheme.sanitizedFontName` to map the legacy value to the new one so existing user preferences continue to work.

6. **Test the integration**
   * Clean the build folder (`Shift+Cmd+K`) and rebuild.
   * Launch the app, open Settings → Editor. Verify:
     * `FontRegistrar` prints a “Registered fonts” line for the new font (or “already registered”).
     * The font appears in the card grid with the correct preview.
     * Hovering the chip updates the query preview with the new typeface.
     * Selecting the font updates the live SQL editor.

## Removing a font

1. **Remove the `.ttf` file**
   * Delete the file from `Echo/Resources/Fonts/`.
   * In Xcode’s navigator, remove the reference (choose “Move to Trash” to delete the file).

2. **Update the build phase**
   * Confirm that the “Copy Fonts” build phase no longer lists the deleted file. Xcode will normally clean this up automatically when the file reference is removed.

3. **Update Settings options**
   * Delete the corresponding entry from `editorFontOptions` in `SettingsWindow.swift`.
   * If the font was mapped in `SQLEditorTheme.sanitizedFontName`, remove or update the mapping so users fall back to a valid default.

4. **Clean and rebuild**
   * Perform a clean build. Verify that the font is no longer shown in the Settings UI and that no warnings are printed by `FontRegistrar`.

## Debugging tips

* **Finding PostScript names:** In DEBUG builds `FontRegistrar` prints the exact PostScript names discovered inside each `.ttf`. Use these strings in `editorFontOptions`.
* **Avoid duplicate registration warnings:** The helper suppresses CoreText error 105 (“already registered”), so repeated launches are safe. If other errors appear, double-check the font file integrity.
* **Hover preview behaviour:** Settings previews react both to selected fonts and to hover state. If a new chip does not update the preview, ensure `EditorFontOption` was added and the PostScript name matches the file’s internal name.

Following this checklist ensures fonts are bundled, registered, and visible to both the Settings UI and the SQL editor without additional manual steps. 
