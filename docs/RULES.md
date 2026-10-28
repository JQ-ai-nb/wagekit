# Rules and Data Versioning

The engine and the rules are **strictly separated**. Everything a policy
change touches lives in data tables or parameter structs; the engine only
implements formulas. This page is the audit surface.

## 所得税税率表（Progressive tables）

| 表 | 位置 | 内容 |
| --- | --- | --- |
| 综合所得年度表 | `annual_table()` in `src/tax_table.mbt` | 7 级：36,000 / 144,000 / 300,000 / 420,000 / 660,000 / 960,000 元，税率 3%–45%，速算扣除 0–181,920 元 |
| 按月换算表（年终奖） | `monthly_table()` | 7 级：3,000 / 12,000 / 25,000 / 35,000 / 55,000 / 80,000 元，速算扣除 0–15,160 元 |

- 来源口径：现行个人所得税法及月度换算表（全年一次性奖金）。
- **年度版本化**：新年度规则 = 新增一个 `annual_table_2027()` 并在入口按
  `year` 选择；旧表保留，历史重算结果不变。

## 基本减除费用

`BASIC_DEDUCTION` = 5,000 元/月（`src/withholding.mbt`）。若立法调整，改这一个常量并补版本测试。

## 专项附加扣除标准（current cycle）

定义于 `src/special_deductions.mbt`，全部为命名常量：

| 项 | 月度标准 | 上限校验 |
| --- | --- | --- |
| 子女教育 | 2,000 元/孩 | — |
| 3 岁以下婴幼儿 | 2,000 元/孩 | — |
| 住房贷款利息 | 1,000 元 | 与租房互斥 |
| 住房租金 | 800 / 1,100 / 1,500 元按城市档 | 档位枚举 |
| 赡养老人 | 分摊额，合计 ≤3,000 元 | 3,000 元 |
| 继续教育 | ≤400 元/月 | 400 元（3,600 元年票由调用方均摊） |
| 大病医疗 | 年度自付超 1.5 万部分，≤80,000 元/年 | 80,000 元 |

## 社保公积金参数（EXAMPLE）

`city_params()` 内置北京/上海/深圳/广州/杭州五个城市的示例参数（基数上下限、
个人比例）。**这些是量级合理的示例数据，不是当年法定值**——真实使用前必须
以各市人社部门年度公布值替换。参数是纯数据，替换不需要动引擎。

## 劳务报酬（Labor remuneration）

折算（≤4,000 减 800；>4,000 打八折）与三档预扣率（20/30/40%，速算
0/2,000/7,000）定义于 `src/labor.mbt`。

## 变更协议（Change protocol）

1. 修改数据表/常量；
2. 更新 `docs/SEMANTICS.md` 对应条目；
3. 新增该规则边界的 ±1 分穷举测试；
4. 跑 `python tests/oracle.py`——Python 端同步修改后对比；
5. 版本号 minor +1，CHANGELOG 记录口径来源。
