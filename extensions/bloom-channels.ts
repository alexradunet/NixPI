import { createServer, type Server, type Socket } from "node:net";
import type {
	AgentEndEvent,
	ExtensionAPI,
	ExtensionContext,
	SessionShutdownEvent,
	SessionStartEvent,
} from "@mariozechner/pi-coding-agent";

interface ChannelInfo {
	socket: Socket;
	connected: boolean;
}

interface ChannelContext {
	channel: string;
	from: string;
}

interface MediaInfo {
	kind: string;
	mimetype: string;
	filepath: string;
	duration?: number;
	size: number;
	caption?: string;
}

interface IncomingMessage {
	type: "register" | "message";
	channel: string;
	from?: string;
	text?: string;
	timestamp?: number;
	media?: MediaInfo;
}

const PORT = parseInt(process.env.BLOOM_CHANNELS_PORT ?? "18800", 10);

export default function (pi: ExtensionAPI) {
	const channels = new Map<string, ChannelInfo>();
	let lastChannelContext: ChannelContext | null = null;
	let server: Server | null = null;
	let lastCtx: ExtensionContext | null = null;

	function updateWidget(ctx: ExtensionContext): void {
		if (!ctx.hasUI) return;
		const lines: string[] = [];
		for (const [name, info] of channels) {
			lines.push(`${name}: ${info.connected ? "connected" : "disconnected"}`);
		}
		if (lines.length > 0) {
			ctx.ui.setWidget("bloom-channels", lines);
		} else {
			ctx.ui.setWidget("bloom-channels", undefined);
		}
		ctx.ui.setStatus("bloom-channels", `Channels: ${channels.size} connected`);
	}

	function removeChannel(name: string): void {
		channels.delete(name);
		if (lastCtx) updateWidget(lastCtx);
	}

	function sendToSocket(socket: Socket, obj: object): void {
		socket.write(`${JSON.stringify(obj)}\n`);
	}

	function handleSocketData(socket: Socket, data: string): void {
		const lines = data.split("\n");
		for (const line of lines) {
			const trimmed = line.trim();
			if (!trimmed) continue;
			let msg: IncomingMessage;
			try {
				msg = JSON.parse(trimmed) as IncomingMessage;
			} catch {
				console.error("[bloom-channels] Failed to parse message:", trimmed);
				continue;
			}

			if (msg.type === "register") {
				const name = msg.channel;
				channels.set(name, { socket, connected: true });
				sendToSocket(socket, { type: "status", connected: true });
				if (lastCtx) updateWidget(lastCtx);
				console.log(`[bloom-channels] Channel registered: ${name}`);
			} else if (msg.type === "message") {
				const from = msg.from ?? "unknown";
				const channel = msg.channel;
				lastChannelContext = { channel, from };

				let prompt: string;
				if (msg.media) {
					const m = msg.media;
					const sizeKB = Math.round(m.size / 1024);
					const duration = m.duration ? ` ${m.duration}s,` : "";
					prompt = `[${channel}: ${from}] sent ${m.kind} (${duration} ${sizeKB}KB, ${m.mimetype}). File: ${m.filepath}`;
					if (m.caption) prompt += `\nCaption: ${m.caption}`;
				} else {
					prompt = `[${channel}: ${from}] ${msg.text ?? ""}`;
				}

				if (lastCtx?.isIdle()) {
					pi.sendUserMessage(prompt);
				} else {
					pi.sendUserMessage(prompt, { deliverAs: "followUp" });
				}
			}
		}
	}

	pi.on("session_start", (_event: SessionStartEvent, ctx: ExtensionContext) => {
		lastCtx = ctx;
		server = createServer((socket: Socket) => {
			let buffer = "";

			socket.on("data", (chunk: Buffer) => {
				buffer += chunk.toString();
				const newlineIdx = buffer.lastIndexOf("\n");
				if (newlineIdx === -1) return;
				const complete = buffer.slice(0, newlineIdx + 1);
				buffer = buffer.slice(newlineIdx + 1);
				handleSocketData(socket, complete);
			});

			socket.on("error", (err: Error) => {
				console.error("[bloom-channels] Socket error:", err.message);
				// Remove any channel registered to this socket
				for (const [name, info] of channels) {
					if (info.socket === socket) {
						removeChannel(name);
						break;
					}
				}
			});

			socket.on("close", () => {
				for (const [name, info] of channels) {
					if (info.socket === socket) {
						removeChannel(name);
						console.log(`[bloom-channels] Channel disconnected: ${name}`);
						break;
					}
				}
			});
		});

		server.on("error", (err: Error) => {
			console.error("[bloom-channels] Server error:", err.message);
		});

		server.listen(PORT, "127.0.0.1", () => {
			console.log(`[bloom-channels] Listening on localhost:${PORT}`);
		});

		updateWidget(ctx);
	});

	pi.on("agent_end", (event: AgentEndEvent, ctx: ExtensionContext) => {
		lastCtx = ctx;
		if (!lastChannelContext) return;

		const { channel, from } = lastChannelContext;
		lastChannelContext = null;

		const channelInfo = channels.get(channel);
		if (!channelInfo) return;

		// Find last assistant message and extract text
		const messages = event.messages;
		let responseText = "";
		for (let i = messages.length - 1; i >= 0; i--) {
			const msg = messages[i];
			if ("role" in msg && msg.role === "assistant") {
				const content = (msg as { role: "assistant"; content: { type: string; text?: string }[] }).content;
				const textParts = content.filter((c) => c.type === "text" && c.text).map((c) => c.text as string);
				responseText = textParts.join("");
				break;
			}
		}

		if (responseText) {
			sendToSocket(channelInfo.socket, {
				type: "response",
				channel,
				to: from,
				text: responseText,
			});
		}
	});

	pi.on("session_shutdown", (_event: SessionShutdownEvent, _ctx: ExtensionContext) => {
		if (server) {
			server.close();
			server = null;
		}
		for (const [, info] of channels) {
			info.socket.destroy();
		}
		channels.clear();
	});

	pi.registerCommand("wa", {
		description: "Send a message to WhatsApp",
		handler: async (args: string, ctx) => {
			const waChannel = channels.get("whatsapp");
			if (!waChannel) {
				ctx.ui.notify("WhatsApp not connected", "warning");
				return;
			}
			const msg = `${JSON.stringify({ type: "send", channel: "whatsapp", text: args })}\n`;
			waChannel.socket.write(msg);
			ctx.ui.notify("Sent to WhatsApp", "info");
		},
	});
}
