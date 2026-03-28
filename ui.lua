-- ui.lua
local UI = {}

local turretTypes = require("turret_types").types
local Map = require("map")

function UI.init()
end

function UI.draw()
    -- 상단 정보 바
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, Game.width, 40)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(string.format("돈: %d  체력: %d  웨이브: %d", Game.money, Game.baseHealth, Game.wave-1), 10, 10, Game.width, "left")
    
    -- 상태에 따른 메뉴 표시
    if Game.buildMode.active then
        UI.drawBuildMenu()
    elseif Game.selectedTurret then
        UI.drawUpgradeMenu(Game.selectedTurret)
    else
        UI.drawShop()
    end
    
    -- 이펙트 처리
    for i = #Game.effects, 1, -1 do
        local f = Game.effects[i]
        love.graphics.setColor(1, 1, 0, f.life * 10)
        love.graphics.line(f.x1, f.y1, f.x2, f.y2)
        f.life = f.life - love.timer.getDelta()
        if f.life <= 0 then table.remove(Game.effects, i) end
    end
end

-- 설치 모드 전용 UI
function UI.drawBuildMenu()
    local mx, my = love.mouse.getPosition()
    local tIdx = Game.buildMode.typeIdx
    local config = turretTypes[tIdx]
    
    -- 1. 안내 문구
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 50, Game.width, 30)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("설치할 위치를 터치하세요 (길 위/다른 터렛 근처는 불가)", 0, 55, Game.width, "center")
    
    -- 2. 설치 취소 버튼 (큼직하게)
    UI.drawButton("설치 취소", Game.width - 150, 90, 130, 50, function()
        Game.buildMode.active = false
        Game.buildMode.typeIdx = nil
    end)
    
    -- 3. 고스트 터렛 (미리보기)
    local canPlace, msg = Map.isValidPlacement(mx, my)
    if canPlace then
        love.graphics.setColor(0, 1, 0, 0.4)
    else
        love.graphics.setColor(1, 0, 0, 0.4)
        if msg then love.graphics.print(msg, mx + 20, my - 20) end
    end
    love.graphics.circle("fill", mx, my, 25)
    love.graphics.circle("line", mx, my, config.range) -- 사거리 미리보기
end

-- 기본 상점 UI (하단에 항상 표시)
function UI.drawShop()
    local panelH = 160
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, Game.height - panelH, Game.width, panelH)
    
    local itemsPerPage = 5
    local startIdx = (Game.shopPage - 1) * itemsPerPage + 1
    local endIdx = math.min(startIdx + itemsPerPage - 1, #turretTypes)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("터렛 상점을 눌러 설치하세요 ("..Game.shopPage.."/2)", 20, Game.height - 150, 400, "left")
    
    for i = startIdx, endIdx do
        local t = turretTypes[i]
        local relIdx = i - startIdx
        local x = 20 + relIdx * 155
        local y = Game.height - 125
        
        love.graphics.setColor(1, 1, 1, 0.1)
        love.graphics.rectangle("fill", x, y, 145, 115, 5, 5)
        
        UI.drawTurretPreview(t, x + 72, y + 35)
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(t.name, x, y + 60, 145, "center")
        
        UI.drawButton(t.cost.."G", x + 30, y + 80, 85, 30, function()
            if Game.money >= t.cost then
                Game.buildMode.active = true
                Game.buildMode.typeIdx = i
                Game.selectedTurret = nil
            end
        end, 14)
    end
    
    -- 페이지 버튼
    if Game.shopPage > 1 then UI.drawButton("<", 5, Game.height - 90, 15, 40, function() Game.shopPage = 1 end) end
    if endIdx < #turretTypes then UI.drawButton(">", Game.width - 20, Game.height - 90, 15, 40, function() Game.shopPage = 2 end) end
end

-- 터렛 업그레이드/판매 UI
function UI.drawUpgradeMenu(t)
    local panelH = 150
    love.graphics.setColor(0, 0, 0, 0.95)
    love.graphics.rectangle("fill", 0, Game.height - panelH, Game.width, panelH)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(t.name.." 관리", 20, Game.height - 140, 400, "left")
    
    -- 닫기 버튼
    UI.drawButton("X", Game.width - 50, Game.height - 140, 30, 30, function() Game.selectedTurret = nil end)
    
    local getCost = function(lvl) return math.floor(50 * (1.35 ^ (lvl - 1))) end
    
    local opts = {
        { label = "공격", lvl = t.levelAtk, inc = function() t.levelAtk = t.levelAtk + 1 end },
        { label = "사거리", lvl = t.levelRange, inc = function() t.levelRange = t.levelRange + 1 end },
        { label = "공속", lvl = t.levelSpeed, inc = function() t.levelSpeed = t.levelSpeed + 1 end }
    }
    
    for i, opt in ipairs(opts) do
        local cost = getCost(opt.lvl)
        UI.drawButton(opt.label.." Lv."..opt.lvl.."\n("..cost.."G)", 20 + (i-1)*130, Game.height - 90, 120, 60, function()
            if Game.money >= cost then
                Game.money = Game.money - cost
                opt.inc()
            end
        end)
    end
    
    UI.drawButton("판매 (반값)", Game.width - 120, Game.height - 90, 100, 60, function()
        for i, tt in ipairs(Game.turrets) do
            if tt == t then table.remove(Game.turrets, i); break end
        end
        Game.money = Game.money + 50
        Game.selectedTurret = nil
    end)
end

function UI.drawTurretPreview(config, x, y)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(0.8, 0.8)
    local headSize = 15
    if config.shape == "circle" then 
        love.graphics.setColor(0.5, 0.7, 1); love.graphics.rectangle("fill", 0, -4, 20, 8); love.graphics.circle("fill", 0, 0, headSize)
    elseif config.shape == "triangle" then 
        love.graphics.setColor(1, 0.4, 0.4); love.graphics.rectangle("fill", 0, -2, 25, 4); love.graphics.polygon("fill", -headSize, -headSize, headSize, 0, -headSize, headSize)
    elseif config.shape == "square" then
        love.graphics.setColor(0.6, 1, 0.6); love.graphics.rectangle("fill", 10, -6, 15, 4); love.graphics.rectangle("fill", 10, 2, 15, 4); love.graphics.rectangle("fill", -headSize, -headSize, headSize*2, headSize*2)
    elseif config.shape == "gold" then
        love.graphics.setColor(1, 0.9, 0); love.graphics.circle("fill", 0, 0, headSize, 8)
    else
        love.graphics.setColor(0.7, 0.7, 0.7); love.graphics.circle("fill", 0, 0, headSize, 6)
    end
    love.graphics.pop()
end

local buttons = {}
function UI.drawButton(text, x, y, w, h, onClick, fontSize)
    love.graphics.setColor(0.2, 0.4, 0.6)
    love.graphics.rectangle("fill", x, y, w, h, 8, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", x, y, w, h, 8, 8)
    
    local font = love.graphics.getFont()
    local _, lines = font:getWrap(text, w)
    local textHeight = #lines * font:getHeight()
    love.graphics.printf(text, x, y + (h - textHeight) / 2, w, "center")
    
    table.insert(buttons, {x=x, y=y, w=w, h=h, click=onClick})
end

function UI.touch(x, y)
    for _, b in ipairs(buttons) do
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            b.click()
            return true
        end
    end
    return false
end

function UI.clearButtons()
    buttons = {}
end

return UI
