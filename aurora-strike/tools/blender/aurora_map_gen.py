# AURORA STRIKE - Procedural Blender Map Generator (Blender 3.6+/4.x)
# Derived from Manuale Esecutivo Mappa AuroraStrike Godot.
# Important: heights/coastline are art-direction estimates, not survey data.
# Run in Blender Scripting workspace or: blender --background --python aurora_map_gen.py
# 1 BU = 1 m. Horizontal plane X/Z: -X west, +X east, -Z north, +Z south.
import bpy, math, csv, os, random, time
from pathlib import Path
from mathutils import Vector

OUT = Path(os.environ.get("AURORA_OUTPUT_DIR", str(Path(__file__).resolve().parent / "generated")))
SEED = 271023
SIZE, TILE, N = 2000.0, 250.0, 8
STEP = 20.0
random.seed(SEED)
POIS = [
("01_Monte_Nevoso","Monte Nevoso",-531,-719,"snow"),
("02_Lago_Azzurro","Lago Azzurro",-94,-633,"lake"),
("03_Bosco_Ombra","Bosco Ombra",227,-703,"forest"),
("04_Isole_del_Relitto","Isole del Relitto",719,-734,"islands"),
("05_Porto","Porto",-766,-250,"port"),
("06_Citta_Centrale","Città Centrale",-297,-250,"city"),
("07_Stazione_Termini","Stazione Termini",195,-242,"station"),
("08_Quartiere_Residenziale","Quartiere Residenziale",703,-375,"residential"),
("09_Colline_Verdi","Colline Verdi",-594,39,"hills"),
("10_Riviera","Riviera",-766,289,"riviera"),
("11_Zona_Industriale","Zona Industriale",31,70,"industry"),
("12_Centro_Commerciale","Centro Commerciale",406,78,"commercial"),
("13_Zona_Agricola","Zona Agricola",719,78,"farm"),
("14_Base_Militare","Base Militare",-367,422,"military"),
("15_Cava_Desolata","Cava Desolata",31,523,"quarry"),
("16_Deserto_Rosso","Deserto Rosso",641,438,"desert")]
COAST=[(-420,-965),(-625,-910),(-790,-790),(-855,-620),(-950,-430),(-930,-265),(-855,-95),(-900,105),(-930,300),(-850,495),(-790,650),(-660,820),(-510,930),(-320,967),(-155,922),(25,955),(210,920),(390,952),(575,905),(745,805),(875,655),(950,465),(910,290),(952,105),(900,-95),(930,-290),(850,-495),(720,-690),(575,-835),(400,-925),(220,-885),(35,-930),(-150,-875),(-300,-925)]
def log(s): print("[AURORA %s] %s"%(time.strftime("%H:%M:%S"),s),flush=True)
def collection(name,parent=None):
 c=bpy.data.collections.new(name); (parent or bpy.context.scene.collection).children.link(c); return c
def relink(o,c):
 for old in list(o.users_collection): old.objects.unlink(o)
 c.objects.link(o); return o
def mat(name,color,rough=.85,metal=0):
 m=bpy.data.materials.get(name) or bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
 bs=m.node_tree.nodes.get("Principled BSDF")
 if bs: bs.inputs["Base Color"].default_value=(*color,1); bs.inputs["Roughness"].default_value=rough; bs.inputs["Metallic"].default_value=metal
 return m
M={}
def init_mats():
 colors={"grass":((.22,.38,.15),.96,0),"forest":((.045,.16,.075),.95,0),"hill":((.33,.45,.19),.98,0),"snow":((.88,.93,.97),.77,0),"rock":((.28,.30,.31),.9,0),"soil":((.28,.20,.12),.98,0),"sand":((.79,.66,.44),.98,0),"red":((.64,.25,.13),.97,0),"asphalt":((.11,.125,.13),.9,0),"concrete":((.48,.49,.46),.91,0),"plaster":((.67,.58,.45),.92,0),"brick":((.47,.24,.17),.9,0),"glass":((.07,.22,.3),.28,.2),"metal":((.25,.29,.3),.48,.45),"wood":((.3,.18,.09),.93,0),"water":((.01,.3,.55),.2,.02),"shallow":((.03,.65,.72),.28,0),"deep":((.01,.12,.28),.24,0),"yellow":((.92,.73,.24),.75,0),"crop":((.48,.43,.19),.94,0),"rust":((.47,.18,.1),.8,.18),"white":((.95,.94,.86),.78,0)}
 for k,(c,r,me) in colors.items(): M[k]=mat("AS_"+k,c,r,me)
