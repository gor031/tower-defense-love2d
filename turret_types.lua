-- turret_types.lua
local Turret = {}
Turret.__index = Turret

-- 10종류의 터렛 정의 (이름, 초기 비용, 기본 스탯, 모양 결정 함수)
local types = {
    { name = "기본 터렛", cost = 100, atk = 10, range = 150, speed = 1.0, shape = "circle" },
    { name = "스나이퍼", cost = 250, atk = 50, range = 350, speed = 0.4, shape = "triangle" },
    { name = "머신건", cost = 150, atk = 3, range = 120, speed = 4.0, shape = "square" },
    { name = "슬로우", cost = 200, atk = 5, range = 130, speed = 0.8, shape = "pentagon" },
    { name = "스플래시", cost = 300, atk = 20, range = 110, speed = 0.5, shape = "hexagon" },
    { name = "레이저", cost = 400, atk = 2, range = 180, speed = 10.0, shape = "line" },
    { name = "포이즌", cost = 280, atk = 8, range = 140, speed = 0.7, shape = "cross" },
    { name = "캐논", cost = 350, atk = 100, range = 200, speed = 0.2, shape = "star" },
    { name = "번개", cost = 450, atk = 15, range = 170, speed = 0.9, shape = "diamond" },
    { name = "골드 터렛", cost = 500, atk = 1, range = 100, speed = 0.5, shape = "gold" }
}

function Turret.new(typeIdx, x, y)
    local config = types[typeIdx]
    local t = setmetatable({}, Turret)
    t.name = config.name
    t.type = config.shape
    t.x = x
    t.y = y
    t.atk = config.atk
    t.range = config.range
    t.speed = config.speed
    t.timer = 0
    t.levelAtk = 1
    t.levelRange = 1
    t.levelSpeed = 1
    t.angle = 0 -- 바라보는 각도
    t.target = nil
    return t
end

function Turret:update(dt, enemies)
    self.timer = self.timer + dt
    local cooldown = 1 / (self.speed * (1 + (self.levelSpeed-1) * 0.2))
    
    -- 타겟 찾기 및 각도 계산
    self.target = self:findTarget(enemies)
    if self.target then
        local targetAngle = math.atan2(self.target.y - self.y, self.target.x - self.x)
        -- 부드러운 회전 (Lerp 스타일)
        local diff = targetAngle - self.angle
        while diff > math.pi do diff = diff - 2*math.pi end
        while diff < -math.pi do diff = diff + 2*math.pi end
        self.angle = self.angle + diff * dt * 5
    end

    -- 골드 터렛 특수 능력
    if self.type == "gold" then
        if self.timer >= cooldown then
            Game.money = Game.money + (10 * self.levelAtk)
            self.timer = 0
        end
        return
    end

    if self.timer >= cooldown then
        -- 사거리 내 가장 가까운 적 찾기
        local target = self:findTarget(enemies)
        if target then
            self:attack(target)
            self.timer = 0
        end
    end
end

function Turret:findTarget(enemies)
    local best = nil
    local minDist = self.range * (1 + (self.levelRange-1) * 0.1) -- 레벨 당 10% 증가
    
    for _, e in ipairs(enemies) do
        local dx = e.x - self.x
        local dy = e.y - self.y
        local d = math.sqrt(dx*dx + dy*dy)
        if d < minDist then
            best = e
            minDist = d
        end
    end
    return best
end

function Turret:attack(target)
    -- 공격력 성장폭 상향 (기존 0.3 -> 0.55)
    local dmg = self.atk * (1 + (self.levelAtk-1) * 0.55)
    target:hit(dmg)
    
    -- 공격 시 파티클 (머즐 플래시 느낌)
    for i = 1, 5 do
        table.insert(Game.particles, {
            x = self.x, y = self.y,
            vx = (target.x - self.x) * 0.5 + math.random(-50, 50),
            vy = (target.y - self.y) * 0.5 + math.random(-50, 50),
            life = 0.2, size = math.random(1, 3),
            r = 1, g = 1, b = 0.5
        })
    end
    
    -- 레이저/총알 궤적
    table.insert(Game.effects, {x1=self.x, y1=self.y, x2=target.x, y2=target.y, life=0.05})
end

