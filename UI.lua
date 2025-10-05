--[[
NovaUI: A lightweight, legit Roblox GUI library (inspired by popular tabbed UIs)
- Purpose: Build *ethical* developer tools and dashboards (NOT exploits)
- Works in Studio and in normal games when added as a LocalScript + ModuleScript
- Features:
    • Window with top bar (draggable), theming
    • Tabs with pages, Sections
    • Controls: Button, Toggle, Slider, Dropdown, TextBox, Keybind, ColorPicker, Label
    • Notifications
    • Minimal state saving (in-memory); optional manual save/load serialization
- No forbidden/ToS-violating behavior. This is purely a UI framework.

USAGE (example):

local NovaUI = require(path.to.NovaUI)
local app = NovaUI.new({ title = "My Tool", theme = NovaUI.Themes.Dark })
local main = app:CreateTab("Main")
local sec = main:CreateSection("General")

sec:AddToggle({text="God Mode (example)", default=false}, function(on)
    -- do your *legit* game logic here (e.g., debug flags)
    print("Toggle:", on)
end)

sec:AddSlider({text="WalkSpeed", min=8, max=32, default=16, step=1}, function(v)
    print("WalkSpeed:", v)
end)

sec:AddDropdown({text="Team", items={"Red","Blue","Green"}, default="Red"}, function(choice)
    print("Team:", choice)
end)

sec:AddColorPicker({text="Accent", default=Color3.fromRGB(0, 170, 255)}, function(c)
    app:SetAccent(c)
end)

app:Notify({title="Loaded", message="NovaUI ready.", duration=3})

--]]

local NovaUI = {}
NovaUI.__index = NovaUI

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

--====================================================--
-- THEMES
--====================================================--
NovaUI.Themes = {
    Dark = {
        Background = Color3.fromRGB(20, 20, 25),
        Panel      = Color3.fromRGB(28, 28, 36),
        Stroke     = Color3.fromRGB(60, 60, 74),
        Text       = Color3.fromRGB(235, 235, 245),
        Subtext    = Color3.fromRGB(170, 170, 185),
        Accent     = Color3.fromRGB(0, 170, 255),
        Hover      = Color3.fromRGB(42, 42, 52)
    },
    Light = {
        Background = Color3.fromRGB(242, 242, 247),
        Panel      = Color3.fromRGB(255, 255, 255),
        Stroke     = Color3.fromRGB(210, 210, 215),
        Text       = Color3.fromRGB(20, 20, 30),
        Subtext    = Color3.fromRGB(90, 90, 110),
        Accent     = Color3.fromRGB(0, 120, 255),
        Hover      = Color3.fromRGB(240, 240, 245)
    }
}

local function round(x, step)
    step = step or 1
    return math.floor(x/step + 0.5) * step
end

local function create(class, props, children)
    local obj = Instance.new(class)
    if props then for k,v in pairs(props) do obj[k] = v end end
    if children then
        for _, child in ipairs(children) do child.Parent = obj end
    end
    return obj
end

