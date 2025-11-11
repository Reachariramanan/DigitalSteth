package com.example.digistethchai

import android.Manifest
import android.annotation.SuppressLint
import android.content.pm.PackageManager
import android.media.*
import android.os.*
import android.widget.SeekBar
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import kotlin.concurrent.thread
import kotlin.math.abs

class MainActivity : AppCompatActivity() {

    private lateinit var visualizerView: VisualizerView
    private lateinit var micVolumeSeekBar: SeekBar
    private lateinit var speakerVolumeSeekBar: SeekBar

    private var audioRecord: AudioRecord? = null
    private var audioTrack: AudioTrack? = null
    private var isRecording = false
    private var micGain = 1.0f
    private lateinit var audioManager: AudioManager
    private lateinit var uiHandler: Handler

    private val sampleRate = 44100
    private val channelConfig = AudioFormat.CHANNEL_IN_MONO
    private val audioFormat = AudioFormat.ENCODING_PCM_16BIT
    // Use smaller buffer for low latency (target ~10ms latency)
    private val bufferSize = (sampleRate * 10 / 1000 * 2).coerceAtLeast(
        AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        visualizerView = findViewById(R.id.visualizerView)
        micVolumeSeekBar = findViewById(R.id.micVolumeSeekBar)
        speakerVolumeSeekBar = findViewById(R.id.speakerVolumeSeekBar)

        audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
        uiHandler = Handler(Looper.getMainLooper())

        setupVolumeControls()
        checkPermissionsAndStart()
    }

    private fun setupVolumeControls() {
        micVolumeSeekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                micGain = progress / 50.0f // 0-2 range
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        })

        speakerVolumeSeekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                val volume = (progress * maxVolume) / 100
                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, volume, 0)
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        })

        // Preset buttons
        findViewById<android.widget.Button>(R.id.micPresetLow).setOnClickListener { micVolumeSeekBar.progress = 25 }
        findViewById<android.widget.Button>(R.id.micPresetMed).setOnClickListener { micVolumeSeekBar.progress = 50 }
        findViewById<android.widget.Button>(R.id.micPresetHigh).setOnClickListener { micVolumeSeekBar.progress = 75 }

        findViewById<android.widget.Button>(R.id.speakerPresetLow).setOnClickListener { speakerVolumeSeekBar.progress = 25 }
        findViewById<android.widget.Button>(R.id.speakerPresetMed).setOnClickListener { speakerVolumeSeekBar.progress = 50 }
        findViewById<android.widget.Button>(R.id.speakerPresetHigh).setOnClickListener { speakerVolumeSeekBar.progress = 75 }
    }

    private fun checkPermissionsAndStart() {
        val permissions = arrayOf(
            Manifest.permission.RECORD_AUDIO,
            Manifest.permission.BLUETOOTH,
            Manifest.permission.MODIFY_AUDIO_SETTINGS
        )

        val allGranted = permissions.all {
            ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
        }

        if (allGranted) {
            startAudioProcessing()
        } else {
            ActivityCompat.requestPermissions(this, permissions, 1)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 1 && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
            startAudioProcessing()
        } else {
            Toast.makeText(this, "Permissions required for audio processing", Toast.LENGTH_LONG).show()
        }
    }

    @SuppressLint("MissingPermission")
    private fun startAudioProcessing() {
        try {
            // Start Bluetooth SCO for mic input
            audioManager.startBluetoothSco()
            audioManager.isBluetoothScoOn = true

            // Create AudioRecord with low latency settings
            val audioRecordBuilder = AudioRecord.Builder()
                .setAudioSource(MediaRecorder.AudioSource.VOICE_COMMUNICATION)
                .setAudioFormat(AudioFormat.Builder()
                    .setEncoding(audioFormat)
                    .setSampleRate(sampleRate)
                    .setChannelMask(channelConfig)
                    .build())
                .setBufferSizeInBytes(bufferSize)

            audioRecord = audioRecordBuilder.build()

            // Create AudioTrack with low latency settings
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()

            val audioTrackBuilder = AudioTrack.Builder()
                .setAudioAttributes(audioAttributes)
                .setAudioFormat(AudioFormat.Builder()
                    .setEncoding(audioFormat)
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build())
                .setBufferSizeInBytes(bufferSize)
                .setTransferMode(AudioTrack.MODE_STREAM)

            audioTrack = audioTrackBuilder.build()

            audioRecord?.startRecording()
            audioTrack?.play()

            isRecording = true

            thread {
                android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_URGENT_AUDIO)
                processAudioLoop()
            }
        } catch (e: Exception) {
            e.printStackTrace()
            Toast.makeText(this, "Error starting audio: ${e.message}", Toast.LENGTH_LONG).show()
        }
    }

    private fun processAudioLoop() {
        // Use smaller chunks for lower latency (target ~5ms chunks)
        val chunkSize = (sampleRate * 5 / 1000).coerceAtLeast(256)
        val buffer = ShortArray(chunkSize)
        val amplitudes = FloatArray(32)
        var amplitudeUpdateCounter = 0

        while (isRecording) {
            val read = audioRecord?.read(buffer, 0, buffer.size) ?: 0
            if (read > 0) {
                // Apply mic gain
                for (i in 0 until read) {
                    buffer[i] = (buffer[i] * micGain).toInt().toShort().coerceIn(Short.MIN_VALUE, Short.MAX_VALUE)
                }

                // Update amplitudes less frequently to reduce UI load
                amplitudeUpdateCounter++
                if (amplitudeUpdateCounter >= 2) { // Update every 2 chunks (~10ms)
                    val ampChunkSize = read / amplitudes.size
                    for (i in amplitudes.indices) {
                        var sum = 0f
                        val start = i * ampChunkSize
                        val end = minOf(start + ampChunkSize, read)
                        for (j in start until end) {
                            sum += abs(buffer[j].toFloat())
                        }
                        amplitudes[i] = sum / (end - start)
                    }

                    // Update visualizer using Handler for lower latency
                    uiHandler.post {
                        visualizerView.updateAmplitudes(amplitudes)
                    }
                    amplitudeUpdateCounter = 0
                }

                // Play back immediately
                audioTrack?.write(buffer, 0, read)
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        isRecording = false
        audioRecord?.stop()
        audioRecord?.release()
        audioTrack?.stop()
        audioTrack?.release()
        audioManager.stopBluetoothSco()
        audioManager.isBluetoothScoOn = false
    }
}
