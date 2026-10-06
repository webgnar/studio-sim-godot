"""Convert an `xwd -root` dump to PNG (handles the 24bpp and 32bpp layouts Xvfb produces)."""
import struct, sys
from PIL import Image

data = open(sys.argv[1], 'rb').read()
header_size = struct.unpack('>I', data[0:4])[0]
width, height = struct.unpack('>II', data[16:24])
bits_per_pixel = struct.unpack('>I', data[44:48])[0]
bytes_per_line = struct.unpack('>I', data[48:52])[0]
ncolors = struct.unpack('>I', data[76:80])[0]
pixels = data[header_size + ncolors * 12:]
mode = 'BGRX' if bits_per_pixel == 32 else 'BGR'
Image.frombuffer('RGB', (width, height), pixels, 'raw', mode, bytes_per_line, 1).save(sys.argv[2])
