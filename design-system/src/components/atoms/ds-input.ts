/**
 * @element ds-input
 * @summary Text input with bottom-stitch border focus effect.
 *
 * Atomic: Text Field
 */

import { LitElement, html, css, type CSSResultGroup } from "lit";
import { customElement, property } from "lit/decorators.js";

@customElement("ds-input")
export class DsInput extends LitElement {
	static styles: CSSResultGroup = css`
    :host {
      display: block;
    }

    .input-wrapper {
      position: relative;
      width: 100%;
    }

    /* Pixel-stitch underline — decorative */
    .input-wrapper::after {
      content: '';
      position: absolute;
      bottom: 0;
      left: 0;
      right: 0;
      height: 1px;
      background-image: linear-gradient(
        to right,
        var(--color-outline-variant, #56423c) 50%,
        transparent 50%
      );
      background-size: 8px 1px;
      background-repeat: repeat-x;
      opacity: 0;
      transition: opacity 0.2s ease;
    }

    .input-wrapper:focus-within::after {
      opacity: 1;
    }

    input,
    textarea {
      width: 100%;
      padding: 10px 12px;
      background-color: var(--color-surface-container, #271d1a);
      color: var(--color-on-surface, #f1dfd9);
      font-family: var(--font-label, 'JetBrains Mono', monospace);
      font-size: var(--typo-label-md-size, 14px);
      line-height: var(--typo-label-md-line, 1.4);
      letter-spacing: var(--typo-label-md-tracking, 0.05em);
      border: none;
      border-bottom: 1px solid var(--color-outline-variant, #56423c);
      border-radius: var(--radius-default, 4px) var(--radius-default, 4px) 0 0;
      outline: none;
      transition: border-color 0.15s ease;
      box-sizing: border-box;
    }

    input::placeholder,
    textarea::placeholder {
      color: var(--color-on-surface-variant, #dcc1b8);
      opacity: 0.5;
    }

    input:focus,
    textarea:focus {
      border-bottom-color: var(--color-primary, #ffb59d);
    }

    input:disabled,
    textarea:disabled {
      opacity: 0.4;
      cursor: not-allowed;
    }

    textarea {
      resize: vertical;
      min-height: 64px;
    }

    /* Optional label */
    label {
      display: block;
      font-family: var(--font-label, 'JetBrains Mono', monospace);
      font-size: var(--typo-label-sm-size, 12px);
      letter-spacing: var(--typo-label-sm-tracking, 0.02em);
      color: var(--color-on-surface-variant, #dcc1b8);
      margin-bottom: var(--space-xs, 8px);
    }

    /* Helper / error text */
    .helper {
      font-family: var(--font-label, 'JetBrains Mono', monospace);
      font-size: 11px;
      color: var(--color-on-surface-variant, #dcc1b8);
      margin-top: var(--space-xs, 8px);
    }

    .helper.error {
      color: var(--color-error, #ffb4ab);
    }
  `;

	@property({ type: String }) type = "text";
	@property({ type: String }) placeholder = "";
	@property({ type: String }) value = "";
	@property({ type: String }) label = "";
	@property({ type: String }) helper = "";
	@property({ type: Boolean }) error = false;
	@property({ type: Boolean }) disabled = false;
	@property({ type: Boolean }) multiline = false;
	@property({ type: Number }) rows = 3;

	render() {
		return html`
      ${this.label ? html`<label for="field">${this.label}</label>` : ""}
      <div class="input-wrapper">
        ${
					this.multiline
						? html`<textarea
              id="field"
              .value="${this.value}"
              placeholder="${this.placeholder}"
              ?disabled="${this.disabled}"
              rows="${this.rows}"
              @input="${this._onInput}"
            ></textarea>`
						: html`<input
              id="field"
              type="${this.type}"
              .value="${this.value}"
              placeholder="${this.placeholder}"
              ?disabled="${this.disabled}"
              @input="${this._onInput}"
            />`
				}
      </div>
      ${
				this.helper
					? html`<div class="helper ${this.error ? "error" : ""}">${this.helper}</div>`
					: ""
			}
    `;
	}

	private _onInput(e: InputEvent) {
		const target = e.target as HTMLInputElement | HTMLTextAreaElement;
		this.value = target.value;
		this.dispatchEvent(
			new CustomEvent("change", {
				detail: { value: this.value },
				bubbles: true,
				composed: true,
			}),
		);
	}
}

declare global {
	interface HTMLElementTagNameMap {
		"ds-input": DsInput;
	}
}
