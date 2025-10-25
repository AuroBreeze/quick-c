local M = {}

local U = require('quick-c.util')

-- 项目配置文件名称
M.CONFIG_FILE_NAME = ".quick-c.json"

-- 从项目根目录查找配置文件
function M.find_project_config(start_path)
    local dir = start_path or vim.fn.getcwd()
    if not dir or dir == "" then return nil end
    local config_path = U.join(dir, M.CONFIG_FILE_NAME)
    if vim.fn.filereadable(config_path) == 1 then
        return config_path
    end
    return nil
end

-- 读取并解析项目配置文件
function M.load_project_config(config_path)
    if not config_path then
        return nil
    end

    -- 检查文件是否存在且可读
    if vim.fn.filereadable(config_path) ~= 1 then
        return nil
    end

    local ok, content = pcall(vim.fn.readfile, config_path)
    if not ok or not content or #content == 0 then
        U.notify_warn("无法读取项目配置文件: " .. config_path)
        return nil
    end

    local json_str = table.concat(content, "\n")

    -- 处理 UTF-8 BOM
    local bom = string.char(0xEF, 0xBB, 0xBF)
    if json_str:sub(1, 3) == bom then
        json_str = json_str:sub(4)
    end

    -- 检查 JSON 内容是否为空
    if json_str:match("^%s*$") then
        U.notify_warn("项目配置文件为空: " .. config_path)
        return nil
    end

    -- 使用可用的 JSON 解码器解析（优先 vim.json.decode，其次 vim.fn.json_decode）
    local decoder
    if vim and vim.json and type(vim.json.decode) == 'function' then
        decoder = vim.json.decode
    elseif vim and vim.fn and type(vim.fn.json_decode) == 'function' then
        decoder = vim.fn.json_decode
    end
    if not decoder then
        U.notify_warn("未找到 JSON 解析器，无法加载项目配置")
        return nil
    end

    local ok, config = pcall(decoder, json_str)
    if not ok then
        U.notify_warn("项目配置文件格式错误: " .. config_path)
        return nil
    end

    -- 检查配置是否为有效表
    if type(config) ~= "table" then
        U.notify_warn("项目配置文件内容无效: " .. config_path)
        return nil
    end

    return config
end

-- 合并项目配置到主配置
function M.merge_project_config(main_config, project_config)
    if not project_config or type(project_config) ~= "table" then
        return main_config
    end

    -- 深度合并配置
    local merged = vim.tbl_deep_extend("force", main_config, project_config)

    -- 记录配置合并信息（用于调试）
    if vim.g.quick_c_debug then
        U.notify_info("项目配置已合并: " .. vim.inspect(project_config))
    end

    return merged
end

-- 获取当前项目的配置（基于当前文件或工作目录）
function M.get_current_project_config()
    local start_path = vim.fn.getcwd()

    local config_path = M.find_project_config(start_path)
    if not config_path then
        return nil
    end

    -- 记录找到的配置文件路径（用于调试）
    if vim.g.quick_c_debug then
        U.notify_info("找到项目配置文件: " .. config_path)
    end

    return M.load_project_config(config_path)
end

-- 初始化项目配置支持
function M.setup(main_config)
    local project_config = M.get_current_project_config()
    if project_config then
        U.notify_info("已加载项目配置文件")
        local merged_config = M.merge_project_config(main_config, project_config)

        -- 验证合并后的配置
        if type(merged_config) ~= "table" then
            U.notify_warn("配置合并失败，使用默认配置")
            return main_config
        end

        return merged_config
    end

    -- 未找到项目配置文件时返回 nil，方便调用方判断
    return nil
end

return M
