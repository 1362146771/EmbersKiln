"""Color-only material calibration to the shipped portrait, with immutable alpha.

Source pixels and pose geometry are never regenerated or resampled here.
Calibration patches identify midtones; smooth palette weights retain shading.
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
MATERIALS = ['skin','shirt','apron','pants','leather','boots','ceramic','metal','hair']
REFERENCE = [(372,480),(520,600),(480,830),(455,1070),(623,873),
             (452,1260),(543,267),(321,770),(417,354)]
SAMPLES = {
 'neutral': [(254,287),(312,342),(300,450),(267,543),(370,460),(246,665),(340,204),(218,410),(287,227)],
 'twist': [(387,326),(344,364),(356,477),(293,527),(426,477),(239,670),(412,244),(491,390),(343,269)],
 'recovery': [(379,353),(346,385),(350,480),(295,538),(421,486),(250,654),(431,273),(451,460),(370,264)],
 'return': [(259,291),(313,338),(317,438),(260,535),(371,463),(244,667),(348,211),(410,400),(287,222)],
 'hurt': [(225,277),(270,314),(270,421),(304,515),(328,439),(237,654),(294,207),(198,390),(247,222)],
}


def patches(image, points, radius=5):
    a=np.asarray(image.convert('RGBA'))
    values=[]
    for x,y in points:
        patch=a[y-radius:y+radius+1,x-radius:x+radius+1]
        pixels=patch[:,:,:3][patch[:,:,3]>250]
        assert len(pixels), (x,y)
        values.append(np.median(pixels,axis=0)/255)
    return np.array(values)


def palette(image, calibration, group):
    reference=Image.open(ROOT.parent/'SPR_Player_Tannaro.png').convert('RGBA')
    target=patches(reference,REFERENCE,8)
    source=patches(calibration,SAMPLES[group])
    # Keep black ink fixed. Color ratios preserve within-material drawing detail.
    source=np.vstack([source,[.025,.022,.020]])
    target=np.vstack([target,[.025,.022,.020]])
    a=np.array(image.convert('RGBA')); rgb=a[:,:,:3].astype(float)/255
    yy=np.indices(a.shape[:2])[0]
    gains=target/np.maximum(source,.02)
    gains[8]=np.clip(gains[8],.80,1.12)
    numerator=np.zeros_like(rgb); denominator=np.zeros(a.shape[:2])
    def ramp(value, low, high):
        t=np.clip((value-low)/(high-low),0,1)
        return t*t*(3-2*t)
    for k,center in enumerate(source):
        weight=1/(np.mean((rgb-center)**2,axis=2)+.012)**2
        name=MATERIALS[k] if k<len(MATERIALS) else 'ink'
        if name=='boots': weight*=ramp(yy,535,580)
        if name=='skin': weight*=1-ramp(yy,515,555)
        if name=='hair': weight*=1-ramp(yy,290,335)
        if name=='shirt': weight*=ramp(yy,225,260)*(1-ramp(yy,420,460))
        if name=='apron': weight*=ramp(yy,330,380)*(1-ramp(yy,540,580))
        if name=='pants': weight*=ramp(yy,470,510)*(1-ramp(yy,575,620))
        numerator+=weight[:,:,None]*gains[k]
        denominator+=weight
    gain=numerator/denominator[:,:,None]
    # Boots share skin hues in some batches. Their material is unambiguous below
    # the knees: use one smooth transform rather than competing skin/bag colors.
    warm=ramp(rgb[:,:,0]-rgb[:,:,2],.025,.10)
    boot_weight=ramp(yy,535,580)*warm
    gain=gain*(1-boot_weight[:,:,None])+gains[5]*boot_weight[:,:,None]
    corrected=np.clip(rgb*gain,0,1)
    # Remove only magenta key spill RGB; leave even subpixel alpha untouched.
    spill=(rgb[:,:,0]>rgb[:,:,1]+.08)&(rgb[:,:,2]>rgb[:,:,1]+.08)
    corrected[:,:,0][spill]=np.minimum(corrected[:,:,0],corrected[:,:,1]+.02)[spill]
    corrected[:,:,2][spill]=np.minimum(corrected[:,:,2],corrected[:,:,1]+.02)[spill]
    a[:,:,:3]=np.rint(corrected*255).astype(np.uint8)
    assert np.array_equal(a[:,:,3],np.asarray(image)[:,:,3])
    return Image.fromarray(a)


def attack_palette(frames):
    calibration={'neutral':frames[0],'twist':frames[2],'recovery':frames[4],'return':frames[6]}
    groups=['neutral','neutral','twist','twist','recovery','recovery','return','neutral']
    return [palette(frame,calibration[group],group) for frame,group in zip(frames,groups)]


def export_hurt():
    source=ROOT/'palette_source'
    originals={i:Image.open(source/f'hurt-{i}.png').convert('RGBA') for i in (1,3,5,8)}
    corrected={i:palette(im,originals[1],'hurt') for i,im in originals.items()}
    order=[1]*2+[3]*2+[5]*3+[8]*4+[5]*5+[3]*5+[1]*9
    frames=[corrected[i] for i in order]
    out=ROOT/'hurt'; atlases=[Image.new('RGBA',(2304,3840)) for _ in range(2)]
    sheet=Image.new('RGBA',(4608,3840)); contact=Image.new('RGB',(1152,960),'#272831')
    preview=[]
    for i,frame in enumerate(frames):
        frame.save(out/f'hurt-{i+1}.png')
        atlases[i//15].paste(frame,((i%15%3)*768,(i%15//3)*768))
        sheet.paste(frame,((i%6)*768,(i//6)*768))
        thumb=frame.resize((192,192),Image.Resampling.LANCZOS)
        contact.paste(thumb,((i%6)*192,(i//6)*192),thumb)
        ImageDraw.Draw(contact).text(((i%6)*192+5,(i//6)*192+5),str(i+1),fill='white')
        small=frame.resize((384,384),Image.Resampling.LANCZOS)
        bg=Image.new('RGB',small.size,'#272831'); bg.paste(small,mask=small.getchannel('A')); preview.append(bg)
    for i,atlas in enumerate(atlases): atlas.save(out/f'atlas-hd-{i+1}.png')
    sheet.save(out/'sheet-transparent.png'); contact.save(out/'contact.png')
    frames[0].save(out/'animation.png',save_all=True,append_images=frames[1:],duration=1000/30,loop=0,disposal=0,blend=0)
    frames[0].save(out/'animation.gif',save_all=True,append_images=frames[1:],duration=[30,30,40]*10,loop=0,disposal=2,optimize=False)
    preview[0].save(out/'preview.gif',save_all=True,append_images=preview[1:],duration=[30,30,40]*10,loop=0)
