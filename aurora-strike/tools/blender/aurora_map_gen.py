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
STEP = 2.0  # 2 m terrain sampling: 56% more terrain triangles than 2.5 m, with LOD planned for distant views.
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
COAST_CONTROL=[(-420,-965),(-625,-910),(-790,-790),(-855,-620),(-950,-430),(-930,-265),(-855,-95),(-900,105),(-930,300),(-850,495),(-790,650),(-660,820),(-510,930),(-320,967),(-155,922),(25,955),(210,920),(390,952),(575,905),(745,805),(875,655),(950,465),(910,290),(952,105),(900,-95),(930,-290),(850,-495),(720,-690),(575,-835),(400,-925),(220,-885),(35,-930),(-150,-875),(-300,-925)]
def smooth_coastline(points, subdivisions=4):
 out=[]
 for i,p1 in enumerate(points):
  p0=points[(i-1)%len(points)];p2=points[(i+1)%len(points)];p3=points[(i+2)%len(points)]
  for k in range(subdivisions):
   t=k/subdivisions;t2=t*t;t3=t2*t
   vals=[]
   for axis in (0,1):
    vals.append(.5*((2*p1[axis])+(-p0[axis]+p2[axis])*t+(2*p0[axis]-5*p1[axis]+4*p2[axis]-p3[axis])*t2+(-p0[axis]+3*p1[axis]-3*p2[axis]+p3[axis])*t3))
   out.append((vals[0],vals[1]))
 return out
# Dense spline samples reduce visible facets along the coastline while preserving the authored control points.
def roughen_coastline(points):
 out=[]
 for i,(x,z) in enumerate(points):
  prev=points[i-1];nxt=points[(i+1)%len(points)]
  tx,tz=nxt[0]-prev[0],nxt[1]-prev[1]
  length=math.hypot(tx,tz) or 1.0
  nx,nz=-tz/length,tx/length
  wave=5.2*math.sin(i*.83)+2.7*math.sin(i*2.07+.4)+1.4*math.sin(i*.19)
  out.append((x+nx*wave,z+nz*wave))
 return out
COAST=roughen_coastline(smooth_coastline(COAST_CONTROL,8))
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
 colors={"grass":((.22,.38,.15),.96,0),"forest":((.045,.16,.075),.95,0),"hill":((.33,.45,.19),.98,0),"snow":((.88,.93,.97),.77,0),"rock":((.28,.30,.31),.9,0),"soil":((.28,.20,.12),.98,0),"sand":((.79,.66,.44),.98,0),"red":((.64,.25,.13),.97,0),"asphalt":((.11,.125,.13),.9,0),"roof":((.18,.20,.20),.92,0),"concrete":((.48,.49,.46),.91,0),"plaster":((.67,.58,.45),.92,0),"brick":((.47,.24,.17),.9,0),"glass":((.07,.22,.3),.28,.2),"metal":((.25,.29,.3),.48,.45),"wood":((.3,.18,.09),.93,0),"water":((.008,.075,.14),.24,.04),"shallow":((.018,.13,.17),.32,0),"deep":((.003,.018,.045),.28,.02),"yellow":((.92,.73,.24),.75,0),"crop":((.48,.43,.19),.94,0),"rust":((.47,.18,.1),.8,.18),"white":((.95,.94,.86),.78,0)}
 for k,(c,r,me) in colors.items(): M[k]=mat("AS_"+k,c,r,me)
 install_realistic_material_library()
 # Route actual scene geometry through the new PBR shaders rather than leaving them as unused library entries.
 for key in ("asphalt","concrete","plaster","brick","roof","metal","wood","sand","soil","glass","rust","water"):
  M[key]=bpy.data.materials.get("AS_"+key+"_PBR") or M[key]
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
def river_center_x(z):
 # Single authoritative centerline shared by terrain depression, river water and bridge placement.
 return 130+125*math.sin((z+180)*.006)+90*math.sin(z*.011)
def height(x,z):
 h=7+2*math.sin(x*.018)*math.cos(z*.014)
 h+=(18+12*math.sin(x*.035+z*.017))*gauss(x,z,-594,39,285,255)
 h+=(12+8*math.sin(x*.032)*math.cos(z*.021))*gauss(x,z,227,-703,300,265)
 h+=(20+10*math.sin(x*.032+z*.01))*gauss(x,z,641,438,260,245)
 h+=8*gauss(x,z,31,523,230,240)
 # Overlapping asymmetric ridges form a single mountain mass with secondary spurs.
 for cx,cz,sx,sz,amp in [(-550,-745,105,115,130),(-490,-680,90,130,100),(-630,-655,100,125,90),(-435,-755,65,80,65),(-655,-555,75,85,60),(-755,-745,72,108,72),(-570,-825,92,66,74),(-455,-650,60,94,62),(-700,-820,65,60,48)]:
  h+=amp*gauss(x,z,cx,cz,sx,sz)
 ridge=(math.sin(x*.052+1.6*math.sin(z*.031))*math.sin(z*.061-x*.017)+.45*math.sin(x*.095+z*.037))*8.0*smooth(55,135,h)
 erosion=(math.sin(x*.083+1.2*math.sin(z*.047))*1.65+math.sin(z*.137-x*.061)*1.05+math.sin(x*.225+z*.193)*math.sin(z*.171)*.65)
 fine=(math.sin(x*.31+math.sin(z*.15))*math.cos(z*.27-x*.09))*.34
 lake=math.sqrt(((x+94)/150)**2+((z+633)/112)**2);h-=20*(1-smooth(.8,1.2,lake))
 rx=river_center_x(z);h-=8*(1-smooth(18,54,abs(x-rx)))
 # Quarry bowl with raised bench; mesa relief in the south-east desert.
 qdist=math.sqrt(((x-31)/210)**2+((z-523)/180)**2)
 if qdist<1.25:
  h-=18*(1-smooth(.35,.95,qdist))
  h+=7*smooth(.70,1.05,qdist)*(1-smooth(1.02,1.22,qdist))
 dd=math.sqrt(((x-641)/285)**2+((z-438)/240)**2)
 h+=18*(1-smooth(.55,1.05,dd))*(.55+.45*math.sin(x*.045+z*.023))
 city=max(gauss(x,z,-297,-250,310,185),gauss(x,z,195,-242,220,120),gauss(x,z,703,-375,250,190),gauss(x,z,31,70,180,145),gauss(x,z,406,78,185,150))
 h=h*(1-min(.78,city*.72))+8*min(.78,city*.72)
 # Flatten the port apron at a low, walkable height outside the excavated basin.
 port_weight=min(.92,gauss(x,z,-766,-250,260,220)*.92)
 h=h*(1-port_weight)+2.5*port_weight
 relief_mask=(1.0-min(.92,city*.82))*smooth(5,30,h)
 h+=(ridge+erosion+fine)*relief_mask
 # Mountain-only fractal relief: sharper ridgelines, gullies and broken rock shoulders.
 # The amplitude fades into cities and lowlands so roads/POI pads remain comparatively stable.
 mountain_mask=max(gauss(x,z,-550,-745,190,185),gauss(x,z,-490,-680,170,200),
                  gauss(x,z,-630,-655,185,190),gauss(x,z,-435,-755,135,150),
                  gauss(x,z,-655,-555,145,150),gauss(x,z,-755,-745,145,170),
                  gauss(x,z,-570,-825,160,120),gauss(x,z,-455,-650,130,155),
                  gauss(x,z,-700,-820,130,115))
 mountain_mask=max(0.0,min(1.0,mountain_mask*1.55))
 ridge_fine=abs(math.sin(x*.071+1.7*math.sin(z*.043)) * math.sin(z*.083-x*.029))
 ridge_mid=abs(math.sin(x*.031+1.2*math.sin(z*.019)) * math.sin(z*.037-x*.014))
 fractured=(ridge_fine*3.2+ridge_mid*5.5-2.0)
 gullies=(math.sin(x*.16+math.sin(z*.081)*1.8)+math.cos(z*.145-x*.053))*1.15
 h+=(fractured+gullies)*mountain_mask*smooth(48,100,h)*relief_mask
 # Fine erosion detail across hills, quarry and desert escarpments without noisy flat city pads.
 erosion_detail=(math.sin(x*.19+math.sin(z*.071))*math.cos(z*.17-x*.063)
                 +.45*math.sin(x*.31+z*.23)*math.sin(z*.27-x*.11))*1.05
 h+=erosion_detail*relief_mask*(.35+.65*mountain_mask)
 # Cut a proper shallow port basin under the water level, rather than covering intact land with blue.
 harbor_dx=x+805.0;harbor_dz=z+250.0
 harbor_dx_norm=harbor_dx/(145.0 if harbor_dx<0 else 62.0)
 harbor_dz_norm=harbor_dz/(126.0 if harbor_dz<0 else 74.0)
 harbor_metric=harbor_dx_norm**2+harbor_dz_norm**2
 if harbor_metric < 1.0:
  return -1.2 + .12*math.sin(x*.07+z*.04)
 return max(1.8,min(420,h))
