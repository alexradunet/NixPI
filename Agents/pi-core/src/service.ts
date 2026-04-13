import {
  AuthStorage,
  createAgentSession,
  ModelRegistry,
  SessionManager,
} from "@mariozechner/pi-coding-agent";
import { mkdirSync } from "node:fs";
import type { PromptResponse } from "./models.js";
import { KeyedSerialQueue } from "./queue.js";

type AssistantTextBlock = {
  type: "text";
  text: string;
};

type AssistantMessageLike = {
  role: "assistant";
  content: Array<{ type: string; text?: string }>;
};

function isAssistantMessage(value: unknown): value is AssistantMessageLike {
  if (!value || typeof value !== "object") return false;
  const msg = value as { role?: unknown; content?: unknown };
  return msg.role === "assistant" && Array.isArray(msg.content);
}

function extractAssistantText(message: unknown): string {
  if (!isAssistantMessage(message)) return "";

  return message.content
    .filter((block): block is AssistantTextBlock => block.type === "text" && typeof block.text === "string")
    .map((block) => block.text)
    .join("")
    .trim();
}

export class PiCoreService {
  private readonly authStorage: AuthStorage;
  private readonly modelRegistry: ModelRegistry;
  private readonly queue = new KeyedSerialQueue();

  constructor(
    private readonly cwd: string,
    private readonly sessionDir: string,
  ) {
    mkdirSync(this.sessionDir, { recursive: true });
    this.authStorage = AuthStorage.create();
    this.modelRegistry = ModelRegistry.create(this.authStorage);
  }

  async prompt(prompt: string, sessionPath?: string | null): Promise<PromptResponse> {
    const key = sessionPath ?? `new:${this.cwd}`;
    return this.queue.run(key, async () => {
      const sessionManager = sessionPath
        ? SessionManager.open(sessionPath, this.sessionDir)
        : SessionManager.create(this.cwd, this.sessionDir);

      const { session } = await createAgentSession({
        cwd: this.cwd,
        sessionManager,
        authStorage: this.authStorage,
        modelRegistry: this.modelRegistry,
      });

      try {
        await session.prompt(prompt);

        const lastAssistant = [...session.messages].reverse().find(isAssistantMessage);
        const resolvedSessionPath = session.sessionFile;
        if (!resolvedSessionPath) {
          throw new Error("Pi core session did not expose a session file");
        }

        return {
          text: extractAssistantText(lastAssistant),
          sessionPath: resolvedSessionPath,
        };
      } finally {
        session.dispose();
      }
    });
  }
}
