local Grid = require("src.grid")
local GridRenderer = require("src.grid_renderer")

local CELL_SIZE = 32
local GRID_W = 16
local GRID_H = 16
local MINE_COUNT = 40
local MARGIN = 60

local grid = nil
local renderer = nil
local front_hud = nil
local front_msg = nil

local message = { text = "", timer = 0, color = { 1, 1, 1, 1 } }

local function flash(text, color, duration)
    message.text = text
    message.color = color or { 1, 1, 1, 1 }
    message.timer = duration or 2.0
end

local function new_game()
    local seed = love.math.random(1, 999999)
    grid = Grid.new(GRID_W, GRID_H, MINE_COUNT, seed)
    renderer = GridRenderer.new(grid, CELL_SIZE, 0, MARGIN)

    grid:on("mine_hit_confirmed", function(data)
        flash("Hit a mine! (-" .. data.message .. "HP)", { 0.9, 0.2, 0.1, 1 }, 1.5)
    end)

    grid:on("mine_hit_cancelled", function(data)
        flash("Close call! (cancelled)", { 0.9, 0.8, 0.1, 1 }, 1.5)
    end)

    grid:on("grid_won", function()
        flash("Field cleared!", { 0.3, 0.9, 0.4, 1 }, 99)
    end)

    grid:on("grid_lost", function()
        flash("Game over. R to restart.", { 0.9, 0.2, 0.1, 1 }, 99)
    end)

    grid:on("flag_placed", function(data)
        -- placeholder: dogs like Pepper will hook here later
    end)
end

local checknil = function(item, msg)
    if not item then
        error(msg)
    end
end

function love.load()
    love.window.setTitle("Minesweeper Core")
    love.window.setMode(
        GRID_W * CELL_SIZE,
        GRID_H * CELL_SIZE + MARGIN,
        { resizable = false, vsync = true }
    )

    ---@diagnostic disable-next-line: lowercase-global
    font_hud = love.graphics.newFont(14)
    ---@diagnostic disable-next-line: lowercase-global
    font_msg = love.graphics.newFont(18)

    new_game()
end

function love.update(dt)
    if message.timer > 0 then
        message.timer = message.timer - dt
    end
end

function love.draw()
    -- Background
    love.graphics.setColor(0.15, 0.13, 0.10, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    -- HUD bar
    love.graphics.setColor(0.20, 0.18, 0.14, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), MARGIN)

    -- HUD text
    love.graphics.setFont(font_hud)
    love.graphics.setColor(0.85, 0.78, 0.65, 1)

    if not grid then
        error("grid is nil")
    end
    local mines_left = grid:mines_remaining()
    local status     = grid.state == "won" and "CLEARED"
        or grid.state == "lost" and "DEAD"
        or "ACTIVE"

    love.graphics.print(
        string.format(
            "Mines: %d / %d   Revealed: %d   Flags: %d   [%s]   Seed: %d",
            mines_left, MINE_COUNT,
            grid.cells_revealed,
            grid.flags_placed,
            status,
            grid.seed
        ),
        8, 8
    )

    love.graphics.setColor(0.60, 0.55, 0.45, 1)
    love.graphics.print(
        "Left: reveal   Right: flag   Middle: chord   R: restart",
        8, 28
    )

    -- Flash message
    if message.timer > 0 then
        love.graphics.setFont(font_msg)
        love.graphics.setColor(message.color)
        love.graphics.printf(message.text, 0, MARGIN - 22, love.graphics.getWidth(), "center")
    end

    if not renderer then
        error("renderer is nil")
    end
    -- Grid
    renderer:draw()

    love.graphics.setColor(1, 1, 1, 1)
end

function love.mousemoved(x, y, dx, dy)
    if not renderer then error("renderer is nil") end
    renderer:mousemoved(x, y)
end

function love.mousepressed(x, y, button)
    if not grid then error("grid is nil") end
    if not renderer then error("renderer is nil") end

    if grid.state ~= "playing" then return end

    local gx, gy = renderer:screen_to_grid(x, y)
    if not gx then return end

    if button == 1 then
        grid:reveal(gx, gy)
    elseif button == 2 then
        grid:toggle_flag(gx, gy)
    elseif button == 3 then
        -- Middle mouse: chord reveal
        grid:chord_reveal(gx, gy)
    end
end

function love.keypressed(key)
    if key == "r" then
        new_game()
        flash("New game.", { 0.8, 0.75, 0.6, 1 }, 1.0)
    end

    if key == "escape" then
        love.event.quit()
    end
end
