-- init.lua
for _, part in ipairs(Config.VehicleParts or {}) do
    VALID_PARTS[part.name] = part
end

TOOL_LISTS = {
    drill   = Config.ToolPickups or {},
    grinder = Config.GrinderPickups or {},
}
for kind, list in pairs(TOOL_LISTS) do
    for i = 1, #list do
        State.mainToolState[kind][i] = false
    end
end
