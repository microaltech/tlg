#!/usr/bin/env python3
"""Generator aset grafis (SVG) untuk game: potret karakter, ikon, latar.

Semua gambar dibuat secara prosedural dari bentuk-bentuk dasar agar orisinal,
konsisten gayanya, dan tajam di semua resolusi. Jalankan ulang setelah mengubah
desain:

    python3 tools/gen_art.py

Hasil ditulis ke assets/portraits, assets/icons, dan assets/bg. Untuk mengganti
dengan gambar buatan ilustrator, cukup taruh file PNG dengan nama yang sama
(mis. assets/portraits/arya.png); game akan memakai PNG lebih dulu.
"""

import math
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
GOLD = "#e8c070"
GOLD_DARK = "#a8742c"


# --- Utilitas warna -------------------------------------------------------

def _rgb(h):
    h = h.lstrip("#")
    return [int(h[i:i + 2], 16) for i in (0, 2, 4)]


def _hex(c):
    return "#" + "".join("%02x" % max(0, min(255, int(round(v)))) for v in c)


def shade(h, f):
    """f < 0 menggelapkan, f > 0 mencerahkan (rentang -1..1)."""
    c = _rgb(h)
    if f < 0:
        return _hex([v * (1 + f) for v in c])
    return _hex([v + (255 - v) * f for v in c])


def mirror(svg):
    """Cerminkan elemen terhadap garis tengah horizontal kanvas 256."""
    return '<g transform="translate(256 0) scale(-1 1)">%s</g>' % svg


def svg_doc(w, h, body, px_w=None, px_h=None, defs=""):
    px_w = px_w or w
    px_h = px_h or h
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">'
        "<defs>%s</defs>%s</svg>\n" % (px_w, px_h, w, h, defs, body)
    )


def write(rel, content):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(content)


# --- Potret ---------------------------------------------------------------

SKIN = {
    "light": "#f2cba6",
    "medium": "#dfa97c",
    "tan": "#c58a5e",
    "deep": "#9a6443",
}


def p_background(c1, c2):
    defs = (
        '<radialGradient id="bg" cx="50%%" cy="42%%" r="70%%">'
        '<stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></radialGradient>'
        % (c1, c2)
    )
    rays = ""
    for i in range(16):
        a0 = math.radians(i * 22.5)
        a1 = math.radians(i * 22.5 + 9)
        rays += '<path d="M128 118 L%.1f %.1f L%.1f %.1f Z" fill="#fff" opacity="0.07"/>' % (
            128 + 260 * math.cos(a0), 118 + 260 * math.sin(a0),
            128 + 260 * math.cos(a1), 118 + 260 * math.sin(a1))
    body = (
        '<rect width="256" height="256" rx="28" fill="url(#bg)"/>'
        '<g clip-path="url(#clip)">%s</g>' % rays
    )
    defs += '<clipPath id="clip"><rect width="256" height="256" rx="28"/></clipPath>'
    return defs, body


def p_frame():
    return (
        '<rect x="4" y="4" width="248" height="248" rx="24" fill="none" stroke="%s" stroke-width="8"/>'
        '<rect x="11" y="11" width="234" height="234" rx="19" fill="none" stroke="%s" stroke-width="2" opacity="0.8"/>'
        '<path d="M128 2 l9 9 -9 9 -9 -9 Z" fill="%s" stroke="%s" stroke-width="2"/>'
        % (GOLD, GOLD_DARK, GOLD, GOLD_DARK)
    )


def hair_back(style, color):
    if style == "long":
        return (
            '<path d="M78 100 Q70 40 128 38 Q186 40 178 100 Q186 160 194 222 Q160 236 128 230 '
            'Q96 236 62 222 Q70 160 78 100 Z" fill="%s"/>' % color
        )
    if style == "bun":
        return (
            '<circle cx="128" cy="44" r="25" fill="%s"/>'
            '<path d="M104 40 L156 34" stroke="%s" stroke-width="4" stroke-linecap="round"/>'
            '<circle cx="158" cy="33" r="5" fill="%s"/>' % (color, GOLD, GOLD)
        )
    if style == "topknot":
        return (
            '<ellipse cx="128" cy="44" rx="17" ry="15" fill="%s"/>'
            '<rect x="116" y="52" width="24" height="7" rx="3" fill="%s"/>' % (color, GOLD)
        )
    if style == "pigtails":
        return (
            '<circle cx="80" cy="70" r="20" fill="%s"/><circle cx="176" cy="70" r="20" fill="%s"/>'
            '<circle cx="80" cy="70" r="6" fill="#e05a7a"/><circle cx="176" cy="70" r="6" fill="#e05a7a"/>'
            % (color, color)
        )
    return ""


def hair_front(style, color):
    hl = shade(color, 0.25)
    if style in ("short", "topknot"):
        return (
            '<path d="M80 114 Q72 50 128 48 Q184 50 176 114 Q172 88 160 80 Q140 94 112 84 Q92 90 80 114 Z" fill="%s"/>'
            '<path d="M104 62 Q128 54 150 62" stroke="%s" stroke-width="4" fill="none" opacity="0.6" stroke-linecap="round"/>'
            % (color, hl)
        )
    if style in ("long", "bun", "pigtails"):
        return (
            '<path d="M80 122 Q74 48 128 46 Q182 48 176 122 Q170 86 150 74 Q132 86 104 78 Q86 90 80 122 Z" fill="%s"/>'
            '<path d="M100 60 Q122 52 140 56" stroke="%s" stroke-width="4" fill="none" opacity="0.6" stroke-linecap="round"/>'
            % (color, hl)
        )
    if style == "child":
        return (
            '<path d="M80 116 Q74 50 128 48 Q182 50 176 116 Q168 86 150 80 Q138 92 118 84 Q96 92 80 116 Z" fill="%s"/>'
            '<path d="M124 50 Q120 32 138 30 Q128 40 134 50 Z" fill="%s"/>' % (color, color)
        )
    return ""


def headwear(kind, p):
    c = p.get("hat_color", "#7a2e22")
    if kind == "helmet":
        metal = p.get("metal", "#c9963f")
        plume = p.get("plume", "#c0392b")
        return (
            '<path d="M128 40 Q150 6 180 14 Q160 22 142 46 Z" fill="%s"/>'
            '<path d="M76 108 Q72 38 128 36 Q184 38 180 108 L172 110 Q166 80 128 78 Q90 80 84 110 Z" fill="%s"/>'
            '<path d="M80 108 L76 144 Q86 150 94 136 L92 108 Z" fill="%s"/>'
            '<path d="M176 108 L180 144 Q170 150 162 136 L164 108 Z" fill="%s"/>'
            '<path d="M76 98 Q128 76 180 98 L180 112 Q128 90 76 112 Z" fill="%s" stroke="%s" stroke-width="2"/>'
            '<path d="M128 38 L128 80" stroke="%s" stroke-width="6"/>'
            '<path d="M100 54 Q114 44 126 44" stroke="#fff" stroke-width="4" fill="none" opacity="0.35" stroke-linecap="round"/>'
            '<circle cx="128" cy="96" r="7" fill="#c0392b" stroke="%s" stroke-width="2"/>'
            % (plume, metal, shade(metal, -0.15), shade(metal, -0.15), GOLD, GOLD_DARK,
               shade(metal, -0.25), GOLD_DARK)
        )
    if kind == "horned":
        metal = p.get("metal", "#4a4a55")
        return (
            '<path d="M86 78 Q56 62 58 24 Q72 54 98 66 Z" fill="#efe3c8" stroke="#a89878" stroke-width="2"/>'
            '<path d="M170 78 Q200 62 198 24 Q184 54 158 66 Z" fill="#efe3c8" stroke="#a89878" stroke-width="2"/>'
            '<path d="M76 108 Q72 40 128 38 Q184 40 180 108 L172 110 Q166 80 128 78 Q90 80 84 110 Z" fill="%s"/>'
            '<path d="M76 98 Q128 76 180 98 L180 112 Q128 90 76 112 Z" fill="%s"/>'
            '<path d="M118 78 L128 108 L138 78 Z" fill="%s"/>'
            % (metal, shade(metal, -0.3), shade(metal, -0.2))
        )
    if kind == "udeng":
        dots = "".join(
            '<circle cx="%d" cy="%d" r="2.5" fill="%s"/>' % (x, 86 - abs(x - 128) * -0.18 - 4, GOLD)
            for x in range(90, 170, 12))
        return (
            '<path d="M84 86 Q90 48 128 46 Q166 48 172 86 Q128 64 84 86 Z" fill="%s"/>'
            '<path d="M80 98 Q128 72 176 98 L176 84 Q128 56 80 84 Z" fill="%s"/>%s'
            '<path d="M118 62 L128 34 L138 62 Z" fill="%s"/>'
            % (shade(c, -0.25), c, dots, c)
        )
    if kind == "blangkon":
        lines = "".join(
            '<path d="M%d 96 Q%d 70 %d 50" stroke="%s" stroke-width="2" fill="none" opacity="0.5"/>'
            % (x, x + (128 - x) * 0.3, x + (128 - x) * 0.5, GOLD) for x in range(86, 172, 14))
        return (
            '<path d="M78 102 Q72 44 128 42 Q184 44 178 102 Q128 82 78 102 Z" fill="%s"/>%s'
            '<path d="M78 102 Q128 82 178 102 L178 94 Q128 74 78 94 Z" fill="%s"/>'
            % (c, lines, GOLD_DARK)
        )
    if kind == "crown":
        gem = '<circle cx="%d" cy="%d" r="%d" fill="%s" stroke="#fff3" stroke-width="1"/>'
        return (
            '<path d="M90 82 L100 40 L114 74 Z" fill="%s" stroke="%s" stroke-width="2"/>'
            '<path d="M166 82 L156 40 L142 74 Z" fill="%s" stroke="%s" stroke-width="2"/>'
            '<path d="M110 76 L128 10 L146 76 Z" fill="%s" stroke="%s" stroke-width="2"/>'
            '<path d="M82 98 Q128 80 174 98 L174 80 Q128 62 82 80 Z" fill="%s" stroke="%s" stroke-width="2"/>'
            '%s%s%s%s'
            '<path d="M80 110 Q66 112 66 128 Q66 140 76 140 Q70 130 78 124 Z" fill="%s"/>'
            '<path d="M176 110 Q190 112 190 128 Q190 140 180 140 Q186 130 178 124 Z" fill="%s"/>'
            % (GOLD, GOLD_DARK, GOLD, GOLD_DARK, GOLD, GOLD_DARK, GOLD, GOLD_DARK,
               gem % (128, 84, 7, "#c0392b"), gem % (104, 88, 4, "#2e86c1"),
               gem % (152, 88, 4, "#2e86c1"), gem % (128, 46, 5, "#27ae60"), GOLD, GOLD)
        )
    if kind == "tiara":
        return (
            '<path d="M90 76 Q128 60 166 76 L162 84 Q128 70 94 84 Z" fill="%s" stroke="%s" stroke-width="1.5"/>'
            '<path d="M116 70 L128 44 L140 70 Z" fill="%s" stroke="%s" stroke-width="1.5"/>'
            '<circle cx="128" cy="62" r="5" fill="%s"/>'
            % (GOLD, GOLD_DARK, GOLD, GOLD_DARK, p.get("gem", "#c0392b"))
        )
    if kind == "bandana":
        return (
            '<path d="M80 98 Q128 66 176 98 L176 84 Q128 50 80 84 Z" fill="%s"/>'
            '<path d="M174 88 Q196 96 204 120 Q190 108 176 104 Z" fill="%s"/>'
            '<path d="M174 92 Q200 110 196 136 Q188 116 174 104 Z" fill="%s"/>'
            % (c, shade(c, -0.15), shade(c, -0.25))
        )
    return ""


def flower(x, y, color, r=9):
    petals = "".join(
        '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>' % (
            x + r * math.cos(math.radians(a)), y + r * math.sin(math.radians(a)), r * 0.75, color)
        for a in range(-90, 270, 72))
    return petals + '<circle cx="%d" cy="%d" r="%.1f" fill="#f4c542"/>' % (x, y, r * 0.5)


def body(p):
    o = p["outfit"]
    inner = p.get("inner", shade(o, 0.5))
    trim = p.get("trim", GOLD)
    out = []
    if p["gender"] == "f":
        out.append(
            '<path d="M36 256 Q40 212 78 198 Q104 188 114 180 L142 180 Q152 188 178 198 '
            'Q216 212 220 256 Z" fill="%s"/>' % o)
        out.append('<path d="M108 180 L128 214 L148 180 Z" fill="%s"/>' % inner)
        out.append(
            '<path d="M106 180 L128 218 L150 180" stroke="%s" stroke-width="5" fill="none" stroke-linejoin="round"/>'
            % trim)
        shawl = p.get("shawl", shade(o, 0.35))
        out.append(
            '<path d="M36 232 Q90 196 158 256 L118 256 Q84 220 38 250 Z" fill="%s" opacity="0.92"/>'
            % shawl)
        # Renda di sepanjang tepi atas selendang (kurva Bezier kuadrat yang sama).
        dots = []
        for i in range(12):
            t = i / 11
            x = (1 - t) ** 2 * 36 + 2 * t * (1 - t) * 90 + t * t * 158
            y = (1 - t) ** 2 * 232 + 2 * t * (1 - t) * 196 + t * t * 256
            dots.append('<circle cx="%.1f" cy="%.1f" r="2.4" fill="%s"/>' % (x, y, trim))
        out.append("".join(dots))
    else:
        out.append(
            '<path d="M22 256 Q26 206 70 192 Q100 182 112 176 L144 176 Q156 182 186 192 '
            'Q230 206 234 256 Z" fill="%s"/>' % o)
        out.append('<path d="M106 178 L128 222 L150 178 Z" fill="%s"/>' % inner)
        out.append(
            '<path d="M104 178 L128 226 L152 178" stroke="%s" stroke-width="6" fill="none" stroke-linejoin="round"/>'
            % trim)
        out.append(
            '<path d="M96 256 Q100 236 128 230 Q156 236 160 256" stroke="%s" stroke-width="4" fill="none" opacity="0.6"/>'
            % shade(o, -0.3))
    if "armor" in p.get("extras", []):
        m = p.get("metal", "#c9963f")
        out.append(
            '<path d="M92 202 Q128 188 164 202 L158 256 L98 256 Z" fill="%s" stroke="%s" stroke-width="3"/>'
            % (shade(m, -0.1), shade(m, -0.4)))
        out.append('<circle cx="128" cy="226" r="11" fill="%s" stroke="%s" stroke-width="3"/>'
                   % (GOLD, GOLD_DARK))
        pad = (
            '<path d="M26 236 Q32 190 94 196 Q84 214 88 240 Z" fill="%s" stroke="%s" stroke-width="3"/>'
            '<path d="M34 222 Q48 202 88 204" stroke="%s" stroke-width="3" fill="none"/>'
            % (m, shade(m, -0.4), shade(m, 0.3)))
        out.append(pad + mirror(pad))
    if "batik" in p.get("extras", []):
        # Motif kawung sederhana di badan (empat elips mengelilingi titik).
        c = p.get("batik_color", GOLD)
        for y in range(212, 256, 18):
            half = 60 + (y - 200) * 1.4
            for x in range(int(128 - half) + 10, int(128 + half) - 6, 20):
                if 104 < x < 152 and y < 232:
                    continue  # jangan menutupi kerah
                out.append(
                    '<g opacity="0.75">' + "".join(
                        '<ellipse cx="%d" cy="%d" rx="2.6" ry="4.5" fill="%s" transform="rotate(%d %d %d)"/>' % (
                            x + dx, y + dy, c, rot, x + dx, y + dy)
                        for dx, dy, rot in [(0, -5, 0), (0, 5, 0), (-5, 0, 90), (5, 0, 90)]) + '</g>')
    if "necklace" in p.get("extras", []):
        out.append(
            '<path d="M102 186 Q128 214 154 186" stroke="%s" stroke-width="4" fill="none"/>'
            '<circle cx="128" cy="204" r="7" fill="#c0392b" stroke="%s" stroke-width="3"/>' % (GOLD, GOLD))
    return "".join(out)


