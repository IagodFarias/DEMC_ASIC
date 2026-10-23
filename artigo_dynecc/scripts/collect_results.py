#!/usr/bin/env python3
"""Extrai os resultados DYNECC direto dos relatorios Cadence para o CSV.
Nenhum numero e estimado: campo sem relatorio valido fica em branco.
Uso (dentro de artigo_dynecc): python3 scripts/collect_results.py [saida.csv]
"""
import csv, re, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "results/measurements_template.csv"
T0, T1, NOPS = 335.0, 7835.0, 1500          # janela do VCD (ns) e operacoes medidas
CASES = [("mrsc_only", "mrsc"), ("tbec_only", "tbec"),
         ("mux_reference", "tbec"), ("mux_reference", "mrsc"), ("mux_reference", "mixed"),
         ("mux_isolated", "tbec"), ("mux_isolated", "mrsc"), ("mux_isolated", "mixed")]
COLS = ["variant", "scenario", "area_logic_um2", "area_die_um2", "delay_typ_ns",
        "power_uW", "leakage_uW", "vcd_annotation_pct", "source_report", "notes",
        "internal_uW", "switching_uW", "area_core_um2", "nets_active_pct",
        "energy_pJ_per_op", "vcd_transitions", "gls_pass", "sdf_warnings"]

def text(p):
    return p.read_text(errors="replace") if p.is_file() else ""

def grab(pattern, s, cast=float):
    m = re.search(pattern, s, re.M)
    return cast(m.group(1)) if m else None

def fmt(x, nd=3):
    return "" if x is None else f"{x:.{nd}f}"

rows = []
for top, sc in CASES:
    d = ROOT / f"results/cadence/ecc_{top}"
    summ, tim = text(d / "summary.rpt"), text(d / "timing_pnr.rpt")
    # Innovus nao sobrescreve o log: cada rodada gera power_X.log, .log1, .log2... -> usar o mais recente
    plogs = sorted((p for p in d.glob(f"power_{sc}.log*") if re.fullmatch(rf"power_{sc}\.log\d*", p.name)),
                   key=lambda p: p.stat().st_mtime)
    prpt, plog = text(d / f"power_{sc}.rpt"), (text(plogs[-1]) if plogs else "")
    gls = text(ROOT / f"results/logs/{top}_{sc}_gls.log")
    vcd = ROOT / f"results/vcd/{top}_{sc}_gls.vcd"

    a_logic = grab(r"Total area of Standard cells\(Subtracting Physical Cells\):\s*([\d.]+)", summ)
    a_core = grab(r"Total area of Core:\s*([\d.]+)", summ)
    a_die = grab(r"Total area of Chip:\s*([\d.]+)", summ)
    delay = grab(r"^\s*-\s*Arrival Time\s+([\d.]+)", tim)       # 1o caminho = pior caso

    mw = lambda k: grab(rf"Total {k} Power:\s*([\d.eE+-]+)", prpt)
    p_int, p_sw, p_leak, p_tot = mw("Internal"), mw("Switching"), mw("Leakage"), grab(r"^Total Power:\s*([\d.eE+-]+)", prpt)
    uw = lambda v: None if v is None else v * 1000.0               # relatorio em mW
    p_int, p_sw, p_leak, p_tot = map(uw, (p_int, p_sw, p_leak, p_tot))
    glitch_on = "handle_glitch true" in plog
    if glitch_on:                                                  # configuracao rejeitada
        p_int = p_sw = p_leak = p_tot = None
    annot = grab(r"Total annotation coverage for all files of type VCD:.*=\s*([\d.]+)%", plog)

    active = toggles = None
    if vcd.is_file() and p_tot is not None:
        r = subprocess.run(["awk", "-v", f"t0={T0:g}", "-v", f"t1={T1:g}", "-v", "scope=tb_ecc_bench.dut",
                            "-f", str(ROOT / "scripts/vcd_toggles.awk"), str(vcd)],
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
        m = re.search(r"redes em \S+: (\d+) \| sem transicao na janela: (\d+).*transicoes: (\d+)", r.stdout)
        if m and int(m.group(1)):
            active = 100.0 * (int(m.group(1)) - int(m.group(2))) / int(m.group(1))
            toggles = int(m.group(3))

    gls_pass = ("PASS" in gls and "errors=0" in gls) if gls else None
    # Sem re-elaboracao (so mudou +SCENARIO), o Xcelium reutiliza o snapshot ja anotado e nao gera
    # sdf_annotate.log; nesse caso vale o log da elaboracao anterior do mesmo top.
    sdf_src, sdf_reused = ROOT / f"results/logs/{top}_{sc}_sdf.log", False
    if not sdf_src.is_file() and gls and "Annotating SDF" not in gls and "Writing initial simulation snapshot" not in gls:
        sib = sorted(ROOT.glob(f"results/logs/{top}_*_sdf.log"), key=lambda p: p.stat().st_mtime)
        if sib: sdf_src, sdf_reused = sib[-1], True
    sdf_w = len(re.findall(r"\*[WE],[A-Z]+", text(sdf_src))) if sdf_src.is_file() else None
    energy = None if p_tot is None else p_tot * 1e-6 * (T1 - T0) * 1e-9 / NOPS * 1e12

    notes = []
    if gls_pass is False: notes.append("GLS FALHOU")
    if glitch_on: notes.append("potencia descartada: handle_glitch true")
    if sdf_reused: notes.append(f"snapshot GLS reutilizado; SDF anotado em {sdf_src.name}")
    if p_tot is not None: notes.append(f"Innovus static, VCD GLS+SDF {T0:g}-{T1:g} ns, handle_glitch false")

    rows.append({
        "variant": top, "scenario": sc,
        "area_logic_um2": fmt(a_logic), "area_die_um2": fmt(a_die), "delay_typ_ns": fmt(delay),
        "power_uW": fmt(p_tot), "leakage_uW": fmt(p_leak, 4), "vcd_annotation_pct": fmt(annot, 1),
        "source_report": f"cadence/ecc_{top}/{{summary,timing_pnr}}.rpt; power_{sc}.rpt",
        "notes": "; ".join(notes),
        "internal_uW": fmt(p_int), "switching_uW": fmt(p_sw), "area_core_um2": fmt(a_core),
        "nets_active_pct": fmt(active, 1), "energy_pJ_per_op": fmt(energy, 4), "vcd_transitions": "" if toggles is None else str(toggles),
        "gls_pass": "" if gls_pass is None else ("PASS" if gls_pass else "FAIL"),
        "sdf_warnings": "" if sdf_w is None else str(sdf_w) + ("*" if sdf_reused else "")})

with OUT.open("w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=COLS); w.writeheader(); w.writerows(rows)

print(f"{'variant':14s} {'scen':6s} {'logic um2':>10s} {'die um2':>10s} {'delay ns':>9s} "
      f"{'P uW':>9s} {'pJ/op':>7s} {'ativas%':>7s} {'transic':>8s} {'GLS':>5s} {'SDFw':>5s}")
for r in rows:
    print(f"{r['variant']:14s} {r['scenario']:6s} {r['area_logic_um2']:>10s} {r['area_die_um2']:>10s} "
          f"{r['delay_typ_ns']:>9s} {r['power_uW']:>9s} {r['energy_pJ_per_op']:>7s} "
          f"{r['nets_active_pct']:>7s} {r['vcd_transitions']:>8s} {r['gls_pass']:>5s} {r['sdf_warnings']:>5s}")
print("* = snapshot do GLS reutilizado (SDF anotado na elaboracao anterior do mesmo top)")
print(f"\nCSV: {OUT}")
