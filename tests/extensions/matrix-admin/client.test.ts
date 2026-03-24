import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { MatrixAdminClient } from "../../../core/pi/extensions/matrix-admin/client.js";

function makeTempDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "pi-test-"));
}

function makeClient(tmpDir: string, fetchImpl: typeof fetch) {
  return new MatrixAdminClient({
    homeserver: "http://localhost:6167",
    accessToken: "tok_test",
    botUserId: "@pi:nixpi",
    configPath: path.join(tmpDir, "matrix-admin.json"),
    fetch: fetchImpl,
  });
}

describe("admin room discovery", () => {
  let tmpDir: string;

  beforeEach(() => { tmpDir = makeTempDir(); });
  afterEach(() => { fs.rmSync(tmpDir, { recursive: true, force: true }); });

  it("resolves room ID via directory API and caches it", async () => {
    const mockFetch = vi.fn().mockResolvedValueOnce({
      ok: true,
      json: async () => ({ room_id: "!abc123:nixpi" }),
    } as Response);

    const client = makeClient(tmpDir, mockFetch);
    const roomId = await client.getAdminRoomId();

    expect(roomId).toBe("!abc123:nixpi");
    expect(mockFetch).toHaveBeenCalledWith(
      "http://localhost:6167/_matrix/client/v3/directory/room/%23admins%3Anixpi",
      expect.objectContaining({ headers: expect.objectContaining({ Authorization: "Bearer tok_test" }) }),
    );

    const cached = JSON.parse(fs.readFileSync(path.join(tmpDir, "matrix-admin.json"), "utf8"));
    expect(cached.adminRoomId).toBe("!abc123:nixpi");
  });

  it("stores caller botUserId from options, not the server bot ID", () => {
    const mockFetch = vi.fn();
    const client = makeClient(tmpDir, mockFetch);
    // The client should preserve the caller identity, not overwrite with server bot
    expect(client.botUserId).toBe("@pi:nixpi");
  });

  it("uses cached room ID without calling the API", async () => {
    const configPath = path.join(tmpDir, "matrix-admin.json");
    fs.writeFileSync(configPath, JSON.stringify({ adminRoomId: "!cached:nixpi" }));

    const mockFetch = vi.fn();
    const client = makeClient(tmpDir, mockFetch);
    const roomId = await client.getAdminRoomId();

    expect(roomId).toBe("!cached:nixpi");
    expect(mockFetch).not.toHaveBeenCalled();
  });

  it("throws when directory API returns non-200", async () => {
    const mockFetch = vi.fn().mockResolvedValueOnce({
      ok: false,
      status: 404,
    } as Response);

    const client = makeClient(tmpDir, mockFetch);
    await expect(client.getAdminRoomId()).rejects.toThrow("admin room not found");
  });

  it("re-discovers and updates cache when invalidateRoomCache is called", async () => {
    const configPath = path.join(tmpDir, "matrix-admin.json");
    fs.writeFileSync(configPath, JSON.stringify({ adminRoomId: "!old:nixpi" }));

    const mockFetch = vi.fn().mockResolvedValueOnce({
      ok: true,
      json: async () => ({ room_id: "!new:nixpi" }),
    } as Response);

    const client = makeClient(tmpDir, mockFetch);
    await client.invalidateRoomCache();
    const roomId = await client.getAdminRoomId();

    expect(roomId).toBe("!new:nixpi");
    const cached = JSON.parse(fs.readFileSync(configPath, "utf8"));
    expect(cached.adminRoomId).toBe("!new:nixpi");
  });
});

describe("getSinceToken", () => {
  let tmpDir: string;

  beforeEach(() => { tmpDir = makeTempDir(); });
  afterEach(() => { fs.rmSync(tmpDir, { recursive: true, force: true }); });

  it("calls /sync?timeout=0 with room filter and returns next_batch", async () => {
    const mockFetch = vi.fn().mockResolvedValueOnce({
      ok: true,
      json: async () => ({ next_batch: "s123_456" }),
    } as Response);

    const client = makeClient(tmpDir, mockFetch);
    const token = await client.getSinceToken("!room:nixpi");

    expect(token).toBe("s123_456");
    const callUrl = mockFetch.mock.calls[0][0] as string;
    expect(callUrl).toContain("timeout=0");
    expect(callUrl).toContain(encodeURIComponent("!room:nixpi"));
  });

  it("throws SyncError on non-200 response", async () => {
    const mockFetch = vi.fn().mockResolvedValueOnce({ ok: false, status: 500 } as Response);
    const client = makeClient(tmpDir, mockFetch);
    await expect(client.getSinceToken("!room:nixpi")).rejects.toThrow("sync failed: 500");
  });
});

