# WageKit

**分毫不差的 MoonBit 薪酬个税计算引擎。**

[![CI](https://github.com/JQ-ai-nb/wagekit/actions/workflows/ci.yml/badge.svg)](https://github.com/JQ-ai-nb/wagekit/actions/workflows/ci.yml)

WageKit 把"发工资要算的税"做成可验证的纯计算库：输入任职期间的工资参数（整数分），输出累计预扣预缴的逐月税额、年终奖两种计税方式对比与法定工资条。所有金额都是精确整数运算——**钱永远不经过浮点**。

它不是 HR SaaS：不做员工管理、不发工资、不连银行；它是可被任何 MoonBit 程序、云函数或 wasm 宿主直接依赖的计算层。

| 30 秒判断 | |
| --- | --- |
| 解决什么 | 发工资要算的税：累计预扣跨月跳档、年终奖临界点、到手反推应发、政策换版重算——每一条都直接对上钱 |
| 谁用 | 招聘算 offer 税前 / 财务查每月预扣依据 / 薪酬系统评估换版成本 / 个人比较年终奖两种计税 |
| 凭什么信 | 44 项单元测试 + 25 项 Node 测试（CLI 19 + 批量 6） + 3,000 组 Python `Decimal` 独立实现逐字段对照；`moon test` 一条命令跑完，不用装 Python 也能验边界 |
| 生态位置 | 本包发布前全量检索（2026-10-29）：Mooncakes **3,390 个包**里薪酬/个税类 **0 个**；金额表示只有 `haol-05/moonmoney`，不做计税 |
| 怎么试 | **先开演示页**（`web/`，零依赖零网络）：五个场景一键切换，每个都有一句"该看什么" |

**先看这个**：打开 `web/index.html`（或在线演示），点「年终奖多发一元」——36,001 元比 36,000 元多缴 2,310.10 元税，到手少 2,309.10 元。再点「到手反推」和「起征点试算」，这两个是普通计算器做不到的方向。

| 能力 | 说明 |
| --- | --- |
| 金额 | 全程整数分、四舍五入到分，浮点从不接触钱 |
| 累计预扣 | 工资薪金累计预扣预缴，跨月状态机，多月跳档正确 |
| 年终奖 | 单独计税 + 并入综合所得对比择优；6 档临界点全档穷举——跨档点落在 ÷12 商的第 +1 分（即多发 0.12 元），到手少 2,309.89 元 |
| 专项附加 | 子女教育/婴幼儿/房贷/租房互斥校验/赡养/继续教育/大病医疗，逐项上限 |
| 社保公积金 | 基数上下限 clamp、逐险种舍入；内置五城示例参数（标注 EXAMPLE） |
| 其他所得 | 收入类型枚举：劳务报酬（20/30/40%）、稿酬（20%）、特许权使用费（20%），共享 800/80% 费用减除 |
| 年度汇算 | 应退/应补分列输出；劳务报酬并入口径差产生真实退税场景（JSON `other_income` / `other_prepaid` → `settlement`） |
| 税后反推 | 给定到手金额求税前应发（`gross_up`）：分段函数求逆，分位台阶上取最小可行解，不可精确命中时报告超出几分 |
| 税额分解 | 每月预扣追溯到底：第几档、什么税率、速算扣除数多少、完整算式（`explain`） |
| 规则集注入 | 两张税率表 + 起征点 + 版本号打包为 `RuleSet`，可换一整套规则重算，不改引擎 |
| 政策影响面 | 同一份工资在旧/新两版规则下逐月对比，输出每人每月增减（`policy_impact`；JSON `preview` 试算起征点） |
| 工资条 | Markdown 输出：应发、各项扣除、实发、累计口径 |
| 确定性 | 同一输入产生逐字节相同的 JSON；规则表数据驱动、按年度版本化 |

## 60 秒评审路径

1. **看著名陷阱**：`moon test` 里的 `every cliff jumps at the twelfth fen past its edge` 用例——年终奖 36,000 元缴税 1,080 元，36,001 元缴税 3,390.10 元，**多发一元，到手少 2,309.10 元**（精确跳档点在 36,000.12 元，测试按分穷举 6 档边界）；
2. **跑独立 oracle**：`python tests/oracle.py 3000`——Python `Decimal` 按官方口径独立实现同一套规则，3,000 组随机工资逐字段对比；
3. **生成工资条**：`node bin/wagekit.mjs examples/months.json --md`，输出样张见 `examples/expected-output.md`；
4. 想看与现有项目的关系：本 README「与现有项目的关系」。

## 四种人用它做什么

同一个计算层，四个真实场景，不是四个玩具 demo：

| 谁 | 问题 | 调用 |
| --- | --- | --- |
| 招聘 / HR | "offer 写 25,000 到手，税前该开多少？"；"这 1,000 人本月的工资条" | `gross_up` / `bin/batch.mjs` |
| 财务 | "这个月每个人的预扣为什么是这个数？" | `explain_withholding` / JSON 的 `explain` |
| 薪酬系统 | "政策换版，全公司要多掏多少钱？" | `policy_impact` |
| 个人 | "年终奖 36,000 还是 36,001 划算？" | `bonus_compare` |

## 三个完整用例

### 1. 累计预扣的跨月正确性

累计预扣预缴是**期间状态机**：3 月累计应纳税所得额跳档时，当月税额跳升，但全年合计与年度汇算一致。单月函数实现必然算错——这是引擎与"查表算术"的分界线。

### 2. 年终奖临界点

`36,000 → 36,001 元`：单独计税税额 `1,080 → 3,390.10 元`。引擎同时计算并入综合所得的新增税额并择优；6 档跳档点各取「边界 / +11 分 / +12 分」三点穷举，跨档必须在第 12 分发生。

### 3. 劳务报酬并入伍算的退税

劳务 1 万元按 20% 预扣 1,600 元；汇算并入综合所得后按年度税率重算——应退 1,360 元。这是"预扣率 ≠ 年度税率"产生的真实退税。

```sh
node bin/wagekit.mjs examples/settlement.json
# {"settlement":{"tax_due":69000,"prepaid":205000,"refund":136000,"payable":0,...}}
```

`other_income` 要传**已按法定比例折算后**的金额（劳务报酬 80%），`other_prepaid` 是这笔钱已经预扣的税。

**减除费用按几个月算，是一个参数，不是引擎替你猜的：**

| `deduction_months` | 含义 | 本例结果 |
| --- | --- | --- |
| 省略 | 跟着数据走（给几个月扣几个月），与产生已预扣额的预扣口径一致 | 应缴 690 → **退 1,360** |
| `12` | 居民个人法定年度减除 60,000 元，即使只给了部分月份 | 应缴 0 → **退 2,050** |

两种情况在完整 12 个月输入下结果相同，所以正常的年度结算不会碰到这个分歧。分期离职、只有部分月份收入时，这个选择值真金白银，所以它是参数。

### 4. 工资条

`render_payslip` 输出 Markdown：应发、三险一金、专项附加、本月预扣、实发、累计口径——可直接进报告与聊天。

### 5. 反推：到手 20,000 该开多少税前

```sh
cat > /tmp/offer.json <<'JSON'
{"year":2026,"months":[{"gross":0,"social":0,"special":300000,"other":0}],"target_net":2000000}
JSON
node bin/wagekit.mjs /tmp/offer.json
```

输出 `"gross_up":{"gross":2037113,"net":2000000,"overshoot":0,"exact":true}`——税前 20,371.13 元分毫不差地落到 20,000 元。
不是解方程：税是分段线性且四舍五入到分，净额曲线有台阶，某些到手额**永远取不到**，所以引擎返回最小可行税前并如实报告超出几分。

### 6. 税额分解：为什么是这个数

同一份输入加 `"explain":true`，每个月都会带出档位、税率、速算扣除数与算式：

```json
{"month":3,"taxable_cum":6600000,"bracket":2,"rate":10,"quick":252000,
 "tax_cum":408000,"withheld":220000,"formula":"66000.00 × 10% − 2520.00 = 4080.00"}
```

### 7. 批量：一张表出全员工资条

```sh
node bin/batch.mjs examples/employees.csv --out payslips
# 已生成 3 份工资条 → /path/to/payslips
# 月度预扣个税合计 2836.00 元｜月实发合计 89864.00 元
# 年终奖按单独计税合计 12870.00 元（是否更省见每份工资条的对比）
```

CSV 列：`name,gross,social,special,other,bonus`，金额单位是**元**（可带两位小数，超过两位直接报错，不静默截断）。每人生成一份 Markdown 工资条，终端打印合计；`--json` 输出机器可读汇总。

实测 **1,000 人 0.44 秒**（含生成 1,000 个文件落盘），单机、无并发。

## 怎么嵌入（一个只用 pub 接口的消费端）

`examples/embed/` 是一个独立包，**只 import `pub` 项、不碰内部实现**，并且由 CI 编译并运行。它能过，说明第三方拿到包就能用；哪天它编译不过，就是真的破坏了别人的构建。

```moonbit
let inputs : Array[@wagekit.MonthInput] = [
  { gross: 3_000_000L, social: 300_000L, special: 100_000L, other: 0L },
]
let schedule = @wagekit.cumulative_withholding(inputs)          // 逐月预扣
let why = @wagekit.explain_withholding(rules, inputs)           // 为什么是这个数
let offer = @wagekit.gross_up(2_000_000L, 300_000L, 0L, 0L)     // 到手反推税前
let impact = @wagekit.policy_impact(rules, candidate, inputs)    // 换版影响面
```

```sh
moon run examples/embed
# 本月预扣 630.00 元
# 档位 1：21000.00 × 3% − 0.00 = 630.00
# 到手 20000.00 元需要税前 23463.92 元（精确）
# 起征点 6000：全年少扣 30.00 元
```

依赖方式：发布后 `moon add JQ-ai-nb/wagekit`；在同一 module 内则 `import { "JQ-ai-nb/wagekit/src" @wagekit }`。

## 验证

```sh
moon check --target all --deny-warn   # 四目标零警告
moon run examples/embed               # 嵌入示例（只用 pub 接口）
moon test --deny-warn                 # 单元测试：临界点穷举、状态机不变量、舍入口径、反推往返
node scripts/build.mjs
node --test tests/cli.test.mjs tests/batch.test.mjs # 21 pass
node bin/wagekit.mjs examples/months.json          # JSON 报告
node bin/wagekit.mjs examples/months.json --md     # 全年工资条（Markdown）
node bin/wagekit.mjs examples/explain-grossup.json # 税额分解 + 反推
node bin/wagekit.mjs examples/settlement.json      # 年度汇算：应退 1,360 元
node bin/wagekit.mjs examples/policy-preview.json  # 起征点改 6,000 的影响面
python tests/oracle.py 3000           # 独立 Decimal oracle，逐字段对比
```

oracle 的随机流固定覆盖**每一个税率跳档点**（年终奖按月度表边界 ×12，取 `edge×12`、`+11 分`、`+12 分` 三点；年度表边界取单月探针 `±1 分`），边界正确性不靠抽样。`moon test` 里另有同口径的 6 档穷举，评审不装 Python 也能复核。

CI 在 Linux / macOS / Windows 上以 `--target all`（wasm / wasm-gc / js / native）执行以上全部检查。

44 项单元测试 + 25 项 Node 测试（CLI 19 + 批量 6）；每份报告都带 `rules` 字段（当前 `2026.1`），归档结果可追溯到确切的规则集。

## 批量性能（可复现）

```sh
node scripts/build.mjs
node bench/bench.mjs 1000 5
```

1,000 名员工 × 12 个月，每人一份独立 JSON 文档，5 轮取中位：**18.6 ms**（每人 0.019 ms，每月 1.5 µs），Node 22 / Windows。数据在内存生成，不含磁盘与网络。

## 为什么不是 Excel 或在线计算器

| 维度 | Excel / 在线计算器 | WageKit |
| --- | --- | --- |
| 口径 | 黑盒公式，改没改不知道 | 每张税率表、每个常量都在 `docs/RULES.md` 里标了位置与来源；`explain` 把每月预扣还原成算式 |
| 方向 | 只能正向算：税前 → 税后 | 双向：`gross_up` 由到手反推应发，offer 谈薪直接用 |
| 年度更新 | 等厂商/作者改模板 | 规则是数据，换一个 `RuleSet` 即重算；`policy_impact` 直接给出换版前后的逐月增减 |
| 可嵌入 | 不能 | MoonBit 库 / JSON wire / Node CLI / wasm 宿主，四种调用 |
| 可验证 | 靠自己复核 | Python `Decimal` 独立实现做 oracle，3,000 组逐字段对比 |
| 批量与参数化 | 手工改单元格 | 五城社保参数、任意月数、任意所得组合，一次调用 |

一句话：**计算器给你一个数，WageKit 给你一个可审计、可嵌入、可被另一个实现验证的口径。**

## 与现有项目的关系（主动披露）

| 项目 | 定位 | 与 WageKit 的边界 |
| --- | --- | --- |
| Mooncakes 薪酬个税类 | **本包发布前不存在**（2026-10-29 全量检索 3,390 个包，按 payroll/salary/payslip/tax/wage/个税/工资 检索命中 0 个） | 本包即该类第一个 |
| haol-05/moonmoney | 金额格式化 | 只管"钱的表示"，不管"税怎么算"，无代码复用 |
| lwmvr/moonbit-fixedincome | 固定收益金融工具 | 与工资个税无关 |
| structuraBlock/MoonStats | 统计工具 | 无关 |
| 本人前作 JoinWitness / Relcore | 数据校验 / 关系执行 | 无代码复用、不同赛道，旧项目保留 |

原创实现，MIT；仅依赖 `moonbitlang/core`（Apache-2.0）；税率与速算扣除数按官方口径表驱动、按年度版本化，参数过期是数据问题不是引擎问题。

## AI 辅助说明

本项目在开发过程中使用 AI 辅助：部分测试用例、文档草稿与重构建议由 AI 参与。

- **不由 AI 决定的部分**：税法口径（税率表、速算扣除数、六项专项附加标准）、每个用例的验收数值、以及最终提交的代码，由维护者逐项核对。
- **不必相信任何一方的说法**：所有结论都能用仓库内的测试与独立 oracle 复现（见「验证」一节），包括"哪个数字是对的"这件事本身。

## 边界（明确不做）

- 不做社保实缴对接、专项附加扣除的申报流程、汇算清缴申报；
- 各地社保基数上下限首期仅内置五城示例参数（标注 EXAMPLE），按城市扩展是数据工作；
- 不提供税务建议；计算结果以主管税务机关口径为准；
- 计算口径（舍入、临界点、并入伍算）固定在 docs/SEMANTICS.md，评审可逐条核对。
