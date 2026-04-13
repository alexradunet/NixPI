import type { PiReply } from "../models.js";

type PromptResponse = {
  text: string;
  sessionPath: string;
};

export class PiCoreClient {
  constructor(private readonly baseUrl: string) {}

  async healthCheck(): Promise<void> {
    const res = await fetch(`${this.baseUrl}/api/v1/health`);
    if (!res.ok) {
      throw new Error(`pi-core health check failed: ${res.status}`);
    }
  }

  async promptNewSession(message: string): Promise<PiReply> {
    return this.prompt(message, null);
  }

  async promptExistingSession(sessionPath: string, message: string): Promise<PiReply> {
    return this.prompt(message, sessionPath);
  }

  private async prompt(message: string, sessionPath?: string | null): Promise<PiReply> {
    const res = await fetch(`${this.baseUrl}/api/v1/prompt`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json; charset=utf-8",
      },
      body: JSON.stringify({ prompt: message, sessionPath }),
    });

    if (!res.ok) {
      throw new Error(`pi-core prompt failed: ${res.status}`);
    }

    const reply = await res.json() as PromptResponse;
    return {
      text: reply.text,
      sessionPath: reply.sessionPath,
    };
  }
}
