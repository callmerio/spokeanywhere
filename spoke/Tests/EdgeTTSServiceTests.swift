import Testing
@testable import SpokenAnyWhere

@Suite("EdgeTTSService 测试")
struct EdgeTTSServiceTests {

    @Test("DRM token 应是 64 位十六进制字符串")
    func drmTokenLooksValid() {
        let token = DRMHelper.generateSecMsGecToken()

        #expect(token.count == 64)
        #expect(token.allSatisfy { $0.isHexDigit })
    }

    @Test("错误文案应保持可读")
    func errorDescriptionsAreReadable() {
        #expect(EdgeTTSError.invalidURL.errorDescription == "无效的 URL")
        #expect(EdgeTTSError.noAudioData.failureReason == "语音合成完成但未返回音频数据")
    }
}
