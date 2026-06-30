-- Fetch Minecraft version manifest
local http = require("http")

local json = http.get("https://launchermeta.mojang.com/mc/game/version_manifest.json")
local manifest = json:toTable()

local releaseType = args.releaseType  -- "release", "snapshot"

local result = {}

for _, v in ipairs(manifest.versions) do
    if v.type == releaseType then
        table.insert(result, {
            value = v.id,
            label = v.id
        })
    end
end

return result