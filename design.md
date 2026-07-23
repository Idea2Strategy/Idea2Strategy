# Idea2Strategy UI design system

## Status and scope

This document is the implementation guide for the standalone `prototype/` product UI. Signal Studio (concept C) is the only product visual system. Terminal and balanced variants, variant labels, and their switch are retired.

The design goal is a calm, information-dense trading workspace. Every screen should feel like the same product before it feels like a different feature.

## Layout

- Desktop content width: `1420px` maximum.
- Product navigation: `72px` tall, horizontal, sticky. Each primary navigation target is `86px` wide.
- Page outer padding: `32px` desktop, `16px` narrow.
- Page section gap: `24px`.
- Component grid gap: `16px`.
- Dense control gap: `8px`.
- Use one alignment edge for the page heading, primary action, panels, and tables.
- Do not introduce a local margin when an existing parent `gap` can express the relationship.

## Spacing scale

Only use the shared 4px-based scale:

| Token | Value | Use |
| --- | ---: | --- |
| `--space-1` | `4px` | icon/text micro gap |
| `--space-2` | `8px` | compact controls |
| `--space-3` | `12px` | control padding |
| `--space-4` | `16px` | card padding and grid gap |
| `--space-5` | `24px` | section separation |
| `--space-6` | `32px` | page padding |
| `--space-8` | `48px` | major vertical separation |

Arbitrary values are reserved for geometry such as chart coordinates and block notches, not normal layout spacing.

## Type system

- Product font: `Pretendard`, `Inter`, `Noto Sans KR`, system sans-serif.
- Code, values, timestamps, tickers, and micro labels: `Cascadia Code`, `SFMono-Regular`, `Consolas`, monospace.
- Do not mix display fonts between pages.
- Headings use the product font, not monospace.
- English uppercase is reserved for navigation, editor mode, ticker symbols, and short eyebrow labels.
- Korean and English body copy use the same size and line-height.

| Role | Size / line-height | Weight |
| --- | --- | ---: |
| Page title | `40px / 1.1` | 700 |
| Section title | `16px / 1.35` | 700 |
| Card title | `14px / 1.4` | 700 |
| Body | `13px / 1.6` | 400 |
| Control | `12px / 1.4` | 650 |
| Caption | `11px / 1.45` | 500 |
| Micro label | `9px / 1.3` | 700 |

Use `-0.035em` tracking only for page titles. Body text and Korean labels use normal tracking. Uppercase micro labels may use `0.08em`.

## Color and material

- Product theme remains the dark Signal Studio system; the financial red/blue reference is scoped to Basic editor blocks.
- Dark background: `#111512`; surface: `#171c18`; main text: `#d5ddd6`.
- Product accent remains sage-lime `#afc878`.
- The accent is used for current selection, one primary action, focus, and live state.
- Accent glows are not used on navigation or primary buttons. Small operational live dots may use a restrained `4px` halo.
- Green, amber, red, and blue are semantic. Buy and sell colors must not become general decoration.
- Basic buy blocks use a clean red ramp from `#f2c7c7` to `#cf4545`.
- Basic sell blocks use a clean blue ramp from `#dce5ff` to `#4f73df`.
- Do not mix ochre, purple, gray-green, or other category colors into the buy/sell flow.
- Borders are one pixel. Shadows are subtle and used only for overlays.
- Product background grids stay below `2%` opacity and must not compete with content.
- Standard radius is `4px`; overlays may use `8px`. Strategy blocks keep their functional geometry.

## Component rules

- Primary buttons are `40px` high. Compact icon controls are `36px`.
- Inputs and selects are `36px` high.
- Panels use consistent border, radius, and `16px` internal padding.
- Table rows are at least `64px` high and share one baseline.
- Page headings have `24px` below them.
- Every product page uses the shared `PageHeading` composition: `9px` eyebrow, `40px/44px` title, and `13px/20px` support copy.
- The browser always reserves the vertical scrollbar gutter so navigation never moves when page height changes.
- Popovers overlay content and never cause layout movement.
- Basic strategy groups start with a colored header and end with a full-width fixed output. Buy and sell groups have equal height.

## Language

- Supported languages: Korean (`ko`) and English (`en`).
- The language selector lives in the global product navigation.
- The selected language is persisted locally and applied to `document.documentElement.lang`.
- Brand names, ticker symbols, Basic/Pro, Competition, and financial abbreviations remain unchanged.
- Translation must cover visible text, placeholder text, and accessible labels.
- Layouts must not depend on Korean text length; controls allow English labels without clipping.

## Responsive behavior

- At `1380px`, global search collapses before it can overlap primary navigation.
- At `1120px`, the wordmark may collapse before primary navigation.
- At `800px`, primary navigation moves to a horizontally scrollable second row.
- Editors switch to the existing read-only narrow-screen notice.
- Content order and language selection remain available at every supported width.

## Review checklist

- Uses only the shared font roles and spacing tokens.
- Page edges and section baselines align.
- No terminal/balanced terminology or switch remains.
- Korean and English can both complete the same interaction.
- No translated label is clipped at 1280px.
- Focus is visible and icon-only controls have accessible labels.
- Hover and click do not shift surrounding layout.
