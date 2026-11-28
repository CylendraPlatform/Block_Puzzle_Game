"""Paired analysis of the interleaved bench_board_draw runs in this folder (raw RAW rows)."""
import glob
import statistics as st


def load(path):
    rows = {}
    for line in open(path, encoding="utf-8", errors="replace"):
        if line.startswith("RAW,") and not line.startswith("RAW,level,"):
            f = line.strip().split(",")
            rows[f[1]] = float(f[4])
    return rows


base = [load(p) for p in sorted(glob.glob("base_run*.log"))]
new = [load(p) for p in sorted(glob.glob("refactor_run*.log"))]
levels = sorted(base[0])
print("levels", len(levels), "runs base", len(base), "refactor", len(new))
rb = [st.median(r.values()) for r in base]
rn = [st.median(r.values()) for r in new]
print("run medians base     ", [round(x, 1) for x in rb], "mean %.1f sd %.1f" % (st.mean(rb), st.stdev(rb)))
print("run medians refactor ", [round(x, 1) for x in rn], "mean %.1f sd %.1f" % (st.mean(rn), st.stdev(rn)))
print("paired run diffs (refactor - base, same slot):", [round(n - b, 1) for n, b in zip(rn, rb)])
ratios = sorted(st.mean(n[l] for n in new) / st.mean(b[l] for b in base) for l in levels)
print("per-level mean ratio refactor/base: median %.3f  p10 %.3f  p90 %.3f" % (st.median(ratios), ratios[10], ratios[89]))
print("levels slower: %d  faster: %d" % (sum(r > 1 for r in ratios), sum(r < 1 for r in ratios)))
# Noise floor: same code, base runs 1-2 vs 3-5 (no code change).
half = sorted(st.mean(b[l] for b in base[:2]) / st.mean(b[l] for b in base[2:]) for l in levels)
print("noise floor (base runs 1-2 vs 3-5, same code): median ratio %.3f  p10 %.3f  p90 %.3f" % (st.median(half), half[10], half[89]))
