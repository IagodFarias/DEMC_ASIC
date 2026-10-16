#!/usr/bin/env python3
"""
v2spice.py - converte uma netlist Verilog estrutural (saida do Innovus/Genus)
             em netlist SPICE para o LVS do KLayout.

Uso:
    python3 v2spice.py <netlist.v> <sg13g2_stdcell.cdl> <saida.cir> [--top ecc_design]

- Cada celula vira um X... ligado na ordem de pinos do .SUBCKT do CDL.
- VDD/VSS sao adicionados em todas as celulas e na porta do top.
- Barramentos sao expandidos bit a bit (data_in_left[0] ... data_in_left[15]),
  no mesmo formato dos rotulos de pino gravados no GDS.
- 'assign a = b;' vira um curto entre as duas redes (mesmo nome no SPICE).
- Constantes 1'b0/1'b1 ligadas direto a uma porta sao recusadas: no layout
  elas precisam vir de uma celula tie (sg13g2_tiehi/tielo).
"""
import argparse
import re
import sys


def ler_cdl(caminho):
    """Retorna {celula: [pinos na ordem do .SUBCKT]}."""
    pinos = {}
    linhas = open(caminho, encoding="utf-8", errors="replace").read().splitlines()
    i = 0
    while i < len(linhas):
        l = linhas[i]
        if l.upper().startswith(".SUBCKT"):
            campos = l.split()
            # continuacoes de linha com '+'
            while i + 1 < len(linhas) and linhas[i + 1].startswith("+"):
                i += 1
                campos += linhas[i][1:].split()
            pinos[campos[1]] = [c for c in campos[2:] if "=" not in c]
        i += 1
    return pinos


def faixa(msb, lsb):
    msb, lsb = int(msb), int(lsb)
    passo = 1 if lsb >= msb else -1
    return list(range(msb, lsb + passo, passo))


def nome_rede(tok, barramentos):
    """Normaliza um identificador Verilog para nome de rede SPICE."""
    tok = tok.strip()
    if tok.startswith("\\"):           # identificador escapado: \a[3] -> a[3]
        tok = tok[1:].strip()
    return tok


def expandir_expr(expr, barramentos):
    """Expande uma expressao de conexao em lista de bits (MSB primeiro)."""
    expr = expr.strip()
    if not expr:
        return []
    if expr.startswith("{") and expr.endswith("}"):
        partes, nivel, atual = [], 0, ""
        for ch in expr[1:-1]:
            if ch == "{":
                nivel += 1
            elif ch == "}":
                nivel -= 1
            if ch == "," and nivel == 0:
                partes.append(atual)
                atual = ""
            else:
                atual += ch
        partes.append(atual)
        bits = []
        for p in partes:
            bits += expandir_expr(p, barramentos)
        return bits
    m = re.fullmatch(r"(\d+)'[bB]([01]+)", expr)
    if m:
        return ["1'b" + b for b in m.group(2)]
    m = re.fullmatch(r"(\\?\S+?)\s*\[(\d+):(\d+)\]", expr)
    if m:
        base = nome_rede(m.group(1), barramentos)
        return [f"{base}[{i}]" for i in faixa(m.group(2), m.group(3))]
    m = re.fullmatch(r"(\\?\S+?)\s*\[(\d+)\]", expr)
    if m and not expr.startswith("\\"):
        return [f"{nome_rede(m.group(1), barramentos)}[{m.group(2)}]"]
    nome = nome_rede(expr, barramentos)
    if nome in barramentos:
        return [f"{nome}[{i}]" for i in barramentos[nome]]
    return [nome]


