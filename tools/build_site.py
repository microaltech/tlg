#!/usr/bin/env python3
"""Bangun situs statis Tuan Nusantara ke build/site (untuk GitHub Pages).

    python3 tools/build_site.py

Isi: beranda, kebijakan privasi (dari docs/privacy_policy.md), dan halaman hapus akun
(wajib untuk Google Play). Data pengembang diambil dari site/site.json.
"""
import html
import json
import os
import re
import shutil

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "build", "site")
CFG = json.load(open(os.path.join(ROOT, "site", "site.json"), encoding="utf-8"))


def inline(text):
    text = html.escape(text, quote=False)
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"(?<![\w*])_([^_]+)_(?!\w)", r"<em>\1</em>", text)
    text = re.sub(r"\[([^\]]+)\]\((https?://[^)]+)\)", r'<a href="\2">\1</a>', text)
    return text


def markdown(md):
    """Pengubah Markdown kecil: judul, paragraf, daftar, tabel, kutipan, kode."""
    out, para, lst, table = [], [], [], []

    def flush():
        nonlocal para, lst, table
        if para:
            out.append("<p>%s</p>" % inline(" ".join(para)))
        if lst:
            out.append("<ul>%s</ul>" % "".join("<li>%s</li>" % inline(x) for x in lst))
        if table:
            rows = [r for r in table if not re.match(r"^\|[\s\-:|]+\|$", r)]
            cells = [[c.strip() for c in r.strip("|").split("|")] for r in rows]
            head = "".join("<th>%s</th>" % inline(c) for c in cells[0])
            body = "".join("<tr>%s</tr>" % "".join("<td>%s</td>" % inline(c) for c in r) for r in cells[1:])
            out.append('<div class="scroll"><table><tr>%s</tr>%s</table></div>' % (head, body))
        para, lst, table = [], [], []

    for line in md.split("\n"):
        s = line.rstrip()
        if not s:
            flush()
            continue
        m = re.match(r"^(#{1,3}) (.*)", s)
        if m:
            flush()
            n = len(m.group(1))
            out.append("<h%d>%s</h%d>" % (n, inline(m.group(2)), n))
        elif s.startswith("|"):
            if para or lst:
                flush()
            table.append(s)
        elif re.match(r"^\s*[-*] ", s):
            if para or table:
                flush()
            lst.append(re.sub(r"^\s*[-*] ", "", s))
        elif s.startswith(">"):
            continue  # catatan untuk pengembang, tidak ditampilkan
        elif lst and line.startswith("  "):
            lst[-1] += " " + s.strip()
        else:
            if lst or table:
                flush()
            para.append(s.strip())
    flush()
    return "\n".join(out)


def fill(text):
    for k, v in {"[NAMA PENGEMBANG]": CFG["developer"], "[nama pengembang]": CFG["developer"],
                 "[EMAIL KONTAK]": CFG["email"], "[email dukungan]": CFG["email"],
                 "[isi tanggal rilis]": CFG["effective_date"]}.items():
        text = text.replace(k, v)
    return text


def page(title, body):
    tpl = open(os.path.join(ROOT, "site", "template.html"), encoding="utf-8").read()
    return fill(tpl.replace("{{title}}", html.escape(title)).replace("{{body}}", body)
                .replace("{{play_url}}", CFG["play_url"]))


def main():
    shutil.rmtree(OUT, ignore_errors=True)
    os.makedirs(OUT)
    for f in os.listdir(os.path.join(ROOT, "site")):
        if f.endswith((".png", ".svg", ".css", ".ico")):
            shutil.copy(os.path.join(ROOT, "site", f), OUT)
    icon = os.path.join(ROOT, "assets", "launcher", "play_store_512.png")
    if os.path.exists(icon):
        shutil.copy(icon, os.path.join(OUT, "icon.png"))
    for name in ["index", "hapus-akun"]:
        src = open(os.path.join(ROOT, "site", name + ".html"), encoding="utf-8").read()
        title = re.search(r"<!--\s*title:\s*(.*?)\s*-->", src).group(1)
        open(os.path.join(OUT, name + ".html"), "w", encoding="utf-8").write(page(title, src))
    md = open(os.path.join(ROOT, "docs", "privacy_policy.md"), encoding="utf-8").read()
    open(os.path.join(OUT, "privasi.html"), "w", encoding="utf-8").write(page("Kebijakan Privasi", markdown(md)))
    print("Situs ditulis ke", OUT, sorted(os.listdir(OUT)))


if __name__ == "__main__":
    main()
