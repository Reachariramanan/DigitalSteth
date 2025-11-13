import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: HeartRecorderScreen(),
    );
  }
}

class HeartRecorderScreen extends StatefulWidget {
  const HeartRecorderScreen({super.key});

  @override
  State<HeartRecorderScreen> createState() => _HeartRecorderScreenState();
}

class _HeartRecorderScreenState extends State<HeartRecorderScreen> {
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  StreamSubscription? _recorderSubscription;
  StreamSubscription? _playerSubscription;

  bool _isRecording = false;
  bool _isMonitoring = false;
  bool _earpieceEnabled = false;
  String? _recordingPath;
  Int16List? _recordedSamples;
  Int16List? _liveSamples;
  double _currentTimeSec = 0.0;

  static const int sampleRate = 4000;
  static const double pixelsPerSecond = 800;
  static const int maxLiveSamples = 4000; // About 1 second of audio at 4000 Hz

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
    _initializePlayer();
    _requestPermissions();
  }

  @override
  void dispose() {
    _recorderSubscription?.cancel();
    _playerSubscription?.cancel();
    _recorder?.closeRecorder();
    _player?.closePlayer();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
  }

  Future<void> _initializeRecorder() async {
    _recorder = FlutterSoundRecorder();
    await _recorder!.openRecorder();
  }

  Future<void> _initializePlayer() async {
    _player = FlutterSoundPlayer();
    await _player!.openPlayer();
  }

  Future<void> _startRecording() async {
    if (_recorder == null) return;

    final directory = await getApplicationDocumentsDirectory();
    _recordingPath = '${directory.path}/heart_recording_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder!.startRecorder(
      toFile: _recordingPath,
      codec: Codec.pcm16WAV,
      sampleRate: sampleRate,
      numChannels: 1,
    );

    setState(() {
      _isRecording = true;
    });
  }

  Future<void> _stopRecording() async {
    if (_recorder == null) return;

    await _recorder!.stopRecorder();
    setState(() {
      _isRecording = false;
    });

    // Load recorded samples for waveform
    if (_recordingPath != null) {
      final file = File(_recordingPath!);
      final bytes = await file.readAsBytes();
      final buffer = bytes.buffer;
      // Skip WAV header (44 bytes) and convert to Int16List
      final data = buffer.asUint8List(44);
      final samples = Int16List(data.length ~/ 2);
      for (int i = 0; i < samples.length; i++) {
        samples[i] = (data[i * 2 + 1] << 8) | data[i * 2];
      }
      setState(() {
        _recordedSamples = samples;
      });
    }
  }

  Future<void> _toggleMonitoring() async {
    if (_player == null || _recorder == null) return;

    if (_isMonitoring) {
      await _player!.stopPlayer();
      await _recorder!.stopRecorder();
      _recorderSubscription?.cancel();
      setState(() {
        _isMonitoring = false;
        _liveSamples = null;
      });
    } else {
      // Initialize live samples buffer
      _liveSamples = Int16List(maxLiveSamples);
      int sampleIndex = 0;

      // Start recording to stream for live waveform
      final recordingDataController = StreamController<Uint8List>();
      _recorderSubscription = recordingDataController.stream.listen((data) {
        final int16Data = Int16List.view(data.buffer);
        for (int i = 0; i < int16Data.length && sampleIndex < maxLiveSamples; i++) {
          _liveSamples![sampleIndex] = int16Data[i];
          sampleIndex = (sampleIndex + 1) % maxLiveSamples;
        }
        setState(() {}); // Update UI with new samples
      });

      await _recorder!.startRecorder(
        toStream: recordingDataController.sink,
        codec: Codec.pcm16,
        sampleRate: sampleRate,
        numChannels: 1,
      );

      // Start live monitoring playback
      await _player!.startPlayerFromMic(
        sampleRate: sampleRate,
        numChannels: 1,
      );

      setState(() {
        _isMonitoring = true;
      });
    }
  }

  void _toggleEarpiece() {
    setState(() {
      _earpieceEnabled = !_earpieceEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heart Sound Recorder'),
      ),
      body: Column(
        children: [
          // Controls
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _toggleEarpiece,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _earpieceEnabled ? Colors.green : Colors.grey,
                  ),
                  child: Text(_earpieceEnabled ? 'Earpiece ON' : 'Earpiece OFF'),
                ),
                ElevatedButton(
                  onPressed: _toggleMonitoring,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isMonitoring ? Colors.blue : Colors.grey,
                  ),
                  child: Text(_isMonitoring ? 'Stop Monitor' : 'Monitor'),
                ),
                ElevatedButton(
                  onPressed: _isRecording ? _stopRecording : _startRecording,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRecording ? Colors.red : Colors.grey,
                  ),
                  child: Text(_isRecording ? 'Stop Record' : 'Record'),
                ),
              ],
            ),
          ),

          // Waveform display
          Expanded(
            child: _isMonitoring && _liveSamples != null
                ? LiveWaveform(
                    samples: _liveSamples!,
                    sampleRate: sampleRate,
                    pixelsPerSecond: pixelsPerSecond,
                  )
                : _recordedSamples != null
                    ? PcgWaveformWithCursor(
                        samples: _recordedSamples!,
                        sampleRate: sampleRate,
                        pixelsPerSecond: pixelsPerSecond,
                        currentTimeSec: _currentTimeSec,
                      )
                    : const Center(
                        child: Text('Press Monitor to see live waveform or Record to capture audio'),
                      ),
          ),
        ],
      ),
    );
  }
}

