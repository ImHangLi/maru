# Stack（开发代号）· V1.2 产品与技术规格

日期：2026-10-10  
状态：供开发、真机验收及首发准备使用的设计规格；不是已实现或通过测试的 App。性能数值均为拟定预算，不是测量结果。  
平台：iPhone 与 iPad 原生（iPad 见 `docs/decisions.md` D072，各设备数据独立、不同步），建议兼容 iOS 17 起；正式提交采用 Apple 当时要求的 SDK，依赖按可用稳定版本锁定。  
优先级：本文件取代旧版 `supplement_app_v1_spec.md` 与 `supplement_app_v1_retention_addendum.md` 中相冲突的范围、默认值、库存/换瓶流程、指标和技术选择。旧文件保留为历史资料，不再直接作为开发指令。

> Amendments (2026-10-11, see `docs/decisions.md` D032): a new item starts as a supplement with the capsule form, and the user can change both. No default amount and no default reminder time (§2.1) stay. The example time of a supplement is the start value of the time picker, not a time in the draft. The plan preview uses no "·" separator. The English name of "我的清单" is "My Items", and it is a grid. These amendments override conflicting text below.
>
> Amendments after V1.2 (2026-10-10, see `docs/decisions.md` D006): add a user-entered intake note per item, for example "with food" or "empty stomach" (milestone A), and a passive history heatmap with no streaks (milestone B). These amendments override conflicting text below.

> Amendments of 2026-10-11 (D021): every flow must be simpler than Apple Health Medications. Milestone A adds an item color, one control that records a whole time slot, an optional follow-up reminder (off by default), as-needed items recorded from Today, and IU as an amount unit. The app has one fixed pink tint and no accent setting. Today uses the header wash of Apple Health on a gray page with white cards, and shows slot names, not clock times (D011). Visual details are in `docs/design.md`. These amendments override conflicting text below.

## 0. 要交付的结果

> 到点提醒，一眼看清安排，随手留下一次可信的记录。

用户已经决定服用什么；App 不替他决定开始、停用、补服、调整剂量或治疗。服务日常补剂和简单、用户确认的药品日程，不自称完整医疗管理系统。

首要任务：
1. 很快建立一个自己确认的提醒。
2. 在忙乱中看清本次安排。
3. 回看本次是否留下记录，以及记录的实际时间。

用户不需要维护库存，不需要每天进 App，不需要填满历史。习惯支持是产品用途；不把改善疗效、避免所有漏服/重复服用、最佳吸收等未验证结果当成承诺。

截图中的广告投入及审核经历是个人自述，不是本产品的收入、获客成本或审核结果。开发、可持续使用、分发、盈利是不同验收问题。先做可自用版本，不强制把访谈数量作为开发前置条件；公开发布前的安全、隐私和关键可靠性验收仍是必需。

## 1. 本轮冻结的范围

| 决定 | 实现要求 |
|---|---|
| 没有库存 | 不建立瓶数、剩余量、耗尽时间、补货提醒、SupplyEvent、InventoryEstimate 或库存界面 |
| 同款换瓶零操作 | 没有“补充一瓶”按钮；同款同规格继续买、继续用，App 不改变任何东西 |
| 默认无结束日期 | `end_at = nil`；按已确认频率提醒，直到用户修改、关闭或归档 |
| 结束日期是高级选项 | 有限提醒必须有确实可兑现的停止实现；未通过真机验收时隐藏该能力，不能靠未来某次启动补做停止 |
| 默认日常入口 | 两个 Tab：今天、我的清单；新会话进入今天；短暂后台返回保留当前页面 |
| 不建账户 | 无登录、邮箱、Profile、健康目标问卷；StoreKit 购买不意味着创建 App 账户 |
| 本地优先 | 清单、日程、记录、照片和规则查询不以网络为前提 |
| 图像是辅助 | 默认小图标 + 完整文字；用户可选用自己的瓶身照片；抠图不阻塞设置或记录 |
| 不惩罚中断 | 未记录保持未知；不欠账、不自动补记、不付费补签 |
| 上线具备可观察性 | 开发期本地性能和错误诊断；公测/上线时具备经明确同意的最小产品分析与反馈 |
| 商业不干扰核心 | 核心免费、无广告；支持者购买后置于设置，不阻塞本地功能 |
| 宣传聚焦 | 提醒、混乱时清楚、回看记录；换瓶/断签恢复是基本质量，不是首屏主要卖点 |

### 明确不做

AI 聊天、库存/购买推荐、药品外观自动鉴定、个性化剂量与补服建议、健康评分、streak 惩罚、排行榜、动态药柜小游戏、社区、家庭远程监督、血检分析、健康数据云同步、注册账户、完整相互作用检查、以广告 SDK 变现。

V1 不自动处理每 X 小时、递减剂量、复杂循环（“服 N 天停 M 天”这一种固定周期除外，D065）、按指标改变剂量及儿童用量。不要把不支持的用法悄悄变成“每天一次”。

## 2. 默认值、权限与设置

### 2.1 低摩擦不等于悄悄做决定

- 初始提醒频率可以在草稿中显示“每天”，但保存前必须可见、可改、由用户确认。
- 重复规则可选：每天、按星期几、隔天一次（D036）、每隔几天（每 3 到 30 天一次）、服几天停几天的周期（如服 21 天停 7 天）（D065）。后三种按日历日计数。选隔天一次时，第一天由用户在“今天开始”和“明天开始”之间选定。选每隔几天或周期时，天数由用户选定，第一天由用户选“今天开始”“明天开始”或另一个日期，日期可以早于今天（周期已经开始时）。天数和第一天 App 都不预选；未选定不能保存。预览用自然语言写出，例如“隔天一次，08:00，明天开始”或“服 21 天，停 7 天，08:00，自 10 月 13 日起”。变化的用量和按小时的间隔仍不支持（§1）。
- 补剂可沿用用户之前确认过的生活时段。首次没有现有时段时，提供一个清楚标为“提醒时间”的示例预选值，而不是“最佳服用时间”。该值不因药名自动获得医学依据。
- 药品的提醒钟点由用户确认；不能仅根据药名默认早晚两次或固定 09:00。识别到的标签用法也需用户核对。
- 保存按钮上方展示完整预览：例如“每天 08:00、20:00 · 不设结束日期”。示例时间不是实际用户用药建议。
- 用户暂不想设时间：允许“以后设置”，保存清单，不发送通知；这是有效的仅清单状态，不假装已开启提醒。
- 不默认填“一粒”。实际服用量可由用户填写，也可留空做名称提醒；留空时不展示或推算数量。若显示扫描出的量，必须核对后采用。
- 产品含量、每份粒数、用户实际一次服用量分开保存。基本提醒不要求填完整成分数据库。
- 标签明确包含疗程/结束要求时，提示核对；不能忽略已知有限要求，把它自动变成无限期治疗提示。
- 智能补全（D043，部分修改本节）：仅限补剂。名称完整匹配内置补剂清单时，剂型自动改为该补剂的常见剂型，但仅限用户在本页尚未选过剂型；之后只作为一键提议，不覆盖用户的选择。用量、提醒时间、备注只显示候选按钮，点选后才填入。类型为药品或名称在药品清单中时，不显示任何候选。候选不是医学建议。

