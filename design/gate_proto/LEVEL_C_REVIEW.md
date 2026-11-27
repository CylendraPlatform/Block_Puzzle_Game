# Level C "Turn the Corner": review of its optimal solutions and Chapter 1 fit

Evidence: `test/proto_level_analysis.gd` (enumerates every optimal sequence; read-only), run
2026-11-27 on Windows, Godot 4.7.2 headless, exit 0. Level B is analysed alongside for
comparison.

```
godot --headless --path . --script res://test/proto_level_analysis.gd -- proto_c.json
```

## What the 65 optimal sequences are

| Measure | Level B | Level C |
|---|---|---|
| Par | 6 | 9 |
| Optimal move sequences | 11 | 65 |
| Distinct plans (same set of moves, order ignored) | 1 | 3 |
| Exit orders | 6 | 6, **all starting with the blue T** |
| States within par - 1 moves | 8,639 | 86,922 |
| Optimal / legal moves at move 1 | 1 / 18 | 4 / 19 |
| Optimal / legal moves over the remaining moves | 21 / 165 (about 1 in 8) | 67 / 653 (about 1 in 10) |

The three Level C plans differ only in where the yellow bar parks while the T comes up:

1. yellow **right** to (4,2), later down to (4,4) and out (the authored plan; 25 sequences);
2. yellow **up** to (2,1), later down to (2,4) and out along row 4 (20);
3. yellow **up** to (2,0), otherwise as plan 2 (20).

All three share the same core: the T comes up and leaves first; the L moves right to columns
4-5 (which opens the I3's column); the I3 moves left to column 1 (which opens the L's columns);
then each leaves. So the 65 sequences are **one idea with two parking choices**, multiplied by
interleavings of moves that do not depend on each other (after the T leaves there are 6 exit
orders). The count is not a sign of a shortcut: the solver proves 9 is the minimum, and every
gate is binding.

## Is it right for early Chapter 1?

**No. It belongs in the second half of Chapter 1 (about levels 12-16).**

- **Too many new things at once.** Four colours, four shapes, four doors on four sides, and the
  silhouette rule for three shapes (the T needs a 2-cell side door, the L a 2-cell bottom door,
  the I3 a 1-cell top door). An early level should introduce one of these.
- **One key insight, then busywork.** The real decision is "the T must leave first, so yellow
  must park". After that the order of the other three is mostly free, which adds moves without
  adding thinking.
- **The best idea is easy to miss.** The L and the I3 each block the other's way out until both
  step aside, but the level does not make the player notice it; a dedicated level should.

## Teaching ladder proposed for Chapter 1 (no levels authored now)

| Levels | Teaches | Like |
|---|---|---|
| 1-3 | One block, one door; line up first; tall vs wide bar | Level A |
| 4-6 | Two colours, two doors; one block in the other's lane; order matters | Level B |
| 7-9 | Shape vs door width: a T or L needs a 2-cell door from one side, a 3-cell one from another | new |
| 10-11 | Parking: a block must step aside to a cell that is not on its own way out | new |
| 12-16 | Combined: shape lock, parking and order | Level C |
| 17-20 | Mechanics that justify a second gate (locked / counter gates) | later spec |

If the owner wants a Level C-like puzzle earlier, the smallest change is to remove a block (for
example the yellow bar, which removes the parking step) and re-validate; the gates would stay.
