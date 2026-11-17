package com.bukuresipi

import android.content.Context
import android.util.AttributeSet
import android.view.View
import android.widget.FrameLayout

/**
 * A box 3/4 as tall as it is wide: the 4:3 photo box of a Home card (feed_ad.xml). Never under 120 dp: AdMob's
 * smallest MediaView (a 2-column grid on a 360 dp phone is ~118 dp tall); the text below gives up the few dp.
 */
class RatioFrameLayout @JvmOverloads constructor(context: Context, attrs: AttributeSet? = null) : FrameLayout(context, attrs) {
    private val minHeight = (120 * resources.displayMetrics.density).toInt()

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val height = maxOf(MeasureSpec.getSize(widthMeasureSpec) * 3 / 4, minHeight)
        super.onMeasure(widthMeasureSpec, MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY))
    }
}
