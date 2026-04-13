-- world.lua — Voxel grid, day/night, spatial queries (LOVR: pure data, no scene nodes)

local log = {write = function() end}
pcall(function() log = require("debuglog") end)

local W = {}
W.__index = W

function W.new(config, items)
    local self = setmetatable({}, W)
    self.config = config
    self.items = items
    self.blocks = {}       -- {gx, gy, gz, itemType, state, dur}
    self.occupied = {}     -- "x,y,z" -> block ref
    self.time = 0
    self.isNight = false
    self.markers = {}          -- communication markers
    return self
end

function W:_key(x, y, z) return x..","..y..","..z end

function W:update(dt)
    self.time = (self.time + dt) % self.config.DAY_LEN
    local phase = self.time / self.config.DAY_LEN
    self.isNight = phase >= self.config.NIGHT_START and phase < self.config.NIGHT_END

    for i = #self.blocks, 1, -1 do
        local b = self.blocks[i]
        if b.state == "placed" then
            b.dur = b.dur - dt
            if b.dur <= 0 then
                log.write("world", "DECAY %s at:(%d,%d,%d)", b.itemType, b.gx, b.gy, b.gz)
                self:_removeAt(i)
            end
        end
    end

    -- Block gravity: throttled (every 0.5s, not every frame)
    self.gravityTimer = (self.gravityTimer or 0) - dt
    if self.gravityTimer <= 0 then
        self.gravityTimer = 0.5
        for pass = 1, 3 do
            local fell = false
            for i = #self.blocks, 1, -1 do
                local b = self.blocks[i]
                if b.gy > 0 and (b.state == "placed" or b.state == "loose") then
                    local belowKey = self:_key(b.gx, b.gy - 1, b.gz)
                    if not self.occupied[belowKey] then
                        local oldKey = self:_key(b.gx, b.gy, b.gz)
                        if self.occupied[oldKey] == b then self.occupied[oldKey] = nil end
                        b.gy = b.gy - 1
                        local newKey = self:_key(b.gx, b.gy, b.gz)
                        if not self.occupied[newKey] then
                            self.occupied[newKey] = b
                        end
                        fell = true
                    end
                end
            end
            if not fell then break end
        end
    end

    -- Marker decay
    for i = #self.markers, 1, -1 do
        self.markers[i].strength = self.markers[i].strength - 0.5 * dt
        if self.markers[i].strength <= 0 then
            table.remove(self.markers, i)
        end
    end
end

function W:daylight()
    local phase = self.time / self.config.DAY_LEN
    local ns, ne = self.config.NIGHT_START, self.config.NIGHT_END
    if phase < ns or phase >= ne then return 1.0 end
    local mid = (ns + ne) / 2
    local half = (ne - ns) / 2
    return 0.12 + 0.88 * (math.abs(phase - mid) / half)
end