### 2.2 权限

相机：点击扫描时申请；拒绝后手动添加可用。相册：优先系统 PhotosPicker，仅处理用户选中的照片。通知：用户确认首个提醒后，在有上下文时申请。分析同意与通知权限不同，分别处理。

拒绝通知后保留记录功能。设置和首页的非阻断状态必须诚实；不重复弹系统权限请求。申请提醒权限不是设置默认医学时间的授权。

## 3. 页面、信息优先级和跳转

### P01 今天

元素：
- 导航标题“今天”、日期、历史入口、添加入口与标准“更多”菜单。
- 当前或下一时段，显示具体钟点。
- 单项行：小图标/照片、名称、可选的已确认规格与实际用量、状态/操作。
- 已记录项目保留简短可见行，例如“早间项目 · 已记录 08:07”，不把用户最想查询的信息彻底藏起来。
- 后续时段可展开。当天较早未记录事项用中性文字呈现；不默认变成应补服任务。
- 不显示库存、营销卡、AI 输入框、健康分或强制动画。

示意仅表示信息结构：

```text
今天                         历史  ＋  更多

08:00
[小图] 项目 A
       用户确认的规格/一次量     已记录 08:07

20:00
[小图] 项目 A
       用户确认的规格/一次量     记录已服
```

实际剂量不由示例填入用户数据。

行名称区域进入详情，记录按钮是独立命中区域。不能把整行点击都当作已服。按钮被按下可即时有按压反馈；“成功”文字和成功触感在本地事务提交后出现。已完成状态点击进入更正菜单，不作为容易误触的开关。

### P02 我的清单

活动项目、添加、归档入口、设置。无独立账户。名称搜索仅查本地已有项目及已审校资料；输入内容不上传为分析事件。

### P03 添加/核对（一个编辑流，不做多页教程）

输入来源：扫描标签、搜索/手动。必需名称；明确类别或按未知药品谨慎处理；用量可选，不猜测。识别结果待核对。填写提醒或以后设置。保存后回来源，保留滚动位置；可继续加一项。

扫描模糊、缺背面、语言不支持时可继续手动，不要求重拍到识别成功。草稿可恢复。只有未保存修改时才问是否丢弃。

快捷输入（D038）：
- 扫描标签：新增项目时，名称上方有“扫描标签”。相机对准瓶身，用户点选标签上的名称，名称填入名称栏，仍可修改。实时扫描在设备上识别文字，不保存照片，不联网。
- 名称建议：名称栏输入两个字符后，显示内置名称清单中的建议。清单包含常见补剂和药品，只含名称。点选后只填名称。
- 各语言名称清单（D070）：简体中文、日语、韩语、西班牙语、德语各有一份本地常用补剂和药品清单（通用名，不含品牌），先于英文清单显示；英文清单在所有语言中都可搜索。中日韩文字输入一个字即可建议；平假名匹配片假名；韩文未打完的音节，末尾辅音可作本音节收音或下一音节初声，只缩小结果。本地补剂名对应英文条目时，使用相同的智能补全。
- 规则：扫描或建议得到的值只是提议。用户在编辑页看到该值，再用正常的“保存”保存。提议不设置类别、用量和提醒时间。剂型规则见下方智能补全（D043 修改了 D038 的剂型规则）。
- 智能补全（D043）：补剂名称完整匹配内置清单（含别名）后，剂型改为标签扫描到的剂型，否则为常见剂型，仅限用户在本页尚未选过剂型；之后显示“使用某剂型”一键提议。药品只保留扫描剂型的一键提议。用量、时间、备注在各自栏位下显示小按钮候选，点选才填入；时间候选用“早上/中午/晚上”的时段词，点选后像“添加时间”一样加入一个可改的提醒时间。候选下方一句说明：建议来自常见标签，请核对自己的标签。切换为药品时候选立即消失，已填的值保留。
- 名称清单只是输入辅助，不是医学资料。

### P04 项目详情

名称、图像、当前安排、最近记录、标签/有限资料依据；编辑按钮。

底部用普通次级行：**“更换或结束此项…”**，打开小型操作菜单：
- 更换产品/规格：核对新资料和生效时间，不自动换算用量。
- 关闭提醒：保留今天/清单和手动记录能力，状态清楚。
- 归档此项：取消该项未来提醒，保留历史；确认文案说明这是 App 操作，不是停药建议。

不能写“你已经吃完了”，因为 App 不知道。无同款续瓶操作。扫描到同款候选时提示“清单里已有此项”，可查看、修改，或确认确实要另建；不需要填数量。

### P05 历史与更正

按日期看已服、跳过、未记录。实际服用时间和记录时间分开。用户知道过去实际吃过时可补记某一次；不知道时保持未记录。没有批量填满过去以恢复连续性的功能。

页面顶部是一张方格图（D041）：每天一格，每列一周；颜色按当天计划剂量中已服的比例分三级，跳过不算已服，按需项目不计。没有标题、计数或连续天数。跨度随使用增长：13 周、26 周、52 周；满一年后显示最近 52 周，更早的日子仍在下方的时间线里。点按或拖动选中一天，时间线滚到那一天。

### P06 设置与反馈

设置：提醒状态、锁屏显示、语言、显示辅助、导出/恢复、隐私/删除、帮助、反馈、支持者购买。

反馈入口：今天的标准“更多”菜单中有“发送反馈”；设置中也有同一入口；错误状态提供“报告问题”。不使用悬浮客服球、自动弹问卷、摇一摇专用入口或反复询问“喜欢我们吗”。

表单只需正文；邮箱、类型、截图和经过脱敏的诊断资料均可选。发送前预览附件。无邮件账户也能通过安全表单端点发送；失败保留草稿，离线不报成功。健康问题反馈不是临床支持渠道。

## 4. 回访与低打扰状态

- 未记录一天或一周：直接今天；旧状态不变，不先展示欠账清单。
- 很久后回来：可进入“核对当前安排”；不强制补旧记录，不复活已关闭的提醒。
- 只要提醒的人：不打卡不加频、不自动降频，不触发营销召回。
- 默认每个已确认时点一条提示，不无限追问。后续提示默认关闭；用户可自选次数（1、2、3、5 次或“直到记录”）和间隔（5、10、15、30 分钟或 1 小时）（D039）。“直到记录”也有上限：系统最多保留 64 条待发请求，App 不在后台运行，所以每个时点最多 12 条；中途修改设置也不超过 12 条，已发出的照算。后续提示在同一项目的下一个时点之前、且最晚到次日 01:00 之前发出，所以深夜的时点也有后续提示；设置中写明这个数字和时间，不宣称无限提醒。
- 同一时点可以合并提示，但不为合并移动用户的安排，也不表示药品被证明可同服。
- 记录完成后不跳到下一个页面、不播放必须等待的动画，不让列表突然重排导致误点。
- 再次查看时必须区分“没有记录”和“确认没有服用”。

## 5. 图像与苹果原生设计

### 5.1 展示决策

默认是小型中性的系统风格图标 + 文字。已知剂型可用相应图形；未知就用中性符号，不能猜形状、颜色或具体药片。SF Symbols 用于通用控件和辅助，不充当商品鉴定。

