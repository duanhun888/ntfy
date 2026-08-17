package io.heckel.ntfy.ui

import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.TextView
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.updatePadding
import androidx.preference.EditTextPreference
import androidx.preference.ListPreference
import androidx.preference.Preference
import androidx.preference.PreferenceFragmentCompat
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.google.android.material.textfield.TextInputEditText
import io.heckel.ntfy.R

abstract class BasePreferenceFragment : PreferenceFragmentCompat() {
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // Preference list must fill the fragment and scroll inside it.
        // With wrong parent sizing, the list grows with content and appears "stuck".
        listView?.let { recyclerView ->
            recyclerView.layoutParams = (recyclerView.layoutParams ?: ViewGroup.LayoutParams(0, 0)).also { lp ->
                lp.width = ViewGroup.LayoutParams.MATCH_PARENT
                lp.height = ViewGroup.LayoutParams.MATCH_PARENT
            }
            recyclerView.clipToPadding = false
            recyclerView.isVerticalScrollBarEnabled = true
            recyclerView.isScrollbarFadingEnabled = false
            recyclerView.scrollBarStyle = View.SCROLLBARS_INSIDE_OVERLAY
            recyclerView.overScrollMode = View.OVER_SCROLL_ALWAYS
            recyclerView.isNestedScrollingEnabled = true
            ViewCompat.setScrollIndicators(
                recyclerView,
                ViewCompat.SCROLL_INDICATOR_TOP or ViewCompat.SCROLL_INDICATOR_BOTTOM
            )
            ViewCompat.setOnApplyWindowInsetsListener(recyclerView) { v, insets ->
                val systemBars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
                val extra = (24 * resources.displayMetrics.density).toInt()
                v.updatePadding(bottom = systemBars.bottom + extra)
                insets
            }
            ViewCompat.requestApplyInsets(recyclerView)
            recyclerView.post {
                recyclerView.requestFocus()
                recyclerView.requestLayout()
            }
        }
    }

    /**
     * Show [ListPreference] and [EditTextPreference] dialog by [MaterialAlertDialogBuilder]
     */
    override fun onDisplayPreferenceDialog(preference: Preference) {
        when (preference) {
            is ListPreference -> {
                val prefIndex = preference.entryValues.indexOf(preference.value)
                val dialog = MaterialAlertDialogBuilder(requireContext())
                    .setTitle(preference.title)
                    .setSingleChoiceItems(preference.entries, prefIndex) { d, index ->
                        val newValue = preference.entryValues[index].toString()
                        if (preference.callChangeListener(newValue)) {
                            preference.value = newValue
                        }
                        d.dismiss()
                    }
                    .setNegativeButton(android.R.string.cancel, null)
                    .create()
                dialog.setOnShowListener {
                    dialog.listView?.apply {
                        isVerticalScrollBarEnabled = true
                        isScrollbarFadingEnabled = false
                        isNestedScrollingEnabled = true
                    }
                }
                dialog.show()
            }
            is EditTextPreference -> {
                val dialogView = layoutInflater.inflate(R.layout.preference_dialog_edittext_edited, null)

                // Description/message: Use dialogMessage if set, otherwise check extras
                val messageView = dialogView.findViewById<TextView>(android.R.id.message)
                val message = preference.dialogMessage?.toString()
                    ?: preference.extras.getString("message")
                    ?: ""
                messageView.text = message

                // Text field: Handle null text by using empty string instead of "null"
                val editText = dialogView.findViewById<TextInputEditText>(android.R.id.edit)
                val hint = preference.extras.getString("hint") ?: ""
                editText.setText(preference.text ?: "")
                editText.hint = hint

                // Configure dialog
                val dialog = MaterialAlertDialogBuilder(requireContext())
                    .setTitle(preference.title)
                    .setView(dialogView)
                    .setPositiveButton(android.R.string.ok) { _, _ ->
                        val newValue = editText.text.toString()
                        if (preference.callChangeListener(newValue)) {
                            preference.text = newValue
                        }
                    }
                    .setNegativeButton(android.R.string.cancel, null)
                    .create()

                // Show keyboard when dialog is shown
                dialog.window?.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE)
                dialog.setOnShowListener {
                    editText.requestFocus()
                    editText.setSelection(editText.text?.length ?: 0)
                }
                dialog.show()
            }
            else -> super.onDisplayPreferenceDialog(preference)
        }
    }
}
