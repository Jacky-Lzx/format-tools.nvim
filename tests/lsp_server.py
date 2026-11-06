"""Minimal stdio LSP server for exercising Neovim's actual client transport."""
import json
import sys

documents = {}


def send(message):
    data = json.dumps(message, ensure_ascii=False).encode()
    sys.stdout.buffer.write(f"Content-Length: {len(data)}\r\n\r\n".encode() + data)
    sys.stdout.buffer.flush()


while True:
    headers = {}
    while True:
        line = sys.stdin.buffer.readline()
        if not line:
            sys.exit(0)
        if line in (b"\r\n", b"\n"):
            break
        key, value = line.decode().split(":", 1)
        headers[key.lower()] = value.strip()
    request = json.loads(sys.stdin.buffer.read(int(headers["content-length"])))
    method, params = request.get("method"), request.get("params", {})
    result = None
    if method == "initialize":
        result = {"capabilities": {"textDocumentSync": 1, "documentFormattingProvider": True,
                                   "positionEncoding": "utf-16"}}
    elif method == "textDocument/didOpen":
        doc = params["textDocument"]
        documents[doc["uri"]] = doc["text"]
    elif method == "textDocument/didChange":
        documents[params["textDocument"]["uri"]] = params["contentChanges"][-1]["text"]
    elif method == "textDocument/formatting":
        text = documents[params["textDocument"]["uri"]]
        result = [{"range": {"start": {"line": 0, "character": 0},
                              "end": {"line": len(text.splitlines()), "character": 0}},
                   "newText": text.replace("bad", "good")}]
    elif method == "exit":
        break
    if "id" in request:
        send({"jsonrpc": "2.0", "id": request["id"], "result": result})