def terrain_color(x,z,h):
 c=(.24,.39,.16)
 regions=[(-594,39,300,250,(.36,.5,.22)),(227,-703,315,280,(.08,.22,.1)),(-531,-719,220,190,(.49,.53,.56)),(31,523,265,235,(.65,.51,.31)),(641,438,280,250,(.64,.25,.13)),(719,78,230,200,(.42,.42,.18)),(31,70,220,190,(.34,.35,.3))]
 for cx,cz,sx,sz,t in regions:
  w=smooth(.1,.9,gauss(x,z,cx,cz,sx,sz));c=tuple(c[i]*(1-w)+t[i]*w for i in range(3))
 if h>90:
  rock_band=smooth(90,160,h)*(1-smooth(195,245,h))
  exposed=.5+.5*math.sin(x*.041+1.5*math.sin(z*.023)+2.0*math.sin(x*.007+z*.012))
  rock_mix=rock_band*smooth(.53,.89,exposed)*.62
  c=tuple(c[i]*(1-rock_mix)+(.25,.28,.30)[i]*rock_mix for i in range(3))
 if h>110:
  w=smooth(110,215,h);c=tuple(c[i]*(1-w)+(.36,.38,.40)[i]*w for i in range(3))
 if h>195:
  w=smooth(195,275,h)
  snow_var=.94+.035*math.sin(x*.06+z*.025)*math.cos(z*.08-x*.02)
  snow=(snow_var*.94,snow_var*.97,min(1.0,snow_var*1.015))
  c=tuple(c[i]*(1-w)+snow[i]*w for i in range(3))
 n=.94+.06*math.sin(x*.038+z*.021)*math.sin(z*.044-x*.015)
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
def faceted_peak(name,x,z,base_y,radius,h,c,phase=0.0):
 segments=16
 verts=[];faces=[];indices=[]
 ring_specs=[(1.0,0.0,0.0,0.0),(.62,.52,.055*radius*math.cos(phase),.055*radius*math.sin(phase)),(.28,.84,.13*radius*math.cos(phase+0.8),.13*radius*math.sin(phase+0.8))]
 for ring_id,(radius_factor,height_factor,ox,oz) in enumerate(ring_specs):
  for i in range(segments):
   a=2*math.pi*i/segments+ring_id*.035
   variation=.84+.16*(.5+.5*math.sin(i*2.1+phase+ring_id*.8))
   rr=radius*radius_factor*variation
   y_jitter=0.0 if ring_id==0 else h*.025*math.sin(i*2.6+phase+ring_id)
   verts.append((x+ox+rr*math.cos(a),base_y+h*height_factor+y_jitter,z+oz+rr*math.sin(a)))
 apex=len(verts)
 verts.append((x+radius*.08*math.cos(phase+1.4),base_y+h,z+radius*.08*math.sin(phase+1.4)))
 for i in range(segments):
  nxt=(i+1)%segments
  lo=i;lon=nxt;mid=segments+i;midn=segments+nxt;up=segments*2+i;upn=segments*2+nxt
  faces.extend([(lo,mid,lon),(lon,mid,midn),(mid,up,midn),(midn,up,upn),(up,apex,upn)])
  indices.extend([0,0,0,0,1 if i in (0,1,2,7,8) else 0])
 obj=mesh(name,verts,faces,c,[M["rock"],M["snow"]],indices)
 for poly in obj.data.polygons: poly.use_smooth=False
 return obj

def _world_noise(x,z,scale,seed):
 # Deterministic multi-frequency value noise without an external texture dependency.
 a=math.sin(x*scale+seed*1.731+math.sin(z*scale*.71+seed)*1.7)
 b=math.sin(z*scale*1.23-seed*.93+math.sin(x*scale*.63)*1.2)
 c=math.sin((x+z)*scale*.49+seed*2.17)
 return (a*.48+b*.34+c*.18)
def _urban_mask(x,z,cx,cz,rx,rz):
 return math.exp(-.5*(((x-cx)/rx)**2+((z-cz)/rz)**2))

def make_pbr_surface(name, base_color, roughness=.82, metallic=0.0, noise_scale=38.0, bump_strength=.16, bump_distance=.08, fine_scale=180.0):
 material=bpy.data.materials.get(name) or bpy.data.materials.new(name)
 material.diffuse_color=(*base_color,1)
 material.use_nodes=True
 nodes=material.node_tree.nodes;links=material.node_tree.links
 nodes.clear()
 out=nodes.new("ShaderNodeOutputMaterial")
 bs=nodes.new("ShaderNodeBsdfPrincipled")
 bs.inputs["Base Color"].default_value=(*base_color,1)
 bs.inputs["Roughness"].default_value=roughness
 bs.inputs["Metallic"].default_value=metallic
 # Keep the shader glTF-exportable: Blender procedural Noise/ColorRamp/Bump graphs are
 # not portable to Godot's standard PBR materials and were producing white roads/water.
 # Bake complex biome variation into the terrain albedo texture; use stable PBR base colors
 # for modular geometry until packed tileable texture maps are authored for these materials.
 bs.inputs["Base Color"].default_value=(*base_color,1)
 bs.inputs["Roughness"].default_value=roughness
 bs.inputs["Metallic"].default_value=metallic
 links.new(bs.outputs["BSDF"],out.inputs["Surface"])
 return material

