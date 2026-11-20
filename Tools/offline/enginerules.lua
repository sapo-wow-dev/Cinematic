-- Checks the engine rules (Tools/engine): every area file loads, ids are unique,
-- each rule has its fields with allowed values. Exits 1 on any problem.
-- python -I Tools/offline/run.py Tools/offline/enginerules.lua
local rules, areas = dofile("Tools/engine/rules.lua")

local CLIENTS = { forever = true, retail = true, classic_era = true }
local STATUS = { tested = true, inferred = true, unknown = true, changed = true }
local problems, seen, count = {}, {}, {}

local function bad(r, msg)
    problems[#problems + 1] = (r.file or "?") .. ": " .. tostring(r.id) .. ": " .. msg
end

local function strings(r, key, required)
    local v = r[key]
    if v == nil then
        if required then bad(r, key .. " missing") end
        return
    end
    if type(v) ~= "table" or (required and #v == 0) then return bad(r, key .. " must be a list of strings") end
    for _, s in ipairs(v) do
        if type(s) ~= "string" or s == "" then bad(r, key .. " has a non-string") end
    end
end

for _, r in ipairs(rules) do
    count[r.file] = (count[r.file] or 0) + 1
    if type(r.id) ~= "string" or not r.id:match("^[%w_]+%.[%w_%-%.]+$") then bad(r, "id must be client.thing.what") end
    if seen[r.id] then bad(r, "duplicate id (also in " .. seen[r.id] .. ")") end
    seen[r.id] = r.file
    for _, key in ipairs({ "area", "when", "rule", "proof", "source" }) do
        if type(r[key]) ~= "string" or r[key] == "" then bad(r, key .. " missing") end
    end
    strings(r, "clients", true)
    for _, c in ipairs(r.clients or {}) do
        if not CLIENTS[c] then bad(r, "unknown client " .. tostring(c)) end
    end
    strings(r, "api", true)
    strings(r, "works")
    strings(r, "fails")
    if not STATUS[r.status] then bad(r, "status must be tested/inferred/unknown/changed") end
    if r.status == "tested" or r.status == "changed" then
        if type(r.tested) ~= "string" or not r.tested:match("^%d%d%d%d%-%d%d%-%d%d$") then
            bad(r, "tested date (YYYY-MM-DD) missing")
        end
    end
    for k in pairs(r) do
        if not ({ id = 1, area = 1, clients = 1, api = 1, when = 1, rule = 1, works = 1, fails = 1, status = 1,
            tested = 1, proof = 1, source = 1, file = 1 })[k] then
            bad(r, "unknown field " .. tostring(k))
        end
    end
end

for _, area in ipairs(areas) do
    print(("%-18s %d rules"):format(area, count[area] or 0))
end
print(("%d rules"):format(#rules))
if #problems > 0 then
    for _, p in ipairs(problems) do print("FAIL " .. p) end
    os.exit(1)
end
print("OK")
