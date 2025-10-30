--- Union-Find data structure for tracking connected components
--- Used to detect episode groups based on episodeLinks
--- @class UnionFind
UnionFind = class(function(o, elements)
    o.parent = {}
    o.rank = {}
    for _, elem in ipairs(elements) do
        o.parent[elem] = elem
        o.rank[elem] = 0
    end
end)

--- Find root of element with path compression optimization
--- @param x any Element to find root of
--- @return any Root element
function UnionFind:find(x)
    if self.parent[x] ~= x then
        self.parent[x] = self:find(self.parent[x])  -- Path compression
    end
    return self.parent[x]
end

--- Union two elements by rank
--- @param x any First element
--- @param y any Second element
function UnionFind:union(x, y)
    local rootX = self:find(x)
    local rootY = self:find(y)

    if rootX == rootY then
        return  -- Already in same set
    end

    -- Union by rank
    if self.rank[rootX] < self.rank[rootY] then
        self.parent[rootX] = rootY
    elseif self.rank[rootX] > self.rank[rootY] then
        self.parent[rootY] = rootX
    else
        self.parent[rootY] = rootX
        self.rank[rootX] = self.rank[rootX] + 1
    end
end

--- Get all connected components
--- @return table Map of root -> {elements in component}
function UnionFind:getComponents()
    local components = {}
    for elem, _ in pairs(self.parent) do
        local root = self:find(elem)
        if not components[root] then
            components[root] = {}
        end
        table.insert(components[root], elem)
    end
    return components
end