用户可把扫描时的一张照片设为辅助图片，另有直接拍照/选择照片入口。没有照片的人不会看到空白大卡片，也不需要挑选几十个图标。

不从网上按名字自动拉包装图，不用生成式 AI 重画药瓶。原因是避免规格/地区包装误匹配、额外网络依赖和未解决的图像使用权；这是本产品的风险取舍，不声称有研究证明照片对所有人最好。

关于图标理解的研究提醒：抽象药品图示需要在具体人群中验证；不是跨语言天然无歧义。[S03] Apple Health 也把形状/颜色作为可选辅助，信息主体仍保留文字。[S01]

### 5.2 照片处理流水线

实时标签扫描（§3 P03，D038）不经过此流水线，不保存任何图片。

```text
相机/PhotosPicker
  → 正确旋转、去除 EXIF 及位置元数据
  → 解码前降采样
  → OCR 与展示图片分离
  → 用户选择保留辅助图片
  → 可选设备端主体分离
  → 用户确认主体/裁切
  → 本地写入显示素材及预解码缩略图
```

- 文字识别与抠图异步，不在 SwiftUI body 或首屏布局期间计算。
- 主体分离使用 Apple Vision/VisionKit 的已支持接口，检查设备与系统能力。[S04]
- 有多瓶、手、反光或错误主体时，不擅自选择并替换；保留普通裁切照片即可。
- 不抠掉标签文字后再生成；不将处理后的图像作为独立药品身份依据。
- 列表素材建议 40–48 pt；存储 1x/2x/3x 所需的紧凑位图，而非每次解码原始大图。
- 设置可在抠图未完成时立即保存；取消编辑后，过期异步任务不得写回其他项目。用 assetID + 编辑 revision 校验结果。
- 未选择保留的扫描原图完成核对后删除；临时目录不残留。

### 5.3 原生设计与可访问性

SwiftUI 原生 NavigationStack、TabView、List/Form、Sheet、系统字体、系统日期/时间选择器。品牌存在于独立图标、一个克制的强调色和少量非阻断反馈，不复制 Apple Health 品牌资产。

支持 Dynamic Type 的辅助字号、VoiceOver、深浅色、Increase Contrast、Reduce Motion。可点击目标至少以 44×44 pt 为预算；药名、用量和关键状态不得截断成无法辨认的省略号。小图标与颜色不是唯一信息通道。[S02]

大字时按钮下移或行高增长，不缩小字号来维持截图观感。同类同名项目必须能用用户确认的规格/备注辨别。关闭全部图片、颜色或动效，主路径仍完整可用。

## 6. 技术栈与模块边界

推荐单个原生 App 仓库，少量本地模块，不做微服务体系。

| 部分 | 选择 | 理由/约束 |
|---|---|---|
| UI | SwiftUI + 系统控件 | 原生导航、文字和辅助功能；少量 UIKit 桥接仅在系统能力需要时使用 |
| 状态 | 明确的 feature state / reducer 或小型 ViewModel | 不为此引入大型架构框架；UI 状态不能替代数据库事实 |
| 存储 | SQLite，经 GRDB 使用 | 明确事务、唯一约束、迁移与按需查询；这是项目选择，不声称 SwiftData 做不到 [S11] |
| 提醒 | UserNotifications | 系统本地交付；核心不依赖服务端、互联网或常驻进程 [S05] |
| 扫描 | Vision / VisionKit | 设备端 OCR，结构化解析与人工核对分开 |
| 图片 | ImageIO + Vision + 本地缓存 | 先降采样、异步处理、不阻塞首页 |
| 小组件 | WidgetKit + 受控 App Group 快照 | 首版只展示/打开记录页，不作为唯一实时状态或关键提醒通道 |
| Apple Watch | WatchConnectivity，手表端无数据库 | iPhone 数据库是唯一事实来源；手表只显示 iPhone 发来的今日清单，并请求 iPhone 记录；iPhone 提交成功并回复后才显示已记录（D071） |
| 购买 | StoreKit 2 | 单一支持者包可后置，权益与健康资料分开 |
| 性能 | os_signpost、Instruments、XCTest；可选脱敏 MetricKit | 本地先测，生产上传另受隐私策略限制 [S07][S08] |
| 使用分析 | AnalyticsClient 接口 + PostHog 适配器 | 仅明确同意后启用，显式事件、严格字段表，无自动录屏 [S09][S10] |
| 反馈 | URLSession → 单一 HTTPS 支持端点 | 有大小限制、限流、幂等与明确状态；不建用户账号 |

建议目录：

```text
App/
Features/Today/  Features/Stack/  Features/ItemEditor/
Features/History/  Features/Settings/  Features/Feedback/
Core/Domain/  Core/Scheduling/  Core/Records/
Infrastructure/Database/  Infrastructure/Notifications/
Infrastructure/Scanning/  Infrastructure/Images/
Infrastructure/Analytics/  Infrastructure/Support/
Widgets/
Resources/Localization/  Resources/ReviewedAdvice/
Tests/Domain/  Tests/Database/  Tests/Privacy/  UITests/
```

UI 只调用领域操作，不直接散落写库、StoreKit 或 PostHog。数据库和提醒服务是不同事务系统，不假装一次 `save()` 就代表系统提醒已经成功。

## 7. 数据模型与不变量

### 7.1 主要对象

| 对象 | 最小字段与责任 |
|---|---|
| Item | stableID、类别、显示名称、归档状态、图像引用；不包含瓶数 |
| ProductVersion | itemID、核对过的名称/规格/标签、来源、核对时间、生效范围 |
| Schedule | stableID、itemID、开启状态、可选结束范围；与临床治疗状态无等号 |
| ScheduleSlot | stable slotID，例如上午那次/晚间那次；改时间不自动产生一个新的“上午剂次” |
| ScheduleVersion | 周规则、钟点、用户填写的单次量、时区策略、有效区间、产品版本 |
| Occurrence | 稳定 ID、slotID、逻辑计划日期、原计划时刻及版本快照；今天与昨天不混用 |
| IntakeEvent | eventID、occurrenceID、动作、实际时间、记录时间、来源、修订关系 |
| NotificationSeries | seriesID、systemRequestID、对应 slots/版本、编译策略与调度状态 |
| Advice | 规则与版本、来源、形态和条件、语言、审校信息；不含自动改变用户安排的权限 |
| Preferences | 语言、显示、提醒隐私、分析同意；与健康资料分离 |
| LocalDailyUsage | 仅同意后的粗粒度功能使用标记，不存药名/每剂时间 |
| FeedbackDraft | 用户主动输入和选择的附件；不自动拷贝健康数据库 |

### 7.2 记录事务

```text
用户选择某一次“已服”
 → 校验 occurrence、版本及当前状态
 → 原子事务写事件 + 当前投影（唯一约束 / 幂等键）
 → 提交成功
 → UI 更新 + 轻触反馈
 → 异步清理已交付提示、更新小组件快照、更新本地日汇总
```

事务失败：不显示“已记录”，不发成功触感；原项目仍待处理，提供重试。按压态本身可以立即响应，但不冒充持久化成功。分析失败永远不能回滚真实健康记录。

