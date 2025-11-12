# Digital Stethoscope

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

## Screenshots

### Main Selection Screen
- Choose between Bluetooth and Wired stethoscope modes
- Large, clearly labeled buttons
- Minimal, distraction-free design

### Audio Interface
- Record button with visual recording indicator
- Playback controls with progress bar
- Feedback button for phonocardiogram
- Real-time status updates

### Phonocardiogram Visualization
- Live waveform chart during feedback playback
- Proper scaling and grid lines
- Medical chart formatting

## Getting Started

### Prerequisites
- Flutter SDK (3.9.2 or higher)
- Android device with microphone permissions
- Bluetooth stethoscope (for BT mode) or wired stethoscope (for wired mode)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
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

### Chart Specifications
- **Update Rate**: 50ms (20 FPS)
- **Data Points**: 200 (rolling window)
- **Y-Axis Range**: -1.2 to +1.2
- **Grid Intervals**: 0.5 (horizontal), 10 (vertical)

## Architecture

### File Structure
```
lib/
├── main.dart          # App entry point and main selection screen
└── audio_screen.dart  # Audio recording/playback interface

android/
└── app/src/main/
    └── AndroidManifest.xml  # Permissions configuration
```

### State Management
- Local state management within screen widgets
- Audio player and recorder lifecycle management
- Real-time chart data updates

### Audio Flow
1. **Recording**: Device microphone → Audio file
2. **Playback**: Audio file → Device speaker
3. **Feedback**: Audio file → Chart visualization + Output routing

## Platform Support

- **Android**: Full support with audio permissions
- **iOS**: Compatible (permissions may vary)
- **Web**: Limited (no microphone access)

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
