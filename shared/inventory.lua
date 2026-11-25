local Inventory = {}

function Inventory.AddItem(source, item, amount)
    local ok, added = pcall(function()
        return exports.ox_inventory:AddItem(source, item, amount)
    end)

    if not ok then
        print(('[CHOP ERROR] ox_inventory:AddItem failed for %s x%s (player %s): %s')
            :format(tostring(item), tostring(amount), tostring(source), tostring(added)))
        return false
    end

    return added == true
end

function Inventory.GetItemCount(source, item)
    local ok, count = pcall(function()
        return exports.ox_inventory:GetItemCount(source, item)
    end)
    if not ok then return 0 end
    return tonumber(count) or 0
end

_G.Inventory = Inventory
return Inventory
