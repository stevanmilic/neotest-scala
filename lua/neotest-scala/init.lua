local Path = require("plenary.path")
local lib = require("neotest.lib")

TEST_PASSED = "passed" -- the test passed
TEST_FAILED = "failed" -- the test failed

---@type neotest.Adapter
local ScalaNeotestAdapter = { name = "neotest-scala" }

ScalaNeotestAdapter.root = lib.files.match_root_pattern("build.sbt")

---@async
---@param file_path string
---@return boolean
function ScalaNeotestAdapter.is_test_file(file_path)
    if not vim.endswith(file_path, ".scala") then
        return false
    end
    local elems = vim.split(file_path, Path.path.sep)
    local file_name = string.lower(elems[#elems])
    local patterns = { "test", "spec", "suite" }
    for _, pattern in ipairs(patterns) do
        if string.find(file_name, pattern) then
            return true
        end
    end
    return false
end

function ScalaNeotestAdapter.filter_dir(name, _, _)
    return true
end

--- Strip quotes from the (captured) test position.
---@param position neotest.Position
---@return string
local function get_position_name(position)
    if position.type == "test" then
        local value = string.gsub(position.name, '"', "")
        return value
    end
    return position.name
end

---Get a package name from the top of the file.
---@return string|nil
local function get_package_name(file)
    local success, lines = pcall(lib.files.read_lines, file)
    if not success then
        return nil
    end
    local line = lines[1]
    return vim.startswith(line, "package") and vim.split(line, " ")[2] or ""
end

---@param position neotest.Position The position to return an ID for
---@param parents neotest.Position[] Parent positions for the position
---@return string
local function build_position_id(position, parents)
    ---@param pos neotest.Position
    local get_parent_name = function(pos)
        if pos.type == "dir" or pos.type == "file" then
            return ""
        end
        if pos.type == "namespace" then
            return get_package_name(pos.path) .. "." .. pos.name
        end
        return get_position_name(pos)
    end
    return table.concat(
        vim.tbl_flatten({
            vim.tbl_map(get_parent_name, parents),
            get_position_name(position),
        }),
        "."
    )
end

---@async
---@return neotest.Tree | nil
function ScalaNeotestAdapter.discover_positions(path)
    local query = [[
	  (object_definition
	   name: (identifier) @namespace.name)
	   @namespace.definition
	  
      ((call_expression
        function: (call_expression
        function: (identifier) @func_name (#match? @func_name "test")
        arguments: (arguments (string) @test.name))
      )) @test.definition
    ]]
    return lib.treesitter.parse_positions(
        path,
        query,
        { nested_tests = true, require_namespaces = true, position_id = build_position_id }
    )
end

local function get_runner()
    local vim_test_runner = vim.g["test#scala#runner"]
    if vim_test_runner == "blooptest" then
        return "bloop"
    end
    if vim_test_runner and lib.func_util.index({ "bloop", "sbt" }, vim_test_runner) then
        return vim_test_runner
    end
    return "bloop"
end

local get_args = function()
    return {}
end

---Get project name from build file.
---@return string|nil
local function get_project_name(path)
    local root = ScalaNeotestAdapter.root(path)
    local build_file = root .. "/build.sbt"
    local success, lines = pcall(lib.files.read_lines, build_file)
    if not success then
        return nil
    end
    for _, line in ipairs(lines) do
        local project = line:match('name := "(.+)"')
        if project then
            return project
        end
    end
    return nil
end

-- Builds a test path from the current position in the tree.
---@param tree neotest.Tree
---@param name string
---@return string|nil
local function build_test_path(tree, name)
    local parent_tree = tree:parent()
    local type = tree:data().type
    if parent_tree and parent_tree:data().type == "namespace" then
        local package = get_package_name(parent_tree:data().path)
        local parent_name = parent_tree:data().name
        return package .. "." .. parent_name .. "." .. name
    end
    if parent_tree and parent_tree:data().type == "test" then
        local parent_pos = parent_tree:data()
        return build_test_path(parent_tree, get_position_name(parent_pos)) .. "." .. name
    end
    if type == "namespace" then
        local package = get_package_name(tree:data().path)
        if not package then
            return nil
        end
        return package .. "." .. name
    end
    if type == "file" then
        local test_suites = {}
        for _, child in tree:iter_nodes() do
            if child:data().type == "namespace" then
                table.insert(test_suites, child:data().name)
            end
        end
        if test_suites then
            local package = get_package_name(tree:data().path)
            return package .. "." .. "{" .. table.concat(test_suites, ",") .. "}"
        end
    end
    if type == "dir" then
        local packages = {}
        local visited = {}
        for _, child in tree:iter_nodes() do
            if child:data().type == "namespace" then
                local package = get_package_name(child:data().path)
                if package and not visited[package] then
                    table.insert(packages, package)
                    visited[package] = true
                end
            end
        end
        if packages then
            return "{" .. table.concat(packages, ",") .. "}"
        end
    end
    return nil
end

---@param project string
---@param runner string
---@param test_path string|nil
---@param extra_args table|string
---@return string[]
local function build_command(project, runner, test_path, extra_args)
    if runner == "bloop" then
        local full_test_path
        if not test_path then
            full_test_path = {}
        else
            full_test_path = { "--", test_path }
        end
        return vim.tbl_flatten({ "bloop", "test", extra_args, project, full_test_path })
    end
    if not test_path then
        return vim.tbl_filter({ "sbt", extra_args, project .. "/test" })
    end
    return vim.tbl_flatten({
        "sbt",
        extra_args,
        project .. "/testOnly -- " .. '"' .. test_path .. '"',
    })
end

---@async
---@param args neotest.RunArgs
---@return neotest.RunSpec
function ScalaNeotestAdapter.build_spec(args)
    local position = args.tree:data()
    local project = get_project_name(position.path)
    assert(project, "scala project not found in the build file")
    local runner = get_runner()
    assert(lib.func_util.index({ "bloop", "sbt" }, runner), "set sbt or bloop runner")
    local test_path = build_test_path(args.tree, get_position_name(position))
    local extra_args = vim.list_extend(get_args(), args.extra_args or {})
    -- TODO: Add support for nvim-dap strategy.
    local command = build_command(project, runner, test_path, extra_args)
    return { command = command }
end

---Extract results from the test output.
---@param tree neotest.Tree
---@param test_results table<string, string>
---@return table<string, neotest.Result>
local function get_results(tree, test_results)
    local no_results = vim.tbl_isempty(test_results)
    local results = {}
    for _, node in tree:iter_nodes() do
        local position = node:data()
        if no_results then
            results[position.id] = { status = TEST_FAILED }
        else
            local test_result = test_results[position.id]
            if test_result then
                results[position.id] = { status = test_result }
            end
        end
    end
    return results
end

---Get test ID from the test line output.
---@param output string
---@return string
local function get_test_id(output)
    local words = vim.split(output, " ", { trimempty = true })
    -- Strip the test success indicator prefix and time taken in ms suffix.
    table.remove(words, 1)
    table.remove(words)
    return table.concat(words, " ")
end

--- Strip ainsi characters from the string, leaving the rest of the string intact.
---@param s string
---@return string
local function strip_ainsi_chars(s)
    local v = s:gsub("\x1b%[%d+;%d+;%d+;%d+;%d+m", "")
        :gsub("\x1b%[%d+;%d+;%d+;%d+m", "")
        :gsub("\x1b%[%d+;%d+;%d+m", "")
        :gsub("\x1b%[%d+;%d+m", "")
        :gsub("\x1b%[%d+m", "")
    return v
end

-- Get test results from the test output.
---@param output_lines string[]
---@return table<string, string>
local function get_test_results(output_lines)
    local test_results = {}
    for _, line in ipairs(output_lines) do
        line = strip_ainsi_chars(line)
        if vim.startswith(line, "+") then
            local test_id = get_test_id(line)
            test_results[test_id] = TEST_PASSED
        elseif vim.startswith(line, "X") then
            local test_id = get_test_id(line)
            test_results[test_id] = TEST_FAILED
        end
    end
    return test_results
end

---@async
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return table<string, neotest.Result>
function ScalaNeotestAdapter.results(_, result, tree)
    local success, lines = pcall(lib.files.read_lines, result.output)
    if not success then
        return {}
    end
    local test_results = get_test_results(lines)
    return get_results(tree, test_results)
end

local is_callable = function(obj)
    return type(obj) == "function" or (type(obj) == "table" and obj.__call)
end

setmetatable(ScalaNeotestAdapter, {
    __call = function(_, opts)
        if is_callable(opts.args) then
            get_args = opts.args
        elseif opts.args then
            get_args = function()
                return opts.args
            end
        end
        if is_callable(opts.runner) then
            get_runner = opts.runner
        elseif opts.runner then
            get_runner = function()
                return opts.runner
            end
        end
        return ScalaNeotestAdapter
    end,
})

return ScalaNeotestAdapter
