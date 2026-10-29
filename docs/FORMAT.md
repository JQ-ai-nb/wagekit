# 输入与输出

## 计算JSON

`{"year":2026,"months":[{"gross":1500000,"social":0,"special":0,"other":0}]}`

所有金额为整数分。months按本单位当年任职受雇期数排列，最多12期。
可选bonus、explain、target_net；preview.basic_deduction为假设每月减除费用。
年终奖默认只给standalone_tax，best=needs_annual_data。
annual_complete:true声明全年全部收入与扣除已给定后，计算最终年度比较与汇算估算。
other_income为已按法定比例折算的其他收入额；other_prepaid为该部分已预缴额。
两者必须成对提供；没有金额时明确写0。未知输入字段直接报错，不参与静默计算。
salary_prepaid为工资实际预扣总额；缺省使用模型值并标明来源。
annual_deductions为未在月度输入重复列示的全年追加扣除。
旧deduction_months参数仅允许12；其他值拒绝。

奖金默认在综合所得汇算中排除。若选择将 `bonus` 另行并入年度综合所得，需设置
`bonus_merged:true`、`annual_complete:true` 和 `salary_prepaid`；后者应包含工资和该奖金
此前已经预扣的税款，不能重复计入other_prepaid。`months` 中不得重复包含同一笔奖金。

## 复核JSON

```json
{"year":2026,"tolerance":0,"employees":[
  {"employee_id":"E001",
   "months":[{"gross":1500000,"social":0,"special":0,"other":0}],
   "actual_withheld":[30000]}
]}
```

通过MoonBit run_audit_report或JS audit调用。金额单位分；employees最多1000项，
每人1..12期；employee_id非空且唯一；actual_withheld与months等长。
结果ok表示输入有效，passed表示全部差额在容差内。不要把ok当作复核一致。

## CSV和CLI

audit.csv列为employee_id,year,period,gross,social,special,other,actual_withheld。
也支持员工编号,年份,期次,应发工资,个人社保公积金,专项附加扣除,其他计税扣除,实扣个税。
此处金额单位元，与JSON不同；year固定2026，period从1连续。支持引号和CRLF。
列顺序可变，中文与英文列名可混用但不能重复映射；未识别列直接报错。员工ID按文本保留。
输出JSON不带原始工资列，仅带计算证据；
文件仍涉及敏感信息，应由实际使用方管理权限。仓库样例全部合成。
退出码0一致、1差异、2无效。见examples/audit.csv与audit-clean.csv。
