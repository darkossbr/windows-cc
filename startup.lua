-- Windows 10 (CC Edition) -- ONE file. Save as /startup.lua and reboot.
-- Start menu (Games), Store (gist / pastebin / URL) and Groove Music included.
-- (Windows 10 reskin of the Fedora CC Edition: the old Fedora updater accepts this file too)
local ok, err = pcall(function()
local unpack = unpack or table.unpack
-- Windows 10 "CC Edition" -- core: display, themes, login, window manager, taskbar, audio engine
if not term.isColor() then print("This system needs an Advanced Computer (gold).") return end
local EMBED = {}
EMBED["files"] = (function()
return function(OS)
  local C = OS.C
  local app = { id = "files", title = "File Explorer", glyph = " F ", icon = "acc", fg = "wht", w = 46, h = 14, minw = 34, minh = 9 }

  local function refresh(win)
    local s = win.state
    local list = {}
    local ok, names = pcall(fs.list, s.path)
    if ok then
      for _, n in ipairs(names) do
        local full = fs.combine(s.path, n)
        local d = fs.isDir(full)
        list[#list + 1] = { name = n, dir = d, full = full, size = d and 0 or fs.getSize(full) }
      end
    end
    table.sort(list, function(a, b)
      if a.dir ~= b.dir then return a.dir end
      return a.name:lower() < b.name:lower()
    end)
    s.list = list; s.sel = nil; s.scroll = 0
  end

  function app.init(win, arg)
    win.state = { path = arg or "", msg = "" }
    refresh(win)
  end

  local function openEntry(win, e)
    local s = win.state
    if e.dir then s.path = e.full; refresh(win)
    elseif e.name:match("%.dfpwm$") then
      OS.audio.play({ { title = (e.name:gsub("%.dfpwm$", "")), artist = "Local file", path = "/" .. e.full } }, 1)
      OS.toast("Playing " .. e.name)
    else OS.open("editor", "/" .. e.full) end
  end

  local function commit(win)
    local s = win.state
    local name = s.input.f.text
    if name == "" then s.input = nil return end
    local full = fs.combine(s.path, name)
    if OS.isProtected(full) then s.msg = "Protected: /startup.lua is the OS"; s.input = nil return end
    local ok, err
    if fs.exists(full) then ok, err = false, "already exists"
    elseif s.input.kind == "dir" then ok, err = pcall(fs.makeDir, full)
    else
      ok, err = pcall(function() local f = fs.open(full, "w"); f.close() end)
    end
    s.msg = ok and ("Created " .. name) or tostring(err)
    s.input = nil
    refresh(win)
  end

  local function del(win)
    local s = win.state
    local e = s.list[s.sel or 0]
    if not e then s.msg = "Select something first" return end
    if OS.isProtected(e.full) then s.msg = "Protected: /startup.lua is the OS" return end
    if s.confirm ~= e.full then s.confirm = e.full; s.msg = "Click Del again to delete " .. e.name return end
    local ok, err = pcall(fs.delete, e.full)
    s.confirm = nil
    s.msg = ok and "Deleted" or tostring(err)
    refresh(win)
  end

  function app.draw(win, g)
    local s = win.state
    local w, h = g.w, g.h
    g.fill(1, 1, w, h, C.win)
    win.title = "File Explorer  /" .. s.path
    if s.input then
      g.put(1, 1, s.input.kind == "dir" and "Folder:" or "File:", C.sub, C.win)
      local lw = s.input.kind == "dir" and 8 or 7
      g.field(lw, 1, w - lw - 12, s.input.f)
      g.btn(w - 10, 1, "OK", function() commit(win) end, "pri")
      g.btn(w - 5, 1, "x", function() s.input = nil end)
    else
      g.btn(1, 1, "<", function()
        if s.path ~= "" then s.path = fs.getDir(s.path); refresh(win) end
      end)
      g.put(5, 1, OS.trunc("/" .. s.path, w - 22), C.text, C.win)
      local x = w - 16
      x = x + g.btn(x, 1, "New", function()
        s.input = { kind = "file", f = OS.field("", { max = 40 }) }; s.input.f.onEnter = function() commit(win) end; win.focus = s.input.f
      end) + 1
      x = x + g.btn(x, 1, "Dir", function()
        s.input = { kind = "dir", f = OS.field("", { max = 40 }) }; s.input.f.onEnter = function() commit(win) end; win.focus = s.input.f
      end) + 1
      g.btn(x, 1, "Del", function() del(win) end, s.confirm and "danger" or nil)
    end
    g.fill(1, 2, w, 1, C.bar)
    g.put(2, 2, "Name", C.sub, C.bar); g.put(w - 8, 2, "Size", C.sub, C.bar)
    local rows = h - 3
    local maxs = math.max(0, #s.list - rows)
    s.scroll = math.max(0, math.min(s.scroll, maxs))
    for r = 1, rows do
      local e = s.list[s.scroll + r]
      if not e then break end
      local sel = (s.scroll + r) == s.sel
      local bg = sel and C.acc or C.win
      g.fill(1, 2 + r, w, 1, bg)
      local nm = e.dir and (e.name .. "/") or e.name
      g.put(2, 2 + r, OS.trunc(nm, w - 12), sel and C.wht or (e.dir and C.acc or C.text), bg)
      if not e.dir then
        local sz = e.size < 1024 and (e.size .. "B") or string.format("%.1fK", e.size / 1024)
        g.put(w - #sz, 2 + r, sz, sel and C.wht or C.sub, bg)
      end
      local idx = s.scroll + r
      g.hot(1, 2 + r, w, 1, function()
        local now = os.clock()
        if s.sel == idx and s.lastClick and now - s.lastClick < 0.6 then openEntry(win, e) else s.sel = idx; s.confirm = nil end
        s.lastClick = now
      end)
    end
    g.scroll(1, 3, w, rows, function(dir) s.scroll = s.scroll + dir * 2 end)
    local free = fs.getFreeSpace("/")
    g.put(1, h, OS.trunc(s.msg ~= "" and s.msg or (#s.list .. " items"), w - 14), C.sub, C.win)
    local fr = string.format("%.0fK free", free / 1024)
    g.put(w - #fr + 1, h, fr, C.sub, C.win)
  end

  return app
end

end)()
EMBED["editor"] = (function()
return function(OS)
  local C = OS.C
  local app = { id = "editor", title = "Notepad", glyph = " E ", icon = "yel", fg = "sp0", w = 50, h = 15, minw = 30, minh = 8 }

  local KW = {}
  for w in ("and break do else elseif end false for function goto if in local nil not or repeat return then true until while"):gmatch("%a+") do KW[w] = true end

  local function colorize(line)
    local cols, i, n = {}, 1, #line
    while i <= n do
      local c = line:sub(i, i)
      if line:sub(i, i + 1) == "--" then
        for j = i, n do cols[j] = "sub" end
        break
      elseif c == '"' or c == "'" then
        local j = i + 1
        while j <= n and line:sub(j, j) ~= c do
          if line:sub(j, j) == "\\" then j = j + 1 end
          j = j + 1
        end
        for k = i, math.min(j, n) do cols[k] = "grn" end
        i = j + 1
      elseif c:match("[%a_]") then
        local w = line:match("^[%w_]+", i)
        local k = KW[w] and "acc" or "text"
        for j = i, i + #w - 1 do cols[j] = k end
        i = i + #w
      elseif c:match("%d") then
        cols[i] = "yel"; i = i + 1
      else i = i + 1 end
    end
    return cols
  end

  local function load(win, path)
    local s = win.state
    s.lines = { "" }
    if path and path ~= "" and fs.exists(path) and not fs.isDir(path) then
      local f = fs.open(path, "r")
      s.lines = {}
      for l in (f.readAll() .. "\n"):gmatch("(.-)\r?\n") do s.lines[#s.lines + 1] = l end
      f.close()
      if #s.lines > 1 and s.lines[#s.lines] == "" then s.lines[#s.lines] = nil end
      if #s.lines == 0 then s.lines = { "" } end
      s.msg = "Opened " .. path
    elseif path and path ~= "" then s.msg = "New file " .. path end
    s.cx, s.cy, s.top, s.left, s.dirty, s.follow = 1, 1, 1, 1, false, true
    s.path.text = path or ""; s.path.pos = #s.path.text
  end

  local function save(win)
    local s = win.state
    local p = s.path.text
    if p == "" then s.msg = "Enter a file name first"; win.focus = s.path return end
    if OS.isProtected(p) then s.msg = "Protected: /startup.lua is the OS - save under another name"; return end
    local ok, err = pcall(function()
      local f = fs.open(p, "w")
      if not f then error("cannot write " .. p) end
      f.write(table.concat(s.lines, "\n") .. "\n"); f.close()
    end)
    if ok then s.dirty = false; s.msg = "Saved " .. p else s.msg = tostring(err) end
  end

  function app.init(win, arg)
    local s = { msg = "" }
    win.state = s
    s.path = OS.field("", { max = 80 })
    s.path.onEnter = function() load(win, s.path.text) end
    load(win, arg)
  end
  function app.onOpen(win, arg) if arg then load(win, arg) end end

  local function insert(s, str)
    local l = s.lines[s.cy]
    s.lines[s.cy] = l:sub(1, s.cx - 1) .. str .. l:sub(s.cx)
    s.cx = s.cx + #str; s.dirty = true; s.follow = true
  end
  local function newline(s)
    local l = s.lines[s.cy]
    local indent = l:match("^%s*")
    local rest = l:sub(s.cx)
    s.lines[s.cy] = l:sub(1, s.cx - 1)
    table.insert(s.lines, s.cy + 1, indent .. rest)
    s.cy = s.cy + 1; s.cx = #indent + 1; s.dirty = true; s.follow = true
  end

  function app.char(win, c)
    if OS.mods.ctrl then return end
    insert(win.state, c)
  end
  function app.paste(win, text)
    local s = win.state
    text = text:gsub("\r", "")
    for i = 1, #text do
      local c = text:sub(i, i)
      if c == "\n" then newline(s) else insert(s, c) end
    end
  end

  function app.key(win, k)
    local s = win.state
    local l = s.lines[s.cy]
    s.follow = true
    if OS.mods.ctrl and k == keys.s then save(win) return end
    if k == keys.up then if s.cy > 1 then s.cy = s.cy - 1; s.cx = math.min(s.cx, #s.lines[s.cy] + 1) end
    elseif k == keys.down then if s.cy < #s.lines then s.cy = s.cy + 1; s.cx = math.min(s.cx, #s.lines[s.cy] + 1) end
    elseif k == keys.left then
      if s.cx > 1 then s.cx = s.cx - 1 elseif s.cy > 1 then s.cy = s.cy - 1; s.cx = #s.lines[s.cy] + 1 end
    elseif k == keys.right then
      if s.cx <= #l then s.cx = s.cx + 1 elseif s.cy < #s.lines then s.cy = s.cy + 1; s.cx = 1 end
    elseif k == keys.home then s.cx = 1
    elseif k == keys["end"] then s.cx = #l + 1
    elseif k == keys.pageUp then s.cy = math.max(1, s.cy - 8); s.cx = math.min(s.cx, #s.lines[s.cy] + 1)
    elseif k == keys.pageDown then s.cy = math.min(#s.lines, s.cy + 8); s.cx = math.min(s.cx, #s.lines[s.cy] + 1)
    elseif k == keys.enter or k == keys.numPadEnter then newline(s)
    elseif k == keys.tab then insert(s, "  ")
    elseif k == keys.backspace then
      if s.cx > 1 then s.lines[s.cy] = l:sub(1, s.cx - 2) .. l:sub(s.cx); s.cx = s.cx - 1; s.dirty = true
      elseif s.cy > 1 then
        local prev = s.lines[s.cy - 1]
        s.lines[s.cy - 1] = prev .. l; table.remove(s.lines, s.cy)
        s.cy = s.cy - 1; s.cx = #prev + 1; s.dirty = true
      end
    elseif k == keys.delete then
      if s.cx <= #l then s.lines[s.cy] = l:sub(1, s.cx - 1) .. l:sub(s.cx + 1); s.dirty = true
      elseif s.cy < #s.lines then s.lines[s.cy] = l .. s.lines[s.cy + 1]; table.remove(s.lines, s.cy + 1); s.dirty = true end
    end
  end

  function app.draw(win, g)
    local s = win.state
    local w, h = g.w, g.h
    g.fill(1, 1, w, h, C.win)
    local name = s.path.text ~= "" and fs.getName(s.path.text) or "untitled"
    win.title = "Text Editor - " .. name .. (s.dirty and " *" or "")
    g.field(1, 1, w - 14, s.path)
    g.btn(w - 12, 1, "Open", function() load(win, s.path.text) end)
    g.btn(w - 6, 1, "Save", function() save(win) end, "pri")
    local gw = math.max(3, #tostring(#s.lines)) + 1
    local vh, vw = h - 2, w - gw
    if s.follow then
      if s.cy < s.top then s.top = s.cy end
      if s.cy > s.top + vh - 1 then s.top = s.cy - vh + 1 end
      if s.cx < s.left then s.left = s.cx end
      if s.cx > s.left + vw - 2 then s.left = s.cx - vw + 2 end
      s.follow = false
    end
    s.top = math.max(1, math.min(s.top, math.max(1, #s.lines)))
    for r = 1, vh do
      local li = s.top + r - 1
      local y = 1 + r
      local line = s.lines[li]
      g.put(1, y, string.format("%" .. (gw - 1) .. "d ", li), C.sub, C.bar)
      if not line then
        g.fill(gw + 1, y, vw, 1, C.win)
      else
        g.fill(gw + 1, y, vw, 1, C.win)
        local cols = colorize(line)
        local x, i = gw + 1, s.left
        local n = #line
        while i <= n and x <= w do
          local col = cols[i] or "text"
          local j = i
          while j + 1 <= n and (cols[j + 1] or "text") == col and (j - i) < vw do j = j + 1 end
          g.put(x, y, line:sub(i, j), C[col], C.win)
          x = x + (j - i + 1); i = j + 1
        end
      end
    end
    g.hot(gw + 1, 2, vw, vh, function(rx, ry)
      s.cy = math.max(1, math.min(#s.lines, s.top + ry - 2))
      s.cx = math.max(1, math.min(#s.lines[s.cy] + 1, s.left + rx - gw - 1))
    end)
    g.scroll(1, 2, w, vh, function(dir) s.top = math.max(1, math.min(#s.lines, s.top + dir * 3)) end)
    g.fill(1, h, w, 1, C.bar)
    g.put(2, h, OS.trunc(s.msg, w - 18), C.sub, C.bar)
    local pos = "Ln " .. s.cy .. ", Col " .. s.cx
    g.put(w - #pos, h, pos, C.text, C.bar)
    if not win.focus then g.cursor(gw + s.cx - s.left + 1, 2 + s.cy - s.top) end
  end

  return app
end

end)()
EMBED["terminal"] = (function()
return function(OS)
  local C = OS.C
  local app = { id = "terminal", title = "Command Prompt", glyph = ">_ ", icon = "sp0", fg = "wht", w = 52, h = 14, minw = 30, minh = 7 }

  local function out(s, text, col)
    for _, l in ipairs(OS.wrap(tostring(text), s.width or 40)) do
      s.lines[#s.lines + 1] = { l, col or "text" }
    end
    while #s.lines > 300 do table.remove(s.lines, 1) end
  end

  local function resolve(s, p)
    if p:sub(1, 1) == "/" then return OS.fsp(fs.combine(p, "")) end
    return OS.fsp(fs.combine(s.cwd, p))
  end

  local cmds = {}
  local function ps(s) return "C:\\" .. ((s.cwd or ""):gsub("/", "\\")) .. ">" end
  local function tcol(n) if n == "text" or n == "sub" or n == "sp" then return C.wht end return C[n] or C.wht end
  function cmds.help(s)
    out(s, "dir cd cls type md del copy move ren echo notepad ver date", "sub")
    out(s, "whoami hostname systeminfo open <app> lua play restart shutdown exit", "sub")
    out(s, "(ls cat rm cp mv mkdir touch edit clear pwd also work)", "sub")
  end
  function cmds.ls(s, a)
    local p = resolve(s, a[1] or "")
    if not fs.isDir(p) then out(s, "ls: not a directory", "red") return end
    for _, n in ipairs(fs.list(p)) do
      out(s, fs.isDir(fs.combine(p, n)) and (n .. "/") or n, fs.isDir(fs.combine(p, n)) and "acc" or "text")
    end
  end
  function cmds.cd(s, a)
    local p = resolve(s, a[1] or "")
    if fs.isDir(p) then s.cwd = p else out(s, "cd: no such directory", "red") end
  end
  function cmds.pwd(s) out(s, "/" .. s.cwd) end
  function cmds.cat(s, a)
    local p = resolve(s, a[1] or "")
    if not fs.exists(p) or fs.isDir(p) then out(s, "cat: no such file", "red") return end
    local f = fs.open(p, "r"); local d = f.readAll(); f.close(); out(s, d)
  end
  function cmds.mkdir(s, a) local ok, e = pcall(fs.makeDir, resolve(s, a[1] or "")); if not ok then out(s, tostring(e), "red") end end
  function cmds.touch(s, a)
    local p = resolve(s, a[1] or "")
    if not fs.exists(p) then local f = fs.open(p, "w"); if f then f.close() end end
  end
  function cmds.rm(s, a) local ok, e = pcall(fs.delete, resolve(s, a[1] or "")); if not ok then out(s, tostring(e), "red") end end
  function cmds.cp(s, a) local ok, e = pcall(fs.copy, resolve(s, a[1] or ""), resolve(s, a[2] or "")); if not ok then out(s, tostring(e), "red") end end
  function cmds.mv(s, a) local ok, e = pcall(fs.move, resolve(s, a[1] or ""), resolve(s, a[2] or "")); if not ok then out(s, tostring(e), "red") end end
  function cmds.echo(s, a) out(s, table.concat(a, " ")) end
  function cmds.clear(s) s.lines = {} end
  function cmds.edit(s, a) OS.open("editor", "/" .. resolve(s, a[1] or "")) end
  function cmds.play(s, a)
    local p = resolve(s, a[1] or "")
    if not fs.exists(p) then out(s, "play: no such file", "red") return end
    OS.audio.play({ { title = fs.getName(p), artist = "Terminal", path = "/" .. p } }, 1)
    out(s, "Playing " .. fs.getName(p), "sp")
  end
  function cmds.open(s, a)
    if OS.apps[a[1] or ""] then OS.open(a[1]) else out(s, "open: unknown app (files terminal editor music calc settings)", "red") end
  end
  function cmds.date(s) out(s, "Day " .. os.day() .. ", " .. OS.clockStr()) end
  function cmds.uname(s) out(s, OS.verName() .. " (CC Edition) " .. os.version()) end
  function cmds.whoami(s) out(s, OS.cfg.user or "user") end
  function cmds.df(s) out(s, string.format("/  %dK free of %dK", math.floor(fs.getFreeSpace("/") / 1024), math.floor(fs.getCapacity("/") / 1024))) end
  function cmds.reboot() os.reboot() end
  function cmds.shutdown() os.shutdown() end
  function cmds.lua(s, a)
    local p = resolve(s, a[1] or "")
    if not fs.exists(p) then out(s, "lua: no such file", "red") return end
    local env = setmetatable({ print = function(...)
      local t = {}
      for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
      out(s, table.concat(t, "\t"))
    end, write = function(x) out(s, tostring(x)) end }, { __index = _G })
    env.fs, env.io, env.shell = OS.guardFs(), OS.guardIo(), OS.guardShell(shell)
    local fn, err = loadfile(p, nil, env)
    if not fn then out(s, tostring(err), "red") return end
    local ok, e = pcall(fn, unpack(a, 2))
    if not ok then out(s, tostring(e), "red") end
  end
  function cmds.systeminfo(s)
    local up = math.floor(os.clock())
    local info = {
      "Host Name:   " .. (OS.cfg.host or "DESKTOP-CC"),
      "OS Name:     " .. OS.verName() .. " (CC Edition)",
      "User:        " .. (OS.cfg.user or "user"),
      "CraftOS:     " .. tostring(os.version()):gsub("^CraftOS ", ""),
      "Up Time:     " .. math.floor(up / 60) .. "m " .. (up % 60) .. "s",
      "Theme:       " .. OS.cfg.theme .. (OS.cfg.darker and " (darker)" or ""),
      "Speakers:    " .. #OS.audio.speakers,
    }
    local logo = { " #####  ##### ", " #####  ##### ", " #####  ##### ", "               ", " #####  ##### ", " #####  ##### ", " #####  ##### " }
    for i = 1, 7 do out(s, logo[i], "acc") end
    out(s, "")
    for _, l in ipairs(info) do out(s, l, "wht") end
  end
  cmds.neofetch = cmds.systeminfo
  function cmds.ver(s) out(s, "Windows 10 [CC Edition, " .. os.version() .. "]", "wht") end
  function cmds.hostname(s) out(s, OS.cfg.host or "DESKTOP-CC", "wht") end
  cmds.dir = cmds.ls; cmds.cls = cmds.clear; cmds.type = cmds.cat; cmds.md = cmds.mkdir
  cmds.del = cmds.rm; cmds.erase = cmds.rm; cmds.copy = cmds.cp; cmds.move = cmds.mv
  cmds.ren = cmds.mv; cmds.rename = cmds.mv; cmds.notepad = cmds.edit; cmds.restart = cmds.reboot

  local function run(win, line)
    local s = win.state
    out(s, ps(s) .. line, "wht")
    if line == "" then return end
    s.hist[#s.hist + 1] = line; s.hi = #s.hist + 1
    local a = {}
    for w in line:gmatch("%S+") do
      if #a > 0 then w = w:gsub("\\", "/"):gsub("^[Cc]:", "") end
      a[#a + 1] = w
    end
    local c = table.remove(a, 1)
    local cmdPart, restPart = c:match("^([^\\]+)\\(.*)$")
    if cmdPart then c = cmdPart; table.insert(a, 1, "/" .. (restPart:gsub("\\", "/"))) end
    c = c:lower()
    if c == "exit" then OS.close(win) return end
    if cmds[c] then
      local ok, e = pcall(cmds[c], s, a)
      if not ok then out(s, tostring(e), "red") end
    else out(s, c .. ": command not found", "red") end
  end

  function app.init(win)
    local s = { lines = {}, cwd = "", hist = {}, hi = 1, width = 40 }
    win.state = s
    s.f = OS.field("", {})
    s.f.onEnter = function(f)
      local t = f.text; f.text = ""; f.pos = 0
      run(win, t)
    end
    s.f.onKey = function(f, k)
      if k == keys.up and #s.hist > 0 then s.hi = math.max(1, s.hi - 1); f.text = s.hist[s.hi]; f.pos = #f.text; return true
      elseif k == keys.down then
        s.hi = math.min(#s.hist + 1, s.hi + 1); f.text = s.hist[s.hi] or ""; f.pos = #f.text; return true
      end
    end
    win.keepFocus = s.f; win.focus = s.f
    out(s, "Windows 10 [CC Edition, " .. os.version() .. "]", "wht"); out(s, "Type 'help' for the list of commands.", "wht"); out(s, "")
  end

  function app.draw(win, g)
    local s = win.state
    local w, h = g.w, g.h
    s.width = w
    g.fill(1, 1, w, h, C.sp0)
    local rows = h - 1
    local first = math.max(1, #s.lines - rows + 1 - (s.back or 0))
    for r = 1, rows do
      local l = s.lines[first + r - 1]
      if l then g.put(1, r, l[1], tcol(l[2]), C.sp0) end
    end
    local prompt = ps(s)
    prompt = OS.trunc(prompt, math.floor(w / 2))
    g.put(1, h, prompt, C.wht, C.sp0)
    g.field(#prompt + 1, h, w - #prompt, s.f, { bg = C.sp0, fg = C.wht })
    g.scroll(1, 1, w, h, function(dir) s.back = math.max(0, (s.back or 0) - dir * 2) end)
  end

  return app
end

end)()
EMBED["calc"] = (function()
return function(OS)
  local C = OS.C
  local app = { id = "calc", title = "Calculator", glyph = " = ", icon = "red", fg = "wht", w = 28, h = 14, single = true, minw = 28, minh = 14 }

  local layout = {
    { "C", "+/-", "%", "/" },
    { "7", "8", "9", "*" },
    { "4", "5", "6", "-" },
    { "1", "2", "3", "+" },
    { "0", ".", "<", "=" },
  }

  local function fmt(n)
    if n == math.floor(n) and math.abs(n) < 1e12 then return string.format("%d", n) end
    local s = string.format("%.10g", n)
    return s
  end

  local function compute(a, op, b)
    if op == "+" then return a + b elseif op == "-" then return a - b
    elseif op == "*" then return a * b
    elseif op == "/" then if b == 0 then return nil end return a / b end
    return b
  end

  local function press(s, k)
    if s.err and k ~= "C" then s.err = nil; s.disp = "0"; s.acc = nil; s.op = nil end
    if k:match("^%d$") then
      if s.fresh then s.disp = k; s.fresh = false
      else s.disp = (s.disp == "0") and k or (#s.disp < 14 and s.disp .. k or s.disp) end
    elseif k == "." then
      if s.fresh then s.disp = "0."; s.fresh = false elseif not s.disp:find("%.") then s.disp = s.disp .. "." end
    elseif k == "C" then s.disp = "0"; s.acc = nil; s.op = nil; s.fresh = false; s.err = nil
    elseif k == "<" then
      if not s.fresh then s.disp = #s.disp > 1 and s.disp:sub(1, -2) or "0"; if s.disp == "-" then s.disp = "0" end end
    elseif k == "+/-" then
      if s.disp ~= "0" then s.disp = s.disp:sub(1, 1) == "-" and s.disp:sub(2) or "-" .. s.disp end
    elseif k == "%" then s.disp = fmt((tonumber(s.disp) or 0) / 100); s.fresh = true
    elseif k == "=" or k == "+" or k == "-" or k == "*" or k == "/" then
      local cur = tonumber(s.disp) or 0
      if s.acc and s.op and not s.fresh then
        local r = compute(s.acc, s.op, cur)
        if r == nil then s.err = true; s.disp = "Cannot divide by 0"; s.acc = nil; s.op = nil; return end
        s.acc = r; s.disp = fmt(r)
      else s.acc = cur end
      if k == "=" then s.op = nil; s.acc = nil else s.op = k end
      s.fresh = true
    end
  end

  function app.init(win) win.state = { disp = "0" } end

  function app.char(win, c)
    local s = win.state
    if c:match("^[%d%.%+%-%*/%%]$") then press(s, c)
    elseif c == "=" then press(s, "=")
    elseif c == "c" or c == "C" then press(s, "C") end
  end
  function app.key(win, k)
    if k == keys.enter or k == keys.numPadEnter then press(win.state, "=")
    elseif k == keys.backspace then press(win.state, "<") end
  end

  function app.draw(win, g)
    local s = win.state
    local w, h = g.w, g.h
    g.fill(1, 1, w, h, C.win)
    g.fill(1, 1, w, 3, C.sp0)
    local ind = s.op and (fmt(s.acc or 0) .. " " .. s.op) or ""
    g.put(w - #ind - 1, 1, ind, C.sub, C.sp0)
    local d = OS.trunc(s.disp, w - 2)
    g.put(w - #d - 1, 2, d, s.err and C.red or C.wht, C.sp0)
    local bw = math.floor((w - 1) / 4)
    for r, row in ipairs(layout) do
      for c, key in ipairs(row) do
        local x, y = 1 + (c - 1) * bw + 1, 4 + (r - 1) * 2
        local isOp = key:match("^[%+%-%*/=]$")
        local bg, fg = C.bar, C.text
        if isOp then bg, fg = C.acc, C.wht elseif key == "C" or key == "+/-" or key == "%" then bg, fg = C.sub, C.sp0 end
        local label = key
        local pad = bw - 2
        local lx = x + math.floor((pad - #label) / 2)
        g.fill(x, y, pad, 1, bg)
        g.put(lx, y, label, fg, bg)
        g.hot(x, y, pad, 1, function() press(s, key) end)
      end
    end
  end

  return app
end

end)()
EMBED["settings"] = (function()
return function(OS)
  local C = OS.C
  local cfg = OS.cfg
  local app = { id = "settings", title = "Settings", glyph = " S ", icon = "sub", fg = "sp0", w = 58, h = 17, single = true, minw = 44, minh = 14 }
  local pages = { { "appearance", "Personalize" }, { "dock", "Taskbar" }, { "launchpad", "Start" }, { "display", "Display" }, { "layout", "Layout" },
    { "wifi", "Wi-Fi" }, { "controller", "Controller" }, { "time", "Time" }, { "sound", "Sound" }, { "music", "Music" }, { "security", "Security" }, { "about", "About" } }
  local scales = { 0.5, 1, 1.5, 2, 2.5, 3, 4, 5 }

  function app.init(win, arg)
    local s = { page = arg or "appearance", msg = "" }
    win.state = s
    s.f = {
      cur = OS.field("", { mask = true, max = 40 }), new1 = OS.field("", { mask = true, max = 40 }), new2 = OS.field("", { mask = true, max = 40 }),
      conv = OS.field(cfg.music.converter or "", { placeholder = "https://host/path?v=%s" }),
      api = OS.field((cfg.music.search[1] or {}).url or ""),
      host = OS.field(os.getComputerLabel() or cfg.host or "DESKTOP-CC", { max = 16 }),
      city = OS.field(cfg.city or "", { max = 24, placeholder = "city for weather" }),
    }
  end
  function app.onOpen(win, arg) if arg then win.state.page = arg; win.state.msg = "" end end

  local function applyPw(s)
    local hasPw = cfg.hash ~= nil
    if hasPw and OS.hashPw(s.f.cur.text, cfg.salt) ~= cfg.hash then s.msg = "Current password is wrong" return end
    if s.f.new1.text ~= s.f.new2.text then s.msg = "New passwords don't match" return end
    if s.f.new1.text == "" then
      if hasPw then cfg.hash = nil; cfg.salt = nil; s.msg = "Password removed" else s.msg = "Type a new password" return end
    elseif #s.f.new1.text < 4 then s.msg = "Use at least 4 characters" return
    else
      cfg.salt = OS.newSalt(); cfg.hash = OS.hashPw(s.f.new1.text, cfg.salt); s.msg = "Password updated"
    end
    OS.save()
    for _, f in pairs({ s.f.cur, s.f.new1, s.f.new2 }) do f.text = ""; f.pos = 0 end
  end

  local function section(g, x, y, text) g.put(x, y, text, C.sub, C.win) end

  local function apUnlock(win)
    local s = win.state
    local t = s.apPw.text
    if OS.hashPw(t, cfg.apSalt) ~= cfg.apHash then s.apMsg = "Wrong password"; OS.sfx("error"); s.apPw.text = ""; s.apPw.pos = 0; return end
    s.apOK = true; s.apMsg = ""; s.apPw.text = ""; s.apPw.pos = 0
  end

  local function drawAppearance(win, g, x, w)
    local s = win.state
    -- locked with a password: nothing here can be changed until it is entered
    if cfg.apHash and not s.apOK then
      s.apPw = s.apPw or OS.field("", { mask = true, max = 40 })
      s.apPw.onEnter = function() apUnlock(win) end
      if not s.apFocus then s.apFocus = true; win.focus = s.apPw end
      section(g, x, 1, "Appearance is locked")
      g.put(x, 3, "Enter the appearance password to change the theme,", C.sub, C.win)
      g.put(x, 4, "wallpaper or colours.", C.sub, C.win)
      g.field(x, 6, math.max(8, w - 14), s.apPw, { bg = C.bar })
      g.btn(x + math.max(8, w - 14) + 1, 6, "Unlock", function() apUnlock(win) end, "pri")
      if s.apMsg and s.apMsg ~= "" then g.put(x, 8, OS.trunc(s.apMsg, w), C.red, C.win) end
      return
    end
    section(g, x, 1, "Accent theme")
    local ncol = (w >= 44) and 4 or 3
    local colw = math.floor(w / ncol)
    local rows = math.ceil(#OS.THEMES / ncol)
    for i, t in ipairs(OS.THEMES) do
      local cx = x + ((i - 1) % ncol) * colw
      local cy = 2 + math.floor((i - 1) / ncol)
      local on = cfg.theme == t.name
      g.put(cx, cy, on and "* " or "  ", C.acc, C.win)
      g.put(cx + 2, cy, OS.trunc(t.name, colw - 3), on and C.acc or C.text, C.win)
      g.hot(cx, cy, colw - 1, 1, function() cfg.theme = t.name; OS.applyTheme(); OS.save() end)
    end
    local ty = 2 + rows
    section(g, x, ty, "Wallpaper")
    local bx = x
    for i, n in ipairs(OS.WALLS) do
      bx = bx + g.btn(bx, ty + 1, n, function() cfg.wall = i; OS.wallCache = nil; OS.applyTheme(); OS.save() end, cfg.wall == i and "pri" or nil) + 1
    end
    -- a picture from the internet
    s.wurl = s.wurl or OS.field(cfg.wallUrl or "", { placeholder = "picture link (https://...)", max = 400 })
    s.wurl.onEnter = function()
      s.wmsg = "Downloading..."; s.wbad = false
      OS.setWallImage(s.wurl.text, function(ok, msg) s.wmsg = msg; s.wbad = not ok end)
    end
    local fw = math.max(8, w - 12)
    g.field(x, ty + 2, fw, s.wurl, { bg = C.bar })
    g.btn(x + fw + 1, ty + 2, "Set", function() s.wurl.onEnter() end, "pri")
    if s.wmsg and s.wmsg ~= "" then g.put(x, ty + 3, OS.trunc(s.wmsg, w), s.wbad and C.red or C.grn, C.win)
    else g.put(x, ty + 3, "Any image link (png, jpg, gif, webp) is resized for you", C.sub, C.win) end
    g.put(x, ty + 4, "Darker mode", C.text, C.win)
    g.toggle(x + w - 6, ty + 4, cfg.darker, function() cfg.darker = not cfg.darker; OS.applyTheme(); OS.save() end)
    g.btn(x, ty + 5, "Personalization...", function() OS.open("themes") end, "pri")
    g.put(x + 20, ty + 5, OS.trunc("custom themes", w - 20), C.sub, C.win)
    -- password for this page
    s.apNew = s.apNew or OS.field("", { mask = true, max = 40, placeholder = cfg.apHash and "new password (empty = remove)" or "set a password" })
    local pw = math.max(8, w - 22)
    g.field(x, ty + 6, pw, s.apNew, { bg = C.bar })
    local bx2 = x + pw + 1
    bx2 = bx2 + g.btn(bx2, ty + 6, cfg.apHash and "Change" or "Set", function()
      local t = s.apNew.text
      if t == "" then
        if cfg.apHash then cfg.apHash = nil; cfg.apSalt = nil; OS.save(); s.apMsg2 = "Password removed" else s.apMsg2 = "Type a password first" end
      elseif #t < 4 then s.apMsg2 = "Use at least 4 characters"
      else cfg.apSalt = OS.newSalt(); cfg.apHash = OS.hashPw(t, cfg.apSalt); OS.save(); s.apMsg2 = "Password set"; s.apOK = true end
      s.apNew.text = ""; s.apNew.pos = 0; s.apNew = nil
    end, "dark") + 1
    if cfg.apHash then g.btn(bx2, ty + 6, "Lock", function() s.apOK = false; s.apFocus = false end, "dark") end
    if s.apMsg2 and s.apMsg2 ~= "" then g.put(x, ty + 7, OS.trunc(s.apMsg2, w), C.sub, C.win) end
  end

  local function drawSound(win, g, x, w)
    local sn = cfg.snd
    local rows = { { "System sounds (boot, clicks, windows)", "sys" }, { "Game sound effects", "sfx" },
      { "Music and theme songs", "music" }, { "Desktop ambient music", "amb" } }
    for i, r in ipairs(rows) do
      g.put(x, i * 2 - 1, OS.trunc(r[1], w - 8), C.text, C.win)
      g.toggle(x + w - 6, i * 2 - 1, sn[r[2]], function() sn[r[2]] = not sn[r[2]]; if not sn.music then OS.snd.track = nil end; OS.save() end)
    end
    section(g, x, 9, "Volume: " .. math.floor(sn.vol * 100 + 0.5) .. "%")
    g.slider(x, 10, math.min(24, w - 2), sn.vol, function(v) sn.vol = math.max(0, math.min(1, v)); OS.save() end, C.acc, C.bar)
    g.btn(x, 12, "Test", function() OS.sfx("boot") end, "pri")
    g.put(x + 8, 12, "Plays on up to 4 attached speakers", C.sub, C.win)
  end

  local function drawTime(win, g, x, w)
    local tc = cfg.time
    if not tc then tc = {}; cfg.time = tc end
    local t = OS.fromUtc(os.epoch("utc") / 1000)
    local days = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }
    local months = { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" }
    g.put(x, 1, OS.clockStr(), C.text, C.win)
    g.put(x, 2, string.format("%s, %d %s %d", days[t.wday] or "", t.day, months[t.month] or "", t.year), C.sub, C.win)
    section(g, x, 4, "Clock format")
    local bx = x
    bx = bx + g.btn(bx, 5, "24-hour", function() tc.h12 = nil; OS.save() end, tc.h12 and "dark" or "pri") + 1
    g.btn(bx, 5, "12-hour", function() tc.h12 = true; OS.save() end, tc.h12 and "pri" or "dark")
    section(g, x, 7, "Date in the taskbar")
    bx = x
    bx = bx + g.btn(bx, 8, "Nov 1", function() tc.date = nil; OS.save() end, (tc.date == nil) and "pri" or "dark") + 1
    bx = bx + g.btn(bx, 8, "1 Nov", function() tc.date = "dm"; OS.save() end, (tc.date == "dm") and "pri" or "dark") + 1
    g.btn(bx, 8, "Hidden", function() tc.date = "off"; OS.save() end, (tc.date == "off") and "pri" or "dark")
    g.put(x, 10, "Minecraft time in the taskbar", C.text, C.win)
    g.toggle(x + w - 6, 10, tc.mc, function() tc.mc = not tc.mc or nil; OS.save() end)
    g.put(x, 3, "In game: " .. OS.mcStr(), C.sub, C.win)
    section(g, x, 12, "Time zone")
    g.put(x, 13, "Automatic (use the computer's zone)", C.text, C.win)
    g.toggle(x + w - 6, 13, tc.tz == nil, function()
      if tc.tz == nil then tc.tz = OS.autoOffset() else tc.tz = nil end
      OS.save()
    end)
    local function fmtTz(v) return string.format("UTC%s%s", v >= 0 and "+" or "-", (math.abs(v) % 1 == 0) and tostring(math.floor(math.abs(v))) or string.format("%.1f", math.abs(v))) end
    if tc.tz ~= nil then
      g.btn(x, 15, " - ", function() tc.tz = math.max(-12, tc.tz - 0.5); OS.save() end, "dark")
      g.put(x + 5, 15, fmtTz(tc.tz), C.text, C.win)
      g.btn(x + 14, 15, " + ", function() tc.tz = math.min(14, tc.tz + 0.5); OS.save() end, "dark")
      g.btn(x + 20, 15, "Reset", function() tc.tz = OS.autoOffset(); OS.save() end, "dark")
    else
      g.put(x, 15, "Currently " .. fmtTz(OS.autoOffset()) .. ". Turn Automatic off to set it by hand.", C.sub, C.win)
    end
  end

  local function drawSecurity(win, g, x, w)
    local s = win.state
    local fw = math.min(30, w - 2)
    g.put(x, 1, cfg.hash and "Login password: enabled" or "Login password: not set", cfg.hash and C.grn or C.sub, C.win)
    local y = 3
    if cfg.hash then
      section(g, x, y, "Current password"); g.field(x, y + 1, fw, s.f.cur); y = y + 2
    end
    section(g, x, y, cfg.hash and "New password (blank = remove)" or "New password"); g.field(x, y + 1, fw, s.f.new1)
    section(g, x, y + 2, "Confirm"); g.field(x, y + 3, fw, s.f.new2)
    g.btn(x, y + 5, cfg.hash and "Apply" or "Set password", function() applyPw(s) end, "pri")
    g.put(x + 16, y + 5, OS.trunc(s.msg, w - 18), s.msg:match("^Password") and C.grn or C.red, C.win)
    g.put(x, y + 7, "Lock screen at startup", C.text, C.win)
    g.toggle(x + w - 6, y + 7, cfg.lockBoot or cfg.hash ~= nil, function() if cfg.hash then s.msg = "Always on while a password is set"; return end cfg.lockBoot = not cfg.lockBoot; OS.save() end)
    g.put(x, y + 8, cfg.hash and "Password is required to unlock" or "No password: just click Unlock", C.sub, C.win)
  end

  local function displays()
    local list = {}
    if (cfg.dispMode or "single") == "single" or #OS.monitors() == 0 then
      local native = term.native and term.native() or term.current()
      list[1] = { id = "term", name = "Computer screen" }
      list[1].w, list[1].h = native.getSize()
    end
    for _, m in ipairs(OS.monitors()) do list[#list + 1] = { id = m.name, name = m.name, w = m.w, h = m.h } end
    return list
  end
  local function mainId() return OS.parentName or "term" end
  local function applyMode(mode)
    cfg.dispMode = mode
    cfg.spanMode = mode == "join"
    cfg.mirror = {}
    -- join and mirror ignore the computer's own screen: a monitor becomes the main display
    if mode ~= "single" and not cfg.monitor then
      local mons = OS.monitors()
      if #mons > 0 then cfg.monitor = true; cfg.monitorName = mons[1].name; OS.setupDisplay() end
    end
    if mode ~= "single" then
      for _, m in ipairs(OS.monitors()) do if m.name ~= mainId() then cfg.mirror[m.name] = true end end
    end
    OS.save(); OS.setupDisplay()
  end
  local function makeMain(id)
    if id == "term" then cfg.monitor = false
    else cfg.monitor = true; cfg.monitorName = id end
    OS.save(); OS.setupDisplay()
    applyMode(cfg.dispMode or "single")
  end

  local wallInfo = OS.wallInfo
  local function gridMove(id, dir) return OS.placeMove(id, dir) end
  local function drawDpad(g, dx, dy, id, label, moved)
    local function go(dir) return function() gridMove(id, dir) end end
    g.btn(dx + 4, dy, "\30", go("u"), "pri")
    g.btn(dx, dy + 1, "\17", go("l"), "pri")
    g.put(dx + 4, dy + 1, " " .. tostring(label) .. " ", C.wht, C.bar)
    g.btn(dx + 8, dy + 1, "\16", go("r"), "pri")
    g.btn(dx + 4, dy + 2, "\31", go("d"), "pri")
  end

  local function drawDisplay(win, g, x, w)
    local s = win.state
    local all = displays()
    local mode = cfg.dispMode or (cfg.spanMode and "join" or (next(cfg.mirror or {}) and "mirror" or "single"))
    g.put(x, 1, "Display Mode", C.sub, C.win)
    local bx = x
    local labels = w >= 41 and { join = "Join Displays", mirror = "Mirror", single = "Single Display" }
      or { join = "Join", mirror = "Mirror", single = "Single" }
    for _, m in ipairs({ "join", "mirror", "single" }) do
      bx = bx + g.btn(bx, 2, labels[m], function() applyMode(m) end, mode == m and "pri" or "dark") + 1
    end
    g.btn(x, 3, "Identify", function() OS.startPlace() end, "dark")
    g.btn(x + 12, 3, "Re-detect", function() OS.recalibrate() end, "pri")
    g.put(x, 4, OS.trunc("Click a display to select it.", w), C.sub, C.win)
    -- arrangement preview
    local main = mainId()
    local byId = {}
    for _, d in ipairs(all) do byId[d.id] = d end
    local order, used = {}, {}
    if mode == "join" then for _, id in ipairs(OS.displayIds()) do if byId[id] then order[#order + 1] = byId[id]; used[id] = true end end
    elseif byId[main] then order[1] = byId[main]; used[main] = true end
    for _, d in ipairs(all) do if not used[d.id] then order[#order + 1] = d; used[d.id] = true; d.off = true end end
    local avail = w - 1
    local total = 0
    for _, d in ipairs(order) do total = total + math.max(1, d.w or 20) end
    local bxp = x
    s.dsel = byId[s.dsel or ""] and s.dsel or main
    for i, d in ipairs(order) do
      local bw = math.max(8, math.floor((d.w or 20) / total * avail) - 1)
      if bxp + bw > x + w then bw = math.max(4, x + w - bxp) end
      local sel = s.dsel == d.id
      local active = not d.off or d.id == main
      local bg = sel and C.acc or (active and C.bar or C.dock)
      g.fill(bxp, 6, bw, 4, bg)
      if d.id == main then g.fill(bxp, 6, bw, 1, C.wht) end
      g.put(bxp + 1, 7, tostring(i), C.wht, sel and C.acc or C.sp0)
      g.put(bxp + 1, 9, OS.trunc(d.name, bw - 2), sel and C.wht or C.sub, bg)
      g.hot(bxp, 6, bw, 4, function() s.dsel = d.id end)
      bxp = bxp + bw + 1
      if bxp > x + w then break end
    end
    -- selected display settings
    local d = byId[s.dsel]
    if d then
      local sw, sh = OS.size()
      g.put(x, 11, OS.trunc((d.id == main and "Main display: " or "Display: ") .. d.name, w), C.text, C.win)
      g.put(x, 12, OS.trunc((d.id == main and ("Desktop " .. sw .. " x " .. sh .. " cells") or ((d.w or 0) .. " x " .. (d.h or 0) .. " cells at 0.5 scale")) .. (d.off and "  (not used in this mode)" or ""), w), C.sub, C.win)
      local ax = x
      if d.id ~= main then ax = ax + g.btn(ax, 13, "Make main", function() makeMain(d.id) end, "pri") + 1 end
      if mode == "join" and OS.span then
        local pos
        for i, sg in ipairs(OS.span.segs) do if (sg.name or "term") == d.id then pos = i end end
        if pos and w >= 38 then drawDpad(g, x + w - 11, 13, d.id, pos) end
      end
    end
    g.put(x, 15, "Text scale: " .. tostring(cfg.scale), C.text, C.win)
    local sx = x + 18
    do
      sx = sx + g.btn(sx, 15, "-", function()
        for i, v in ipairs(scales) do if v == cfg.scale and scales[i - 1] then cfg.scale = scales[i - 1]; break end end
        OS.save(); OS.setupDisplay()
      end) + 1
      g.btn(sx, 15, "+", function()
        for i, v in ipairs(scales) do if v == cfg.scale and scales[i + 1] then cfg.scale = scales[i + 1]; break end end
        OS.save(); OS.setupDisplay()
      end)
    end
    local ex = x
    ex = ex + g.btn(ex, 16, "Best fit", function()
      local b = OS.bestFit()
      s.msg = b and ("Using " .. b.name .. " " .. b.w .. "x" .. b.h) or "No monitor attached"
      applyMode(cfg.dispMode or "single")
    end) + 1
    if mode == "mirror" then
      ex = ex + g.btn(ex, 16, cfg.mirrorFit ~= false and "Stretch: on" or "Stretch: off", function() cfg.mirrorFit = not (cfg.mirrorFit ~= false); OS.save(); OS.setupDisplay() end) + 1
    end
    g.put(ex, 16, OS.trunc(s.msg or "", w - (ex - x)), C.yel, C.win)
  end

  -- Layout: how joined monitors are arranged (row, column, grid), their order and per-monitor text scale
  local function spanIds()
    local ids = {}
    if OS.span then for _, sg in ipairs(OS.span.segs) do ids[#ids + 1] = sg.name or "term" end end
    return ids
  end
  local function setOrder(ids)
    cfg.spanOrder = ids; OS.save(); OS.setupDisplay()
  end
  local function drawLayout(win, g, x, w)
    local s = win.state
    local ids = spanIds()
    local n = #ids
    if n < 2 then
      g.put(x, 1, "Layout is for joined displays.", C.text, C.win)
      g.put(x, 3, OS.trunc("Go to Display, choose Join Displays and", w), C.sub, C.win)
      g.put(x, 4, OS.trunc("have two or more monitors attached.", w), C.sub, C.win)
      g.btn(x, 6, "Identify", function() OS.startPlace() end, "dark")
      return
    end
    local cols = OS.span.cols
    local rows = OS.span.rows
    g.put(x, 1, "Join layout", C.sub, C.win)
    local _, wall, pc, known = wallInfo()
    if known then g.put(x, 4, OS.trunc("Boxes = your wall (X across, Y down).", math.max(8, w - 17)), C.sub, C.win)
    else g.put(x, 4, OS.trunc("Use Identify, then the arrows to place.", math.max(8, w - 17)), C.yel, C.win) end
    local vx = x + 13
    vx = vx + g.btn(vx, 1, "Grid", function() cfg.dispView = nil; OS.save() end, cfg.dispView ~= "list" and "pri" or "dark") + 1
    vx = vx + g.btn(vx, 1, "List", function() cfg.dispView = "list"; OS.save() end, cfg.dispView == "list" and "pri" or "dark") + 1
    g.btn(vx, 1, "Identify", function() OS.startPlace() end, "dark")
    local bx = x
    local function preset(label, v, on)
      bx = bx + g.btn(bx, 2, label, function() cfg.spanCols = v; OS.save(); OS.setupDisplay() end, on and "pri" or "dark") + 1
    end
    preset("Auto", nil, cfg.spanCols == nil)
    preset("X line", n, cfg.spanCols == n)
    preset("Y stack", 1, cfg.spanCols == 1)
    g.put(x, 3, "X: " .. cols .. "  Y: " .. rows, C.text, C.win)
    local cx = x + 14
    cx = cx + g.btn(cx, 3, " - ", function() cfg.spanCols = math.max(1, cols - 1); OS.save(); OS.setupDisplay() end, "dark") + 1
    g.btn(cx, 3, " + ", function() cfg.spanCols = math.min(n, cols + 1); OS.save(); OS.setupDisplay() end, "dark")
    -- preview of the wall, or the same monitors as a list (both read the live state every frame)
    local pos = {}
    for i, id in ipairs(ids) do pos[id] = i end
    s.lname = (s.lname and pos[s.lname]) and s.lname or wall[1]
    local prows = math.ceil(n / pc)
    if cfg.dispView == "list" then
      local rowsMax = 7
      s.ltop = math.max(0, math.min(s.ltop or 0, math.max(0, n - rowsMax)))
      for k = 1, rowsMax do
        local id = wall[k + s.ltop]
        if not id then break end
        local sg = OS.span.segs[pos[id]]
        local on = s.lname == id
        local bg = on and C.acc or ((k % 2 == 0) and C.bar or C.win)
        g.fill(x, 4 + k, w, 1, bg)
        local nm = id == "term" and "Computer screen" or id
        local sc = (cfg.dscale or {})[id] or cfg.scale or 0.5
        local line = string.format("%d  %s  %dx%d  %s", pos[id], nm, sg.w, sg.h, sc)
        g.put(x + 1, 4 + k, OS.trunc(line, w - 2), on and C.wht or C.text, bg)
        g.hot(x, 4 + k, w, 1, function() s.lname = id end)
      end
      g.scroll(x, 5, w, rowsMax, function(d) s.ltop = math.max(0, math.min(math.max(0, n - rowsMax), (s.ltop or 0) + d)) end)
    else
      -- any number of monitors: cells shrink, and arrows page through a wall that doesn't fit
      local gap = (prows <= 2) and 1 or 0
      local ch = (prows <= 2) and 3 or ((prows == 3) and 2 or 1)
      local cw = math.max(5, math.min(14, math.floor((w - (pc - 1)) / pc)))
      local vr = math.max(1, math.min(prows, math.floor((7 + gap) / (ch + gap))))
      local vc = math.max(1, math.min(pc, math.floor((w + 1) / (cw + 1))))
      s.px0 = math.max(0, math.min(s.px0 or 0, pc - vc))
      s.py0 = math.max(0, math.min(s.py0 or 0, prows - vr))
      for r = s.py0, s.py0 + vr - 1 do
        for c = s.px0, s.px0 + vc - 1 do
          local id = wall[r * pc + c + 1]
          if id then
            local px, py = x + (c - s.px0) * (cw + 1), 5 + (r - s.py0) * (ch + gap)
            local on = s.lname == id
            local bg = on and C.acc or (((r + c) % 2 == 0) and C.bar or C.dock)
            g.fill(px, py, cw, ch, bg)
            local nm = id == "term" and "Computer" or id:gsub("^monitor_", "mon ")
            g.put(px + 1, py, OS.trunc(pos[id] .. (cw >= 8 and (" " .. nm) or ""), cw - 1), C.wht, bg)
            if ch > 1 then
              local sc = (cfg.dscale or {})[id] or cfg.scale or 0.5
              g.put(px + 1, py + 1, OS.trunc(string.format("X%d Y%d", c + 1, r + 1), cw - 1), on and C.wht or C.sub, bg)
              if ch > 2 then g.put(px + 1, py + 2, OS.trunc("scale " .. sc, cw - 1), on and C.wht or C.sub, bg) end
            end
            g.hot(px, py, cw, ch, function() s.lname = id end)
          end
        end
      end
      if vc < pc or vr < prows then
        local bxp = x + w - 16
        bxp = bxp + g.btn(bxp, 4, "<", function() s.px0 = math.max(0, (s.px0 or 0) - 1) end, "dark") + 1
        bxp = bxp + g.btn(bxp, 4, ">", function() s.px0 = math.min(pc - vc, (s.px0 or 0) + 1) end, "dark") + 1
        bxp = bxp + g.btn(bxp, 4, "^", function() s.py0 = math.max(0, (s.py0 or 0) - 1) end, "dark") + 1
        g.btn(bxp, 4, "v", function() s.py0 = math.min(prows - vr, (s.py0 or 0) + 1) end, "dark")
      end
      g.scroll(x, 5, w, 7, function(d) s.py0 = math.max(0, math.min(prows - vr, (s.py0 or 0) + d)) end)
    end
    g.btn(x, 12, "Rotate", function()
      local o = {}; for i = 1, n do o[i] = ids[(i % n) + 1] end; setOrder(o)
    end, "dark")
    g.btn(x + 9, 12, "Reverse", function()
      local o = {}; for i = 1, n do o[i] = ids[n - i + 1] end; setOrder(o)
    end, "dark")
    g.btn(x, 13, "Turn grid", function()
      -- swap rows and columns (a full grid is transposed, so a 3x2 wall becomes 2x3)
      if n == cols * rows then
        local o = {}
        for i = 1, n do
          local r, c = math.floor((i - 1) / cols), (i - 1) % cols
          o[c * rows + r + 1] = ids[i]
        end
        cfg.spanCols = rows; setOrder(o)
      else cfg.spanCols = rows; OS.save(); OS.setupDisplay() end
    end, "dark")
    g.btn(x + 12, 13, "Test", function() OS.testUntil = os.clock() + 20; OS.toast("Test pattern for 20 seconds", 3) end, "dark")
    g.btn(x, 14, "Re-detect", function() OS.recalibrate() end, "pri")
    g.put(x + 14, 14, OS.trunc("no touching needed", math.max(0, w - 26)), C.sub, C.win)
    drawDpad(g, x + w - 11, 12, s.lname, pos[s.lname], nil)
    -- text scale of the selected monitor
    local id = s.lname
    cfg.dscale = cfg.dscale or {}
    local cur = cfg.dscale[id] or cfg.scale or 0.5
    g.put(x, 15, OS.trunc("Text scale of " .. pos[id] .. ": " .. cur, w), C.text, C.win)
    local function stepScale(d)
      local idx
      for i, v in ipairs(scales) do if v == cur then idx = i end end
      idx = math.max(1, math.min(#scales, (idx or 1) + d))
      cfg.dscale[id] = scales[idx]; OS.save(); OS.setupDisplay()
    end
    local sx = x
    sx = sx + g.btn(sx, 16, " - ", function() stepScale(-1) end, "dark") + 1
    sx = sx + g.btn(sx, 16, " + ", function() stepScale(1) end, "dark") + 1
    g.btn(sx, 16, "Default", function() cfg.dscale[id] = nil; OS.save(); OS.setupDisplay() end, "dark")
  end

  local function drawDockPage(win, g, x, w, h)
    local s = win.state
    local half = math.floor(w / 2)
    g.put(x, 1, "Pinned (right-click = unpin)", C.sub, C.win)
    g.put(x, h, "Auto-hide taskbar", C.text, C.win)
    g.toggle(x + w - 6, h, cfg.dockHide, function() cfg.dockHide = not cfg.dockHide or nil; OS.dockUntil = nil; OS.save() end)
    local list = OS.dockList()
    for i, id in ipairs(list) do
      local a = OS.apps[id]
      if a then
        local y = 2 + i
        if y <= h - 2 then
          g.put(x, y, OS.trunc(a.title or id, half - 11), C.text, C.win)
          local bx = x + half - 10
          bx = bx + g.btn(bx, y, "^", function() OS.dockMove(id, -1) end) + 0
          bx = bx + g.btn(bx, y, "v", function() OS.dockMove(id, 1) end) + 0
          g.btn(bx, y, "x", function() OS.dockToggle(id) end, "danger")
        end
      end
    end
    local ax = x + half + 1
    g.put(ax, 2, "Add (scroll)", C.sub, C.win)
    local ids = {}
    for id, a in pairs(OS.apps) do if not a.hidden and not a.action and not OS.dockHas(id) then ids[#ids + 1] = id end end
    table.sort(ids, function(p, q) return tostring(OS.apps[p].title):lower() < tostring(OS.apps[q].title):lower() end)
    local rows = h - 4
    s.dsc = math.max(0, math.min(s.dsc or 0, math.max(0, #ids - rows)))
    for i = 1, rows do
      local id = ids[s.dsc + i]
      if id then
        g.put(ax, 2 + i, OS.trunc(OS.apps[id].title or id, half - 6), C.text, C.win)
        g.btn(ax + half - 5, 2 + i, "+", function() OS.dockToggle(id) end)
      end
    end
    g.scroll(ax, 3, half, rows, function(dir) s.dsc = (s.dsc or 0) + dir end)
    g.btn(x, h - 1, "Reset taskbar", function() cfg.dock = nil; OS.dirty = true end)
  end

  local function drawLpPage(win, g, x, w)
    local lp = cfg.lp
    g.put(x, 1, "Start menu layout", C.sub, C.win)
    g.put(x, 3, "Group by category (off = one flat list)", C.text, C.win)
    g.toggle(x + w - 6, 3, not lp.flat, function() lp.flat = not lp.flat; OS.dirty = true end)
    g.put(x, 5, "Pinned tile columns: " .. (lp.cols and tostring(lp.cols) or "auto"), C.text, C.win)
    local bx = x
    bx = bx + g.btn(bx, 6, "-", function() lp.cols = math.max(1, (lp.cols or 2) - 1); OS.dirty = true end) + 1
    bx = bx + g.btn(bx, 6, "+", function() lp.cols = math.min(3, (lp.cols or 2) + 1); OS.dirty = true end) + 1
    g.btn(bx, 6, "Auto", function() lp.cols = nil; OS.dirty = true end)
    g.btn(x, 8, "Edit order / hide / pin...", function() OS.open_lp_edit() end, "pri")
    g.put(x, 9, OS.trunc("Also: right-click an app in Start to pin it to the taskbar.", w), C.sub, C.win)
    g.btn(x, 11, "Reset order and unhide all", function() lp.order = {}; lp.hide = {}; OS.dirty = true end)
  end

  local function drawWifi(win, g, x, w)
    local W = OS.wifi
    local wc = cfg.wifi or {}
    g.put(x, 1, "Wi-Fi", C.text, C.win)
    g.toggle(x + 8, 1, wc.on, function() wc.on = not wc.on; OS.dirty = true end)
    g.put(x, 3, OS.trunc(W and W.status or "Not available", w), C.sub, C.win)
    g.put(x, 4, W and W.available() and "Wireless modem: found" or "Wireless modem: none (attach one)", W and W.available() and C.grn or C.red, C.win)
    local lab = W and W.label()
    if lab then g.put(x, 5, lab, C.acc, C.win) end
    g.btn(x, 7, "Open Wi-Fi...", function() OS.open("wifi") end, "pri")
    g.put(x, 9, "Place a Wireless Modem next to this computer,", C.sub, C.win)
    g.put(x, 10, "start a Hotspot on one and connect from others.", C.sub, C.win)
  end

  local function drawController(win, g, x, w)
    g.put(x, 1, "Controller cursor (F8)", C.text, C.win)
    g.toggle(x + w - 6, 1, OS.vc ~= nil, function() OS.toggleVC() end)
    local lines = {
      "Arrow keys   move the pointer (Shift = faster)",
      "Enter/Space  left click      Backspace  right click",
      "PgUp/PgDn    scroll          F8         toggle",
      "",
      "Gamepad mods such as Controllable can bind the",
      "D-pad / stick to arrow keys and buttons to",
      "Enter / Backspace, which then drives this cursor.",
      "Turn it off before playing games that use arrows.",
    }
    for i, l in ipairs(lines) do g.put(x, 2 + i, OS.trunc(l, w), i > 4 and C.sub or C.text, C.win) end
  end

  local function drawMusic(win, g, x, w)
    local s = win.state
    local fw = w - 1
    section(g, x, 1, "Audio converter URL (use %s for the video id)")
    g.field(x, 2, fw, s.f.conv)
    section(g, x, 3, "Must return raw 48 kHz mono DFPWM audio")
    section(g, x, 5, "Search API")
    local inst = cfg.music.search[1] or { kind = "piped", url = "" }
    local bx = x
    g.btn(bx, 6, inst.kind, function()
      inst.kind = inst.kind == "piped" and "invidious" or "piped"; cfg.music.search[1] = inst
    end)
    g.field(x + #inst.kind + 3, 6, fw - #inst.kind - 3, s.f.api)
    section(g, x, 8, "Default volume: " .. math.floor(cfg.music.vol * 100 + 0.5) .. "%")
    g.slider(x, 9, math.min(24, fw), cfg.music.vol, function(v) OS.audio.setVol(v) end, C.acc, C.bar)
    g.btn(x, 11, "Save", function()
      cfg.music.converter = s.f.conv.text
      inst.url = s.f.api.text; cfg.music.search[1] = inst
      OS.save(); s.msg = "Saved"
    end, "pri")
    g.put(x + 8, 11, s.msg, C.grn, C.win)
  end

  local function drawAbout(win, g, x, w)
    local s = win.state
    local lines = {
      { OS.verName(), "CC Edition", true },
      { "Kernel", os.version() },
      { "Computer ID", tostring(os.getComputerID()) },
      { "User", cfg.user or "-" },
      { "Disk", string.format("%dK free of %dK", math.floor(fs.getFreeSpace("/") / 1024), math.floor(fs.getCapacity("/") / 1024)) },
      { "Speakers", tostring(#OS.audio.speakers) },
      { "Uptime", OS.fmtTime(os.clock()) },
    }
    for i, l in ipairs(lines) do
      if l[3] then g.put(x, i, l[1], C.acc, C.win); g.put(x + #l[1] + 1, i, l[2], C.sub, C.win)
      else g.put(x, i, l[1], C.sub, C.win); g.put(x + 13, i, OS.trunc(l[2], w - 13), C.text, C.win) end
    end
    section(g, x, 9, "Computer name")
    g.field(x, 10, math.min(24, w - 8), s.f.host)
    g.btn(x + math.min(24, w - 8) + 1, 10, "Set", function()
      pcall(os.setComputerLabel, s.f.host.text); cfg.host = s.f.host.text; OS.save()
    end)
    section(g, x, 11, "Weather city (calendar panel)")
    g.field(x, 12, math.min(24, w - 8), s.f.city)
    g.btn(x + math.min(24, w - 8) + 1, 12, "Set", function()
      cfg.city = s.f.city.text; OS.weather.t = -1e9; OS.save()
    end)
  end

  function app.draw(win, g)
    local s = win.state
    local w, h = g.w, g.h
    if w < 40 then
      -- small screen: a list of pages, then one page at a time with a Back button
      g.fill(1, 1, w, h, C.win)
      if not s.open then
        g.put(2, 1, "Settings", C.text, C.win)
        for i, p in ipairs(pages) do
          local y = 1 + i * 2
          if y <= h then
            g.fill(1, y, w, 1, C.bar)
            g.put(2, y, OS.trunc(p[2], w - 4), C.text, C.bar)
            g.put(w - 1, y, ">", C.sub, C.bar)
            g.hot(1, y, w, 1, function() s.page = p[1]; s.open = true; s.msg = ""; win.focus = nil end)
          end
        end
        return
      end
      local title
      for _, p in ipairs(pages) do if p[1] == s.page then title = p[2] end end
      g.btn(1, 1, "< Back", function() s.open = false; win.focus = nil end, "dark")
      g.put(10, 1, OS.trunc(title or "", w - 10), C.text, C.win)
      local gg = OS.subG(g, 0, 1, w, h - 1)
      local pg = setmetatable({ put = function(px, py, t, fg, bg) gg.put(px, py, t, fg, bg or C.win) end }, { __index = gg })
      local x, cw = 1, w
      if s.page == "appearance" then drawAppearance(win, pg, x, cw)
      elseif s.page == "security" then drawSecurity(win, pg, x, cw)
      elseif s.page == "display" then drawDisplay(win, pg, x, cw)
      elseif s.page == "layout" then drawLayout(win, pg, x, cw)
      elseif s.page == "sound" then drawSound(win, pg, x, cw)
      elseif s.page == "time" then drawTime(win, pg, x, cw)
      elseif s.page == "dock" then drawDockPage(win, pg, x, cw, h - 1)
      elseif s.page == "launchpad" then drawLpPage(win, pg, x, cw)
      elseif s.page == "wifi" then drawWifi(win, pg, x, cw)
      elseif s.page == "controller" then drawController(win, pg, x, cw)
      elseif s.page == "music" then drawMusic(win, pg, x, cw)
      else drawAbout(win, pg, x, cw) end
      return
    end
    local sw = 14
    g.fill(1, 1, sw, h, C.bar)
    g.fill(sw + 1, 1, w - sw, h, C.win)
    for i, p in ipairs(pages) do
      local on = s.page == p[1]
      g.fill(1, i, sw, 1, on and C.acc or C.bar)
      g.put(2, i, p[2], on and C.wht or C.text, on and C.acc or C.bar)
      g.hot(1, i, sw, 1, function() s.page = p[1]; s.msg = ""; win.focus = nil end)
    end
    local x, cw = sw + 2, w - sw - 2
    local sub = { x = x }
    local gg = setmetatable({
      put = function(px, py, t, fg, bg) g.put(px, py, t, fg, bg or C.win) end,
    }, { __index = g })
    if s.page == "appearance" then drawAppearance(win, gg, x, cw)
    elseif s.page == "security" then drawSecurity(win, gg, x, cw)
    elseif s.page == "display" then drawDisplay(win, gg, x, cw)
    elseif s.page == "layout" then drawLayout(win, gg, x, cw)
    elseif s.page == "sound" then drawSound(win, gg, x, cw)
    elseif s.page == "time" then drawTime(win, gg, x, cw)
    elseif s.page == "dock" then drawDockPage(win, gg, x, cw, h)
    elseif s.page == "launchpad" then drawLpPage(win, gg, x, cw)
    elseif s.page == "wifi" then drawWifi(win, gg, x, cw)
    elseif s.page == "controller" then drawController(win, gg, x, cw)
    elseif s.page == "music" then drawMusic(win, gg, x, cw)
    else drawAbout(win, gg, x, cw) end
  end

  return app
end

end)()
EMBED["store"] = (function()
return function(OS)
  local C = OS.C
  local cfg = OS.cfg
  local app = { id = "store", title = "Store", glyph = " A ", icon = "acc", fg = "wht",
    w = 52, h = 16, single = true, minw = 40, minh = 11 }

  -- Featured programs. "installer" ones are scripts that install themselves; they run in a window.
  local CATALOG = {
    { name = "youcube", title = "YouCube", src = "pastebin:swsmNAf7", installer = true, after = "/youcube.lua",
      desc = "YouTube audio/video player (its installer runs in a window)" },
  }

  cfg.pkgs = cfg.pkgs or {}

  local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
  local function clean(n) return (tostring(n or ""):gsub("[^%w_%-]", "")) end

  -- gist / pastebin / url / file -> url, kind, id
  local function resolveSrc(s)
    s = trim(s)
    if s == "" then return nil end
    local pb = s:match("^pastebin:(%w+)$") or s:match("pastebin%.com/raw/(%w+)") or s:match("pastebin%.com/(%w+)$")
    if pb then return "https://pastebin.com/raw/" .. pb, "pastebin", pb end
    if s:find("gist.githubusercontent.com", 1, true) then
      return s, "gist", (s:match("/(%x+)/raw") or s:match("/(%x%x%x%x%x%x%x%x+)") or "gist")
    end
    local user, gid = s:match("gist%.github%.com/([%w%-_]+)/(%x+)")
    if not gid then user, gid = s:match("^gist:([%w%-_]+)/(%x+)$") end
    if gid then return "https://gist.githubusercontent.com/" .. user .. "/" .. gid .. "/raw", "gist", gid end
    local path = s:match("^file:(.+)$")
    if path then return path, "file", (path:match("([^/]+)$") or "prog"):gsub("%.lua$", "") end
    if s:match("^https?://") then return s, "url", ((s:match("([^/?]+)$") or "prog"):gsub("%.lua$", "")) end
    if s:match("^%w%w%w%w%w%w%w%w$") then return "https://pastebin.com/raw/" .. s, "pastebin", s end
    return nil
  end

  local function upsert(rec)
    for i, p in ipairs(cfg.pkgs) do if p.name == rec.name then cfg.pkgs[i] = rec; return end end
    cfg.pkgs[#cfg.pkgs + 1] = rec
  end

  local function download(url, cb)
    OS.http(url, function(data, err)
      if not data then cb(nil, "Failed: " .. tostring(err)) return end
      if data:find("^%s*<") then cb(nil, "Got a web page, not Lua (use the raw link)") return end
      local fn, e = load(data, "=check")
      if not fn then cb(nil, "Not valid Lua: " .. tostring(e):sub(1, 40)) return end
      cb(data)
    end)
  end

  local function install(win, rec)
    local s = win.state
    s.msg = "Downloading " .. rec.name .. "..."
    download(rec.url, function(data, err)
      if not data then s.msg = err return end
      fs.makeDir("/win10/pkgs")
      rec.file = "/win10/pkgs/" .. rec.name .. ".lua"
      local f = fs.open(rec.file, "wb"); f.write(data); f.close()
      upsert(rec)
      OS.registerPkg(rec)
      OS.save()
      s.msg = "Installed " .. rec.name .. " - find it in Start"
    end)
  end

  local function runInstaller(win, e)
    local s = win.state
    local url = resolveSrc(e.src)
    s.msg = "Downloading " .. e.title .. " installer..."
    download(url, function(data, err)
      if not data then s.msg = err return end
      s.msg = e.title .. " installer is running in a window"
      OS.runProgram(e.title .. " installer", data)
    end)
  end

  local function remove(win, p)
    OS.unregisterPkg(p.name)
    if p.kind ~= "file" and p.file and fs.exists(p.file) then pcall(fs.delete, p.file) end
    for i, q in ipairs(cfg.pkgs) do if q == p then table.remove(cfg.pkgs, i) break end end
    OS.save()
    win.state.msg = "Removed " .. p.name
  end

  local function openCatalog(win, e)
    if not fs.exists(e.after) then win.state.msg = e.after .. " not found - run the installer first" return end
    local rec = { name = e.name, file = e.after, kind = "file" }
    upsert(rec); OS.registerPkg(rec); OS.save()
    OS.launch("pkg:" .. e.name)
  end

  local function doAdd(win)
    local s = win.state
    local url, kind, id = resolveSrc(s.src.text)
    if not url then s.msg = "Use a gist/pastebin link, raw URL, 8-char pastebin ID, or file:/path" return end
    local name = clean(s.name.text)
    if name == "" then
      name = clean(kind == "pastebin" and ("pb-" .. id) or kind == "gist" and ("gist-" .. tostring(id):sub(1, 6)) or id)
    end
    if name == "" then name = "program" end
    if kind == "file" then
      if OS.isProtected(url) then s.msg = "/startup.lua is the OS itself - pick another file" return end
      if not fs.exists(url) or fs.isDir(url) then s.msg = "No such file: " .. url return end
      local rec = { name = name, file = url, kind = "file" }
      upsert(rec); OS.registerPkg(rec); OS.save()
      s.msg = "Added " .. name
    else
      install(win, { name = name, url = url, kind = kind })
    end
    s.src.text = ""; s.src.pos = 0
  end

  function app.init(win)
    local s = { scroll = 0, msg = "" }
    win.state = s
    s.src = OS.field("", { placeholder = "gist / pastebin link, raw URL or file:/path" })
    s.name = OS.field("", { max = 16, placeholder = "optional" })
    s.src.onEnter = function() doAdd(win) end
    s.name.onEnter = function() doAdd(win) end
    win.keepFocus = s.src; win.focus = s.src
  end

  local function rowsList()
    local out = { { hdr = "Featured" } }
    for _, e in ipairs(CATALOG) do out[#out + 1] = { cat = e } end
    out[#out + 1] = { hdr = "Installed" }
    for _, p in ipairs(cfg.pkgs) do out[#out + 1] = { pkg = p } end
    if #cfg.pkgs == 0 then out[#out + 1] = { note = "Nothing installed yet - add a link below." } end
    return out
  end

  function app.draw(win, g)
    local s = win.state
    local w, h = g.w, g.h
    g.fill(1, 1, w, h, C.win)
    g.put(2, 1, "Gist, Pastebin and URL software", C.sub, C.win)
    local lh = h - 5
    local list = rowsList()
    s.scroll = math.max(0, math.min(s.scroll, math.max(0, #list - lh)))
    for r = 1, lh do
      local it = list[s.scroll + r]
      if not it then break end
      local y = 1 + r
      if it.hdr then
        g.fill(1, y, w, 1, C.bar); g.put(2, y, it.hdr, C.text, C.bar)
      elseif it.note then
        g.put(2, y, OS.trunc(it.note, w - 2), C.sub, C.win)
      else
        local btns = {}
        local label, sub
        if it.cat then
          local e = it.cat
          label, sub = e.title, e.desc
          btns[#btns + 1] = { "Install", function() runInstaller(win, e) end, "pri" }
          if fs.exists(e.after) then btns[#btns + 1] = { "Open", function() openCatalog(win, e) end } end
        else
          local p = it.pkg
          label, sub = p.name, "[" .. (p.kind or "?") .. "] " .. (p.file or "")
          btns[#btns + 1] = { "Open", function() OS.launch("pkg:" .. p.name) end, "pri" }
          if p.url then btns[#btns + 1] = { "Update", function() install(win, { name = p.name, url = p.url, kind = p.kind }) end } end
          btns[#btns + 1] = { "Del", function() remove(win, p) end, "danger" }
        end
        local bw = 0
        for _, b in ipairs(btns) do bw = bw + #b[1] + 3 end
        local x = w - bw + 1
        for _, b in ipairs(btns) do x = x + g.btn(x, y, b[1], b[2], b[3]) + 1 end
        g.put(2, y, OS.trunc(label, 14), C.text, C.win)
        g.put(17, y, OS.trunc(sub or "", math.max(1, w - bw - 17)), C.sub, C.win)
      end
    end
    g.scroll(1, 2, w, lh, function(dir) s.scroll = s.scroll + dir end)
    g.put(2, h - 3, "Add by link (gist, pastebin, raw URL, file:/path)", C.sub, C.win)
    g.field(1, h - 2, w - 9, s.src)
    g.btn(w - 7, h - 2, "Add", function() doAdd(win) end, "pri")
    g.put(2, h - 1, "Name", C.sub, C.win)
    g.field(7, h - 1, 18, s.name)
    g.put(1, h, OS.trunc(s.msg, w), (s.msg:find("^Failed") or s.msg:find("^Got a web") or s.msg:find("^Not valid") or s.msg:find("^Use a") or s.msg:find("^No such")) and C.red or C.grn, C.win)
  end

  return app
end

end)()
EMBED["snake"] = (function()
return function(OS)
  local C = OS.C
  local app = { id = "snake", title = "Snake", glyph = " S ", icon = "grn", fg = "wht", cat = "Games",
    w = 36, h = 19, single = true, minw = 24, minh = 10 }
  local GW, GH = 16, 15

  local function place(s)
    local occ = {}
    for _, p in ipairs(s.snake) do occ[p.y * 100 + p.x] = true end
    local tries = 0
    repeat
      s.fx, s.fy = math.random(1, GW), math.random(1, GH)
      tries = tries + 1
    until not occ[s.fy * 100 + s.fx] or tries > 500
  end

  local function reset(s)
    s.snake = { { x = 8, y = 8 }, { x = 7, y = 8 }, { x = 6, y = 8 } }
    s.dx, s.dy, s.qx, s.qy = 1, 0, 1, 0
    s.score = 0
    s.state = "ready"
    place(s)
  end

  local function step(s)
    s.dx, s.dy = s.qx, s.qy
    local h = s.snake[1]
    local nx, ny = h.x + s.dx, h.y + s.dy
    if nx < 1 or nx > GW or ny < 1 or ny > GH then s.state = "dead"; OS.sfx("die") return end
    local grow = (nx == s.fx and ny == s.fy)
    local n = #s.snake
    for i = 1, grow and n or n - 1 do
      local p = s.snake[i]
      if p.x == nx and p.y == ny then s.state = "dead"; OS.sfx("die") return end
    end
    table.insert(s.snake, 1, { x = nx, y = ny })
    if grow then s.score = s.score + 1; place(s); OS.sfx("eat") else table.remove(s.snake) end
    if s.score > (OS.cfg.snakeBest or 0) then OS.cfg.snakeBest = s.score; OS.dirty = true end
  end

  local function tick(win)
    local s = win.state
    if not s.alive then return end
    if s.state == "playing" and OS.active() == win then step(s) end
    OS.timer(math.max(0.06, 0.17 - s.score * 0.004), function() tick(win) end)
  end

  local function turn(s, dx, dy)
    if s.state == "dead" then return end
    if dx ~= -s.dx or dy ~= -s.dy then s.qx, s.qy = dx, dy end
    if s.state == "ready" then s.state = "playing" end
  end

  function app.init(win)
    local s = { alive = true }
    win.state = s
    reset(s)
    OS.music("snake", win)
    OS.timer(0.2, function() tick(win) end)
  end
  function app.close(win) win.state.alive = false; OS.musicStop(win) end

  function app.key(win, k)
    local s = win.state
    if k == keys.up then turn(s, 0, -1)
    elseif k == keys.down then turn(s, 0, 1)
    elseif k == keys.left then turn(s, -1, 0)
    elseif k == keys.right then turn(s, 1, 0)
    elseif k == keys.space then
      if s.state == "dead" then reset(s) elseif s.state == "playing" then s.state = "paused" elseif s.state == "paused" then s.state = "playing" end
    end
  end
  function app.char(win, c)
    local s = win.state
    if c == "w" then turn(s, 0, -1) elseif c == "s" then turn(s, 0, 1)
    elseif c == "a" then turn(s, -1, 0) elseif c == "d" then turn(s, 1, 0)
    elseif c == "r" then reset(s) end
  end

  function app.draw(win, g)
    local s = win.state
    local w, h = g.w, g.h
    g.fill(1, 1, w, h, C.win)
    local ox = math.max(1, math.floor((w - GW * 2) / 2) + 1)
    local oy = 2
    g.put(2, 1, "Score " .. s.score, C.text, C.win)
    local best = "Best " .. (OS.cfg.snakeBest or 0)
    g.put(w - #best - 1, 1, best, C.sub, C.win)
    g.fill(ox, oy, GW * 2, GH, C.desk)
    g.fill(ox + (s.fx - 1) * 2, oy + s.fy - 1, 2, 1, C.red)
    for i, p in ipairs(s.snake) do
      g.fill(ox + (p.x - 1) * 2, oy + p.y - 1, 2, 1, i == 1 and C.sp or C.grn)
    end
    local msg
    if s.state == "ready" then msg = "Arrows / WASD to start"
    elseif s.state == "dead" then msg = "Game over - Space"
    elseif s.state == "paused" then msg = "Paused - Space" end
    if msg then g.put(ox + math.floor((GW * 2 - #msg) / 2), oy + math.floor(GH / 2), msg, C.wht, C.desk) end
    local by = oy + GH
    if by <= h then
      local x = 2
      x = x + g.btn(x, by, "<", function() turn(s, -1, 0) end) + 1
      x = x + g.btn(x, by, "^", function() turn(s, 0, -1) end) + 1
      x = x + g.btn(x, by, "v", function() turn(s, 0, 1) end) + 1
      x = x + g.btn(x, by, ">", function() turn(s, 1, 0) end) + 1
      g.btn(x + 1, by, "New", function() reset(s) end, "pri")
    end
  end

  return app
end

end)()
EMBED["doom"] = (function()
return function(OS)
  local C = OS.C
  local app = { id = "doom", title = "Doom", glyph = " D ", icon = "red", fg = "wht", cat = "Games",
    w = 50, h = 17, single = true, minw = 30, minh = 10 }

  -- A small original raycaster in the spirit of 90s shooters (not the real game).
  local MAP = {
    "1111111111111111",
    "1P.....1.......1",
    "1......1...E...1",
    "1..22..1.......1",
    "1..2.......22..1",
    "1..2...1...2...1",
    "1......1...2...1",
    "1111.1111..2...1",
    "1......1.......1",
    "1..E...1..1111.1",
    "1......1..1....1",
    "1...2......1.E.1",
    "1...2..1...1...1",
    "1......1.......1",
    "1.E....1....E..1",
    "1111111111111111",
  }
  local LV1 = { " ", "\129", "\137", "\153", "\158", "\159" }
  local LV2 = { " ", "\130", "\134", "\150", "\157", "\159" }

  local function cell(x, y)
    local r = MAP[y + 1]
    if not r then return "1" end
    local c = r:sub(x + 1, x + 1)
    if c == "" then return "1" end
    return c
  end
  local function isWall(x, y)
    local c = cell(math.floor(x), math.floor(y))
    return c == "1" or c == "2"
  end

  local function reset(s)
    s.enemies = {}
    for y = 0, #MAP - 1 do
      for x = 0, #MAP[1] - 1 do
        local c = cell(x, y)
        if c == "P" then s.px, s.py = x + 0.5, y + 0.5
        elseif c == "E" then s.enemies[#s.enemies + 1] = { x = x + 0.5, y = y + 0.5, hp = 2, cd = 0 } end
      end
    end
    s.total = #s.enemies
    s.a, s.hp, s.ammo, s.kills, s.shot, s.hurt, s.mode = 0.3, 100, 60, 0, 0, 0, "play"
  end

  local function tryMove(s, dx, dy)
    local m = 0.22
    local nx, ny = s.px + dx, s.py + dy
    if not isWall(nx + (dx > 0 and m or -m), s.py) then s.px = nx end
    if not isWall(s.px, ny + (dy > 0 and m or -m)) then s.py = ny end
  end

  local function shoot(s)
    if s.mode ~= "play" or s.ammo <= 0 then return end
    s.ammo = s.ammo - 1; s.shot = 2; OS.sfx("shoot")
    local best, bd
    for _, e in ipairs(s.enemies) do
      if e.hp > 0 and e.ty and e.ty > 0.3 and math.abs(e.tx / e.ty) < 0.25 and e.ty < (s.zc or 99) then
        if not bd or e.ty < bd then best, bd = e, e.ty end
      end
    end
    if best then
      best.hp = best.hp - 1
      OS.sfx("hit")
      if best.hp <= 0 then s.kills = s.kills + 1; s.ammo = s.ammo + 4; OS.sfx("boom") end
      if s.kills >= s.total then s.mode = "won"; OS.sfx("win") end
    end
  end

  local function tick(win)
    local s = win.state
    if not s.alive then return end
    if s.mode == "play" and OS.active() == win then
      s.shot = math.max(0, s.shot - 1)
      s.hurt = math.max(0, s.hurt - 1)
      for _, e in ipairs(s.enemies) do
        if e.hp > 0 then
          local dx, dy = s.px - e.x, s.py - e.y
          local d = math.sqrt(dx * dx + dy * dy)
          if d < 9 and d > 0.8 then
            local st = 0.09
            local nx, ny = e.x + dx / d * st, e.y + dy / d * st
            if not isWall(nx, e.y) then e.x = nx end
            if not isWall(e.x, ny) then e.y = ny end
          elseif d <= 0.8 then
            e.cd = e.cd - 1
            if e.cd <= 0 then s.hp = s.hp - 8; e.cd = 6; s.hurt = 3; OS.sfx("hit") end
          end
        end
      end
      if s.hp <= 0 then s.hp = 0; s.mode = "dead"; OS.sfx("lose") end
    end
    OS.timer(0.1, function() tick(win) end)
  end

  function app.init(win)
    local s = { alive = true }
    win.state = s
    reset(s)
    OS.music("doom", win)
    OS.timer(0.2, function() tick(win) end)
  end
  function app.close(win) win.state.alive = false; OS.musicStop(win) end

  function app.key(win, k)
    local s = win.state
    if k == keys.space then if s.mode == "play" then shoot(s) else reset(s) end return end
    if s.mode ~= "play" then return end
    local cx, cy = math.cos(s.a), math.sin(s.a)
    if k == keys.up then tryMove(s, cx * 0.3, cy * 0.3)
    elseif k == keys.down then tryMove(s, -cx * 0.3, -cy * 0.3)
    elseif k == keys.left then s.a = s.a - 0.16
    elseif k == keys.right then s.a = s.a + 0.16 end
  end
  function app.char(win, c)
    local s = win.state
    if c == "r" then reset(s) return end
    if s.mode ~= "play" then return end
    local cx, cy = math.cos(s.a), math.sin(s.a)
    if c == "w" then tryMove(s, cx * 0.3, cy * 0.3)
    elseif c == "s" then tryMove(s, -cx * 0.3, -cy * 0.3)
    elseif c == "a" then s.a = s.a - 0.16
    elseif c == "d" then s.a = s.a + 0.16
    elseif c == "q" then tryMove(s, cy * 0.25, -cx * 0.25)
    elseif c == "e" then tryMove(s, -cy * 0.25, cx * 0.25) end
  end

  local function render(s, g)
    local w, h = g.w, g.h
    local vh = math.max(3, h - 1)
    local bl = colors.toBlit
    local ceilB, floorB, blk = bl(C.sp2), bl(C.sp1), bl(C.sp0)
    local wall1, wall2 = bl(C.sub), bl(C.red)
    local redB, yelB, grnB = bl(C.red), bl(C.yel), bl(C.grn)
    local zb, cols = {}, {}
    local dirx, diry = math.cos(s.a), math.sin(s.a)
    local plx, ply = -diry * 0.66, dirx * 0.66

    for x = 1, w do
      local camx = 2 * (x - 0.5) / w - 1
      local rdx, rdy = dirx + plx * camx, diry + ply * camx
      local mx, my = math.floor(s.px), math.floor(s.py)
      local ddx = rdx == 0 and 1e30 or math.abs(1 / rdx)
      local ddy = rdy == 0 and 1e30 or math.abs(1 / rdy)
      local sx, sy, sdx, sdy
      if rdx < 0 then sx = -1; sdx = (s.px - mx) * ddx else sx = 1; sdx = (mx + 1 - s.px) * ddx end
      if rdy < 0 then sy = -1; sdy = (s.py - my) * ddy else sy = 1; sdy = (my + 1 - s.py) * ddy end
      local side, hitc = 0, "1"
      for _ = 1, 40 do
        if sdx < sdy then sdx = sdx + ddx; mx = mx + sx; side = 0
        else sdy = sdy + ddy; my = my + sy; side = 1 end
        local c = cell(mx, my)
        if c == "1" or c == "2" then hitc = c; break end
      end
      local perp = side == 0 and (sdx - ddx) or (sdy - ddy)
      if perp < 0.05 then perp = 0.05 end
      zb[x] = perp
      local lh = math.floor(vh * 1.1 / perp)
      local ds = math.floor((vh - lh) / 2) + 1
      local br = 1 - perp / 11
      if side == 1 then br = br * 0.75 end
      cols[x] = { ds = ds, de = ds + lh - 1, lvl = math.max(0, math.min(5, math.floor(br * 6))), c = hitc }
    end
    s.zc = zb[math.floor(w / 2) + 1] or zb[1]

    local rows = {}
    for y = 1, vh do
      local t, f, b = {}, {}, {}
      for x = 1, w do
        local cl = cols[x]
        if y < cl.ds then t[x] = " "; f[x] = "0"; b[x] = ceilB
        elseif y > cl.de then t[x] = " "; f[x] = "0"; b[x] = floorB
        else
          local wc = cl.c == "2" and wall2 or wall1
          if cl.lvl >= 5 then t[x] = " "; f[x] = wc; b[x] = wc
          elseif cl.lvl == 0 then t[x] = " "; f[x] = wc; b[x] = blk
          else t[x] = (((x + y) % 2 == 0) and LV1 or LV2)[cl.lvl + 1]; f[x] = wc; b[x] = blk end
        end
      end
      rows[y] = { t, f, b }
    end

    -- enemies (billboards, depth-tested against walls)
    local invDet = 1 / (plx * diry - dirx * ply)
    local list = {}
    for _, e in ipairs(s.enemies) do
      if e.hp > 0 then
        local ex, ey = e.x - s.px, e.y - s.py
        e.tx = invDet * (diry * ex - dirx * ey)
        e.ty = invDet * (-ply * ex + plx * ey)
        if e.ty > 0.2 then list[#list + 1] = e end
      end
    end
    table.sort(list, function(p, q) return p.ty > q.ty end)
    for _, e in ipairs(list) do
      local scrx = math.floor(w / 2 * (1 + e.tx / e.ty))
      local sh = math.floor(vh / e.ty * 0.9)
      local sw = math.max(1, math.floor(sh * 0.9))
      local y0 = math.floor((vh - sh) / 2) + 1 + math.floor(sh * 0.1)
      for x = scrx - math.floor(sw / 2), scrx + math.floor(sw / 2) do
        if x >= 1 and x <= w and e.ty < zb[x] then
          for y = math.max(1, y0), math.min(vh, y0 + sh - 1) do
            local rel = (y - y0) / math.max(1, sh)
            local col = (e.hp == 1) and grnB or redB
            local dxs = math.abs(x - scrx)
            if rel > 0.1 and rel < 0.25 and dxs >= sw / 8 and dxs <= sw / 3 then col = yelB end
            rows[y][1][x] = " "; rows[y][2][x] = "0"; rows[y][3][x] = col
          end
        end
      end
    end

    -- gun + crosshair
    local cxh, cyh = math.floor(w / 2) + 1, math.floor(vh / 2) + 1
    local gunB = bl(C.bar)
    for y = vh - 1, vh do
      for x = cxh - 2, cxh + 2 do
        if y >= 1 and rows[y] and x >= 1 and x <= w then rows[y][1][x] = " "; rows[y][3][x] = gunB end
      end
    end
    if s.shot > 0 then
      for _, p in ipairs({ { 0, -1 }, { -1, -2 }, { 1, -2 }, { 0, -2 } }) do
        local y, x = vh + p[2], cxh + p[1]
        if rows[y] and x >= 1 and x <= w then rows[y][1][x] = "*"; rows[y][2][x] = yelB end
      end
    end
    if rows[cyh] and cxh <= w then rows[cyh][1][cxh] = "\7"; rows[cyh][2][cxh] = bl(C.wht) end
    if s.hurt > 0 then
      for y = 1, vh do rows[y][3][1] = redB; rows[y][3][w] = redB end
    end
    for y = 1, vh do
      g.blit(1, y, table.concat(rows[y][1]), table.concat(rows[y][2]), table.concat(rows[y][3]))
    end
  end

  function app.draw(win, g)
    local s = win.state
    local w, h = g.w, g.h
    render(s, g)
    local hud = string.format(" HP %d   Ammo %d   Kills %d/%d", s.hp, s.ammo, s.kills, s.total)
    g.put(1, h, hud .. (" "):rep(w), C.wht, C.sp0)
    local msg
    if s.mode == "dead" then msg = " YOU DIED - Space to retry "
    elseif s.mode == "won" then msg = " LEVEL CLEAR! Space to replay " end
    if msg then g.put(math.floor((w - #msg) / 2) + 1, math.floor(h / 2), msg, C.wht, C.red) end
    g.put(w - 20, h, "WASD move  Space fire", C.sub, C.sp0)
    g.hot(1, 1, w, h - 1, function() if s.mode == "play" then shoot(s) else reset(s) end end)
  end

  return app
end

end)()
EMBED["gta"] = (function()
return function(OS)
  local C = OS.C
  local app = { id = "gta", title = "GTA VI", glyph = "VI ", icon = "yel", fg = "sp0", cat = "Games",
    w = 50, h = 17, single = true, minw = 30, minh = 10 }

  -- An original top-down city driving game: grab the cash, shake the cops. (Not the real game.)
  local MW, MH = 64, 40
  local BCOL = { "acc", "dock", "sp2", "sub" }
  local GLY = { ">>", "vv", "<<", "^^" }
  local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

  local function road(x, y) return x % 8 < 2 or y % 8 < 2 end
  local function solid(x, y)
    if x < 1 or y < 1 or x > MW or y > MH then return true end
    return not road(x, y)
  end
  local function tileCol(x, y)
    if x < 1 or y < 1 or x > MW or y > MH then return C.sp0 end
    if road(x, y) then return C.sp0 end
    local bx, by = math.floor((x - 2) / 8), math.floor((y - 2) / 8)
    if (bx + by * 2) % 5 == 0 then return C.grn end
    return C[BCOL[(bx * 7 + by * 3) % 4 + 1]]
  end
  local function randRoad(minDistFrom, minD)
    for _ = 1, 200 do
      local x, y = math.random(2, MW - 1), math.random(2, MH - 1)
      if road(x, y) and (not minDistFrom or math.abs(x - minDistFrom.px) + math.abs(y - minDistFrom.py) > minD) then
        return x + 0.5, y + 0.5
      end
    end
    return 8.5, 8.5
  end
  local function heading(a)
    return GLY[math.floor((a + math.pi / 4) / (math.pi / 2)) % 4 + 1]
  end

  local function reset(s)
    s.px, s.py, s.a, s.v = 8.5, 8.5, 0, 0
    s.hp, s.cash, s.wanted, s.heat, s.mode = 100, 0, 0, 0, "play"
    s.cops, s.pick = {}, {}
    for i = 1, 14 do
      local x, y = randRoad()
      s.pick[i] = { x = x, y = y }
    end
  end

  local function spawnCop(s)
    local x, y = randRoad(s, 12)
    s.cops[#s.cops + 1] = { x = x, y = y, a = 0 }
  end

  local function stepTo(x, y, nx, ny)
    if not solid(math.floor(nx), math.floor(y)) then x = nx end
    if not solid(math.floor(x), math.floor(ny)) then y = ny end
    return x, y
  end

  local function tick(win)
    local s = win.state
    if not s.alive then return end
    local dt = 0.08
    if s.mode == "play" and OS.active() == win then
      s.v = s.v * 0.93
      if math.abs(s.v) < 0.05 then s.v = 0 end
      local nx = s.px + math.cos(s.a) * s.v * dt
      local ny = s.py + math.sin(s.a) * s.v * dt
      local bumped = false
      if not solid(math.floor(nx), math.floor(s.py)) then s.px = nx else bumped = true end
      if not solid(math.floor(s.px), math.floor(ny)) then s.py = ny else bumped = true end
      if bumped then
        if math.abs(s.v) > 3 then s.hp = s.hp - math.abs(s.v) * 1.2; OS.sfx("hit") end
        s.v = -s.v * 0.3
      end
      for i, p in ipairs(s.pick) do
        if (p.x - s.px) ^ 2 + (p.y - s.py) ^ 2 < 1.2 then
          s.cash = s.cash + 500; OS.sfx("coin")
          if s.wanted < 5 then OS.sfx("siren") end
          s.wanted = math.min(5, s.wanted + 1)
          s.heat = os.clock()
          local x, y = randRoad(s, 6)
          s.pick[i] = { x = x, y = y }
          if s.cash > (OS.cfg.gtaBest or 0) then OS.cfg.gtaBest = s.cash; OS.dirty = true end
        end
      end
      if s.wanted > 0 and os.clock() - s.heat > 14 then s.wanted = s.wanted - 1; s.heat = os.clock() end
      while #s.cops < s.wanted do spawnCop(s) end
      while #s.cops > s.wanted do table.remove(s.cops) end
      for _, c in ipairs(s.cops) do
        local dx, dy = s.px - c.x, s.py - c.y
        local d = math.sqrt(dx * dx + dy * dy)
        if d > 0.01 then
          local sp = (3.2 + s.wanted * 0.5) * dt
          c.x, c.y = stepTo(c.x, c.y, c.x + dx / d * sp, c.y + dy / d * sp)
          c.a = atan2(dy, dx)
        end
        if d < 1.1 then s.hp = s.hp - 1.4 end
      end
      if s.hp <= 0 then s.hp = 0; s.mode = "dead"; OS.sfx("lose") end
    end
    OS.timer(dt, function() tick(win) end)
  end

  function app.init(win)
    local s = { alive = true }
    win.state = s
    reset(s)
    OS.music("gta", win)
    OS.timer(0.2, function() tick(win) end)
  end
  function app.close(win) win.state.alive = false; OS.musicStop(win) end

  local function gas(s) s.v = math.min(9, s.v + 2.2); if s.v > 8 then OS.sfx("tick") end end
  local function brake(s) s.v = math.max(-3, s.v - 3) end
  local function steer(s, d) s.a = s.a + d * 0.3 end

  function app.key(win, k)
    local s = win.state
    if k == keys.space and s.mode ~= "play" then reset(s) return end
    if s.mode ~= "play" then return end
    if k == keys.up then gas(s) elseif k == keys.down then brake(s)
    elseif k == keys.left then steer(s, -1) elseif k == keys.right then steer(s, 1) end
  end
  function app.char(win, c)
    local s = win.state
    if c == "r" then reset(s) return end
    if s.mode ~= "play" then return end
    if c == "w" then gas(s) elseif c == "s" then brake(s)
    elseif c == "a" then steer(s, -1) elseif c == "d" then steer(s, 1) end
  end

  function app.draw(win, g)
    local s = win.state
    local w, h = g.w, g.h
    local vw, vh = math.max(4, math.floor(w / 2)), math.max(3, h - 2)
    local camx = math.max(1, math.min(MW + 1 - vw, math.floor(s.px - vw / 2)))
    local camy = math.max(1, math.min(MH + 1 - vh, math.floor(s.py - vh / 2)))
    g.fill(1, 1, w, h, C.sp0)
    for ty = 0, vh - 1 do
      for tx = 0, vw - 1 do
        local mx, my = camx + tx, camy + ty
        local col = tileCol(mx, my)
        if col == C.sp0 and (mx % 8 == 1 and my % 2 == 0 or my % 8 == 1 and mx % 2 == 0) and road(mx, my) then
          g.put(1 + tx * 2, 2 + ty, ". ", C.sp1, col)
        else
          g.put(1 + tx * 2, 2 + ty, "  ", C.wht, col)
        end
      end
    end
    local function ent(x, y, txt, fg, bg)
      local sx = 1 + (math.floor(x) - camx) * 2
      local sy = 2 + (math.floor(y) - camy)
      if sx >= 1 and sx < w and sy >= 2 and sy <= vh + 1 then g.put(sx, sy, txt, fg, bg) end
    end
    for _, p in ipairs(s.pick) do ent(p.x, p.y, "$ ", C.yel, C.sp0) end
    for _, c in ipairs(s.cops) do ent(c.x, c.y, heading(c.a), C.wht, C.acc) end
    ent(s.px, s.py, heading(s.a), C.sp0, C.yel)

    local stars = ("*"):rep(s.wanted) .. ("-"):rep(5 - s.wanted)
    local hud = string.format(" $%d  HP %d  Wanted %s  Best $%d", s.cash, math.floor(s.hp), stars, OS.cfg.gtaBest or 0)
    g.put(1, 1, hud .. (" "):rep(w), C.wht, C.sp2)
    local y = h
    local x = 2
    x = x + g.btn(x, y, "<", function() if s.mode == "play" then steer(s, -1) end end) + 1
    x = x + g.btn(x, y, "Gas", function() if s.mode == "play" then gas(s) end end, "pri") + 1
    x = x + g.btn(x, y, "Brake", function() if s.mode == "play" then brake(s) end end) + 1
    x = x + g.btn(x, y, ">", function() if s.mode == "play" then steer(s, 1) end end) + 1
    g.btn(x, y, "New", function() reset(s) end)
    if s.mode == "dead" then
      local msg = string.format(" WRECKED - $%d - Space to retry ", s.cash)
      g.put(math.floor((w - #msg) / 2) + 1, math.floor(h / 2), msg, C.wht, C.red)
    end
  end

  return app
end

end)()
EMBED["wilson"] = (function()
return function(OS)
  local C = OS.C
  local cfg = OS.cfg
  local app = { id = "wilson", title = "Super Wilson World", glyph = " W ", icon = "sp1", fg = "wht", cat = "Games",
    w = 52, h = 17, single = true, minw = 36, minh = 12 }

  -- Wilson the bear is crossing three worlds to reach the castle and rescue his cub.
  -- Original levels, characters and rules: a side-scrolling platformer in the classic style.

  local H, PW, PH = 13, 3, 2
  local SOLID = { ["#"] = true, B = true, ["?"] = true, J = true, U = true, ["="] = true, W = true }

  ---------------------------------------------------------------- level builder
  local function blank(w, name, th)
    local L = { w = w, name = name, th = th, t = {}, ents = {} }
    for y = 1, H do
      local r = {}
      for x = 1, w do r[x] = " " end
      L.t[y] = r
    end
    return L
  end
  local function put(L, x, y, c)
    if x >= 1 and x <= L.w and y >= 1 and y <= H then L.t[y][x] = c end
  end
  local function ground(L, x1, x2, top)
    for x = x1, x2 do for y = top, H do put(L, x, y, "#") end end
  end
  local function plat(L, x1, x2, y, c)
    for x = x1, x2 do put(L, x, y, c or "=") end
  end
  local function row(L, x, y, str)
    for i = 1, #str do
      local c = str:sub(i, i)
      if c ~= "." then put(L, x + i - 1, y, c) end
    end
  end
  local function surface(L, x)
    for y = 1, H do
      if SOLID[L.t[y][x] or " "] then return y end
    end
    return H + 1
  end
  local function walker(L, x) L.ents[#L.ents + 1] = { k = "e", x = x, y = surface(L, x) - 1, dir = -1 } end
  local function wasp(L, x, y) L.ents[#L.ents + 1] = { k = "w", x = x, y = y, x0 = x, y0 = y, dir = -1 } end
  local function spikes(L, x1, x2) for x = x1, x2 do put(L, x, surface(L, x) - 1, "x") end end
  local function honey(L, x1, x2, n) for x = x1, x2 do put(L, x, surface(L, x) - n, "o") end end
  local function rel(L, x, n, str) row(L, x, surface(L, x) - n, str) end
  local function stairs(L, x, n)
    for i = 1, n do
      for k = 0, 1 do
        for y = 11 - i, 10 do put(L, x + (i - 1) * 2 + k, y, "#") end
      end
    end
  end
  local function pole(L, x)
    put(L, x, 4, "F")
    for y = 5, 10 do put(L, x, y, "G") end
  end
  local function pillar(L, x, width, height)
    for xx = x, x + width - 1 do
      for y = 11 - height, 10 do put(L, xx, y, "W") end
    end
  end
  local function lava(L, x1, x2)
    for x = x1, x2 do put(L, x, 12, "L"); put(L, x, 13, "L") end
  end

  local function level1()
    local L = blank(180, "World 1 - Pine Meadow", { sky = "acc", top = "grn", body = "sp1" })
    ground(L, 1, 36, 11); ground(L, 43, 76, 11); ground(L, 84, 118, 11); ground(L, 125, 180, 11)
    honey(L, 12, 14, 1)
    row(L, 18, 7, "BB??BB")
    honey(L, 26, 28, 1); walker(L, 30)
    row(L, 38, 9, "o"); row(L, 40, 8, "oo"); row(L, 42, 9, "o")
    plat(L, 48, 54, 8); row(L, 49, 6, "ooooo"); walker(L, 57)
    row(L, 60, 7, "??BB"); walker(L, 64); honey(L, 66, 69, 1); walker(L, 71)
    plat(L, 79, 81, 9); row(L, 79, 7, "ooo")
    spikes(L, 90, 92)
    plat(L, 95, 101, 8); row(L, 96, 6, "ooooo"); walker(L, 103)
    row(L, 104, 7, "?J??"); walker(L, 108); walker(L, 112)
    plat(L, 120, 122, 9); row(L, 120, 7, "ooo")
    honey(L, 130, 132, 1); walker(L, 135); walker(L, 141)
    row(L, 138, 7, "BB??BB"); spikes(L, 150, 152); walker(L, 156)
    stairs(L, 160, 4)
    pole(L, 172)
    return L
  end

  local function level2()
    local L = blank(200, "World 2 - Amber Hills", { sky = "acc", top = "yel", body = "sp1" })
    ground(L, 1, 26, 11); ground(L, 27, 40, 9); ground(L, 41, 54, 11); ground(L, 62, 74, 11)
    ground(L, 75, 92, 9); ground(L, 93, 106, 7); ground(L, 107, 124, 9)
    ground(L, 131, 150, 11); ground(L, 151, 200, 11)
    walker(L, 12); honey(L, 16, 20, 1); rel(L, 22, 4, "BB??BB")
    walker(L, 31); honey(L, 33, 35, 1); walker(L, 37)
    spikes(L, 44, 46); walker(L, 50)
    plat(L, 56, 60, 8); row(L, 56, 6, "ooooo")
    wasp(L, 66, 7); wasp(L, 71, 6)
    walker(L, 78); honey(L, 80, 82, 1)
    spikes(L, 86, 88); rel(L, 90, 4, "?J")
    walker(L, 96); rel(L, 98, 4, "BB??"); wasp(L, 101, 3)
    walker(L, 110); honey(L, 112, 115, 1); walker(L, 118)
    plat(L, 126, 128, 8); row(L, 126, 6, "ooo")
    walker(L, 135); rel(L, 146, 4, "BB??BB"); spikes(L, 139, 141); walker(L, 145)
    wasp(L, 155, 6); walker(L, 158); walker(L, 164)
    stairs(L, 170, 4)
    pole(L, 186)
    return L
  end

  local function level3()
    local L = blank(220, "World 3 - Bramble Castle", { sky = "sp0", top = "sub", body = "sp2" })
    for x = 1, 220 do put(L, x, 1, "W"); put(L, x, 2, "W") end
    ground(L, 1, 30, 11); lava(L, 31, 37); plat(L, 33, 35, 9)
    ground(L, 38, 70, 11)
    pillar(L, 48, 2, 3); pillar(L, 56, 2, 3)
    walker(L, 42); walker(L, 52); walker(L, 62); honey(L, 44, 46, 1); spikes(L, 66, 68)
    lava(L, 71, 78); plat(L, 73, 74, 9); plat(L, 77, 78, 8)
    ground(L, 79, 110, 11)
    wasp(L, 85, 6); wasp(L, 92, 7); walker(L, 88); walker(L, 98)
    rel(L, 95, 4, "BB??BB"); honey(L, 100, 104, 1)
    pillar(L, 106, 2, 3)
    lava(L, 111, 117); plat(L, 113, 115, 8)
    ground(L, 118, 160, 11)
    pillar(L, 124, 2, 2); pillar(L, 130, 2, 3)
    walker(L, 122); walker(L, 127); walker(L, 134); spikes(L, 138, 141); wasp(L, 145, 5); walker(L, 150)
    rel(L, 146, 4, "?J??")
    lava(L, 161, 170); plat(L, 163, 164, 9); plat(L, 167, 168, 8)
    ground(L, 171, 220, 11)
    walker(L, 176); walker(L, 182); wasp(L, 188, 6); spikes(L, 192, 194); walker(L, 198)
    -- the castle: a lintel over the door, walls behind, and the cub waiting inside
    for x = 208, 218 do for y = 3, 7 do put(L, x, y, "W") end end
    for y = 3, 10 do put(L, 219, y, "W"); put(L, 220, y, "W") end
    for x = 212, 213 do for y = 8, 10 do put(L, x, y, "K") end end
    L.cub = { x = 216, y = 10 }
    return L
  end

  local LEVELS = { level1, level2, level3 }

  ---------------------------------------------------------------- helpers
  local function tileAt(L, x, y)
    if x < 1 or x > L.w or y < 1 or y > H then return " " end
    return L.t[y][x]
  end
  local function solidCell(L, x, y)
    if x < 1 or x > L.w then return true end
    if y < 1 or y > H then return false end
    return SOLID[L.t[y][x]] == true
  end
  local function boxHits(L, x, y, w, h)
    local x1, x2 = math.floor(x), math.ceil(x + w) - 1
    local y1, y2 = math.floor(y), math.ceil(y + h) - 1
    for cy = y1, y2 do
      for cx = x1, x2 do
        if solidCell(L, cx, cy) then return true end
      end
    end
    return false
  end

  local function loadLevel(s, n)
    s.n = n
    s.L = LEVELS[n]()
    s.x, s.y, s.vx, s.vy = 4, 9, 0, 0
    s.face, s.onGround, s.invul, s.t = 1, false, 0, 0
    s.kl, s.kr, s.tapL, s.tapR, s.jump = false, false, 0, 0, 0
    s.mode = "play"
  end

  local function newGame(s)
    s.lives, s.score, s.honey, s.strong = 3, 0, 0, false
    loadLevel(s, 1)
    s.mode = "play"
  end

  local function die(s)
    if s.mode ~= "play" then return end
    s.lives = s.lives - 1
    s.mode = "dead"; s.timer = 8
    s.vy = -1; OS.sfx("die")
  end
  local function hurt(s, fatal)
    if s.mode ~= "play" then return end
    if s.invul > 0 and not fatal then return end
    if s.strong and not fatal then s.strong = false; s.invul = 15; s.vy = -0.6; OS.sfx("hit") return end
    die(s)
  end

  local function bump(s, r)
    local L = s.L
    local x1, x2 = math.floor(s.x), math.ceil(s.x + PW) - 1
    local mid = math.floor(s.x + PW / 2)
    for _, c in ipairs({ mid, mid - 1, mid + 1 }) do
      if c >= x1 and c <= x2 then
        local t = tileAt(L, c, r)
        if t == "?" then L.t[r][c] = "U"; s.honey = s.honey + 3; s.score = s.score + 50; OS.sfx("coin") return
        elseif t == "J" then L.t[r][c] = "U"; s.strong = true; s.score = s.score + 200; OS.sfx("power") return
        elseif t == "B" then L.t[r][c] = " "; s.score = s.score + 10; OS.sfx("bump") return end
      end
    end
  end

  local function moveX(s, dx)
    local nx = s.x + dx
    if boxHits(s.L, nx, s.y, PW, PH) then
      if dx > 0 then nx = math.floor(nx + PW) - PW else nx = math.floor(nx) + 1 end
      s.vx = 0
    end
    s.x = math.max(1, nx)
  end
  local function moveY(s, dy)
    local ny = s.y + dy
    if boxHits(s.L, s.x, ny, PW, PH) then
      if dy > 0 then
        ny = math.floor(ny + PH) - PH
        s.onGround = true
      else
        bump(s, math.floor(ny))
        ny = math.floor(ny) + 1
      end
      s.vy = 0
    end
    s.y = ny
  end

  local function pickups(s)
    local L = s.L
    local x1, x2 = math.floor(s.x), math.ceil(s.x + PW) - 1
    local y1, y2 = math.floor(s.y), math.ceil(s.y + PH) - 1
    for cy = y1, y2 do
      for cx = x1, x2 do
        local c = tileAt(L, cx, cy)
        if c == "o" then
          L.t[cy][cx] = " "; s.honey = s.honey + 1; s.score = s.score + 10; OS.sfx("coin")
          if s.honey % 25 == 0 then s.lives = s.lives + 1 end
        elseif c == "x" then hurt(s, false)
        elseif c == "L" then hurt(s, true)
        elseif c == "G" or c == "F" then
          s.mode = "clear"; s.score = s.score + 500; OS.sfx("win")
          if s.score > (cfg.wilsonBest or 0) then cfg.wilsonBest = s.score; OS.dirty = true end
          return
        elseif c == "K" then
          s.mode = "win"; s.score = s.score + 2000; OS.sfx("win")
          if s.score > (cfg.wilsonBest or 0) then cfg.wilsonBest = s.score; OS.dirty = true end
          return
        end
      end
    end
  end

  local function enemies(s)
    local L = s.L
    for _, e in ipairs(L.ents) do
      if e.alive ~= false then
        if e.k == "e" then
          local nx = e.x + e.dir * 0.25
          local lead = e.dir > 0 and math.floor(nx + 1.99) or math.floor(nx)
          if solidCell(L, lead, e.y) or not solidCell(L, lead, e.y + 1) then e.dir = -e.dir else e.x = nx end
        else
          e.x = e.x + e.dir * 0.3
          if math.abs(e.x - e.x0) > 8 then e.dir = -e.dir end
          e.y = e.y0 + math.floor(math.sin(s.t / 4 + e.x0) * 1.5 + 0.5)
        end
        if s.mode == "play" and s.x < e.x + 2 and s.x + PW > e.x and s.y < e.y + 1 and s.y + PH > e.y then
          if s.vy > 0.1 and (s.y + PH) - e.y < 1.2 then
            e.alive = false; s.vy = -0.9; s.score = s.score + 100; OS.sfx("stomp")
          else hurt(s, false) end
        end
      end
    end
  end

  local function update(s)
    local L = s.L
    s.t = s.t + 1
    if s.invul > 0 then s.invul = s.invul - 1 end
    local ax = 0
    if s.kl or s.tapL > 0 then ax = ax - 1 end
    if s.kr or s.tapR > 0 then ax = ax + 1 end
    s.tapL = math.max(0, s.tapL - 1); s.tapR = math.max(0, s.tapR - 1)
    if ax ~= 0 then
      s.vx = s.vx + ax * 0.3; s.face = ax
    else
      s.vx = s.vx * 0.65
      if math.abs(s.vx) < 0.04 then s.vx = 0 end
    end
    s.vx = math.max(-0.9, math.min(0.9, s.vx))
    if s.jump > 0 then
      if s.onGround then s.vy = -1.3; s.jump = 0; OS.sfx("jump") else s.jump = s.jump - 1 end
    end
    s.vy = math.min(1.1, s.vy + 0.2)
    s.onGround = false
    for _ = 1, 3 do
      moveX(s, s.vx / 3)
      moveY(s, s.vy / 3)
    end
    pickups(s)
    if s.mode == "play" then enemies(s) end
    if s.mode == "play" and s.y > H + 3 then die(s) end
  end

  local function tick(win)
    local s = win.state
    if not s.alive then return end
    if OS.active() ~= win then
      s.kl, s.kr = false, false
    elseif s.mode == "play" and not s.paused then
      update(s)
    elseif s.mode == "dead" then
      s.vy = s.vy + 0.2; s.y = s.y + s.vy / 2
      s.timer = s.timer - 1
      if s.timer <= 0 then
        if s.lives <= 0 then s.mode = "over" else loadLevel(s, s.n) end
      end
    end
    OS.timer(0.1, function() tick(win) end)
  end

  local function advance(s)
    if s.mode == "title" then newGame(s)
    elseif s.mode == "clear" then loadLevel(s, s.n + 1)
    elseif s.mode == "over" or s.mode == "win" then s.mode = "title" end
  end

  function app.init(win)
    local s = { alive = true, mode = "title", n = 1, lives = 3, score = 0, honey = 0, strong = false, paused = false,
      kl = false, kr = false, tapL = 0, tapR = 0, jump = 0, invul = 0, t = 0 }
    win.state = s
    s.L = LEVELS[1]()
    s.x, s.y, s.vx, s.vy, s.face, s.onGround = 4, 9, 0, 0, 1, true
    OS.music("wilson", win)
    OS.timer(0.2, function() tick(win) end)
  end
  function app.close(win) win.state.alive = false; OS.musicStop(win) end

  function app.key(win, k)
    local s = win.state
    if k == keys.left or k == keys.a then s.kl = true
    elseif k == keys.right or k == keys.d then s.kr = true
    elseif k == keys.space or k == keys.enter then
      if s.mode == "play" then s.jump = 3 else advance(s) end
    elseif k == keys.up or k == keys.w or k == keys.z then
      if s.mode == "play" then s.jump = 3 end
    end
  end
  function app.keyUp(win, k)
    local s = win.state
    if k == keys.left or k == keys.a then s.kl = false
    elseif k == keys.right or k == keys.d then s.kr = false end
  end
  function app.char(win, c)
    local s = win.state
    if c == "p" and s.mode == "play" then s.paused = not s.paused end
  end

  ---------------------------------------------------------------- drawing
  local function draw(win, g)
    local s = win.state
    local L = s.L
    local w, h = g.w, g.h
    local vrows = math.max(3, h - 2)
    local bc = colors.toBlit
    local th = L.th
    local sky, top, body = bc(C[th.sky]), bc(C[th.top]), bc(C[th.body])
    local blk, wht, yel, red = bc(C.sp0), bc(C.wht), bc(C.yel), bc(C.red)
    local stone, stoneFg, platB, usedB = bc(C.dock), bc(C.sub), bc(C.sub), bc(C.sp2)
    local brown = bc(C.sp1)

    local camx = L.w <= w and 1 or math.max(1, math.min(L.w - w + 1, math.floor(s.x + PW / 2 - w / 3)))
    local camy = vrows >= H and 1 or math.max(1, math.min(H - vrows + 1, math.floor(s.y + PH / 2 - vrows / 2)))

    local rows = {}
    for r = 1, vrows do
      local t, f, b = {}, {}, {}
      local ty = camy + r - 1
      for x = 1, w do
        local tx = camx + x - 1
        local c = (tx < 1 or tx > L.w) and "W" or ((ty < 1 or ty > H) and " " or L.t[ty][tx])
        local ch, fg, bg = " ", "0", sky
        if c == "#" then
          bg = SOLID[tileAt(L, tx, ty - 1)] and body or top
        elseif c == "W" then
          ch = ((tx + ty) % 2 == 0) and "." or " "; fg = stoneFg; bg = stone
        elseif c == "B" then
          ch = (tx % 2 == 0) and "[" or "]"; fg = blk; bg = red
        elseif c == "?" or c == "J" then
          ch = "?"; fg = blk; bg = yel
        elseif c == "U" then
          bg = usedB
        elseif c == "=" then
          ch = "-"; fg = blk; bg = platB
        elseif c == "o" then
          ch = "o"; fg = yel
        elseif c == "x" then
          ch = "^"; fg = wht
        elseif c == "G" then
          ch = "|"; fg = wht
        elseif c == "F" then
          ch = ">"; fg = red
        elseif c == "L" then
          ch = "~"; fg = yel; bg = red
        elseif c == "K" then
          bg = blk
        end
        t[x], f[x], b[x] = ch, fg, bg
      end
      rows[r] = { t, f, b }
    end

    local function plot(rx, ry, ch, fg, bg)
      local r, c = ry - camy + 1, rx - camx + 1
      if r >= 1 and r <= vrows and c >= 1 and c <= w then
        rows[r][1][c] = ch; rows[r][2][c] = fg; rows[r][3][c] = bg
      end
    end

    for _, e in ipairs(L.ents) do
      if e.alive ~= false then
        local ex, ey = math.floor(e.x + 0.5), e.y
        if e.k == "e" then
          plot(ex, ey, "<", wht, red); plot(ex + 1, ey, ">", wht, red)
        else
          local wing = (s.t % 2 == 0) and "v" or "^"
          plot(ex, ey, wing, blk, yel); plot(ex + 1, ey, wing, blk, yel)
        end
      end
    end

    if L.cub then
      plot(L.cub.x, L.cub.y, "o", yel, brown); plot(L.cub.x + 1, L.cub.y, "o", yel, brown)
      local msg = "HELP!"
      for i = 1, #msg do plot(L.cub.x - 1 + i, L.cub.y - 2, msg:sub(i, i), yel, sky) end
    end

    if s.mode ~= "dead" or s.t % 2 == 0 then
      if not (s.invul > 0 and s.t % 2 == 0) then
        local px, py = math.floor(s.x + 0.5), math.floor(s.y + 0.5)
        local ear = s.strong and yel or blk
        plot(px, py, "n", ear, brown); plot(px + 1, py, ".", blk, brown); plot(px + 2, py, "n", ear, brown)
        local step = (s.onGround and s.vx ~= 0 and s.t % 2 == 0)
        if s.face > 0 then
          plot(px, py + 1, step and "/" or "(", blk, brown); plot(px + 1, py + 1, "o", blk, brown); plot(px + 2, py + 1, ">", blk, yel)
        else
          plot(px, py + 1, "<", blk, yel); plot(px + 1, py + 1, "o", blk, brown); plot(px + 2, py + 1, step and "\\" or ")", blk, brown)
        end
      end
    end

    for r = 1, vrows do
      g.blit(1, r + 1, table.concat(rows[r][1]), table.concat(rows[r][2]), table.concat(rows[r][3]))
    end

    -- HUD
    local hud = string.format(" WILSON x%d  Honey %d  Score %d%s", s.lives, s.honey, s.score, s.strong and "  [STRONG]" or "")
    g.put(1, 1, hud .. (" "):rep(w), C.wht, C.sp0)
    local wn = L.name:match("^(World %d)") or ""
    g.put(w - #wn - 1, 1, wn, C.yel, C.sp0)

    -- touch / mouse controls
    local bx = 2
    g.fill(1, h, w, 1, C.sp0)
    bx = bx + g.btn(bx, h, "<", function() s.tapL = 3 end, "dark") + 1
    bx = bx + g.btn(bx, h, ">", function() s.tapR = 3 end, "dark") + 1
    bx = bx + g.btn(bx, h, "Jump", function() if s.mode == "play" then s.jump = 3 else advance(s) end end, "pri") + 1
    g.btn(bx, h, s.paused and "Resume" or "Pause", function() if s.mode == "play" then s.paused = not s.paused end end, "dark")

    local function banner(lines, bg)
      local y0 = math.floor((h - #lines) / 2)
      for i, l in ipairs(lines) do
        g.put(math.floor((w - #l) / 2) + 1, y0 + i, " " .. l .. " ", C.wht, bg or C.sp0)
      end
    end
    if s.mode == "title" then
      banner({ "", "  S U P E R   W I L S O N   W O R L D  ", "",
        "The cub is locked in the castle.", "Wilson the bear is going to get him back!", "",
        "A/D or arrows: move   W/Up/Space: jump", "Stomp beetles, bump blocks, grab honey", "",
        "Best " .. (cfg.wilsonBest or 0) .. "   -   press Space", "" })
    elseif s.mode == "clear" then
      banner({ "", " " .. L.name .. " cleared! ", " Score " .. s.score .. " ", " Space: next world ", "" }, C.grn)
    elseif s.mode == "over" then
      banner({ "", " GAME OVER ", " Score " .. s.score .. " ", " Space: title ", "" }, C.red)
    elseif s.mode == "win" then
      banner({ "", " Wilson reached the castle! ", " The cub is safe - they walk home together. ",
        " Score " .. s.score .. " ", " Space: title ", "" }, C.acc)
    elseif s.paused then
      banner({ "", " PAUSED ", "" })
    elseif s.t < 15 and s.mode == "play" then
      banner({ L.name })
    end
  end

  function app.draw(win, g) draw(win, g) end

  return app
end

end)()
EMBED["bomber"] = (function()
return function(OS)
  local C = OS.C
  local cfg = OS.cfg
  local app = { id = "bomber", title = "Bomb Maze", glyph = " * ", icon = "red", fg = "wht", cat = "Games",
    w = 34, h = 17, single = true, minw = 34, minh = 17 }

  -- Original grid-bomber: blast the bricks, clear the blobs, find the exit door.
  local GW, GH = 15, 13
  local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

  local function isWall(x, y)
    return x == 1 or y == 1 or x == GW or y == GH or (x % 2 == 1 and y % 2 == 1)
  end

  local function newLevel(s)
    local gr = {}
    local bricks = {}
    for y = 1, GH do
      gr[y] = {}
      for x = 1, GW do
        if isWall(x, y) then gr[y][x] = "#"
        elseif (x + y <= 5) then gr[y][x] = "."
        elseif math.random() < 0.55 then gr[y][x] = "b"; bricks[#bricks + 1] = { x, y }
        else gr[y][x] = "." end
      end
    end
    s.grid = gr
    local d = bricks[math.random(1, math.max(1, #bricks))] or { GW - 1, GH - 1 }
    s.door = { x = d[1], y = d[2], shown = false }
    s.bombs, s.flames, s.items, s.enemies = {}, {}, {}, {}
    local want = math.min(8, 3 + s.level)
    local tries = 0
    while #s.enemies < want and tries < 500 do
      tries = tries + 1
      local x, y = math.random(2, GW - 1), math.random(2, GH - 1)
      if gr[y][x] == "." and (x - 2) + (y - 2) >= 6 then
        local taken = false
        for _, e in ipairs(s.enemies) do if e.x == x and e.y == y then taken = true end end
        if not taken then s.enemies[#s.enemies + 1] = { x = x, y = y, d = math.random(1, 4), alive = true } end
      end
    end
    s.px, s.py, s.cd, s.invul, s.t = 2, 2, 0, 20, 0
    s.mode = "play"
  end

  local function newGame(s)
    s.level, s.lives, s.score, s.maxBombs, s.range = 1, 3, 0, 1, 2
    newLevel(s)
  end

  local function bombAt(s, x, y)
    for _, b in ipairs(s.bombs) do if not b.dead and b.x == x and b.y == y then return b end end
  end
  local function blocked(s, x, y, isPlayer)
    local c = s.grid[y] and s.grid[y][x]
    if c ~= "." then return true end
    local b = bombAt(s, x, y)
    if b and not (isPlayer and b.pass) then return true end
    return false
  end

  local function die(s)
    if s.mode ~= "play" or s.invul > 0 then return end
    s.lives = s.lives - 1
    s.mode = "dead"; s.timer = 10; OS.sfx("die")
  end

  local function destroyBrick(s, x, y)
    s.grid[y][x] = "."
    s.score = s.score + 10
    if s.door.x == x and s.door.y == y then s.door.shown = true
    elseif math.random() < 0.25 then s.items[y * 100 + x] = math.random() < 0.5 and "B" or "F" end
  end

  local function explode(s, b)
    b.dead = true; OS.sfx("boom")
    local cells = { { b.x, b.y } }
    for _, d in ipairs(DIRS) do
      for i = 1, b.range do
        local x, y = b.x + d[1] * i, b.y + d[2] * i
        local t = s.grid[y][x]
        if t == "#" then break end
        cells[#cells + 1] = { x, y }
        if t == "b" then destroyBrick(s, x, y) break end
        local ob = bombAt(s, x, y)
        if ob then ob.t = 0 end
      end
    end
    for _, c in ipairs(cells) do s.flames[#s.flames + 1] = { x = c[1], y = c[2], t = 4 } end
  end

  local function processBombs(s)
    local again = true
    while again do
      again = false
      for _, b in ipairs(s.bombs) do
        if not b.dead and b.t <= 0 then explode(s, b); again = true end
      end
    end
    local keep = {}
    for _, b in ipairs(s.bombs) do if not b.dead then keep[#keep + 1] = b end end
    s.bombs = keep
  end

  local function alive(s)
    local n = 0
    for _, e in ipairs(s.enemies) do if e.alive then n = n + 1 end end
    return n
  end

  local function pickup(s)
    local k = s.py * 100 + s.px
    local it = s.items[k]
    if it then
      s.items[k] = nil; s.score = s.score + 50; OS.sfx("power")
      if it == "B" then s.maxBombs = math.min(6, s.maxBombs + 1) else s.range = math.min(8, s.range + 1) end
    end
    if s.door.shown and s.door.x == s.px and s.door.y == s.py and alive(s) == 0 then
      s.mode = "clear"; s.score = s.score + 500 + s.level * 100; OS.sfx("win")
      if s.score > (cfg.bomberBest or 0) then cfg.bomberBest = s.score; OS.dirty = true end
    end
  end

  local function tryMove(s, dx, dy)
    if s.mode ~= "play" or s.cd > 0 or s.paused then return end
    local nx, ny = s.px + dx, s.py + dy
    if blocked(s, nx, ny, true) then return end
    s.px, s.py, s.cd = nx, ny, 2
    for _, b in ipairs(s.bombs) do
      if b.pass and (b.x ~= s.px or b.y ~= s.py) then b.pass = false end
    end
    pickup(s)
  end

  local function placeBomb(s)
    if s.mode ~= "play" or s.paused then return end
    if #s.bombs >= s.maxBombs or bombAt(s, s.px, s.py) then return end
    s.bombs[#s.bombs + 1] = { x = s.px, y = s.py, t = 30, range = s.range, pass = true }
    OS.sfx("fuse")
  end

  local function tick(win)
    local s = win.state
    if not s.alive then return end
    if s.mode == "play" and not s.paused and OS.active() == win then
      s.t = s.t + 1
      if s.cd > 0 then s.cd = s.cd - 1 end
      if s.invul > 0 then s.invul = s.invul - 1 end
      for _, b in ipairs(s.bombs) do b.t = b.t - 1 end
      processBombs(s)
      local fset = {}
      for i = #s.flames, 1, -1 do
        local f = s.flames[i]
        fset[f.y * 100 + f.x] = true
        f.t = f.t - 1
        if f.t <= 0 then table.remove(s.flames, i) end
      end
      if s.t % 4 == 0 then
        for _, e in ipairs(s.enemies) do
          if e.alive then
            local d = DIRS[e.d]
            if blocked(s, e.x + d[1], e.y + d[2], false) or math.random(1, 6) == 1 then
              local opts = {}
              for i, dd in ipairs(DIRS) do
                if not blocked(s, e.x + dd[1], e.y + dd[2], false) then opts[#opts + 1] = i end
              end
              if #opts > 0 then e.d = opts[math.random(1, #opts)] end
              d = DIRS[e.d]
            end
            if not blocked(s, e.x + d[1], e.y + d[2], false) then e.x, e.y = e.x + d[1], e.y + d[2] end
          end
        end
      end
      for _, e in ipairs(s.enemies) do
        if e.alive then
          if fset[e.y * 100 + e.x] then e.alive = false; s.score = s.score + 100; OS.sfx("stomp")
          elseif e.x == s.px and e.y == s.py then die(s) end
        end
      end
      if fset[s.py * 100 + s.px] then die(s) end
      pickup(s)
    elseif s.mode == "dead" then
      s.timer = s.timer - 1
      if s.timer <= 0 then
        if s.lives <= 0 then
          s.mode = "over"; OS.sfx("lose")
          if s.score > (cfg.bomberBest or 0) then cfg.bomberBest = s.score; OS.dirty = true end
        else
          s.px, s.py, s.invul, s.mode = 2, 2, 25, "play"
          s.bombs = {}
        end
      end
    end
    OS.timer(0.1, function() tick(win) end)
  end

  local function advance(s)
    if s.mode == "title" or s.mode == "over" then newGame(s)
    elseif s.mode == "clear" then s.level = s.level + 1; newLevel(s) end
  end

  function app.init(win)
    local s = { alive = true, mode = "title", level = 1, lives = 3, score = 0, maxBombs = 1, range = 2,
      grid = {}, bombs = {}, flames = {}, items = {}, enemies = {}, door = { x = 0, y = 0 },
      px = 2, py = 2, cd = 0, invul = 0, t = 0, paused = false }
    win.state = s
    OS.music("bomber", win)
    OS.timer(0.2, function() tick(win) end)
  end
  function app.close(win) win.state.alive = false; OS.musicStop(win) end

  function app.key(win, k)
    local s = win.state
    if k == keys.left or k == keys.a then tryMove(s, -1, 0)
    elseif k == keys.right or k == keys.d then tryMove(s, 1, 0)
    elseif k == keys.up or k == keys.w then tryMove(s, 0, -1)
    elseif k == keys.down or k == keys.s then tryMove(s, 0, 1)
    elseif k == keys.space or k == keys.enter then
      if s.mode == "play" then placeBomb(s) else advance(s) end
    end
  end
  function app.char(win, c)
    local s = win.state
    if c == "p" and s.mode == "play" then s.paused = not s.paused end
  end

  function app.draw(win, g)
    local s = win.state
    local w, h = g.w, g.h
    g.fill(1, 1, w, h, C.sp0)
    local ox = math.max(1, math.floor((w - GW * 2) / 2) + 1)
    local bc = colors.toBlit
    local floorB, pillarB, brickB = bc(C.sp2), bc(C.sub), bc(C.red)
    local blk, wht, yel, redB = bc(C.sp0), bc(C.wht), bc(C.yel), bc(C.red)
    local brown, grn, acc = bc(C.sp1), bc(C.grn), bc(C.acc)

    if s.mode ~= "title" then
      local fset = {}
      for _, f in ipairs(s.flames) do fset[f.y * 100 + f.x] = true end
      local eset = {}
      for _, e in ipairs(s.enemies) do if e.alive then eset[e.y * 100 + e.x] = true end end
      for y = 1, GH do
        local t, f, b = {}, {}, {}
        for x = 1, GW do
          local key = y * 100 + x
          local c1, c2, fg, bg = " ", " ", "0", floorB
          local tile = s.grid[y][x]
          if tile == "#" then bg = pillarB; c1, c2 = "#", "#"; fg = bc(C.dock)
          elseif tile == "b" then bg = brickB; c1, c2 = "[", "]"; fg = blk
          elseif fset[key] then bg = yel; c1, c2 = "*", "*"; fg = redB
          else
            if s.door.shown and s.door.x == x and s.door.y == y then bg = acc; c1, c2 = "[", "]"; fg = wht end
            local it = s.items[key]
            if it then c1, c2 = "+", it; fg = (it == "B") and wht or yel end
            local bomb = bombAt(s, x, y)
            if bomb then
              c1, c2 = "(", ")"; fg = (bomb.t < 10 and s.t % 2 == 0) and redB or wht
            end
            if eset[key] then bg = grn; c1, c2 = "o", "o"; fg = blk end
            if s.px == x and s.py == y and (s.mode == "play" or s.mode == "clear") and not (s.invul > 0 and s.t % 2 == 0) then
              bg = brown; c1, c2 = "o", "o"; fg = yel
            end
          end
          t[#t + 1] = c1 .. c2; f[#f + 1] = fg .. fg; b[#b + 1] = bg .. bg
        end
        g.blit(ox, y + 1, table.concat(t), table.concat(f), table.concat(b))
      end
    end

    local hud = string.format(" Lvl %d  x%d  Score %d  Bombs %d  Range %d", s.level, s.lives, s.score, s.maxBombs, s.range)
    g.put(1, 1, hud .. (" "):rep(w), C.wht, C.sp0)

    local bx = 1
    bx = bx + g.btn(bx, h, "<", function() tryMove(s, -1, 0) end, "dark") + 1
    bx = bx + g.btn(bx, h, "^", function() tryMove(s, 0, -1) end, "dark") + 1
    bx = bx + g.btn(bx, h, "v", function() tryMove(s, 0, 1) end, "dark") + 1
    bx = bx + g.btn(bx, h, ">", function() tryMove(s, 1, 0) end, "dark") + 1
    g.btn(bx, h, "Bomb", function() if s.mode == "play" then placeBomb(s) else advance(s) end end, "danger")

    local function banner(lines, bg)
      local y0 = math.floor((h - #lines) / 2)
      for i, l in ipairs(lines) do
        g.put(math.floor((w - #l) / 2) + 1, y0 + i, " " .. l .. " ", C.wht, bg or C.sp0)
      end
    end
    if s.mode == "title" then
      banner({ "", "B O M B   M A Z E", "", "Arrows/WASD move, Space drops a bomb", "Blast bricks, clear every blob,",
        "then step on the exit door.", "", "Best " .. (cfg.bomberBest or 0) .. " - press Space", "" })
    elseif s.mode == "clear" then
      banner({ "", " LEVEL CLEAR! ", " Space: next level ", "" }, C.grn)
    elseif s.mode == "over" then
      banner({ "", " GAME OVER ", " Score " .. s.score .. " ", " Space: new game ", "" }, C.red)
    elseif s.paused then
      banner({ "", " PAUSED ", "" })
    elseif s.mode == "play" and alive(s) == 0 and s.door.shown then
      g.put(2, h - 1, "Exit is open!", C.yel, C.sp0)
    end
  end

  return app
end

end)()
EMBED["voxel"] = (function()
return function(OS)
  local C = OS.C
  -- Blockworld: an original first-person block sandbox with a machine-tech progression
  -- (ore -> dust -> ingots -> alloys -> circuits). Not Minecraft and not GregTech.
  local app = { id = "blockworld", title = "Blockworld", glyph = " B ", icon = "grn", fg = "wht", cat = "Games",
    w = 56, h = 22, single = true, minw = 34, minh = 14, startMax = true, fullH = true, noclick = true,
    pal = { sp = 0x6CA8FF, wp = 0x1B2F6B, dock = 0x1F6B2A, sp1 = 0x8B5A2B, sp2 = 0x8A8A92 } }

  local floor, ceil, abs, sin, cos, sqrt, min, max = math.floor, math.ceil, math.abs, math.sin, math.cos, math.sqrt, math.min, math.max
  local NX, NZ, NY, SEA = 40, 40, 20, 6
  local DAYLEN = 240
  local FILE = "/win10/data/blockworld.dat"
  local function bl(c) return colors.toBlit(c) end
  local BK, WH, SKY, DEEP, GRS, LEAF, DIRT, STONE, SAND, RED, ACC, DARK, MAUVE =
    bl(C.sp0), bl(C.wht), bl(C.sp), bl(C.wp), bl(C.grn), bl(C.dock), bl(C.sp1), bl(C.sp2), bl(C.yel), bl(C.red), bl(C.acc), bl(C.bar), bl(C.sub)
  local LV1 = { " ", "\129", "\137", "\153", "\158", "\159" }
  local LV2 = { " ", "\130", "\134", "\150", "\157", "\159" }
  local SHN = { "Off", "Shaded", "Ultra" }

  local WLD, HM = {}, {}

  ---------------------------------------------------------------- blocks
  local B = {}
  local function def(id, name, o) o.name = name; B[id] = o end
  local function spk(base, acc, p)
    return function(s, x, y, z, face, top, u, v, r) if r < p then return acc end return base end
  end
  local function machTex(body, trim, glow)
    return function(s, x, y, z, face, top, u, v, r)
      local m = s.mach[(y * NZ + z) * NX + x + 1]
      local act = m and (m.job or (m.burn or 0) > 0)
      if face ~= 2 and u > 0.25 and u < 0.75 and v > 0.2 and v < 0.6 then return act and glow or BK end
      if r < 0.12 then return trim end
      return body
    end
  end
  def(1, "Grass", { hard = 1, drop = "dirt", tex = function(s, x, y, z, face, top, u, v, r)
    if top then return r < 0.2 and LEAF or GRS end
    if face ~= 2 and v > 0.7 then return GRS end
    return r < 0.15 and BK or DIRT
  end })
  def(2, "Dirt", { hard = 1, drop = "dirt", put = "dirt", tex = spk(DIRT, BK, 0.14) })
  def(3, "Stone", { hard = 6, drop = "cobble", put = "stone", tex = spk(STONE, DARK, 0.18) })
  def(4, "Cobblestone", { hard = 5, drop = "cobble", put = "cobble", tex = spk(STONE, BK, 0.35) })
  def(5, "Sand", { hard = 1, drop = "sand", put = "sand", tex = spk(SAND, WH, 0.15) })
  def(6, "Log", { hard = 3, drop = "log", put = "log", tex = function(s, x, y, z, face, top, u, v, r)
    if face == 2 then local du, dv = u - 0.5, v - 0.5; return (du * du + dv * dv < 0.12) and SAND or DIRT end
    return r < 0.3 and BK or DIRT
  end })
  def(7, "Planks", { hard = 3, drop = "planks", put = "planks", tex = function(s, x, y, z, face, top, u, v, r)
    return (v % 0.34 < 0.07) and DIRT or SAND
  end })
  def(8, "Leaves", { hard = 1, tex = spk(LEAF, GRS, 0.3) })
  def(9, "Water", { hard = 99, tr = "water", tex = function() return DEEP end })
  def(10, "Coal Ore", { hard = 6, drop = "coal", tier = 0, tex = spk(STONE, BK, 0.32) })
  def(11, "Copper Ore", { hard = 7, drop = "copper_ore", tier = 1, tex = spk(STONE, RED, 0.3) })
  def(12, "Tin Ore", { hard = 7, drop = "tin_ore", tier = 1, tex = spk(STONE, WH, 0.3) })
  def(13, "Iron Ore", { hard = 8, drop = "iron_ore", tier = 1, tex = spk(STONE, MAUVE, 0.32) })
  def(14, "Gold Ore", { hard = 9, drop = "gold_ore", tier = 2, tex = spk(STONE, SAND, 0.36) })
  def(15, "Glass", { hard = 1, drop = "glass", put = "glass", tr = "glass", tex = function() return WH end })
  def(16, "Bedrock", { hard = 99, tex = spk(BK, DARK, 0.3) })
  def(17, "Cable", { hard = 2, drop = "cable", put = "cable", tex = spk(DARK, SAND, 0.3) })
  def(18, "Furnace", { hard = 5, drop = "furnace", put = "furnace", mach = "furnace", tex = machTex(STONE, DARK, RED) })
  def(19, "Generator", { hard = 5, drop = "generator", put = "generator", mach = "gen", tex = machTex(SAND, BK, RED) })
  def(20, "Macerator", { hard = 5, drop = "macerator", put = "macerator", mach = "macerator", tex = machTex(ACC, WH, SAND) })
  def(21, "Alloy Smelter", { hard = 5, drop = "alloy", put = "alloy", mach = "alloy", tex = machTex(MAUVE, RED, SAND) })
  def(22, "Compressor", { hard = 5, drop = "compressor", put = "compressor", mach = "compressor", tex = machTex(DARK, WH, ACC) })
  def(23, "Assembler", { hard = 5, drop = "assembler", put = "assembler", mach = "assembler", tex = machTex(DEEP, SAND, WH) })
  def(24, "Machine Casing", { hard = 4, drop = "casing", put = "casing", tex = function(s, x, y, z, face, top, u, v, r)
    if (u < 0.2 or u > 0.8) and (v < 0.2 or v > 0.8) then return ACC end
    return DARK
  end })
  def(25, "Tech Lamp", { hard = 1, drop = "lamp", put = "lamp", emit = true, tex = function(s, x, y, z, face, top, u, v, r)
    return r < 0.2 and SAND or WH
  end })
  local ITEMBLOCK, PLACEABLE = {}, { "dirt", "stone", "cobble", "sand", "log", "planks", "glass", "cable", "casing", "lamp",
    "furnace", "generator", "macerator", "alloy", "compressor", "assembler" }
  for id, d in pairs(B) do if d.put then ITEMBLOCK[d.put] = id end end

  local NAME = { copper = "Copper Ingot", tin = "Tin Ingot", iron = "Iron Ingot", gold = "Gold Ingot", bronze = "Bronze Ingot",
    steel = "Steel Ingot", pick1 = "Wood Pickaxe", pick2 = "Bronze Pickaxe", pick3 = "Steel Pickaxe", lamp = "Tech Lamp",
    alloy = "Alloy Smelter", casing = "Machine Casing", iron_plate = "Iron Plate", circuit = "Circuit" }
  local function nm(k)
    if NAME[k] then return NAME[k] end
    return (k:gsub("_", " "):gsub("(%a)(%w*)", function(a, b) return a:upper() .. b end))
  end

  ---------------------------------------------------------------- recipes
  local R = {}
  local function rc(m, o, n, i, t, extra)
    local r = { m = m, o = o, n = n, i = i, t = t or 0, ri = #R + 1 }
    if extra then for k, v in pairs(extra) do r[k] = v end end
    R[#R + 1] = r
  end
  rc("hand", "planks", 4, { { "log", 1 } })
  rc("hand", "pick1", 1, { { "planks", 4 } })
  rc("hand", "furnace", 1, { { "cobble", 8 } })
  rc("hand", "bronze", 4, { { "copper", 3 }, { "tin", 1 } })
  rc("hand", "iron_plate", 1, { { "iron", 2 } })
  rc("hand", "cable", 4, { { "tin", 1 } })
  rc("hand", "casing", 1, { { "bronze", 6 } })
  rc("hand", "pick2", 1, { { "bronze", 3 }, { "planks", 2 } })
  rc("hand", "generator", 1, { { "casing", 1 }, { "furnace", 1 }, { "cable", 2 } })
  rc("hand", "macerator", 1, { { "casing", 1 }, { "cable", 2 }, { "iron_plate", 2 } })
  rc("hand", "alloy", 1, { { "casing", 1 }, { "furnace", 1 }, { "cable", 2 } })
  rc("hand", "compressor", 1, { { "casing", 1 }, { "cable", 2 }, { "cobble", 4 } })
  rc("hand", "assembler", 1, { { "casing", 1 }, { "cable", 4 }, { "iron_plate", 2 } })
  rc("hand", "pick3", 1, { { "steel", 3 }, { "planks", 2 } })
  rc("hand", "circuit", 1, { { "iron_plate", 1 }, { "copper", 4 } })
  rc("hand", "lamp", 1, { { "glass", 1 }, { "circuit", 1 }, { "cable", 1 } })
  for _, m in ipairs({ "copper", "tin", "iron", "gold" }) do
    rc("furnace", m, 1, { { m .. "_ore", 1 }, { "coal", 1 } }, 3)
    rc("furnace", m, 2, { { m .. "_dust", 2 }, { "coal", 1 } }, 3)
  end
  rc("furnace", "glass", 1, { { "sand", 1 }, { "coal", 1 } }, 3)
  rc("furnace", "stone", 1, { { "cobble", 1 }, { "coal", 1 } }, 3)
  rc("furnace", "steel", 1, { { "iron", 1 }, { "coal", 2 } }, 6)
  for _, m in ipairs({ "copper", "tin", "iron", "gold" }) do rc("macerator", m .. "_dust", 2, { { m .. "_ore", 1 } }, 3) end
  rc("macerator", "sand", 1, { { "cobble", 1 } }, 2)
  rc("alloy", "bronze", 4, { { "copper", 3 }, { "tin", 1 } }, 3)
  rc("alloy", "steel", 2, { { "iron", 2 }, { "coal", 1 } }, 4)
  rc("compressor", "iron_plate", 1, { { "iron", 1 } }, 2)
  rc("compressor", "stone", 1, { { "cobble", 2 } }, 2)
  rc("assembler", "circuit", 2, { { "iron_plate", 1 }, { "copper", 2 } }, 4)
  rc("assembler", "casing", 2, { { "bronze", 10 } }, 4)
  rc("assembler", "lamp", 2, { { "glass", 1 }, { "circuit", 1 }, { "cable", 1 } }, 3)
  rc("gen", nil, 0, { { "coal", 1 } }, 0, { b = 60, l = "Burn Coal (60s)" })
  rc("gen", nil, 0, { { "planks", 2 } }, 0, { b = 15, l = "Burn Planks (15s)" })
  rc("gen", nil, 0, { { "log", 1 } }, 0, { b = 10, l = "Burn Log (10s)" })
  local RBY = {}
  for _, r in ipairs(R) do RBY[r.m] = RBY[r.m] or {}; RBY[r.m][#RBY[r.m] + 1] = r end
  local KIND = { [18] = "furnace", [19] = "gen", [20] = "macerator", [21] = "alloy", [22] = "compressor", [23] = "assembler" }
  local KTITLE = { hand = "Hand Crafting", furnace = "Furnace", gen = "Generator", macerator = "Macerator (powered)",
    alloy = "Alloy Smelter (powered)", compressor = "Compressor (powered)", assembler = "Assembler (powered)" }
  local NEEDP = { macerator = true, alloy = true, compressor = true, assembler = true }
  local GOALS = {
    { "Punch a tree to collect logs  [F]", "log" }, { "Craft planks  [E]", "planks" }, { "Craft a wood pickaxe", "pick1" },
    { "Mine 8 cobble, craft a furnace", "furnace" }, { "Smelt a copper ingot in a furnace  [R]", "copper" },
    { "Smelt a tin ingot", "tin" }, { "Make bronze: 3 copper + 1 tin", "bronze" }, { "Craft a bronze pickaxe", "pick2" },
    { "Craft a machine casing", "casing" }, { "Craft a generator, place and fuel it", "generator" },
    { "Craft a macerator: ore -> 2 dust", "macerator" }, { "Make an iron plate", "iron_plate" },
    { "Make steel (iron + 2 coal)", "steel" }, { "Build a circuit", "circuit" }, { "Craft a Tech Lamp", "lamp" },
  }

  ---------------------------------------------------------------- world
  local CH = {}
  for i = 0, 60 do CH[i] = string.char(i + 48) end
  local function I(x, y, z) return (y * NZ + z) * NX + x + 1 end
  local function get(x, y, z)
    if y < 0 then return 16 end
    if x < 0 or x >= NX or z < 0 or z >= NZ then return -1 end
    if y >= NY then return 0 end
    return WLD[(y * NZ + z) * NX + x + 1]
  end
  local function solid(x, y, z)
    local id = get(x, y, z)
    return id ~= 0 and id ~= 9
  end
  local function colTop(x, z)
    for y = NY - 1, 0, -1 do
      local id = WLD[I(x, y, z)]
      if id ~= 0 and id ~= 9 and id ~= 15 then return y end
    end
    return 0
  end
  local function hash2(x, z, sd) local n = sin(x * 127.1 + z * 311.7 + sd * 74.7) * 43758.5453; return n - floor(n) end
  local function hash3(a, b, c) local n = sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453; return n - floor(n) end
  local function vnoise(x, z, sd)
    local xi, zi = floor(x), floor(z)
    local xf, zf = x - xi, z - zi
    xf = xf * xf * (3 - 2 * xf); zf = zf * zf * (3 - 2 * zf)
    local a, b, c, d = hash2(xi, zi, sd), hash2(xi + 1, zi, sd), hash2(xi, zi + 1, sd), hash2(xi + 1, zi + 1, sd)
    return a + (b - a) * xf + (c - a) * zf + (a - b - c + d) * xf * zf
  end

  local function genWorld(seed)
    for i = 1, NX * NY * NZ do WLD[i] = 0 end
    local top = {}
    for z = 0, NZ - 1 do
      for x = 0, NX - 1 do
        local h = floor(5 + vnoise(x / 9 + seed, z / 9, 1) * 6 + vnoise(x / 4, z / 4 + seed, 2) * 2.5)
        top[z * NX + x + 1] = h
        for y = 0, max(h, SEA) do
          local id
          if y == 0 then id = 16
          elseif y == h then id = (h <= SEA + 1) and 5 or 1
          elseif y >= h - 3 then id = (h <= SEA + 1) and 5 or 2
          else
            id = 3
            local r = hash3(x * 1.7 + y * 13.1, z * 2.3 + y * 7.7, 11 + seed)
            if r < 0.035 then id = 10
            elseif r < 0.06 and y <= 9 then id = 11
            elseif r < 0.082 and y <= 8 then id = 12
            elseif r < 0.105 and y <= 7 then id = 13
            elseif r < 0.115 and y <= 4 then id = 14 end
            if y >= 2 and y <= h - 3 and vnoise(x / 5 + y * 0.7, z / 5 - y * 0.5, 7 + seed) > 0.78 then id = 0 end
          end
          if y > h then id = 9 end
          WLD[I(x, y, z)] = id
        end
      end
    end
    -- trees
    for z = 3, NZ - 4 do
      for x = 3, NX - 4 do
        local h = top[z * NX + x + 1]
        if h > SEA + 1 and hash2(x, z, 5 + seed) > 0.968 then
          local th = 4 + floor(hash2(x, z, 6) * 2)
          for y = h + 1, h + th do WLD[I(x, y, z)] = 6 end
          for dy = th - 1, th + 1 do
            for dx = -2, 2 do
              for dz = -2, 2 do
                local y = h + dy + 1
                if abs(dx) + abs(dz) + max(0, dy - th + 1) <= 3 and y < NY and WLD[I(x + dx, y, z + dz)] == 0 then
                  WLD[I(x + dx, y, z + dz)] = 8
                end
              end
            end
          end
        end
      end
    end
    for z = 0, NZ - 1 do for x = 0, NX - 1 do HM[z * NX + x + 1] = colTop(x, z) end end
  end

  local function setb(s, x, y, z, id)
    WLD[I(x, y, z)] = id
    HM[z * NX + x + 1] = colTop(x, z)
    s.ver = s.ver + 1
    s.dirty = true
  end

  ---------------------------------------------------------------- inventory / crafting
  local function have(s, k) return s.inv[k] or 0 end
  local function add(s, k, n)
    s.inv[k] = (s.inv[k] or 0) + n
    s.got[k] = true
  end
  local function take(s, k, n)
    s.inv[k] = (s.inv[k] or 0) - n
    if s.inv[k] <= 0 then s.inv[k] = nil end
  end
  local function craftable(s, r)
    for _, p in ipairs(r.i) do if have(s, p[1]) < p[2] then return false end end
    return true
  end
  local function say(s, t) s.msg = t; s.msgT = os.clock() + 3 end
  local function tier(s)
    if have(s, "pick3") > 0 then return 3 elseif have(s, "pick2") > 0 then return 2 elseif have(s, "pick1") > 0 then return 1 end
    return 0
  end
  local SPEED = { 1, 2, 3.5, 6 }

  local function startJob(s, m, r, count)
    count = count or 1
    if r.b then
      local n = 0
      while n < count and craftable(s, r) do
        for _, p in ipairs(r.i) do take(s, p[1], p[2]) end
        m.burn = (m.burn or 0) + r.b; n = n + 1
      end
      if n == 0 then OS.sfx("error") return end
      OS.sfx("machine"); s.ver = s.ver + 1; s.dirty = true
      return
    end
    if m.job then say(s, "Machine is busy"); OS.sfx("error") return end
    if not craftable(s, r) then say(s, "Missing ingredients"); OS.sfx("error") return end
    for _, p in ipairs(r.i) do take(s, p[1], p[2]) end
    m.job = { r = r, left = r.t }; m.rep = count - 1
    OS.sfx("select"); s.ver = s.ver + 1
  end

  local function finishJob(s, m)
    local r = m.job.r
    add(s, r.o, r.n)
    OS.sfx("machine")
    say(s, "Done: " .. nm(r.o) .. " x" .. r.n)
    m.job = nil
    if (m.rep or 0) > 0 and craftable(s, r) then
      m.rep = m.rep - 1
      for _, p in ipairs(r.i) do take(s, p[1], p[2]) end
      m.job = { r = r, left = r.t }
    else m.rep = 0 end
    s.ver = s.ver + 1
  end

  ---------------------------------------------------------------- player
  local OFX, OFY = { -0.3, 0.3 }, { 0.05, 0.9, 1.65 }
  local function collides(px, py, pz)
    for a = 1, 2 do
      for b = 1, 2 do
        for c = 1, 3 do
          if solid(floor(px + OFX[a]), floor(py + OFY[c]), floor(pz + OFX[b])) then return true end
        end
      end
    end
    return false
  end

  local function move(s, fwd, side)
    if s.ui then return end
    local sp = 0.45
    local dx = (sin(s.yaw) * fwd + cos(s.yaw) * side) * sp
    local dz = (cos(s.yaw) * fwd - sin(s.yaw) * side) * sp
    local nx = s.px + dx
    if not collides(nx, s.py, s.pz) then s.px = nx
    elseif s.ground and not collides(nx, s.py + 1.01, s.pz) then s.px = nx; s.py = s.py + 1.01; s.vy = 0; s.ground = false end
    local nz = s.pz + dz
    if not collides(s.px, s.py, nz) then s.pz = nz
    elseif s.ground and not collides(s.px, s.py + 1.01, nz) then s.pz = nz; s.py = s.py + 1.01; s.vy = 0; s.ground = false end
    s.steps = s.steps + 1
    if s.steps % 3 == 0 then OS.sfx("step") end
  end

  local function physicsStep(s, dt)
    local wat = get(floor(s.px), floor(s.py + 0.5), floor(s.pz)) == 9
    if wat ~= s.wat then s.wat = wat; if wat then OS.sfx("splash") end end
    if wat then s.vy = max(s.vy - 6 * dt, -2.5) else s.vy = max(s.vy - 28 * dt, -8) end
    local ny = s.py + s.vy * dt
    if s.vy <= 0 then
      if collides(s.px, ny, s.pz) then s.py = floor(ny + 0.05) + 1; s.vy = 0; s.ground = true
      else s.py = ny; s.ground = false end
    else
      if collides(s.px, ny, s.pz) then s.vy = 0 else s.py = ny end
      s.ground = false
    end
  end
  -- small steps so a long frame can never carry the player through a floor (max ~0.3 block per step)
  local function physics(s, dt)
    -- stuck inside blocks (for example after a long pause): climb out instead of falling through
    if collides(s.px, s.py, s.pz) then
      for _ = 1, 24 do
        if not collides(s.px, s.py, s.pz) then break end
        s.py = s.py + 0.5
      end
      s.vy = 0
    end
    local n = max(1, math.ceil(dt / 0.03))
    n = min(n, 40)
    for _ = 1, n do physicsStep(s, dt / n) end
  end

  local function jump(s)
    if s.ui then return end
    if s.wat then s.vy = 4.5; OS.sfx("tick")
    elseif s.ground then s.vy = 9; s.ground = false; OS.sfx("jump") end
  end

  local function look(s)
    local cp = cos(s.pitch)
    return cp * sin(s.yaw), sin(s.pitch), cp * cos(s.yaw)
  end

  local function target(s)
    local ox, oy, oz = s.px, s.py + 1.6, s.pz
    local fx, fy, fz = look(s)
    local lx, ly, lz = floor(ox), floor(oy), floor(oz)
    for i = 1, 110 do
      local t = i * 0.05
      local x, y, z = floor(ox + fx * t), floor(oy + fy * t), floor(oz + fz * t)
      if x ~= lx or y ~= ly or z ~= lz then
        local id = get(x, y, z)
        if id < 0 then return nil end
        if id > 0 and id ~= 9 then return x, y, z, lx, ly, lz, id end
        lx, ly, lz = x, y, z
      end
    end
  end

  local function breakAt(s, x, y, z, id)
    local d = B[id]
    s.mach[I(x, y, z)] = nil
    setb(s, x, y, z, 0)
    if d.drop then add(s, d.drop, 1) end
    OS.sfx("pick")
  end

  local function mine(s)
    if s.ui then return end
    local x, y, z, _, _, _, id = target(s)
    if not x then return end
    local d = B[id]
    if d.hard >= 99 then say(s, "Unbreakable"); OS.sfx("error") return end
    local tr = tier(s)
    if d.tier and tr < d.tier then say(s, "You need a better pickaxe"); OS.sfx("error") return end
    local key = I(x, y, z)
    if not s.mine or s.mine.k ~= key then s.mine = { k = key, n = 0 } end
    s.mine.n = s.mine.n + 1
    s.mine.need = ceil(d.hard / SPEED[tr + 1])
    OS.sfx("dig")
    if s.mine.n >= s.mine.need then s.mine = nil; breakAt(s, x, y, z, id) end
  end

  local function placeable(s)
    local list = {}
    for _, k in ipairs(PLACEABLE) do if have(s, k) > 0 then list[#list + 1] = k end end
    return list
  end
  local function cycle(s, dir)
    local list = placeable(s)
    if #list == 0 then s.sel = nil return end
    local idx = 0
    for i, k in ipairs(list) do if k == s.sel then idx = i end end
    idx = ((idx - 1 + dir) % #list) + 1
    s.sel = list[idx]
    OS.sfx("tick")
  end

  local function place(s)
    if s.ui then return end
    if not s.sel or have(s, s.sel) <= 0 then cycle(s, 1) end
    if not s.sel then say(s, "Nothing to place"); OS.sfx("error") return end
    local x, y, z, lx, ly, lz = target(s)
    if not x then return end
    local bid = ITEMBLOCK[s.sel]
    if not bid or ly < 1 or ly >= NY then return end
    local cur = get(lx, ly, lz)
    if cur ~= 0 and cur ~= 9 then return end
    if lx + 1 > s.px - 0.3 and lx < s.px + 0.3 and lz + 1 > s.pz - 0.3 and lz < s.pz + 0.3 and ly + 1 > s.py and ly < s.py + 1.8 then
      say(s, "You are in the way"); OS.sfx("error") return
    end
    take(s, s.sel, 1)
    setb(s, lx, ly, lz, bid)
    local kd = KIND[bid]
    if kd then s.mach[I(lx, ly, lz)] = { kind = kd, x = lx, y = ly, z = lz, burn = 0, rep = 0 } end
    OS.sfx("place")
    if have(s, s.sel) <= 0 then cycle(s, 1) end
  end

  local function useBlock(s)
    if s.ui then s.ui = nil; return end
    local x, y, z, _, _, _, id = target(s)
    if not x then return end
    local m = s.mach[I(x, y, z)]
    if m then s.ui = m.kind; s.mpos = m; s.rsel = 1; OS.sfx("open")
    else say(s, B[id].name) end
  end

  local function openHand(s)
    if s.ui then s.ui = nil; OS.sfx("back") return end
    s.ui = "hand"; s.rsel = 1; s.tab = "craft"; OS.sfx("open")
  end

  local function craftSel(s, bulk)
    local list = RBY[s.ui]
    local r = list and list[s.rsel]
    if not r then return end
    if s.ui == "hand" then
      if not craftable(s, r) then say(s, "Missing ingredients"); OS.sfx("error") return end
      for _, p in ipairs(r.i) do take(s, p[1], p[2]) end
      add(s, r.o, r.n)
      OS.sfx("craft")
      say(s, "Crafted " .. nm(r.o) .. " x" .. r.n)
      if not s.sel and ITEMBLOCK[r.o] then s.sel = r.o end
    else
      startJob(s, s.mpos, r, bulk and 8 or 1)
    end
  end

  ---------------------------------------------------------------- state
  local function save(s)
    pcall(function()
      local parts = {}
      for i = 1, #WLD do parts[i] = CH[WLD[i]] or CH[0] end
      local mach = {}
      for k, m in pairs(s.mach) do
        mach[tostring(k)] = { kind = m.kind, x = m.x, y = m.y, z = m.z, burn = m.burn, rep = m.rep,
          job = m.job and { ri = m.job.r.ri, left = m.job.left } or nil }
      end
      local data = { v = 1, w = table.concat(parts), px = s.px, py = s.py, pz = s.pz, yaw = s.yaw, pitch = s.pitch,
        inv = s.inv, got = s.got, mach = mach, tm = s.tm, day = s.day, shader = s.shader, sel = s.sel, spawn = s.spawn }
      local f = fs.open(FILE, "w")
      f.write(textutils.serialize(data)); f.close()
      s.dirty = false
    end)
  end

  local function load(s)
    local ok, res = pcall(function()
      if not fs.exists(FILE) then return false end
      local f = fs.open(FILE, "r")
      local d = textutils.unserialize(f.readAll()); f.close()
      if type(d) ~= "table" or d.v ~= 1 or type(d.w) ~= "string" or #d.w ~= NX * NY * NZ then return false end
      for i = 1, #d.w do WLD[i] = d.w:byte(i) - 48 end
      s.px, s.py, s.pz, s.yaw, s.pitch = d.px, d.py, d.pz, d.yaw, d.pitch
      s.inv, s.got, s.tm, s.day, s.shader, s.sel = d.inv or {}, d.got or {}, d.tm or 0.3, d.day or 1, d.shader or 3, d.sel
      s.spawn = d.spawn
      for k, m in pairs(d.mach or {}) do
        local job = nil
        if m.job and R[m.job.ri] then job = { r = R[m.job.ri], left = m.job.left } end
        s.mach[tonumber(k)] = { kind = m.kind, x = m.x, y = m.y, z = m.z, burn = m.burn or 0, rep = m.rep or 0, job = job }
      end
      for z = 0, NZ - 1 do for x = 0, NX - 1 do HM[z * NX + x + 1] = colTop(x, z) end end
      return true
    end)
    return ok and res
  end

  local function computePower(s)
    local pw = {}
    for key, m in pairs(s.mach) do
      if m.kind == "gen" and (m.burn or 0) > 0 then
        local q, qi, seen, cap = { m }, 1, { [key] = true }, 3
        while qi <= #q do
          local c = q[qi]; qi = qi + 1
          local nb = { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } }
          for _, o in ipairs(nb) do
            local x, y, z = c.x + o[1], c.y + o[2], c.z + o[3]
            local k = I(x, y, z)
            if not seen[k] and get(x, y, z) > 0 then
              local id = get(x, y, z)
              if id == 17 then seen[k] = true; q[#q + 1] = { x = x, y = y, z = z }
              elseif s.mach[k] and s.mach[k].kind ~= "gen" then
                seen[k] = true
                if cap > 0 and not pw[k] then pw[k] = true; cap = cap - 1 end
              end
            end
          end
        end
      end
    end
    s.powered = pw
  end

  local function goalIndex(s)
    for i, g in ipairs(GOALS) do if not s.got[g[2]] then return i end end
    return #GOALS + 1
  end

  local function sim(win)
    local s = win.state
    if not s.alive then return end
    local now = os.clock()
    local dt = min(0.5, now - s.last); s.last = now
    local act = OS.active() == win
    if act then
      physics(s, dt)
      if s.py < -3 and s.spawn then
        s.px, s.py, s.pz, s.vy = s.spawn.px, s.spawn.py, s.spawn.pz, 0
        s.ver = s.ver + 1; say(s, "You fell out of the world. Respawned.")
      end
      s.tm = s.tm + dt / DAYLEN
      if s.tm >= 1 then s.tm = s.tm - 1; s.day = s.day + 1 end
    end
    computePower(s)
    local busy = false
    for key, m in pairs(s.mach) do
      if (m.burn or 0) > 0 then m.burn = max(0, m.burn - dt); busy = true; if m.burn == 0 then s.ver = s.ver + 1 end end
      if m.job then
        busy = true
        if not NEEDP[m.kind] or s.powered[key] then
          m.job.left = m.job.left - dt
          if m.job.left <= 0 then finishJob(s, m) end
        end
      end
    end
    local gi = goalIndex(s)
    if gi ~= s.goal then
      if s.goal and gi > s.goal then OS.sfx(gi > #GOALS and "win" or "power"); say(s, gi > #GOALS and "Circuit Age reached!" or "Goal complete!") end
      s.goal = gi
    end
    local want = busy and "machine" or "block"
    if want ~= s.trk then s.trk = want; OS.music(want, win) end
    if s.msg and now > s.msgT then s.msg = nil end
    if s.dirty and now - s.saveT > 20 then s.saveT = now; save(s) end
    OS.timer(0.1, function() sim(win) end)
  end

  function app.init(win)
    local s = { alive = true, px = 0, py = 0, pz = 0, vy = 0, yaw = 0.6, pitch = -0.25, inv = {}, got = {}, mach = {}, ver = 0,
      tm = 0.3, day = 1, shader = 3, steps = 0, last = os.clock(), saveT = os.clock(), powered = {}, rsel = 1 }
    win.state = s
    if not load(s) then
      genWorld(floor(os.clock() * 7) % 50)
      s.px, s.pz, s.py = NX / 2 + 0.5, NZ / 2 + 0.5, 12
      local found = false
      for rad = 0, 14 do
        for dx = -rad, rad do
          for dz = -rad, rad do
            if not found and max(abs(dx), abs(dz)) == rad then
              local x, z = NX / 2 + dx, NZ / 2 + dz
              for y = NY - 2, 1, -1 do
                local id = WLD[I(x, y, z)]
                if id ~= 0 and id ~= 6 and id ~= 8 and id ~= 9 then
                  if (id == 1 or id == 5) and WLD[I(x, y + 1, z)] == 0 then
                    found = true; s.px, s.pz, s.py = x + 0.5, z + 0.5, y + 1
                  end
                  break
                end
              end
            end
          end
        end
      end
      say(s, "Welcome! Find a tree and punch it (F).")
    end
    if not s.spawn then s.spawn = { px = s.px, py = s.py, pz = s.pz } end
    -- a bad saved position (NaN / outside the world) goes back to spawn
    if not (s.px == s.px and s.py == s.py and s.pz == s.pz) or s.py < 0 or s.py > NY + 2 or s.px < 0 or s.px > NX or s.pz < 0 or s.pz > NZ then
      s.px, s.py, s.pz, s.vy = s.spawn.px, s.spawn.py, s.spawn.pz, 0
    end
    s.goal = goalIndex(s)
    OS.timer(0.2, function() sim(win) end)
  end

  function app.close(win)
    local s = win.state
    s.alive = false
    save(s)
    OS.musicStop(win)
  end

  ---------------------------------------------------------------- commands (press / or Enter)
  local function itemKeys()
    local set = {}
    for _, b in pairs(B) do
      if b.drop then set[b.drop] = true end
      if b.put then set[b.put] = true end
    end
    for _, r in ipairs(R) do if r.o then set[r.o] = true end end
    for k in pairs(NAME) do set[k] = true end
    return set
  end
  local function findItem(arg)
    local want = arg:lower():gsub("%s+", "_")
    local set = itemKeys()
    if set[want] then return want end
    local hit, n = nil, 0
    for k in pairs(set) do
      if k:find(want, 1, true) or nm(k):lower():gsub("%s+", "_"):find(want, 1, true) then hit = k; n = n + 1 end
    end
    if n == 1 then return hit end
    return nil, n
  end
  local function respawn(s, why)
    local sp = s.spawn or { px = NX / 2 + 0.5, py = 12, pz = NZ / 2 + 0.5 }
    s.px, s.py, s.pz, s.vy = sp.px, sp.py, sp.pz, 0
    s.ver = s.ver + 1
    say(s, why or "Respawned at your spawn point")
    s.msgT = os.clock() + 4
  end
  local function runCmd(win, text)
    local s = win.state
    text = (text or ""):gsub("^%s*/?%s*", "")
    local a = {}
    for w in text:gmatch("%S+") do a[#a + 1] = w end
    local c = (a[1] or ""):lower()
    local function ok(t) say(s, t); s.msgT = os.clock() + 5 end
    if c == "" then return
    elseif c == "help" or c == "?" then
      ok("/respawn /kill /spawnpoint /tp x y z /time set day|night /give item n /clear /where /shader n /goal")
    elseif c == "respawn" or c == "spawn" then respawn(s)
    elseif c == "kill" or c == "suicide" then respawn(s, "You died. Respawned at your spawn point")
    elseif c == "spawnpoint" or c == "setspawn" or c == "sethome" then
      s.spawn = { px = s.px, py = s.py, pz = s.pz }; s.dirty = true
      ok(string.format("Spawn point set to %d %d %d", floor(s.px), floor(s.py), floor(s.pz)))
    elseif c == "where" or c == "pos" or c == "coords" then
      ok(string.format("You are at X%.1f Y%.1f Z%.1f", s.px, s.py, s.pz))
    elseif c == "tp" or c == "teleport" then
      if a[2] == "spawn" or #a == 1 then respawn(s, "Teleported to spawn") return end
      local x, y, z = tonumber(a[2]), tonumber(a[3]), tonumber(a[4])
      if not (x and y and z) then ok("Use: /tp x y z   (or /tp spawn)") return end
      x, z = max(1, min(NX - 1, x)), max(1, min(NZ - 1, z))
      y = max(1, min(NY - 2, y))
      s.px, s.py, s.pz, s.vy = x + 0.5, y, z + 0.5, 0
      s.ver = s.ver + 1; ok(string.format("Teleported to %d %d %d", x, y, z))
    elseif c == "time" or c == "day" or c == "night" then
      local v = a[3]
      if c == "day" then v = "day" elseif c == "night" then v = "night" end
      if c == "time" and a[2] ~= "set" then v = a[2] end
      local map = { day = 0.3, morning = 0.27, noon = 0.5, evening = 0.7, night = 0.75, midnight = 0.0 }
      local t = map[(v or ""):lower()]
      if not t and tonumber(v) then t = (tonumber(v) % 24) / 24 end
      if not t then ok("Use: /time set day|noon|night|midnight|0-24") return end
      s.tm = t; s.ver = s.ver + 1; s.dirty = true; ok(string.format("Time set to %02d:00", floor(t * 24)))
    elseif c == "give" then
      if not a[2] then ok("Use: /give <item> [amount]") return end
      local n = tonumber(a[#a]) and #a > 2 and tonumber(a[#a]) or 1
      local nameArg = table.concat(a, " ", 2, (tonumber(a[#a]) and #a > 2) and #a - 1 or #a)
      local k, many = findItem(nameArg)
      if not k then ok(many and many > 1 and ("More than one item matches '" .. nameArg .. "'") or ("Unknown item '" .. nameArg .. "'")) return end
      n = max(1, min(999, floor(n)))
      add(s, k, n); if not s.sel then s.sel = k end
      s.dirty = true; ok("Gave " .. n .. " " .. nm(k))
    elseif c == "clear" then
      s.inv = {}; s.sel = nil; s.dirty = true; ok("Inventory cleared")
    elseif c == "shader" then
      local n = tonumber(a[2])
      if not n or n < 1 or n > 3 then ok("Use: /shader 1-3  (Off, Shaded, Ultra)") return end
      s.shader = floor(n); s.ver = s.ver + 1; ok("Shader: " .. SHN[s.shader])
    elseif c == "goal" then
      local gi = s.goal or goalIndex(s)
      ok(GOALS[gi] and ("Goal: " .. GOALS[gi][1]) or "You reached the Circuit Age!")
    elseif c == "save" then save(s); ok("World saved")
    else ok("Unknown command '" .. c .. "'. Try /help") end
  end
  local function closeCmd(win)
    local s = win.state
    s.cmd = nil
    win.focus = nil; win.keepFocus = nil
  end
  local function openCmd(win)
    local s = win.state
    s.cmd = OS.field("", { max = 60, placeholder = "command, e.g. respawn" })
    s.cmd.onEnter = function(f) local t = f.text; closeCmd(win); runCmd(win, t) end
    s.cmd.onKey = function(f, k)
      if k == keys.escape or (k == keys.backspace and f.text == "") then closeCmd(win); return true end
    end
    win.focus = s.cmd; win.keepFocus = s.cmd
  end

  ---------------------------------------------------------------- input
  local function turn(s, d) s.yaw = s.yaw + d end
  local function tilt(s, d) s.pitch = max(-1.35, min(1.35, s.pitch + d)) end

  function app.key(win, k)
    local s = win.state
    if s.ui then
      local list = RBY[s.ui] or {}
      if k == keys.up then s.rsel = max(1, s.rsel - 1); OS.sfx("tick")
      elseif k == keys.down then s.rsel = min(#list, s.rsel + 1); OS.sfx("tick")
      elseif k == keys.enter or k == keys.space then craftSel(s, false)
      elseif k == keys.tab then s.tab = (s.tab == "craft") and "items" or "craft"
      elseif k == keys.backspace then s.ui = nil; OS.sfx("back") end
      return
    end
    if k == keys.enter and not s.cmd then openCmd(win) return end
    if k == keys.left then turn(s, -0.18) elseif k == keys.right then turn(s, 0.18)
    elseif k == keys.up then tilt(s, 0.14) elseif k == keys.down then tilt(s, -0.14)
    elseif k == keys.space then jump(s) end
  end

  function app.char(win, c)
    local s = win.state
    if c == "/" and not s.cmd then openCmd(win) return end
    c = c:lower()
    if s.ui then
      if c == "e" or c == "r" then s.ui = nil; OS.sfx("back")
      elseif c == "b" and s.ui ~= "hand" then craftSel(s, true)
      elseif c == "w" then s.rsel = max(1, s.rsel - 1) elseif c == "s" then s.rsel = min(#(RBY[s.ui] or {}), s.rsel + 1)
      elseif c == "i" then s.tab = (s.tab == "craft") and "items" or "craft" end
      return
    end
    if c == "w" then move(s, 1, 0) elseif c == "s" then move(s, -1, 0)
    elseif c == "a" then move(s, 0, -1) elseif c == "d" then move(s, 0, 1)
    elseif c == "q" then turn(s, -0.18) elseif c == "c" then turn(s, 0.18)
    elseif c == "f" then mine(s) elseif c == "g" then place(s)
    elseif c == "r" then useBlock(s) elseif c == "e" or c == "i" then openHand(s)
    elseif c == "z" then cycle(s, -1) elseif c == "x" then cycle(s, 1)
    elseif c == "t" then s.shader = s.shader % 3 + 1; s.ver = s.ver + 1; OS.sfx("select")
    elseif c == "v" then s.tm = (s.tm < 0.5) and 0.75 or 0.3; s.ver = s.ver + 1; OS.sfx("select")
    elseif c == " " then jump(s) end
  end

  ---------------------------------------------------------------- rendering
  local function dither(cov, fgc, bgc, cx, cy)
    local lvl = floor(cov * 6)
    if lvl <= 0 then return " ", fgc, bgc end
    if lvl >= 5 then return " ", fgc, fgc end
    return (((cx + cy) % 2 == 0) and LV1 or LV2)[lvl + 1], fgc, bgc
  end

  local function cast(ox, oy, oz, dx, dy, dz, maxd)
    local x, y, z = floor(ox), floor(oy), floor(oz)
    local sx, sy, sz = dx > 0 and 1 or -1, dy > 0 and 1 or -1, dz > 0 and 1 or -1
    local ax, ay, az = abs(dx), abs(dy), abs(dz)
    local ddx, ddy, ddz = ax > 1e-9 and 1 / ax or 1e30, ay > 1e-9 and 1 / ay or 1e30, az > 1e-9 and 1 / az or 1e30
    local tx = ax > 1e-9 and ((dx > 0 and (x + 1 - ox) or (ox - x)) * ddx) or 1e30
    local ty = ay > 1e-9 and ((dy > 0 and (y + 1 - oy) or (oy - y)) * ddy) or 1e30
    local tz = az > 1e-9 and ((dz > 0 and (z + 1 - oz) or (oz - z)) * ddz) or 1e30
    local t, face = 0, 0
    local tr, trt, tre, trx, try, trz
    for _ = 1, 90 do
      local id
      if x < 0 or x >= NX or z < 0 or z >= NZ then break
      elseif y < 0 then id = 16
      elseif y >= NY then id = 0; if dy >= 0 then break end
      else id = WLD[(y * NZ + z) * NX + x + 1] end
      if id ~= 0 then
        local d = B[id]
        if d.tr then
          if not tr then tr = id; trt = t; trx, try, trz = x, y, z end
        else return id, face, t, x, y, z, tr, trt, tre or t end
      elseif tr and not tre then tre = t end
      if tx < ty then
        if tx < tz then x = x + sx; t = tx; tx = tx + ddx; face = 1
        else z = z + sz; t = tz; tz = tz + ddz; face = 3 end
      else
        if ty < tz then y = y + sy; t = ty; ty = ty + ddy; face = 2
        else z = z + sz; t = tz; tz = tz + ddz; face = 3 end
      end
      if t > maxd then break end
    end
    if tr == 9 then return 9, 2, trt, trx, try, trz end
    return 0, 0, t, x, y, z, tr, trt, tre or t
  end

  local function renderWorld(s, w, vh)
    local sh = s.shader
    local yaw, pit = s.yaw, s.pitch
    local sy_, cy_, sp_, cp_ = sin(yaw), cos(yaw), sin(pit), cos(pit)
    local fx, fy, fz = cp_ * sy_, sp_, cp_ * cy_
    local rx, rz = cy_, -sy_
    local ux, uy, uz = -sp_ * sy_, cp_, -sp_ * cy_
    local tanx = 0.75
    local tany = tanx * (vh * 9) / (w * 6)
    local ox, oy, oz = s.px, s.py + 1.6, s.pz
    local ang = (s.tm - 0.25) * 2 * math.pi
    local e = sin(ang)
    local d = max(0.12, min(1, 0.5 + e * 1.6))
    local sdx, sdy, sdz = cos(ang) * 0.9, e, 0.35
    local sl = sqrt(sdx * sdx + sdy * sdy + sdz * sdz)
    sdx, sdy, sdz = sdx / sl, sdy / sl, sdz / sl
    local maxd = (sh == 3) and 26 or 20
    local fogC = (d >= 0.5) and SKY or ((d >= 0.22) and DEEP or BK)
    local amb = (sh == 1) and 1 or (0.25 + 0.75 * d)
    local tx0, ty0, tz0 = s.tgx, s.tgy, s.tgz
    local tmv = s.tm * 400
    local rt, rf, rb = {}, {}, {}
    for cy = 1, vh do
      local v = (1 - (cy - 0.5) / vh * 2) * tany
      local tt, ff, bb = {}, {}, {}
      for cx = 1, w do
        local u = ((cx - 0.5) / w * 2 - 1) * tanx
        local dx, dy, dz = fx + rx * u + ux * v, fy + uy * v, fz + rz * u + uz * v
        local inv = 1 / sqrt(dx * dx + dy * dy + dz * dz)
        dx, dy, dz = dx * inv, dy * inv, dz * inv
        local id, face, t, hx, hy, hz, tr, trt, tre = cast(ox, oy, oz, dx, dy, dz, maxd)
        local ch, fc, bc
        if id == 0 then
          -- sky
          if sh == 1 then ch, fc, bc = " ", SKY, SKY
          else
            local cov
            if d >= 0.78 then bc = SKY; fc = WH; cov = 0.5 * (1 - max(0, min(1, dy * 2.2)))
            elseif d >= 0.22 then bc = DEEP; fc = SKY; cov = (d - 0.22) / 0.56
            else bc = BK; fc = DEEP; cov = (d - 0.1) / 0.12 end
            local sd = dx * sdx + dy * sdy + dz * sdz
            if e > 0 and sd > 0.994 then bc = SAND; fc = SAND; cov = 1
            elseif e < 0.1 and -sd > 0.996 then bc = WH; fc = WH; cov = 1
            elseif d < 0.5 and dy > 0.02 and hash3(floor(dx * 42), floor(dy * 42), floor(dz * 42)) > 0.985 then
              bc = BK; fc = WH; cov = 0.5
            else
              if e > -0.12 and e < 0.3 and dy < 0.4 then
                local hd = (dx * sdx + dz * sdz) / max(0.01, sqrt(sdx * sdx + sdz * sdz))
                if hd > 0.5 then fc = (e > 0.08) and SAND or RED; cov = (hd - 0.5) * 1.6 * (1 - dy * 2.4); if cov < 0 then cov = 0 end end
              end
              if sh == 3 and dy > 0.06 and d > 0.3 then
                local k = 30 / dy
                if hash2(floor((ox + dx * k + tmv * 0.05) / 5), floor((oz + dz * k) / 5), 9) > 0.64 then fc = WH; cov = 0.55 * d + 0.2 end
              end
            end
            ch, fc, bc = dither(cov, fc, bc, cx, cy)
          end
        else
          local bd = B[id]
          local px_, py_, pz_ = ox + dx * t, oy + dy * t, oz + dz * t
          local fxx, fyy, fzz = px_ - hx, py_ - hy, pz_ - hz
          local top = (face == 2 and dy < 0)
          local uu, vv
          if face == 1 then uu, vv = fzz, fyy elseif face == 2 then uu, vv = fxx, fzz else uu, vv = fxx, fyy end
          uu = max(0, min(0.999, uu)); vv = max(0, min(0.999, vv))
          local r = hash3(hx + face * 0.31, hy, hz + floor(uu * 3.99) * 0.17 + floor(vv * 3.99) * 0.37)
          local col = bd.tex(s, hx, hy, hz, face, top, uu, vv, r)
          local f
          if sh == 1 then f = 1
          else
            local fb = (face == 1) and 0.78 or ((face == 3) and 0.6 or (top and 1 or 0.45))
            if sh == 3 then
              local nd
              if face == 1 then nd = (dx > 0 and -sdx or sdx) elseif face == 2 then nd = (dy > 0 and -sdy or sdy) else nd = (dz > 0 and -sdz or sdz) end
              if nd > 0 then fb = fb + 0.18 * nd * d end
            end
            local a = amb
            local cf = 1
            if sh == 3 then
              local hmy = HM[hz * NX + hx + 1] or 0
              if hy < hmy then cf = 1 - min(5, hmy - hy) / 5 * 0.7 end
              a = 0.22 + 0.78 * d * cf
            end
            f = fb * a
            local glow = (1 - d * cf) * 0.4 * max(0, 1 - t / 8)
            f = f + glow
            if bd.emit then f = 1 end
            if hx == tx0 and hy == ty0 and hz == tz0 then f = f + 0.3 end
            if f > 1 then f = 1 end
          end
          local vis = 1
          local bg = BK
          if sh == 3 then
            local fa = max(0, (t - 8) / (maxd - 8))
            if fa > 1 then fa = 1 end
            fa = fa ^ 1.4
            vis = 1 - fa
            if fa > 0.3 then bg = fogC end
          elseif sh == 2 then
            vis = 1 - 0.3 * (t / maxd)
          end
          local cov = f * vis
          if tr then
            local a = 0.3
            if tr == 9 then a = max(0.3, min(0.85, 0.3 + 0.13 * ((tre or t) - (trt or 0)))) else a = 0.12 end
            if tr == 9 then
              bg = DEEP
              cov = cov * (1 - a)
              if sh == 3 and t - (trt or 0) < 0.6 and hash3(cx, cy, floor(tmv)) > 0.93 then col = WH; cov = 0.6 end
            else
              cov = cov * 0.78
              if bg == BK then bg = DARK end
            end
          end
          if sh == 1 then ch, fc, bc = " ", col, col
          else ch, fc, bc = dither(cov, col, bg, cx, cy) end
        end
        tt[cx] = ch; ff[cx] = fc; bb[cx] = bc
      end
      rt[cy] = table.concat(tt); rf[cy] = table.concat(ff); rb[cy] = table.concat(bb)
    end
    return { t = rt, f = rf, b = rb }
  end

  local function panel(win, g, s, w, vh)
    local pw, ph = min(w - 2, 48), max(8, min(vh, 15))
    local x0, y0 = floor((w - pw) / 2) + 1, 2 + floor((vh - ph) / 2)
    g.fill(x0, y0, pw, ph, C.win)
    local function pad(t, n) t = tostring(t):sub(1, n); return t .. (" "):rep(n - #t) end
    g.put(x0, y0, pad(" " .. (KTITLE[s.ui] or s.ui), pw), C.wht, C.acc)
    g.hot(x0, y0, pw, ph, function() end)
    local list = RBY[s.ui] or {}
    local rows = ph - 5
    if s.ui == "hand" and s.tab == "items" then
      local names = {}
      for k, n in pairs(s.inv) do names[#names + 1] = k end
      table.sort(names)
      g.put(x0 + 1, y0 + 1, "Inventory (" .. #names .. " kinds)  [Tab] craft", C.sub, C.win)
      local per = ph - 3
      for i, k in ipairs(names) do
        local c2, r2 = floor((i - 1) / per), (i - 1) % per
        if c2 < 2 then g.put(x0 + 1 + c2 * floor(pw / 2), y0 + 2 + r2, OS.trunc(nm(k) .. " " .. s.inv[k], floor(pw / 2) - 1), C.text, C.win) end
      end
      if #names == 0 then g.put(x0 + 1, y0 + 2, "Empty - go punch a tree!", C.sub, C.win) end
    else
      local top = max(1, min(s.rsel - floor(rows / 2), #list - rows + 1))
      for i = 0, rows - 1 do
        local r = list[top + i]
        if r then
          local ok = craftable(s, r)
          local label = r.l or (nm(r.o) .. " x" .. r.n)
          local idx = top + i
          local sel = idx == s.rsel
          local line = (sel and "> " or "  ") .. label
          g.put(x0 + 1, y0 + 1 + i, pad(OS.trunc(line, pw - 2), pw - 2), ok and C.grn or C.sub, C.win)
          g.hot(x0 + 1, y0 + 1 + i, pw - 2, 1, function() if s.rsel == idx then craftSel(s, false) else s.rsel = idx end end)
        end
      end
      local r = list[s.rsel]
      if r then
        local parts = {}
        for _, p in ipairs(r.i) do parts[#parts + 1] = nm(p[1]) .. " " .. have(s, p[1]) .. "/" .. p[2] end
        local lines = OS.wrap("Needs: " .. table.concat(parts, ", ") .. (r.t > 0 and ("  (" .. r.t .. "s)") or ""), pw - 2)
        for i = 1, 2 do if lines[i] then g.put(x0 + 1, y0 + ph - 4 + i - 1, lines[i], C.text, C.win) end end
      end
      local m = s.mpos
      if s.ui ~= "hand" and m then
        local st
        if s.ui == "gen" then st = (m.burn or 0) > 0 and ("Burning " .. floor(m.burn) .. "s") or "Idle - add fuel"
        elseif m.job then
          local pwr = (not NEEDP[m.kind]) or s.powered[I(m.x, m.y, m.z)]
          st = "Working " .. floor((1 - m.job.left / max(0.1, m.job.r.t)) * 100) .. "%" .. (pwr and "" or "  NO POWER") .. ((m.rep or 0) > 0 and (" +" .. m.rep) or "")
        else st = NEEDP[m.kind] and (s.powered[I(m.x, m.y, m.z)] and "Powered, idle" or "No power (generator + cable)") or "Idle" end
        g.put(x0 + 1, y0 + ph - 2, OS.trunc(st, pw - 2), (st:find("NO POWER") or st:find("No power")) and C.red or C.yel, C.win)
      end
      g.put(x0 + 1, y0 + ph - 1, OS.trunc(s.ui == "hand" and "Up/Dn pick, Enter craft, Tab items, E close" or "Up/Dn pick, Enter start, B x8, R close", pw - 2), C.sub, C.win)
    end
  end

  function app.draw(win, g)
    local s = win.state
    local w, h = g.w, g.h
    local vh = max(4, h - 4)
    g.fill(1, 1, w, h, C.sp0)
    local ang = (s.tm - 0.25) * 2 * math.pi
    local hr = floor(s.tm * 24)
    local mn = floor((s.tm * 24 - hr) * 60)
    g.put(1, 1, OS.trunc(string.format(" Blockworld  X%d Y%d Z%d  Day %d %02d:%02d  %s", floor(s.px), floor(s.py), floor(s.pz), s.day, hr, mn, SHN[s.shader]), w) .. (" "):rep(w), C.wht, C.acc)

    local tx, ty, tz, _, _, _, tid = target(s)
    s.tgx, s.tgy, s.tgz = tx, ty, tz
    local key = string.format("%d|%d|%.2f|%.2f|%.2f|%.2f|%.2f|%d|%d|%d|%s|%s|%s|%d|%d", s.ver, s.shader, s.px, s.py, s.pz, s.yaw, s.pitch,
      floor(s.tm * 400), w, vh, tostring(tx), tostring(ty), tostring(tz), s.ui and 1 or 0, 0)
    if s.cache and s.cache.key == key then
      -- reuse
    else
      s.cache = renderWorld(s, w, vh)
      s.cache.key = key
    end
    local c = s.cache
    for y = 1, vh do g.blit(1, y + 1, c.t[y], c.f[y], c.b[y]) end
    local cxh, cyh = floor(w / 2) + 1, floor(vh / 2) + 2
    g.blit(cxh, cyh, "\7", WH, c.b[cyh - 1]:sub(cxh, cxh))

    -- viewport click zones
    local third = floor(w / 3)
    g.hot(1, 2, third, vh, function() turn(s, -0.25) end)
    g.hot(third + 1, 2, third, vh, function() mine(s) end)
    g.hot(third * 2 + 1, 2, w - third * 2, vh, function() turn(s, 0.25) end)

    if s.msg then g.put(2, 2, " " .. OS.trunc(s.msg, w - 4) .. " ", C.wht, C.sp2) end
    if tid and not s.ui then
      local tn = B[tid].name
      if s.mine and s.mine.need then tn = tn .. " " .. s.mine.n .. "/" .. s.mine.need end
      g.put(2, vh + 1, " " .. OS.trunc(tn, w - 4) .. " ", C.wht, C.sp2)
    end

    -- status rows
    local sel = s.sel and (nm(s.sel) .. " x" .. have(s, s.sel)) or "none"
    local gi = s.goal or goalIndex(s)
    local goal = GOALS[gi] and ("Goal: " .. GOALS[gi][1]) or "You reached the Circuit Age! Build freely."
    if s.cmd then
      g.fill(1, vh + 3, w, 1, C.bar)
      g.put(1, vh + 3, "/", C.yel, C.bar)
      g.field(2, vh + 3, w - 2, s.cmd, { bg = C.sp2 })
    end
    local row2 = " Block: " .. sel .. "  Pick T" .. tier(s)
    g.put(1, vh + 2, OS.trunc(row2, w) .. (" "):rep(w), C.text, C.bar)
    if not s.cmd then g.put(1, vh + 3, OS.trunc(" " .. goal, w) .. (" "):rep(w), C.yel, C.bar) end

    if s.ui then panel(win, g, s, w, vh) end

    -- buttons
    local by = h
    g.fill(1, by, w, 1, C.bar)
    local bx = 1
    local function b(label, fn, style)
      if bx + #label + 1 > w then return end
      bx = bx + g.btn(bx, by, label, fn, style) + 1
    end
    b("<", function() turn(s, -0.25) end)
    b(">", function() turn(s, 0.25) end)
    b("^", function() tilt(s, 0.2) end)
    b("v", function() tilt(s, -0.2) end)
    b("Fwd", function() move(s, 1, 0) end, "dark")
    b("Back", function() move(s, -1, 0) end, "dark")
    b("Jump", function() jump(s) end, "dark")
    b("Mine", function() mine(s) end, "pri")
    b("Put", function() place(s) end)
    b("Use", function() useBlock(s) end)
    b("Craft", function() openHand(s) end)
    b("Fx", function() app.char(win, "t") end)
    b("/", function() if not s.cmd then openCmd(win) end end, "dark")
  end

  return app
end

end)()
EMBED["monitor"] = (function()
return function(OS)
  local C = OS.C
  local app = { id = "monitor", title = "Task Manager", glyph = " % ", icon = "red", fg = "wht", w = 50, h = 18, single = true, minw = 36, minh = 10 }

  local function sample(win)
    local s = win.state
    if not s or not s.alive then return end
    local st = OS.sysStats()
    s.hist[#s.hist + 1] = st.mem
    while #s.hist > 40 do table.remove(s.hist, 1) end
    OS.timer(1, function() sample(win) end)
  end

  function app.init(win)
    win.state = { alive = true, hist = {} }
    sample(win)
  end
  function app.close(win) win.state.alive = false end

  local function bar(g, x, y, w, ratio)
    g.fill(x, y, w, 1, C.bar)
    g.fill(x, y, math.max(0, math.min(w, math.floor(ratio * w + 0.5))), 1, ratio > 0.85 and C.red or C.acc)
  end

  function app.draw(win, g)
    local s = win.state
    local w, h = g.w, g.h
    local st = OS.sysStats()
    g.fill(1, 1, w, h, C.win)
    local bw = w - 2
    g.put(2, 1, "Memory", C.red, C.win)
    local mv = st.hasMem and string.format("%d KB", math.floor(st.mem)) or "not available"
    g.put(w - #mv, 1, mv, C.text, C.win)
    -- 3-row history chart
    local top = 0
    for _, v in ipairs(s.hist) do top = math.max(top, v) end
    top = math.max(top, 1)
    g.fill(2, 2, bw, 3, C.bar)
    local n = #s.hist
    for i, v in ipairs(s.hist) do
      local cx = 2 + bw - n + i - 1
      local hh = math.max(1, math.ceil(v / top * 3))
      if cx >= 2 then g.fill(cx, 5 - hh, 1, hh, C.acc) end
    end
    g.put(2, 6, "Disk", C.red, C.win)
    local dv = string.format("%d%% used, %d KB free", math.floor(st.disk * 100), math.floor(st.free / 1024))
    g.put(w - #dv, 6, OS.trunc(dv, w - 8), C.text, C.win)
    bar(g, 2, 7, bw, st.disk)
    g.put(2, 9, "Speakers (" .. st.spk .. "/" .. st.spkAll .. " on)", C.red, C.win)
    local row = 10
    for i, sp in ipairs(OS.audio.speakers) do
      if i > 3 then g.put(2, row, "+" .. (#OS.audio.speakers - 3) .. " more", C.sub, C.win); row = row + 1 break end
      g.put(2, row, OS.trunc(sp.name, w - 12), C.text, C.win)
      g.toggle(w - 6, row, sp.on, function() OS.audio.setSpeaker(sp, not sp.on) end)
      row = row + 1
    end
    if #OS.audio.speakers == 0 then g.put(2, row, "No speakers attached", C.sub, C.win); row = row + 1 end
    row = row + 1
    g.put(2, row, "Running apps", C.red, C.win)
    row = row + 1
    for _, wn in ipairs({ table.unpack(OS.wins) }) do
      if row > h then break end
      g.put(2, row, OS.trunc(wn.title or wn.app.title, w - 14), wn == win and C.sub or C.text, C.win)
      g.btn(w - 8, row, "Quit", function() OS.close(wn) end)
      row = row + 1
    end
  end

  return app
end

end)()
EMBED["flappy"] = (function()
return function(OS)
  local C = OS.C
  -- Flappy Bee: tap to flap through the gaps (original bee, original pipes)
  local app = { id = "flappy", title = "Flappy Bee", glyph = " ~ ", icon = "yel", fg = "sp0", cat = "Games",
    w = 44, h = 18, single = true, minw = 28, minh = 10, startMax = true, fullH = true, noclick = true }
  local GAP, SPACING, BX = 5, 15, 8

  local function reset(s)
    s.y, s.vy, s.score, s.t, s.state, s.pipes, s.cool = s.fh / 2, 0, 0, 0, "ready", {}, 0
    s.nextX = s.fw + 4
  end

  local function flap(s)
    if s.state == "ready" then s.state = "play" end
    if s.state == "play" then s.vy = -1.05; OS.sfx("jump")
    elseif s.state == "dead" and s.cool <= 0 then reset(s) end
  end

  local function die(s)
    s.state = "dead"; s.cool = 8; OS.sfx("die")
    if s.score > (OS.cfg.flappyBest or 0) then OS.cfg.flappyBest = s.score; OS.dirty = true end
  end

  local function tick(win)
    local s = win.state
    if not s.alive then return end
    if OS.active() == win then
      if s.state == "play" then
        s.vy = math.min(1.2, s.vy + 0.28)
        s.y = s.y + s.vy
        s.t = s.t + 1
        s.nextX = s.nextX - 1
        while s.nextX < s.fw + SPACING do
          s.pipes[#s.pipes + 1] = { x = s.nextX, gy = math.random(2, math.max(2, s.fh - GAP - 1)), scored = false }
          s.nextX = s.nextX + SPACING
        end
        local keep = {}
        for _, p in ipairs(s.pipes) do
          p.x = p.x - 1
          if p.x > -4 then keep[#keep + 1] = p end
          if p.x <= BX + 1 and p.x + 2 >= BX then
            if s.y < p.gy or s.y >= p.gy + GAP then die(s) end
          end
          if not p.scored and p.x + 2 < BX then p.scored = true; s.score = s.score + 1; OS.sfx("coin") end
        end
        s.pipes = keep
        if s.y < 1 or s.y > s.fh then die(s) end
      elseif s.state == "dead" then s.cool = s.cool - 1
      elseif s.state == "ready" then s.t = s.t + 1; s.y = s.fh / 2 + math.sin(s.t / 3) end
    end
    OS.timer(0.1, function() tick(win) end)
  end

  function app.init(win)
    local s = { alive = true, fw = 40, fh = 12 }
    win.state = s
    reset(s)
    OS.music("flappy", win)
    OS.timer(0.2, function() tick(win) end)
  end
  function app.close(win) win.state.alive = false; OS.musicStop(win) end

  function app.key(win, k)
    if k == keys.space or k == keys.up then flap(win.state) end
  end
  function app.char(win, c)
    if c == "w" or c == " " then flap(win.state) elseif c == "r" then reset(win.state) end
  end

  function app.draw(win, g)
    local s = win.state
    local w, h = g.w, g.h
    s.fw, s.fh = w, math.max(6, h - 2)
    local fw, fh = s.fw, s.fh
    g.fill(1, 1, w, h, C.sp0)
    g.put(1, 1, (" Score " .. s.score .. "   Best " .. (OS.cfg.flappyBest or 0)) .. (" "):rep(w), C.wht, C.acc)
    g.fill(1, 2, fw, fh, C.desk)
    for _, p in ipairs(s.pipes) do
      g.fill(p.x, 2, 3, p.gy - 1, C.grn)
      g.fill(p.x - 1, p.gy, 5, 1, C.grn)
      local by = p.gy + GAP
      g.fill(p.x - 1, 1 + by, 5, 1, C.grn)
      g.fill(p.x, 2 + by, 3, math.max(0, fh - by - 1), C.grn)
    end
    g.fill(1, fh + 2, fw, 1, C.sp1)
    local by = math.floor(s.y + 0.5)
    local wing = (s.t % 2 == 0) and "~" or "^"
    g.put(BX, 1 + by, "@>", C.sp0, s.state == "dead" and C.red or C.yel)
    g.put(BX - 1, 1 + by, wing, C.wht, C.desk)
    local msg
    if s.state == "ready" then msg = " Tap / Space to flap "
    elseif s.state == "dead" then msg = " Game over - Space " end
    if msg then g.put(math.floor((w - #msg) / 2) + 1, math.floor(fh / 2) + 1, msg, C.wht, C.acc) end
    g.hot(1, 2, w, fh, function() flap(s) end)
    g.btn(2, h, "Flap", function() flap(s) end, "pri")
  end

  return app
end

end)()
EMBED["pong"] = (function()
return function(OS)
  local C = OS.C
  -- Paddle Duel: first to 7 beats the CPU
  local app = { id = "pong", title = "Paddle Duel", glyph = " | ", icon = "wp", fg = "wht", cat = "Games",
    w = 46, h = 17, single = true, minw = 30, minh = 10, startMax = true, fullH = true, noclick = true }
  local WIN = 7

  local function serve(s, dir)
    s.bx, s.by = s.fw / 2, s.fh / 2
    s.vx = 0.9 * dir
    s.vy = (math.random() - 0.5) * 0.6
    s.wait = 8
  end

  local function reset(s)
    s.ph = math.max(3, math.floor(s.fh / 4))
    s.py, s.ay = s.fh / 2 - s.ph / 2, s.fh / 2 - s.ph / 2
    s.ps, s.as = 0, 0
    s.state = "ready"
    serve(s, 1)
  end

  local function movePlayer(s, d) s.py = math.max(1, math.min(s.fh - s.ph + 1, s.py + d)) end

  local function start(s)
    if s.state == "ready" then s.state = "play"
    elseif s.state == "over" then reset(s); s.state = "play" end
  end

  local function tick(win)
    local s = win.state
    if not s.alive then return end
    if s.state == "play" and OS.active() == win then
      if s.wait > 0 then s.wait = s.wait - 1
      else
        s.bx = s.bx + s.vx; s.by = s.by + s.vy
        if s.by < 1 then s.by = 1; s.vy = math.abs(s.vy); OS.sfx("tick") end
        if s.by > s.fh then s.by = s.fh; s.vy = -math.abs(s.vy); OS.sfx("tick") end
        if s.vx < 0 and s.bx <= 4 and s.bx > 1 and s.by >= s.py - 0.6 and s.by <= s.py + s.ph + 0.6 then
          s.vx = math.min(1.7, math.abs(s.vx) * 1.06)
          s.vy = s.vy + (s.by - (s.py + s.ph / 2)) / s.ph * 0.7
          OS.sfx("hit")
        elseif s.vx > 0 and s.bx >= s.fw - 3 and s.bx < s.fw and s.by >= s.ay - 0.6 and s.by <= s.ay + s.ph + 0.6 then
          s.vx = -math.min(1.7, math.abs(s.vx) * 1.06)
          s.vy = s.vy + (s.by - (s.ay + s.ph / 2)) / s.ph * 0.7
          OS.sfx("hit")
        end
        s.vy = math.max(-0.7, math.min(0.7, s.vy))
        if s.bx < 1 then s.as = s.as + 1; OS.sfx("lose"); serve(s, 1)
        elseif s.bx > s.fw then s.ps = s.ps + 1; OS.sfx("coin"); serve(s, -1) end
        if s.ps >= WIN or s.as >= WIN then
          s.state = "over"; OS.sfx(s.ps >= WIN and "win" or "lose")
          if s.ps >= WIN and s.ps - s.as > (OS.cfg.pongBest or 0) then OS.cfg.pongBest = s.ps - s.as; OS.dirty = true end
        end
      end
      -- CPU paddle
      local target = s.by - s.ph / 2
      if s.vx > 0 or math.abs(s.bx - s.fw / 2) < s.fw / 4 then
        local d = target - s.ay
        s.ay = s.ay + math.max(-0.55, math.min(0.55, d))
      end
      s.ay = math.max(1, math.min(s.fh - s.ph + 1, s.ay))
    end
    OS.timer(0.06, function() tick(win) end)
  end

  function app.init(win)
    local s = { alive = true, fw = 40, fh = 12 }
    win.state = s
    reset(s)
    OS.music("pong", win)
    OS.timer(0.2, function() tick(win) end)
  end
  function app.close(win) win.state.alive = false; OS.musicStop(win) end

  function app.key(win, k)
    local s = win.state
    if k == keys.up then movePlayer(s, -2) elseif k == keys.down then movePlayer(s, 2)
    elseif k == keys.space then start(s) end
  end
  function app.char(win, c)
    local s = win.state
    if c == "w" then movePlayer(s, -2) elseif c == "s" then movePlayer(s, 2) elseif c == "r" then reset(s) end
  end

  function app.draw(win, g)
    local s = win.state
    local w, h = g.w, g.h
    local nfw, nfh = w, math.max(6, h - 2)
    if nfw ~= s.fw or nfh ~= s.fh then s.fw, s.fh = nfw, nfh; reset(s) end
    g.fill(1, 1, w, h, C.sp0)
    local hud = string.format(" You %d  -  %d CPU    first to %d", s.ps, s.as, WIN)
    g.put(1, 1, hud .. (" "):rep(w), C.wht, C.acc)
    g.fill(1, 2, s.fw, s.fh, C.desk)
    for y = 1, s.fh, 2 do g.put(math.floor(s.fw / 2), 1 + y, "|", C.bar, C.desk) end
    g.fill(2, 1 + math.floor(s.py + 0.5), 2, s.ph, C.wht)
    g.fill(s.fw - 2, 1 + math.floor(s.ay + 0.5), 2, s.ph, C.wht)
    g.put(math.floor(s.bx), 1 + math.floor(s.by + 0.5), "[]", C.sp0, C.yel)
    local msg
    if s.state == "ready" then msg = " Space to serve - W/S or Up/Down "
    elseif s.state == "over" then msg = s.ps >= WIN and " You win! Space " or " CPU wins. Space " end
    if msg then g.put(math.floor((w - #msg) / 2) + 1, math.floor(s.fh / 2) + 2, msg, C.wht, C.acc) end
    g.hot(1, 2, w, math.floor(s.fh / 2), function() movePlayer(s, -3); start(s) end)
    g.hot(1, 2 + math.floor(s.fh / 2), w, s.fh - math.floor(s.fh / 2), function() movePlayer(s, 3); start(s) end)
    local bx = 2
    bx = bx + g.btn(bx, h, "Up", function() movePlayer(s, -3) end) + 1
    bx = bx + g.btn(bx, h, "Down", function() movePlayer(s, 3) end) + 1
    g.btn(bx, h, "Serve", function() start(s) end, "pri")
  end

  return app
end

end)()
EMBED["blockfall"] = (function()
return function(OS)
  local C = OS.C
  -- Blockfall: falling-block puzzle (7-bag, line clears, levels)
  local app = { id = "blockfall", title = "Blockfall", glyph = " # ", icon = "acc", fg = "wht", cat = "Games",
    w = 40, h = 18, single = true, minw = 30, minh = 10, startMax = true, fullH = true, noclick = true }
  local BW, BH = 10, 14
  local SHAPES = {
    I = { { -1, 0 }, { 0, 0 }, { 1, 0 }, { 2, 0 } }, O = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } },
    T = { { -1, 0 }, { 0, 0 }, { 1, 0 }, { 0, 1 } }, S = { { 0, 0 }, { 1, 0 }, { -1, 1 }, { 0, 1 } },
    Z = { { -1, 0 }, { 0, 0 }, { 0, 1 }, { 1, 1 } }, J = { { -1, 0 }, { 0, 0 }, { 1, 0 }, { -1, 1 } },
    L = { { -1, 0 }, { 0, 0 }, { 1, 0 }, { 1, 1 } },
  }
  local ORDER = { "I", "O", "T", "S", "Z", "J", "L" }
  local COLS = { C.sub, C.yel, C.acc, C.grn, C.red, C.wht, C.sp1 }

  local function cells(p)
    local out = {}
    for i, c in ipairs(SHAPES[ORDER[p.k]]) do
      local x, y = c[1], c[2]
      for _ = 1, p.r do x, y = -y, x end
      out[i] = { p.x + x, p.y + y }
    end
    return out
  end

  local function fits(s, p)
    for _, c in ipairs(cells(p)) do
      if c[1] < 1 or c[1] > BW or c[2] > BH then return false end
      if c[2] >= 1 and s.board[c[2]][c[1]] ~= 0 then return false end
    end
    return true
  end

  local function nextKind(s)
    if #s.bag == 0 then
      for i = 1, 7 do s.bag[i] = i end
      for i = 7, 2, -1 do local j = math.random(1, i); s.bag[i], s.bag[j] = s.bag[j], s.bag[i] end
    end
    return table.remove(s.bag)
  end

  local function spawn(s)
    s.cur = { k = s.nextK, x = 5, y = 0, r = 0 }
    s.nextK = nextKind(s)
    if not fits(s, s.cur) then
      s.state = "over"; OS.sfx("lose")
      if s.score > (OS.cfg.blockBest or 0) then OS.cfg.blockBest = s.score; OS.dirty = true end
    end
  end

  local function reset(s)
    s.board = {}
    for y = 1, BH do s.board[y] = {}; for x = 1, BW do s.board[y][x] = 0 end end
    s.bag, s.score, s.lines, s.level, s.state, s.acc = {}, 0, 0, 1, "ready", 0
    s.nextK = nextKind(s)
    spawn(s)
  end

  local function lock(s)
    for _, c in ipairs(cells(s.cur)) do
      if c[2] >= 1 then s.board[c[2]][c[1]] = s.cur.k end
    end
    local cleared = 0
    local y = BH
    while y >= 1 do
      local full = true
      for x = 1, BW do if s.board[y][x] == 0 then full = false break end end
      if full then
        table.remove(s.board, y)
        local row = {}
        for x = 1, BW do row[x] = 0 end
        table.insert(s.board, 1, row)
        cleared = cleared + 1
      else y = y - 1 end
    end
    if cleared > 0 then
      s.score = s.score + ({ 100, 300, 500, 800 })[cleared] * s.level
      s.lines = s.lines + cleared
      s.level = 1 + math.floor(s.lines / 10)
      OS.sfx(cleared >= 4 and "win" or "power")
    else OS.sfx("place") end
    spawn(s)
  end

  local function shift(s, dx)
    if s.state ~= "play" then return end
    local p = { k = s.cur.k, x = s.cur.x + dx, y = s.cur.y, r = s.cur.r }
    if fits(s, p) then s.cur = p; OS.sfx("tick") end
  end
  local function rotate(s)
    if s.state ~= "play" then return end
    for _, kick in ipairs({ 0, -1, 1, -2, 2 }) do
      local p = { k = s.cur.k, x = s.cur.x + kick, y = s.cur.y, r = (s.cur.r + 1) % 4 }
      if fits(s, p) then s.cur = p; OS.sfx("select"); return end
    end
  end
  local function drop1(s)
    if s.state ~= "play" then return false end
    local p = { k = s.cur.k, x = s.cur.x, y = s.cur.y + 1, r = s.cur.r }
    if fits(s, p) then s.cur = p; return true end
    lock(s)
    return false
  end
  local function hard(s)
    if s.state ~= "play" then return end
    local n = 0
    while drop1(s) do n = n + 1 end
    s.score = s.score + n
  end
  local function startOrPause(s)
    if s.state == "ready" then s.state = "play"
    elseif s.state == "play" then s.state = "paused"
    elseif s.state == "paused" then s.state = "play"
    elseif s.state == "over" then reset(s); s.state = "play" end
  end

  local function tick(win)
    local s = win.state
    if not s.alive then return end
    if s.state == "play" and OS.active() == win then
      s.acc = s.acc + 0.05
      if s.acc >= math.max(0.08, 0.6 - s.level * 0.05) then s.acc = 0; drop1(s) end
    end
    OS.timer(0.05, function() tick(win) end)
  end

  function app.init(win)
    local s = { alive = true }
    win.state = s
    reset(s)
    OS.music("fall", win)
    OS.timer(0.2, function() tick(win) end)
  end
  function app.close(win) win.state.alive = false; OS.musicStop(win) end

  function app.key(win, k)
    local s = win.state
    if k == keys.left then shift(s, -1) elseif k == keys.right then shift(s, 1)
    elseif k == keys.up then rotate(s) elseif k == keys.down then drop1(s)
    elseif k == keys.space then if s.state == "play" then hard(s) else startOrPause(s) end end
  end
  function app.char(win, c)
    local s = win.state
    if c == "a" then shift(s, -1) elseif c == "d" then shift(s, 1) elseif c == "w" then rotate(s)
    elseif c == "s" then drop1(s) elseif c == "p" then startOrPause(s) elseif c == "r" then reset(s) end
  end

  function app.draw(win, g)
    local s = win.state
    local w, h = g.w, g.h
    g.fill(1, 1, w, h, C.sp0)
    g.put(1, 1, (" Score " .. s.score .. "  Lines " .. s.lines .. "  Lvl " .. s.level) .. (" "):rep(w), C.wht, C.acc)
    local ox = math.max(1, math.floor((w - BW * 2 - (w >= 36 and 12 or 0)) / 2) + 1)
    g.fill(ox - 1, 2, BW * 2 + 2, BH + 1, C.bar)
    g.fill(ox, 2, BW * 2, BH, C.desk)
    for y = 1, BH do
      for x = 1, BW do
        local v = s.board[y][x]
        if v ~= 0 then g.fill(ox + (x - 1) * 2, 1 + y, 2, 1, COLS[v]) end
      end
    end
    if s.state ~= "over" then
      -- ghost piece
      local gp = { k = s.cur.k, x = s.cur.x, y = s.cur.y, r = s.cur.r }
      while fits(s, { k = gp.k, x = gp.x, y = gp.y + 1, r = gp.r }) do gp.y = gp.y + 1 end
      for _, c in ipairs(cells(gp)) do
        if c[2] >= 1 then g.put(ox + (c[1] - 1) * 2, 1 + c[2], "::", C.bar, C.desk) end
      end
      for _, c in ipairs(cells(s.cur)) do
        if c[2] >= 1 then g.fill(ox + (c[1] - 1) * 2, 1 + c[2], 2, 1, COLS[s.cur.k]) end
      end
    end
    if w >= 36 then
      local px = ox + BW * 2 + 2
      g.put(px, 2, "NEXT", C.sub, C.sp0)
      for _, c in ipairs(SHAPES[ORDER[s.nextK]]) do
        g.fill(px + (c[1] + 1) * 2, 4 + c[2], 2, 1, COLS[s.nextK])
      end
      g.put(px, 8, "Best " .. (OS.cfg.blockBest or 0), C.sub, C.sp0)
      g.put(px, 10, "A/D move", C.sub, C.sp0)
      g.put(px, 11, "W rotate", C.sub, C.sp0)
      g.put(px, 12, "S soft  Spc drop", C.sub, C.sp0)
    end
    local msg
    if s.state == "ready" then msg = " Space to start "
    elseif s.state == "paused" then msg = " Paused - P "
    elseif s.state == "over" then msg = " Game over - Space " end
    if msg then g.put(ox + math.floor((BW * 2 - #msg) / 2), 2 + math.floor(BH / 2), msg, C.wht, C.acc) end
    local bx = 1
    bx = bx + g.btn(bx, h, "<", function() shift(s, -1) end) + 1
    bx = bx + g.btn(bx, h, ">", function() shift(s, 1) end) + 1
    bx = bx + g.btn(bx, h, "Rot", function() rotate(s) end, "pri") + 1
    bx = bx + g.btn(bx, h, "Down", function() drop1(s) end) + 1
    bx = bx + g.btn(bx, h, "Drop", function() hard(s) end) + 1
    g.btn(bx, h, s.state == "play" and "Pause" or "Start", function() startOrPause(s) end, "dark")
  end

  return app
end

end)()
EMBED["breakout"] = (function()
return function(OS)
  local C = OS.C
  -- Brick Breaker
  local app = { id = "breakout", title = "Brick Breaker", glyph = " = ", icon = "red", fg = "wht", cat = "Games",
    w = 46, h = 18, single = true, minw = 30, minh = 10, startMax = true, fullH = true, noclick = true }
  local BWID, ROWS = 4, 5
  local ROWCOL = { "red", "yel", "grn", "acc", "sub" }

  local function buildBricks(s)
    s.cols = math.max(4, math.floor(s.fw / BWID))
    s.bricks = {}
    for r = 1, ROWS do
      s.bricks[r] = {}
      for c = 1, s.cols do
        local on = true
        if s.level % 3 == 2 and (c + r) % 2 == 0 then on = false end
        if s.level % 3 == 0 and r % 2 == 0 and c % 3 == 0 then on = false end
        s.bricks[r][c] = on and 1 or 0
      end
    end
  end

  local function count(s)
    local n = 0
    for r = 1, ROWS do for c = 1, s.cols do n = n + s.bricks[r][c] end end
    return n
  end

  local function park(s)
    s.bx, s.by = s.px + s.pw / 2, s.fh - 2
    s.vx, s.vy, s.live = 0.4, -0.55, false
  end

  local function newLevel(s)
    buildBricks(s); s.pw = math.max(6, math.floor(s.fw / 6)); s.px = s.fw / 2 - s.pw / 2; park(s)
  end

  local function reset(s)
    s.score, s.lives, s.level, s.state = 0, 3, 1, "ready"
    newLevel(s)
  end

  local function launch(s)
    if s.state == "ready" or s.state == "over" or s.state == "clear" then
      if s.state == "over" then reset(s) elseif s.state == "clear" then s.level = s.level + 1; newLevel(s) end
      s.state = "play"
    end
    if not s.live then s.live = true; OS.sfx("select") end
  end

  local function movePaddle(s, d) s.px = math.max(1, math.min(s.fw - s.pw + 1, s.px + d)); if not s.live then s.bx = s.px + s.pw / 2 end end

  local function tick(win)
    local s = win.state
    if not s.alive then return end
    if s.state == "play" and s.live and OS.active() == win then
      local sp = 1 + (s.level - 1) * 0.07
      local nx, ny = s.bx + s.vx * sp, s.by + s.vy * sp
      if nx < 1 then nx = 1; s.vx = math.abs(s.vx); OS.sfx("tick") end
      if nx > s.fw then nx = s.fw; s.vx = -math.abs(s.vx); OS.sfx("tick") end
      if ny < 1 then ny = 1; s.vy = math.abs(s.vy); OS.sfx("tick") end
      -- bricks (rows 2..ROWS+1)
      local row = math.floor(ny) - 1
      local col = math.floor((nx - 1) / BWID) + 1
      if row >= 1 and row <= ROWS and col >= 1 and col <= s.cols and s.bricks[row][col] == 1 then
        s.bricks[row][col] = 0; s.vy = -s.vy; s.score = s.score + 10 * (ROWS - row + 1)
        OS.sfx("coin")
        ny = s.by
        if count(s) == 0 then
          s.state = "clear"; s.live = false; OS.sfx("win")
          if s.score > (OS.cfg.breakBest or 0) then OS.cfg.breakBest = s.score; OS.dirty = true end
        end
      end
      -- paddle
      if s.vy > 0 and ny >= s.fh - 1 and s.by < s.fh and nx >= s.px - 0.5 and nx <= s.px + s.pw + 0.5 then
        local rel = (nx - (s.px + s.pw / 2)) / (s.pw / 2)
        s.vx = rel * 0.7
        s.vy = -math.sqrt(math.max(0.12, 0.62 - s.vx * s.vx * 0.5))
        ny = s.fh - 2
        OS.sfx("hit")
      end
      if ny > s.fh then
        s.lives = s.lives - 1
        if s.lives <= 0 then
          s.state = "over"; OS.sfx("lose")
          if s.score > (OS.cfg.breakBest or 0) then OS.cfg.breakBest = s.score; OS.dirty = true end
        else OS.sfx("die") end
        park(s)
      else s.bx, s.by = nx, ny end
    end
    OS.timer(0.06, function() tick(win) end)
  end

  function app.init(win)
    local s = { alive = true, fw = 40, fh = 13 }
    win.state = s
    reset(s)
    OS.music("brick", win)
    OS.timer(0.2, function() tick(win) end)
  end
  function app.close(win) win.state.alive = false; OS.musicStop(win) end

  function app.key(win, k)
    local s = win.state
    if k == keys.left then movePaddle(s, -3) elseif k == keys.right then movePaddle(s, 3)
    elseif k == keys.space then launch(s) end
  end
  function app.char(win, c)
    local s = win.state
    if c == "a" then movePaddle(s, -3) elseif c == "d" then movePaddle(s, 3) elseif c == "r" then reset(s) end
  end

  function app.draw(win, g)
    local s = win.state
    local w, h = g.w, g.h
    local nfw, nfh = w, math.max(8, h - 2)
    if nfw ~= s.fw or nfh ~= s.fh then s.fw, s.fh = nfw, nfh; reset(s) end
    g.fill(1, 1, w, h, C.sp0)
    g.put(1, 1, string.format(" Score %d   Lives %d   Level %d   Best %d", s.score, s.lives, s.level, OS.cfg.breakBest or 0) .. (" "):rep(w), C.wht, C.acc)
    g.fill(1, 2, s.fw, s.fh, C.desk)
    for r = 1, ROWS do
      for c = 1, s.cols do
        if s.bricks[r][c] == 1 then g.put((c - 1) * BWID + 1, 2 + r, "[==]", C.sp0, C[ROWCOL[r]]) end
      end
    end
    g.fill(math.floor(s.px), 1 + s.fh - 1, s.pw, 1, C.wht)
    g.put(math.floor(s.bx), 1 + math.floor(s.by), "o", C.yel, C.desk)
    local msg
    if s.state == "ready" then msg = " Space / click: launch "
    elseif s.state == "over" then msg = " Game over - Space "
    elseif s.state == "clear" then msg = " Level clear! Space " end
    if msg then g.put(math.floor((w - #msg) / 2) + 1, math.floor(s.fh / 2) + 3, msg, C.wht, C.acc) end
    g.hot(1, 2, w, s.fh, function(rx)
      s.px = math.max(1, math.min(s.fw - s.pw + 1, rx - math.floor(s.pw / 2)))
      if not s.live then s.bx = s.px + s.pw / 2 end
      if not s.live then launch(s) end
    end, true)
    local bx = 2
    bx = bx + g.btn(bx, h, "<", function() movePaddle(s, -3) end) + 1
    bx = bx + g.btn(bx, h, ">", function() movePaddle(s, 3) end) + 1
    g.btn(bx, h, "Launch", function() launch(s) end, "pri")
  end

  return app
end

end)()
EMBED["invaders"] = (function()
return function(OS)
  local C = OS.C
  -- Star Invaders: hold the line against waves of descending aliens (original sprites)
  local app = { id = "invaders", title = "Star Invaders", glyph = " W ", icon = "grn", fg = "sp0", cat = "Games",
    w = 46, h = 18, single = true, minw = 36, minh = 10, startMax = true, fullH = true, noclick = true }
  local ACOLS, AROWS, CW = 8, 4, 5
  local SPR = { "<O>", "{#}", "/W\\", "\\M/" }
  local RCOL = { "red", "yel", "grn", "sub" }

  local function buildWave(s)
    s.aliens = {}
    for r = 1, AROWS do for c = 1, ACOLS do s.aliens[#s.aliens + 1] = { r = r, c = c, alive = true } end end
    s.ax, s.ay, s.dir, s.stepT, s.bombs, s.shots = 2, 2, 1, 0, {}, {}
  end

  local function reset(s)
    s.score, s.lives, s.wave, s.state = 0, 3, 1, "ready"
    s.sx, s.cool, s.t, s.ufo = s.fw / 2, 0, 0, nil
    buildWave(s)
  end

  local function alive(s)
    local n = 0
    for _, a in ipairs(s.aliens) do if a.alive then n = n + 1 end end
    return n
  end

  local function fire(s)
    if s.state == "ready" then s.state = "play" end
    if s.state == "over" then reset(s); s.state = "play" return end
    if s.state == "clear" then s.wave = s.wave + 1; buildWave(s); s.state = "play" return end
    if s.state ~= "play" or s.cool > 0 or #s.shots >= 2 then return end
    s.shots[#s.shots + 1] = { x = math.floor(s.sx), y = s.fh - 2 }
    s.cool = 3
    OS.sfx("shoot")
  end

  local function move(s, d) s.sx = math.max(2, math.min(s.fw - 2, s.sx + d)) end

  local function lose(s)
    s.lives = s.lives - 1
    s.bombs = {}
    OS.sfx("die")
    if s.lives <= 0 then
      s.state = "over"; OS.sfx("lose")
      if s.score > (OS.cfg.invBest or 0) then OS.cfg.invBest = s.score; OS.dirty = true end
    end
  end

  local function tick(win)
    local s = win.state
    if not s.alive then return end
    if s.state == "play" and OS.active() == win then
      s.t = s.t + 1
      if s.cool > 0 then s.cool = s.cool - 1 end
      -- march
      local n = alive(s)
      local interval = math.max(1, math.floor(n / 4) + 1 - math.floor(s.wave / 2))
      s.stepT = s.stepT + 1
      if s.stepT >= interval then
        s.stepT = 0
        local minC, maxC, maxR = 99, 0, 0
        for _, a in ipairs(s.aliens) do
          if a.alive then minC = math.min(minC, a.c); maxC = math.max(maxC, a.c); maxR = math.max(maxR, a.r) end
        end
        local left, right = s.ax + (minC - 1) * CW, s.ax + (maxC - 1) * CW + 3
        if (s.dir > 0 and right >= s.fw) or (s.dir < 0 and left <= 1) then
          s.dir = -s.dir; s.ay = s.ay + 1
          OS.sfx("tick")
        else s.ax = s.ax + s.dir end
        if s.ay + (maxR - 1) * 2 >= s.fh - 2 then s.state = "over"; OS.sfx("lose") end
      end
      -- alien bombs
      if n > 0 and math.random() < 0.12 + s.wave * 0.02 and #s.bombs < 3 + s.wave then
        local a = s.aliens[math.random(1, #s.aliens)]
        if a.alive then s.bombs[#s.bombs + 1] = { x = s.ax + (a.c - 1) * CW + 1, y = s.ay + (a.r - 1) * 2 + 1 } end
      end
      for i = #s.bombs, 1, -1 do
        local b = s.bombs[i]
        if s.t % 2 == 0 then b.y = b.y + 1 end
        if b.y >= s.fh - 1 then
          if math.abs(b.x - s.sx) <= 1.5 then lose(s); break end
          table.remove(s.bombs, i)
        end
      end
      -- player shots
      for i = #s.shots, 1, -1 do
        local sh = s.shots[i]
        sh.y = sh.y - 1
        local hitSomething = false
        if sh.y < 1 then hitSomething = true end
        for _, a in ipairs(s.aliens) do
          if a.alive and not hitSomething then
            local axp, ayp = s.ax + (a.c - 1) * CW, s.ay + (a.r - 1) * 2
            if sh.y == ayp and sh.x >= axp and sh.x <= axp + 2 then
              a.alive = false; hitSomething = true
              s.score = s.score + 10 * (AROWS - a.r + 2)
              OS.sfx("boom")
            end
          end
        end
        if s.ufo and not hitSomething and sh.y == 1 and math.abs(sh.x - s.ufo.x) <= 2 then
          s.score = s.score + 150; s.ufo = nil; hitSomething = true; OS.sfx("power")
        end
        if hitSomething then table.remove(s.shots, i) end
      end
      -- ufo
      if s.ufo then
        s.ufo.x = s.ufo.x + 1
        if s.ufo.x > s.fw then s.ufo = nil end
      elseif math.random() < 0.01 then s.ufo = { x = 1 } end
      if alive(s) == 0 then
        s.state = "clear"; OS.sfx("win")
        if s.score > (OS.cfg.invBest or 0) then OS.cfg.invBest = s.score; OS.dirty = true end
      end
    end
    OS.timer(0.08, function() tick(win) end)
  end

  function app.init(win)
    local s = { alive = true, fw = 40, fh = 13 }
    win.state = s
    reset(s)
    OS.music("invade", win)
    OS.timer(0.2, function() tick(win) end)
  end
  function app.close(win) win.state.alive = false; OS.musicStop(win) end

  function app.key(win, k)
    local s = win.state
    if k == keys.left then move(s, -2) elseif k == keys.right then move(s, 2) elseif k == keys.space then fire(s) end
  end
  function app.char(win, c)
    local s = win.state
    if c == "a" then move(s, -2) elseif c == "d" then move(s, 2) elseif c == "w" then fire(s) elseif c == "r" then reset(s) end
  end

  function app.draw(win, g)
    local s = win.state
    local w, h = g.w, g.h
    local nfw, nfh = math.max(ACOLS * CW + 4, w), math.max(8, h - 2)
    if nfw ~= s.fw or nfh ~= s.fh then s.fw, s.fh = nfw, nfh; reset(s) end
    g.fill(1, 1, w, h, C.sp0)
    g.put(1, 1, string.format(" Score %d   Lives %d   Wave %d   Best %d", s.score, s.lives, s.wave, OS.cfg.invBest or 0) .. (" "):rep(w), C.wht, C.acc)
    g.fill(1, 2, s.fw, s.fh, C.desk)
    for _, a in ipairs(s.aliens) do
      if a.alive then
        local sprite = SPR[a.r]
        if (s.ax + s.t) % 2 == 0 then sprite = sprite:reverse():gsub("[<>{}/\\]", { ["<"] = ">", [">"] = "<", ["{"] = "}", ["}"] = "{", ["/"] = "\\", ["\\"] = "/" }) end
        g.put(s.ax + (a.c - 1) * CW, 1 + s.ay + (a.r - 1) * 2, sprite, C[RCOL[a.r]], C.desk)
      end
    end
    if s.ufo then g.put(s.ufo.x, 2, "<==>", C.red, C.desk) end
    for _, b in ipairs(s.bombs) do g.put(b.x, 1 + b.y, "!", C.yel, C.desk) end
    for _, sh in ipairs(s.shots) do g.put(sh.x, 1 + sh.y, "|", C.wht, C.desk) end
    g.put(math.floor(s.sx) - 1, 1 + s.fh - 1, "/A\\", C.sp0, C.sp)
    g.fill(1, 1 + s.fh, s.fw, 1, C.sp1)
    local msg
    if s.state == "ready" then msg = " A/D move, W or Space fire "
    elseif s.state == "over" then msg = " Earth has fallen - Space "
    elseif s.state == "clear" then msg = " Wave cleared! Space " end
    if msg then g.put(math.floor((w - #msg) / 2) + 1, math.floor(s.fh / 2) + 2, msg, C.wht, C.acc) end
    g.hot(1, 2, w, s.fh, function(rx) s.sx = math.max(2, math.min(s.fw - 2, rx)); fire(s) end, true)
    local bx = 2
    bx = bx + g.btn(bx, h, "<", function() move(s, -3) end) + 1
    bx = bx + g.btn(bx, h, ">", function() move(s, 3) end) + 1
    g.btn(bx, h, "Fire", function() fire(s) end, "pri")
  end

  return app
end

end)()
EMBED["archcomecome"] = (function()
return function(OS)
  local C = OS.C
  -- ArchComeCome: an original maze-chase. Eat every package, dodge the daemons,
  -- grab a power pellet to chase them back. (Original maze, characters and music.)
  local app = { id = "archcomecome", title = "ArchComeCome", glyph = " A ", icon = "acc", fg = "wht", cat = "Games",
    w = 46, h = 18, single = true, minw = 44, minh = 12, startMax = true, fullH = true, noclick = true }
  local MAP = {
    "#####################",
    "#o........#........o#",
    "#.###.###.#.###.###.#",
    "#.....#.......#.....#",
    "#####.#.#####.#.#####",
    "    #.#.......#.#    ",
    "#####.#.##-##.#.#####",
    "........#GGG#........",
    "#####.#.#####.#.#####",
    "    #.#.......#.#    ",
    "#####.#.#####.#.#####",
    "#.....#.......#.....#",
    "#.###.###.#.###.###.#",
    "#o........#........o#",
    "#####################",
  }
  local MW, MH = 21, 15
  local DIRS = { { 0, -1 }, { -1, 0 }, { 0, 1 }, { 1, 0 } }
  local GCOL = { "red", "wht", "grn", "sp" }
  local CORNER = { { 19, 1 }, { 1, 1 }, { 19, 13 }, { 1, 13 } }

  local function chr(x, y)
    x = x % MW
    if y < 0 or y >= MH then return "#" end
    return MAP[y + 1]:sub(x + 1, x + 1)
  end

  local function initDots(s)
    s.dots, s.left = {}, 0
    for y = 0, MH - 1 do
      for x = 0, MW - 1 do
        local c = chr(x, y)
        if c == "." or c == "o" then s.dots[y * 100 + x] = c; s.left = s.left + 1 end
      end
    end
  end

  local function placeActors(s)
    s.px, s.py, s.dx, s.dy, s.qx, s.qy = 10, 11, -1, 0, -1, 0
    s.ghosts = {
      { x = 10, y = 5, dx = -1, dy = 0, mode = "out", wait = 0 },
      { x = 9, y = 7, dx = 0, dy = 0, mode = "house", wait = 25 },
      { x = 11, y = 7, dx = 0, dy = 0, mode = "house", wait = 60 },
      { x = 10, y = 7, dx = 0, dy = 0, mode = "house", wait = 100 },
    }
    for _, g in ipairs(s.ghosts) do g.fright, g.eaten = 0, false end
  end

  local function reset(s)
    s.score, s.lives, s.level, s.state = 0, 3, 1, "ready"
    initDots(s); placeActors(s)
    s.t, s.streak, s.interval = 0, 0, 0.15
  end

  local function nextLevel(s)
    s.level = s.level + 1
    initDots(s); placeActors(s)
    s.interval = math.max(0.07, 0.15 - s.level * 0.01)
    s.state = "ready"
  end

  local function pass(s, x, y, ghost)
    local c = chr(x, y)
    if c == "#" or c == " " then return false end
    if c == "-" then return ghost and (ghost.mode == "leaving" or ghost.eaten) or false end
    return true
  end

  local function wrap(x) return x % MW end

  local function dist2(ax, ay, bx, by) return (ax - bx) ^ 2 + (ay - by) ^ 2 end

  local function moveGhost(s, gi, g)
    if g.mode == "house" then
      g.wait = g.wait - 1
      if g.wait <= 0 then g.mode = "leaving" end
      return
    end
    local tx, ty
    if g.eaten then tx, ty = 10, 7
    elseif g.mode == "leaving" then tx, ty = 10, 5
    elseif g.fright > 0 then tx, ty = nil, nil
    elseif s.scatter then tx, ty = CORNER[gi][1], CORNER[gi][2]
    elseif gi == 1 then tx, ty = s.px, s.py
    elseif gi == 2 then tx, ty = s.px + s.dx * 3, s.py + s.dy * 3
    elseif gi == 3 then tx, ty = MW - 1 - s.px, MH - 1 - s.py
    else
      if dist2(g.x, g.y, s.px, s.py) > 36 then tx, ty = s.px, s.py else tx, ty = CORNER[4][1], CORNER[4][2] end
    end
    local opts = {}
    for i, d in ipairs(DIRS) do
      local nx, ny = wrap(g.x + d[1]), g.y + d[2]
      local rev = (d[1] == -g.dx and d[2] == -g.dy and (g.dx ~= 0 or g.dy ~= 0))
      if pass(s, nx, ny, g) and not rev then opts[#opts + 1] = { d = d, x = nx, y = ny } end
    end
    if #opts == 0 then
      for _, d in ipairs(DIRS) do
        local nx, ny = wrap(g.x + d[1]), g.y + d[2]
        if pass(s, nx, ny, g) then opts[#opts + 1] = { d = d, x = nx, y = ny } end
      end
    end
    if #opts == 0 then return end
    local pick = opts[1]
    if not tx then pick = opts[math.random(1, #opts)]
    else
      local best = 1e9
      for _, o in ipairs(opts) do
        local dd = dist2(o.x, o.y, tx, ty)
        if dd < best then best = dd; pick = o end
      end
    end
    g.dx, g.dy, g.x, g.y = pick.d[1], pick.d[2], pick.x, pick.y
    if g.mode == "leaving" and g.x == 10 and g.y == 5 then g.mode = "out" end
    if g.eaten and g.x == 10 and g.y == 7 then g.eaten = false; g.mode = "house"; g.wait = 12; g.fright = 0 end
  end

  local function caught(s)
    for _, g in ipairs(s.ghosts) do
      if g.x == s.px and g.y == s.py and not g.eaten and g.mode ~= "house" then
        if g.fright > 0 then
          s.streak = s.streak + 1
          s.score = s.score + 100 * 2 ^ s.streak
          g.eaten = true; g.fright = 0
          OS.sfx("stomp")
        else
          s.lives = s.lives - 1
          OS.sfx("die")
          if s.lives <= 0 then
            s.state = "over"; OS.sfx("lose")
            if s.score > (OS.cfg.archBest or 0) then OS.cfg.archBest = s.score; OS.dirty = true end
          else placeActors(s); s.state = "ready" end
          return
        end
      end
    end
  end

  local function step(s)
    s.t = s.t + 1
    s.scatter = (s.t % 110) > 90
    -- player
    local qx, qy = s.px + s.qx, s.py + s.qy
    if pass(s, qx, qy, nil) and chr(qx, qy) ~= "G" then s.dx, s.dy = s.qx, s.qy end
    local nx, ny = wrap(s.px + s.dx), s.py + s.dy
    if pass(s, nx, ny, nil) and chr(nx, ny) ~= "G" then s.px, s.py = nx, ny end
    local k = s.py * 100 + s.px
    local d = s.dots[k]
    if d then
      s.dots[k] = nil; s.left = s.left - 1
      if d == "o" then
        s.score = s.score + 50; s.streak = 0
        for _, g in ipairs(s.ghosts) do
          if not g.eaten then g.fright = 45; g.dx, g.dy = -g.dx, -g.dy end
        end
        OS.sfx("power")
      else
        s.score = s.score + 10
        if s.left % 2 == 0 then OS.sfx("eat") end
      end
    end
    caught(s)
    if s.state ~= "play" then return end
    for gi, g in ipairs(s.ghosts) do
      if g.fright > 0 then
        g.fright = g.fright - 1
        if s.t % 2 == 0 then moveGhost(s, gi, g) end
      else moveGhost(s, gi, g) end
    end
    caught(s)
    if s.state == "play" and s.left <= 0 then
      s.state = "clear"; OS.sfx("win")
      if s.score > (OS.cfg.archBest or 0) then OS.cfg.archBest = s.score; OS.dirty = true end
    end
  end

  local function tick(win)
    local s = win.state
    if not s.alive then return end
    if s.state == "play" and OS.active() == win then step(s) end
    OS.timer(s.interval, function() tick(win) end)
  end

  local function turn(s, dx, dy)
    s.qx, s.qy = dx, dy
    if s.state == "ready" then s.state = "play" end
    if s.state == "over" then reset(s); s.state = "play" end
    if s.state == "clear" then nextLevel(s); s.state = "play" end
  end

  function app.init(win)
    local s = { alive = true }
    win.state = s
    reset(s)
    OS.music("arch", win)
    OS.timer(0.2, function() tick(win) end)
  end
  function app.close(win) win.state.alive = false; OS.musicStop(win) end

  function app.key(win, k)
    local s = win.state
    if k == keys.up then turn(s, 0, -1) elseif k == keys.down then turn(s, 0, 1)
    elseif k == keys.left then turn(s, -1, 0) elseif k == keys.right then turn(s, 1, 0)
    elseif k == keys.space then
      if s.state == "play" then s.state = "paused" elseif s.state == "paused" then s.state = "play"
      else turn(s, s.qx, s.qy) end
    end
  end
  function app.char(win, c)
    local s = win.state
    if c == "w" then turn(s, 0, -1) elseif c == "s" then turn(s, 0, 1)
    elseif c == "a" then turn(s, -1, 0) elseif c == "d" then turn(s, 1, 0) elseif c == "r" then reset(s) end
  end

  function app.draw(win, g)
    local s = win.state
    local w, h = g.w, g.h
    g.fill(1, 1, w, h, C.sp0)
    g.put(1, 1, string.format(" ArchComeCome  Score %d  Lives %d  Lv %d  Best %d", s.score, s.lives, s.level, OS.cfg.archBest or 0) .. (" "):rep(w), C.wht, C.acc)
    local ox = math.max(1, math.floor((w - MW * 2) / 2) + 1)
    local oy = 2
    for y = 0, MH - 1 do
      for x = 0, MW - 1 do
        local c = chr(x, y)
        local sx, sy = ox + x * 2, oy + y
        if c == "#" then g.put(sx, sy, "##", C.bar, C.dock)
        elseif c == " " then g.put(sx, sy, "  ", C.text, C.sp0)
        elseif c == "-" then g.put(sx, sy, "--", C.sub, C.desk)
        else
          local d = s.dots[y * 100 + x]
          if d == "." then g.put(sx, sy, " .", C.yel, C.desk)
          elseif d == "o" then g.put(sx, sy, (s.t % 4 < 2) and " O" or "  ", C.wht, C.desk)
          else g.put(sx, sy, "  ", C.text, C.desk) end
        end
      end
    end
    for gi, gh in ipairs(s.ghosts) do
      local sx, sy = ox + gh.x * 2, oy + gh.y
      if gh.eaten then g.put(sx, sy, "oo", C.wht, C.desk)
      elseif gh.fright > 0 then g.put(sx, sy, "xx", C.sp0, (gh.fright < 12 and s.t % 2 == 0) and C.wht or C.sub)
      else g.put(sx, sy, "{}", C.sp0, C[GCOL[gi]]) end
    end
    g.put(ox + s.px * 2, oy + s.py, (s.t % 2 == 0) and "/\\" or "/|", C.wht, C.acc)
    local msg
    if s.state == "ready" then msg = " Arrows / WASD to start "
    elseif s.state == "paused" then msg = " Paused - Space "
    elseif s.state == "over" then msg = " Game over - any arrow "
    elseif s.state == "clear" then msg = " All packages installed! Arrow: next " end
    if msg then g.put(ox + math.floor((MW * 2 - #msg) / 2), oy + 8, msg, C.wht, C.acc) end
    g.hot(1, 2, w, MH, function(rx, ry)
      local dx, dy = (rx - (ox + s.px * 2)) / 2, ry - (oy + s.py)
      if math.abs(dx) > math.abs(dy) then turn(s, dx > 0 and 1 or -1, 0) else turn(s, 0, dy > 0 and 1 or -1) end
    end)
  end

  return app
end

end)()
EMBED["reactor"] = (function()
return function(OS)
  local C = OS.C
  -- Reactor Monitor: Big / Extreme / Bigger Reactors reactors and turbines (read status, control power and rods)
  local app = { id = "reactor", title = "Reactor Monitor", glyph = " R ", icon = "grn", fg = "wht", cat = "Mods",
    w = 66, h = 19, single = true, minw = 46, minh = 13 }

  local function call(name, m, ...)
    local ok, r = pcall(OS.P.call, name, m, ...)
    if ok then return r end
  end

  -- Bigger Reactors has a different computer-port API from Big / Extreme Reactors: methods such as active(), battery(),
  -- fuelTank(), coolantTank(), rotor() and getControlRod(i) that return objects with their own functions. Every value is read
  -- through helpers that try the new names first and the old flat names second, and only use methods the peripheral really has.
  local mcache = {}
  local function methodSet(n)
    local c = mcache[n]
    if c and os.clock() - c.t < 30 then return c.set end
    local set = {}
    local ok, list = pcall(OS.P.getMethods, n)
    if ok and type(list) == "table" then for _, m in ipairs(list) do set[m] = true end end
    mcache[n] = { set = set, t = os.clock() }
    return set
  end
  local function has(n, m) return methodSet(n)[m] == true end
  -- first existing method of the list that gives an answer
  local function try(n, ...)
    for _, m in ipairs({ ... }) do
      if has(n, m) then
        local r = call(n, m)
        if r ~= nil then return r end
      end
    end
  end
  -- objects (battery(), fuelTank() ...) can't cross Wi-Fi, so the value is asked for as one chain: "battery" then "stored"
  local function ch(n, steps)
    local ok, r = pcall(OS.P.call, n, "!chain", steps)
    if ok then return r end
  end
  local function g1(n, a, b, ...)
    if not has(n, a) then return nil end
    return ch(n, { { m = a }, { m = b, a = { ... } } })
  end

  local function fmt(n, unit)
    if type(n) ~= "number" then return "-" end
    local a = math.abs(n)
    local sfx = ""
    if a >= 1e12 then n = n / 1e12; sfx = "T" elseif a >= 1e9 then n = n / 1e9; sfx = "G"
    elseif a >= 1e6 then n = n / 1e6; sfx = "M" elseif a >= 1e3 then n = n / 1e3; sfx = "k" end
    local str = (sfx == "") and string.format("%d", math.floor(n + 0.5)) or string.format("%.1f", n)
    return str .. sfx .. (unit or "")
  end

  local function scan(s)
    local devs = {}
    for _, n in ipairs(OS.P.names()) do
      local t = (OS.P.getType(n) or ""):lower()
      if (t:find("bigreactors") or t:find("reactor") or t:find("turbine")) and not t:find("fission") and not t:find("fusion") and not t:find("valve") and not t:find("mekanism") then
        devs[#devs + 1] = { name = n, kind = t:find("turbine") and "turbine" or "reactor", bigger = t:find("bigger") ~= nil or has(n, "battery") or has(n, "fuelTank") or has(n, "rotor") }
      end
    end
    s.devs = devs
  end

  local function readDev(d)
    local n, v = d.name, {}
    if d.bigger and d.kind == "reactor" then
      v.active = try(n, "active", "getActive")
      v.energy = g1(n, "battery", "stored") or try(n, "getEnergyStored")
      v.cap = g1(n, "battery", "capacity") or try(n, "getEnergyCapacity") or 10000000
      v.rft = g1(n, "battery", "producedLastTick") or try(n, "getEnergyProducedLastTick")
      v.fuel = g1(n, "fuelTank", "fuel") or g1(n, "fuelTank", "totalReactant") or try(n, "getFuelAmount")
      v.fuelMax = g1(n, "fuelTank", "capacity") or try(n, "getFuelAmountMax")
      v.waste = g1(n, "fuelTank", "waste") or try(n, "getWasteAmount")
      v.burn = g1(n, "fuelTank", "burnedLastTick") or try(n, "getFuelConsumedLastTick")
      v.ftemp = try(n, "fuelTemperature", "fuelHeat", "getFuelTemperature")
      v.ctemp = try(n, "casingTemperature", "casingHeat", "stackTemperature", "stackHeat", "getCasingTemperature")
      v.react = try(n, "fuelReactivity", "getFuelReactivity")
      if has(n, "getControlRod") then v.rod = ch(n, { { m = "getControlRod", a = { 0 } }, { m = "level" } }) end
      if v.rod == nil then v.rod = call(n, "getControlRodLevel", 0) end
      v.cooled = try(n, "isActivelyCooled", "activelyCooled")
      if v.cooled then v.hot = g1(n, "coolantTank", "transitionedLastTick") or try(n, "getHotFluidProducedLastTick") end
    elseif d.bigger then
      v.active = try(n, "active", "getActive")
      v.energy = g1(n, "battery", "stored") or try(n, "getEnergyStored")
      v.cap = g1(n, "battery", "capacity") or try(n, "getEnergyCapacity") or 1000000
      v.rft = g1(n, "battery", "producedLastTick") or try(n, "getEnergyProducedLastTick")
      v.rpm = g1(n, "rotor", "RPM") or g1(n, "rotor", "rpm") or try(n, "getRotorSpeed")
      v.blades = g1(n, "rotor", "bladeCount") or g1(n, "rotor", "blades") or try(n, "getNumberOfBlades")
      v.flow = g1(n, "fluidTank", "nominalFlowRate") or try(n, "getFluidFlowRate")
      v.flowMax = g1(n, "fluidTank", "maxFlowRate") or try(n, "getFluidFlowRateMax") or v.flow
      v.flowCap = g1(n, "fluidTank", "maxNominalFlowRate") or try(n, "getFluidFlowRateMaxMax") or 2000
      v.steam = g1(n, "fluidTank", "inputAmount") or g1(n, "fluidTank", "amount") or try(n, "getInputAmount")
      v.steamMax = g1(n, "fluidTank", "inputCapacity") or g1(n, "fluidTank", "capacity") or try(n, "getInputAmountMax")
      v.inductor = try(n, "coilEngaged", "getInductorEngaged")
    elseif d.kind == "reactor" then
      v.active = call(n, "getActive")
      v.energy = call(n, "getEnergyStored")
      v.cap = call(n, "getEnergyCapacity") or 10000000
      v.rft = call(n, "getEnergyProducedLastTick")
      v.fuel = call(n, "getFuelAmount"); v.fuelMax = call(n, "getFuelAmountMax")
      v.waste = call(n, "getWasteAmount")
      v.ftemp = call(n, "getFuelTemperature"); v.ctemp = call(n, "getCasingTemperature")
      v.react = call(n, "getFuelReactivity"); v.burn = call(n, "getFuelConsumedLastTick")
      v.rod = call(n, "getControlRodLevel", 0)
      v.cooled = call(n, "isActivelyCooled")
      if v.cooled then v.hot = call(n, "getHotFluidProducedLastTick") end
    else
      v.active = call(n, "getActive")
      v.rpm = call(n, "getRotorSpeed")
      v.rft = call(n, "getEnergyProducedLastTick")
      v.energy = call(n, "getEnergyStored"); v.cap = 1000000
      v.steam = call(n, "getInputAmount"); v.steamMax = call(n, "getInputAmountMax")
      v.flow = call(n, "getFluidFlowRate"); v.flowMax = call(n, "getFluidFlowRateMax"); v.flowCap = call(n, "getFluidFlowRateMaxMax")
      v.inductor = call(n, "getInductorEngaged")
      v.blades = call(n, "getNumberOfBlades")
    end
    -- whatever a mod returns, the screen only ever sees numbers and booleans
    for k, val in pairs(v) do
      if k == "active" or k == "cooled" or k == "inductor" then
        if type(val) == "string" then v[k] = (val == "true") elseif type(val) ~= "boolean" then v[k] = nil end
      elseif type(val) == "string" then v[k] = tonumber(val)
      elseif type(val) == "table" then
        -- some versions answer with a table such as { value = 12 } or { amount = 12 }
        v[k] = tonumber(val.value or val.amount or val.stored or val.level or val[1])
      elseif type(val) ~= "number" then v[k] = nil end
    end
    return v
  end

  local function demo(s)
    local t = os.clock()
    s.devs = { { name = "demo_reactor_0", kind = "reactor" }, { name = "demo_turbine_0", kind = "turbine" } }
    local on = not s.demoOff
    s.data.demo_reactor_0 = { active = on, energy = on and (5e6 + math.sin(t / 5) * 2e6) or 1e6, cap = 1e7, rft = on and 1480 + math.sin(t) * 40 or 0,
      fuel = 3200, fuelMax = 4000, waste = 410, ftemp = on and 640 + math.sin(t / 3) * 25 or 30, ctemp = on and 420 or 28, react = 38.5, burn = 0.12,
      rod = s.demoRod or 40 }
    s.data.demo_turbine_0 = { active = on, rpm = on and 1790 + math.sin(t) * 8 or 0, rft = on and 1260 or 0, energy = 4e5, cap = 1e6,
      steam = 1800, steamMax = 4000, flow = 1500, flowMax = 1500, flowCap = 2000, inductor = true, blades = 24 }
  end

  local function mekApi() local m = OS.apps and OS.apps.mekanism; return m and m.api end

  local function poll(s)
    while s.alive do
      local mk = mekApi()
      if s.demo then
        demo(s)
        if mk then
          local m = s.mk
          m.demo = true
          mk.demo(m)
          -- only the reactors, turbines and boilers belong in this tab
          local keep = {}
          for _, d in ipairs(m.devs) do if d.kind ~= "machine" and d.kind ~= "matrix" then keep[#keep + 1] = d end end
          m.devs = keep
        end
      else
        scan(s)
        for _, d in ipairs(s.devs) do
          if not s.alive then return end
          s.data[d.name] = readDev(d)
        end
        if mk then
          local m = s.mk
          m.demo = false
          local list = mk.scan(m, true)
          for _, d in ipairs(list) do
            if not s.alive then return end
            m.data[d.name] = mk.read(m, d)
          end
          mk.alarm(m)
        end
      end
      if s.mk and s.msel > #s.mk.devs then s.msel = math.max(1, #s.mk.devs) end
      if s.sel > #s.devs then s.sel = math.max(1, #s.devs) end
      -- overheat alarm
      for _, d in ipairs(s.devs) do
        local v = s.data[d.name]
        if v and d.kind == "reactor" and ((v.ctemp or 0) > 1500 or (v.ftemp or 0) > 1800) and os.clock() - (s.alarm or -99) > 10 then
          s.alarm = os.clock(); OS.sfx("siren"); OS.toast("Reactor overheating: " .. d.name, 5)
        end
      end
      sleep(1)
    end
  end

  function app.init(win)
    local s = { alive = true, devs = {}, data = {}, sel = 1, msel = 1, tab = "big", demo = false, msg = "" }
    s.mk = { devs = {}, data = {}, sel = 1, demo = false, msg = "", fe = OS.cfg.mekFE ~= false, auto = OS.cfg.mekAuto == true }
    win.state = s
    s.poller = OS.async(function() poll(s) end)
  end
  function app.close(win) local s = win.state; s.alive = false; if s.poller then s.poller.stop = true end end

  -- writes that differ between the two APIs
  local function setFlow(n, rate)
    rate = math.max(0, rate)
    if has(n, "setFluidFlowRateMax") then OS.P.call(n, "setFluidFlowRateMax", rate)
    else ch(n, { { m = "fluidTank" }, { m = "setNominalFlowRate", a = { rate } } }) end
  end
  local function setInductor(n, on)
    if has(n, "setInductorEngaged") then OS.P.call(n, "setInductorEngaged", on)
    elseif has(n, "setCoilEngaged") then OS.P.call(n, "setCoilEngaged", on) end
  end

  local function act(s, d, fn)
    if s.demo then fn(true) return end
    OS.async(function() local ok, e = pcall(fn); if not ok then s.msg = tostring(e) end end)
  end

  local function bar(g, x, y, w, ratio, col, label)
    ratio = math.max(0, math.min(1, ratio or 0))
    g.fill(x, y, w, 1, C.bar)
    local fw = math.floor(ratio * w + 0.5)
    g.fill(x, y, fw, 1, col or C.acc)
    if label then
      local lab = " " .. OS.trunc(label, w - 2)
      for i = 1, #lab do g.put(x + i - 1, y, lab:sub(i, i), C.wht, (i <= fw) and (col or C.acc) or C.bar) end
    end
  end

  local function row(g, x, y, w, label, ratio, col, text)
    g.put(x, y, label, C.sub, C.win)
    bar(g, x + 10, y, w - 10, ratio, col, text)
  end

  local function drawReactor(win, g, x, w, d, v)
    local s = win.state
    local fullW = w
    if w >= 46 then w = w - 14 end
    local hot = (v.ctemp or 0) > 1500 or (v.ftemp or 0) > 1800
    local on = v.active
    local st = (v.active == nil) and "NO DATA" or (hot and "OVERHEAT" or (on and "ONLINE" or "OFFLINE"))
    g.put(x, 1, (d.bigger and "Bigger Reactor " or "Reactor ") .. d.name, C.text, C.win)
    g.put(x, 2, "Status: " .. st, hot and C.red or (on and C.grn or C.yel), C.win)
    g.put(x + 20, 2, "Output " .. fmt(v.rft, " RF/t"), C.text, C.win)
    row(g, x, 4, w, "Buffer", (v.energy or 0) / (v.cap or 1), C.acc, fmt(v.energy, " RF"))
    row(g, x, 5, w, "Fuel", (v.fuel or 0) / math.max(1, v.fuelMax or 1), C.grn, fmt(v.fuel, " mB"))
    row(g, x, 6, w, "Waste", (v.waste or 0) / math.max(1, v.fuelMax or 1), C.yel, fmt(v.waste, " mB"))
    row(g, x, 7, w, "Fuel temp", (v.ftemp or 0) / 2000, (v.ftemp or 0) > 1500 and C.red or C.acc, fmt(v.ftemp, " C"))
    row(g, x, 8, w, "Casing", (v.ctemp or 0) / 2000, (v.ctemp or 0) > 1200 and C.red or C.acc, fmt(v.ctemp, " C"))
    row(g, x, 9, w, "Ctrl rods", (v.rod or 0) / 100, C.sub, (v.rod and (v.rod .. "% inserted")) or "-")
    g.put(x, 11, string.format("Reactivity %s%%   Burn %s mB/t%s", v.react and string.format("%.1f", v.react) or "-", v.burn and string.format("%.3f", v.burn) or "-",
      v.cooled and ("   Steam " .. fmt(v.hot, " mB/t")) or ""), C.sub, C.win)
    -- control-rod silo: three rod columns that fill from the top as the rods go in
    if fullW >= 46 then
      local px, pw = x + w + 2, 12
      g.fill(px, 4, pw, 8, C.bar)
      g.put(px + 1, 4, "ROD DEPTH", C.sub, C.bar)
      local depth = math.max(0, math.min(100, v.rod or 0))
      local fillH = math.floor(5 * depth / 100 + 0.5)
      for i = 0, 2 do
        local cx = px + 1 + i * 4
        g.fill(cx, 5, 3, 5, C.sp0)
        if fillH > 0 then g.fill(cx, 5, 3, fillH, hot and C.red or C.acc) end
      end
      g.put(px + 1, 10, (v.rod and (v.rod .. "% in") or "-"), C.text, C.bar)
      g.put(px + 1, 11, "Steam " .. (v.cooled and fmt(v.hot) or "-"), C.sub, C.bar)
    end
    OS.btnRow(g, x, 13, fullW, {
      { on and "Shut down" or "Start", function()
        act(s, d, function(demoMode)
          if demoMode then s.demoOff = on else OS.P.call(d.name, "setActive", not on) end
        end)
      end, on and "danger" or "pri" },
      { "Rods -", function()
        act(s, d, function(demoMode)
          local lv = math.max(0, (v.rod or 0) - 5)
          if demoMode then s.demoRod = lv else OS.P.call(d.name, "setAllControlRodLevels", lv) end
        end)
      end },
      { "Rods +", function()
        act(s, d, function(demoMode)
          local lv = math.min(100, (v.rod or 0) + 5)
          if demoMode then s.demoRod = lv else OS.P.call(d.name, "setAllControlRodLevels", lv) end
        end)
      end },
      { "SCRAM", function()
        act(s, d, function(demoMode)
          if demoMode then s.demoRod = 100; s.demoOff = true
          else OS.P.call(d.name, "setAllControlRodLevels", 100); OS.P.call(d.name, "setActive", false) end
        end)
      end, "danger" },
    })
    -- control rod insertion slider
    local sy = (fullW < 40) and 16 or 15
    g.put(x, sy, "Control rod insertion", C.sub, C.win)
    local function apply(pct)
      pct = math.max(0, math.min(100, math.floor(pct / 5 + 0.5) * 5))
      act(s, d, function(demoMode)
        if demoMode then s.demoRod = pct else OS.P.call(d.name, "setAllControlRodLevels", pct) end
      end)
    end
    g.slider(x, sy + 1, math.max(8, fullW - 8), (v.rod or 0) / 100, function(f)
      local now = os.clock()
      if now - (s.rodT or 0) > 0.4 then s.rodT = now; s.rodPend = nil; apply(f * 100) else s.rodPend = f * 100 end
    end, C.acc, C.bar)
    g.put(x + math.max(8, fullW - 8) + 1, sy + 1, (v.rod or "-") .. "%", C.text, C.win)
    if s.rodPend and os.clock() - (s.rodT or 0) > 0.4 then local pv = s.rodPend; s.rodPend = nil; s.rodT = os.clock(); apply(pv) end
  end

  local function drawTurbine(win, g, x, w, d, v)
    local s = win.state
    local on = v.active
    g.put(x, 1, (d.bigger and "Bigger Turbine " or "Turbine ") .. d.name, C.text, C.win)
    g.put(x, 2, "Status: " .. ((v.active == nil) and "NO DATA" or (on and "SPINNING" or "STOPPED")), on and C.grn or C.yel, C.win)
    g.put(x + 20, 2, "Output " .. fmt(v.rft, " RF/t"), C.text, C.win)
    local rpmOk = (v.rpm or 0) > 1750 and (v.rpm or 0) < 1850
    row(g, x, 4, w, "Rotor", (v.rpm or 0) / 2000, rpmOk and C.grn or C.yel, fmt(v.rpm, " RPM"))
    row(g, x, 5, w, "Steam in", (v.steam or 0) / math.max(1, v.steamMax or 1), C.acc, fmt(v.steam, " mB"))
    row(g, x, 6, w, "Flow", (v.flow or 0) / math.max(1, v.flowCap or v.flowMax or 1), C.sub, fmt(v.flow, " / ") .. fmt(v.flowMax, " mB/t"))
    row(g, x, 7, w, "Buffer", (v.energy or 0) / (v.cap or 1), C.acc, fmt(v.energy, " RF"))
    g.put(x, 9, string.format("Blades %s   Inductor %s", tostring(v.blades or "-"), v.inductor == nil and "-" or (v.inductor and "engaged" or "off")), C.sub, C.win)
    OS.btnRow(g, x, 13, w, {
      { on and "Stop" or "Start", function()
        act(s, d, function(demoMode) if demoMode then s.demoOff = on else OS.P.call(d.name, "setActive", not on) end end)
      end, on and "danger" or "pri" },
      { "Flow -", function()
        act(s, d, function(demoMode) if not demoMode then setFlow(d.name, (v.flow or v.flowMax or 0) - 100) end end)
      end },
      { "Flow +", function()
        act(s, d, function(demoMode) if not demoMode then setFlow(d.name, math.min(v.flowCap or 2000, (v.flow or v.flowMax or 0) + 100)) end end)
      end },
      { "Inductor", function()
        act(s, d, function(demoMode) if not demoMode then setInductor(d.name, not v.inductor) end end)
      end },
    })
  end

  function app.draw(win, g)
    local s = win.state
    local w, h = g.w, g.h
    g.fill(1, 1, w, h, C.win)
    if w < 40 then
      -- small screen: tabs and a device picker on top, the device below
      local mekT = s.tab == "mek"
      local devs, data, selk = s.devs, s.data, "sel"
      if mekT then devs, data, selk = s.mk.devs, s.mk.data, "msel" end
      g.btn(1, 1, "Bigger", function() s.tab = "big" end, not mekT and "pri" or "dark")
      g.btn(10, 1, "Mekanism", function() s.tab = "mek" end, mekT and "pri" or "dark")
      g.btn(w - 5, 2, "Demo", function()
        s.demo = not s.demo; s.devs = {}; s.data = {}; s.sel = 1
        s.mk.devs = {}; s.mk.data = {}; s.msel = 1
      end, s.demo and "pri" or "dark")
      local n = #devs
      local d = devs[s[selk]]
      g.btn(1, 2, "<", function() if n > 0 then s[selk] = (s[selk] - 2) % n + 1 end end, "dark")
      g.put(5, 2, OS.trunc(d and d.name or "no devices", w - 12), C.text, C.win)
      g.btn(w - 9, 2, ">", function() if n > 0 then s[selk] = s[selk] % n + 1 end end, "dark")
      local x, cw = 1, w
      local sub = OS.subG(g, 0, 3, w, h - 3)
      if not d then
        sub.put(1, 1, mekT and "No Mekanism reactors." or "No reactors found.", C.text, C.win)
        sub.put(1, 3, OS.trunc("Attach a wired modem and", w), C.sub, C.win)
        sub.put(1, 4, OS.trunc("right-click it, or try Demo.", w), C.sub, C.win)
        return
      end
      local v = data[d.name]
      if not v then sub.put(1, 1, "Reading...", C.sub, C.win) return end
      if mekT then
        local mk = mekApi()
        s.mk.demo = s.demo
        if mk then mk.draw({ state = s.mk }, sub, x, cw, d, v) end
      elseif d.kind == "reactor" then drawReactor(win, sub, x, cw, d, v) else drawTurbine(win, sub, x, cw, d, v) end
      return
    end
    local lw = math.min(22, math.floor(w / 3))
    g.fill(1, 1, lw, h, C.bar)
    local mekTab = s.tab == "mek"
    local devs, data, selk = s.devs, s.data, "sel"
    if mekTab then devs, data, selk = s.mk.devs, s.mk.data, "msel" end
    local total = 0
    for _, d in ipairs(s.devs) do total = total + ((s.data[d.name] or {}).rft or 0) end
    g.put(2, 1, OS.trunc("Total " .. fmt(total, " RF/t"), lw - 2), C.yel, C.bar)
    -- tabs: Bigger / Big Reactors and Mekanism
    g.btn(2, 2, "Bigger", function() s.tab = "big" end, not mekTab and "pri" or "dark")
    g.btn(11, 2, "Mekanism", function() s.tab = "mek" end, mekTab and "pri" or "dark")
    for i, d in ipairs(devs) do
      local v = data[d.name] or {}
      local y = 3 + i
      if y < h - 2 then
        local on = (i == s[selk])
        local alive = v.active
        g.fill(1, y, lw, 1, on and C.acc or C.bar)
        g.put(2, y, "*", alive and C.grn or C.red, on and C.acc or C.bar)
        local tag = mekTab and (d.tag or "M") or (d.kind == "reactor" and "R" or "T")
        g.put(4, y, OS.trunc(tag .. " " .. d.name, lw - 4), on and C.wht or C.text, on and C.acc or C.bar)
        g.hot(1, y, lw, 1, function() s[selk] = i end)
      end
    end
    g.btn(2, h, s.demo and "Demo: on" or "Demo", function()
      s.demo = not s.demo; s.devs = {}; s.data = {}; s.sel = 1
      s.mk.devs = {}; s.mk.data = {}; s.msel = 1
    end)
    if mekTab then
      g.btn(2, h - 1, s.mk.fe and "Unit: FE" or "Unit: J", function() s.mk.fe = not s.mk.fe; OS.cfg.mekFE = s.mk.fe; OS.save() end, "dark")
    end
    local x, cw = lw + 2, w - lw - 2
    local d = devs[s[selk]]
    if not d then
      if mekTab then
        g.put(x, 2, "No Mekanism reactors found.", C.text, C.win)
        local help = { "Attach a wired modem to a Fission or Fusion", "Reactor Logic Adapter, Turbine Valve or Boiler",
          "Valve and right-click the modem.", "", "Induction matrices and other machines are", "in the Mekanism app.",
          "", "Press Demo (bottom-left) to preview." }
        for i, l in ipairs(help) do g.put(x, 3 + i, OS.trunc(l, cw), C.sub, C.win) end
      else
        g.put(x, 2, "No reactor peripherals found.", C.text, C.win)
        local help = { "Place a wired modem on the reactor's Computer Port",
          "(or turbine's), attach it to this computer's network,", "right-click the modem to connect, then re-open.",
          "", "Works with Big, Extreme and Bigger Reactors.", "Mekanism reactors are in the Mekanism tab.",
          "Press Demo (bottom-left) to preview the GUI." }
        for i, l in ipairs(help) do g.put(x, 3 + i, OS.trunc(l, cw), C.sub, C.win) end
      end
      return
    end
    local v = data[d.name]
    if not v then g.put(x, 2, "Reading " .. d.name .. " ...", C.sub, C.win) return end
    if mekTab then
      local mk = mekApi()
      s.mk.demo = s.demo
      if mk then mk.draw({ state = s.mk }, g, x, cw, d, v) end
      if s.mk.msg ~= "" then g.put(x, h, OS.trunc(s.mk.msg, cw), C.red, C.win) end
    else
      if d.kind == "reactor" then drawReactor(win, g, x, cw, d, v) else drawTurbine(win, g, x, cw, d, v) end
      if s.msg ~= "" then g.put(x, h, OS.trunc(s.msg, cw), C.red, C.win) end
    end
  end

  return app
end

end)()
EMBED["mekanism"] = (function()
return function(OS)
  local C = OS.C
  -- Mekanism Monitor: fission and fusion reactors, induction matrices, turbines, boilers and any other Mekanism machine
  -- with an energy buffer. Mekanism's built-in computer support is used, so no extra mod is needed. Every value is read
  -- through helpers that only call methods the peripheral really has, so a missing method shows "-" and never crashes.
  local app = { id = "mekanism", title = "Mekanism", glyph = " M ", icon = "sub", fg = "sp0", cat = "Mods",
    w = 62, h = 19, single = true, minw = 46, minh = 13 }

  local function call(name, m, ...)
    local ok, r = pcall(OS.P.call, name, m, ...)
    if ok then return r end
  end

  local mcache = {}
  local function methodSet(n)
    local c = mcache[n]
    if c and os.clock() - c.t < 30 then return c.set end
    local set = {}
    local ok, list = pcall(OS.P.getMethods, n)
    if ok and type(list) == "table" then for _, m in ipairs(list) do set[m] = true end end
    mcache[n] = { set = set, t = os.clock() }
    return set
  end
  local function has(n, m) return methodSet(n)[m] == true end
  -- first existing method that answers
  local function try(n, ...)
    for _, m in ipairs({ ... }) do
      if has(n, m) then
        local r = call(n, m)
        if r ~= nil then return r end
      end
    end
  end
  local function num(x)
    if type(x) == "number" then return x end
    if type(x) == "string" then return tonumber(x) end
    if type(x) == "table" then return tonumber(x.amount or x.value or x[1]) end
  end
  local function bool(x)
    if type(x) == "boolean" then return x end
    if type(x) == "string" then return x == "true" end
    if type(x) == "number" then return x ~= 0 end
  end
  local function tname(x)
    if type(x) == "table" and type(x.name) == "string" then return (x.name:gsub("^%w+:", ""):gsub("_", " ")) end
  end

  local function fmt(n, unit)
    if type(n) ~= "number" then return "-" end
    local a = math.abs(n)
    local sfx = ""
    if a >= 1e15 then n = n / 1e15; sfx = "P" elseif a >= 1e12 then n = n / 1e12; sfx = "T" elseif a >= 1e9 then n = n / 1e9; sfx = "G"
    elseif a >= 1e6 then n = n / 1e6; sfx = "M" elseif a >= 1e3 then n = n / 1e3; sfx = "k" end
    local str
    if sfx == "" then str = (n == math.floor(n)) and string.format("%d", n) or string.format("%.1f", n) else str = string.format("%.1f", n) end
    return str .. sfx .. (unit or "")
  end

  -- Mekanism reports energy in joules; 1 FE = 2.5 J
  local function en(s, j)
    if type(j) ~= "number" then return nil end
    return s.fe and (j / 2.5) or j
  end
  local function eu(s) return s.fe and " FE" or " J" end

  local KINDS = {
    { kind = "fission", match = "fissionreactorlogic", label = "Fission reactor", tag = "F" },
    { kind = "fusion", match = "fusionreactorlogic", label = "Fusion reactor", tag = "U" },
    { kind = "matrix", match = "inductionport", label = "Induction matrix", tag = "I" },
    { kind = "turbine", match = "turbinevalve", label = "Turbine", tag = "T" },
    { kind = "boiler", match = "boilervalve", label = "Boiler", tag = "B" },
  }

  local function scan(s, only)
    local devs = {}
    for _, n in ipairs(OS.P.names()) do
      local t = (OS.P.getType(n) or ""):lower()
      local found
      for _, k in ipairs(KINDS) do if t:find(k.match, 1, true) then found = k end end
      if not found and not only and t ~= "" and not t:find("monitor") and not t:find("modem") and not t:find("speaker") and not t:find("drive") then
        -- any other Mekanism machine: they all share this energy trio
        if has(n, "getEnergy") and has(n, "getMaxEnergy") and has(n, "getEnergyFilledPercentage") then
          found = { kind = "machine", label = "Machine", tag = "M" }
        end
      end
      if found then devs[#devs + 1] = { name = n, kind = found.kind, label = found.label, tag = found.tag, type = t } end
    end
    s.devs = devs
    return devs
  end

  local function readDev(s, d)
    local n, v = d.name, {}
    if d.kind == "fission" then
      v.active = bool(try(n, "getStatus"))
      v.temp = num(try(n, "getTemperature"))
      v.dmg = num(try(n, "getDamagePercent"))
      v.fuelP = num(try(n, "getFuelFilledPercentage"))
      v.wasteP = num(try(n, "getWasteFilledPercentage"))
      v.coolP = num(try(n, "getCoolantFilledPercentage"))
      v.heatP = num(try(n, "getHeatedCoolantFilledPercentage"))
      v.burn = num(try(n, "getBurnRate")); v.burnNow = num(try(n, "getActualBurnRate")); v.burnMax = num(try(n, "getMaxBurnRate"))
      v.heating = num(try(n, "getHeatingRate"))
      v.fuelAmt = num(try(n, "getFuel")); v.fuelCap = num(try(n, "getFuelCapacity"))
      v.disabled = bool(try(n, "isForceDisabled"))
    elseif d.kind == "fusion" then
      v.active = bool(try(n, "isIgnited", "getStatus"))
      v.plasma = num(try(n, "getPlasmaTemperature")); v.case = num(try(n, "getCaseTemperature"))
      v.prod = num(try(n, "getProductionRate")); v.inj = num(try(n, "getInjectionRate"))
      v.energyP = num(try(n, "getEnergyFilledPercentage"))
      v.energy = en(s, num(try(n, "getEnergy"))); v.cap = en(s, num(try(n, "getMaxEnergy")))
      v.dP = num(try(n, "getDeuteriumFilledPercentage")); v.tP = num(try(n, "getTritiumFilledPercentage"))
      v.dtP = num(try(n, "getDTFuelFilledPercentage"))
    elseif d.kind == "matrix" then
      v.energy = en(s, num(try(n, "getEnergy"))); v.cap = en(s, num(try(n, "getMaxEnergy")))
      v.pct = num(try(n, "getEnergyFilledPercentage"))
      v.inp = en(s, num(try(n, "getLastInput"))); v.out = en(s, num(try(n, "getLastOutput")))
      v.xfer = en(s, num(try(n, "getTransferCap")))
      v.cells = num(try(n, "getInstalledCells")); v.prov = num(try(n, "getInstalledProviders"))
    elseif d.kind == "turbine" then
      v.energy = en(s, num(try(n, "getEnergy"))); v.cap = en(s, num(try(n, "getMaxEnergy")))
      v.pct = num(try(n, "getEnergyFilledPercentage"))
      v.prod = en(s, num(try(n, "getProductionRate"))); v.prodMax = en(s, num(try(n, "getMaxProduction")))
      v.flow = num(try(n, "getFlowRate")); v.flowMax = num(try(n, "getMaxFlowRate"))
      v.steamP = num(try(n, "getSteamFilledPercentage"))
      v.blades = num(try(n, "getBlades")); v.vents = num(try(n, "getVents"))
      v.dump = try(n, "getDumpingMode")
    elseif d.kind == "boiler" then
      v.temp = num(try(n, "getTemperature"))
      v.boil = num(try(n, "getBoilRate")); v.boilMax = num(try(n, "getMaxBoilRate"))
      v.waterP = num(try(n, "getWaterFilledPercentage")); v.steamP = num(try(n, "getSteamFilledPercentage"))
      v.coolP = num(try(n, "getCooledCoolantFilledPercentage")); v.heatP = num(try(n, "getHeatedCoolantFilledPercentage"))
    else
      v.energy = en(s, num(try(n, "getEnergy"))); v.cap = en(s, num(try(n, "getMaxEnergy")))
      v.pct = num(try(n, "getEnergyFilledPercentage"))
      v.xfer = en(s, num(try(n, "getTransferCap")))
    end
    if type(v.dump) ~= "string" then v.dump = nil end
    return v
  end

  local function demo(s)
    local t = os.clock()
    s.devs = {
      { name = "demo_fission", kind = "fission", label = "Fission reactor", tag = "F" },
      { name = "demo_matrix", kind = "matrix", label = "Induction matrix", tag = "I" },
      { name = "demo_turbine", kind = "turbine", label = "Turbine", tag = "T" },
      { name = "demo_cube", kind = "machine", label = "Machine", tag = "M" },
    }
    local on = not s.demoOff
    local burn = s.demoBurn or 8
    s.data.demo_fission = { active = on, temp = on and 780 + math.sin(t / 4) * 20 or 300, dmg = 0, fuelP = 0.74, wasteP = 0.22, coolP = 0.81, heatP = 0.35,
      burn = burn, burnNow = on and burn or 0, burnMax = 24, heating = on and burn * 2400 or 0, fuelAmt = 74000, fuelCap = 100000 }
    s.data.demo_matrix = { energy = en(s, 3.2e11 + math.sin(t / 6) * 2e10), cap = en(s, 8e11), pct = 0.4, inp = en(s, 5.2e6), out = en(s, 3.1e6),
      xfer = en(s, 2e8), cells = 12, prov = 8 }
    s.data.demo_turbine = { energy = en(s, 1.4e7), cap = en(s, 2e7), pct = 0.7, prod = en(s, on and 4.1e6 or 0), prodMax = en(s, 9e6), flow = on and 14000 or 0, flowMax = 32000,
      steamP = 0.62, blades = 24, vents = 6, dump = "IDLE" }
    s.data.demo_cube = { energy = en(s, 4.2e7), cap = en(s, 6e7), pct = 0.7, xfer = en(s, 1e6) }
  end

  -- what the matrix gained or lost over the last few polls (J/t estimate from input - output)
  local function poll(s)
    while s.alive do
      if s.demo then demo(s)
      else
        scan(s)
        for _, d in ipairs(s.devs) do
          if not s.alive then return end
          s.data[d.name] = readDev(s, d)
        end
      end
      if s.sel > #s.devs then s.sel = math.max(1, #s.devs) end
      app.alarm(s)
      sleep(1)
    end
  end

  function app.alarm(s)
    for _, d in ipairs(s.devs) do
      local v = s.data[d.name]
      if v and d.kind == "fission" and v.active then
        local danger = (v.dmg or 0) >= 0.10 or ((v.coolP or 1) < 0.05) or ((v.wasteP or 0) > 0.95)
        if danger and os.clock() - (s.alarm or -99) > 10 then
          s.alarm = os.clock(); OS.sfx("siren"); OS.toast("Fission reactor in danger: " .. d.name, 5)
          if s.auto and not s.demo then pcall(OS.P.call, d.name, "scram") end
        end
      end
    end
  end

  function app.init(win)
    local s = { alive = true, devs = {}, data = {}, sel = 1, demo = false, msg = "", fe = OS.cfg.mekFE ~= false, auto = OS.cfg.mekAuto == true }
    win.state = s
    s.poller = OS.async(function() poll(s) end)
  end
  function app.close(win) local s = win.state; s.alive = false; if s.poller then s.poller.stop = true end end

  local function act(s, fn)
    if s.demo then fn(true) return end
    OS.async(function() local ok, e = pcall(fn); if not ok then s.msg = tostring(e) end end)
  end

  local function bar(g, x, y, w, ratio, col, label)
    ratio = math.max(0, math.min(1, ratio or 0))
    g.fill(x, y, w, 1, C.bar)
    local fw = math.floor(ratio * w + 0.5)
    g.fill(x, y, fw, 1, col or C.acc)
    if label then
      local lab = " " .. OS.trunc(label, w - 2)
      for i = 1, #lab do g.put(x + i - 1, y, lab:sub(i, i), C.wht, (i <= fw) and (col or C.acc) or C.bar) end
    end
  end
  local function row(g, x, y, w, label, ratio, col, text)
    g.put(x, y, OS.trunc(label, 10), C.sub, C.win)
    bar(g, x + 11, y, math.max(4, w - 11), ratio, col, text)
  end
  local function pct(p) return type(p) == "number" and string.format("%.1f%%", p * 100) or "-" end

  local function drawFission(win, g, x, w, d, v)
    local s = win.state
    local on = v.active
    local danger = (v.dmg or 0) >= 0.10 or (v.coolP or 1) < 0.05 or (v.wasteP or 0) > 0.95
    local st = (v.active == nil) and "NO DATA" or (danger and on and "DANGER" or (on and "ONLINE" or "OFFLINE"))
    g.put(x, 1, "Fission reactor " .. d.name, C.text, C.win)
    g.put(x, 2, "Status: " .. st, danger and on and C.red or (on and C.grn or C.yel), C.win)
    g.put(x + 20, 2, "Burn " .. (v.burnNow and string.format("%.2f", v.burnNow) or "-") .. " mB/t", C.text, C.win)
    row(g, x, 4, w, "Damage", v.dmg, (v.dmg or 0) >= 0.10 and C.red or C.grn, pct(v.dmg))
    row(g, x, 5, w, "Temp", (v.temp or 0) / 1400, (v.temp or 0) > 1000 and C.red or C.acc, fmt(v.temp, " K") .. (v.temp and string.format("  (%d C)", math.floor(v.temp - 273.15)) or ""))
    row(g, x, 6, w, "Fuel", v.fuelP, C.grn, pct(v.fuelP))
    row(g, x, 7, w, "Waste", v.wasteP, (v.wasteP or 0) > 0.9 and C.red or C.yel, pct(v.wasteP))
    row(g, x, 8, w, "Coolant", v.coolP, (v.coolP or 1) < 0.1 and C.red or C.acc, pct(v.coolP))
    row(g, x, 9, w, "Heated", v.heatP, C.sub, pct(v.heatP))
    g.put(x, 11, OS.trunc(string.format("Burn set %s / max %s mB/t   Heating %s mB/t", v.burn and string.format("%.2f", v.burn) or "-", v.burnMax and string.format("%.1f", v.burnMax) or "-", fmt(v.heating)), w), C.sub, C.win)
    if v.disabled then g.put(x, 12, "Reactor is force disabled", C.red, C.win) end
    local step = math.max(0.1, (v.burnMax or 10) / 20)
    local ly = OS.btnRow(g, x, 14, w, {
      { on and "Scram" or "Activate", function()
        act(s, function(demoMode)
          if demoMode then s.demoOff = on elseif on then OS.P.call(d.name, "scram") else OS.P.call(d.name, "activate") end
        end)
      end, on and "danger" or "pri" },
      { "Burn -", function()
        act(s, function(demoMode)
          local r = math.max(0, (v.burn or 0) - step)
          if demoMode then s.demoBurn = r else OS.P.call(d.name, "setBurnRate", r) end
        end)
      end },
      { "Burn +", function()
        act(s, function(demoMode)
          local r = math.min(v.burnMax or 1000, (v.burn or 0) + step)
          if demoMode then s.demoBurn = r else OS.P.call(d.name, "setBurnRate", r) end
        end)
      end },
      { s.auto and "Auto SCRAM: on" or "Auto SCRAM", function() s.auto = not s.auto; OS.cfg.mekAuto = s.auto; OS.save() end, s.auto and "pri" or "dark" },
    })
    g.put(x, ly + 1, OS.trunc("Auto SCRAM: 10% damage, low coolant, full waste.", w), C.sub, C.win)
  end

  local function drawFusion(win, g, x, w, d, v)
    local s = win.state
    local on = v.active
    g.put(x, 1, "Fusion reactor " .. d.name, C.text, C.win)
    g.put(x, 2, "Status: " .. ((v.active == nil) and "NO DATA" or (on and "IGNITED" or "OFF")), on and C.grn or C.yel, C.win)
    g.put(x + 20, 2, "Output " .. fmt(en(s, v.prod) or v.prod, eu(s) .. "/t"), C.text, C.win)
    row(g, x, 4, w, "Plasma", (v.plasma or 0) / 4e8, C.red, fmt(v.plasma, " K"))
    row(g, x, 5, w, "Case", (v.case or 0) / 2e7, C.acc, fmt(v.case, " K"))
    row(g, x, 6, w, "Buffer", v.energyP or ((v.energy or 0) / math.max(1, v.cap or 1)), C.acc, fmt(v.energy, eu(s)))
    if v.dP then row(g, x, 7, w, "Deuterium", v.dP, C.grn, pct(v.dP)) end
    if v.tP then row(g, x, 8, w, "Tritium", v.tP, C.yel, pct(v.tP)) end
    if v.dtP then row(g, x, 9, w, "D-T fuel", v.dtP, C.grn, pct(v.dtP)) end
    g.put(x, 11, "Injection rate " .. (v.inj and tostring(math.floor(v.inj)) or "-"), C.sub, C.win)
    OS.btnRow(g, x, 14, w, {
      { "Inj -", function()
        act(s, function(demoMode) if not demoMode then OS.P.call(d.name, "setInjectionRate", math.max(0, (v.inj or 0) - 2)) end end)
      end },
      { "Inj +", function()
        act(s, function(demoMode) if not demoMode then OS.P.call(d.name, "setInjectionRate", math.min(98, (v.inj or 0) + 2)) end end)
      end },
    })
  end

  local function drawMatrix(win, g, x, w, d, v)
    local s = win.state
    g.put(x, 1, "Induction matrix " .. d.name, C.text, C.win)
    local p = v.pct or ((v.energy or 0) / math.max(1, v.cap or 1))
    g.put(x, 2, "Stored " .. fmt(v.energy, eu(s)) .. " of " .. fmt(v.cap, eu(s)), C.text, C.win)
    row(g, x, 4, w, "Energy", p, p < 0.15 and C.red or C.acc, pct(p))
    row(g, x, 5, w, "Input", (v.inp or 0) / math.max(1, v.xfer or 1), C.grn, fmt(v.inp, eu(s) .. "/t"))
    row(g, x, 6, w, "Output", (v.out or 0) / math.max(1, v.xfer or 1), C.yel, fmt(v.out, eu(s) .. "/t"))
    local net = (v.inp and v.out) and (v.inp - v.out) or nil
    g.put(x, 8, "Net " .. (net and ((net >= 0 and "+" or "-") .. fmt(math.abs(net), eu(s) .. "/t")) or "-"), net and (net >= 0 and C.grn or C.red) or C.sub, C.win)
    g.put(x, 9, "Transfer cap " .. fmt(v.xfer, eu(s) .. "/t"), C.sub, C.win)
    g.put(x, 10, "Cells " .. tostring(v.cells or "-") .. "   Providers " .. tostring(v.prov or "-"), C.sub, C.win)
    if net and net < 0 and v.energy and v.energy > 0 then
      local secs = v.energy / (-net) / 20
      g.put(x, 12, "Empty in " .. (secs > 3600 and string.format("%.1f h", secs / 3600) or string.format("%d min", math.floor(secs / 60))), C.yel, C.win)
    elseif net and net > 0 and v.cap and v.energy then
      local secs = (v.cap - v.energy) / net / 20
      g.put(x, 12, "Full in " .. (secs > 3600 and string.format("%.1f h", secs / 3600) or string.format("%d min", math.floor(secs / 60))), C.grn, C.win)
    end
  end

  local function drawTurbine(win, g, x, w, d, v)
    local s = win.state
    g.put(x, 1, "Turbine " .. d.name, C.text, C.win)
    g.put(x, 2, "Output " .. fmt(v.prod, eu(s) .. "/t") .. " of " .. fmt(v.prodMax, eu(s) .. "/t"), C.text, C.win)
    row(g, x, 4, w, "Energy", v.pct or ((v.energy or 0) / math.max(1, v.cap or 1)), C.acc, pct(v.pct))
    row(g, x, 5, w, "Steam", v.steamP, C.sub, pct(v.steamP))
    row(g, x, 6, w, "Flow", (v.flow or 0) / math.max(1, v.flowMax or 1), C.grn, fmt(v.flow, " / ") .. fmt(v.flowMax, " mB/t"))
    row(g, x, 7, w, "Production", (v.prod or 0) / math.max(1, v.prodMax or 1), C.yel, fmt(v.prod, eu(s) .. "/t"))
    g.put(x, 9, string.format("Blades %s   Vents %s   Dump %s", tostring(v.blades or "-"), tostring(v.vents or "-"), tostring(v.dump or "-")), C.sub, C.win)
  end

  local function drawBoiler(win, g, x, w, d, v)
    g.put(x, 1, "Boiler " .. d.name, C.text, C.win)
    row(g, x, 3, w, "Temp", (v.temp or 0) / 1500, C.red, fmt(v.temp, " K"))
    row(g, x, 4, w, "Boil rate", (v.boil or 0) / math.max(1, v.boilMax or 1), C.grn, fmt(v.boil, " / ") .. fmt(v.boilMax, " mB/t"))
    row(g, x, 5, w, "Water", v.waterP, C.acc, pct(v.waterP))
    row(g, x, 6, w, "Steam", v.steamP, C.sub, pct(v.steamP))
    if v.coolP then row(g, x, 7, w, "Coolant", v.coolP, C.acc, pct(v.coolP)) end
    if v.heatP then row(g, x, 8, w, "Heated", v.heatP, C.yel, pct(v.heatP)) end
  end

  local function drawMachine(win, g, x, w, d, v)
    local s = win.state
    g.put(x, 1, OS.trunc(d.name .. "  (" .. (d.type or "") .. ")", w), C.text, C.win)
    local p = v.pct or ((v.energy or 0) / math.max(1, v.cap or 1))
    g.put(x, 2, "Stored " .. fmt(v.energy, eu(s)) .. " of " .. fmt(v.cap, eu(s)), C.text, C.win)
    row(g, x, 4, w, "Energy", p, p < 0.15 and C.red or C.acc, pct(p))
    g.put(x, 6, "Transfer cap " .. fmt(v.xfer, eu(s) .. "/t"), C.sub, C.win)
  end

  -- used by the Reactor Monitor, which shows Mekanism reactors in its own tab
  app.api = {
    scan = scan, read = readDev, demo = demo, alarm = function(s) return app.alarm(s) end,
    draw = function(win, g, x, cw, d, v)
      if d.kind == "fission" then drawFission(win, g, x, cw, d, v)
      elseif d.kind == "fusion" then drawFusion(win, g, x, cw, d, v)
      elseif d.kind == "matrix" then drawMatrix(win, g, x, cw, d, v)
      elseif d.kind == "turbine" then drawTurbine(win, g, x, cw, d, v)
      elseif d.kind == "boiler" then drawBoiler(win, g, x, cw, d, v)
      else drawMachine(win, g, x, cw, d, v) end
    end,
  }

  function app.draw(win, g)
    local s = win.state
    local w, h = g.w, g.h
    g.fill(1, 1, w, h, C.win)
    if w < 40 then
      -- small screen: device picker on top, the device below
      local n = #s.devs
      local d = s.devs[s.sel]
      g.btn(1, 1, "<", function() if n > 0 then s.sel = (s.sel - 2) % n + 1 end end, "dark")
      g.put(5, 1, OS.trunc(d and d.name or "no devices", w - 18), C.text, C.win)
      g.btn(w - 15, 1, ">", function() if n > 0 then s.sel = s.sel % n + 1 end end, "dark")
      g.btn(w - 11, 1, s.fe and "FE" or "J", function() s.fe = not s.fe; OS.cfg.mekFE = s.fe; OS.save() end, "dark")
      g.btn(w - 6, 1, "Demo", function() s.demo = not s.demo; s.devs = {}; s.data = {}; s.sel = 1 end, s.demo and "pri" or "dark")
      local sub = OS.subG(g, 0, 2, w, h - 2)
      if not d then sub.put(1, 1, "No Mekanism devices.", C.text, C.win) sub.put(1, 3, "Try Demo, or attach a modem.", C.sub, C.win) return end
      local v = s.data[d.name]
      if not v then sub.put(1, 1, "Reading...", C.sub, C.win) return end
      app.api.draw(win, sub, 1, w, d, v)
      return
    end
    local lw = math.min(22, math.floor(w / 3))
    g.fill(1, 1, lw, h, C.bar)
    g.put(2, 1, "Mekanism", C.yel, C.bar)
    for i, d in ipairs(s.devs) do
      local v = s.data[d.name] or {}
      local y = 2 + i
      if y < h - 2 then
        local on = (i == s.sel)
        local alive = v.active
        if alive == nil then alive = (v.energy or 0) > 0 end
        g.fill(1, y, lw, 1, on and C.acc or C.bar)
        g.put(2, y, "*", alive and C.grn or C.red, on and C.acc or C.bar)
        g.put(4, y, OS.trunc(d.tag .. " " .. d.name, lw - 4), on and C.wht or C.text, on and C.acc or C.bar)
        g.hot(1, y, lw, 1, function() s.sel = i end)
      end
    end
    g.btn(2, h, s.demo and "Demo: on" or "Demo", function() s.demo = not s.demo; s.devs = {}; s.data = {}; s.sel = 1 end)
    g.btn(2, h - 1, s.fe and "Unit: FE" or "Unit: J", function() s.fe = not s.fe; OS.cfg.mekFE = s.fe; OS.save() end, "dark")
    local x, cw = lw + 2, w - lw - 2
    local d = s.devs[s.sel]
    if not d then
      g.put(x, 2, "No Mekanism peripherals found.", C.text, C.win)
      local help = { "Mekanism has built-in computer support.", "Attach a wired modem to a Fission/Fusion Logic",
        "Adapter, Induction Port, Turbine Valve, Boiler Valve", "or any machine, then right-click the modem.",
        "", "Press Demo (bottom-left) to preview the GUI." }
      for i, l in ipairs(help) do g.put(x, 3 + i, OS.trunc(l, cw), C.sub, C.win) end
      return
    end
    local v = s.data[d.name]
    if not v then g.put(x, 2, "Reading " .. d.name .. " ...", C.sub, C.win) return end
    app.api.draw(win, g, x, cw, d, v)
    if s.msg ~= "" then g.put(x, h, OS.trunc(s.msg, cw), C.red, C.win) end
  end

  return app
end

end)()
EMBED["energy"] = (function()
return function(OS)
  local C = OS.C
  -- Draconic Energy Core: dashboard for Draconic Evolution energy cores (draconic_rf_storage) and any other
  -- energy storage peripheral. Input / output panels, rotating core matrix, tier selector and total storage bar.
  local app = { id = "energy", title = "Energy Core", glyph = " E ", icon = "yel", fg = "sp0", cat = "Mods",
    w = 64, h = 21, single = true, minw = 44, minh = 12, startMax = true, fullH = true }

  -- Draconic Evolution energy core tiers (RF capacity)
  local TIERS = { 9.88e6, 59.28e6, 273.6e6, 1.03e9, 3.38e9, 9.88e9, 27.3e9, 2.14e12 }
  local function tierOf(cap)
    if type(cap) ~= "number" or cap <= 0 then return nil end
    for t, c in ipairs(TIERS) do if math.abs(cap / c - 1) < 0.04 then return t end end
    if cap >= 9e18 then return 9 end -- unlimited / modified cores
    return 0
  end
  local function tierLabel(t)
    if t == nil then return "-" elseif t == 9 then return "MAX" elseif t == 0 then return "CUSTOM" end
    return "TIER " .. t
  end

  local HIST = 60
  local function demoCap(t) return TIERS[t] or TIERS[8] end

  local function call(name, m, ...)
    local ok, r = pcall(OS.P.call, name, m, ...)
    if ok then return r end
  end

  local function commas(n)
    if type(n) ~= "number" then return "-" end
    local neg = n < 0
    local s = string.format("%.0f", math.abs(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return (neg and "-" or "") .. out
  end
  local function short(n)
    if type(n) ~= "number" then return "-" end
    local a = math.abs(n)
    for _, u in ipairs({ { 1e18, "Q" }, { 1e15, "P" }, { 1e12, "T" }, { 1e9, "G" }, { 1e6, "M" }, { 1e3, "k" } }) do
      if a >= u[1] then return string.format("%.2f%s", n / u[1], u[2]) end
    end
    return string.format("%d", math.floor(n))
  end
  local function eta(secs)
    if not secs or secs ~= secs or secs == math.huge or secs < 0 then return "-" end
    if secs > 86400 * 99 then return ">99d" end
    local d, h, m = math.floor(secs / 86400), math.floor(secs / 3600) % 24, math.floor(secs / 60) % 60
    if d > 0 then return d .. "d " .. h .. "h" end
    if h > 0 then return h .. "h " .. m .. "m" end
    return m .. "m " .. math.floor(secs % 60) .. "s"
  end

  local function scan(s)
    local devs = {}
    for _, n in ipairs(OS.P.names()) do
      local ok, methods = pcall(OS.P.getMethods, n)
      if ok and methods then
        local set = {}
        for _, m in ipairs(methods) do set[m] = true end
        local t = OS.P.getType(n) or ""
        local d
        if set.getEnergyStored and set.getMaxEnergyStored then d = { get = "getEnergyStored", max = "getMaxEnergyStored" }
        elseif set.getEnergy and set.getEnergyCapacity then d = { get = "getEnergy", max = "getEnergyCapacity" }
        elseif set.getEnergy and set.getMaxEnergy then d = { get = "getEnergy", max = "getMaxEnergy" } end
        if d then
          d.name, d.type = n, t
          d.draconic = t:lower():find("draconic") ~= nil
          d.transfer = set.getTransferPerTick and "getTransferPerTick" or nil
          devs[#devs + 1] = d
        end
      end
    end
    s.devs = devs
  end

  local function poll(s)
    local last = os.clock()
    while s.alive do
      local now = os.clock()
      local dt = now - last
      last = now
      if s.demo then
        local sim = s.sim
        sim.stored = math.max(0, math.min(sim.cap, sim.stored + (sim.inR - sim.outR) * 20 * dt))
        s.view = { stored = sim.stored, cap = sim.cap, inR = sim.inR, outR = sim.outR, name = "simulation", live = false }
        local h = s.hist
        h[#h + 1] = sim.stored / sim.cap
      else
        scan(s)
        if s.sel > #s.devs then s.sel = math.max(1, #s.devs) end
        local d = s.devs[s.sel]
        if d then
          local e, cap = call(d.name, d.get), call(d.name, d.max)
          if type(e) == "number" then
            local prev = s.prev
            local rate = 0
            if prev and prev.name == d.name and now - prev.t > 0.2 then rate = (e - prev.e) / ((now - prev.t) * 20) end
            s.prev = { name = d.name, e = e, t = now }
            s.view = { stored = e, cap = cap or 0, inR = math.max(rate, 0), outR = math.max(-rate, 0), name = d.name,
              live = true, draconic = d.draconic, xfer = d.transfer and call(d.name, d.transfer) or nil }
            local h = s.hist
            h[#h + 1] = (cap and cap > 0) and (e / cap) or 0
          end
        else s.view = nil end
      end
      while #s.hist > HIST do table.remove(s.hist, 1) end
      sleep(0.5)
    end
  end

  local function newSim(tier)
    local cap = demoCap(tier)
    return { tier = tier, cap = cap, stored = cap * 0.458, inR = 500000, outR = 150000 }
  end

  local function anim(win)
    local s = win.state
    if not s or not s.alive then return end
    OS.timer(0.3, function() anim(win) end)
  end

  function app.init(win)
    local s = { alive = true, devs = {}, sel = 1, demo = false, hist = {}, sim = newSim(6) }
    win.state = s
    s.poller = OS.async(function() poll(s) end)
    OS.timer(0.3, function() anim(win) end)
  end
  function app.close(win)
    local s = win.state; s.alive = false; if s.poller then s.poller.stop = true end
  end

  -- ------------------------------------------------------------ drawing helpers
  local function panel(g, x, y, w, h)
    g.fill(x, y, w, h, C.bar)
    g.put(x, y, "+", C.acc, C.bar); g.put(x + w - 1, y, "+", C.acc, C.bar)
    g.put(x, y + h - 1, "+", C.acc, C.bar); g.put(x + w - 1, y + h - 1, "+", C.acc, C.bar)
  end
  local function badge(g, x, y, text, col)
    g.put(x, y, " " .. text .. " ", col, C.dock)
    return #text + 2
  end
  local function segBar(g, x, y, w, ratio, col)
    ratio = math.max(0, math.min(1, ratio))
    local f = math.floor(ratio * w + 0.5)
    for i = 0, w - 1 do
      local on = i < f
      g.put(x + i, y, (i % 2 == 0) and "=" or " ", on and col or C.sp2, C.bar)
    end
  end
  local function sliderBlock(g, x, y, w, label, val, vmax, col, fn)
    g.put(x, y, label, C.sub, C.bar)
    local vt = commas(val) .. " RF/t"
    g.put(x + w - #vt, y, vt, col, C.bar)
    g.slider(x, y + 1, w, val / vmax, function(f) fn(math.floor(f * vmax / 1000 + 0.5) * 1000) end, col, C.sp2)
    g.put(x, y + 2, "0", C.sub, C.bar)
    g.put(x + math.floor(w / 2) - 2, y + 2, "2.5M", C.sub, C.bar)
    g.put(x + w - 9, y + 2, "5.0M RF/t", C.sub, C.bar)
  end

  local function flow(g, s, v, x, y, w, h, isIn)
    local col = isIn and C.grn or C.red
    panel(g, x, y, w, h)
    local tight = h < 5
    local ty = tight and y or y + 1
    g.put(x + 2, ty, OS.trunc(isIn and "ENTERING ENERGY" or "EXITING ENERGY", w - 12), C.text, C.bar)
    local tag = isIn and "INPUT" or "OUTPUT"
    if w >= 26 then badge(g, x + w - #tag - 3, ty, tag, col) end
    local val = v and (isIn and v.inR or v.outR) or 0
    g.put(x + 2, ty + 1, OS.trunc((isIn and "+" or "-") .. commas(val), w - 4), col, C.bar)
    local by = ty + 2
    if not tight then g.put(x + 2, ty + 2, "RF / tick", C.sub, C.bar); by = ty + 3 end
    local scale = (s.demo and 5e6) or math.max(v and v.xfer or 0, val, 1)
    segBar(g, x + 2, by, w - 4, val / scale, col)
    if s.demo and h >= 11 then
      sliderBlock(g, x + 2, y + h - 4, w - 4, "SIMULATE " .. (isIn and "INPUT" or "OUTPUT") .. " RATE",
        val, 5e6, col, function(n) if isIn then s.sim.inR = n else s.sim.outR = n end end)
    end
  end

  local function netPanel(g, s, v, x, y, w, h)
    panel(g, x, y, w, h)
    local tight = h < 4
    local ty = tight and y or y + 1
    g.put(x + 2, ty, "NET TRANSFER RATE", C.sub, C.bar)
    local net = v and (v.inR - v.outR) or 0
    local col = net > 0 and C.grn or (net < 0 and C.red or C.text)
    g.put(x + 2, ty + 1, OS.trunc((net >= 0 and "+" or "") .. commas(net) .. " RF/t", w - 4), col, C.bar)
    if not tight then
      local st = (net > 0 and "Core Charging") or (net < 0 and "Core Draining") or "Core Idle"
      g.put(x + 2, ty + 2, "o", col, C.bar)
      g.put(x + 4, ty + 2, OS.trunc(st, w - 6), C.sub, C.bar)
    end
  end

  local function statePanel(g, s, v, x, y, w, h)
    panel(g, x, y, w, h)
    local ty = h < 4 and y or y + 1
    g.put(x + 2, ty, "CORE CHARGE STATE", C.sub, C.bar)
    if s.demo then
      local bw = math.max(4, math.floor((w - 6) / 3))
      for i, pct in ipairs({ 0, 50, 100 }) do
        g.btn(x + 1 + (i - 1) * (bw + 1), math.min(ty + 2, y + h - 1), pct .. "%", function() s.sim.stored = s.sim.cap * pct / 100 end, "dark")
      end
    else
      local ratio = v and v.cap > 0 and v.stored / v.cap or 0
      g.put(x + 2, ty + 1, string.format("%.1f%% full", ratio * 100), C.text, C.bar)
      if h >= 5 and v then
        local net = v.inR - v.outR
        local t = net > 0 and ("Full in " .. eta((v.cap - v.stored) / (net * 20))) or (net < 0 and ("Empty in " .. eta(v.stored / (-net * 20))) or "Stable")
        g.put(x + 2, ty + 2, OS.trunc(t, w - 4), C.sub, C.bar)
      end
    end
  end

  local function sphere(g, cx, cy, rx, ry, ratio, t)
    local a, tilt = t * 0.5, 0.45
    local ca, sa, ct, st = math.cos(a), math.sin(a), math.cos(tilt), math.sin(tilt)
    local front, back = {}, {}
    local function pt(lat, lon, r)
      local x, y, z = r * math.cos(lat) * math.cos(lon), r * math.sin(lat), r * math.cos(lat) * math.sin(lon)
      local x2, z2 = x * ca + z * sa, -x * sa + z * ca
      local y3, z3 = y * ct - z2 * st, y * st + z2 * ct
      local px, py = cx + math.floor(x2 * rx + 0.5), cy + math.floor(y3 * ry + 0.5)
      local list = z3 >= 0 and front or back
      list[#list + 1] = { px, py }
    end
    local function shell(r)
      local nl = ry >= 10 and 5 or 3
      local nm = ry >= 10 and 8 or 5
      local stepsLon = math.max(36, rx * 5)
      local stepsLat = math.max(24, ry * 5)
      for i = -nl, nl do
        local lat = i * (math.pi / 2) / (nl + 1)
        for k = 0, stepsLon - 1 do pt(lat, k * 2 * math.pi / stepsLon, r) end
      end
      for j = 0, nm - 1 do
        local lon = j * math.pi / nm
        for k = 0, stepsLat do pt(-math.pi / 2 + k * math.pi / stepsLat, lon, r) end
        for k = 0, stepsLat do pt(-math.pi / 2 + k * math.pi / stepsLat, lon + math.pi, r) end
      end
    end
    shell(1)
    for _, p in ipairs(back) do g.put(p[1], p[2], ".", C.sp2, C.bar) end
    for _, p in ipairs(front) do g.put(p[1], p[2], "*", C.acc, C.bar) end
    front, back = {}, {}
    local r2 = 0.25 + 0.4 * math.max(0, math.min(1, ratio))
    shell(r2)
    for _, p in ipairs(front) do g.put(p[1], p[2], "+", C.yel, C.bar) end
  end

  local function center(g, s, v, x, y, w, h)
    panel(g, x, y, w, h)
    local ratio = v and v.cap > 0 and math.min(1, v.stored / v.cap) or 0
    local stab = s.demo and "CORE STABILITY: 100%" or (v and ("LINK: ACTIVE  " .. OS.trunc(v.name, math.max(4, w - 30))) or "LINK: NO CORE")
    g.put(x + 2, y + 1, OS.trunc(stab, w - 4), v and C.grn or C.red, C.bar)
    local sy = y + 2
    local footer = (h >= 9) and 3 or 1
    local sh = h - 2 - footer
    if sh >= 3 then
      -- a text cell is about 1.5x taller than wide, so a circle needs rx = 1.5 * ry; fit it inside the panel
      local ry = math.max(1, math.min(math.floor((sh - 1) / 2), math.floor(((w - 4) / 2) / 1.5)))
      local rx = math.floor(ry * 1.5 + 0.5)
      local cxm, cym = x + math.floor(w / 2), sy + math.floor(sh / 2)
      for i = 1, 8 do
        local k = math.floor(os.clock() * 2)
        local px = x + 1 + (i * 7919 + k * 31 * i) % (w - 2)
        local py = sy + (i * 104729 + k * 17) % sh
        g.put(px, py, ".", C.acc, C.bar)
      end
      sphere(g, cxm, cym, rx, ry, ratio, os.clock())
    end
    local pct = string.format("%.2f%% CAPACITY", ratio * 100)
    g.put(x + math.floor((w - #pct) / 2), y + h - footer - (footer > 1 and 0 or 1) + 0, pct, C.wht, C.dock)
    if footer >= 3 then
      local ty = y + h - 2
      local cur = s.demo and s.sim.tier or tierOf(v and v.cap)
      g.put(x + 2, ty, "TIER", C.sub, C.bar)
      if w - 10 >= 8 * 5 then
        local bx = x + 8
        for t = 1, 8 do
          local on = cur == t
          local lab = "T" .. t
          if s.demo then
            bx = bx + g.btn(bx, ty, lab, function() local ns = newSim(t); ns.inR, ns.outR = s.sim.inR, s.sim.outR; s.sim = ns end, on and "pri" or "dark") + 1
          else
            g.put(bx, ty, " " .. lab .. " ", on and C.wht or C.sub, on and C.acc or C.dock)
            bx = bx + #lab + 3
          end
        end
        if not s.demo and (cur == 9 or cur == 0) then g.put(bx, ty, tierLabel(cur), C.acc, C.bar) end
      else
        local lab = tierLabel(cur)
        if s.demo then
          g.btn(x + 8, ty, lab .. " >", function() local t = (s.sim.tier % 8) + 1; local ns = newSim(t); ns.inR, ns.outR = s.sim.inR, s.sim.outR; s.sim = ns end, "pri")
        else g.put(x + 8, ty, lab, C.acc, C.bar) end
      end
    end
  end

  local function bottom(g, s, v, x, y, w, h)
    panel(g, x, y, w, h)
    local stored, cap = v and v.stored or 0, v and v.cap or 0
    local ratio = cap > 0 and math.min(1, stored / cap) or 0
    g.put(x + 2, y + 1, "TOTAL ENERGY STORAGE CAPACITY", C.text, C.bar)
    local nums = commas(stored) .. " / " .. commas(cap) .. " RF"
    if #nums + 34 < w then g.put(x + w - #nums - 2, y + 1, nums, C.acc, C.bar) end
    local by = y + h - 2
    if h >= 5 then g.put(x + 2, y + 2, "Real-time Energy Field Matrix Status", C.sub, C.bar) end
    local bw = w - 4
    local f = math.floor(ratio * bw + 0.5)
    local lab = string.format("%.2f%% STORED (%s RF)", ratio * 100, short(stored))
    local lx = math.floor((bw - #lab) / 2) + 1
    for i = 1, bw do
      local ch = (i >= lx and i < lx + #lab) and lab:sub(i - lx + 1, i - lx + 1) or " "
      local on = i <= f
      local bg = on and ((i > f - 2 and f < bw) and C.yel or C.acc) or C.desk
      g.put(x + 1 + i, by, ch, on and C.sp0 or C.text, bg)
    end
  end

  function app.draw(win, g)
    local s = win.state
    local w, h = g.w, g.h
    g.fill(1, 1, w, h, C.win)
    local v = s.view
    local full = w >= 60 and h >= 17
    local hh = h >= 15 and 3 or 1
    local bh = h >= 17 and 5 or (h >= 13 and 4 or 3)

    -- header
    if hh == 3 then
      panel(g, 1, 1, w, 3)
      g.put(3, 2, " ! ", C.acc, C.dock)
      g.put(7, 2, "DRACONIC ENERGY CORE", C.wht, C.bar)
      badge(g, 28, 2, s.demo and ("TIER " .. s.sim.tier) or (v and tierLabel(tierOf(v.cap)) or "OFFLINE"), C.acc)
    else
      g.fill(1, 1, w, 1, C.bar)
      g.put(2, 1, "DRACONIC ENERGY CORE", C.wht, C.bar)
    end
    -- demo toggle + device cycle
    local ctl = w - 10
    if hh == 3 then
      g.btn(w - 10, 3, s.demo and "Demo:on" or "Demo", function() s.demo = not s.demo; s.hist = {}; s.view = nil; s.prev = nil end, s.demo and "pri" or "dark")
      if not s.demo and #s.devs > 1 then
        g.btn(3, 3, "<", function() s.sel = (s.sel - 2) % #s.devs + 1 end, "dark")
        g.btn(7, 3, ">", function() s.sel = s.sel % #s.devs + 1 end, "dark")
        g.put(11, 3, OS.trunc(s.devs[s.sel] and s.devs[s.sel].name or "", 24), C.sub, C.bar)
      else g.put(7, 3, OS.trunc("MULTI-BLOCK FLUX STORAGE MATRIX - " .. (v and "ACTIVE" or "OFFLINE"), math.max(8, w - 28)), C.sub, C.bar) end
    else
      g.btn(w - 10, 1, s.demo and "Demo:on" or "Demo", function() s.demo = not s.demo; s.hist = {}; s.view = nil; s.prev = nil end, s.demo and "pri" or "dark")
    end

    local my, mh = hh + 1, h - hh - bh
    if not v then
      g.fill(1, my, w, mh, C.win)
      g.put(3, my + 1, "No energy storage found.", C.text, C.win)
      local help = { "Connect a Draconic Evolution Energy Core (energy", "peripheral) or any energy storage block via", "a wired modem, then reopen this app.", "", "Press Demo to preview the dashboard." }
      for i, l in ipairs(help) do if my + 2 + i <= h - bh then g.put(3, my + 2 + i, OS.trunc(l, w - 4), C.sub, C.win) end end
    elseif full then
      local lw = math.max(22, math.floor(w * 0.27))
      local cw = w - lw * 2
      local topH = math.floor(mh * 0.68)
      flow(g, s, v, 1, my, lw, topH, true)
      netPanel(g, s, v, 1, my + topH, lw, mh - topH)
      center(g, s, v, lw + 1, my, cw, mh)
      flow(g, s, v, lw + cw + 1, my, lw, topH, false)
      statePanel(g, s, v, lw + cw + 1, my + topH, lw, mh - topH)
    else
      local cw = math.floor(w * 0.5)
      center(g, s, v, 1, my, cw, mh)
      local rw = w - cw
      local ph = math.floor(mh / 3)
      flow(g, s, v, cw + 1, my, rw, ph, true)
      flow(g, s, v, cw + 1, my + ph, rw, ph, false)
      netPanel(g, s, v, cw + 1, my + ph * 2, rw, mh - ph * 2)
    end
    bottom(g, s, v, 1, h - bh + 1, w, bh)
  end

  return app
end

end)()
EMBED["wifi"] = (function()
return function(OS)
  local C = OS.C
  local cfg = OS.cfg
  -- Wi-Fi: finds other Windows 10 computers through wireless modems placed in the world (like Wi-Fi / Bluetooth).
  -- One computer turns on a Hotspot; others scan, pick it, enter the password and connect, then can chat/ping.
  local app = { id = "wifi", title = "Wi-Fi", glyph = " ) ", icon = "acc", fg = "wht", single = true,
    w = 58, h = 18, minw = 50, minh = 13 }
  local CH = 4242
  local PROTO = "fedora-wifi"
  local myId = os.getComputerID()
  local REPLY = 10000 + (myId % 50000)

  cfg.wifi = cfg.wifi or {}
  local wc = cfg.wifi
  if wc.on == nil then wc.on = true end
  wc.ap = wc.ap or { on = false, ssid = "CC-" .. myId, pass = "" }
  wc.known = wc.known or {}
  if wc.auto == nil then wc.auto = true end
  wc.name = wc.name or (os.getComputerLabel() or ("computer-" .. myId))

  local W = { nets = {}, clients = {}, inbox = {}, modems = {}, conn = nil, conns = {}, pends = {}, rcache = {},
    status = "Idle", scanAt = 0, reqs = {} }
  OS.wifi = W

  local function pwHash(ssid, pass) return OS.sha256(ssid .. "\0" .. pass) end

  local function scanModems()
    local list = {}
    for _, n in ipairs(peripheral.getNames()) do
      if peripheral.getType(n) == "modem" then
        local okW, wl = pcall(peripheral.call, n, "isWireless")
        list[#list + 1] = { name = n, wireless = okW and wl or false }
      end
    end
    W.modems = list
    for _, m in ipairs(list) do
      if m.wireless then
        pcall(peripheral.call, m.name, "open", CH)
        pcall(peripheral.call, m.name, "open", REPLY)
      end
    end
  end

  local function tx(ch, msg)
    msg.proto, msg.id, msg.label = PROTO, myId, wc.name
    local sent = false
    for _, m in ipairs(W.modems) do
      if m.wireless then
        if pcall(peripheral.call, m.name, "transmit", ch, REPLY, msg) then sent = true end
      end
    end
    return sent
  end
  W.tx = tx

  -- several hotspots can be connected at once: W.conns[apId] = connection; W.conn = the first one
  function W.connList()
    local list = {}
    for id, c in pairs(W.conns) do list[#list + 1] = c end
    table.sort(list, function(a, b) return a.since < b.since end)
    return list
  end
  local function sync()
    W.conn = W.connList()[1]
  end
  local function ssidSet()
    local set, order = {}, {}
    for _, c in ipairs(W.connList()) do if not set[c.ssid] then set[c.ssid] = true; order[#order + 1] = c.ssid end end
    if wc.ap.on and not set[wc.ap.ssid] then set[wc.ap.ssid] = true; order[#order + 1] = wc.ap.ssid end
    return set, order
  end

  function W.available()
    for _, m in ipairs(W.modems) do if m.wireless then return true end end
    return false
  end
  function W.scan() W.scanAt = os.clock(); return tx(CH, { t = "probe" }) end
  function W.connect(net, pass, hash)
    if not net or W.conns[net.id] then return end
    local h = hash or pwHash(net.ssid, pass or "")
    W.status = "Connecting to " .. net.ssid .. "..."
    W.pends[net.id] = { net = net, hash = h, at = os.clock() }
    if not hash and wc.known[net.ssid] then wc.known[net.ssid].bad = nil end
    tx(net.reply or CH, { t = "auth", ssid = net.ssid, hash = h, to = net.id })
  end
  function W.disconnect(apId)
    for id, c in pairs(W.conns) do
      if not apId or apId == id then
        tx(c.reply or CH, { t = "bye", ssid = c.ssid, to = id })
        W.conns[id] = nil; W.rcache[id] = nil
      end
    end
    sync(); W.status = "Disconnected"
  end
  function W.send(text)
    local _, order = ssidSet()
    if #order == 0 then return false, "Not connected" end
    W.inbox[#W.inbox + 1] = { from = "me", text = text }
    local ok = false
    for _, ssid in ipairs(order) do ok = tx(CH, { t = "msg", ssid = ssid, text = text }) or ok end
    return ok
  end
  function W.ping()
    local _, order = ssidSet()
    W.pingAt = os.clock()
    for _, ssid in ipairs(order) do tx(CH, { t = "ping", ssid = ssid }) end
  end
  local rid = 0
  function W.request(kind, extra, cb, apId)
    local c = apId and W.conns[apId] or W.conn
    if not c then cb(false, "Not connected to a hotspot"); return end
    rid = rid + 1
    extra.t, extra.ssid, extra.rid, extra.to = kind, c.ssid, rid, c.ap
    W.reqs[rid] = { cb = cb, at = os.clock() }
    if not tx(c.reply or CH, extra) then W.reqs[rid] = nil; cb(false, "No wireless modem") end
  end
  -- turn any value into something a modem message can carry
  local function clean(v, depth)
    local t = type(v)
    if t == "table" then
      if (depth or 0) > 4 then return "<table>" end
      local out, n = {}, 0
      for k, x in pairs(v) do
        n = n + 1
        if n > 600 then break end
        out[type(k) == "number" and k or tostring(k)] = clean(x, (depth or 0) + 1)
      end
      return out
    elseif t == "string" or t == "number" or t == "boolean" or t == "nil" then return v end
    return tostring(v)
  end
  -- Unified peripheral layer: local peripherals plus the ones shared by every hotspot we are connected to
  -- (named "wifi:<hotspot id>/<name>"). Other apps use OS.P instead of the peripheral API so they work over Wi-Fi too.
  local function parseRemote(n)
    if type(n) ~= "string" then return nil end
    local id, nm = n:match("^wifi:(%d+)/(.+)$")
    if id then return tonumber(id), nm end
  end
  local function isRemote(n) return parseRemote(n) ~= nil end
  -- "!chain": call a method that returns an object, then call members of that object (e.g. battery().stored()). Objects can't
  -- travel over Wi-Fi, so the hotspot walks the chain itself and only sends back the final value.
  local function runChain(name, steps)
    local obj
    for i, st in ipairs(steps or {}) do
      local a = st.a or {}
      if i == 1 then obj = peripheral.call(name, st.m, table.unpack(a))
      else
        if type(obj) ~= "table" or type(obj[st.m]) ~= "function" then error("no member " .. tostring(st.m), 0) end
        obj = obj[st.m](table.unpack(a))
      end
    end
    return obj
  end
  local function async() return OS.asyncSet and OS.asyncSet[coroutine.running()] end
  local function blocking(kind, extra, apId)
    local done, ok, data
    W.request(kind, extra, function(o, d) ok, data, done = o, d, true end, apId)
    local t = os.clock()
    while not done and os.clock() - t < 8 do sleep(0.05) end
    return ok, data
  end
  -- what a connected hotspot offers, grouped by the app that can use it
  local KINDS = {
    { key = "energy", label = "Energy core", app = "energy", match = function(t) return t:find("draconic") or t:find("energy") or t:find("battery") or t:find("cell") or t:find("induction") end },
    { key = "reactor", label = "Reactor/turbine", app = "reactor", match = function(t) return t:find("reactor") or t:find("turbine") end },
    { key = "mekanism", label = "Mekanism", app = "mekanism", match = function(t) return t:find("fissionreactorlogic") or t:find("fusionreactorlogic") or t:find("inductionport") or t:find("turbinevalve") or t:find("boilervalve") or t:find("energycube") end },
    { key = "storage", label = "Refined Storage", app = "storage", match = function(t) return t:find("rsbridge") or t:find("rs_bridge") end },
  }
  function W.remoteSummary(apId)
    local out = {}
    local rc = W.rcache[apId or (W.conn and W.conn.ap)]
    if not rc then return out end
    for _, k in ipairs(KINDS) do
      local n = 0
      for _, d in ipairs(rc.list) do
        local t = tostring(d[2]):lower()
        if t ~= "modem" and k.match(t) then n = n + 1 end
      end
      if n > 0 then out[#out + 1] = { label = k.label, n = n, app = k.app } end
    end
    return out
  end
  function W.refreshRemote(apId)
    local c = W.conns[apId]
    if not c then return end
    W.rcache[apId] = W.rcache[apId] or { list = {}, meth = {} }
    W.request("plist", {}, function(ok, data)
      if ok and type(data) == "table" and W.conns[apId] then
        local rc = W.rcache[apId]
        rc.list = data
        local parts = {}
        for _, it in ipairs(W.remoteSummary(apId)) do parts[#parts + 1] = it.n .. "x " .. it.label end
        local text = table.concat(parts, ", ")
        if text ~= rc.summary then
          rc.summary = text
          if text ~= "" then OS.toast(c.ssid .. " shares: " .. text, 6); OS.sfx("toast") end
        end
      end
    end, apId)
  end
  OS.P = {}
  function OS.P.names()
    local out = {}
    for _, n in ipairs(peripheral.getNames()) do out[#out + 1] = n end
    for _, c in ipairs(W.connList()) do
      local rc = W.rcache[c.ap]
      if rc then for _, d in ipairs(rc.list) do out[#out + 1] = "wifi:" .. c.ap .. "/" .. d[1] end end
    end
    return out
  end
  function OS.P.getType(n)
    local id, nm = parseRemote(n)
    if id then
      local rc = W.rcache[id]
      if rc then for _, d in ipairs(rc.list) do if d[1] == nm then return d[2] end end end
      return nil
    end
    return peripheral.getType(n)
  end
  function OS.P.getMethods(n)
    local id, nm = parseRemote(n)
    if not id then return peripheral.getMethods(n) end
    local rc = W.rcache[id]
    if not rc then return {} end
    local m = rc.meth[nm]
    if m then return m end
    if not async() then return {} end
    local ok, data = blocking("pmeth", { name = nm }, id)
    if ok and type(data) == "table" then rc.meth[nm] = data; return data end
    error(tostring(data), 0)
  end
  function OS.P.call(n, method, ...)
    local id, nm = parseRemote(n)
    if not id then
      if method == "!chain" then return runChain(n, (...)) end
      return peripheral.call(n, method, ...)
    end
    local args = { ... }
    if not async() then
      W.request("pcall", { name = nm, method = method, args = args }, function() end, id)
      return nil
    end
    local ok, data = blocking("pcall", { name = nm, method = method, args = args }, id)
    if not ok then error(tostring(data), 0) end
    return table.unpack(data, 1, #data)
  end
  function OS.P.isRemote(n) return isRemote(n) end

  function W.label()
    local list = W.connList()
    if #list > 1 then return "WiFi x" .. #list end
    if list[1] then return "WiFi " .. list[1].ssid end
    if wc.ap.on then return "AP " .. wc.ap.ssid end
  end

  local function onMessage(side, ch, reply, msg, dist)
    if type(msg) ~= "table" or (msg.proto ~= PROTO and msg.proto ~= "win10-wifi") or msg.id == myId then return end
    local t = msg.t
    if t == "probe" and wc.on and wc.ap.on then
      tx(reply, { t = "beacon", ssid = wc.ap.ssid, sec = wc.ap.pass ~= "" })
    elseif t == "beacon" and wc.on then
      W.nets[msg.ssid .. ":" .. msg.id] = { ssid = msg.ssid, sec = msg.sec, id = msg.id, label = msg.label, dist = dist, reply = reply, seen = os.clock() }
    elseif t == "auth" and wc.on and wc.ap.on and msg.ssid == wc.ap.ssid and (msg.to == nil or msg.to == myId) then
      if wc.ap.pass == "" or msg.hash == pwHash(wc.ap.ssid, wc.ap.pass) then
        W.clients[msg.id] = { label = msg.label, dist = dist, seen = os.clock() }
        tx(reply, { t = "authok", ssid = wc.ap.ssid })
        W.inbox[#W.inbox + 1] = { from = "system", text = tostring(msg.label) .. " joined" }
        OS.sfx("toast")
      else tx(reply, { t = "authfail", ssid = wc.ap.ssid }) end
    elseif t == "authok" and W.pends[msg.id] and W.pends[msg.id].net.ssid == msg.ssid then
      local p = W.pends[msg.id]
      W.conns[msg.id] = { ssid = msg.ssid, ap = msg.id, apLabel = msg.label, dist = dist, since = os.clock(), seen = os.clock(), reply = reply }
      wc.known[msg.ssid] = { hash = p.hash }; OS.dirty = true
      W.pends[msg.id] = nil; sync(); W.status = "Connected to " .. msg.ssid
      wc.last = { ssid = msg.ssid }
      OS.sfx("toast"); OS.toast("Wi-Fi connected: " .. msg.ssid)
      W.rcache[msg.id] = { list = {}, meth = {} }; W.refreshRemote(msg.id)
    elseif t == "authfail" and W.pends[msg.id] and W.pends[msg.id].net.ssid == msg.ssid then
      if wc.known[msg.ssid] then wc.known[msg.ssid].bad = true end
      W.pends[msg.id] = nil; W.status = "Wrong password for " .. msg.ssid; OS.sfx("error")
    elseif t == "bye" and wc.ap.on and W.clients[msg.id] then
      W.clients[msg.id] = nil
    elseif t == "plist" or t == "pmeth" or t == "pcall" then
      if wc.on and wc.ap.on and (wc.share == true or (wc.share == nil and wc.ap.pass ~= "")) and W.clients[msg.id] and msg.ssid == wc.ap.ssid and (msg.to == nil or msg.to == myId) then
        W.clients[msg.id].seen = os.clock()
        local res = { t = "presp", ssid = wc.ap.ssid, rid = msg.rid, to = msg.id }
        if t == "plist" then
          local list = {}
          for _, n in ipairs(peripheral.getNames()) do list[#list + 1] = { n, peripheral.getType(n) or "?" } end
          res.ok, res.data = true, list
        elseif t == "pmeth" then
          local ok, m = pcall(peripheral.getMethods, tostring(msg.name))
          res.ok, res.data = ok, ok and m or tostring(m)
        else
          local r
          if msg.method == "!chain" then r = table.pack(pcall(runChain, tostring(msg.name), (msg.args or {})[1]))
          else r = table.pack(pcall(peripheral.call, tostring(msg.name), tostring(msg.method), table.unpack(msg.args or {}))) end
          res.ok = r[1]
          res.data = clean({ table.unpack(r, 2, r.n) })
        end
        tx(reply, res)
      end
    elseif t == "presp" and msg.to == myId then
      local r = W.reqs[msg.rid]
      if r then W.reqs[msg.rid] = nil; r.cb(msg.ok, msg.data) end
    elseif t == "msg" then
      local set = ssidSet()
      if set[msg.ssid] then
        W.inbox[#W.inbox + 1] = { from = (msg.label or ("#" .. msg.id)) .. " @" .. tostring(msg.ssid), text = tostring(msg.text), dist = dist }
        while #W.inbox > 100 do table.remove(W.inbox, 1) end
        OS.sfx("toast")
      end
    elseif t == "ping" then
      local set = ssidSet()
      if set[msg.ssid] then tx(reply, { t = "pong", ssid = msg.ssid }) end
    elseif t == "pong" and W.pingAt then
      W.inbox[#W.inbox + 1] = { from = "system", text = string.format("pong from %s: %d blocks, %d ms", tostring(msg.label), math.floor(dist or 0), math.floor((os.clock() - W.pingAt) * 1000)) }
    end
    local c = W.conns[msg.id]
    if c then c.dist = dist; c.seen = os.clock() end
  end

  -- background service
  OS.async(function()
    scanModems()
    local timer = os.startTimer(1)
    local n = 0
    while true do
      local ev = { os.pullEvent() }
      if ev[1] == "modem_message" then pcall(onMessage, ev[2], ev[3], ev[4], ev[5], ev[6])
      elseif ev[1] == "peripheral" or ev[1] == "peripheral_detach" then scanModems()
      elseif ev[1] == "timer" and ev[2] == timer then
        timer = os.startTimer(1)
        n = n + 1
        local now = os.clock()
        for k, v in pairs(W.nets) do if now - v.seen > 20 then W.nets[k] = nil end end
        for k, v in pairs(W.clients) do if now - v.seen > 120 then W.clients[k] = nil end end
        for k, r in pairs(W.reqs) do if now - r.at > 6 then W.reqs[k] = nil; r.cb(false, "timeout") end end
        if n % 5 == 1 then for id in pairs(W.conns) do W.refreshRemote(id) end end
        for id, p in pairs(W.pends) do if now - p.at > 6 then W.pends[id] = nil; W.status = "No answer from " .. p.net.ssid end end
        if wc.on and wc.auto and next(W.pends) == nil then
          for _, net in pairs(W.nets) do
            local k = wc.known[net.ssid]
            if k and not k.bad and not W.conns[net.id] then W.status = "Auto-connecting to " .. net.ssid .. "..."; W.connect(net, nil, k.hash); break end
          end
        end
        if wc.on and n % 6 == 0 and W.available() then W.scan() end
        for id, c in pairs(W.conns) do
          if now - c.seen > 60 then W.conns[id] = nil; W.rcache[id] = nil; sync(); W.status = "Lost " .. c.ssid end
        end
      end
    end
  end)

  local function bars(dist)
    local d = dist or 999
    local n = d < 24 and 4 or (d < 48 and 3 or (d < 80 and 2 or 1))
    return ("#"):rep(n) .. ("-"):rep(4 - n)
  end

  function app.init(win)
    win.state = { tab = 1, sel = nil, pass = OS.field("", { mask = true, placeholder = "Password" }),
      ssid = OS.field(wc.ap.ssid, {}), appass = OS.field(wc.ap.pass, {}), chat = OS.field("", { placeholder = "Message..." }), top = 0,
      dv = { mode = "local", sel = nil, mtop = 0, ltop = 0, args = OS.field("", { placeholder = "args: 1, \"text\", true" }), result = "" } }
    local s = win.state
    s.chat.onEnter = function() if #s.chat.text > 0 then W.send(s.chat.text); s.chat.text = ""; s.chat.pos = 0 end end
    scanModems()
    W.scan()
  end

  function app.draw(win, g)
    local s = win.state
    local w, h = g.w, g.h
    g.fill(1, 1, w, h, C.win)
    g.put(2, 1, "Wi-Fi", C.text, C.win)
    g.toggle(10, 1, wc.on, function() wc.on = not wc.on; OS.dirty = true; if not wc.on then W.disconnect() end end)
    g.put(17, 1, OS.trunc(W.status, w - 32), C.sub, C.win)
    g.put(w - 13, 1, "Auto", C.sub, C.win)
    g.toggle(w - 8, 1, wc.auto, function() wc.auto = not wc.auto; OS.dirty = true end)
    local x = 2
    for i, n in ipairs({ "Networks", "Hotspot", "Chat", "Devices", "Modems" }) do
      x = x + g.btn(x, 2, n, function() s.tab = i end, s.tab == i and "pri" or nil) + 1
    end
    local y0 = 4
    if not W.available() and s.tab <= 3 then
      g.put(2, y0, "No wireless modem found.", C.red, C.win)
      g.put(2, y0 + 1, "Attach a Wireless Modem to this computer (a side", C.sub, C.win)
      g.put(2, y0 + 2, "or via the Modems tab) and it appears here.", C.sub, C.win)
      return
    end
    if s.tab == 1 then
      local cy = y0
      for _, c in ipairs(W.connList()) do
        if cy + 1 > h - 6 then break end
        g.put(2, cy, OS.trunc("Connected: " .. c.ssid, w - 28) .. "  " .. bars(c.dist), C.grn, C.win)
        g.btn(w - 14, cy, "Disconnect", function() W.disconnect(c.ap) end, "danger")
        local sum = W.remoteSummary(c.ap)
        if #sum == 0 then g.put(4, cy + 1, "shares no known devices", C.sub, C.win)
        else
          local sx = 4
          for _, it in ipairs(sum) do
            sx = sx + g.btn(sx, cy + 1, "Open " .. it.label .. " (" .. it.n .. ")", function() OS.open(it.app) end, "dark") + 1
          end
        end
        cy = cy + 2
      end
      local list = {}
      for _, n in pairs(W.nets) do list[#list + 1] = n end
      table.sort(list, function(a, b) return (a.dist or 999) < (b.dist or 999) end)
      g.btn(w - 8, 2, "Scan", function() W.scan(); OS.sfx("select") end)
      local ly = cy + 1
      if #list == 0 then g.put(2, ly, "No networks yet - press Scan.", C.sub, C.win) end
      for i, n in ipairs(list) do
        local y = ly + i - 1
        if y > h - 3 then break end
        local on = s.sel == n.ssid .. ":" .. n.id
        g.fill(1, y, w, 1, on and C.acc or C.win)
        g.put(2, y, OS.trunc(n.ssid, w - 32) .. (n.sec and " *" or "") .. (W.conns[n.id] and " [connected]" or (wc.known[n.ssid] and " [saved]" or "")), on and C.wht or C.text, on and C.acc or C.win)
        g.put(w - 20, y, string.format("%s  %3d blk", bars(n.dist), math.floor(n.dist or 0)), on and C.wht or C.sub, on and C.acc or C.win)
        g.hot(1, y, w, 1, function() s.sel = n.ssid .. ":" .. n.id end)
      end
      local sel = s.sel and W.nets[s.sel]
      if sel and W.conns[sel.id] then sel = nil end
      if sel then
        g.put(2, h - 1, "Password", C.sub, C.win)
        g.field(11, h - 1, math.max(10, w - 28), s.pass, { bg = C.bar })
        local k = wc.known[sel.ssid]
        g.btn(w - 12, h - 1, "Connect", function()
          if k and s.pass.text == "" then W.connect(sel, nil, k.hash) else W.connect(sel, s.pass.text) end
          s.pass.text = ""; s.pass.pos = 0
        end, "pri")
        if k then g.btn(2, h, "Forget this network", function() wc.known[sel.ssid] = nil; OS.dirty = true end, "dark") end
      end
    elseif s.tab == 2 then
      g.put(2, y0, "Share a network from this computer", C.sub, C.win)
      g.put(2, y0 + 1, "Hotspot", C.text, C.win)
      g.toggle(14, y0 + 1, wc.ap.on, function() wc.ap.on = not wc.ap.on; OS.dirty = true; if wc.ap.on then OS.toast("Hotspot on: " .. wc.ap.ssid) end end)
      g.put(22, y0 + 1, "Share my devices", C.text, C.win)
      g.toggle(40, y0 + 1, wc.share == true or (wc.share == nil and wc.ap.pass ~= ""), function()
        wc.share = not (wc.share == true or (wc.share == nil and wc.ap.pass ~= "")); OS.dirty = true
      end)
      g.put(2, y0 + 3, "Name", C.sub, C.win)
      g.field(10, y0 + 3, 20, s.ssid, { bg = C.bar })
      g.put(2, y0 + 4, "Password", C.sub, C.win)
      g.field(10, y0 + 4, 20, s.appass, { bg = C.bar })
      g.btn(32, y0 + 3, "Save", function()
        if #s.ssid.text > 0 then wc.ap.ssid = s.ssid.text; wc.ap.pass = s.appass.text; OS.dirty = true; W.clients = {}; OS.toast("Hotspot saved") end
      end, "pri")
      g.put(2, y0 + 6, "Devices connected: " .. (function() local c = 0 for _ in pairs(W.clients) do c = c + 1 end return c end)(), C.text, C.win)
      local yy = y0 + 7
      for id, c in pairs(W.clients) do
        if yy > h - 1 then break end
        g.put(3, yy, OS.trunc(tostring(c.label) .. " (#" .. id .. ")", w - 14) .. "  " .. bars(c.dist), C.sub, C.win)
        yy = yy + 1
      end
      g.put(2, h, "Leave the password empty for an open network.", C.sub, C.win)
    elseif s.tab == 3 then
      local rows = h - 5
      local start = math.max(1, #W.inbox - rows + 1)
      for i = start, #W.inbox do
        local m = W.inbox[i]
        g.put(2, y0 + i - start, OS.trunc("<" .. m.from .. "> " .. m.text, w - 2), m.from == "system" and C.sub or (m.from == "me" and C.acc or C.text), C.win)
      end
      g.btn(2, h - 1, "Ping", function() W.ping() end)
      g.field(10, h - 1, w - 20, s.chat, { bg = C.bar })
      g.btn(w - 8, h - 1, "Send", function() if #s.chat.text > 0 then W.send(s.chat.text); s.chat.text = ""; s.chat.pos = 0 end end, "pri")
    elseif s.tab == 4 then
      local dv = s.dv
      local isRemote = dv.mode == "remote"
      if isRemote and not (dv.ap and W.conns[dv.ap]) then dv.ap = W.conn and W.conn.ap end
      local function parseArgs(txt)
        local a = {}
        for tok in (txt .. ","):gmatch("%s*(.-)%s*,") do
          if tok ~= "" then
            local q = tok:match('^"(.*)"$') or tok:match("^'(.*)'$")
            if q then a[#a + 1] = q
            elseif tok == "true" then a[#a + 1] = true elseif tok == "false" then a[#a + 1] = false
            elseif tonumber(tok) then a[#a + 1] = tonumber(tok) else a[#a + 1] = tok end
          end
        end
        return a
      end
      local function show(ok, data)
        local parts = {}
        if type(data) == "table" then
          for i = 1, #data do
            local v = data[i]
            parts[#parts + 1] = type(v) == "table" and textutils.serialize(v, { compact = true }) or tostring(v)
          end
          if #parts == 0 and next(data) ~= nil then parts[1] = textutils.serialize(data, { compact = true }) end
        else parts[1] = tostring(data) end
        dv.result = (ok and "-> " or "error: ") .. (#parts > 0 and table.concat(parts, ", ") or "(no result)")
      end
      local function loadMethods()
        dv.methods, dv.mtop, dv.msel = nil, 0, nil
        if not dv.sel then return end
        if isRemote then
          W.request("pmeth", { name = dv.sel }, function(ok, data) dv.methods = ok and data or {}; if not ok then show(false, data) end end, dv.ap)
        else
          local ok, m = pcall(peripheral.getMethods, dv.sel)
          dv.methods = ok and m or {}
          table.sort(dv.methods)
        end
      end
      local function refreshRemote()
        dv.rlist = nil
        W.request("plist", {}, function(ok, data) dv.rlist = ok and data or {}; if not ok then show(false, data) end end, dv.ap)
      end
      local bx = 2
      bx = bx + g.btn(bx, y0, "This computer", function() dv.mode = "local"; dv.sel = nil; dv.methods = nil end, not isRemote and "pri" or "dark") + 1
      local conns = W.connList()
      if #conns == 0 then
        bx = bx + g.btn(bx, y0, "Over Wi-Fi", function() dv.mode = "remote"; dv.sel = nil; dv.methods = nil; dv.rlist = nil end, isRemote and "pri" or "dark") + 1
      end
      for _, c in ipairs(conns) do
        local on = isRemote and dv.ap == c.ap
        bx = bx + g.btn(bx, y0, OS.trunc(c.ssid, 10), function() dv.mode = "remote"; dv.ap = c.ap; dv.sel = nil; dv.methods = nil; refreshRemote() end, on and "pri" or "dark") + 1
      end
      if isRemote then g.btn(bx, y0, "Refresh", refreshRemote) end
      local list = {}
      if isRemote then for _, d in ipairs(dv.rlist or {}) do list[#list + 1] = { name = d[1], type = d[2] } end
      else for _, n in ipairs(peripheral.getNames()) do list[#list + 1] = { name = n, type = peripheral.getType(n) or "?" } end end
      local lw = math.floor(w * 0.5) - 2
      local rows = h - y0 - 5
      if isRemote and not W.conn then g.put(2, y0 + 2, "Connect to a hotspot that shares devices.", C.sub, C.win) end
      if isRemote and W.conn and not dv.rlist then g.put(2, y0 + 2, "Asking the hotspot...", C.sub, C.win) end
      if #list == 0 and not isRemote then g.put(2, y0 + 2, "No peripherals. Attach devices, or a wired modem", C.sub, C.win); g.put(2, y0 + 3, "(right-click it to activate the network).", C.sub, C.win) end
      dv.ltop = math.max(0, math.min(dv.ltop, math.max(0, #list - rows)))
      for i = 1, rows do
        local d = list[i + dv.ltop]
        if not d then break end
        local y = y0 + 1 + i
        local on = dv.sel == d.name
        g.fill(1, y, lw + 2, 1, on and C.acc or C.win)
        g.put(2, y, OS.trunc(d.name .. " (" .. d.type .. ")", lw), on and C.wht or C.text, on and C.acc or C.win)
        g.hot(1, y, lw + 2, 1, function() dv.sel = d.name; loadMethods() end)
      end
      g.scroll(1, y0 + 2, lw + 2, rows, function(dir) dv.ltop = math.max(0, dv.ltop + dir) end)
      local mx = lw + 4
      local ms = dv.methods or {}
      dv.mtop = math.max(0, math.min(dv.mtop, math.max(0, #ms - rows)))
      if dv.sel and not dv.methods then g.put(mx, y0 + 2, "Loading...", C.sub, C.win) end
      for i = 1, rows do
        local m = ms[i + dv.mtop]
        if not m then break end
        local y = y0 + 1 + i
        local on = dv.msel == m
        g.fill(mx - 1, y, w - mx + 2, 1, on and C.acc or C.win)
        g.put(mx, y, OS.trunc(m, w - mx), on and C.wht or C.sub, on and C.acc or C.win)
        g.hot(mx - 1, y, w - mx + 2, 1, function() dv.msel = m end)
      end
      g.scroll(mx - 1, y0 + 2, w - mx + 2, rows, function(dir) dv.mtop = math.max(0, dv.mtop + dir) end)
      g.put(2, h - 2, "Args", C.sub, C.win)
      g.field(7, h - 2, w - 22, dv.args, { bg = C.bar })
      g.btn(w - 13, h - 2, "Call", function()
        if not dv.sel or not dv.msel then dv.result = "Pick a device and a method first"; return end
        local args = parseArgs(dv.args.text)
        if isRemote then
          W.request("pcall", { name = dv.sel, method = dv.msel, args = args }, show, dv.ap)
        else
          local r = table.pack(pcall(peripheral.call, dv.sel, dv.msel, table.unpack(args)))
          show(r[1], { table.unpack(r, 2, r.n) })
        end
      end, "pri")
      g.put(2, h - 1, OS.trunc(dv.result, w - 3), dv.result:find("^error") and C.red or C.grn, C.win)
    else
      g.put(2, y0, "Modems on this computer", C.sub, C.win)
      if #W.modems == 0 then g.put(2, y0 + 2, "None. Craft a Wireless Modem and place it next to", C.sub, C.win); g.put(2, y0 + 3, "the computer (or on a wired network).", C.sub, C.win) end
      for i, m in ipairs(W.modems) do
        g.put(2, y0 + 1 + i, OS.trunc(m.name, w - 20) .. (m.wireless and "  wireless" or "  wired (no Wi-Fi)"), m.wireless and C.grn or C.sub, C.win)
      end
      g.btn(2, h - 1, "Rescan", function() scanModems(); W.scan() end)
      g.put(14, h - 1, "Computer name:", C.sub, C.win)
      g.put(29, h - 1, OS.trunc(wc.name, w - 30), C.text, C.win)
    end
  end

  return app
end

end)()
EMBED["updater"] = (function()
return function(OS)
  local C = OS.C
  local cfg = OS.cfg
  -- System Update: install a new startup.lua from a gist link, or browse a GitHub user's gists and update
  -- straight from one of their versions. The old version is kept for rollback.
  local app = { id = "updater", title = "Windows Update", glyph = " U ", icon = "grn", fg = "wht", single = true,
    w = 60, h = 20, minw = 46, minh = 14 }
  local DEFAULT_USER = "darkossbr"
  local DEFAULT_REPO = "github:darkossbr/windows-cc"
  local BUILD_AT = "2026-11-01T22:35:47Z" -- when this copy of the system was built (UTC)

  local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
  -- GitHub sends UTC ("2026-11-01T18:19:00Z"); show it in the computer's local (real life) time
  local function localDate(iso)
    local Y, M, D, h, m, sec = tostring(iso or ""):match("^(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
    if not Y then return tostring(iso or ""):sub(1, 16) end
    Y, M, D = tonumber(Y), tonumber(M), tonumber(D)
    local y = (M <= 2) and (Y - 1) or Y
    local era = math.floor(y / 400)
    local yoe = y - era * 400
    local doy = math.floor((153 * (M + ((M > 2) and -3 or 9)) + 2) / 5) + D - 1
    local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
    local days = era * 146097 + doe - 719468
    local t = days * 86400 + tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(sec)
    local ok, out = pcall(function()
      local d = OS.fromUtc(t)
      return string.format("%04d-%02d-%02d %02d:%02d", d.year, d.month, d.day, d.hour, d.min)
    end)
    return ok and out or tostring(iso):sub(1, 16)
  end

  local function resolve(s)
    s = trim(s)
    if s == "" then return nil end
    local pb = s:match("^pastebin:(%w+)$") or s:match("pastebin%.com/raw/(%w+)") or s:match("pastebin%.com/(%w+)$")
    if pb then return "https://pastebin.com/raw/" .. pb end
    -- GitHub repository: github:user/repo[@branch]  or  https://github.com/user/repo  (reads startup.lua from the branch, main by default)
    local function ghRaw(u, r, b, p) return "https://raw.githubusercontent.com/" .. u .. "/" .. r .. "/" .. ((b and b ~= "") and b or "main") .. "/" .. (p or "startup.lua") end
    local gu, gr, gb = s:match("^github:([%w%-_%.]+)/([%w%-_%.]+)@?([%w%-_%./]*)$")
    if gu then return ghRaw(gu, (gr:gsub("%.git$", "")), gb) end
    local gp
    gu, gr, gb, gp = s:match("^https?://github%.com/([%w%-_%.]+)/([%w%-_%.]+)/blob/([^/]+)/(.+)$")
    if gu then return ghRaw(gu, gr, gb, gp) end
    gu, gr = s:match("^https?://github%.com/([%w%-_%.]+)/([%w%-_%.]+)/?$")
    if gu then return ghRaw(gu, (gr:gsub("%.git$", ""))) end
    if s:find("gist.githubusercontent.com", 1, true) then return s end
    local user, gid = s:match("gist%.github%.com/([%w%-_]+)/(%x+)")
    if not gid then user, gid = s:match("^gist:([%w%-_]+)/(%x+)$") end
    if gid then return "https://gist.githubusercontent.com/" .. user .. "/" .. gid .. "/raw" end
    if s:match("^https?://") then return s end
  end

  local function check(data)
    if not data or #data < 5000 then return nil, "File is too small to be the OS" end
    if data:find("^%s*<") then return nil, "Got a web page, not Lua (use the raw link)" end
    local fn, e = load(data, "=update")
    if not fn then return nil, "Not valid Lua: " .. tostring(e):sub(1, 40) end
    if not data:find("Windows 10", 1, true) or not data:find("OS.apps", 1, true) then return nil, "This doesn't look like a Windows 10 (CC Edition) system file" end
    return true
  end

  local function install(win)
    local s = win.state
    if not s.data then s.msg = "Download first"; return end
    local ok, err = OS.installSystem(s.data)
    if ok then
      if s.meta then cfg.sysId = s.meta.id; cfg.sysWhen = s.meta.when; cfg.sysName = s.meta.name; cfg.sysSize = #s.data
      else cfg.sysId = nil; cfg.sysWhen = nil; cfg.sysName = nil; cfg.sysSize = nil end
      s.msg = "Installed. Restarting..."; s.data = nil
      OS.sfx("boot"); OS.save()
      OS.timer(1.5, function() os.reboot() end)
    else s.msg = "Install failed: " .. tostring(err); OS.sfx("error") end
  end

  -- download + check; when `thenInstall` is set the update is installed straight away
  local function fetchUrl(win, url, thenInstall, meta)
    local s = win.state
    s.meta = meta
    s.msg = "Downloading..."; s.data = nil; s.bad = false
    OS.http(url, function(data, err)
      if not data then s.msg = "Failed: " .. tostring(err); s.bad = true; OS.sfx("error"); return end
      local ok, why = check(data)
      if not ok then s.msg = why; s.bad = true; OS.sfx("error"); return end
      s.data = data
      s.msg = string.format("Ready: %.1f KB (current %.1f KB).", #data / 1024, (OS.meSize or 0) / 1024)
      if thenInstall then install(win) else s.msg = s.msg .. " Press Install." ; OS.sfx("select") end
    end)
  end

  local function fetch(win)
    local s = win.state
    local url = resolve(s.url.text)
    if not url then s.msg = "Use github:user/repo, a gist / pastebin link or a raw URL"; s.bad = true; return end
    cfg.updateUrl = s.url.text; OS.dirty = true
    fetchUrl(win, url, false)
  end

  local function rollback(win)
    local s = win.state
    local ok, err = OS.rollbackSystem()
    if ok then s.msg = "Previous version restored. Restarting..."; OS.save(); OS.timer(1.5, function() os.reboot() end)
    else s.msg = "Rollback failed: " .. tostring(err); s.bad = true end
  end

  -- list a GitHub user's public gists. The API is tried first; it is rate limited (60/h per IP, shared by
  -- everyone on a server), so on any failure the public gist web page is read instead.
  local function scrape(win, user, why)
    local s = win.state
    local found, order = {}, {}
    local pending = 2
    OS.gistMeta = OS.gistMeta or {}
    local function unhtml(t)
      t = tostring(t or ""):gsub("<[^>]*>", ""):gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"'):gsub("&#39;", "'")
      return (t:gsub("^%s+", ""):gsub("%s+$", ""))
    end
    local function sortList(list)
      table.sort(list, function(a, b) return a.updated > b.updated end)
    end
    local function finish()
      local list = {}
      for _, id in ipairs(order) do
        local e = found[id]
        local m = OS.gistMeta[id] or {}
        list[#list + 1] = { id = id, file = m.name or e.name or id:sub(1, 10), desc = m.desc or "", updated = m.when or e.when or "", size = 0,
          raw = "https://gist.githubusercontent.com/" .. user .. "/" .. id .. "/raw?t=" .. os.epoch("utc"), page = "" }
      end
      sortList(list)
      s.list = list
      if #list == 0 then s.msg = "No public gists found (" .. tostring(why):sub(1, 30) .. ")"; s.bad = true; return end
      s.bad = false
      -- read each gist's own page, one at a time (slow but reliable), for its name and creation date
      local todo = {}
      for _, e in ipairs(list) do if not OS.gistMeta[e.id] then todo[#todo + 1] = e end end
      local n = 0
      local function nextOne()
        n = n + 1
        local e = todo[n]
        if not e or s.list ~= list then
          s.msg = #list .. " gist(s) via web page (API limit reached)."; sortList(list); return
        end
        s.msg = "Reading gist " .. n .. " of " .. #todo .. "..."
        OS.http("https://gist.github.com/" .. user .. "/" .. e.id, function(d)
          if d then
            local name = d:match('gist%-blob%-name[^>]*>%s*(.-)%s*</') or d:match('data%-tagsearch%-path="([^"]+)"') or d:match('<title>(.-)</title>')
            name = name and unhtml(name):gsub("%s*[·|%-]+%s*GitHub%s*$", ""):gsub("^%s*gist:?%s*", "")
            local when = d:match('datetime="([^"]+)"') or d:match('"created_at":"([^"]+)"')
            local desc = d:match('<meta name="description" content="([^"]*)"')
            local m = { name = (name and name ~= "") and name or nil, when = when, desc = desc and unhtml(desc) or nil }
            if m.desc and (m.desc == m.name or m.desc:lower():find("instantly share code", 1, true) or m.desc:find("^GitHub Gist")) then m.desc = nil end
            OS.gistMeta[e.id] = m
            if m.name then e.file = m.name end
            if m.when then e.updated = m.when end
            e.desc = m.desc or ""
          end
          OS.timer(0.4, nextOne)
        end)
      end
      nextOne()
    end
    for pg = 1, 2 do
      OS.http("https://gist.github.com/" .. user .. "?page=" .. pg, function(data)
        if data then
          local pat = 'href="/' .. user:gsub("%-", "%%-") .. '/(%x+)"'
          local pos = 1
          while true do
            local a, b, id = data:find(pat, pos)
            if not a then break end
            pos = b + 1
            if #id >= 20 and not found[id] then
              found[id] = {}; order[#order + 1] = id
              found[id].name = data:match('^[^>]*>%s*<strong[^>]*>%s*(.-)%s*</strong>', b + 1)
              -- the created / updated time sits a little further on in the same gist block
              local nextA = data:find(pat, b + 1) or (#data + 1)
              local blk = data:sub(b + 1, math.min(nextA - 1, b + 6000))
              found[id].when = blk:match('datetime="([^"]+)"')
            end
          end
        end
        pending = pending - 1
        if pending == 0 then finish() end
      end)
    end
  end

  local unlockSource
  local function loadGists(win)
    local s = win.state
    local user = trim(s.user.text)
    if user == "" then s.msg = "Enter a GitHub user name"; s.bad = true; return end
    cfg.gistUser = user; OS.dirty = true
    s.msg = "Loading gists of " .. user .. "..."; s.bad = false; s.list = nil; s.top = 0; s.sel = nil
    OS.http("https://api.github.com/users/" .. user .. "/gists?per_page=100", function(data, err)
      if not data then return scrape(win, user, err or "no answer") end
      local ok, j = pcall(textutils.unserialiseJSON, data)
      if not ok or type(j) ~= "table" then return scrape(win, user, "bad reply") end
      if j.message then return scrape(win, user, j.message) end
      local list = {}
      local ng = 0
      for _, g in ipairs(j) do
        ng = ng + 1
        for fname, f in pairs(g.files or {}) do
          if f.raw_url and (f.size or 0) >= 5000 then
            list[#list + 1] = { file = fname, desc = g.description or "", updated = g.updated_at or "", size = f.size or 0,
              raw = f.raw_url, page = g.html_url, id = tostring(f.raw_url):match("/(%x+)/raw") or g.id }
          end
        end
      end
      table.sort(list, function(a, b) return a.updated > b.updated end)
      s.list = list
      s.msg = ng .. " gist(s), " .. #list .. " big enough to be the system"
      s.bad = false
      if ng == 0 then s.msg = "GitHub lists no PUBLIC gists for " .. user .. " (secret gists are hidden)"; s.bad = true end
    end)
  end

  -- the gist source is locked with its own password; the first time you set one, after that it is asked
  unlockSource = function(win)
    local s = win.state
    local t = s.pw.text
    if cfg.srcHash then
      if OS.hashPw(t, cfg.srcSalt) ~= cfg.srcHash then s.msg = "Wrong password"; s.bad = true; OS.sfx("error"); s.pw.text = ""; s.pw.pos = 0; return end
    else
      if #t < 4 then s.msg = "Choose a password of at least 4 characters"; s.bad = true; return end
      cfg.srcSalt = OS.newSalt(); cfg.srcHash = OS.hashPw(t, cfg.srcSalt); OS.save()
    end
    s.pw.text = ""; s.pw.pos = 0
    s.ask = false; s.unlocked = true; s.bad = false; s.msg = "Unlocked: you can change the gist user"
    win.keepFocus = s.user; win.focus = s.user
  end

  function app.init(win)
    local s = { msg = "", tab = 1, top = 0 }
    win.state = s
    s.url = OS.field(cfg.updateUrl or DEFAULT_REPO, { placeholder = "github:user/repo, gist link or raw URL" })
    s.url.onEnter = function() fetch(win) end
    s.user = OS.field(cfg.gistUser or DEFAULT_USER, {})
    s.user.onEnter = function() loadGists(win) end
    s.pw = OS.field("", { mask = true, max = 40 })
    s.pw.onEnter = function() unlockSource(win) end
    win.keepFocus = s.url; win.focus = s.url
  end

  function app.draw(win, g)
    local s = win.state
    local w, h = g.w, g.h
    g.fill(1, 1, w, h, C.win)
    g.put(2, 1, "Windows Update", C.text, C.win)
    local x = 2
    x = x + g.btn(x, 2, "From link", function() s.tab = 1; win.keepFocus = s.url; win.focus = s.url end, s.tab == 1 and "pri" or "dark") + 1
    x = x + g.btn(x, 2, "Gist versions", function()
      local fld = s.unlocked and s.user or s.url; s.tab = 2; win.keepFocus = fld; win.focus = fld
      if not s.list then loadGists(win) end
    end, s.tab == 2 and "pri" or "dark") + 1
    g.btn(w - 10, 2, "Rollback", function() rollback(win) end, "dark")
    local msgY = h
    g.put(2, msgY, OS.trunc(s.msg, w - 3), s.bad and C.red or C.grn, C.win)
    if s.tab == 1 then
      g.put(2, 4, "GitHub repo (github:user/repo), gist link or raw URL:", C.sub, C.win)
      g.field(2, 5, w - 3, s.url, { bg = C.bar })
      local bx = 2
      bx = bx + g.btn(bx, 7, "Download", function() fetch(win) end) + 1
      g.btn(bx, 7, "Install + Restart", function() install(win) end, s.data and "pri" or "dark")
      local info = {
        "Installed file: " .. (OS.me or "(not running as startup)"),
        "Size: " .. string.format("%.1f KB", (OS.meSize or 0) / 1024),
        "The old version is kept for Rollback if space allows.",
        "Only the OS file is replaced; your data stays.",
      }
      for i, l in ipairs(info) do if 9 + i < h then g.put(2, 9 + i, OS.trunc(l, w - 3), C.sub, C.win) end end
    else
      g.put(2, 4, "GitHub user", C.sub, C.win)
      local fw = math.max(8, w - 38)
      if s.unlocked then
        g.field(14, 4, fw, s.user, { bg = C.bar })
        g.btn(w - 23, 4, "Lock", function() s.unlocked = false; s.user.text = cfg.gistUser or DEFAULT_USER; s.user.pos = #s.user.text; win.keepFocus = s.url; win.focus = s.url end, "dark")
      else
        g.put(14, 4, OS.trunc(trim(s.user.text), fw), C.text, C.win)
        g.btn(w - 23, 4, "Change", function() s.ask = not s.ask; if s.ask then win.keepFocus = s.pw; win.focus = s.pw end end, s.ask and "pri" or "dark")
      end
      g.btn(w - 14, 4, "Refresh", function() loadGists(win) end, "pri")
      if s.ask and not s.unlocked then
        g.fill(1, 6, w, 1, C.bar)
        g.put(2, 6, cfg.srcHash and "Password:" or "New password:", C.text, C.bar)
        g.field(16, 6, math.max(8, w - 30), s.pw, { bg = C.win })
        g.btn(w - 12, 6, "Unlock", function() unlockSource(win) end, "pri")
      end
      g.put(2, 5, OS.trunc("gist.github.com/" .. trim(s.user.text), w - 3), C.sub, C.win)
      local list = s.list or {}
      local rows = math.floor((h - 8) / 2)
      local maxTop = math.max(0, #list - rows)
      s.top = math.max(0, math.min(s.top, maxTop))
      if not s.list then g.put(2, 7, "Loading...", C.sub, C.win)
      elseif #list == 0 then g.put(2, 7, "No file of 5 KB or more in the public gists.", C.sub, C.win) end
      for i = 1, rows do
        local e = list[i + s.top]
        if not e then break end
        local y = 5 + i * 2
        local idx = i + s.top
        local on = s.sel == idx
        local bg = on and C.acc or C.win
        g.fill(1, y, w, 2, bg)
        local date = (e.updated ~= "") and localDate(e.updated) or "latest version"
        -- which version is installed: the one this system was installed from, otherwise the first gist made after this build
        local curWhen = cfg.sysWhen
        if not curWhen or curWhen == "" then
          for _, o in ipairs(list) do
            if o.updated ~= "" and o.updated >= BUILD_AT and (not curWhen or o.updated < curWhen) then curWhen = o.updated end
          end
        end
        -- same version = Reinstall, newer = Update, older = Rollback (the red button on the left)
        local kind = "Update"
        if curWhen and e.updated ~= "" then
          if e.updated == curWhen then kind = "Reinstall"
          elseif e.updated < curWhen then kind = "Rollback" end
        elseif e.updated ~= "" and BUILD_AT:match("^%d") and e.updated < BUILD_AT then kind = "Rollback" end
        local lab = (s.confirm == idx) and "Confirm?" or kind
        g.btn(2, y, lab, function()
          s.sel = idx
          if s.confirm == idx then s.confirm = nil; fetchUrl(win, e.raw, true, { id = e.id, when = e.updated, name = tostring(e.file):gsub("%.lua$", "") })
          else s.confirm = idx; s.msg = "Click Confirm? to " .. kind:lower() .. " " .. e.file .. " (" .. date .. ")"; s.bad = false
            OS.timer(5, function() if s.confirm == idx then s.confirm = nil end end) end
        end, "pri")
        local title = e.file .. ((e.desc and e.desc ~= "") and ("  " .. e.desc) or "")
        g.put(14, y, OS.trunc(title, w - 15), on and C.wht or C.text, bg)
        local info = ((e.updated == curWhen) and "[installed] " or "") .. date .. ((e.size > 0) and string.format("  %.1f KB", e.size / 1024) or "")
        g.put(14, y + 1, OS.trunc(info, w - 15), on and C.wht or C.sub, bg)
        g.hot(14, y, w - 14, 2, function() s.sel = idx; s.confirm = nil end)
      end
      g.scroll(1, 7, w, rows, function(d) s.top = math.max(0, math.min(maxTop, s.top + d)) end)
    end
  end

  return app
end

end)()
EMBED["storage"] = (function()
return function(OS)
  local C = OS.C
  -- Storage Monitor: Refined Storage through an Advanced Peripherals RS Bridge ("rsBridge").
  -- Crafting tasks, item/fluid browser (list, icon grid or compact view), search, sorting, mod filter,
  -- item details with craft buttons, and system energy/storage.
  local app = { id = "storage", title = "Storage Monitor", glyph = " S ", icon = "grn", fg = "sp0", cat = "Mods",
    w = 66, h = 20, single = true, minw = 44, minh = 12 }

  local function call(name, m, ...)
    local ok, r = pcall(OS.P.call, name, m, ...)
    if ok then return r end
  end

  local function fmt(n)
    if type(n) ~= "number" then return "-" end
    local a = math.abs(n)
    if a >= 1e9 then return string.format("%.1fG", n / 1e9) end
    if a >= 1e6 then return string.format("%.1fM", n / 1e6) end
    if a >= 1e3 then return string.format("%.1fk", n / 1e3) end
    return tostring(math.floor(n))
  end
  local function commas(n)
    if type(n) ~= "number" then return "-" end
    local s = string.format("%.0f", n)
    return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
  end

  local function stripName(n) return (tostring(n):gsub("^%[(.*)%]$", "%1")) end
  local function nameOf(t)
    if type(t) ~= "table" then return tostring(t) end
    local r = t.resource or t.item or t.fluid or t
    if type(r) == "table" then return stripName(r.displayName or r.name or r.id or "?") end
    return stripName(r)
  end
  local function idOf(t)
    if type(t) ~= "table" then return tostring(t) end
    local r = t.resource or t.item or t.fluid or t
    if type(r) == "table" then return tostring(r.name or r.id or r.displayName or "?") end
    return tostring(r)
  end
  local function amountOf(t)
    if type(t) ~= "table" then return nil end
    return t.amount or t.quantity or t.count or (type(t.resource) == "table" and t.resource.count) or nil
  end
  local function progressOf(t)
    if type(t) ~= "table" then return nil end
    local p = t.completion or t.progress or t.percentage
    if type(p) == "number" then
      if p > 1 then p = p / 100 end
      return math.max(0, math.min(1, p))
    end
  end
  local function nsOf(id) return tostring(id):match("^([^:]+):") or "other" end

  -- ------------------------------------------------------------ generated icons
  -- (the bridge has no textures, so every item gets a stable coloured tile with its initials)
  local PAL = { "acc", "grn", "red", "yel", "sp", "sp1", "wp", "dock" }
  local LIGHT = { yel = true, grn = true, sp = true }
  local function hash(str)
    local h = 7
    for i = 1, #str do h = (h * 31 + str:byte(i)) % 1000003 end
    return h
  end
  local function initials(name)
    local a, b = name:match("^(%w)%S*%s+(%w)")
    if not a then a, b = name:sub(1, 1), name:sub(2, 2) end
    return (a .. (b ~= "" and b or " ")):upper()
  end
  local function icon(g, x, y, it, rows, big)
    local h = hash(it.id)
    local nm = PAL[h % #PAL + 1]
    local bg = C[nm]
    local fg = LIGHT[nm] and C.sp0 or C.wht
    local ini = initials(it.name)
    if big then
      for r = 0, 3 do
        for c = 0, 7 do
          local on = (math.floor(h / (2 ^ ((r * 8 + c) % 19))) % 2) == 1
          g.put(x + c, y + r, " ", fg, on and bg or C.dock)
        end
      end
      g.put(x + 3, y + 1, ini, fg, bg)
    elseif rows == 2 then
      g.put(x, y, " " .. ini .. " ", fg, bg)
      for i = 0, 3 do
        local on = (math.floor(h / 2 ^ (i + 1)) % 2) == 1
        g.put(x + i, y + 1, " ", fg, on and bg or C.dock)
      end
    else
      g.put(x, y, " " .. ini .. " ", fg, bg)
    end
  end

  -- ------------------------------------------------------------ data
  local function findBridge()
    for _, n in ipairs(OS.P.names()) do
      local t = (OS.P.getType(n) or ""):lower()
      if t == "rsbridge" or t:find("rs_?bridge") then return n end
    end
  end

  local function convert(list, fluid)
    local out = {}
    if type(list) == "table" then
      for _, it in ipairs(list) do
        out[#out + 1] = { name = nameOf(it), id = idOf(it), amount = amountOf(it) or 0, fluid = fluid, craftable = type(it) == "table" and it.isCraftable or nil }
      end
    end
    return out
  end

  local DEMO = {
    { "minecraft:cobblestone", "Cobblestone", 5900000 }, { "minecraft:iron_ingot", "Iron Ingot", 3700000 },
    { "minecraft:redstone", "Redstone Dust", 3100000 }, { "minecraft:oak_log", "Oak Log", 2900000 },
    { "minecraft:gold_ingot", "Gold Ingot", 2100000 }, { "minecraft:diamond", "Diamond", 812000 },
    { "mekanism:ingot_osmium", "Osmium Ingot", 1500000 }, { "mekanism:ingot_tin", "Tin Ingot", 1300000 },
    { "thermal:nickel_ingot", "Nickel Ingot", 900000 }, { "thermal:silver_ingot", "Silver Ingot", 450000 },
    { "create:andesite_alloy", "Andesite Alloy", 600000 }, { "create:brass_ingot", "Brass Ingot", 410000 },
    { "draconicevolution:draconium_dust", "Draconium Dust", 250000 }, { "draconicevolution:awakened_core", "Awakened Draconium Core", 64 },
    { "appliedenergistics2:certus_quartz_crystal", "Certus Quartz", 700000 }, { "minecraft:ender_pearl", "Ender Pearl", 12000 },
    { "minecraft:blaze_rod", "Blaze Rod", 8800 }, { "minecraft:netherite_ingot", "Netherite Ingot", 300 },
    { "botania:manasteel_ingot", "Manasteel Ingot", 57000 }, { "immersiveengineering:ingot_steel", "Steel Ingot", 940000 },
  }

  local function demoData(s)
    local t = os.clock()
    s.tasks = {
      { name = "Processor (Printed)", id = "refinedstorage:printed_processor", amount = 64, progress = (t / 40) % 1 },
      { name = "Advanced Processor", id = "refinedstorage:advanced_processor", amount = 16, progress = (t / 25) % 1 },
      { name = "Quartz Enriched Iron", id = "refinedstorage:quartz_enriched_iron", amount = 128, progress = (t / 60) % 1 },
    }
    local items = {}
    for _, d in ipairs(DEMO) do items[#items + 1] = { id = d[1], name = d[2], amount = d[3] + math.floor(math.sin(t + #d[2]) * 40), craftable = d[3] < 1000000 } end
    s.items = items
    s.fluids = { { id = "minecraft:water", name = "Water", amount = 5e7, fluid = true }, { id = "minecraft:lava", name = "Lava", amount = 2.4e6, fluid = true },
      { id = "mekanism:hydrogen", name = "Hydrogen", amount = 880000, fluid = true } }
    s.sys = { e = 3.2e6 + math.sin(t) * 1e5, emax = 8e6, use = 1480, used = 98210, total = 256000 }
  end

  local function poll(s)
    local n = 0
    while s.alive do
      n = n + 1
      if s.demo then
        s.bridge = "demo_bridge"; demoData(s)
      else
        s.bridge = findBridge()
        if s.bridge then
          local b = s.bridge
          local tasks = call(b, "getCraftingTasks")
          local list = {}
          if type(tasks) == "table" then
            for _, t in ipairs(tasks) do list[#list + 1] = { name = nameOf(t), id = idOf(t), amount = amountOf(t), progress = progressOf(t) } end
          end
          local newDone = (s.nTasks or 0) > #list and s.nTasks ~= nil
          s.nTasks = #list
          if newDone then OS.sfx("coin") end
          s.tasks = list
          s.items = convert(call(b, "listItems"), false)
          if n % 3 == 1 then s.fluids = convert(call(b, "listFluids"), true) end
          if n % 5 == 1 then
            local set = {}
            local cr = call(b, "listCraftableItems")
            if type(cr) == "table" then for _, it in ipairs(cr) do set[idOf(it)] = true end end
            s.craftSet = set
          end
          if s.craftSet then for _, it in ipairs(s.items) do if s.craftSet[it.id] then it.craftable = true end end end
          s.sys = { e = call(b, "getEnergyStorage"), emax = call(b, "getMaxEnergyStorage"), use = call(b, "getEnergyUsage"),
            used = call(b, "getUsedItemStorage") or call(b, "getUsedExternItemStorage"), total = call(b, "getTotalItemStorage") or call(b, "getTotalExternItemStorage") }
        else
          s.tasks, s.items, s.fluids, s.sys = nil, nil, nil, nil
        end
      end
      sleep(2)
    end
  end

  function app.init(win)
    local s = { alive = true, tab = 2, demo = false, scroll = 0, top = 0, sortI = 1, mod = nil, msg = "",
      view = OS.cfg.storageView or "icons", q = OS.field("", { placeholder = "Search..." }) }
    win.state = s
    s.poller = OS.async(function() poll(s) end)
  end
  function app.close(win) local s = win.state; s.alive = false; if s.poller then s.poller.stop = true end end

  local SORTS = { "Count v", "Count ^", "A-Z", "Z-A", "Mod" }

  local function bar(g, x, y, w, ratio, col, label)
    g.fill(x, y, w, 1, C.bar)
    local fw = math.floor(math.max(0, math.min(1, ratio)) * w + 0.5)
    g.fill(x, y, fw, 1, col)
    if label then
      local lab = " " .. OS.trunc(label, w - 2)
      for i = 1, #lab do g.put(x + i - 1, y, lab:sub(i, i), C.wht, (i <= fw) and col or C.bar) end
    end
  end

  local function craft(s, it, n)
    if not s.bridge then return end
    s.msg = "Requesting " .. n .. "x " .. it.name .. "..."
    OS.async(function()
      if s.demo then sleep(0.3); s.msg = "Demo: crafting " .. n .. "x " .. it.name; OS.sfx("select"); return end
      local ok, r = pcall(OS.P.call, s.bridge, "craftItem", { name = it.id, count = n })
      if ok and r then s.msg = "Crafting " .. n .. "x " .. it.name; OS.sfx("select")
      else s.msg = "Cannot craft " .. it.name .. (ok and "" or (": " .. tostring(r))); OS.sfx("error") end
    end)
  end

  local function filtered(s, list)
    local q = s.q.text:lower()
    local out = {}
    local mods = {}
    for _, it in ipairs(list or {}) do
      local ns = nsOf(it.id)
      mods[ns] = (mods[ns] or 0) + 1
      if (not s.mod or ns == s.mod) and (q == "" or it.name:lower():find(q, 1, true) or it.id:lower():find(q, 1, true))
        and (not s.craftOnly or it.craftable) then out[#out + 1] = it end
    end
    local m = SORTS[s.sortI]
    table.sort(out, function(a, b)
      if m == "Count v" then if a.amount ~= b.amount then return a.amount > b.amount end
      elseif m == "Count ^" then if a.amount ~= b.amount then return a.amount < b.amount end
      elseif m == "Z-A" then if a.name ~= b.name then return a.name:lower() > b.name:lower() end
      elseif m == "Mod" then local na, nb = nsOf(a.id), nsOf(b.id); if na ~= nb then return na < nb end end
      return a.name:lower() < b.name:lower()
    end)
    return out, mods
  end

  local function browser(win, g, w, h, list, label)
    local s = win.state
    local fw = math.max(10, math.min(22, math.floor(w / 3)))
    g.field(2, 3, fw, s.q, { bg = C.bar })
    local x = fw + 3
    for _, v in ipairs({ { "icons", "Icons" }, { "list", "List" }, { "compact", "Compact" } }) do
      if x + #v[2] + 2 < w then
        x = x + g.btn(x, 3, v[2], function() s.view = v[1]; OS.cfg.storageView = v[1]; OS.dirty = true; s.top = 0 end, s.view == v[1] and "pri" or "dark") + 1
      end
    end
    if x + 12 < w then x = x + g.btn(x, 3, SORTS[s.sortI], function() s.sortI = s.sortI % #SORTS + 1 end) + 1 end
    if x + 12 < w and s.tab == 2 then g.btn(x, 3, s.craftOnly and "Craftable" or "All items", function() s.craftOnly = not s.craftOnly; s.top = 0 end, s.craftOnly and "pri" or "dark") end

    local items, mods = filtered(s, list)
    -- mod chips
    local names = {}
    for ns, c in pairs(mods) do names[#names + 1] = { ns, c } end
    table.sort(names, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return a[1] < b[1] end)
    local cx = 2
    cx = cx + g.btn(cx, 4, "All", function() s.mod = nil; s.top = 0 end, not s.mod and "pri" or "dark") + 1
    for _, nmc in ipairs(names) do
      local lab = OS.trunc(nmc[1], 12) .. " " .. nmc[2]
      if cx + #lab + 3 >= w then break end
      cx = cx + g.btn(cx, 4, lab, function() s.mod = nmc[1]; s.top = 0 end, s.mod == nmc[1] and "pri" or "dark") + 1
    end
    g.put(w - 14, 2, OS.trunc(#items .. " " .. label, 13), C.acc, C.win)

    local selIt
    for _, it in ipairs(items) do if it.id == s.sel then selIt = it end end
    local dw = (selIt and w >= 60) and 26 or 0
    local lw = w - dw - (dw > 0 and 1 or 0)
    local y0, rows = 6, h - 6
    if rows < 1 then return end

    if #items == 0 then g.put(2, y0, "Nothing matches.", C.sub, C.win) end
    local function pick(it) return function() s.sel = (s.sel == it.id) and nil or it.id end end
    local total, per
    if s.view == "icons" then
      local cw = 19
      local cols = math.max(1, math.floor((lw - 1) / cw))
      local rr = math.max(1, math.floor(rows / 3))
      total = math.ceil(#items / cols)
      local maxTop = math.max(0, total - rr)
      s.top = math.max(0, math.min(s.top, maxTop))
      for r = 0, rr - 1 do
        for c = 0, cols - 1 do
          local it = items[(r + s.top) * cols + c + 1]
          if not it then break end
          local cx0, cy0 = 2 + c * cw, y0 + r * 3
          local on = it.id == s.sel
          if on then g.fill(cx0 - 1, cy0, cw, 2, C.bar) end
          icon(g, cx0, cy0, it, 2)
          g.put(cx0 + 5, cy0, OS.trunc(it.name, cw - 7), on and C.wht or C.text, on and C.bar or C.win)
          g.put(cx0 + 5, cy0 + 1, fmt(it.amount) .. (it.fluid and " mB" or "") .. (it.craftable and " +" or ""), C.acc, on and C.bar or C.win)
          g.hot(cx0 - 1, cy0, cw, 2, pick(it))
        end
      end
      g.scroll(1, y0, lw, rows, function(d) s.top = math.max(0, math.min(maxTop, s.top + d)) end)
    elseif s.view == "list" then
      total = #items
      local maxTop = math.max(0, total - rows)
      s.top = math.max(0, math.min(s.top, maxTop))
      for r = 1, rows do
        local it = items[r + s.top]
        if not it then break end
        local y = y0 + r - 1
        local on = it.id == s.sel
        g.fill(1, y, lw, 1, on and C.bar or C.win)
        icon(g, 2, y, it, 1)
        local cnt = fmt(it.amount) .. (it.fluid and " mB" or "")
        g.put(7, y, OS.trunc(it.name, lw - 9 - #cnt - 2), on and C.wht or C.text, on and C.bar or C.win)
        if lw >= 56 then g.put(7 + math.min(#it.name, 24) + 2, y, OS.trunc(it.id, lw - 12 - #cnt - math.min(#it.name, 24) - 2), C.sub, on and C.bar or C.win) end
        g.put(lw - #cnt - 1, y, cnt, it.craftable and C.grn or C.acc, on and C.bar or C.win)
        g.hot(1, y, lw, 1, pick(it))
      end
      g.scroll(1, y0, lw, rows, function(d) s.top = math.max(0, math.min(maxTop, s.top + d * 2)) end)
    else
      local cw = 26
      local cols = math.max(1, math.floor((lw - 1) / cw))
      total = math.ceil(#items / cols)
      local maxTop = math.max(0, total - rows)
      s.top = math.max(0, math.min(s.top, maxTop))
      for r = 0, rows - 1 do
        for c = 0, cols - 1 do
          local it = items[(r + s.top) * cols + c + 1]
          if not it then break end
          local cx0, y = 2 + c * cw, y0 + r
          local on = it.id == s.sel
          local cnt = fmt(it.amount)
          g.put(cx0, y, OS.trunc(it.name, cw - 3 - #cnt), on and C.acc or C.text, C.win)
          g.put(cx0 + cw - 2 - #cnt, y, cnt, C.sub, C.win)
          g.hot(cx0, y, cw - 1, 1, pick(it))
        end
      end
      g.scroll(1, y0, lw, rows, function(d) s.top = math.max(0, math.min(maxTop, s.top + d * 2)) end)
    end

    -- detail pane
    if selIt then
      local dx = lw + 2
      g.fill(dx - 1, 5, dw + 1, h - 4, C.bar)
      icon(g, dx + 1, 6, selIt, 4, true)
      g.put(dx, 11, OS.trunc(selIt.name, dw - 1), C.wht, C.bar)
      g.put(dx, 12, OS.trunc(selIt.id, dw - 1), C.sub, C.bar)
      g.put(dx, 14, "Stored", C.sub, C.bar)
      g.put(dx, 15, OS.trunc(commas(selIt.amount) .. (selIt.fluid and " mB" or ""), dw - 1), C.acc, C.bar)
      if not selIt.fluid then
        g.put(dx, 16, selIt.craftable and "Craftable" or "Not craftable", selIt.craftable and C.grn or C.sub, C.bar)
        if selIt.craftable and h >= 18 then
          local bx2 = dx
          for _, n in ipairs({ 1, 10, 64 }) do bx2 = bx2 + g.btn(bx2, 17, "x" .. n, function() craft(s, selIt, n) end, "pri") + 1 end
        end
      end
      g.btn(dx + dw - 8, 5, "Close", function() s.sel = nil end, "dark")
    end
  end

  function app.draw(win, g)
    local s = win.state
    local w, h = g.w, g.h
    g.fill(1, 1, w, h, C.win)
    local x = 2
    for i, n in ipairs({ "Crafting", "Items", "Fluids", "System" }) do
      x = x + g.btn(x, 1, n, function() s.tab = i; s.scroll = 0; s.top = 0 end, s.tab == i and "pri" or nil) + 1
    end
    g.btn(w - 8, 1, s.demo and "Demo:on" or "Demo", function() s.demo = not s.demo; s.tasks, s.items, s.fluids, s.sys = nil, nil, nil, nil; s.sel = nil end)
    if not s.bridge then
      g.put(2, 3, "No RS Bridge found.", C.text, C.win)
      local help = { "Needs Advanced Peripherals: place an RS Bridge", "next to your Refined Storage network and a", "wired modem / adjacent computer (or connect to a", "Wi-Fi hotspot that shares one).", "", "Press Demo to preview this app." }
      for i, l in ipairs(help) do g.put(2, 4 + i, OS.trunc(l, w - 3), C.sub, C.win) end
      return
    end
    g.put(2, 2, OS.trunc("Bridge: " .. s.bridge .. (s.msg ~= "" and ("   " .. s.msg) or ""), w - 18), C.sub, C.win)
    local rows = h - 3
    if s.tab == 1 then
      local tasks = s.tasks or {}
      if #tasks == 0 then g.put(2, 4, "Nothing is crafting.", C.sub, C.win) end
      local per = 3
      local maxScroll = math.max(0, #tasks - math.floor(rows / per))
      s.scroll = math.min(s.scroll, maxScroll)
      for i = 1, math.floor(rows / per) do
        local t = tasks[i + s.scroll]
        if not t then break end
        local y = 3 + (i - 1) * per
        icon(g, 2, y, { id = t.id or t.name, name = t.name }, 2)
        g.put(7, y, OS.trunc(t.name .. (t.amount and (" x" .. fmt(t.amount)) or ""), w - 9), C.text, C.win)
        if t.progress then bar(g, 7, y + 1, w - 9, t.progress, C.grn, string.format("%d%%", t.progress * 100))
        else g.put(7, y + 1, "in progress...", C.sub, C.win) end
      end
      g.put(w - 26, 2, #tasks .. " task(s)", C.acc, C.win)
      g.scroll(1, 3, w, rows, function(d) s.scroll = math.max(0, math.min(maxScroll, s.scroll + d)) end)
    elseif s.tab == 2 then browser(win, g, w, h, s.items, "items")
    elseif s.tab == 3 then browser(win, g, w, h, s.fluids, "fluids")
    else
      local sy = s.sys or {}
      g.put(2, 4, "Energy", C.sub, C.win)
      bar(g, 2, 5, w - 3, (sy.emax and sy.emax > 0 and sy.e) and sy.e / sy.emax or 0, C.yel, fmt(sy.e) .. " / " .. fmt(sy.emax) .. " RF")
      g.put(2, 7, "Usage: " .. fmt(sy.use) .. " RF/t", C.text, C.win)
      g.put(2, 9, "Item storage", C.sub, C.win)
      bar(g, 2, 10, w - 3, (sy.total and sy.total > 0 and sy.used) and sy.used / sy.total or 0, C.acc, fmt(sy.used) .. " / " .. fmt(sy.total))
    end
  end

  return app
end

end)()
EMBED["themes"] = (function()
return function(OS)
  local C = OS.C
  local cfg = OS.cfg
  -- Theme Studio: custom themes, per-slot RGB sliders, hex entry, presets, rainbow accent.
  local app = { id = "themes", title = "Personalization", glyph = " T ", icon = "acc", fg = "wht", cat = "System",
    w = 58, h = 19, single = true, minw = 50, minh = 17 }
  local SLOTS = { { "acc", "Accent" }, { "dk", "Wallpaper" }, { "win", "Window" }, { "bar", "Titlebar" },
    { "desk", "Desktop" }, { "dock", "Dock" }, { "text", "Text" }, { "sub", "Dim text" } }
  local DEFAULTS = { acc = 0x0078D7, dk = 0x6FBCF7, win = 0x1F1F1F, bar = 0x2D2D2D, desk = 0x03122F,
    dock = 0x151515, text = 0xFFFFFF, sub = 0xA0A0A0 }
  local PRESETS = { 0x0078D7, 0x0063B1, 0x8E8CD8, 0x744DA9, 0xB146C2, 0xC30052, 0xE81123, 0xF7630C,
    0xFFB900, 0x10893E, 0x00B7C3, 0x2D7D9A, 0x767676, 0x4C4A48, 0xFFFFFF, 0x000000 }

  -- swatches use the live palette slots (a terminal can only show 16 colours at once)
  local SWATCH = { acc = "acc", dk = "wp", win = "win", bar = "bar", desk = "desk", dock = "dock", text = "text", sub = "sub" }
  local SPARE = { "sp0", "sp1", "sp2", "sp" }

  local function parts(c) return math.floor(c / 65536) % 256, math.floor(c / 256) % 256, c % 256 end
  local function join(r, g, b) return r * 65536 + g * 256 + b end

  local function cur(s)
    for _, t in ipairs(cfg.custom) do if t.name == s.sel then return t end end
  end
  local function refresh() OS.wallCache = nil; OS.applyTheme(); OS.dirty = true end

  local function newTheme(s, base)
    local n, name = 1, "Custom 1"
    local function exists(nm) return OS.findTheme(nm) ~= nil end
    while exists(name) do n = n + 1; name = "Custom " .. n end
    local t = { name = name }
    local src = base or OS.findTheme(cfg.theme) or {}
    for k, v in pairs(DEFAULTS) do t[k] = src[k] or v end
    t.lt = src.lt or 0x99C9F2
    cfg.custom[#cfg.custom + 1] = t
    s.sel = name; cfg.theme = name; s.hex.text = string.format("%06X", t[s.slot]); s.hex.pos = #s.hex.text
    refresh()
  end

  function app.init(win)
    if not cfg.custom then cfg.custom = {} end
    if not cfg.rgb then cfg.rgb = { speed = 3 } end
    local s = { slot = "acc", sel = cfg.theme, hex = { text = "", pos = 0 }, name = { text = "", pos = 0 }, ltop = 0,
      locked = cfg.hash ~= nil, pw = OS.field("", { mask = true, max = 40, placeholder = "Password" }), msg = "" }
    win.state = s
    s.pw.onEnter = function()
      if OS.hashPw(s.pw.text, cfg.salt) == cfg.hash then s.locked = false; win.focus = nil; OS.sfx("login")
      else s.msg = "Wrong password"; OS.sfx("error") end
      s.pw.text = ""; s.pw.pos = 0
    end
    if s.locked then win.keepFocus = s.pw; win.focus = s.pw end
    local t = cur(s)
    if t then s.hex.text = string.format("%06X", t.acc or 0); s.hex.pos = 6 end
  end

  function app.draw(win, g)
    local s = win.state
    local w, h = g.w, g.h
    g.fill(1, 1, w, h, C.win)
    if s.locked then
      local fw = math.min(30, w - 4)
      local x0 = math.floor((w - fw) / 2) + 1
      g.put(x0, math.floor(h / 2) - 3, "Personalization is locked", C.text, C.win)
      g.put(x0, math.floor(h / 2) - 2, "Enter your login password", C.sub, C.win)
      g.field(x0, math.floor(h / 2), fw, s.pw)
      g.btn(x0, math.floor(h / 2) + 2, "Unlock", function() s.pw.onEnter() end, "pri")
      g.put(x0, math.floor(h / 2) + 4, s.msg, C.red, C.win)
      return
    end
    -- left: theme list
    local lw = 20
    g.fill(1, 1, lw, h, C.bar)
    g.put(2, 1, "Themes", C.sub, C.bar)
    local all = {}
    for _, t in ipairs(OS.THEMES) do all[#all + 1] = { t = t, custom = false } end
    for _, t in ipairs(cfg.custom) do all[#all + 1] = { t = t, custom = true } end
    local rowsN = h - 4
    local maxTop = math.max(0, #all - rowsN)
    s.ltop = math.max(0, math.min(s.ltop, maxTop))
    for i = 1, rowsN do
      local e = all[i + s.ltop]
      if not e then break end
      local t, custom = e.t, e.custom
      local row = 1 + i
      local on = cfg.theme == t.name
      g.fill(1, row, lw, 1, on and C.acc or C.bar)
      g.put(2, row, (on and "* " or "  ") .. OS.trunc(t.name, lw - 4), on and C.wht or C.text, on and C.acc or C.bar)
      g.hot(1, row, lw, 1, function()
        cfg.theme = t.name; refresh()
        s.sel = custom and t.name or nil
        if custom then s.hex.text = string.format("%06X", t[s.slot] or 0); s.hex.pos = 6 end
      end)
    end
    g.scroll(1, 2, lw, rowsN, function(d) s.ltop = math.max(0, math.min(maxTop, s.ltop + d)) end)
    g.btn(2, h - 1, "+ New", function() newTheme(s, OS.findTheme(cfg.theme)) end, "pri")
    local t = cur(s)
    if t then g.btn(10, h - 1, "Delete", function()
      for k, v in ipairs(cfg.custom) do if v == t then table.remove(cfg.custom, k) break end end
      cfg.theme = "Windows 10"; s.sel = nil; refresh()
    end, "danger") end

    -- right
    local x = lw + 2
    local rw = w - x
    local cth = OS.findTheme(cfg.theme)
    if cth and cth.rgb then
      g.put(x, 1, "RGB theme speed", C.text, C.win)
      g.slider(x + 17, 1, math.max(6, rw - 18), (cfg.rgb.speed - 1) / 9, function(v) cfg.rgb.speed = 1 + math.floor(v * 9 + 0.5); OS.dirty = true end)
    else
      g.put(x, 1, "Pick the RGB theme for a rainbow accent", C.sub, C.win)
    end
    g.put(x, 2, "Darker mode", C.text, C.win)
    g.toggle(x + 16, 2, cfg.darker, function() cfg.darker = not cfg.darker; refresh() end)
    if not t then
      g.put(x, 5, "Built-in theme selected.", C.sub, C.win)
      g.put(x, 6, "Press + New to copy it into an", C.sub, C.win)
      g.put(x, 7, "editable custom theme.", C.sub, C.win)
      return
    end
    g.put(x, 4, "Editing: " .. t.name, C.acc, C.win)
    g.field(x + 22, 4, math.max(8, rw - 30), s.name, { bg = C.bar })
    g.btn(w - 8, 4, "Rename", function()
      local nm = s.name.text
      if #nm > 0 and (not OS.findTheme(nm) or nm == t.name) then t.name = nm; cfg.theme = nm; s.sel = nm; s.name.text = ""; s.name.pos = 0; OS.dirty = true end
    end)
    -- slots
    for k, sl in ipairs(SLOTS) do
      local y = 5 + k - (k > 4 and 4 or 0)
      local cx = k > 4 and (x + math.floor(rw / 2)) or x
      local on = s.slot == sl[1]
      local label = sl[2]
      g.put(cx, y, " ", C.wht, C[SWATCH[sl[1]]])
      g.put(cx + 1, y, " " .. OS.trunc(label, 10) .. " ", on and C.wht or C.text, on and C.acc or C.win)
      g.hot(cx, y, 13, 1, function() s.slot = sl[1]; s.hex.text = string.format("%06X", t[sl[1]] or 0); s.hex.pos = 6 end)
    end
    local v = t[s.slot] or 0
    local r, gg, b = parts(v)
    local sy = 11
    g.put(x, sy - 1, "Colour: " .. s.slot, C.sub, C.win)
    local sw = math.max(10, rw - 12)
    local function chan(n, label, val, idx)
      g.put(x, sy + n, label, C.sub, C.win)
      g.slider(x + 2, sy + n, sw, val / 255, function(f)
        local nv = math.floor(f * 255 + 0.5)
        local rr, g2, bb = parts(t[s.slot] or 0)
        if idx == 1 then rr = nv elseif idx == 2 then g2 = nv else bb = nv end
        t[s.slot] = join(rr, g2, bb); s.hex.text = string.format("%06X", t[s.slot]); s.hex.pos = 6; refresh()
      end, idx == 1 and C.red or (idx == 2 and C.grn or C.acc))
      g.put(x + sw + 3, sy + n, string.format("%3d", val), C.text, C.win)
    end
    chan(0, "R", r, 1); chan(1, "G", gg, 2); chan(2, "B", b, 3)
    g.put(x, sy + 4, "Hex #", C.sub, C.win)
    g.field(x + 6, sy + 4, 9, s.hex, { bg = C.bar })
    g.btn(x + 16, sy + 4, "Apply", function()
      local hx = s.hex.text:gsub("^#", "")
      local n = tonumber(hx, 16)
      if n and #hx == 6 then t[s.slot] = n; refresh() else OS.toast("Hex must be 6 digits, e.g. B3264A") end
    end, "pri")
    g.btn(x + 25, sy + 4, "Reset slot", function() t[s.slot] = DEFAULTS[s.slot]; s.hex.text = string.format("%06X", t[s.slot]); refresh() end)
    -- presets: four at a time, drawn with spare palette slots
    g.put(x, sy + 6, "Presets", C.sub, C.win)
    local pages = math.ceil(#PRESETS / 4)
    s.ppage = (s.ppage or 0) % pages
    local want = {}
    for i = 1, 4 do want[SPARE[i]] = PRESETS[s.ppage * 4 + i] or 0 end
    local same = app.pal ~= nil
    if same then for k, v in pairs(want) do if app.pal[k] ~= v then same = false end end end
    if not same then app.pal = want; OS.palOver = want; OS.applyTheme() end
    g.btn(x + 9, sy + 6, "<", function() s.ppage = (s.ppage - 1) % pages end, "dark")
    g.btn(x + 13, sy + 6, ">", function() s.ppage = (s.ppage + 1) % pages end, "dark")
    for i = 1, 4 do
      local c = PRESETS[s.ppage * 4 + i]
      if c then
        local px = x + (i - 1) * 8
        g.put(px, sy + 7, "      ", C.wht, C[SPARE[i]])
        g.put(px, sy + 8, "      ", C.wht, C[SPARE[i]])
        g.hot(px, sy + 7, 6, 2, function() t[s.slot] = c; s.hex.text = string.format("%06X", c); s.hex.pos = 6; refresh() end)
      end
    end
  end

  return app
end

end)()
EMBED["berielpedia"] = (function()
return function(OS)
  local C = OS.C
  -- BerielPedia: offline encyclopedia about Minecraft and All the Mods 6-11, plus optional online lookup.
  local app = { id = "berielpedia", title = "BerielPedia", glyph = " W ", icon = "acc", fg = "wht", cat = "Utilities",
    w = 62, h = 19, single = true, minw = 44, minh = 12 }

  local A = {
    { "Minecraft", "Minecraft", "Minecraft is a sandbox game created by Markus 'Notch' Persson and developed and published by Mojang Studios. Players explore a world of blocks, gather resources, craft tools, build structures and fight or avoid monsters.\n\nModes: Survival (health, hunger, resources), Creative (unlimited blocks and flight), Adventure and Spectator. The Java Edition is the one the big mod ecosystems (Forge, NeoForge, Fabric) target, which is why modpacks like All the Mods are Java-based.\n\nVersion numbers: older releases used 1.x.y (for example 1.20.1 or 1.21.1). Recent releases moved to year-based numbering starting with 26.x. Modpacks usually stay on one version for a long time because mods must be rebuilt for each new one." },
    { "Minecraft", "Dimensions", "There are three main dimensions.\n\nOverworld: the starting world with biomes, caves, villages and oceans. Since the 1.18 world update, the build height runs from Y=-64 to Y=320.\n\nThe Nether: a hot, dangerous dimension reached through an obsidian portal. Fast travel (1 block there = 8 blocks in the Overworld), fortresses, bastions, ancient debris for netherite.\n\nThe End: reached through an End Portal found in a stronghold. Home of the Ender Dragon, end cities and elytra." },
    { "Minecraft", "Crafting and tools", "Crafting turns items into other items on a crafting table (3x3 grid) or in the 2x2 inventory grid. Tool tiers in order: wood, stone, iron, gold, diamond, netherite.\n\nFurnaces smelt ore and cook food; blast furnaces and smokers do it twice as fast for ore and food respectively. Anvils repair and rename; smithing tables upgrade diamond gear to netherite." },
    { "Minecraft", "Redstone", "Redstone is Minecraft's electrical system. Redstone dust carries a signal up to 15 blocks, repeaters refresh and delay it, comparators read container fill levels and compare signals, and observers detect block updates.\n\nCommon parts: pistons, hoppers, droppers, dispensers, levers, buttons, pressure plates and daylight sensors. Players build doors, farms, sorters and even working computers. CC:Tweaked computers can read and output redstone on all six sides." },
    { "Minecraft", "Mobs", "Passive: cows, pigs, sheep, chickens, villagers. Neutral: endermen, wolves, bees (they attack if provoked). Hostile: zombies, skeletons, creepers (explode), spiders, witches, phantoms.\n\nBosses: the Ender Dragon (the End) and the Wither (summoned with soul sand and wither skeleton skulls). Newer additions include the Warden in the deep dark." },
    { "Minecraft", "Enchanting", "Enchanting improves tools, weapons and armour. Use an enchanting table with lapis lazuli and experience levels (more bookshelves around the table unlock stronger options), or combine enchanted books on an anvil.\n\nExamples: Sharpness, Efficiency, Unbreaking, Fortune, Silk Touch, Protection, Mending. Some enchantments conflict, such as Fortune and Silk Touch." },
    { "Minecraft", "Modding", "Mods add content to the Java Edition through loaders: Forge, NeoForge and Fabric. Mods are written for a specific Minecraft version and loader, so packs pick one pair and stay on it.\n\nCC:Tweaked adds programmable computers, turtles, monitors and peripherals in Lua. Advanced Peripherals, Big Reactors-style mods, Draconic Evolution and Refined Storage all expose peripherals that CC computers can read and control, which is how apps like the Reactor Monitor in this OS work." },

    { "All the Mods", "What is All the Mods?", "All the Mods (ATM) is a family of large kitchen-sink modpacks published on CurseForge. Each release bundles hundreds of mods covering tech, magic, storage, exploration and automation, with a progression goal.\n\nNumbered releases (ATM 6, 7, 8, 9, 10 and 11) each target a Minecraft version. Smaller spin-offs such as 'To the Sky' variants start the player on a floating island. Check CurseForge for the exact version and recommended RAM of each pack; those details change with updates." },
    { "All the Mods", "ATM 6", "All the Mods 6 targets Minecraft 1.16.5 on Forge. It was a very popular pack with a big tech-and-magic list, including Mekanism, Applied Energistics 2, Refined Storage, Thermal series, Immersive Engineering, Botania and Create-style automation alternatives. Quests help guide progression." },
    { "All the Mods", "ATM 7", "All the Mods 7 targets Minecraft 1.18.2 on Forge, taking advantage of the taller, reworked world generation introduced in 1.18. Its modlist drew on the same big tech and magic mods as before as they were ported forward." },
    { "All the Mods", "ATM 8", "All the Mods 8 targets Minecraft 1.19.2 on Forge. It continued the tech, magic and exploration formula with the mods that had been updated to that version." },
    { "All the Mods", "ATM 9", "All the Mods 9 targets Minecraft 1.20.1 on Forge. 1.20.1 was a long-lived version for modding, so the pack has a very large mod list and a long quest line. A 'To the Sky' edition also exists." },
    { "All the Mods", "ATM 10", "All the Mods 10 targets Minecraft 1.21.1 on NeoForge, following the community's move from Forge to NeoForge. Like earlier packs, it ships with quests and a large modlist; a 'To the Sky' edition also exists." },
    { "All the Mods", "ATM 11", "All the Mods 11 is the newest numbered ATM release covered here. Because the loader and Minecraft version of new packs can change between updates, check its CurseForge page for the target version, required Java and recommended memory before installing." },
    { "All the Mods", "Using ATM with CC:Tweaked", "Most ATM packs include CC:Tweaked and Advanced Peripherals, so computers can talk to machines. With a wired modem on a block you can often call peripheral.getMethods(name) to list what it exposes.\n\nIdeas: read a reactor or energy core with the Reactor Monitor and Energy Core apps, watch autocrafting with the Storage Monitor (RS Bridge from Advanced Peripherals), or show everything on a monitor wall with best-fit resolution." },

    { "Computercraft", "CC:Tweaked basics", "CC:Tweaked adds Computers, Advanced Computers (colour), Turtles, Monitors, Speakers, Disk Drives and Modems. Programs are written in Lua; the 'startup' file runs on boot.\n\nUseful APIs: term, window, peripheral, os.pullEvent, fs, http, textutils, parallel and redstone. Peripherals attach directly or through wired modems; call methods with peripheral.call(name, method, ...)." },
  }

  local function lines(text, w)
    local out = {}
    for para in (text .. "\n"):gmatch("(.-)\n") do
      if para == "" then out[#out + 1] = ""
      else
        local line = ""
        for word in para:gmatch("%S+") do
          if #line + #word + 1 > w and #line > 0 then out[#out + 1] = line; line = word
          else line = (#line > 0 and (line .. " ") or "") .. word end
        end
        if #line > 0 then out[#out + 1] = line end
      end
    end
    return out
  end

  local function urlenc(s) return (s:gsub("[^%w%-_%.~]", function(c) return string.format("%%%02X", c:byte()) end)) end

  function app.init(win)
    win.state = { sel = 1, nav = 0, body = 0, search = OS.field("", { placeholder = "Search..." }), online = nil, busy = false }
  end

  local function visible(s)
    local q = s.search.text:lower()
    local out = {}
    for i, a in ipairs(A) do
      if q == "" or a[2]:lower():find(q, 1, true) or a[3]:lower():find(q, 1, true) then out[#out + 1] = i end
    end
    return out
  end

  local function lookup(s)
    local q = s.search.text
    if q == "" then OS.toast("Type a topic in the search box first"); return end
    if not http then OS.toast("HTTP is disabled on this server"); return end
    s.busy = true
    OS.http("https://en.wikipedia.org/api/rest_v1/page/summary/" .. urlenc((q:gsub(" ", "_"))), function(data, err)
      s.busy = false
      if not data then s.online = { title = q, text = "Could not load: " .. tostring(err) }; return end
      local ok, j = pcall(textutils.unserialiseJSON, data)
      if ok and type(j) == "table" and j.extract then s.online = { title = j.title or q, text = j.extract }
      else s.online = { title = q, text = "No article found for '" .. q .. "'." } end
      s.sel = 0; s.body = 0
    end)
  end

  function app.draw(win, g)
    local s = win.state
    local w, h = g.w, g.h
    g.fill(1, 1, w, h, C.win)
    local lw = math.min(24, math.floor(w * 0.38))
    g.fill(1, 1, lw, h, C.bar)
    g.field(1, 1, lw, s.search, { bg = C.sp2 })
    local vis = visible(s)
    local rows = h - 3
    s.nav = math.max(0, math.min(s.nav, math.max(0, #vis - rows)))
    local lastGroup
    local y = 2
    -- build list rows with group headers
    local items = {}
    for _, i in ipairs(vis) do
      if A[i][1] ~= lastGroup then lastGroup = A[i][1]; items[#items + 1] = { head = lastGroup } end
      items[#items + 1] = { i = i }
    end
    local maxNav = math.max(0, #items - rows)
    s.nav = math.min(s.nav, maxNav)
    for k = 1, rows do
      local it = items[k + s.nav]
      if not it then break end
      if it.head then g.put(2, y, OS.trunc(it.head:upper(), lw - 2), C.sub, C.bar)
      else
        local on = s.sel == it.i
        g.fill(1, y, lw, 1, on and C.acc or C.bar)
        g.put(2, y, OS.trunc(A[it.i][2], lw - 2), on and C.wht or C.text, on and C.acc or C.bar)
        g.hot(1, y, lw, 1, function() s.sel = it.i; s.body = 0 end)
      end
      y = y + 1
    end
    g.scroll(1, 2, lw, rows, function(d) s.nav = math.max(0, math.min(maxNav, s.nav + d)) end)
    g.btn(2, h, s.busy and "Loading..." or "Wikipedia", function() lookup(s) end, "pri")

    local x = lw + 2
    local bw = w - x
    local title, text
    if s.sel == 0 and s.online then title, text = s.online.title .. " (Wikipedia)", s.online.text
    elseif A[s.sel] then title, text = A[s.sel][2], A[s.sel][3]
    else title, text = "BerielPedia", "Pick an article on the left, or type a topic and press Wikipedia to fetch a summary online." end
    g.put(x, 1, OS.trunc(title, bw), C.acc, C.win)
    local L = lines(text, bw)
    local vrows = h - 2
    local maxB = math.max(0, #L - vrows)
    s.body = math.max(0, math.min(s.body, maxB))
    for k = 1, vrows do
      local l = L[k + s.body]
      if not l then break end
      g.put(x, 2 + k, l, C.text, C.win)
    end
    g.scroll(lw + 1, 2, w - lw, h - 1, function(d) s.body = math.max(0, math.min(maxB, s.body + d * 2)) end)
    if maxB > 0 then g.put(w, 3 + math.floor((vrows - 2) * s.body / maxB), "|", C.acc, C.win) end
  end

  return app
end

end)()
local unpack = unpack or table.unpack
local BASE, DATA = "/win10", "/win10/data"
local MIGRATED = false
-- upgrading from the Fedora version: move its folder so the account, saves and installed programs are kept
pcall(function()
  if fs.exists("/fedora") and fs.isDir("/fedora") and not fs.exists(BASE) then fs.move("/fedora", BASE); MIGRATED = true end
end)
-- free space taken by older versions's backup files
for _, n in ipairs({ BASE .. "/startup.bak", BASE .. "/startup.new" }) do pcall(fs.delete, n) end
fs.makeDir(DATA)
local dfpwm = require("cc.audio.dfpwm")

local OS = { VERSION = "Windows 10", apps = {}, wins = {}, mods = {}, timers = {}, pending = {}, mode = "boot", dockOrder = { "launchpad", "files", "terminal", "editor", "music", "store", "settings" } }
local cfg, parent, T, W, H

-- 16 palette slots, each given a semantic meaning
local C = { desk = colors.black, win = colors.white, bar = colors.lightGray, text = colors.gray,
  sub = colors.lightBlue, acc = colors.blue, dock = colors.cyan, red = colors.red, yel = colors.yellow,
  grn = colors.green, sp2 = colors.orange, sp = colors.lime, wp = colors.magenta, wht = colors.pink,
  sp0 = colors.purple, sp1 = colors.brown }
OS.C = C

local THEMES = {
  { name = "Windows 10", acc = 0x0078D7, dk = 0x6FBCF7, lt = 0x99C9F2, desk = 0x03122F, win = 0x1F1F1F, bar = 0x2D2D2D, dock = 0x151515, text = 0xFFFFFF, sub = 0xA0A0A0 },
  { name = "Windows 10 Light", acc = 0x0078D7, dk = 0x9AD0FA, lt = 0xCCE4F7, desk = 0x0A3E86, win = 0xFFFFFF, bar = 0xE6E6E6, dock = 0xF2F2F2, text = 0x000000, sub = 0x5E5E5E },
  { name = "Merlot",   acc = 0xB3264A, dk = 0x4A0F22, lt = 0xE8A0B4 },
  -- special theme: the accent and wallpaper tint cycle through the rainbow
  { name = "RGB", rgb = true, acc = 0xFF2040, dk = 0x1A1A24, lt = 0xFFFFFF, desk = 0x0A0A10, win = 0x15151D, bar = 0x1F1F2A, dock = 0x2A2A38, text = 0xF0F0F8, sub = 0x9A9AB0 },
  { name = "Burgundy", acc = 0x9B1B30, dk = 0x3A0A16, lt = 0xD98A9A },
  { name = "Rose Wine", acc = 0xD9577A, dk = 0x5C1D33, lt = 0xF2B8C8 },
  { name = "Port",     acc = 0x8A3FA0, dk = 0x2E1240, lt = 0xC9A0D8 },
  { name = "Sangria",  acc = 0xE0603A, dk = 0x5A1A1A, lt = 0xF5B49A },
  { name = "Chardonnay", acc = 0xC9A24A, dk = 0x4A3A12, lt = 0xEBD9A0 },
  { name = "Midnight", acc = 0x4C7DFF, dk = 0x0E1A44, lt = 0xA9BCFF, desk = 0x070B18, win = 0x0F1527, bar = 0x18203A, dock = 0x1F2A4D, text = 0xE6EBFA, sub = 0x8D99C0 },
  { name = "Ocean",    acc = 0x1CA3C4, dk = 0x08334A, lt = 0x9ADBEA, desk = 0x06161E, win = 0x0C2733, bar = 0x14394A, dock = 0x1A4A5E, text = 0xE3F4F8, sub = 0x86AFBC },
  { name = "Forest",   acc = 0x3FA55A, dk = 0x14361E, lt = 0xA3DDB2, desk = 0x08130B, win = 0x10231A, bar = 0x193325, dock = 0x214530, text = 0xE6F3E9, sub = 0x8FB39A },
  { name = "Amethyst", acc = 0x9B59D6, dk = 0x2D1B45, lt = 0xD2B4EE, desk = 0x100A1A, win = 0x1D1430, bar = 0x2A1D44, dock = 0x372757, text = 0xF0E8FA, sub = 0xA997C4 },
  { name = "Sunset",   acc = 0xF0803C, dk = 0x4A1F18, lt = 0xF8C09A, desk = 0x1A0C0A, win = 0x2B1612, bar = 0x3B201A, dock = 0x4D2A22, text = 0xFBEDE6, sub = 0xC09A8C },
  { name = "Mocha",    acc = 0xC08552, dk = 0x3A2518, lt = 0xE6C4A0, desk = 0x140E0A, win = 0x221813, bar = 0x30241C, dock = 0x403126, text = 0xF2E9E0, sub = 0xB09E8C },
  { name = "Nord",     acc = 0x88C0D0, dk = 0x2E3440, lt = 0xC8E2EA, desk = 0x20242E, win = 0x2E3440, bar = 0x3B4252, dock = 0x434C5E, text = 0xECEFF4, sub = 0x9AA5B8 },
  { name = "Dracula",  acc = 0xBD93F9, dk = 0x282A36, lt = 0xDCC8FC, desk = 0x1B1C26, win = 0x282A36, bar = 0x343746, dock = 0x44475A, text = 0xF8F8F2, sub = 0x9AA0C8 },
  { name = "Graphite", acc = 0x8A94A6, dk = 0x20242A, lt = 0xC6CCD8, desk = 0x0E1013, win = 0x1A1D22, bar = 0x252932, dock = 0x2F3440, text = 0xE8EAED, sub = 0x8E949E },
  { name = "Mint",     acc = 0x2ECC9A, dk = 0x0F3A2E, lt = 0xA0EAD0, desk = 0x07140F, win = 0x0F221B, bar = 0x173229, dock = 0x1F4438, text = 0xE6F7F0, sub = 0x8DBBA8 },
  { name = "Crimson",  acc = 0xE0243C, dk = 0x45101A, lt = 0xF2A0AC, desk = 0x150508, win = 0x240B10, bar = 0x33121A, dock = 0x451A24, text = 0xFAE8EA, sub = 0xC48A92 },
  { name = "Gold",     acc = 0xE0B030, dk = 0x3F3010, lt = 0xF2DC98, desk = 0x140F05, win = 0x231B0A, bar = 0x32270F, dock = 0x433415, text = 0xFBF3DF, sub = 0xBBA678 },
}
OS.THEMES = THEMES
OS.WALLS = { "Windows", "Diagonal", "Aurora", "Solid", "Image" }

----------------------------------------------------------------------- config
local function defaults()
  return { pkgs = {}, dark = true, darker = false, dnd = false, night = false, city = "", ctl = false, custom = {}, rgb = { speed = 3 },
    lp = { order = {}, hide = {}, flat = false }, theme = "Windows 10", snd = { sfx = true, music = true, sys = true, amb = true, vol = 0.6 }, wall = 1, user = nil, host = "DESKTOP-CC", monitor = false, scale = 0.5,
    music = { vol = 0.5, converter = "", loop = false, off = {}, liked = {},
      search = { { kind = "piped", url = "https://pipedapi.kavin.rocks" }, { kind = "invidious", url = "https://yewtu.be" } } } }
end
local function loadCfg()
  local c = defaults()
  if fs.exists(DATA .. "/config.lua") then
    local f = fs.open(DATA .. "/config.lua", "r")
    local d = textutils.unserialize(f.readAll()); f.close()
    if type(d) == "table" then
      for k, v in pairs(d) do
        if (k == "music" or k == "snd" or k == "lp" or k == "rgb") and type(v) == "table" then for k2, v2 in pairs(v) do c[k][k2] = v2 end else c[k] = v end
      end
    end
  end
  return c
end
cfg = loadCfg()
if MIGRATED then
  cfg.theme = "Windows 10"; cfg.wall = 1
  if cfg.host == ("fed" .. "ora") then cfg.host = "DESKTOP-CC" end
  for _, p in ipairs(cfg.pkgs or {}) do
    if type(p.file) == "string" then p.file = (p.file:gsub("^/fedora/", "/win10/")) end
  end
end
OS.cfg = cfg
function OS.save()
  local ok = pcall(function()
    local f = fs.open(DATA .. "/config.lua", "w")
    if not f then error("cannot open config") end
    f.write(textutils.serialize(cfg)); f.close()
  end)
  if ok then OS.dirty = false else OS.dirty = false; if OS.toast then OS.toast("Could not save settings (disk full?)", 4) end end
end

----------------------------------------------------------------------- helpers
function OS.fmtTime(s) s = math.max(0, s or 0); return string.format("%d:%02d", math.floor(s / 60), math.floor(s % 60)) end
local MONTHS = { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" }
local DAYNAMES = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }
-- broken-down time for a UTC epoch (seconds), honouring the Time settings (auto = the computer's own zone)
function OS.fromUtc(sec)
  local tc = cfg.time or {}
  if tc.tz then return os.date("!*t", math.floor(sec + tc.tz * 3600)) end
  return os.date("*t", math.floor(sec + (os.epoch("local") - os.epoch("utc")) / 1000))
end
local function nowT()
  local ok, t = pcall(function() return OS.fromUtc(os.epoch("utc") / 1000) end)
  if ok and type(t) == "table" and t.year then return t end
  local h = os.time()
  return { year = 2026, month = 1, day = 1, hour = math.floor(h) % 24, min = math.floor((h - math.floor(h)) * 60), wday = 1 }
end
-- the zone the computer itself uses, in hours from UTC (what "Automatic" currently means)
function OS.autoOffset()
  local ok, v = pcall(function()
    local u = os.epoch("utc") / 1000
    local a = os.date("*t", math.floor(u + (os.epoch("local") - os.epoch("utc")) / 1000))
    local b = os.date("!*t", math.floor(u))
    local d = (a.hour * 60 + a.min) - (b.hour * 60 + b.min)
    while d > 14 * 60 do d = d - 1440 end
    while d <= -12 * 60 do d = d + 1440 end
    return math.floor(d / 30 + 0.5) / 2
  end)
  return ok and v or 0
end
local function daysIn(y, m)
  if m == 2 and ((y % 4 == 0 and y % 100 ~= 0) or y % 400 == 0) then return 29 end
  return ({ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 })[m]
end
local function wdayOf(y, m, d) -- 0 = Sunday
  local t = { 0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4 }
  if m < 3 then y = y - 1 end
  return (y + math.floor(y / 4) - math.floor(y / 100) + math.floor(y / 400) + t[m] + d) % 7
end
-- Minecraft (in-game) day and time, e.g. "Day 12 06:30"
function OS.mcStr()
  local ok, str = pcall(function()
    local h = os.time("ingame")
    local hh, mm = math.floor(h) % 24, math.floor((h - math.floor(h)) * 60)
    local tm
    if cfg.time and cfg.time.h12 then
      local x = hh % 12; if x == 0 then x = 12 end
      tm = string.format("%d:%02d %s", x, mm, hh < 12 and "AM" or "PM")
    else tm = string.format("%02d:%02d", hh, mm) end
    return "Day " .. os.day("ingame") .. " " .. tm
  end)
  return ok and str or "Day ?"
end
function OS.clockStr(force24)
  local t = nowT()
  if not force24 and cfg.time and cfg.time.h12 then
    local h = t.hour % 12; if h == 0 then h = 12 end
    return string.format("%d:%02d %s", h, t.min, t.hour < 12 and "AM" or "PM")
  end
  return string.format("%02d:%02d", t.hour, t.min)
end
function OS.timer(sec, fn) local id = os.startTimer(sec); OS.timers[id] = fn; return id end
function OS.size() return W, H end
-- ordered list of displays that take part in a joined desktop ("term" = the computer's own screen)
function OS.displayIds()
  local main = OS.parentName or "term"
  local set, list = { [main] = true }, {}
  for name, on in pairs(cfg.mirror or {}) do
    if on and name ~= main and peripheral.isPresent(name) and peripheral.getType(name) == "monitor" then set[name] = true end
  end
  for _, n in ipairs(cfg.spanOrder or {}) do if set[n] then list[#list + 1] = n; set[n] = nil end end
  local rest = {}
  for n in pairs(set) do rest[#rest + 1] = n end
  table.sort(rest, function(a, b) if a == main then return true elseif b == main then return false end return a < b end)
  for _, n in ipairs(rest) do list[#list + 1] = n end
  return list
end
function OS.trunc(s, n) s = tostring(s); if n <= 0 then return "" end if #s > n then return s:sub(1, math.max(0, n - 1)) .. "~" end return s end
function OS.clean(s) return (tostring(s or ""):gsub("[\128-\255]+", "?"):gsub("[%c]", " ")) end
function OS.wrap(s, width)
  local out = {}
  width = math.max(4, width)
  for line in (tostring(s) .. "\n"):gmatch("(.-)\n") do
    if #line == 0 then out[#out + 1] = "" end
    while #line > 0 do out[#out + 1] = line:sub(1, width); line = line:sub(width + 1) end
  end
  return out
end
function OS.toast(msg, secs) if cfg and cfg.dnd and (secs or 3) < 5 then return end if OS.sfx then OS.sfx("toast") end OS.toastMsg = { s = tostring(msg), t = os.clock() + (secs or 3) } end

-- async http: cb(data, err)
function OS.http(url, cb, headers)
  OS.pending[url] = cb
  http.request(url, nil, headers, true)
  OS.timer(25, function() if OS.pending[url] == cb then OS.pending[url] = nil; cb(nil, "timeout") end end)
end

----------------------------------------------------------------------- sha256 (password hashing)
local K, H0 = {}, {}
do
  local n, count = 2, 0
  while count < 64 do
    local isp = true
    for d = 2, math.floor(math.sqrt(n)) do if n % d == 0 then isp = false break end end
    if isp then
      count = count + 1
      local c3, c2 = n ^ (1 / 3), n ^ (1 / 2)
      K[count] = math.floor((c3 - math.floor(c3)) * 2 ^ 32)
      if count <= 8 then H0[count] = math.floor((c2 - math.floor(c2)) * 2 ^ 32) end
    end
    n = n + 1
  end
end
local function sha256(msg)
  local band, bxor, bnot, rsh, rrot = bit32.band, bit32.bxor, bit32.bnot, bit32.rshift, bit32.rrotate
  local len = #msg
  local bits = len * 8
  msg = msg .. "\128" .. ("\0"):rep((55 - len) % 64) .. "\0\0\0\0" ..
    string.char(band(rsh(bits, 24), 255), band(rsh(bits, 16), 255), band(rsh(bits, 8), 255), band(bits, 255))
  local Hs = { unpack(H0) }
  local w = {}
  for chunk = 1, #msg, 64 do
    for i = 0, 15 do
      local a, b, c, d = msg:byte(chunk + i * 4, chunk + i * 4 + 3)
      w[i] = a * 16777216 + b * 65536 + c * 256 + d
    end
    for i = 16, 63 do
      local s0 = bxor(rrot(w[i - 15], 7), rrot(w[i - 15], 18), rsh(w[i - 15], 3))
      local s1 = bxor(rrot(w[i - 2], 17), rrot(w[i - 2], 19), rsh(w[i - 2], 10))
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) % 4294967296
    end
    local a, b, c, d, e, f, g, h = Hs[1], Hs[2], Hs[3], Hs[4], Hs[5], Hs[6], Hs[7], Hs[8]
    for i = 0, 63 do
      local S1 = bxor(rrot(e, 6), rrot(e, 11), rrot(e, 25))
      local ch = bxor(band(e, f), band(bnot(e), g))
      local t1 = (h + S1 + ch + K[i + 1] + w[i]) % 4294967296
      local S0 = bxor(rrot(a, 2), rrot(a, 13), rrot(a, 22))
      local maj = bxor(band(a, b), band(a, c), band(b, c))
      local t2 = (S0 + maj) % 4294967296
      h = g; g = f; f = e; e = (d + t1) % 4294967296; d = c; c = b; b = a; a = (t1 + t2) % 4294967296
    end
    Hs[1] = (Hs[1] + a) % 4294967296; Hs[2] = (Hs[2] + b) % 4294967296; Hs[3] = (Hs[3] + c) % 4294967296; Hs[4] = (Hs[4] + d) % 4294967296
    Hs[5] = (Hs[5] + e) % 4294967296; Hs[6] = (Hs[6] + f) % 4294967296; Hs[7] = (Hs[7] + g) % 4294967296; Hs[8] = (Hs[8] + h) % 4294967296
  end
  return string.format("%08x%08x%08x%08x%08x%08x%08x%08x", unpack(Hs))
end
OS.sha256 = sha256
function OS.hashPw(pw, salt)
  local h = sha256(salt .. pw)
  for _ = 1, 63 do h = sha256(h .. salt) end
  return h
end
function OS.newSalt()
  math.randomseed(os.epoch("utc") + math.floor(os.clock() * 1000))
  local t = {}
  for i = 1, 16 do t[i] = string.format("%x", math.random(0, 15)) end
  return table.concat(t)
end

----------------------------------------------------------------------- startup protection
-- /startup.lua IS this OS. Programs that try to write, move or delete it (or /startup/) are redirected
-- into /win10/redirect/ instead, so installing a program that ships its own startup file can't break the system.
local realFs, realIo = fs, io
local REDIR = BASE .. "/redirect"
function OS.isProtected(p)
  local ok, n = pcall(realFs.combine, "/", tostring(p or ""))
  if not ok then return false end
  return n == "startup.lua" or n == "startup" or n:sub(1, 8) == "startup/"
end
function OS.fsp(p)
  if type(p) ~= "string" or not OS.isProtected(p) then return p end
  if not OS.redirNote and OS.toast then
    OS.redirNote = true
    OS.toast("A program touched /startup.lua (the OS). Redirected to " .. REDIR, 6)
  end
  return REDIR .. "/" .. realFs.combine("/", p)
end
local function ensureDir(q) pcall(realFs.makeDir, realFs.getDir(q)) end
function OS.guardFs()
  local G = {}
  for _, n in ipairs({ "exists", "isDir", "isReadOnly", "getSize", "delete", "makeDir", "attributes", "getDrive", "list" }) do
    G[n] = function(p, ...) return realFs[n](OS.fsp(p), ...) end
  end
  function G.open(p, mode, ...)
    local q = OS.fsp(p)
    if q ~= p and tostring(mode):find("[wa]") then ensureDir(q) end
    return realFs.open(q, mode, ...)
  end
  function G.move(a, b) local q = OS.fsp(b); if q ~= b then ensureDir(q) end return realFs.move(OS.fsp(a), q) end
  function G.copy(a, b) local q = OS.fsp(b); if q ~= b then ensureDir(q) end return realFs.copy(OS.fsp(a), q) end
  return setmetatable(G, { __index = realFs })
end
function OS.guardIo()
  local G = {}
  function G.open(p, ...)
    local q = OS.fsp(p)
    if q ~= p then ensureDir(q) end
    return realIo.open(q, ...)
  end
  function G.lines(p, ...) return realIo.lines(OS.fsp(p), ...) end
  return setmetatable(G, { __index = realIo })
end
function OS.guardShell(real)
  if not real then return nil end
  local function fixArg(a)
    local ok, r = pcall(real.resolve, tostring(a))
    if ok and OS.isProtected(r) then return OS.fsp(r) end
    return a
  end
  local G = {}
  function G.run(...)
    local out, first = {}, true
    for tok in table.concat({ ... }, " "):gmatch("%S+") do
      out[#out + 1] = first and tok or fixArg(tok); first = false
    end
    return real.run(table.concat(out, " "))
  end
  function G.execute(cmd, ...)
    local args = { ... }
    for i, a in ipairs(args) do args[i] = fixArg(a) end
    return real.execute(cmd, table.unpack(args))
  end
  return setmetatable(G, { __index = real })
end
-- keep the OS file in memory (not on disk: CC computers only have ~1MB) and restore it if something overwrites it
function OS.watchStartup(init)
  if init then
    local me = shell and shell.getRunningProgram and shell.getRunningProgram() or nil
    if not me or not OS.isProtected(me) or not realFs.exists(me) or realFs.isDir(me) then OS.me = nil return end
    OS.me = "/" .. realFs.combine("/", me)
    OS.meSize = realFs.getSize(OS.me)
    local f = realFs.open(OS.me, "rb")
    if f then OS.selfCopy = f.readAll(); f.close() end
    return
  end
  if not OS.me or not OS.selfCopy then return end
  if not realFs.exists(OS.me) or realFs.getSize(OS.me) ~= OS.meSize then
    pcall(realFs.delete, OS.me)
    local f = realFs.open(OS.me, "wb")
    if f then f.write(OS.selfCopy); f.close(); OS.toast("Something overwrote /startup.lua - the OS was restored", 6) end
  end
end

-- system updates (the only code allowed to replace /startup.lua). Only one old copy is kept on disk.
function OS.installSystem(data)
  local me = OS.me or "/startup.lua"
  local prev = BASE .. "/startup.prev"
  pcall(realFs.delete, prev)
  local cur = realFs.exists(me) and realFs.getSize(me) or 0
  local free = realFs.getFreeSpace("/")
  -- need room for the new file once the old one is gone
  if free + cur < #data + 4096 then
    return false, string.format("not enough disk space: need %dK, have %dK (delete files in Files)", math.ceil((#data + 4096) / 1024), math.floor((free + cur) / 1024))
  end
  -- keep a rollback copy only if it fits next to the new file
  local keep = cur > 0 and free >= cur + 4096 and (free - cur) + cur >= #data + 4096
  if keep then pcall(realFs.copy, me, prev) end
  local oldData = OS.selfCopy
  pcall(realFs.delete, me)
  local f = realFs.open(me, "wb")
  local ok = f ~= nil
  if f then ok = pcall(f.write, data); pcall(f.close) end
  if not ok or realFs.getSize(me) ~= #data then
    pcall(realFs.delete, me)
    if realFs.exists(prev) then pcall(realFs.move, prev, me)
    elseif oldData then
      local g = realFs.open(me, "wb")
      if g then g.write(oldData); g.close() end
    end
    return false, "write failed (disk full?) - old version restored"
  end
  OS.me = me; OS.meSize = #data; OS.selfCopy = data
  return true
end
function OS.rollbackSystem()
  local me = OS.me or "/startup.lua"
  local prev = BASE .. "/startup.prev"
  if not realFs.exists(prev) then return false, "no previous version saved" end
  pcall(realFs.delete, me)
  local ok, err = pcall(realFs.move, prev, me)
  if not ok then return false, tostring(err) end
  OS.me = me; OS.meSize = realFs.getSize(me); OS.selfCopy = nil
  return true
end

----------------------------------------------------------------------- display / theme
function OS.findTheme(name)
  for _, t in ipairs(THEMES) do if t.name == name then return t end end
  for _, t in ipairs(cfg.custom or {}) do if t.name == name then return t end end
end
function OS.hsv(h)
  local i = math.floor(h * 6); local f = h * 6 - i; local q = 1 - f
  local r, g, b
  i = i % 6
  if i == 0 then r, g, b = 1, f, 0 elseif i == 1 then r, g, b = q, 1, 0 elseif i == 2 then r, g, b = 0, 1, f
  elseif i == 3 then r, g, b = 0, q, 1 elseif i == 4 then r, g, b = f, 0, 1 else r, g, b = 1, 0, q end
  return math.floor(r * 255) * 65536 + math.floor(g * 255) * 256 + math.floor(b * 255)
end
OS.WSLOT = { "wp", "sp", "sp0", "sp1" }
local WSLOT = OS.WSLOT
function OS.applyTheme()
  local th = OS.findTheme(cfg.theme) or THEMES[1]
  local acc, wpd = th.acc, th.dk
  if th.rgb then
    acc = OS.hsv((os.clock() * 0.02 * ((cfg.rgb and cfg.rgb.speed) or 3)) % 1)
    local r, g, b = math.floor(acc / 65536) % 256, math.floor(acc / 256) % 256, acc % 256
    wpd = math.floor(r * 0.3) * 65536 + math.floor(g * 0.3) * 256 + math.floor(b * 0.3)
  end
  cfg.dark = true
  local k = cfg.darker and 0.55 or 1
  local function dim(c) local r, g, b = math.floor(c / 65536) % 256, math.floor(c / 256) % 256, c % 256
    return math.floor(r * k) * 65536 + math.floor(g * k) * 256 + math.floor(b * k) end
  local pal = {
    desk = dim(th.desk or 0x101216), win = dim(th.win or 0x1F1F1F), bar = dim(th.bar or 0x2D2D2D),
    text = th.text or 0xFFFFFF, sub = th.sub or 0xA0A0A0, acc = acc, dock = dim(th.dock or 0x151515),
    red = 0xE81123, yel = 0xFFB900, grn = 0x13A10E, sp2 = dim(0x2B2B2B), sp = 0x1DB954,
    wp = cfg.darker and dim(wpd) or wpd, wht = 0xFFFFFF, sp0 = cfg.darker and 0x000000 or 0x0C0C0C, sp1 = 0x8B5A2B,
  }
  if OS.palOver then for k, v in pairs(OS.palOver) do pal[k] = v end end
  -- a picture wallpaper borrows four palette slots for its own colours (unless the focused app needs them)
  if cfg.wall == 5 and OS.wallPal and OS.wallImg and not OS.palOver then
    for k, key in ipairs(WSLOT) do if OS.wallPal[k] then pal[key] = cfg.darker and dim(OS.wallPal[k]) or OS.wallPal[k] end end
  end
  if cfg.night then
    for k, c in pairs(pal) do
      pal[k] = math.floor(math.floor(c / 65536) % 256) * 65536 + math.floor((math.floor(c / 256) % 256) * 0.85) * 256 + math.floor((c % 256) * 0.55)
    end
  end
  OS.pal = pal
  for k, col in pairs(C) do
    parent.setPaletteColor(col, pal[k])
    T.setPaletteColor(col, pal[k])
    for _, m in pairs(OS.mirrors or {}) do pcall(m.setPaletteColor, col, pal[k]) end
  end
end

function OS.monitors()
  local list = {}
  for _, n in ipairs(peripheral.getNames()) do
    if peripheral.getType(n) == "monitor" then
      local m = peripheral.wrap(n)
      local ok, w, h = pcall(m.getSize)
      local okS, sc = pcall(m.getTextScale)
      if ok and w then
        sc = (okS and sc) or 1
        list[#list + 1] = { name = n, w = math.floor(w * sc / 0.5), h = math.floor(h * sc / 0.5) }
      end
    end
  end
  return list
end
function OS.bestFit()
  local best
  for _, m in ipairs(OS.monitors()) do if not best or m.w * m.h > best.w * best.h then best = m end end
  if not best then return false end
  cfg.monitor = true; cfg.monitorName = best.name; cfg.scale = 0.5
  OS.save(); OS.setupDisplay()
  return best
end

-- fingerprint of everything the joined layout depends on (used to notice changes while running)
function OS.spanSig()
  local parts = { tostring(cfg.spanCols), tostring(cfg.scale), tostring(cfg.spanMode) }
  for _, id in ipairs(OS.displayIds()) do
    local sc = (cfg.dscale or {})[id]
    parts[#parts + 1] = id .. ":" .. tostring(sc)
  end
  for name, on in pairs(cfg.mirror or {}) do if on and peripheral.isPresent(name) then parts[#parts + 1] = "m" .. name end end
  table.sort(parts)
  return table.concat(parts, "|")
end

function OS.setupDisplay()
  local native = term.native and term.native() or term.current()
  parent = native
  if cfg.monitor then
    local m
    if cfg.monitorName and peripheral.isPresent(cfg.monitorName) and peripheral.getType(cfg.monitorName) == "monitor" then
      m = peripheral.wrap(cfg.monitorName)
    else m = peripheral.find("monitor") end
    if m then
      parent = m; m.setTextScale(cfg.scale or 0.5)
      OS.parentName = (cfg.monitorName and peripheral.isPresent(cfg.monitorName)) and cfg.monitorName or nil
      if not OS.parentName then
        for _, n in ipairs(peripheral.getNames()) do if peripheral.getType(n) == "monitor" then OS.parentName = n break end end
      end
    end
  end
  if parent == native then OS.parentName = nil end
  local okS, pw, ph = pcall(parent.getSize)
  if not okS or type(pw) ~= "number" or type(ph) ~= "number" or pw < 1 or ph < 1 then
    parent = native; OS.parentName = nil
    pw, ph = parent.getSize()
  end
  W, H = pw, ph
  -- span: several monitors act as one wide desktop (left to right)
  OS.span = nil
  local extras = {}
  for name, on in pairs(cfg.mirror or {}) do
    if on and name ~= OS.parentName and peripheral.isPresent(name) and peripheral.getType(name) == "monitor" then extras[#extras + 1] = name end
  end
  table.sort(extras)
  if cfg.spanMode and #extras > 0 then
    local segs = {}
    local function add(name, m)
      pcall(m.setTextScale, (cfg.dscale or {})[name or "term"] or cfg.scale or 0.5)
      local ok, w, h = pcall(m.getSize)
      if ok and w then segs[#segs + 1] = { m = m, name = name, w = w, h = h } end
    end
    -- the small computer screen only joins when there are fewer than two monitors
    local ids = OS.displayIds()
    local monIds = {}
    for _, id in ipairs(ids) do if id ~= "term" then monIds[#monIds + 1] = id end end
    local use = (#monIds >= 2) and monIds or ids
    for _, id in ipairs(use) do
      if id == "term" then add(nil, native)
      elseif id == OS.parentName then add(id, parent)
      else add(id, peripheral.wrap(id)) end
    end
    if #segs > 1 then
      -- grid layout: monitors fill rows left to right, `cols` per row (Auto: one row up to 3 monitors, else a roughly 3:2 wall)
      local n = #segs
      local cols = tonumber(cfg.spanCols) or (n <= 3 and n or math.max(2, math.floor(math.sqrt(1.5 * n) + 0.5)))
      cols = math.max(1, math.min(n, math.floor(cols)))
      local rows = math.ceil(n / cols)
      local colW, rowH = {}, {}
      for i, sg in ipairs(segs) do
        local r, c = math.floor((i - 1) / cols) + 1, (i - 1) % cols + 1
        sg.r, sg.c = r, c
        colW[c] = math.min(colW[c] or 1e9, sg.w)
        rowH[r] = math.min(rowH[r] or 1e9, sg.h)
      end
      local cx, ry = { 0 }, { 0 }
      for c = 1, cols do cx[c + 1] = cx[c] + (colW[c] or 0) end
      for r = 1, rows do ry[r + 1] = ry[r] + (rowH[r] or 0) end
      W, H = cx[cols + 1], ry[rows + 1]
      for _, sg in ipairs(segs) do
        sg.vx, sg.vy = cx[sg.c], ry[sg.r]
        sg.cw, sg.ch = colW[sg.c], rowH[sg.r]
        -- a monitor bigger than its cell shows the desktop centred in it
        sg.ox, sg.oy = math.floor((sg.w - sg.cw) / 2), math.floor((sg.h - sg.ch) / 2)
      end
      local hasTerm = false
      for _, sg in ipairs(segs) do if sg.name == nil then hasTerm = true end end
      local ids2 = {}
      for _, sg in ipairs(segs) do ids2[#ids2 + 1] = sg.name or "term" end
      -- which monitors cover each desktop row (so the flush never loops over every monitor for every row)
      local rowSegs = {}
      for y = 1, H do
        local list = {}
        for _, sg in ipairs(segs) do if y > sg.vy and y <= sg.vy + sg.ch then list[#list + 1] = sg end end
        rowSegs[y] = list
      end
      OS.span = { segs = segs, last = {}, termFree = not hasTerm, cols = cols, rows = rows, sig = OS.spanSig(), rowSegs = rowSegs }
      OS.spanPrimaryX0 = 0
      for _, sg in ipairs(segs) do if sg.name == OS.parentName then OS.spanPrimaryX0 = sg.vx - sg.ox end end
    end
  end
  T = window.create(parent, 1, 1, W, H, false)
  OS.wallCache = nil
  if OS.place then OS.place.dirty = true end
  -- extra monitors that mirror the desktop
  OS.mirrors = {}
  OS.mirrorLast = {}
  OS.mirrorOff = {}
  for name, on in pairs(cfg.mirror or {}) do
    if OS.span and on and name ~= OS.parentName and peripheral.isPresent(name) and peripheral.getType(name) == "monitor" then
      OS.mirrors[name] = peripheral.wrap(name); OS.mirrorOff[name] = { 0, 0 }
    elseif on and peripheral.isPresent(name) and peripheral.getType(name) == "monitor" then
      local m = peripheral.wrap(name)
      if name ~= OS.parentName then
        local off = { 0, 0 }
        if cfg.mirrorFit ~= false then
          -- stretch: pick the biggest text scale at which the whole desktop still fits, then centre it
          local mw, mh
          for _, sc in ipairs({ 5, 4, 3, 2.5, 2, 1.5, 1, 0.5 }) do
            pcall(m.setTextScale, sc)
            mw, mh = m.getSize()
            if mw >= W and mh >= H then break end
          end
          off = { math.max(0, math.floor((mw - W) / 2)), math.max(0, math.floor((mh - H) / 2)) }
        else pcall(m.setTextScale, cfg.scale or 0.5) end
        OS.mirrors[name] = m
        OS.mirrorOff[name] = off
      end
    end
  end
  OS.applyTheme()
  -- the computer's own screen is not used when the desktop lives on monitors
  if parent ~= native and not OS.span then
    pcall(function()
      native.setBackgroundColor(colors.black); native.setTextColor(colors.white); native.clear()
      native.setCursorPos(1, 1); native.write("Windows 10 is running on a monitor.")
      native.setCursorPos(1, 3); native.write("Keyboard works here.")
    end)
  end
  for _, win in ipairs(OS.wins) do
    win.w = math.min(win.w, W); win.h = math.min(win.h, H - 1)
    win.x = math.max(1, math.min(win.x, W - win.w + 1)); win.y = math.max(1, math.min(win.y, H - win.h))
  end
  if not OS.place and not OS.idUntil and OS.clearUnused then OS.clearUnused() end
end

local function put(x, y, s, fg, bg)
  if y < 1 or y > H then return end
  if x < 1 then s = s:sub(2 - x); x = 1 end
  if x + #s - 1 > W then s = s:sub(1, W - x + 1) end
  if #s == 0 then return end
  T.setCursorPos(x, y)
  T.setTextColor(fg or C.text)
  T.setBackgroundColor(bg or C.win)
  T.write(s)
end

local function under(x, y)
  if x < 1 or x > W or y < 1 or y > H then return C.desk end
  local ok, _, _, b = pcall(T.getLine, y)
  if ok and b then
    local n = tonumber(b:sub(x, x), 16)
    if n then return math.floor(2 ^ n) end
  end
  return C.desk
end

-- rounded rectangle using teletext sub-pixel corner cells
local function roundBox(x, y, w, h, bg, topbg)
  topbg = topbg or bg
  local tl, tr, bl, br = under(x, y), under(x + w - 1, y), under(x, y + h - 1), under(x + w - 1, y + h - 1)
  local row = (" "):rep(w)
  for j = 0, h - 1 do put(x, y + j, row, C.text, j == 0 and topbg or bg) end
  if h == 1 then return end
  put(x, y, "\129", tl, topbg); put(x + w - 1, y, "\130", tr, topbg)
  put(x, y + h - 1, "\144", bl, bg); put(x + w - 1, y + h - 1, "\159", br, bg)
end
OS.roundBox = roundBox

-- flat rectangle: Windows 10 has square corners
local box = function(x, y, w, h, bg)
  if w <= 0 then return end
  local row = (" "):rep(w)
  for j = 0, h - 1 do put(x, y + j, row, C.text, bg) end
end
OS.box = box
-- the four-pane Windows logo, three cells wide (2x3 teletext sub-pixels)
function OS.startLogo(x, y, logo, gap)
  put(x, y, "\140", gap, logo); put(x + 1, y, "\157", gap, logo); put(x + 2, y, "\145", logo, gap)
end
-- text drawn straight on the wallpaper (every letter keeps the colour that is under it)
function OS.wallText(x, y, s, fg)
  for i = 1, #s do put(x + i - 1, y, s:sub(i, i), fg, under(x + i - 1, y)) end
end
-- desktop shortcuts (double-click, or tap on a touch screen)
local DESK_NAMES = { files = "This PC", terminal = "Cmd", store = "Store", settings = "Settings", music = "Music" }
function OS.drawDesktopIcons()
  OS.deskIcons = {}
  if W < 30 then return end
  local list = cfg.desktop or { "files", "terminal", "store", "settings" }
  local y = 2
  for _, id in ipairs(list) do
    local a = OS.apps[id]
    if a and y + 2 <= H - 1 then
      local bg = C[a.icon or "acc"] or C.acc
      put(2, y, "     ", C.wht, bg)
      put(2, y + 1, " " .. tostring(a.glyph or " ? ") .. " ", C[a.fg or "wht"] or C.wht, bg)
      local lab = OS.trunc(DESK_NAMES[id] or a.title or id, 12)
      local lx = math.max(1, 4 - math.floor(#lab / 2))
      if OS.deskSel == id then put(lx, y + 2, lab, C.wht, C.acc) else OS.wallText(lx, y + 2, lab, C.wht) end
      OS.deskIcons[#OS.deskIcons + 1] = { x = 1, y = y, w = 7, h = 3, id = id }
      y = y + 4
    end
  end
end

----------------------------------------------------------------------- wallpaper

----------------------------------------------------------------------- image wallpaper (download a picture, draw it with 2x3 teletext sub-pixels)
local function inflate(s, pos)
  local band, rsh, lsh = bit32.band, bit32.rshift, bit32.lshift
  pos = pos + 2
  local bitbuf, bitcnt = 0, 0
  local out, on = {}, 0
  local function bits(n)
    while bitcnt < n do bitbuf = bitbuf + lsh(s:byte(pos) or 0, bitcnt); pos = pos + 1; bitcnt = bitcnt + 8 end
    local v = band(bitbuf, lsh(1, n) - 1)
    bitbuf = rsh(bitbuf, n); bitcnt = bitcnt - n
    return v
  end
  local function build(lens, n)
    local count, offs, sym = {}, {}, {}
    for i = 0, 15 do count[i] = 0 end
    for i = 1, n do count[lens[i]] = count[lens[i]] + 1 end
    offs[1] = 0
    for i = 1, 15 do offs[i + 1] = offs[i] + count[i] end
    for i = 1, n do local l = lens[i]; if l ~= 0 then sym[offs[l] + 1] = i - 1; offs[l] = offs[l] + 1 end end
    return { count = count, sym = sym }
  end
  local function decode(h)
    local code, first, index = 0, 0, 0
    for len = 1, 15 do
      code = code + bits(1)
      local cnt = h.count[len]
      if code - cnt < first then return h.sym[index + (code - first) + 1] end
      index = index + cnt; first = (first + cnt) * 2; code = code * 2
    end
    error("bad huffman code")
  end
  local lbase = { 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258 }
  local lext = { 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0 }
  local dbase = { 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577 }
  local dext = { 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13 }
  local clo = { 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 }
  local fixedL, fixedD
  repeat
    local last, typ = bits(1), bits(2)
    if typ == 0 then
      bitbuf, bitcnt = 0, 0
      local len = (s:byte(pos) or 0) + (s:byte(pos + 1) or 0) * 256
      pos = pos + 4
      for i = 0, len - 1 do on = on + 1; out[on] = s:byte(pos + i) or 0 end
      pos = pos + len
    elseif typ == 1 or typ == 2 then
      local lh, dh
      if typ == 1 then
        if not fixedL then
          local l = {}
          for i = 1, 144 do l[i] = 8 end
          for i = 145, 256 do l[i] = 9 end
          for i = 257, 280 do l[i] = 7 end
          for i = 281, 288 do l[i] = 8 end
          local d = {}
          for i = 1, 30 do d[i] = 5 end
          fixedL, fixedD = build(l, 288), build(d, 30)
        end
        lh, dh = fixedL, fixedD
      else
        local nlen, ndist, ncode = bits(5) + 257, bits(5) + 1, bits(4) + 4
        local cl = {}
        for i = 1, 19 do cl[i] = 0 end
        for i = 1, ncode do cl[clo[i] + 1] = bits(3) end
        local ch = build(cl, 19)
        local lens, i = {}, 1
        while i <= nlen + ndist do
          local sym = decode(ch)
          if sym < 16 then lens[i] = sym; i = i + 1
          else
            local rep, val = 0, 0
            if sym == 16 then val = lens[i - 1]; rep = 3 + bits(2)
            elseif sym == 17 then rep = 3 + bits(3)
            else rep = 11 + bits(7) end
            for _ = 1, rep do lens[i] = val; i = i + 1 end
          end
        end
        local l, d = {}, {}
        for k = 1, nlen do l[k] = lens[k] end
        for k = 1, ndist do d[k] = lens[nlen + k] end
        lh, dh = build(l, nlen), build(d, ndist)
      end
      while true do
        local sym = decode(lh)
        if sym < 256 then on = on + 1; out[on] = sym
        elseif sym == 256 then break
        else
          sym = sym - 256
          local len = lbase[sym] + bits(lext[sym])
          local ds = decode(dh) + 1
          local dist = dbase[ds] + bits(dext[ds])
          for _ = 1, len do on = on + 1; out[on] = out[on - dist] end
        end
      end
    else error("bad block") end
  until last == 1
  return out
end

local function decodePng(data)
  if data:sub(2, 4) ~= "PNG" then return nil, "not a PNG picture" end
  local function be(str, i) return ((str:byte(i) * 256 + str:byte(i + 1)) * 256 + str:byte(i + 2)) * 256 + str:byte(i + 3) end
  local pos, idat, w, h, depth, ctype, inter, pal = 9, {}, 0, 0, 0, 0, 0, nil
  while pos < #data do
    local len = be(data, pos)
    local typ = data:sub(pos + 4, pos + 7)
    local body = data:sub(pos + 8, pos + 7 + len)
    if typ == "IHDR" then w, h, depth, ctype, inter = be(body, 1), be(body, 5), body:byte(9), body:byte(10), body:byte(13)
    elseif typ == "PLTE" then pal = {}; for i = 1, #body - 2, 3 do pal[#pal + 1] = { body:byte(i), body:byte(i + 1), body:byte(i + 2) } end
    elseif typ == "IDAT" then idat[#idat + 1] = body
    elseif typ == "IEND" then break end
    pos = pos + 12 + len
  end
  if depth ~= 8 or inter ~= 0 then return nil, "unsupported PNG (need 8-bit, not interlaced)" end
  if w < 1 or h < 1 or w * h > 90000 then return nil, "picture is too big" end
  local bpp = ({ [0] = 1, [2] = 3, [3] = 1, [4] = 2, [6] = 4 })[ctype]
  if not bpp then return nil, "unsupported PNG type" end
  local raw = inflate(table.concat(idat), 1)
  local stride = w * bpp
  local prev, p = {}, 1
  for i = 1, stride do prev[i] = 0 end
  local R, G, B, L = {}, {}, {}, {}
  for y = 1, h do
    local ft = raw[p]; p = p + 1
    local cur = {}
    for i = 1, stride do
      local x = raw[p]; p = p + 1
      local a = (i > bpp) and cur[i - bpp] or 0
      local b = prev[i]
      local v
      if ft == 0 then v = x
      elseif ft == 1 then v = x + a
      elseif ft == 2 then v = x + b
      elseif ft == 3 then v = x + math.floor((a + b) / 2)
      else
        local cc = (i > bpp) and prev[i - bpp] or 0
        local pp = a + b - cc
        local pa, pb, pc = math.abs(pp - a), math.abs(pp - b), math.abs(pp - cc)
        v = x + ((pa <= pb and pa <= pc) and a or (pb <= pc and b or cc))
      end
      cur[i] = v % 256
    end
    for xx = 0, w - 1 do
      local o = xx * bpp
      local r, g, b
      if ctype == 0 or ctype == 4 then r = cur[o + 1]; g = r; b = r
      elseif ctype == 3 then local e = pal and pal[cur[o + 1] + 1] or { 0, 0, 0 }; r, g, b = e[1], e[2], e[3]
      else r, g, b = cur[o + 1], cur[o + 2], cur[o + 3] end
      local k = (y - 1) * w + xx + 1
      R[k], G[k], B[k] = r, g, b
      L[k] = (r * 0.3 + g * 0.59 + b * 0.11) / 255
    end
    prev = cur
  end
  return { w = w, h = h, r = R, g = G, b = B, lum = L }
end

-- colours of a decoded picture: the terminal only has 16 palette slots, so the picture gets 4 of them
-- (wp, sp, sp0, sp1), found by k-means, and every pixel is a dithered mix of two of those colours
local function prepWallImage(img)
  local n = #img.lum
  local K = 4
  local order = {}
  for i = 1, n do order[i] = i end
  table.sort(order, function(a, b) return img.lum[a] < img.lum[b] end)
  local cr, cg, cb = {}, {}, {}
  for k = 1, K do
    local i = order[math.max(1, math.min(n, math.floor(n * (k - 0.5) / K)))]
    cr[k], cg[k], cb[k] = img.r[i], img.g[i], img.b[i]
  end
  local assign = {}
  for _ = 1, 6 do
    local sr, sg, sb, cnt = {}, {}, {}, {}
    for k = 1, K do sr[k], sg[k], sb[k], cnt[k] = 0, 0, 0, 0 end
    for i = 1, n do
      local r, g, b = img.r[i], img.g[i], img.b[i]
      local best, bd = 1, 1e9
      for k = 1, K do
        local d = (r - cr[k]) ^ 2 + (g - cg[k]) ^ 2 + (b - cb[k]) ^ 2
        if d < bd then bd = d; best = k end
      end
      assign[i] = best
      sr[best] = sr[best] + r; sg[best] = sg[best] + g; sb[best] = sb[best] + b; cnt[best] = cnt[best] + 1
    end
    for k = 1, K do
      if cnt[k] > 0 then cr[k], cg[k], cb[k] = sr[k] / cnt[k], sg[k] / cnt[k], sb[k] / cnt[k] end
    end
  end
  -- every pixel = colour A mixed with colour B (t = how much B), the closest point on a line between two palette colours
  local pa, pb, pt = {}, {}, {}
  for i = 1, n do
    local r, g, b = img.r[i], img.g[i], img.b[i]
    local bestd, ba, bb, bt = 1e18, 1, 1, 0
    for p = 1, K do
      for q = p, K do
        local t, d = 0, 0
        if p == q then d = (r - cr[p]) ^ 2 + (g - cg[p]) ^ 2 + (b - cb[p]) ^ 2
        else
          local dr, dg, db = cr[q] - cr[p], cg[q] - cg[p], cb[q] - cb[p]
          local len2 = dr * dr + dg * dg + db * db
          if len2 > 0 then t = ((r - cr[p]) * dr + (g - cg[p]) * dg + (b - cb[p]) * db) / len2 end
          t = math.max(0, math.min(1, t))
          d = (r - (cr[p] + dr * t)) ^ 2 + (g - (cg[p] + dg * t)) ^ 2 + (b - (cb[p] + db * t)) ^ 2
        end
        if d < bestd then bestd = d; ba, bb, bt = p, q, t end
      end
    end
    pa[i], pb[i], pt[i] = ba, bb, bt
  end
  img.pa, img.pb, img.pt = pa, pb, pt
  local pal = {}
  for k = 1, K do
    pal[k] = math.floor(math.max(0, math.min(255, cr[k]))) * 65536 + math.floor(math.max(0, math.min(255, cg[k]))) * 256 + math.floor(math.max(0, math.min(255, cb[k])))
  end
  img.pal = pal
  img.dist = {}
  for p = 1, K do
    img.dist[p] = {}
    for q = 1, K do img.dist[p][q] = (cr[p] - cr[q]) ^ 2 + (cg[p] - cg[q]) ^ 2 + (cb[p] - cb[q]) ^ 2 end
  end
  OS.wallPal = pal
  return img
end

function OS.loadWallFile()
  if OS.wallImg or OS.wallTried then return end
  OS.wallTried = true
  if not fs.exists("/.win10_wall.png") then return end
  pcall(function()
    local f = fs.open("/.win10_wall.png", "rb"); local d = f.readAll(); f.close()
    local img = decodePng(d)
    if img then OS.wallImg = prepWallImage(img); OS.wallImgId = (OS.wallImgId or 0) + 1 end
  end)
end

local function urlEnc(s) return (tostring(s):gsub("[^%w%-_%.~]", function(ch) return string.format("%%%02X", ch:byte()) end)) end
-- download a picture from a web address (any format; a free resizing service turns it into a small PNG) and use it as the wallpaper
function OS.setWallImage(url, cb)
  url = tostring(url or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if not url:match("^https?://") then cb(false, "Use a full web address (https://...)"); return end
  local tw = math.max(32, math.min(128, W * 2))
  local th = math.max(18, math.min(110, math.floor(tw * (H * 3) / (W * 2) + 0.5)))
  local src = "https://wsrv.nl/?url=" .. urlEnc(url) .. "&w=" .. tw .. "&h=" .. th .. "&fit=cover&output=png"
  OS.http(src, function(data, err)
    if not data then cb(false, "Download failed: " .. tostring(err)); return end
    local ok, img, why = pcall(decodePng, data)
    if not ok or not img then cb(false, "Can't read the picture: " .. tostring(ok and why or img):sub(1, 40)); return end
    local ok2, prepped = pcall(prepWallImage, img)
    if not ok2 then cb(false, "Can't use the picture"); return end
    pcall(function() local f = fs.open("/.win10_wall.png", "wb"); f.write(data); f.close() end)
    OS.wallImg = prepped; OS.wallImgId = (OS.wallImgId or 0) + 1; OS.wallTried = true
    cfg.wall = 5; cfg.wallUrl = url; OS.wallCache = nil
    OS.applyTheme(); OS.save()
    cb(true, "Wallpaper set (" .. img.w .. "x" .. img.h .. ")")
  end)
end

local LV1 = { " ", "\129", "\137", "\153", "\158", "\159" }
local LV2 = { " ", "\130", "\134", "\150", "\157", "\159" }
local BAYER = { 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5 }
local function imageRows()
  local img = OS.wallImg
  local rows = {}
  local blit = {}
  for k = 1, #WSLOT do blit[k] = colors.toBlit(C[WSLOT[k]]) end
  local iw, ih, pa, pb, pt, dist = img.w, img.h, img.pa, img.pb, img.pt, img.dist
  local colIdx, rowOff = {}, {}
  for sx = 0, W * 2 - 1 do colIdx[sx] = math.min(iw, math.floor((sx + 0.5) / (W * 2) * iw) + 1) end
  for sy = 0, H * 3 - 1 do rowOff[sy] = math.min(ih - 1, math.floor((sy + 0.5) / (H * 3) * ih)) * iw end
  local char = string.char
  for y = 1, H do
    local t, f, b = {}, {}, {}
    local sy0 = (y - 1) * 3
    for x = 1, W do
      local sx0 = (x - 1) * 2
      local col = {}
      local cnt = {}
      for p = 0, 5 do
        local sx, sy = sx0 + (p % 2), sy0 + math.floor(p / 2)
        local k = rowOff[sy] + colIdx[sx]
        local useB = pt[k] > (BAYER[(sy % 4) * 4 + (sx % 4) + 1] + 0.5) / 16
        local ci = useB and pb[k] or pa[k]
        col[p] = ci
        cnt[ci] = (cnt[ci] or 0) + 1
      end
      -- the cell can show two colours: the two most used ones
      local A, nA = nil, 0
      for ci, nn in pairs(cnt) do if nn > nA then A, nA = ci, nn end end
      local Bc, nB = nil, 0
      for ci, nn in pairs(cnt) do if ci ~= A and nn > nB then Bc, nB = ci, nn end end
      if not Bc then t[x] = " "; f[x] = blit[A]; b[x] = blit[A]
      else
        local v = 0
        local bit5 = false
        for p = 0, 5 do
          local ci = col[p]
          local isB
          if ci == A then isB = false elseif ci == Bc then isB = true
          else isB = dist[ci][Bc] < dist[ci][A] end
          if isB then if p == 5 then bit5 = true else v = v + 2 ^ p end end
        end
        if bit5 then t[x] = char(128 + (31 - v)); f[x] = blit[A]; b[x] = blit[Bc]
        else t[x] = char(128 + v); f[x] = blit[Bc]; b[x] = blit[A] end
      end
    end
    rows[y] = { table.concat(t), table.concat(f), table.concat(b) }
  end
  return rows
end
local function wallRows()
  if cfg.wall == 5 then
    OS.loadWallFile()
    if OS.wallImg and not OS.palWithTone then OS.palWithTone = true; OS.applyTheme() end
  end
  local imgOn = cfg.wall == 5 and OS.wallImg
  local key = cfg.wall .. "/" .. W .. "x" .. H .. "/" .. (imgOn and (OS.wallImgId or 0) or 0) .. (OS.mode == "desktop" and "d" or "s")
  if imgOn then
    if OS.wallCache and OS.wallCache.key == key then return OS.wallCache.rows end
    local ok, rows = pcall(imageRows)
    if ok then OS.wallCache = { key = key, rows = rows }; return rows end
  end
  if OS.wallCache and OS.wallCache.key == key then return OS.wallCache.rows end
  local rows = {}
  local bd, bw = colors.toBlit(C.desk), colors.toBlit(C.wp)
  -- Windows 10 hero picture: a glow in the middle and the four-pane logo on top
  local ba = colors.toBlit(C.acc)
  local ba = colors.toBlit(C.acc)
  local lg
  if cfg.wall == 1 and OS.mode == "desktop" then
    local ph = math.max(2, math.min(8, math.floor((H - 1) / 4)))
    local pw = math.max(3, math.floor(ph * 1.7 + 0.5))
    lg = { pw = pw, ph = ph, tw = pw * 2 + 1, th = ph * 2 + 1 }
    lg.x0 = math.floor((W - lg.tw) / 2) + 1
    lg.y0 = math.floor((H - 1 - lg.th) / 2) + 1
    lg.c = colors.toBlit(C.wht)
  end
  for y = 1, H do
    local t, f, b = {}, {}, {}
    for x = 1, W do
      local v = 0
      if cfg.wall == 1 then
        local dx = (x - W * 0.5) / (W * 0.62)
        local dy = (y - (H - 1) * 0.5) / (math.max(1, H - 1) * 0.95)
        v = 1.05 - math.sqrt(dx * dx + dy * dy) * 1.15
      elseif cfg.wall == 2 then v = ((x - 1) / math.max(1, W - 1) + (y - 1) / math.max(1, H - 1)) / 2
      elseif cfg.wall == 3 then v = 0.45 + 0.35 * math.sin(x / 6 + y / 3) + 0.2 * (y / H) end
      v = math.max(0, math.min(1, v))
      local bd, bw = bd, bw
      if cfg.wall == 1 then
        if v < 0.5 then bw = ba; v = v * 2 else bd = ba; v = (v - 0.5) * 2 end
      end
      local lv = math.floor(v * 7)
      if cfg.wall >= 4 then lv = 0 end
      if lv >= 6 then t[x] = " "; f[x] = bw; b[x] = bw
      else t[x] = ((x + y) % 2 == 0 and LV1 or LV2)[lv + 1]; f[x] = bw; b[x] = bd end
      if lg and x >= lg.x0 and x < lg.x0 + lg.tw and y >= lg.y0 and y < lg.y0 + lg.th
        and (x - lg.x0) ~= lg.pw and (y - lg.y0) ~= lg.ph then
        t[x] = " "; f[x] = lg.c; b[x] = lg.c
      end
    end
    rows[y] = { table.concat(t), table.concat(f), table.concat(b) }
  end
  OS.wallCache = { key = key, rows = rows }
  return rows
end
local function drawWall()
  local rows = wallRows()
  for y = 1, H do T.setCursorPos(1, y); T.blit(rows[y][1], rows[y][2], rows[y][3]) end
end

----------------------------------------------------------------------- immediate-mode UI context
local function fieldKey(f, k)
  if f.onKey and f.onKey(f, k) then return end
  if k == keys.backspace then
    if f.pos > 0 then f.text = f.text:sub(1, f.pos - 1) .. f.text:sub(f.pos + 1); f.pos = f.pos - 1 end
  elseif k == keys.delete then f.text = f.text:sub(1, f.pos) .. f.text:sub(f.pos + 2)
  elseif k == keys.left then f.pos = math.max(0, f.pos - 1)
  elseif k == keys.right then f.pos = math.min(#f.text, f.pos + 1)
  elseif k == keys.home then f.pos = 0
  elseif k == keys["end"] then f.pos = #f.text
  elseif k == keys.enter or k == keys.numPadEnter then if f.onEnter then f.onEnter(f) end
  elseif k == keys.tab then if f.onTab then f.onTab(f) end end
end
local function fieldText(f, s)
  s = s:gsub("[%c]", "")
  if f.max and #f.text + #s > f.max then s = s:sub(1, math.max(0, f.max - #f.text)) end
  f.text = f.text:sub(1, f.pos) .. s .. f.text:sub(f.pos + 1); f.pos = f.pos + #s
end
function OS.field(text, o)
  local f = { text = text or "", pos = #(text or "") }
  for k, v in pairs(o or {}) do f[k] = v end
  return f
end

local function newG(hld, ox, oy, w, h)
  local g = { w = w, h = h }
  function g.put(x, y, s, fg, bg)
    if y < 1 or y > h then return end
    s = tostring(s)
    if x < 1 then s = s:sub(2 - x); x = 1 end
    if x + #s - 1 > w then s = s:sub(1, w - x + 1) end
    if #s > 0 then put(ox + x - 1, oy + y - 1, s, fg or C.text, bg or C.win) end
  end
  function g.fill(x, y, fw, fh, bg)
    local x1, y1, x2, y2 = math.max(x, 1), math.max(y, 1), math.min(x + fw - 1, w), math.min(y + fh - 1, h)
    if x2 < x1 then return end
    local row = (" "):rep(x2 - x1 + 1)
    for j = y1, y2 do put(ox + x1 - 1, oy + j - 1, row, C.text, bg or C.win) end
  end
  function g.hot(x, y, hw, hh, fn, drag)
    local r = { x = x, y = y, w = hw, h = hh, fn = fn, drag = drag }
    hld.hots[#hld.hots + 1] = r
    return r
  end
  function g.blit(x, y, t, f, b)
    if y < 1 or y > h then return end
    if x < 1 then t = t:sub(2 - x); f = f:sub(2 - x); b = b:sub(2 - x); x = 1 end
    if x + #t - 1 > w then local n = w - x + 1; t = t:sub(1, n); f = f:sub(1, n); b = b:sub(1, n) end
    if #t > 0 then T.setCursorPos(ox + x - 1, oy + y - 1); T.blit(t, f, b) end
  end
  function g.scroll(x, y, sw, sh, fn) hld.hots[#hld.hots + 1] = { x = x, y = y, w = sw, h = sh, fn = fn, scroll = true } end
  function g.cursor(x, y)
    if hld.active and x >= 1 and x <= w and y >= 1 and y <= h then OS.cursor = { ox + x - 1, oy + y - 1 } end
  end
  function g.btn(x, y, label, fn, style)
    local bg, fg = C.bar, C.text
    if style == "pri" then bg, fg = C.acc, C.wht
    elseif style == "danger" then bg, fg = C.red, C.wht
    elseif style == "sp" then bg, fg = C.sp, C.sp0
    elseif style == "dark" then bg, fg = C.sp2, C.wht
    elseif style == "darkon" then bg, fg = C.sp2, C.sp end
    local s = " " .. label .. " "
    g.put(x, y, s, fg, bg); g.hot(x, y, #s, 1, fn)
    return #s
  end
  function g.toggle(x, y, on, fn, off)
    g.put(x, y, "   ", C.wht, on and C.acc or (off or C.bar))
    g.put(x + (on and 3 or 0), y, "  ", C.wht, C.wht)
    if not on then g.put(x + 2, y, " ", C.wht, off or C.bar) end
    g.hot(x, y, 5, 1, fn)
  end
  function g.slider(x, y, sw, v, fn, fill, track)
    v = math.max(0, math.min(1, v or 0))
    local filled = math.floor(v * (sw - 1) + 0.5)
    for i = 0, sw - 1 do
      local bg = i < filled and (fill or C.acc) or (track or C.bar)
      if i == filled then bg = C.wht end
      g.put(x + i, y, " ", C.text, bg)
    end
    g.hot(x, y, sw, 1, function(rx) fn(math.max(0, math.min(1, (rx - x) / math.max(1, sw - 1)))) end, true)
  end
  function g.field(x, y, fw, f, o)
    o = o or {}
    local bg = o.bg or C.bar
    local shown = f.mask and ("*"):rep(#f.text) or f.text
    local view = 0
    if f.pos > fw - 2 then view = f.pos - (fw - 2) end
    local vis = shown:sub(view + 1, view + fw - 1)
    local line
    if #f.text == 0 and f.placeholder and hld.focus ~= f then
      line = " " .. OS.trunc(f.placeholder, fw - 1)
      g.put(x, y, line .. (" "):rep(math.max(0, fw - #line)), C.sub, bg)
    else
      line = " " .. vis
      g.put(x, y, line:sub(1, fw) .. (" "):rep(math.max(0, fw - #line)), o.fg or C.text, bg)
    end
    if hld.focus == f then g.cursor(x + 1 + f.pos - view, y) end
    g.hot(x, y, fw, 1, function(rx) f.pos = math.max(0, math.min(#f.text, rx - x - 1 + view)); hld.focus = f end)
  end
  return g
end

-- a drawing area that is a shifted part of another one (all coordinates move by dx, dy)
function OS.subG(g, dx, dy, w, h)
  local sg = { w = w, h = h }
  for _, k in ipairs({ "put", "fill", "hot", "blit", "scroll", "cursor", "btn", "toggle", "slider", "field" }) do
    local f = g[k]
    if f then sg[k] = function(x, y, ...) return f(x + dx, y + dy, ...) end end
  end
  return sg
end
-- buttons in a row that wraps onto the next row when the width runs out; items = { {label, fn, style}, ... }; returns the last row used
function OS.btnRow(g, x, y, w, items)
  local bx = x
  for _, it in ipairs(items) do
    local bw = #it[1] + 2
    if bx > x and bx + bw - 1 > x + w - 1 then bx = x; y = y + 1 end
    g.btn(bx, y, it[1], it[2], it[3])
    bx = bx + bw + 1
  end
  return y
end

local function hit(hld, rx, ry, btn, dragStart)
  hld.focus = nil
  for i = #hld.hots, 1, -1 do
    local h = hld.hots[i]
    if not h.scroll and rx >= h.x and rx < h.x + h.w and ry >= h.y and ry < h.y + h.h then
      if not (hld.app and hld.app.noclick) and OS.sfx then OS.sfx("click") end
      if h.drag then OS.drag = { hot = h, hld = hld } end
      h.fn(rx, ry, btn, "click")
      if not hld.focus then hld.focus = hld.keepFocus end
      return true
    end
  end
  if not hld.focus then hld.focus = hld.keepFocus end
  return false
end
local function hitScroll(hld, rx, ry, dir)
  for i = #hld.hots, 1, -1 do
    local h = hld.hots[i]
    if h.scroll and rx >= h.x and rx < h.x + h.w and ry >= h.y and ry < h.y + h.h then h.fn(dir); return true end
  end
end

----------------------------------------------------------------------- audio engine
local Audio = { queue = {}, idx = 0, state = "stopped", speakers = {}, status = "", loop = cfg.music.loop }
OS.audio = Audio
local CH = 3000 -- bytes per chunk = 0.5 s

function Audio.scan()
  local old = {}
  for _, s in ipairs(Audio.speakers) do old[s.name] = s end
  local list = {}
  for _, n in ipairs(peripheral.getNames()) do
    if peripheral.getType(n) == "speaker" then
      local s = old[n] or { name = n, on = not cfg.music.off[n] }
      s.p = peripheral.wrap(n)
      list[#list + 1] = s
    end
  end
  Audio.speakers = list
end
function Audio.setSpeaker(s, on)
  s.on = on
  cfg.music.off[s.name] = (not on) or nil
  if not on then pcall(s.p.stop) end
  OS.dirty = true
end
function Audio.stopSpeakers() for _, s in ipairs(Audio.speakers) do pcall(s.p.stop) end end
function Audio.setVol(v) cfg.music.vol = math.max(0, math.min(1, v)); OS.dirty = true end

function Audio.pos()
  local a = Audio
  if a.state == "playing" or a.state == "drain" then
    if not a.started then return a.pos0 or 0 end
    return math.min(a.total or 0, os.clock() - a.t0)
  elseif a.state == "paused" then return a.ppos or 0 end
  return 0
end

function Audio.fill()
  local a = Audio
  if a.state ~= "playing" and a.state ~= "drain" then return end
  if a.state == "drain" then
    if os.clock() - a.t0 >= a.total then Audio.next(true) end
    return
  end
  for _ = 1, 40 do
    if a.pending then
      local all = true
      local t0 = os.epoch("utc")
      for _, s in ipairs(a.speakers) do
        if s.on and not a.acc[s] then
          if os.epoch("utc") - t0 > 60 then -- time-slice: keep the UI alive with hundreds of speakers
            if not Audio.tm2 then Audio.tm2 = OS.timer(0.05, function() Audio.tm2 = nil; Audio.fill() end) end
            return
          end
          local ok, res = pcall(s.p.playAudio, a.pending, cfg.music.vol * 2)
          if not ok or res then a.acc[s] = true else all = false end
        end
      end
      if not all then return end
      a.pending = nil
      if not a.started then a.started = true; a.t0 = os.clock() - a.pos0 end
    end
    if a.started and ((a.i - 1) / 6000 - (os.clock() - a.t0)) > 1.5 then return end
    if a.i > #a.data then a.state = "drain"; return end
    a.pending = a.dec(a.data:sub(a.i, a.i + CH - 1)); a.i = a.i + CH; a.acc = {}
  end
end
function Audio.kick()
  if Audio.tm then return end
  Audio.tm = OS.timer(0.25, function()
    Audio.tm = nil
    Audio.fill()
    if Audio.state == "playing" or Audio.state == "drain" then Audio.kick() end
  end)
end

function Audio.load(e)
  local a = Audio
  Audio.stopSpeakers()
  a.cur = e; a.state = "loading"; a.status = "Loading " .. OS.trunc(e.title or "?", 24) .. "..."; a.data = nil; a.pending = nil; a.error = nil
  local function got(data, err)
    if a.cur ~= e then return end
    if not data or #data < 64 then a.state = "stopped"; a.status = err and ("Error: " .. tostring(err)) or "No audio data received"; a.error = true; return end
    a.data = data; a.i = 1; a.pos0 = 0; a.started = false; a.dec = dfpwm.make_decoder(); a.total = #data / 6000
    a.state = "playing"; a.status = ""; a.acc = {}
    Audio.scan()
    if #a.speakers == 0 then a.status = "No speakers connected" end
    Audio.fill(); Audio.kick()
  end
  if e.path then
    local f = fs.open(e.path, "rb")
    if not f then got(nil, "file not found") return end
    local d = f.readAll(); f.close(); got(d)
  elseif e.url then OS.http(e.url, got)
  elseif e.id then
    local tpl = cfg.music.converter or ""
    if tpl == "" then
      a.state = "stopped"; a.error = true
      a.status = "No audio converter set -> click here (Settings > Music)"
      return
    end
    OS.http((tpl:gsub("%%s", (e.id))), got)
  end
end
function Audio.play(list, i) Audio.queue = list; Audio.idx = i; Audio.load(list[i]) end
function Audio.next(auto)
  local n = Audio.idx + 1
  if n > #Audio.queue then
    if Audio.loop and #Audio.queue > 0 then n = 1
    else Audio.stopSpeakers(); Audio.state = "stopped"; Audio.status = ""; return end
  end
  Audio.idx = n; Audio.load(Audio.queue[n])
end
function Audio.seek(sec)
  local a = Audio
  if not a.data then return end
  sec = math.max(0, math.min(sec, a.total - 0.5))
  a.i = math.floor(sec * 6000) + 1; a.pos0 = sec; a.started = false; a.pending = nil; a.acc = {}
  a.dec = dfpwm.make_decoder(); Audio.stopSpeakers(); a.state = "playing"
  Audio.fill(); Audio.kick()
end
function Audio.prev()
  if Audio.pos() > 3 or Audio.idx <= 1 then Audio.seek(0) else Audio.idx = Audio.idx - 1; Audio.load(Audio.queue[Audio.idx]) end
end
function Audio.pause()
  if Audio.state == "playing" or Audio.state == "drain" then Audio.ppos = Audio.pos(); Audio.state = "paused"; Audio.stopSpeakers() end
end
function Audio.toggle()
  if Audio.state == "paused" then Audio.seek(Audio.ppos or 0)
  elseif Audio.state == "playing" or Audio.state == "drain" then Audio.pause()
  elseif Audio.cur then Audio.load(Audio.cur) end
end
function Audio.stop() Audio.stopSpeakers(); Audio.state = "stopped"; Audio.cur = nil; Audio.status = "" end
function Audio.setLoop(v) Audio.loop = v; cfg.music.loop = v; OS.dirty = true end

----------------------------------------------------------------------- sound engine (note-block synth: music, themes, sfx)
local Snd = { q = {}, rr = 0, track = nil, amb = nil }
OS.snd = Snd
local NSEMI = { c = 0, d = 2, e = 4, f = 5, g = 7, a = 9, b = 11 }
local function pitchOf(n)
  if type(n) == "number" then return math.max(0, math.min(24, n)) end
  local l, sh, oc = tostring(n):match("^(%a)([#b]?)(%d)$")
  if not l then return nil end
  local m = 12 * (tonumber(oc) + 1) + (NSEMI[l] or 0) + (sh == "#" and 1 or sh == "b" and -1 or 0)
  return math.max(0, math.min(24, m - 54))
end
local function voices()
  local out = {}
  for _, s in ipairs(Audio.speakers) do
    if s.on and s.p then out[#out + 1] = s; if #out >= 4 then break end end
  end
  return out
end
local function note(inst, n, vol)
  if not (cfg.snd and cfg.snd.vol > 0) then return end
  local vs = voices(); if #vs == 0 then return end
  local p = pitchOf(n); if not p then return end
  Snd.rr = Snd.rr % #vs + 1
  pcall(vs[Snd.rr].p.playNote, inst, math.min(3, (vol or 1) * 3 * cfg.snd.vol), p)
end

local SFX = {
  click = { "hat c5" }, tick = { "hat g4" }, back = { "hat f4" },
  open = { "chime c5", "chime g5 0.06" }, close = { "chime g5", "chime c5 0.06" },
  toast = { "bell e5", "bell b5 0.08" }, error = { "bass c4", "bass f#3 0.1" },
  boot = { "harp d4", "harp a4 0.12", "bell d5 0.26", "chime f#4 0.26", "chime f#5 0.5", "bell a4 0.5" },
  login = { "bell d5", "chime a4 0.1", "chime f#5 0.2" }, lock = { "harp e5", "harp c5 0.1", "bass g4 0.2" },
  shutdown = { "harp g4", "harp e4 0.12", "harp c4 0.24", "bass c4 0.36" },
  coin = { "bit b4", "bit e5 0.07" }, jump = { "bit c4", "bit g4 0.05", "bit c5 0.1" },
  stomp = { "basedrum c4", "bit e4 0.04" }, bump = { "basedrum f#3" }, hit = { "snare c4", "bass c4 0.04" },
  die = { "bit g4", "bit e4 0.12", "bit c4 0.24", "bass g3 0.36" },
  win = { "bit c4", "bit e4 0.1", "bit g4 0.2", "bit c5 0.3", "bit e5 0.4", "bell g5 0.5" },
  lose = { "bass g4", "bass e4 0.2", "bass c4 0.4", "bass f#3 0.6" },
  power = { "bit c4", "bit e4 0.05", "bit g4 0.1", "bit c5 0.15", "bit e5 0.2" },
  eat = { "bit e5", "bit a5 0.05" }, boom = { "basedrum f#3", "snare f#3 0.03", "bass f#3 0.06", "basedrum f#3 0.15" },
  fuse = { "hat a5" }, place = { "bass g3", "snare c5 0.02" }, dig = { "snare c4", "hat e4 0.03" },
  pick = { "bell c5", "bell g5 0.05" }, craft = { "iron_xylophone e4", "iron_xylophone g4 0.07", "iron_xylophone c5 0.14" },
  machine = { "bit c4", "bit c5 0.06", "iron_xylophone g4 0.12" }, splash = { "snare a4", "hat c5 0.04" },
  shoot = { "snare e4", "bit e5 0.03" }, reload = { "hat c4", "hat g4 0.12" }, siren = { "bit c5", "bit g4 0.15", "bit c5 0.3" },
  honk = { "didgeridoo c4", "didgeridoo c4 0.08" }, step = { "hat c4" }, select = { "pling c5", "pling g5 0.06" },
}
OS.SFX = SFX
function OS.sfx(name)
  local c = cfg and cfg.snd; if not c then return end
  local sys = name == "click" or name == "tick" or name == "back" or name == "open" or name == "close" or name == "toast"
    or name == "error" or name == "boot" or name == "login" or name == "lock" or name == "shutdown"
  if sys and not c.sys or (not sys and not c.sfx) then return end
  local seq = SFX[name]; if not seq then return end
  for _, e in ipairs(seq) do
    local inst, n, d = e:match("^(%S+) (%S+) ?(%S*)$")
    d = tonumber(d) or 0
    if d == 0 then note(inst, tonumber(n) or n, 0.8)
    else Snd.q[#Snd.q + 1] = { t = os.clock() + d, i = inst, n = tonumber(n) or n, v = 0.8 } end
  end
  Snd.pump()
end

-- tracks: step = seconds per token; each voice is { instrument, volume, "tokens" } (r/- = rest, . = sustain)
local TRACKS = {
  desktop = { step = 0.5, v = { { "harp", 0.35, "c4 - e4 - g4 - e4 - a3 - c4 - e4 - c4 - f4 - - - a4 - - - g4 - - - e4 - - - " },
    { "bell", 0.18, "- - - - - - - - - - - - - - - - - - - - - - - - c5 - - - - - - -" } } },
  snake = { step = 0.14, v = { { "bit", 0.4, "e4 g4 b4 g4 e4 g4 b4 g4 d4 f#4 a4 f#4 d4 f#4 a4 f#4 c4 e4 g4 e4 c4 e4 g4 e4 d4 f#4 a4 b4 a4 f#4 d4 -" },
    { "bass", 0.5, "e3 - e3 - e3 - e3 - d3 - d3 - d3 - d3 - c3 - c3 - c3 - c3 - d3 - d3 - d3 - d3 -" } } },
  doom = { step = 0.12, v = { { "bass", 0.8, "f#3 f#3 - f#3 f#3 - a3 - f#3 f#3 - f#3 f#3 - g3 f#3 f#3 f#3 - f#3 f#3 - a3 - c4 b3 - a3 - g3 - f#3 -" },
    { "didgeridoo", 0.45, "f#3 - - - - - - - f#3 - - - - - - - f#3 - - - - - - - g3 - - - - - - -" },
    { "snare", 0.35, "- - c4 - - - - - - - c4 - - - - - - - c4 - - - - - - - c4 - c4 -" } } },
  gta = { step = 0.2, v = { { "pling", 0.4, "a4 - c5 - e5 - c5 - g4 - b4 - d5 - b4 - f4 - a4 - c5 - a4 - e4 - g#4 - b4 - e5 - " },
    { "bass", 0.7, "a3 - - a3 - - a3 - g3 - - g3 - - g3 - f3 - - f3 - - f3 - e3 - - e3 - - g#3 -" },
    { "hat", 0.3, "c5 - c5 c5 - c5 c5 - c5 - c5 c5 - c5 c5 - c5 - c5 c5 - c5 c5 - c5 - c5 c5 - c5 c5 -" } } },
  wilson = { step = 0.15, v = { { "bit", 0.4, "c5 - e5 - g5 - e5 - c5 - e5 - g5 - e5 - d5 - f5 - a5 - f5 - d5 - f5 - g5 - b4 - d5 - g4 - " },
    { "harp", 0.5, "c4 - g4 - c4 - g4 - c4 - g4 - c4 - g4 - d4 - a4 - d4 - a4 - g3 - d4 - g3 - d4 -" } } },
  bomber = { step = 0.16, v = { { "banjo", 0.5, "e4 e4 g4 e4 a4 g4 e4 d4 e4 e4 g4 e4 b4 a4 g4 - e4 e4 g4 e4 a4 g4 e4 d4 c4 d4 e4 g4 e4 - - -" },
    { "bass", 0.6, "e3 - b3 - e3 - b3 - e3 - b3 - e3 - b3 - a3 - e4 - a3 - e4 - a3 - e4 - e3 - b3 -" } } },
  block = { step = 0.45, v = { { "harp", 0.4, "c4 - g4 - e4 - g4 - a3 - e4 - c4 - e4 - f3 - c4 - a3 - c4 - g3 - d4 - b3 - d4 -" },
    { "chime", 0.2, "- - - - - - - - - - - - - - c5 - - - - - - - - - - - - - g5 - - -" } } },
  machine = { step = 0.2, v = { { "iron_xylophone", 0.4, "c4 - c4 - g4 - c4 - f4 - f4 - c5 - f4 - g4 - g4 - d5 - g4 - c4 - e4 - g4 - -" },
    { "bass", 0.6, "c3 - - - c3 - - - f3 - - - f3 - - - g3 - - - g3 - - - c3 - - - - - - -" } } },
  flappy = { step = 0.18, v = { { "bit", 0.4, "e4 g4 a4 g4 e4 g4 c5 - a4 c5 e5 c5 a4 g4 e4 -" },
    { "harp", 0.5, "c4 - - - g3 - - - a3 - - - f4 - - -" } } },
  pong = { step = 0.15, v = { { "bit", 0.4, "c4 - c4 - g4 - c4 - e4 - e4 - b4 - e4 -" },
    { "bass", 0.6, "g3 - - - g3 - - - a3 - - - b3 - - -" } } },
  fall = { step = 0.2, v = { { "pling", 0.4, "d4 f#4 a4 f#4 d4 g4 b4 g4 e4 g4 b4 g4 f#4 a4 d5 a4" },
    { "bass", 0.6, "g3 - - - g3 - - - a3 - - - a3 - - -" } } },
  brick = { step = 0.16, v = { { "iron_xylophone", 0.4, "g4 a4 b4 d5 b4 a4 g4 - e4 g4 a4 b4 a4 g4 e4 -" },
    { "bass", 0.6, "g3 - d4 - g3 - d4 - e4 - b3 - e4 - b3 -" } } },
  invade = { step = 0.3, v = { { "didgeridoo", 0.5, "a3 - g#3 - g3 - f#3 -" },
    { "bit", 0.3, "- - - - - - - - e5 - - - c5 - - - - - - - - - - - b4 - - - g4 - - -" } } },
  arch = { step = 0.16, v = { { "pling", 0.4, "e4 g#4 b4 e5 b4 g#4 e4 - c#4 e4 g#4 c#5 g#4 e4 c#4 -" },
    { "bass", 0.6, "e4 - - - e4 - - - c#4 - - - c#4 - - -" },
    { "hat", 0.25, "c5 - c5 - c5 - c5 c5" } } },
}
OS.TRACKS = TRACKS
local function toks(s) local t = {}; for w in s:gmatch("%S+") do t[#t + 1] = w end return t end
function OS.music(name, owner)
  Snd.track = nil
  if not name or not TRACKS[name] then return end
  local tr = TRACKS[name]
  local vs = {}
  for _, v in ipairs(tr.v) do vs[#vs + 1] = { inst = v[1], vol = v[2], t = toks(v[3]) } end
  Snd.track = { name = name, owner = owner, step = tr.step, v = vs, i = 0, nt = os.clock() }
end
function OS.musicStop(owner) if Snd.track and (not owner or Snd.track.owner == owner) then Snd.track = nil end end

function Snd.pump()
  local now = os.clock()
  local q = Snd.q
  local k = 1
  while k <= #q do
    if q[k].t <= now then local e = table.remove(q, k); note(e.i, e.n, e.v) else k = k + 1 end
  end
  if #q > 0 and not Snd.qt then
    Snd.qt = true
    OS.timer(0.05, function() Snd.qt = nil; Snd.pump() end)
  end
end
function Snd.tick()
  local c = cfg.snd
  local tr = Snd.track
  if tr and tr.owner then
    local open = false
    for _, w in ipairs(OS.wins) do if w == tr.owner then open = true end end
    if not open then Snd.track = nil; tr = nil end
  end
  local act = OS.active and OS.active()
  if tr and tr.amb and (act or OS.mode ~= "desktop") then Snd.track = nil; tr = nil end
  if not tr and c and c.music and c.amb and OS.mode == "desktop" and not act and Audio.state ~= "playing" then
    OS.music("desktop"); Snd.track.amb = true; tr = Snd.track
  end
  if tr and c and c.music and Audio.state ~= "playing" and OS.mode == "desktop" then
    local now = os.clock()
    local quiet = tr.owner and OS.active() ~= tr.owner
    if now >= tr.nt then
      tr.nt = now + tr.step
      for _, v in ipairs(tr.v) do
        local tk = v.t[tr.i % #v.t + 1]
        if tk ~= "-" and tk ~= "." and tk ~= "r" and not quiet then
          note(v.inst, tk, v.vol * 0.7)
        end
      end
      tr.i = tr.i + 1
    end
  end
  Snd.pump()
  OS.timer(Snd.track and math.max(0.03, Snd.track.nt - os.clock()) or 0.5, Snd.tick)
end
function Snd.start() if not Snd.running then Snd.running = true; OS.timer(0.1, Snd.tick) end end

----------------------------------------------------------------------- windows
function OS.running(id) for _, w in ipairs(OS.wins) do if w.app.id == id then return w end end end
function OS.active() for i = #OS.wins, 1, -1 do if not OS.wins[i].min then return OS.wins[i] end end end
function OS.raise(win)
  for i, w in ipairs(OS.wins) do if w == win then table.remove(OS.wins, i) break end end
  OS.wins[#OS.wins + 1] = win; win.min = false
end
function OS.close(win)
  win.closed = true
  for i, w in ipairs(OS.wins) do if w == win then table.remove(OS.wins, i) break end end
  if win.app.close then pcall(win.app.close, win) end
  OS.sfx("close")
end
-- Small screens (pocket computers, tiny monitors): one app at a time, full screen, slim chrome, touch-sized controls
function OS.compact() return W < 40 end
-- a full-screen window; x = 0 and 2 extra columns so the app area is exactly the screen width
function OS.fullscreen(win)
  if not win.cmp then win.prev = { x = win.x, y = win.y, w = win.w, h = win.h } end
  win.x, win.y, win.w, win.h = 0, 1, W + 2, H
  win.max = true; win.cmp = true
end
function OS.maximize(win)
  if OS.compact() then OS.fullscreen(win) return end
  win.cmp = nil
  if win.max then
    local p = win.prev; win.x, win.y, win.w, win.h = p.x, p.y, p.w, p.h; win.max = false; win.snapPrev = nil
  else
    win.prev = { x = win.x, y = win.y, w = win.w, h = win.h }
    win.x, win.y, win.w, win.h = 1, 1, W, math.max(6, (win.app.fullH or cfg.dockHide) and H or (H - 1)); win.max = true
  end
end
-- get the source of an external program (file on disk, else downloaded into memory)
function OS.externalSource(app)
  if app.source then return app.source end
  local path = app.external
  if fs.exists(path) then
    local f = fs.open(path, "rb"); app.source = f.readAll(); f.close()
    return app.source
  end
  if not app.url then return nil, "Program file missing: " .. tostring(path) end
  OS.toast("Downloading Music...", 10); OS.render()
  local ok, res = pcall(http.get, app.url, nil, true)
  if not ok or not res then return nil, "Download failed. Is http enabled for gist.githubusercontent.com?" end
  local data = res.readAll(); res.close()
  if not data or #data < 100 or data:find("^%s*<") then return nil, "Download failed (got a web page, not Lua)" end
  app.source = data
  return data
end

function OS.open(id, arg)
  local app = OS.apps[id]
  if not app then OS.toast("App not installed: " .. tostring(id)); return end
  if app.action then app.action() return end
  if app.single then
    local ex = OS.running(id)
    if ex then OS.raise(ex); if app.onOpen then pcall(app.onOpen, ex, arg) end return ex end
  end
  local w, h = math.min(app.w or 40, W), math.min(app.h or 14, math.max(6, H - 2))
  local n = #OS.wins % 5
  local win = { app = app, title = app.title, w = w, h = h, hots = {}, state = {}, min = false,
    x = math.max(1, math.floor((W - w) / 2) + 1 + n * 2 - 4), y = math.max(1, math.floor((H - 1 - h) / 2) + 1 + n - 2) }
  local ok, err = pcall(app.init, win, arg)
  if not ok then OS.toast(app.title .. ": " .. tostring(err), 5) return end
  OS.wins[#OS.wins + 1] = win
  if OS.compact() then OS.fullscreen(win)
  elseif app.startMax and not win.max then OS.maximize(win) end
  OS.sfx("open")
  return win
end
function OS.open_lp_edit() OS.lp = { scroll = 0, edit = true }; OS.menu = nil end
function OS.lpWhy(why)
  pcall(function() local f = fs.open("/win10_error.log", "a"); f.writeLine(os.date() .. " app grid closed: " .. tostring(why)); f.close() end)
end
function OS.toggleLP()
  if OS.lp then OS.lp = nil else OS.lp = { scroll = 0, t0 = os.clock() }; OS.menu = nil; OS.panel = nil end
end
function OS.launch(id)
  local a = OS.apps[id]
  if a and a.action then a.action() return end
  OS.lp = nil
  if cfg.dockHide then OS.dockUntil = nil end
  local ex = OS.running(id)
  if ex then OS.raise(ex) else OS.open(id) end
end

local function drawWindowCompact(win, active)
  local y = win.y
  local tb = active and C.acc or C.bar
  put(1, y, (" "):rep(W), C.text, tb)
  put(2, y, OS.trunc(win.title or win.app.title, math.max(3, W - 10)), active and C.wht or C.sub, tb)
  put(W - 5, y, " _ ", active and C.wht or C.sub, tb)
  put(W - 2, y, " X ", C.wht, C.red)
  for j = 1, H - y do put(1, y + j, (" "):rep(W), C.text, C.win) end
  win.hots = {}; win.active = active
  local g = newG(win, 1, y + 1, W, H - y)
  local ok, err = pcall(win.app.draw, win, g)
  if not ok then
    g.fill(1, 1, g.w, g.h, C.win)
    g.put(1, 1, "This app crashed:", C.red, C.win)
    for i, l in ipairs(OS.wrap(tostring(err), g.w)) do g.put(1, 1 + i, l, C.text, C.win) end
  end
end

local function drawWindow(win, active)
  if OS.compact() then
    if not win.cmp then OS.fullscreen(win) end
    return drawWindowCompact(win, active)
  end
  if win.cmp then win.cmp = nil; win.max = false; if win.prev then win.x, win.y, win.w, win.h = win.prev.x, win.prev.y, win.prev.w, win.prev.h end end
  local x, y, w, h = win.x, win.y, win.w, win.h
  local tb = active and C.acc or C.bar
  local border = tb
  local row = (" "):rep(w)
  put(x, y, row, C.text, tb)
  for j = 1, h - 1 do put(x, y + j, row, C.text, C.win) end
  -- thin outline: half-cell strips at the sides, a third of a cell at the bottom
  for j = 1, h - 2 do
    put(x, y + j, "\149", border, C.win)
    put(x + w - 1, y + j, "\149", C.win, border)
  end
  put(x, y + h - 1, "\138", C.win, border)
  put(x + w - 1, y + h - 1, "\133", C.win, border)
  if w > 2 then put(x + 1, y + h - 1, ("\143"):rep(w - 2), C.win, border) end
  -- icon, title, minimise / maximise / close
  local a = win.app
  put(x + 1, y, tostring(a.glyph or " ? "), C[a.fg or "wht"] or C.wht, C[a.icon or "acc"] or C.acc)
  local tfg = active and C.wht or C.sub
  if OS.grab and OS.grab.win == win then tfg = C.yel end
  put(x + 5, y, OS.trunc(win.title or a.title, w - 15), tfg, tb)
  local bx = x + w - 9
  put(bx, y, " _ ", tfg, tb)
  put(bx + 3, y, win.max and "[=]" or "[ ]", tfg, tb)
  put(bx + 6, y, " X ", C.wht, active and C.red or tb)
  win.hots = {}; win.active = active
  local g = newG(win, x + 1, y + 1, w - 2, h - 2)
  local ok, err = pcall(win.app.draw, win, g)
  if not ok then
    g.fill(1, 1, g.w, g.h, C.win)
    g.put(1, 1, "This app crashed:", C.red, C.win)
    for i, l in ipairs(OS.wrap(tostring(err), g.w)) do g.put(1, 1 + i, l, C.text, C.win) end
  end
  put(x + w - 2, y + h - 1, ":", active and C.wht or C.sub, border)
end

----------------------------------------------------------------------- desktop chrome
local MON3 = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
local function anySnd() local c = cfg.snd; return c.sys or c.sfx or c.music end

function OS.sysStats()
  local cap = fs.getCapacity and fs.getCapacity("/") or 1
  local free = fs.getFreeSpace("/")
  local used = 0
  if type(cap) == "number" and cap > 0 and cap < 1e15 then used = math.max(0, math.min(1, 1 - free / cap)) end
  local n = 0
  for _, sp in ipairs(Audio.speakers) do if sp.on then n = n + 1 end end
  return { mem = collectgarbage and collectgarbage("count") or 0, hasMem = collectgarbage ~= nil, disk = used, free = free, cap = cap, spk = n, spkAll = #Audio.speakers,
    wins = #OS.wins, up = os.clock() }
end

function OS.dockList() return cfg.dock or OS.dockOrder end
-- the version name: the gist this copy was installed from (when this file is that install), else the built-in number
function OS.verName()
  if cfg and cfg.sysName and cfg.sysName ~= "" and cfg.sysSize and cfg.sysSize == OS.meSize then return cfg.sysName end
  return OS.VERSION
end
function OS.dockHas(id) for _, v in ipairs(OS.dockList()) do if v == id then return true end end return false end
function OS.dockToggle(id)
  local l = {}
  local had = false
  for _, v in ipairs(OS.dockList()) do if v == id then had = true else l[#l + 1] = v end end
  if not had then
    if #l >= math.max(3, math.floor((W - 5) / 4)) then OS.toast("Taskbar is full"); return end
    l[#l + 1] = id
  end
  cfg.dock = l; OS.dirty = true
end
function OS.dockMove(id, d)
  local l = {}
  for _, v in ipairs(OS.dockList()) do l[#l + 1] = v end
  for i, v in ipairs(l) do
    if v == id and l[i + d] then l[i], l[i + d] = l[i + d], l[i]; break end
  end
  cfg.dock = l; OS.dirty = true
end

local function taskbarClick(id)
  local a = OS.apps[id]
  if a and a.action then a.action() return end
  local aw = OS.active()
  local win
  for i = #OS.wins, 1, -1 do
    local w = OS.wins[i]
    if w.app.id == id and (not win or (win.min and not w.min)) then win = w; if not w.min then break end end
  end
  if not win then OS.launch(id) return end
  if win == aw then win.min = true else OS.raise(win) end
  OS.lp = nil
end
OS.taskbarClick = taskbarClick
function OS.showDesktop()
  local any = false
  for _, w in ipairs(OS.wins) do if not w.min then any = true end end
  if any then for _, w in ipairs(OS.wins) do w.min = true end; OS.deskHidden = true
  elseif OS.deskHidden then for _, w in ipairs(OS.wins) do w.min = false end; OS.deskHidden = false end
end
function OS.toggleTV()
  if OS.lp and OS.lp.tv then OS.lp = nil
  else OS.lp = { tv = true, scroll = 0, t0 = os.clock() }; OS.menu = nil; OS.panel = nil end
end

local function drawTaskbar()
  local aw = OS.active()
  OS.barHits = {}; OS.dockIcons = {}
  local small = OS.compact()
  if (aw and small and not OS.lp) or (aw and aw.max and aw.app.fullH and not OS.lp) then
    OS.dockRect = { x = 0, y = 0, w = 0, h = 0 }
    return
  end
  if cfg.dockHide and not OS.lp and not (OS.dockUntil and os.clock() < OS.dockUntil) then
    OS.dockRect = { x = 1, y = H, w = W, h = 1, hidden = true }
    return
  end
  OS.dockRect = { x = 1, y = H, w = W, h = 1 }
  put(1, H, (" "):rep(W), C.text, C.dock)
  local pk = OS.panel and OS.panel.kind
  -- start button
  local sbg = (OS.lp and not OS.lp.tv) and C.bar or C.dock
  put(1, H, "     ", C.text, sbg)
  OS.startLogo(2, H, C.text, sbg)
  -- right side: show-desktop sliver, action centre, clock
  put(W, H, "\149", C.sub, C.dock)
  OS.barHits.desk = { x = W, w = 1 }
  local rx = W
  rx = rx - 3
  put(rx, H, " \159 ", C.text, pk == "quick" and C.bar or C.dock)
  OS.barHits.quick = { x = rx, w = 3 }
  local t = nowT()
  local ds = (cfg.time or {}).date
  local dtxt = (ds == "off") and "" or (ds == "dm" and string.format("%d %s", t.day, MON3[t.month]) or string.format("%s %d", MON3[t.month], t.day))
  local right = " " .. OS.clockStr() .. ((dtxt ~= "" and W >= 44) and ("  " .. dtxt) or "") .. " "
  if cfg.time and cfg.time.mc and W >= 60 then right = " " .. OS.mcStr() .. " |" .. right end
  rx = rx - #right
  put(rx, H, right, C.text, pk == "cal" and C.bar or C.dock)
  OS.barHits.clock = { x = rx, w = #right }
  local minLeft = 6 + (W >= 44 and 3 or 0) + 12
  -- status words
  local st = ""
  if OS.wifi and OS.wifi.conn then st = st .. "Wi-Fi " end
  if cfg.dnd then st = st .. "DND " end
  if not anySnd() then st = st .. "Mute " end
  if cfg.night then st = st .. "Night " end
  if st ~= "" and not small and rx - #st - 1 > minLeft then
    put(rx - #st - 1, H, " " .. st, C.sub, C.dock)
    rx = rx - #st - 1
  end
  OS.touchDev = cfg.monitor or next(OS.mirrors or {}) ~= nil
  if OS.touchDev and not small and rx - 5 > minLeft then
    rx = rx - 5
    put(rx, H, " RC ", OS.rcNext and C.wht or C.sub, OS.rcNext and C.acc or C.dock)
    OS.barHits.rc = { x = rx + 0, w = 4 }
  end
  if W >= 70 then
    local s2 = OS.sysStats()
    local segs = {}
    if s2.hasMem then segs = { { "MEM ", C.sub }, { string.format("%dK ", math.floor(s2.mem)), C.text } } end
    segs[#segs + 1] = { "DSK ", C.sub }; segs[#segs + 1] = { string.format("%d%% ", math.floor(s2.disk * 100)), C.text }
    segs[#segs + 1] = { "SPK ", C.sub }; segs[#segs + 1] = { s2.spk .. " ", C.text }
    local len = 1
    for _, sg in ipairs(segs) do len = len + #sg[1] end
    local sx = rx - len
    if sx > minLeft then
      local bgc = pk == "stats" and C.bar or C.dock
      put(sx, H, " ", C.text, bgc)
      local cx = sx + 1
      for _, sg in ipairs(segs) do put(cx, H, sg[1], sg[2], bgc); cx = cx + #sg[1] end
      OS.barHits.stats = { x = sx, w = len }
      rx = sx
    end
  end
  local A = Audio
  OS.musicHit = nil
  if A.cur and (A.state == "playing" or A.state == "paused" or A.state == "drain" or A.state == "loading") then
    local lab = (A.state == "paused" and "|| " or "> ") .. OS.trunc(A.cur.title or "", 16) .. " "
    local lx = rx - #lab
    if lx > minLeft then
      put(lx, H, lab, C.sp, C.dock)
      OS.musicHit = { x = lx, w = #lab }
      rx = lx
    end
  end
  -- left side: task view, search, app buttons
  local lx = 6
  if W >= 44 then
    put(lx, H, "[|]", C.text, (OS.lp and OS.lp.tv) and C.bar or C.dock)
    OS.barHits.taskview = { x = lx, w = 3 }
    lx = lx + 3
  end
  if W >= 80 then
    put(lx, H, OS.trunc("  o  Type here to search", 24) .. (" "):rep(math.max(0, 24 - 23)), C.sub, C.bar)
    OS.barHits.search = { x = lx, w = 24 }
    lx = lx + 25
  end
  local maxN = math.max(0, math.floor((rx - lx) / 4))
  local order, seen = {}, {}
  for _, id in ipairs(OS.dockList()) do
    local a = OS.apps[id]
    if a and not a.action and not seen[id] then order[#order + 1] = { id = id, app = a }; seen[id] = true end
  end
  for _, win in ipairs(OS.wins) do
    local id = win.app.id
    if not seen[id] then order[#order + 1] = { id = id, app = win.app }; seen[id] = true end
  end
  while #order > maxN do table.remove(order) end
  for i, it in ipairs(order) do
    local a = it.app
    local ix = lx + (i - 1) * 4
    local run = OS.running(it.id)
    local act = aw and aw.app.id == it.id
    put(ix, H, tostring(a.glyph or " ? "), C[a.fg or "wht"] or C.wht, C[a.icon or "acc"] or C.acc)
    put(ix + 3, H, " ", C.text, run and (act and C.acc or C.sub) or C.dock)
    OS.dockIcons[#OS.dockIcons + 1] = { x = ix, id = it.id }
  end
end

local function lpRank(id)
  for i, v in ipairs(cfg.lp.order) do if v == id then return i end end
  return 1000
end
local function lpSections(edit)
  local secs
  if cfg.lp.flat then secs = { { name = "All Apps", items = {} } }
  else secs = { { name = "Apps", items = {} }, { name = "Games", items = {} }, { name = "Mods", items = {} }, { name = "Installed", items = {} } } end
  local ids = {}
  for id, a in pairs(OS.apps) do
    if not a.hidden and not a.action and (edit or not cfg.lp.hide[id]) then ids[#ids + 1] = id end
  end
  table.sort(ids, function(a, b)
    local ra, rb = lpRank(a), lpRank(b)
    if ra ~= rb then return ra < rb end
    return tostring(OS.apps[a].title or a):lower() < tostring(OS.apps[b].title or b):lower()
  end)
  for _, id in ipairs(ids) do
    local cat = OS.apps[id].cat
    local si = 1
    if not cfg.lp.flat then si = cat == "Games" and 2 or (cat == "Mods" and 3 or (cat == "Installed" and 4 or 1)) end
    local t = secs[si].items
    t[#t + 1] = id
  end
  return secs
end

local function lpMove(dir)
  local lp = OS.lp
  if not lp or not lp.sel then return end
  local flatList, target = {}, nil
  for _, sec in ipairs(lpSections(true)) do
    for i, id in ipairs(sec.items) do
      flatList[#flatList + 1] = id
      if id == lp.sel then target = sec.items[i + dir] end
    end
  end
  if not target then return end
  cfg.lp.order = flatList
  local a, b
  for i, id in ipairs(flatList) do if id == lp.sel then a = i elseif id == target then b = i end end
  flatList[a], flatList[b] = flatList[b], flatList[a]
  OS.dirty = true
end

local function drawTaskView()
  local lp = OS.lp
  for yy = 1, H - 1 do put(1, yy, (" "):rep(W), C.text, C.desk) end
  local ttl = "Task view"
  put(math.floor((W - #ttl) / 2) + 1, 2, ttl, C.text, C.desk)
  lp.rect = { x = 1, y = 1, w = W, h = H - 1 }
  if #OS.wins == 0 then
    local s = "No open windows"
    put(math.floor((W - #s) / 2) + 1, math.floor(H / 2), s, C.sub, C.desk)
    return
  end
  local cw, ch = math.min(24, W - 2), 6
  local per = math.max(1, math.floor((W - 1) / (cw + 1)))
  local x0 = math.floor((W - (math.min(per, #OS.wins) * (cw + 1) - 1)) / 2) + 1
  local act = OS.active()
  for i, win in ipairs(OS.wins) do
    local r, c = math.floor((i - 1) / per), (i - 1) % per
    local cx, cy = x0 + c * (cw + 1), 4 + r * (ch + 1)
    if cy + ch - 1 <= H - 1 then
      local a = win.app
      local hot = (win == act)
      box(cx, cy, cw, ch, C.win)
      put(cx, cy, (" "):rep(cw), C.text, hot and C.acc or C.bar)
      put(cx + 1, cy, tostring(a.glyph or " ? "), C[a.fg or "wht"] or C.wht, C[a.icon or "acc"] or C.acc)
      put(cx + 5, cy, OS.trunc(win.title or a.title or "?", cw - 10), hot and C.wht or C.text, hot and C.acc or C.bar)
      put(cx + cw - 3, cy, " X ", C.wht, C.red)
      put(cx + 2, cy + 2, OS.trunc(win.min and "minimized" or "open", cw - 4), C.sub, C.win)
      lp.btns[#lp.btns + 1] = { x = cx + cw - 3, y = cy, w = 3, h = 1, fn = function() OS.close(win) end }
      lp.hits[#lp.hits + 1] = { x = cx, y = cy, w = cw, h = ch, win = win }
    end
  end
end

-- the Start menu: a rail on the left, the app list, and the pinned tiles
local function drawStart()
  local lp = OS.lp
  lp.hits = {}; lp.btns = {}; lp.pbtns = {}
  if lp.tv then return drawTaskView() end
  lp.search = lp.search or OS.field("", { max = 30 })
  local search = lp.search
  search.onEnter = function() if lp.first then local id = lp.first; OS.lp = nil; OS.launch(id) end end
  local edit = lp.edit
  local small = OS.compact()
  local rail = 3
  local TW = 0
  if not small and W >= 50 then TW = (W >= 64) and 28 or 24 end
  local LW = small and (W - rail) or math.min(26, W - rail - (TW > 0 and (TW + 1) or 0))
  local mw = rail + LW + (TW > 0 and (TW + 1) or 0)
  local mh = math.min(H - 1, math.max(12, math.min(30, math.floor(H * 0.85))))
  local x0, y0 = 1, H - mh
  lp.rect = { x = x0, y = y0, w = mw, h = mh }
  box(x0, y0, mw, mh, C.dock)
  -- rail
  local function rbtn(y, label, fn, on)
    put(x0, y, label, C.text, on and C.acc or C.dock)
    lp.btns[#lp.btns + 1] = { x = x0, y = y, w = rail, h = 1, fn = fn }
  end
  rbtn(H - 1, "(|)", function() lp.power = not lp.power end, lp.power)
  rbtn(H - 2, " * ", function() OS.lp = nil; OS.open("settings") end)
  rbtn(H - 3, " F ", function() OS.lp = nil; OS.open("files") end)
  rbtn(H - 4, " " .. ((cfg.user or "u"):sub(1, 1):upper()) .. " ", function() OS.lp = nil; OS.lock() end)
  local lx = x0 + rail
  local q = search.text:lower()
  put(lx, y0, (" "):rep(LW), C.text, C.bar)
  if search.text == "" then put(lx + 1, y0, OS.trunc("Type here to search", LW - 2), C.sub, C.bar)
  else put(lx + 1, y0, OS.trunc(search.text, LW - 3) .. "_", C.text, C.bar) end
  put(lx, y0 + 1, (" "):rep(LW), C.sub, C.dock)
  put(lx + 1, y0 + 1, q ~= "" and "Best match" or "All apps", C.sub, C.dock)
  local ebl = edit and " Done " or " Edit "
  local ebx = lx + LW - #ebl
  put(ebx, y0 + 1, ebl, edit and C.wht or C.text, edit and C.grn or C.bar)
  lp.btns[#lp.btns + 1] = { x = ebx, y = y0 + 1, w = #ebl, h = 1, fn = function() lp.edit = not lp.edit; lp.sel = nil end }
  -- app list
  local secs = lpSections(edit)
  local rows = {}
  if q ~= "" then
    for _, sec in ipairs(secs) do
      for _, id in ipairs(sec.items) do
        local a = OS.apps[id]
        if a and tostring(a.title or id):lower():find(q, 1, true) then rows[#rows + 1] = { id = id } end
      end
    end
  else
    for _, sec in ipairs(secs) do
      if #sec.items > 0 then
        if not cfg.lp.flat then rows[#rows + 1] = { hdr = sec.name } end
        for _, id in ipairs(sec.items) do rows[#rows + 1] = { id = id } end
      end
    end
  end
  lp.first = nil
  for _, r in ipairs(rows) do if r.id then lp.first = r.id break end end
  local ly0 = y0 + 2
  local lyN = H - 1 - (edit and 1 or 0)
  local view = lyN - ly0 + 1
  local maxS = math.max(0, #rows - view)
  lp.scroll = math.max(0, math.min(math.floor(tonumber(lp.scroll) or 0), maxS))
  lp.max = maxS
  for k = 1, view do
    local r = rows[lp.scroll + k]
    if not r then break end
    local y = ly0 + k - 1
    if r.hdr then
      put(lx, y, (" "):rep(LW), C.sub, C.dock); put(lx + 1, y, OS.trunc(r.hdr, LW - 2), C.sub, C.dock)
    else
      local a = OS.apps[r.id] or {}
      local hidden = cfg.lp.hide[r.id]
      local sel = edit and lp.sel == r.id
      local bg = sel and C.acc or C.dock
      put(lx, y, (" "):rep(LW), C.text, bg)
      put(lx, y, tostring(a.glyph or " ? "), C[a.fg or "wht"] or C.wht, hidden and C.bar or (C[a.icon or "acc"] or C.acc))
      put(lx + 4, y, OS.trunc(tostring(a.title or r.id), LW - 6), sel and C.wht or (hidden and C.sub or C.text), bg)
      if OS.dockHas(r.id) then put(lx + LW - 1, y, "*", C.yel, bg) end
      lp.hits[#lp.hits + 1] = { x = lx, y = y, w = LW, h = 1, id = r.id }
    end
  end
  if lp.scroll > 0 then put(lx + LW - 1, ly0, "\30", C.sub, C.dock) end
  if lp.scroll < maxS then put(lx + LW - 1, lyN, "\31", C.sub, C.dock) end
  -- edit toolbar
  if edit then
    local ey = H - 1
    put(lx, ey, (" "):rep(LW), C.sub, C.dock)
    local bx = lx
    local function eb(label, fn)
      put(bx, ey, label, C.text, C.bar)
      lp.btns[#lp.btns + 1] = { x = bx, y = ey, w = #label, h = 1, fn = fn }
      bx = bx + #label + 1
    end
    if lp.sel then
      local id = lp.sel
      eb(" < ", function() lpMove(-1) end)
      eb(" > ", function() lpMove(1) end)
      eb(cfg.lp.hide[id] and " Show " or " Hide ", function() cfg.lp.hide[id] = (not cfg.lp.hide[id]) or nil; OS.dirty = true end)
      eb(OS.dockHas(id) and " Unpin " or " Pin ", function() OS.dockToggle(id) end)
    else put(lx, ey, OS.trunc("Pick an app: move / hide / pin", LW), C.sub, C.dock) end
  end
  -- pinned tiles
  lp.tilesX = nil
  if TW > 0 then
    local tx0 = lx + LW + 1
    lp.tilesX = tx0
    put(tx0, y0 + 1, "Pinned", C.sub, C.dock)
    local cols = math.max(1, math.min(3, math.floor(tonumber(cfg.lp.cols) or 2)))
    local tw = math.floor((TW - (cols - 1)) / cols)
    local tiles = {}
    for _, id in ipairs(OS.dockList()) do
      local a = OS.apps[id]
      if a and not a.action then tiles[#tiles + 1] = id end
    end
    local trows = math.ceil(#tiles / cols)
    local tview = math.max(1, math.floor(((H - 1) - ly0 + 2) / 4))
    local tmax = math.max(0, trows - tview)
    lp.tscroll = math.max(0, math.min(math.floor(tonumber(lp.tscroll) or 0), tmax))
    for i, id in ipairs(tiles) do
      local r, c = math.floor((i - 1) / cols), (i - 1) % cols
      local rr = r - lp.tscroll
      if rr >= 0 and rr < tview then
        local a = OS.apps[id]
        local bg = C[a.icon or "acc"] or C.acc
        local fg = C[a.fg or "wht"] or C.wht
        local tx, ty = tx0 + c * (tw + 1), ly0 + rr * 4
        box(tx, ty, tw, 3, bg)
        put(tx + math.floor((tw - 3) / 2), ty + 1, tostring(a.glyph or " ? "), fg, bg)
        put(tx + 1, ty + 2, OS.trunc(tostring(a.title or id), tw - 2), fg, bg)
        lp.hits[#lp.hits + 1] = { x = tx, y = ty, w = tw, h = 3, id = id }
      end
    end
  end
  -- power menu
  if lp.power then
    local items = {
      { "Lock", function() OS.lock() end },
      { "Exit to CraftOS", function() OS.quit = true end },
      { "Restart", function() os.reboot() end },
      { "Shut down", function() OS.sfx("shutdown"); sleep(0.9); os.shutdown() end },
    }
    local pw = 18
    local py = H - 1 - #items
    box(x0 + rail, py, pw, #items, C.bar)
    for i, it in ipairs(items) do
      put(x0 + rail + 1, py + i - 1, OS.trunc(it[1], pw - 2), C.text, C.bar)
      lp.pbtns[#lp.pbtns + 1] = { x = x0 + rail, y = py + i - 1, w = pw, h = 1, fn = function() OS.lp = nil; it[2]() end }
    end
  end
end

local function drawMenu()
  local m = OS.menu
  if not m then return end
  local w = 4
  for _, it in ipairs(m) do w = math.max(w, #it[1] + 4) end
  m.w = w; m.y0 = H - #m
  box(1, m.y0, w, #m, C.bar)
  for i, it in ipairs(m) do
    local y = m.y0 + i - 1
    if it[1] == "-" then put(2, y, ("-"):rep(w - 2), C.sub, C.bar)
    else put(2, y, " " .. it[1] .. (" "):rep(w - #it[1] - 3), C.text, C.bar) end
  end
end

local function drawToast()
  local t = OS.toastMsg
  if not t then return end
  if os.clock() > t.t then OS.toastMsg = nil return end
  local lines = OS.wrap(t.s, math.min(36, W - 4))
  local w = 0
  for _, l in ipairs(lines) do w = math.max(w, #l) end
  local bx, by = W - w - 3, H - #lines - 2
  box(bx, by, w + 4, #lines + 2, C.bar)
  for j = 0, #lines + 1 do put(bx, by + j, " ", C.wht, C.acc) end
  for i, l in ipairs(lines) do put(bx + 2, by + i, l, C.text, C.bar) end
end

local function openMenu()
  if OS.menu then OS.menu = nil return end
  OS.panel = nil; OS.lp = nil
  OS.menu = {
    { "About your PC", function() OS.open("settings", "about") end },
    { "Windows Update", function() OS.open("updater") end },
    { "-" },
    { "Start", function() OS.toggleLP() end },
    { "Store", function() OS.open("store") end },
    { "Task Manager", function() OS.open("monitor") end },
    { "Command Prompt", function() OS.open("terminal") end },
    { "File Explorer", function() OS.open("files") end },
    { "Settings", function() OS.open("settings") end },
    { "-" },
    { (cfg.snd.sys or cfg.snd.sfx or cfg.snd.music) and "Mute all sounds" or "Unmute sounds", function()
        local on = not (cfg.snd.sys or cfg.snd.sfx or cfg.snd.music)
        cfg.snd.sys, cfg.snd.sfx, cfg.snd.music = on, on, on; OS.dirty = true
        if not on then OS.snd.track = nil end
      end },
    { "Lock", function() OS.lock() end },
    { "Exit to CraftOS", function() OS.quit = true end },
    { "Restart", function() os.reboot() end },
    { "Shut down", function() OS.sfx("shutdown"); sleep(0.9); os.shutdown() end },
  }
  OS.menu.y0 = H - #OS.menu
end

function OS.lock()
  OS.mode = "lock"; OS.screen = OS.lockScreen(); OS.menu = nil; OS.panel = nil; OS.sfx("lock")
end

----------------------------------------------------------------------- screens
local FONT = {
  ["0"] = { "111", "101", "101", "101", "111" }, ["1"] = { "010", "110", "010", "010", "111" },
  ["2"] = { "111", "001", "111", "100", "111" }, ["3"] = { "111", "001", "111", "001", "111" },
  ["4"] = { "101", "101", "111", "001", "001" }, ["5"] = { "111", "100", "111", "001", "111" },
  ["6"] = { "111", "100", "111", "101", "111" }, ["7"] = { "111", "001", "001", "001", "001" },
  ["8"] = { "111", "101", "111", "101", "111" }, ["9"] = { "111", "101", "111", "001", "111" },
  [":"] = { "0", "1", "0", "1", "0" } }
local function bigClock(y)
  local s = OS.clockStr(true)
  local total = 0
  for i = 1, #s do total = total + #FONT[s:sub(i, i)][1] * 2 + (i < #s and 2 or 0) end
  local x = math.floor((W - total) / 2) + 1
  for i = 1, #s do
    local gl = FONT[s:sub(i, i)]
    for r = 1, 5 do
      for c = 1, #gl[1] do
        if gl[r]:sub(c, c) == "1" then put(x + (c - 1) * 2, y + r - 1, "  ", C.text, C.text) end
      end
    end
    x = x + #gl[1] * 2 + 2
  end
end

-- Identify: show a pop-up with the number and peripheral name on every monitor (like macOS "Identify displays")
-- Stable numbers for monitors (same number every time, whatever the layout): ordered by the number in the peripheral name
function OS.monMap()
  local names = {}
  for _, n in ipairs(peripheral.getNames()) do if peripheral.getType(n) == "monitor" then names[#names + 1] = n end end
  table.sort(names, function(a, b)
    local na, nb = tonumber(a:match("(%d+)$")) or 0, tonumber(b:match("(%d+)$")) or 0
    if na ~= nb then return na < nb end
    return a < b
  end)
  local map = {}
  for i, n in ipairs(names) do map[n] = i end
  return map
end
function OS.identList()
  local list, seen = {}, {}
  local function add(name, extra)
    if name and name ~= "term" and not seen[name] then seen[name] = true; list[#list + 1] = { name = name, extra = extra } end
  end
  if OS.span then
    for _, sg in ipairs(OS.span.segs) do add(sg.name, "X " .. sg.c .. ", Y " .. sg.r) end
  else
    for _, id in ipairs(OS.displayIds()) do add(id) end
  end
  for _, n in ipairs(peripheral.getNames()) do
    if peripheral.getType(n) == "monitor" then add(n, "not in use") end
  end
  return list
end
function OS.identify(secs)
  OS.idUntil = os.clock() + (secs or 6)
  OS.timer((secs or 6) + 0.3, function() end)
end
local function identDraw()
  for i, e in ipairs(OS.identList()) do
    pcall(function()
      local m = (e.name == OS.parentName) and parent or peripheral.wrap(e.name)
      if not m then return end
      OS.overlaid = OS.overlaid or {}; OS.overlaid[e.name] = true
      local w, h = m.getSize()
      local bw, bh = math.min(w, 30), math.min(h, 12)
      local bx, by = math.floor((w - bw) / 2) + 1, math.floor((h - bh) / 2) + 1
      m.setBackgroundColor(C.win); m.setTextColor(C.text)
      for r = 0, bh - 1 do m.setCursorPos(bx, by + r); m.write((" "):rep(bw)) end
      local ds = tostring(i)
      if bh >= 9 and bw >= 12 then
        local tw = 0
        for k = 1, #ds do tw = tw + #FONT[ds:sub(k, k)][1] * 2 + 1 end
        local x = bx + math.floor((bw - tw) / 2)
        m.setBackgroundColor(C.acc)
        for k = 1, #ds do
          local gl = FONT[ds:sub(k, k)]
          for r = 1, 5 do
            for c = 1, #gl[1] do
              if gl[r]:sub(c, c) == "1" then m.setCursorPos(x + (c - 1) * 2, by + r); m.write("  ") end
            end
          end
          x = x + #gl[1] * 2 + 1
        end
        m.setBackgroundColor(C.win)
        local nm = e.name:sub(1, bw - 2)
        m.setTextColor(C.text); m.setCursorPos(bx + math.floor((bw - #nm) / 2), by + 7); m.write(nm)
        if e.extra then
          local ex = e.extra:sub(1, bw - 2)
          m.setTextColor(C.sub); m.setCursorPos(bx + math.floor((bw - #ex) / 2), by + 9); m.write(ex)
        end
      else
        local t = i .. "  " .. e.name
        t = t:sub(1, bw)
        m.setTextColor(C.wht); m.setCursorPos(bx, by + math.floor(bh / 2)); m.write(t)
      end
    end)
  end
end
-- blank every monitor the pop-ups were drawn on that the desktop doesn't use
function OS.clearUnused()
  local used = {}
  if OS.span then for _, sg in ipairs(OS.span.segs) do if sg.name then used[sg.name] = true end end end
  for n in pairs(OS.mirrors or {}) do used[n] = true end
  if OS.parentName then used[OS.parentName] = true end
  for n in pairs(OS.overlaid or {}) do
    if not used[n] then
      if peripheral.isPresent(n) then pcall(function() local m = peripheral.wrap(n); m.setBackgroundColor(C.desk); m.clear() end) end
    end
    OS.overlaid[n] = nil
  end
end
-- put every screen back after the pop-ups
local function identClear()
  OS.idUntil = nil
  if OS.span then for k in pairs(OS.span.last) do OS.span.last[k] = {} end end
  for k in pairs(OS.mirrorLast or {}) do OS.mirrorLast[k] = nil end
  local used = {}
  if OS.span then for _, sg in ipairs(OS.span.segs) do if sg.name then used[sg.name] = true end end end
  for n in pairs(OS.mirrors or {}) do used[n] = true end
  if OS.parentName then used[OS.parentName] = true end
  for _, n in ipairs(peripheral.getNames()) do
    if peripheral.getType(n) == "monitor" and not used[n] then
      pcall(function() local m = peripheral.wrap(n); m.setBackgroundColor(C.desk); m.clear() end)
    end
  end
  OS.clearUnused()
  if not OS.span then pcall(function() T.redraw() end) end
end

-- ===== Place mode: every monitor shows its number with arrows; touching an arrow moves that screen's piece of the
-- desktop one step in that direction on the real wall (it swaps with the monitor next to it). Updates live.
function OS.wallInfo()
  if not OS.span then return nil end
  local ids = {}
  for _, sg in ipairs(OS.span.segs) do ids[#ids + 1] = sg.name or "term" end
  local w = cfg.wallOrder
  local ok = type(w) == "table" and #w == #ids
  if ok then
    local set = {}
    for _, v in ipairs(ids) do set[v] = true end
    for _, v in ipairs(w) do if not set[v] then ok = false end end
  end
  if ok then return ids, w, math.max(1, math.min(#w, cfg.wallCols or OS.span.cols or #w)), true end
  -- no touching needed: the wall is simply the desktop layout as it is now
  return ids, ids, OS.span.cols or #ids, true
end
-- the monitor physically next to `id` in direction l / r / u / d (nil at the edge of the wall)
function OS.wallNeighbor(id, dir)
  local ids, wall, pc, known = OS.wallInfo()
  if not ids or not known then return nil end
  local pos
  for i, v in ipairs(wall) do if v == id then pos = i end end
  if not pos then return nil end
  local n, to = #wall, nil
  if dir == "l" and (pos - 1) % pc > 0 then to = pos - 1
  elseif dir == "r" and pos % pc ~= 0 and pos < n then to = pos + 1
  elseif dir == "u" then to = pos - pc
  elseif dir == "d" then to = pos + pc end
  if to and to >= 1 and to <= n then return wall[to] end
end
function OS.placeMove(id, dir)
  local ids, _, _, known = OS.wallInfo()
  if not ids then return false end
  local nb = OS.wallNeighbor(id, dir)
  if not nb then return false end
  local a, b
  for i, v in ipairs(ids) do if v == id then a = i elseif v == nb then b = i end end
  if not a or not b then return false end
  ids[a], ids[b] = ids[b], ids[a]
  cfg.spanOrder = ids; OS.save(); OS.setupDisplay()
  if OS.place then OS.place.dirty = true end
  return true
end
-- Reset: forget any saved wall, re-read every screen's size and rebuild the layout (no touching needed)
function OS.recalibrate()
  cfg.wallOrder = nil; cfg.wallCols = nil; OS.save()
  OS.setupDisplay()
  OS.toast("Displays re-detected", 3)
end
function OS.startPlace()
  if not OS.span then OS.identify(8); return end
  OS.place = { t0 = os.clock(), dirty = true, hits = {} }
end
function OS.endPlace()
  OS.place = nil
  OS.setupDisplay()
  OS.clearUnused()
end
function OS.placeTouch(name, x, y)
  local hs = OS.place and OS.place.hits[name]
  if not hs then return end
  for _, h in ipairs(hs) do
    if x >= h.x1 and x <= h.x2 and y >= h.y1 and y <= h.y2 then
      if h.dir == "done" then OS.endPlace() else OS.placeMove(name, h.dir) end
      OS.place = OS.place or nil
      if OS.place then OS.place.dirty = true end
      return
    end
  end
end
local function placeDraw()
  local pl = OS.place
  if not pl.dirty then return end
  pl.dirty = false
  pl.hits = {}
  local pos = {}
  if OS.span then for i, sg in ipairs(OS.span.segs) do pos[sg.name or "term"] = i end end
  for _, e in ipairs(OS.identList()) do
    pcall(function()
      local m = (e.name == OS.parentName) and parent or peripheral.wrap(e.name)
      if not m then return end
      OS.overlaid = OS.overlaid or {}; OS.overlaid[e.name] = true
      local w, h = m.getSize()
      m.setBackgroundColor(C.desk); m.setTextColor(C.text); m.clear()
      local function bar(x, y, n, col) m.setBackgroundColor(col); m.setCursorPos(x, y); m.write((" "):rep(n)) end
      local function say(y, t, fg)
        t = t:sub(1, w)
        m.setBackgroundColor(C.desk); m.setTextColor(fg); m.setCursorPos(math.max(1, math.floor((w - #t) / 2) + 1), y); m.write(t)
      end
      local num = pos[e.name]
      local mid = math.floor(h / 2)
      -- big number
      if num and h >= 12 then
        local ds = tostring(num)
        local tw = 0
        for k = 1, #ds do tw = tw + #FONT[ds:sub(k, k)][1] * 2 + 1 end
        local x = math.floor((w - tw) / 2) + 1
        for k = 1, #ds do
          local gl = FONT[ds:sub(k, k)]
          for r = 1, 5 do
            for c = 1, #gl[1] do
              if gl[r]:sub(c, c) == "1" then bar(x + (c - 1) * 2, mid - 3 + r, 2, C.acc) end
            end
          end
          x = x + #gl[1] * 2 + 1
        end
      elseif num then say(mid, tostring(num), C.acc) end
      say(mid + 4, e.name, C.text)
      say(mid + 5, num and "desktop position" or "not in use", C.sub)
      if not num then return end
      -- arrows only where there is a monitor to swap with
      local K = math.max(2, math.min(6, math.floor((h - 8) / 3), math.floor((w - 14) / 8)))
      local hits = {}
      local function chevron(dir)
        local pts = {}
        if dir == "l" then for k = 0, K do pts[#pts + 1] = { 3 + 2 * (K - k), mid - K + k }; pts[#pts + 1] = { 3 + 2 * (K - k), mid + K - k } end
        elseif dir == "r" then for k = 0, K do pts[#pts + 1] = { w - 4 - 2 * (K - k), mid - K + k }; pts[#pts + 1] = { w - 4 - 2 * (K - k), mid + K - k } end
        elseif dir == "u" then for k = 0, K do pts[#pts + 1] = { math.floor(w / 2) - 2 * k, 3 + k }; pts[#pts + 1] = { math.floor(w / 2) + 2 * k, 3 + k } end
        else for k = 0, K do pts[#pts + 1] = { math.floor(w / 2) - 2 * k, h - 3 - k }; pts[#pts + 1] = { math.floor(w / 2) + 2 * k, h - 3 - k } end end
        local x1, y1, x2, y2 = 1e9, 1e9, -1e9, -1e9
        for _, p in ipairs(pts) do
          bar(p[1], p[2], 3, C.sub)
          x1, y1, x2, y2 = math.min(x1, p[1]), math.min(y1, p[2]), math.max(x2, p[1] + 2), math.max(y2, p[2])
        end
        hits[#hits + 1] = { x1 = x1 - 2, y1 = y1 - 1, x2 = x2 + 2, y2 = y2 + 1, dir = dir }
      end
      for _, d in ipairs({ "l", "r", "u", "d" }) do if OS.wallNeighbor(e.name, d) then chevron(d) end end
      -- done button
      local dw = 8
      local dx = math.floor((w - dw) / 2) + 1
      bar(dx, h - 1, dw, C.acc)
      m.setTextColor(C.wht); m.setCursorPos(dx + 1, h - 1); m.write(" Done  ")
      hits[#hits + 1] = { x1 = dx, y1 = h - 1, x2 = dx + dw - 1, y2 = h - 1, dir = "done" }
      say(2, "Touch an arrow to move this screen", C.sub)
      pl.hits[e.name] = hits
    end)
  end
end

local function card(w, h)
  local x, y = math.floor((W - w) / 2) + 1, math.max(2, math.floor((H - h) / 2) + 1)
  roundBox(x, y, w, h, C.win)
  return x, y
end

function OS.lockScreen()
  local scr = { hots = {}, active = true }
  local pw = OS.field("", { mask = true, max = 40 })
  scr.focus = pw; scr.keepFocus = pw
  scr.fails = 0; scr.msg = ""
  local function try()
    if os.clock() < (scr.until_ or 0) then scr.msg = "Too many attempts, wait " .. math.ceil(scr.until_ - os.clock()) .. "s"; return end
    if not cfg.hash or OS.hashPw(pw.text, cfg.salt) == cfg.hash then
      OS.mode = "desktop"; OS.screen = nil; scr.fails = 0; OS.sfx("login")
    else
      OS.sfx("error")
      scr.fails = scr.fails + 1; scr.msg = "Wrong password"
      if scr.fails >= 3 then scr.until_ = os.clock() + (scr.fails - 2) * 5 end
    end
    pw.text = ""; pw.pos = 0
  end
  pw.onEnter = try
  function scr.draw(self, g)
    drawWall()
    if H >= 19 and W >= 36 then
      bigClock(2)
      local tt = nowT()
      local dstr = (DAYNAMES[tt.wday] or "") .. ", " .. (MONTHS[tt.month] or "") .. " " .. tt.day
      OS.wallText(math.floor((W - #dstr) / 2) + 1, 8, dstr, C.wht)
    end
    local cw, ch = math.min(32, W - 2), 9
    local x, y = math.floor((W - cw) / 2) + 1, math.max(2, math.floor((H - ch) / 2) + 1)
    if H >= 19 then y = math.max(y, 9) end
    roundBox(x, y, cw, ch, C.win)
    local function center(row, s, col) g.put(x + math.floor((cw - #s) / 2), row, s, col, C.win) end
    center(y + 1, "Day " .. os.day() .. "  " .. OS.clockStr(), C.sub)
    roundBox(x + math.floor(cw / 2) - 2, y + 2, 5, 1, C.acc)
    g.put(x + math.floor(cw / 2), y + 2, (cfg.user or "u"):sub(1, 1):upper(), C.wht, C.acc)
    center(y + 3, cfg.user or "user", C.text)
    pw.placeholder = "Enter password"
    if cfg.hash then g.field(x + 3, y + 5, cw - 6, pw)
    else center(y + 5, "Press Enter or click Sign in", C.sub) end
    if scr.msg ~= "" then center(y + 6, scr.msg, C.red) end
    g.btn(x + math.floor((cw - 10) / 2), y + 7, " Sign in  ", try, "pri")
  end
  return scr
end

function OS.setupScreen()
  local scr = { hots = {}, active = true, msg = "" }
  local f = {
    host = OS.field(os.getComputerLabel() or "DESKTOP-CC", { max = 16 }), user = OS.field("", { max = 16, placeholder = "your name" }),
    pw = OS.field("", { mask = true, max = 40, placeholder = "optional" }), pw2 = OS.field("", { mask = true, max = 40, placeholder = "repeat" }) }
  scr.focus = f.user
  local function create()
    if f.user.text == "" then scr.msg = "Please enter a user name"; return end
    if f.pw.text ~= f.pw2.text then scr.msg = "Passwords don't match"; return end
    if f.pw.text ~= "" and #f.pw.text < 4 then scr.msg = "Use at least 4 characters"; return end
    cfg.user = f.user.text; cfg.host = f.host.text ~= "" and f.host.text or "DESKTOP-CC"
    if f.pw.text ~= "" then cfg.salt = OS.newSalt(); cfg.hash = OS.hashPw(f.pw.text, cfg.salt) end
    pcall(os.setComputerLabel, cfg.host)
    OS.save(); OS.mode = "desktop"; OS.screen = nil; OS.sfx("login")
    OS.toast("Welcome, " .. cfg.user .. "!")
  end
  f.user.onEnter = function() scr.focus = f.pw end
  f.pw.onEnter = function() scr.focus = f.pw2 end
  f.pw2.onEnter = create
  f.host.onEnter = function() scr.focus = f.user end
  function scr.draw(self, g)
    drawWall()
    local cw, ch = math.min(40, W - 2), 14
    local x, y = card(cw, ch)
    local function center(row, s, col) g.put(x + math.floor((cw - #s) / 2), row, s, col, C.win) end
    box(x + math.floor(cw / 2) - 3, y + 1, 7, 1, C.acc)
    OS.startLogo(x + math.floor(cw / 2) - 1, y + 1, C.wht, C.acc)
    center(y + 2, "Hi! Let's set up " .. OS.verName(), C.text)
    center(y + 3, "Create your account", C.sub)
    local lx, fw = x + 2, cw - 4
    g.put(lx, y + 4, "Computer name", C.sub, C.win); g.field(lx, y + 5, fw, f.host)
    g.put(lx, y + 6, "User name", C.sub, C.win); g.field(lx, y + 7, fw, f.user)
    g.put(lx, y + 8, "Password (blank = no lock)", C.sub, C.win); g.field(lx, y + 9, fw, f.pw)
    g.put(lx, y + 10, "Confirm", C.sub, C.win); g.field(lx, y + 11, fw, f.pw2)
    if scr.msg ~= "" then center(y + 12, scr.msg, C.red) end
    g.btn(x + math.floor((cw - 16) / 2), y + 13, " Create account ", create, "pri")
  end
  return scr
end

local function bootScreen()
  local scr = { hots = {}, active = true, p = 0 }
  function scr.draw(self, g)
    g.fill(1, 1, W, H, C.sp0)
    local cx, cy = math.floor(W / 2), math.floor(H / 2)
    local ph = math.max(2, math.min(4, math.floor(H / 6)))
    local pw = math.max(3, math.floor(ph * 1.7 + 0.5))
    local tw, th = pw * 2 + 1, ph * 2 + 1
    local x0, y0 = cx - math.floor(tw / 2), cy - math.floor(th / 2) - 1
    for r = 0, 1 do
      for c = 0, 1 do box(x0 + c * (pw + 1), y0 + r * (ph + 1), pw, ph, C.acc) end
    end
    local lit = math.floor(scr.p * 32) % 5
    for i = 0, 4 do put(cx - 4 + i * 2, y0 + th + 2, i == lit and "o" or ".", i == lit and C.wht or C.sub, C.sp0) end
  end
  return scr
end

----------------------------------------------------------------------- input handling
local function inRect(x, y, r) return r and x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h end

----------------------------------------------------------------------- top-bar panels (quick settings, calendar, system stats)
local PAN = { hots = {}, x = 0, y = 0 }
OS.weather = { t = -1e9 }
function OS.fetchWeather()
  local wx = OS.weather
  if os.clock() - wx.t < 600 then return end
  wx.t = os.clock(); wx.txt = nil
  if not http then wx.txt = "http disabled" return end
  local city = (cfg.city or ""):gsub("%s+", "+")
  OS.http("https://wttr.in/" .. city .. "?format=%25C+%25t", function(data)
    if data and #data < 80 then wx.txt = OS.clean(data) else wx.txt = "unavailable" end
  end)
end

local function togglePanel(kind)
  if OS.panel and OS.panel.kind == kind then OS.panel = nil return end
  OS.panel = { kind = kind, off = 0 }; OS.menu = nil
  if kind == "cal" then OS.fetchWeather() end
  OS.sfx("open")
end

local function pill(g, x, y, w, label, on, fn)
  local bg, fg = on and C.acc or C.bar, on and C.wht or C.text
  g.fill(x, y, w, 2, bg)
  g.put(x + 1, y, label, fg, bg)
  g.put(x + 1, y + 1, on and "On" or "Off", on and C.wht or C.sub, bg)
  g.hot(x, y, w, 2, fn)
end

local function drawQuick(g, w)
  g.put(1, 1, OS.trunc(cfg.user or "user", w - 14), C.text, C.win)
  g.btn(w - 11, 1, "Lock", function() OS.panel = nil; OS.lock() end)
  g.btn(w - 5, 1, "Off", function() OS.panel = nil; OS.sfx("shutdown"); sleep(0.9); os.shutdown() end, "danger")
  local c0 = math.floor(w / 2)
  local items = {
    { "Sound", anySnd() and true or false, function()
        local on = not anySnd(); local c = cfg.snd; c.sys, c.sfx, c.music = on, on, on
        if not on then OS.snd.track = nil end; OS.dirty = true end },
    { "Darker mode", cfg.darker, function() cfg.darker = not cfg.darker; OS.applyTheme(); OS.dirty = true end },
    { "Focus assist", cfg.dnd, function() cfg.dnd = not cfg.dnd; OS.dirty = true end },
    { "Night Light", cfg.night, function() cfg.night = not cfg.night; OS.applyTheme(); OS.dirty = true end },
    { "Ambient Music", cfg.snd.amb, function() cfg.snd.amb = not cfg.snd.amb; OS.dirty = true end },
    { "Game Effects", cfg.snd.sfx, function() cfg.snd.sfx = not cfg.snd.sfx; OS.dirty = true end },
  }
  for i, it in ipairs(items) do
    local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
    local x = 1 + col * c0
    pill(g, x, 3 + row * 2, col == 0 and (c0 - 1) or (w - c0), it[1], it[2] and true or false, it[3])
  end
  g.put(1, 10, "System volume " .. math.floor(cfg.snd.vol * 100 + 0.5) .. "%", C.sub, C.win)
  g.slider(1, 11, w, cfg.snd.vol, function(v) cfg.snd.vol = v; OS.dirty = true end, C.acc, C.bar)
  g.put(1, 12, "Music volume " .. math.floor(cfg.music.vol * 100 + 0.5) .. "%", C.sub, C.win)
  g.slider(1, 13, w, cfg.music.vol, function(v) Audio.setVol(v) end, C.acc, C.bar)
  local bx = 1
  bx = bx + g.btn(bx, 14, "Task Manager", function() OS.panel = nil; OS.open("monitor") end) + 1
  g.btn(bx, 14, "Settings", function() OS.panel = nil; OS.open("settings") end)
end

local function drawCal(g, w, p)
  local wx = OS.weather
  g.put(1, 1, OS.trunc((cfg.city and cfg.city ~= "") and cfg.city or "Weather", w), C.sub, C.win)
  g.put(1, 2, OS.trunc(wx.txt or "loading...", w), C.text, C.win)
  local t = nowT()
  local m, y = t.month + p.off, t.year
  while m > 12 do m = m - 12; y = y + 1 end
  while m < 1 do m = m + 12; y = y - 1 end
  g.btn(1, 4, "<", function() p.off = p.off - 1 end)
  local title = MONTHS[m] .. " " .. y
  g.put(math.floor((w - #title) / 2) + 1, 4, title, C.text, C.win)
  g.btn(w - 2, 4, ">", function() p.off = p.off + 1 end)
  local hd = { "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" }
  for c = 1, 7 do g.put(2 + (c - 1) * 3, 6, hd[c], C.sub, C.win) end
  local first = wdayOf(y, m, 1)
  for d = 1, daysIn(y, m) do
    local idx = first + d - 1
    local col, row = idx % 7, math.floor(idx / 7)
    local today = (y == t.year and m == t.month and d == t.day)
    g.put(1 + col * 3, 7 + row, string.format("%2d ", d), today and C.wht or C.text, today and C.acc or C.win)
  end
  g.put(1, 14, DAYNAMES[t.wday] or "", C.sub, C.win)
  g.put(1, 15, string.format("%s %d %d", MONTHS[t.month], t.day, t.year), C.text, C.win)
  local ig = os.time()
  g.put(1, 16, string.format("Game: day %d  %02d:%02d", os.day(), math.floor(ig) % 24, math.floor((ig - math.floor(ig)) * 60)), C.sub, C.win)
end

local function statRow(g, w, y, label, value, ratio)
  g.put(1, y, label, C.text, C.win)
  g.put(w - #value + 1, y, value, C.sub, C.win)
  if ratio then
    g.fill(1, y + 1, w, 1, C.bar)
    g.fill(1, y + 1, math.max(0, math.min(w, math.floor(ratio * w + 0.5))), 1, C.acc)
  end
end

local function drawStats(g, w)
  local st = OS.sysStats()
  statRow(g, w, 1, "Memory", st.hasMem and string.format("%d KB", math.floor(st.mem)) or "n/a", st.hasMem and st.mem / 4096 or 0)
  statRow(g, w, 4, "Disk", string.format("%d%% used", math.floor(st.disk * 100)), st.disk)
  statRow(g, w, 7, "Speakers", st.spk .. " of " .. st.spkAll .. " on")
  statRow(g, w, 8, "Windows", tostring(st.wins))
  statRow(g, w, 9, "Uptime", OS.fmtTime(st.up))
  g.btn(1, 11, "Task Manager", function() OS.panel = nil; OS.open("monitor") end, "pri")
end

local function drawPanel()
  local p = OS.panel
  if not p then OS.panRect = nil return end
  local pw = p.kind == "cal" and 27 or (p.kind == "stats" and 32 or 34)
  local ph = p.kind == "cal" and 19 or (p.kind == "stats" and 13 or 16)
  pw = math.min(pw, W); ph = math.min(ph, H - 1)
  local px = W - pw + 1
  if p.kind == "stats" and OS.barHits and OS.barHits.stats then px = math.min(px, OS.barHits.stats.x) end
  px = math.max(1, px)
  local py = H - ph
  box(px, py, pw, ph, C.win)
  for j = 0, ph - 1 do put(px, py + j, "\149", C.acc, C.win) end
  OS.panRect = { x = px, y = py, w = pw, h = ph }
  PAN.hots = {}; PAN.x = px; PAN.y = py
  local g = newG(PAN, px + 1, py + 1, pw - 2, ph - 2)
  if p.kind == "quick" then drawQuick(g, pw - 2)
  elseif p.kind == "cal" then drawCal(g, pw - 2, p)
  else drawStats(g, pw - 2) end
end

local function barClick(x)
  local bh = OS.barHits or {}
  local map = { { "clock", "cal" }, { "quick", "quick" }, { "stats", "stats" } }
  for _, m in ipairs(map) do
    local rct = bh[m[1]]
    if rct and x >= rct.x and x < rct.x + rct.w then return m[2] end
  end
end


-- ===== window snapping / tap-to-move / tap-to-resize (monitors only send taps, so the touch way is "pick up, then tap where it goes")
function OS.workBottom() return H - 1 end
function OS.snapRect(x, y)
  local uh = H - 1
  local hw, hh = math.floor(W / 2), math.floor(uh / 2)
  local L, R = x <= 3, x >= W - 2
  local T_, B = y <= 2, y >= H - 2
  if (L or R) and T_ then return L and { 1, 1, hw, hh } or { hw + 1, 1, W - hw, hh } end
  if (L or R) and B then return L and { 1, 1 + hh, hw, uh - hh } or { hw + 1, 1 + hh, W - hw, uh - hh } end
  if L then return { 1, 1, hw, uh } end
  if R then return { hw + 1, 1, W - hw, uh } end
  if T_ then return { 1, 1, W, uh } end
  return nil
end
function OS.snapWin(win, x, y)
  local r = OS.snapRect(x, y)
  if not r then return false end
  if r[3] < (win.app.minw or 24) or r[4] < (win.app.minh or 8) then return false end
  if not win.snapPrev and not win.max then win.snapPrev = { w = win.w, h = win.h } end
  win.x, win.y, win.w, win.h = r[1], r[2], r[3], r[4]
  win.max = false; win.cmp = nil
  return true
end
function OS.applyGrab(g, x, y)
  local win = g.win
  if g.mode == "move" then
    if OS.snapWin(win, x, y) then return end
    if win.snapPrev then win.w, win.h = win.snapPrev.w, win.snapPrev.h; win.snapPrev = nil end
    win.x = math.max(2 - win.w + 8, math.min(W - 8, x - g.dx)); win.y = math.max(1, math.min(H - 2, y - g.dy))
  else
    win.snapPrev = nil
    if g.mode == "se" or g.mode == "e" then win.w = math.max(win.app.minw or 24, math.min(W - win.x + 1, x - win.x + 1)) end
    if g.mode == "se" or g.mode == "s" then win.h = math.max(win.app.minh or 8, math.min(H - win.y, y - win.y + 1)) end
  end
end

local function desktopClick(btn, x, y)
  if OS.lp and OS.lp.t0 and os.clock() - OS.lp.t0 < 0.6 then return end -- the touch that opened the grid must not also close it
  if OS.grab then
    local gr = OS.grab; OS.grab = nil
    if gr.win and not gr.win.closed then OS.applyGrab(gr, x, y) end
    return
  end
  if OS.lp then
    if not inRect(x, y, OS.dockRect) then
      local lp = OS.lp
      if lp.power then
        for _, b in ipairs(lp.pbtns or {}) do
          if inRect(x, y, b) then lp.power = nil; b.fn() return end
        end
        lp.power = nil
        return
      end
      for _, b in ipairs(lp.btns or {}) do
        if inRect(x, y, b) then b.fn() return end
      end
      for _, h in ipairs(lp.hits or {}) do
        if inRect(x, y, h) then
          if h.win then OS.lp = nil; h.win.min = false; OS.raise(h.win) return end
          if btn == 2 then OS.dockToggle(h.id) return end
          if lp.edit then lp.sel = h.id return end
          OS.lp = nil; OS.launch(h.id) return
        end
      end
      if lp.rect and inRect(x, y, lp.rect) and not lp.tv then return end
      if not lp.edit then OS.lp = nil end
      return
    end
  end
  local closedKind
  if OS.panel then
    if inRect(x, y, OS.panRect) then hit(PAN, x - PAN.x, y - PAN.y, btn) return end
    closedKind = OS.panel.kind; OS.panel = nil
  end
  if OS.menu then
    local m = OS.menu
    if x >= 1 and x <= (m.w or 0) and y >= (m.y0 or H) and y <= H - 1 then
      local it = m[y - m.y0 + 1]
      OS.menu = nil
      if it and it[2] then it[2]() end
      return
    end
    OS.menu = nil
    if y == H and x <= 5 then return end
  end
  if inRect(x, y, OS.dockRect) then
    if OS.dockRect.hidden then
      OS.dockUntil = os.clock() + 6; OS.timer(6.3, function() end)
      return
    end
    if cfg.dockHide then OS.dockUntil = os.clock() + 6; OS.timer(6.3, function() end) end
    if x <= 5 then
      if btn == 2 then openMenu() else OS.toggleLP() end
      return
    end
    OS.lp = nil
    local bh = OS.barHits or {}
    local function inX(r) return r and x >= r.x and x < r.x + r.w end
    local kind = barClick(x)
    if kind then
      if kind ~= closedKind then togglePanel(kind) end
      return
    end
    if inX(bh.desk) then OS.showDesktop() return end
    if inX(bh.taskview) then OS.toggleTV() return end
    if inX(bh.search) then OS.toggleLP() return end
    if inX(OS.musicHit) then OS.launch("music") return end
    for _, ic in ipairs(OS.dockIcons or {}) do
      if x >= ic.x and x <= ic.x + 3 then
        if btn == 2 then OS.dockToggle(ic.id) else OS.taskbarClick(ic.id) end
        return
      end
    end
    return
  end
  for i = #OS.wins, 1, -1 do
    local win = OS.wins[i]
    if not win.min and x >= win.x and x < win.x + win.w and y >= win.y and y < win.y + win.h then
      OS.raise(win)
      if win.cmp then
        if y == win.y then
          if x >= W - 2 then OS.close(win) elseif x >= W - 5 then win.min = true end
        else hit(win, x - win.x, y - win.y, btn) end
      elseif y == win.y then
        local dx = win.x + win.w - 1 - x
        if dx <= 2 then OS.close(win)
        elseif dx <= 5 then OS.maximize(win)
        elseif dx <= 8 then win.min = true
        else
          local now = os.clock()
          if win.lastTitle and now - win.lastTitle < 0.5 then OS.maximize(win); win.lastTitle = nil
          else
            win.lastTitle = now
            if OS.touchMode then
              OS.grab = { win = win, mode = "move", dx = x - win.x, dy = y - win.y }
              OS.toast("Tap where the window goes. Edges and corners snap it.", 4)
            elseif not win.max then OS.drag = { win = win, dx = x - win.x, dy = y - win.y } end
          end
        end
      elseif not win.max and ((y == win.y + win.h - 1) or (x == win.x + win.w - 1)) then
        local mode = (y == win.y + win.h - 1) and (x >= win.x + win.w - 3 and "se" or "s") or "e"
        if OS.touchMode then
          OS.grab = { win = win, mode = mode }
          OS.toast("Tap where the " .. (mode == "se" and "corner" or (mode == "s" and "bottom" or "right edge")) .. " should go", 4)
        else OS.drag = { win = win, rs = true, mode = mode } end
      else
        hit(win, x - win.x, y - win.y, btn)
        if win.app.click and not OS.dragConsumed then end
      end
      return
    end
  end
  -- desktop shortcuts
  for _, ic in ipairs(OS.deskIcons or {}) do
    if inRect(x, y, ic) then
      local now = os.clock()
      if OS.touchMode or (OS.deskSel == ic.id and OS.deskClick and now - OS.deskClick < 0.7) then
        OS.deskSel = nil; OS.launch(ic.id)
      else OS.deskSel = ic.id; OS.deskClick = now end
      return
    end
  end
  OS.deskSel = nil
end

local function dragMove(x, y, btn)
  local d = OS.drag
  if not d then return end
  if d.hot then
    local ox, oy = 0, 0
    if d.hld ~= OS.screen then ox, oy = d.hld.x or 0, d.hld.y or 0 end
    d.hot.fn(x - ox, y - oy, btn, "drag")
  elseif d.rs then
    local w = d.win
    w.snapPrev = nil
    if d.mode ~= "s" then w.w = math.max(w.app.minw or 24, math.min(W - w.x + 1, x - w.x + 1)) end
    if d.mode ~= "e" then w.h = math.max(w.app.minh or 8, math.min(H - w.y, y - w.y + 1)) end
  else
    local w = d.win
    w.x = math.max(2 - w.w + 8, math.min(W - 8, x - d.dx)); w.y = math.max(1, math.min(H - 2, y - d.dy))
  end
end

function OS.toggleVC()
  if OS.vc then OS.vc = nil; cfg.ctl = false; OS.toast("Controller cursor off (F8)", 2)
  else OS.vc = { x = math.floor(W / 2), y = math.floor(H / 2) }; cfg.ctl = true; OS.toast("Controller cursor on: arrows move, Enter clicks, F8 off", 4) end
  OS.dirty = true
end

local function keyRoute(hld, onApp, k, held)
  if hld.focus then fieldKey(hld.focus, k) elseif onApp then onApp(k, held) end
end

local function handle(ev)
  local e = ev[1]
  if e == "terminate" then return end
  if OS.place then
    if e == "monitor_touch" then OS.placeTouch(ev[2], ev[3], ev[4]); OS.dirty = true; return end
    if e == "key" and ev[2] == keys.escape then OS.endPlace(); return end
    if e == "mouse_click" or e == "key" or e == "char" then return end
  end
  if OS.arrange then
    if e == "monitor_touch" then OS.arrangeTouch(ev[2]); OS.dirty = true; return end
    if e == "key" and ev[2] == keys.escape then OS.endArrange(false); return end
    if e == "mouse_click" or e == "key" or e == "char" then return end
  end
  if OS.span then
    -- map a touch on one monitor into the wide desktop
    if e == "monitor_touch" then
      for _, sg in ipairs(OS.span.segs) do
        if sg.name == ev[2] then
          ev[3] = math.max(1, math.min(W, ev[3] - (sg.ox or 0) + (sg.vx or 0)))
          ev[4] = math.max(1, math.min(H, ev[4] - (sg.oy or 0) + (sg.vy or 0)))
          break
        end
      end
    elseif e:sub(1, 6) == "mouse_" and not OS.span.termFree then ev[3] = ev[3] + (OS.spanPrimaryX0 or 0) end
  end
  if e ~= "key" and e ~= "key_up" and e ~= "char" and e ~= "paste" and e ~= "monitor_touch" and e:sub(1, 5) ~= "mouse" then
    OS.broadcast(ev)
  end
  if e == "timer" then
    local fn = OS.timers[ev[2]]
    if fn then OS.timers[ev[2]] = nil; fn() end
  elseif e == "http_success" or e == "http_failure" then
    local cb = OS.pending[ev[2]]
    if cb then
      OS.pending[ev[2]] = nil
      if e == "http_success" then
        local h = ev[3]
        local data = h.readAll(); h.close()
        cb(data)
      else cb(nil, ev[3]) end
    end
  elseif e == "speaker_audio_empty" then Audio.fill()
  elseif e == "peripheral" or e == "peripheral_detach" then
    Audio.scan()
    local nm = ev[2]
    if nm and (nm == OS.parentName or (cfg.mirror and cfg.mirror[nm]) or (e == "peripheral" and peripheral.getType(nm) == "monitor")) then OS.setupDisplay() end
  elseif e == "term_resize" or e == "monitor_resize" then
    if OS.span then
      local changed = false
      for _, sg in ipairs(OS.span.segs) do
        local ok, w, h = pcall(sg.m.getSize)
        if not ok or w ~= sg.w or h ~= sg.h then changed = true end
      end
      if changed then OS.setupDisplay() end
    else
      local ok, pw, ph = pcall(parent.getSize)
      if ok and type(pw) == "number" and type(ph) == "number" and pw > 0 and ph > 0 then
        W, H = pw, ph; T.reposition(1, 1, W, H); OS.wallCache = nil
        for _, win in ipairs(OS.wins) do OS.maximize(win); OS.maximize(win) end
      else OS.setupDisplay() end
    end
  elseif e == "key" then
    local k = ev[2]
    if k == keys.f8 and not ev[3] then OS.toggleVC() return end
    if OS.vc and OS.vcKey(k, ev[3]) then return end
    if k == keys.leftCtrl or k == keys.rightCtrl then OS.mods.ctrl = true
    elseif k == keys.leftShift or k == keys.rightShift then OS.mods.shift = true end
    if OS.mode == "desktop" then
      local w = OS.active()
      if OS.lp then
        local lp = OS.lp
        if k == keys.escape then
          if lp.search and lp.search.text ~= "" then lp.search.text = ""; lp.search.pos = 0
          elseif lp.folder then lp.folder = nil else OS.lp = nil end
        elseif lp.search then fieldKey(lp.search, k) end
      elseif w then keyRoute(w, w.app.key and function(kk, hh) w.app.key(w, kk, hh) end, k, ev[3]) end
    elseif OS.screen then keyRoute(OS.screen, nil, k, ev[3]) end
  elseif e == "key_up" then
    local k = ev[2]
    if k == keys.leftCtrl or k == keys.rightCtrl then OS.mods.ctrl = false
    elseif k == keys.leftShift or k == keys.rightShift then OS.mods.shift = false end
    if OS.mode == "desktop" then
      local w = OS.active()
      if w and w.app.keyUp then w.app.keyUp(w, k) end
    end
  elseif e == "char" or e == "paste" then
    local s = ev[2]
    if OS.vcSkip and s == " " then OS.vcSkip = nil return end
    if OS.mode == "desktop" and OS.lp and OS.lp.search then
      if e == "char" or e == "paste" then fieldText(OS.lp.search, s); OS.lp.scroll = 0 end
      return
    end
    local hld, app
    if OS.mode == "desktop" then hld = OS.active(); app = hld and hld.app else hld = OS.screen end
    if hld then
      if hld.focus then fieldText(hld.focus, s)
      elseif app then
        if e == "char" and app.char then app.char(hld, s) elseif e == "paste" and app.paste then app.paste(hld, s) end
      end
    end
  elseif e == "mouse_click" or e == "monitor_touch" then
    local btn, x, y = ev[2], ev[3], ev[4]
    local skip = false
    if e == "monitor_touch" then
      -- monitors only send left touches; "RC" in the menu bar makes the next touch a right click
      local off = (not OS.span) and OS.mirrorOff and OS.mirrorOff[ev[2]]
      x, y = ev[3] - (off and off[1] or 0), ev[4] - (off and off[2] or 0)
      btn = 1
      local rc = OS.barHits and OS.barHits.rc
      if OS.mode == "desktop" and rc and y == H and x >= rc.x and x < rc.x + rc.w then
        OS.rcNext = not OS.rcNext; skip = true
      elseif OS.rcNext then btn = 2; OS.rcNext = false end
    end
    OS.touchMode = (e == "monitor_touch")
    if skip then
    elseif OS.mode == "desktop" then desktopClick(btn, x, y)
    elseif OS.screen then hit(OS.screen, x, y, btn) end
    if e == "monitor_touch" then OS.drag = nil end
  elseif e == "mouse_drag" then
    dragMove(ev[3], ev[4], ev[2])
  elseif e == "mouse_up" then
    local d = OS.drag
    if d and d.win and not d.rs then OS.snapWin(d.win, ev[3], ev[4]) end
    if d and d.hot and d.hot.up then
      local ox, oy = 0, 0
      if d.hld ~= OS.screen then ox, oy = d.hld.x or 0, d.hld.y or 0 end
      d.hot.up(ev[3] - ox, ev[4] - oy, ev[2])
    end
    OS.drag = nil
  elseif e == "mouse_scroll" then
    local dir, x, y = ev[2], ev[3], ev[4]
    OS.lastMouse = { x, y }
    if OS.lp then
      local lp = OS.lp
      if lp.tilesX and x >= lp.tilesX then lp.tscroll = math.max(0, (lp.tscroll or 0) + dir)
      else lp.scroll = math.max(0, (lp.scroll or 0) + dir * 2) end
      return
    end
    if OS.mode == "desktop" then
      for i = #OS.wins, 1, -1 do
        local win = OS.wins[i]
        if not win.min and x >= win.x and x < win.x + win.w and y >= win.y and y < win.y + win.h then
          hitScroll(win, x - win.x, y - win.y, dir); break
        end
      end
    end
  end
end

----------------------------------------------------------------------- render + main
OS.handle = handle
function OS.vcKey(k, held)
  local vc = OS.vc
  local hld = (OS.mode == "desktop") and OS.active() or OS.screen
  if hld and hld.focus then return false end
  local step = OS.mods.shift and 4 or 1
  if k == keys.up then vc.y = math.max(1, vc.y - step)
  elseif k == keys.down then vc.y = math.min(H, vc.y + step)
  elseif k == keys.left then vc.x = math.max(1, vc.x - step)
  elseif k == keys.right then vc.x = math.min(W, vc.x + step)
  elseif k == keys.enter or k == keys.space or k == keys.backspace then
    if held then return true end
    local b = (k == keys.backspace) and 2 or 1
    OS.vcSkip = (k == keys.space) or nil
    OS.handle({ "mouse_click", b, vc.x, vc.y }); OS.handle({ "mouse_up", b, vc.x, vc.y })
  elseif k == keys.pageUp then OS.handle({ "mouse_scroll", -1, vc.x, vc.y })
  elseif k == keys.pageDown then OS.handle({ "mouse_scroll", 1, vc.x, vc.y })
  else return false end
  return true
end

-- "Arrange by touch": every monitor asks to be touched in desktop order (1 = top-left, then across, then down)
function OS.startArrange()
  if not OS.span then return false end
  OS.arrange = { got = {}, order = {}, t0 = os.clock(), dirty = true }
  return true
end
function OS.endArrange(apply)
  local a = OS.arrange
  local chain = a and a.thenPlace
  OS.arrange = nil
  if apply and a then
    cfg.spanOrder = a.order
    -- remember where the monitors physically are (reading order + width of the wall), so the D-pad can move them
    cfg.wallOrder = {}
    for i, v in ipairs(a.order) do cfg.wallOrder[i] = v end
    cfg.wallCols = OS.span and OS.span.cols or #a.order
    OS.save()
    OS.toast("Monitor order saved", 3)
  end
  OS.setupDisplay()
  if apply and chain then OS.startPlace() end
end
function OS.arrangeTouch(name)
  local a = OS.arrange
  if not a or a.got[name] then return end
  local n = 0
  for _ in pairs(a.got) do n = n + 1 end
  n = n + 1
  a.got[name] = n; a.order[n] = name; a.dirty = true
  if OS.span and n >= #OS.span.segs then OS.endArrange(true) end
end
local function arrangeDraw()
  local a, sp = OS.arrange, OS.span
  if not a.dirty then return end
  a.dirty = false
  local nxt = 1
  for _ in pairs(a.got) do nxt = nxt + 1 end
  local cols = sp.cols or #sp.segs
  for _, sg in ipairs(sp.segs) do
    pcall(function()
      local m, nm = sg.m, sg.name or "term"
      m.setBackgroundColor(C.desk); m.setTextColor(C.text); m.clear()
      local function say(row, txt, fg)
        m.setTextColor(fg or C.text)
        m.setCursorPos(math.max(1, math.floor((sg.w - #txt) / 2) + 1), row); m.write(txt)
      end
      local mid = math.max(1, math.floor(sg.h / 2))
      if a.got[nm] then
        say(mid, "Position " .. a.got[nm], C.grn)
        say(mid + 1, "done", C.sub)
      else
        local r, c = math.floor((nxt - 1) / cols) + 1, (nxt - 1) % cols + 1
        say(mid - 1, "Touch the monitor that is", C.text)
        say(mid, "position " .. nxt .. " (X " .. c .. ", Y " .. r .. ")", C.acc)
        say(mid + 1, "Esc on the computer cancels", C.sub)
      end
    end)
  end
end

function OS.spanFlush()
  local sp = OS.span
  if OS.arrange then
    if os.clock() - OS.arrange.t0 > 120 + 15 * #sp.segs then OS.endArrange(false); return end
    arrangeDraw(); return
  end
  if OS.place then
    local pl = OS.place
    if os.clock() - pl.t0 > 600 then OS.endPlace(); return end
    -- live: notice monitors being added, removed or resized while this is open
    if not pl.chk or os.clock() - pl.chk > 3 then
      pl.chk = os.clock()
      local okS, sig = pcall(OS.spanSig)
      local bad = false
      for _, sg in ipairs(sp.segs) do
        local ok, w, h = pcall(sg.m.getSize)
        if not ok or w ~= sg.w or h ~= sg.h then bad = true end
      end
      if (okS and sig ~= sp.sig) or bad then pcall(OS.setupDisplay); pl.dirty = true; return end
    end
    placeDraw(); return
  end
  -- slow, steady self-repair, ONE monitor per tick (every monitor call costs time, so with many
  -- screens repainting them all at once froze the desktop): check its size, repaint it without a clear
  local now = os.clock()
  if not sp.sync then sp.sync = now end
  local nseg = #sp.segs
  if now - sp.sync >= (cfg.syncEvery or 2) then
    sp.sync = now
    sp.rr = (sp.rr or 0) % nseg + 1
    local sg = sp.segs[sp.rr]
    local bad = false
    local ok, w, h = pcall(sg.m.getSize)
    if not ok or w ~= sg.w or h ~= sg.h then bad = true end
    if sp.rr == 1 then
      local okSig, sig = pcall(OS.spanSig)
      if okSig and sig ~= sp.sig then bad = true end
    end
    if bad then
      pcall(OS.setupDisplay)
      if not OS.span then return end
      sp = OS.span
    else
      sp.last[sg.name or "?"] = {}
      if sp.rr == 1 and (not sp.paletteAt or now - sp.paletteAt >= 12 * math.max(1, nseg / 3)) then
        sp.paletteAt = now
        pcall(OS.applyTheme)
      end
    end
  end
  -- one desktop row at a time across all monitors, so the pieces update together; works for any number of monitors
  for y = 1, H do
    local list = sp.rowSegs and sp.rowSegs[y]
    if list and #list > 0 then
      local t, f, b = T.getLine(y)
      local rk = t .. f .. b
      local rowSame = sp.rowKey and sp.rowKey[y] == rk
      if not sp.rowKey then sp.rowKey = {} end
      sp.rowKey[y] = rk
      for _, sg in ipairs(list) do
        local key0 = sg.name or "?"
        local last = sp.last[key0]
        if not last then
          last = {}; sp.last[key0] = last
          pcall(function() sg.m.setBackgroundColor(C.desk); sg.m.clear() end)
        end
        local a2, z2 = sg.vx + 1, sg.vx + sg.cw
        local ts, fs_, bs = t:sub(a2, z2), f:sub(a2, z2), b:sub(a2, z2)
        local key = ts .. fs_ .. bs
        if last[y] ~= key and not (rowSame and last[y] ~= nil) then
          last[y] = key
          pcall(function()
            sg.m.setCursorPos(1 + sg.ox, y - sg.vy + sg.oy)
            sg.m.blit(ts, fs_, bs)
          end)
        end
      end
    end
  end
  if sp.termFree and not sp.banner then
    sp.banner = true
    pcall(function()
      local native = term.native and term.native() or term.current()
      native.setBackgroundColor(C.desk); native.setTextColor(C.text); native.clear()
      native.setCursorPos(1, 1); native.write("Windows 10: desktop is joined across")
      native.setCursorPos(1, 2); native.write(#sp.segs .. " monitors.")
      native.setCursorPos(1, 4); native.write("Keyboard works here.")
    end)
  end
end

function OS.mirrorFlush()
  for name, m in pairs(OS.mirrors) do
    local ok = pcall(function()
      local mw, mh = m.getSize()
      local last = OS.mirrorLast[name]
      if not last or last.w ~= mw or last.h ~= mh then
        last = { w = mw, h = mh }; OS.mirrorLast[name] = last
        m.setBackgroundColor(C.desk); m.clear()
      end
      local off = OS.mirrorOff[name] or { 0, 0 }
      local n = mw - off[1]
      for y = 1, math.min(H, mh - off[2]) do
        local t, f, b = T.getLine(y)
        local key = t:sub(1, n) .. f:sub(1, n) .. b:sub(1, n)
        if last[y] ~= key then
          last[y] = key
          m.setCursorPos(1 + off[1], y + off[2])
          m.blit(t:sub(1, n), f:sub(1, n), b:sub(1, n))
        end
      end
    end)
    if not ok then OS.mirrors[name] = nil end
  end
end

function OS.render()
  OS.cursor = nil
  if OS.place and not OS.span then OS.place = nil end
  local aw = (OS.mode == "desktop") and OS.active() or nil
  local want = aw and aw.app.pal or nil
  if want ~= OS.palOver then OS.palOver = want; OS.applyTheme() end
  T.setVisible(false)
  if OS.mode == "desktop" then
    drawWall()
    OS.drawDesktopIcons()
    local act = OS.active()
    if not (OS.lp and OS.lp.tv) then
      for _, win in ipairs(OS.wins) do if not win.min then drawWindow(win, win == act) end end
    end
    if OS.lp then
      local okLp, errLp = pcall(drawStart)
      if not okLp then
        -- never take the system down, and don't close Start: print the error right inside it
        pcall(function()
          local f = fs.open("/win10_error.log", "a"); f.writeLine(os.date() .. " start menu: " .. tostring(errLp)); f.close()
        end)
        local lines = OS.wrap("Start error: " .. tostring(errLp), math.max(10, math.min(60, W - 6)))
        for i, l in ipairs(lines) do put(4, 3 + i, l, C.wht, C.red) end
        OS.lp.hits = OS.lp.hits or {}; OS.lp.btns = OS.lp.btns or {}; OS.lp.pbtns = OS.lp.pbtns or {}
      end
    end
    drawTaskbar(); drawMenu(); drawPanel(); drawToast()
  elseif OS.screen then
    OS.screen.hots = {}
    local g = newG(OS.screen, 1, 1, W, H)
    OS.screen.draw(OS.screen, g)
    drawToast()
  end
  if OS.cursor then
    T.setCursorPos(OS.cursor[1], OS.cursor[2]); T.setTextColor(C.text); T.setCursorBlink(true)
  else T.setCursorBlink(false) end
  if OS.vc then put(OS.vc.x, OS.vc.y, "\16", C.wht, C.red) end
  -- test pattern for joined monitors: every monitor's frame, a line across the whole wall and its position number
  if OS.span and OS.testUntil and os.clock() < OS.testUntil then
    for i, sg in ipairs(OS.span.segs) do
      local x1, y1, x2, y2 = sg.vx + 1, sg.vy + 1, sg.vx + sg.cw, sg.vy + sg.ch
      put(x1, y1, (" "):rep(sg.cw), C.wht, C.acc); put(x1, y2, (" "):rep(sg.cw), C.wht, C.acc)
      for yy = y1, y2 do put(x1, yy, " ", C.wht, C.acc); put(x2, yy, " ", C.wht, C.acc) end
      local lbl = " " .. i .. "  X " .. sg.c .. " Y " .. sg.r .. " "
      put(x1 + math.max(1, math.floor((sg.cw - #lbl) / 2)), y1 + math.floor(sg.ch / 2), lbl, C.wht, C.red)
    end
    for yy = 1, H do put(math.max(1, math.floor(yy / H * W)), yy, "  ", C.wht, C.grn) end
  elseif OS.testUntil then OS.testUntil = nil end
  if OS.span then OS.spanFlush()
  else
    T.setVisible(true)
    if next(OS.mirrors or {}) then OS.mirrorFlush() end
  end
  if OS.idUntil then
    if os.clock() < OS.idUntil then identDraw() else identClear() end
  end
end

local function wait(t)
  local id = os.startTimer(t)
  repeat local e, p = os.pullEventRaw() until e == "timer" and p == id
end

-- windowed host for a standalone program (runs it in a coroutine with a private virtual terminal)
local function procResume(win, ...)
  local s = win.state
  if not s or not s.co or coroutine.status(s.co) ~= "suspended" then return end
  if s.filter and s.filter ~= (...) then return end
  local old = term.redirect(s.pw)
  local ok, res = coroutine.resume(s.co, ...)
  term.redirect(old)
  if not ok then s.err = tostring(res); s.co = nil
  elseif coroutine.status(s.co) == "dead" then s.co = nil; s.err = s.err or "Program exited"
  else s.filter = res end
end

-- background coroutines (slow peripheral polling) fed with every non-input event, like the parallel API
OS.listeners = {}
function OS.async(fn)
  local co = coroutine.create(fn)
  OS.asyncSet = OS.asyncSet or setmetatable({}, { __mode = "k" })
  OS.asyncSet[co] = true
  local filter
  local entry = { stop = false }
  function entry.feed(ev)
    if entry.stop or coroutine.status(co) ~= "suspended" then return false end
    if ev and filter and ev[1] ~= filter and ev[1] ~= "terminate" then return true end
    local ok, f
    if ev then ok, f = coroutine.resume(co, unpack(ev)) else ok, f = coroutine.resume(co) end
    if not ok then OS.toast("async: " .. tostring(f), 5); return false end
    filter = f
    return coroutine.status(co) == "suspended"
  end
  OS.listeners[#OS.listeners + 1] = entry
  entry.feed(nil)
  return entry
end
function OS.broadcast(ev)
  for i = #OS.listeners, 1, -1 do
    if not OS.listeners[i].feed(ev) then table.remove(OS.listeners, i) end
  end
  for _, win in ipairs({ unpack(OS.wins) }) do
    if win.app.proc and win.state and win.state.co then procResume(win, unpack(ev)) end
  end
end

function OS.procApp(app)
  app.proc = true; app.startMax = true; app.fullH = true
  app.w = app.w or 51; app.h = app.h or 14; app.minw = 30; app.minh = 8
  local function start(win)
    local s = win.state
    local env = setmetatable({ require = require, package = package, shell = OS.guardShell(shell), multishell = multishell,
      fs = OS.guardFs(), io = OS.guardIo() }, { __index = _G })
    local fn, err = load(s.src, "=" .. tostring(app.id), nil, env)
    if not fn then s.err = tostring(err); s.co = nil return end
    s.co = coroutine.create(fn); s.filter = nil; s.err = nil
    procResume(win)
  end
  function app.init(win)
    local src, err = OS.externalSource(app)
    if not src then error(err or "no source", 0) end
    if app.startMax then OS.maximize(win) end
    local s = { src = src }
    win.state = s
    s.w, s.h = math.max(10, win.w - 2), math.max(5, win.h - 2)
    s.pw = window.create(T, 1, 1, s.w, s.h, false)
    start(win)
  end
  function app.draw(win, g)
    local s = win.state
    local w, h = g.w, g.h
    if s.w ~= w or s.h ~= h then
      s.w, s.h = w, h; s.pw.reposition(1, 1, w, h)
      procResume(win, "term_resize")
    end
    local map = {}
    for n = 0, 15 do
      local r, gg, b = s.pw.getPaletteColor(2 ^ n)
      local best, bd = C.desk, 1e9
      for k, col in pairs(C) do
        local rgb = OS.pal[k]
        local dr = r - math.floor(rgb / 65536) / 255
        local dg = gg - (math.floor(rgb / 256) % 256) / 255
        local db = b - (rgb % 256) / 255
        local d = dr * dr + dg * dg + db * db
        if d < bd then bd = d; best = col end
      end
      map[string.format("%x", n)] = colors.toBlit(best)
    end
    for y = 1, h do
      local t, f, b = s.pw.getLine(y)
      g.blit(1, y, t, (f:gsub(".", map)), (b:gsub(".", map)))
    end
    if s.pw.getCursorBlink() then
      local cx, cy = s.pw.getCursorPos()
      g.cursor(cx, cy)
    end
    local hot = g.hot(1, 1, w, h, function(rx, ry, btn, kind)
      if kind == "drag" then procResume(win, "mouse_drag", btn, rx, ry) else procResume(win, "mouse_click", btn, rx, ry) end
    end, true)
    hot.up = function(rx, ry, btn) procResume(win, "mouse_up", btn or 1, rx, ry) end
    g.scroll(1, 1, w, h, function(dir)
      local lm = OS.lastMouse or { 1, 1 }
      procResume(win, "mouse_scroll", dir, lm[1] - win.x, lm[2] - win.y)
    end)
    if s.err then
      g.fill(1, h, w, 1, C.red)
      g.put(1, h, OS.trunc(s.err, w - 12), C.wht, C.red)
      g.btn(w - 9, h, "Restart", function() start(win) end, "dark")
    end
  end
  function app.key(win, k, held) procResume(win, "key", k, held) end
  function app.keyUp(win, k) procResume(win, "key_up", k) end
  function app.char(win, ch) procResume(win, "char", ch) end
  function app.paste(win, t) procResume(win, "paste", t) end
  function app.close(win) if win.state then win.state.co = nil end if app.id == "music" then Audio.stopSpeakers() end end
  return app
end

local PKGCOL = { "acc", "grn", "yel", "red", "sub" }
function OS.registerPkg(p)
  local id = "pkg:" .. p.name
  OS.apps[id] = OS.procApp { id = id, title = p.name, glyph = " " .. p.name:sub(1, 1):upper() .. " ", icon = PKGCOL[#p.name % 5 + 1],
    fg = "wht", single = true, external = p.file, cat = "Installed" }
end
function OS.unregisterPkg(name)
  local id = "pkg:" .. name
  for i = #OS.wins, 1, -1 do if OS.wins[i].app.id == id then OS.close(OS.wins[i]) end end
  OS.apps[id] = nil
end
function OS.runProgram(title, src)
  local id = "run:" .. title
  local a = OS.procApp { id = id, title = title, glyph = " > ", icon = "sub", fg = "wht", hidden = true, source = src }
  OS.apps[id] = a
  return OS.open(id)
end

local function loadApps()
  for name, mk in pairs(EMBED) do
    local ok, res = pcall(mk, OS)
    if ok and type(res) == "table" then OS.apps[res.id] = res
    else print("app " .. name .. " failed: " .. tostring(res)) sleep(1) end
  end
end

local function main()
  OS.setupDisplay()
  Audio.scan()
  loadApps()
  OS.apps.music = OS.procApp { id = "music", title = "Groove Music", glyph = " M ", icon = "sp", fg = "sp0", single = true,
    external = "/gnome-music.lua",
    url = "https://gist.githubusercontent.com/Nelsonmcintosh/97e6dbb0963e40ec7d5d91284db8fec5/raw" }
  OS.apps.launchpad = { id = "launchpad", title = "Start", glyph = " # ", icon = "grn", fg = "wht", action = OS.toggleLP }
  for _, p in ipairs(cfg.pkgs or {}) do
    if p.file and not OS.isProtected(p.file) and fs.exists(p.file) then pcall(OS.registerPkg, p) end
  end
  OS.mode = "boot"; OS.screen = bootScreen()
  for i = 1, 16 do OS.screen.p = i / 16; OS.render(); wait(0.05) end
  if not cfg.user then OS.mode = "setup"; OS.screen = OS.setupScreen()
  elseif cfg.hash or cfg.lockBoot then OS.mode = "lock"; OS.screen = OS.lockScreen()
  else OS.mode = "desktop"; OS.screen = nil end
  OS.sfx("boot"); Snd.start(); OS.watchStartup(true)
  if cfg.ctl then OS.vc = { x = math.floor(W / 2), y = math.floor(H / 2) } end
  local function rgbTick()
    local th = OS.findTheme(cfg.theme)
    if th and th.rgb then OS.applyTheme(); OS.timer(0.25, rgbTick)
    else OS.timer(1, rgbTick) end
  end
  rgbTick()
  local function tick()
    if OS.dirty then OS.save() end
    OS.watchStartup()
    OS.timer(1, tick)
  end
  OS.startTick = function() OS.timer(1, tick) end
  OS.startTick()
  while not OS.quit do
    OS.render()
    handle({ os.pullEventRaw() })
  end
  Audio.stop()
  if OS.dirty then OS.save() end
  for i = 0, 15 do
    local c = 2 ^ i
    pcall(parent.setPaletteColor, c, term.nativePaletteColor(c))
  end
  parent.setBackgroundColor(colors.black); parent.setTextColor(colors.white); parent.clear(); parent.setCursorPos(1, 1)
  term.setCursorBlink(false)
end

main()

end)
if not ok then
  for i = 0, 15 do pcall(term.setPaletteColor, 2 ^ i, term.nativePaletteColor(2 ^ i)) end
  term.setBackgroundColor(colors.black); term.setTextColor(colors.red); term.clear(); term.setCursorPos(1, 1)
  term.setCursorBlink(false)
  print("Windows 10 crashed:"); print(tostring(err))
  term.setTextColor(colors.white); print("Dropping to CraftOS shell.")
end
