name: Digital Scoarță / Pixel Loom
modes:
night:
name: Digital Scoarță / Pixel Loom Night
description: Midnight Wool — deep, nocturnal foundation
light:
name: Digital Scoarță / Pixel Loom Light
description: Daylight Wool — bright, sun-drenched atelier
colors:
night:
surface: "#1a110f"
surface-dim: "#1a110f"
surface-bright: "#423733"
surface-container-lowest: "#150c0a"
surface-container-low: "#231916"
surface-container: "#271d1a"
surface-container-high: "#322824"
surface-container-highest: "#3e322f"
on-surface: "#f1dfd9"
on-surface-variant: "#dcc1b8"
inverse-surface: "#f1dfd9"
inverse-on-surface: "#392e2b"
outline: "#a48b84"
outline-variant: "#56423c"
surface-tint: "#ffb59d"
primary: "#ffb59d"
on-primary: "#5d1800"
primary-container: "#b85736"
on-primary-container: "#fffaf9"
inverse-primary: "#9d4323"
secondary: "#e9c267"
on-secondary: "#3f2e00"
secondary-container: "#755800"
on-secondary-container: "#f8d074"
tertiary: "#76d5dc"
on-tertiary: "#00363a"
tertiary-container: "#008087"
on-tertiary-container: "#ecfeff"
error: "#ffb4ab"
on-error: "#690005"
error-container: "#93000a"
on-error-container: "#ffdad6"
primary-fixed: "#ffdbd0"
primary-fixed-dim: "#ffb59d"
on-primary-fixed: "#390b00"
on-primary-fixed-variant: "#7e2c0e"
secondary-fixed: "#ffdf9b"
secondary-fixed-dim: "#e9c267"
on-secondary-fixed: "#251a00"
on-secondary-fixed-variant: "#5b4300"
tertiary-fixed: "#93f2f9"
tertiary-fixed-dim: "#76d5dc"
on-tertiary-fixed: "#002022"
on-tertiary-fixed-variant: "#004f54"
background: "#1a110f"
on-background: "#f1dfd9"
surface-variant: "#3e322f"
light:
surface: "#fff8f6"
surface-dim: "#e9d6d1"
surface-bright: "#fff8f6"
surface-container-lowest: "#ffffff"
surface-container-low: "#fff1ed"
surface-container: "#fdeae4"
surface-container-high: "#f7e4df"
surface-container-highest: "#f1dfd9"
on-surface: "#231916"
on-surface-variant: "#56423c"
inverse-surface: "#392e2b"
inverse-on-surface: "#ffede8"
outline: "#89726b"
outline-variant: "#dcc1b8"
surface-tint: "#9d4323"
primary: "#983f20"
on-primary: "#ffffff"
primary-container: "#b85736"
on-primary-container: "#fffaf9"
inverse-primary: "#ffb59d"
secondary: "#775a03"
on-secondary: "#ffffff"
secondary-container: "#fed578"
on-secondary-container: "#785b04"
tertiary: "#00656b"
on-tertiary: "#ffffff"
tertiary-container: "#008087"
on-tertiary-container: "#ecfeff"
error: "#ba1a1a"
on-error: "#ffffff"
error-container: "#ffdad6"
on-error-container: "#93000a"
primary-fixed: "#ffdbd0"
primary-fixed-dim: "#ffb59d"
on-primary-fixed: "#390b00"
on-primary-fixed-variant: "#7e2c0e"
secondary-fixed: "#ffdf9b"
secondary-fixed-dim: "#e9c267"
on-secondary-fixed: "#251a00"
on-secondary-fixed-variant: "#5b4300"
tertiary-fixed: "#93f2f9"
tertiary-fixed-dim: "#76d5dc"
on-tertiary-fixed: "#002022"
on-tertiary-fixed-variant: "#004f54"
background: "#fff8f6"
on-background: "#231916"
surface-variant: "#f1dfd9"
typography:
headline-lg:
fontFamily: Newsreader
fontSize: 40px
fontWeight: "600"
lineHeight: "1.2"
letterSpacing: -0.02em
headline-md:
fontFamily: Newsreader
fontSize: 28px
fontWeight: "500"
lineHeight: "1.3"
body-lg:
fontFamily: Work Sans
fontSize: 18px
fontWeight: "400"
lineHeight: "1.6"
body-md:
fontFamily: Work Sans
fontSize: 16px
fontWeight: "400"
lineHeight: "1.5"
label-md:
fontFamily: JetBrains Mono
fontSize: 14px
fontWeight: "500"
lineHeight: "1.4"
letterSpacing: 0.05em
label-sm:
fontFamily: JetBrains Mono
fontSize: 12px
fontWeight: "500"
lineHeight: "1.4"
letterSpacing: 0.02em
headline-lg-mobile:
fontFamily: Newsreader
fontSize: 32px
fontWeight: "600"
lineHeight: "1.2"
rounded:
sm: 0.125rem
DEFAULT: 0.25rem
md: 0.375rem
lg: 0.5rem
xl: 0.75rem
full: 9999px
spacing:
base: 4px
xs: 8px
sm: 16px
md: 24px
lg: 40px
xl: 64px
gutter: 24px
margin: 32px