def cube(name,loc,dims,ma,c,bevel=0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=bpy.context.object;o.name=name;o.dimensions=dims;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);relink(o,c);o.data.materials.append(ma)
 if bevel:
  b=o.modifiers.new("Edge_Bevel","BEVEL");b.width=bevel;b.segments=2;o.modifiers.new("Weighted_Normals","WEIGHTED_NORMAL")
 return o
def cone(name,loc,r,h,ma,c,verts=8,r2=0):
 bpy.ops.mesh.primitive_cone_add(vertices=verts,radius1=r,radius2=r2,depth=h,location=loc);o=bpy.context.object;o.name=name;o.rotation_euler.x=-math.pi/2;relink(o,c);o.data.materials.append(ma);return o
def sphere(name,loc,scale,ma,c):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=5,radius=1,location=loc);o=bpy.context.object;o.name=name;o.scale=scale;relink(o,c);o.data.materials.append(ma)
 for p in o.data.polygons:p.use_smooth=True
 return o
def inside(x,z):
 yes=False;j=len(COAST)-1
 for i,(xi,zi) in enumerate(COAST):
  xj,zj=COAST[j]
  if ((zi>z)!=(zj>z)) and x < (xj-xi)*(z-zi)/(zj-zi+1e-12)+xi: yes=not yes
  j=i
 return yes
def gauss(x,z,cx,cz,sx,sz): return math.exp(-.5*(((x-cx)/sx)**2+((z-cz)/sz)**2))
def smooth(a,b,x):
 t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
def height(x,z):
 h=7+2*math.sin(x*.018)*math.cos(z*.014)
 h+=(18+12*math.sin(x*.035+z*.017))*gauss(x,z,-594,39,285,255)
 h+=(12+8*math.sin(x*.032)*math.cos(z*.021))*gauss(x,z,227,-703,300,265)
 h+=(20+10*math.sin(x*.032+z*.01))*gauss(x,z,641,438,260,245)
 h+=8*gauss(x,z,31,523,230,240)
 for cx,cz,sx,sz,amp in [(-575,-770,125,130,260),(-510,-705,110,155,225),(-650,-680,115,155,180),(-445,-780,75,95,145),(-690,-575,85,100,115)]: h+=amp*gauss(x,z,cx,cz,sx,sz)
 lake=math.sqrt(((x+94)/150)**2+((z+633)/112)**2);h-=20*(1-smooth(.8,1.2,lake))
 rx=130+125*math.sin((z+100)*.0035)+70*math.sin(z*.01);h-=8*(1-smooth(18,54,abs(x-rx)))
 city=gauss(x,z,-297,-250,310,185)+gauss(x,z,195,-242,220,120);h=h*(1-min(.72,city*.6))+8*min(.72,city*.6)
 return max(1.8,min(420,h))
def terrain_color(x,z,h):
 c=(.24,.39,.16)
 regions=[(-594,39,300,250,(.36,.5,.22)),(227,-703,315,280,(.08,.22,.1)),(-531,-719,220,190,(.49,.53,.56)),(31,523,265,235,(.65,.51,.31)),(641,438,280,250,(.64,.25,.13)),(719,78,230,200,(.42,.42,.18)),(31,70,220,190,(.34,.35,.3))]
 for cx,cz,sx,sz,t in regions:
  w=smooth(.1,.9,gauss(x,z,cx,cz,sx,sz));c=tuple(c[i]*(1-w)+t[i]*w for i in range(3))
 if h>110:
  w=smooth(110,220,h);c=tuple(c[i]*(1-w)+(.38,.4,.42)[i]*w for i in range(3))
 if h>220:
  w=smooth(220,340,h);c=tuple(c[i]*(1-w)+(.91,.95,.98)[i]*w for i in range(3))
 n=.93+.07*math.sin(x*.038+z*.021)*math.sin(z*.044-x*.015)
 return tuple(max(0,min(1,v*n)) for v in c)
