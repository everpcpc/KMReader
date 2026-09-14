#!/usr/bin/env python3
"""Minimal stdio MCP client for Xcode's built-in MCP bridge (mcpbridge).

Works with Xcode 26+ (Device Hub era). The bridge connects to the running
Xcode instance selected by xcode-select.

Usage:
  xcode_mcp.py list-tools
  xcode_mcp.py schema <tool_name>
  xcode_mcp.py call <tool_name> '<json_args>'
"""
import json
import subprocess
import sys
import threading
import time
from pathlib import Path


def bridge_path() -> str:
    dev_dir = subprocess.run(
        ["xcode-select", "-p"], capture_output=True, text=True, check=True
    ).stdout.strip()
    candidate = Path(dev_dir) / "usr" / "bin" / "mcpbridge"
    if not candidate.exists():
        sys.exit(f"mcpbridge not found at {candidate} (Xcode 26+ required)")
    return str(candidate)


class MCPClient:
    def __init__(self):
        self.proc = subprocess.Popen(
            [bridge_path()],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            bufsize=1,
        )
        self._id = 0
        self._lock = threading.Lock()
        self._responses = {}
        self._reader = threading.Thread(target=self._read_loop, daemon=True)
        self._reader.start()

    def _read_loop(self):
        for line in self.proc.stdout:
            line = line.strip()
            if not line:
                continue
            try:
                msg = json.loads(line)
            except json.JSONDecodeError:
                continue
            if "id" in msg and ("result" in msg or "error" in msg):
                with self._lock:
                    self._responses[msg["id"]] = msg

    def request(self, method, params=None, timeout=600):
        with self._lock:
            self._id += 1
            rid = self._id
        msg = {"jsonrpc": "2.0", "method": method, "id": rid}
        if params is not None:
            msg["params"] = params
        self.proc.stdin.write(json.dumps(msg) + "\n")
        self.proc.stdin.flush()
        deadline = time.time() + timeout
        while time.time() < deadline:
            with self._lock:
                if rid in self._responses:
                    return self._responses.pop(rid)
            time.sleep(0.05)
        raise TimeoutError(f"timeout waiting for {method}")

    def initialize(self):
        resp = self.request(
            "initialize",
            {
                "protocolVersion": "2025-03-26",
                "capabilities": {},
                "clientInfo": {"name": "xcode-mcp-skill", "version": "1.0"},
            },
        )
        self.proc.stdin.write(
            json.dumps({"jsonrpc": "2.0", "method": "notifications/initialized"})
            + "\n"
        )
        self.proc.stdin.flush()
        return resp

    def close(self):
        self.proc.kill()


def unwrap(resp):
    """Extract text payload from a tools/call result."""
    result = resp.get("result", resp)
    for item in result.get("content", []):
        if item.get("type") == "text":
            text = item["text"]
            try:
                payload = json.loads(text)
                return json.dumps(payload, ensure_ascii=False, indent=1)
            except json.JSONDecodeError:
                return text
    return json.dumps(result, ensure_ascii=False)[:2000]


def main():
    client = MCPClient()
    init = client.initialize()
    if "error" in init:
        print(json.dumps(init, indent=2))
        sys.exit(1)

    cmd = sys.argv[1] if len(sys.argv) > 1 else "list-tools"
    if cmd == "list-tools":
        resp = client.request("tools/list", {})
        for t in resp.get("result", {}).get("tools", []):
            desc = t.get("description", "").split("\n")[0][:100]
            print(f"{t['name']}  -  {desc}")
    elif cmd == "schema":
        resp = client.request("tools/list", {})
        for t in resp.get("result", {}).get("tools", []):
            if t["name"] == sys.argv[2]:
                print(json.dumps(t.get("inputSchema", {}), indent=1))
                break
        else:
            sys.exit(f"tool not found: {sys.argv[2]}")
    elif cmd == "call":
        name = sys.argv[2]
        args = json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}
        resp = client.request(
            "tools/call", {"name": name, "arguments": args}, timeout=900
        )
        print(unwrap(resp))
    client.close()


if __name__ == "__main__":
    main()