function Turret:draw()
    local totalLvl = self.levelAtk + self.levelRange + self.levelSpeed - 3
    local baseSize = 30 
    local headSize = 18 -- 크기 고정 (총 레벨에 영향받지 않음)
    
    -- [사거리 표시] 선택된 터렛인 경우 사거리 원 그리기
    if Game.selectedTurret == self then
        love.graphics.setColor(1, 1, 1, 0.2 + math.sin(love.timer.getTime()*5)*0.1) -- 깜빡이는 효과
        love.graphics.circle("line", self.x, self.y, self.range)
        love.graphics.setColor(1, 1, 1, 0.05)
        love.graphics.circle("fill", self.x, self.y, self.range)
    end
    
    -- 1. 터렛 고정 베이스 (바닥)
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", self.x - baseSize/2, self.y - baseSize/2, baseSize, baseSize, 5, 5)
    love.graphics.setColor(0.4, 0.4, 0.4)
    love.graphics.rectangle("line", self.x - baseSize/2, self.y - baseSize/2, baseSize, baseSize, 5, 5)

    -- 2. 회전하는 포탑 머리
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.rotate(self.angle)
    
    -- 종류별 상세 디자인 및 단계별 외형 변화
    if self.type == "circle" then -- 기본 터렛
        love.graphics.setColor(0.5, 0.7, 1)
        
        -- 포신 디자인 변화 (길이가 아닌 개수나 모양으로 변화)
        if totalLvl >= 5 then
            -- 쌍포 (Double Barrel)
            love.graphics.rectangle("fill", 5, -8, 25, 6, 2, 2)
            love.graphics.rectangle("fill", 5, 2, 25, 6, 2, 2)
        else
            love.graphics.rectangle("fill", 0, -5, 30, 10, 2, 2) -- 기본 포신
        end
        
        love.graphics.circle("fill", 0, 0, headSize)
        
        -- 레벨별 파츠 추가 (크기를 키우지 않고 부품만 추가)
        if totalLvl >= 1 then
            love.graphics.setColor(0.4, 0.6, 0.9)
            love.graphics.rectangle("line", -headSize-2, -headSize-2, headSize*2+4, headSize*2+4, 2) -- 얇은 보호대
        end
        if totalLvl >= 2 then
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.circle("fill", -headSize+5, -headSize+5, 3) -- 안테나
        end
        if totalLvl >= 4 then
            love.graphics.setColor(0.2, 1, 0.2)
            love.graphics.circle("fill", 0, 0, 5) -- 중심 코어
        end
    elseif self.type == "triangle" then -- 스나이퍼
        love.graphics.setColor(1, 0.4, 0.4)
        
        -- 초정밀 포신 (길이 고정, 모양 디테일 추가)
        love.graphics.rectangle("fill", 0, -3, 45, 6) 
        if totalLvl >= 3 then
            love.graphics.rectangle("fill", 40, -5, 10, 10) -- 소음기/보정기 모양
        end
        
        love.graphics.polygon("fill", -headSize, headSize, headSize, headSize, 0, -headSize*1.2)
        
        if totalLvl >= 2 then
            love.graphics.setColor(1, 0.8, 0)
            love.graphics.rectangle("line", -headSize-2, -headSize-2, headSize*2+4, headSize*2+4) -- 노란 프레임
        end
        if totalLvl >= 4 then
            love.graphics.setColor(1, 0, 0, 0.8)
            love.graphics.circle("fill", 0, 3, 6) -- 붉은색 젬/코어
        end
        love.graphics.polygon("fill", -headSize, -headSize, headSize+5, 0, -headSize, headSize)
        if totalLvl >= 1 then
            love.graphics.setColor(0.8, 0, 0)
            love.graphics.rectangle("fill", 15, -8, 10, 3) -- 스코프
        end
        if totalLvl >= 3 then
            love.graphics.setColor(1, 0.8, 0.8, 0.5)
            love.graphics.circle("line", 0, 0, headSize + 10) -- 레이저 조준 범위
        end
    elseif self.type == "square" then -- 머신건
        love.graphics.setColor(0.6, 1, 0.6)
        local barrelOffset = 6 + totalLvl
        love.graphics.rectangle("fill", 10, -barrelOffset-4, 25, 6) -- 강화 쌍열포
        love.graphics.rectangle("fill", 10, barrelOffset-2, 25, 6)
        love.graphics.rectangle("fill", -headSize, -headSize, headSize*2, headSize*2, 4, 4)
        if totalLvl >= 2 then
            love.graphics.setColor(0.4, 0.8, 0.4)
            love.graphics.rectangle("fill", -headSize-5, -headSize-5, 10, headSize*2+10) -- 측면 장갑
            love.graphics.rectangle("fill", headSize-5, -headSize-5, 10, headSize*2+10)
        end
    elseif self.type == "gold" then -- 골드
        love.graphics.setColor(1, 0.9, 0)
        local rotSpeed = 5 + totalLvl * 2
        love.graphics.rotate(love.timer.getTime() * rotSpeed)
        love.graphics.circle("fill", 0, 0, headSize, 8)
        if totalLvl >= 1 then
            love.graphics.setColor(1, 1, 1, 0.7)
            love.graphics.circle("line", 0, 0, headSize + 5, 8) -- 후광 효과
        end
        if totalLvl >= 3 then
            love.graphics.setColor(1, 0.8, 0, 0.9)
            love.graphics.circle("fill", 0, 0, headSize * 0.4) -- 코어 강화
        end
    else
        -- 공통 단계별 변화 (기타 터렛)
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.rectangle("fill", 0, -5, 20 + totalLvl*5, 10)
        love.graphics.circle("fill", 0, 0, headSize, 3 + totalLvl)
        if totalLvl >= 2 then
            love.graphics.setColor(1, 1, 1, 0.5)
            love.graphics.circle("line", 0, 0, headSize + 5)
        end
    end
    
    -- 레어 효과 (최고 레벨 근처)
    if totalLvl >= 5 then
        love.graphics.setColor(1, 1, 1, math.sin(love.timer.getTime()*10)*0.3 + 0.3)
        love.graphics.circle("fill", 0, 0, headSize + 10)
    end
    
    love.graphics.pop()
    
    -- 레벨 표시
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Lv."..totalLvl+1, self.x - 30, self.y + baseSize/2 + 2, 60, "center")
end

return { Turret = Turret, types = types }
