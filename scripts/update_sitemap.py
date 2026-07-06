#!/usr/bin/env python3
from __future__ import annotations

import argparse
import html
import os
from datetime import datetime, timezone
from pathlib import Path


REPO_BASE_URLS = {
    "HKASAR1239/HKASAR1239.github.io": "https://hkasar1239.github.io",
    "solutions-spylab/solutions-spylab.github.io": "https://solutions-spylab.github.io",
}

SKIP_DIRS = {".git", ".github", "scripts"}


def infer_base_url(root: Path) -> str:
    github_repo = os.environ.get("GITHUB_REPOSITORY", "")
    if github_repo in REPO_BASE_URLS:
        return REPO_BASE_URLS[github_repo]
    name = root.resolve().name
    if "solutions-spylab.github.io" in name:
        return "https://solutions-spylab.github.io"
    return "https://hkasar1239.github.io"


def is_skipped(path: Path, root: Path) -> bool:
    rel = path.relative_to(root)
    return any(part.startswith(".") or part in SKIP_DIRS for part in rel.parts)


def collect_urls(root: Path, base_url: str) -> list[str]:
    base_url = base_url.rstrip("/")
    urls = [f"{base_url}/"]
    for index_file in sorted(root.rglob("index.html")):
        if is_skipped(index_file, root):
            continue
        rel_dir = index_file.parent.relative_to(root)
        if str(rel_dir) == ".":
            continue
        rel_url = "/".join(rel_dir.parts)
        urls.append(f"{base_url}/{rel_url}/")
    return sorted(dict.fromkeys(urls))


def write_sitemaps(root: Path, base_url: str, urls: list[str]) -> None:
    today = datetime.now(timezone.utc).date().isoformat()
    xml = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    ]
    for url in urls:
        priority = "1.00" if url == f"{base_url.rstrip('/')}/" else "0.85"
        xml.extend(
            [
                "  <url>",
                f"    <loc>{html.escape(url, quote=True)}</loc>",
                f"    <lastmod>{today}</lastmod>",
                "    <changefreq>weekly</changefreq>",
                f"    <priority>{priority}</priority>",
                "  </url>",
            ]
        )
    xml.append("</urlset>")

    xml_text = "\n".join(xml) + "\n"
    txt_text = "\n".join(urls) + "\n"
    (root / "sitemap.xml").write_text(xml_text, encoding="utf-8")
    (root / "gsc-sitemap.xml").write_text(xml_text, encoding="utf-8")
    (root / "sitemap.txt").write_text(txt_text, encoding="utf-8")
    (root / "gsc-sitemap.txt").write_text(txt_text, encoding="utf-8")
    (root / "robots.txt").write_text(
        f"User-agent: *\nAllow: /\n\nSitemap: {base_url.rstrip('/')}/sitemap.xml\n",
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Regenerate GitHub Pages mirror sitemaps.")
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--base-url", default="")
    args = parser.parse_args()

    root = args.root.resolve()
    base_url = (args.base_url or infer_base_url(root)).rstrip("/")
    urls = collect_urls(root, base_url)
    write_sitemaps(root, base_url, urls)
    print(f"Wrote {len(urls)} URLs for {base_url}")


if __name__ == "__main__":
    main()
