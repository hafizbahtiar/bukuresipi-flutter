"""Achievement badges: 6 categories x 5 tiers as SVG (design/badges/svg) and PNG (assets/badges, via macOS QuickLook).

Run from the app root: python3 design/badges/build.py
Design: bukuresipi-hono docs/superpowers/specs/2026-11-09-achievements-design.md
"""
import math, os, subprocess, shutil, tempfile

TIERS = {  # highlight, body, shadow, deep
    'bronze':   ('#F6C9A0', '#C98549', '#8A4F24', '#5A3115'),
    'silver':   ('#FFFFFF', '#C9D0D9', '#8A939F', '#565E69'),
    'gold':     ('#FFF1B8', '#F0C23B', '#B5830F', '#7A5507'),
    'platinum': ('#F4FFFE', '#BFE3E0', '#76A9A5', '#3E6B68'),
    'diamond':  ('#F1F8FF', '#9FD0FF', '#4F8FDB', '#244E8F'),
}
CATEGORIES = {  # ribbon colour, emblem
    'explorer':  '#2E7D5B',
    'traveller': '#2F6DB5',
    'regular':   '#C9822B',
    'cook':      '#B5483B',
    'critic':    '#7A4FB0',
    'helper':    '#2A9D8F',
}
CX, CY, R = 128, 112, 84  # medal centre and radius (viewBox 256)


def shade(hex_, k):
    """k < 0 darker, k > 0 lighter."""
    r, g, b = (int(hex_[i:i + 2], 16) for i in (1, 3, 5))
    t = 255 if k > 0 else 0
    k = abs(k)
    return '#%02X%02X%02X' % tuple(round(c + (t - c) * k) for c in (r, g, b))


def rosette(n, r_out, r_in):
    pts = []
    for i in range(n):
        a = -math.pi / 2 + 2 * math.pi * i / n
        m = a + math.pi / n
        p = (CX + math.cos(a) * r_in, CY + math.sin(a) * r_in)
        c = (CX + math.cos(m) * r_out, CY + math.sin(m) * r_out)
        pts.append((p, c))
    d = 'M%.2f,%.2f ' % pts[0][0]
    for i, (p, c) in enumerate(pts):
        nxt = pts[(i + 1) % n][0]
        d += 'Q%.2f,%.2f %.2f,%.2f ' % (c[0], c[1], nxt[0], nxt[1])
    return d + 'Z'


def star(x, y, r):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + math.pi * i / 5
        rr = r if i % 2 == 0 else r * 0.45
        pts.append('%.2f,%.2f' % (x + math.cos(a) * rr, y + math.sin(a) * rr))
    return 'M' + ' L'.join(pts) + 'Z'


