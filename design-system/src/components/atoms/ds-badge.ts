/**
 * @element ds-badge
 * @summary Status chip / tag with semantic colors.
 */

import { LitElement, html, css, type CSSResultGroup } from "lit";
import { customElement, property } from "lit/decorators.js";

@customElement("ds-badge")
export class DsBadge extends LitElement {
	static styles: CSSResultGroup = css`
    :host { display: inline-block; }

    span {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      padding: 3px 8px;
      border-radius: var(--radius-default, 4px);
      font-family: var(--font-label, 'JetBrains Mono', monospace);
      font-size: var(--typo-label-sm-size, 12px);
      letter-spacing: var(--typo-label-sm-tracking, 0.02em);
      font-weight: 500;
      line-height: 1.4;
      white-space: nowrap;
    }

    .variant-default {
      background: color-mix(in srgb, var(--color-on-surface-variant, #dcc1b8) 15%, transparent);
      border: 1px solid var(--color-on-surface-variant, #dcc1b8);
      color: var(--color-on-surface-variant, #dcc1b8);
    }

    .variant-primary {
      background: color-mix(in srgb, var(--color-primary-container, #b85736) 20%, transparent);
      border: 1px solid var(--color-primary-container, #b85736);
      color: var(--color-primary, #ffb59d);
    }

    .variant-secondary {
      background: color-mix(in srgb, var(--color-secondary, #e9c267) 15%, transparent);
      border: 1px solid var(--color-secondary, #e9c267);
      color: var(--color-secondary, #e9c267);
    }

    .variant-tertiary {
      background: color-mix(in srgb, var(--color-tertiary, #76d5dc) 15%, transparent);
      border: 1px solid var(--color-tertiary, #76d5dc);
      color: var(--color-tertiary, #76d5dc);
    }

    .variant-error {
      background: color-mix(in srgb, var(--color-error, #ffb4ab) 15%, transparent);
      border: 1px solid var(--color-error, #ffb4ab);
      color: var(--color-error, #ffb4ab);
    }

    .dot {
      width: 6px;
      height: 6px;
      border-radius: 50%;
      background: currentColor;
      flex-shrink: 0;
    }
  `;

	@property({ type: String }) variant:
		| "default"
		| "primary"
		| "secondary"
		| "tertiary"
		| "error" = "default";
	@property({ type: Boolean }) dot = false;

	render() {
		return html`
      <span class="variant-${this.variant}">
        ${this.dot ? html`<span class="dot"></span>` : ""}
        <slot></slot>
      </span>
    `;
	}
}

declare global {
	interface HTMLElementTagNameMap {
		"ds-badge": DsBadge;
	}
}
