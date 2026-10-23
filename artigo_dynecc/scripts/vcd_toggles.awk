# uso: awk -v t0=335 -v t1=7835 -v scope=tb_ecc_bench.dut -f scripts/vcd_toggles.awk arquivo.vcd
BEGIN { mul=1000 }
/\$timescale/ { ts=1 }
ts && /fs/ { mul=1000000 }
ts && /ps/ { mul=1000 }
ts && /ns/ { mul=1 }
ts && /\$end/ { ts=0 }
/^[ \t]*\$scope/   { depth++; path[depth]=$3; next }
/^[ \t]*\$upscope/ { depth--; next }
/^[ \t]*\$var/ { p=path[1]; for(i=2;i<=depth;i++) p=p"."path[i];
                 if (p==scope && !($4 in name)) { name[$4]=$5; n++ } next }
/^#/ { t=substr($0,2)/mul; next }
/^[01xzXZ]/ { id=substr($0,2); if ((id in name) && t>t0 && t<t1) c[id]++; next }
/^[bBrR]/   { id=$2;           if ((id in name) && t>t0 && t<t1) c[id]++; next }
END { z=0; tot=0
      for (id in name) { if (id in c) tot+=c[id]; else { z++; if (z<=15) zl=zl" "name[id] } }
      printf "redes em %s: %d | sem transicao na janela: %d (%.1f%%) | transicoes: %d\n", scope, n, z, (n?100*z/n:0), tot
      if (z) print "exemplos parados:" zl }
