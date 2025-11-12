package com.example.digistethchai

import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import android.widget.SeekBar
import android.widget.Switch
import androidx.appcompat.app.AppCompatActivity

class PreprocessingActivity : AppCompatActivity() {

    private lateinit var prefs: SharedPreferences

    private lateinit var bandPassSwitch: Switch
    private lateinit var bandPassLowSeekBar: SeekBar
    private lateinit var bandPassHighSeekBar: SeekBar

    private lateinit var noiseReductionSwitch: Switch
    private lateinit var noiseReductionSeekBar: SeekBar

    private lateinit var highPassSwitch: Switch
    private lateinit var highPassSeekBar: SeekBar

    private lateinit var normalizationSwitch: Switch

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_preprocessing)

        prefs = getSharedPreferences("preprocessing_prefs", Context.MODE_PRIVATE)

        initializeViews()
        loadSettings()
        setupListeners()
    }

    private fun initializeViews() {
        bandPassSwitch = findViewById(R.id.bandPassSwitch)
        bandPassLowSeekBar = findViewById(R.id.bandPassLowSeekBar)
        bandPassHighSeekBar = findViewById(R.id.bandPassHighSeekBar)

        noiseReductionSwitch = findViewById(R.id.noiseReductionSwitch)
        noiseReductionSeekBar = findViewById(R.id.noiseReductionSeekBar)

        highPassSwitch = findViewById(R.id.highPassSwitch)
        highPassSeekBar = findViewById(R.id.highPassSeekBar)

        normalizationSwitch = findViewById(R.id.normalizationSwitch)
    }

    private fun loadSettings() {
        bandPassSwitch.isChecked = prefs.getBoolean("bandPassEnabled", false)
        bandPassLowSeekBar.progress = prefs.getInt("bandPassLow", 20)
        bandPassHighSeekBar.progress = prefs.getInt("bandPassHigh", 2000)

        noiseReductionSwitch.isChecked = prefs.getBoolean("noiseReductionEnabled", false)
        noiseReductionSeekBar.progress = prefs.getInt("noiseReductionStrength", 50)

        highPassSwitch.isChecked = prefs.getBoolean("highPassEnabled", false)
        highPassSeekBar.progress = prefs.getInt("highPassCutoff", 20)

        normalizationSwitch.isChecked = prefs.getBoolean("normalizationEnabled", false)
    }

    private fun setupListeners() {
        bandPassSwitch.setOnCheckedChangeListener { _, isChecked ->
            prefs.edit().putBoolean("bandPassEnabled", isChecked).apply()
        }
        bandPassLowSeekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                prefs.edit().putInt("bandPassLow", progress + 20).apply() // 20-520
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        })
        bandPassHighSeekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                prefs.edit().putInt("bandPassHigh", progress + 500).apply() // 500-4500
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        })

        noiseReductionSwitch.setOnCheckedChangeListener { _, isChecked ->
            prefs.edit().putBoolean("noiseReductionEnabled", isChecked).apply()
        }
        noiseReductionSeekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                prefs.edit().putInt("noiseReductionStrength", progress).apply()
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        })

        highPassSwitch.setOnCheckedChangeListener { _, isChecked ->
            prefs.edit().putBoolean("highPassEnabled", isChecked).apply()
        }
        highPassSeekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                prefs.edit().putInt("highPassCutoff", progress + 10).apply() // 10-110
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        })

        normalizationSwitch.setOnCheckedChangeListener { _, isChecked ->
            prefs.edit().putBoolean("normalizationEnabled", isChecked).apply()
        }
    }
}
