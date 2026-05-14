/**
 * @element ds-card
 * @summary Elevated surface container with optional corner-notch.
 */

import { LitElement, html, css, type CSSResultGroup } from "lit";
import { customElement, property } from "lit/decorators.js";

@customElement("ds-card")
export class DsCard extends LitElement {
	static styles: CSSResultGroup = css`
    :host { display: block; }

    .card {
      background: var(--color-surface-container, #271d1a);
      border: 1px solid var(--color-outline-variant, #56423c);
      border-radius: var(--radius-default, 4px);
      padding: var(--space-sm, 16px);
      transition: border-color 0.15s ease;
      position: relative;
    }

    .card.interactive:hover {
      border-color: var(--color-outline, #a48b84);
    }

    .card.interactive { cursor: pointer; }

    /* Corner notch */
    .card.notch::after {
      content: '';
      position: absolute;
      top: 0;
      right: 0;
      width: 4px;
      height: 4px;
      background-color: var(--color-outline-variant, #56423c);
      pointer-events: none;
    }

    .card-header {
      margin-bottom: var(--space-xs, 8px);
    }

    .card-title {
      font-family: var(--font-headline, 'Newsreader', serif);
      font-size: 18px;
      font-weight: 500;
      line-height: 1.3;
      color: var(--color-on-surface, #f1dfd9);
      margin: 0;
    }

    .card-subtitle {
      font-family: var(--font-label, 'JetBrains Mono', monospace);
      font-size: var(--typo-label-sm-size, 12px);
      color: var(--color-on-surface-variant, #dcc1b8);
      margin: 2px 0 0 0;
    }

    .card-actions {
      display: flex;
      justify-content: flex-end;
      gap: var(--space-xs, 8px);
      margin-top: var(--space-sm, 16px);
      padding-top: var(--space-xs, 8px);
      border-top: 1px dashed var(--color-outline-variant, #56423c);
    }
  `;

	@property({ type: String }) title = "";
	@property({ type: String }) subtitle = "";
	@property({ type: Boolean }) interactive = false;
	@property({ type: Boolean }) notch = false;

	render() {
		const classes = [
			"card",
			this.interactive ? "interactive" : "",
			this.notch ? "notch" : "",
		]
			.filter(Boolean)
			.join(" ");

		return html`
      <div class="${classes}" @click="${this._onClick}">
        ${
					this.title
						? html`
          <div class="card-header">
            <h3 class="card-title">${this.title}</h3>
            ${this.subtitle ? html`<p class="card-subtitle">${this.subtitle}</p>` : ""}
          </div>
        `
						: ""
				}
        <div class="card-content">
          <slot></slot>
        </div>
        <slot name="actions"></slot>
      </div>
    `;
	}

	private _onClick(_e: Event) {
		if (!this.interactive) return;
		this.dispatchEvent(
			new CustomEvent("card-click", {
				bubbles: true,
				composed: true,
			}),
		);
	}
}

declare global {
	interface HTMLElementTagNameMap {
		"ds-card": DsCard;
	}
}
