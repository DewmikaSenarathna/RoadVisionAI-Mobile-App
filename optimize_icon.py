from PIL import Image
import os

# Create a square launcher image from the original Logo.png and save to assets
src_path = os.path.join('mobile_app', 'assets', 'Logo.png')
out_path = os.path.join('mobile_app', 'assets', 'Logo_square.png')

logo = Image.open(src_path).convert('RGBA')
print(f"Original logo: {logo.size}")

# Target square size (use 1024 which is common for launcher source)
size = 1024

# Calculate scale to fill the square while preserving aspect ratio
logo_ratio = logo.width / logo.height
if logo_ratio > 1:
	# Wider than tall: fit width
	new_w = size
	new_h = round(size / logo_ratio)
else:
	# Taller than wide: fit height
	new_h = size
	new_w = round(size * logo_ratio)

resized = logo.resize((new_w, new_h), Image.Resampling.LANCZOS)

# Create square transparent background and paste centered
bg = Image.new('RGBA', (size, size), (255, 255, 255, 0))
offset = ((size - new_w) // 2, (size - new_h) // 2)
bg.paste(resized, offset, resized)

# Save square image
bg.save(out_path)
print(f"Saved square launcher image: {out_path} ({bg.size})")

# Also save a copy into android drawable as logo.png (compatibility)
drawable_out = os.path.join('mobile_app', 'android', 'app', 'src', 'main', 'res', 'drawable', 'logo.png')
bg.convert('RGBA').save(drawable_out)
print(f"Saved drawable logo for Android: {drawable_out}")

# Also create a "cover" variant that fills the square (may crop edges) so logo fills icon
from PIL import ImageOps
out_fill = os.path.join('mobile_app', 'assets', 'Logo_square_fill.png')
# ImageOps.fit crops to fill the target size
filled = ImageOps.fit(logo, (size, size), Image.Resampling.LANCZOS, centering=(0.5, 0.5))
filled.save(out_fill)
print(f"Saved fill square launcher image: {out_fill} ({filled.size})")

# Save fill variant to drawable too
drawable_fill = os.path.join('mobile_app', 'android', 'app', 'src', 'main', 'res', 'drawable', 'logo_fill.png')
filled.save(drawable_fill)
print(f"Saved drawable fill logo for Android: {drawable_fill}")

# Create a padded variant so the logo isn't clipped by circular masks
pad_ratio = 0.12  # 12% padding by default; adjust if needed
inner = int(size * (1 - 2 * pad_ratio))
# Resize logo to fit within inner box
if logo_ratio > 1:
	# wider: fit width to inner
	new_w = inner
	new_h = round(inner / logo_ratio)
else:
	new_h = inner
	new_w = round(inner * logo_ratio)
resized_pad = logo.resize((new_w, new_h), Image.Resampling.LANCZOS)
bg_pad = Image.new('RGBA', (size, size), (255, 255, 255, 0))
offset_pad = ((size - new_w) // 2, (size - new_h) // 2)
bg_pad.paste(resized_pad, offset_pad, resized_pad)
out_pad = os.path.join('mobile_app', 'assets', 'Logo_square_padded.png')
bg_pad.save(out_pad)
print(f"Saved padded square launcher image: {out_pad} ({bg_pad.size})")

# Save padded variant to drawable too
drawable_pad = os.path.join('mobile_app', 'android', 'app', 'src', 'main', 'res', 'drawable', 'logo_padded.png')
bg_pad.save(drawable_pad)
print(f"Saved drawable padded logo for Android: {drawable_pad}")
