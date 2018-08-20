local Class = require'libs.hump.class'
local Entity = require'entity'
local HitBox = require'components.hitbox'

Player = Class{
    --[[
    corners = {
        -6, 5, -22, -0.5,
    }; -- why does this need a semi colon --]]
    __includes = Entity
    -- todo fixme calibrate
}

-- local PLAYER_WIDTH, PLAYER_HEIGHT = 16, 22 LEFT = -1
LEFT = -1
RIGHT = 1
PS_RUN, PS_CLIMB, PS_CARRY, PS_THROW, PS_DEAD = 0,1,2,3,4 -- Player states 
PLAYER_WIDTH = 32
PLAYER_HEIGHT = 64
-- give the player a bit of edge room when being attacked
-- but still want to collide normally with the map
HITBOX_WIDTH = PLAYER_WIDTH * .75 
HITBOX_HEIGHT = PLAYER_HEIGHT

local GD_UP, GD_HORIZONTAL, GD_DOWN = 0,2,4 -- Gun directions

local NORMAL_GRAVITY=80
local BRAKE_SPEED = 350
local MAX_SPEED = 160
local MAX_JUMP = 100
local JUMP_TIME_MAX = 0.5

local lg = love.graphics
Player.__index = Player

function Player:init(x,y,level)

    -- local img = love.graphics.newImage('assets/character_block.png')
    local img = love.graphics.newImage('assets/blue_tough_guy.png')
    local w = PLAYER_WIDTH
    local h = PLAYER_HEIGHT
    self.boundingQuad = lg.newQuad(12, 0, 53, 64, img:getDimensions())
    Entity.init(self,x,y,w,h)
    self.name = "Player"
    self.img = img
    self.x = x + PLAYER_WIDTH
    self.y = y
    self.w = w -- img:getWidth()
    self.h = h -- img:getHeight()
    self.xspeed = 0
    self.yspeed = 0
    self.xacc = 35
    self.friction = 10
    self.gravity = NORMAL_GRAVITY
    self.hasReachedMax = false
    self.jump_time = JUMP_TIME_MAX

    self.onGround = false
    self.time = 0
    self.lastDir = RIGHT
    self.dir = RIGHT
    self.jumpAcc = 25

    self.jumping = false;
    self.state = PS_RUN
    self.actionName = "";
    self.hitBox = HitBox;
    self.hitBox:init(
        self,
        self.x,
        self.y,
        HITBOX_HEIGHT,  
        HITBOX_WIDTH
    )
    print("player hitbox = "..tostring(self.hitBox))
    self.spawnX = self.x
    self.spawnY = self.y - 10
    self.doRespawn = false
    --[[
    self.gundir = GD_HORIZONTAL
    self.shooting = false
    self.bulletStreamLength = 0
    self.streamCollided = false
    self.bulletQuad = love.graphics.newQuad(
        0, 0, 10, 10, 16, 17
    )
    self.timesJumped = 0
    --]]

    return self
end

function Player:updateRunning(dt)
    local changedDir = false
    local both = keystate.right and keystate.left

    local walkingRight = (not both and keystate.right) or
                         (both and self.lastDir == RIGHT)
    local walkingLeft = (not both and keystate.left) or
                        (both and self.lastDir == LEFT)
    self.xspeed = self.xspeed * (1 - math.min(dt * self.friction, 1))
    if walkingRight and self.xspeed > -MAX_SPEED then
        self.xspeed = self.xspeed + self.xacc*dt
        if self.dir == LEFT then
            self.dir = RIGHT
            changedDir = true
        end
    elseif walkingLeft and self.xspeed < MAX_SPEED then
        self.xspeed = self.xspeed - self.xacc*dt
        if self.dir == RIGHT then
            self.dir = LEFT
            changedDir = true
        end 
    end

    self.xspeed = cap(self.xspeed, -MAX_SPEED, MAX_SPEED);
    goalX = self.x + self.xspeed

    self.yspeed = self.yspeed * (1 - math.min(dt * self.friction, 1))
    if not self.onGround then
        --print("not on the ground")
        if self.jumping then
           -- print("jumping so should be jumping")
            self:updateJumping(dt)
        end
    end
    
    self.yspeed = self.yspeed + self.gravity *dt

    goalY = self.y + self.yspeed
    self.x, self.y, collisions = map.world:move(self, goalX, goalY)

    for i, coll in ipairs(collisions) do
        if coll.touch.y > goalY then
            -- print("first if check");
            player.hasReachedMax = true
            self.onGround = false
        elseif coll.normal.y < 0 then
            self.jumping = false
            player.hasReachedMax = false
            self.onGround = true
            self.yspeed = 0
            self.jump_time = JUMP_TIME_MAX
        end
        for key, value in pairs(coll.other) do
            print("key = "..tostring(key).." = "..tostring(value))
        end
    end
end

function Player:updateJumping(dt)
    -- print("top of Player:updateJumping")
    if self.jump_time > 0
    and love.keyboard.isDown(config_keys.jump) then
        self.jump_time = self.jump_time - dt
        self.yspeed = self.yspeed - self.jumpAcc * (dt / JUMP_TIME_MAX) local targetJumpSpeed = self.jumpAcc*dt;
        -- print("jump speed is gonna  = "..targetJumpSpeed.."\n")
        self.yspeed = self.yspeed - targetJumpSpeed
    end
end

--[[
you can do that! try setting a minimum and maximum jump speed.
if Input.is_action_just_pressed("ui_up"):
                    velocity.y = JUMP_SPEED
if velocity.y < MIN_JUMP_SPEED and Input.is_action_just_released("ui_up"):
                     velocity.y = MIN_JUMP_SPEED
so your upwards velocity
if it's greater than the minimum jump speed, and you release your jump button
it makes a smaller jump
but if you hold it, it'll give you the full jump height
--]]
function Player:jump()
    self.jumping = true
    self.onGround = false
    self.yspeed = self.yspeed - self.jumpAcc
end

function Player:update(dt)
    --print("before doing action = "..tostring(self.doingAction))
    self.doingAction = false
    --print("after doing action = "..tostring(self.doingAction))
    --[[
    if not love.keyboard.isDown(config_keys.action) then
        self.doingAction = false
    end
    --]]
    -- reset shooting
    -- self.shooting = false
    -- first update states
    if self.state == PS_RUN then
        self:updateRunning(dt)
    end

    self.hitBox:update(dt)
end

function Player:draw()
    lg.draw(self.img, self.boundingQuad, math.floor(self.x), math.floor(self.y), 0, 1, 1, 4)
end

-- kind of a weak warp function
function Player:warp(x,y)
    print("hitting warp")
    print("x = "..tostring(x).." y = "..tostring(y))
    self.x = x
    self.y = y
    self.xspeed = 0
    self.yspeed = 0
end

function Player:respawn()
    print("top of respawn()")
    self.doRespawn = true
    self:warp(
        self.spawnX,
        self.spawnY
    )
end

function Player:doAction()
    self.doingAction = true
end

function Player:action(actionName)
    -- debugging 
    self.actionName = actionName

    if actionName == "jump" and not self.jumping then
        --print("initiating jump")
        self:jump()
    elseif actionName == "left" or actionName == "right" then
        if actionName == "left" then
            self.lastDir = LEFT
        else
            self.lastDir = RIGHT
        end 
    elseif actionName == "respawn" then
        self:respawn()
    elseif actionName == "action" then
        print("self hitting action")
        self:doAction()
    end
end
