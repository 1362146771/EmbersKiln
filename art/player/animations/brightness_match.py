"""Match source-batch exposure using the same neutral pose; never move pixels.

Only HSV value changes: RGB channels share one multiplier, retaining hue,
saturation, alpha and all pose geometry. Calibrate before adding the shared axe.
"""
import numpy as np
from PIL import Image


def match_brightness(image, neutral, reference):
    def samples(pose):
        pixels = np.asarray(pose)
        return pixels[:, :, :3].max(axis=2)[pixels[:, :, 3] > 250] / 255.0

    quantiles = np.linspace(25, 75, 11)
    source = np.quantile(samples(neutral), quantiles / 100)
    target = np.quantile(samples(reference), quantiles / 100)
    # A smooth exposure correction avoids histogram matching's abrupt slopes,
    # which can exaggerate tiny source gradients into noisy highlight bands.
    gain = float(np.median(target / np.maximum(source, 1 / 255)))
    pixels = np.array(image)
    rgb = pixels[:, :, :3].astype(np.float64) / 255
    value = rgb.max(axis=2)
    # Preserve bright neutral ceramic highlights; colored skin/leather still
    # receives exposure correction. One multiplier retains RGB proportions.
    highlight = np.clip((rgb.min(axis=2) - 0.65) / 0.30, 0, 1)
    highlight = highlight * highlight * (3 - 2 * highlight)
    shoulder = np.clip((value - 0.55) / 0.40, 0, 1)
    shoulder = shoulder * shoulder * (3 - 2 * shoulder)
    protection = np.maximum(highlight, shoulder * 0.70)
    ratio = gain + (1 - gain) * protection
    ratio = np.minimum(ratio, np.divide(1, value, out=np.ones_like(value), where=value > 0))
    pixels[:, :, :3] = np.rint(rgb * ratio[:, :, None] * 255).clip(0, 255).astype(np.uint8)
    assert np.array_equal(pixels[:, :, 3], np.asarray(image)[:, :, 3])
    return Image.fromarray(pixels)
