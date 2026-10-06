# Sustain UI mockup (design spec)

The approved, clickable mockup lives on a Claude Design canvas:
https://claude.ai/artifact/TSe1AHctNW6q3tCF7dqDYC (private to the owner).

The files here are a copy of that canvas's source, so a new session can read the design without the canvas. They are the **visual and interaction spec** for the native SwiftUI app: layouts, copy, states, color tokens and keyboard behavior. They are not app code.

- `Main.dc.html`: the whole prototype. One interactive component with all screens, fake data, the area picker, lanes, the theme generator (`themeBases()`, `buildTheme()`) and the Today queue rules (`computeQueue()`).
- The other `.dc.html` files are tiny wrappers that mount `Main` with a different `start` screen, palette or mode.
- `canvas.json`: board layout. The Screens page holds the app screens; the Color schemes page holds the 8 palette boards. The chosen palette is **Paper & Ink**.

The files need the canvas runtime (`./support.js`), so they don't open on their own in a browser. Read them as source, or open the canvas link.

## Checks for mockup edits

```
python3 -I design/mockup/checks/check.py design/mockup/Main.dc.html design/mockup/checks/main.js
node design/mockup/checks/harness.js design/mockup/Main.dc.html
node design/mockup/checks/contrast.js
```

What each one checks:
- `check.py`: extracts the component script, runs `node --check` on it, and lists the template names.
- `harness.js`: confirms every `{{ }}` in the markup resolves, for all start screens × palettes × modes, and runs about 70 interaction scenarios.
- `contrast.js`: the WCAG contrast gate for all 8 themes.

If you change the mockup on the canvas, read the live files back first. The owner edits the canvas directly.
