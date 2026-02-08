//
//  DeepLTranslation 2.swift
//  appstore-translate-metadata
//
//  Created by Daniel Bedrich on 01.02.26.
//


struct DeepLTranslation: Codable {
    let detected_source_language: String
    let text: String
    
    private enum CodingKeys: String, CodingKey {
        case text
        case detected_source_language
    }
    
    init(from decoder:Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        detected_source_language = try values.decode(String.self, forKey: .detected_source_language)
        text = try values.decode(String.self, forKey: .text)
    }
}
