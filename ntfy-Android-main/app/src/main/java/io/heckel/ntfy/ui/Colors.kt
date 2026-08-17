package io.heckel.ntfy.ui

import android.content.Context
import android.graphics.Color
import androidx.core.content.ContextCompat
import com.google.android.material.color.MaterialColors
import io.heckel.ntfy.R
import io.heckel.ntfy.util.isDarkThemeOn

class Colors {
    companion object {
        fun primary(context: Context): Int {
            return MaterialColors.getColor(context, R.attr.colorPrimary, Color.GREEN)
        }

        fun onPrimary(context: Context): Int {
            return MaterialColors.getColor(context, R.attr.colorOnPrimary, Color.GREEN)
        }

        fun notificationIcon(context: Context): Int {
            return MaterialColors.getColor(context, R.attr.colorPrimary, Color.GREEN)
        }

        fun linkColor(context: Context): Int {
            return MaterialColors.getColor(context, R.attr.colorPrimary, Color.GREEN)
        }

        fun itemSelectedBackground(context: Context): Int {
            return ContextCompat.getColor(context, R.color.md_theme_surfaceContainerHigh)
        }

        fun cardBackgroundColor(context: Context): Int {
            return if (isDarkThemeOn(context)) {
                MaterialColors.getColor(context, R.attr.colorSurfaceContainer, Color.GRAY)
            } else {
                MaterialColors.getColor(context, R.attr.colorSurface, Color.WHITE)
            }
        }

        fun cardSelectedBackgroundColor(context: Context): Int {
            return if (isDarkThemeOn(context)) {
                MaterialColors.getColor(context, R.attr.colorSurfaceContainerHigh, Color.GRAY)
            } else {
                MaterialColors.getColor(context, R.attr.colorSurfaceContainerHighest, Color.GRAY)
            }
        }

        fun statusBarNormal(context: Context, dynamicColors: Boolean, darkMode: Boolean): Int {
            val default = context.resources.getColor(R.color.action_bar, null)
            return if (dynamicColors) {
                // Use colorSurface for both light and dark mode when dynamic colors are enabled
                MaterialColors.getColor(context, R.attr.colorSurface, default)
            } else {
                default
            }
        }

        fun toolbarTextColor(context: Context, dynamicColors: Boolean, darkMode: Boolean): Int {
            return if (dynamicColors) {
                MaterialColors.getColor(context, R.attr.colorOnSurface, Color.BLACK)
            } else {
                // Celadon toolbar — always white title/icons
                MaterialColors.getColor(context, R.attr.colorOnPrimary, Color.WHITE)
            }
        }

        fun shouldUseLightStatusBar(dynamicColors: Boolean, darkMode: Boolean): Boolean {
            // Celadon status bar uses light icons (white); light status bar icons only for dynamic light mode
            return dynamicColors && !darkMode
        }

        fun dangerText(context: Context): Int {
            return MaterialColors.getColor(context, R.attr.colorError, Color.RED)
        }

        fun swipeToRefreshColor(context: Context): Int {
            return MaterialColors.getColor(context, R.attr.colorPrimary, Color.GREEN)
        }
    }
}
