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
