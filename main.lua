-- 터렛 디펜스 게임 main.lua
-- 모바일 터치 대응

-- 게임 상태 전역 변수 (모듈 로딩 전 정의)
Game = {
    money = 500,
    baseHealth = 100,
    wave = 1,
    enemies = {},
    turrets = {},
    paths = {},
    effects = {},
    particles = {},
    shopPage = 1,
    selectedTurret = nil, -- 선택된 터렛 객체
    buildMode = { active = false, typeIdx = nil }, -- 빌드 모드 상태
    state = "PLAYING",
    width = 800,
    height = 600,
    cameraX = 0,
    cameraY = 0,
    cameraScale = 1,
    isDragging = false,
    dragStartX = 0,
    dragStartY = 0,
    dragCameraStartX = 0,
    dragCameraStartY = 0,
    hasDragged = false,
    initialPinchDist = nil,
    initialPinchScale = nil
}

local turretClasses = require("turret_types")
local Map = require("map")
local Enemy = require("enemy")
local UI = require("ui")

function love.load()
    love.window.setMode(Game.width, Game.height, {resizable=true, vsync=true})
    love.window.setTitle("터렛 디펜스 모바일")
    
    -- 웹 호환성이 더 좋은 랜덤 시드 설정
    math.randomseed(love.timer.getTime() * 1000)
    
    -- 가벼운 한글 폰트(nanum.ttf) 사용
    local fontOk, font = pcall(love.graphics.newFont, "nanum.ttf", 16)
    if fontOk then
        love.graphics.setFont(font)
    else
        love.graphics.setFont(love.graphics.newFont(14))
    end
    
    -- 맵 초기화 (기본 슬롯 및 경로 생성)
    Map.init()
    
    -- UI 초기화
    UI.init()
end

-- [디버깅 도구] 웹 호환 에러 핸들러
function love.errorhandler(msg)
    local trace = debug.traceback("", 2) or ""
    local full_error = "Error: " .. tostring(msg) .. "\n\n" .. tostring(trace)
    print(full_error) -- 브라우저 콘솔에 출력
    
    return function()
        if not love.event or not love.graphics then return 1 end
        love.event.pump()
        for e in love.event.poll() do
            if e == "quit" then return 1 end
        end
        
        love.graphics.clear(0.15, 0.05, 0.05)
        love.graphics.setColor(1, 0.3, 0.3)
        love.graphics.printf(full_error, 10, 10, love.graphics.getWidth() - 20)
        love.graphics.present()
    end
end

-- 게임 상태 초기화 함수 (웹에서는 quit/restart가 안 되므로)
local function resetGame()
    Game.money = 500
    Game.baseHealth = 100
    Game.wave = 1
    Game.enemies = {}
    Game.turrets = {}
    Game.effects = {}
    Game.particles = {}
    Game.shopPage = 1
    Game.selectedTurret = nil
    Game.buildMode = { active = false, typeIdx = nil }
    Game.state = "PLAYING"
    Game.cameraX = 0
    Game.cameraY = 0
    Game.cameraScale = 1
    Game.isDragging = false
    Game.hasDragged = false
    Game.initialPinchDist = nil
    Map.init()
end

function love.update(dt)
    if Game.state == "PLAYING" then
        -- 적 업데이트
        for i = #Game.enemies, 1, -1 do
            local e = Game.enemies[i]
            e:update(dt)
            if e.dead then
                table.remove(Game.enemies, i)
                Game.money = Game.money + e.reward
            elseif e.escaped then
                table.remove(Game.enemies, i)
                Game.baseHealth = Game.baseHealth - e.damage
                if Game.baseHealth <= 0 then
                    Game.state = "GAMEOVER"
                end
            end
        end
        
        -- 파티클 업데이트
        for i = #Game.particles, 1, -1 do
            local p = Game.particles[i]
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.life = p.life - dt
            if p.life <= 0 then table.remove(Game.particles, i) end
        end
        
        -- 터렛 업데이트 (공격 로직)
        for _, t in ipairs(Game.turrets) do
            t:update(dt, Game.enemies)
        end
        
        -- 웨이브 관리 (간단한 예시)
        if #Game.enemies == 0 then
            -- 새 웨이브 시작 로직
            Enemy.spawnWave(Game.wave)
            Game.wave = Game.wave + 1
        end
    end
end

