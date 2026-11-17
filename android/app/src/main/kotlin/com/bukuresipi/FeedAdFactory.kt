package com.bukuresipi

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.util.TypedValue
import android.view.LayoutInflater
import android.view.View
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.NativeAdFactory
import kotlin.math.max

/**
 * The Home feed's ad card (factory id "feedCard", lib/features/home/presentation/widgets/feed_ad.dart). Flutter
 * cannot draw an AdMob native ad, so this copies FeedCard natively: the app passes its theme colours, text sizes and
 * the "Ad" label in customOptions. shortcut: system sans-serif, not the app's Familjen Grotesk (google_fonts downloads
 * it at run time; Android would need the font bundled in res/font) - bundle it if the difference shows.
 */
class FeedAdFactory(private val context: Context) : NativeAdFactory {
    override fun createNativeAd(ad: NativeAd, options: MutableMap<String, Any>?): NativeAdView {
        val o = options.orEmpty()
        fun color(key: String) = (o[key] as? Number)?.toInt() ?: Color.GRAY
        fun TextView.style(sizeKey: String, colorKey: String) {
            setTextSize(TypedValue.COMPLEX_UNIT_SP, (o[sizeKey] as? Number)?.toFloat() ?: 12f)
            setTextColor(color(colorKey))
        }
        val dp = context.resources.displayMetrics.density
        val view = LayoutInflater.from(context).inflate(R.layout.feed_ad, null) as NativeAdView
        // The card's paper, border and round corners; clipToOutline keeps the image inside them.
        view.background = GradientDrawable().apply {
            setColor(color("paper"))
            cornerRadius = 12 * dp
            setStroke(max(1, dp.toInt()), color("line"))
        }
        view.clipToOutline = true

        val media = view.findViewById<MediaView>(R.id.ad_media)
        media.setBackgroundColor(color("placeholder"))
        ad.mediaContent?.let { media.mediaContent = it }
        view.mediaView = media

        // "AD · ADVERTISER" where our cards say "RESTAURANT": the ad is marked as one in the same place.
        view.findViewById<TextView>(R.id.ad_label).apply {
            style("labelSize", "pandan")
            text = listOfNotNull(o["label"] as? String, ad.advertiser?.takeIf { it.isNotBlank() }).joinToString(" · ")
            view.advertiserView = this
        }
        view.findViewById<TextView>(R.id.ad_headline).apply {
            style("titleSize", "ink")
            paint.isFakeBoldText = true
            text = ad.headline
            view.headlineView = this
        }
        view.findViewById<TextView>(R.id.ad_text).apply {
            style("bodySize", "inkSoft")
            text = ad.body
            visibility = if (ad.body.isNullOrBlank()) View.GONE else View.VISIBLE
            view.bodyView = this
        }
        view.findViewById<TextView>(R.id.ad_cta).apply {
            style("ctaSize", "pandanDeep")
            text = ad.callToAction?.let { "$it ›" }
            visibility = if (ad.callToAction.isNullOrBlank()) View.GONE else View.VISIBLE
            view.callToActionView = this
        }
        view.setNativeAd(ad)
        return view
    }
}
