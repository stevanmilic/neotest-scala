local lib = require("neotest.lib")

local M = {}

--- Strip quotes from the (captured) test position.
---@param position neotest.Position
---@return string
function M.get_position_name(position)
    if position.type == "test" then
        local value = string.gsub(position.name, '"', "")
        return value
    end
    return position.name
end

---Get a package name from the top of the file.
---@return string|nil
function M.get_package_name(file)
    local success, lines = pcall(lib.files.read_lines, file)
    if not success then
        return nil
    end
    local line = lines[1]
    return vim.startswith(line, "package") and vim.split(line, " ")[2] or ""
end

return M
