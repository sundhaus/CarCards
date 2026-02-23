//
//  ProfanityFilter.swift
//  Car Collector
//
//  Filters profanity from comments for minor users.
//  Uses normalization to catch l33tspeak, spacing tricks, and common misspellings.
//

import Foundation

struct ProfanityFilter {
    
    /// Censor profanity in text, replacing bad words with asterisks
    static func censor(_ text: String) -> String {
        var result = text
        let normalized = normalize(text)
        
        for word in blocklist {
            // Search in normalized version to find positions, replace in original
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: normalized, range: NSRange(normalized.startIndex..., in: normalized))
                
                // Replace from end to preserve indices
                for match in matches.reversed() {
                    if let range = Range(match.range, in: result) {
                        let replacement = String(repeating: "*", count: result[range].count)
                        result.replaceSubrange(range, with: replacement)
                    }
                }
            }
        }
        
        // Also do a simple contains check for the core words (catches embedded profanity)
        for word in coreBlocklist {
            let normalizedResult = normalize(result)
            if let range = normalizedResult.range(of: word, options: .caseInsensitive) {
                let startIdx = normalizedResult.distance(from: normalizedResult.startIndex, to: range.lowerBound)
                let length = normalizedResult.distance(from: range.lowerBound, to: range.upperBound)
                let resultStart = result.index(result.startIndex, offsetBy: startIdx)
                let resultEnd = result.index(resultStart, offsetBy: length)
                let replacement = String(repeating: "*", count: length)
                result.replaceSubrange(resultStart..<resultEnd, with: replacement)
            }
        }
        
        return result
    }
    
    /// Check if text contains profanity
    static func containsProfanity(_ text: String) -> Bool {
        let normalized = normalize(text)
        
        for word in blocklist {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                if regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)) != nil {
                    return true
                }
            }
        }
        
        for word in coreBlocklist {
            if normalized.localizedCaseInsensitiveContains(word) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Normalization
    
    /// Normalize text to catch l33tspeak, spacing tricks, special chars
    private static func normalize(_ text: String) -> String {
        var s = text.lowercased()
        
        // Remove zero-width and invisible characters
        s = s.replacingOccurrences(of: "\u{200B}", with: "")  // zero-width space
        s = s.replacingOccurrences(of: "\u{200C}", with: "")
        s = s.replacingOccurrences(of: "\u{200D}", with: "")
        s = s.replacingOccurrences(of: "\u{FEFF}", with: "")
        
        // L33tspeak substitutions
        let leetMap: [Character: Character] = [
            "0": "o", "1": "i", "3": "e", "4": "a", "5": "s",
            "7": "t", "8": "b", "9": "g", "@": "a", "$": "s",
            "!": "i", "+": "t", "(": "c", "|": "i",
        ]
        
        s = String(s.map { leetMap[$0] ?? $0 })
        
        // Remove repeated characters beyond 2 (e.g. "fuuuuck" → "fuuck")
        var deduped = ""
        var lastChar: Character?
        var count = 0
        for char in s {
            if char == lastChar {
                count += 1
                if count <= 2 { deduped.append(char) }
            } else {
                deduped.append(char)
                lastChar = char
                count = 1
            }
        }
        s = deduped
        
        // Remove common separator tricks (dots, dashes, underscores between letters)
        // "f.u.c.k" → "fuck", "f-u-c-k" → "fuck"
        s = s.replacingOccurrences(of: ".", with: "")
        s = s.replacingOccurrences(of: "-", with: "")
        s = s.replacingOccurrences(of: "_", with: "")
        s = s.replacingOccurrences(of: " ", with: "")
        
        return s
    }
    
    // MARK: - Core blocklist (substring match — catches embedded words)
    
    private static let coreBlocklist: [String] = [
        "fuck", "shit", "cunt", "nigger", "nigga", "faggot", "fag",
    ]
    
    // MARK: - Full blocklist (word boundary match)
    
    private static let blocklist: [String] = [
        // F-word variants
        "fuck", "fuck", "fuk", "fuc", "fck", "phuck", "phuk",
        "fucked", "fucker", "fuckers", "fucking", "fuckoff",
        "motherfucker", "motherfucking", "mfer", "mofo",
        "wtf", "stfu",
        
        // S-word variants
        "shit", "shite", "sht", "shyt", "shiit",
        "shitty", "shitted", "bullshit", "horseshit", "dipshit",
        
        // A-word
        "ass", "arse", "asshole", "arsehole", "asswipe",
        "dumbass", "fatass", "jackass", "smartass", "badass",
        
        // B-word
        "bitch", "biatch", "biotch", "bitches",
        
        // D-word
        "damn", "dammit", "goddamn", "goddammit",
        "dick", "dck", "dik", "dickhead",
        
        // C-word
        "cunt", "cunts",
        
        // H-word
        "hell", "hoe", "whore", "hooker", "hoes",
        
        // P-word
        "piss", "pissed", "pissoff",
        "pussy", "pussies",
        "prick",
        
        // Racial slurs
        "nigger", "nigga", "nigg", "niger", "n1gger", "n1gga",
        "chink", "gook", "spic", "wetback", "beaner",
        "kike", "kyke", "hymie",
        "coon", "darkie", "jiggaboo",
        "cracker", "honky", "gringo",
        "towelhead", "raghead", "sandnigger",
        "redskin", "injun",
        
        // Homophobic slurs
        "faggot", "fag", "faggy", "fagg",
        "dyke",
        "tranny",
        
        // Sexual
        "cock", "cocks", "cocksucker",
        "blowjob", "handjob", "rimjob",
        "dildo", "vibrator",
        "cum", "cumming", "cumshot",
        "jizz", "jizzed",
        "tits", "titties", "boobs", "boobies",
        "penis", "vagina", "ballsack", "nutsack",
        "wank", "wanker", "wanking",
        "masturbate", "masturbation",
        "orgasm", "erection", "boner",
        "porn", "porno", "pornography",
        "anal", "anus",
        "hentai", "bukake", "bukkake",
        
        // Misc profanity
        "bastard", "bollocks", "bugger",
        "crap", "douche", "douchebag",
        "slut", "skank", "tramp",
        "retard", "retarded", "tard",
        "twat",
        
        // Drug references
        "cocaine", "heroin", "meth", "crack",
        
        // Violence
        "kill", "rape", "murder",
        "kys", "kms",
        
        // Abbreviations
        "lmao", "lmfao",
        "pos", "sob",
        "smh",
    ]
}
