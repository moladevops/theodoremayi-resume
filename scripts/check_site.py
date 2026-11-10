"""Checks run before every deployment of the site.

- the required files exist
- every local link, image, stylesheet and PDF referenced by the pages exists
- no phone number is published (privacy)

Usage: python scripts/check_site.py [site_dir]   (default: site)
"""
import re
import sys
from html.parser import HTMLParser
from pathlib import Path

SITE = Path(sys.argv[1] if len(sys.argv) > 1 else "site")
REQUIRED = ["index.html", "en.html", "robots.txt", "sitemap.xml"]
PHONE = re.compile(r"(?:\+33|0)\s?[67](?:[\s.-]?\d{2}){4}")


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.refs = []

    def handle_starttag(self, tag, attrs):
        for name, value in attrs:
            if name in ("href", "src") and value:
                self.refs.append(value)


def main() -> int:
    errors = []

    for name in REQUIRED:
        if not (SITE / name).is_file():
            errors.append(f"missing file: {name}")

    for page in sorted(SITE.glob("*.html")):
        html = page.read_text(encoding="utf-8")
        if PHONE.search(html):
            errors.append(f"{page.name}: contains a phone number")
        parser = Links()
        parser.feed(html)
        for ref in parser.refs:
            if ref.startswith(("http://", "https://", "mailto:", "#", "//")):
                continue
            target = SITE / ref.split("#")[0].split("?")[0].lstrip("/")
            if not target.exists():
                errors.append(f"{page.name}: broken link -> {ref}")

    if errors:
        print("Site check failed:")
        for e in errors:
            print(f"  - {e}")
        return 1

    files = sum(1 for p in SITE.rglob("*") if p.is_file())
    print(f"Site check passed: {files} files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
