---@module "Grid"

---@class Grid
local Grid = {
    w = 0,
    h = 0,
    mine_count = 0,
    seed = 0,
    initialized = false,
    cells_revealed = 0,
    flags_placed = 0,
    mines_hit = 0,
    state = "playing",
    hooks = {},
    cells = {},
    _hooks = {},
    ---@enum CellState
    STATE = {
        HIDDEN = "hidden",
        REVEALED = "revealed",
        FLAGGED = "flagged",
        SCORED = "scouted",
        ALREADY_DONE = "already_done",
        PLAYING = "playing",
        GAME_OVER = "game_over",
        OUT_OF_BOUNDS = "out_of_bounds",
        MINE = "mine",
        MINE_CANCELLED = "mine_cancelled"
    },
    ---@enum GridEvent
    EVENT = {
        CELL_REVEALED = "cell_revealed",
        CELL_FLAGGED = "cell_flagged",
        CELL_UNFLAGGED = "cell_unflagged",
        CHORD_REVEALED = "chord_revealed",
        MINE_CANCELLED = "mine_cancelled",
        GAME_WON = "game_won",
        FLAG_REMOVED = "flag_removed",
        MINE_HIT_CONFIRMED = "mine_hit_confirmed",
    },
}
Grid.__index = Grid



---
---@param w number
---@param h number
---@param mine_count number
---@param seed number
---@return Grid
function Grid.new(w, h, mine_count, seed)
    assert(
        w > 0 and h > 0,
        "Grid dimentions must be positive"
    )

    assert(
        mine_count < w * h,
        "Too  many mines for grid size"
    )

    assert(
        mine_count > 0, "must  have at least one mine"
    )

    local self = setmetatable({}, Grid)

    self.w = w
    self.h = h
    self.mine_count = mine_count
    self.seed = seed or os.time()
    self.initialized = false

    self.cells_revealed = 0
    self.flags_placed = 0
    self.mines_hit = 0
    self.state = ({
        PLAYING = "playing",
        WON = "won",
        LOST = "lost"
    }).PLAYING

    self.hooks = {}
    self._hooks = {}

    self.cells = {}
    for y = 1, h do
        self.cells[y] = {}
        for x = 1, w do
            self.cells[y][x] = {
                x = x,
                y = y,
                mine = false,
                number = 0,
                state = Grid.STATE.HIDDEN,
            }
        end
    end

    return self
end

--- Registers a listener for a given event
---@param event string
---@param fn function
---@return nil
function Grid:on(event, fn)
    self._hooks[event] = self._hooks[event] or {}
    table.insert(self._hooks[event], fn)
end

--- Emits an event to all registered listeners
---@param event string
---@param data table
---@return {}
function Grid:emit(event, data)
    data = data or {}
    for _, fn in ipairs(self._hooks[event] or {}) do
        fn(data)
    end
    return data
end

--- Places mines on the grid, avoiding the safe zone
---@private
---@param safe_x number
---@param safe_y number
function Grid:_place_mines(safe_x, safe_y)
    math.randomseed(self.seed)

    local placed = 0
    local attempts = 0
    local max_attempts = self.w * self.h * 10

    while placed < self.mine_count do
        attempts = attempts + 1
        assert(
            attempts < max_attempts,
            "Mine placement exceeded attempt limit"
        )

        local x = math.random(1, self.w)
        local y = math.random(1, self.h)
        local cell = self.cells[y][x]

        if not cell.mine
            and not self:_is_safe_zone(
                x,
                y,
                safe_x,
                safe_y)
        then
            cell.mine = true
            placed = placed + 1
        end
    end

    self:_compute_numbers()
    self.initialized = true
end

---@private
---@param x number
---@param y number
---@param cx number
---@param cy number
---@return boolean
function Grid:_is_safe_zone(x, y, cx, cy)
    return math.abs(x - cx) <= 1
        and math.abs(y - cy) <= 1
end

---@private
--- Computes the number of mines in each cell's neighborhood
---@return nil
function Grid:_compute_numbers()
    for y = 1, self.h do
        for x = 1, self.w do
            local cell = self.cells[y][x]
            if not cell.mine then
                local count = 0
                for _, n in ipairs(self:get_neighbors(x, y)) do
                    if n.mine then count = count + 1 end
                end
                cell.number = count
            end
        end
    end
end

--- Returns the neighbors of a given cell
---@param x number
---@param y number
---@return table
function Grid:get_neighbors(x, y)
    local result = {}
    for dy = -1, 1 do
        for dx = -1, 1 do
            if not (dx == 0 and dy == 0) then
                local nx, ny = x + dx, y + dy
                if nx >= 1 and nx <= self.w and ny >= 1 and ny <= self.h then
                    table.insert(result, self.cells[ny][nx])
                end
            end
        end
    end
    return result
