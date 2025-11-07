import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';

void main() {
  runApp(const StethoscopeApp());
}

class StethoscopeApp extends StatelessWidget {
  const StethoscopeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital Stethoscope',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const StethoscopeHomePage(),
    );
  }
}

enum StethMode { bt, wired }

class StethoscopeHomePage extends StatefulWidget {
  const StethoscopeHomePage({super.key});

  @override
  State<StethoscopeHomePage> createState() => _StethoscopeHomePageState();
}

class _StethoscopeHomePageState extends State<StethoscopeHomePage> {
  StethMode _currentMode = StethMode.bt;
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  StreamSubscription? _playerSub;
  bool _isRecording = false;
  bool _isPlaying = false;
  double _preprocessingIntensity = 5.0;
  double _impedance = 1.0;
  double _speakerIntensity = 0.5;
  double _pickupIntensity = 0.5;
  BluetoothDevice? _connectedDevice;

  @override
  void initState() {
    super.initState();
    _initAudio();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    await Permission.bluetooth.request();
    await Permission.bluetoothConnect.request();
    await Permission.bluetoothScan.request();
    await Permission.location.request(); // Required for Bluetooth scanning on Android
  }

  Future<void> _initAudio() async {
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();
    await _recorder!.openRecorder();
    await _player!.openPlayer();
  }

  Future<void> _stopAllAudio() async {
    if (_recorder?.isRecording ?? false) {
      await _recorder!.stopRecorder();
    }
    if (_player?.isPlaying ?? false) {
      await _player!.stopPlayer();
    }
    _playerSub?.cancel();
    _playerSub = null;
  }

  @override
  void dispose() {
    _stopAllAudio();
    _recorder?.closeRecorder();
    _player?.closePlayer();
    super.dispose();
  }

  void _switchMode(StethMode mode) {
    setState(() {
      _currentMode = mode;
    });
  }

  String? _recordedFilePath;

  Future<void> _startRecording() async {
    try {
      if (_currentMode == StethMode.bt) {
        if (_recorder != null && !_isRecording) {
          // Get app documents directory for recording
          Directory appDocDir = await getApplicationDocumentsDirectory();
          String filePath = '${appDocDir.path}/steth_recording.m4a';

          await _recorder!.startRecorder(
            toFile: filePath,
            codec: Codec.aacMP4,
          );

          setState(() {
            _isRecording = true;
            _recordedFilePath = filePath;
          });
        }
      } else if (_currentMode == StethMode.wired) {
        // For wired mode, if BT connected, play from BT, else show wave
        if (_connectedDevice != null) {
          // TODO: Play from BT device
          setState(() {
            _isPlaying = true;
          });
        } else {
          // Show wave
          setState(() {
            _isPlaying = true;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recording error: $e')),
      );
    }
  }

  Future<void> _playPath(String path) async {
    await _player!.startPlayer(fromURI: path);
    _playerSub?.cancel();
    await _player!.setSubscriptionDuration(const Duration(milliseconds: 100));
    _playerSub = _player!.onProgress!.listen((event) {
      final d = event.duration;
      final p = event.position;
      if (d != null && p >= d) {
        setState(() => _isPlaying = false);
        _playerSub?.cancel();
        _playerSub = null;
      }
    });
    setState(() => _isPlaying = true);
  }

  Future<void> _stopRecording() async {
    try {
      if (_currentMode == StethMode.bt) {
        if (_recorder != null && _isRecording) {
          final path = await _recorder!.stopRecorder();
          setState(() => _isRecording = false);
          if (path != null && _player != null) {
            await _playPath(path);
          }
        }
      } else if (_currentMode == StethMode.wired) {
        setState(() => _isPlaying = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stop recording error: $e')),
      );
    }
  }

  Future<void> _scanAndConnectBT() async {
    try {
      // Check if Bluetooth is available and enabled
      if (await FlutterBluePlus.isSupported == false) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetooth not supported on this device')),
        );
        return;
      }

      // Check Bluetooth adapter state
      var adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable Bluetooth')),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scanning for devices...')),
      );

      // Collect scan results
      List<ScanResult> results = [];

      // Listen to scan results
      var subscription = FlutterBluePlus.scanResults.listen((scanResults) {
        results = scanResults;
      });

      // Start scanning
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

      // Wait for scan to complete
      await Future.delayed(const Duration(seconds: 5));

      // Stop scanning
      await FlutterBluePlus.stopScan();

      // Cancel subscription
      await subscription.cancel();

      if (results.isNotEmpty) {
        if (!mounted) return;

        // Show dialog to select device
        BluetoothDevice? selectedDevice = await showDialog<BluetoothDevice>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Select Bluetooth Device'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final device = results[index].device;
                    final name = device.platformName.isEmpty ? "Unknown Device" : device.platformName;
                    return ListTile(
                      title: Text(name),
                      subtitle: Text(device.remoteId.toString()),
                      onTap: () => Navigator.pop(context, device),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );

        if (selectedDevice != null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Connecting to ${selectedDevice.platformName.isEmpty ? "Unknown Device" : selectedDevice.platformName}...')),
          );

          await selectedDevice.connect(timeout: const Duration(seconds: 15));

          setState(() {
            _connectedDevice = selectedDevice;
          });

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Connected to ${selectedDevice.platformName.isEmpty ? "Unknown Device" : selectedDevice.platformName}')),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No Bluetooth devices found. Make sure device is in pairing mode.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bluetooth error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Stethoscope'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_connectedDevice != null ? Icons.bluetooth_connected : Icons.bluetooth),
            onPressed: _scanAndConnectBT,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Mode Selection
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildModeButton(StethMode.bt, 'assets/bt_steth.svg'),
                _buildModeButton(StethMode.wired, 'assets/wired_steth.svg'),
              ],
            ),
            const SizedBox(height: 20),
            // Wave Visualization
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _isRecording || _isPlaying ? const WaveAnimation() : const Center(
                child: Text(
                  'Wave Form',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Controls
            Expanded(
              child: ListView(
                children: [
                  _buildSlider('Preprocessing Intensity', _preprocessingIntensity, 0, 10, (value) {
                    setState(() {
                      _preprocessingIntensity = value;
                    });
                  }),
                  _buildSlider('Impedance (X)', _impedance, 0.1, 5.0, (value) {
                    setState(() {
                      _impedance = value;
                    });
                  }),
                  _buildSlider('Speaker Intensity Out', _speakerIntensity, 0, 1, (value) {
                    setState(() {
                      _speakerIntensity = value;
                    });
                  }),
                  _buildSlider('Pickup Intensity In', _pickupIntensity, 0, 1, (value) {
                    setState(() {
                      _pickupIntensity = value;
                    });
                  }),
                ],
              ),
            ),
            // Record/Play Button
            ElevatedButton(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(_isRecording ? 'Stop' : 'Start'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(StethMode mode, String assetPath) {
    bool isSelected = _currentMode == mode;
    return GestureDetector(
      onTap: () => _switchMode(mode),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey,
            width: isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SvgPicture.asset(
          assetPath,
          width: 60,
          height: 60,
          colorFilter: ColorFilter.mode(
            isSelected ? Colors.blue : Colors.black,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(1)}'),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class WaveAnimation extends StatefulWidget {
  const WaveAnimation({super.key});

  @override
  State<WaveAnimation> createState() => _WaveAnimationState();
}

class _WaveAnimationState extends State<WaveAnimation> with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _animations = List.generate(5, (index) {
      return Tween<double>(begin: 10, end: 50).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(index * 0.2, (index + 1) * 0.2, curve: Curves.easeInOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            return Container(
              width: 4,
              height: _animations[index].value,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
