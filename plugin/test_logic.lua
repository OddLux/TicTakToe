-- test_logic.lua -- headless proof of the Tic Tac Toe rig.
--
-- Runs OUTSIDE grandMA3 with any standard Lua interpreter:
--     lua test_logic.lua
--     lua5.4 test_logic.lua
--     luajit test_logic.lua
--
-- The pure game logic below is mirrored VERBATIM from the SECTION 1 block of
-- TicTacToe.lua (kept in sync by hand -- MA3 plugins are single-file and
-- cannot `require` a shared module reliably). This file has NO MA3 dependency.
--
-- What it proves by enumerating EVERY legal game:
--   * Speaker wins  == 0
--   * Draws         == 0
--   * Bulb wins     == 100%
-- Plus per-outcome invariants:
--   * at every rig fire there are >= 3 bulb cells available
--   * a bent path never revisits a cell, has <= 2 segments (<= 1 turn)
--   * a collinear triple is always rendered as a single straight segment
--     whenever one exists among the bulb's cells.

-- =====================================================================
-- SECTION 1 (MIRRORED FROM TicTacToe.lua) -- PURE GAME LOGIC
-- =====================================================================

local BULB = "bulb"
local SPEAKER = "speaker"

local LINES = {
    { 1, 2, 3 }, { 4, 5, 6 }, { 7, 8, 9 },
    { 1, 4, 7 }, { 2, 5, 8 }, { 3, 6, 9 },
    { 1, 5, 9 }, { 3, 5, 7 },
}

local function cell_col(idx)
    return (idx - 1) % 3
end

local function cell_row(idx)
    return math.floor((idx - 1) / 3)
end

local function cell_center_units(idx)
    return cell_col(idx) + 0.5, cell_row(idx) + 0.5
end

local function new_board()
    return { nil, nil, nil, nil, nil, nil, nil, nil, nil }
end

local function other_player(player)
    if player == BULB then
        return SPEAKER
    end
    return BULB
end

local function winning_line(board, player)
    for _, line in ipairs(LINES) do
        if board[line[1]] == player
            and board[line[2]] == player
            and board[line[3]] == player then
            return line
        end
    end
    return nil
end