def mesh(name,verts,faces,c,mats,indices=None,colors=None):
 me=bpy.data.meshes.new(name+"_Mesh");me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);c.objects.link(o)
 for m in mats:me.materials.append(m)
 if indices:
  for p,idx in zip(me.polygons,indices):p.material_index=idx
 if colors:
  try:
   attr=me.color_attributes.new(name="BiomeColor",type="FLOAT_COLOR",domain="POINT")
   for i,col in enumerate(colors):attr.data[i].color=(*col,1)
   m=mats[0];m.use_nodes=True;bs=m.node_tree.nodes.get("Principled BSDF");n=m.node_tree.nodes.new("ShaderNodeVertexColor");n.layer_name="BiomeColor";m.node_tree.links.new(n.outputs["Color"],bs.inputs["Base Color"])
  except Exception as e:log("Vertex color fallback: "+str(e))
 return o
def make_terrain(c):
 log("Generating dense island terrain")
 verts=[];colors=[];lookup={};faces=[];steps=int(SIZE/STEP)+1
 for iz in range(steps):
  z=-1000+iz*STEP
  for ix in range(steps):
   x=-1000+ix*STEP
   if inside(x,z):lookup[(ix,iz)]=len(verts);h=height(x,z);verts.append((x,h,z));colors.append(terrain_color(x,z,h))
 for (ix,iz),a in lookup.items():
  if (ix+1,iz) in lookup and (ix,iz+1) in lookup and (ix+1,iz+1) in lookup:
   b=lookup[(ix+1,iz)];d=lookup[(ix,iz+1)];e=lookup[(ix+1,iz+1)];faces.extend([(a,d,b),(b,d,e)])
 return mesh("Island_Terrain_2000m",verts,faces,c,[M["grass"]],colors=colors)
def ribbon(name,points,width,yoff,ma,c):
 verts=[];faces=[]
 for i,(x,z) in enumerate(points):
  if i==0:dx,dz=points[1][0]-x,points[1][1]-z
  elif i==len(points)-1:dx,dz=x-points[i-1][0],z-points[i-1][1]
  else:dx,dz=points[i+1][0]-points[i-1][0],points[i+1][1]-points[i-1][1]
  l=math.hypot(dx,dz) or 1;nx,nz=-dz/l,dx/l;y=height(x,z)+yoff
  verts.extend([(x+nx*width/2,y,z+nz*width/2),(x-nx*width/2,y,z-nz*width/2)])
 for i in range(len(points)-1):a=i*2;faces.extend([(a,a+2,a+1),(a+1,a+2,a+3)])
 return mesh(name,verts,faces,c,[ma])
def build_water(c):
 mesh("Open_Ocean",[(-1200,-1,-1200),(1200,-1,-1200),(1200,-1,1200),(-1200,-1,1200)],[(0,2,1),(0,3,2)],c,[M["deep"]])
 v=[];f=[];idx=[]
 for i,(x,z) in enumerate(COAST):
  v.extend([(x,.5,z),(x*1.035,-.2,z*1.035)])
 for i in range(len(COAST)):
  n=(i+1)%len(COAST);f.extend([(i*2,n*2,i*2+1),(i*2+1,n*2,n*2+1)]);idx.extend([0,1])
 mesh("Turquoise_Shore_Ring",v,f,c,[M["shallow"],M["sand"]],idx)
 # Real internal lake surface with irregular shoreline.
 cx,cz=-94,-633;v=[(cx,31,cz)];n=64
 for i in range(n):
  a=2*math.pi*i/n;r=1+.08*math.sin(a*3)+.04*math.cos(a*7);v.append((cx+150*r*math.cos(a),31,cz+112*r*math.sin(a)))
 mesh("Lago_Azzurro_Water",v,[(0,i+1,(i+1)%n+1) for i in range(n)],c,[M["water"]])
 # Curving outlet river heads south.
 pts=[]
 for j in range(45):
  z=-535+j*32;x=130+125*math.sin((z+180)*.006)+90*math.sin(z*.011);pts.append((x,z))
 ribbon("River_Shore_Bed",pts,58,.15,M["soil"],c);ribbon("River_Water",pts,43,1,M["water"],c)
