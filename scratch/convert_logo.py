import os
from PIL import Image

src_path = r"C:\Users\naidu\Downloads\Local Vyapari\Local Vyapari\Only Logo.png"
dest_path = r"c:\Users\naidu\OneDrive\Desktop\Local-Vyapari\assets\images\logo.webp"

def process_logo():
    # Ensure parent directory exists
    os.makedirs(os.path.dirname(dest_path), exist_ok=True)
    
    # Open the image
    img = Image.open(src_path)
    print(f"Original image size: {img.size}, format: {img.format}, mode: {img.mode}")
    
    # Select resample filter dynamically based on Pillow version
    try:
        resample_filter = Image.Resampling.LANCZOS
    except AttributeError:
        resample_filter = Image.LANCZOS
        
    # Resize keeping aspect ratio (max 200x200)
    img.thumbnail((200, 200), resample_filter)
    
    # Save as WebP
    img.save(dest_path, format="WEBP", quality=90)
    
    file_size = os.path.getsize(dest_path)
    print(f"Successfully processed logo!")
    print(f"New dimensions: {img.size}")
    print(f"Output file size: {file_size / 1024:.2f} KB")

if __name__ == "__main__":
    process_logo()
