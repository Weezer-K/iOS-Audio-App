
# iOS Audio Recorder & Transcriber

A robust iOS SwiftUI app for **encrypted audio recording, segmentation, transcription, and local storage using SwiftData**.  

Designed to meet production-quality standards with **full audio session management**, **route change handling**, **offline transcription queuing**, and **scalable data persistence**.

<img src="https://github.com/user-attachments/assets/2ffbf71c-c7b3-4bd0-b3c6-79b38f1f60d4" width="300" height="200">
---

## Overview

This project demonstrates:

✅ A production-ready audio recording system  
✅ Real-world handling of audio interruptions and route changes  
✅ Background recording support  
✅ Search Feature  
✅ Segmented backend transcription with retry logic  
✅ Secure, encrypted storage of audio files  
✅ SwiftData model designed for thousands of sessions and segments  
✅ Offline queue for failed transcription  
✅ Configurable audio quality  
✅ Unit-tested core business logic  

---

## Setup Instructions

Open the project in Xcode. If you want to be able to use Deepgram api for trasncrbing vs apple's local version you will need the api key. Either run it on start up and be prompted for the key or follow the guide linked below, which tells you how to set the env variable. Use the key name DEEPGRAM_API_KEY.    
(https://m25lazi.medium.com/environment-variables-in-xcode-a78e07d223ed)

On first launch:
- Grant microphone permission  
- Grant speech recognition permission  

Tap the record button and you are all set.

## Audio Recording System

- **AVAudioEngine** for recording  
- Configurable quality (Low/Medium/High)  
- Handles route changes (headphones/Bluetooth)  
- Handles interruptions (calls, Siri) with auto-resume  
- Real-time audio level metering  

---

## Encryption & Security

- AES encryption via CryptoKit  
- Encrypted files stored in Documents directory  
- Temporary decrypted files in temp directory, deleted after use  
- API keys stored securely in Keychain  
- Adheres to iOS privacy best practices  

---

## SwiftData Integration

- **RecordingSession** (title, date, filename)  
- **TranscriptionSegment** (start/end, text, status)  
- **QueuedTranscriptionSegment** (offline retry)  
- Pagination (20 per page) for large datasets  
- In-memory store for unit tests  

---

## Backend Transcription

- Segments recordings into 30s chunks  
- **Deepgram API** (preferred if key present)  
- **Apple SpeechRecognizer** fallback  
- Exponential backoff and retry logic  
- Offline queue auto-retry on launch  

---

## User Interface

- SwiftUI-based MVVM design  
- Recording controls with live feedback  
- Session list grouped by date with pull-to-refresh  
- Session detail shows segments, status, transcript  
- Smooth scrolling with large datasets  
- Accessibility: VoiceOver & dynamic type support  

---

## Error Handling & Edge Cases

- Audio permission denied/revoked  
- Low storage alerts  
- Network failures during transcription  
- Interruption & route-change recovery  
- App termination during recording  
- Data corruption and recovery paths  

---

## Performance Optimizations

- Efficient memory use for large audio  
- Battery-conscious session configs  
- Temp file cleanup strategy  
- SwiftData fetch limits and pagination  

---

## Deepgram Integration

1. Obtain API key from https://developers.deepgram.com/  
2. Store in Keychain via app settings  
3. App auto-detects and uses Deepgram for transcription  
4. Falls back to Apple SpeechRecognizer if unavailable  

---

## Future Enhancements

- iCloud sync of encrypted recordings  
- Full-text search across transcripts  
- Real-time waveform visualization
- Tap word and hear that point onwards
- Advanced noise reduction filters  
- iOS Home Screen Widget for quick record
- Naming files



## Closing Thoughts
I feel this was a good start. Given more time I could flesh out more things like the actual UI and features like renaming recordings. I'd also like to improve my testing. Overall a fun exercise. If you have any questions please feel free to reach out.
