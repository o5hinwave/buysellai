import Foundation

extension String {
    var localized: String {
        String(localized: String.LocalizationValue(self))
    }

    static func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
        let format = String(localized: String.LocalizationValue(key))
        return String(format: format, locale: Locale.current, arguments: arguments)
    }
}
