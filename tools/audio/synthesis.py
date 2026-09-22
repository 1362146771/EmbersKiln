"""Deterministic, original procedural Foley. Python + NumPy; no sample downloads.

Modal resonators approximate clay/ceramic/metal, filtered granular noise provides
friction, ash, paper and combustion. These are designed effects, not recordings.
"""
import hashlib
import math
import numpy as np

RATE = 44100


class Sound:
    def __init__(self, seconds, seed):
        self.n = round(seconds * RATE)
        self.t = np.arange(self.n) / RATE
        self.x = np.zeros(self.n)
        self.rng = np.random.default_rng(seed)

    def noise(self, n, low=40, high=6000, color=0):
        f = np.fft.rfftfreq(n, 1 / RATE)
        shape = (1 - np.exp(-(f / max(low, 1)) ** 4)) / (1 + (f / high) ** 6)
        shape *= np.maximum(f, 45) ** (-color / 2)
        x = np.fft.irfft(np.fft.rfft(self.rng.normal(size=n)) * shape, n)
        return x / max(float(np.std(x)), 1e-8)

    def add(self, x, at=0, gain=1):
        start = max(0, round(at * RATE))
        n = min(len(x), self.n - start)
        if n > 0:
            self.x[start:start+n] += x[:n] * gain

    def burst(self, at=0, length=.2, low=100, high=5000, gain=.25, attack=.004, decay=6, swell=False):
        n = max(4, round(length * RATE))
        t = np.arange(n) / RATE
        if swell:
            env = np.maximum(0, np.sin(np.pi * np.arange(n) / (n-1))) ** 1.5
        else:
            env = np.minimum(1, t / attack) * np.exp(-decay * t / length)
        env *= np.minimum(1, (length-t) / .008)
        self.add(self.noise(n, low, high, .6) * env, at, gain)

    def mode(self, at=0, length=.4, freq=260, gain=.3, material='ceramic', decay=8):
        ratios = {
            'ceramic': [1, 1.477, 2.092, 2.583, 3.73, 5.12],
            'metal': [1, 1.414, 2.756, 4.07, 5.43, 6.79],
            'wood': [1, 2.13, 3.74, 5.1],
            'soft': [1, 1.51, 2.02],
            'bell': [1, 2.01, 2.76, 4.05, 5.41],
        }[material]
        t = np.arange(round(length * RATE)) / RATE
        x = np.zeros(len(t))
        for i, ratio in enumerate(ratios):
            f = freq * ratio * self.rng.uniform(.989, 1.011)
            x += np.sin(2*np.pi*f*t) * np.exp(-decay*(1+i*.17)*t/length) / (1+i)**1.35
        x *= np.minimum(1, t/.002) * np.minimum(1, (length-t)/.015)
        self.add(x, at, gain)

    def sweep(self, at=0, length=.35, start=150, end=60, gain=.2, decay=5):
        t = np.arange(round(length * RATE)) / RATE
        k = math.log(end/start) / length
        phase = 2*np.pi*start*np.expm1(k*t)/k if abs(k) > 1e-6 else 2*np.pi*start*t
        x = (np.sin(phase) + .18*np.sin(phase*2.03)) * np.exp(-decay*t/length)
        x *= np.minimum(1, t/.006) * np.minimum(1, (length-t)/.015)
        self.add(x, at, gain)

    def chips(self, at=0, span=.35, count=14, gain=.1, metal=False):
        for i in range(count):
            when = at + self.rng.uniform(0, span)
            f = self.rng.uniform(650, 2800) if metal else self.rng.uniform(380, 2300)
            a = gain * self.rng.uniform(.4, 1) * (1-(when-at)/(span*1.5))
            self.mode(when, self.rng.uniform(.05,.16), f, a, 'metal' if metal else 'ceramic', 6)
            self.burst(when, .025, 1600, 6500, a*.7)

    def impact(self, material='ceramic', at=0, scale=1):
        if material in ['ceramic','heavy_ceramic']:
            self.mode(at, .5*scale, 275/scale, .65, 'ceramic', 7)
            self.mode(at, .24, 93/scale, .45, 'soft', 7)
            self.burst(at, .14, 350, 4200, .45)
            self.chips(at+.022, .20*scale, 13, .15)
        elif material in ['stone','press']:
            self.sweep(at, .38*scale, 105, 47, .65)
            self.mode(at, .4, 173/scale, .38, 'wood')
            self.burst(at, .29*scale, 55, 2700, .6, decay=5)
            self.chips(at+.06, .30*scale, 18, .12)
        elif material=='metal':
            self.mode(at, .52, 360/scale, .5, 'metal', 5)
            self.mode(at, .21, 115, .35, 'soft')
            self.burst(at, .065, 900, 6700, .36)
        elif material in ['mud','sludge']:
            self.sweep(at, .26, 175/scale, 54, .55)
            self.burst(at, .24*scale, 65, 1800, .5, decay=5)
            for i in range(7):
                self.sweep(at+self.rng.uniform(.015,.19), .065, self.rng.uniform(230,650), 95, .08)
        elif material=='body':
            self.sweep(at, .22, 125, 51, .6)
            self.burst(at, .18, 90, 1600, .5)
            self.mode(at+.018,.16,230,.14,'ceramic')
        elif material=='ash':
            self.burst(at,.30*scale,180,4400,.6,decay=4)
            self.sweep(at,.2,140,65,.25)
            self.chips(at,.15,6,.05)
        elif material=='wood':
            self.mode(at,.25,195/scale,.7,'wood',9)
            self.burst(at,.07,180,2600,.24)

    def fire(self, at=0, length=.7, gain=1):
        self.burst(at,length,45,2600,.36*gain,attack=.026,decay=3)
        self.burst(at+.03,length*.8,400,6800,.19*gain,attack=.015,decay=3.5)
        self.chips(at+.025,length*.72,max(5,int(length*22)),.055*gain)
        self.sweep(at,length*.7,95,44,.24*gain,3)

    def air(self, at=0, length=.45, gain=.4, low=180, high=3800):
        self.burst(at,length,low,high,gain,swell=True)

    def shimmer(self, notes=(300,450,600), at=0, step=.10, gain=.25, material='bell', length=.65):
        for i, f in enumerate(notes):
            self.mode(at+i*step,length,f,gain,material,4.5)


