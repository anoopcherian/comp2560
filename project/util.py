"""Miscellaneous utility functions (i.e. stuff not specific to this project,
and which doesn't fit in anywhere else)."""

from datetime import datetime
from random import randint
from struct import pack

import numpy as np

from errno import EEXIST
from os import makedirs, path


def create_dirs(dest, mode=0777):
    """Mimics mkdir -p."""
    try:
        makedirs(dest, mode)
    except OSError as e:
        if e.errno != EEXIST or not path.isdir(dest):
            raise e


def unique_key():
    """Return a base64-encoded key of ~10 characters; attempts to be unique.
    Useful for writing databases."""
    time_bits = 48
    random_bits = 16
    # Everything needs to be packed into 64 bits
    assert time_bits + random_bits == 64
    # Arbitrary choice :)
    epoch = datetime(2015, 8, 21, 15, 15, 47, 123416)

    delta = datetime.utcnow() - epoch
    microseconds = int(delta.total_seconds() * 10**6)
    masked_time = microseconds & ~(1 << time_bits)
    assert masked_time == microseconds, "Increase the epoch or use more bits"

    random_val = randint(0, (1 << random_bits) - 1)

    key = (masked_time << random_bits) | random_val
    # Make sure thing actually DO go into 64 bits!
    assert key < 1 << 63

    return pack('>Q', key).encode('base64')[:-1]


def sample_patch(image, center_x, center_y, width, height, mode='edge'):
    """Crops a patch out an image, padding with the boundary value if
    necessary. ``mode`` takes on the same values as ``numpy.pad``'s ``mode``
    keyword argument."""
    assert image.ndim >= 2

    top = center_y - height/2
    top_b = max(top, 0)
    top_pad = top_b - top
    assert top_pad >= 0

    bot = top + height
    bot_b = min(bot, image.shape[0])
    bot_pad = bot - bot_b
    assert bot_pad >= 0

    left = center_x - width/2
    left_b = max(left, 0)
    left_pad = left_b - left
    assert left_pad >= 0

    right = left + width
    right_b = min(right, image.shape[1])
    right_pad = right - right_b
    assert right_pad >= 0

    sample = image[top_b:bot_b, left_b:right_b]
    assert bot_b > top_b and right_b > left_b, (top_b, bot_b, left_b, right_b)
    pad_amounts = ((top_pad, bot_pad), (left_pad, right_pad))
    pad_amounts += ((0, 0),) * (image.ndim - 2)
    rv = np.pad(sample, pad_amounts, mode=mode)
    assert (rv.shape[0], rv.shape[1]) == (height, width)

    return rv
