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
    private lateinit var bandPassLowValue: android.widget.TextView
    private lateinit var bandPassHighValue: android.widget.TextView

    private lateinit var noiseReductionSwitch: Switch
    private lateinit var noiseReductionSeekBar: SeekBar
    private lateinit var noiseReductionValue: android.widget.TextView

    private lateinit var highPassSwitch: Switch
    private lateinit var highPassSeekBar: SeekBar
    private lateinit var highPassValue: android.widget.TextView

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
        bandPassLowValue = findViewById(R.id.bandPassLowValue)
        bandPassHighValue = findViewById(R.id.bandPassHighValue)

        noiseReductionSwitch = findViewById(R.id.noiseReductionSwitch)
        noiseReductionSeekBar = findViewById(R.id.noiseReductionSeekBar)
        noiseReductionValue = findViewById(R.id.noiseReductionValue)

        highPassSwitch = findViewById(R.id.highPassSwitch)
        highPassSeekBar = findViewById(R.id.highPassSeekBar)
        highPassValue = findViewById(R.id.highPassValue)

        normalizationSwitch = findViewById(R.id.normalizationSwitch)
    }

    private fun loadSettings() {
        bandPassSwitch.isChecked = prefs.getBoolean("bandPassEnabled", false)
        val low = prefs.getInt("bandPassLow", 20)
        bandPassLowSeekBar.progress = low - 20
        bandPassLowValue.text = low.toString()

        val high = prefs.getInt("bandPassHigh", 2000)
        bandPassHighSeekBar.progress = high - 500
        bandPassHighValue.text = high.toString()

        noiseReductionSwitch.isChecked = prefs.getBoolean("noiseReductionEnabled", false)
        val strength = prefs.getInt("noiseReductionStrength", 50)
        noiseReductionSeekBar.progress = strength
        noiseReductionValue.text = strength.toString()

        highPassSwitch.isChecked = prefs.getBoolean("highPassEnabled", false)
        val cutoff = prefs.getInt("highPassCutoff", 20)
        highPassSeekBar.progress = cutoff - 10
        highPassValue.text = cutoff.toString()

        normalizationSwitch.isChecked = prefs.getBoolean("normalizationEnabled", false)
    }

    private fun setupListeners() {
        bandPassSwitch.setOnCheckedChangeListener { _, isChecked ->
            prefs.edit().putBoolean("bandPassEnabled", isChecked).apply()
        }
        bandPassLowSeekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                val value = progress + 20
                bandPassLowValue.text = value.toString()
                prefs.edit().putInt("bandPassLow", value).apply()
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        })
        bandPassHighSeekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                val value = progress + 500
                bandPassHighValue.text = value.toString()
                prefs.edit().putInt("bandPassHigh", value).apply()
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        })

        noiseReductionSwitch.setOnCheckedChangeListener { _, isChecked ->
            prefs.edit().putBoolean("noiseReductionEnabled", isChecked).apply()
        }
        noiseReductionSeekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                noiseReductionValue.text = progress.toString()
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
                val value = progress + 10
                highPassValue.text = value.toString()
                prefs.edit().putInt("highPassCutoff", value).apply()
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        })

        normalizationSwitch.setOnCheckedChangeListener { _, isChecked ->
            prefs.edit().putBoolean("normalizationEnabled", isChecked).apply()
        }
    }
}