def render(cue, variant):
    seed = int.from_bytes(hashlib.sha256(f"kiln-sfx-v1/{cue['id']}/{variant}".encode()).digest()[:8], 'little')
    s = Sound(cue['seconds'], seed)
    r, d, p = cue['recipe'], cue['seconds'], cue['params']
    scale = p.get('size', 1) * s.rng.uniform(.94, 1.06)
    if r=='ambience':
        return ambience(s, p['material'], cue['level_dbfs'])
    if r in ['ceramic','stone','metal','mud','body','ash','wood','heavy_ceramic','sludge','press']:
        s.impact(r, scale=scale*(1.5 if r in ['heavy_ceramic','press'] else 1))
        if r=='heavy_ceramic': s.impact('stone', .018, 1.25)
        if r=='sludge': s.burst(.04,d*.8,180,2300,.25,decay=2.5)
        if r=='press': s.air(.04,d*.85,.25,90,2200)
    elif r in ['tap','confirm','cancel','deny','turn','end_turn']:
        f = {'tap':580,'confirm':530,'cancel':410,'deny':185,'turn':290,'end_turn':320}[r]
        s.mode(0, d*.9, f, .6, 'wood' if r in ['tap','deny'] else 'ceramic')
        s.burst(0,.045,400,3600,.16)
        if r in ['confirm','turn']:
            s.mode(d*.25,d*.65,f*1.48,.32,'ceramic',5)
        if r=='deny': s.mode(.095,.13,145,.4,'wood')
        if r=='cancel':s.burst(.035,.1,100,2000,.16)
    elif r in ['paper','paper_cast','shuffle','cloth']:
        count = 8 if r=='shuffle' else 2
        for i in range(count):
            at = i*d/(count+1)
            length = min(d-at,.13 if r=='shuffle' else d*.66)
            s.burst(at,length,550 if r!='cloth' else 110,7200 if r!='cloth' else 2600,.42,attack=.015,decay=3)
            if r!='cloth': s.mode(at,.05,160+s.rng.uniform(0,120),.10,'wood')
        if r=='paper_cast':s.air(.035,d*.8,.25,220,5200)
    elif r in ['whoosh','claw','stab','flame_slash','reap']:
        # Generic swing is pre-hit; enemy attack cues contain an immediate impact.
        if r=='whoosh':
            s.air(0,d*.94,.72,100/scale,4200/scale)
            s.sweep(d*.22,d*.65,165/scale,75/scale,.15,1)
        else:
            s.burst(0,.085,450,6500,.6)
            s.impact('ceramic' if r=='claw' else 'body',scale=.8)
            s.air(.025,d*.60,.38,300,5700)
            if r=='flame_slash':s.fire(.02,d*.85,.8)
            if r=='reap':
                s.air(.1,d*.75,.45,120,1800)
                s.shimmer((240,358),.32,.14,.16,length=.6)
    elif r in ['burn','fire','eruption','crackle','heat','embers','ash_burst','dark_burst']:
        s.fire(0,d*.93,1)
        if r in ['eruption','dark_burst']:
            s.impact('stone',scale=1.4)
            s.burst(.02,d*.8,35,950,.45,decay=4)
        if r=='dark_burst':s.shimmer((77,113,169),0,.02,.30,'metal',d*.9)
        if r=='burn':s.burst(0,d*.7,1600,6900,.28,decay=3)
        if r=='heat':s.mode(0,d,155,.28,'ceramic',3)
        if r=='embers':s.shimmer((392,587,784),.09,.14,.18,length=.6)
        if r=='ash_burst':s.burst(0,d*.7,240,4800,.42,decay=3)
    elif r in ['shatter','fracture','shard','collapse','boss_collapse']:
        if r in ['collapse','boss_collapse']:
            s.burst(0,d*.55,120,1600,.20,decay=1.5)
            s.impact('wood', .26,1.3)
            s.impact('ceramic', .68 if r=='collapse' else .4,1.25)
            s.chips(.74 if r=='collapse' else .5,d*.35,26,.13)
            if r=='boss_collapse':s.impact('stone',.15,2)
        else:
            s.impact('ceramic',scale=.85 if r=='shard' else 1)
            s.chips(.015,d*.65,8 if r=='shard' else 30,.14)
            if r=='fracture':s.air(.04,d*.65,.17,180,2100)
    elif r in ['shield','seal','chain_seal']:
        s.mode(0,d*.85,210/scale,.65,'ceramic',5)
        s.mode(.015,d*.8,540/scale,.25,'metal',6)
        s.burst(0,.16,80,2100,.3)
        if r in ['seal','chain_seal']:
            s.burst(.04,d*.68,70,1700,.3,decay=2)
            s.impact('wood',d*.34,.75)
        if r=='chain_seal':
            for i in range(5):s.mode(i*.045,.22,630+i*90,.16,'metal')
            s.burst(.13,.48,350,2600,.22)
    elif r in ['skill','power','strength','awaken','charge','summon','hex','weak','decay','soul']:
        base = dict(skill=290,power=130,strength=110,awaken=73,charge=95,summon=105,hex=156,weak=195,decay=143,soul=320)[r]
        s.burst(0,d*.88,70,2000,.21,attack=.02,decay=2.4)
        for i, ratio in enumerate([1,1.49,2.07]):
            s.mode(i*.025,d*.92,base*ratio,.34/(i+1),'metal' if r in ['hex','decay','soul'] else 'ceramic',3.8)
        if r in ['power','strength','awaken','summon']:s.impact('stone',0,.8)
        if r in ['charge','awaken']:s.air(.05,d*.85,.4,85,1450)
        if r=='summon':s.chips(.12,.5,16,.09)
        if r in ['weak','decay']:s.sweep(0,d*.8,280,86,.19,2)
        if r=='decay':s.burst(.08,d*.7,1000,4500,.16,decay=2)
        if r=='soul':s.burst(0,.12,550,4800,.3)
    elif r in ['air','vent','wing']:
        if r=='wing':
            for i in range(3):s.air(i*.16,.24,.4,180,2800)
        else:
            s.air(0,d*.97,.7,95,4200 if r=='vent' else 2800)
            if r=='vent':s.mode(0,d*.7,110,.16,'soft',3)
    elif r in ['heal','energy','cleanse','acquire','copy','recover','ready','research','enchant','blessing','relic','victory','triumph','rebirth','defeat']:
        notes = {
            'heal':(330,440,660), 'energy':(392,588), 'cleanse':(280,420,840),
            'acquire':(392,523), 'copy':(460,690), 'recover':(294,440),
            'ready':(349,523,698), 'research':(294,392,587), 'enchant':(220,330,494),
            'blessing':(262,392,524), 'relic':(294,440,587),
            'victory':(196,294,392,588), 'triumph':(147,220,294,440,588),
            'rebirth':(147,220,330,440), 'defeat':(220,164,110),
        }[r]
        s.shimmer(notes,0,min(.16,d*.16),.3,'ceramic' if r in ['copy','recover'] else 'bell',min(1.3,d*.75))
        s.air(.015,d*.90,.10,200,2400)
        if r in ['enchant','rebirth']:s.fire(0,d*.8,.34)
        if r in ['relic','victory','triumph']:s.mode(0,d*.8,98,.25,'wood',5)
        if r=='research':s.burst(0,.22,700,5000,.17,attack=.01,decay=3)
        if r=='defeat':s.burst(0,d*.8,60,700,.12,decay=2)
    elif r in ['coins','bottle','uncork','splash']:
        if r=='coins':
            for i in range(8):s.mode(i*d*.065,.2,s.rng.uniform(1200,2100),.2,'metal',8)
            s.burst(d*.35,.16,300,2300,.14)
        elif r=='bottle':s.shimmer((720,1080),0,.075,.43,'ceramic',.3)
        elif r=='uncork':
            s.sweep(0,.09,480,140,.4)
            s.burst(0,.06,130,3200,.27)
            s.mode(.07,.22,930,.18,'ceramic')
            for i in range(6):s.sweep(.13+i*.03,.065,350+i*55,750+i*55,.06)
        else:
            s.burst(0,d*.85,200,5400,.5,decay=4)
            for i in range(18):s.sweep(s.rng.uniform(.01,d*.55),.075,s.rng.uniform(400,1400),180,.085)
    elif r in ['forge','hammer','chest','step','rope','gate','battle']:
        if r in ['forge','hammer']:
            for i in range(3):
                at=i*.19
                s.impact('metal',at,1.1)
                s.impact('wood',at,.8)
            if r=='forge':s.shimmer((330,494),.43,.10,.22,length=.7)
        elif r=='chest':
            s.burst(0,.52,80,1400,.3,decay=1.7)
            s.mode(.08,.34,140,.4,'wood')
            s.impact('metal',.31,1.3)
            s.impact('wood',.55,1.2)
        elif r=='step':
            s.impact('wood',0,1.2)
            s.burst(.015,.19,380,3500,.33)
        elif r=='rope':
            s.burst(0,.12,250,4000,.6)
            s.sweep(0,.16,230,70,.28)
            s.mode(.014,.16,510,.17,'ceramic')
        elif r=='gate':
            s.burst(0,d*.85,45,1300,.4,attack=.05,decay=1.8)
            s.mode(.04,d*.8,85,.3,'metal',2)
            s.impact('stone',.85,1.4)
        else:
            s.impact('stone',0,1.3)
            s.mode(.02,d*.9,153,.36,'metal',4)
            s.fire(.03,d*.75,.25)
    elif r=='bite':
        s.impact('wood',0,.75)
        s.impact('mud',.012,.65)
        s.chips(.008,.12,8,.14)
    else:
        raise ValueError(f'Unknown synthesis recipe: {r}')
    # Dry, short early reflections preserve transients; avoid long fantasy tails.
    x = s.x.copy()
    for delay, gain in [(0.019,.07),(.037,.045),(.061,.025)]:
        k = round(delay*RATE)
        if k<len(x):x[k:] += s.x[:-k]*gain
    return finish(x,cue['level_dbfs'],False)


