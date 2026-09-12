import klayout.lay as lay

lv = lay.LayoutView()
lv.load_layout("ecc_design_final.gds")
lv.max_hier()
lv.zoom_fit()
lv.save_image("gds_view.png", 1600, 1600)
print("Imagem salva em gds_view.png")
