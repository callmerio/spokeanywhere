import Foundation

// MARK: - Parsed Definition Data Models

/// 解析后的词典定义
struct ParsedDefinition {
    let word: String
    let phonetic: String?
    let sections: [DefinitionSection]
    let rawDefinition: String
    let dictionaryType: DictionaryType
}

/// 词典类型
enum DictionaryType {
    case englishChinese  // 英汉词典 (牛津等)
    case englishEnglish  // 英英词典
    case unknown
}

/// 定义分区 (如 A. noun, B. verb)
struct DefinitionSection {
    let label: String?        // "A", "B", etc.
    let pos: String           // "noun", "verb", etc.
    let senses: [DefinitionSense]
}

/// 单个义项
struct DefinitionSense: Identifiable {
    let id = UUID()
    let number: String?       // "①", "②", etc.
    let gloss: String?        // "(piece, section)" 等括号内的说明
    let chinese: String?      // 中文释义
    let pinyin: String?       // 拼音
    let examples: [DefinitionExample]
    let subsenses: [DefinitionSense]  // 子义项
}

/// 例句
struct DefinitionExample: Identifiable {
    let id = UUID()
    let english: String
    let chinese: String?
}

// MARK: - Dictionary Definition Parser

final class DictionaryDefinitionParser: Sendable {

    static let shared = DictionaryDefinitionParser()

    private init() {}
    
    /// 解析词典定义
    func parse(word: String, definition: String) -> ParsedDefinition {
        let dictionaryType = detectDictionaryType(definition)
        let phonetic = extractPhonetic(from: definition)
        
        let sections: [DefinitionSection]
        switch dictionaryType {
        case .englishChinese:
            sections = parseEnglishChineseSections(definition)
        case .englishEnglish:
            sections = parseEnglishEnglishSections(definition)
        case .unknown:
            sections = parseGenericSections(definition)
        }
        
        return ParsedDefinition(
            word: word,
            phonetic: phonetic,
            sections: sections,
            rawDefinition: definition,
            dictionaryType: dictionaryType
        )
    }
    
    // MARK: - Dictionary Type Detection
    
