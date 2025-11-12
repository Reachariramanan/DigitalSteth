# Digital Stethoscope

(DIY) Digital Stethoscope - App For the world. Made in INDIA

A minimal, professional digital stethoscope application built with Flutter, featuring real-time audio recording, playback, and phonocardiogram visualization.

## Features

### 🎵 **Audio Recording & Playback**
- Record audio from Bluetooth or wired stethoscope input
- High-quality audio recording (AAC, 128kbps, 44.1kHz)
- Play back recorded audio with progress tracking
- Visual feedback for recording and playback states

### 🔊 **Feedback System**
- Dedicated feedback button for audio playback
- Automatic routing to appropriate output device:
  - **BT Mode**: Audio plays through Bluetooth speaker
  - **Wired Mode**: Audio plays through device earpiece/speaker

### 📊 **Phonocardiogram Chart**
- Real-time waveform visualization during feedback
- Automatic chart activation when feedback starts
- Smooth, scrolling waveform display
- Professional medical chart styling

### 🎨 **Minimal Design**
- Matte black, white, and grey color scheme
- Clean, accessible interface
- Large, easy-to-press buttons
- Medical-grade professional aesthetics

## Getting Started

### Prerequisites
- Flutter SDK (3.9.2 or higher)
- Android device with microphone permissions
- Bluetooth stethoscope (for BT mode) or wired stethoscope (for wired mode)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Reachariramanan/DigitalSteth.git
   cd digitalsteth
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Permissions

The app requires the following permissions:
- **Microphone**: For audio recording
- **Audio Settings**: For audio playback routing

These permissions are automatically requested when the app starts.

## Usage

### 1. Select Stethoscope Type
- Launch the app
- Choose "BT Steth" for Bluetooth stethoscope
- Choose "Wired Steth" for wired stethoscope

### 2. Record Audio
- Press the red record button to start recording
- The button turns red and shows a stop icon when recording
- Press again to stop recording

### 3. Play Audio
- After recording, use the play button to listen to the recording
- Progress bar shows playback position
- Pause/resume functionality available

### 4. Use Feedback Mode
- Press the "Feedback" button to start phonocardiogram
- Audio plays through appropriate output device
- Real-time waveform chart appears automatically
- Press "Stop Feedback" to end the session

## Technical Details

### Dependencies
- `record: ^6.1.2` - Audio recording
- `audioplayers: ^6.0.0` - Audio playback
- `path_provider: ^2.1.3` - File system access
- `fl_chart: ^0.68.0` - Chart visualization

### Audio Configuration
- **Format**: AAC LC
- **Bitrate**: 128 kbps
- **Sample Rate**: 44.1 kHz
- **File Extension**: .m4a

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Medical Disclaimer

This application is for educational and demonstration purposes only. It is not intended for medical diagnosis or treatment. Always consult qualified medical professionals for health-related decisions.