def face(p):
    skin = p["skin"]
    dark = shade(skin, -0.2)
    child = p.get("child", False)
    f = p["gender"] == "f" or child
    out = []
    # Leher dan bayangan dagu
    out.append('<path d="M112 148 L144 148 L146 186 L110 186 Z" fill="%s"/>' % skin)
    out.append('<path d="M112 156 Q128 174 144 156 L144 172 Q128 182 112 172 Z" fill="%s" opacity="0.55"/>'
               % dark)
    ear = ('<ellipse cx="84" cy="120" rx="8" ry="13" fill="%s"/>'
           '<ellipse cx="85" cy="121" rx="3.5" ry="7" fill="%s" opacity="0.6"/>' % (skin, dark))
    out.append(ear + mirror(ear))
    if child:
        head = ("M82 112 Q82 58 128 58 Q174 58 174 112 Q174 146 154 162 Q140 172 128 172 "
                "Q116 172 102 162 Q82 146 82 112 Z")
    elif f:
        head = ("M84 108 Q84 58 128 58 Q172 58 172 108 Q172 140 154 158 Q140 170 128 170 "
                "Q116 170 102 158 Q84 140 84 108 Z")
    else:
        head = ("M82 106 Q82 58 128 58 Q174 58 174 106 Q174 142 158 160 Q142 172 128 172 "
                "Q114 172 98 160 Q82 142 82 106 Z")
    out.append('<path d="%s" fill="%s"/>' % (head, skin))
    out.append('<path d="M160 96 Q172 130 150 160 Q162 130 154 96 Z" fill="%s" opacity="0.35"/>' % dark)
    if f:
        out.append('<ellipse cx="102" cy="138" rx="10" ry="6" fill="#e8737a" opacity="0.3"/>'
                   '<ellipse cx="154" cy="138" rx="10" ry="6" fill="#e8737a" opacity="0.3"/>')
    # Mata
    ey = 118 if child else 115
    ir = 7.5 if child else (6.5 if f else 6)
    iris = p.get("eyes", "#3b2314")
    eye = ('<path d="M96 {y} Q108 {t} 120 {y} Q108 {b} 96 {y} Z" fill="#fff"/>'
           '<circle cx="109" cy="{y}" r="{r}" fill="{iris}"/>'
           '<circle cx="109" cy="{y}" r="{pr}" fill="#140b06"/>'
           '<circle cx="111.5" cy="{hy}" r="2" fill="#fff"/>').format(
        y=ey, t=ey - 9 - (2 if f else 0), b=ey + 7, r=ir, pr=ir * 0.45, iris=iris, hy=ey - 2.5)
    if f:
        eye += ('<path d="M95 {y} Q108 {t} 121 {y}" stroke="#2a160c" stroke-width="3" fill="none" '
                'stroke-linecap="round"/><path d="M95 {y} L91 {y2}" stroke="#2a160c" stroke-width="2.5" '
                'stroke-linecap="round"/>').format(y=ey, t=ey - 11, y2=ey - 4)
    else:
        eye += ('<path d="M96 {y} Q108 {t} 120 {y}" stroke="#2a160c" stroke-width="2.5" fill="none"/>'
                ).format(y=ey, t=ey - 9)
    if "eyepatch" in p.get("extras", []):
        out.append(eye)
        out.append('<path d="M84 96 L172 128" stroke="#1a1a1a" stroke-width="4"/>'
                   '<ellipse cx="148" cy="%d" rx="15" ry="13" fill="#1a1a1a"/>' % ey)
    else:
        out.append(eye + mirror(eye))
    # Alis
    hc = p.get("brow_color", shade(p["hair"], -0.1))
    brows = {
        "calm": '<path d="M95 101 Q108 94 121 99" stroke="%s" stroke-width="5" fill="none" stroke-linecap="round"/>',
        "fierce": '<path d="M94 95 L121 104" stroke="%s" stroke-width="6" fill="none" stroke-linecap="round"/>',
        "soft": '<path d="M97 100 Q108 95 119 99" stroke="%s" stroke-width="3.5" fill="none" stroke-linecap="round"/>',
    }[p.get("brows", "calm")] % hc
    out.append(brows + mirror(brows))
    # Hidung
    out.append('<path d="M128 120 Q123 134 130 136" stroke="%s" stroke-width="2.5" fill="none" '
               'stroke-linecap="round"/>' % dark)
    # Jenggot / kumis
    beard_c = p["hair"]
    beard = p.get("beard")
    if beard == "full":
        out.append('<path d="M84 116 Q86 152 104 168 Q128 192 152 168 Q170 152 172 116 Q168 142 152 152 '
                   'Q140 146 128 150 Q116 146 104 152 Q88 142 84 116 Z" fill="%s"/>' % beard_c)
    if beard == "stubble":
        out.append('<path d="M90 130 Q94 160 128 170 Q162 160 166 130 Q150 160 128 160 Q106 160 90 130 Z" '
                   'fill="%s" opacity="0.25"/>' % shade(beard_c, -0.2))
    # Mulut
    mouth = p.get("mouth", "smile" if f else "calm")
    if mouth == "smile":
        out.append('<path d="M116 147 Q128 158 140 147 Q128 152 116 147 Z" fill="#c4545e"/>')
    elif mouth == "fierce":
        out.append('<path d="M116 152 Q128 146 140 152" stroke="#6b2a22" stroke-width="3.5" fill="none" '
                   'stroke-linecap="round"/>')
    elif mouth == "grin":
        out.append('<path d="M114 146 Q128 162 142 146 Z" fill="#fff" stroke="#6b2a22" stroke-width="3"/>')
    else:
        out.append('<path d="M117 148 Q128 154 139 148" stroke="#7a3a2e" stroke-width="3" fill="none" '
                   'stroke-linecap="round"/>')
    if beard in ("mustache", "goatee", "full"):
        out.append('<path d="M106 142 Q118 132 128 138 Q138 132 150 142 Q138 140 128 145 Q118 140 106 142 Z" '
                   'fill="%s"/>' % beard_c)
    if beard == "goatee":
        out.append('<path d="M120 160 Q128 180 136 160 Q128 165 120 160 Z" fill="%s"/>' % beard_c)
    if "fangs" in p.get("extras", []):
        tusk = '<path d="M113 154 L116 136 L121 152 Z" fill="#fffbe8" stroke="#8a7a5a" stroke-width="1.5"/>'
        out.append(tusk + mirror(tusk))
    if "scar" in p.get("extras", []):
        out.append('<path d="M142 98 L160 132" stroke="#9e3b32" stroke-width="3" stroke-linecap="round"/>'
                   '<path d="M146 108 L154 105 M150 118 L158 115" stroke="#9e3b32" stroke-width="2"/>')
    return "".join(out)


def portrait(p):
    defs, bg = p_background(*p["bg"])
    parts = [bg]
    parts.append(hair_back(p.get("hair_style", "short"), p["hair"]))
    parts.append(body(p))
    parts.append(face(p))
    if p.get("headwear") not in ("helmet", "horned"):
        parts.append(hair_front(p.get("hair_style", "short"), p["hair"]))
    parts.append(headwear(p.get("headwear"), p))
    if "earrings" in p.get("extras", []):
        parts.append('<circle cx="84" cy="138" r="5" fill="%s"/><circle cx="172" cy="138" r="5" fill="%s"/>'
                     % (GOLD, GOLD))
    for fx, fy, fc in p.get("flowers", []):
        parts.append(flower(fx, fy, fc))
    parts.append(p_frame())
    return svg_doc(256, 256, "".join(parts), 384, 384, defs)


CHARACTERS = {
    # Penasihat
    "arya": dict(gender="m", skin=SKIN["medium"], hair="#2a1a10", hair_style="short", headwear="helmet",
                 outfit="#8e2b22", inner="#e9d6b0", beard="mustache", brows="fierce", mouth="fierce",
                 extras=["armor"], bg=("#d65a3a", "#5e1810")),
    "sekar": dict(gender="f", skin=SKIN["light"], hair="#1f140d", hair_style="bun", outfit="#2c5d8f",
                  inner="#e8eef5", shawl="#86b3d9", brows="soft", extras=["earrings"],
                  bg=("#5aa0d6", "#16304f")),
    "bayu": dict(gender="m", skin=SKIN["tan"], hair="#24170f", hair_style="short", headwear="udeng",
                 hat_color="#6b3d1e", outfit="#2f6b45", inner="#efe4c4", beard="goatee", brows="calm",
                 bg=("#5fbf7d", "#173d24")),
    "ratna": dict(gender="f", skin=SKIN["medium"], hair="#2b170c", hair_style="long", outfit="#a33a6b",
                  inner="#f6d9e6", shawl="#e58fb6", extras=["necklace", "earrings"],
                  flowers=[(164, 70, "#ffffff"), (176, 86, "#ffd1e0")], bg=("#e57aa8", "#5a1a3a")),
    "gajah": dict(gender="m", skin=SKIN["deep"], hair="#1a110b", hair_style="short", headwear="helmet",
                  metal="#7d7f88", plume="#2d2d2d", outfit="#5b2a12", beard="full", brows="fierce",
                  mouth="fierce", extras=["armor", "scar"], bg=("#e08a3a", "#4a2208")),
    "dewi": dict(gender="f", skin=SKIN["light"], hair="#140d08", hair_style="long", headwear="tiara",
                 gem="#8e44ad", outfit="#5b2f86", inner="#efe0f7", shawl="#b38ad6",
                 extras=["necklace", "earrings"], bg=("#a47ad6", "#2d1647")),
    "satria": dict(gender="m", skin=SKIN["medium"], hair="#1b120b", hair_style="topknot", headwear="crown",
                   outfit="#efe6d2", inner="#c9963f", trim="#b8862f", beard="mustache", brows="calm",
                   extras=["necklace"], bg=("#f2d27a", "#7a4b12")),
    # Penasihat khusus rekrut (gacha)
    "lintang": dict(gender="f", skin=SKIN["tan"], hair="#1d120b", hair_style="long", headwear="bandana",
                    hat_color="#3d7a4a", outfit="#2f5e3a", inner="#e9f2e4", shawl="#8fbf7a", brows="calm",
                    mouth="calm", extras=["earrings"], bg=("#6fc4a0", "#123d2e")),
    "danu": dict(gender="m", skin=SKIN["medium"], hair="#24170f", hair_style="short", headwear="udeng",
                 hat_color="#a83a22", outfit="#7a4a1e", inner="#f1e3c6", beard="stubble", brows="calm",
                 mouth="smile", bg=("#e0a060", "#4a2410")),
    "wening": dict(gender="f", skin=SKIN["light"], hair="#140d08", hair_style="bun", headwear="tiara",
                   gem="#2e86c1", outfit="#1f6f78", inner="#e4f4f5", shawl="#7cc7cc",
                   extras=["necklace", "earrings"], bg=("#62c6d0", "#0e3a40")),
    "bagas": dict(gender="m", skin=SKIN["deep"], hair="#120b07", hair_style="short", headwear="helmet",
                  metal="#b8c2cc", plume="#2e6fbf", outfit="#23395d", beard="goatee", brows="fierce",
                  mouth="fierce", extras=["armor"], bg=("#6f9fd8", "#14284a")),
    "kedaton": dict(gender="f", skin=SKIN["medium"], hair="#120a06", hair_style="long", headwear="crown",
                    outfit="#8e1b2e", inner="#fbe3c8", shawl="#e8c070", trim="#f4d58a",
                    extras=["necklace", "earrings"], bg=("#f0b050", "#6a0f20")),
    "resi": dict(gender="m", skin=SKIN["tan"], hair="#ece8e0", hair_style="topknot", outfit="#d98c1e",
                 inner="#f6ead2", trim="#8a4b12", beard="full", brows="calm", mouth="calm",
                 extras=["necklace"], bg=("#f7dc8a", "#7a4a0a")),
    # Penasihat tambahan
    "rangga": dict(gender="m", skin=SKIN["tan"], hair="#1a110b", hair_style="long", headwear="udeng",
                   hat_color="#7a1f1f", outfit="#9a2e1e", inner="#f0d9b5", beard="mustache", brows="fierce",
                   mouth="fierce", extras=["armor", "earrings"], metal="#a0743a", bg=("#e2683c", "#4a140a")),
    "sora": dict(gender="m", skin=SKIN["medium"], hair="#2a1a10", hair_style="short", headwear="blangkon",
                 hat_color="#4a5a2a", outfit="#556b2f", inner="#eef0d8", beard="goatee", brows="calm",
                 mouth="smile", bg=("#a8c46a", "#2c3a12")),
    "tantular": dict(gender="m", skin=SKIN["light"], hair="#d8d2c4", hair_style="topknot", headwear="tiara",
                     gem="#16a085", outfit="#f4f0e6", inner="#c9963f", trim="#16a085", beard="full",
                     brows="calm", mouth="calm", extras=["necklace"], bg=("#9fe0cf", "#0e4a3c")),
    "kusuma": dict(gender="f", skin=SKIN["tan"], hair="#1d120b", hair_style="bun", outfit="#b5651d",
                   inner="#fbecd6", shawl="#e8a75a", brows="soft", mouth="smile", extras=["earrings"],
                   flowers=[(150, 52, "#ffffff")], bg=("#f2b36b", "#5a2c08")),
    "jaka": dict(gender="m", skin=SKIN["medium"], hair="#120b07", hair_style="topknot", headwear="crown",
                 outfit="#1f2f5f", inner="#d4af37", trim="#d4af37", beard="stubble", brows="fierce",
                 mouth="calm", extras=["armor", "necklace"], metal="#c9a64a", bg=("#7aa0e8", "#0e1a45")),
    "nawang": dict(gender="f", skin=SKIN["light"], hair="#0f0906", hair_style="long", headwear="tiara",
                   gem="#5dade2", outfit="#eaf6fb", inner="#d6eaf8", shawl="#aed6f1", trim="#85c1e9",
                   extras=["necklace", "earrings"], flowers=[(166, 70, "#ffffff"), (178, 88, "#d6eaf8")],
                   bg=("#bfe6ff", "#1b4f72")),
    # Selir tambahan
    "kemuning": dict(gender="f", skin=SKIN["medium"], hair="#24160c", hair_style="bun", headwear="tiara",
                     gem="#f1c40f", outfit="#d4ac0d", inner="#fef9e7", shawl="#f7dc6f",
                     extras=["necklace", "earrings"], flowers=[(92, 72, "#fdfefe")], bg=("#f9e79f", "#7d6608")),
    "kantil": dict(gender="f", skin=SKIN["light"], hair="#1a0f08", hair_style="long", outfit="#f2f3f4",
                   inner="#fdfefe", shawl="#d5d8dc", extras=["earrings"],
                   flowers=[(164, 68, "#fdfefe"), (176, 84, "#fdfefe"), (154, 86, "#fdfefe")],
                   bg=("#d6dbdf", "#2c3e50")),
    # Bos aliansi
    "boss_buto": dict(gender="m", skin="#5f9e48", hair="#151510", hair_style="long", headwear="crown",
                      outfit="#6b1a1a", inner="#e8c070", brows="fierce", mouth="grin", eyes="#c0392b",
                      extras=["fangs", "earrings", "necklace", "armor"], metal="#8a6a2a",
                      bg=("#9fd36a", "#1e3a12")),
    # Selir
    "melati": dict(gender="f", skin=SKIN["light"], hair="#1d120b", hair_style="long", outfit="#4f8a5b",
                   inner="#f2f7ee", shawl="#ffffff", extras=["earrings"],
                   flowers=[(92, 70, "#ffffff"), (82, 88, "#ffffff"), (104, 60, "#ffffff")],
                   bg=("#9ed6a6", "#24502c")),
    "kenanga": dict(gender="f", skin=SKIN["medium"], hair="#24160c", hair_style="bun", outfit="#c79a1e",
                    inner="#fff3cf", shawl="#f2d36b", extras=["necklace", "earrings"],
                    flowers=[(150, 50, "#f6e27a")], bg=("#f2d36b", "#6b4e08")),
    "anggrek": dict(gender="f", skin=SKIN["tan"], hair="#120a06", hair_style="long", outfit="#6c3483",
                    inner="#f1e2f7", shawl="#c39bd3", extras=["necklace", "earrings"],
                    flowers=[(166, 72, "#d7a6e8"), (178, 90, "#b97fd0")], bg=("#c39bd3", "#3a1648")),
    "cempaka": dict(gender="f", skin=SKIN["light"], hair="#2a170b", hair_style="long", headwear="tiara",
                    gem="#e67e22", outfit="#c0561e", inner="#fde8d4", shawl="#f0a35e",
                    extras=["necklace", "earrings"], flowers=[(92, 74, "#f5b041")],
                    bg=("#f0a35e", "#5e2408")),
    # Anak
    "child_m": dict(gender="m", child=True, skin=SKIN["medium"], hair="#24170f", hair_style="child",
                    outfit="#2e86c1", inner="#eaf2f8", brows="soft", mouth="grin", bg=("#85c1e9", "#1b4f72")),
    "child_f": dict(gender="f", child=True, skin=SKIN["light"], hair="#2a170b", hair_style="pigtails",
                    outfit="#d35d8a", inner="#fdeef4", brows="soft", mouth="grin", bg=("#f5b7c8", "#7a1f45")),
    # Tuan (pemain)
    "lord": dict(gender="m", skin=SKIN["medium"], hair="#1d130c", hair_style="short", headwear="blangkon",
                 hat_color="#3b2416", outfit="#1f3a5f", inner="#efe6d2", beard="mustache", brows="calm",
                 extras=["necklace"], bg=("#4f7cac", "#13233a")),
    # Kostum Tuan
    "lord_batik": dict(gender="m", skin=SKIN["medium"], hair="#1d130c", hair_style="short", headwear="udeng",
                       hat_color="#7a4a1e", outfit="#6b3a1a", inner="#efe6d2", beard="mustache", brows="calm",
                       extras=["necklace", "batik"], batik_color="#e8c070", bg=("#c98a3a", "#4a2410")),
    "lord_zirah": dict(gender="m", skin=SKIN["medium"], hair="#1d130c", hair_style="short", headwear="helmet",
                       outfit="#5e1810", inner="#efe6d2", beard="mustache", brows="fierce", mouth="fierce",
                       extras=["armor", "scar"], metal="#8a8a95", plume="#1f3a5f", bg=("#7a8aa0", "#1a2230")),
    "lord_raja": dict(gender="m", skin=SKIN["medium"], hair="#1d130c", hair_style="short", headwear="crown",
                      outfit="#4a1f6b", inner="#f4e4c1", beard="mustache", brows="calm",
                      extras=["necklace", "batik"], batik_color="#f4d58a", bg=("#9a5ac0", "#2a0e3a")),
    # Musuh
    "enemy_bandit": dict(gender="m", skin=SKIN["tan"], hair="#2a1a10", hair_style="short", headwear="bandana",
                         hat_color="#5d4a2e", outfit="#4a3b2a", beard="stubble", brows="fierce", mouth="grin",
                         extras=["scar"], bg=("#8a7a5a", "#2a2216")),
    "enemy_rebel": dict(gender="m", skin=SKIN["medium"], hair="#1a110b", hair_style="short", headwear="bandana",
                        hat_color="#b03a2e", outfit="#3b3b3b", beard="goatee", brows="fierce", mouth="fierce",
                        bg=("#c0504d", "#3a0f0e")),
    "enemy_pirate": dict(gender="m", skin=SKIN["deep"], hair="#120b07", hair_style="short", headwear="bandana",
                         hat_color="#1f4e79", outfit="#2b2b2b", beard="full", brows="fierce", mouth="grin",
                         extras=["eyepatch"], bg=("#4a7fa8", "#0e2234")),
    "enemy_warlord": dict(gender="m", skin=SKIN["tan"], hair="#0f0a06", hair_style="short", headwear="horned",
                          outfit="#2a1f2e", beard="full", brows="fierce", mouth="fierce",
                          extras=["armor", "scar"], metal="#55525e", bg=("#6e4a7e", "#1a0e20")),
}