    private func detectDictionaryType(_ definition: String) -> DictionaryType {
        // 英汉词典特征：包含大量中文、拼音标注、圈数字
        let chineseCount = definition.unicodeScalars.filter { $0.value >= 0x4E00 && $0.value <= 0x9FFF }.count
        let hasCircledNumbers = definition.contains("①") || definition.contains("②") || definition.contains("③")
        let hasSectionLabels = definition.contains("A.") || definition.contains("B.") || definition.contains("C.")
        let hasPinyin = definition.range(of: #"[a-zāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ]+\s"#, options: .regularExpression) != nil
        
        if chineseCount > 10 && (hasCircledNumbers || hasSectionLabels || hasPinyin) {
            return .englishChinese
        } else if chineseCount == 0 {
            return .englishEnglish
        }
        return .unknown
    }
    
    // MARK: - Phonetic Extraction
    
    private func extractPhonetic(from definition: String) -> String? {
        // 匹配 | BrE xxx, AmE xxx | 或 /xxx/ 格式
        if let match = definition.range(of: #"\|[^|]+\|"#, options: .regularExpression) {
            return String(definition[match]).trimmingCharacters(in: CharacterSet(charactersIn: "|")).trimmingCharacters(in: .whitespaces)
        }
        if let match = definition.range(of: #"/[^/]+/"#, options: .regularExpression) {
            return String(definition[match])
        }
        return nil
    }
    
    // MARK: - English-Chinese Dictionary Parsing
    
    private func parseEnglishChineseSections(_ definition: String) -> [DefinitionSection] {
        var sections: [DefinitionSection] = []
        
        // 尝试按 A. B. C. 分割
        let sectionPattern = #"([A-Z])\.\s*(noun|verb|adjective|adverb|preposition|pronoun|conjunction|interjection|determiner|transitive verb|intransitive verb|n\.|v\.|adj\.|adv\.)"#
        let regex = try? NSRegularExpression(pattern: sectionPattern, options: .caseInsensitive)
        let nsString = definition as NSString
        let matches = regex?.matches(in: definition, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        
        if matches.isEmpty {
            // 没有 A. B. 分区，尝试直接按词性分割
            let posPattern = #"(noun|verb|adjective|adverb|preposition|pronoun|conjunction|interjection|determiner)"#
            if let posMatch = definition.range(of: posPattern, options: [.regularExpression, .caseInsensitive]) {
                let pos = String(definition[posMatch])
                let senses = parseEnglishChineseSenses(definition)
                if !senses.isEmpty {
                    sections.append(DefinitionSection(label: nil, pos: pos, senses: senses))
                }
            } else {
                // 完全没有词性标记，创建一个通用分区
                let senses = parseEnglishChineseSenses(definition)
                if !senses.isEmpty {
                    sections.append(DefinitionSection(label: nil, pos: "", senses: senses))
                }
            }
        } else {
            // 有 A. B. 分区
            for (index, match) in matches.enumerated() {
                let label = nsString.substring(with: match.range(at: 1))
                let pos = nsString.substring(with: match.range(at: 2))
                
                // 获取这个分区的内容范围
                let startIndex = match.range.upperBound
                let endIndex = index + 1 < matches.count ? matches[index + 1].range.location : nsString.length
                let sectionContent = nsString.substring(with: NSRange(location: startIndex, length: endIndex - startIndex))
                
                let senses = parseEnglishChineseSenses(sectionContent)
                sections.append(DefinitionSection(label: label, pos: pos, senses: senses))
            }
        }
        
        return sections
    }
    
    private func parseEnglishChineseSenses(_ content: String) -> [DefinitionSense] {
        var senses: [DefinitionSense] = []
        
        // 按圈数字分割 ① ② ③ 等，支持到 ⑪
        let circledNumbers = ["①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨", "⑩", "⑪", "⑫"]
        var segments: [(number: String?, content: String)] = []
        
        // 找到所有圈数字的位置
        var numberPositions: [(number: String, position: String.Index)] = []
        for number in circledNumbers {
            var searchStart = content.startIndex
            while let range = content.range(of: number, range: searchStart..<content.endIndex) {
                numberPositions.append((number, range.lowerBound))
                searchStart = range.upperBound
            }
        }
        
        // 按位置排序
        numberPositions.sort { content.distance(from: content.startIndex, to: $0.position) < content.distance(from: content.startIndex, to: $1.position) }
        
        // 分割内容
        for (index, item) in numberPositions.enumerated() {
            let startIdx = content.index(item.position, offsetBy: item.number.count)
            let endIdx = index + 1 < numberPositions.count ? numberPositions[index + 1].position : content.endIndex
            let segmentContent = String(content[startIdx..<endIdx])
            segments.append((item.number, segmentContent))
        }
        
        // 如果没有圈数字，整个内容作为一个义项
        if segments.isEmpty && !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            segments.append((nil, content))
        }
        
        for segment in segments {
            let sense = parseSingleSense(number: segment.number, content: segment.content)
            senses.append(sense)
        }
        
        return senses
    }
    
    private func parseSingleSense(number: String?, content: String) -> DefinitionSense {
        var gloss: String?
        var chinese: String?
        var pinyin: String?
        var examples: [DefinitionExample] = []
        
        // 先分离例句部分（以 ▸ 开头）和释义部分
        let parts = content.components(separatedBy: "▸")
        let meaningPart = parts.first ?? content
        let exampleParts = parts.dropFirst()
        
        // 提取括号内的说明 (piece, section) 等
        if let glossMatch = meaningPart.range(of: #"\([^)]+\)"#, options: .regularExpression) {
            gloss = String(meaningPart[glossMatch])
        }
        
        // 从释义部分提取中文和拼音
        // 格式通常是: (gloss) 中文 pinyin 或 中文 pinyin
        let meaningWithoutGloss = gloss != nil ? meaningPart.replacingOccurrences(of: gloss!, with: "") : meaningPart
        
        // 提取中文释义（第一个连续的中文）
        let chinesePattern = #"[\u4e00-\u9fa5][\u4e00-\u9fa5，、/]*"#
        if let chineseRegex = try? NSRegularExpression(pattern: chinesePattern, options: []) {
            let nsContent = meaningWithoutGloss as NSString
            let chineseMatches = chineseRegex.matches(in: meaningWithoutGloss, options: [], range: NSRange(location: 0, length: nsContent.length))
            if let firstMatch = chineseMatches.first {
                chinese = nsContent.substring(with: firstMatch.range).trimmingCharacters(in: .whitespaces)
            }
        }
        
        // 提取拼音（中文后面的拉丁字母带声调）
        let pinyinPattern = #"\s([a-zāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ]+(?:\s+[a-zāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ]+)*)"#
        if let pinyinMatch = meaningWithoutGloss.range(of: pinyinPattern, options: .regularExpression) {
            let matched = String(meaningWithoutGloss[pinyinMatch]).trimmingCharacters(in: .whitespaces)
            if matched.count < 30 {
                pinyin = matched
            }
        }
        
        // 解析例句（以 ▸ 分隔的部分）
        for examplePart in exampleParts {
            let trimmed = examplePart.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let (eng, chn) = splitEnglishChinese(trimmed)
                if !eng.isEmpty {
                    examples.append(DefinitionExample(english: eng, chinese: chn))
                }
            }
        }
        
        return DefinitionSense(
            number: number,
            gloss: gloss,
            chinese: chinese,
            pinyin: pinyin,
            examples: examples,
            subsenses: []
        )
    }
    
