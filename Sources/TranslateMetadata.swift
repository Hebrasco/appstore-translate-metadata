//
//  main.swift
//  appstore-metadata-updater
//
//  Created by Daniel Bedrich on 04.02.26.
//

import Foundation
import ArgumentParser
@preconcurrency import AppStoreConnect_Swift_SDK

let provider = APIProvider(configuration: APPSTORE_CONFIGURATION)

let SUPPORTED_DEEPL_LANGUAGES: [String] = [
    "ar", "bg", "cs", "da", "de", "el", "en-GB", "en-US", "es", "es-419",
    "et", "fi", "fr", "he", "hi", "hr", "hu", "id", "it", "ja", "ko", "lt", "lv",
    "nb", "nl", "pl", "pt-BR", "pt-PT", "ro", "ru", "sk", "sl", "sv",
    "th", "tr", "uk", "vi", "zh", "zh-Hans", "zh-Hant"
]

@main
struct TranslateMetadata: AsyncParsableCommand {
    @Argument(help: "The apps bundle id to translate the matadata for.")
    var bundleId: String
    
    @Option(name: .long, help: "The source '.json' file containing the base meta data used for the translation.")
    var sourceFile: String
    
    @Option(name: .long, help: "The source languate to translate from.")
    var sourceLanguage: String
    
    @Option(name: .long, help: "The path to the folder where the '.json' files should be saved.")
    var outputPath: String
    
    @Option(name: .long, help: "The marketing url.")
    var marketingURL: String? = nil
    
    @Option(name: .long, help: "The support url.")
    var supportURL: String? = nil
    
    @Flag(help: "Skip what's new.")
    var skipWhatsNew: Bool = false
    
    @Flag(help: "Skip promotional text.")
    var skipPromotionalText: Bool = false
    
    mutating func run() async throws {
        await translateMetaData()
    }
    
    func translateMetaData() async {
        let url = URL(string: "file://\(sourceFile)")
        guard let url else { TranslateMetadata.exit() }
        
        let app = await requestApp(bundleId: bundleId)
        let version = await requestLatestAppVersion(app)
        let localizations = version.relationships!.appStoreVersionLocalizations!.data!
        
        let jsonData = try! Data(contentsOf: url)
        
        let attributes = try! JSONDecoder().decode(
            AppStoreVersionLocalizationUpdateRequest.Data.Attributes.self,
            from: jsonData
        )
        
        let isDescriptionValid = validateAttribute(attributes.description, maxCount: 4000)
        let isKeywordsValid = validateAttribute(attributes.keywords, maxCount: 100)
        let isPromotionalTextValid = validateAttribute(attributes.promotionalText, maxCount: 170)
        let isWhatsNewValid = validateAttribute(attributes.whatsNew, maxCount: 4000)
        
        if !isDescriptionValid { print("The attribute 'description' is longer than 4000 characters.") }
        if !isKeywordsValid { print("The attribute 'keywords' is longer than 100 characters.") }
        if !isPromotionalTextValid { print("The attribute 'promotionalText' is longer than 170 characters.") }
        if !isWhatsNewValid { print("The attribute 'whatsNew' is longer than 4000 characters.") }
        
        if
            !isDescriptionValid ||
            !isKeywordsValid ||
            !isPromotionalTextValid ||
            !isWhatsNewValid
        {
            print("Some attributes are invalid. Continuing...")
        }
        
        for localizationId in localizations.map({ $0.id }) {
            let localization = await requestLocalization(localizationId)
            let locale = getLocale(localization.attributes!.locale!)
            
            print("🌐 Translating '\(locale)'")
            
            if !SUPPORTED_DEEPL_LANGUAGES.contains(locale) {
                print("Locale '\(locale)' not uspported by DeepL. Continuing...")
                continue
            }
            
            var text: [String] = []

            text.append(attributes.description ?? "")
            text.append(attributes.keywords ?? "")
            text.append(attributes.promotionalText ?? "")
            text.append(attributes.whatsNew ?? "")
            
            if text.count == 0 { continue }
            
            let translations = await translateTexts(text, targetLanguage: locale)
            
            let fileContent: AppStoreVersionLocalizationUpdateRequest.Data.Attributes = .init(
                description: translations[0].text,
                keywords: translations[1].text,
                marketingURL: attributes.marketingURL ?? URL(string: marketingURL ?? ""),
                promotionalText: skipPromotionalText ? nil : translations[2].text,
                supportURL: attributes.supportURL ?? URL(string: supportURL ?? ""),
                whatsNew: skipWhatsNew ? nil : translations[3].text,
            )
            
            let output = "\(outputPath)/\(locale).json"
            
            let filemanager = FileManager.default
            if !filemanager.fileExists(atPath: output) {
                try! filemanager.createDirectory(atPath: outputPath, withIntermediateDirectories: true)
            }
            filemanager.createFile(atPath: output, contents: try! JSONEncoder().encode(fileContent))
        }
    }
    
    func getLocale(_ locale: String) -> String {
        if !SUPPORTED_DEEPL_LANGUAGES.contains(locale) {
            if locale == "no" { return "nb" }
            if locale.contains("-") {
                let languageKey = String(locale.split(separator: "-").first ?? "")
                guard SUPPORTED_DEEPL_LANGUAGES.contains(languageKey) else { return locale }
                
                return languageKey
            }
            
            return locale
        }
        
        return locale
    }
    
    func validateAttribute(_ attribute: String?, maxCount: Int) -> Bool {
        attribute?.count ?? 0 > maxCount
    }

    func requestApp(bundleId: String) async -> App {
        let appRequest = APIEndpoint.v1
            .apps
            .get(parameters: .init(filterBundleID: [bundleId], include: [.appInfos, .appStoreVersions]))
        let app: App = try! await provider.request(appRequest).data.first!
        
        return app
    }
    
    func requestLatestAppVersion(_ app: App) async -> AppStoreVersion {
        let versionId = app.relationships!.appStoreVersions!.data!.first!.id
        let versionRequest = APIEndpoint.v1
            .appStoreVersions
            .id(versionId)
            .get(parameters: .init(include: [.appStoreVersionLocalizations], limitAppStoreVersionLocalizations: 50))
        let version: AppStoreVersion = try! await provider.request(versionRequest).data
        
        return version
    }
    
    func requestLocalization(_ id: String) async -> AppStoreVersionLocalization {
        let localizationRequest = APIEndpoint.v1
            .appStoreVersionLocalizations
            .id(id)
            .get()
        let localization: AppStoreVersionLocalization = try! await provider.request(localizationRequest).data
        
        return localization
    }
    
    func requestTranslation(params: [String : Any]) async -> DeepLResponse {
        var request = URLRequest(url: URL(string: "https://api-free.deepl.com/v2/translate")!)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: params, options: [])
        request.addValue("DeepL-Auth-Key \(DEEPL_API_KEY)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        try! await Task.sleep(for: .seconds(0.35))
        
        let (data, _) = try! await URLSession.shared.data(for: request)
        let fetchedData = try! JSONDecoder().decode(DeepLResponse.self, from: data)
        
        return fetchedData
    }
    
    func translateTexts(_ text: [String], targetLanguage: String) async -> [DeepLTranslation] {
        let params = [
            "text": text,
            "target_lang": targetLanguage,
            "source_lang": sourceLanguage
        ] as [String : Any]
        
        let translations = await requestTranslation(params: params).translations
        
        return translations
    }
}
