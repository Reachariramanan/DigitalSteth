package com.example.digistethchai

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.media.*
import android.os.*
import android.widget.Button
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

    // compute separate mins (optional but better)
    private val minRec = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
    private val minTrack = AudioTrack.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_OUT_MONO, audioFormat)
    private val recBufferSize = maxOf(minRec, (sampleRate / 100) * 2)   // ~10ms
    private val trackBufferSize = maxOf(minTrack, (sampleRate / 100) * 2)

    // Preprocessing
    private lateinit var prefs: SharedPreferences
    private var bandPassFilter: BandPassFilter? = null
    private var highPassFilter: HighPassFilter? = null
    private var noiseReducer: NoiseReducer? = null
    private var normalizer: Normalizer? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        visualizerView = findViewById(R.id.visualizerView)
        micVolumeSeekBar = findViewById(R.id.micVolumeSeekBar)
        speakerVolumeSeekBar = findViewById(R.id.speakerVolumeSeekBar)

        audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
        uiHandler = Handler(Looper.getMainLooper())

        prefs = getSharedPreferences("preprocessing_prefs", Context.MODE_PRIVATE)
        loadPreprocessingSettings()

        setupVolumeControls()
        setupNavigation()
        checkPermissionsAndStart()
    }

    private fun setupVolumeControls() {
        // Mic gain 0.0–2.0 (center at 1.0 if you want: set progress=50 in XML)
        micVolumeSeekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                micGain = progress / 50.0f // 0..2
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        })

        // Use the VOICE_CALL stream to match USAGE_VOICE_COMMUNICATION
        speakerVolumeSeekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                val stream = AudioManager.STREAM_VOICE_CALL
                val maxVolume = audioManager.getStreamMaxVolume(stream)
                val volume = (progress * maxVolume) / 100
                audioManager.setStreamVolume(stream, volume, 0)
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        })
    }

    private fun setupNavigation() {
        findViewById<Button>(R.id.settingsButton).setOnClickListener {
            startActivity(Intent(this, PreprocessingActivity::class.java))
        }
    }

    private fun loadPreprocessingSettings() {
        if (prefs.getBoolean("bandPassEnabled", false)) {
            val low = prefs.getInt("bandPassLow", 20)
            val high = prefs.getInt("bandPassHigh", 2000)
            bandPassFilter = BandPassFilter(sampleRate, low, high)
        }
        if (prefs.getBoolean("highPassEnabled", false)) {
            val cutoff = prefs.getInt("highPassCutoff", 20)
            highPassFilter = HighPassFilter(sampleRate, cutoff)
        }
        if (prefs.getBoolean("noiseReductionEnabled", false)) {
            val strength = prefs.getInt("noiseReductionStrength", 50)
            noiseReducer = NoiseReducer(sampleRate, strength)
        }
        if (prefs.getBoolean("normalizationEnabled", false)) {
            normalizer = Normalizer()
        }
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
        if (allGranted) startAudioProcessing()
        else ActivityCompat.requestPermissions(this, permissions, 1)
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
            audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
            audioManager.startBluetoothSco()
            audioManager.isBluetoothScoOn = true

            audioRecord = AudioRecord.Builder()
                .setAudioSource(MediaRecorder.AudioSource.VOICE_COMMUNICATION)
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(audioFormat)
                        .setSampleRate(sampleRate)
                        .setChannelMask(channelConfig)
                        .build()
                )
                .setBufferSizeInBytes(recBufferSize)
                .build()

            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()

            audioTrack = AudioTrack.Builder()
                .setAudioAttributes(audioAttributes)
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(audioFormat)
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build()
                )
                .setBufferSizeInBytes(trackBufferSize)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()

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
        val chunkSize = maxOf(256, sampleRate * 5 / 1000)
        val buffer = ShortArray(chunkSize)
        val amplitudes = FloatArray(32)
        var amplitudeUpdateCounter = 0

        while (isRecording) {
            val read = audioRecord?.read(buffer, 0, buffer.size) ?: 0
            if (read > 0) {
                // safe gain (avoid overflow before narrowing)
                for (i in 0 until read) {
                    val scaled = (buffer[i] * micGain).toInt()
                    buffer[i] = scaled.coerceIn(-32768, 32767).toShort()
                }

                // Apply preprocessing filters
                for (i in 0 until read) {
                    var sample = buffer[i]
                    bandPassFilter?.let { sample = it.process(sample) }
                    highPassFilter?.let { sample = it.process(sample) }
                    noiseReducer?.let { sample = it.process(sample) }
                    normalizer?.let { sample = it.process(sample) }
                    buffer[i] = sample
                }

                amplitudeUpdateCounter++
                if (amplitudeUpdateCounter >= 2) {
                    val bands = amplitudes.size
                    val step = maxOf(1, read / bands)
                    for (b in 0 until bands) {
                        val start = b * step
                        val end = minOf(start + step, read)
                        if (end <= start) { amplitudes[b] = 0f; continue }
                        var sum = 0f
                        for (j in start until end) sum += kotlin.math.abs(buffer[j].toFloat())
                        amplitudes[b] = sum / (end - start)
                    }
                    uiHandler.post { visualizerView.updateAmplitudes(amplitudes) }
                    amplitudeUpdateCounter = 0
                }

                audioTrack?.write(buffer, 0, read)
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        isRecording = false
        try { audioRecord?.stop() } catch (_: Exception) {}
        audioRecord?.release(); audioRecord = null
        try { audioTrack?.stop() } catch (_: Exception) {}
        audioTrack?.release(); audioTrack = null
        try { audioManager.stopBluetoothSco() } catch (_: Exception) {}
        audioManager.isBluetoothScoOn = false
        audioManager.mode = AudioManager.MODE_NORMAL
    }
}
