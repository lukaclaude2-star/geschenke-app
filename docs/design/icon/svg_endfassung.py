"""Erzeugt die SVG-Quellen der Endfassung (farbig, grau, Silhouette) neben diese Datei. Danach in 4096 px rendern (z. B. Browser) und mit PIL/Lanczos auf 1024 px verkleinern."""
import pathlib
FASSUNG = {
  'farbe': dict(grund='#5F7A33', figur='#D7843A', band='#EBD9B4', auge='#23160C'),
  'grau':  dict(grund='#000000', figur='#E8E8E8', band='#9A9A9A', auge='#000000'),
  'silh':  dict(grund='#FFFFFF', figur='#000000', band=None,      auge=None),
}
def svg(c, px=4096):
    band = '' if not c['band'] else (
        f'<rect x="43" y="33" width="14" height="16" fill="{c["band"]}"/>'
        f'<rect x="43" y="53" width="14" height="33.5" fill="{c["band"]}"/>')
    augen = '' if not c['auge'] else ''.join(
        f'<path d="M{x} 67 q6 6 12 0" stroke="{c["auge"]}" stroke-width="5.6" fill="none" stroke-linecap="round"/>' for x in (26.5, 61.5))
    f = c['figur']
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{px}" height="{px}" viewBox="0 0 100 100">'
      f'<rect width="100" height="100" fill="{c["grund"]}"/><g transform="translate(-3 -3) scale(1.06)">'
      f'<polygon points="22,35 28,14 42,35" fill="{f}" stroke="{f}" stroke-width="4" stroke-linejoin="round"/>'
      f'<polygon points="58,35 72,14 78,35" fill="{f}" stroke="{f}" stroke-width="4" stroke-linejoin="round"/>'
      f'<rect x="15" y="33" width="70" height="16" rx="6" fill="{f}"/><rect x="20" y="53" width="60" height="33.5" rx="8" fill="{f}"/>'
      f'{band}{augen}</g></svg>')
out = pathlib.Path(__file__).parent
for name, c in FASSUNG.items():
    (out / f'{name}.svg').write_text(svg(c), encoding='utf-8')
print('ok')
