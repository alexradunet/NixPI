/**
 * @element ds-avatar
 * @summary Circular avatar with border and fallback.
 */

import { LitElement, html, css, type CSSResultGroup } from "lit";
import { customElement, property } from "lit/decorators.js";

@customElement("ds-avatar")
export class DsAvatar extends LitElement {
	static styles: CSSResultGroup = css`
    :host { display: inline-block; }

    .avatar {
      width: 32px;
      height: 32px;
      border-radius: var(--radius-full, 9999px);
      border: 1px solid var(--color-outline-variant, #56423c);
      background-color: var(--color-surface-container-high, #322824);
      display: flex;
      align-items: center;
      justify-content: center;
      overflow: hidden;
      cursor: pointer;
      transition: transform 0.1s ease;
    }

    .avatar:active {
      transform: scale(0.95);
    }

    .avatar img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }

    .avatar .fallback {
      font-family: var(--font-label, 'JetBrains Mono', monospace);
      font-size: 11px;
      font-weight: 500;
      color: var(--color-primary, #ffb59d);
    }

    .size-sm  { width: 24px; height: 24px; }
    .size-md  { width: 32px; height: 32px; }
    .size-lg  { width: 40px; height: 40px; }
    .size-xl  { width: 48px; height: 48px; }
  `;

	@property({ type: String }) src = "";
	@property({ type: String }) alt = "";
	@property({ type: String }) fallback = "π";
	@property({ type: String }) size: "sm" | "md" | "lg" | "xl" = "md";

	render() {
		return html`
      <div class="avatar size-${this.size}">
        ${
					this.src
						? html`<img src="${this.src}" alt="${this.alt}" />`
						: html`<span class="fallback">${this.fallback}</span>`
				}
      </div>
    `;
	}
}

declare global {
	interface HTMLElementTagNameMap {
		"ds-avatar": DsAvatar;
	}
}