当前状态：未记录 / 已记录为已服 / 记录为跳过；“稍后提醒”不是服用状态。每次只允许一个有效状态，修订保留可恢复关系，不形成两次有效服用。

**重要边界：**修改今天上午的提醒钟点，如果今天上午已经有记录，不应新生另一次待服。稳定 slot 与 occurrence 映射跨编辑保留；只有用户明确增加另一时点，才建立另一个独立 slot。产品规格或提醒时间变化不重写过去。

用户确实提前服用未来事项时，单独选择对应事项，显示明确日期；不能把点击明天那行默认为今天刚吃的一次。

数字与单位保留精确原始形式；不自动把 mg/μg、元素量/化合物总量、每份/每粒相互转换。若需数值运算，用受约束十进制或分数类型，并有经验证规则；基础记录不需要这类计算。

### 7.3 持久化与恢复

开启数据库唯一约束和外键；迁移版本固定。查询今天及少量上下文，不在启动时读全历史或生成无限未来事项。持久化照片放独立受保护文件，数据库只存引用。

迁移、磁盘不足、损坏时，禁止“清空重建以恢复可用”。进入明确的安全错误页，保留文件与恢复路径；不要假装清单为空。

A delete of one item with its records, which the user asks for and confirms, is a different thing: it runs in one transaction, it changes no other item, and it is never a way to recover from an error (D033).

用户主动发起并确认的“从备份恢复”同样不属于上面禁止的“清空重建”：它是整体替换，不合并两份数据，也绝不作为出错后的自动恢复手段（D040）。

提供免费的记录导出（CSV）和备份/恢复（D040）。恢复先在副本上完整校验（格式版本、数据库版本、与正常读取相同的一致性检查），用户确认一次后原子替换；任何一步失败，本机原数据不变。恢复是整体替换，所以不会复制出两份；确认后按恢复的安排重排提醒。首版备份文件不加密，界面明确说明；带口令的认证加密备份是下一步，届时用经过审查的标准加密与口令派生实现，不自己发明算法。购买恢复不恢复本地健康数据。

## 8. 提醒引擎：默认无限期，不依赖后台侥幸续排

### 8.1 默认实现

每天/每周固定钟点：使用可重复的 `UNCalendarNotificationTrigger`，编译到少量按真实钟点与周规则分组的 series。`end_at = nil` 不生成无限数据库行。[S05]

保存路径：写入本地计划及待调度状态 → 提交 → 向系统注册/替换请求 → 记录成功或失败。失败时显示“计划已保存，提醒尚未设置成功”，不可只显示绿色完成。启动时可对账，但长期提醒不能靠下一次启动才存在。

隔天一次（D036）：系统的可重复日历触发无法表达“每隔一天”。这类安排改用带日期的一次性请求：每个钟点预排接下来 7 个应服日，一个应服日一条，与每天/每周的 series 一起计入 48 条请求预算，预算先分给每天/每周的重复请求，再分给带日期的请求；同一钟点的 7 条要么全部排入，要么都不排并显示“未设置”，不只排前几天。引擎每次运行（保存后、启动、回到前台）补齐到 7 个应服日，做法与后续提示相同。局限必须明说：用户一直不打开 App，这类提醒在最后一个已排应服日（上次运行时排定的第 7 个应服日）之后停止；每天/每周的重复提醒不受影响。项目详情在提醒状态下写明这一点，不显示无条件的“已开启”。同一钟点既有每天的项目又有隔天的项目时，应服日发两条通知：重复请求只含每天的项目，带日期的请求只含当天应服的隔天项目；任何通知都不在非应服日写出某个项目的名称。

> Amendment (2026-10-13, D065): A plan of every few days and a plan with days on and days off use the dated requests of D036, with no other mechanism. A day of the pause is not a due day: it gets no request, and no notification names the item. The 7 due days of a plan with a pause can be 7 days in a row, so its reminders can stop after one week with no open of Maru. The item detail states the limit with the same text.

> Amendment (2026-10-12, D047): One fire time gives one notification that names the open items. A dose that is recorded (taken or skipped) before its time does not remind: the repeating request of that weekday is replaced by weekly requests for the other weekdays, and by dated requests for the next two dates of that weekday. A daily or weekly item and an every-other-day item at one time share one dated request on a due day. Each run (launch, return to the front, save, record, undo) compiles again, and after the time passes the plan has the repeating request again. Without room in the budget of 48, the plain requests stay. The limits are in `docs/decisions.md` D047.

没有常驻 timer、假后台音频、依赖每晚后台刷新、APNs 续命或逐日服务端推送。计划本身可以持续存在，实际通知显示仍受系统权限、专注模式、摘要、关机等影响；不宣传必达、永不漏服或自动绕过静音。

### 8.2 重复通知的内容与局限

> Amendment (2026-10-12, D047): The limit below changed. A dose that is recorded before its time no longer gets the reminder of that time. The text of a request still never says that a dose is not taken. D047 gives the rule, the room, and the limits. Spec 8.1 has the new rule.

重复本地通知的内容不是每次执行前实时查询数据库。首版基线是中性“查看你设定的 08:00 安排”，默认锁屏不显示药名。

> Amendment (2026-10-11, D029): Reminders now show the item names by default: the title "Time to take" and the names in the body. The text has no clock time and no amount. Settings has "Show Names in Reminders" to return to text that names no item. The engine replaces a request when its text changes. The other rules of this section stay.

用户可能提前完成记录，但相应的未来重复提示仍出现。不能把此提示写成“你还没有吃”。清除已经交付的提示是可做的；取消一个重复 request 会影响整个 series，不等于只取消今天。不要在记录后删掉 series，再假设明天后台会重建。[S05]

初版宁可使用明确的固定查看提示，也不采用“短滚动队列 + 未来某次后台续排”的隐性失效方案。按日历日计数的安排（隔天一次、每隔几天、周期）是唯一例外（§8.1，D036，D065）：它的队列长度和停止条件在项目详情中明示，补排只发生在 App 运行时，不依赖后台。若要宣称“提前记录后保证不再提醒本次，同时无限期不停后续提醒”，必须先提供独立真机原型和证据；未验证时不作此承诺。

前台收到提示时可根据当前数据库抑制重复展示；后台不拥有同样的任意执行保证。记录后删掉当前已交付通知，不能假装同时完成了对未来重复内容的动态修改。

### 8.3 精确定位与旧通知

一次性通知可携带 occurrenceID。重复通知的 userInfo 是 seriesID + scheduleRevision，不能预写一个固定“今天的 occurrenceID”永远复用。

隔天一次、每隔几天和周期的带日期请求（D036，D065）在 userInfo 中另带计划日期。点击时直接用这个日期，不从交付时间推断；其余规则不变：不是今天、延迟交付、时区不确定、旧版本或夏令时歧义时进入确认。只对应一个项目的带日期请求同样提供“已服”动作，用 scheduleRevision 校验身份。

点击时综合 `UNNotification.date`、触发规则、时区与历史版本解析候选事项；不能用用户点击时的 `Date()` 直接记为今天。[S12] 系统交付元数据不必然等于原定时间；跨日延迟、时区、旧版本或无法唯一解析时必须进入日期/事项确认，而不是猜。

