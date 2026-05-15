/**
 * @element ds-avatar
 * @summary Circular avatar with slot/fallback text.
 */

import { LitElement, html, css, type CSSResultGroup } from "lit";
import { customElement, property } from "lit/decorators.js";

@customElement("ds-avatar")
export class DsAvatar extends LitElement {
	static styles: CSSResultGroup = css`
    :host {
      display: inline-flex;
      align-items: center;
      justify-content: center;
    }

    .avatar {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      border: 1px solid var(--color-outline-variant, #56423c);
      border-radius: var(--radius-full, 9999px);
      background: var(--color-surface-container-high, #322824);
      color: var(--color-primary, #ffb59d);
      font-family: var(--font-label, 'JetBrains Mono', monospace);
      overflow: hidden;
      user-select: none;
    }

    .size-sm { width: 24px; height: 24px; font-size: 11px; }
    .size-md { width: 32px; height: 32px; font-size: 12px; }
    .size-lg { width: 40px; height: 40px; font-size: 14px; }
  `;

	@property({ type: String }) fallback = "";
	@property({ type: String }) size: "sm" | "md" | "lg" = "md";

	render() {
		return html`
      <span class="avatar size-${this.size}">
        <slot>${this.fallback}</slot>
      </span>
    `;
	}
}

declare global {
	interface HTMLElementTagNameMap {
		"ds-avatar": DsAvatar;
	}
}
