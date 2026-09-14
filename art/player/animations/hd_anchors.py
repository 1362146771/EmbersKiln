"""Measure the anatomical left boot (screen right), without altering poses."""
import numpy as np

def left_foot(image):
    return _foot(image, True)


def right_foot(image):
    return _foot(image, False)


def _foot(image, screen_right):
    mask = np.asarray(image.getchannel('A')) > 96
    ys, xs = np.where(mask)
    bottom = int(ys.max()) + 1
    start = bottom - max(12, round((bottom-int(ys.min())) * 0.13))
    band = mask[start:bottom]
    rgb = np.asarray(image.convert('RGB'), dtype=float)[start:bottom]
    leather = band & (rgb[:,:,0] > rgb[:,:,1]*1.12) & (rgb[:,:,0] > rgb[:,:,2]*1.25)
    occupied = np.any(leather, axis=0)
    spans = []
    first = None
    for x, active in enumerate(list(occupied)+[False]):
        if active and first is None:
            first = x
        elif not active and first is not None:
            if int(band[:, first:x].sum()) >= 12:
                spans.append((first, x))
            first = None
    if len(spans) < 2:
        # Restrict to screen-right half if cuffs still connect at this height.
        middle = int((xs.min()+xs.max())/2)
        spans = [(middle, int(xs.max())+1)] if screen_right else [(int(xs.min()), middle)]
    spans = sorted(spans, key=lambda s: int(leather[:,s[0]:s[1]].sum()), reverse=True)[:2]
    x0, x1 = (max if screen_right else min)(spans, key=lambda s: s[0])
    x0, x1 = max(0,x0-2), min(mask.shape[1],x1+2)
    py, px = np.where(band[:, x0:x1])
    sole_y = int(py.max()) + start + 1
    sole_xs = px[py >= py.max()-2] + x0
    return (float(np.median(sole_xs)), float(sole_y))