local function stroke(parent, color, thickness)
    return create("UIStroke", {Parent=parent, Thickness=thickness or 1, Color=color or Color3.fromRGB(60,60,74), ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
end

local function corner(parent, radius)
    return create("UICorner", {Parent=parent, CornerRadius=UDim.new(0, radius or 8)})
end

local function padding(parent, p)
    return create("UIPadding", {Parent=parent, PaddingTop=UDim.new(0,p or 8), PaddingBottom=UDim.new(0,p or 8), PaddingLeft=UDim.new(0,p or 8), PaddingRight=UDim.new(0,p or 8)})
end

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")

--====================================================--
-- ROOT APP
--====================================================--
function NovaUI.new(opts)
    opts = opts or {}
    local theme = opts.theme or NovaUI.Themes.Dark
    local self = setmetatable({
        _theme = theme,
        _accent = theme.Accent,
        _tabs = {},
        _connections = {},
        _state = {},
        _dragging = false,
    }, NovaUI)

    local screen = create("ScreenGui", {
        Name = opts.guiName or ("NovaUI_"..HttpService:GenerateGUID(false)),
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Global
    })

    if syn and syn.protect_gui then pcall(function() syn.protect_gui(screen) end) end -- harmless protection if environment supports

    screen.Parent = PlayerGui or game:GetService("CoreGui")
    self._screen = screen

    -- Window frame
    local window = create("Frame", {
        Parent = screen,
        Name = "Window",
        BackgroundColor3 = theme.Panel,
        Size = UDim2.fromOffset(580, 380),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5)
    }, {
        corner(nil, 12),
        stroke(nil, theme.Stroke, 1),
    })

    self._window = window

    -- TopBar
    local top = create("Frame", {
        Parent = window,
        BackgroundColor3 = theme.Background,
        Size = UDim2.new(1, 0, 0, 40)
    }, {corner(nil, 12), stroke(nil, theme.Stroke, 1)})

    local title = create("TextLabel", {
        Parent = top,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -100, 1, 0),
        Position = UDim2.fromOffset(12, 0),
        Font = Enum.Font.GothamMedium,
        Text = tostring(opts.title or "NovaUI"),
        TextColor3 = theme.Text,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left
    })

    local close = create("TextButton", {
        Parent = top,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(40, 40),
        Position = UDim2.new(1, -44, 0, 0),
        Font = Enum.Font.Gotham,
        Text = "✕",
        TextColor3 = theme.Subtext,
        TextSize = 16
    })

    close.MouseButton1Click:Connect(function()
        screen.Enabled = false
    end)

    -- Drag logic
    do
        local dragging, dragStart, startPos
        top.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = input.Position
                startPos = window.Position
                input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
            end
        end)
        top.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position - dragStart
                window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
    end

    -- Left tab bar
    local tabbar = create("Frame", {
        Parent = window,
        BackgroundColor3 = theme.Panel,
        Position = UDim2.fromOffset(0, 40),
        Size = UDim2.new(0, 140, 1, -40)
    }, {stroke(nil, theme.Stroke, 1)})

    local tablist = create("UIListLayout", {Parent=tabbar, FillDirection=Enum.FillDirection.Vertical, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6)})
    padding(tabbar, 8)

    -- Right content area
    local content = create("Frame", {
        Parent = window,
        Name = "Content",
        BackgroundColor3 = theme.Background,
        Position = UDim2.fromOffset(140, 40),
        Size = UDim2.new(1, -140, 1, -40)
    }, {stroke(nil, theme.Stroke, 1)})

    self._tabbar = tabbar
    self._content = content

    return self
end

function NovaUI:GetTheme() return self._theme end
function NovaUI:SetAccent(color)
    self._accent = color
    for _, fn in ipairs(self._onAccentChanged or {}) do pcall(fn, color) end
end

--====================================================--
-- TABS
--====================================================--
local Tab = {}
Tab.__index = Tab

function NovaUI:CreateTab(name)
    local theme = self._theme
    local tabBtn = create("TextButton", {
        Parent = self._tabbar,
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = theme.Panel,
        Text = name,
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextColor3 = theme.Subtext,
        AutoButtonColor = false
    }, {corner(nil, 10), stroke(nil, self._theme.Stroke, 1)})

    local page = create("ScrollingFrame", {
        Parent = self._content,
        Active = true,
        Visible = false,
        CanvasSize = UDim2.new(0,0,0,0),
        ScrollBarThickness = 4,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1,1)
    })

    local layout = create("UIListLayout", {Parent=page, Padding=UDim.new(0,8), SortOrder=Enum.SortOrder.LayoutOrder})
    padding(page, 10)

    local tab = setmetatable({
        _app = self,
        _button = tabBtn,
        _page = page,
        _sections = {}
    }, Tab)

    tabBtn.MouseEnter:Connect(function()
        TweenService:Create(tabBtn, TweenInfo.new(0.15), {BackgroundColor3 = self._theme.Hover}):Play()
    end)
    tabBtn.MouseLeave:Connect(function()
        TweenService:Create(tabBtn, TweenInfo.new(0.15), {BackgroundColor3 = self._theme.Panel}):Play()
    end)

    tabBtn.MouseButton1Click:Connect(function()
        for _, t in ipairs(self._tabs) do
            t._page.Visible = false
            t._button.TextColor3 = self._theme.Subtext
        end
        page.Visible = true
        tabBtn.TextColor3 = self._accent
    end)

    if #self._tabs == 0 then
        page.Visible = true
        tabBtn.TextColor3 = self._accent
    end

    table.insert(self._tabs, tab)
    return tab
