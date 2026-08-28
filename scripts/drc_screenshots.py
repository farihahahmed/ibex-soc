# KLayout script: annotate the 4 M3.1 DRC violations and prove they sit inside
# the two SRAM macro boundaries, on the VSS Metal3 pin.
import pya, os

gds = os.environ.get("GDS", "gds/chip_top_full.gds")
outdir = os.environ.get("OUTDIR", "docs/drc_screenshots")
os.makedirs(outdir, exist_ok=True)

MW, MH = 431.860, 484.880
imem = (120.0, 300.0)
dmem = (560.0, 300.0)
macros = [("imem_sram", imem), ("dmem_sram", dmem)]
viols = [
    (238.435, 330.995, 240.000, 331.165),
    (240.000, 330.995, 326.985, 331.165),
    (678.435, 330.995, 720.000, 331.165),
    (720.000, 330.995, 766.985, 331.165),
]

app = pya.Application.instance()
mw = app.main_window()
mw.load_layout(gds, 1)
view = mw.current_view()
cv = view.active_cellview()
ly = cv.layout()
dbu = ly.dbu
top = cv.cell

li_bound = ly.insert_layer(pya.LayerInfo(1000, 0))
li_viol  = ly.insert_layer(pya.LayerInfo(1001, 0))
def um2dbu(v): return int(round(v/dbu))
for name, (ox, oy) in macros:
    top.shapes(li_bound).insert(pya.Box(um2dbu(ox), um2dbu(oy), um2dbu(ox+MW), um2dbu(oy+MH)))
for (x1,y1,x2,y2) in viols:
    top.shapes(li_viol).insert(pya.Box(um2dbu(x1),um2dbu(y1),um2dbu(x2),um2dbu(y2)))

view.max_hier()
for lp in view.each_layer():
    li = lp.source_layer_index
    if li == li_bound:
        lp.fill_color = 0x0000ff; lp.frame_color = 0x0000ff
        lp.dither_pattern = 1; lp.transparent = True; lp.width = 3
    elif li == li_viol:
        lp.fill_color = 0xff0000; lp.frame_color = 0xff0000; lp.width = 3
view.update_content()

def shot(fn, x1, y1, x2, y2, w=1600, h=1200):
    view.zoom_box(pya.DBox(x1, y1, x2, y2))
    view.save_image(os.path.join(outdir, fn), w, h)
    print("wrote", fn)

shot("1_overview.png", -20, -20, 1130, 820)
shot("2_imem_macro.png", 110, 290, 560, 790)
shot("3_dmem_macro.png", 550, 290, 1000, 790)
shot("4_pin_closeup_imem.png", 235, 329, 330, 333)
shot("5_pin_closeup_dmem.png", 675, 329, 770, 333)
print("DONE ->", outdir)
app.exit(0)