def install_realistic_material_library():
 settings={
  # World-space noise scales: broad breakup roughly 8–30 m, fine surface detail roughly 0.4–1.2 m.
  "AS_asphalt_PBR":((.075,.082,.085),.91,.02,.075,.12,.025,1.7),
  "AS_concrete_PBR":((.42,.43,.41),.87,0,.09,.18,.035,2.0),
  "AS_plaster_PBR":((.62,.55,.44),.88,0,.12,.14,.022,2.2),
  "AS_brick_PBR":((.40,.17,.12),.91,0,.10,.18,.028,2.1),
  "AS_roof_PBR":((.105,.12,.125),.84,.08,.085,.17,.022,2.0),
  "AS_metal_PBR":((.22,.25,.26),.43,.72,.065,.09,.012,2.4),
  "AS_wood_PBR":((.24,.13,.065),.79,0,.16,.13,.018,1.6),
  "AS_sand_PBR":((.65,.49,.30),.94,0,.11,.20,.045,2.0),
  "AS_soil_PBR":((.22,.15,.095),.97,0,.14,.22,.05,1.8),
  "AS_glass_PBR":((.055,.16,.21),.20,.16,.06,.035,.004,2.2),
  "AS_rust_PBR":((.33,.105,.055),.83,.18,.12,.19,.03,2.0),
  "AS_water_PBR":((.008,.075,.14),.24,.04,.07,.05,.006,1.8)
 }
 for name,(color,rough,metal,scale,bump_strength,bump_distance,fine_scale) in settings.items():
  make_pbr_surface(name,color,rough,metal,scale,bump_strength,bump_distance,fine_scale)
