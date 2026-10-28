///|
/// Payslip rendering. Output is Markdown so it drops into reports, chats and
/// terminals unchanged.

///|
/// Render one month's payslip in Markdown. `note` is an optional trailing
/// remark (pass "" for none).
pub fn render_payslip(
  year : Int32,
  month : Int32,
  input : MonthInput,
  result : MonthResult,
  note : String,
) -> String {
  let buf = StringBuilder()
  buf.write_string("# 工资条 \{year} 年 \{month} 月\n\n")
  buf.write_string("| 项目 | 金额（元） |\n| --- | --- |\n")
  buf.write_string("| 应发工资 | \{yuan_text(input.gross)} |\n")
  buf.write_string(
    "| 三险一金（个人） | \{yuan_text(input.social)} |\n",
  )
  buf.write_string("| 专项附加扣除 | \{yuan_text(input.special)} |\n")
  buf.write_string("| 其他扣除 | \{yuan_text(input.other)} |\n")
  buf.write_string("| 本月预扣个税 | \{yuan_text(result.withheld)} |\n")
  buf.write_string(
    "| 实发 | \{yuan_text(input.gross - input.social - result.withheld)} |\n\n",
  )
  buf.write_string(
    "- 累计应纳税所得额：\{yuan_text(result.taxable_cum)} 元\n- 累计应预扣：\{yuan_text(result.tax_cum)} 元\n",
  )
  if note != "" {
    buf.write_string("\n> \{note}\n")
  }
  buf.to_string()
}

///|
/// Render the annual bonus comparison in Markdown.
pub fn render_bonus_report(choice : BonusChoice) -> String {
  let buf = StringBuilder()
  buf.write_string("# 年终奖计税方式对比\n\n")
  buf.write_string("| 方式 | 税额（元） |\n| --- | --- |\n")
  buf.write_string("| 单独计税 | \{yuan_text(choice.standalone_tax)} |\n")
  buf.write_string(
    "| 并入综合所得（新增） | \{yuan_text(choice.combined_extra_tax)} |\n\n",
  )
  let suggestion = if choice.best == "standalone" {
    "单独计税"
  } else {
    "并入综合所得"
  }
  buf.write_string("建议方式：**\{suggestion}**\n")
  buf.to_string()
}
