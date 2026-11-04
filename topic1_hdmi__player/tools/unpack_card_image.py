"""Restore the published TF image and verify its original SHA-256.

Run from any working directory. Existing images are checked, never overwritten.
"""
import gzip
import hashlib
import os
from pathlib import Path
import shutil
import tempfile

EXPECTED = '71D32B709A5D6871B1FABA7394DF19819EDB5E222AE671F2EBFD8AD0A06EA3B0'

def sha256(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest().upper()

def main():
    folder = Path(__file__).resolve().parents[1] / 'build'
    source = folder / 'sound_science_card.img.gz'
    target = folder / 'sound_science_card.img'
    if target.exists():
        if sha256(target) != EXPECTED:
            raise SystemExit('Existing image differs; preserve or move it before extracting.')
        print('Existing image matches the published SHA-256:', target)
        return
    fd, name = tempfile.mkstemp(prefix='sound_science_', suffix='.tmp', dir=folder)
    os.close(fd)
    temp = Path(name)
    try:
        with gzip.open(source, 'rb') as reader, temp.open('wb') as writer:
            shutil.copyfileobj(reader, writer)
        if sha256(temp) != EXPECTED:
            raise SystemExit('Image SHA-256 mismatch; extraction was not published.')
        # On Windows rename fails if the destination appeared in the meantime.
        temp.rename(target)
    finally:
        temp.unlink(missing_ok=True)
    print('Image restored and SHA-256 verified:', target)

if __name__ == '__main__':
    main()