首版通知主路径为“打开并记录”。单项“已服”快捷动作只有在唯一事项可解析、认证和持久化均可用时开放；否则打开确认界面。组通知不提供盲记全组/全天。

数据库在锁屏受保护不可访问时，必须要求解锁；不能为了锁屏一键快感降低健康数据保护，或在未写入时声称成功。

> Amendment (2026-10-11, D034): A reminder or a follow-up for exactly one item has a "Taken" action. The system asks for an unlock first, then Maru records in the background. The action records only when the rules of this section give exactly one open dose of today. In every other case it records nothing, a notification says "Not recorded", and Maru shows the confirmation when the user opens it. A reminder for two or more items has no action.

> Amendment (2026-10-11, D039): A follow-up of a dose of the day before has the "Taken" action until 01:00, and the action records that dose. The follow-up carries its plan date and its item, so Maru does not guess the date. After 01:00 the action records nothing, and a tap shows the confirmation. Today still shows only the doses of today (D019).

### 8.4 有结束日期的次要能力

系统重复触发不带本产品所需的通用 `until` 停止机制。初次自用版本可先不开放结束日期。公开版本仅在实现和容量验证完成后开启。

首版允许的保守实现：对容量内的有限安排，预先编译全部不晚于结束日期的一次性通知。只有全部所需请求可安排时才承诺该有限提醒；必须计算整个 App 的请求预算，留出用户主动稍后提醒等余量。不得宣传无限提醒数量；实际容量以所支持系统真机验证为准。

超出已验证能力时：明确说明这个有限计划暂不能自动提醒，允许保存为清单/仅记录；不偷偷改成无限期，不只预排前几天然后显示完整成功。结束日期 UI 放在高级设置，不能向多数无限期用户解释这些内部限制。

以后可以研发更完善的有限日历编译器，但“架构留接口”不代表能力已经上线。

### 8.5 时间、暂停与版本

- 每日固定钟点与每隔 X 小时不同，后者不属于 V1 自动调度。
- 隔天一次（D036）：安排保存一个起始日期。起始日当天，以及其后与起始日相隔偶数个日历日的日期，是应服日。日期按该安排的日历和时区计算，只数日历日，不数小时；夏令时切换和时区变化不改变节奏，漏服或跳过也不改变节奏。修改钟点或用量产生新版本并保留起始日期；修改节奏或起始日产生的新版本自今天起生效，过去的记录不变。非应服日不生成事项，今天不显示该项目，历史也不显示“没有记录”。
- 每隔几天与周期（D065）：与隔天一次是同一条规则。安排保存起始日期、服用天数和停用天数：自起始日起连续“服用天数”天是应服日，随后“停用天数”天不是，如此循环。隔天一次是 1 和 1，每 N 天一次是 1 和 N−1，服 21 天停 7 天是 21 和 7。起始日可以早于今天。其余与隔天一次相同：只数日历日；夏令时切换、时区变化、漏服或跳过都不改变节奏；修改钟点或用量保留起始日期和天数；修改天数或起始日产生的新版本自今天起生效，过去的记录不变；停用日不生成事项，今天和历史都不显示该项目。
- 补剂可选择跟随当地生活时间；药品默认保留用户确认的原时区日历语义，切时区显示对应当地时间，不静默决定新的服法。
- 时区策略以命名时区保存，不只保存 UTC offset；夏令时测试不存在/重复时刻；有歧义就明确显示待核对，不编造剂量。
- 暂停/关闭提醒取消相应 requests，但不等同建议停药；归档同时移出活动安排。
- 系统调度和 DB 无法原子提交：用待对账状态及受控重试，重试幂等；UI 显示实际结果。
- 不因无记录自动关掉、加频、重新设定或推断形成习惯。

## 9. 性能预算：测出来的快，而不是用动画遮住等待

以下是对 Release 真机版本的工程目标，不是保证任何设备、任何热状态都达到。

基准覆盖：iPhone 12 级别的较旧设备、一台当前常用设备；60/120Hz 分开；空数据、20 个项目 + 一年历史、较大数据集；离线与联网。系统最低版本与当前版本都测。冷启动、进程启动、后台恢复分别报告，记录样本量、系统、温度和构建号。样本不足不把 P95 当稳定结论。

| 指标 | 目标预算 | 测量定义 |
|---|---|---|
| 人为等待 | 0 ms | 无 logo 最短播放、sleep、强制倒计时 |
| 普通进程启动的有用首帧 | P50 ≤400 ms；P95 ≤700 ms | 启动测量起点到今天实际内容，而非空壳 |
| 重启后冷启动 | P95 争取 ≤900 ms，单独报告 | 不把后台恢复冒充冷启动 |
| 后台回到今天可操作 | P95 ≤150 ms | 系统恢复到当前有效快照与交互可用 |
| 按压/触摸响应 | 一帧内开始，目标 <50 ms | 不是成功写入状态 |
| 本地记录提交并展示确认 | P95 ≤120 ms；P99 ≤250 ms | 从实际操作到事务提交及状态可见 |
| 已有项目进入详情 | P95 ≤150 ms | 不等照片/网络 |
| 列表滚动 | 无可复现明显 hitch | 60Hz 约 16.7ms、120Hz 约 8.3ms 的帧预算分别看 |
| OCR/抠图 | 异步、可取消、可手动继续 | 不用首页延迟为识别速度背书，不承诺所有设备同样耗时 |

Apple 的启动优化资料明确区分冷启动、暖启动与恢复，也用首帧约 400ms 作为优化目标；它是工程参考，不是本 App 已达到的性能。[S06]

### 启动关键路径

只做：打开本地库（必要安全迁移）→ 读取今天所需计划/状态 → 建立轻量投影 → 展示。

不得等待：网络、PostHog 初始化、远程 feature flags、StoreKit 商品列表、照片抠图、全库历史统计、健康规则下载、AI 响应。

系统 Launch Screen 与首页背景自然衔接；不加第二层品牌 Splash。Apple 的指南不把启动画面当广告/品牌展示机会。[S13]

### 工程细节

- SQLite 查询有索引；不在 MainActor 扫描、解码原图、压缩备份或跑完整规则库。
- 列表使用稳定 ID，局部更新；不要每记录一项就重建整个 TabView。
- 图片首屏用小缩略图缓存，不展示网络骨架屏。
- `TodaySnapshot` 必须带日期、数据 revision 和生成时间；过期内容不能短暂冒充今天的可信记录。
- 购买/分析/反馈网络操作使用明确超时、有限重试；无连锁阻塞。
- 开发阶段用 signpost 定位启动、查库、写库与布局；再使用 XCTest 性能测试和生产汇总诊断。[S07][S08]
- 记录的“成功”只能由持久化确认驱动，不用乐观打勾后异步丢数据。

## 10. 隐私与安全

健康资料默认只在设备。数据库、WAL/SHM、照片、导出临时文件和小组件快照都列入保护检查。例外（D071）：安装 Apple Watch App 后，今日清单（名称、用量、时间、状态）经 WatchConnectivity 发到用户自己已配对的手表，不经过任何服务器；手表不建数据库；iPhone 重启后尚未解锁时手表无法记录，并明确说明。App 进入后台时应用切换器快照不暴露清单。