def paths_between(c):
 roads=[
 [(-850,-250),(-700,-250),(-520,-250),(-297,-250),(-50,-245),(195,-242),(450,-290),(703,-375)],
 [(-594,39),(-680,85),(-735,160),(-766,289),(-670,280),(-594,210),(-450,70),(-297,-250),(-420,-430),(-531,-719)],
 [(31,70),(40,170),(10,260),(-95,335),(-225,390),(-367,422),(-200,480),(31,523),(330,480),(641,438)],
 [(406,78),(530,78),(719,78),(760,0),(760,-170),(703,-375)],
 [(195,-242),(160,-360),(145,-470),(190,-560),(227,-703),(430,-690),(610,-710),(719,-734)]]
 for j,path in enumerate(roads):
  pts=[]
  for a,b in zip(path,path[1:]):
   dist=math.hypot(b[0]-a[0],b[1]-a[1]);num=max(2,int(dist/18))
   for i in range(num):
    t=i/num;pts.append((a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t))
  pts.append(path[-1]);ribbon("Road_%02d"%j,pts,14 if j==0 else 9,.55,M["asphalt"],c)
 # Bridge decks at four approximate river crossings.
 for i,(x,z) in enumerate([(-8,90),(140,235),(180,410),(115,615)]):
  cube("River_Bridge_%02d"%i,(x,height(x,z)+4,z),(26,1.8,62),M["concrete"],c,.25)
  for side in [-1,1]:cube("Bridge_Rail_%d_%d"%(i,side),(x+side*12,height(x,z)+6,z),(1,1,62),M["metal"],c)
