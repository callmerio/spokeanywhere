#if DEBUG
import Foundation

let liveCaptionMockScenarioEnvKey = "SPOKE_DEBUG_LIVECAPTION_SCENARIO"
let liveCaptionMockScenarioBootstrapFilePath = "/tmp/spoke-livecaption-mock-scenario.txt"

struct LiveCaptionMockFrame: Equatable {
    enum Kind: Equatable {
        case pending
        case finalized
    }

    let kind: Kind
    let original: String
    let translation: String
}

func makeLiveCaptionLongTranslationMockFrames() -> [LiveCaptionMockFrame] {
    [
        .init(
            kind: .pending,
            original: "A spec that is with high fidelity able to reproduce the system as it is. It's fantastic. And you're basically, you're not really adding any of your human bias in there, right?",
            translation: "能够按本质再现系统的高保真规格。太棒了。你基本上没有真正加入任何人性偏见，对吗？"
        ),
        .init(
            kind: .pending,
            original: "A spec that is with high fidelity able to reproduce the system as it is. It's fantastic. And you're basically, you're not really adding any of your human bias in there, right? A lot of times people write us back and be like, okay, I think it should be done this way and you'll riff on something and it's like, no, the agent could have just handled it. Like, you're still scaffolding in a sense, right? I want it done this way.",
            translation: "能够按本质再现系统的高保真规格。太棒了。你基本上没有真正加入任何人性偏见，对吗？很多时候，人们回信说我觉得应该这样做，你就会顺着某种思路延伸，但其实代理本来就可以自己处理。从某种意义上说，你仍然在搭脚手架。你说，我希望它这样完成。"
        ),
        .init(
            kind: .pending,
            original: "A spec that is with high fidelity able to reproduce the system as it is. It's fantastic. And you're basically, you're not really adding any of your human bias in there, right? A lot of times people write us back and be like, okay, I think it should be done this way and you'll riff on something and it's like, no, the agent could have just handled it. Like, you're still scaffolding in a sense, right? I want it done this way. It can determine its spec better. That's right. That's right. Part of me, you know, I've been working a lot on evils recently, and part of me is wondering if an Asian can produce a spec that it cannot solve.",
            translation: "能够按本质再现系统的高保真规格。太棒了。你基本上没有真正加入任何人性偏见，对吗？很多时候，人们回信说我觉得应该这样做，你就会顺着某种思路延伸，但其实代理本来就可以自己处理。从某种意义上说，你仍然在搭脚手架。你说，我希望它这样完成。它可以更好地确定自己的规格。没错。没错。我最近一直在处理很多棘手的问题，其中一部分让我开始想，一个代理是否会产出它自己根本解不了的规格。"
        ),
        .init(
            kind: .pending,
            original: "A spec that is with high fidelity able to reproduce the system as it is. It's fantastic. And you're basically, you're not really adding any of your human bias in there, right? A lot of times people write us back and be like, okay, I think it should be done this way and you'll riff on something and it's like, no, the agent could have just handled it. Like, you're still scaffolding in a sense, right? I want it done this way. It can determine its spec better. That's right. That's right. Part of me, you know, I've been working a lot on evils recently, and part of me is wondering if an Asian can produce a spec that it cannot solve. Like, is it always capable of things that it can imagine or can you imagine things that it is impossible to do? I think with symphony, we, there's like this axis, right? Where you have things that are easier, hard, or established or new, right?",
            translation: "能够按本质再现系统的高保真规格。太棒了。你基本上没有真正加入任何人性偏见，对吗？很多时候，人们回信说我觉得应该这样做，你就会顺着某种思路延伸，但其实代理本来就可以自己处理。从某种意义上说，你仍然在搭脚手架。你说，我希望它这样完成。它可以更好地确定自己的规格。没错。没错。我最近一直在处理很多棘手的问题，其中一部分让我开始想，一个代理是否会产出它自己根本解不了的规格。比如，它是否总能完成自己能想象到的事，还是说你可以想象出它根本做不到的事？我觉得在 symphony 里，有这样一条轴线：事情可能更容易、更难、更成熟或者更新。"
        ),
        .init(
            kind: .pending,
            original: "A spec that is with high fidelity able to reproduce the system as it is. It's fantastic. And you're basically, you're not really adding any of your human bias in there, right? A lot of times people write us back and be like, okay, I think it should be done this way and you'll riff on something and it's like, no, the agent could have just handled it. Like, you're still scaffolding in a sense, right? I want it done this way. It can determine its spec better. That's right. That's right. Part of me, you know, I've been working a lot on evils recently, and part of me is wondering if an Asian can produce a spec that it cannot solve. Like, is it always capable of things that it can imagine or can you imagine things that it is impossible to do? I think with symphony, we, there's like this axis, right? Where you have things that are easier, hard, or established or new, right? And I think things that are hard and new is still something that the models need humans. But I think those other quadrants are largely solved given the right scaffold and the right thing that's going to drive the agent to completion.",
            translation: "能够按本质再现系统的高保真规格。太棒了。你基本上没有真正加入任何人性偏见，对吗？很多时候，人们回信说我觉得应该这样做，你就会顺着某种思路延伸，但其实代理本来就可以自己处理。从某种意义上说，你仍然在搭脚手架。你说，我希望它这样完成。它可以更好地确定自己的规格。没错。没错。我最近一直在处理很多棘手的问题，其中一部分让我开始想，一个代理是否会产出它自己根本解不了的规格。比如，它是否总能完成自己能想象到的事，还是说你可以想象出它根本做不到的事？我觉得在 symphony 里，有这样一条轴线：事情可能更容易、更难、更成熟或者更新。我认为那些又难又新的部分，模型现在依然需要人类；但另外几个象限，只要脚手架对、驱动力对，基本已经可以做完。"
        ),
        .init(
            kind: .pending,
            original: "A spec that is with high fidelity able to reproduce the system as it is. It's fantastic. And you're basically, you're not really adding any of your human bias in there, right? A lot of times people write us back and be like, okay, I think it should be done this way and you'll riff on something and it's like, no, the agent could have just handled it. Like, you're still scaffolding in a sense, right? I want it done this way. It can determine its spec better. That's right. That's right. Part of me, you know, I've been working a lot on evils recently, and part of me is wondering if an Asian can produce a spec that it cannot solve. Like, is it always capable of things that it can imagine or can you imagine things that it is impossible to do? I think with symphony, we, there's like this axis, right? Where you have things that are easier, hard, or established or new, right? And I think things that are hard and new is still something that the models need humans. But I think those other quadrants are largely solved given the right scaffold and the right thing that's going to drive the agent to completion. It's crazy that it's all, but it means that the humans, the ones with limited time and attention, get to work on the hardest stuff, right? Like the problems where it's pure white space out in front or like the deepest refactorings where you don't know what the proper shape of the interfaces are.",
            translation: "能够按本质再现系统的高保真规格。太棒了。你基本上没有真正加入任何人性偏见，对吗？很多时候，人们回信说我觉得应该这样做，你就会顺着某种思路延伸，但其实代理本来就可以自己处理。从某种意义上说，你仍然在搭脚手架。你说，我希望它这样完成。它可以更好地确定自己的规格。没错。没错。我最近一直在处理很多棘手的问题，其中一部分让我开始想，一个代理是否会产出它自己根本解不了的规格。比如，它是否总能完成自己能想象到的事，还是说你可以想象出它根本做不到的事？我觉得在 symphony 里，有这样一条轴线：事情可能更容易、更难、更成熟或者更新。我认为那些又难又新的部分，模型现在依然需要人类；但另外几个象限，只要脚手架对、驱动力对，基本已经可以做完。这件事很疯狂，但它意味着真正时间和注意力有限的人类，可以把精力放到最难的部分，比如前面完全是白纸的难题，或者那些你甚至不知道接口最终应该长成什么样的深度重构。"
        ),
        .init(
            kind: .finalized,
            original: "A spec that is with high fidelity able to reproduce the system as it is. It's fantastic. And you're basically, you're not really adding any of your human bias in there, right? A lot of times people write us back and be like, okay, I think it should be done this way and you'll riff on something and it's like, no, the agent could have just handled it. Like, you're still scaffolding in a sense, right? I want it done this way. It can determine its spec better. That's right. That's right. Part of me, you know, I've been working a lot on evils recently, and part of me is wondering if an Asian can produce a spec that it cannot solve. Like, is it always capable of things that it can imagine or can you imagine things that it is impossible to do? I think with symphony, we, there's like this axis, right? Where you have things that are easier, hard, or established or new, right? And I think things that are hard and new is still something that the models need humans. But I think those other quadrants are largely solved given the right scaffold and the right thing that's going to drive the agent to completion. It's crazy that it's all, but it means that the humans, the ones with limited time and attention, get to work on the hardest stuff, right? Like the problems where it's pure white space out in front or like the deepest refactorings where you don't know what the proper shape of the interfaces are.",
            translation: "能够按本质再现系统的高保真规格。太棒了。你基本上没有真正加入任何人性偏见，对吗？很多时候，人们回信说我觉得应该这样做，你就会顺着某种思路延伸，但其实代理本来就可以自己处理。从某种意义上说，你仍然在搭脚手架。你说，我希望它这样完成。它可以更好地确定自己的规格。没错。没错。我最近一直在处理很多棘手的问题，其中一部分让我开始想，一个代理是否会产出它自己根本解不了的规格。比如，它是否总能完成自己能想象到的事，还是说你可以想象出它根本做不到的事？我觉得在 symphony 里，有这样一条轴线：事情可能更容易、更难、更成熟或者更新。我认为那些又难又新的部分，模型现在依然需要人类；但另外几个象限，只要脚手架对、驱动力对，基本已经可以做完。这件事很疯狂，但它意味着真正时间和注意力有限的人类，可以把精力放到最难的部分，比如前面完全是白纸的难题，或者那些你甚至不知道接口最终应该长成什么样的深度重构。"
        ),
        .init(
            kind: .pending,
            original: "And this is where I want to spend my time because it lets me set up for the next level of scale. Yeah. Yeah. Amazing. Let's introduce symphony. I think we've been mentioning it every now and then. Elixir? Interesting option?",
            translation: "这也是我想投入时间的地方，因为它能让我为下一个规模层级做准备。是的。是的。太厉害了。我们来介绍一下 symphony。我想我们已经时不时提到它了。Elixir？这确实是个很有意思的选择。"
        ),
        .init(
            kind: .finalized,
            original: "Let's introduce symphony. I think we've been mentioning it every now and then. Elixir? Interesting option? Again, the elixir manifestation here is just a derivative. And it chose that because the process supervision and the gen servers are super amenable to the type of process orchestration that we're doing here, right? You are essentially spinning up little demons for every task that is in execution and driving it to completion.",
            translation: "我们来介绍一下 symphony。我想我们已经时不时提到它了。Elixir？这是个很有意思的选择。再说一次，这里的 elixir 形态其实只是一个衍生实现。之所以这样选，是因为它的进程监督和 gen server 非常适合我们现在这种流程编排方式。你本质上是在为每一个正在执行的任务生成小型守护进程，并一路把它推到完成。"
        )
    ]
}

private func liveCaptionMockScenarioFromBootstrapFile(
    fileManager: FileManager = .default
) -> String? {
    guard fileManager.fileExists(atPath: liveCaptionMockScenarioBootstrapFilePath),
          let raw = try? String(contentsOfFile: liveCaptionMockScenarioBootstrapFilePath, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
          !raw.isEmpty else {
        return nil
    }
    return raw
}

func liveCaptionMockScenarioFromEnvironment(
    _ environment: [String: String] = ProcessInfo.processInfo.environment
) -> String? {
    guard let raw = environment[liveCaptionMockScenarioEnvKey]?
        .trimmingCharacters(in: .whitespacesAndNewlines),
          !raw.isEmpty else {
        return liveCaptionMockScenarioFromBootstrapFile()
    }
    return raw
}

func liveCaptionHasMockScenario(
    _ environment: [String: String] = ProcessInfo.processInfo.environment
) -> Bool {
    liveCaptionMockScenarioFromEnvironment(environment) != nil
}
#endif
