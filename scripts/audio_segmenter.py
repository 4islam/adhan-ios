import os
import argparse
import subprocess
import re
import sys

def get_silence_intervals(input_file, silence_thresh, min_silence_len_ms):
    """
    Use ffmpeg silencedetect to find silence intervals.
    """
    duration_sec = min_silence_len_ms / 1000.0
    cmd = [
        "ffmpeg",
        "-i", input_file,
        "-af", f"silencedetect=noise={silence_thresh}dB:d={duration_sec}",
        "-f", "null",
        "-"
    ]
    
    print(f"Running silence detection: {' '.join(cmd)}")
    result = subprocess.run(cmd, stderr=subprocess.PIPE, text=True)
    output = result.stderr
    
    silence_starts = []
    silence_ends = []
    
    for line in output.split('\n'):
        if "silence_start" in line:
            match = re.search(r"silence_start: ([\d\.]+)", line)
            if match:
                silence_starts.append(float(match.group(1)))
        elif "silence_end" in line:
            match = re.search(r"silence_end: ([\d\.]+)", line)
            if match:
                silence_ends.append(float(match.group(1)))
                
    # Construct Non-Silent Intervals
    # Defaults: Start at 0.
    # If silence_start[0] > 0, the first chunk is 0 to silence_start[0]
    
    chunks = []
    current_pos = 0.0
    
    # Pair starts and ends
    # Logic: 
    # Chunk 1: 0 to silence_start[0]
    # Chunk 2: silence_end[0] to silence_start[1]
    # ...
    # Last Chunk: silence_end[last] to EOF
    
    # If file starts with silence (silence_start[0] == 0), we skip to silence_end[0]
    
    count = max(len(silence_starts), len(silence_ends))
    
    # We need total duration to close the last chunk
    duration_cmd = ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", input_file]
    total_duration = float(subprocess.check_output(duration_cmd).strip())
    
    if not silence_starts:
        # No silence found, treat whole file as one chunk? Or split by time?
        # User prompt implies splitting based on silence. If no silence, it's one big Adhan.
        # We might need to forcefully split if it's too long, but let's assume detection works.
        chunks.append((0, total_duration))
        return chunks

    # If first silence starts > 0, we have a chunk at the start
    if silence_starts[0] > 0.1:
        chunks.append((0, silence_starts[0]))
        
    for i in range(len(silence_ends)):
        start = silence_ends[i]
        if i < len(silence_starts) - 1:
            end = silence_starts[i+1]
        else:
            # Last silence end to file end (if there is audio left)
            # Check if there is a silence start after this? 
            # silence_starts usually has one more entry if silence is at EOF, but silencedetect can be tricky.
            # actually silence_starts[i+1] is the NEXT silence start.
            if i + 1 < len(silence_starts):
                 end = silence_starts[i+1]
            else:
                 end = total_duration
        
        if end - start > 0.5: # Min chunk size 0.5s
            chunks.append((start, end))
            
    return chunks

def process_chunk(input_file, start, end, index, output_dir, file_prefix):
    TARGET_DURATION = 29.0
    duration = end - start
    
    if duration <= 0: return

    tempo = duration / TARGET_DURATION
    
    # Chain atempo filters
    remaining_tempo = tempo
    filters = []
    
    if duration < 1.0:
       print(f"Skipping tiny chunk {duration}s")
       return

    # Safety: FFmpeg atempo limits 0.5 - 2.0
    while remaining_tempo > 2.0:
        filters.append("atempo=2.0")
        remaining_tempo /= 2.0
    while remaining_tempo < 0.5:
        filters.append("atempo=0.5")
        remaining_tempo /= 0.5
    
    filters.append(f"atempo={remaining_tempo}")
    filter_string = ",".join(filters)
    
    output_filename = f"{file_prefix}_{index:02d}.wav"
    output_path = os.path.join(output_dir, output_filename)
    
    # Re-encoding to basic wav/pcm for max compatibility
    # -ss before -i is faster seeking, but less accurate. 
    # -ss after -i is frame accurate.
    
    cmd = [
        "ffmpeg", "-y",
        "-i", input_file,
        "-ss", str(start),
        "-to", str(end),
        "-filter:a", filter_string,
        "-ar", "44100", # Standardize sample rate
        "-ac", "1",     # Mono is fine for notification
        output_path
    ]
    
    print(f"Processing Chunk {index}: {start:.2f}-{end:.2f} ({duration:.2f}s) -> Stretch {tempo:.2f}x -> {output_filename}")
    subprocess.run(cmd, check=True, stderr=subprocess.DEVNULL)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("input_file")
    parser.add_argument("--output_dir", default="Adhan Segments")
    parser.add_argument("--silence_thresh", type=int, default=-16)
    parser.add_argument("--min_silence_len", type=int, default=1000)
    args = parser.parse_args()
    
    if not os.path.exists(args.output_dir):
        os.makedirs(args.output_dir)
        
    chunks = get_silence_intervals(args.input_file, args.silence_thresh, args.min_silence_len)
    print(f"Found {len(chunks)} chunks.")
    
    file_prefix = os.path.splitext(os.path.basename(args.input_file))[0]
    
    saved_count = 0
    for i, (start, end) in enumerate(chunks):
        # We pass a mutable index based on SUCCESSFUL saves
        if process_chunk(args.input_file, start, end, saved_count + 1, args.output_dir, file_prefix):
            saved_count += 1
            
    print(f"Successfully generated {saved_count} contiguous segments.")

def process_chunk(input_file, start, end, index, output_dir, file_prefix):
    TARGET_DURATION = 29.0
    duration = end - start
    
    if duration <= 1.0: # increased min threshold slightly
       print(f"Skipping tiny chunk {duration}s")
       return False

    tempo = duration / TARGET_DURATION
    
    # Chain atempo filters
    remaining_tempo = tempo
    filters = []

    # Safety: FFmpeg atempo limits 0.5 - 2.0
    while remaining_tempo > 2.0:
        filters.append("atempo=2.0")
        remaining_tempo /= 2.0
    while remaining_tempo < 0.5:
        filters.append("atempo=0.5")
        remaining_tempo /= 0.5
    
    filters.append(f"atempo={remaining_tempo}")
    filter_string = ",".join(filters)
    
    # Join atempo filters
    filter_string = ",".join(filters)
    
    # Use .caf with PCM for iOS native compatibility
    output_filename = f"{file_prefix}_{index:02d}.caf"
    output_path = os.path.join(output_dir, output_filename)
    
    # robust input seeking: -ss and -t BEFORE -i
    # This cuts the stream before filtering, so atempo works on the slice
    cmd = [
        "ffmpeg", "-y",
        "-ss", str(start),
        "-t", str(duration),
        "-i", input_file,
        "-filter:a", filter_string,
        "-c:a", "pcm_s16le", # Linear PCM (Safest for Notifications)
        "-ar", "44100", # Standardize sample rate
        output_path
    ]
    
    print(f"Processing Chunk {index}: {start:.2f}-{end:.2f} ({duration:.2f}s) -> Stretch {tempo:.2f}x -> {output_filename}")
    subprocess.run(cmd, check=True, stderr=subprocess.DEVNULL)
    return True

if __name__ == "__main__":
    main()
