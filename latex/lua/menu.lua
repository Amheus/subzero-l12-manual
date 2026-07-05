local Menu = {}
Menu.locale = "en-GB"

local function localise(translations)
    if type(translations) ~= "table" then
        return tostring(translations)
    end
    if translations[Menu.locale] then
        return translations[Menu.locale]
    end
    if translations["en-GB"] then
        return translations["en-GB"]
    end
    for _, value in pairs(translations) do
        return value
    end
    return ""
end

local function decode(path)
    local file = assert(io.open(path, "r"), "menu: cannot open " .. path)
    local contents = file:read("*a")
    file:close()
    return json.decode(contents)
end

function Menu.load_menu(path)       Menu.menu = decode(path) end
function Menu.load_bands(path)      Menu.bands = decode(path) end
function Menu.load_controls(path)   Menu.controls = decode(path) end
function Menu.load_panel(path)      Menu.panel = decode(path) end

local function format_frequency(hertz)
    if hertz >= 1000 then
        local kilohertz = hertz / 1000
        if kilohertz == math.floor(kilohertz) then
            return string.format("%d\\,kHz", kilohertz)
        end
        return string.format("%.1f\\,kHz", kilohertz)
    end
    return string.format("%d\\,Hz", hertz)
end

local function escape_unit(unit)
    if unit == "%" then
        return "\\%"
    end
    return unit
end

local function db_range(low, high)
    local function format_sign(number)
        if number < 0 then
            return "$-" .. math.abs(number) .. "$"
        end
        if number > 0 then
            return "$+" .. number .. "$"
        end
        return "0"
    end
    return format_sign(low) .. " to " .. format_sign(high) .. "\\,dB"
end

local function band_range(segments)
    local low = format_frequency(segments[1].from)
    local high = format_frequency(segments[#segments].to)
    local steps = {}
    for _, segment in ipairs(segments) do
        steps[#steps + 1] = format_frequency(segment.step)
    end
    local unique_steps, seen = {}, {}
    for _, step in ipairs(steps) do
        if not seen[step] then
            seen[step] = true; unique_steps[#unique_steps + 1] = step
        end
    end
    return low .. "-" .. high .. " (" .. table.concat(unique_steps, " / ") .. " steps)"
end

local function item_setting(item)
    local item_type = item.type
    if item_type == "enum" then
        return table.concat(item.values, ", ")
    elseif item_type == "range" then
        local setting = item.off and "OFF, " or ""
        setting = setting .. string.format("%g-%g", item.min, item.max)
        if item.unit then
            setting = setting .. "\\," .. escape_unit(item.unit)
        end
        if item.step and item.step ~= 1 then
            setting = setting .. string.format(" (%g", item.step)
            if item.unit then
                setting = setting .. "\\," .. escape_unit(item.unit)
            end
            setting = setting .. " steps)"
        end
        return setting
    elseif item_type == "submenu" then
        return "Configurable 5-band (see table)"
    end
    return ""
end

function Menu.render()
    local menu_data = Menu.menu
    tex.sprint("\\dspmenuintro{" .. localise(menu_data.entry) .. "}{" .. localise(menu_data.navigation) .. "}")
    for _, page in ipairs(menu_data.pages) do
        tex.sprint("\\dspmenupage{" .. tostring(page.page) .. "}")
        for _, item in ipairs(page.items) do
            local setting = item_setting(item)
            local description = item.description and localise(item.description) or ""
            if description ~= "" then
                tex.sprint("\\dspmenuitemdesc{" .. item.name .. "}{" .. setting .. "}{" .. description .. "}")
            else
                tex.sprint("\\dspmenuitem{" .. item.name .. "}{" .. setting .. "}")
            end
        end
    end
end

function Menu.render_bands()
    local bands_data = Menu.bands
    tex.sprint("\\begin{eqbandtabular}")
    for _, band in ipairs(bands_data.bands) do
        tex.sprint(string.format("%d & %s & %s\\\\", band.n, band_range(band.freq), format_frequency(band.default)))
    end
    tex.sprint("\\end{eqbandtabular}")
    tex.sprint(string.format("\\eqgainnote{%s}{%g}", db_range(bands_data.gain.min, bands_data.gain.max), bands_data.gain.step))
end

function Menu.render_controls()
    local controls_data = Menu.controls

    local mic_effect = controls_data.mic_effect
    tex.sprint("\\menusubhead{" .. mic_effect.name .. "}")
    tex.sprint("\\menuaccess{" .. localise(mic_effect.access) .. " On screen this appears as \\texttt{" .. (mic_effect.screen_label or "") .. "}.}")
    for _, param in ipairs(mic_effect.params) do
        tex.sprint("\\dspmenuitem{" .. param.name .. "}{" .. item_setting(param) .. "}")
    end

    local guitar_fx = controls_data.guitar_fx
    tex.sprint("\\menusubhead{" .. guitar_fx.name .. "}")
    tex.sprint("\\menuaccess{" .. localise(guitar_fx.access) .. "}")
    tex.sprint("\\dspmenuitem{Effects}{" .. table.concat(guitar_fx.values, ", ") .. "}")

    local tone = controls_data.tone
    tex.sprint("\\menusubhead{" .. tone.name .. "}")
    for _, param in ipairs(tone.params) do
        local setting = format_frequency(param.freq) .. " shelf, " .. db_range(param.min, param.max)
        tex.sprint("\\dspmenuitem{" .. param.name .. "}{" .. setting .. "}")
    end
    local misprint_param = tone.params[1]

    tex.sprint("\\begin{caution}")
    tex.sprint("The control board prints the Bass and Treble lower limit as \"" .. misprint_param.boardMisprint .. "\". The actual range is " .. db_range(misprint_param.min, misprint_param.max) .. ".")
    tex.sprint("\\end{caution}")
end

function Menu.render_panel()
    local panel_data = Menu.panel
    tex.sprint("\\begin{panellegendtabular}")
    for _, feature in ipairs(panel_data.topPanel) do
        tex.sprint(string.format("\\panelnum{%d} & %s & %s\\\\", feature.id, localise(feature.label), localise(feature.description)))
    end
    tex.sprint("\\end{panellegendtabular}")
end

return Menu
