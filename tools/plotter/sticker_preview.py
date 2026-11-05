import json,os,sys
# Contact sheet for tools/plotter/vectorize_stickers.gd output.
# python3 sticker_preview.py in.json out.png 'title' marker_mm
REPO=os.environ.get('STICKER_REPO','.')
from PIL import Image,ImageDraw
d=json.load(open(sys.argv[1])); out=sys.argv[2]; title=sys.argv[3] if len(sys.argv)>3 else ''
MARK=float(sys.argv[4]) if len(sys.argv)>4 else 5
P=520; rows=[]
for id,r in d.items():
    W,H=r['size']; s=500/max(W,H); w,h=int(W*s),int(H*s)
    src=Image.open(os.path.join(REPO,'sprites','painting layers',id+'.png')).convert('RGBA').resize((w,h))
    a=Image.new('RGB',(P,h+20),'white'); a.paste(src,(10,10),src)
    b=Image.new('RGB',(P,h+20),'white'); db=ImageDraw.Draw(b)
    SS=4; c=Image.new('RGB',(P*SS,(h+20)*SS),'white'); dc=ImageDraw.Draw(c)
    for L in r['layers']:
        col='#'+L['color']
        for p in L['polygons']:
            pts=[(10+p[i]*s,10+p[i+1]*s) for i in range(0,len(p),2)]
            if len(pts)>1: db.line(pts+[pts[0]],fill=col,width=2)
        off=(-300+250*W*s/500/1+10, 0)
        for key,wid in (('hatch',MARK),('outlines',MARK)):
            for p in L[key]:
                pts=[((p[i]-300+w/2+10)*SS,(p[i+1]-300+h/2+10)*SS) for i in range(0,len(p),2)]
                dc.line(pts,fill=col,width=max(1,round(wid*SS)),joint='curve')
                if wid>=1:
                    for q in (pts[0],pts[-1]): rr=wid*SS/2; dc.ellipse([q[0]-rr,q[1]-rr,q[0]+rr,q[1]+rr],fill=col)
    nh=sum(len(L['hatch']) for L in r['layers']); npoly=sum(len(L['polygons']) for L in r['layers'])
    row=Image.new('RGB',(3*P,h+44),'white'); row.paste(a,(0,0)); row.paste(b,(P,0)); row.paste(c.resize((P,h+20),Image.LANCZOS),(2*P,0))
    ImageDraw.Draw(row).text((10,h+24),f"sticker {id}: {len(r['layers'])} colours "+' '.join('#'+L['color'] for L in r['layers'])+f" | {npoly} regions | {nh} hatch strokes",fill='black')
    rows.append(row)
H=sum(r.height for r in rows)+40; img=Image.new('RGB',(3*P,H),'white'); dr=ImageDraw.Draw(img)
dr.text((10,8),title,fill='black'); dr.text((10,22),"original  |  traced colour regions  |  painted with a %g mm marker at 500 mm wide (hatching + outlines)"%MARK,fill='black')
y=40
for r in rows: img.paste(r,(0,y)); y+=r.height
img.save(out)