def make_terrain(c):
 log("Generating dense island terrain with procedural biome albedo")
 # 1024² world-aligned biome albedo: higher resolution reduces visible color smearing across 250 m tiles.
 resolution=1024
 image=bpy.data.images.new("AURORA_STRIKE_Biome_Albedo",width=resolution,height=resolution,alpha=True,float_buffer=False)
 pixels=[]
 for py in range(resolution):
  z=-1000.0+(py/(resolution-1))*2000.0
  for px in range(resolution):
   x=-1000.0+(px/(resolution-1))*2000.0
   h=height(x,z)
   c0=terrain_color(x,z,h)
   n1=_world_noise(x,z,.026,17)
   n2=_world_noise(x,z,.091,29)
   n3=_world_noise(x,z,.27,43)
   variation=1.0+n1*.18+n2*.085+n3*.032
   rgb=[max(0,min(1,ch*variation)) for ch in c0]
   # Forest canopy footprints have feathered, non-rectangular edges and multiple green tones.
   forest=max(_urban_mask(x,z,227,-703,255,225),_urban_mask(x,z,-594,39,245,215)*.88,
              _urban_mask(x,z,-610,445,190,235)*.65,_urban_mask(x,z,-240,-475,180,125)*.58)
   forest=max(0,min(.9,forest*(.78+.12*n1+.09*n2)))
   fcol=(.035+.016*n2,.145+.032*n1,.055+.018*n3)
   for ci in range(3):rgb[ci]=rgb[ci]*(1-forest)+fcol[ci]*forest
   # A mottled snow/rock field spans the north-west mountain massif.
   mountain=_urban_mask(x,z,-575,-720,260,220)
   rock=mountain*max(0,min(.9,(h-70)/145))*(.40+.35*(.5+.5*n2))
   rcol=(.26+.05*n2,.28+.06*n2,.30+.06*n2)
   for ci in range(3):rgb[ci]=rgb[ci]*(1-rock)+rcol[ci]*rock
   snow=max(0,min(.98,(h-150)/105))*mountain
   snowpatch=max(0,min(.85,.42+.27*n1+.16*n2))
   snow*=snowpatch
   for ci,white in enumerate((.91,.94,.97)):rgb[ci]=rgb[ci]*(1-snow)+white*snow
   # Desert surface: warm mineral strata, dry river fans and sparse rock stippling.
   desert=max(_urban_mask(x,z,641,438,275,230),_urban_mask(x,z,31,523,220,190)*.35)
   dcol=(.77+.055*n1,.43+.045*n2,.22+.026*n3)
   for ci in range(3):rgb[ci]=rgb[ci]*(1-desert)+dcol[ci]*desert
   strata=.5+.5*math.sin((z+x*.42)*.071+2.4*n2)
   strata_mix=desert*.14*strata
   ochre=(.56,.24,.105)
   for ci in range(3):rgb[ci]=rgb[ci]*(1-strata_mix)+ochre[ci]*strata_mix
   # Agricultural parcel bands to the east of the commercial centre.
   farm=_urban_mask(x,z,719,78,225,155)
   if farm>.025:
    row=abs(math.sin((x*.74+z*.18)*.105+n2*.7))
    band=farm*(.10+.22*(row>.70))
    soil=(.53,.39,.20)
    for ci in range(3):rgb[ci]=rgb[ci]*(1-band)+soil[ci]*band
   # Urban ground plateaus are neutral grey-beige with block-scale pavement variation.
   urban=max(_urban_mask(x,z,-297,-250,185,135),_urban_mask(x,z,195,-242,145,100),
             _urban_mask(x,z,703,-375,180,135),_urban_mask(x,z,31,70,145,125),
             _urban_mask(x,z,406,78,155,130))
   urban=max(0,min(.88,urban))
   pavement=(.36+.035*n2,.35+.032*n2,.32+.028*n2)
   for ci in range(3):rgb[ci]=rgb[ci]*(1-urban)+pavement[ci]*urban
   pixels.extend((rgb[0],rgb[1],rgb[2],1.0))
 image.pixels.foreach_set(pixels)
 image.pack()
 material=bpy.data.materials.new("AS_Biome_Terrain_PBR")
 material.use_nodes=True
 nodes=material.node_tree.nodes;links=material.node_tree.links
 bs=nodes.get("Principled BSDF")
 tex=nodes.new("ShaderNodeTexImage");tex.name="Biome_Albedo_Texture";tex.image=image;tex.interpolation="Linear"
 links.new(tex.outputs["Color"],bs.inputs["Base Color"])
 bs.inputs["Roughness"].default_value=.96
 # Gentle fine bump gives earth/rock more readable relief under raking light.
 noise=nodes.new("ShaderNodeTexNoise");noise.inputs["Scale"].default_value=5.5;noise.inputs["Detail"].default_value=5.0;noise.inputs["Roughness"].default_value=.72
 bump=nodes.new("ShaderNodeBump");bump.inputs["Strength"].default_value=.16;bump.inputs["Distance"].default_value=.45
 links.new(noise.outputs["Fac"],bump.inputs["Height"]);links.new(bump.outputs["Normal"],bs.inputs["Normal"])
 verts=[];uvs=[];lookup={};faces=[];steps=int(SIZE/STEP)+1
 # Scanline rasterization: intersect the coastline once per terrain row, rather than
 # running a full point-in-polygon test (hundreds of coast segments) for every vertex.
 # This makes denser terrain practical without changing the authored coastline.
 for iz in range(steps):
  z=-1000+iz*STEP
  crossings=[]
  prev_x,prev_z=COAST[-1]
  for curr_x,curr_z in COAST:
   if (curr_z>z)!=(prev_z>z):
    crossings.append(curr_x+(z-curr_z)*(prev_x-curr_x)/(prev_z-curr_z))
   prev_x,prev_z=curr_x,curr_z
  crossings.sort()
  ix=0
  for span in range(0,len(crossings)-1,2):
   start_x,end_x=crossings[span],crossings[span+1]
   start_ix=max(0,int(math.ceil((start_x+1000)/STEP)))
   end_ix=min(steps-1,int(math.floor((end_x+1000)/STEP)))
   for ix in range(start_ix,end_ix+1):
    x=-1000+ix*STEP
    lookup[(ix,iz)]=len(verts);verts.append((x,height(x,z),z));uvs.append(((x+1000)/2000,(z+1000)/2000))
 for (ix,iz),a in lookup.items():
  if (ix+1,iz) in lookup and (ix,iz+1) in lookup and (ix+1,iz+1) in lookup:
   b=lookup[(ix+1,iz)];d=lookup[(ix,iz+1)];e=lookup[(ix+1,iz+1)];faces.extend([(a,d,b),(b,d,e)])
 terrain_obj=mesh("Island_Terrain_2000m",verts,faces,c,[material])
 uv_layer=terrain_obj.data.uv_layers.new(name="World_Albedo_UV")
 for poly in terrain_obj.data.polygons:
  poly.use_smooth=True
  for loop_index in poly.loop_indices:
   uv_layer.data[loop_index].uv=uvs[terrain_obj.data.loops[loop_index].vertex_index]
 # Add a second, lower-detail rock/sand shoulder along sea-facing cliffs for top-down relief.
 return terrain_obj
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
 # Close gaps left by the 5m raster grid with a thin, color-matched strip that follows the smoothed coast.
 lip_v=[];lip_f=[];lip_colors=[]
 for x,z in COAST:
  ix,iz=x*.99,z*.99
  ih=height(ix,iz);ch=height(x,z)
  lip_v.extend([(ix,ih+.12,iz),(x,ch+.12,z)])
  lip_colors.extend([terrain_color(ix,iz,ih),terrain_color(x,z,ch)])
 for i in range(len(COAST)):
  a=i*2;b=((i+1)%len(COAST))*2
  lip_f.extend([(a,b,a+1),(a+1,b,b+1)])
 mesh("Coastline_Land_Lip",lip_v,lip_f,c,[M["grass"]],colors=lip_colors)
 v=[];f=[];idx=[]
 # Two continuous concentric bands: warm sand on the inner strip, turquoise shallows on the outer strip.
 # Avoid alternating material on adjacent triangles, which made a jagged checkerboard coastline.
 for x,z in COAST:
  # Biome-specific coast bands: sandy bays, north-west cliffs and ochre southern coves.
  if x < -700 and z < 80:
   inner_y=3.8;shore_y=1.6
  elif z < -560 and x < -250:
   inner_y=11.0;shore_y=3.6
  elif x > 500 and z > 260:
   inner_y=5.4;shore_y=2.0
  elif z > 650:
   inner_y=3.2;shore_y=1.1
  else:
   inner_y=4.7+.7*math.sin(x*.025+z*.013);shore_y=1.8+.4*math.cos(x*.021-z*.017)
  # Restrained shore bands: a narrow sand shelf and dark teal shallows avoid the oversized neon-cyan outline.
  v.extend([(x*.984,inner_y,z*.984),(x,shore_y,z),(x*1.018,-.15,z*1.018)])
 for i in range(len(COAST)):
  n=(i+1)%len(COAST);a=i*3;b=n*3
  f.extend([(a,b,a+1),(a+1,b,b+1)]);idx.extend([1,1])
  f.extend([(a+1,b+1,a+2),(a+2,b+1,b+2)]);idx.extend([0,0])
 mesh("Turquoise_Shore_Ring",v,f,c,[M["shallow"],M["sand"]],idx)
 # Thin shoreline foam traces the coastline without a repeated rectangular decal.
 foam_v=[];foam_f=[]
 for x,z in COAST:
  foam_v.extend([(x*.999,1.27,z*.999),(x*1.002,1.22,z*1.002)])
 for i in range(len(COAST)):
  a=i*2;b=((i+1)%len(COAST))*2
  foam_f.extend([(a,b,a+1),(a+1,b,b+1)])
 mesh("Coastal_Foam_Edge",foam_v,foam_f,c,[M["white"]])
 # Curved harbour basin follows the west-coast port and leaves a channel to the sea.
 hx,hz=-805.0,-250.0
 harbor_outline=[(-145,-82),(-128,-112),(-96,-126),(-60,-119),(-32,-98),(8,-87),(42,-64),(62,-28),(60,12),(39,42),(9,61),(-31,67),(-68,55),(-99,34),(-122,8),(-140,-22)]
 hv=[(hx,1.48,hz)]
 for dx,dz in harbor_outline:
  hv.append((hx+dx,1.48,hz+dz))
 hf=[(0,i+1,(i+1)%len(harbor_outline)+1) for i in range(len(harbor_outline))]
 mesh("Porto_Harbor_Basin",hv,hf,c,[M["water"]])
 # Raised port access causeway joins the quay system to dry land across the inner basin.
 cube("Port_Access_Pier_Deck",(-750.0,3.7,-250.0),(65.0,1.0,14.0),M["concrete"],c,.3)
 cube("Port_Access_Pier_Asphalt",(-750.0,4.22,-250.0),(58.0,.12,8.4),M["asphalt"],c,.1)
 for pier_idx in range(5):
  pier_x=-775.0+float(pier_idx)*12.5
  cube("Port_Access_Pier_Pylon_%02d"%pier_idx,(pier_x,1.25,-250.0),(1.5,3.8,1.5),M["metal"],c,.1)
  for side in (-1.0,1.0):
   cube("Port_Access_Pier_Rail_%02d_%d"%(pier_idx,int(side)),(pier_x,4.85,-250.0+side*6.8),(1.2,1.5,.32),M["metal"],c,.06)
 # Real internal lake surface with irregular shoreline.
 cx,cz=-94,-633;v=[(cx,31,cz)];n=64
 for i in range(n):
  a=2*math.pi*i/n;r=1+.08*math.sin(a*3)+.04*math.cos(a*7);v.append((cx+150*r*math.cos(a),31,cz+112*r*math.sin(a)))
 mesh("Lago_Azzurro_Water",v,[(0,i+1,(i+1)%n+1) for i in range(n)],c,[M["water"]])
 # Curving outlet river heads south.
 pts=[]
 for j in range(181):
  z=-535+j*8;pts.append((river_center_x(z),z))
 # Narrow the channel so it reads as a river, not a broad blue road, from the overhead camera.
 ribbon("River_Shore_Bed",pts,42,.35,M["soil"],c);ribbon("River_Water",pts,29,2.6,M["water"],c)
 # Small, broken shallow-water margins soften the channel edge without forming a continuous bright outline.
 for side in (-1,1):
  bank_pts=[]
  for j,(rx,rz) in enumerate(pts):
   if j%3==0:
    prev=pts[max(0,j-1)];nxt=pts[min(len(pts)-1,j+1)]
    dx,dz=nxt[0]-prev[0],nxt[1]-prev[1];ln=math.hypot(dx,dz) or 1
    bank_pts.append((rx-side*18*(-dz/ln),rz-side*18*(dx/ln)))
  if len(bank_pts)>2:ribbon("River_Shallow_Bank_%s"%side,bank_pts,2.8,1.1,M["shallow"],c)
