#!/usr/bin/env python3
"""Minimal DNS A query: query.py SERVER PORT NAME [tcp] -> prints "<answer-name> <ip>" per A record."""
import socket
import struct
import sys

server, port, name = sys.argv[1], int(sys.argv[2]), sys.argv[3].rstrip(".")
tcp = len(sys.argv) > 4 and sys.argv[4] == "tcp"
q = struct.pack(">HHHHHH", 0x1234, 0x0100, 1, 0, 0, 0)
q += b"".join(bytes([len(p)]) + p.encode() for p in name.split(".")) + b"\0" + struct.pack(">HH", 1, 1)

if tcp:
    with socket.create_connection((server, port), timeout=5) as s:
        s.sendall(struct.pack(">H", len(q)) + q)
        size = struct.unpack(">H", s.recv(2))[0]
        resp = b""
        while len(resp) < size:
            resp += s.recv(size - len(resp))
else:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(5)
    s.sendto(q, (server, port))
    resp = s.recv(4096)


def read_name(buf, off):
    labels = []
    while True:
        n = buf[off]
        if n & 0xC0 == 0xC0:
            ptr = struct.unpack(">H", buf[off:off + 2])[0] & 0x3FFF
            labels.append(read_name(buf, ptr)[0])
            return ".".join(labels), off + 2
        off += 1
        if n == 0:
            return ".".join(labels), off
        labels.append(buf[off:off + n].decode())
        off += n


_, flags, qd, an, _, _ = struct.unpack(">HHHHHH", resp[:12])
if flags & 0xF:
    sys.exit(f"rcode {flags & 0xF}")
off = 12
for _ in range(qd):
    off = read_name(resp, off)[1] + 4
for _ in range(an):
    rname, off = read_name(resp, off)
    rtype, _, _, rdlen = struct.unpack(">HHIH", resp[off:off + 10])
    off += 10
    if rtype == 1:
        print(rname, socket.inet_ntoa(resp[off:off + rdlen]))
    off += rdlen
