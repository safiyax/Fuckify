#!/bin/bash

# ImageMagick script to resize images from 1290x2796px to 1242x2688px
# Usage: ./resize_images.sh <input_folder>
# Output: Creates resized images with _resized suffix in the same folder

# Check if ImageMagick is installed
if ! command -v magick &> /dev/null && ! command -v convert &> /dev/null; then
    echo "Error: ImageMagick is not installed."
    echo "Install with: brew install imagemagick"
    exit 1
fi

# Use 'magick' command if available (ImageMagick 7+), otherwise 'convert' (ImageMagick 6)
if command -v magick &> /dev/null; then
    CONVERT_CMD="magick"
else
    CONVERT_CMD="convert"
fi

# Check if input folder is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <input_folder>"
    echo "Example: $0 ./screenshots"
    exit 1
fi

INPUT_DIR="$1"

# Check if directory exists
if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: Directory '$INPUT_DIR' does not exist"
    exit 1
fi

# Target dimensions
TARGET_WIDTH=1284
TARGET_HEIGHT=2778

# Counter for processed files
count=0

echo "Starting image resize process..."
echo "Input directory: $INPUT_DIR"
echo "Target size: ${TARGET_WIDTH}x${TARGET_HEIGHT}px"
echo "Method: Scale and crop to exact size"
echo ""

# Process all common image formats
shopt -s nullglob
for ext in png jpg jpeg PNG JPG JPEG; do
    for img in "$INPUT_DIR"/*."$ext"; do
        # Get filename without path and extension
        filename=$(basename "$img")
        extension="${filename##*.}"
        name="${filename%.*}"
        
        # Skip if already processed
        if [[ "$name" == *"_resized" ]]; then
            echo "Skipping already resized: $filename"
            continue
        fi
        
        output="$INPUT_DIR/${name}_resized.${extension}"
        
        echo "Processing: $filename"
        
        # Resize using scale and crop method
        # -resize: Scale to fill the target dimensions (one dimension will match, other will be larger)
        # -gravity center: Crop from the center
        # -extent: Crop to exact target dimensions
        $CONVERT_CMD "$img" \
            -resize "${TARGET_WIDTH}x${TARGET_HEIGHT}^" \
            -gravity center \
            -extent "${TARGET_WIDTH}x${TARGET_HEIGHT}" \
            "$output"
        
        if [ $? -eq 0 ]; then
            echo "✓ Created: ${name}_resized.${extension}"
            ((count++))
        else
            echo "✗ Failed to process: $filename"
        fi
    done
done
shopt -u nullglob

echo ""
echo "Resize complete! Processed $count image(s)."
