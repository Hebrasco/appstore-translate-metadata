//
//  DeepLResponse.swift
//  xcloc-translator
//
//  Created by Daniel Bedrich on 01.02.26.
//

struct DeepLResponse: Codable {
    let translations: [DeepLTranslation]
    
    private enum CodingKeys: String, CodingKey {
        case translations
    }
    
    init(from decoder:Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        translations = try values.decode([DeepLTranslation].self, forKey: .translations)
    }
}