class PcgWaveformWithCursor extends StatelessWidget {
  final Int16List samples;
  final int sampleRate;
  final double pixelsPerSecond;
  final double currentTimeSec;

  const PcgWaveformWithCursor({
    super.key,
    required this.samples,
    required this.sampleRate,
    required this.currentTimeSec,
    this.pixelsPerSecond = 800,
  });

  @override
  Widget build(BuildContext context) {
    final durationSeconds = samples.length / sampleRate;
    final width = durationSeconds * pixelsPerSecond;
    final cursorX = currentTimeSec * pixelsPerSecond;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Stack(
        children: [
          CustomPaint(
            size: Size(width, 200),
            painter: _PcgWaveformPainter(
              samples: samples,
              sampleRate: sampleRate,
              pixelsPerSecond: pixelsPerSecond,
            ),
          ),
          Positioned(
            left: cursorX,
            top: 0,
            bottom: 0,
            child: Container(width: 2, color: const Color(0xFFFF4444)),
          ),
        ],
      ),
    );
  }
}

class LiveWaveform extends StatelessWidget {
  final Int16List samples;
  final int sampleRate;
  final double pixelsPerSecond;

  const LiveWaveform({
    super.key,
    required this.samples,
    required this.sampleRate,
    this.pixelsPerSecond = 800,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _LiveWaveformPainter(
        samples: samples,
        sampleRate: sampleRate,
        pixelsPerSecond: pixelsPerSecond,
      ),
    );
  }
}

class _LiveWaveformPainter extends CustomPainter {
  final Int16List samples;
  final int sampleRate;
  final double pixelsPerSecond;

  _LiveWaveformPainter({
    required this.samples,
    required this.sampleRate,
    required this.pixelsPerSecond,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 1
      ..color = const Color(0xFF00CCFF)
      ..isAntiAlias = true;

    final midY = size.height / 2;
    final totalSamples = samples.length;
    final durationSeconds = totalSamples / sampleRate;
    final totalWidth = durationSeconds * pixelsPerSecond;

    final samplesPerPixel = totalSamples / totalWidth;

    for (int x = 0; x < size.width && x < totalWidth; x++) {
      final sampleIndex = (x * samplesPerPixel).floor();
      if (sampleIndex < 0 || sampleIndex >= totalSamples) continue;

      final s = samples[sampleIndex] / 32768.0;
      final amp = s * (size.height / 2);

      canvas.drawLine(
        Offset(x.toDouble(), midY - amp),
        Offset(x.toDouble(), midY + amp),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LiveWaveformPainter oldDelegate) =>
      oldDelegate.samples != samples ||
      oldDelegate.pixelsPerSecond != pixelsPerSecond;
}

class _PcgWaveformPainter extends CustomPainter {
  final Int16List samples;
  final int sampleRate;
  final double pixelsPerSecond;

  _PcgWaveformPainter({
    required this.samples,
    required this.sampleRate,
    required this.pixelsPerSecond,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 1
      ..color = const Color(0xFFCCCCCC)
      ..isAntiAlias = true;

    final midY = size.height / 2;
    final totalSamples = samples.length;
    final durationSeconds = totalSamples / sampleRate;
    final totalWidth = durationSeconds * pixelsPerSecond;

    final samplesPerPixel = totalSamples / totalWidth;

    for (int x = 0; x < totalWidth; x++) {
      final sampleIndex = (x * samplesPerPixel).floor();
      if (sampleIndex < 0 || sampleIndex >= totalSamples) continue;

      final s = samples[sampleIndex] / 32768.0;
      final amp = s * (size.height / 2);

      canvas.drawLine(
        Offset(x.toDouble(), midY - amp),
        Offset(x.toDouble(), midY + amp),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PcgWaveformPainter oldDelegate) =>
      oldDelegate.samples != samples ||
      oldDelegate.pixelsPerSecond != pixelsPerSecond;
}
