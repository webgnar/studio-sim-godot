# Steam bundle art

Made with the steam-bundle-art skill. Studio Sim's half comes from its live store capsules in `../store_art/` (appid 4278180). Each partner's capsules go in `partner_art/<slug>/`.

New partner, from their store URL:

```
cd Steam
python3 bundle/fetch_steam_art.py <store url> bundle/partner_art/<slug>
# view their hero_capsule_2x, main_capsule_2x and small_capsule_2x, box the title lettering in each, then:
python3 bundle/make_bundle_art.py --out bundle \
  --ours store_art/hero_capsule_2x.jpg:15,205,735,705 \
  --ours-for bundle_header=store_art/main_capsule_2x.jpg:35,220,1180,455 \
  --ours-for vertical_capsule=store_art/main_capsule_2x.jpg:35,220,1180,455 \
  --partner <slug>=bundle/partner_art/<slug>/hero_capsule_2x.jpg:<box> \
  --partner-for <slug>.bundle_header=bundle/partner_art/<slug>/main_capsule_2x.jpg:<box> \
  --partner-for <slug>.vertical_capsule=bundle/partner_art/<slug>/main_capsule_2x.jpg:<box> \
  --partner-for <slug>.small_capsule=bundle/partner_art/<slug>/small_capsule_2x.jpg:<box>
```

Partners so far:
- `picking_fruits/`: A Game About Picking Fruits (app 5243280). Boxes: hero 110,380,660,690; main 246,260,1020,685; small 148,62,335,168.
- `cake_break_room/`: There is Cake in the Break Room (app 5114500). Boxes: hero 230,245,515,720; main 475,160,740,610; small 12,8,452,108 (small half is squeezed horizontally so the one-line title stays big).
- `zen_house/`: Zen House: Zed Zero Simulator (app 5292280). Boxes: hero 20,100,705,700 (title + house); main 40,25,1200,650 (title + house); small 20,60,430,125 (small half squeezed horizontally, bundle header and vertical slightly stretched vertically to fit the wide title).
- `coast_clear/`: The Coast is Clear: Tidy up the Beach (app 5205300). The developer sent a clean artwork + transparent logo, so their halves were built first with `compose_partner_half.py partner_art/coast_clear/artwork.png partner_art/coast_clear/logo.png partner_art/coast_clear/halves`, then passed per size with box 0,0,10,10 (already exact size, no crop).