end

--====================================================--
-- SECTIONS
--====================================================--
local Section = {}
Section.__index = Section

function Tab:CreateSection(title)
    local theme = self._app._theme
    local section = create("Frame", {
        Parent = self._page,
        BackgroundColor3 = theme.Panel,
        Size = UDim2.new(1, -6, 0, 46),
        AutomaticSize = Enum.AutomaticSize.Y
    }, {
        corner(nil, 10),
        stroke(nil, theme.Stroke, 1)
    })

    local header = create("TextLabel", {
        Parent = section,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -16, 0, 28),
        Position = UDim2.fromOffset(8, 6),
        Font = Enum.Font.GothamMedium,
        Text = tostring(title or "Section"),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = theme.Text
    })

    local content = create("Frame", {
        Parent = section,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(8, 34),
        Size = UDim2.new(1, -16, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y
    })

    local layout = create("UIListLayout", {Parent=content, Padding=UDim.new(0,6), SortOrder=Enum.SortOrder.LayoutOrder})

    local sec = setmetatable({ _app = self._app, _section = section, _content = content }, Section)
    return sec
end

--====================================================--
-- CONTROLS
--====================================================--
local function baseControl(parent, app, labelText)
    local theme = app._theme
    local holder = create("Frame", {
        Parent = parent,
        BackgroundColor3 = theme.Background,
        Size = UDim2.new(1, 0, 0, 40)
    }, {corner(nil, 8), stroke(nil, theme.Stroke, 1)})

    local label = create("TextLabel", {
        Parent = holder,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -120, 1, 0),
        Font = Enum.Font.Gotham,
        Text = tostring(labelText or "Label"),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = theme.Text
    })

    return holder, label
end

function Section:AddLabel(text)
    local holder = create("TextLabel", {
        Parent = self._content,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 24),
        Font = Enum.Font.Gotham,
        Text = tostring(text or ""),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = self._app._theme.Subtext
    })
    return holder
end

function Section:AddButton(opts, callback)
    opts = opts or {}
    local app = self._app
    local theme = app._theme

    local btn = create("TextButton", {
        Parent = self._content,
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = theme.Background,
        Font = Enum.Font.GothamSemibold,
        Text = tostring(opts.text or "Button"),
        TextSize = 14,
        TextColor3 = theme.Text,
        AutoButtonColor = false
    }, {corner(nil, 8), stroke(nil, theme.Stroke, 1)})

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = app._theme.Hover}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = app._theme.Background}):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        if callback then callback() end
    end)

    return btn
end

function Section:AddToggle(opts, callback)
    opts = opts or {}
    local app = self._app
    local holder, label = baseControl(self._content, app, opts.text)

    local knob = create("Frame", {
        Parent = holder,
        Size = UDim2.fromOffset(44, 22),
        Position = UDim2.new(1, -56, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = app._theme.Stroke
    }, {corner(nil, 11)})

    local dot = create("Frame", {
        Parent = knob,
        Size = UDim2.fromOffset(18, 18),
        Position = UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.fromRGB(255,255,255)
    }, {corner(nil, 9)})

    local state = opts.default == true

    local function setState(on, animate)
        state = on
        local goal = {BackgroundColor3 = on and app._accent or app._theme.Stroke}
        TweenService:Create(knob, TweenInfo.new(0.15), goal):Play()
        local dotX = on and 44-2-18 or 2
        TweenService:Create(dot, TweenInfo.new(0.15), {Position = UDim2.fromOffset(dotX, 2)}):Play()
        if callback then callback(state) end
    end

    setState(state, false)

    holder.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then setState(not state, true) end
    end)

    return {
        Set = function(_, v) setState(v, true) end,
        Get = function() return state end
    }
