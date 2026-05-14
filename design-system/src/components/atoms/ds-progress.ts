/**
 * @element ds-progress
 * @summary Thin progress bar / meter.
 */

import { LitElement, html, css, type CSSResultGroup } from "lit";
import { customElement, property } from "lit/decorators.js";

@customElement("ds-progress")
export class DsProgress extends LitElement {
	static styles: CSSResultGroup = css`
    :host { display: block; }

    .track {
      height: 2px;
      background: var(--color-outline-variant, #56423c);
      width: 100%;
      border-radius: 1px;
      overflow: hidden;
    }

    .bar {
      height: 100%;
      background: var(--color-on-surface, #f1dfd9);
      transition: width 0.5s ease;
      border-radius: 1px;
    }

    .label-row {
      display: flex;
      justify-content: space-between;
      margin-bottom: var(--space-xs, 8px);
    }

    .label {
      font-family: var(--font-label, 'JetBrains Mono', monospace);
      font-size: 10px;
      font-weight: 500;
      letter-spacing: 0.05em;
      text-transform: uppercase;
      color: var(--color-on-surface-variant, #dcc1b8);
    }

    .value {
      font-family: var(--font-label, 'JetBrains Mono', monospace);
      font-size: 10px;
      font-weight: 500;
      color: var(--color-on-surface, #f1dfd9);
    }
  `;

	@property({ type: Number }) value = 0;
	@property({ type: Number }) max = 100;
	@property({ type: String }) label = "";

	__pct(): number {
		return Math.min(100, Math.max(0, (this.value / this.max) * 100));
	}

	render() {
		return html`
      ${
				this.label
					? html`
        <div class="label-row">
          <span class="label">${this.label}</span>
          <span class="value">${Math.round(this.__pct())}%</span>
        </div>
      `
					: ""
			}
      <div class="track">
        <div class="bar" style="width: ${this.__pct()}%"></div>
      </div>
    `;
	}
}

declare global {
	interface HTMLElementTagNameMap {
		"ds-progress": DsProgress;
	}
}
