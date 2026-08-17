import SwiftUI

/// Visual tokens aligned with Android / Web console (ink · celadon · cinnabar).
enum CnTheme {
    static let ink = Color(red: 0.11, green: 0.11, blue: 0.11)
    static let inkMuted = Color(red: 0.36, green: 0.36, blue: 0.36)
    static let paper = Color(red: 0.957, green: 0.965, blue: 0.957)
    static let panel = Color(red: 0.988, green: 0.992, blue: 0.984)
    static let celadon = Color(red: 0.184, green: 0.435, blue: 0.369)
    static let celadonSoft = Color(red: 0.184, green: 0.435, blue: 0.369).opacity(0.10)
    static let cinnabar = Color(red: 0.706, green: 0.137, blue: 0.094)
    static let seal = Color(red: 0.620, green: 0.165, blue: 0.133)
    static let lineStrong = Color.black.opacity(0.22)
}
