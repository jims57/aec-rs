"""
This example play song.wav in the speakers and recording microphone to output.wav while cancel the song from the microphone input.
Uses sounddevice instead of pyaudio for better macOS compatibility.

pip install pyaec sounddevice soundfile numpy
wget https://github.com/thewh1teagle/aec/releases/download/audio-files/song.wav
python microphone_sounddevice.py song.wav off.wav off
python microphone_sounddevice.py song.wav on.wav on
"""

import soundfile as sf
import numpy as np
import sys
import sounddevice as sd
from pyaec import Aec
import time

# Parameters
frame_size = 160 # 0.01s
sample_rate = 16000 # 16kHz
filter_length = int(sample_rate * 0.4) # 0.4s
aec = Aec(frame_size, filter_length, sample_rate, True)

# Input and output paths from command line arguments
song_path, out_path, echo_cancellation = sys.argv[1], sys.argv[2], sys.argv[3]

# Load the song
song_samples, _ = sf.read(song_path, dtype="int16")

# List to store output frames
output_frames = []

# Global variables for audio streams
input_stream = None
output_stream = None
song_position = 0

def audio_callback(indata, outdata, frames, time, status):
    global song_position, output_frames
    
    if status:
        print(f"Stream status: {status}")
    
    # Get current song chunk
    if song_position + frame_size <= len(song_samples):
        song_frame = song_samples[song_position:song_position + frame_size]
        song_position += frame_size
    else:
        # Loop back to beginning if we reach the end
        song_position = 0
        song_frame = song_samples[:frame_size]
    
    # Convert input data to int16
    in_samples = indata.flatten().astype(np.int16)
    
    # Process echo cancellation or skip it based on argument
    if echo_cancellation.lower() == "on":
        processed_frame = aec.cancel_echo(in_samples, song_frame)
    else:
        processed_frame = in_samples  # No echo cancellation, just use input as output
    
    # Store processed frame
    output_frames.append(processed_frame)
    
    # Play the song frame through speakers
    outdata[:] = song_frame.reshape(-1, 1)

def process_audio(duration=10):
    global input_stream, output_stream, song_position
    
    print(f"Starting audio processing for {duration} seconds...")
    print(f"Echo cancellation: {echo_cancellation}")
    
    # Start the audio streams
    with sd.Stream(channels=1, samplerate=sample_rate, blocksize=frame_size,
                  callback=audio_callback, dtype=np.int16):
        sd.sleep(duration * 1000)  # Convert to milliseconds
    
    # Concatenate all processed frames and save to output file
    if output_frames:
        output = np.concatenate(output_frames, axis=0)
        
        # Convert output to int16 before saving to file
        output = output.astype(np.int16)
        
        # Write the output to the output file
        sf.write(out_path, output, sample_rate)
        print(f"Created {out_path}")
    else:
        print("No audio frames captured")

# Start processing for 10 seconds
process_audio(duration=10)
