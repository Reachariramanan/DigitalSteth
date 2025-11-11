package com.example.digistethchai

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.AttributeSet
import android.view.View
import kotlin.math.abs

class VisualizerView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private val paint = Paint().apply {
        color = Color.WHITE
        style = Paint.Style.FILL
    }

    private var amplitudes = FloatArray(32) { 0f }
    private var maxAmplitude = 32767f

    fun updateAmplitudes(newAmplitudes: FloatArray) {
        amplitudes = newAmplitudes.copyOf()
        // Use postInvalidate() for thread safety and potentially lower latency
        postInvalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        val width = width.toFloat()
        val height = height.toFloat()
        val barWidth = width / amplitudes.size

        for (i in amplitudes.indices) {
            val amplitude = abs(amplitudes[i])
            val normalizedAmplitude = (amplitude / maxAmplitude).coerceIn(0f, 1f)
            val barHeight = normalizedAmplitude * height

            val left = i * barWidth
            val top = height - barHeight
            val right = left + barWidth - 2
            val bottom = height

            canvas.drawRect(left, top, right, bottom, paint)
        }
    }
}
