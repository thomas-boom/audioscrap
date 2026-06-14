Monaspace Krypton font

Instructions to include Monaspace Krypton in this app bundle:

1. On your Mac, open Font Book and locate the "Monaspace Krypton" font.
2. Right-click the font and choose "Show in Finder" (or export the font file). If you only have it installed, you can duplicate the font file from the system font folders.
3. Copy the font file(s) (.ttf or .otf) into this folder (`Fonts/`).
4. In Xcode, open the project, select the copied font files in the Project navigator, and ensure the file's Target Membership includes the `audioscrap` app target (so the files are embedded in the app bundle).

Notes
- This project automatically registers any fonts placed in `Fonts/` at app launch. No Info.plist edits are required.
- After copying the font files, rebuild the app. The app will use the first registered bundled font or the installed system font `Monaspace Krypton` if present.
- If you prefer not to bundle the font, ensure `Monaspace Krypton` is installed in Font Book; the app will attempt to use the system-installed font name automatically.