def paths_between(c):
 roads=[
  # Main transport spine through the port, central city, Termini and residential district.
  # Main spine bypasses Termini instead of cutting through the station hall and platforms.
  [(-720,-250),(-700,-250),(-520,-250),(-390,-250),(-297,-250),(-160,-248),(-50,-245),(35,-255),(65,-305),(95,-365),(195,-382),(295,-365),(325,-310),(350,-270),(450,-290),(565,-330),(703,-375)],
  # West loop through green hills and Riviera, with a branch to the snowy mountain.
  [(-594,39),(-680,85),(-735,160),(-766,289),(-670,280),(-594,210),(-480,135),(-390,40),(-297,-250),(-420,-430),(-486,-555),(-531,-719)],
  # Southern industrial/quarry/military/desert road; original central bridge anchor retained.
  [(31,70),(40,170),(10,260),(-95,335),(-225,390),(-367,422),(-290,458),(-200,480),(-30,511),(31,523),(170,505),(330,480),(485,460),(641,438)],
  # Commercial, farming and residential connections.
  [(406,78),(530,78),(719,78),(760,0),(760,-170),(703,-280),(703,-375)],
  # Northern route through woodland to the wreck islands.
  [(195,-242),(160,-360),(145,-470),(158,-545),(190,-610),(227,-703),(355,-700),(430,-690),(520,-702),(610,-710),(719,-734)],
  # Secondary west-central connector from port to central city and river corridor.
  [(-720,-250),(-690,-180),(-600,-130),(-500,-145),(-390,-205),(-297,-250),(-180,-330),(-90,-385),(30,-420),(145,-470)],
  # Lake-to-forest edge route.
  [(-531,-719),(-445,-665),(-360,-620),(-275,-600),(-190,-625),(-94,-633),(10,-620),(105,-585),(160,-535)],
  # Southern coast route along the outskirts of the military base, quarry and desert.
  [(-766,289),(-755,395),(-690,500),(-610,585),(-500,650),(-367,690),(-225,710),(-90,720),(31,710),(190,690),(350,680),(500,670),(641,640)],
  # Civic ring and east-side arterial.
  # Civic ring bends around the east edge of Termini instead of crossing the station footprint.
  [(-420,-95),(-340,-125),(-260,-120),(-190,-95),(-125,-80),(-65,-95),(0,-125),(75,-150),(140,-170),(245,-300),(300,-335),(330,-300),(350,-220),(270,-185),(350,-155),(420,-125),(500,-100),(575,-90),(650,-85)],
  [(31,70),(145,80),(250,80),(406,78),(530,150),(610,235),(700,320),(770,410)],
  # Military perimeter road.
  [(-367,422),(-455,435),(-545,440),(-630,425),(-710,410),(-766,360)],
  # Quarry access loop around the rim, rather than across the extraction floor.
  [(-200,480),(-120,520),(-70,570),(0,600),(85,615),(165,600),(230,560),(300,520),(330,480)]]
 for j,path in enumerate(roads):
  pts=[]
  for seg_idx,(a,b) in enumerate(zip(path,path[1:])):
   prev=path[max(0,seg_idx-1)];nxt=path[min(len(path)-1,seg_idx+2)]
   dist=math.hypot(b[0]-a[0],b[1]-a[1]);num=max(3,int(dist/10))
   for sample_idx in range(num):
    t=sample_idx/num;t2=t*t;t3=t2*t;out=[]
    for axis in (0,1):
     out.append(.5*((2*a[axis])+(-prev[axis]+b[axis])*t+(2*prev[axis]-5*a[axis]+4*b[axis]-nxt[axis])*t2+(-prev[axis]+3*a[axis]-3*b[axis]+nxt[axis])*t3))
    pts.append((out[0],out[1]))
  pts.append(path[-1])
  road_width=15.0 if j==0 else 9.5
  # Pale concrete shoulders sit just above the terrain; the asphalt crown is only slightly higher.
  ribbon("Road_Bed_%02d"%j,pts,road_width+3.6,.22,M["concrete"],c)
  ribbon("Road_%02d"%j,pts,road_width,.38,M["asphalt"],c)

 # Dashes follow the actual road polylines and terrain height instead of floating as a straight decal.
 mark_v=[];mark_f=[]
 for road_index,path in enumerate(roads):
  dash_counter=0
  for a,b in zip(path,path[1:]):
   dx,dz=b[0]-a[0],b[1]-a[1];length=math.hypot(dx,dz)
   if length<12:continue
   ux,uz=dx/length,dz/length;nx,nz=-uz,ux
   n=max(1,int(length/18.0))
   for step_idx in range(1,n,2):
    t=min(.96,(step_idx*18.0+4.0)/length)
    px=a[0]+dx*t;pz=a[1]+dz*t
    py=height(px,pz)+.46
    half_len=min(3.2,(length*.25));half_w=.24
    base=len(mark_v)
    mark_v.extend([
     (px-ux*half_len+nx*half_w,py,pz-uz*half_len+nz*half_w),
     (px-ux*half_len-nx*half_w,py,pz-uz*half_len-nz*half_w),
     (px+ux*half_len-nx*half_w,py,pz+uz*half_len-nz*half_w),
     (px+ux*half_len+nx*half_w,py,pz+uz*half_len+nz*half_w)
    ])
    mark_f.append((base,base+3,base+2,base+1))
    dash_counter+=1
 if mark_f:mesh("Road_Centre_Dashed_Markings",mark_v,mark_f,c,[M["yellow"]])

 # Find the actual road/river polyline intersections instead of placing bridges at unrelated coordinates.
 def intersect(a,b,d,e):
  rx,rz=b[0]-a[0],b[1]-a[1]
  sx,sz=e[0]-d[0],e[1]-d[1]
  den=rx*sz-rz*sx
  if abs(den)<1e-8:return None
  qx,qz=d[0]-a[0],d[1]-a[1]
  t=(qx*sz-qz*sx)/den
  u=(qx*rz-qz*rx)/den
  if 0.0<=t<=1.0 and 0.0<=u<=1.0:
   return (a[0]+t*rx,a[1]+t*rz,rx,rz)
  return None
 river_pts=[(river_center_x(-535+j*8),-535+j*8) for j in range(181)]
 crossings=[]
 for road_index,path in enumerate(roads):
  for a,b in zip(path,path[1:]):
   for d,e in zip(river_pts,river_pts[1:]):
    hit=intersect(a,b,d,e)
    if hit and all(math.hypot(hit[0]-old[0],hit[1]-old[1])>12.0 for old in crossings):
     crossings.append((hit[0],hit[1],hit[2],hit[3],road_index))
 if not crossings:
  raise RuntimeError("Road network does not intersect the river; bridge generation would be invalid")
 for i,(x,z,dx,dz,road_index) in enumerate(crossings):
  tangent_len=math.hypot(dx,dz) or 1.0
  ux,uz=dx/tangent_len,dz/tangent_len
  nx,nz=-uz,ux
  yaw=-math.atan2(uz,ux)
  ground=height(x,z)
  # Deck top is aligned to the road ribbon (height + 0.55); the long axis follows the road tangent.
  deck=cube("River_Bridge_%02d"%i,(x,ground-0.35,z),(64,1.8,18),M["concrete"],c,.25)
  deck.rotation_euler[1]=yaw
  for side in (-1,1):
   rail=cube("Bridge_Rail_%d_%d"%(i,side),(x+nx*8.6,ground+1.15,z+nz*8.6),(64,1.2,.8),M["metal"],c,.08)
   rail.rotation_euler[1]=yaw
  log("Bridge %02d aligned to road %02d at (%.1f, %.1f)"%(i,road_index,x,z))
