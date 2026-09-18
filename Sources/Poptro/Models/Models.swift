import Foundation

/// 一条"快捷键 -> 打开某个 App"的绑定记录
struct LaunchBinding: Codable, Identifiable, Equatable {
    let id: UUID
    var appName: String
    var appBundlePath: String   // .app 的完整路径
    var hotkeyName: String      // 对应 KeyboardShortcuts.Name 的 rawValue,格式如 "launch_<uuid>"
    var isEnabled: Bool

    init(id: UUID = UUID(), appName: String, appBundlePath: String, isEnabled: Bool = true) {
        self.id = id
        self.appName = appName
        self.appBundlePath = appBundlePath
        self.hotkeyName = "launch_\(id.uuidString)"
        self.isEnabled = isEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        appName = try container.decode(String.self, forKey: .appName)
        appBundlePath = try container.decode(String.self, forKey: .appBundlePath)
        hotkeyName = try container.decodeIfPresent(String.self, forKey: .hotkeyName)
            ?? "launch_\(id.uuidString)"
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }
}

/// 翻译服务商
enum TranslationProvider: String, Codable, CaseIterable, Identifiable {
    case zhipu
    case openai
    case deepl
    case groq
    case google
    case ollama

    var id: String { rawValue }

    /// 下拉菜单里显示的名字。以后要加新服务商,在这里加一行 case 和 displayName 就行,
    /// 设置界面的下拉菜单会自动列出所有 case,不需要改 UI 代码。
    var displayName: String {
        switch self {
        case .zhipu: return "智谱 GLM(默认,免费模型)"
        case .openai: return "OpenAI(GPT 系列)"
        case .deepl: return "DeepL"
        case .groq: return "Groq"
        case .google: return "Google AI(Gemini)"
        case .ollama: return "Ollama(本地模型,免费离线)"
        }
    }

    var requiresAPIKey: Bool { self != .ollama }

    var supportsRemoteModelDiscovery: Bool {
        switch self {
        case .deepl: return false
        default: return true
        }
    }
}

/// 弹窗外观:浅色/深色是强制指定(不管系统当前是什么模式),跟随系统则由系统决定
enum PanelAppearanceMode: String, Codable, CaseIterable, Identifiable {
    case light
    case dark
    case system

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: return "浅色"
        case .dark: return "深色"
        case .system: return "跟随系统"
        }
    }
}

/// 常用语言目录,两家服务商共用同一套(OpenAI 用 label 拼进 prompt,DeepL 用 code 传给接口),
/// 弹窗内切换目标语言、设置里选主/备语言,都是从这一份列表选。
/// 覆盖范围对齐 NaturalLanguage 框架能识别的语种,尽量覆盖主要语系。
enum SupportedLanguage {
    static let options: [(code: String, label: String)] = [
        ("ZH", "中文(简体)"),
        ("EN-US", "英语(美式)"),
        ("EN-GB", "英语(英式)"),
        ("JA", "日语"),
        ("KO", "韩语"),
        ("FR", "法语"),
        ("DE", "德语"),
        ("ES", "西班牙语"),
        ("IT", "意大利语"),
        ("PT-BR", "葡萄牙语(巴西)"),
        ("PT-PT", "葡萄牙语(葡萄牙)"),
        ("RU", "俄语"),
        ("NL", "荷兰语"),
        ("PL", "波兰语"),
        ("TR", "土耳其语"),
        ("VI", "越南语"),
        ("TH", "泰语"),
        ("ID", "印尼语"),
        ("MS", "马来语"),
        ("AR", "阿拉伯语"),
        ("HE", "希伯来语"),
        ("HI", "印地语"),
        ("BN", "孟加拉语"),
        ("UR", "乌尔都语"),
        ("FA", "波斯语"),
        ("EL", "希腊语"),
        ("SV", "瑞典语"),
        ("DA", "丹麦语"),
        ("FI", "芬兰语"),
        ("NB", "挪威语"),
        ("CS", "捷克语"),
        ("SK", "斯洛伐克语"),
        ("HU", "匈牙利语"),
        ("RO", "罗马尼亚语"),
        ("BG", "保加利亚语"),
        ("UK", "乌克兰语"),
        ("HR", "克罗地亚语"),
        ("SL", "斯洛文尼亚语"),
        ("ET", "爱沙尼亚语"),
        ("LV", "拉脱维亚语"),
        ("LT", "立陶宛语"),
        ("CA", "加泰罗尼亚语"),
        ("IS", "冰岛语"),
        ("KM", "高棉语"),
        ("MY", "缅甸语"),
        ("LO", "老挝语"),
        ("MN", "蒙古语"),
        ("TA", "泰米尔语"),
        ("TE", "泰卢固语"),
        ("KN", "卡纳达语"),
        ("ML", "马拉雅拉姆语"),
        ("MR", "马拉地语"),
        ("GU", "古吉拉特语"),
        ("PA", "旁遮普语"),
        ("SI", "僧伽罗语"),
        ("BO", "藏语"),
        ("HY", "亚美尼亚语"),
        ("KA", "格鲁吉亚语"),
        ("AM", "阿姆哈拉语"),
        ("KK", "哈萨克语")
    ]

