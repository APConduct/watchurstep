---@diagnostic disable: duplicate-set-field
local W, H = 120, 80
local CELL = 8

local grid = {}
local next_grid = {}
local paused = false
local timer = 0
local STEP = 0.1
local MIN_STEP = 0.01
local MAX_STEP = 1.0
local gen = 0




local function make_grid()
    local g = {}
    for y = 1, H do
        g[y] = {}
        for x = 1, W do
            g[y][x] = 0
        end
    end
    return g
end

local function clear_grid(g)
    for y = 1, H do
        for x = 1, W do
            g[y][x] = 0
        end
    end
end

local function get(g, x, y)
    x = ((x - 1) % W) + 1
    y = ((y - 1) % H) + 1
    return g[y][x]
end

local function count_neighbors(g, x, y)
    local n = 0
    for dy = -1, 1 do
        for dx = -1, 1 do
            if not (dx == 0 and dy == 0) then
                n = n + get(g, x + dx, y + dy)
            end
        end
    end
    return n
end

local function px_to_cell(mx, my)
    local cx = math.floor(mx / CELL) + 1
    local cy = math.floor(my / CELL) + 1
    cx = math.max(1, math.min(W, cx))
    cy = math.max(1, math.min(H, cy))
    return cx, cy
end

local function load_rle(g, rle, ox, oy)
    local body = rle:match("!?[bo$0-9]+!?") or rle
    local x, y = ox, oy
    local count_str = ""

    for ch in body:gmatch(".") do
        if ch:match("%d") then
            count_str = count_str .. ch
        else
            local count = tonumber(count_str) or 1
            count_str = ""

            if ch == "b" then
                x = x + count
            elseif ch == "o" then
                for i = 0, count - 1 do
                    local gx = x + i
                    local gy = y
                    if gx >= 1 and gx <= W and gy >= 1 and gy <= H then
                        g[gy][gx] = 1
                    end
                end
                x = x + count
            elseif ch == "$" then
                y = y + count
                x = ox
            elseif ch == "!" then
                break
            end
        end
    end
end

local PATTERNS = {
    -- name, rle, width_hint, height_hint
    { name = "Glider",      rle = "bob$2bo$3o!" },
    { name = "R-pentomino", rle = "2bo$b2o$bo!" },
    { name = "Acorn",       rle = "bo5b$3bo3b$2o2b3o!" },
    {
        name = "Gosper Glider Gun",
        rle =
        "24bo$22bobo$12b2o6b2o12b2o$11bo3bo4b2o12b2o$2o8bo5bo3b2o$2o8bo3bob2o4bobo$18bo5bobo$11bo3bo6bo$12b2o$24bo$22bobo$24bo!"
    },
    {
        name = "Lightweight Spaceship",
        rle = "2b2o$o4bo$5bo$o3bo$b4o!"
    },
}

local selected_pattern = 1



---@diagnostic disable-next-line: duplicate-set-field
function love.load()
    love.window.setMode(W * CELL, H * CELL + 40)
    love.window.setTitle("Game of Life")
    love.graphics.setBackgroundColor(0.05, 0.05, 0.08)

    grid = make_grid()
    next_grid = make_grid()

    for y = 1, H do
        for x = 1, W do
            grid[y][x] = love.math.random(0, 1)
        end
    end
end

local painting = false
local paint_val = 1

function love.update(dt)
    if painting and love.mouse.isDown(1, 2) then
        local mx, my = love.mouse.getPosition()
        if my < H * CELL then
            local cx, cy = px_to_cell(mx, my)
            local btn = love.mouse.isDown(1) and 1 or 0

            grid[cy][cx] = paint_val
        end
    end

    if paused then
        return
    end

    timer = timer + dt
    if timer < STEP then
        return
    end
    timer = 0
    gen = gen + 1

    for y = 1, H do
        for x = 1, W do
            local n = count_neighbors(grid, x, y)
            local alive = grid[y][x] == 1
            if alive then
                next_grid[y][x] = (n == 2 or n == 3) and 1 or 0
            else
                next_grid[y][x] = (n == 3) and 1 or 0
            end
        end
    end
    grid, next_grid = next_grid, grid
end

function love.draw()
    love.graphics.setColor(0.2, 0.9, 0.4)
    for y = 1, H do
        for x = 1, W do
            if grid[y][x] == 1 then
                love.graphics.rectangle("fill", (x - 1) * CELL, (y - 1) * CELL, CELL - 1, CELL - 1)
            end
        end
    end

    local hy = H * CELL
    love.graphics.setColor(0.1, 0.1, 0.14)
    love.graphics.rectangle("fill", 0, hy, W * CELL, 40)

    love.graphics.setColor(0.6, 0.6, 0.6)
    local speed_pct = math.floor((1 - (STEP - MIN_STEP) / (MAX_STEP - MIN_STEP)) * 100)
    local status = paused and "[[PAUSED]]" or string.format("gen %d", gen)
    local pat_name = PATTERNS[selected_pattern].name

    love.graphics.print(string.format(
        "SPACE=pause  R=random  C=clear  Speed:[←→] %d%%  Pattern:[↑↓] %s  F=stamp  LMB=draw  RMB=erase", speed_pct,
        pat_name), 6, hy + 4)
    love.graphics.setColor(0.2, 0.9, 0.4)
    love.graphics.print(status, W * CELL - 100, hy + 4)
end

---@diagnostic disable-next-line: duplicate-set-field
function love.mousepressed(mx, my, btn)
    if my >= H * CELL then
        return
    end

    local cx, cy = px_to_cell(mx, my)
    if btn == 1 then
        paint_val = (grid[cy][cx] == 0) and 1 or 0
        grid[cy][cx] = paint_val
        painting = true
    elseif btn == 2 then
        paint_val = 0
        grid[cy][cx] = 0
        painting = true
    end
end

function love.mousereleased(mx, my, btn)
    if btn == 1 or btn == 2 then
        painting = false
    end
end

function love.keypressed(key)
    if key == "space" then
        paused = not paused
    elseif key == "r" then
        clear_grid(grid)
        for y = 1, H do
            for x = 1, W do
                grid[y][x] = love.math.random(0, 1)
            end
        end
        gen = 0
    elseif key == "c" then
        clear_grid(grid)
        gen = 0
    elseif key == "right" then
        STEP = math.max(MIN_STEP, STEP * 0.75)
    elseif key == "left" then
        STEP = math.min(MAX_STEP, STEP * 1.33)
    elseif key == "up" then
        selected_pattern = (selected_pattern % #PATTERNS) + 1
    elseif key == "down" then
        selected_pattern = ((selected_pattern - 2) % #PATTERNS) + 1
    elseif key == "f" then
        local p = PATTERNS[selected_pattern]
        local ox = math.floor(W / 2) - 10
        local oy = math.floor(W / 2) - 5
        load_rle(grid, p.rle, ox, oy)
    end
end
