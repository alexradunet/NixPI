/**
 * @element ds-divider
 * @summary Pixel-stitch divider (horizontal or vertical).
 */

import { LitElement, html, css, type CSSResultGroup } from "lit";
import { customElement, property } from "lit/decorators.js";

@customElement("ds-divider")
export class DsDivider extends LitElement {
	static styles: CSSResultGroup = css`
    :host { display: block; }

    hr {
      border: none;
      margin: 0;
      background-repeat: repeat;
    }

    .orientation-h {
      height: 1px;
      width: 100%;
      background-image: linear-gradient(
        to right,
        var(--color-outline-variant, #56423c) 50%,
        transparent 50%
      );
      background-size: 8px 1px;
    }

    .orientation-v {
      width: 1px;
      height: 100%;
      background-image: linear-gradient(
        to bottom,
        var(--color-outline-variant, #56423c) 50%,
        transparent 50%
      );
      background-size: 1px 8px;
    }
  `;

	@property({ type: String }) orientation: "h" | "v" = "h";

	render() {
		return html`<hr class="orientation-${this.orientation}" />`;
	}
}

declare global {
	interface HTMLElementTagNameMap {
		"ds-divider": DsDivider;
	}
}