    static func label(for code: String) -> String {
        options.first { $0.code == code }?.label ?? code
    }

    /// DeepL 官方支持的目标语言代码。这份列表是我按 2026 年初已知的 DeepL 支持范围整理的,
    /// DeepL 会不定期新增语言,如果你发现某个语言明明 DeepL 已经支持了但这里被挡住,
    /// 去 DeepL 官方文档核实后把对应代码加进这个集合就行。
    static let deeplSupportedCodes: Set<String> = [
        "ZH", "EN-US", "EN-GB", "JA", "KO", "FR", "DE", "ES", "IT", "PT-BR", "PT-PT",
        "RU", "NL", "PL", "TR", "VI", "ID", "AR", "EL", "SV", "DA", "FI", "NB",
        "CS", "SK", "HU", "RO", "BG", "UK", "ET", "LV", "LT", "SL"
    ]
}

/// 翻译相关设置(API Key 单独存 Keychain,这里只存非敏感配置)
struct TranslationSettings: Codable {
    var provider: TranslationProvider = .zhipu

    // gpt-4.1-mini: 无推理步骤、延迟低,1M 超大上下文(长文不怕截断),
    // 价格便宜,是"划词弹窗即时翻译"这个场景质量/速度的最佳平衡点。
    // 想要更高质量可在设置里换成 gpt-5.4-mini 或 gpt-5.4(会稍慢、稍贵)。
    var model: String = "gpt-4.1-mini"
    var zhipuModel: String = "glm-4-flash-250414"
    var groqModel: String = "qwen/qwen3.8-27b"
    var googleModel: String = "gemini-3.5-flash-lite"

    // 只负责"风格/格式"规则,方向(翻成哪种语言)在发请求时由代码明确指定,
    // 这里不再包含"自动判断中英方向"这句话——之前这句话和运行时追加的强制方向指令冲突,
    // 会让模型收到两条互相矛盾的指示,容易导致翻译方向不稳定。
    var customSystemPrompt: String = """
    你是一个专业翻译引擎。只输出翻译结果,不要任何解释、不要加引号、不要重复原文。
    - 如果输入只是一个单词或短语:给出最常用、最贴切的译文;若该词有多个常见含义,用"; "分隔列出最多3个,不加编号。
    - 如果输入是完整句子或长文:保持原意准确、语句通顺自然,符合目标语言的表达习惯,不要逐字直译。
    - 保留原文中的专业术语、人名、品牌名、代码片段、数字和单位格式,不要擅自转换单位。
    - 保留原文的段落结构和换行。
    """

    // 两家服务商共用同一套目标语言配置(语言代码),不再分开存
    var primaryLanguageCode: String = "ZH"      // 中文(简体)
    var secondaryLanguageCode: String = "EN-US" // 英文(美式)

    // MARK: Ollama 专用(本地跑的模型,不需要 API Key)
    var ollamaBaseURL: String = "http://localhost:11434"
    var ollamaModel: String = "qwen3:8b"

    /// 浅色/深色/跟随系统,默认浅色
    var panelAppearanceMode: PanelAppearanceMode = .light

    private static let filename = "translation_settings.json"
    private static let deprecatedModels = ["gpt-4o-mini", "gpt-4o", "gpt-3.5-turbo"]

    init() {}

