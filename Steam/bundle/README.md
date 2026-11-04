# Steam bundle art

Made with the steam-bundle-art skill. Studio Sim's half comes from the live store capsules in `../store_art/` (pulled from Steam, appid 4278180).

Re-run for a new partner (add their header to `partner_headers/` and box their title lettering):

```
cd Steam
python3 bundle/make_bundle_art.py --out bundle \
  --ours store_art/hero_capsule_2x.jpg:15,205,735,705 \
  --ours-for bundle_header=store_art/main_capsule_2x.jpg:35,220,1180,455 \
  --ours-for vertical_capsule=store_art/main_capsule_2x.jpg:35,220,1180,455 \
  --partner picking_fruits=bundle/partner_headers/picking_fruits.jpg:112,78,358,212
```

Partners: `picking_fruits/` (A Game About Picking Fruits).
