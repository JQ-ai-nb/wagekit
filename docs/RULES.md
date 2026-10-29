# 规则来源与版本边界

核对日期：2026-10-29。内置版本CN-resident-2026.2仅用于2026年居民普通工资累计预扣。
以下链接是口径来源；代码及测试的推导不替代官方解释或申报系统。

| 内容 | 官方来源 | 实现 |
| --- | --- | --- |
| 综合所得税率、年度减除费用6万元 | [个人所得税法](https://www.chinatax.gov.cn/chinatax/n810219/n810744/n3752930/n3752974/c3970366/content.html)第六条、税率表一 | tax_table.mbt、settlement.mbt |
| 当期应扣减去累计已预扣、负差暂不退 | [2018年第61号第六条的税务问答](https://liaoning.chinatax.gov.cn/art/2020/12/31/art_99_54414.html) | rules.mbt、audit.mbt |
| 奖金除12选月表、单独计税或并入、政策有效期 | [财政部税务总局2023年第30号](https://jiangsu.chinatax.gov.cn/art/2023/8/28/art_8349_432405.html)，执行至2027-12-31 | bonus.mbt |
| 只工作部分月份仍可年度减除6万元 | [上海税务年度汇算问答](https://shanghai.chinatax.gov.cn/zcfw/rdwd/202404/t471515.html) | settlement.mbt |
| 大病医疗超1.5万元部分，8万元限额，年度汇算扣除 | [税务问答](https://jiangsu.chinatax.gov.cn/art/2023/11/10/art_9280_439902.html) | special_deductions.mbt |
| 学历继续教育400/月、资格继续教育当年3600 | [2026上海税务问答](https://shanghai.chinatax.gov.cn/zcfw/rdwd/202602/t479530.html) | 辅助金额和调用方年度输入 |

子女教育、婴幼儿照护、赡养老人标准来源于国务院2023年提高专项附加扣除标准的通知；
本库辅助结构仅计算已确认资格的金额，不实现家庭全量资格判断或期限管理。
五城社保参数为合成演示参数，不是当前法定数据；Contribution表达自备的分险种基数和费率。

版本策略：改规则必须改版本号、更新来源和有效期、补固定边界与回归用例后发布新包。
当前没有多年份自动政策路由；不支持的year拒绝。自定义假设规则必须有自己的版本名，
不能冒用CN-resident-2026.2。本次0.2修复改变0.1结果，旧结果应按新口径复核。
