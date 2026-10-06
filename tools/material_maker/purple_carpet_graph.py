"""Builds materials/source/purple_carpet.ptex: an example of writing a Material Maker graph as JSON.
    python3 tools/material_maker/purple_carpet_graph.py [tuft count] [out.ptex]
"""
import json,sys
def col(r,g,b,a=1): return {"r":r,"g":g,"b":b,"a":a,"type":"Color"}
def node(name,typ,params,x,y): return {"name":name,"type":typ,"parameters":params,"node_position":{"x":x,"y":y}}
def math(name,op,d2,x,y,d1=0): return node(name,"math",{"op":op,"default_in1":d1,"default_in2":d2,"clamp":False},x,y)
TUFTS = float(sys.argv[1]) if len(sys.argv)>1 else 8
nodes=[
 node("Material","material",{"albedo_color":col(1,1,1),"ao_light_affect":1,"depth_scale":0.3,"emission_energy":1,
      "metallic":0,"normal_scale":1,"resolution":1,"roughness":1,"size":10,"subsurf_scatter_strength":0},900,200),
 # tufted grid of soft pillow bumps
 node("tufts","pattern",{"mix":0,"x_wave":0,"x_scale":TUFTS,"y_wave":0,"y_scale":TUFTS},-400,0),
 # soften the bumps into rounded pillows (pow < 1 widens the tops)
 math("tufts_soft",6,0.6,-200,0),
 # fine carpet pile fuzz
 node("pile","fbm2",{"noise":0,"scale_x":192,"scale_y":192,"folds":0,"iterations":2,"persistence":0.55,"offset":0},-400,200),
 # large soft mottling / wear
 node("mottle","fbm2",{"noise":1,"scale_x":5,"scale_y":5,"folds":0,"iterations":4,"persistence":0.5,"offset":0},-400,400),
 math("tufts_w",2,0.8,0,0),
 math("pile_w",2,0.22,0,200),
 math("height",0,0,200,100),
 math("mottle_w",2,0.3,0,400),
 math("mottle_off",0,0.7,200,400),
 math("shade",2,0,400,200),
 node("albedo","colorize",{"gradient":{"interpolation":1,"type":"Gradient","points":[
     {"pos":0.0,"r":0.01,"g":0.0,"b":0.03,"a":1},
     {"pos":0.30,"r":0.12,"g":0.01,"b":0.26,"a":1},
     {"pos":0.62,"r":0.42,"g":0.06,"b":0.78,"a":1},
     {"pos":0.88,"r":0.62,"g":0.16,"b":1.0,"a":1},
     {"pos":1.0,"r":0.78,"g":0.34,"b":1.0,"a":1}]}},600,100),
 node("normal","normal_map2",{"buffer":1,"param2":0,"size":10,"strength":1.4},600,300),
 node("ao","occlusion2",{"param0":10,"param1":14,"param2":1.2,"param3":1},600,450),
 math("rough_w",2,0.12,400,550),
 math("rough",0,0.84,600,550),
]
C=lambda a,ap,b,bp: {"from":a,"from_port":ap,"to":b,"to_port":bp}
conns=[
 C("tufts",0,"tufts_soft",0), C("tufts_soft",0,"tufts_w",0),
 C("pile",0,"pile_w",0),
 C("tufts_w",0,"height",0), C("pile_w",0,"height",1),
 C("mottle",0,"mottle_w",0), C("mottle_w",0,"mottle_off",0),
 C("height",0,"shade",0), C("mottle_off",0,"shade",1),
 C("shade",0,"albedo",0), C("albedo",0,"Material",0),
 C("pile",0,"rough_w",0), C("rough_w",0,"rough",0), C("rough",0,"Material",2),
 C("height",0,"normal",0), C("normal",0,"Material",4),
 C("height",0,"ao",0), C("ao",0,"Material",5),
 C("height",0,"Material",6),
]
json.dump({"type":"graph","label":"Graph","name":"purple_carpet","node_position":{"x":0,"y":0},
           "parameters":{},"nodes":nodes,"connections":conns},open(sys.argv[2] if len(sys.argv)>2 else 'purple_carpet.ptex','w'),indent=1)