class Uniao:
    def __init__(self):
        self.pai = {}

    def achar(self, a):
        self.pai.setdefault(a, a)
        while self.pai[a] != a:
            self.pai[a] = self.pai[self.pai[a]]
            a = self.pai[a]
        return a

    def unir(self, a, b, preferido):
        ra, rb = self.achar(a), self.achar(b)
        if ra == rb:
            return
        # mantem como representante o nome de porta, se houver
        if rb in preferido and ra not in preferido:
            ra, rb = rb, ra
        self.pai[rb] = ra


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("verilog")
    ap.add_argument("cdl")
    ap.add_argument("saida")
    ap.add_argument("--top", default=None, help="modulo top (padrao: o unico/ultimo modulo)")
    ap.add_argument("--vdd", default="VDD")
    ap.add_argument("--vss", default="VSS")
    a = ap.parse_args()

    pinos_cdl = ler_cdl(a.cdl)
    texto = open(a.verilog, encoding="utf-8").read()
    texto = re.sub(r"/\*.*?\*/", "", texto, flags=re.S)
    texto = re.sub(r"//[^\n]*", "", texto)

    modulos = re.findall(r"\bmodule\s+(\S+?)\s*\((.*?)\)\s*;(.*?)\bendmodule", texto, flags=re.S)
    if not modulos:
        sys.exit("ERRO: nenhum modulo encontrado na netlist")
    if a.top:
        modulos = [m for m in modulos if m[0] == a.top]
        if not modulos:
            sys.exit(f"ERRO: modulo {a.top} nao encontrado")
    top, lista_portas, corpo = modulos[-1]
    portas = [p.strip() for p in lista_portas.split(",") if p.strip()]

    # declaracoes de porta/fio (com ou sem faixa)
    barramentos = {}
    for decl in re.finditer(r"\b(input|output|inout|wire)\s+(?:\[(\d+):(\d+)\]\s*)?([^;]+);", corpo):
        nomes = [nome_rede(n, {}) for n in decl.group(4).split(",")]
        if decl.group(2) is not None:
            for n in nomes:
                barramentos[n] = faixa(decl.group(2), decl.group(3))

    bits_porta = []
    for p in portas:
        bits_porta += expandir_expr(p, barramentos)
    preferido = set(bits_porta)

    uniao = Uniao()
    for m in re.finditer(r"\bassign\s+(.+?)\s*=\s*(.+?)\s*;", corpo):
        esq = expandir_expr(m.group(1), barramentos)
        dir_ = expandir_expr(m.group(2), barramentos)
        if len(esq) != len(dir_):
            sys.exit(f"ERRO: larguras diferentes em assign: {m.group(0)}")
        for x, y in zip(esq, dir_):
            if y.startswith("1'b"):
                sys.exit(f"ERRO: constante ligada direto em '{x}' (use celula tie)")
            uniao.unir(x, y, preferido)

    instancias = []
    padrao_inst = re.compile(r"(\\?[A-Za-z_][\w$]*)\s+(\\\S+|[A-Za-z_][\w$]*)\s*\((\s*\..*?)\)\s*;", re.S)
    for m in padrao_inst.finditer(corpo):
        celula, inst, conexoes = m.group(1), m.group(2), m.group(3)
        if celula in ("module", "input", "output", "inout", "wire", "assign"):
            continue
        if celula not in pinos_cdl:
            sys.exit(f"ERRO: celula '{celula}' (instancia {inst}) nao existe no CDL")
        mapa = {}
        for c in re.finditer(r"\.(\w+)\s*\(\s*(.*?)\s*\)\s*(?=,|$)", conexoes, flags=re.S):
            bits = expandir_expr(c.group(2), barramentos)
            if len(bits) > 1:
                sys.exit(f"ERRO: pino {c.group(1)} de {inst} ligado a mais de 1 bit")
            if bits and bits[0].startswith("1'b"):
                sys.exit(f"ERRO: constante no pino {c.group(1)} de {inst} (use celula tie)")
            mapa[c.group(1)] = bits[0] if bits else None
        instancias.append((celula, nome_rede(inst, {}), mapa))

    n_soltos = 0
    linhas = [f"* Gerado por signoff/v2spice.py a partir de {a.verilog}",
              f'.INCLUDE "{a.cdl}"', "",
              f".SUBCKT {top} " + " ".join(bits_porta + [a.vdd, a.vss])]
    for celula, inst, mapa in instancias:
        nos = []
        for pino in pinos_cdl[celula]:
            if pino == "VDD":
                nos.append(a.vdd)
            elif pino == "VSS":
                nos.append(a.vss)
            elif mapa.get(pino):
                nos.append(uniao.achar(mapa[pino]))
            else:
                n_soltos += 1
                nos.append(f"NC_{inst}_{pino}")
        linhas.append(f"X{inst} " + " ".join(nos) + f" {celula}")
    linhas += [f".ENDS {top}", ""]

    with open(a.saida, "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))
    print(f"{a.saida}: top={top}, {len(bits_porta)} bits de porta, "
          f"{len(instancias)} instancias, {n_soltos} pinos sem conexao")


if __name__ == "__main__":
    main()