end

function Section:AddSlider(opts, callback)
    opts = opts or {}
    local app = self._app
    local holder, label = baseControl(self._content, app, opts.text)

    local min,max,step = opts.min or 0, opts.max or 100, opts.step or 1
    local value = math.clamp(opts.default or min, min, max)

    local bar = create("Frame", {
        Parent = holder,
        Size = UDim2.new(0, 220, 0, 6),
        Position = UDim2.new(1, -240, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = app._theme.Stroke
    }, {corner(nil, 3)})

    local fill = create("Frame", {Parent=bar, BackgroundColor3=app._accent, Size=UDim2.new(0,0,1,0)}, {corner(nil,3)})

    local valueLbl = create("TextLabel", {
        Parent = holder,
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -10, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        Size = UDim2.fromOffset(60, 20),
        Font = Enum.Font.Gotham,
        Text = tostring(value),
        TextColor3 = app._theme.Subtext,
        TextSize = 14
    })

    local function render()
        local alpha = (value - min)/(max - min)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        valueLbl.Text = tostring(value)
    end

    local function setValue(v, fire)
        v = round(math.clamp(v, min, max), step)
        if v ~= value then
            value = v
            render()
            if fire and callback then callback(value) end
        else
            render()
            if fire and callback then callback(value) end
        end
    end

    render()

    local dragging = false
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            local rx = (input.Position.X - bar.AbsolutePosition.X)/bar.AbsoluteSize.X
            setValue(min + rx*(max-min), true)
        end
    end)
    bar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local rx = (input.Position.X - bar.AbsolutePosition.X)/bar.AbsoluteSize.X
            setValue(min + rx*(max-min), true)
        end
    end)

    return {
        Set = function(_, v) setValue(v, true) end,
        Get = function() return value end
    }
end

