-- map.lua
local Map = {}

local PATH_WIDTH = 50
local TURRET_RADIUS = 25 -- 터렛 배치 시 충돌 반경

function Map.init()
    Game.slots = {} -- 이제 사용하지 않음 (이전 코드 호환성용 빈 테이블)
    Game.paths = {}
    Game.decorations = {}
    
    local startY = math.random(250, 350)
    local branchX = math.random(200, 300)
    
    local isSplit = math.random(1, 100) <= 75
    
    local common = {}
    table.insert(common, {x = -50, y = startY})
    table.insert(common, {x = 100, y = startY})
    table.insert(common, {x = branchX, y = startY})
    
    local function extendPath(basePath, initialDir)
        local path = {}
        for _, p in ipairs(basePath) do
            table.insert(path, {x = p.x, y = p.y})
        end
        
        local cX = path[#path].x
        local cY = path[#path].y
        local goingUp = (initialDir < 0)
        
        local jumpY = math.random(160, 200)
        if goingUp then cY = cY - jumpY else cY = cY + jumpY end
        cY = math.max(80, math.min(520, cY))
        table.insert(path, {x = cX, y = cY})
        
        cX = cX + math.random(250, 350)
        table.insert(path, {x = cX, y = cY})
        
        jumpY = math.random(160, 200)
        if goingUp then cY = cY + jumpY else cY = cY - jumpY end
        cY = math.max(80, math.min(520, cY))
        table.insert(path, {x = cX, y = cY})
        
        table.insert(path, {x = Game.width + 100, y = cY})
        return path
    end

    if isSplit then
        table.insert(Game.paths, extendPath(common, -1))
        table.insert(Game.paths, extendPath(common, 1))
        Game.branchIndex = #common
    else
        table.insert(Game.paths, extendPath(common, math.random() > 0.5 and 1 or -1))
        Game.branchIndex = #common
    end
    
    -- 장식 요소
    for i = 1, 40 do
        table.insert(Game.decorations, {
            x = math.random(0, Game.width), y = math.random(0, Game.height),
            size = math.random(2, 4),
            color = {0.1 + math.random()*0.05, 0.3 + math.random()*0.1, 0.1}
        })
    end
end

-- 점과 선분 사이의 거리 계산
function Map.distToSegment(px, py, x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    if dx == 0 and dy == 0 then return math.sqrt((px-x1)^2 + (py-y1)^2) end
    local t = ((px - x1) * dx + (py - y1) * dy) / (dx*dx + dy*dy)
    t = math.max(0, math.min(1, t))
    local closestX, closestY = x1 + t * dx, y1 + t * dy
    return math.sqrt((px - closestX)^2 + (py - closestY)^2)
end

-- 해당 위치에 터렛 설치 가능한지 확인
function Map.isValidPlacement(x, y)
    -- 1. 화면 밖인지 확인
    if x < 40 or x > Game.width - 40 or y < 40 or y > Game.height - 200 then
        return false, "화면 끝에는 지을 수 없습니다."
    end

    -- 2. 길 위에 있는지 확인
    for _, path in ipairs(Game.paths) do
        for i = 1, #path - 1 do
            local d = Map.distToSegment(x, y, path[i].x, path[i].y, path[i+1].x, path[i+1].y)
            if d < (PATH_WIDTH / 2 + 25) then -- 길 너비 + 여유공간
                return false, "길 위에는 지을 수 없습니다."
            end
        end
    end

    -- 3. 다른 터렛과 겹치는지 확인
    for _, t in ipairs(Game.turrets) do
        local d = math.sqrt((x - t.x)^2 + (y - t.y)^2)
        if d < 60 then
            return false, "다른 터렛과 너무 가깝습니다."
        end
    end

    return true
end

function Map.draw()
    love.graphics.setColor(0.1, 0.25, 0.1)
    love.graphics.rectangle("fill", 0, 0, Game.width, Game.height)
    
    for _, d in ipairs(Game.decorations) do
        love.graphics.setColor(d.color); love.graphics.circle("fill", d.x, d.y, d.size)
    end

    love.graphics.setLineJoin("miter")
    love.graphics.setLineStyle("smooth")
    
    if #Game.paths > 0 then
        local firstPath = Game.paths[1]
        local bIdx = Game.branchIndex
        local bPoint = firstPath[bIdx]
        
        local function safeUnpack(t) return (table.unpack or _G.unpack)(t) end
        
        -- 바닥층
        love.graphics.setLineWidth(50)
        love.graphics.setColor(0.4, 0.3, 0.2)
        local commonPart = {}
        for i=1, bIdx do table.insert(commonPart, firstPath[i].x); table.insert(commonPart, firstPath[i].y) end
        if #commonPart >= 4 then love.graphics.line(safeUnpack(commonPart)) end
        love.graphics.circle("fill", bPoint.x, bPoint.y, 25)
        for _, path in ipairs(Game.paths) do
            local div = {}
            for i=bIdx, #path do table.insert(div, path[i].x); table.insert(div, path[i].y) end
            if #div >= 4 then love.graphics.line(safeUnpack(div)) end
        end
        
        -- 위층
        love.graphics.setLineWidth(40)
        love.graphics.setColor(0.5, 0.4, 0.3)
        if #commonPart >= 4 then love.graphics.line(safeUnpack(commonPart)) end
        love.graphics.circle("fill", bPoint.x, bPoint.y, 20)
        for _, path in ipairs(Game.paths) do
            local div = {}
            for i=bIdx, #path do table.insert(div, path[i].x); table.insert(div, path[i].y) end
            if #div >= 4 then love.graphics.line(safeUnpack(div)) end
        end
    end
    
    love.graphics.setLineWidth(1)
end

return Map
