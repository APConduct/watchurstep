-- conf.lua
function love.conf(t)
    t.title            = "Minesweeper Core"
    t.version          = "11.4"
    t.window.width     = 512
    t.window.height    = 572 -- 16*32 + 60 margin
    t.window.resizable = false
    t.window.vsync     = 1
    t.console          = false
end