def make_poi(poi,root):
 pid,label,x,z,kind=poi;c=collection("POI_"+pid,root);y=height(x,z)
 def b(n,dx,dy,dz,sx,sy,sz,ma,bev=0):return cube(label+"_"+n,(x+dx,y+dy,z+dz),(sx,sy,sz),ma,c,bev)
 def cn(n,dx,dy,dz,r,h,ma,seg=9,r2=0):return cone(label+"_"+n,(x+dx,y+dy,z+dz),r,h,ma,c,seg,r2)
 if kind=="snow":
  for i,(dx,dz,r,h) in enumerate([(-90,-35,40,55),(-20,-50,50,86),(52,25,34,54),(95,-65,26,43),(-45,60,28,46)]):
   base_y=height(x+dx,z+dz)
   faceted_peak(label+"_AlpinePeak_"+str(i),x+dx,z+dz,base_y,r,h,c,float(i)*1.7)
 elif kind in ("forest","hills"):
  # Layered, irregular crowns and mixed tree heights give the biome a fuller silhouette at gameplay distance.
  tree_count=180 if kind=="forest" else 95
  for i in range(tree_count):
   dx=random.uniform(-155,155);dz=random.uniform(-128,128)
   r=random.uniform(2.8,6.8);h=random.uniform(8,18)
   ma=M["forest"] if kind=="forest" else M["hill"]
   # More faceted, multi-tier tree silhouettes: break the repeated single-cone look from map height.
   cn("TreeTrunk"+str(i),dx,h*.20,dz,r*.17,h*.48,M["wood"],9,r*.10)
   cn("TreeCrown_Lower"+str(i),dx,h*.47,dz,r,h*.58,ma,16,r*.20)
   cn("TreeCrown_Middle"+str(i),dx+random.uniform(-.65,.65),h*.66,dz+random.uniform(-.65,.65),r*.78,h*.52,ma,14,r*.15)
   cn("TreeCrown_Upper"+str(i),dx+random.uniform(-.9,.9),h*.83,dz+random.uniform(-.9,.9),r*.56,h*.43,ma,12,.10)
 elif kind=="lake":
  b("Molo",0,2,122,6,.8,62,M["wood"])
  for i in range(8):cube(label+"_DockPlank"+str(i),(x+(-7+i*2),y+2,z+115),(1,.6,9),M["wood"],c)
 elif kind=="islands":
  islets=[(-132,-72,22,9),(-100,-40,35,14),(-67,-89,18,8),(-35,35,46,19),(2,73,23,10),(28,-55,31,13),(60,-83,17,7),(85,20,39,16),(115,-5,20,8),(138,-44,24,9),(152,45,18,7),(70,74,14,6)]
  for i,(dx,dz,r,rock_h) in enumerate(islets):
   cn("Islet_Rock_"+str(i),dx,rock_h*.42,dz,r,rock_h,M["rock"],11,r*.58)
   cn("Islet_Sand_Shoulder_"+str(i),dx,2.2,dz,r*1.12,3.4,M["sand"],13,r*.75)
  b("WreckHull",-35,10,30,62,12,18,M["rust"],2)
  b("WreckDeck",-35,16,30,40,1.2,15,M["metal"],.3)
  b("WreckMast",-22,24,30,2,28,2,M["wood"])
  for i in range(4):
   b("WreckDeckContainer_"+str(i),-50+i*10,18,29,8,5.5,7,[M["rust"],M["red"],M["metal"],M["yellow"]][i],.35)
 elif kind=="port":
  # Quays, mooring bollards and cranes sit above the carved harbor water.
  for i in range(6):
   zz=-92+i*36
   b("Quay"+str(i),-67,3.05,zz,106,4.5,17,M["concrete"],.7)
   b("Quay_Edge_Stripe"+str(i),-67,5.35,zz,106,.18,.55,M["white"],.04)
   for j in range(5):
    mat=[M["red"],M["glass"],M["yellow"],M["metal"],M["rust"]][(i+j)%5]
    b("Container%d_%d"%(i,j),-97+j*15.5,7.2,zz,12.5,8.4,10.5,mat,.35)
   for bollard in range(0,9,2):
    cn("Mooring_Bollard_%d_%d"%(i,bollard),-123+bollard*14,5.9,zz+9,.48,1.6,M["metal"],8,.42)
  for dx in (-106,-52):
   b("CraneLeg"+str(dx),dx,20,-24,4.2,34,4.2,M["yellow"])
  b("CraneBeam",-79,38,-24,65,4.2,5.0,M["yellow"])
  for crane_x in (-103,-55):
   b("Crane_Boom",crane_x,40,-10,2.4,2.4,34,M["yellow"])
   b("Crane_Hoist",crane_x,31,8,.9,17,.9,M["metal"])
 elif kind=="city":
  # Dense 8x7 city fabric with roof variation, individual windows and shopfronts.
  for i in range(56):
   dx=(i%8)*30-105;dz=(i//8)*29-87;w=random.uniform(18,23);d=random.uniform(18,23);h=random.uniform(13,42)
   base_mat=[M["plaster"],M["brick"],M["concrete"],M["sand"]][i%4]
   b("RomanBuilding"+str(i),dx,h/2,dz,w,h,d,base_mat,.65)
   b("Roof"+str(i),dx,h+.55,dz,w+.7,1.0,d+.7,M["roof"],.2)
   front=dz+d/2+.08
   for floor in range(1,max(2,int(h/4.2))):
    wy=2.0+floor*3.8
    for col in (-.30,0,.30):
     b("Facade_Window",dx+col*w,wy,front,w*.17,1.4,.18,M["glass"],.04)
   if i%3==0:
    b("Shopfront_Glazing",dx,2.2,front+.08,w*.66,2.4,.20,M["glass"],.04)
    b("Shop_Awning",dx,3.8,front+.42,w*.72,.45,.8,M["red"] if i%2 else M["yellow"],.08)
  # The local road grid uses neutral concrete verges and asphalt centres.
  for road_idx in range(7):
   street_x=-90+road_idx*30
   cube("City_Street_V_%02d"%road_idx,(x+street_x,y+.42,z),(5.8,.20,226),M["asphalt"],c,.08)
   cube("City_Verge_V_%02d"%road_idx,(x+street_x,y+.30,z),(8.2,.16,226),M["concrete"],c,.04)
  for road_idx in range(6):
   street_z=-72.5+road_idx*29
   cube("City_Street_H_%02d"%road_idx,(x,y+.42,z+street_z),(240,.20,5.6),M["asphalt"],c,.08)
   cube("City_Verge_H_%02d"%road_idx,(x,y+.30,z+street_z),(240,.16,8.0),M["concrete"],c,.04)
 elif kind=="station":
  # Termini: long contemporary hall, glazed entrance, roof lanterns and six legible rail platforms.
  b("MainHall",0,13,0,145,26,55,M["plaster"],1)
  b("GlassFront",0,13,28,120,17,1,M["glass"])
  b("Roof",0,27,0,154,3,64,M["roof"])
  # Repeated structural bays and mullions break the single-box silhouette at overhead scale.
  for bx in range(-65,66,13):
   b("Hall_Facade_Pier_%d"%bx,bx,13,28.9,1.25,20,1.1,M["concrete"],.08)
  for bx in range(-54,55,18):
   b("Entrance_Glazing_Bay_%d"%bx,bx,12.5,29.15,15.5,14,.22,M["glass"],.05)
  # Raised roof lanterns with metallic frames and translucent glass strips.
  for lx in (-48,-24,0,24,48):
   b("Roof_Skylight_Frame_%d"%lx,lx,29.1,-1,17,.65,21,M["metal"],.12)
   b("Roof_Skylight_Glass_%d"%lx,lx,29.18,-1,14,.28,18,M["glass"],.08)
  # Entrance canopy, edge beams and evenly spaced support columns.
  b("Entrance_Canopy",0,22,34,128,1.3,15,M["metal"],.18)
  b("Entrance_Canopy_Glass",0,22.75,35,118,.25,12,M["glass"],.05)
  for cx in range(-58,59,14):
   b("Canopy_Support_%d"%cx,cx,16,39,.85,12,.85,M["metal"],.08)
  # Six platforms with roof trusses, platform edge safety stripe, sleepers and two rails per track.
  # Keep the six platforms outside the hall footprint; the previous inner pair clipped through the building.
  for pidx,pz in enumerate((-112,-82,-52,52,82,112)):
   b("Platform_%02d"%pidx,0,1,pz,170,2,13,M["concrete"],.18)
   b("Platform_Safety_Edge_%02d"%pidx,0,2.08,pz-5.3,168,.16,.48,M["yellow"],.03)
   b("Canopy_%02d"%pidx,0,10,pz,174,1,13,M["metal"],.12)
   b("Canopy_Ridge_%02d"%pidx,0,10.7,pz,174,.35,.55,M["concrete"],.04)
   for tx in range(-80,81,8):
    b("Sleeper_%02d_%d"%(pidx,tx),tx,2.45,pz-8,2.3,.32,1.05,M["wood"])
   for rz in (pz-2.0,pz+2.0):
    b("Track_Rail_%02d_%.1f"%(pidx,rz),0,2.72,rz,174,.42,.32,M["metal"],.05)
   for lx in range(-72,73,24):
    b("Platform_Light_Post_%02d_%d"%(pidx,lx),lx,6.1,pz, .35,8.2,.35,M["metal"],.06)
    b("Platform_Light_%02d_%d"%(pidx,lx),lx,10.35,pz,2.2,.3,1.0,M["white"],.08)
  # Track-end signals and service cabinets add scale and railway identity.
  for sx in (-88,88):
   b("Track_Signal_Pole_%d"%sx,sx,5,-48,.5,8,.5,M["metal"],.05)
   b("Track_Signal_Lamp_Red_%d"%sx,sx,8.7,-48,1.1,1.1,.6,M["red"],.08)
   b("Track_Signal_Lamp_Green_%d"%sx,sx,10,-48,1.1,1.1,.6,M["crop"],.08)
  for bx in (-45,45):
   b("Station_Service_Cabinet_%d"%bx,bx,2,42,5,3,3,M["metal"],.15)
 elif kind=="residential":
  for i in range(30):
   dx=(i%6)*25-62.5;dz=(i//6)*29-58;h=random.choice([7,9,12,16,18]);w=random.uniform(15,20);d=random.uniform(16,21)
   base_mat=[M["plaster"],M["brick"],M["sand"]][i%3]
   b("House"+str(i),dx,h/2,dz,w,h,d,base_mat,.45)
   b("Roof"+str(i),dx,h+.55,dz,w+.8,1.1,d+.8,M["roof"],.15)
   for floor in range(1,max(2,int(h/3.8))):
    for side in (-1,1):
     b("Window",dx+side*w*.25,1.9+floor*3.4,dz+d/2+.11,w*.16,1.15,.18,M["glass"],.035)
   if i%5==0:
    b("Balcony",dx,h*.63,dz+d/2+.5,w*.56,.22,.75,M["metal"],.04)
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
 scene=bpy.context.scene; world=bpy.data.worlds.new("AS_Sky") if not bpy.data.worlds else bpy.data.worlds[0];scene.world=world;world.use_nodes=True;world.node_tree.nodes["Background"].inputs["Color"].default_value=(.20,.31,.42,1);world.node_tree.nodes["Background"].inputs["Strength"].default_value=.75
 bpy.ops.object.light_add(type="SUN",location=(0,450,0));sun=bpy.context.object;sun.name="AS_Sun";sun.data.energy=4.0;sun.data.use_shadow=True;sun.rotation_euler=(math.radians(25),math.radians(-25),math.radians(-30));relink(sun,root)
 bpy.ops.object.camera_add(location=(0,2600,0),rotation=(math.radians(-90),0,0));cam=bpy.context.object;cam.name="AS_Overview_Camera";cam.data.type="ORTHO";cam.data.ortho_scale=2250;cam.data.clip_start=.1;cam.data.clip_end=10000;scene.camera=cam;relink(cam,root)
 try: scene.render.engine="BLENDER_EEVEE_NEXT"
 except: scene.render.engine="BLENDER_EEVEE"
 scene.render.resolution_x=1600;scene.render.resolution_y=1600;scene.render.resolution_percentage=100;scene.render.image_settings.file_format="PNG"
 try:
  scene.eevee.taa_render_samples=96
  scene.eevee.use_gtao=True
  scene.eevee.gtao_distance=18.0
  scene.eevee.gtao_factor=1.28
 except: pass
 try:
  scene.view_settings.view_transform="AgX"
  scene.view_settings.look="AgX - Medium High Contrast"
  scene.view_settings.exposure=.6
  scene.view_settings.gamma=1.0
 except:pass
 try:
  scene.render.image_settings.color_mode="RGBA"
  scene.render.film_transparent=False
  scene.eevee.taa_render_samples=64
 except:pass
 return cam
def glb_export(objects,path):
 bpy.ops.object.select_all(action="DESELECT"); valid=[]
 for o in objects:
  if o and o.name in bpy.data.objects: o.hide_set(False);o.select_set(True);valid.append(o)
 if not valid:return False
 bpy.context.view_layer.objects.active=valid[0]
 bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",use_selection=True,export_apply=True,export_cameras=False,export_lights=False,export_yup=False)
 bpy.ops.object.select_all(action="DESELECT")
 return path.exists() and path.stat().st_size>64
def export_tiles(terrain,outdir,rows):
 # Generate each tile from the same global height function on a 2.5m lattice.
 # Shared-edge coordinates are computed from each tile origin and the same exact step,
 # so adjacent tiles have matching seam vertices and a substantially cleaner shoreline.
 log("Generating 64 high-density terrain tile meshes on a shared 2.5m lattice")
 paths=[]; tile_segments=100; tile_vertices=tile_segments+1; step=TILE/float(tile_segments)
 for j in range(N):
  for i in range(N):
   x0=-1000+i*TILE; z0=-1000+j*TILE; x1=x0+TILE; z1=z0+TILE
   tv=[]; tf=[]; cols=[]; valid=[]
   for zz in range(tile_vertices):
    for xx in range(tile_vertices):
     wx=x0+xx*step; wz=z0+zz*step; ok=inside(wx,wz)
     valid.append(ok)
     tv.append((wx-x0,height(wx,wz) if ok else 0.0,wz-z0))
     cols.append(terrain_color(wx,wz,height(wx,wz)) if ok else (0.02,0.04,0.06))
   for zz in range(tile_segments):
    for xx in range(tile_segments):
     a=zz*tile_vertices+xx; b=a+1; c=a+tile_vertices; d=c+1
     if valid[a] and valid[b] and valid[c] and valid[d]:
      tf.extend([(a,c,b),(b,c,d)])
   tile_type="terrain_tile"
   if not tf:
    # Keep all 64 sectors represented. Empty land sectors carry a simple deep-ocean surface.
    tv=[(0,-0.8,0),(TILE,-0.8,0),(TILE,-0.8,TILE),(0,-0.8,TILE)]
    tf=[(0,2,1),(0,3,2)];cols=None;tile_type="water_tile"
   name="Tile_X%02d_Z%02d"%(i,j);col=collection("Export_"+name)
   tile=mesh(name,tv,tf,col,[M["deep"] if tile_type=="water_tile" else M["grass"]],colors=cols)
   if tile_type=="terrain_tile":
    for poly in tile.data.polygons: poly.use_smooth=True
   tile.location=(x0,0,z0);tile["tile_x"]=i;tile["tile_z"]=j;tile["world_origin_x"]=x0;tile["world_origin_z"]=z0;tile["kind"]=tile_type
   path=outdir/"tiles"/(name+".glb");path.parent.mkdir(parents=True,exist_ok=True);glb_export([tile],path);paths.append(path)
   rows.append([tile_type,name,str(path.relative_to(OUT)),i,j,x0,z0,x1,z1,"procedural original; 2.5m grid; estimated heights; verify transform once in Godot"])
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
 for name,cx,cz,count,ma in [
  ("Bosco_Ombra",227,-703,3000,M["forest"]),
  ("Colline_Verdi",-594,39,1450,M["hill"]),
  ("Bosco_Ripariale",-155,70,980,M["forest"]),
  ("Bosco_Sudoccidentale",-610,445,1150,M["forest"]),
  ("Macchia_Centrale",-315,115,700,M["hill"]),
  ("Bosco_Lago_Nord",-240,-475,420,M["forest"])
 ]:
  v=[];f=[];mi=[]
  for k in range(count):
   x=cx+random.uniform(-190,190);z=cz+random.uniform(-145,145)
   if not inside(x,z):continue
   forest_metric=((x-cx)/190.0)**2+((z-cz)/145.0)**2
   forest_edge=1.0+.095*math.sin(x*.031+z*.019)+.052*math.sin(z*.073-x*.041)
   if forest_metric>forest_edge:continue
   if forest_metric>.74 and random.random()<.23:continue
   # Keep canopy out of the lake, riverbed, station aprons and compact urban POIs.
   lake_metric=((x+94)/157.0)**2+((z+633)/120.0)**2
   if lake_metric<1.08:continue
   if abs(x-river_center_x(z))<30.0:continue
   urban=max(
    gauss(x,z,-297,-250,145,105),
    gauss(x,z,195,-242,125,90),
    gauss(x,z,703,-375,150,120),
    gauss(x,z,31,70,100,90),
    gauss(x,z,406,78,130,110),
    gauss(x,z,-766,-250,90,100)
   )
   if urban>0.42:continue
   y=height(x,z)
   if y>125.0 and name not in ("Colline_Verdi","Bosco_Lago_Nord"):continue
   r=random.uniform(2.8,6.4);h=random.uniform(8.5,20.5);base=len(v)
   # Low-poly trunk prism.
   v.extend([(x-r*.17,y,z-r*.17),(x+r*.17,y,z-r*.17),(x+r*.17,y,z+r*.17),(x-r*.17,y,z+r*.17),
             (x-r*.10,y+h*.43,z-r*.10),(x+r*.10,y+h*.43,z-r*.10),(x+r*.10,y+h*.43,z+r*.10),(x-r*.10,y+h*.43,z+r*.10)])
   f.extend([(base,base+3,base+2,base+1),(base+4,base+5,base+6,base+7),
             (base,base+1,base+5,base+4),(base+1,base+2,base+6,base+5),
             (base+2,base+3,base+7,base+6),(base+3,base,base+4,base+7)])
   mi.extend([0]*6)
   # Three stacked, triangulated foliage crowns; one mesh per biome keeps object count low.
   side_count=5+(k%5)
   crown_shape=(.78,.98,1.12,1.0,.86)[k%5]
   for tier in range(3):
    ring_base=len(v); base_y=y+h*(.28+tier*.205); radius=r*crown_shape*(1.08-tier*.19); peak_y=y+h*(.72+tier*.13)
    for side in range(side_count):
     ang=2*math.pi*side/side_count + (k%7)*.17 + tier*.035
     local_radius=radius*(.88+.12*math.sin(side*2.31+k*.37))
     v.append((x+local_radius*math.cos(ang),base_y,z+local_radius*math.sin(ang)))
    tip=len(v);v.append((x+math.sin(k*.13)*r*.08,peak_y,z+math.cos(k*.17)*r*.08))
    for side in range(side_count):
     f.append((ring_base+side,ring_base+(side+1)%side_count,tip));mi.append(1)
     if tier==0:
      f.append((base+4,ring_base+side,ring_base+(side+1)%side_count));mi.append(1)
  tree=mesh(name+"_TreeBatch",v,f,veg,[M["wood"],ma],mi)
  for poly in tree.data.polygons: poly.use_smooth=False
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
  rows.append(["poi_module",pid,str(path.relative_to(OUT)),"","",x,z,x,z,"procedural original; estimated concept coordinates"])
 # Manifest is persisted before render; a graphics-driver failure must not lose the inventory.
 manifest=OUT/"manifest.csv"
 with open(manifest,"w",newline="",encoding="utf-8") as f:
  w=csv.writer(f);w.writerow(["type","id","file","tile_x","tile_z","origin_x","origin_z","max_x","max_z","provenance"]);w.writerows(rows)
 log("Manifest written: %d assets"%len(rows))
 try:
  log("Exporting master preview GLB")
  # The runtime replaces these low-detail blockouts with existing detailed Godot scenes.
  detailed_poi_prefixes=("Città Centrale_","Stazione Termini_","Centro Commerciale_","Zona Industriale_","Quartiere Residenziale_")
  master_objects=[o for o in bpy.context.scene.objects
                  if o.type in {"MESH","CURVE"} and not o.name.startswith(detailed_poi_prefixes)]
  glb_export(master_objects,OUT/"AURORA_STRIKE_Master_Preview.glb")
 except Exception as e:log("Master GLB export warning: "+str(e))
 # Render last, after the source, tiles, POIs, master GLB, and manifest have been saved.
 scene=bpy.context.scene;scene.camera=camera;scene.render.filepath=str(OUT/"preview"/"aurora_strike_overview.png")
 try:
  log("Rendering 1600x1600 overview PNG")
  bpy.ops.render.render(write_still=True)
  overview=OUT/"preview"/"aurora_strike_overview.png"
  if overview.exists() and overview.stat().st_size>10000: log("Overview render complete: %s bytes"%overview.stat().st_size)
  else: log("Overview render returned without a usable image")
 except Exception as e:log("Overview render warning: "+str(e))
 log("FINISHED: %d terrain tiles and %d POIs in %s"%(len(tile_paths),len(poi_paths),OUT))
if __name__=="__main__":
 try:main()
 except Exception as e:log("FATAL: "+repr(e));raise