function love.draw()
    -- 카메라 변환 적용
    love.graphics.push()
    love.graphics.scale(Game.cameraScale, Game.cameraScale)
    love.graphics.translate(-Game.cameraX, -Game.cameraY)

    -- 배경
    love.graphics.clear(0.1, 0.1, 0.1)
    
    -- 맵 (슬롯 및 지형)
    Map.draw()
    
    -- 터렛
    for _, t in ipairs(Game.turrets) do
        t:draw()
    end
    
    -- 적
    for _, e in ipairs(Game.enemies) do
        e:draw()
    end
    
    -- 파티클 그리기
    for _, p in ipairs(Game.particles) do
        love.graphics.setColor(p.r, p.g, p.b, p.life)
        love.graphics.circle("fill", p.x, p.y, p.size)
    end
    
    love.graphics.pop()
    
    -- UI (상단 정보, 하단 메뉴 등)
    UI.clearButtons() -- 매 프레임 버튼 목록 초기화 (draw에서 새로 생성)
    UI.draw()
    
    if Game.state == "GAMEOVER" then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, Game.width, Game.height)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("GAME OVER\nPress to restart", 0, Game.height/2 - 20, Game.width, "center")
    end
end

function love.mousepressed(x, y, button, istouch)
    if Game.state == "GAMEOVER" then
        resetGame()
        return
    end

    -- 1. UI 터미널(버튼) 클릭 확인 (스크린 좌표 사용)
    if UI.touch(x, y) then
        return
    end
    
    -- 핀치 투 줌인지 확인
    local touches = love.touch.getTouches()
    if #touches >= 2 then
        Game.isDragging = false
        Game.hasDragged = false
        return
    end
    
    -- 빈 공간이면 드래그 시작 설정
    Game.isDragging = true
    Game.dragStartX = x
    Game.dragStartY = y
    Game.dragCameraStartX = Game.cameraX
    Game.dragCameraStartY = Game.cameraY
    Game.hasDragged = false
end

function love.mousemoved(x, y, dx, dy, istouch)
    -- 멀티터치 핀치 투 줌 로직
    local touches = love.touch.getTouches()
    if #touches >= 2 then
        local id1, id2 = touches[1], touches[2]
        local x1, y1 = love.touch.getPosition(id1)
        local x2, y2 = love.touch.getPosition(id2)
        local dist = math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
        
        if not Game.initialPinchDist then
            Game.initialPinchDist = dist
            Game.initialPinchScale = Game.cameraScale
        elseif dist > 0 then
            local scaleRatio = dist / Game.initialPinchDist
            local newScale = Game.initialPinchScale * scaleRatio
            Game.cameraScale = math.max(0.5, math.min(2.5, newScale))
        end
        return
    else
        Game.initialPinchDist = nil
    end

    if Game.isDragging then
        -- 마우스 이동 시 드래그 동작인지 클릭 오차인지 판별
        local dist = math.sqrt((x - Game.dragStartX)^2 + (y - Game.dragStartY)^2)
        if dist > 10 then
            Game.hasDragged = true
        end
        
        -- 카메라 이동
        local dWX = (x - Game.dragStartX) / Game.cameraScale
        local dWY = (y - Game.dragStartY) / Game.cameraScale
        
        Game.cameraX = Game.dragCameraStartX - dWX
        Game.cameraY = Game.dragCameraStartY - dWY
    end
end

function love.wheelmoved(x, y)
    if y > 0 then
        Game.cameraScale = math.min(2.5, Game.cameraScale + 0.1)
    elseif y < 0 then
        Game.cameraScale = math.max(0.5, Game.cameraScale - 0.1)
    end
end

function love.mousereleased(x, y, button, istouch)
    if Game.initialPinchDist then
        Game.initialPinchDist = nil
        return
    end

    if Game.isDragging then
        Game.isDragging = false
        if Game.hasDragged then
            return -- 드래그를 한 경우 아래의 클릭, 건설, 선택 무시
        end
    end
    
    if Game.state == "GAMEOVER" then return end
    
    -- UI 버튼은 놓을때가 아닌 누를 때 인식되게끔 위에 있지만 만약을 위해 블락
    if y > Game.height - 180 or y < 40 then
        return
    end
    
    -- 월드 좌표로 변환 (역산)
    local worldX = (x / Game.cameraScale) + Game.cameraX
    local worldY = (y / Game.cameraScale) + Game.cameraY

    -- 2. 빌드 모드일 때 배치 확인
    if Game.buildMode.active then
        local canPlace, msg = Map.isValidPlacement(worldX, worldY)
        if canPlace then
            local typeIdx = Game.buildMode.typeIdx
            local cost = turretClasses.types[typeIdx].cost
            if Game.money >= cost then
                Game.money = Game.money - cost
                local newT = turretClasses.Turret.new(typeIdx, worldX, worldY)
                table.insert(Game.turrets, newT)
            end
        end
        return
    end

    -- 3. 기존 터렛 선택 확인
    Game.selectedTurret = nil
    for _, t in ipairs(Game.turrets) do
        local d = math.sqrt((worldX - t.x)^2 + (worldY - t.y)^2)
        if d < 30 then
            Game.selectedTurret = t
            break
        end
    end
end

-- 윈도우 리사이즈 대응 (모바일 화면비 유지)
function love.resize(w, h)
    -- 화면 스케일 계산 등 필요 시 추가
end