    // 手写 Decodable 实现:每个字段用 decodeIfPresent + 默认值兜底,而不是用编译器自动生成的版本。
    // 自动生成的版本要求 JSON 里必须包含每一个字段,新增字段后旧版本存的 JSON 会整体解码失败、
    // 静默回退成全新默认值,导致用户之前调过的设置(模型选择、自定义 prompt 等)全部被冲掉。
    // 手写这版之后,以后再加新字段,旧配置文件只是缺这一个新字段用默认值,其它已保存的设置不受影响。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        provider = try c.decodeIfPresent(TranslationProvider.self, forKey: .provider) ?? .zhipu
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? "gpt-4.1-mini"
        zhipuModel = try c.decodeIfPresent(String.self, forKey: .zhipuModel) ?? "glm-4-flash-250414"
        groqModel = try c.decodeIfPresent(String.self, forKey: .groqModel) ?? "qwen/qwen3.8-27b"
        googleModel = try c.decodeIfPresent(String.self, forKey: .googleModel) ?? "gemini-3.5-flash-lite"
        customSystemPrompt = try c.decodeIfPresent(String.self, forKey: .customSystemPrompt)
            ?? TranslationSettings().customSystemPrompt
        primaryLanguageCode = try c.decodeIfPresent(String.self, forKey: .primaryLanguageCode) ?? "ZH"
        secondaryLanguageCode = try c.decodeIfPresent(String.self, forKey: .secondaryLanguageCode) ?? "EN-US"
        ollamaBaseURL = try c.decodeIfPresent(String.self, forKey: .ollamaBaseURL) ?? "http://localhost:11434"
        ollamaModel = try c.decodeIfPresent(String.self, forKey: .ollamaModel) ?? "qwen3:8b"
        panelAppearanceMode = try c.decodeIfPresent(PanelAppearanceMode.self, forKey: .panelAppearanceMode)
            ?? .light
    }

    /// 统一的读取入口:自动把旧版本残留的已退场模型名迁移到当前推荐模型。
    /// 设置界面和实际发起翻译请求的地方都应该用这个,而不是直接调 LocalStore.load。
    static func loadCurrent() -> TranslationSettings {
        var settings = LocalStore.load(TranslationSettings.self, filename: filename, default: TranslationSettings())
        if deprecatedModels.contains(settings.model) {
            settings.model = "gpt-4.1-mini"
            settings.save()
        }
        return settings
    }

    func save() {
        LocalStore.save(self, filename: Self.filename)
    }

    /// 按语言代码取展示名(不区分服务商,两边共用同一套语言目录)
    func languageLabel(isPrimary: Bool) -> String {
        SupportedLanguage.label(for: isPrimary ? primaryLanguageCode : secondaryLanguageCode)
    }

    func model(for provider: TranslationProvider) -> String {
        switch provider {
        case .zhipu: return zhipuModel
        case .openai: return model
        case .groq: return groqModel
        case .google: return googleModel
        case .ollama: return ollamaModel
        case .deepl: return "DeepL"
        }
    }

    mutating func setModel(_ value: String, for provider: TranslationProvider) {
        switch provider {
        case .zhipu: zhipuModel = value
        case .openai: model = value
        case .groq: groqModel = value
        case .google: googleModel = value
        case .ollama: ollamaModel = value
        case .deepl: break
        }
    }
}

/// 悬浮翻译窗口上次的位置和大小。位置每次拖动都会记住;
/// 大小只有在用户真的手动拖过边缘/角落调整过之后才会被记住并在下次沿用,
/// 避免内容自适应高度产生的临时尺寸被误当成"用户想要的大小"存下来。
struct PanelPosition: Codable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var wasManuallyResized: Bool

    private static let filename = "panel_position.json"

    init(x: Double, y: Double, width: Double, height: Double, wasManuallyResized: Bool) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.wasManuallyResized = wasManuallyResized
    }

    // 手写解码,兼容只存了 x/y 的旧版本文件(宽高和标记字段缺失时给默认值)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        x = try c.decode(Double.self, forKey: .x)
        y = try c.decode(Double.self, forKey: .y)
        width = try c.decodeIfPresent(Double.self, forKey: .width) ?? 400
        height = try c.decodeIfPresent(Double.self, forKey: .height) ?? 340
        wasManuallyResized = try c.decodeIfPresent(Bool.self, forKey: .wasManuallyResized) ?? false
    }

    static func loadCurrent() -> PanelPosition? {
        LocalStore.load(PanelPosition?.self, filename: filename, default: nil)
    }

    func save() {
        LocalStore.save(self, filename: Self.filename)
    }
}

/// 简单的本地 JSON 持久化工具,存放在 ~/Library/Application Support/Poptro/。
/// 首次运行会无损迁移旧名称 MenuBarTranslator 下的配置。
enum LocalStore {
    private static let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Poptro", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let legacy = base.appendingPathComponent("MenuBarTranslator", isDirectory: true)
        if let files = try? FileManager.default.contentsOfDirectory(at: legacy, includingPropertiesForKeys: nil) {
            for source in files {
                let destination = dir.appendingPathComponent(source.lastPathComponent)
                if !FileManager.default.fileExists(atPath: destination.path) {
                    try? FileManager.default.copyItem(at: source, to: destination)
                }
            }
        }
        return dir
    }()

    static func load<T: Decodable>(_ type: T.Type, filename: String, default defaultValue: T) -> T {
        let url = directory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(T.self, from: data) else {
            return defaultValue
        }
        return decoded
    }

    static func save<T: Encodable>(_ value: T, filename: String) {
        let url = directory.appendingPathComponent(filename)
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url)
    }
}
