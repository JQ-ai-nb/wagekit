# WageKit

MoonBit 薪酬计算与差异复核引擎。版本 0.2.1，MIT。

[CI](https://github.com/JQ-ai-nb/wagekit/actions/workflows/ci.yml) · [Mooncakes](https://mooncakes.io/docs/JQ-ai-nb/wagekit) · [演示](https://jq-ai-nb.github.io/wagekit/web/)

为薪酬软件接入、工资预扣复核和计算逻辑回归测试提供同一份 MoonBit 内核。
输入工资、扣除和实际预扣记录，逐期输出应扣、实扣、差额以及累计计算依据。
这里的复核是给定范围内的软件计算比对，不等于税务机关认定。

## 先跑一个有用的例子

MoonBit 0.10.17 / moon 0.1.20261021，Node 22+；Python 3.12+ 用于对照测试。

```sh
node scripts/build.mjs
node bin/audit.mjs examples/audit.csv
# E001 第3期：应扣 150.00，实扣 300.00，差额 150.00 元
# 返回 1，便于接入 CI 或工资系统变更前的检查
node bin/audit.mjs examples/audit-clean.csv
# 复核一致，返回 0
node scripts/serve.mjs
# 打开 http://127.0.0.1:8899；页面中的数据不上传
```

样例为合成数据。两名员工共四期记录，其中一人收入下降后回升；累计已扣税额
必须保留，不能把下降后的应纳税额当作已经缴纳的税款。这个场景同时是回归测试。

## 功能和实际用途

| 能力 | 输入与输出 | 使用场景 |
| --- | --- | --- |
| 差异复核 | 工资/扣除/实扣历史 → 员工、期数、应扣、实扣、差额、累计依据 | 工资表核对、系统迁移验证 |
| 累计预扣 | 最多12期正常工资 → 各期预扣和累计应纳 | 薪酬应用嵌入 |
| 年终奖比较 | 单独计税；完整年度数据下比较并入新增税额 | 年终奖测算 |
| 居民年度汇算估算 | 年度收入与扣除、模型或提供的预缴额 → 应退/应补 | 软件汇算结果核对 |
| 首期净额反推 | 固定社保和扣除条件、目标净额 → 最小可行税前 | 首期定薪试算 |
| 规则对比 | 两套明确的税表和基本减除参数 → 逐期差额 | 参数变更回归 |
| 金额与社保公式 | 整数分内核；险种独立基数与基点费率 | 精确金额与0.5%等费率表达 |

所有税务算法在 `src/*.mbt`。Node 负责文件读写和 CSV 适配，浏览器使用 MoonBit
编译的同一 JS 引擎。没有调用远程计税服务；浏览器载入静态程序文件后在本地计算。

## 适用范围

- 内置规则仅支持 **2026 年中国大陆居民个人、同一单位、普通累计预扣方法**。
- 期数为本单位当年的任职受雇期数，从1连续输入；缺失历史直接报错，不能只拿第三期工资当首期算。
- 首次取得工资可按累计自然月份扣除、上年收入不超过6万元的简便预扣、跨单位合并、免税/减免税、捐赠、非居民与境外规则暂未实现。
- 工资及符合条件的扣除金额、其他综合所得的收入额折算、扣除资格和重复申报由调用方确认。
- 年度计算必须显式设置 `annual_complete:true`，表示已提供全年全部收入及扣除。缺少此声明时，年终奖只输出单独计税试算，`best=needs_annual_data`。
- 年度基本减除按12个月计算；大病医疗等年度扣除走 `annual_deductions`，不能摊入月度预扣。
- 单独计税年终奖不包含在当前综合所得汇算输出中。库支持显式并入；调用方不得将同一奖金同时放入工资和附加奖金。
- `salary_prepaid` 是用户提供的工资已预扣额；省略则使用模型推算，报告标明 `prepaid_source`，不能视为实缴凭证。
- 各城市社保数据仅为示例。实际费率和各险种基数须由调用方提供并核实。

## CSV 复核接口

列：`employee_id,year,period,gross,social,special,other,actual_withheld`。
金额为十进制元，最多两位小数；文本按整数转换成分，拒绝指数或多余小数。
支持 UTF-8 BOM、带引号的逗号、转义引号、CRLF；拒绝重复表头、重复员工期数、
不连续历史和负金额。最多1000名员工、每人12期、CSV文本4MB。

```sh
node bin/audit.mjs examples/audit.csv --json
node bin/audit.mjs examples/audit.csv --tolerance 0.01 --json
```

退出码：0一致；1存在差异；2输入无效。容差默认0分。每期应扣按
`max(累计应纳 − 此前实际累计已扣, 0)` 计算；后续正常补扣不会仅因前期少扣而重复误报。
复核报告保留全部行，避免只给结论而无法复算。

## MoonBit 库与 JSON 接口

```sh
moon add JQ-ai-nb/wagekit@0.2.1
moon run examples/embed --target js
node bin/wagekit.mjs examples/settlement.json
node bin/wagekit.mjs examples/months.json --md
```

包导入路径是 `JQ-ai-nb/wagekit/src`。公共接口示例见 `examples/embed/main.mbt`，
包括 `cumulative_withholding`、`reconcile`、`bonus_compare_under` 和 `gross_up`。
JSON 金额必须是无小数、无指数的整数分。浏览器导出 `run`、`run_payslip`、`audit`。
复核 JSON 结构见 [格式说明](docs/FORMAT.md)。

批量首期工资条：`node bin/batch.mjs examples/employees.csv --out _build/slips`。
此便捷命令只处理首期，后续工资必须提供完整历史并使用复核接口。

## 验证

```sh
moon check --target all --deny-warn
moon test --target all --deny-warn
moon fmt --check
moon info
node scripts/build.mjs
node --test tests/cli.test.mjs tests/batch.test.mjs tests/audit.test.mjs
python tests/oracle.py 3000
```

Python 使用 Decimal 分段累加计算年度税额，与 MoonBit 的速算扣除实现分开。
3,000组随机用例加30个固定奖金边界用例对照；两套实现一致只说明已覆盖场景一致，
不能证明政策适用范围完整。核心测试覆盖预扣下降后恢复、边界1分、完整年度声明、
实际预缴、年度扣除、分项费率及规则注入。CI在 Linux/macOS/Windows 跑检查、测试、
构建和公共包示例；远程是否通过以 Actions 的实际结果为准。

## 同类项目与独立贡献

工资个税计算、年终奖比较和反推都有现有实现。本项目不主张算法首创或唯一：
[TaxCalculatorWeb](https://github.com/WingkySky/TaxCalculatorWeb)、
[SalaryCalculator](https://github.com/Ignareo/SalaryCalculator) 是功能相关的项目。

WageKit 的交付重点是 MoonBit 可依赖内核、实际预扣历史复核、逐期证据、
明确年度完整性与预缴来源、同一内核在库/CLI/浏览器中的复用。
现阶段没有已证实的生产用户；外部消费示例和合成复核案例是可验证的接入证据。
旧项目 JoinWitness/Relcore 属数据关系方向，本项目独立实现、无代码复用。

## 维护与来源

[计算口径](docs/SEMANTICS.md) · [规则来源](docs/RULES.md) ·
[与同类比较](docs/COMPARISON.md) · [发布说明](CHANGELOG.md)

MIT；运行依赖仅 MoonBit 标准库。政策采用公开官方文件，原创代码未移植上述同类项目。
AI参与了代码修改、测试设计和文档草稿；参赛者须理解范围、运行测试并对最终提交负责。
本库是计算与复核软件，结果仍须结合实际申报信息核实。
