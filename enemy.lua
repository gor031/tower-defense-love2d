-- enemy.lua
local Enemy = {}
Enemy.__index = Enemy

-- 적 타입 정의
local TYPES = {
    normal = { color = {1, 0.1, 0.1}, size = 12, hpMul = 1.0, speedMul = 1.0, rewardMul = 1.0, damage = 1 },
    fast = { color = {1, 1, 0.2}, size = 9, hpMul = 0.5, speedMul = 1.6, rewardMul = 0.8, damage = 1 },
    tank = { color = {0.2, 0.6, 1}, size = 16, hpMul = 2.5, speedMul = 0.6, rewardMul = 1.8, damage = 1 },
    boss = { color = {0.8, 0, 1}, size = 25, hpMul = 8.0, speedMul = 0.4, rewardMul = 10.0, damage = 5 }
}

function Enemy.new(type, baseHp, baseSpeed, baseReward, path)
    local e = setmetatable({}, Enemy)
    local config = TYPES[type] or TYPES.normal
    
    e.type = type
    e.waypoints = path or Game.paths[1]
    e.x = e.waypoints[1].x
    e.y = e.waypoints[1].y
    e.targetIdx = 2
    
    e.hp = baseHp * config.hpMul
    e.maxHp = e.hp
    e.speed = baseSpeed * config.speedMul
    e.reward = math.floor(baseReward * config.rewardMul)
    e.damage = config.damage
    e.size = config.size
    e.color = config.color
    
    e.dead = false
    e.escaped = false
    return e
end

function Enemy:update(dt)
    local target = self.waypoints[self.targetIdx]
    if not target then return end
    
    local dx = target.x - self.x
    local dy = target.y - self.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    if dist < 5 then
        self.targetIdx = self.targetIdx + 1
        if self.targetIdx > #self.waypoints then
            self.escaped = true
        end
    else
        self.x = self.x + (dx/dist) * self.speed * dt
        self.y = self.y + (dy/dist) * self.speed * dt
    end
end

function Enemy:hit(dmg)
    self.hp = self.hp - dmg
    if self.hp <= 0 then
        self.dead = true
        local pCount = (self.type == "boss") and 40 or 15
        for i = 1, pCount do
            table.insert(Game.particles, {
                x = self.x, y = self.y,
                vx = math.random(-120, 120), vy = math.random(-120, 120),
                life = 0.6, size = math.random(2, 5),
                r = self.color[1], g = self.color[2], b = self.color[3]
            })
        end
    end
end

function Enemy:draw()
    -- 그림자
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.circle("fill", self.x, self.y + 5, self.size)
    
    -- 몸체
    love.graphics.setColor(self.color)
    love.graphics.circle("fill", self.x, self.y, self.size)
    
    -- 외곽선 (보스면 더 굵게)
    love.graphics.setColor(1, 1, 1)
    if self.type == "boss" then
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", self.x, self.y, self.size + 2)
        love.graphics.setLineWidth(1)
    else
        love.graphics.circle("line", self.x, self.y, self.size)
    end
    
    -- HP 바
    local barW = self.size * 2.5
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", self.x - barW/2, self.y - self.size - 10, barW, 6, 2, 2)
    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle("fill", self.x - barW/2, self.y - self.size - 10, barW * (self.hp/self.maxHp), 6, 2, 2)
end

function Enemy.spawnWave(wave)
    -- 하드코어 밸런스: 웨이브가 지날수록 체력과 숫자가 기하급수적으로 폭증
    local baseCount = 6 + math.floor(wave * 4.5)     -- 머릿수 증가폭 상향 (+3 -> +4.5)
    local hpFreq = 1.15 ^ (wave - 1)             -- 매 웨이브 15%씩 복리 체력 증가
    local baseHp = (40 + wave * 20) * hpFreq     -- 기본 체력 및 복리 효과 적용
    local baseSpeed = 60 + (wave * 5)           -- 이속도 꾸준히 상향
    local baseReward = math.floor(15 * (1.06 ^ (wave - 1)) + (wave * 2))

    -- 보스 웨이브 체크 (5웨이브 마다)
    if wave % 5 == 0 then
        local pathIdx = math.random(1, #Game.paths)
        local bossHp = baseHp * 8
        -- 보스는 별도로 생성
        local e = Enemy.new("boss", bossHp / TYPES.boss.hpMul, baseSpeed, baseReward, Game.paths[pathIdx])
        e.x = Game.paths[pathIdx][1].x - 100
        table.insert(Game.enemies, e)
        -- 보스 웨이브에도 일반 몹을 넉넉히 섞음 (70% 수준)
        baseCount = math.floor(baseCount * 0.7)
    end

    for i = 1, baseCount do
        local pathIdx = math.random(1, #Game.paths)
        local selectedPath = Game.paths[pathIdx]
        
        -- 타입 결정 (랜덤)
        local r = math.random()
        local type = "normal"
        if r < 0.2 then type = "fast"
        elseif r < 0.4 then type = "tank"
        end
        
        local e = Enemy.new(type, baseHp, baseSpeed, baseReward, selectedPath)
        e.x = selectedPath[1].x - (i * 60) 
        e.y = selectedPath[1].y
        table.insert(Game.enemies, e)
    end
end

return Enemy