---

## Brand & Style

This design system is a "Digital Scoarță," blending the ancient tactile heritage of Romanian woven carpets with the precision of local-first computing. The system operates in two modes—**Night** and **Light**—each expressing the same loom metaphor through a different temporal lens.

The aesthetic is a sophisticated fusion of **Minimalism** and **Tactile Pixel-Art**. It avoids the sterility of modern cloud interfaces in favor of grounded, textile-like foundations and rhythmic structural elements. The UI feels constructed rather than rendered, using subtle pixel-level motifs on dividers and borders to simulate the "stitch" of a loom. It is designed for operators who value transparency, clarity, and the beauty of visible craftsmanship in their digital tools.

### Night Mode

Evokes the feeling of a midnight atelier—a digital loom where the glow of work-in-progress illuminates a deep, nocturnal foundation. Built on "Midnight Wool," it provides a high-comfort, low-fatigue environment that emphasizes focus through luminance rather than saturation.

### Light Mode

Transforms the system into a sun-drenched atelier—a digital loom where the clarity of daylight illuminates the intricate "stitching" of the interface. Built on "Daylight Wool," it provides a bright, high-clarity environment that emphasizes structure through subtle tonal shifts rather than aggressive shadows.

## Theme Switching

The system uses a **class-based** approach. The `.dark` class on `<html>` activates Night mode; its absence activates Light mode. This integrates seamlessly with Tailwind's `darkMode: "class"` configuration.

- **Default:** Respects `prefers-color-scheme: dark` when no explicit choice is stored
- **Persistence:** User preference is saved to `localStorage` under the key `nixpi-theme`
- **Toggle:** A sun/moon icon button in the topbar switches between modes
- **CSS Variables:** All `--color-*` tokens change value based on the `.dark` class, making every component react automatically
- **Tailwind Bridge:** `--tw-*` RGB channel variables allow Tailwind's `rgb()` color format to consume the same tokens

## Colors — Shared Principles

Both modes share the same color architecture rooted in natural dyes: **Madder Red** (primary), **Ochre** (secondary), and **Teal** (tertiary). The semantic mapping is identical across modes—only the concrete hex values shift to maintain proper contrast and mood for each lighting condition.

- **Foundations:** Use `Background` for the main application shell and `Surface` for nested navigation or sidebar elements. `Card` surfaces provide subtle definition against the base.
- **Typography:** Night mode uses `Bleached Linen` (on-surface) for high-contrast readability on the dark base; Light mode uses `Midnight Wool` on the bright base. `Weathered Stone` (on-surface-variant) handles secondary metadata in both modes.
- **Accents & Actions:** `Madder Red` (Primary) is the primary thread, reserved for key intents and high-priority states. `Ochre` (Secondary) is used for highlighting, active states, and focus indicators.
- **Semantics:** Moss/Teal (Success), and Ember (Error) are tuned for each mode's legibility, ensuring they harmoniously integrate with the warm, organic base.

### Night Mode Colors

The palette is rooted in natural dyes emerging from a deep shadow. "Midnight Wool" provides a high-comfort, low-fatigue environment that emphasizes focus through luminance rather than saturation.

