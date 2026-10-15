#!/usr/bin/env python3
"""Print "<component> <image>" for each controller in a Flux release.

Usage: flux_images.py FLUX_VERSION
"""
import io
import re
import sys
import tarfile
import urllib.request

version = sys.argv[1].lstrip("v")
url = f"https://github.com/fluxcd/flux2/releases/download/v{version}/manifests.tar.gz"
with urllib.request.urlopen(url) as r, tarfile.open(fileobj=io.BytesIO(r.read())) as t:
    for m in t.getmembers():
        if m.isfile():
            for image in sorted(set(re.findall(r"image: (\S+)", t.extractfile(m).read().decode()))):
                name = image.rsplit("/", 1)[-1].split(":", 1)[0]
                print(name, image if image.count("/") > 1 else f"ghcr.io/{image}")
