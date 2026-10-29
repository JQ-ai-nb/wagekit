import {run,audit} from './wagekit.js';
import {auditDocument} from './csv.mjs';
const $=id=>document.getElementById(id);
const money=n=>(n/100).toFixed(2);
const escape=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function auditError(error){
 return error.message
  .replace('unsupported CSV column: ','不支持的列：')
  .replace('missing column: ','缺少必需列：')
  .replace('duplicate CSV header','表头重复，中英文同义列只能保留一列')
  .replace('period history must start at 1 with no gaps: ','期次须从1开始连续填写：')
  .replace('duplicate employee period: ','员工期次重复：')
  .replace('only year 2026 is supported','当前仅支持2026年')
  .replace('invalid employee_id','员工编号无效')
  .replace('period must be 1..12','期次须为1至12的整数')
  .replace('must be decimal yuan with at most two decimals','必须是最多两位小数的元金额')
  .replace('must be non-negative','不能为负数')
  .replace('wrong column count','字段数量与表头不一致');
}
const header='employee_id,year,period,gross,social,special,other,actual_withheld\n';
const bad=header+'E001,2026,1,15000,0,0,0,300\nE001,2026,2,0,0,0,0,0\nE001,2026,3,15000,0,0,0,300\nE002,2026,1,20000,2000,0,0,390\n';
const good=bad.replace('E001,2026,3,15000,0,0,0,300','E001,2026,3,15000,0,0,0,150');
const chinese=bad.replace(header,'员工编号,年份,期次,应发工资,个人社保公积金,专项附加扣除,其他计税扣除,实扣个税\n');
function check(){
 try{
  const r=JSON.parse(audit(JSON.stringify(auditDocument($('csv').value))));
  if(!r.ok)throw new Error(r.error);
  $('audit-status').textContent=r.passed?'复核一致：'+r.checked+' 期，未发现差异':'发现 '+r.differences+' 项差异（共复核 '+r.checked+' 期）';
  $('audit-status').className='status '+(r.passed?'good':'');
  const first=r.rows.find(x=>!x.matched);
  $('audit-summary').textContent=first?`${first.employee_id} 第${first.period}期：应扣 ${money(first.expected)} 元，实扣 ${money(first.actual)} 元，差额 ${money(first.delta)} 元。`:'';
  $('audit-json').textContent=JSON.stringify(r,null,2);
  $('audit-table').innerHTML='<table><thead><tr><th>员工</th><th>期数</th><th>累计应纳</th><th>此前实扣累计</th><th>本期应扣</th><th>本期实扣</th><th>差额（元）</th></tr></thead><tbody>'+r.rows.map(x=>'<tr class="'+(x.matched?'':'bad')+'"><td>'+escape(x.employee_id)+'</td><td>'+x.period+'</td>'+[x.tax_cum,x.paid_before,x.expected,x.actual,x.delta].map(n=>'<td>'+money(n)+'</td>').join('')+'</tr>').join('')+'</tbody></table>';
 }catch(e){$('audit-status').textContent='无法复核：'+auditError(e);$('audit-summary').textContent='';$('audit-table').textContent='';$('audit-json').textContent='';}
}
$('csv').value=bad;
$('audit-go').onclick=check;
$('bad-sample').onclick=()=>{$('csv').value=bad;check();};
$('good-sample').onclick=()=>{$('csv').value=good;check();};
$('zh-sample').onclick=()=>{$('csv').value=chinese;check();};
$('csv-file').onchange=async e=>{const f=e.target.files[0];if(f){if(f.size>4_000_000){$('audit-status').textContent='文件超过 4 MB';return;}$('csv').value=await f.text();check();}};
const m=(gross,special=0)=>({gross,social:0,special,other:0});
const scenarios={
 recovery:{note:'累计已扣税款在收入下降时保留；收入恢复后，本期应扣只补尚欠部分。',doc:{year:2026,months:[m(1500000),m(0),m(1500000)],explain:true}},
 bonus:{note:'36,000.01 元已超过第一档上限；确认完整年度数据后才比较两种方式的全年税负。',doc:{year:2026,annual_complete:true,months:[m(2000000)],bonus:3600001}},
 annual:{note:'全年只有一个月工资 20,000 元和劳务收入额 8,000 元。居民年度减除 60,000 元，按提供的已预缴额估算退税 2,050 元。',doc:{year:2026,annual_complete:true,months:[m(2000000)],other_income:800000,other_prepaid:160000,salary_prepaid:45000}},
 offer:{note:'首个普通扣缴期、固定社保和扣除条件下反推税前；后续月份不能直接沿用首期结果。',doc:{year:2026,months:[m(0,300000)],target_net:2000000}},
 policy:{note:'假设把每月基本减除从 5,000 调整到 6,000 元。这是软件模拟参数，不是已实施政策。',doc:{year:2026,months:Array.from({length:12},()=>m(3000000,300000)),preview:{basic_deduction:600000}}}
};
function calc(){
 try{
  const r=JSON.parse(run($('params').value));if(!r.ok)throw new Error(r.error);
  const lines=['工资预扣合计：'+money(r.total_withheld)+' 元'];
  if(r.months.length)lines.push('逐期预扣：'+r.months.map(x=>money(x.withheld)).join(' / ')+' 元');
  if(r.bonus){lines.push('年终奖单独计税：'+money(r.bonus.standalone_tax)+' 元');lines.push(r.bonus.best==='needs_annual_data'?'全年数据未确认，暂不推荐计税方式':'在已声明完整的年度数据下：'+(r.bonus.best==='combined'?'并入综合所得':'单独计税')+'税负较低或相同');}
  if(r.settlement){
    const scope=r.settlement.bonus_merged?'（奖金并入）':(r.bonus?'（不含单独计税奖金）':'');
    lines.push('年度汇算估算'+scope+'：应纳 '+money(r.settlement.tax_due)+'，应退 '+money(r.settlement.refund)+'，应补 '+money(r.settlement.payable)+' 元；预缴来源：'+(r.settlement.prepaid_source==='provided'?'用户提供':'模型推算'));
  }
  if(r.gross_up)lines.push('首期目标到手 '+money(r.gross_up.target_net)+' 元，需要税前 '+money(r.gross_up.gross)+' 元');
  if(r.policy_impact)lines.push('假设规则影响：'+money(r.policy_impact.total_delta)+' 元');
  $('calc-result').textContent=lines.join('\n');$('calc-json').textContent=JSON.stringify(r,null,2);
 }catch(e){$('calc-result').textContent='无法试算：'+e.message;$('calc-json').textContent='';}
}
function choose(key){$('scenario-note').textContent=scenarios[key].note;$('params').value=JSON.stringify(scenarios[key].doc,null,2);calc();}
document.querySelectorAll('[data-scenario]').forEach(b=>b.onclick=()=>choose(b.dataset.scenario));
$('calc-go').onclick=calc;
check();choose('recovery');
