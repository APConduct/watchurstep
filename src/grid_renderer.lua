local GridRenderer = {}
GridRenderer.__index = GridRenderer

-- Palette — earthy/industrial to match the miner theme
local COLORS = {
    -- cell backgrounds
    hidden          = { 0.25, 0.22, 0.18, 1 }, -- dark soil
    revealed        = { 0.82, 0.76, 0.65, 1 }, -- sandstone
    flagged         = { 0.25, 0.22, 0.18, 1 }, -- same as hidden
    mine_hit        = { 0.70, 0.15, 0.10, 1 }, -- dark red
    scouted         = { 0.40, 0.36, 0.28, 1 }, -- brushed soil

    -- borders
    border_hidden   = { 0.18, 0.15, 0.12, 1 },
    border_revealed = { 0.68, 0.62, 0.52, 1 },

    -- numbers (classic minesweeper palette, slightly desaturated)
    numbers         = {
        [1] = { 0.20, 0.40, 0.80, 1 }, -- blue
        [2] = { 0.10, 0.55, 0.25, 1 }, -- green
        [3] = { 0.80, 0.20, 0.15, 1 }, -- red
        [4] = { 0.10, 0.10, 0.55, 1 }, -- dark blue
        [5] = { 0.60, 0.10, 0.10, 1 }, -- dark red
        [6] = { 0.10, 0.50, 0.50, 1 }, -- teal
        [7] = { 0.10, 0.10, 0.10, 1 }, -- near black
        [8] = { 0.45, 0.45, 0.45, 1 }, -- grey
    },

    flag            = { 0.90, 0.35, 0.10, 1 },    -- burnt orange
    mine            = { 0.12, 0.10, 0.08, 1 },    -- near black
    highlight       = { 1.00, 1.00, 0.60, 0.25 }, -- soft yellow hover
    scouted_safe    = { 0.30, 0.80, 0.35, 0.35 }, -- faint green safe hint
    scouted_warn    = { 0.90, 0.40, 0.10, 0.30 }, -- faint orange danger hint
}

function GridRenderer.new(grid, cell_size, offset_x, offset_y)
    local self     = setmetatable({}, GridRenderer)
    self.grid      = grid
    self.cell_size = cell_size or 32
    self.ox        = offset_x or 0
    self.oy        = offset_y or 0
    self.hovered   = nil -- {x, y} grid coords of hovered cell, or nil
    self.font      = love.graphics.newFont(math.floor(cell_size * 0.45))
    return self
end

-- Coordinate conversion

-- Screen px -> grid cell (1-indexed). Returns nil if out of bounds.
function GridRenderer:screenToGrid(sx, sy)
    local gx = math.floor((sx - self.ox) / self.cell_size) + 1
    local gy = math.floor((sy - self.oy) / self.cell_size) + 1
    if self.grid:inBounds(gx, gy) then
        return gx, gy
    end
    return nil, nil
end

-- Grid cell -> top-left screen pixel
function GridRenderer:gridToScreen(gx, gy)
    return self.ox + (gx - 1) * self.cell_size,
        self.oy + (gy - 1) * self.cell_size
end

------------------------------------------------------
-- Mouse tracking
------——--————————————————----------

function GridRenderer:mousemoved(sx, sy)
    local gx, gy = self:screenToGrid(sx, sy)
    if gx then
        self.hovered = { x = gx, y = gy }
    else
        self.hovered = nil
    end
end

function GridRenderer:mouseleave()
    self.hovered = nil
end

------------------------------------------------------
-- Main draw
------------—--———————————----------------

function GridRenderer:draw()
    local cs = self.cell_size
    local grid = self.grid

    for y = 1, grid.h do
        for x = 1, grid.w do
            local cell = grid.cells[y][x]
            local sx, sy = self:gridToScreen(x, y)
            self:_drawCell(cell, sx, sy, cs)
        end
    end

    -- — Hover highlight drawn on top
    if self.hovered then
        local cell = grid:getCell(self.hovered.x, self.hovered.y)
        if cell and cell.state ~= "revealed" then
            local sx, sy = self:gridToScreen(self.hovered.x, self.hovered.y)
            love.graphics.setColor(COLORS.highlight)
            love.graphics.rectangle("fill", sx + 1, sy + 1, cs - 2, cs - 2)
        end
    end

    love.graphics.setColor(1, 1, 1, 1) -- reset
