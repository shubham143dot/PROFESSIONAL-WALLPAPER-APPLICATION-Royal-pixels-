import sys
from PIL import Image, ImageDraw, ImageFont

img_path = r"c:\royal_pixels\assets\icon.png"
out_path = img_path

try:
    img = Image.open(img_path).convert("RGBA")
    
    # 1. Crop to bounding box based on alpha channel
    bg = Image.new("RGBA", img.size, (0, 0, 0, 0))
    diff = Image.composite(img, bg, img)
    bbox = diff.getbbox()
    if bbox:
        img = img.crop(bbox)
        
    # Resize back to a square dimension based on the cropped size
    w, h = img.size
    dim = max(w, h)
    
    # "fill black to body" -> create black background
    final_img = Image.new("RGBA", (dim, dim), (0, 0, 0, 255))
    
    # paste cropped image into center
    offset_x = (dim - w) // 2
    offset_y = (dim - h) // 2
    final_img.paste(img, (offset_x, offset_y), img)
    
    # "middle diamond shows thanks" 
    # Let's draw the text "Thanks" in the center of the image.
    text = "Thanks"
    
    # Load default font
    font = ImageFont.load_default()
    
    # Create an image for the text to scale it up nicely
    text_img = Image.new("RGBA", (200, 50), (0, 0, 0, 0))
    text_draw = ImageDraw.Draw(text_img)
    text_draw.text((10, 10), text, fill=(255, 215, 0, 255), font=font) # Gold color
    
    # Crop the text image
    text_bbox = text_img.getbbox()
    if text_bbox:
        text_img = text_img.crop(text_bbox)
    
        # Scale text roughly to 40% of the image width
        target_width = int(dim * 0.4)
        ratio = target_width / text_img.width
        target_height = int(text_img.height * ratio)
        text_img = text_img.resize((target_width, target_height), Image.Resampling.LANCZOS)
        
        # Paste text in center
        t_w, t_h = text_img.size
        t_x = (dim - t_w) // 2
        t_y = (dim - t_h) // 2
        final_img.paste(text_img, (t_x, t_y), text_img)
    
    # Save back
    final_img.save(out_path)
    print("Successfully edited logo!")
except Exception as e:
    print(f"Error: {e}")
