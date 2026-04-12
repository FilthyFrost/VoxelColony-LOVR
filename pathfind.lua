-- pathfind.lua — A* 3D grid pathfinding for voxel world
-- NPC is 1x2x1 (1 wide, 2 tall, 1 deep)
-- Supports: flat walk, jump up 1, drop down 1-2, climb scaffolding

local PF = {}

-- Binary min-heap for open set (sorted by f-cost)
local function heapPush(heap, node)
    heap[#heap+1] = node
    local i = #heap
    while i > 1 do
        local parent = math.floor(i / 2)
        if heap[parent].f > heap[i].f then
            heap[parent], heap[i] = heap[i], heap[parent]
            i = parent
        else break end
    end
end

local function heapPop(heap)
    if #heap == 0 then return nil end
    local top = heap[1]
    heap[1] = heap[#heap]
    heap[#heap] = nil
    local i = 1
    while true do
        local smallest = i
        local l, r = i*2, i*2+1
        if l <= #heap and heap[l].f < heap[smallest].f then smallest = l end
        if r <= #heap and heap[r].f < heap[smallest].f then smallest = r end
        if smallest ~= i then
            heap[i], heap[smallest] = heap[smallest], heap[i]
            i = smallest
        else break end
    end
    return top
end

local function key(x, y, z) return x..","..y..","..z end

----------------------------------------------------------------------------
-- Find path from (sx,sy,sz) to (gx,gy,gz) in the world grid
-- world: must have :canStandAt(x,y,z) and :isOccupied(x,y,z)
-- Returns: array of {x=,y=,z=} waypoints, or nil if no path
-- maxNodes: search budget (default 500)
----------------------------------------------------------------------------
function PF.findPath(world, sx, sy, sz, gx, gy, gz, maxNodes)
    maxNodes = maxNodes or 500

    -- If start == goal, done
    if sx == gx and sy == gy and sz == gz then return {} end

    local startKey = key(sx, sy, sz)
    local goalKey = key(gx, gy, gz)

    local open = {}  -- min-heap
    local closed = {}  -- key -> true
    local cameFrom = {}  -- key -> {x,y,z}
    local gScore = {}  -- key -> cost from start

    gScore[startKey] = 0
    local h = math.abs(gx-sx) + math.abs(gy-sy) + math.abs(gz-sz)
    heapPush(open, {x=sx, y=sy, z=sz, f=h})

    local explored = 0

    while #open > 0 and explored < maxNodes do
        local cur = heapPop(open)
        local ck = key(cur.x, cur.y, cur.z)

        if ck == goalKey then
            -- Reconstruct path
            local path = {}
            local k = goalKey
            while k and k ~= startKey do
                local pos = cameFrom[k]
                if not pos then break end
                local parts = {}
                for p in k:gmatch("([^,]+)") do parts[#parts+1] = tonumber(p) end
                table.insert(path, 1, {x=parts[1], y=parts[2], z=parts[3]})
                k = key(pos.x, pos.y, pos.z)
            end
            return path
        end

        if closed[ck] then goto continue end
        closed[ck] = true
        explored = explored + 1

        local curG = gScore[ck] or 0

        -- Expand neighbors
        local neighbors = PF._getNeighbors(world, cur.x, cur.y, cur.z)
        for _, nb in ipairs(neighbors) do
            local nk = key(nb.x, nb.y, nb.z)
            if not closed[nk] then
                local tentG = curG + nb.cost
                if not gScore[nk] or tentG < gScore[nk] then
                    gScore[nk] = tentG
                    cameFrom[nk] = {x=cur.x, y=cur.y, z=cur.z}
                    local nh = math.abs(gx-nb.x) + math.abs(gy-nb.y) + math.abs(gz-nb.z)
                    heapPush(open, {x=nb.x, y=nb.y, z=nb.z, f=tentG + nh})
                end
            end
        end

        ::continue::
    end

    return nil  -- no path found
end

----------------------------------------------------------------------------
-- Get valid neighbor positions from (x,y,z)
-- NPC is 1x2x1: occupies (x,y,z) and (x,y+1,z)
-- Returns: array of {x, y, z, cost}
----------------------------------------------------------------------------
function PF._getNeighbors(world, x, y, z)
    local result = {}
    local dirs = {{1,0}, {-1,0}, {0,1}, {0,-1}}

    for _, d in ipairs(dirs) do
        local nx, nz = x + d[1], z + d[2]

        -- Flat walk: same Y level
        if world:canStandAt(nx, y, nz) then
            result[#result+1] = {x=nx, y=y, z=nz, cost=1.0}
        else
            -- Jump up: blocked at same level, try one above
            if world:canStandAt(nx, y+1, nz) then
                -- Also check clearance: head at y+2 must be clear
                if not world:isOccupied(x, y+2, z) then
                    result[#result+1] = {x=nx, y=y+1, z=nz, cost=1.5}
                end
            end
        end

        -- Drop down: forward position has no floor at same level
        -- but has floor one level below
        if world:canStandAt(nx, y-1, nz) and y > 0 then
            result[#result+1] = {x=nx, y=y-1, z=nz, cost=1.2}
        end
    end

    -- Vertical: climb straight up (if standing on a block and space above)
    if world:canStandAt(x, y+1, z) then
        result[#result+1] = {x=x, y=y+1, z=z, cost=2.0}
    end
    -- Vertical: drop straight down
    if y > 0 and world:canStandAt(x, y-1, z) then
        result[#result+1] = {x=x, y=y-1, z=z, cost=1.0}
    end

    return result
end

----------------------------------------------------------------------------
-- Find path to a position ADJACENT to goal (for placing blocks)
-- Useful when the goal cell itself is occupied or will be occupied
-- Returns path to nearest neighboring cell of goal
----------------------------------------------------------------------------
function PF.findPathAdjacent(world, sx, sy, sz, gx, gy, gz, maxNodes)
    -- Try all neighbors of goal position at various Y levels
    local candidates = {}
    local dirs = {{1,0}, {-1,0}, {0,1}, {0,-1}}
    for _, d in ipairs(dirs) do
        local nx, nz = gx + d[1], gz + d[2]
        -- Try at goal Y level, and below
        for ty = gy, math.max(0, gy-2), -1 do
            if world:canStandAt(nx, ty, nz) then
                candidates[#candidates+1] = {x=nx, y=ty, z=nz}
                break  -- found lowest valid Y for this direction
            end
        end
    end

    -- Find shortest path to any candidate
    local bestPath = nil
    local bestLen = math.huge
    for _, c in ipairs(candidates) do
        local path = PF.findPath(world, sx, sy, sz, c.x, c.y, c.z, maxNodes)
        if path and #path < bestLen then
            bestPath = path
            bestLen = #path
        end
    end
    return bestPath
end

----------------------------------------------------------------------------
-- Find path to a position from which NPC can REACH target (tx,ty,tz)
-- "Reach" = XZ Manhattan dist ≤ 1, and ty within standY..standY+2
-- Used for placing/breaking blocks at various heights
----------------------------------------------------------------------------
function PF.findPathToReach(world, sx, sy, sz, tx, ty, tz, maxNodes)
    local candidates = {}
    local dirs = {{1,0},{-1,0},{0,1},{0,-1}}
    for _, d in ipairs(dirs) do
        local nx, nz = tx + d[1], tz + d[2]
        -- From target height down, find a standable position within reach
        for standY = ty, math.max(0, ty - 2), -1 do
            if world:canStandAt(nx, standY, nz) and ty <= standY + 2 then
                candidates[#candidates+1] = {x=nx, y=standY, z=nz}
                break
            end
        end
    end

    -- Also try standing at the target XZ itself (for blocks above NPC)
    for standY = ty, math.max(0, ty - 2), -1 do
        if world:canStandAt(tx, standY, tz) and ty <= standY + 2 then
            candidates[#candidates+1] = {x=tx, y=standY, z=tz}
            break
        end
    end

    local bestPath = nil
    local bestLen = math.huge
    for _, c in ipairs(candidates) do
        -- Skip if candidate == start
        if c.x == sx and c.y == sy and c.z == sz then
            return {}  -- already there
        end
        local path = PF.findPath(world, sx, sy, sz, c.x, c.y, c.z, maxNodes)
        if path and #path < bestLen then
            bestPath = path
            bestLen = #path
        end
    end
    return bestPath
end

return PF
