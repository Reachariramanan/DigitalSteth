import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math';

enum StethoscopeType {
  bluetooth,
  wired,
}

class AudioScreen extends StatefulWidget {
  final StethoscopeType stethoscopeType;

  const AudioScreen({super.key, required this.stethoscopeType});

  @override
  State<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends State<AudioScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isFeedbackMode = false;
  String? _recordedFilePath;
  Duration _recordingDuration = Duration.zero;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;

  // Phonocardiogram chart data
  List<FlSpot> _chartData = [];
  double _chartXValue = 0;
  Timer? _chartUpdateTimer;

  @override
  void initState() {
    super.initState();
    _initializeAudio();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _chartUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeAudio() async {
    // Request microphone permission
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Set up audio player listeners
    _audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        _playbackPosition = position;
      });
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() {
        _playbackDuration = duration ?? Duration.zero;
      });
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _isPlaying = false;
        _playbackPosition = Duration.zero;
      });
    });
  }

  Future<void> _startRecording() async {
    try {
      final directory = await getTemporaryDirectory();
      final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final filePath = '${directory.path}/$fileName';

      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      );

      await _audioRecorder.start(config, path: filePath);

      setState(() {
        _isRecording = true;
        _recordedFilePath = filePath;
        _recordingDuration = Duration.zero;
      });

      // Start duration timer
      _startRecordingTimer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _recordedFilePath = path;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to stop recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startRecordingTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_isRecording && mounted) {
        setState(() {
          _recordingDuration += const Duration(seconds: 1);
        });
        _startRecordingTimer();
      }
    });
  }

  Future<void> _playRecording() async {
    if (_recordedFilePath == null) return;

    try {
      await _audioPlayer.play(DeviceFileSource(_recordedFilePath!));
      setState(() {
        _isPlaying = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pausePlayback() async {
    try {
      await _audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pause playback: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopPlayback() async {
    try {
      await _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
        _playbackPosition = Duration.zero;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to stop playback: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _startFeedback() async {
    if (_recordedFilePath == null) return;

    try {
      // Start playing audio
      await _audioPlayer.play(DeviceFileSource(_recordedFilePath!));

      // Initialize chart data
      setState(() {
        _isFeedbackMode = true;
        _isPlaying = true;
        _chartData = [];
        _chartXValue = 0;
      });

      // Start chart update timer
      _startChartUpdates();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start feedback: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startChartUpdates() {
    _chartUpdateTimer?.cancel();
    _chartUpdateTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted && _isFeedbackMode) {
        // Generate simulated waveform data (in a real app, this would come from audio analysis)
        final random = Random();
        final amplitude = random.nextDouble() * 2 - 1; // Random value between -1 and 1

        setState(() {
          _chartData.add(FlSpot(_chartXValue, amplitude));
          _chartXValue += 0.05;

          // Keep only last 200 data points for performance
          if (_chartData.length > 200) {
            _chartData.removeAt(0);
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _stopFeedback() async {
    try {
      await _audioPlayer.stop();
      _chartUpdateTimer?.cancel();

      setState(() {
        _isFeedbackMode = false;
        _isPlaying = false;
        _playbackPosition = Duration.zero;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to stop feedback: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPhonocardiogramChart() {
    if (!_isFeedbackMode || _chartData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          const Text(
            'Phonocardiogram',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 0.5,
                  verticalInterval: 10,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[300],
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: Colors.grey[300],
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 20,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 0.5,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toStringAsFixed(1),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey[300]!),
                ),
                minX: _chartData.isNotEmpty ? _chartData.first.x : 0,
                maxX: _chartData.isNotEmpty ? _chartData.last.x : 100,
                minY: -1.2,
                maxY: 1.2,
                lineBarsData: [
                  LineChartBarData(
                    spots: _chartData,
                    isCurved: true,
                    color: Colors.black,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.black.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.stethoscopeType == StethoscopeType.bluetooth
        ? 'BT Stethoscope'
        : 'Wired Stethoscope';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Status indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: _isRecording
                      ? Colors.red.withOpacity(0.1)
                      : _isPlaying
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  _isRecording
                      ? 'Recording... ${_formatDuration(_recordingDuration)}'
                      : _isFeedbackMode
                          ? 'Feedback Active... ${_formatDuration(_playbackPosition)}'
                          : _isPlaying
                              ? 'Playing... ${_formatDuration(_playbackPosition)}'
                              : 'Ready to record',
                  style: TextStyle(
                    fontSize: 16,
                    color: _isRecording
                        ? Colors.red
                        : _isFeedbackMode
                            ? Colors.blue
                            : _isPlaying
                                ? Colors.green
                                : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 64),
              // Record Button
              SizedBox(
                width: 120,
                height: 120,
                child: ElevatedButton(
                  onPressed: _isRecording ? _stopRecording : _startRecording,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRecording ? Colors.red : Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isRecording ? 'Stop Recording' : 'Start Recording',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 48),
              // Playback controls (only show if we have a recording)
              if (_recordedFilePath != null) ...[
                SizedBox(
                  width: 120,
                  height: 120,
                  child: ElevatedButton(
                    onPressed: _isPlaying ? _pausePlayback : _playRecording,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPlaying ? Colors.grey[600] : Colors.grey[800],
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isPlaying ? 'Pause Playback' : 'Play Recording',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 32),
                // Feedback Button
                SizedBox(
                  width: 100,
                  height: 100,
                  child: ElevatedButton(
                    onPressed: _isFeedbackMode ? _stopFeedback : _startFeedback,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isFeedbackMode ? Colors.blue : Colors.grey[700],
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                    ),
                    child: Icon(
                      _isFeedbackMode ? Icons.stop : Icons.volume_up,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isFeedbackMode ? 'Stop Feedback' : 'Feedback',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                // Progress bar for playback
                if (_playbackDuration > Duration.zero) ...[
                  Container(
                    width: double.infinity,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _playbackDuration.inMilliseconds > 0
                          ? _playbackPosition.inMilliseconds / _playbackDuration.inMilliseconds
                          : 0.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_playbackPosition),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        _formatDuration(_playbackDuration),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              // Phonocardiogram Chart (shows when feedback is active)
              if (_isFeedbackMode) ...[
                const SizedBox(height: 32),
                _buildPhonocardiogramChart(),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
