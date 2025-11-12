package com.example.digistethchai

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

// Simple band-pass filter using biquad IIR
class BandPassFilter(private val sampleRate: Int, lowCutoff: Int, highCutoff: Int) {
    private val a = DoubleArray(3)
    private val b = DoubleArray(3)
    private val x = DoubleArray(3)
    private val y = DoubleArray(3)

    init {
        // Design band-pass filter
        val low = 2 * PI * lowCutoff / sampleRate
        val high = 2 * PI * highCutoff / sampleRate
        val bw = high - low
        val cf = (low + high) / 2

        val c = cos(cf)
        val s = sin(cf)
        val alpha = sin(bw / 2)

        val r = sin(PI / 4) / alpha // Q = 1/sqrt(2) for Butterworth

        b[0] = alpha
        b[1] = 0.0
        b[2] = -alpha
        a[0] = 1 + alpha
        a[1] = -2 * c
        a[2] = 1 - alpha

        // Normalize
        for (i in 0..2) {
            b[i] /= a[0]
            a[i] /= a[0]
        }
    }

    fun process(input: Short): Short {
        val xn = input.toDouble()
        val yn = b[0] * xn + b[1] * x[1] + b[2] * x[2] - a[1] * y[1] - a[2] * y[2]

        // Shift
        x[2] = x[1]; x[1] = xn
        y[2] = y[1]; y[1] = yn

        return yn.toInt().toShort().coerceIn(-32768, 32767)
    }
}

// Simple high-pass filter
class HighPassFilter(private val sampleRate: Int, cutoff: Int) {
    private val a = DoubleArray(2)
    private val b = DoubleArray(2)
    private val x = DoubleArray(2)
    private val y = DoubleArray(2)

    init {
        val c = 2 * PI * cutoff / sampleRate
        val cosC = cos(c)
        val sinC = sin(c)
        val alpha = sinC / 2

        b[0] = (1 + cosC) / 2
        b[1] = -(1 + cosC) / 2
        a[0] = 1 + alpha
        a[1] = -2 * cosC

        // Normalize
        b[0] /= a[0]; b[1] /= a[0]
        a[1] /= a[0]
    }

    fun process(input: Short): Short {
        val xn = input.toDouble()
        val yn = b[0] * xn + b[1] * x[1] - a[1] * y[1]

        x[1] = xn
        y[1] = yn

        return yn.toInt().toShort().coerceIn(-32768, 32767)
    }
}

// Simple noise reduction (basic low-pass)
class NoiseReducer(private val sampleRate: Int, strength: Int) {
    private val alpha = strength / 100.0
    private var last = 0.0

    fun process(input: Short): Short {
        val xn = input.toDouble()
        val yn = alpha * xn + (1 - alpha) * last
        last = yn
        return yn.toInt().toShort().coerceIn(-32768, 32767)
    }
}

// Normalization (simple AGC)
class Normalizer {
    private var maxAmp = 1.0

    fun process(input: Short): Short {
        val amp = abs(input.toDouble())
        if (amp > maxAmp) maxAmp = amp
        return (input.toDouble() / maxAmp * 32767).toInt().toShort().coerceIn(-32768, 32767)
    }
}
