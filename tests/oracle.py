"""Decimal cross-check using marginal-band accumulation, not quick deductions.
References: IIT Law article 6 / rate table; STA 2018-61; MOF/STA 2023-30.
This checks implementation agreement, not policy completeness or eligibility.
"""
import json,random,subprocess,sys
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
BOUNDS=[3600000,14400000,30000000,42000000,66000000,96000000]
RATES=[3,10,20,25,30,35,45]
def rounded(v):return int(v.quantize(Decimal(1),rounding=ROUND_HALF_UP))
def annual_tax(taxable):
    remaining=max(taxable,0);previous=0;total=Decimal(0)
    for upper,rate in zip(BOUNDS+[10**18],RATES):
        band=min(remaining,upper-previous)
        total+=Decimal(band)*Decimal(rate)/100
        remaining-=band;previous=upper
        if not remaining:break
    return rounded(total)
def bonus_tax(bonus):
    # Exact Decimal division; never discard fractional cents when selecting.
    monthly=Decimal(bonus)/12
    bounds=[300000,1200000,2500000,3500000,5500000,8000000,10**18]
    quick=[0,21000,141000,266000,441000,716000,1516000]
    for upper,rate,q in zip(bounds,RATES,quick):
        if monthly<=upper:return rounded(Decimal(bonus)*rate/100)-q
def expected(case):
    rows=[];gross=deductions=paid=0
    for k,m in enumerate(case['months'],1):
        gross+=m['gross'];deductions+=500000+m['social']+m['special']+m['other']
        taxable=gross-deductions;due=annual_tax(taxable)
        amount=max(due-paid,0);paid+=amount
        rows.append(dict(month=k,taxable_cum=taxable,tax_cum=due,withheld=amount))
    result=dict(ok=True,rules='CN-resident-2026.2',year=2026,months=rows,total_withheld=paid,bonus=None)
    if 'bonus' in case:
        bonus=case['bonus']
        result['bonus']=dict(amount=bonus,standalone_tax=bonus_tax(bonus),combined_extra_tax=None,best='needs_annual_data')
    return result
def main():
    n=int(sys.argv[1]) if len(sys.argv)>1 else 3000
    rng=random.Random(42);cases=[]
    # All published bonus edges: fixed probes, not chance coverage.
    for edge in BOUNDS:
        for offset in [-1,0,1,11,12]:
            cases.append(dict(year=2026,months=[],bonus=edge+offset))
    for _ in range(n):
        months=[]
        for _ in range(rng.randint(1,12)):
            gross=rng.randint(0,8000000)
            months.append(dict(gross=gross,social=rng.randint(0,min(gross,600000)),special=rng.randint(0,600000),other=0))
        case=dict(year=2026,months=months)
        if rng.random()<0.6:case['bonus']=rng.randint(0,20000000)
        cases.append(case)
    file=ROOT/'_build/oracle-cases.json';file.parent.mkdir(exist_ok=True)
    file.write_text(json.dumps(cases),encoding='utf-8')
    run=subprocess.run(['node',str(ROOT/'tests/batch.mjs'),str(file)],capture_output=True,text=True,cwd=ROOT)
    if run.returncode:raise RuntimeError(run.stderr[-1000:])
    reports=json.loads(run.stdout)
    assert len(reports)==len(cases),'truncated report stream'
    for i,(case,report) in enumerate(zip(cases,reports)):
        want=expected(case)
        if report!=want:
            print('MISMATCH',i,json.dumps(case),json.dumps(want),json.dumps(report));return 1
    print(f'oracle: {n} random cases + 30 fixed boundary cases matched field by field')
    return 0
if __name__=='__main__':sys.exit(main())