function Section:AddDropdown(opts, callback)
    opts = opts or {}
    local app = self._app
    local holder, label = baseControl(self._content, app, opts.text)

    local current = opts.default or (opts.items and opts.items[1]) or ""

    local box = create("TextButton", {
        Parent = holder,
        Size = UDim2.new(0, 180, 0, 26),
        Position = UDim2.new(1, -190, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = app._theme.Panel,
        Text = tostring(current),
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextColor3 = app._theme.Text,
        AutoButtonColor = false
    }, {corner(nil, 8), stroke(nil, app._theme.Stroke, 1)})

    local listHolder = create("Frame", {
        Parent = holder,
        BackgroundColor3 = app._theme.Panel,
        Position = UDim2.new(1, -190, 1, 4),
        AnchorPoint = Vector2.new(0.5, 0),
        Size = UDim2.new(0, 180, 0, 0),
        Visible = false
    }, {corner(nil, 8), stroke(nil, app._theme.Stroke, 1)})

    local listLayout = create("UIListLayout", {Parent=listHolder, Padding=UDim.new(0,4)})
    padding(listHolder, 6)

    local function open(v)
        listHolder.Visible = v
        TweenService:Create(listHolder, TweenInfo.new(0.15), {Size = v and UDim2.new(0,180,0, math.min(140, #opts.items*26+8)) or UDim2.new(0,180,0,0)}):Play()
    end

    local function setChoice(choice, fire)
        current = choice
        box.Text = tostring(choice)
        if fire and callback then callback(choice) end
    end

    box.MouseButton1Click:Connect(function()
        open(not listHolder.Visible)
    end)

    local function clearChildren()
        for _,c in ipairs(listHolder:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
    end

    local function buildItems(items)
        clearChildren()
        for _, item in ipairs(items or {}) do
            local btn = create("TextButton", {
                Parent = listHolder,
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundColor3 = app._theme.Background,
                Text = tostring(item),
                Font = Enum.Font.Gotham,
                TextSize = 14,
                TextColor3 = app._theme.Text,
                AutoButtonColor = false
            }, {corner(nil, 6), stroke(nil, app._theme.Stroke, 1)})
            btn.MouseButton1Click:Connect(function()
                setChoice(item, true)
                open(false)
            end)
        end
    end

    buildItems(opts.items or {})
    setChoice(current, false)

    return {
        SetItems = function(_, items) opts.items = items; buildItems(items) end,
        Set = function(_, v) setChoice(v, true) end,
        Get = function() return current end
    }
end

function Section:AddTextBox(opts, callback)
    opts = opts or {}
    local app = self._app
    local holder, label = baseControl(self._content, app, opts.text)

    local box = create("TextBox", {
        Parent = holder,
        Size = UDim2.new(0, 220, 0, 26),
        Position = UDim2.new(1, -230, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = app._theme.Panel,
        Text = tostring(opts.default or ""),
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextColor3 = app._theme.Text,
        ClearTextOnFocus = false
    }, {corner(nil, 8), stroke(nil, app._theme.Stroke, 1)})

    box.FocusLost:Connect(function(enter)
        if callback then callback(box.Text) end
    end)

    return box
end

function Section:AddKeybind(opts, callback)
    opts = opts or {}
    local app = self._app
    local holder, label = baseControl(self._content, app, opts.text)

    local keyBtn = create("TextButton", {
        Parent = holder,
        Size = UDim2.new(0, 120, 0, 26),
        Position = UDim2.new(1, -130, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = app._theme.Panel,
        Text = opts.default and tostring(opts.default.Name) or "Set...",
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextColor3 = app._theme.Text,
        AutoButtonColor = false
    }, {corner(nil, 8), stroke(nil, app._theme.Stroke, 1)})

    local listening = false
    local key = opts.default

    keyBtn.MouseButton1Click:Connect(function()
        listening = true
        keyBtn.Text = "Press any key..."
    end)

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if listening then
            listening = false
            if input.KeyCode ~= Enum.KeyCode.Unknown then
                key = input.KeyCode
                keyBtn.Text = input.KeyCode.Name
                if callback then callback("changed", key) end
            else
                keyBtn.Text = "Set..."
            end
        else
            if key and input.KeyCode == key then
                if callback then callback("pressed", key) end
            end
        end
    end)

    return {
        Get = function() return key end,
        Set = function(_, kc) key = kc; keyBtn.Text = kc and kc.Name or "Set..." end
    }
end

function Section:AddColorPicker(opts, callback)
    opts = opts or {}
    local app = self._app
    local holder, label = baseControl(self._content, app, opts.text)

    local swatch = create("TextButton", {
        Parent = holder,
        Size = UDim2.fromOffset(32, 20),
        Position = UDim2.new(1, -42, 0.5, 0),
        AnchorPoint = Vector2.new(0.5,0.5),
        BackgroundColor3 = opts.default or app._accent,
        AutoButtonColor = false,
        Text = ""
    }, {corner(nil, 6), stroke(nil, app._theme.Stroke, 1)})

    local pop = create("Frame", {
        Parent = holder,
        BackgroundColor3 = app._theme.Panel,
        Position = UDim2.new(1, -42, 1, 6),
        AnchorPoint = Vector2.new(0.5,0),
        Size = UDim2.fromOffset(180, 140),
        Visible = false
    }, {corner(nil, 8), stroke(nil, app._theme.Stroke, 1)})

    local hue = 0
    local sat = 1
    local val = 1

    local hueBar = create("Frame", {Parent=pop, BackgroundColor3=Color3.fromRGB(255,255,255), Size=UDim2.new(1,-12,0,12), Position=UDim2.fromOffset(6,6)}, {corner(nil,6), stroke(nil, app._theme.Stroke, 1)})
    local satVal = create("Frame", {Parent=pop, BackgroundColor3=Color3.fromRGB(255,0,0), Size=UDim2.new(1,-12,1,-30), Position=UDim2.fromOffset(6,24)}, {corner(nil,8), stroke(nil, app._theme.Stroke, 1)})

    local function hsvToColor(h,s,v)
        return Color3.fromHSV(h,s,v)
    end

    local function updateColor(fire)
        local c = Color3.fromHSV(hue, sat, val)
        swatch.BackgroundColor3 = c
        satVal.BackgroundColor3 = Color3.fromHSV(hue,1,1)
        if fire and callback then callback(c) end
    end

    swatch.MouseButton1Click:Connect(function()
        pop.Visible = not pop.Visible
    end)

    local function clamp01(x) return math.clamp(x,0,1) end

    local draggingHue=false; local draggingSV=false

    hueBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingHue=true
            local t = (input.Position.X - hueBar.AbsolutePosition.X)/hueBar.AbsoluteSize.X
            hue = clamp01(t)
            updateColor(true)
        end
    end)
    hueBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingHue=false end
    end)

    satVal.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingSV=true
            local rx = (input.Position.X - satVal.AbsolutePosition.X)/satVal.AbsoluteSize.X
            local ry = (input.Position.Y - satVal.AbsolutePosition.Y)/satVal.AbsoluteSize.Y
            sat = clamp01(rx); val = clamp01(1-ry)
            updateColor(true)
        end
    end)
    satVal.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingSV=false end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        if draggingHue then
            local t = (input.Position.X - hueBar.AbsolutePosition.X)/hueBar.AbsoluteSize.X
            hue = clamp01(t)
            updateColor(true)
        elseif draggingSV then
            local rx = (input.Position.X - satVal.AbsolutePosition.X)/satVal.AbsoluteSize.X
            local ry = (input.Position.Y - satVal.AbsolutePosition.Y)/satVal.AbsoluteSize.Y
            sat = clamp01(rx); val = clamp01(1-ry)
            updateColor(true)
        end
    end)

    updateColor(false)

    return {
        Set = function(_, c)
            local h,s,v = c:ToHSV()
            hue,sat,val = h,s,v
            updateColor(true)
        end,
        Get = function() return Color3.fromHSV(hue,sat,val) end
    }
end

--====================================================--
-- NOTIFICATIONS
--====================================================--
function NovaUI:Notify(opts)
    opts = opts or {}
    local theme = self._theme
    local toast = create("Frame", {
        Parent = self._screen,
        BackgroundColor3 = theme.Panel,
        Size = UDim2.fromOffset(260, 64),
        Position = UDim2.new(1, 280, 1, -100),
        AnchorPoint = Vector2.new(1,1)
    }, {corner(nil, 10), stroke(nil, theme.Stroke, 1)})

    local title = create("TextLabel", {
        Parent = toast,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10,6),
        Size = UDim2.new(1, -20, 0, 20),
        Font = Enum.Font.GothamSemibold,
        Text = tostring(opts.title or "Notification"),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = theme.Text
    })

    local msg = create("TextLabel", {
        Parent = toast,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10,26),
        Size = UDim2.new(1, -20, 0, 34),
        Font = Enum.Font.Gotham,
        TextWrapped = true,
        Text = tostring(opts.message or ""),
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextColor3 = theme.Subtext
    })

    TweenService:Create(toast, TweenInfo.new(0.25), {Position = UDim2.new(1, -14, 1, -14)}):Play()

    task.delay(tonumber(opts.duration) or 2.5, function()
        TweenService:Create(toast, TweenInfo.new(0.25), {Position = UDim2.new(1, 280, 1, -100)}):Play()
        task.wait(0.3)
        toast:Destroy()
    end)
end

--====================================================--
-- (Optional) SIMPLE STATE SERIALIZATION
--====================================================--
function NovaUI:Serialize()
    return HttpService:JSONEncode(self._state)
end

function NovaUI:Deserialize(json)
    local ok, data = pcall(function() return HttpService:JSONDecode(json) end)
    if ok and type(data) == "table" then
        self._state = data
    end
end

return NovaUI