def make_poi(poi,root):
 pid,label,x,z,kind=poi;c=collection("POI_"+pid,root);y=height(x,z)
 def b(n,dx,dy,dz,sx,sy,sz,ma,bev=0):return cube(label+"_"+n,(x+dx,y+dy,z+dz),(sx,sy,sz),ma,c,bev)
 def cn(n,dx,dy,dz,r,h,ma,seg=9,r2=0):return cone(label+"_"+n,(x+dx,y+dy,z+dz),r,h,ma,c,seg,r2)
 if kind=="snow":
  for i,(dx,dz,r,h) in enumerate([(-90,-35,65,170),(-20,-50,74,250),(52,25,52,145),(95,-65,42,105),(-45,60,38,115)]):
   cn("RockPeak"+str(i),dx,h/2,dz,r,h,M["rock"],7,3);cn("SnowCap"+str(i),dx,h*.82,dz,r*.4,h*.32,M["snow"],7,1)
 elif kind in ("forest","hills"):
  for i in range(110 if kind=="forest" else 65):
   dx=random.uniform(-150,150);dz=random.uniform(-120,120);r=random.uniform(2.5,6);h=random.uniform(7,16)
   cn("TreeTrunk"+str(i),dx,h*.22,dz,r*.2,h*.5,M["wood"],6,r*.12)
   cn("TreeCrown"+str(i),dx,h*.68,dz,r,h*.7,M["forest"] if kind=="forest" else M["hill"],7,.15)
 elif kind=="lake":
  b("Molo",0,2,122,6,.8,62,M["wood"])
  for i in range(8):cube(label+"_DockPlank"+str(i),(x+(-7+i*2),y+2,z+115),(1,.6,9),M["wood"],c)
 elif kind=="islands":
  for i,(dx,dz,r) in enumerate([(-100,-40,35),(-35,35,46),(28,-55,31),(85,20,39),(115,-5,20)]):cn("Islet"+str(i),dx,3,dz,r,5,M["sand"],9,r*.7)
  b("WreckHull",-35,10,30,62,12,18,M["rust"],2);b("WreckMast",-22,24,30,2,28,2,M["wood"])
 elif kind=="port":
  for i in range(5):
   zz=-80+i*42;b("Quay"+str(i),-70,3,zz,110,5,22,M["concrete"],.5)
   for j in range(4):b("Container%d_%d"%(i,j),-90+j*17,8,zz,14,10,12,[M["red"],M["glass"],M["yellow"],M["metal"]][(i+j)%4],.3)
  for dx in (-105,-50):b("CraneLeg"+str(dx),dx,23,-25,4,40,4,M["yellow"])
  b("CraneBeam",-78,44,-25,63,4,5,M["yellow"])
 elif kind=="city":
  for i in range(24):
   dx=(i%6)*36-90;dz=(i//6)*38-57;w=random.uniform(22,31);d=random.uniform(23,32);h=random.uniform(18,45)
   b("RomanBuilding"+str(i),dx,h/2,dz,w,h,d,[M["plaster"],M["brick"],M["concrete"]][i%3],.5)
   b("Roof"+str(i),dx,h+1,dz,w+1,1.5,d+1,M["roof"])
 elif kind=="station":
  b("MainHall",0,13,0,145,26,55,M["plaster"],1);b("GlassFront",0,13,28,120,17,1,M["glass"]);b("Roof",0,27,0,154,3,64,M["roof"])
  for pz in (-75,-48,-21,21,48,75):
   b("Platform",0,1,pz,170,2,13,M["concrete"]);b("Canopy",0,10,pz,174,1,13,M["metal"])
   for tx in range(-80,81,8):b("Rail",tx,2,pz-2,8,.4,.4,M["metal"])
 elif kind=="residential":
  for i in range(30):
   dx=(i%6)*28-70;dz=(i//6)*32-80;h=random.choice([7,9,12,16]);b("House"+str(i),dx,h/2,dz,19,h,19,[M["plaster"],M["brick"],M["sand"]][i%3],.4);b("Roof"+str(i),dx,h+.7,dz,21,1.4,21,M["roof"])
 elif kind=="industry":
  b("FactoryHall",0,10,0,135,20,86,M["metal"],.7);b("FactoryRoof",0,21,0,140,3,92,M["roof"])
  for i in range(7):cn("Tank"+str(i),-70+i*23,10,58,8,20,M["metal"],16,8)
 elif kind=="commercial":
  for i,h in enumerate([48,76,94,58,70,52]):
   dx=(i%3)*54-54;dz=(i//3)*56-28;w=35;d=31;b("GlassTower"+str(i),dx,h/2,dz,w,h,d,M["glass"],.3);b("TowerRoof"+str(i),dx,h+.7,dz,w+2,1.4,d+2,M["metal"])
 elif kind=="farm":
  for fidx in range(5):
   for row in range(12):b("CropRow",-85+fidx*35,.8,-90+row*15,4,1.3,12,M["crop"])
  for i in range(3):cn("Silo"+str(i),90,11,-35+i*35,8,22,M["metal"],16,6)
  b("Barn",-5,7,105,42,14,36,M["red"],.5)
 elif kind=="military":
  b("Runway",0,1,0,32,1.5,255,M["asphalt"]);b("CentreLine",0,2,0,1,.2,225,M["white"])
  for i in range(3):b("Hangar"+str(i),-70+i*65,8,-70,44,16,38,M["metal"],.6)
  for i in range(12):
   a=2*math.pi*i/12;cn("FencePost"+str(i),110*math.cos(a),2,105*math.sin(a),.4,4,M["metal"],6,.25)
 elif kind=="quarry":
  for i in range(5):
   size=200-i*28;b("QuarryBench"+str(i),0,5+i*7,0,size,4,size*.72,M["rock"])
 elif kind=="desert":
  for i in range(18):
   dx=random.uniform(-150,150);dz=random.uniform(-120,120);r=random.uniform(18,44);h=random.uniform(18,60);cn("RedMesa"+str(i),dx,h/2,dz,r,h,M["red"],8,r*.72)
 elif kind=="riviera":
  b("Promenade",0,2,0,170,1.5,15,M["concrete"])
  for i in range(8):
   dx=-72+i*20;cn("UmbrellaPost"+str(i),dx,4,-25,.7,5,M["wood"],6,.35);sphere("BeachUmbrella"+str(i),(x+dx,y+7,z-25),(4,1,4),M["yellow"] if i%2 else M["red"],c)
 return c

# --- exporter / entry point ---
def create_overview(root):
 scene=bpy.context.scene; world=bpy.data.worlds.new("AS_Sky") if not bpy.data.worlds else bpy.data.worlds[0];scene.world=world;world.use_nodes=True;world.node_tree.nodes["Background"].inputs["Color"].default_value=(.02,.07,.15,1)
 bpy.ops.object.light_add(type="SUN",location=(0,450,0));sun=bpy.context.object;sun.name="AS_Sun";sun.data.energy=2.0;sun.rotation_euler=(math.radians(25),math.radians(-25),math.radians(-30));relink(sun,root)
 bpy.ops.object.camera_add(location=(0,2600,0),rotation=(math.radians(-90),0,0));cam=bpy.context.object;cam.name="AS_Overview_Camera";cam.data.type="ORTHO";cam.data.ortho_scale=2250;scene.camera=cam;relink(cam,root)
 try: scene.render.engine="BLENDER_EEVEE_NEXT"
 except: scene.render.engine="BLENDER_EEVEE"
 scene.render.resolution_x=1600;scene.render.resolution_y=1600;scene.render.resolution_percentage=100;scene.render.image_settings.file_format="PNG"
 try:scene.view_settings.view_transform="AgX"
 except:pass
 return cam
def glb_export(objects,path):
 bpy.ops.object.select_all(action="DESELECT"); valid=[]
 for o in objects:
  if o and o.name in bpy.data.objects: o.hide_set(False);o.select_set(True);valid.append(o)
 if not valid:return False
 bpy.context.view_layer.objects.active=valid[0]
 bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",use_selection=True,export_apply=True,export_cameras=False,export_lights=False)
 bpy.ops.object.select_all(action="DESELECT")
 return path.exists() and path.stat().st_size>64
def export_tiles(terrain,outdir,rows):
 # Generate each tile directly from the same global height function and 12.5m lattice.
 # 21x21 vertices per tile guarantees the seam vertices use exactly identical X/Z values.
 log("Generating 64 individual terrain tile meshes with shared-edge sample coordinates")
 paths=[]; step=TILE/20.0
 for j in range(N):
  for i in range(N):
   x0=-1000+i*TILE; z0=-1000+j*TILE; x1=x0+TILE; z1=z0+TILE
   tv=[]; tf=[]; cols=[]; valid=[]
   for zz in range(21):
    for xx in range(21):
     wx=x0+xx*step; wz=z0+zz*step; ok=inside(wx,wz)
     valid.append(ok)
     tv.append((wx-x0,height(wx,wz) if ok else 0.0,wz-z0))
     cols.append(terrain_color(wx,wz,height(wx,wz)) if ok else (0.02,0.04,0.06))
   for zz in range(20):
    for xx in range(20):
     a=zz*21+xx; b=a+1; c=a+21; d=c+1
     if valid[a] and valid[b] and valid[c] and valid[d]:
      tf.extend([(a,c,b),(b,c,d)])
   if not tf: continue
   name="Tile_X%02d_Z%02d"%(i,j);col=collection("Export_"+name)
   tile=mesh(name,tv,tf,col,[M["grass"]],colors=cols)
   tile.location=(x0,0,z0);tile["tile_x"]=i;tile["tile_z"]=j;tile["world_origin_x"]=x0;tile["world_origin_z"]=z0
   path=outdir/"tiles"/(name+".glb");path.parent.mkdir(parents=True,exist_ok=True);glb_export([tile],path);paths.append(path)
   rows.append(["terrain_tile",name,str(path),i,j,x0,z0,x1,z1,"procedural original; 12.5m grid; estimated heights; verify transform once in Godot"])
   bpy.data.objects.remove(tile,do_unlink=True);bpy.data.collections.remove(col)
   log(name+" exported")
 return paths

def main():
 OUT.mkdir(parents=True,exist_ok=True)
 for folder in ("tiles","poi","preview"):(OUT/folder).mkdir(parents=True,exist_ok=True)
 bpy.ops.object.select_all(action="SELECT");bpy.ops.object.delete(use_global=False)
 for c in list(bpy.data.collections):
  if c.name!=bpy.context.scene.collection.name:bpy.data.collections.remove(c)
 init_mats();root=collection("AURORA_STRIKE_WORLD");tc=collection("Terrain_Source",root);wc=collection("Water_and_Coast",root);rc=collection("Roads_and_Bridges",root);pc=collection("POI_Registry",root)
 terrain=make_terrain(tc);build_water(wc);paths_between(rc);poi_cols=[]
 for idx,poi in enumerate(POIS,1):log("Building POI %d/16: %s"%(idx,poi[1]));poi_cols.append((poi,make_poi(poi,pc)))
 # Batch trees by biome to reduce object count.
 veg=collection("Vegetation_Batches",root)
 for name,cx,cz,count,ma in [("Bosco_Ombra",227,-703,220,M["forest"]),("Colline_Verdi",-594,39,110,M["hill"])]:
  v=[];f=[];mi=[]
  for k in range(count):
   x=cx+random.uniform(-180,180);z=cz+random.uniform(-135,135)
   if not inside(x,z):continue
   y=height(x,z);r=random.uniform(2.5,5);h=random.uniform(8,17);base=len(v)
   v.extend([(x-r*.2,y,z),(x+r*.2,y,z),(x+r*.13,y+h*.5,z),(x-r*.13,y+h*.5,z),(x-r,y+h*.45,z),(x+r,y+h*.45,z),(x,y+h,z)])
   f.extend([(base,base+1,base+2,base+3),(base+4,base+5,base+6)]);mi.extend([0,1])
  mesh(name+"_TreeBatch",v,f,veg,[M["wood"],ma],mi)
 camera=create_overview(root)
 source=OUT/"AURORA_STRIKE_Map_Source.blend";bpy.ops.wm.save_as_mainfile(filepath=str(source));log("Saved editable Blender source")
 rows=[];tile_paths=export_tiles(terrain,OUT,rows)
 poi_paths=[]
 for poi,c in poi_cols:
  pid,label,x,z,kind=poi;dups=[]
  for src in list(c.objects):
   d=src.copy()
   if src.data:d.data=src.data.copy()
   bpy.context.scene.collection.objects.link(d);d.location.x-=x;d.location.z-=z;dups.append(d)
  path=OUT/"poi"/(pid+".glb");glb_export(dups,path);poi_paths.append(path)
  for d in dups:
   data=d.data;bpy.data.objects.remove(d,do_unlink=True)
   if data and data.users==0 and isinstance(data,bpy.types.Mesh):bpy.data.meshes.remove(data)
  rows.append(["poi_module",pid,str(path),"","",x,z,x,z,"procedural original; estimated concept coordinates"])
 try:glb_export([o for o in bpy.context.scene.objects if o.type in {"MESH","CURVE"}],OUT/"AURORA_STRIKE_Master_Preview.glb")
 except Exception as e:log("Master GLB export warning: "+str(e))
 scene=bpy.context.scene;scene.camera=camera;scene.render.filepath=str(OUT/"preview"/"aurora_strike_overview.png")
 try:bpy.ops.render.render(write_still=True)
 except Exception as e:log("Overview render warning: "+str(e))
 with open(OUT/"manifest.csv","w",newline="",encoding="utf-8") as f:
  w=csv.writer(f);w.writerow(["type","id","file","tile_x","tile_z","origin_x","origin_z","max_x","max_z","provenance"]);w.writerows(rows)
 log("FINISHED: %d terrain tiles and %d POIs in %s"%(len(tile_paths),len(poi_paths),OUT))
if __name__=="__main__":
 try:main()
 except Exception as e:log("FATAL: "+repr(e));raise
