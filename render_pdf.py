#!/usr/bin/env python3
"""Render an HTML file to a single-page PDF sized exactly to its content.

WeasyPrint cannot measure an 'auto' page height. Strategy:
  1) render once onto a very tall probe page,
  2) walk the layout tree to find the actual bottom of the content,
  3) re-render with `@page { size: 210mm <measured>mm }`.
"""
import sys
from weasyprint import HTML, CSS

PAGE_WIDTH_MM  = 210
MARGIN_MM      = 4
PROBE_HEIGHT   = 20000          # mm — single page, plenty
PX_TO_MM       = 25.4 / 96.0    # WeasyPrint works in CSS px


def max_bottom(box):
    """Return the deepest descendant bottom (excluding the box itself)."""
    deepest = 0.0
    for child in getattr(box, "children", ()):
        bottom = child.position_y + (child.height or 0)
        if bottom > deepest:
            deepest = bottom
        sub = max_bottom(child)
        if sub > deepest:
            deepest = sub
    return deepest


def render(html_path: str, pdf_path: str) -> None:
    base = f"margin: {MARGIN_MM}mm;"

    probe_css = CSS(string=(
        f"@page {{ size: {PAGE_WIDTH_MM}mm {PROBE_HEIGHT}mm; {base} }}"
    ))
    doc = HTML(filename=html_path).render(
        stylesheets=[probe_css], presentational_hints=True
    )
    if not doc.pages:
        raise SystemExit("weasyprint produced no pages")

    content_px = max(max_bottom(p._page_box) for p in doc.pages)
    height_mm  = content_px * PX_TO_MM + 2 * MARGIN_MM + 4  # small buffer
    height_mm  = min(max(height_mm, 50), PROBE_HEIGHT)

    final_css = CSS(string=(
        f"@page {{ size: {PAGE_WIDTH_MM}mm {height_mm:.2f}mm; {base} }}"
    ))
    HTML(filename=html_path).write_pdf(
        pdf_path, stylesheets=[final_css], presentational_hints=True
    )


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(f"usage: {sys.argv[0]} <input.html> <output.pdf>")
    render(sys.argv[1], sys.argv[2])