# --- Ikon -----------------------------------------------------------------

def icon_doc(body, defs=""):
    return svg_doc(96, 96, body, 144, 144, defs)


ICONS = {}

ICONS["silver"] = icon_doc(
    "".join(
        '<ellipse cx="48" cy="%d" rx="30" ry="10" fill="#8f98a3"/>'
        '<rect x="18" y="%d" width="60" height="8" fill="#8f98a3"/>'
        '<ellipse cx="48" cy="%d" rx="30" ry="10" fill="#c9d1da" stroke="#6b7480" stroke-width="2"/>'
        % (y + 8, y, y) for y in (72, 62, 52))
    + '<circle cx="48" cy="34" r="26" fill="#dfe6ee" stroke="#6b7480" stroke-width="3"/>'
      '<circle cx="48" cy="34" r="19" fill="none" stroke="#9aa4b0" stroke-width="2"/>'
      '<rect x="41" y="27" width="14" height="14" fill="#6b7480"/>'
      '<path d="M32 22 Q40 14 52 13" stroke="#fff" stroke-width="3" fill="none" stroke-linecap="round"/>')

ICONS["grain"] = icon_doc(
    '<path d="M22 86 Q14 56 30 40 L66 40 Q82 56 74 86 Q48 94 22 86 Z" fill="#d9b77a" stroke="#8a6a35" stroke-width="3"/>'
    '<path d="M30 40 Q48 48 66 40 L62 32 Q48 38 34 32 Z" fill="#c49a55" stroke="#8a6a35" stroke-width="3"/>'
    '<path d="M48 34 Q44 18 36 8 M48 34 Q50 16 58 6 M48 34 Q56 22 68 16" stroke="#7a8a2a" stroke-width="3" fill="none"/>'
    + "".join('<ellipse cx="%d" cy="%d" rx="3" ry="5" fill="#e8c95a" transform="rotate(%d %d %d)"/>'
              % (x, y, r, x, y) for x, y, r in [(38, 14, -30), (35, 9, -30), (56, 12, 20), (59, 7, 20),
                                                (64, 19, 50), (68, 15, 50)])
    + '<path d="M36 64 Q48 70 60 64" stroke="#8a6a35" stroke-width="3" fill="none"/>'
      '<circle cx="48" cy="58" r="6" fill="#c0392b"/>')

ICONS["soldiers"] = icon_doc(
    '<path d="M18 86 L70 10" stroke="#7a5a32" stroke-width="5"/><path d="M78 86 L26 10" stroke="#7a5a32" stroke-width="5"/>'
    '<path d="M70 10 L78 2 L74 16 Z" fill="#c9d1da"/><path d="M26 10 L18 2 L22 16 Z" fill="#c9d1da"/>'
    '<path d="M20 66 Q18 26 48 24 Q78 26 76 66 Z" fill="#c9963f" stroke="#7a4b1f" stroke-width="3"/>'
    '<path d="M14 66 L82 66 L78 76 L18 76 Z" fill="#e8c070" stroke="#7a4b1f" stroke-width="3"/>'
    '<path d="M48 24 Q62 4 80 8 Q66 14 56 28 Z" fill="#c0392b"/>'
    '<path d="M30 40 Q38 32 48 31" stroke="#fff" stroke-width="3" fill="none" opacity="0.5" stroke-linecap="round"/>')

ICONS["prestige"] = icon_doc(
    '<path d="M30 60 L20 92 L34 84 L42 94 L46 64 Z" fill="#c0392b"/><path d="M66 60 L76 92 L62 84 L54 94 L50 64 Z" fill="#a93226"/>'
    '<circle cx="48" cy="40" r="32" fill="#e8c070" stroke="#a8742c" stroke-width="4"/>'
    '<path d="M48 18 L54 34 L71 34 L57 44 L62 61 L48 51 L34 61 L39 44 L25 34 L42 34 Z" fill="#fff6d8" stroke="#a8742c" stroke-width="2"/>')

ICONS["power"] = icon_doc(
    '<path d="M48 2 Q62 14 54 24 Q46 32 56 40 Q66 50 56 58 Q50 62 54 66 L42 66 Q36 58 44 52 '
    'Q52 44 42 36 Q32 28 42 20 Q50 12 48 2 Z" fill="#d6dde6" stroke="#5d6670" stroke-width="2.5"/>'
    '<path d="M48 8 Q54 16 49 24 Q44 32 51 40 Q57 48 50 56" stroke="#9aa4b0" stroke-width="2" fill="none"/>'
    '<path d="M30 66 L66 66 L62 74 L34 74 Z" fill="#e8c070" stroke="#7a4b1f" stroke-width="2.5"/>'
    '<path d="M42 74 L54 74 L56 92 Q48 96 40 92 Z" fill="#7a4b1f" stroke="#4a2c10" stroke-width="2.5"/>')

ICONS["gold"] = icon_doc(
    "".join(
        '<path d="M%d %d L%d %d L%d %d L%d %d Z" fill="#f2c14e" stroke="#9a6a12" stroke-width="3" stroke-linejoin="round"/>'
        '<path d="M%d %d L%d %d L%d %d L%d %d Z" fill="#ffe08a"/>'
        % (x, y + 22, x + 8, y, x + 38, y, x + 46, y + 22,
           x + 9, y + 3, x + 37, y + 3, x + 40, y + 9, x + 6, y + 9)
        for x, y in [(4, 66), (46, 66), (25, 44), (25, 66)])
    + '<path d="M60 22 L64 32 L74 34 L64 38 L60 48 L56 38 L46 34 L56 32 Z" fill="#fff8d0"/>')

ICONS["tab_gacha"] = icon_doc(
    '<rect x="18" y="20" width="60" height="56" fill="#f4e4c1" stroke="#7a4b1f" stroke-width="3"/>'
    '<path d="M28 34 L68 34 M28 44 L68 44 M28 54 L58 54" stroke="#a8742c" stroke-width="3"/>'
    '<rect x="10" y="12" width="76" height="12" rx="6" fill="#a8742c" stroke="#5e3a12" stroke-width="3"/>'
    '<rect x="10" y="72" width="76" height="12" rx="6" fill="#a8742c" stroke="#5e3a12" stroke-width="3"/>'
    '<circle cx="66" cy="64" r="12" fill="#c0392b" stroke="#6b1a12" stroke-width="3"/>'
    '<path d="M60 64 L66 58 L72 64 L66 70 Z" fill="#e8c070"/>')

ICONS["rays"] = icon_doc(
    "".join('<path d="M48 48 L%.1f %.1f L%.1f %.1f Z" fill="#fff"/>' % (
        48 + 60 * math.cos(math.radians(a)), 48 + 60 * math.sin(math.radians(a)),
        48 + 60 * math.cos(math.radians(a + 12)), 48 + 60 * math.sin(math.radians(a + 12)))
        for a in range(0, 360, 30))
    + '<circle cx="48" cy="48" r="20" fill="#fff" opacity="0.8"/>')

ICONS["mission"] = icon_doc(
    '<rect x="16" y="10" width="64" height="80" rx="8" fill="#f4e4c1" stroke="#7a4b1f" stroke-width="4"/>'
    '<rect x="34" y="4" width="28" height="14" rx="5" fill="#a8742c" stroke="#5e3a12" stroke-width="3"/>'
    + "".join(
        '<rect x="26" y="%d" width="12" height="12" rx="2" fill="#fff" stroke="#7a4b1f" stroke-width="2.5"/>'
        '<path d="M44 %d L70 %d" stroke="#a8742c" stroke-width="4" stroke-linecap="round"/>' % (y, y + 6, y + 6)
        for y in (28, 48, 68))
    + '<path d="M27 33 L31 38 L39 26" stroke="#2e9a4a" stroke-width="4" fill="none" stroke-linecap="round"/>'
      '<path d="M27 53 L31 58 L39 46" stroke="#2e9a4a" stroke-width="4" fill="none" stroke-linecap="round"/>')


def chest(open_):
    lid = ('<path d="M12 40 L12 26 Q12 12 28 12 L68 12 Q84 12 84 26 L84 40 Z" fill="#a8582a" stroke="#4a2410" stroke-width="3"/>'
           '<path d="M12 30 L84 30" stroke="#e8c070" stroke-width="5"/>')
    if open_:
        lid = ('<circle cx="48" cy="40" r="30" fill="#fff1b0" opacity="0.6"/>'
               '<path d="M12 40 L20 8 Q22 2 30 4 L76 14 Q82 16 82 24 L76 42 Z" fill="#8e4a22" stroke="#4a2410" stroke-width="3"/>'
               '<path d="M18 22 L80 32" stroke="#e8c070" stroke-width="5"/>'
               '<ellipse cx="48" cy="44" rx="30" ry="8" fill="#f2c14e"/>'
               '<circle cx="36" cy="40" r="5" fill="#ffe08a"/><circle cx="56" cy="38" r="5" fill="#ffe08a"/>')
    return icon_doc(
        '<rect x="12" y="40" width="72" height="44" rx="4" fill="#a8582a" stroke="#4a2410" stroke-width="3"/>'
        '<path d="M12 52 L84 52 M12 74 L84 74" stroke="#e8c070" stroke-width="5"/>'
        '<rect x="20" y="40" width="8" height="44" fill="#e8c070"/><rect x="68" y="40" width="8" height="44" fill="#e8c070"/>'
        + lid +
        '<rect x="40" y="44" width="16" height="18" rx="3" fill="#e8c070" stroke="#7a4b1f" stroke-width="2.5"/>'
        '<circle cx="48" cy="52" r="3" fill="#4a2410"/>')


ICONS["calendar"] = icon_doc(
    '<rect x="10" y="16" width="76" height="72" rx="10" fill="#f4e4c1" stroke="#7a4b1f" stroke-width="4"/>'
    '<path d="M10 26 Q10 16 20 16 L76 16 Q86 16 86 26 L86 36 L10 36 Z" fill="#c0392b" stroke="#7a4b1f" stroke-width="4"/>'
    '<rect x="26" y="6" width="8" height="20" rx="4" fill="#e8c070" stroke="#7a4b1f" stroke-width="2.5"/>'
    '<rect x="62" y="6" width="8" height="20" rx="4" fill="#e8c070" stroke="#7a4b1f" stroke-width="2.5"/>'
    + "".join('<rect x="%d" y="%d" width="12" height="10" rx="2" fill="%s"/>' % (
        20 + c * 16, 44 + r * 14, "#e8c070" if (r * 4 + c) < 6 else "#d8c49a") for r in range(3) for c in range(4))
    + '<circle cx="74" cy="74" r="16" fill="#2e9a4a" stroke="#fff3d6" stroke-width="3"/>'
      '<path d="M66 74 L72 80 L82 68" stroke="#fff" stroke-width="5" fill="none" stroke-linecap="round"/>')

ICONS["check"] = icon_doc(
    '<circle cx="48" cy="48" r="40" fill="#2e9a4a" stroke="#fff3d6" stroke-width="6"/>'
    '<path d="M28 50 L42 64 L68 34" stroke="#fff" stroke-width="11" fill="none" stroke-linecap="round" stroke-linejoin="round"/>')

