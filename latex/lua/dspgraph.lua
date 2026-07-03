local DspGraph = {}
local data = nil

DspGraph.locale = "en-GB"

local function localise(translations)
    if type(translations) ~= "table" then
        return tostring(translations)
    end
    if translations[DspGraph.locale] then
        return translations[DspGraph.locale]
    end
    if translations["en-GB"] then
        return translations["en-GB"]
    end
    for _, value in pairs(translations) do
        return value
    end
    return ""
end

function DspGraph.load(path)
    local file = assert(io.open(path, "r"), "dspgraph: cannot open " .. path)
    local contents = file:read("*a")
    file:close()
    data = json.decode(contents)
    for key, mode_data in pairs(data.modes) do
        tex.sprint(string.format("\\expandafter\\gdef\\csname dsp@label@%s\\endcsname{%s}", key, localise(mode_data.label)))
    end
end

local function mode(key)
    if not data then
        tex.error("dspgraph: data not loaded - call dspgraph.load() first")
    end
    local mode_data = data.modes[key]
    if not mode_data then
        tex.error("dspgraph: unknown DSP mode '" .. tostring(key) .. "'")
    end
    return mode_data
end

function DspGraph.plot(key)
    local mode_data = mode(key)
    if not mode_data.targetPoints then
        tex.error("dspgraph: '" .. key .. "' is a configurable EQ (no fixed curve) - render it as a band table, not a graph")
        return
    end
    local coordinates = {}
    for _, point in ipairs(mode_data.targetPoints) do
        coordinates[#coordinates + 1] = string.format("(%g,%g)", point[1], point[2])
    end
    local line = table.concat(coordinates, " ")
    tex.sprint("\\addplot[dspzero] coordinates {(20,0) (20000,0)};")
    tex.sprint("\\addplot[dspcurve] coordinates {" .. line .. "};")
end

return DspGraph
