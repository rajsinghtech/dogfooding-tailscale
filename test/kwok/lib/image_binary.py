#!/usr/bin/env python3
"""Extract a container image's entrypoint binary using only the Python standard library.

Usage: image_binary.py IMAGE DEST [--dir IMAGE_DIR OUT_DIR] [--arch ARCH]

Flux and Flux Operator only publish their controllers as container images. KWOK
runs no containers, so the harness runs the controllers as host processes.
"""
import argparse
import io
import json
import os
import sys
import tarfile
import urllib.request

ACCEPT = ", ".join([
    "application/vnd.oci.image.index.v1+json",
    "application/vnd.docker.distribution.manifest.list.v2+json",
    "application/vnd.oci.image.manifest.v1+json",
    "application/vnd.docker.distribution.manifest.v2+json",
])


def parse(image):
    name, _, tag = image.rpartition(":")
    if "/" in tag or not name:
        name, tag = image, "latest"
    registry, _, repo = name.partition("/")
    if "." not in registry:
        registry, repo = "registry-1.docker.io", name if "/" in name else f"library/{name}"
    return registry, repo, tag


def token(registry, repo):
    if registry == "ghcr.io":
        url = f"https://ghcr.io/token?scope=repository:{repo}:pull"
    elif registry == "registry-1.docker.io":
        url = f"https://auth.docker.io/token?service=registry.docker.io&scope=repository:{repo}:pull"
    else:
        return None
    with urllib.request.urlopen(url) as r:
        body = json.load(r)
    return body.get("token") or body.get("access_token")


def get(registry, repo, path, tok, accept=ACCEPT):
    req = urllib.request.Request(f"https://{registry}/v2/{repo}/{path}", headers={"Accept": accept})
    if tok:
        req.add_header("Authorization", f"Bearer {tok}")
    with urllib.request.urlopen(req) as r:
        return r.read()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("dest")
    ap.add_argument("--dir", nargs=2, metavar=("IMAGE_DIR", "OUT_DIR"),
                    help="also copy a directory tree out of the image")
    ap.add_argument("--arch", default={"x86_64": "amd64", "aarch64": "arm64"}.get(os.uname().machine, os.uname().machine))
    args = ap.parse_args()
    image, dest, arch = args.image, args.dest, args.arch
    tree = args.dir[0].strip("/") + "/" if args.dir else None
    registry, repo, tag = parse(image)
    tok = token(registry, repo)
    manifest = json.loads(get(registry, repo, f"manifests/{tag}", tok))
    if "manifests" in manifest:
        digest = next(m["digest"] for m in manifest["manifests"]
                      if m.get("platform", {}).get("os") == "linux" and m["platform"].get("architecture") == arch)
        manifest = json.loads(get(registry, repo, f"manifests/{digest}", tok))
    config = json.loads(get(registry, repo, f"blobs/{manifest['config']['digest']}", tok, "*/*"))["config"]
    entry = (config.get("Entrypoint") or []) + (config.get("Cmd") or [])
    binary = next(e for e in entry if os.path.basename(e) not in ("tini", "dumb-init", "--"))
    if "/" not in binary:
        paths = next((e.split("=", 1)[1] for e in config.get("Env", []) if e.startswith("PATH=")), "/usr/local/bin:/usr/bin:/bin")
        candidates = [os.path.join(p, binary).lstrip("/") for p in paths.split(":")]
    else:
        candidates = [binary.lstrip("/")]
    found = None
    for layer in manifest["layers"]:
        blob = get(registry, repo, f"blobs/{layer['digest']}", tok, "*/*")
        with tarfile.open(fileobj=io.BytesIO(blob)) as t:
            for m in t.getmembers():
                name = m.name.lstrip("./")
                if m.isfile() and name in candidates:
                    found = t.extractfile(m).read()
                elif tree and m.isfile() and name.startswith(tree):
                    out = os.path.join(args.dir[1], name[len(tree):])
                    os.makedirs(os.path.dirname(out), exist_ok=True)
                    with open(out, "wb") as f:
                        f.write(t.extractfile(m).read())
    if found is None:
        sys.exit(f"{image}: entrypoint {binary} not found in layers")
    os.makedirs(os.path.dirname(os.path.abspath(dest)), exist_ok=True)
    with open(dest, "wb") as f:
        f.write(found)
    os.chmod(dest, 0o755)
    print(f"{image} -> {dest}")


if __name__ == "__main__":
    main()
