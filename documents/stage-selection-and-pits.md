# Stage selection, blockers and Stage 3 falls

City Warrior now boots into its own four-stage picker. Click a stage, use
arrow keys + Enter, or press 1–4. The selected stage starts fresh and still
progresses through the remaining campaign normally. The HUD's **STAGES [ESC]**
button (or Escape) returns to the picker, discarding the current stage. This
does not change the Game Center lobby or any other embedded game.

Stage 3 starts with **three fall lives**, shown below Billy's health bar.
Each fall removes exactly one life, with no additional 20-HP penalty. The
first two falls return Billy to his last safely supported checkpoint, preserving
combat HP and granting the existing short recovery protection. The third fall
uses normal defeat/retry; retry resets the stage and its three lives. Combat
damage and combat death are unchanged. Lives are local to Stage 3, not a new
campaign-wide currency.

Both small dark holes are traced separately from the unchanged background.
They are subtracted from support queries and actual physics support polygons;
nearby ground stays solid. Missing bridge planks and river edges remain gaps.
Walking into a hole or through the broken bridge commits the fall rather than
allowing Billy to walk onto the far rim for a free landing. Jump first (K);
the short existing ledge-grace window still accepts a just-late jump. Jumping
over a hole or the bridge preserves all lives.

Billy sinks/fades at the opening, with expanding earth-colored ripples at holes
and blue ripples/spray at the river. One reusable effect is driven by the
physics height crossing, not by the respawn location or a repeating timer.

Shared blocker handling now reads crate/wall elevations from each layout,
rather than assuming every map uses Stage 2's heights. Diagonal movement also
slides along higher platform faces instead of cancelling both axes. Stage 1
boundaries, Stage 2 crates/walls, Stage 3 cliffs and Stage 4 narrow walkways
remain solid where pictured; no artwork or real gaps were covered up.

Validation: `python3 tools/run_smoke_tests.py` includes dedicated stage-picker,
fall/ripple, and all-stage blocker suites. `python3 tools/build_web.py` boots
the picker and all four stages from the actual exported PCK.