function W:addBlock(gx, gy, gz, itemType, state)
    if gx < 0 or gx >= self.config.GRID or gz < 0 or gz >= self.config.GRID then return nil end
    local k = self:_key(gx, gy, gz)
    if self.occupied[k] then return nil end
    -- Bed occupies 2 cells: check second cell too
    if itemType == "bed" and state ~= "carried" and state ~= "loose" then
        local k2 = self:_key(gx, gy, gz + 1)
        if self.occupied[k2] then return nil end
    end
    local st = state or "loose"
    local block = {gx=gx, gy=gy, gz=gz, itemType=itemType, state=st, dur=self.config.BLOCK_DUR,
                   dropTime=(st == "loose") and self.time or nil}
    self.blocks[#self.blocks+1] = block
    if st ~= "carried" then
        self.occupied[k] = block
        -- Bed: also occupy (gx, gy, gz+1)
        if itemType == "bed" and st == "placed" then
            local k2 = self:_key(gx, gy, gz + 1)
            if not self.occupied[k2] then self.occupied[k2] = block end
        end
    end
    return block
end

function W:_removeAt(idx)
    local b = self.blocks[idx]
    local k = self:_key(b.gx, b.gy, b.gz)
    if self.occupied[k] == b then self.occupied[k] = nil end
    -- Bed: also clear second cell
    if b.itemType == "bed" then
        local k2 = self:_key(b.gx, b.gy, b.gz + 1)
        if self.occupied[k2] == b then self.occupied[k2] = nil end
    end
    table.remove(self.blocks, idx)
end

function W:removeBlock(block)
    for i, b in ipairs(self.blocks) do
        if b == block then self:_removeAt(i); return end
    end
end

function W:nearestLoose(x, z, itemType)
    local best, bestD2 = nil, math.huge
    for _, b in ipairs(self.blocks) do
        if b.state == "loose" and (itemType == nil or b.itemType == itemType) then
            local d2 = (b.gx-x)^2 + (b.gz-z)^2
            if d2 < bestD2 then best, bestD2 = b, d2 end
        end
    end
    return best
end

function W:nearestLooseBuilding(x, z, buildingType)
    local best, bestD2 = nil, math.huge
    for _, b in ipairs(self.blocks) do
        if b.state == "loose" then
            local def = self.items.get(b.itemType)
            if def and def.building_type == buildingType then
                local d2 = (b.gx-x)^2 + (b.gz-z)^2
                if d2 < bestD2 then best, bestD2 = b, d2 end
            end
        end
    end
    return best
end

function W:hasRoof(gx, gz)
    for y = 1, 20 do
        if self.occupied[self:_key(gx, y, gz)] then return true end
    end
    return false
end

function W:isOccupied(gx, gy, gz) return self.occupied[self:_key(gx, gy, gz)] ~= nil end

-- Check if a block at this position is a solid obstacle (not a loose item on the ground)
function W:isSolid(gx, gy, gz)
    local block = self.occupied[self:_key(gx, gy, gz)]
    if not block then return false end
    if block.state == "loose" then return false end
    if block.itemType == "door" then return false end  -- doors are passable
    return true
end

-- Check if an NPC (1x2x1) can stand at grid position (gx, gy, gz)
-- Feet at (gx, gy, gz), head at (gx, gy+1, gz)
-- Requires: feet clear of solid blocks, head clear, floor below (or gy==0 = ground)
-- Loose blocks (items on ground) do NOT block NPC movement
function W:canStandAt(gx, gy, gz)
    if gx < 0 or gx >= self.config.GRID or gz < 0 or gz >= self.config.GRID then return false end
    if gy < 0 then return false end
    local feetClear = not self:isSolid(gx, gy, gz)
    local headClear = not self:isSolid(gx, gy + 1, gz)
    local hasFloor = (gy == 0) or self:isOccupied(gx, gy - 1, gz)
    return feetClear and headClear and hasFloor
end

function W:breakBlockAt(gx, gy, gz)
    local k = self:_key(gx, gy, gz)
    local block = self.occupied[k]
    if block then self:removeBlock(block); return true end
    return false
end

function W:isRoomEnclosed(ix, iz)
    local visited = {}
    local queue = {{ix, iz}}
    visited[ix..","..iz] = true
    local head = 1
    while head <= #queue do
        local x, z = queue[head][1], queue[head][2]
        head = head + 1
        if x < 0 or x >= self.config.GRID or z < 0 or z >= self.config.GRID then return false end
        for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
            local nx, nz = x+d[1], z+d[2]
            local nk = nx..","..nz
            if not visited[nk] then
                local wall0 = self.occupied[self:_key(nx, 0, nz)]
                local wall1 = self.occupied[self:_key(nx, 1, nz)]
                if wall0 and wall1 then
                    visited[nk] = true  -- wall, don't expand
                else
                    visited[nk] = true
                    queue[#queue+1] = {nx, nz}
                end
            end
        end
    end
    return true
end

function W:getRecentDropsNear(cx, cz, radius, sinceTime)
    local result = {}
    local r2 = radius * radius
    for _, b in ipairs(self.blocks) do
        if b.state == "loose" and b.dropTime and b.dropTime >= sinceTime then
            if (b.gx - cx)^2 + (b.gz - cz)^2 <= r2 then
                result[#result + 1] = b
            end
        end
    end
    return result
end

function W:countLooseByType()
    local counts = {}
    for _, b in ipairs(self.blocks) do
        if b.state == "loose" then
            counts[b.itemType] = (counts[b.itemType] or 0) + 1
        end
    end
    return counts
end

-- Find a free ground-level spot near (cx, cz), spiraling outward
function W:_findFreeGround(cx, cz)
    for r = 1, 10 do  -- start at 1 to avoid returning the same position
        for dx = -r, r do
            for dz = -r, r do
                if math.abs(dx) == r or math.abs(dz) == r then -- perimeter only
                    local fx, fz = cx + dx, cz + dz
                    if fx >= 0 and fx < self.config.GRID and fz >= 0 and fz < self.config.GRID
                       and not self.occupied[self:_key(fx, 0, fz)] then
                        return fx, fz
                    end
                end
            end
        end
    end
    return nil, nil
end

function W:demolishBuilding(blueprint)
    local ox, oz = blueprint.originX, blueprint.originZ
    local w, d = blueprint.width, blueprint.depth
    local maxY = (blueprint.wallH or self.config.WALL_H) + 1
    for y = maxY, 0, -1 do
        for x = ox, ox + w - 1 do
            for z = oz, oz + d - 1 do
                local k = self:_key(x, y, z)
                local block = self.occupied[k]
                if block then
                    local itemType = block.itemType
                    self:removeBlock(block)
                    local fx, fz = self:_findFreeGround(x, z)
                    if fx then
                        self:addBlock(fx, 0, fz, itemType, "loose")
                    end
                end
            end
        end
    end
end

----------------------------------------------------------------------------
-- MARKER COMMUNICATION SYSTEM
----------------------------------------------------------------------------
function W:addMarker(markerType, x, z, npcId)
    -- Don't duplicate: check if same type exists nearby recently
    for _, m in ipairs(self.markers) do
        if m.type == markerType and m.strength > 50
           and math.abs(m.x - x) + math.abs(m.z - z) <= 3 then
            m.strength = 100  -- refresh existing marker
            return
        end
    end
    self.markers[#self.markers + 1] = {
        type = markerType, x = x, z = z,
        createdBy = npcId, createdAt = self.time,
        strength = 100,
    }
end

function W:getMarkersNear(cx, cz, radius, markerType)
    local result = {}
    local r2 = radius * radius
    for _, m in ipairs(self.markers) do
        if (not markerType or m.type == markerType) and m.strength > 0 then
            if (m.x - cx)^2 + (m.z - cz)^2 <= r2 then
                result[#result + 1] = m
            end
        end
    end
    return result
end

return W
