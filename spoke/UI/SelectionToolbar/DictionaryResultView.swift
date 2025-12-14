import SwiftUI

struct DictionaryResultView: View {
    let word: String
    let data: DictionaryData?
    let error: DictionaryAPIError?
    let onDismiss: () -> Void
    
    @State private var isAppearing = false
    
    var body: some View {
        HStack(spacing: 12) {
            if let data = data {
                successContent(data)
            } else if let error = error {
                errorContent(error)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundView)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isAppearing = true
            }
        }
        .scaleEffect(isAppearing ? 1 : 0.9)
        .opacity(isAppearing ? 1 : 0)
        .onTapGesture {
            onDismiss()
        }
    }
    
    // MARK: - Success Content
    
    @ViewBuilder
    private func successContent(_ data: DictionaryData) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(data.word)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                if let phonetic = data.phonetic, !phonetic.isEmpty {
                    Text(phonetic)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .frame(minWidth: 60)
            
            Divider()
                .frame(height: 40)
                .background(Color.white.opacity(0.2))
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(data.senses.prefix(3).enumerated()), id: \.offset) { index, sense in
                    senseRow(sense)
                }
            }
        }
    }
    
    @ViewBuilder
    private func senseRow(_ sense: DictionarySense) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if !sense.posDisplay.isEmpty {
                Text(sense.posDisplay)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.cyan.opacity(0.9))
                    .frame(minWidth: 30, alignment: .leading)
            }
            
            if let chinese = sense.chinese {
                Text(chinese)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
            }
        }
    }
    
    // MARK: - Error Content
    
    @ViewBuilder
    private func errorContent(_ error: DictionaryAPIError) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundColor(.yellow)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(word)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(error.localizedDescription)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
    
    // MARK: - Background
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.black.opacity(0.75))
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Preview

#Preview("Dictionary Result") {
    VStack(spacing: 20) {
        DictionaryResultView(
            word: "prisoner",
            data: DictionaryData(
                word: "prisoner",
                phonetic: "/ˈprɪz.ən.ər/",
                senses: [
                    DictionarySense(pos: "noun", chinese: "被监禁在监狱中", english: nil, examples: nil),
                    DictionarySense(pos: "noun", chinese: "任何被违背其意愿拘禁的人。", english: nil, examples: nil),
                    DictionarySense(pos: "noun", chinese: "因某种情况或环境而感到受限或被困的人。", english: nil, examples: nil)
                ],
                lemma: nil,
                lemmaInfo: nil
            ),
            error: nil,
            onDismiss: {}
        )
        
        DictionaryResultView(
            word: "hello",
            data: DictionaryData(
                word: "hello",
                phonetic: "/həˈloʊ/",
                senses: [
                    DictionarySense(pos: "interjection", chinese: "你好；喂", english: nil, examples: nil)
                ],
                lemma: nil,
                lemmaInfo: nil
            ),
            error: nil,
            onDismiss: {}
        )
        
        DictionaryResultView(
            word: "xyz",
            data: nil,
            error: .notFound,
            onDismiss: {}
        )
    }
    .padding()
    .background(Color.gray.opacity(0.3))
}
