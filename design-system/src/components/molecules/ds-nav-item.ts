/**
 * @element ds-nav-item
 * @summary Sidebar navigation item with icon, label, and active state.
 */

import { LitElement, html, css, type CSSResultGroup } from "lit";
import { customElement, property } from "lit/decorators.js";

@customElement("ds-nav-item")
export class DsNavItem extends LitElement {
	static styles: CSSResultGroup = css`
    :host { display: block; }

    a {
      display: flex;
      align-items: center;
      gap: var(--space-xs, 8px);
      padding: 8px 12px;
      padding-left: 10px;
      border-radius: var(--radius-default, 4px);
      border-left: 2px solid transparent;
      text-decoration: none;
      font-family: var(--font-label, 'JetBrains Mono', monospace);
      font-size: var(--typo-label-md-size, 14px);
      letter-spacing: var(--typo-label-md-tracking, 0.05em);
      font-weight: 500;
      line-height: 1.4;
      color: var(--color-on-surface-variant, #dcc1b8);
      transition: all 0.15s ease;
      cursor: pointer;
    }

    a:hover {
      color: var(--color-primary, #ffb59d);
      background: var(--color-surface-container, #271d1a);
    }

    a.active {
      color: var(--color-secondary, #e9c267);
      border-left-color: var(--color-primary, #ffb59d);
      background: var(--color-surface-container, #271d1a);
      font-weight: 700;
    }

    .icon {
      flex-shrink: 0;
      font-size: 20px;
      width: 20px;
      text-align: center;
    }
  `;

	@property({ type: String }) icon = "";
	@property({ type: String }) label = "";
	@property({ type: String }) href = "#";
	@property({ type: Boolean, reflect: true }) active = false;

	render() {
		return html`
      <a
        class="${this.active ? "active" : ""}"
        href="${this.href}"
        @click="${this._onClick}"
      >
        ${this.icon ? html`<span class="icon material-symbols-outlined ${this.active ? "fill" : ""}">${this.icon}</span>` : ""}
        <span>${this.label}</span>
      </a>
    `;
	}

	private _onClick(e: Event) {
		if (this.href === "#") {
			e.preventDefault();
		}
		this.dispatchEvent(
			new CustomEvent("navigate", {
				detail: { label: this.label, href: this.href },
				bubbles: true,
				composed: true,
			}),
		);
	}
}

declare global {
	interface HTMLElementTagNameMap {
		"ds-nav-item": DsNavItem;
	}
}