end

--- returns the cell at the given coordinates, or nil if out of bounds
---@param x number
---@param y number
---@return nil
function Grid:get_cell(x, y)
    if x < 1 or x > self.w or y < 1 or y > self.h then return nil end
    return self.cells[y][x]
end

--- checks if the given coordinates are within the grid bounds
---@param x number
---@param y number
---@return boolean
function Grid:inbounds(x, y)
    return x >= 1 and x <= self.w and y >= 1 and y <= self.h
end

--- Reveals the cell at the given coordinates.
--- Initializes mines on the first reveal, triggers flood fill for empty cells,
--- and checks for a win condition after revealing.
---@param x number
---@param y number
---@return CellState
function Grid:reveal(x, y)
    if self.state ~= "playing" then
        return self.STATE.GAME_OVER
    end

    local cell = self:get_cell(x, y)
    if not cell then
        return self.STATE.OUT_OF_BOUNDS
    end
    if cell.state == Grid.STATE.REVEALED then
        return self.STATE.ALREADY_DONE
    end
    if cell.state == Grid.STATE.FLAGGED then
        return self.STATE.FLAGGED
    end

    if not self.initialized then
        self:_place_mines(x, y)
    end

    if cell.mine then
        return self:_hit_mine(cell)
    end

    self:_reveal_cell(cell)
    self:_flood_fill(x, y)
    self:_check_win()

    return self.STATE.REVEALED
end

--- Reveals all hidden, unflagged neighbors of a revealed numbered cell,
--- provided the number of adjacent flags matches the cell's mine count.
---@param x number
---@param y number
function Grid:chord_reveal(x, y)
    if self.state ~= Grid.STATE.PLAYING then return end

    local cell = self:get_cell(x, y)
    if not cell or cell.state ~= Grid.STATE.REVEALED or cell.number == 0 then return end

    local flag_count = 0
    for _, n in ipairs(self:get_neighbors(x, y)) do
        if n.state == Grid.STATE.FLAGGED then
            flag_count = flag_count + 1
        end
    end

    if flag_count == cell.number then
        for _, n in ipairs(self:get_neighbors(x, y)) do
            if n.state == Grid.STATE.HIDDEN then
                self:reveal(n.x, n.y)
            end
        end
    end
end

--- Marks a cell as revealed, increments the revealed counter,
--- and emits a CELL_REVEALED event.
---@param cell table
function Grid:_reveal_cell(cell)
    cell.state = Grid.STATE.REVEALED
    self.cells_revealed = self.cells_revealed + 1
    self:emit(Grid.EVENT.CELL_REVEALED, { cell = cell, grid = self })
end

--- Flood fill algorithm to reveal cells around a given cell.
---@param x number
---@param y number
function Grid:_flood_fill(x, y)
    local cell = self.cells[y][x]
    if cell.number ~= 0 then return end

    for _, neighbor in ipairs(self:get_neighbors(x, y)) do
        if neighbor.state == Grid.STATE.HIDDEN and not neighbor.mine then
            self:_reveal_cell(neighbor)
            self:_flood_fill(neighbor.x, neighbor.y)
        end
    end
end

--- Reveals a mine and ends the game.
---@param cell table
---@return CellState
function Grid:_hit_mine(cell)
    self.mines_hit = self.mines_hit + 1

    local data = self:emit("mine_hit", { cell = cell, grid = self, damage = 1, cancel = false })

    if not data.cancel then
        cell.state = Grid.STATE.REVEALED
        self:emit("mine_hit_confirmed", { cell = cell, damage = data.damage, grid = self })
        self:set_lost()
        return "mine"
    else
        self:emit("mine_hit_cancelled", { cell = cell, grid = self })
        cell.state = Grid.STATE.REVEALED
        return "mine_cancelled"
    end
end

--- Toggles a flag on a cell.
---@param x number
---@param y number
function Grid:toggle_flag(x, y)
    if self.state ~= "playing" then return "game_over" end

    local cell = self:get_cell(x, y)
    if not cell then return "out_of_bounds" end
    if cell.state == Grid.STATE.REVEALED then return "already_revealed" end

    if cell.state == Grid.STATE.FLAGGED then
        cell.state = Grid.STATE.HIDDEN
        self.flags_placed = self.flags_placed - 1
        self:emit("flag_removed", { cell = cell, grid = self })
        return "unflagged"
    else
        cell.state = Grid.STATE.FLAGGED
        self.flags_placed = self.flags_placed + 1

        local is_correct = cell.mine
        self:emit("flag_placed", {
            cell    = cell,
            grid    = self,
            correct = is_correct,
        })
        return "flagged"
    end