数据库目录（数据库、WAL/SHM、恢复标记文件）使用“首次解锁前完全保护”（D066，取代首版的严格保护）：静态加密；重启后首次解锁前无法读写，之后锁屏时可读写，使 Apple Watch 记录和手表上通知的“已服”在 iPhone 锁屏时可用。照片、导出临时文件和草稿仍用完全保护。无法读写时要求解锁，不假装快捷动作已完成。Widget 默认只展示非敏感入口，用户主动允许后才显示更多内容；快照可能旧，显示相应状态且不作为实时服用判据。

原规格的“不使用个人健康资料 iCloud 同步”继续保留。Apple 指南对个人健康信息、分析共享与隐私政策有专门要求。[S14] 也需实际核查系统备份行为，不能因没用 CloudKit 就宣称所有敏感文件都不会进入备份。导出由用户主动选择。

不访问通讯录、位置、广告 ID。禁止 session replay、热图式 UI 文本采集、会话录屏、自动抓取搜索词和全屏错误截图。不要把无账号或随机 ID 写成绝对匿名。

隐私政策必须与真实 SDK 配置、反馈端点和保留时间一致。商店的隐私标签、Privacy Manifest、Required Reason API 等按实际构建核查；本文不是已完成全球法律审查的证明。

## 11. Telemetry / PostHog 设计

### 11.1 我们要回答的问题

- 用户能否完成首项添加？卡在扫描、资料核对还是提醒设置？
- 用户通过 App、通知入口或小组件回来？
- 是否有实际记录功能使用、历史查看或纠正？
- 哪个版本启动、保存或提醒注册出错？
- 用户主动反馈的是哪种体验问题？

事件能说明行为路径，不能直接读懂意图。比如进历史可能是查记录，也可能是改记录；离开编辑页可能是中断，不自动标成放弃。

### 11.2 三层分离

1. **本地健康事实**：精确药名、用量、服用时间、历史。只供用户功能，不上传分析。
2. **本地工程诊断**：耗时、错误分类、计数；默认本地，上传须按策略脱敏与同意。
3. **可选产品分析**：显式允许的事件/日汇总。无药名、标签、实际用量、精确每剂时间或条目 ID。

### 11.3 同意及生命周期

> D051 changes the default: analytics is on by default outside the EU, the EEA, the UK, and Switzerland, with a switch in Settings. D078 removes the one-time notice there: analytics starts with no notice and no question. In the EU, the EEA, the UK, and Switzerland the user opts in first, with a one-time question after the first save and the same switch. The rules below apply to the opt-in regions.

- 分析默认关闭。首项计划保存后可在合适位置一次性提供可忽略的“帮助改进 App”说明，设置中始终可改；不在启动前阻断使用。
- 同意前不初始化第三方 SDK、不建立第三方识别身份、不发配置请求；也不事后补传同意前的使用历史。
- 仅同意后生成独立安装标识。它是可关联的假名标识，不是匿名证明；不能关联邮件、药品 ItemID 或其他应用身份。
- 撤回后停止采集与发送、清除待发队列、解除 SDK 网络活动，支持删除既有分析数据；删除身份的端点必须只允许删除当前设备对应数据，不在客户端嵌管理密钥。
- 离线核心照常使用。分析队列大小/保留天数有硬上限，失败可丢弃分析，不可丢失健康记录。

### 11.4 PostHog 集成原则

选 PostHog 做漏斗、留存和版本比较，不默认启用它的所有功能。官方配置包含自动页面/控件采集和其他集成；部分默认项或 API 会变化，应锁定稳定版本并检查实际源代码与网络包。[S09][S10]

适配器需要显式关闭：自动 lifecycle、screen capture、UIKit/SwiftUI 元素捕获、replay、rage clicks、自动推送元数据/订阅捕获、自动异常正文、自动 surveys。关闭 swizzling 及不需要的集成，不调用含屏幕标题、通知 body 或 health userInfo 的便捷 capture 方法。

不是只设一次 `sessionReplay = false` 就视为隐私完成。不要依赖一个可能已变成 no-op 的远程配置开关来保证没有联网。若选中的 SDK 不能满足约束，维持 NullAnalyticsClient，或采用经审核的最小事件传输实现，不能降级隐私要求。

本项目不需要业务域持有 PostHog SDK。使用 `AnalyticsClient` 接口：本地/关闭实现和生产实现可替换。发送前严格字段白名单，未知字段丢弃或拒绝。事件适配时 SDK 附加属性同样必须检查。

### 11.5 最小事件契约

配套 `telemetry.schema.json` 定义应用侧允许的 envelope；它不是未经转换可直接发送给 PostHog 的 HTTP 格式。vendor adapter 只映射允许字段并显式审计自动附加元数据。

| 事件 | 允许的信息 | 禁止的信息 |
|---|---|---|
| setup_step | 步骤枚举、新建/编辑/替换枚举、是否有提醒时间、是否有用量/备注/照片、名称来源（手输/建议/扫描）、是否用过智能补全、是否首项、是否有改动、耗时桶 | 搜索词、OCR 文本、药名、剂量、计划类型、提醒时间个数、具体提醒钟点、具体星期 |
| daily_usage_summary | 同意后的相对日序号、是否用过记录/历史/通知入口/小组件入口/提醒动作/跳过/撤销/修改记录/按需/我的项目/项目详情/设置等布尔标志、打开次数桶、活动项目数桶、是否有小组件 | 每次“已服”时间序列、已服/跳过明细、一天几剂、稳定药品 ID |
| core_error | 保存/读取/调度/扫描等操作枚举、预定义错误码 | 原始 exception message、SQL 内容、文件路径或 userInfo |
| notification_permission | 新的通知权限枚举、之前的权限枚举（只在变化时发送） | 通知内容、提醒钟点 |
| setting_changed | “再次提醒”次数与间隔枚举、是否在提醒中显示名称、App 颜色枚举 | 其他设置值；分析开关关闭后不再发送 |
| data_action | 导出/备份/恢复枚举、结果枚举 | 文件名、文件内容、路径 |
| feedback_entry | 入口枚举、是否发送成功 | 用户反馈正文、附件和邮箱（单独支持端点处理） |
| purchase_result | 商品枚举、结果枚举 | Apple 账号、原始交易收据、金融身份 |

记录动作精确时间只在本地健康库。每日使用摘要在下一次可运行时合并发送；不为上传摘要唤醒用户，不依赖后台保证送达。没有摘要不代表没有服用。分析同意日期不同于真实首次安装日期，报表不得混用。

产品分析的网络请求仍会有连接元数据、接收时间等；不声称“完全不能推断”。不做 IP 地理画像，不把原始 IP 持久化到分析属性；服务商处理位置、日志、保留和删除需完成实际核查。

### 11.6 第一个看板，只做四组

