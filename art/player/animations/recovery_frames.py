"""Register generated recovery drawings and reuse the accepted rigid axe."""
from PIL import Image, ImageDraw, ImageChops
from hd_anchors import right_foot
from generate2dsprite import connected_components
from brightness_match import match_brightness

def isolate(image):
    probe=image.copy()
    probe.putalpha(image.getchannel('A').point(lambda a: 255 if a>96 else 0))
    box=connected_components(probe)[0]['bbox']
    out=Image.new('RGBA',image.size)
    out.paste(image.crop(box),box[:2])
    return out

def build_recovery(root, clean, master, body_scale, neutral_reference):
    source=clean(Image.open(root/'attack5_source/recovery-upright-raw.png'))
    w,h=source.size
    half=w//2
    # One calibration for the entire source sheet, based on its neutral pose.
    neutral=isolate(source.crop((half,h//2,w,h)))
    source=match_brightness(source, neutral, neutral_reference)
    bounds=neutral.getbbox()
    scale=545/(bounds[3]-bounds[1])
    grips=[(448,366),(1066,365),(272,974)]
    hands=[[(416,383),(439,380),(457,404),(451,424),(430,428),(413,411)],
           [(1030,365),(1046,357),(1067,369),(1078,387),(1062,403),(1042,404),(1029,389)],
           [(250,954),(274,948),(295,970),(292,990),(273,1002),(250,990)]]
    # Raised blade at impact (-65/-75), then continuous lowering to idle (-167).
    angles=[-92,-115,-142]
    hands[0]=[(x+14,y-36) for x,y in hands[0]]
    hands[1]=[(x+16,y-18) for x,y in hands[1]]
    frames=[]; metrics=[]
    for i in range(3):
        x,y=(i%2)*half,(i//2)*(h//2)
        box=(x,y,x+half,y+h//2)
        pose=isolate(source.crop(box))
        # Same final weapon size as original attack; no per-frame weapon scaling.
        weapon=master.resize((round(512*body_scale/scale),)*2,Image.Resampling.LANCZOS)
        center=weapon.width//2
        weapon=weapon.rotate(angles[i],Image.Resampling.BICUBIC,center=(center,center))
        pose.alpha_composite(weapon,(grips[i][0]-x-center,grips[i][1]-y-center))
        mask=Image.new('L',source.size)
        ImageDraw.Draw(mask).polygon(hands[i],fill=255)
        hand=source.copy(); hand.putalpha(ImageChops.multiply(source.getchannel('A'),mask))
        pose.alpha_composite(hand.crop(box))
        pose=pose.resize(tuple(round(v*scale) for v in pose.size),Image.Resampling.LANCZOS)
        foot=right_foot(pose)
        delta=(round(240-foot[0]),round(700-foot[1]))
        b=pose.getbbox()
        assert b[0]+delta[0]>0 and b[1]+delta[1]>0 and b[2]+delta[0]<768 and b[3]+delta[1]<768
        frame=Image.new('RGBA',(768,768)); frame.alpha_composite(pose,delta)
        measured=right_foot(frame)
        error=max(abs(measured[0]-240),abs(measured[1]-700))
        assert error<=1
        frames.append(frame)
        metrics.append(dict(source='attack5_source/recovery-upright-raw.png',source_cell=i,shared_scale=scale,right_foot=measured,anchor_error_px=error,weapon_angle_degrees=angles[i],bbox=frame.getbbox()))
    return frames,metrics