def finish(x, level, loop):
    x = x - np.mean(x,axis=0)
    if not loop:
        fade_in = min(round(.002*RATE),len(x)//4)
        fade_out = min(round(.025*RATE),len(x)//4)
        x[:fade_in] *= np.linspace(0,1,fade_in)
        x[-fade_out:] *= np.linspace(1,0,fade_out)
        # Fades can introduce a tiny DC bias. Remove it without lifting endpoints.
        dc_window = np.sin(np.pi*np.arange(len(x))/(len(x)-1))**2
        x -= np.mean(x)*dc_window/np.mean(dc_window)
    rms = float(np.sqrt(np.mean(x*x)))
    x *= 10**(level/20)/max(rms,1e-9)
    # Peak cap is a single linear gain, not clipping/limiting the transient.
    peak = float(np.max(np.abs(x)))
    x *= min(1,.79/max(peak,1e-9))
    return x


def ambience(s, material, level):
    # Every noise bed is FFT-periodic. Granules wrap around the loop boundary.
    n, t = s.n, s.t
    period = n/RATE
    out=[]
    for channel in range(2):
        low = s.noise(n,45,650,1.2)*.35
        air = s.noise(n,220,3500,1)*.10
        mod = .72+.16*np.sin(2*np.pi*2*t/period+channel*.55)+.10*np.sin(2*np.pi*5*t/period)
        x=(low+air)*mod
        if material in ['kiln','deep']:
            for hz,gain in [(61,.09),(97,.05),(143,.03)]:
                cycles=round(hz*period)
                x+=gain*np.sin(2*np.pi*cycles*t/period)*(.75+.2*np.sin(2*np.pi*t/period))
        if material in ['fire','camp','kiln','town']:
            count={'fire':65,'camp':42,'kiln':24,'town':12}[material]
            for _ in range(count):
                start=int(s.rng.integers(n))
                g=Sound(.075,int(s.rng.integers(2**32)))
                g.burst(0,.060,800,6500,s.rng.uniform(.13,.5))
                g.mode(0,.055,s.rng.uniform(350,1400),.10,'wood')
                np.add.at(x,(start+np.arange(g.n))%n,g.x)
        if material=='town':
            for at in [1.8,5.4,9.3]:
                g=Sound(.34,int(s.rng.integers(2**32)))
                g.mode(0,.3,430,.16,'metal')
                np.add.at(x,(round((at+.035*channel)*RATE)+np.arange(g.n))%n,g.x)
        if material in ['wind','ash']:
            x+=s.noise(n,500,4700,.7)*(.08+.065*np.sin(2*np.pi*3*t/period+channel))
        if material=='ash':
            for at in [2.1,6.7,10.5]:
                g=Sound(.7,int(s.rng.integers(2**32)))
                g.burst(0,.7,160,1700,.15,attack=.07,decay=2)
                np.add.at(x,(round(at*RATE)+np.arange(g.n))%n,g.x)
        # Match value and first difference over a gentle 8ms boundary repair.
        k=round(.008*RATE)
        u=np.linspace(0,1,k)
        delta=x[0]-x[-1]
        x[-k:]+=delta*(u*u*(3-2*u))
        out.append(x)
    # Correlated low bed keeps mobile mono downmix stable; no phase inversion.
    stereo=np.column_stack(out)
    mid=np.mean(stereo,axis=1)
    stereo=mid[:,None]*.72+stereo*.28
    return finish(stereo,level,True)