end

--- Returns the number of mines remaining to be flagged.
---@return number
function Grid:mines_remaining()
    return self.mine_count - self.flags_placed
end

---@private
function Grid:_check_win()
    -- Win condition: every non-mine cell is revealed
    local safe_total = self.w * self.h - self.mine_count
    if self.cells_revealed >= safe_total then
        self.state = "won"
        self:emit("grid_won", { grid = self })
    end
end

--- Transitions the grid to the lost state, reveals all mines,
--- and emits a grid_lost event.
---@private
function Grid:set_lost()
    if self.state == "playing" then
        self.state = "lost"
        self:_reveal_all_mines()
        self:emit("grid_lost", { grid = self })
    end
end

--- Transitions the grid to the won state and emits a grid_won event.
---@private
function Grid:set_won()
    if self.state == "playing" then
        self.state = "won"
        self:emit("grid_won", { grid = self })
    end
end

---@private
function Grid:_reveal_all_mines()
    for y = 1, self.h do
        for x = 1, self.w do
            local cell = self.cells[y][x]
            if cell.mine and cell.state ~= Grid.STATE.FLAGGED then
                cell.state = Grid.STATE.REVEALED
            end
        end
    end
end

--- Returns all unrevealed, non-flagged, non-mine cells (for safe-reveal effects)
---@return table
function Grid:getSafeCells()
    local result = {}
    for y = 1, self.h do
        for x = 1, self.w do
            local c = self.cells[y][x]
            if not c.mine and c.state == Grid.STATE.HIDDEN then
                table.insert(result, c)
            end
        end
    end
    return result
end

--- Returns all hidden mine cells (for mine-reveal or shift effects)
---@private
---@return table
function Grid:_get_mine_cells()
    local result = {}
    for y = 1, self.h do
        for x = 1, self.w do
            local c = self.cells[y][x]
            if c.mine and c.state == Grid.STATE.HIDDEN then
                table.insert(result, c)
            end
        end
    end
    return result
end

--- Reveals `count` random safe cells (used by Biscuit, Metal Detector hints, etc.)
---@param count number
---@return table
function Grid:reveal_random_safe(count)
    local safe = self:getSafeCells()
    local revealed = {}
    for i = 1, math.min(count, #safe) do
        local idx = math.random(1, #safe)
        local cell = table.remove(safe, idx)
        self:_reveal_cell(cell)
        self:_flood_fill(cell.x, cell.y)
        table.insert(revealed, cell)
    end
    self:_check_win()
    return revealed
end

--- Returns a count of correctly placed flags
---@return number
function Grid:correct_flag_count()
    local count = 0
    for y = 1, self.h do
        for x = 1, self.w do
            local c = self.cells[y][x]
            if c.mine and c.state == Grid.STATE.FLAGGED then
                count = count + 1
            end
        end
    end
    return count
end

------------------------------------------------------
-- Serialization (for save/run persistence)

--- Serializes the grid state to a plain table suitable for saving.
---@return table
function Grid:serialize()
    local data = {
        w = self.w,
        h = self.h,
        mine_count = self.mine_count,
        seed = self.seed,
        initialized = self.initialized,
        cells_revealed = self.cells_revealed,
        flags_placed = self.flags_placed,
        mines_hit = self.mines_hit,
        state = self.state,
        cells = {}
    }
    for y = 1, self.h do
        data.cells[y] = {}
        for x = 1, self.w do
            local c = self.cells[y][x]
            data.cells[y][x] = {
                mine   = c.mine,
                number = c.number,
                state  = c.state,
            }
        end
    end
    return data
end

--- Deserializes a plain table back into a Grid instance.
---@param data table
---@return Grid
function Grid.deserialize(data)
    local self          = setmetatable({}, Grid)
    self.w              = data.w
    self.h              = data.h
    self.mine_count     = data.mine_count
    self.seed           = data.seed
    self.initialized    = data.initialized
    self.cells_revealed = data.cells_revealed
    self.flags_placed   = data.flags_placed
    self.mines_hit      = data.mines_hit
    self.state          = data.state
    self._hooks         = {}
    self.cells          = {}

    for y = 1, self.h do
        self.cells[y] = {}
        for x = 1, self.w do
            local d = data.cells[y][x]
            self.cells[y][x] = {
                x      = x,
                y      = y,
                mine   = d.mine,
                number = d.number,
                state  = d.state,
            }
        end
    end

    return self
end

return Grid