end

function GridRenderer:_drawCell(cell, sx, sy, cs)
    local state = cell.state

    -- Background
    if state == "revealed" and cell.mine then
        love.graphics.setColor(COLORS.mine_hit)
    elseif state == "revealed" then
        love.graphics.setColor(COLORS.revealed)
    elseif state == "scouted" then
        love.graphics.setColor(COLORS.scouted)
    else
        love.graphics.setColor(COLORS.hidden)
    end
    love.graphics.rectangle("fill", sx, sy, cs, cs)

    -- Border
    if state == "revealed" then
        love.graphics.setColor(COLORS.border_revealed)
    else
        love.graphics.setColor(COLORS.border_hidden)
    end
    love.graphics.rectangle("line", sx, sy, cs, cs)
    -- Content
    if state == "revealed" then
        if cell.mine then
            self:_drawMine(sx, sy, cs)
        elseif cell.number > 0 then
            self:_drawNumber(cell.number, sx, sy, cs)
        end
    elseif state == "flagged" then
        self:_drawFlag(sx, sy, cs)
    elseif state == "scouted" then
        self:_drawScoutedHint(cell, sx, sy, cs)
    end
end

function GridRenderer:_drawNumber(n, sx, sy, cs)
    local color = COLORS.numbers[n] or { 0.1, 0.1, 0.1, 1 }
    love.graphics.setColor(color)
    love.graphics.setFont(self.font)
    love.graphics.printf(
        tostring(n),
        sx, sy + (cs - self.font:getHeight()) / 2,
        cs, "center"
    )
end

function GridRenderer:_drawMine(sx, sy, cs)
    love.graphics.setColor(COLORS.mine)
    local pad = cs * 0.22
    local cx  = sx + cs / 2
    local cy  = sy + cs / 2
    local r   = cs / 2 - pad

    -- Body
    love.graphics.circle("fill", cx, cy, r)
    -- Spikes (8-directional)
    love.graphics.setColor(COLORS.mine)
    local spike = r * 0.45
    for i = 0, 7 do
        local angle = i * math.pi / 4
        local x1 = cx + math.cos(angle) * r * 0.6
        local y1 = cy + math.sin(angle) * r * 0.6
        local x2 = cx + math.cos(angle) * (r + spike)
        local y2 = cy + math.sin(angle) * (r + spike)
        love.graphics.setLineWidth(2)
        love.graphics.line(x1, y1, x2, y2)
    end

    -- Shine
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.circle("fill", cx - r * 0.25, cy - r * 0.25, r * 0.25)
end

function GridRenderer:_drawFlag(sx, sy, cs)
    local pad    = cs * 0.2
    local bx     = sx + pad
    local by     = sy + cs * 0.65
    local pole_x = sx + cs * 0.38

    -- Pole
    love.graphics.setColor(COLORS.mine)
    love.graphics.setLineWidth(2)
    love.graphics.line(pole_x, by, pole_x, sy + pad)

    -- Flag
    love.graphics.setColor(COLORS.flag)
    love.graphics.polygon("fill",
        pole_x, sy + pad,
        pole_x + cs * 0.35, sy + pad + cs * 0.18,
        pole_x, sy + pad + cs * 0.32
    )

    -- Base
    love.graphics.setColor(COLORS.mine)
    love.graphics.setLineWidth(2)
    love.graphics.line(bx, by, bx + cs - pad * 2, by)
end

-- Scouted hint: used by The Brush tool — shows safe/danger without full reveal
function GridRenderer:_drawScoutedHint(cell, sx, sy, cs)
    if cell.safe ~= nil then
        if cell.safe then
            love.graphics.setColor(COLORS.scouted_safe)
        else
            love.graphics.setColor(COLORS.scouted_warn)
        end
        love.graphics.rectangle("fill", sx + 2, sy + 2, cs - 4, cs - 4, 3, 3)
    end
end

------------------------------------------------------
-- HUD helpers
----------—--—————————————--------------

-- Returns total pixel dimensions of the grid
function GridRenderer:getDimensions()
    return self.grid.w * self.cell_size, self.grid.h * self.cell_size
end

return GridRenderer