### Light Mode Colors

The palette is rooted in natural dyes applied to a bleached textile base. "Daylight Wool" provides a bright, high-clarity environment that emphasizes structure through subtle tonal shifts rather than aggressive shadows.

## Typography

The typography strategy is **shared across both modes**—it balances editorial elegance with technical precision.

- **Headings:** Use **Newsreader** for all headers. It provides a literary, authoritative character that feels like a physical ledger or an ancestral loom's pattern book.
- **Interface:** **Work Sans** is used for its grounded, highly legible Swiss-inspired terminals, ensuring clarity in functional UI elements.
- **Data & Logs:** **JetBrains Mono** is utilized for metadata, tags, and system logs, reinforcing the local-first, operator-centric nature of this design system. It brings a technical "woven" rhythm to small-scale text.

## Layout & Spacing

Shared across both modes. This design system employs a **Fixed Grid** philosophy that mimics the rigid yet organic structure of a woven textile.

- **Structure:** A 12-column grid for desktop with 24px gutters. Content is contained within a maximum width of 1280px to maintain focus.
- **Rhythm:** All vertical spacing must be a multiple of the 4px base unit.
- **Dividers:** Horizontal and vertical lines are not mere hairlines; they should use a "pixel-stitch" pattern—alternating 1px dashes that suggest a thread path.
- **Mobile:** Transition to a 4-column grid with 16px margins. Headlines scale down but maintain their editorial weight.

## Elevation & Depth

This system rejects heavy shadows in favor of **Tonal Layers** and **Structural Outlines**. The mechanism differs subtly between modes:

- **Night Mode:** Depth is communicated through luminance steps—higher layers glow slightly brighter against the dark base.
- **Light Mode:** Depth is communicated through "bleach" levels—higher layers appear slightly more vibrant or use crisp outlines to simulate separation from the off-white base.
- **Stacking (shared):** The closer an element is to the user, the more defined its border becomes. Every surface and card uses a 1px solid border.
- **Borders:** The border color is typically `outline-variant`, or `primary` for active focus.
- **Pixel Motifs:** Use 4x4 pixel "notches" or corner accents on containers to denote interactive or important structural hubs. This replaces the need for ambient shadows.

## Shapes

The shape language is **shared across both modes**—primarily architectural and lean, prioritizing structural integrity with only a minimal softening.

- **Corners:** Use a consistent **4px (0.25rem)** radius for all cards, buttons, and inputs. This provides a "sharp-tactile" feel—disciplined and grid-aligned, but avoiding the clinical harshness of perfectly square corners.
- **Intersections:** Elements should feel like they are "interlocked" rather than floating. Dividers should meet borders at 90-degree angles, creating a grid-like textile map.
- **Icons:** Use thick-stroke (2px) monolinear icons. Avoid rounded icon sets; prefer geometric or slightly pixelated representations.

## Components

Component specifications are **mode-aware**—colors reference semantic tokens that shift automatically.

- **Buttons:** Rectangular with **4px radius**. Primary buttons use `primary-container` background with `on-primary-container` text. Secondary buttons use a surface background with a 1px `outline-variant` border.
- **Input Fields:** Use mode-appropriate backgrounds with a bottom-only 1px border that extends into a "stitch" pattern on focus. Use **JetBrains Mono** for input text.
- **Cards:** Flat surfaces with a 1px border and **4px radius**. For interactive cards, add a 4-pixel "weaving" motif in the top-right corner.
- **Dividers:** Instead of solid lines, use a repeating 1px dash/gap pattern. This creates the "Pixel Loom" effect.
- **Status Chips:** Small, rectangular tags using `JetBrains Mono`. Backgrounds match the semantic color at 15% opacity with a solid 1px border of the same color.
- **Local-First Indicators:** A specific component (the "Hearth") should reside in the corner of the UI, using a pixelated flame or loom icon to show sync status and local database health.
- **Theme Toggle:** A sun/moon icon button in the topbar toggles between Night and Light mode. Uses `material-symbols-outlined` icons: `dark_mode` (night active) and `light_mode` (light active).
