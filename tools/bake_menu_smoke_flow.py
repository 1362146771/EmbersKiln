"""Bake a DATA texture from authored upward smoke paths, without editing the art.

Flow RG stores pixel-space tangent. Path UV uses RG as a 16-bit longitudinal
coordinate and B as the cross-stream coordinate. Extra longitudinal precision
avoids block patterns when sampling the detail texture over long curved paths.
Coordinates below are in the 941 x 1672 source illustration's pixel space.
"""
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = np.array([941.0, 1672.0])
SIZE = (471, 836)
PATHS = [
    # Foreground ribbon: lower left -> front of tower -> upper right -> behind.
    [(285, 1720), (145, 1590), (55, 1460), (20, 1340), (57, 1220),
     (118, 1144), (268, 1130), (427, 1103), (544, 1060), (580, 1005),
     (540, 965), (453, 934), (383, 879)],
    # Middle ribbon returns across the front to the left as it rises.
    [(377, 740), (435, 657), (455, 568), (435, 482), (379, 426),
     (286, 394), (178, 388), (83, 362), (-45, 312)],
    # Upper ring travels up the right side and around the chimney crown.
    [(434, 390), (533, 332), (604, 247), (632, 161), (608, 104),
     (540, 61), (454, 33), (359, 12), (290, -45)],
    # Left side of the crown also rises, then merges above the image.
    [(181, 217), (135, 162), (143, 110), (187, 66), (237, 34), (290, -45)],
    # Distant strands on the right, deliberately slower in the shader's matte.
    [(948, 1565), (877, 1430), (815, 1329), (694, 1285), (555, 1237), (460, 1215)],
    [(925, 755), (898, 635), (869, 514), (815, 446), (770, 403)],
]


def sample_path(points):
    """Centripetal-looking cubic Hermite tangents, clamped to avoid y reversal."""
    p = np.array(points, dtype=np.float32)
    tangents = np.empty_like(p)
    tangents[0], tangents[-1] = p[1] - p[0], p[-1] - p[-2]
    tangents[1:-1] = (p[2:] - p[:-2]) * 0.5
    result = []
    for i in range(len(p) - 1):
        # Monotone y interpolation. No return swing or downward tangent.
        dy = p[i + 1, 1] - p[i, 1]
        m0, m1 = tangents[i].copy(), tangents[i + 1].copy()
        m0[1] = max(3.0 * dy, min(0.0, m0[1]))
        m1[1] = max(3.0 * dy, min(0.0, m1[1]))
        for t in np.linspace(0.0, 1.0, 20, endpoint=False):
            result.append((2*t**3-3*t**2+1)*p[i] + (t**3-2*t**2+t)*m0
                          + (-2*t**3+3*t**2)*p[i+1] + (t**3-t**2)*m1)
    return np.array(result + [p[-1]], dtype=np.float32)


def main():
    y, x = np.mgrid[:SIZE[1], :SIZE[0]]
    pixels = np.stack(((x+.5)*SOURCE[0]/SIZE[0], (y+.5)*SOURCE[1]/SIZE[1]), axis=-1)
    best = np.full((SIZE[1], SIZE[0]), np.inf)
    data = np.zeros((SIZE[1], SIZE[0], 4), dtype=np.float32)
    for points in PATHS:
        path = sample_path(points)
        edges = np.diff(path, axis=0)
        lengths = np.linalg.norm(edges, axis=1)
        cumulative = np.concatenate(([0.0], np.cumsum(lengths)))
        # Align the upper paths at their shared end, avoiding a phase seam.
        offset = 1800.0 - cumulative[-1]
        for i, (a, edge, length) in enumerate(zip(path[:-1], edges, lengths)):
            relative = pixels - a
            t = np.clip(np.sum(relative*edge, axis=-1)/(length*length), 0.0, 1.0)
            separation = relative - t[..., None]*edge
            distance = np.sum(separation*separation, axis=-1)
            selected = distance < best
            tangent = edge / length
            side = separation[..., 0]*(-tangent[1]) + separation[..., 1]*tangent[0]
            best[selected] = distance[selected]
            data[selected, 0] = tangent[0]*.5+.5
            data[selected, 1] = tangent[1]*.5+.5
            data[selected, 2] = (offset + cumulative[i] + t[selected]*length)/2048.0
            data[selected, 3] = np.clip(.5 + side[selected]/256.0, 0.0, 1.0)
    out = ROOT/'art/ui/main_menu/SmokeFlow.png'
    Image.fromarray(np.uint8(np.clip(data[..., :3], 0, 1)*255+.5), 'RGB').save(out)
    longitudinal = np.uint16(np.clip(data[..., 2], 0, 1)*65535+.5)
    uv = np.stack((longitudinal >> 8, longitudinal & 255,
                   np.uint16(np.clip(data[..., 3], 0, 1)*255+.5)), axis=-1).astype(np.uint8)
    Image.fromarray(uv, 'RGB').save(out.with_name('SmokePathUV.png'))
    assert (data[..., 1] <= .501).all(), 'Flow must never point down'
    print(f'Baked {out.name}: {SIZE}, {len(PATHS)} upward paths')


if __name__ == '__main__':
    main()