ICONS["event_harvest"] = icon_doc(
    "".join('<path d="M48 70 Q%d 40 %d 10" stroke="#9a8a2a" stroke-width="3" fill="none"/>'
            '<ellipse cx="%d" cy="%d" rx="5" ry="9" fill="#f2c14e" stroke="#a8742c" stroke-width="1.5" transform="rotate(%d %d %d)"/>'
            '<ellipse cx="%d" cy="%d" rx="5" ry="9" fill="#f2c14e" stroke="#a8742c" stroke-width="1.5" transform="rotate(%d %d %d)"/>'
            % (48 + dx // 2, 48 + dx, 48 + dx, 14, dx // 2, 48 + dx, 14,
               48 + dx * 0.8, 26, dx // 2 + 10, 48 + dx * 0.8, 26) for dx in (-24, -12, 0, 12, 24))
    + '<path d="M36 64 L60 64 L56 92 L40 92 Z" fill="#c9a24a" stroke="#7a5a1f" stroke-width="3"/>'
      '<rect x="32" y="62" width="32" height="9" rx="4" fill="#c0392b" stroke="#6b1a12" stroke-width="2"/>'
      '<path d="M66 92 Q90 80 84 56 Q80 70 66 76" fill="#d6dde6" stroke="#5d6670" stroke-width="2.5"/>'
      '<rect x="60" y="76" width="8" height="18" rx="3" fill="#7a4b1f" transform="rotate(-30 64 85)"/>')

ICONS["event_tournament"] = icon_doc(
    '<path d="M14 92 L70 6" stroke="#7a5a32" stroke-width="5"/><path d="M82 92 L26 6" stroke="#7a5a32" stroke-width="5"/>'
    '<path d="M70 6 L78 0 L74 14 Z" fill="#c9d1da"/><path d="M26 6 L18 0 L22 14 Z" fill="#c9d1da"/>'
    '<path d="M28 22 L68 22 L66 44 Q64 62 48 64 Q32 62 30 44 Z" fill="#f2c14e" stroke="#9a6a12" stroke-width="3"/>'
    '<path d="M28 28 Q14 28 16 40 Q18 50 31 50" stroke="#f2c14e" stroke-width="5" fill="none"/>'
    '<path d="M68 28 Q82 28 80 40 Q78 50 65 50" stroke="#f2c14e" stroke-width="5" fill="none"/>'
    '<rect x="43" y="64" width="10" height="12" fill="#c9963f"/>'
    '<rect x="32" y="76" width="32" height="12" rx="3" fill="#a8742c" stroke="#5e3a12" stroke-width="3"/>'
    '<path d="M48 30 L52 39 L61 40 L54 46 L56 55 L48 50 L40 55 L42 46 L35 40 L44 39 Z" fill="#fff6d8"/>')

ICONS["event_market"] = icon_doc(
    '<path d="M6 46 L18 24 L78 24 L90 46 Z" fill="#c0392b" stroke="#6b1a12" stroke-width="3"/>'
    + "".join('<path d="M%d 46 Q%d 54 %d 46" fill="#f4e4c1" stroke="#6b1a12" stroke-width="2"/>' % (x, x + 7, x + 14)
              for x in range(6, 90, 14))
    + '<rect x="14" y="52" width="6" height="40" fill="#7a4b1f"/><rect x="76" y="52" width="6" height="40" fill="#7a4b1f"/>'
      '<rect x="20" y="70" width="56" height="10" fill="#a8742c" stroke="#5e3a12" stroke-width="2"/>'
      '<circle cx="34" cy="66" r="6" fill="#e67e22"/><circle cx="48" cy="65" r="7" fill="#27ae60"/>'
      '<circle cx="62" cy="66" r="6" fill="#f1c40f"/>'
      '<path d="M48 4 L48 12" stroke="#e8c070" stroke-width="3"/>'
      '<ellipse cx="48" cy="18" rx="10" ry="8" fill="#e74c3c" stroke="#e8c070" stroke-width="2"/>')

ICONS["event_palace"] = icon_doc(
    "".join('<path d="M48 82 L%.1f %.1f A44 44 0 0 1 %.1f %.1f Z" fill="%s" stroke="#8e1f45" stroke-width="2"/>' % (
        48 + 44 * math.cos(math.radians(a0)), 82 + 44 * math.sin(math.radians(a0)),
        48 + 44 * math.cos(math.radians(a0 + 20)), 82 + 44 * math.sin(math.radians(a0 + 20)),
        "#f5b7c8" if k % 2 == 0 else "#e8829e") for k, a0 in enumerate(range(-170, -10, 20)))
    + '<path d="M10 72 A44 44 0 0 1 86 72" stroke="#e8c070" stroke-width="4" fill="none"/>'
      '<circle cx="48" cy="82" r="6" fill="#e8c070" stroke="#7a4b1f" stroke-width="2"/>'
    + flower(66, 30, "#ffffff", 8))

ICONS["event_ritual"] = icon_doc(
    '<circle cx="48" cy="34" r="28" fill="#fff4c8" stroke="#e8c070" stroke-width="3"/>'
    '<circle cx="40" cy="28" r="5" fill="#efe0a8"/><circle cx="58" cy="40" r="4" fill="#efe0a8"/><circle cx="52" cy="22" r="3" fill="#efe0a8"/>'
    '<path d="M48 62 Q40 54 48 48 Q56 42 48 36" stroke="#d8d0e8" stroke-width="3" fill="none" opacity="0.8"/>'
    '<path d="M30 74 L66 74 L60 92 L36 92 Z" fill="#a8742c" stroke="#5e3a12" stroke-width="3"/>'
    '<rect x="26" y="70" width="44" height="8" rx="3" fill="#e8c070" stroke="#5e3a12" stroke-width="2"/>'
    '<path d="M48 70 L48 60" stroke="#7a4b1f" stroke-width="3"/><circle cx="48" cy="59" r="3" fill="#e74c3c"/>')

def emblem(color, symbol):
    shield = ('<path d="M48 4 L86 16 L82 54 Q78 78 48 93 Q18 78 14 54 L10 16 Z" fill="%s" stroke="#e8c070" stroke-width="5"/>'
              '<path d="M48 12 L78 22 L75 53 Q72 72 48 84 Q24 72 21 53 L18 22 Z" fill="none" stroke="#fff3" stroke-width="2"/>'
              % color)
    return icon_doc(shield + symbol)


ICONS["emblem_garuda"] = emblem("#a8241e",
    '<path d="M48 30 Q30 22 18 30 Q30 34 34 40 Q22 40 20 48 Q34 46 40 50 L48 66 L56 50 Q62 46 76 48 Q74 40 62 40 '
    'Q66 34 78 30 Q66 22 48 30 Z" fill="#f2c14e" stroke="#7a4b1f" stroke-width="2"/>'
    '<circle cx="48" cy="30" r="7" fill="#f2c14e" stroke="#7a4b1f" stroke-width="2"/>'
    '<path d="M52 28 L58 30 L52 32 Z" fill="#7a4b1f"/><path d="M42 66 L48 76 L54 66 Z" fill="#f2c14e"/>')

ICONS["emblem_teratai"] = emblem("#1f6f5a",
    "".join('<ellipse cx="48" cy="44" rx="8" ry="20" fill="%s" stroke="#a8742c" stroke-width="1.5" '
            'transform="rotate(%d 48 60)"/>' % ("#f7c6d6" if abs(a) != 0 else "#fbe3ec", a)
            for a in (-60, 60, -30, 30, 0))
    + '<path d="M26 64 Q48 74 70 64" stroke="#e8c070" stroke-width="4" fill="none"/>'
      '<circle cx="48" cy="56" r="5" fill="#f2c14e"/>')

ICONS["emblem_macan"] = emblem("#2c3e50",
    '<path d="M28 30 L34 18 L42 28 Z" fill="#e67e22" stroke="#4a2410" stroke-width="2"/>'
    '<path d="M68 30 L62 18 L54 28 Z" fill="#e67e22" stroke="#4a2410" stroke-width="2"/>'
    '<ellipse cx="48" cy="46" rx="22" ry="21" fill="#e67e22" stroke="#4a2410" stroke-width="2.5"/>'
    '<path d="M48 26 L48 34 M38 28 L41 35 M58 28 L55 35 M27 44 L34 45 M69 44 L62 45 M28 52 L35 51 M68 52 L61 51" '
    'stroke="#2a1a10" stroke-width="3" stroke-linecap="round"/>'
    '<ellipse cx="48" cy="56" rx="11" ry="8" fill="#fff3e0"/>'
    '<circle cx="40" cy="44" r="3.5" fill="#2a1a10"/><circle cx="56" cy="44" r="3.5" fill="#2a1a10"/>'
    '<path d="M44 52 L52 52 L48 56 Z" fill="#2a1a10"/>')

ICONS["tab_alliance"] = icon_doc(
    '<path d="M22 92 L22 8" stroke="#7a4b1f" stroke-width="5"/><path d="M74 92 L74 8" stroke="#7a4b1f" stroke-width="5"/>'
    '<path d="M24 10 L50 10 L44 26 L50 42 L24 42 Z" fill="#c0392b" stroke="#6b1a12" stroke-width="2.5"/>'
    '<path d="M72 10 L46 10 L52 26 L46 42 L72 42 Z" fill="#2e6fbf" stroke="#14284a" stroke-width="2.5"/>'
    '<circle cx="34" cy="26" r="5" fill="#e8c070"/><circle cx="62" cy="26" r="5" fill="#e8c070"/>'
    '<path d="M30 70 Q48 50 66 70 L60 78 Q48 66 36 78 Z" fill="#e8c070" stroke="#7a4b1f" stroke-width="3"/>'
    '<circle cx="48" cy="58" r="6" fill="#e8c070" stroke="#7a4b1f" stroke-width="2.5"/>')

ICONS["jasa"] = icon_doc(
    '<circle cx="48" cy="48" r="38" fill="#c98a4a" stroke="#6b3d1a" stroke-width="4"/>'
    '<circle cx="48" cy="48" r="29" fill="none" stroke="#e8b27a" stroke-width="3"/>'
    '<path d="M28 52 Q34 42 44 46 L52 40 Q58 36 64 42 L70 50 Q66 56 58 54 L50 60 Q42 64 36 58 Z" '
    'fill="#f6d2a8" stroke="#6b3d1a" stroke-width="2.5" stroke-linejoin="round"/>'
    '<path d="M34 26 Q40 18 48 22" stroke="#fff" stroke-width="3" fill="none" opacity="0.5" stroke-linecap="round"/>')

ICONS["tab_arena"] = icon_doc(
    '<circle cx="48" cy="50" r="40" fill="#7a2e22" stroke="#e8c070" stroke-width="5"/>'
    '<path d="M24 76 L66 22 M72 76 L30 22" stroke="#d6dde6" stroke-width="7" stroke-linecap="round"/>'
    '<path d="M26 66 L36 76 M70 66 L60 76" stroke="#a8742c" stroke-width="8" stroke-linecap="round"/>'
    '<path d="M18 30 Q8 50 20 72 M78 30 Q88 50 76 72" stroke="#6fbf5a" stroke-width="5" fill="none"/>')

ICONS["arena_coin"] = icon_doc(
    '<circle cx="48" cy="48" r="38" fill="#9b59b6" stroke="#4a235a" stroke-width="4"/>'
    '<circle cx="48" cy="48" r="29" fill="none" stroke="#d2b4de" stroke-width="3"/>'
    '<path d="M32 64 L60 30 M64 64 L36 30" stroke="#f4ecf7" stroke-width="5" stroke-linecap="round"/>'
    '<path d="M34 24 Q42 18 50 20" stroke="#fff" stroke-width="3" fill="none" opacity="0.5" stroke-linecap="round"/>')

ICONS["ticket"] = icon_doc(
    '<path d="M10 28 L86 28 L86 40 Q78 48 86 56 L86 68 L10 68 L10 56 Q18 48 10 40 Z" fill="#e8c070" '
    'stroke="#7a4b1f" stroke-width="3.5"/>'
    '<path d="M30 30 L30 66" stroke="#7a4b1f" stroke-width="2.5" stroke-dasharray="4 4"/>'
    '<path d="M44 58 L70 38 M70 58 L44 38" stroke="#a8241e" stroke-width="5" stroke-linecap="round"/>')


def league_badge(color, stars):
    star = '<path d="M0 -7 L2 -2 L7 -2 L3 1 L4.5 6 L0 3 L-4.5 6 L-3 1 L-7 -2 L-2 -2 Z" fill="#fff8d0" stroke="#7a4b1f" stroke-width="1"/>'
    row = "".join('<g transform="translate(%.1f 82)">%s</g>' % (48 + (i - (stars - 1) / 2) * 15, star)
                  for i in range(stars))
    return icon_doc(
        '<path d="M48 4 L82 16 L80 50 Q76 72 48 86 Q20 72 16 50 L14 16 Z" fill="%s" stroke="#3a2418" stroke-width="4"/>'
        '<path d="M48 12 L74 21 L72 49 Q69 66 48 77 Q27 66 24 49 L22 21 Z" fill="%s"/>'
        '<path d="M34 54 L62 24 M62 54 L34 24" stroke="#fff" stroke-width="5" stroke-linecap="round" opacity="0.9"/>'
        '<circle cx="48" cy="39" r="7" fill="%s" stroke="#fff" stroke-width="2"/>' % (
            color, shade(color, 0.25), shade(color, -0.3)) + row)


for i, (c, n) in enumerate([("#b07a45", 1), ("#9aa4b0", 2), ("#e0a830", 3), ("#4fb3d9", 4), ("#c0392b", 5)]):
    ICONS["league_%d" % i] = league_badge(c, n)

ICONS["pointer"] = icon_doc(
    '<path d="M34 6 L62 6 L62 46 L82 46 L48 90 L14 46 L34 46 Z" fill="#f2c14e" stroke="#5e3a12" '
    'stroke-width="5" stroke-linejoin="round"/>'
    '<path d="M40 12 L40 50" stroke="#fff6d0" stroke-width="5" stroke-linecap="round" opacity="0.8"/>')

ICONS["help"] = icon_doc(
    '<circle cx="48" cy="48" r="40" fill="#2e86c1" stroke="#fff3d6" stroke-width="5"/>'
    '<path d="M34 36 Q34 20 48 20 Q64 20 64 34 Q64 44 52 48 Q48 50 48 58" stroke="#fff" stroke-width="9" '
    'fill="none" stroke-linecap="round"/>'
    '<circle cx="48" cy="74" r="6" fill="#fff"/>')

def gold_bar(x, y, w=30):
    return ('<path d="M%d %d L%d %d L%d %d L%d %d Z" fill="#f2c14e" stroke="#9a6a12" stroke-width="2.5" stroke-linejoin="round"/>'
            '<path d="M%d %d L%d %d" stroke="#ffe08a" stroke-width="3"/>'
            % (x, y + 14, x + 5, y, x + w - 5, y, x + w, y + 14, x + 6, y + 4, x + w - 6, y + 4))


ICONS["gold_pile"] = icon_doc(
    "".join(gold_bar(x, y) for x, y in [(6, 76), (34, 76), (62, 76), (20, 62), (48, 62), (34, 48)])
    + '<path d="M70 20 L73 28 L81 30 L73 33 L70 41 L67 33 L59 30 L67 28 Z" fill="#fff8d0"/>')

ICONS["gold_sack"] = icon_doc(
    '<path d="M24 90 Q8 60 30 40 L66 40 Q88 60 72 90 Z" fill="#b8864a" stroke="#5e3a12" stroke-width="3.5"/>'
    '<path d="M32 40 Q48 30 64 40 L60 30 Q48 24 36 30 Z" fill="#9a6a32" stroke="#5e3a12" stroke-width="3"/>'
    '<rect x="34" y="36" width="28" height="7" rx="3" fill="#c0392b"/>'
    + gold_bar(24, 18) + gold_bar(44, 12)
    + '<circle cx="48" cy="66" r="12" fill="#f2c14e" stroke="#9a6a12" stroke-width="2.5"/>'
      '<rect x="44" y="62" width="8" height="8" fill="#9a6a12"/>')

ICONS["gold_crown"] = icon_doc(
    "".join(gold_bar(x, y, 26) for x, y in [(4, 80), (28, 80), (52, 80), (70, 80), (16, 68), (40, 68), (62, 68), (28, 56), (52, 56)])
    + '<path d="M22 46 L18 16 L34 30 L48 8 L62 30 L78 16 L74 46 Z" fill="#f2c14e" stroke="#9a6a12" stroke-width="3" stroke-linejoin="round"/>'
      '<circle cx="48" cy="34" r="5" fill="#c0392b"/><circle cx="32" cy="38" r="3.5" fill="#2e86c1"/><circle cx="64" cy="38" r="3.5" fill="#2e86c1"/>')

ICONS["card_monthly"] = icon_doc(
    '<rect x="8" y="18" width="80" height="60" rx="10" fill="#2c3e78" stroke="#e8c070" stroke-width="4"/>'
    '<path d="M8 34 L88 34" stroke="#e8c070" stroke-width="3"/>'
    '<circle cx="66" cy="56" r="13" fill="#fff4c8"/><circle cx="72" cy="51" r="11" fill="#2c3e78"/>'
    + "".join('<rect x="%d" y="%d" width="7" height="6" rx="1" fill="#f2c14e"/>' % (16 + c * 10, 42 + r * 9)
              for r in range(3) for c in range(4)) +
    '<path d="M60 22 L63 28 L69 29 L64 32 L66 38 L60 34 L54 38 L56 32 L51 29 L57 28 Z" fill="#f2c14e"/>')

ICONS["starter"] = icon_doc(
    '<rect x="14" y="42" width="68" height="46" rx="6" fill="#c0392b" stroke="#6b1a12" stroke-width="3.5"/>'
    '<rect x="8" y="30" width="80" height="16" rx="5" fill="#e74c3c" stroke="#6b1a12" stroke-width="3.5"/>'
    '<rect x="42" y="30" width="12" height="58" fill="#f2c14e"/>'
    '<path d="M48 30 Q30 8 22 20 Q18 30 48 30 Q78 30 74 20 Q66 8 48 30 Z" fill="#f2c14e" stroke="#9a6a12" stroke-width="3"/>'
    '<path d="M74 56 L77 63 L84 64 L79 68 L80 75 L74 71 L68 75 L69 68 L64 64 L71 63 Z" fill="#fff8d0"/>')

ICONS["plus"] = icon_doc(
    '<circle cx="48" cy="48" r="40" fill="#4f9a4a" stroke="#fff3d6" stroke-width="7"/>'
    '<path d="M48 26 L48 70 M26 48 L70 48" stroke="#fff" stroke-width="12" stroke-linecap="round"/>')

ICONS["store"] = icon_doc(
    '<path d="M14 36 L82 36 L76 90 L20 90 Z" fill="#c0392b" stroke="#6b1a12" stroke-width="3.5"/>'
    '<path d="M32 36 Q32 10 48 10 Q64 10 64 36" stroke="#e8c070" stroke-width="6" fill="none"/>'
    + gold_bar(33, 54) + '<circle cx="48" cy="80" r="5" fill="#f2c14e"/>')

ICONS["vip"] = icon_doc(
    '<path d="M10 70 L6 24 L28 42 L48 12 L68 42 L90 24 L86 70 Z" fill="#f2c14e" stroke="#7a4b1f" stroke-width="4" stroke-linejoin="round"/>'
    '<rect x="10" y="68" width="76" height="18" rx="5" fill="#c0392b" stroke="#7a4b1f" stroke-width="4"/>'
    '<path d="M34 40 L48 64 L62 40" stroke="#7a4b1f" stroke-width="8" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
    '<circle cx="48" cy="12" r="5" fill="#2e86c1"/><circle cx="6" cy="24" r="4" fill="#27ae60"/><circle cx="90" cy="24" r="4" fill="#27ae60"/>'
    '<circle cx="30" cy="77" r="4" fill="#f2c14e"/><circle cx="48" cy="77" r="4" fill="#f2c14e"/><circle cx="66" cy="77" r="4" fill="#f2c14e"/>')

def fort(flag, wall="#8a7a6a", core=False, ruined=False):
    out = ('<path d="M12 90 L12 40 L22 40 L22 32 L32 32 L32 40 L42 40 L42 32 L54 32 L54 40 L64 40 L64 32 L74 32 '
           'L74 40 L84 40 L84 90 Z" fill="%s" stroke="#3a2a20" stroke-width="3.5" stroke-linejoin="round"/>' % wall)
    out += "".join('<path d="M%d %d L%d %d" stroke="%s" stroke-width="2"/>' % (12, y, 84, y, shade(wall, -0.25))
                   for y in (56, 72))
    out += '<path d="M38 90 L38 70 Q48 60 58 70 L58 90 Z" fill="#2a1a10"/>'
    if core:
        out += ('<path d="M30 32 L30 18 L48 4 L66 18 L66 32 Z" fill="%s" stroke="#3a2a20" stroke-width="3"/>' % shade(wall, 0.1)
                + '<path d="M38 18 L44 10 L48 16 L52 10 L58 18 Z" fill="#f2c14e"/>')
    px = 69 if core else 48  # pada Keraton, bendera di menara kanan agar tidak menutupi mahkota
    out += '<path d="M%d 32 L%d 6" stroke="#3a2a20" stroke-width="3"/>' % (px, px)
    out += '<path d="M%d 6 L%d 13 L%d 20 Z" fill="%s" stroke="#3a2a20" stroke-width="2"/>' % (
        px + 2, px + 24 if not core else px + 20, px + 2, flag)
    if ruined:
        out += '<path d="M14 88 L30 70 L24 88 Z M70 88 L82 66 L82 88 Z" fill="#3a2a20" opacity="0.5"/>'
    return icon_doc(out)


ICONS["fort"] = fort("#c0392b")
ICONS["fort_core"] = fort("#c0392b", "#9a8070", core=True)
ICONS["fort_captured"] = fort("#f2c14e", "#7a6a5a", ruined=True)

ICONS["trophy"] = icon_doc(
    '<path d="M28 10 L68 10 L66 40 Q64 60 48 62 Q32 60 30 40 Z" fill="#f2c14e" stroke="#9a6a12" stroke-width="3.5"/>'
    '<path d="M28 18 Q10 18 12 32 Q14 44 30 46" stroke="#f2c14e" stroke-width="6" fill="none"/>'
    '<path d="M68 18 Q86 18 84 32 Q82 44 66 46" stroke="#f2c14e" stroke-width="6" fill="none"/>'
    '<path d="M38 18 Q36 36 46 48" stroke="#fff6d0" stroke-width="4" fill="none" opacity="0.7" stroke-linecap="round"/>'
    '<rect x="42" y="62" width="12" height="14" fill="#c9963f"/>'
    '<rect x="28" y="76" width="40" height="14" rx="3" fill="#7a4b1f" stroke="#4a2c10" stroke-width="3"/>'
    '<rect x="38" y="80" width="20" height="5" rx="2" fill="#f2c14e"/>')

ICONS["item_scroll"] = icon_doc(
    '<rect x="22" y="18" width="52" height="60" fill="#f4e4c1" stroke="#7a4b1f" stroke-width="3"/>'
    '<path d="M32 32 L64 32 M32 42 L64 42 M32 52 L56 52" stroke="#2e86c1" stroke-width="3"/>'
    '<rect x="14" y="10" width="68" height="12" rx="6" fill="#2e86c1" stroke="#14284a" stroke-width="3"/>'
    '<rect x="14" y="74" width="68" height="12" rx="6" fill="#2e86c1" stroke="#14284a" stroke-width="3"/>'
    '<path d="M62 56 L68 62 L80 46" stroke="#27ae60" stroke-width="5" fill="none" stroke-linecap="round"/>')

ICONS["item_star"] = icon_doc(
    '<path d="M48 6 L74 30 L64 84 L32 84 L22 30 Z" fill="#8e44ad" stroke="#4a235a" stroke-width="4" stroke-linejoin="round"/>'
    '<path d="M48 6 L48 84 M22 30 L74 30" stroke="#c39bd3" stroke-width="2.5"/>'
    '<path d="M48 34 L53 46 L66 47 L56 55 L59 68 L48 61 L37 68 L40 55 L30 47 L43 46 Z" fill="#f4c542" stroke="#9a6a12" stroke-width="2"/>')

ICONS["item_pill"] = icon_doc(
    '<path d="M20 30 Q20 14 34 14 L62 14 Q76 14 76 30 L76 74 Q76 88 62 88 L34 88 Q20 88 20 74 Z" fill="#f5b7c8" '
    'stroke="#8e1f45" stroke-width="3.5"/>'
    '<rect x="30" y="6" width="36" height="12" rx="4" fill="#c0392b" stroke="#6b1a12" stroke-width="3"/>'
    '<path d="M48 70 Q30 58 31 46 Q32 38 40 38 Q46 38 48 45 Q50 38 56 38 Q64 38 65 46 Q66 58 48 70 Z" fill="#e0507a"/>')

ICONS["item_tea"] = icon_doc(
    '<path d="M16 40 L72 40 L66 82 Q48 90 22 82 Z" fill="#f4e4c1" stroke="#7a4b1f" stroke-width="3.5"/>'
    '<path d="M72 48 Q90 48 86 62 Q82 72 68 70" stroke="#7a4b1f" stroke-width="5" fill="none"/>'
    '<ellipse cx="44" cy="42" rx="26" ry="5" fill="#8a9a3a"/>'
    '<path d="M34 30 Q28 20 36 12 M50 32 Q44 20 52 10" stroke="#c9d1da" stroke-width="3.5" fill="none" stroke-linecap="round"/>'
    '<path d="M30 60 L58 60" stroke="#27ae60" stroke-width="4"/>')

ICONS["ticket_recruit"] = icon_doc(
    '<path d="M8 26 L88 26 L88 40 Q80 48 88 56 L88 70 L8 70 L8 56 Q16 48 8 40 Z" fill="#f2c14e" stroke="#7a4b1f" stroke-width="3.5"/>'
    '<path d="M30 28 L30 68" stroke="#7a4b1f" stroke-width="2.5" stroke-dasharray="4 4"/>'
    '<rect x="44" y="34" width="34" height="28" rx="3" fill="#f4e4c1" stroke="#7a4b1f" stroke-width="2.5"/>'
    '<path d="M50 42 L72 42 M50 48 L72 48 M50 54 L64 54" stroke="#a8742c" stroke-width="2.5"/>'
    '<circle cx="18" cy="48" r="6" fill="#c0392b"/>')

ICONS["bag"] = icon_doc(
    '<path d="M18 40 Q14 88 30 90 L66 90 Q82 88 78 40 Z" fill="#a8582a" stroke="#4a2410" stroke-width="3.5"/>'
    '<path d="M30 40 Q30 14 48 14 Q66 14 66 40" stroke="#4a2410" stroke-width="6" fill="none"/>'
    '<rect x="14" y="36" width="68" height="12" rx="5" fill="#e8c070" stroke="#4a2410" stroke-width="3"/>'
    '<rect x="40" y="56" width="16" height="14" rx="3" fill="#e8c070" stroke="#4a2410" stroke-width="2.5"/>')

ICONS["prison"] = icon_doc(
    '<rect x="8" y="10" width="80" height="78" rx="6" fill="none" stroke="#4a4a52" stroke-width="6"/>'
    + "".join('<path d="M%d 12 L%d 86" stroke="#5d5d66" stroke-width="6" stroke-linecap="round"/>' % (x, x)
              for x in range(22, 80, 14))
    + '<path d="M8 48 L88 48" stroke="#4a4a52" stroke-width="5"/>'
      '<circle cx="74" cy="56" r="6" fill="#c9963f" stroke="#5e3a12" stroke-width="2"/>')

def gear():
    import math
    pts = []
    for i in range(16):
        r = 40 if i % 2 == 0 else 31
        for da in (-0.13, 0.13):
            a = (i + 0.5) * math.pi / 8 + da
            pts.append("%.1f %.1f" % (48 + r * math.cos(a), 48 + r * math.sin(a)))
    return icon_doc(
        '<path d="M%s Z" fill="#8f98a3" stroke="#3f4650" stroke-width="3.5" stroke-linejoin="round"/>' % " L".join(pts)
        + '<circle cx="48" cy="48" r="22" fill="#c9d1da" stroke="#3f4650" stroke-width="3"/>'
          '<circle cx="48" cy="48" r="10" fill="#5a2e14" stroke="#3f4650" stroke-width="3"/>'
          '<path d="M34 36 Q40 28 50 28" stroke="#fff" stroke-width="3" fill="none" stroke-linecap="round"/>')


ICONS["settings"] = gear()

# Tiket Musim: tiket emas bergerigi dengan bintang.
ICONS["pass"] = icon_doc(
    '<path d="M10 24 L86 24 L86 40 Q78 48 86 56 L86 72 L10 72 L10 56 Q18 48 10 40 Z" fill="#e8c070" '
    'stroke="#8a5a12" stroke-width="3" stroke-linejoin="round"/>'
    '<path d="M64 26 L64 70" stroke="#8a5a12" stroke-width="2" stroke-dasharray="4 3"/>'
    '<path d="M36 34 L40 44 L51 44 L42 50 L46 61 L36 54 L26 61 L30 50 L21 44 L32 44 Z" fill="#c0392b" '
    'stroke="#6b1a12" stroke-width="2" stroke-linejoin="round"/>'
    '<path d="M70 38 L80 38 M70 48 L80 48 M70 58 L80 58" stroke="#8a5a12" stroke-width="3" stroke-linecap="round"/>')

# Menara Ujian: candi bertingkat.
ICONS["tower"] = icon_doc(
    '<path d="M14 88 L82 88 L76 74 L20 74 Z" fill="#8a5a3a" stroke="#3b2210" stroke-width="2.5" stroke-linejoin="round"/>'
    '<path d="M22 74 L74 74 L68 58 L28 58 Z" fill="#a86a42" stroke="#3b2210" stroke-width="2.5" stroke-linejoin="round"/>'
    '<path d="M30 58 L66 58 L61 42 L35 42 Z" fill="#c07a4a" stroke="#3b2210" stroke-width="2.5" stroke-linejoin="round"/>'
    '<path d="M37 42 L59 42 L55 28 L41 28 Z" fill="#d48c56" stroke="#3b2210" stroke-width="2.5" stroke-linejoin="round"/>'
    '<path d="M42 28 L54 28 L48 8 Z" fill="#e8c070" stroke="#6b4a12" stroke-width="2.5" stroke-linejoin="round"/>'
    '<rect x="42" y="78" width="12" height="10" fill="#3b2210"/>'
    '<path d="M44 64 L52 64 L52 72 L44 72 Z" fill="#3b2210"/>')

# Formasi pasukan: susunan titik prajurit di atas panji.
def formation_icon(points, color):
    b = '<rect x="8" y="8" width="80" height="80" rx="16" fill="#f4e4c1" stroke="#7a4b1f" stroke-width="3"/>'
    for x, y in points:
        b += '<circle cx="%d" cy="%d" r="7" fill="%s" stroke="#3b2416" stroke-width="2"/>' % (x, y, color)
    return icon_doc(b)


ICONS["formation_balanced"] = formation_icon(
    [(x, y) for x in (30, 48, 66) for y in (30, 48, 66)], "#3f7fc4")
ICONS["formation_assault"] = formation_icon(
    [(70, 48), (54, 36), (54, 60), (38, 24), (38, 48), (38, 72), (22, 36), (22, 60)], "#c0392b")
ICONS["formation_defense"] = icon_doc(
    '<rect x="8" y="8" width="80" height="80" rx="16" fill="#f4e4c1" stroke="#7a4b1f" stroke-width="3"/>'
    '<path d="M48 16 L76 26 Q76 62 48 82 Q20 62 20 26 Z" fill="#8a6a3a" stroke="#3b2416" stroke-width="3" '
    'stroke-linejoin="round"/>'
    '<path d="M48 26 L66 32 Q66 58 48 72 Q30 58 30 32 Z" fill="#e8c070"/>')

# Festival musiman.
ICONS["fest_tahun_baru"] = icon_doc(
    '<circle cx="48" cy="48" r="40" fill="#1b2a6b"/>'
    + "".join('<path d="M48 44 L%.1f %.1f" stroke="%s" stroke-width="4" stroke-linecap="round"/>'
              '<circle cx="%.1f" cy="%.1f" r="4" fill="%s"/>' % (
                  48 + 30 * math.cos(math.radians(a)), 44 + 30 * math.sin(math.radians(a)), c,
                  48 + 34 * math.cos(math.radians(a)), 44 + 34 * math.sin(math.radians(a)), c)
              for a, c in zip(range(0, 360, 30), ["#f4d03f", "#e74c3c", "#5dade2", "#f4d03f", "#58d68d",
                                                  "#e74c3c", "#f4d03f", "#af7ac5", "#5dade2", "#f4d03f",
                                                  "#58d68d", "#e74c3c"]))
    + '<circle cx="48" cy="44" r="7" fill="#fff6d8"/>'
      '<path d="M20 86 L26 70 M74 86 L68 72" stroke="#f4d03f" stroke-width="3" stroke-linecap="round"/>')
ICONS["fest_ramadan"] = icon_doc(
    '<path d="M48 10 L84 46 L48 82 L12 46 Z" fill="#7fb34d" stroke="#2f5a1a" stroke-width="3" stroke-linejoin="round"/>'
    '<path d="M30 28 L66 64 M48 10 L48 82 M66 28 L30 64 M12 46 L84 46" stroke="#cfe5a0" stroke-width="3"/>'
    '<path d="M39 19 L75 55 M57 19 L21 55 M21 37 L57 73 M75 37 L39 73" stroke="#2f5a1a" stroke-width="1.5" opacity="0.6"/>'
    '<path d="M48 82 Q44 92 36 94 M48 82 Q54 92 62 92" stroke="#2f5a1a" stroke-width="3" fill="none"/>'
    '<path d="M78 8 Q66 14 68 26 Q74 18 84 18 Q76 14 78 8 Z" fill="#f4d03f"/>')
ICONS["fest_merdeka"] = icon_doc(
    '<path d="M22 8 L22 92" stroke="#6b4a2a" stroke-width="5" stroke-linecap="round"/>'
    '<circle cx="22" cy="8" r="5" fill="#e8c070"/>'
    '<path d="M25 14 Q50 6 84 16 L84 38 Q50 28 25 36 Z" fill="#d6241e"/>'
    '<path d="M25 36 Q50 28 84 38 L84 60 Q50 50 25 58 Z" fill="#ffffff" stroke="#c9c9c9" stroke-width="1"/>'
    '<path d="M40 80 Q48 70 56 80 Q64 90 72 80" stroke="#c0392b" stroke-width="4" fill="none" stroke-linecap="round"/>')
ICONS["fest_sumpah_pemuda"] = icon_doc(
    '<path d="M40 50 L56 50 L52 92 L44 92 Z" fill="#8a5a3a" stroke="#3b2210" stroke-width="2.5"/>'
    '<rect x="36" y="44" width="24" height="10" rx="3" fill="#c9963f" stroke="#6b4a12" stroke-width="2"/>'
    '<path d="M48 6 Q66 22 60 36 Q58 44 48 44 Q36 44 36 34 Q36 24 44 18 Q44 28 50 30 Q52 18 48 6 Z" fill="#e67e22"/>'
    '<path d="M48 20 Q56 30 54 38 Q50 42 46 40 Q42 34 48 20 Z" fill="#f4d03f"/>'
    '<path d="M14 70 L32 62 M82 70 L64 62 M18 50 L32 50 M78 50 L64 50" stroke="#c0392b" stroke-width="4" stroke-linecap="round"/>')
ICONS["fest_pahlawan"] = icon_doc(
    '<path d="M30 92 L60 10" stroke="#9aaa4a" stroke-width="9" stroke-linecap="round"/>'
    '<path d="M60 10 L54 30" stroke="#d8e08a" stroke-width="3"/>'
    '<path d="M36 76 L40 66 M44 54 L48 44" stroke="#5e6a1e" stroke-width="10" opacity="0.5"/>'
    '<path d="M60 10 L66 4 L64 18 Z" fill="#c9d1da"/>'
    '<path d="M54 34 Q78 30 86 44 Q74 42 70 54 Q64 40 54 44 Z" fill="#d6241e"/>'
    '<path d="M54 44 Q64 40 70 54 Q60 50 52 54 Z" fill="#ffffff"/>')
ICONS["frame"] = icon_doc(
    '<rect x="10" y="10" width="76" height="76" rx="14" fill="#f4d58a" stroke="#a8742c" stroke-width="8"/>'
    '<rect x="24" y="24" width="48" height="48" rx="8" fill="#4f7cac"/>'
    '<circle cx="48" cy="42" r="10" fill="#e0b088"/><path d="M30 72 Q48 52 66 72 Z" fill="#1f3a5f"/>')

# Ekspedisi: hutan, candi, pelabuhan, gunung.
ICONS["exp_hutan"] = icon_doc(
    '<circle cx="48" cy="48" r="42" fill="#cfe5a0"/>'
    '<path d="M28 88 L28 64 M66 88 L66 58" stroke="#5e3a12" stroke-width="6"/>'
    '<path d="M28 20 L46 52 L36 52 L50 72 L6 72 L20 52 L10 52 Z" fill="#2f6b30" stroke="#1a3a1a" stroke-width="2" stroke-linejoin="round"/>'
    '<path d="M66 12 L86 46 L76 46 L90 66 L42 66 L56 46 L46 46 Z" fill="#3a8a3a" stroke="#1a3a1a" stroke-width="2" stroke-linejoin="round"/>'
    '<path d="M40 90 L86 74" stroke="#7a5a32" stroke-width="4" stroke-linecap="round"/>'
    '<path d="M86 74 L80 70 L88 66 Z" fill="#c9d1da"/>')
ICONS["exp_candi"] = icon_doc(
    '<circle cx="48" cy="48" r="42" fill="#f4d7a0"/>'
    '<path d="M10 86 L86 86 L80 76 L16 76 Z" fill="#8a7a6a" stroke="#4a3a2a" stroke-width="2"/>'
    '<path d="M18 76 L78 76 L72 64 L24 64 Z" fill="#9a8a7a" stroke="#4a3a2a" stroke-width="2"/>'
    '<path d="M26 64 L70 64 L64 52 L32 52 Z" fill="#aa9a8a" stroke="#4a3a2a" stroke-width="2"/>'
    '<path d="M34 52 L62 52 Q62 34 48 30 Q34 34 34 52 Z" fill="#b8a898" stroke="#4a3a2a" stroke-width="2"/>'
    '<path d="M48 30 L48 12" stroke="#4a3a2a" stroke-width="4" stroke-linecap="round"/>'
    + "".join('<path d="M%d %d Q%d %d %d %d Q%d %d %d %d Z" fill="#b8a898" stroke="#4a3a2a" stroke-width="1.5"/>' % (
        x - 4, y, x - 4, y - 8, x, y - 10, x + 4, y - 8, x + 4, y) for x, y in [(22, 76), (36, 64), (60, 64), (74, 76)]))
ICONS["exp_pelabuhan"] = icon_doc(
    '<circle cx="48" cy="48" r="42" fill="#aed6f1"/>'
    '<path d="M6 70 Q24 64 48 70 Q72 76 90 70 L90 90 L6 90 Z" fill="#2e86c1"/>'
    '<path d="M18 66 L78 66 L70 78 L26 78 Z" fill="#8a5a3a" stroke="#4a2a12" stroke-width="2"/>'
    '<path d="M48 66 L48 14" stroke="#4a2a12" stroke-width="4"/>'
    '<path d="M50 16 L76 56 L50 56 Z" fill="#f4e4c1" stroke="#a8742c" stroke-width="2"/>'
    '<path d="M46 22 L24 56 L46 56 Z" fill="#e8c070" stroke="#a8742c" stroke-width="2"/>'
    '<path d="M48 14 L60 18 L48 22 Z" fill="#c0392b"/>')
ICONS["exp_gunung"] = icon_doc(
    '<circle cx="48" cy="48" r="42" fill="#f5cba7"/>'
    '<path d="M6 88 L36 34 L42 40 L48 30 L56 40 L60 34 L90 88 Z" fill="#6a5a8a" stroke="#3a2a4a" stroke-width="2" stroke-linejoin="round"/>'
    '<path d="M36 34 L42 40 L48 30 L56 40 L60 34 L54 50 L42 50 Z" fill="#4a3a5a"/>'
    '<path d="M48 30 Q40 16 46 6 Q50 18 56 12 Q58 22 48 30 Z" fill="#9a9aa0" opacity="0.8"/>'
    '<path d="M44 50 Q46 62 40 74 M52 50 Q52 64 58 76" stroke="#e67e22" stroke-width="3" fill="none"/>')

# Kuda tunggangan: kuda berdiri menghadap kanan, warna per jenis.
def horse(coat, mane, wings=False, saddle="#a8322d"):
    d = shade(coat, -0.25)
    b = '<circle cx="48" cy="48" r="44" fill="#f4e4c1"/>'
    if wings:
        b += ('<path d="M40 44 Q20 10 4 18 Q18 22 14 30 Q24 30 22 38 Q30 36 34 46 Z" fill="#fff6d8" '
              'stroke="#c9963f" stroke-width="2" stroke-linejoin="round"/>')
    # kaki
    for x, off in [(28, 0), (36, 2), (60, 0), (68, 2)]:
        b += '<path d="M%d 58 L%d 84" stroke="%s" stroke-width="6" stroke-linecap="round"/>' % (x, x + off, d)
        b += '<rect x="%d" y="82" width="8" height="5" rx="2" fill="#3b2416"/>' % (x + off - 4)
    # badan, leher, kepala
    b += '<ellipse cx="48" cy="54" rx="28" ry="14" fill="%s" stroke="%s" stroke-width="2"/>' % (coat, d)
    b += '<path d="M64 50 L76 22 L86 26 L78 54 Z" fill="%s" stroke="%s" stroke-width="2" stroke-linejoin="round"/>' % (coat, d)
    b += '<path d="M74 18 Q86 14 92 26 L90 32 Q84 30 80 30 Z" fill="%s" stroke="%s" stroke-width="2" stroke-linejoin="round"/>' % (coat, d)
    b += '<path d="M76 18 L76 10 L80 16 Z" fill="%s"/>' % coat
    b += '<circle cx="82" cy="22" r="1.8" fill="#1a0e08"/>'
    # surai & ekor
    b += '<path d="M76 16 Q66 26 64 46 Q70 36 74 30 Q70 40 70 48 Q76 34 80 24 Z" fill="%s"/>' % mane
    b += '<path d="M20 50 Q8 56 10 76 Q14 66 22 60 Z" fill="%s"/>' % mane
    # pelana
    b += '<path d="M38 42 Q48 38 58 42 L56 54 L40 54 Z" fill="%s" stroke="#5e1810" stroke-width="2"/>' % saddle
    b += '<path d="M48 54 L48 64" stroke="#3b2416" stroke-width="2"/><rect x="45" y="63" width="6" height="4" fill="%s"/>' % GOLD
    if wings:
        b += ('<path d="M44 44 Q30 4 12 8 Q26 14 22 22 Q34 22 32 30 Q40 28 42 40 Z" fill="#ffffff" '
              'stroke="#c9963f" stroke-width="2" stroke-linejoin="round"/>')
    return icon_doc(b)


HORSE_SPECS = {
    "kuda_jawa": ("#8a5a3a", "#2a1a10", False),
    "kuda_gayo": ("#5a3a2a", "#1a0e08", False),
    "kuda_sandel": ("#efe3c8", "#c9a77a", False),
    "kuda_bima": ("#2a2a30", "#101014", False),
    "kuda_sembrani": ("#ffffff", "#e8c070", True),
}
for _hid, (_coat, _mane, _wings) in HORSE_SPECS.items():
    ICONS["horse_" + _hid] = horse(_coat, _mane, _wings)
ICONS["stable"] = horse("#8a5a3a", "#2a1a10")

# Pusaka: keris berlekuk, lontar, dan kalung.
ICONS["eq_weapon"] = icon_doc(
    '<path d="M50 8 Q58 18 50 28 Q42 38 50 48 Q58 58 50 66 L46 66 Q38 58 46 48 Q54 38 46 28 Q38 18 46 8 Z" '
    'fill="#c9d1da" stroke="#4a5058" stroke-width="2.5" stroke-linejoin="round"/>'
    '<path d="M48 14 Q53 22 48 30 Q43 38 48 46" stroke="#ffffff" stroke-width="1.6" fill="none" opacity="0.8"/>'
    '<path d="M32 66 Q48 60 66 66 L62 74 L36 74 Z" fill="#c9963f" stroke="#6b4a12" stroke-width="2.5"/>'
    '<path d="M42 74 Q38 84 44 92 L54 92 Q60 84 56 74 Z" fill="#7a4a24" stroke="#3b2210" stroke-width="2.5"/>'
    '<circle cx="49" cy="70" r="3" fill="#c0392b"/>')
ICONS["eq_book"] = icon_doc(
    "".join('<rect x="12" y="%d" width="72" height="12" rx="5" fill="%s" stroke="#7a5a2a" stroke-width="2"/>'
            '<path d="M22 %d L72 %d" stroke="#8a6a3a" stroke-width="1.5" stroke-dasharray="5 3"/>'
            % (y, c, y + 6, y + 6) for y, c in [(20, "#e8cf96"), (36, "#f0d9a6"), (52, "#e8cf96"), (68, "#f0d9a6")])
    + '<path d="M48 14 L48 86" stroke="#a8322d" stroke-width="3"/>'
      '<circle cx="48" cy="12" r="5" fill="#c9963f" stroke="#6b4a12" stroke-width="2"/>')
ICONS["eq_charm"] = icon_doc(
    '<path d="M18 18 Q48 66 78 18" stroke="#c9963f" stroke-width="5" fill="none" stroke-linecap="round"/>'
    + "".join('<circle cx="%d" cy="%d" r="4" fill="#f4d58a" stroke="#8a6a12" stroke-width="1.5"/>' % (x, y)
              for x, y in [(26, 30), (34, 40), (62, 40), (70, 30)])
    + '<path d="M48 50 L62 66 L48 88 L34 66 Z" fill="#2e86c1" stroke="#0e3a5a" stroke-width="3" stroke-linejoin="round"/>'
      '<path d="M48 56 L56 66 L48 78" stroke="#ffffff" stroke-width="2" fill="none" opacity="0.7"/>')

ICONS["chest"] = chest(False)
ICONS["chest_open"] = chest(True)

ICONS["heart"] = icon_doc(
    '<path d="M48 86 Q10 60 12 34 Q14 14 32 14 Q44 14 48 28 Q52 14 64 14 Q82 14 84 34 Q86 60 48 86 Z" '
    'fill="#e0507a" stroke="#8e1f45" stroke-width="4"/>'
    '<path d="M24 34 Q24 24 34 22" stroke="#fff" stroke-width="5" fill="none" stroke-linecap="round" opacity="0.7"/>')

ICONS["star"] = icon_doc(
    '<path d="M48 6 L59 34 L90 36 L66 56 L74 88 L48 70 L22 88 L30 56 L6 36 L37 34 Z" '
    'fill="#f4c542" stroke="#a8742c" stroke-width="4" stroke-linejoin="round"/>')

ICONS["lock"] = icon_doc(
    '<path d="M30 44 L30 30 Q30 12 48 12 Q66 12 66 30 L66 44" stroke="#c9d1da" stroke-width="8" fill="none"/>'
    '<rect x="20" y="42" width="56" height="44" rx="8" fill="#e8c070" stroke="#7a4b1f" stroke-width="4"/>'
    '<circle cx="48" cy="60" r="6" fill="#4a2c10"/><rect x="45" y="62" width="6" height="14" fill="#4a2c10"/>')

ICONS["tab_city"] = icon_doc(
    '<path d="M10 88 L10 40 L26 26 L28 88 Z" fill="#c0563a" stroke="#5e1f10" stroke-width="3"/>'
    '<path d="M86 88 L86 40 L70 26 L68 88 Z" fill="#c0563a" stroke="#5e1f10" stroke-width="3"/>'
    '<path d="M14 40 L24 30 M14 56 L26 46 M14 72 L26 62 M82 40 L72 30 M82 56 L70 46 M82 72 L70 62" stroke="#5e1f10" stroke-width="2.5"/>'
    '<path d="M48 10 L34 40 L62 40 Z" fill="#e8c070" stroke="#7a4b1f" stroke-width="3"/>'
    '<rect x="36" y="40" width="24" height="48" fill="#a8742c" stroke="#5e3a12" stroke-width="3"/>'
    '<path d="M42 88 L42 64 Q48 56 54 64 L54 88 Z" fill="#3b2416"/>')

ICONS["tab_counselor"] = icon_doc(
    '<circle cx="48" cy="32" r="18" fill="#e8c070" stroke="#7a4b1f" stroke-width="3"/>'
    '<path d="M14 90 Q16 58 48 56 Q80 58 82 90 Z" fill="#e8c070" stroke="#7a4b1f" stroke-width="3"/>'
    '<path d="M30 20 Q48 0 66 20 Q48 12 30 20 Z" fill="#7a4b1f"/>'
    '<path d="M40 60 L48 78 L56 60" stroke="#7a4b1f" stroke-width="3" fill="none"/>')

ICONS["tab_campaign"] = icon_doc(
    '<path d="M18 88 L18 8" stroke="#7a4b1f" stroke-width="5"/>'
    '<path d="M20 10 Q46 2 54 14 Q62 26 84 18 L84 50 Q62 58 54 46 Q46 34 20 42 Z" fill="#c0392b" stroke="#6b1a12" stroke-width="3"/>'
    '<circle cx="50" cy="30" r="8" fill="#e8c070"/>'
    '<path d="M40 88 L84 60 M84 88 L40 60" stroke="#d6dde6" stroke-width="6" stroke-linecap="round"/>'
    '<path d="M44 82 L50 88 M80 82 L74 88" stroke="#7a4b1f" stroke-width="6" stroke-linecap="round"/>')

ICONS["tab_palace"] = icon_doc(
    '<path d="M4 44 Q48 6 92 44 L80 44 Q48 20 16 44 Z" fill="#c0392b" stroke="#6b1a12" stroke-width="3"/>'
    '<path d="M16 44 L80 44 L74 34 L22 34 Z" fill="#e8c070"/>'
    '<path d="M48 4 L48 16" stroke="#e8c070" stroke-width="4"/><circle cx="48" cy="4" r="4" fill="#e8c070"/>'
    '<rect x="20" y="44" width="8" height="40" fill="#a8742c"/><rect x="68" y="44" width="8" height="40" fill="#a8742c"/>'
    '<rect x="40" y="56" width="16" height="28" rx="8" fill="#3b2416"/>'
    '<rect x="10" y="84" width="76" height="8" fill="#e8c070" stroke="#7a4b1f" stroke-width="2"/>')


# --- Latar ----------------------------------------------------------------

def mountains(w, base, layers):
    out = ""
    for i, (color, height, seed) in enumerate(layers):
        pts = ["0,%d" % base]
        n = 9
        for k in range(n + 1):
            x = w * k / n
            y = base - height * (0.55 + 0.45 * math.sin(k * 1.7 + seed) * math.cos(k * 0.6 + seed * 2))
            pts.append("%.0f,%.0f" % (x, y))
        pts.append("%d,%d" % (w, base))
        out += '<polygon points="%s" fill="%s"/>' % (" ".join(pts), color)
    return out


def volcano(cx, base, w, h, color, cap):
    return ('<path d="M%d %d L%d %d Q%d %d %d %d L%d %d Z" fill="%s"/>'
            '<path d="M%d %d Q%d %d %d %d L%d %d Q%d %d %d %d Z" fill="%s" opacity="0.8"/>'
            % (cx - w, base, cx - 18, base - h, cx, base - h - 8, cx + 18, base - h, cx + w, base, color,
               cx - 30, base - h + 30, cx - 22, base - h + 6, cx - 16, base - h, cx + 16, base - h,
               cx + 24, base - h + 10, cx + 30, base - h + 30, cap))


def joglo(x, y, s, roof, wall):
    """Rumah tradisional beratap joglo bertingkat."""
    return (
        '<g transform="translate(%d %d) scale(%.2f)">'
        '<rect x="-34" y="0" width="68" height="34" fill="%s"/>'
        '<rect x="-8" y="12" width="16" height="22" fill="#3b2416"/>'
        '<path d="M-52 2 L-22 -22 L22 -22 L52 2 Z" fill="%s"/>'
        '<path d="M-24 -20 L-10 -46 L10 -46 L24 -20 Z" fill="%s"/>'
        "</g>" % (x, y, s, wall, roof, shade(roof, 0.15)))


def candi_bentar(cx, base, h, color):
    """Gerbang terbelah khas Jawa-Bali."""
    half = (
        '<path d="M{a} {b} L{a} {c} L{d} {e} L{f} {g} L{f2} {h2} L{i} {j} L{i} {b} Z" fill="{col}"/>'
    ).format(a=cx - 70, b=base, c=base - h * 0.45, d=cx - 62, e=base - h * 0.55, f=cx - 54, g=base - h * 0.78,
             f2=cx - 40, h2=base - h, i=cx - 18, j=base - h * 0.5, col=color)
    lines = "".join('<path d="M%d %d L%d %d" stroke="%s" stroke-width="3"/>'
                    % (cx - 70, base - k, cx - 18, base - k, shade(color, -0.25))
                    for k in range(20, int(h * 0.45), 22))
    g = half + lines
    return g + '<g transform="translate(%d 0) scale(-1 1)">%s</g>' % (2 * cx, g)


def tree(x, y, s, color):
    return ('<g transform="translate(%d %d) scale(%.2f)"><rect x="-4" y="-10" width="8" height="30" fill="#4a2c10"/>'
            '<circle cx="0" cy="-26" r="22" fill="%s"/><circle cx="-16" cy="-12" r="16" fill="%s"/>'
            '<circle cx="16" cy="-12" r="16" fill="%s"/></g>'
            % (x, y, s, color, shade(color, -0.1), shade(color, 0.08)))


def bg_city():
    W, H = 720, 360
    defs = ('<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="#3a5a8c"/><stop offset="0.55" stop-color="#e9a15a"/>'
            '<stop offset="1" stop-color="#f6d08a"/></linearGradient>')
    b = '<rect width="%d" height="%d" fill="url(#sky)"/>' % (W, H)
    b += '<circle cx="560" cy="150" r="46" fill="#fff1c4" opacity="0.9"/>'
    b += volcano(200, 250, 210, 150, "#6a5a8a", "#e9e4f2")
    b += mountains(W, 270, [("#7b5f7e", 90, 1.0), ("#5c4a64", 60, 2.4)])
    b += '<rect x="0" y="262" width="%d" height="%d" fill="#3f5a2c"/>' % (W, H)
    for x, s in [(70, 0.9), (150, 0.7), (580, 0.85), (660, 0.7)]:
        b += joglo(x, 262, s, "#6b2e1e", "#d9b98a")
    b += tree(30, 300, 1.2, "#2f5a2a") + tree(700, 300, 1.1, "#2f5a2a")
    b += tree(250, 284, 0.8, "#3a6a30") + tree(470, 284, 0.8, "#3a6a30")
    b += candi_bentar(360, 330, 210, "#b2553a")
    b += '<path d="M300 360 L340 330 L380 330 L420 360 Z" fill="#c9a77a"/>'
    b += '<rect y="330" width="%d" height="30" fill="#2e4421" opacity="0.6"/>' % W
    return svg_doc(W, H, b, 1080, 540, defs)


def bg_counselor():
    W, H = 720, 360
    defs = ('<linearGradient id="wall" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="#3b2416"/><stop offset="1" stop-color="#6b4226"/></linearGradient>')
    b = '<rect width="%d" height="%d" fill="url(#wall)"/>' % (W, H)
    # Pendopo: atap & tiang
    b += '<path d="M0 0 L720 0 L720 70 Q360 20 0 70 Z" fill="#7a2e22"/>'
    b += '<path d="M0 70 Q360 20 720 70 L720 84 Q360 34 0 84 Z" fill="%s"/>' % GOLD
    for x in range(40, 720, 160):
        b += '<rect x="%d" y="80" width="26" height="250" fill="#8e3b26"/>' % x
        b += '<rect x="%d" y="80" width="26" height="14" fill="%s"/><rect x="%d" y="316" width="26" height="14" fill="%s"/>' % (
            x, GOLD, x, GOLD)
    # Gulungan & rak
    for i, x in enumerate(range(110, 640, 160)):
        b += '<rect x="%d" y="140" width="90" height="120" fill="#4a2c18" stroke="%s" stroke-width="3"/>' % (x, GOLD_DARK)
        for r in range(3):
            for c in range(3):
                b += '<rect x="%d" y="%d" width="22" height="30" rx="4" fill="%s"/>' % (
                    x + 8 + c * 28, 148 + r * 38, ["#e9d6b0", "#c9963f", "#d8c49a"][(r + c + i) % 3])
    b += '<rect y="330" width="%d" height="30" fill="#2a170c"/>' % W
    b += "".join('<rect x="%d" y="330" width="60" height="30" fill="%s"/>' % (x, "#3b2416" if (x // 60) % 2 else "#2a170c")
                 for x in range(0, W, 60))
    return svg_doc(W, H, b, 1080, 540, defs)


def bg_campaign():
    W, H = 720, 360
    defs = ('<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="#2a1426"/><stop offset="0.6" stop-color="#b8442e"/>'
            '<stop offset="1" stop-color="#e88a4a"/></linearGradient>')
    b = '<rect width="%d" height="%d" fill="url(#sky)"/>' % (W, H)
    b += mountains(W, 250, [("#5a2a2e", 100, 0.4), ("#3e1d22", 70, 3.1)])
    # Benteng musuh
    b += '<rect x="420" y="150" width="260" height="110" fill="#4a3a36"/>'
    for x in range(420, 680, 26):
        b += '<rect x="%d" y="136" width="16" height="16" fill="#4a3a36"/>' % x
    b += '<rect x="520" y="110" width="60" height="150" fill="#3a2c2a"/>'
    b += '<path d="M512 112 L550 70 L588 112 Z" fill="#2a1e1c"/>'
    b += '<path d="M534 260 L534 214 Q550 196 566 214 L566 260 Z" fill="#1a1210"/>'
    b += '<path d="M550 70 L550 30" stroke="#2a1e1c" stroke-width="4"/><path d="M552 32 L590 42 L552 52 Z" fill="#2a2a2a"/>'
    b += '<rect y="250" width="%d" height="%d" fill="#4a3220"/>' % (W, H)
    # Tenda & panji pasukan sendiri
    for x in (60, 170, 280):
        b += '<path d="M%d 300 L%d 240 L%d 300 Z" fill="#d9c49a" stroke="#7a5a32" stroke-width="3"/>' % (x - 40, x, x + 40)
        b += '<path d="M%d 300 L%d 262 L%d 300 Z" fill="#7a5a32"/>' % (x - 10, x, x + 10)
    for x in (110, 230, 350):
        b += '<path d="M%d 330 L%d 200" stroke="#5e3a12" stroke-width="5"/>' % (x, x)
        b += '<path d="M%d 204 Q%d 196 %d 210 L%d 250 Q%d 238 %d 246 Z" fill="#c0392b"/>' % (
            x + 2, x + 30, x + 50, x + 50, x + 30, x + 2)
        b += '<circle cx="%d" cy="226" r="7" fill="%s"/>' % (x + 26, GOLD)
    b += '<rect y="320" width="%d" height="40" fill="#2e1f14"/>' % W
    return svg_doc(W, H, b, 1080, 540, defs)


def bg_palace():
    W, H = 720, 360
    defs = ('<linearGradient id="wall" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="#5a1a2a"/><stop offset="1" stop-color="#9a3a3a"/></linearGradient>'
            '<radialGradient id="glow" cx="50%" cy="50%" r="50%">'
            '<stop offset="0" stop-color="#ffd88a" stop-opacity="0.9"/>'
            '<stop offset="1" stop-color="#ffd88a" stop-opacity="0"/></radialGradient>')
    b = '<rect width="%d" height="%d" fill="url(#wall)"/>' % (W, H)
    # Jendela melengkung dengan bulan
    b += '<path d="M290 300 L290 150 Q360 70 430 150 L430 300 Z" fill="#1f2a4a" stroke="%s" stroke-width="8"/>' % GOLD
    b += '<circle cx="384" cy="160" r="26" fill="#fff4d0"/>'
    b += '<path d="M360 300 L360 120 M290 210 L430 210" stroke="%s" stroke-width="5"/>' % GOLD
    # Tirai
    for side in (0, 1):
        cur = ('<path d="M0 0 L170 0 Q150 120 180 340 L0 340 Z" fill="#a8243a"/>'
               '<path d="M30 0 Q40 160 20 340 M80 0 Q96 160 70 340 M130 0 Q140 160 130 340" stroke="#7a1428" '
               'stroke-width="6" fill="none"/>'
               '<path d="M0 150 Q90 190 176 160" stroke="%s" stroke-width="10" fill="none"/>' % GOLD)
        b += cur if side == 0 else '<g transform="translate(720 0) scale(-1 1)">%s</g>' % cur
    b += '<path d="M0 0 L720 0 L720 40 Q360 70 0 40 Z" fill="#7a1428"/>'
    b += "".join('<path d="M%d 40 Q%d 62 %d 40" fill="%s"/>' % (x, x + 20, x + 40, GOLD) for x in range(0, 720, 40))
    # Lentera
    for x in (220, 500):
        b += '<path d="M%d 40 L%d 110" stroke="%s" stroke-width="3"/>' % (x, x, GOLD)
        b += '<circle cx="%d" cy="140" r="60" fill="url(#glow)"/>' % x
        b += '<ellipse cx="%d" cy="140" rx="22" ry="30" fill="#e74c3c" stroke="%s" stroke-width="3"/>' % (x, GOLD)
        b += '<rect x="%d" y="106" width="20" height="8" fill="%s"/><rect x="%d" y="166" width="20" height="8" fill="%s"/>' % (
            x - 10, GOLD, x - 10, GOLD)
    # Lantai
    b += '<rect y="300" width="%d" height="60" fill="#3a1a14"/>' % W
    b += "".join('<path d="M%d 300 L%d 360" stroke="#5a2a20" stroke-width="3"/>' % (x, x * 1.6 - 216)
                 for x in range(0, 760, 60))
    return svg_doc(W, H, b, 1080, 540, defs)


def bg_gacha():
    """Ruang pemanggilan: candi bercahaya dengan sinar dan kelopak melayang."""
    W, H = 720, 360
    defs = ('<radialGradient id="glow" cx="50%" cy="62%" r="65%">'
            '<stop offset="0" stop-color="#ffe7a0"/><stop offset="0.35" stop-color="#c46a3a"/>'
            '<stop offset="1" stop-color="#2a0f2e"/></radialGradient>')
    b = '<rect width="%d" height="%d" fill="url(#glow)"/>' % (W, H)
    for i in range(18):
        a0 = math.radians(i * 20 - 90)
        a1 = math.radians(i * 20 - 82)
        b += '<path d="M360 220 L%.0f %.0f L%.0f %.0f Z" fill="#fff6d0" opacity="0.10"/>' % (
            360 + 700 * math.cos(a0), 220 + 700 * math.sin(a0), 360 + 700 * math.cos(a1), 220 + 700 * math.sin(a1))
    # Candi bertingkat di tengah
    tiers = [(250, 300, 470, 300), (270, 260, 450, 260), (295, 222, 425, 222), (320, 188, 400, 188), (342, 158, 378, 158)]
    for i, (x0, y, x1, _) in enumerate(tiers):
        b += '<rect x="%d" y="%d" width="%d" height="%d" fill="%s" stroke="#3a1a10" stroke-width="2"/>' % (
            x0, y - 34 if i else y - 40, x1 - x0, 40 if i == 0 else 34, shade("#6b3a2a", -0.08 * i))
    b += '<path d="M352 124 L360 90 L368 124 Z" fill="#e8c070"/>'
    b += '<path d="M338 300 L338 268 Q360 246 382 268 L382 300 Z" fill="#fff1b8"/>'
    b += '<circle cx="360" cy="276" r="40" fill="#fff6d0" opacity="0.35"/>'
    b += '<rect y="300" width="%d" height="60" fill="#2a1410"/>' % W
    b += '<path d="M200 300 L260 360 L460 360 L520 300 Z" fill="#4a2418"/>'
    # Lampu minyak & kelopak
    for x in (120, 600):
        b += '<path d="M%d 300 L%d 240" stroke="#a8742c" stroke-width="5"/>' % (x, x)
        b += '<circle cx="%d" cy="232" r="26" fill="#ffd27a" opacity="0.35"/>' % x
        b += '<path d="M%d 240 Q%d 220 %d 240 Z" fill="#e8c070"/>' % (x - 14, x, x + 14)
        b += '<path d="M%d 232 Q%d 214 %d 232 Q%d 238 %d 232 Z" fill="#fff1b8"/>' % (x - 5, x, x + 5, x, x - 5)
    for i, (x, y) in enumerate([(90, 80), (180, 140), (540, 70), (640, 150), (250, 50), (470, 120), (60, 200), (680, 230)]):
        b += '<ellipse cx="%d" cy="%d" rx="7" ry="4" fill="%s" opacity="0.8" transform="rotate(%d %d %d)"/>' % (
            x, y, ["#ffd1e0", "#fff6d0", "#f5b041"][i % 3], i * 40, x, y)
    return svg_doc(W, H, b, 1080, 540, defs)


def bg_alliance():
    """Balairung aliansi: panji-panji tergantung dan meja bundar."""
    W, H = 720, 360
    defs = ('<linearGradient id="wall" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="#2a1d2e"/><stop offset="1" stop-color="#5a3a2a"/></linearGradient>')
    b = '<rect width="%d" height="%d" fill="url(#wall)"/>' % (W, H)
    b += '<path d="M0 0 L720 0 L720 54 Q360 10 0 54 Z" fill="#4a2418"/>'
    b += '<path d="M0 54 Q360 10 720 54 L720 66 Q360 22 0 66 Z" fill="%s"/>' % GOLD
    for i, (x, c) in enumerate([(110, "#a8241e"), (260, "#1f6f5a"), (460, "#2c3e50"), (610, "#c79a1e")]):
        b += '<path d="M%d 70 L%d 70 L%d 220 L%d 196 L%d 220 Z" fill="%s" stroke="%s" stroke-width="3"/>' % (
            x - 40, x + 40, x + 40, x, x - 40, c, GOLD)
        b += '<circle cx="%d" cy="130" r="20" fill="none" stroke="%s" stroke-width="4"/>' % (x, GOLD)
        b += '<path d="M%d 118 L%d 142 M%d 130 L%d 130" stroke="%s" stroke-width="4"/>' % (x, x, x - 12, x + 12, GOLD)
    for x in (30, 190, 360, 530, 690):
        b += '<rect x="%d" y="66" width="18" height="250" fill="#6b2e1e"/>' % (x - 9)
    b += '<ellipse cx="360" cy="300" rx="220" ry="40" fill="#7a4b2a" stroke="%s" stroke-width="5"/>' % GOLD
    b += '<ellipse cx="360" cy="292" rx="200" ry="30" fill="#8e5a34"/>'
    for i in range(7):
        a = math.radians(200 + i * 23)
        x, y = 360 + 230 * math.cos(a), 318 + 46 * math.sin(a)
        b += '<rect x="%.0f" y="%.0f" width="26" height="40" rx="6" fill="#3a2418"/>' % (x - 13, y - 40)
    b += '<rect y="330" width="%d" height="30" fill="#2a170c"/>' % W
    return svg_doc(W, H, b, 1080, 540, defs)


def bg_arena():
    """Alun-alun arena: gelanggang pasir, tribun penonton, dan umbul-umbul."""
    W, H = 720, 360
    defs = ('<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="#4a7fb8"/><stop offset="1" stop-color="#f4d7a0"/></linearGradient>')
    b = '<rect width="%d" height="%d" fill="url(#sky)"/>' % (W, H)
    # Tribun bertingkat
    for k, (y, c) in enumerate([(120, "#7a4b2a"), (160, "#8e5a34"), (200, "#a06a3c")]):
        b += '<rect x="0" y="%d" width="%d" height="44" fill="%s"/>' % (y, W, c)
        for x in range(8, W, 18):
            hue = ["#c0392b", "#2e86c1", "#27ae60", "#f1c40f", "#8e44ad", "#e67e22"][(x // 18 + k * 2) % 6]
            b += '<circle cx="%d" cy="%d" r="7" fill="%s"/><circle cx="%d" cy="%d" r="5" fill="#e0b48a"/>' % (
                x, y + 26, hue, x, y + 14)
    # Atap tribun dan umbul-umbul
    b += '<path d="M0 120 L720 120 L720 100 L0 100 Z" fill="#6b2e1e"/>'
    for x in range(30, 720, 90):
        b += '<path d="M%d 100 L%d 20" stroke="#5e3a12" stroke-width="4"/>' % (x, x)
        b += '<path d="M%d 22 Q%d 30 %d 22 L%d 70 Q%d 62 %d 70 Z" fill="%s"/>' % (
            x + 2, x + 14, x + 26, x + 26, x + 14, x + 2, ["#c0392b", "#f1c40f", "#2e86c1"][(x // 90) % 3])
    # Gelanggang
    b += '<ellipse cx="360" cy="330" rx="420" ry="100" fill="#d9b77a" stroke="%s" stroke-width="6"/>' % GOLD
    b += '<ellipse cx="360" cy="330" rx="260" ry="56" fill="none" stroke="#b8955a" stroke-width="4"/>'
    b += '<path d="M330 330 L390 330 M360 310 L360 350" stroke="#b8955a" stroke-width="4"/>'
    return svg_doc(W, H, b, 1080, 540, defs)


# --- Bangunan kota (160x120, alas di y=112) -------------------------------

def bld_doc(body):
    return svg_doc(160, 120, body, 240, 180)


def _ground(w=140):
    return '<ellipse cx="80" cy="113" rx="%d" ry="6" fill="#000" opacity="0.25"/>' % (w // 2)


def _roof(cx, y, w, h, color, tiers=1):
    """Atap joglo/meru bertingkat: tiap tingkat makin kecil ke atas."""
    out = ""
    for t in range(tiers):
        ww = w * (1 - 0.28 * t)
        top = y - h * t * 0.8
        out += '<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="%s" stroke="%s" stroke-width="1.5"/>' % (
            cx - ww / 2, top, cx - ww / 4, top - h, cx + ww / 4, top - h, cx + ww / 2, top,
            shade(color, 0.08 * t), shade(color, -0.35))
    return out


def _flag(x, y, color):
    return ('<path d="M%d %d L%d %d" stroke="#5e3a12" stroke-width="2"/>'
            '<path d="M%d %d L%d %d L%d %d Z" fill="%s"/>' % (x, y, x, y - 26, x, y - 26, x + 14, y - 21, x, y - 16, color))


def bld_plot():
    """Tanah kosong berpatok dan bertali, siap dibangun."""
    b = _ground(120)
    b += '<path d="M28 112 L80 98 L132 112 L80 118 Z" fill="#a07850" stroke="#6b4a2a" stroke-width="2"/>'
    for x, y in [(28, 112), (80, 98), (132, 112), (80, 118)]:
        b += '<path d="M%d %d L%d %d" stroke="#5e3a12" stroke-width="3"/>' % (x, y, x, y - 14)
    b += '<path d="M28 98 L80 84 L132 98 L80 104 Z" fill="none" stroke="#e8c070" stroke-width="1.5" stroke-dasharray="4 3"/>'
    b += '<rect x="96" y="100" width="22" height="8" fill="#8a6a3a"/><rect x="100" y="94" width="22" height="8" fill="#a07850"/>'
    return bld_doc(b)


def bld_istana(tier):
    b = _ground()
    if tier == 1:
        b += '<rect x="50" y="88" width="60" height="24" fill="#d9b98a" stroke="#6b4a2a" stroke-width="2"/>'
        b += '<rect x="74" y="96" width="12" height="16" fill="#3b2416"/>'
        b += _roof(80, 90, 92, 18, "#7a2e22", 2)
    elif tier == 2:
        b += '<rect x="20" y="96" width="120" height="16" fill="#c9a77a" stroke="#6b4a2a" stroke-width="2"/>'
        b += '<rect x="40" y="80" width="80" height="22" fill="#e6c99a" stroke="#6b4a2a" stroke-width="2"/>'
        for x in range(46, 120, 14):
            b += '<rect x="%d" y="82" width="4" height="20" fill="%s"/>' % (x, GOLD_DARK)
        b += '<rect x="72" y="88" width="16" height="14" fill="#3b2416"/>'
        b += _roof(80, 82, 112, 18, "#7a2e22", 3)
        b += _roof(28, 98, 30, 10, "#8e3b26") + _roof(132, 98, 30, 10, "#8e3b26")
    else:
        b += '<rect x="8" y="100" width="144" height="12" fill="#b2553a" stroke="#5e2416" stroke-width="2"/>'
        b += '<rect x="14" y="94" width="132" height="8" fill="%s"/>' % GOLD
        b += '<rect x="34" y="72" width="92" height="24" fill="#f0d7a6" stroke="#6b4a2a" stroke-width="2"/>'
        for x in range(40, 126, 12):
            b += '<rect x="%d" y="74" width="4" height="22" fill="%s"/>' % (x, GOLD)
        b += '<path d="M70 96 L70 82 Q80 74 90 82 L90 96 Z" fill="#3b2416" stroke="%s" stroke-width="2"/>' % GOLD
        b += _roof(80, 74, 124, 18, "#6b1a12", 4)
        b += '<circle cx="80" cy="16" r="4" fill="%s"/>' % GOLD
        b += _roof(22, 96, 34, 14, "#7a2e22", 2) + _roof(138, 96, 34, 14, "#7a2e22", 2)
        b += _flag(10, 100, "#c0392b") + _flag(150, 100, "#c0392b")
    return bld_doc(b)


def bld_pasar(tier):
    b = _ground()
    stalls = {1: [(80, "#c0392b")], 2: [(44, "#c0392b"), (80, "#2e86c1"), (116, "#27ae60")],
              3: []}[tier]
    for cx, c in stalls:
        b += '<rect x="%d" y="92" width="32" height="20" fill="#d9b98a" stroke="#6b4a2a" stroke-width="1.5"/>' % (cx - 16)
        b += '<rect x="%d" y="88" width="32" height="6" fill="#8a6a3a"/>' % (cx - 16)
        b += "".join('<circle cx="%d" cy="88" r="3" fill="%s"/>' % (cx - 10 + i * 7, f)
                     for i, f in enumerate(["#e67e22", "#f1c40f", "#27ae60", "#c0392b"]))
        b += '<path d="M%d 82 L%d 82 L%d 72 L%d 72 Z" fill="%s"/>' % (cx - 22, cx + 22, cx + 18, cx - 18, c)
        b += "".join('<path d="M%d 82 L%d 88 L%d 82 Z" fill="%s"/>' % (cx - 22 + i * 11, cx - 16 + i * 11, cx - 11 + i * 11,
                                                                       shade(c, -0.2)) for i in range(4))
        b += '<path d="M%d 82 L%d 112 M%d 82 L%d 112" stroke="#5e3a12" stroke-width="2"/>' % (cx - 20, cx - 20, cx + 20, cx + 20)
    if tier == 3:
        b += '<rect x="14" y="78" width="132" height="34" fill="#e6c99a" stroke="#6b4a2a" stroke-width="2"/>'
        for i, x in enumerate(range(20, 146, 21)):
            b += '<rect x="%d" y="88" width="15" height="24" fill="%s"/>' % (x, ["#c0392b", "#2e86c1", "#27ae60", "#f1c40f",
                                                                               "#8e44ad", "#e67e22"][i % 6])
            b += '<rect x="%d" y="96" width="15" height="4" fill="#d9b98a"/>' % x
        b += _roof(80, 80, 150, 22, "#7a4a24", 2)
        b += '<rect x="60" y="40" width="40" height="12" rx="3" fill="%s" stroke="#6b4a12" stroke-width="1.5"/>' % GOLD
        b += _flag(14, 80, "#f1c40f") + _flag(146, 80, "#2e86c1")
    return bld_doc(b)


def _barn(cx, s=1.0):
    return ('<g transform="translate(%d 0) scale(%.2f 1)">'
            '<path d="M-14 112 L-14 92 M14 112 L14 92" stroke="#5e3a12" stroke-width="3"/>'
            '<rect x="-16" y="90" width="32" height="4" fill="#5e3a12"/>'
            '<rect x="-14" y="72" width="28" height="18" fill="#c9a77a" stroke="#6b4a2a" stroke-width="1.5"/>'
            '<path d="M-24 76 Q-22 40 0 30 Q22 40 24 76 Z" fill="#d4a94a" stroke="#8a6a12" stroke-width="2"/>'
            '<path d="M-18 64 Q0 58 18 64 M-14 52 Q0 46 14 52" stroke="#8a6a12" stroke-width="1.5" fill="none"/>'
            '</g>' % (cx, s))


def bld_lumbung(tier):
    b = _ground()
    if tier == 1:
        b += _barn(80)
    elif tier == 2:
        b += _barn(52) + _barn(108)
        b += '<path d="M70 112 L90 112 L88 100 L72 100 Z" fill="#e8d4a0" stroke="#8a6a3a" stroke-width="1.5"/>'
    else:
        b += _barn(30, 0.9) + _barn(130, 0.9) + _barn(80, 1.3)
        for x in (52, 64, 96, 108):
            b += '<path d="M%d 112 L%d 112 L%d 102 L%d 102 Z" fill="#e8d4a0" stroke="#8a6a3a" stroke-width="1.5"/>' % (
                x - 6, x + 6, x + 5, x - 5)
        b += _flag(80, 30, "#27ae60")
    return bld_doc(b)


def bld_barak(tier):
    b = _ground()
    if tier == 1:
        b += '<path d="M50 112 L80 72 L110 112 Z" fill="#c9a77a" stroke="#6b4a2a" stroke-width="2"/>'
        b += '<path d="M74 112 L80 92 L86 112 Z" fill="#3b2416"/>'
        b += _flag(80, 74, "#c0392b")
        b += '<path d="M116 112 L124 82 M122 112 L114 84" stroke="#7a5a32" stroke-width="2"/>'
    elif tier == 2:
        for x in range(14, 148, 8):
            b += '<path d="M%d 112 L%d 96 L%d 92 L%d 96 L%d 112" fill="#8a5a3a" stroke="#5e3a12" stroke-width="1"/>' % (
                x, x, x + 3, x + 6, x + 6)
        b += '<rect x="40" y="76" width="80" height="26" fill="#a86a42" stroke="#5e3a12" stroke-width="2"/>'
        b += '<rect x="74" y="86" width="12" height="16" fill="#3b2416"/>'
        b += _roof(80, 78, 96, 14, "#5e3a12")
        b += _flag(124, 92, "#c0392b")
    else:
        b += '<rect x="10" y="78" width="140" height="34" fill="#8a7a6a" stroke="#4a3a2a" stroke-width="2"/>'
        for x in range(10, 150, 14):
            b += '<rect x="%d" y="70" width="8" height="10" fill="#8a7a6a" stroke="#4a3a2a" stroke-width="1.5"/>' % x
        b += '<rect x="62" y="40" width="36" height="72" fill="#9a8a7a" stroke="#4a3a2a" stroke-width="2"/>'
        for x in range(62, 98, 9):
            b += '<rect x="%d" y="32" width="6" height="10" fill="#9a8a7a" stroke="#4a3a2a" stroke-width="1.5"/>' % x
        b += '<path d="M70 112 L70 92 Q80 82 90 92 L90 112 Z" fill="#3b2416"/>'
        b += '<rect x="76" y="56" width="8" height="12" fill="#3b2416"/>'
        b += _flag(80, 34, "#c0392b") + _flag(20, 72, "#f1c40f") + _flag(140, 72, "#f1c40f")
    return bld_doc(b)


def scaffold():
    """Perancah bambu untuk bangunan yang sedang dibangun."""
    b = ""
    for x in (30, 60, 100, 130):
        b += '<path d="M%d 112 L%d 40" stroke="#b8955a" stroke-width="4"/>' % (x, x)
    for y in (60, 84, 106):
        b += '<path d="M24 %d L136 %d" stroke="#b8955a" stroke-width="4"/>' % (y, y)
    b += '<path d="M30 106 L60 60 M100 106 L130 60" stroke="#8a6a3a" stroke-width="3"/>'
    for x, y in [(30, 60), (60, 84), (100, 60), (130, 84)]:
        b += '<circle cx="%d" cy="%d" r="3" fill="#5e3a12"/>' % (x, y)
    return bld_doc(b)


def pattern_kawung():
    """Tile motif batik kawung untuk latar aplikasi."""
    s = 96
    c = "#3a2618"
    b = '<rect width="%d" height="%d" fill="#24170f"/>' % (s, s)
    for cx, cy in [(0, 0), (s, 0), (0, s), (s, s), (s / 2, s / 2)]:
        for dx, dy, rot in [(0, -16, 0), (0, 16, 0), (-16, 0, 90), (16, 0, 90)]:
            b += '<ellipse cx="%.0f" cy="%.0f" rx="9" ry="15" fill="%s" transform="rotate(%d %.0f %.0f)"/>' % (
                cx + dx, cy + dy, c, rot, cx + dx, cy + dy)
        b += '<circle cx="%.0f" cy="%.0f" r="3" fill="#4a3220"/>' % (cx, cy)
    return svg_doc(s, s, b, s, s)


def main():
    for cid, spec in CHARACTERS.items():
        write("portraits/%s.svg" % cid, portrait(spec))
    for name, doc in ICONS.items():
        write("icons/%s.svg" % name, doc)
    write("bg/city.svg", bg_city())
    write("bg/counselor.svg", bg_counselor())
    write("bg/campaign.svg", bg_campaign())
    write("bg/palace.svg", bg_palace())
    write("bg/gacha.svg", bg_gacha())
    write("bg/alliance.svg", bg_alliance())
    write("bg/arena.svg", bg_arena())
    write("bg/kawung.svg", pattern_kawung())
    write("buildings/plot.svg", bld_plot())
    write("buildings/scaffold.svg", scaffold())
    for name, fn in [("istana", bld_istana), ("pasar", bld_pasar), ("lumbung", bld_lumbung), ("barak", bld_barak)]:
        for tier in (1, 2, 3):
            write("buildings/%s_%d.svg" % (name, tier), fn(tier))
        write("icons/bld_%s.svg" % name, fn(2))
    print("Aset ditulis ke", os.path.normpath(ROOT))


if __name__ == "__main__":
    main()