- 设置：只统计同意之后实际发生的添加流程、耗时桶及失败分类。默认在首项保存后询问分析同意，因此更早的首次设置流失不可观察；不能补传或把后续添加称作真实首项漏斗。需要首项可用性证据时，使用预先自愿同意的公测或本地观察，与商店用户分开报告。
- 使用：按同意/有效观察的 cohort 报告日汇总中的记录、历史、通知入口等使用；不只看打开次数，不宣称真实服药依从率。
- 质量：保存/调度错误、启动和交互性能，按版本/系统分组。
- 商业：商店真实净收入与验证购买，退款、成本；支持者点击不当付款。

公测样本、同意采集样本和所有商店安装量分开报告。D1/D7/D30 必须写清 cohort 起点、完整窗口、是否只有提醒而无动作等限制。没有足够样本先看人数，不发虚假的显著性结论。原补货/续瓶任务指标全部删除。

## 12. 反馈服务

一个 `POST /feedback` 端点即可；本文不指定尚未创建的供应商、项目 ID 或 URL。

请求包含一次随机 requestID、正文、可选邮箱、可选有限附件、可选已预览的 appVersion/osMajor/固定错误分类。服务端限流、大小限制、附件类型白名单、病毒/恶意内容处理，发送幂等。

不要把正文原样写入应用日志或 analytics，不自动把用户药品记录附上。关闭 analytics 的人仍可主动反馈。支持收件箱与分析系统隔离权限。收到的用户自愿健康信息同样按敏感数据处理，并设置保留/删除机制。

不先问满意度再决定是否请求商店评分；首版可以完全没有评分弹窗。

## 13. 内容、语言与品牌

### 13.1 内容

核心提醒不依赖百科。有限资料放添加核对与详情，明确来源/适用范围/审校日期。没有审核覆盖就显示暂无建议，而不是让模型按药名实时决定。技术内容更新不能静默改变用户计划。

### 13.2 语言

本地开发先把英文、简中跑通，但从首个组件使用 String Catalog 和 locale-aware 日期/数字。首发语言目标沿用 en、zh-Hans、zh-Hant、ja、de、fr、es；每种语言通过实际界面/通知/错误/支付/健康语句核查后才启用。界面语言、扫描支持和医学资料语言分别声明。

“适合全年龄理解”不等于提供儿童医疗方案。基本导航应适合不同成年人和辅助使用条件；医疗边界不因年龄覆盖而扩大。

### 13.3 命名

Stack 保留为开发代号/概念。公开商店已有 Supplement Tracker: Stack、StackDay 和 StackLog 等近直接竞品；不能称纯 Stack 是已验证可用名称。[S15][S16][S17]

候选工作名 **Stakdo**：六个字母，保留 stack 的声音并强调执行；只是创意候选。此次有限公开搜索未找到明显同名结果，不代表商标、域名、商店名或社交账号可用。正式商标及主要地区语言含义核验尚未进行。不能把“名字短”写成有证据保证转化或留存。

不因命名阻塞领域模型。bundleID、品牌显示字符串和本地化副标题分离；正式发布前再冻结不可轻易修改的外部标识。

视觉方向：原创的小型叠放形状与明确确认感，不照搬 Apple Health 心形标识。不在启动时展示品牌动画；品牌质量由连续使用的细节体现。[S13][S14]

## 14. 自用版、公测版、商店版

### A. 自用真机纵向版本

先交付真实持久化的：手动添加 → 无结束日期的确认提醒 → 今天 → 记录 → 回看 → 撤销/更正 → 改时间/关闭。

包含测试数据工具：一天两时点、过期通知、跨日、关闭权限、写库失败、未记录 7 天、版本更新。测试必须用虚构用量/项目，不要求用户改变真实服用来验证。

验收真机离线、多日不打开、旧通知定位和写入完整性。自用版不能在这些尚未验证时充当唯一关键用药保障。

### B. 可发 TestFlight 的完整 V1

补齐扫描核对、可选照片及非阻塞抠图、基础小组件、语言、辅助功能、加密导出恢复、最小分析同意/传输与反馈。正式健康资料只有审校完成才开放。

先自用、再公开收集反馈；没有“必须先访谈 30 人才能开发”的前置要求。

### C. 公开 App Store 版本

审核说明、隐私政策、权限文案、真实健康数据处理说明、支持入口、实际语言范围、数据删除/恢复测试、StoreKit 购买/恢复（若销售）、原创素材和已检查的品牌。

商店截图、落地页和推广文案可下一阶段讨论；但不能把隐私与数据架构也等到宣传时才补。Apple 对医疗信息、隐私和内容权利有明确要求；质量差或 AI 编写本身不能简单等同一个统一的自动拒绝规则。[S14]

### D. 上线后迭代

优先安全/记录/提醒错误，其次添加摩擦、速度、反馈中反复出现的实际需求，再做外观。用自愿反馈解释分析中的行为，不根据一次退出推断心理。

不为保留用户增加库存、任务债、资讯或无需求的 AI。先看软件是否被真实使用，再决定付费便利能力。没有正向单位经济证据之前，不把广告预算当作自然启动步骤。

## 15. 验收清单（待执行，不是已通过）

