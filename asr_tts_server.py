import asyncio
import datetime
import os

import edge_tts
import websockets
import speech_recognition as sr
from gtts import gTTS
from pydub import AudioSegment
import numpy as np
import io
import wave
import pyaudio
from scipy.io import wavfile
from scipy.signal import wiener
from scipy.signal import butter, lfilter
from vosk import Model, KaldiRecognizer

# HOST = 'localhost'
HOST = '192.168.0.106'
PORT = 8081

# Initialize PyAudio
p = pyaudio.PyAudio()
# Audio stream configuration
FORMAT = pyaudio.paFloat32
CHANNELS = 1
RATE = 48000
CHUNK = 4800
SAMPLE_WIDTH = 4

# FORMAT = pyaudio.paInt16
# CHANNELS = 1
# RATE = 44000
# CHUNK = 1024
# SAMPLE_WIDTH = 2

def create_wave_file(memory_file, channels, sample_width, frame_rate):
    wf = wave.open(memory_file, 'wb')
    wf.setnchannels(channels)
    wf.setsampwidth(sample_width)
    wf.setframerate(frame_rate)
    return wf


def processASR_speech_recognition(pcm_data, frame_rate, sample_width):
    recognizer = sr.Recognizer()
    audio_data = sr.AudioData(pcm_data, frame_rate, sample_width)
    try:
        text = recognizer.recognize_vosk(audio_data, "en")
        print(f"Speech Recognition text: {text}")
        return text
    except sr.UnknownValueError:
        print("Speech Recognition could not understand the audio")
        return "error"
    except sr.RequestError as e:
        print(f"Could not request results from Speech Recognition service; {e}")
        return "error"


async def processTTS_google(websocket, text, filePath):
    tts = gTTS(text=text, lang='en', slow=False)
    tts.save(filePath)
    with open(filePath, "rb") as f:
        mp3_data = f.read()
    await websocket.send(mp3_data)
    os.remove(filePath)


async def processTTS_edgeTTS(websocket, text, filePath):
    tts = edge_tts.Communicate(text, "en-US-AriaNeural")
    # tts = edge_tts.Communicate(text, "zh-CN-XiaoxiaoNeural")
    mp3_data = io.BytesIO()
    async for chunk in tts.stream():
        if chunk["type"] == "audio":
            mp3_data.write(chunk["data"])
    await websocket.send(mp3_data.getvalue())


async def handler(websocket, path):
    print("Client connected")
    stream = p.open(format=FORMAT,
                    channels=CHANNELS,
                    rate=RATE,
                    # input=True,
                    output=True,
                    frames_per_buffer=CHUNK)

    sampleSize = p.get_sample_size(FORMAT)
    print(f"sampleSize={sampleSize}")

    try:
        async for message in websocket:
            if isinstance(message, bytes):
                print(f"Received binary message length: {len(message)}")
                stream.write(message)
                pcm_data.write(message)
            else:
                print(f"Received non-binary message: {message}")
                if message == "[msg_begin]":
                    now = datetime.datetime.now()
                    filePath = f"/Users/agenthun/Downloads/output_wav_{now}.wav"
                    fileMP3Path = f"/Users/agenthun/Downloads/output_wav_{now}.mp3"
                    wf = create_wave_file(
                        filePath,
                        CHANNELS,
                        SAMPLE_WIDTH,
                        RATE)
                    pcm_data = io.BytesIO()
                if message == "[msg_end]":
                    text = processASR_speech_recognition(pcm_data=pcm_data.getvalue(), frame_rate=RATE,
                                                         sample_width=SAMPLE_WIDTH)
                    await processTTS_edgeTTS(
                        websocket=websocket,
                        filePath=fileMP3Path,
                        text=text,
                    )
                    wf.writeframes(pcm_data.getvalue())
                    wf.close()
    except websockets.ConnectionClosed:
        print("Client disconnected")
    finally:
        stream.stop_stream()
        stream.close()


async def main():
    async with websockets.serve(handler, HOST, PORT):
        print(f"Server started at ws://{HOST}:{PORT}")
        await asyncio.Future()  # Run forever


if __name__ == "__main__":
    asyncio.run(main())