    private func splitEnglishChinese(_ text: String) -> (english: String, chinese: String?) {
        // 找到第一个中文字符的位置
        if let firstChineseIndex = text.firstIndex(where: { char in
            guard let scalar = char.unicodeScalars.first else { return false }
            return scalar.value >= 0x4E00 && scalar.value <= 0x9FFF
        }) {
            let english = String(text[..<firstChineseIndex]).trimmingCharacters(in: .whitespaces)
            let chinese = String(text[firstChineseIndex...]).trimmingCharacters(in: .whitespaces)
            return (english, chinese.isEmpty ? nil : chinese)
        }
        return (text, nil)
    }
    
    // MARK: - English-English Dictionary Parsing
    
    private func parseEnglishEnglishSections(_ definition: String) -> [DefinitionSection] {
        var sections: [DefinitionSection] = []
        
        // 简化处理：按词性分割
        let posPattern = #"(noun|verb|adjective|adverb|preposition|pronoun|conjunction|interjection|determiner)"#
        if let regex = try? NSRegularExpression(pattern: posPattern, options: .caseInsensitive) {
            let nsString = definition as NSString
            let matches = regex.matches(in: definition, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches {
                let pos = nsString.substring(with: match.range)
                let sense = DefinitionSense(
                    number: nil,
                    gloss: nil,
                    chinese: nil,
                    pinyin: nil,
                    examples: [],
                    subsenses: []
                )
                sections.append(DefinitionSection(label: nil, pos: pos, senses: [sense]))
            }
        }
        
        // 如果没有找到词性，整个作为一个分区
        if sections.isEmpty {
            let sense = DefinitionSense(
                number: nil,
                gloss: nil,
                chinese: nil,
                pinyin: nil,
                examples: [],
                subsenses: []
            )
            sections.append(DefinitionSection(label: nil, pos: "", senses: [sense]))
        }
        
        return sections
    }
    
    // MARK: - Generic Parsing
    
    private func parseGenericSections(_ definition: String) -> [DefinitionSection] {
        // 尝试英汉解析，失败则用英英
        let sections = parseEnglishChineseSections(definition)
        if !sections.isEmpty {
            return sections
        }
        return parseEnglishEnglishSections(definition)
    }
}