| ID | 场景 | 通过条件 |
|---|---|---|
| T01 | 首次离线打开 | 无账户/网络等待，能手动添加 |
| T02 | 未设置钟点 | 可保存仅清单，不注册假提醒 |
| T03 | 保存无限期提醒 | 预览清楚，end_at 为空，系统调度状态可见 |
| T04 | 同款继续买一瓶 | 无需任何操作，历史/提醒不变 |
| T05 | 扫描已有同款 | 可查看或核对，不自动新建重复提醒 |
| T06 | 换规格 | 核对新信息，不自动沿用量，过去快照不变 |
| T07 | 关闭提醒 | 取消未来提示，记录/历史保留 |
| T08 | 归档 | 活动列表移出，未来提示取消，非停药建议 |
| T09 | 无库存体验 | 无余量字段/补货事件/补充按钮或隐藏库存请求 |
| T10 | 有限结束安排能力关闭 | UI 不展示无法兑现的日期能力 |
| T11 | 有限安排可用 | 最后一条不越过结束时间，离线/不再启动也不越界 |
| T12 | 有限请求超预算 | 明确不支持，不静默截断或转无限 |
| T13 | 拒绝通知 | 继续记录，提醒状态诚实，不反复弹权限 |
| T14 | 后续关闭系统通知 | 回来能看到状态，没有虚假正常 |
| T15 | 跨日点击旧通知 | 定位旧候选或明确核对，不写今天的新一次 |
| T16 | 早晚同一项 | 上午与晚上独立 |
| T17 | 修改已记录时点 | 不生成当天第二个相同逻辑剂次 |
| T18 | 重复点/多入口 | 一份有效记录，操作幂等 |
| T19 | 保存失败 | 无成功文字/触感，状态可重试 |
| T20 | 撤销与更正 | DB、今天及历史一致，不只改 UI |
| T21 | 提前记录 | 不假称重复通知一定消失，通知不宣称未服 |
| T22 | 多日不启动/强制退出/离线 | 重复提醒不依赖后续后台续排；实际结果有测试记录。隔天一次、每隔几天和周期的提醒在已排的 7 个应服日之后停止，界面已说明（§8.1，T51，T52） |
| T23 | App 前台接收提醒 | 正确读取当前状态，避免误导重复展示 |
| T24 | 专注模式/摘要/延迟 | 不误报必达，不据延迟点击猜实际服用 |
| T25 | 时区与夏令时 | 明确策略，无重复或不明疗程转换 |
| T26 | 未记录 1/7/30 天 | 直接今天，不要求补齐，不自动复活归档 |
| T27 | 拍照拒绝/识别失败 | 手动路径可用，草稿不丢 |
| T28 | 每份/每粒、单位、小数 | 不猜数量；采用前核对 |
| T29 | 照片多主体或抠图失败 | 普通裁切回退，文字及保存不受影响 |
| T30 | 抠图中取消编辑 | 异步结果不写入错误项目 |
| T31 | 原图与 EXIF | 未保留原图清理，位置元数据去除 |
| T32 | 图片完全关闭 | 名称、量、状态及所有操作仍可用 |
| T33 | 大字/VoiceOver/Reduce Motion | 核心添加、记录、更正完整可用 |
| T34 | 同名项目与长名称 | 可区分，关键数据不截断 |
| T35 | 启动离线/SDK 超时 | 首页不等网络/遥测/StoreKit |
| T36 | 启动和记录预算 | Release 真机数据附版本、设备、样本量与分位数 |
| T37 | 数据库迁移失败 | 不清库重建，不假称空账户 |
| T38 | 备份损坏/版本过新/密码错误 | 原数据不破坏（D040；首版备份无密码） |
| T39 | 备份恢复 | 校验并确认后整体替换，再按恢复的安排重排提醒；不合并，不复制出两份（D040） |
| T40 | 锁屏/应用切换器/小组件 | Reminders show item names by default, and a setting turns them off (§8.2, D029)。应用切换器和小组件默认不泄露名称，受保护写入要求解锁 |
| T41 | 分析未同意 | 无 SDK 初始化或对外分析/配置网络请求 |
| T42 | 分析同意后抓包 | 只有白名单信息，无姓名、药名、量、精确服用时序或录屏 |
| T43 | 撤回同意 | 停止发送、清除队列，删除流程有效 |
| T44 | 分析网络故障 | 记录正常，队列有界、无频繁电量消耗 |
| T45 | 非法 telemetry 字段 | Schema/适配器拒绝，不静默发送 |
| T46 | 反馈离线/无邮件账户 | 草稿保留，在线表单可发，不假成功 |
| T47 | 反馈重试 | 幂等，正文不入 analytics/错误日志 |
| T48 | 购买失败/取消/退款 | 免费记录不受影响，健康资料不动 |
| T49 | 语言/日期/数字 | 实际支持范围准确，通知和错误同样本地化 |
| T50 | 宣传与实际构建 | 不声称库存、无限可靠、临床效果或没有实际实现的能力 |
| T51 | 隔天一次 | 起始日及其后每隔一个日历日应服；夏令时、时区变化、漏服或跳过不改变节奏；非应服日今天和历史都不出现该项目；通知不在非应服日写出该项目；详情写明提醒只排到接下来 7 个应服日 |
| T52 | 每隔几天与周期 | 天数和起始日由用户选定，App 不预选，未选定不能保存；自起始日起服 N 天、停 M 天循环（每 N 天一次是服 1 天、停 N−1 天）；夏令时、时区变化、漏服或跳过不改变节奏；停用日今天和历史都不出现该项目，通知不写出该项目；详情写明提醒只排到接下来 7 个应服日；数据库迁移后隔天一次的安排保持原节奏，旧备份可以恢复 |

## 16. 交付与验收证据

开发交付须包括：可编译 Xcode 项目、锁定依赖与许可证、设备/构建矩阵、领域与数据库测试、真机提醒记录、性能测试原始结果、隐私抓包结果、迁移与恢复测试、已审校内容清单、反馈端点说明与维护责任、发布说明。

本次产物仅为规格与分析事件契约及其格式测试；没有编译 iOS App、没有在 iPhone 上执行通知测试、没有配置 PostHog 账户、没有完成商标/域名核查，也没有发布或保证审核通过。

## 17. 本轮核查来源

以下是原始或官方资料，检索日期 2026-10-10。源 API、条款和商品页面会变化，正式实现按锁定版本和提审时要求复核。设计预算、状态机、品牌候选及商业路线是本方案建议，不是这些来源已证明的本产品结果。

- S01 Apple Support — Add and log medications with iPhone, iPad, and Apple Watch. https://support.apple.com/en-us/105064
- S02 Apple HIG — Accessibility. https://developer.apple.com/design/human-interface-guidelines/accessibility
- S03 Malhotra et al., 2022（在线 2021）— Validation of pharmaceutical pictograms among older adults with limited English proficiency. 250 名新加坡年长受试者、52 个药品图示；不等于本 App 图像方案试验。https://pubmed.ncbi.nlm.nih.gov/34412906/
- S04 Apple WWDC23 — Lift subjects from images in your app. https://developer.apple.com/videos/play/wwdc2023/10176/ ; Vision API: https://developer.apple.com/documentation/vision/vngenerateforegroundinstancemaskrequest
- S05 Apple — Scheduling and Handling Local Notifications（官方归档，当前系统仍需真机复核）. https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/SchedulingandHandlingLocalNotifications.html ; https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger
- S06 Apple WWDC19 — Optimizing App Launch. https://developer.apple.com/videos/play/wwdc2019/423/
- S07 Apple — XCTApplicationLaunchMetric. https://developer.apple.com/documentation/xctest/xctapplicationlaunchmetric
- S08 Apple — MetricKit. https://developer.apple.com/documentation/metrickit
- S09 PostHog — iOS usage/configuration and controlling data collection（本轮网页抓取部分失败，以可见官方检索摘要及源代码核查补充）. https://posthog.com/docs/libraries/ios/usage ; https://posthog.com/docs/libraries/ios/configuration ; https://posthog.com/docs/privacy/data-collection
- S10 PostHog 官方 iOS 源代码 — PostHogConfig.swift（main 是移动目标，不代替锁定版本检查）. https://raw.githubusercontent.com/PostHog/posthog-ios/main/PostHog/PostHogConfig.swift
- S11 GRDB 官方仓库. https://github.com/groue/GRDB.swift
- S12 Apple — UNNotification.date. https://developer.apple.com/documentation/usernotifications/unnotification/date
- S13 Apple HIG — Launching / Branding. https://developer.apple.com/design/human-interface-guidelines/launching ; https://developer.apple.com/design/human-interface-guidelines/branding
- S14 Apple — App Review Guidelines. https://developer.apple.com/app-store/review/guidelines/
- S15 App Store — Supplement Tracker: Stack（开发者自述功能，不等于本次实测或医学认证）. https://apps.apple.com/au/app/supplement-tracker-stack/id6780631034
- S16 App Store — StackDay: Supplement & Peptide. https://apps.apple.com/us/app/stackday-supplement-peptide/id6761502044
- S17 App Store — StackLog: Supplement Tracker. https://apps.apple.com/au/app/stacklog-supplement-tracker/id6754559530
- S18 App Store — Stackwise: Supplement Tracker；同类也宣传无账号、设备端、无 streak 压力，不能将这些宣称为本产品独有. https://apps.apple.com/il/app/stackwise-supplement-tracker/id6804325684
