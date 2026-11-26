# TD-3.6 P1 corrections — eight polyomino candidates

The original eight files (`td36-001`–`008`) are **technical fixtures**. They stay in `levels_v2/td36/` for solver and metric regression. Product review rejected them as generator seeds because six of them are the same 1D siding shuttle.

These eight extra files (`td36-009`–`016`) are **review candidates**, not a production campaign and not a generator template. P2 is not started.

## Proven vs estimated

| Kind | Source |
| --- | --- |
| Proven | Schema, `SOLVED` under cap 80 000, witness replay, shortest length, explored states, branching along that witness, shortest-path count (complete on all eight), counterfactual `blocked_by`, `genuine_multi_piece`, `mechanism_family`, `interaction_pattern`, pairwise structural similarity |
| Estimated only | Human time, fun, “Easy/Medium” feel. `human_difficulty` is `unmeasured` on every card |

Solver length 4–6 is **not** a claim that a person will finish in 30 seconds. It only means the shortest legal plan is that long.

## Candidate table (Godot 4.7.2, cap 80 000)

| ID | Pattern | Shapes | Len | Explored | Paths | genuine_multi | Why it is a puzzle |
| --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| 009 | drop_wait | T, L | 5 | 1362 | 2 | true | T cannot use a 1-cell door; L and keys occupy the 3-wide floor |
| 010 | bar_lane | I-tromino, L | 5 | 346 | 15 | false | 3-wide bar must slide two columns; L occupies the slide |
| 011 | bar_and_z | Z, I-tromino, L | 4 | 143 | 3 | true | Z’s floor span is plugged by a tall post that leaves sideways |
| 012 | slide_then_drop | T, L | 5 | 3159 | 12 | false | T’s gate is two columns right of its start |
| 013 | triple_stack | T, S, L | 6 | 1417 | 5 | true | T sits on an S; S must leave a 2-row side gate |
| 014 | bar_and_t | T, I-tetromino, L | 5 | 516 | 15 | false | 1-cell vs 3-cell floor gates; the post must drop first |
| 015 | domino_plug | T, L, domino | 4 | 194 | 6 | false | A two-cell plug covers the T’s floor |
| 016 | plus_block | plus, S, L | 6 | 298 | 2 | true | 3×3 plus waits; S parks, yields a key, then exits |

None of 009–016 is `siding_1d`. Pairwise similarity is below 0.80 (near-duplicate threshold). 011 and 015 miss the Easy 5–10 action band (`meets_target` false).

## Witnesses (shortest)

### td36-009 T Waits for the L (5)
1. exit orange orange_right
2. move yellow down 2,4
3. exit blue blue_right
4. exit yellow yellow_left
5. exit red red_bottom

### td36-010 Three-Wide Lane (5)
1. exit green green_right
2. move blue right 2,1
3. exit orange orange_right
4. exit blue blue_bottom
5. exit yellow yellow_left

### td36-011 Z And the Post (4)
1. exit blue blue_right
2. exit orange orange_right
3. exit red red_left
4. exit yellow yellow_bottom

### td36-012 Slide Then Drop (5)
1. exit green green_right
2. move blue right 2,0
3. exit orange orange_right
4. exit yellow yellow_left
5. exit blue blue_bottom

### td36-013 Stacked Skews (6)
1. exit green green_right
2. move blue up 0,3
3. exit yellow yellow_left
4. move blue down 0,4
5. exit blue blue_right
6. exit red red_bottom

### td36-014 T Meets the Post (5)
1. exit blue blue_bottom
2. exit green green_left
3. move red right 2,0
4. exit yellow yellow_right
5. exit red red_bottom

### td36-015 Domino Plug (4)
1. exit blue blue_left
2. exit green green_right
3. exit yellow yellow_right
4. exit red red_bottom

### td36-016 Plus in the Well (6)
1. exit blue blue_left
2. move green up 2,2
3. exit yellow yellow_left
4. move green down 2,3
5. exit green green_right
6. exit purple purple_bottom

## QA route

Dev menu **TD-3.6 QA** (`scenes/Td36Qa.tscn`) lists fixtures and candidates. Progress is `user://td36_qa.save` only. Play, Levels, `user://progress.save`, and `user://pilot_v2.save` are unchanged. The HUD timer counts up from the first committed move and does not fail the puzzle.

## Still not approved

These candidates are short (4–6 actions) and 4-piece. They vary shape and gate width; they do **not** recreate 15–31 action siding depth. Do not bulk-generate from them until product playtest says the interactions are worth copying.
