-- Global cache for all version data (vanilla, fabric, neoforge)
versions = {}

-- Minimal XML parser for NeoForge metadata
-- Extracts all <version>...</version> entries from the XML text
local function parseNeoForgeXML(xml)
    local list = {}

    for version in string.gmatch(xml, "<version>(.-)</version>") do
        table.insert(list, version)
    end

    return list
end

-- Called once at initialize to populate version caches
function init()
    ---------------------------------------------------------------------
    -- VANILLA VERSION MANIFEST
    ---------------------------------------------------------------------
    local json_text = http:get("https://launchermeta.mojang.com/mc/game/version_manifest.json")
    local manifest = json.parse(json_text)
    versions.vanilla = manifest.versions

    ---------------------------------------------------------------------
    -- FABRIC GAME VERSION LIST
    ---------------------------------------------------------------------
    local fabric_text = http:get("https://meta.fabricmc.net/v2/versions/game")
    local fabric_manifest = json.parse(fabric_text)
    versions.fabric = fabric_manifest

    ---------------------------------------------------------------------
    -- NEOFORGE VERSION METADATA (XML)
    ---------------------------------------------------------------------
    local xml_text = http:get("https://maven.neoforged.net/releases/net/neoforged/neoforge/maven-metadata.xml")
    versions.neoforge = parseNeoForgeXML(xml_text)
end

-- Unified version resolver for serverVersion field
function getVersions(args)
    local serverType = args.serverType
    local releaseType = args.releaseType
    local result = {}

    ---------------------------------------------------------------------
    -- VANILLA: Filter by releaseType (release/snapshot)
    ---------------------------------------------------------------------
    if serverType == "vanilla" then
        for _, v in ipairs(versions.vanilla) do
            if v.type == releaseType then
                table.insert(result, {
                    value = v.id,
                    label = v.id
                })
            end
        end

        return result
    end

    ---------------------------------------------------------------------
    -- FABRIC: Only include versions that exist in vanilla manifest
    ---------------------------------------------------------------------
    if serverType == "fabric" then
        -- Build lookup table of vanilla versions
        local vanillaLookup = {}
        for _, v in ipairs(versions.vanilla) do
            vanillaLookup[v.id] = true
        end

        -- Fabric API returns objects with "version" field
        for _, v in ipairs(versions.fabric) do
            if vanillaLookup[v.version] then
                table.insert(result, {
                    value = v.version,
                    label = v.version
                })
            end
        end

        return result
    end

    ---------------------------------------------------------------------
    -- NEOFORGE: Return Minecraft versions supported by NeoForge
    ---------------------------------------------------------------------
    if serverType == "neoforge" then
        local neoforgeLookup = {}

        -- Build lookup of NeoForge supported keys: "20.2", "21.1", "26.2"
        for _, v in ipairs(versions.neoforge) do
            local nf_major, nf_minor = string.match(v, "^(%d+)%.(%d+)")
            if nf_major and nf_minor then
                neoforgeLookup[nf_major .. "." .. nf_minor] = true
            end
        end

        -- Match Minecraft versions against NeoForge keys
        for _, v in ipairs(versions.vanilla) do
            local mcKey = nil

            -- NEW Minecraft format: "26.2"
            mcKey = string.match(v.id, "^(%d+%.%d+)$")

            if not mcKey then
                -- OLD Minecraft format: "1.21.1" → "21.1"
                local mc_major, mc_minor = string.match(v.id, "^1%.(%d+)%.(%d+)")
                if mc_major and mc_minor then
                    mcKey = mc_major .. "." .. mc_minor
                end
            end

            -- Include Minecraft version if NeoForge supports it
            if mcKey and neoforgeLookup[mcKey] then
                table.insert(result, {
                    value = v.id,
                    label = v.id
                })
            end
        end

        return result
    end

    ---------------------------------------------------------------------
    -- DEFAULT: Unknown serverType → return empty list
    ---------------------------------------------------------------------
    return {}
end

-- Return NeoForge versions that match the selected Minecraft version
function getNeoForgeVersions(args)
    local mcVersion = args.serverVersion
    local result = {}

    ---------------------------------------------------------------------
    -- Convert Minecraft version → major.minor
    -- Supports both old (1.x.y → x.y) and new (26.2 → 26.2) formats
    ---------------------------------------------------------------------

    local mcKey = nil

    -- NEW Minecraft format: "26.2"
    mcKey = string.match(mcVersion, "^(%d+%.%d+)$")

    if not mcKey then
        -- OLD Minecraft format: "1.21.1" → "21.1"
        local mc_major, mc_minor = string.match(mcVersion, "^1%.(%d+)%.(%d+)")
        if mc_major and mc_minor then
            mcKey = mc_major .. "." .. mc_minor
        end
    end

    -- If Minecraft version cannot be parsed → return empty list
    if not mcKey then
        return result
    end

    ---------------------------------------------------------------------
    -- Build list of NeoForge versions matching the Minecraft key
    ---------------------------------------------------------------------

    local matchingVersions = {}

    for _, v in ipairs(versions.neoforge) do
        -- Extract major.minor from NeoForge version
        local nf_major, nf_minor = string.match(v, "^(%d+)%.(%d+)")
        if nf_major and nf_minor then
            local key = nf_major .. "." .. nf_minor

            -- Match NeoForge key with Minecraft key
            if key == mcKey then
                table.insert(matchingVersions, v)
            end
        end
    end

    ---------------------------------------------------------------------
    -- Sort NeoForge versions descending (largest first)
    -- Sorting by numeric major.minor.patch
    ---------------------------------------------------------------------

    table.sort(matchingVersions, function(a, b)
        local a1, a2, a3 = string.match(a, "^(%d+)%.(%d+)%.(%d+)")
        local b1, b2, b3 = string.match(b, "^(%d+)%.(%d+)%.(%d+)")

        a1 = tonumber(a1) or 0
        a2 = tonumber(a2) or 0
        a3 = tonumber(a3) or 0

        b1 = tonumber(b1) or 0
        b2 = tonumber(b2) or 0
        b3 = tonumber(b3) or 0

        if a1 ~= b1 then return a1 > b1 end
        if a2 ~= b2 then return a2 > b2 end
        return a3 > b3
    end)

    ---------------------------------------------------------------------
    -- Build result list for UI
    ---------------------------------------------------------------------

    for _, v in ipairs(matchingVersions) do
        table.insert(result, {
            value = v,
            label = v
        })
    end

    return result
end
