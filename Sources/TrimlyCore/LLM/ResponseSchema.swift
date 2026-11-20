import Foundation

/// JSON schema passed as Ollama's `format`; `target_folder` is an enum, so the model cannot invent folders.
public enum ResponseSchema {
    public static func json(allowedFolders: [String]) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "target_folder": ["type": "string", "enum": allowedFolders],
                "suggested_name": ["type": "string", "description": "2-6 kelimelik kisa aciklama; tarih, kategori ve uzanti YOK"],
                "confidence": ["type": "number", "minimum": 0, "maximum": 1],
                "reason": ["type": "string", "maxLength": 160]
            ],
            "required": ["target_folder", "suggested_name", "confidence", "reason"],
            "additionalProperties": false
        ]
    }
}
