import { describe, expect, it } from "vitest";
import { DANGEROUS_COMMANDS, applyTransformations, isDangerous } from "../../../core/pi/extensions/matrix-admin/commands.js";

describe("DANGEROUS_COMMANDS", () => {
  it("includes destructive user commands", () => {
    expect(isDangerous("users deactivate")).toBe(true);
    expect(isDangerous("users deactivate-all")).toBe(true);
    expect(isDangerous("users logout")).toBe(true);
    expect(isDangerous("users make-user-admin")).toBe(true);
    expect(isDangerous("users force-join-list-of-local-users")).toBe(true);
    expect(isDangerous("users force-join-all-local-users")).toBe(true);
  });

  it("includes destructive room commands", () => {
    expect(isDangerous("rooms moderation ban-room")).toBe(true);
    expect(isDangerous("rooms moderation ban-list-of-rooms")).toBe(true);
  });

  it("includes dangerous server commands", () => {
    expect(isDangerous("server restart")).toBe(true);
    expect(isDangerous("server shutdown")).toBe(true);
    expect(isDangerous("server show-config")).toBe(true);
  });

  it("includes dangerous federation and appservice commands", () => {
    expect(isDangerous("federation disable-room")).toBe(true);
    expect(isDangerous("appservices unregister")).toBe(true);
  });

  it("includes dangerous media and token commands", () => {
    expect(isDangerous("media delete-list")).toBe(true);
    expect(isDangerous("media delete-past-remote-media")).toBe(true);
    expect(isDangerous("media delete-all-from-user")).toBe(true);
    expect(isDangerous("media delete-all-from-server")).toBe(true);
    expect(isDangerous("token destroy")).toBe(true);
  });

  it("does NOT include safe read commands", () => {
    expect(isDangerous("users list-users")).toBe(false);
    expect(isDangerous("rooms list-rooms")).toBe(false);
    expect(isDangerous("server uptime")).toBe(false);
  });
});

describe("isDangerous", () => {
  it("returns true when command starts with a dangerous prefix", () => {
    expect(isDangerous("users deactivate @alice:nixpi")).toBe(true);
    expect(isDangerous("server restart")).toBe(true);
  });

  it("returns false for safe commands", () => {
    expect(isDangerous("users list-users")).toBe(false);
    expect(isDangerous("rooms list-rooms")).toBe(false);
  });

  it("does not false-positive on a command that shares a prefix string but not a word boundary", () => {
    // "users deactivate" should not match "users deactivates-everything" (hypothetical)
    // The + " " guard in isDangerous prevents this
    expect(isDangerous("users deactivates-everything")).toBe(false);
  });
});

describe("check/debug/query pass-through namespaces", () => {
  it("debug commands are not dangerous", () => {
    expect(isDangerous("debug ping example.com")).toBe(false);
    expect(isDangerous("check")).toBe(false);
    expect(isDangerous("query globals signing-keys-for example.com")).toBe(false);
  });

  it("applyTransformations does not modify debug or query commands", () => {
    expect(applyTransformations("debug change-log-level debug")).toBe("debug change-log-level debug");
    expect(applyTransformations("query raw raw-del somekey")).toBe("query raw raw-del somekey");
  });
});

describe("applyTransformations", () => {
  it("appends --yes-i-want-to-do-this to force-join-list-of-local-users", () => {
    const result = applyTransformations("users force-join-list-of-local-users !room:nixpi");
    expect(result).toBe("users force-join-list-of-local-users !room:nixpi --yes-i-want-to-do-this");
  });

  it("does NOT duplicate the flag if already present", () => {
    const cmd = "users force-join-list-of-local-users !room:nixpi --yes-i-want-to-do-this";
    expect(applyTransformations(cmd)).toBe(cmd);
  });

  it("does not modify other commands", () => {
    expect(applyTransformations("users list-users")).toBe("users list-users");
    expect(applyTransformations("rooms list-rooms")).toBe("rooms list-rooms");
  });

  it("does not modify dangerous commands that have no transformation rule", () => {
    expect(applyTransformations("users deactivate @alice:nixpi")).toBe("users deactivate @alice:nixpi");
    expect(applyTransformations("server restart")).toBe("server restart");
  });
});
