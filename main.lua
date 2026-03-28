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
    height = 600
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
    
    -- 웹 환경에서 13MB 폰트는 메모리 초과를 일으키므로 기본 폰트 사용
    -- TODO: 경량 한글 폰트로 교체 예정
    local font = love.graphics.newFont(14)
    love.graphics.setFont(font)
    
    -- 맵 초기화 (기본 슬롯 및 경로 생성)
    Map.init()
    
    -- UI 초기화
    UI.init()
end

-- [디버깅 도구] 에러 발생 시 화면에 빨간 글씨로 에러 내용을 표시합니다.
function love.errorhandler(msg)
    if luvit then return end
    if not love.window or not love.graphics or not love.event then return end

    if not love.graphics.isCreated() or not love.window.isOpen() then
        local success, status = pcall(love.window.setMode, 800, 600)
        if not success or not status then return end
    end

    love.graphics.setCanvas()
    love.graphics.setOrigin()
    love.graphics.clear(0.1, 0.1, 0.1)

    local trace = debug.traceback()
    local full_error = "Error: " .. tostring(msg) .. "\n\n" .. trace

    return function()
        love.event.pump()
        for e, a, b, c in love.event.poll() do
            if e == "quit" then return 1 end
        end

        love.graphics.clear(0.1, 0.1, 0.1)
        love.graphics.setColor(1, 0, 0)
        love.graphics.printf(full_error, 20, 20, love.graphics.getWidth() - 40)
        love.graphics.present()
    end
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
        love.event.quit("restart")
        return
    end

    -- 1. UI 터미널(버튼) 클릭 확인
    if UI.touch(x, y) then
        return
    end
    
    -- 2. 빌드 모드일 때 배치 확인
    if Game.buildMode.active then
        local canPlace, msg = Map.isValidPlacement(x, y)
        if canPlace then
            local typeIdx = Game.buildMode.typeIdx
            local cost = turretClasses.types[typeIdx].cost
            if Game.money >= cost then
                Game.money = Game.money - cost
                local newT = turretClasses.Turret.new(typeIdx, x, y)
                table.insert(Game.turrets, newT)
                -- 연속 설치를 위해 빌드 모드 유지 (원하면 끌 수 있음)
            end
        else
            -- 설치 불가 메시지 이펙트 (선택사항)
        end
        return
    end

    -- 3. 기존 터렛 선택 확인
    Game.selectedTurret = nil
    for _, t in ipairs(Game.turrets) do
        local d = math.sqrt((x - t.x)^2 + (y - t.y)^2)
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