describe("sendAdminCommand", () => {
  let tmpDir: string;

  beforeEach(() => { tmpDir = makeTempDir(); });
  afterEach(() => { fs.rmSync(tmpDir, { recursive: true, force: true }); });

  it("sends !admin prefixed message to the room", async () => {
    const mockFetch = vi.fn().mockResolvedValueOnce({
      ok: true,
      json: async () => ({ event_id: "$evt1" }),
    } as Response);

    const client = makeClient(tmpDir, mockFetch);
    await client.sendAdminCommand("!room:nixpi", "users list-users", undefined);

    const [url, opts] = mockFetch.mock.calls[0] as [string, RequestInit];
    expect(url).toContain("/_matrix/client/v3/rooms/");
    expect(url).toContain("/send/m.room.message/");
    const body = JSON.parse(opts.body as string);
    expect(body.body).toBe("!admin users list-users");
    expect(body.msgtype).toBe("m.text");
  });

  it("appends a codeblock when body is provided", async () => {
    const mockFetch = vi.fn().mockResolvedValueOnce({
      ok: true,
      json: async () => ({ event_id: "$evt2" }),
    } as Response);

    const client = makeClient(tmpDir, mockFetch);
    await client.sendAdminCommand("!room:nixpi", "rooms moderation ban-list-of-rooms", "!bad:nixpi\n!worse:nixpi");

    const [, opts] = mockFetch.mock.calls[0] as [string, RequestInit];
    const body = JSON.parse(opts.body as string);
    expect(body.body).toContain("!admin rooms moderation ban-list-of-rooms");
    expect(body.body).toContain("!bad:nixpi");
    expect(body.body).toContain("!worse:nixpi");
  });

  it("throws on HTTP error", async () => {
    const mockFetch = vi.fn().mockResolvedValueOnce({ ok: false, status: 403 } as Response);
    const client = makeClient(tmpDir, mockFetch);
    await expect(client.sendAdminCommand("!room:nixpi", "users list-users", undefined))
      .rejects.toThrow("send failed: 403");
  });
});

describe("pollForResponse", () => {
  let tmpDir: string;

  beforeEach(() => { tmpDir = makeTempDir(); });
  afterEach(() => { fs.rmSync(tmpDir, { recursive: true, force: true }); });

  it("returns the first message body from the server bot", async () => {
    const mockFetch = vi.fn().mockResolvedValueOnce({
      ok: true,
      json: async () => ({
        next_batch: "s2",
        rooms: {
          join: {
            "!room:nixpi": {
              timeline: {
                events: [
                  {
                    type: "m.room.message",
                    sender: "@conduit:nixpi",
                    content: { body: "Listed 3 users." },
                  },
                ],
              },
            },
          },
        },
      }),
    } as Response);

    const client = makeClient(tmpDir, mockFetch);
    const response = await client.pollForResponse("!room:nixpi", "s1", 5000);

    expect(response).toBe("Listed 3 users.");
  });

  it("ignores messages from other senders and advances since token between polls", async () => {
    const mockFetch = vi.fn()
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          next_batch: "s2",
          rooms: {
            join: {
              "!room:nixpi": {
                timeline: {
                  events: [
                    { type: "m.room.message", sender: "@pi:nixpi", content: { body: "not the bot" } },
                  ],
                },
              },
            },
          },
        }),
      } as Response)
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          next_batch: "s3",
          rooms: {
            join: {
              "!room:nixpi": {
                timeline: {
                  events: [
                    { type: "m.room.message", sender: "@conduit:nixpi", content: { body: "Real reply" } },
                  ],
                },
              },
            },
          },
        }),
      } as Response);

    const client = makeClient(tmpDir, mockFetch);
    const response = await client.pollForResponse("!room:nixpi", "s1", 5000);

    expect(response).toBe("Real reply");
    expect(mockFetch).toHaveBeenCalledTimes(2);
    const secondCallUrl = mockFetch.mock.calls[1][0] as string;
    expect(secondCallUrl).toContain("since=s2");
  });

  it("returns null on timeout (no response before deadline)", async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ next_batch: "sN", rooms: {} }),
    } as Response);

    const client = makeClient(tmpDir, mockFetch);
    const response = await client.pollForResponse("!room:nixpi", "s1", 50);

    expect(response).toBeNull();
  });

  it("throws on sync HTTP error", async () => {
    const mockFetch = vi.fn().mockResolvedValueOnce({ ok: false, status: 429 } as Response);
    const client = makeClient(tmpDir, mockFetch);
    await expect(client.pollForResponse("!room:nixpi", "s1", 5000)).rejects.toThrow("sync error: 429");
  });
});
