local U = {}

function U.is_windows()
  return vim.fn.has('win32') == 1
end

function U.is_powershell()
  local sh = (vim.o.shell or ''):lower()
  return sh:find('powershell') or sh:find('pwsh')
end

function U.join(a, b)
  if a:sub(-1) == '/' or a:sub(-1) == '\\' then return a .. b end
  local sep = U.is_windows() and '\\' or '/'
  return a .. sep .. b
end

function U.norm(p)
  p = vim.fn.fnamemodify(p, ':p')
  if U.is_windows() then
    p = p:gsub('\\', '/'):lower()
  else
    p = p:gsub('//+', '/')
  end
  if p:sub(-1) == '/' then p = p:sub(1, -2) end
  return p
end

function U.shell_quote_path(p)
  if U.is_windows() then
    if U.is_powershell() then
      return string.format("'%s'", p)
    else
      return string.format('"%s"', p)
    end
  else
    return string.format("'%s'", p)
  end
end

function U.notify_err(msg)
  vim.notify('Quick-c: ' .. msg, vim.log.levels.ERROR)
end
function U.notify_info(msg)
  vim.notify('Quick-c: ' .. msg, vim.log.levels.INFO)
end
function U.notify_warn(msg)
  vim.notify('Quick-c: ' .. msg, vim.log.levels.WARN)
end

return U
