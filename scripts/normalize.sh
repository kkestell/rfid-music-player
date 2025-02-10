#!/bin/bash

if [ "$#" -eq 0 ] || [ "$#" -gt 2 ]; then
    echo "Usage: $0 input_file [output_file]"
    echo "If output_file is not specified, input_file will be overwritten"
    exit 1
fi

input_file="$1"
output_file="${2:-$1}"  # If $2 is not set, use $1
temp_file="/tmp/temp_conversion_$$.mp3"

# Check if input file exists
if [ ! -f "$input_file" ]; then
    echo "Error: Input file '$input_file' does not exist"
    exit 1
fi

# Check if input is an audio file
if ! ffmpeg -i "$input_file" -hide_banner 2>&1 | grep -q "Audio:"; then
    echo "Error: Input file '$input_file' does not contain audio"
    exit 1
fi

# First convert to MP3 with desired specs
echo "Converting to 128k 44.1kHz MP3..."
ffmpeg -y -i "$input_file" -vn -ar 44100 -c:a libmp3lame -q:a 4 -map_metadata -1 "$temp_file"

# Check loudness level of converted file
levels=$(ffmpeg -i "$temp_file" -filter:a ebur128 -f null /dev/null 2>&1 | grep "I:")
integrated_loudness=$(echo "$levels" | grep -o 'I: *-*[0-9.]*' | cut -d' ' -f2)

# If loudness is already close to -14 LUFS (within ±1 dB), skip normalization
if (( $(echo "$integrated_loudness > -15 && $integrated_loudness < -13" | bc -l) )); then
    echo "File is already normalized (loudness: ${integrated_loudness} LUFS). Moving to output."
    mv "$temp_file" "$output_file"
else
    echo "Normalizing file (current loudness: ${integrated_loudness} LUFS)"
    ffmpeg -y -i "$temp_file" -vn -filter:a loudnorm -c:a libmp3lame -q:a 4 -map_metadata -1 "$output_file"
    rm "$temp_file"
fi
