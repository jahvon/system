#!/usr/bin/env python3
"""Prints the clients and units a TP-Link Deco knows about, as JSON or as hosts file lines.

The Deco has no public API. This speaks the local protocol its web page uses, which a firmware
update could change. Reads DECO_PASSWORD from the environment and changes nothing on the router.
    usage: deco.py <router address> [<vendors file> <reserved IPs file>]
Vendors are tab-separated "mac, vendor" lines. Reserved IPs keep the records they already have.
"""
import base64
import hashlib
import http.cookiejar
import json
import os
import re
import secrets
import subprocess
import sys
import urllib.parse
import urllib.request

RSA_CHUNK = 53  # bytes of plaintext per block, which the router expects
VENDOR_FILLER = {"private", "shenzhen", "co", "corp", "corporation", "inc", "llc", "ltd", "limited", "tech", "technology", "technologies", "electronics", "labs", "the"}


def fail(message):
    print(f"deco: {message}", file=sys.stderr)
    sys.exit(1)


def rsa_encrypt(text, key):
    """RSA with PKCS#1 v1.5 padding, hex encoded, in the router's fixed-size chunks."""
    n, e = int(key[0], 16), int(key[1], 16)
    size = (n.bit_length() + 7) // 8
    raw = text.encode()
    out = ""
    for i in range(0, len(raw), RSA_CHUNK):
        chunk = raw[i:i + RSA_CHUNK]
        filler = bytes(b for b in secrets.token_bytes(size * 2) if b)[:size - len(chunk) - 3]
        block = b"\x00\x02" + filler + b"\x00" + chunk
        out += pow(int.from_bytes(block, "big"), e, n).to_bytes(size, "big").hex()
    return out


class Deco:
    def __init__(self, host, password):
        self.base = f"http://{host}/cgi-bin/luci/"
        self.password = password
        self.hash = hashlib.md5(f"admin{password}".encode()).hexdigest()
        self.key = "".join(secrets.choice("0123456789") for _ in range(16))
        self.iv = "".join(secrets.choice("0123456789") for _ in range(16))
        self.stok = ""
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))

    def aes(self, data, decrypt=False):
        flags = ["-d"] if decrypt else ["-e"]
        result = subprocess.run(
            ["openssl", "enc", "-aes-128-cbc", "-K", self.key.encode().hex(), "-iv", self.iv.encode().hex(), *flags],
            input=data, capture_output=True, check=False)
        if result.returncode:
            fail("could not read the router's encrypted response")
        return result.stdout

    def post(self, path, body):
        request = urllib.request.Request(self.base + f";stok={self.stok}/" + path, data=body.encode())
        # The router's own page labels even its form-encoded bodies this way, and login fails without it.
        request.add_header("Content-Type", "application/json")
        with self.opener.open(request, timeout=15) as response:
            return json.loads(response.read())

    def secure(self, path, payload):
        data = base64.b64encode(self.aes(json.dumps(payload).encode())).decode()
        keys = f"k={self.key}&i={self.iv}&" if not self.stok else ""
        sign = rsa_encrypt(f"{keys}h={self.hash}&s={self.seq + len(data)}", self.sign_key)
        body = urllib.parse.urlencode({"sign": sign, "data": data})
        reply = self.post(path, body)
        if "data" not in reply:
            fail(f"unexpected reply from {path.split('?')[0]}, error {reply.get('error_code')}")
        return json.loads(self.aes(base64.b64decode(reply["data"]), decrypt=True))

    def login(self):
        read = json.dumps({"operation": "read"})
        password_key = self.post("login?form=keys", read)["result"]["password"]
        auth = self.post("login?form=auth", read)["result"]
        self.sign_key, self.seq = auth["key"], auth["seq"]
        reply = self.secure("login?form=login", {
            "params": {"password": rsa_encrypt(self.password, password_key)},
            "operation": "login",
        })
        if reply.get("error_code") != 0 or "stok" not in reply.get("result", {}):
            code = reply.get("error_code")
            if code == -5003:
                fail("the router has locked its login after too many attempts. Wait before retrying")
            if code == -5002:
                fail("wrong password. Check it before retrying, because repeated failures lock the router's login")
            fail(f"login refused, error {code}")
        self.stok = reply["result"]["stok"]

    def logout(self):
        try:
            self.secure("admin/system?form=logout", {"operation": "logout"})
        except Exception:  # the session expires by itself
            pass

    def read(self, path, params=None):
        payload = {"operation": "read"}
        if params:
            payload["params"] = params
        reply = self.secure(path, payload)
        if reply.get("error_code") != 0:
            fail(f"could not read {path.split('?')[0]}, error {reply.get('error_code')}")
        return reply["result"]


def decode(value):
    try:
        return base64.b64decode(value).decode().strip()
    except (ValueError, TypeError):
        return (value or "").strip()


def mac(value):
    return (value or "").lower().replace("-", ":")


def read_clients(deco):
    clients = []
    for unit in deco.read("admin/device?form=device_list").get("device_list", []):
        unit_name = decode(unit.get("custom_nickname") or unit.get("nickname"))
        clients.append({"mac": mac(unit.get("mac")), "ip": unit.get("device_ip") or "", "type": "deco", "name": f"Deco {unit_name}", "unit": unit_name})
        for client in deco.read("admin/client?form=client_list", {"device_mac": unit.get("mac")}).get("client_list", []):
            clients.append({
                "mac": mac(client.get("mac")),
                "ip": client.get("ip") or "",
                "type": client.get("client_type") or "",
                "name": decode(client.get("name")),
                "unit": unit_name,
            })
    return clients


def slug(text):
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def vendor_word(vendor):
    """The maker's short name from a registry entry like "Shenzhen Intellirocks Tech. Co. Ltd."."""
    if re.search("intellirocks", vendor, re.I):
        return "govee"
    words = [w for w in slug(vendor).split("-") if w not in VENDOR_FILLER]
    return words[0] if words else ""


def label(client, vendors):
    """A hostname: the name set in the Deco, or the maker and the end of the IP for an unnamed device."""
    name = slug(client["name"])
    if name and name != "unknown":
        return name
    kind = slug(client["type"])
    prefix = vendor_word(vendors.get(client["mac"], "")) or (kind if kind not in ("", "other", "unknown") else "device")
    return f"{prefix}-{client['ip'].rsplit('.', 1)[-1]}"


def hosts_lines(clients, vendors, reserved):
    return [f"{c['ip']} {label(c, vendors)}" for c in sorted(clients, key=lambda c: [int(p) for p in c["ip"].split(".")])
            if c["ip"] and c["ip"] not in reserved]


def read_table(path):
    with open(path, encoding="utf-8") as f:
        return [line.rstrip("\n").split("\t") for line in f if line.strip()]


def main():
    if len(sys.argv) not in (2, 4):
        fail("usage: deco.py <router address> [<vendors file> <reserved IPs file>]")
    password = os.environ.get("DECO_PASSWORD")
    if not password:
        fail("DECO_PASSWORD is not set")
    deco = Deco(sys.argv[1], password)
    deco.login()
    try:
        clients = read_clients(deco)
    finally:
        deco.logout()
    if not clients:
        fail("the router returned no clients")
    if len(sys.argv) == 2:
        json.dump(clients, sys.stdout, indent=2)
        print()
        return
    vendors = {mac(row[0]): row[1] for row in read_table(sys.argv[2]) if len(row) > 1}
    reserved = {row[0] for row in read_table(sys.argv[3])}
    print("\n".join(hosts_lines(clients, vendors, reserved)))


if __name__ == "__main__":
    main()