# Emblems: drawn in a 100x100 box centred on the medal; fill = struck metal, `cut` = details cut into it.
def emblem(cat, ink, cut):
    if cat == 'explorer':  # a shop front: scalloped awning, window, door
        return f'''
<path d="M14,30 L86,30 L92,46 L8,46 Z" fill="{ink}"/>
<path d="M8,46 Q14,56 20.5,46 Q27,56 33.5,46 Q40,56 46.5,46 Q53,56 59.5,46 Q66,56 72.5,46 Q79,56 85.5,46 Q89,52 92,46 Z" fill="{ink}"/>
<path d="M26,30 L22,46 M42,30 L40,46 M58,30 L60,46 M74,30 L78,46" stroke="{cut}" stroke-width="3"/>
<rect x="16" y="58" width="68" height="30" rx="2" fill="{ink}"/>
<rect x="22" y="63" width="26" height="15" rx="2" fill="{cut}"/>
<rect x="56" y="63" width="20" height="25" rx="2" fill="{cut}"/>
<circle cx="72" cy="76" r="1.8" fill="{ink}"/>
<rect x="10" y="86" width="80" height="6" rx="3" fill="{ink}"/>'''
    if cat == 'traveller':  # a folded map with a pin
        return f'''
<path d="M10,30 L36,20 L64,30 L90,20 L90,80 L64,90 L36,80 L10,90 Z" fill="{ink}"/>
<path d="M36,20 L36,80 M64,30 L64,90" stroke="{cut}" stroke-width="3"/>
<path d="M16,66 Q30,52 44,62 T76,50" stroke="{cut}" stroke-width="3" fill="none" stroke-dasharray="5 4" stroke-linecap="round"/>
<path d="M66,10 C52,10 46,22 50,32 C54,42 66,54 66,54 C66,54 78,42 82,32 C86,22 80,10 66,10 Z" fill="{ink}" stroke="{cut}" stroke-width="3"/>
<circle cx="66" cy="27" r="6" fill="{cut}"/>'''
    if cat == 'regular':  # a till receipt
        return f'''
<path d="M24,10 L76,10 L76,92 L69.5,86 L63,92 L56.5,86 L50,92 L43.5,86 L37,92 L30.5,86 L24,92 Z" fill="{ink}"/>
<rect x="33" y="22" width="34" height="5" rx="2.5" fill="{cut}"/>
<rect x="33" y="36" width="22" height="4" rx="2" fill="{cut}"/><rect x="59" y="36" width="8" height="4" rx="2" fill="{cut}"/>
<rect x="33" y="47" width="18" height="4" rx="2" fill="{cut}"/><rect x="59" y="47" width="8" height="4" rx="2" fill="{cut}"/>
<rect x="33" y="58" width="24" height="4" rx="2" fill="{cut}"/><rect x="59" y="58" width="8" height="4" rx="2" fill="{cut}"/>
<path d="M33,69 L67,69" stroke="{cut}" stroke-width="2" stroke-dasharray="3 3"/>
<rect x="33" y="74" width="14" height="5" rx="2.5" fill="{cut}"/><rect x="55" y="74" width="12" height="5" rx="2.5" fill="{cut}"/>'''
    if cat == 'cook':  # a pot with steam
        return f'''
<path d="M36,30 C30,22 42,18 36,10 M50,30 C44,22 56,18 50,10 M64,30 C58,22 70,18 64,10" stroke="{ink}" stroke-width="5" fill="none" stroke-linecap="round"/>
<rect x="14" y="40" width="72" height="8" rx="4" fill="{ink}"/>
<rect x="44" y="34" width="12" height="7" rx="3" fill="{ink}"/>
<path d="M18,50 L82,50 L78,82 Q77,90 68,90 L32,90 Q23,90 22,82 Z" fill="{ink}"/>
<path d="M18,56 Q6,56 6,64 Q6,70 18,70 M82,56 Q94,56 94,64 Q94,70 82,70" stroke="{ink}" stroke-width="5" fill="none"/>
<path d="M28,62 L72,62" stroke="{cut}" stroke-width="3" stroke-linecap="round"/>'''
    if cat == 'critic':  # a speech bubble with a star
        return f'''
<path d="M14,18 L86,18 Q94,18 94,26 L94,66 Q94,74 86,74 L46,74 L26,92 L30,74 L14,74 Q6,74 6,66 L6,26 Q6,18 14,18 Z" fill="{ink}"/>
<path d="{star(50, 46, 20)}" fill="{cut}"/>'''
    if cat == 'helper':  # a map pin with a tick: the map, fixed
        return f'''
<path d="M50,6 C28,6 16,22 16,40 C16,62 50,94 50,94 C50,94 84,62 84,40 C84,22 72,6 50,6 Z" fill="{ink}"/>
<circle cx="50" cy="40" r="20" fill="{cut}"/>
<path d="M40,40 L47,47 L61,33" stroke="{ink}" stroke-width="6" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
<ellipse cx="50" cy="95" rx="22" ry="3" fill="{ink}" opacity="0.5"/>'''
    raise KeyError(cat)


def badge(cat, tier):
    hi, body, sh, deep = TIERS[tier]
    rib = CATEGORIES[cat]
    level = list(TIERS).index(tier)  # 0..4
    n = 16 + level * 2
    stars = ''.join(
        f'<path d="{star(CX + (i - level / 2) * 15, 203, 6.2)}" fill="{hi}" stroke="{deep}" stroke-width="1.2"/>'
        for i in range(level + 1))
    glints = ''
    if level >= 3:
        def glint(x, y, s):
            return (f'<path d="M{x},{y - s} Q{x},{y} {x + s},{y} Q{x},{y} {x},{y + s} Q{x},{y} {x - s},{y} '
                    f'Q{x},{y} {x},{y - s} Z" fill="#FFFFFF"/>')
        glints = glint(176, 58, 11) + glint(66, 150, 7) + glint(190, 150, 6)  # on the rim: white on paper is lost
    gem = ''
    if tier == 'diamond':  # a cut gem on the crown of the medal
        gem = f'''<g transform="translate({CX},{CY - R + 2})">
<path d="M-15,-6 L-8,-14 L8,-14 L15,-6 L0,14 Z" fill="#DFF2FF" stroke="{deep}" stroke-width="1.5"/>
<path d="M-15,-6 L15,-6 M-8,-14 L-4,-6 L0,14 M8,-14 L4,-6 L0,14" stroke="{sh}" stroke-width="1" fill="none"/>
<path d="M-8,-14 L-4,-6 L-15,-6 Z" fill="#FFFFFF" opacity="0.8"/></g>'''
    em = emblem(cat, f'url(#struck)', hi)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="512" height="512">
