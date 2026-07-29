# I2S brand asset

## Decision

- The user-supplied `i2s_logo_vector (1).svg` is the canonical visual source for the prototype navigation mark.
- The two supplied PNG files remain reference exports; the web prototype uses SVG so the mark stays sharp at different display densities.
- The logo artwork, gradients, title, and description are preserved. Only the SVG view box is tightened around the existing artwork to remove source-canvas whitespace at navigation sizes.

## UI usage

- Balanced navigation: display the complete I2S mark inside a 42px white tile.
- Terminal navigation: display the same complete mark inside a 32px white tile while keeping the existing terminal wordmark and layout.
- Use `Idea2Strategy` as the accessible image alternative.
- Do not recolor the supplied mark. A white tile preserves contrast in both light and dark themes.
