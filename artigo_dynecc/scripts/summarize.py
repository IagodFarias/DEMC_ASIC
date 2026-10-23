#!/usr/bin/env python3
"""Summarize VERIFIED, manually extracted ASIC results. No numbers are assumed."""
import csv,sys,pathlib
p=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else 'results/measurements_template.csv')
with p.open(newline='') as f: rows=list(csv.DictReader(f))
items={}
for r in rows:
  try:
    if not r['power_uW'].strip():continue
    val=float(r['power_uW'])
    if val<0:raise ValueError('negative power')
    key=(r['variant'],r['scenario'])
    items[key]=val
  except ValueError:
    raise SystemExit('Invalid number: '+repr(r))
if not items:raise SystemExit('No measured power values yet; fill CSV after Cadence runs.')
for (variant,sc),val in sorted(items.items()):
  print(f'{variant:16s} {sc:6s} {val:10.3f} uW')
for sc in ('tbec','mrsc','mixed'):
  a=items.get(('mux_reference',sc));b=items.get(('mux_isolated',sc))
  if a is not None and b is not None and a>0:
    print(f'{sc:6s}: gated input isolation relative to reference: {100*(a-b)/a:+.2f}% savings')