<defs>
  <linearGradient id="metal" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="{hi}"/><stop offset="0.45" stop-color="{body}"/><stop offset="1" stop-color="{sh}"/>
  </linearGradient>
  <linearGradient id="rim" x1="1" y1="1" x2="0" y2="0">
    <stop offset="0" stop-color="{hi}"/><stop offset="0.5" stop-color="{body}"/><stop offset="1" stop-color="{deep}"/>
  </linearGradient>
  <radialGradient id="face" cx="0.38" cy="0.32" r="0.8">
    <stop offset="0" stop-color="{hi}"/><stop offset="0.6" stop-color="{body}"/><stop offset="1" stop-color="{sh}"/>
  </radialGradient>
  <linearGradient id="struck" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="{sh}"/><stop offset="1" stop-color="{deep}"/>
  </linearGradient>
  <linearGradient id="ribbon" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="{shade(rib, -0.25)}"/><stop offset="1" stop-color="{rib}"/>
  </linearGradient>
  <filter id="drop" x="-20%" y="-20%" width="140%" height="140%">
    <feDropShadow dx="0" dy="4" stdDeviation="4" flood-color="#000" flood-opacity="0.28"/>
  </filter>
</defs>
<!-- ribbon tails -->
<path d="M84,150 L118,150 L106,246 L91,232 L72,242 Z" fill="url(#ribbon)"/>
<path d="M138,150 L172,150 L184,242 L165,232 L150,246 Z" fill="{shade(rib, -0.12)}"/>
<path d="M98,150 L106,150 L94,236 L88,231 Z M150,150 L158,150 L168,231 L162,236 Z" fill="#FFFFFF" opacity="0.25"/>
<!-- medal -->
<g filter="url(#drop)">
  <path d="{rosette(n, R + 10, R - 2)}" fill="url(#metal)" stroke="{deep}" stroke-width="2"/>
</g>
<circle cx="{CX}" cy="{CY}" r="{R - 12}" fill="url(#rim)"/>
<circle cx="{CX}" cy="{CY}" r="{R - 19}" fill="url(#face)" stroke="{sh}" stroke-width="1.5"/>
<circle cx="{CX}" cy="{CY}" r="{R - 24}" fill="none" stroke="{hi}" stroke-width="1" opacity="0.7"/>
<!-- emblem: struck, with a light edge below right -->
<g transform="translate({CX - 46},{CY - 48}) scale(0.92)">
  <g transform="translate(2.5,2.5)" opacity="0.9">{emblem(cat, hi, hi)}</g>
  {em}
</g>
<!-- shine -->
<path d="M{CX - 52},{CY - 20} A56,56 0 0 1 {CX + 30},{CY - 54} A70,70 0 0 0 {CX - 52},{CY - 20} Z" fill="#FFFFFF" opacity="0.35"/>
<!-- banner with the tier's stars -->
<path d="M58,192 L70,186 L186,186 L198,192 L186,214 L70,214 Z" fill="{deep}"/>
<path d="M70,186 L186,186 L182,210 L74,210 Z" fill="url(#struck)"/>
<path d="M74,188 L182,188" stroke="{hi}" stroke-width="1" opacity="0.6"/>
{stars}
{gem}
{glints}
</svg>
'''


def main():
    root = os.path.dirname(os.path.abspath(__file__))
    svg_dir = os.path.join(root, 'svg')
    png_dir = os.path.join(root, '..', '..', 'assets', 'badges')
    os.makedirs(svg_dir, exist_ok=True)
    os.makedirs(png_dir, exist_ok=True)
    paths = []
    for cat in CATEGORIES:
        for tier in TIERS:
            p = os.path.join(svg_dir, f'{cat}_{tier}.svg')
            with open(p, 'w') as f:
                f.write(badge(cat, tier))
            paths.append(p)
    if shutil.which('qlmanage'):
        with tempfile.TemporaryDirectory() as out:
            subprocess.run(['qlmanage', '-t', '-s', '512', '-o', out, *paths], check=True, capture_output=True)
            for p in paths:
                name = os.path.basename(p)
                shutil.move(os.path.join(out, name + '.png'), os.path.join(png_dir, name[:-4] + '.png'))
    print(f'{len(paths)} badges')


if __name__ == '__main__':
    main()
