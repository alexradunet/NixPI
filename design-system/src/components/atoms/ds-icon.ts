/**
 * @element ds-icon
 * @summary Material Symbols Outlined icon wrapper with size & color.
 */

import { LitElement, html, css, type CSSResultGroup } from "lit";
import { customElement, property } from "lit/decorators.js";

declare type IconSize = "xs" | "sm" | "md" | "lg";
declare type IconColor =
	| "primary"
	| "secondary"
	| "tertiary"
	| "error"
	| "default"
	| "onSurface"
	| "onSurfaceVariant";

const COLOR_MAP: Record<string, string> = {
	primary: "--color-primary",
	secondary: "--color-secondary",
	tertiary: "--color-tertiary",
	error: "--color-error",
	default: "--color-on-surface",
	onSurface: "--color-on-surface",
	onSurfaceVariant: "--color-on-surface-variant",
};

@customElement("ds-icon")
export class DsIcon extends LitElement {
	static styles: CSSResultGroup = css`
    :host { display: inline-flex; align-items: center; }

    .icon {
      font-variation-settings: 'wght' 400;
      user-select: none;
    }

    .size-xs { font-size: 14px; }
    .size-sm { font-size: 18px; }
    .size-md { font-size: 24px; }
    .size-lg { font-size: 32px; }

    .fill { font-variation-settings: 'wght' 400, 'FILL' 1; }
  `;

	@property({ type: String }) name = "";
	@property({ type: String }) size: IconSize = "md";
	@property({ type: String }) color: IconColor = "default";
	@property({ type: Boolean }) fill = false;

	__computeColor(): string {
		const token = COLOR_MAP[this.color] || "--color-on-surface";
		return `var(${token}, #f1dfd9)`;
	}

	render() {
		return html`
      <span
        class="icon size-${this.size} ${this.fill ? "fill" : ""} material-symbols-outlined"
        style="color: ${this.__computeColor()}"
      >${this.name}</span>
    `;
	}
}

declare global {
	interface HTMLElementTagNameMap {
		"ds-icon": DsIcon;
	}
}
