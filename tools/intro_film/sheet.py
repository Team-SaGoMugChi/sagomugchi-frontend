import sys,glob
from PIL import Image,ImageDraw
fs=sorted(glob.glob(sys.argv[1]+'_*.jpg'),key=lambda f:float(f.rsplit('_',1)[1][:-4]))
w,h=270,480;cols=min(len(fs),6);rows=(len(fs)+cols-1)//cols
S=Image.new('RGB',(cols*w,rows*(h+30)),'white');d=ImageDraw.Draw(S)
for i,f in enumerate(fs):
  im=Image.open(f).resize((w,h));x,y=(i%cols)*w,(i//cols)*(h+30);S.paste(im,(x,y+30));d.text((x+8,y+8),f.rsplit('_',1)[1][:-4]+'s',fill='black')
S.save(sys.argv[2])
