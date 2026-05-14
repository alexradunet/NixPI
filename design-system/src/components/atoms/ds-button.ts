/**
 * @element ds-button
 * @summary Primary action component — Madder Red / Ochre variants.
 *
 * Atomic: Button
 * Variants: filled | outlined | text | fab
 * Sizes: sm | md | lg
 */

import { LitElement, html, css, type CSSResultGroup } from "lit";
import { customElement, property } from "lit/decorators.js";

@customElement("ds-button")
export class DsButton extends LitElement {
	static styles: CSSResultGroup = css`
    :host {
      display: inline-block;
    }

    button {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: var(--space-xs, 8px);
      border: 1px solid transparent;
      border-radius: var(--radius-default, 4px);
      font-family: var(--font-label, 'JetBrains Mono', monospace);
      cursor: pointer;
      white-space: nowrap;
      user-select: none;
      position: relative;
      overflow: hidden;
      transition: all 0.15s ease-out;

      &:disabled {
        opacity: 0.5;
        cursor: not-allowed;
      }
    }

    /* ── Variant: filled ── */
    .variant-filled {
      background-color: var(--color-primary-container, #b85736);
      color: var(--color-on-primary-container, #fffaf9);
      border-color: var(--color-primary-container, #b85736);

      &:hover:not(:disabled) {
        background-color: var(--color-inverse-primary, #9d4323);
        border-color: var(--color-inverse-primary, #9d4323);
      }

      &:active:not(:disabled) {
        transform: scale(0.98);
      }
    }

    /* ── Variant: outlined ── */
    .variant-outlined {
      background-color: transparent;
      color: var(--color-secondary, #e9c267);
      border-color: var(--color-secondary, #e9c267);

      &:hover:not(:disabled) {
        background-color: rgba(233, 194, 103, 0.08);
      }

      &:active:not(:disabled) {
        transform: scale(0.98);
      }
    }

    /* ── Variant: text ── */
    .variant-text {
      background-color: transparent;
      color: var(--color-on-surface-variant, #dcc1b8);
      border: none;
      border-radius: var(--radius-full, 9999px);

      &:hover:not(:disabled) {
        background-color: var(--color-surface-container-high, #322824);
        color: var(--color-primary, #ffb59d);
      }

      &:active:not(:disabled) {
        transform: scale(0.95);
      }
    }

    /* ── Variant: fab (icon-only circle) ── */
    .variant-fab {
      width: 40px;
      height: 40px;
      border-radius: var(--radius-full, 9999px);
      background-color: transparent;
      color: var(--color-on-surface-variant, #dcc1b8);
      border: none;
      padding: 0;

      &:hover:not(:disabled) {
        background-color: var(--color-surface-container-high, #322824);
      }

      &:active:not(:disabled) {
        transform: scale(0.95);
      }
    }

    .variant-fab.primary {
      background-color: var(--color-primary-container, #b85736);
      color: var(--color-on-primary-container, #fffaf9);

      &:hover:not(:disabled) {
        background-color: var(--color-inverse-primary, #9d4323);
      }
    }

    /* ── Sizes ── */
    .size-sm { padding: 4px 10px; font-size: var(--typo-label-sm-size, 12px); }
    .size-md { padding: 6px 14px; font-size: var(--typo-label-md-size, 14px); }
    .size-lg { padding: 10px 20px; font-size: var(--typo-label-md-size, 14px); }

    .size-sm.fab { width: 32px; height: 32px; }
    .size-md.fab { width: 40px; height: 40px; }
    .size-lg.fab { width: 48px; height: 48px; }

    /* ── Full width ── */
    .full-width {
      width: 100%;
    }

    /* ── Corner notch for filled variant ── */
    .notch::after {
      content: '';
      position: absolute;
      top: 0;
      right: 0;
      width: 4px;
      height: 4px;
      background-color: var(--color-outline-variant, #56423c);
    }
  `;

	@property({ type: String }) variant: "filled" | "outlined" | "text" | "fab" =
		"filled";
	@property({ type: String }) size: "sm" | "md" | "lg" = "md";
	@property({ type: Boolean }) disabled = false;
	@property({ type: Boolean }) full = false;
	@property({ type: Boolean }) notch = false;
	@property({ type: Boolean, reflect: true }) primary = false;
	@property({ type: String }) type = "button";

	render() {
		const classes = [
			`variant-${this.variant}`,
			`size-${this.size}`,
			this.variant === "fab" ? "fab" : "",
			this.full ? "full-width" : "",
			this.notch ? "notch" : "",
			this.primary ? "primary" : "",
		]
			.filter(Boolean)
			.join(" ");

		return html`
      <button
        class="${classes}"
        ?disabled="${this.disabled}"
        type="${this.type}"
        @click="${this._handleClick}"
      >
        <slot></slot>
      </button>
    `;
	}

	private _handleClick(e: Event) {
		if (this.disabled) {
			e.preventDefault();
			e.stopPropagation();
			return;
		}
	}
}

declare global {
	interface HTMLElementTagNameMap {
		"ds-button": DsButton;
	}
}