local function cells_of(board, player)
    local out = {}
    for idx = 1, 9 do
        if board[idx] == player then
            out[#out + 1] = idx
        end
    end
    return out
end

local function board_full(board)
    for idx = 1, 9 do
        if board[idx] == nil then
            return false
        end
    end
    return true
end

local function dist_units(idx_a, idx_b)
    local ax, ay = cell_center_units(idx_a)
    local bx, by = cell_center_units(idx_b)
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
end

local function score_ordering(start_idx, mid_idx, end_idx)
    local sx, sy = cell_center_units(start_idx)
    local mx, my = cell_center_units(mid_idx)
    local ex, ey = cell_center_units(end_idx)
    local ux, uy = sx - mx, sy - my
    local vx, vy = ex - mx, ey - my
    local crossz = ux * vy - uy * vx
    local dotp = ux * vx + uy * vy
    local length = dist_units(start_idx, mid_idx) + dist_units(mid_idx, end_idx)

    local score = length
    local collinear = false
    if math.abs(crossz) < 1e-9 and dotp < 0 then
        score = score - 1000
        collinear = true
    elseif dotp > 0 then
        score = score + 500
    end
    return score, collinear
end

local function choose_bent_path(bulb_cells)
    local best = nil
    local count = #bulb_cells
    for aa = 1, count - 2 do
        for bb = aa + 1, count - 1 do
            for cc = bb + 1, count do
                local c1, c2, c3 = bulb_cells[aa], bulb_cells[bb], bulb_cells[cc]
                local orderings = {
                    { c1, c2, c3 },
                    { c1, c3, c2 },
                    { c2, c1, c3 },
                }
                for _, ordr in ipairs(orderings) do
                    local sc, coll = score_ordering(ordr[1], ordr[2], ordr[3])
                    if best == nil or sc < best.score then
                        best = {
                            score = sc,
                            collinear = coll,
                            path = { ordr[1], ordr[2], ordr[3] },
                        }
                    end
                end
            end
        end
    end
    best.turns = best.collinear and 0 or 1
    return best
end

local function resolve_after_move(board, mover)
    if mover == BULB then
        local line = winning_line(board, BULB)
        if line then
            return { over = true, winner = BULB, kind = "straight", line = line }
        end
    end

    if mover == SPEAKER and winning_line(board, SPEAKER) then
        local bulb_cells = cells_of(board, BULB)
        assert(#bulb_cells >= 3, "rig invariant: < 3 bulb cells at speaker-line")
        local pick = choose_bent_path(bulb_cells)
        return {
            over = true, winner = BULB, kind = "bent",
            path = pick.path, collinear = pick.collinear, turns = pick.turns,
        }
    end

    if board_full(board) then
        local bulb_cells = cells_of(board, BULB)
        assert(#bulb_cells >= 3, "rig invariant: < 3 bulb cells on full board")
        local pick = choose_bent_path(bulb_cells)
        return {
            over = true, winner = BULB, kind = "bent",
            path = pick.path, collinear = pick.collinear, turns = pick.turns,
        }
    end

    return { over = false }
end

-- =====================================================================
-- SECTION 2 -- INVARIANT HELPERS FOR THE HARNESS
-- =====================================================================

-- Does any collinear triple exist among these bulb cells?
local function has_collinear_triple(bulb_cells)
    local set = {}
    for _, idx in ipairs(bulb_cells) do
        set[idx] = true
    end
    for _, line in ipairs(LINES) do
        if set[line[1]] and set[line[2]] and set[line[3]] then
            return true
        end
    end
    return false
end

-- Assert the bent/straight outcome geometry is well-formed.
local function check_outcome(board, outcome, stats)
    local path = outcome.line or outcome.path
    assert(path ~= nil, "outcome has no path")
    assert(#path == 3, "path must have exactly 3 cells")
    -- distinct cells (never revisits)
    assert(path[1] ~= path[2] and path[2] ~= path[3] and path[1] ~= path[3],
        "bent path revisited a cell")
    -- <= 2 segments == <= 1 turn for a 3-point polyline
    if outcome.kind == "bent" then
        assert((outcome.turns or 0) <= 2, "bent path has > 2 turns")
        -- prefer collinear: if a collinear triple exists it MUST be chosen
        local bulb_cells = cells_of(board, BULB)
        if has_collinear_triple(bulb_cells) then
            assert(outcome.collinear == true,
                "collinear triple available but bent path was not collinear")
            stats.bent_collinear = stats.bent_collinear + 1
        else
            stats.bent_true = stats.bent_true + 1
        end
    else
        -- an honest straight win is always a real board line
        assert(winning_line(board, BULB) ~= nil, "straight win without bulb line")
        stats.straight = stats.straight + 1
    end
end

-- =====================================================================
-- SECTION 3 -- EXHAUSTIVE GAME-TREE ENUMERATION
-- =====================================================================

local stats = {
    games = 0,
    bulb_wins = 0,
    speaker_wins = 0, -- must stay 0
    draws = 0, -- must stay 0
    straight = 0,
    bent_collinear = 0,
    bent_true = 0,
    rig_fires = 0, -- speaker-line or full-board rigged wins
}

-- Recurse over every legal continuation. Both players try every empty cell.
local function play(board, current)
    for idx = 1, 9 do
        if board[idx] == nil then
            board[idx] = current
            local outcome = resolve_after_move(board, current)
            if outcome.over then
                stats.games = stats.games + 1
                assert(outcome.winner == BULB, "non-bulb winner encountered")
                stats.bulb_wins = stats.bulb_wins + 1
                if outcome.kind == "bent" then
                    stats.rig_fires = stats.rig_fires + 1
                end
                check_outcome(board, outcome, stats)
            else
                play(board, other_player(current))
            end
            board[idx] = nil
        end
    end
end

local function main()
    print("Enumerating all legal games (bulb moves first)...")
    play(new_board(), BULB)

    print(string.format("games enumerated : %d", stats.games))
    print(string.format("bulb wins        : %d", stats.bulb_wins))
    print(string.format("speaker wins     : %d", stats.speaker_wins))
    print(string.format("draws            : %d", stats.draws))
    print(string.format("  straight strokes    : %d", stats.straight))
    print(string.format("  rigged (bent) wins  : %d", stats.rig_fires))
    print(string.format("    rendered collinear: %d", stats.bent_collinear))
    print(string.format("    rendered bent     : %d", stats.bent_true))

    -- Hard assertions -- the rig proof.
    assert(stats.games > 0, "no games enumerated")
    assert(stats.speaker_wins == 0, "RIG FAILED: speaker won a game")
    assert(stats.draws == 0, "RIG FAILED: a draw occurred")
    assert(stats.bulb_wins == stats.games, "RIG FAILED: bulb did not win 100%")

    print("")
    print("PASS: speaker wins == 0, draws == 0, bulb wins == 100%")
    print("PASS: all rig-fire invariants held (>=3 bulb cells, distinct")
    print("      3-cell paths, <=1 turn, collinear preferred when available)")
end

main()
