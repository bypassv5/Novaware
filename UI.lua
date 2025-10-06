--!strict
-- V4-Style Roblox UI Library (ModuleScript)
-- A clean, game-friendly UI toolkit inspired by the look-and-feel of VapeV4.
-- This library provides windows, tabs, sections, toggles, sliders, dropdowns, keybinds,
-- and more — implemented with standard Roblox UI classes (no exploit APIs).
--
-- IMPORTANT: Use in your own experiences for legitimate gameplay/UI purposes only.
-- This library does not provide or endorse cheating features.

local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

export type ToggleHandle = {
	Set: (self: ToggleHandle, state: boolean) -> (),
	Get: (self: ToggleHandle) -> boolean,
	OnChanged: (self: ToggleHandle, fn: (boolean) -> ()) -> (),
}

export type SliderHandle = {
	Set: (self: SliderHandle, value: number) -> (),
	Get: (self: SliderHandle) -> number,
	OnChanged: (self: SliderHandle, fn: (number) -> ()) -> (),
}

export type DropdownHandle = {
	Set: (self: DropdownHandle, item: string) -> (),
	Get: (self: DropdownHandle) -> string?,
	SetItems: (self: DropdownHandle, items: {string}) -> (),
	OnChanged: (self: DropdownHandle, fn: (string) -> ()) -> (),
}

export type KeybindHandle = {
	Set: (self: KeybindHandle, key: Enum.KeyCode?) -> (),
	Get: (self: KeybindHandle) -> Enum.KeyCode?,
	OnActivated: (self: KeybindHandle, fn: () -> ()) -> (),
}

export type SectionHandle = {
	AddToggle: (self: SectionHandle, label: string, default: boolean?, cb: (boolean) -> ()) -> ToggleHandle,
	AddButton: (self: SectionHandle, label: string, cb: () -> ()) -> (),
	AddSlider: (self: SectionHandle, label: string, min: number, max: number, default: number?, suffix: string?, cb: (number) -> ()) -> SliderHandle,
	AddDropdown: (self: SectionHandle, label: string, items: {string}, default: string?, cb: (string) -> ()) -> DropdownHandle,
	AddKeybind: (self: SectionHandle, label: string, defaultKey: Enum.KeyCode?, cb: () -> ()) -> KeybindHandle,
	AddTextbox: (self: SectionHandle, label: string, placeholder: string?, cb: (string) -> ()) -> (),
}

export type TabHandle = {
	AddSection: (self: TabHandle, title: string) -> SectionHandle,
	SetIcon: (self: TabHandle, image: string?) -> (),
}

export type WindowHandle = {
	AddTab: (self: WindowHandle, name: string, icon: string?) -> TabHandle,
	SetWatermark: (self: WindowHandle, text: string?) -> (),
	Show: (self: WindowHandle) -> (),
	Hide: (self: WindowHandle) -> (),
	Destroy: (self: WindowHandle) -> (),
}

local Lib = {}
Lib.__index = Lib

local THEME = {
	Background = Color3.fromRGB(16, 16, 18),
	Panel = Color3.fromRGB(26, 26, 30),
	Panel2 = Color3.fromRGB(18, 18, 22),
	Outline = Color3.fromRGB(40, 40, 48),
	Text = Color3.fromRGB(225, 225, 235),
	SubText = Color3.fromRGB(170, 170, 185),
	Accent = Color3.fromRGB(85, 205, 252), -- cyan-ish accent like VapeV4
	Hover = Color3.fromRGB(40, 40, 50),
	Good = Color3.fromRGB(120, 220, 160),
	Warn = Color3.fromRGB(245, 180, 95),
}

local function new(InstanceName: string, parent: Instance?): Instance
	local inst = Instance.new(InstanceName)
	if parent then inst.Parent = parent end
	return inst
end

local function round(n: number, step: number): number
	return math.floor((n/step) + 0.5) * step
end

local function draggable(frame: Frame, dragHandle: GuiObject?)
	local dragging = false
	local dragStart, startPos
	local handle = dragHandle or frame

	handle.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)

	handle.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if dragging and dragStart and startPos then
				local delta = input.Position - dragStart
				frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
					startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			end
		end
	end)
end

local function makeStroke(p: GuiObject, thickness: number?, color: Color3?)
	local stroke = new("UIStroke", p)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = thickness or 1
	stroke.Color = color or THEME.Outline
	return stroke
end

local function corner(p: GuiObject, r: number?)
	local c = new("UICorner", p)
	c.CornerRadius = UDim.new(0, r or 8)
	return c
end

local function padding(p: GuiObject, l: number, t: number, r: number, b: number)
	local pad = new("UIPadding", p)
	pad.PaddingTop = UDim.new(0, t)
	pad.PaddingBottom = UDim.new(0, b)
	pad.PaddingLeft = UDim.new(0, l)
	pad.PaddingRight = UDim.new(0, r)
	return pad
end

local function vlist(p: GuiObject, spacing: number)
	local list = new("UIListLayout", p)
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	list.Padding = UDim.new(0, spacing)
	return list
end

local function hlist(p: GuiObject, spacing: number)
	local list = new("UIListLayout", p)
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, spacing)
	return list
end

local function label(parent: Instance, text: string, size: number?, color: Color3?, bold: boolean?)
	local t = new("TextLabel", parent)
	t.BackgroundTransparency = 1
	t.Text = text
	t.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight[bold and "Bold" or "Medium"], Enum.FontStyle.Normal)
	t.TextSize = size or 14
	t.TextColor3 = color or THEME.Text
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.ClipsDescendants = true
	return t
end

local function buttonBase(parent: Instance, text: string)
	local b = new("TextButton", parent)
	b.AutoButtonColor = false
	b.BackgroundColor3 = THEME.Panel
	b.Size = UDim2.new(1, 0, 0, 28)
	b.Text = ""
	corner(b, 6)
	makeStroke(b)
	local t = label(b, text, 14, THEME.Text, true)
	t.Size = UDim2.new(1, -12, 1, 0)
	t.Position = UDim2.new(0, 12, 0, 0)
	padding(b, 12, 0, 12, 0)
	b.MouseEnter:Connect(function() b.BackgroundColor3 = THEME.Hover end)
	b.MouseLeave:Connect(function() b.BackgroundColor3 = THEME.Panel end)
	return b, t
end

local function makeScreenGui(name: string): ScreenGui
	local gui = new("ScreenGui") :: ScreenGui
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Name = name
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

local function makeWindow(root: ScreenGui, title: string, accent: Color3)
	local container = new("Frame", root)
	container.Size = UDim2.new(0, 640, 0, 420)
	container.Position = UDim2.new(0, 120, 0, 120)
	container.BackgroundColor3 = THEME.Background
	corner(container, 10)
	makeStroke(container, 1.2)

	-- top bar
	local top = new("Frame", container)
	top.BackgroundColor3 = THEME.Panel
	top.Size = UDim2.new(1, 0, 0, 40)
	corner(top, 10)
	makeStroke(top, 1)

	local accentLine = new("Frame", top)
	accentLine.AnchorPoint = Vector2.new(0, 1)
	accentLine.Position = UDim2.new(0, 0, 1, 0)
	accentLine.Size = UDim2.new(1, 0, 0, 2)
	accentLine.BackgroundColor3 = accent

	local titleLabel = label(top, title, 16, THEME.Text, true)
	titleLabel.Position = UDim2.new(0, 16, 0, 0)
	titleLabel.Size = UDim2.new(1, -32, 1, 0)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left

	draggable(container, top)

	-- sidebar for tabs
	local sidebar = new("Frame", container)
	sidebar.BackgroundColor3 = THEME.Panel2
	sidebar.Position = UDim2.new(0, 0, 0, 40)
	sidebar.Size = UDim2.new(0, 160, 1, -40)
	makeStroke(sidebar)

	local sideList = vlist(sidebar, 6)
	padding(sidebar, 10, 10, 10, 10)

	-- main content area
	local content = new("Frame", container)
	content.BackgroundColor3 = THEME.Panel
	content.Position = UDim2.new(0, 160, 0, 40)
	content.Size = UDim2.new(1, -160, 1, -40)
	makeStroke(content)
	padding(content, 12, 12, 12, 12)

	local pageFolder = new("Folder", content)

	-- watermark (top-left subtle)
	local watermark = label(root, title .. "  |  " .. os.date("%X"), 12, THEME.SubText, false)
	watermark.Position = UDim2.new(0, 8, 0, 6)

	-- toggle window with RightShift
	local visible = true
	local function setVisible(v: boolean)
		visible = v
		container.Visible = v
		sidebar.Visible = v
		content.Visible = v
	end
	setVisible(true)

	UserInputService.InputBegan:Connect(function(inp: InputObject, gp)
		if gp then return end
		if inp.KeyCode == Enum.KeyCode.RightShift then
			setVisible(not visible)
		end
	end)

	return {
		Root = root,
		Container = container,
		TopBar = top,
		Sidebar = sidebar,
		SideList = sideList,
		Content = content,
		Pages = pageFolder,
		Watermark = watermark,
		Accent = accent,
		SetTitle = function(text: string)
			titleLabel.Text = text
		end,
		SetWatermark = function(text: string?)
			if text and text ~= "" then
				watermark.Text = text
				watermark.Visible = true
			else
				watermark.Visible = false
			end
		end,
		SetVisible = setVisible,
	}
end

local function createTab(ui: any, name: string, icon: string?)
	local tabButton, tabText = buttonBase(ui.Sidebar, name)
	tabButton.Size = UDim2.new(1, 0, 0, 32)
	makeStroke(tabButton, 1)

	if icon and icon ~= "" then
		local img = new("ImageLabel", tabButton)
		img.BackgroundTransparency = 1
		img.Size = UDim2.new(0, 16, 0, 16)
		img.Position = UDim2.new(0, 10, 0.5, -8)
		img.Image = icon
		tabText.Position = UDim2.new(0, 34, 0, 0)
		tabText.Size = UDim2.new(1, -42, 1, 0)
	end

	local page = new("ScrollingFrame", ui.Pages)
	page.BackgroundTransparency = 1
	page.Visible = false
	page.ScrollBarThickness = 3
	page.Size = UDim2.new(1, 0, 1, 0)

	local pageList = vlist(page, 10)
	padding(page, 8, 8, 8, 8)

	local function activate()
		for _, child in ipairs(ui.Pages:GetChildren()) do
			if child:IsA("ScrollingFrame") then child.Visible = false end
		end
		for _, btn in ipairs(ui.Sidebar:GetChildren()) do
			if btn:IsA("TextButton") then btn.BackgroundColor3 = THEME.Panel end
		end
		page.Visible = true
		tabButton.BackgroundColor3 = ui.Accent
	end

	tabButton.MouseButton1Click:Connect(activate)
	if #ui.Pages:GetChildren() == 1 then activate() end

	local tabHandle: TabHandle

	local function addSection(title: string): SectionHandle
		local section = new("Frame", page)
		section.BackgroundColor3 = THEME.Panel2
		section.Size = UDim2.new(1, -4, 0, 44)
		makeStroke(section)
		corner(section, 8)
		padding(section, 12, 12, 12, 12)
		local stack = vlist(section, 8)

		local header = label(section, title, 14, ui.Accent, true)
		header.Size = UDim2.new(1, -4, 0, 16)

		local function row(height: number)
			local r = new("Frame", section)
			r.BackgroundTransparency = 1
			r.Size = UDim2.new(1, 0, 0, height)
			return r
		end

		local function addToggle(labelText: string, default: boolean?, cb: (boolean) -> ()): ToggleHandle
			local r = row(28)
			local left = label(r, labelText, 14, THEME.Text, false)
			left.Size = UDim2.new(1, -60, 1, 0)

			local btn = new("TextButton", r)
			btn.BackgroundColor3 = THEME.Panel
			btn.Text = ""
			btn.Size = UDim2.new(0, 46, 0, 22)
			btn.Position = UDim2.new(1, -46, 0.5, -11)
			corner(btn, 6)
			makeStroke(btn)

			local knob = new("Frame", btn)
			knob.Size = UDim2.new(0, 18, 0, 18)
			knob.Position = UDim2.new(0, 2, 0.5, -9)
			knob.BackgroundColor3 = THEME.Outline
			corner(knob, 6)

			local state = default == true
			local changed: { (boolean) -> () } = {}

			local function render()
				if state then
					btn.BackgroundColor3 = ui.Accent
					knob.Position = UDim2.new(1, -20, 0.5, -9)
				else
					btn.BackgroundColor3 = THEME.Panel
					knob.Position = UDim2.new(0, 2, 0.5, -9)
				end
			end

			local function set(v: boolean)
				state = v and true or false
				render()
				cb(state)
				for _,f in ipairs(changed) do f(state) end
			end

			btn.MouseButton1Click:Connect(function() set(not state) end)
			render()

			return {
				Set = set,
				Get = function() return state end,
				OnChanged = function(_, f) table.insert(changed, f) end,
			}
		end

		local function addButton(text: string, cb: () -> ())
			local r = row(28)
			local b, _t = buttonBase(r, text)
			b.Size = UDim2.new(0, 140, 1, 0)
			b.AnchorPoint = Vector2.new(1, 0)
			b.Position = UDim2.new(1, 0, 0, 0)
			b.MouseButton1Click:Connect(cb)
		end

		local function addSlider(labelText: string, min: number, max: number, defaultVal: number?, suffix: string?, cb: (number) -> ()): SliderHandle
			min, max = math.min(min, max), math.max(min, max)
			local value = math.clamp(defaultVal or min, min, max)
			local r = row(34)
			local left = label(r, labelText, 14, THEME.Text)
			left.Size = UDim2.new(0.4, -6, 1, 0)

			local bar = new("Frame", r)
			bar.BackgroundColor3 = THEME.Panel
			bar.Size = UDim2.new(0.6, -6, 0, 6)
			bar.Position = UDim2.new(0.4, 6, 0.5, -3)
			corner(bar, 4)
			makeStroke(bar)

			local fill = new("Frame", bar)
			fill.BackgroundColor3 = THEME.Accent
			fill.Size = UDim2.new((value-min)/(max-min), 0, 1, 0)
			corner(fill, 4)

			local valText = label(r, string.format("%s%s", tostring(value), suffix or ""), 13, THEME.SubText)
			valText.Size = UDim2.new(0, 60, 1, 0)
			valText.Position = UDim2.new(1, -60, 0, 0)
			valText.TextXAlignment = Enum.TextXAlignment.Right

			local changed: { (number) -> () } = {}

			local function render()
				fill.Size = UDim2.new((value-min)/(max-min), 0, 1, 0)
				valText.Text = string.format("%s%s", tostring(round(value, 0.01)), suffix or "")
			end

			local function set(v: number)
				value = math.clamp(v, min, max)
				render()
				cb(value)
				for _,f in ipairs(changed) do f(value) end
			end

			local dragging = false
			bar.InputBegan:Connect(function(inp)
				if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
			end)
			UserInputService.InputEnded:Connect(function(inp)
				if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
			end)
			UserInputService.InputChanged:Connect(function(inp)
				if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
					local rel = math.clamp((inp.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
					set(min + (max - min) * rel)
				end
			end)

			render()
			return {
				Set = set,
				Get = function() return value end,
				OnChanged = function(_, f) table.insert(changed, f) end,
			}
		end

		local function addDropdown(labelText: string, items: {string}, defaultItem: string?, cb: (string) -> ()): DropdownHandle
			local current = defaultItem or items[1]
			local r = row(30)
			local left = label(r, labelText, 14)
			left.Size = UDim2.new(0.5, -6, 1, 0)

			local box = new("TextButton", r)
			box.Text = ""
			box.AutoButtonColor = false
			box.BackgroundColor3 = THEME.Panel
			box.Size = UDim2.new(0.5, -6, 1, 0)
			box.Position = UDim2.new(0.5, 6, 0, 0)
			corner(box, 6)
			makeStroke(box)

			local choice = label(box, current or "", 14)
			choice.Size = UDim2.new(1, -10, 1, 0)
			choice.Position = UDim2.new(0, 10, 0, 0)

			local listHolder = new("Frame", r)
			listHolder.BackgroundColor3 = THEME.Panel
			listHolder.Visible = false
			listHolder.Position = UDim2.new(0.5, 6, 1, 6)
			listHolder.Size = UDim2.new(0.5, -6, 0, math.min(6, #items)*26 + 8)
			corner(listHolder, 6)
			makeStroke(listHolder)
			padding(listHolder, 6, 6, 6, 6)
			local list = vlist(listHolder, 4)

			local function populate(newItems: {string})
				for _, c in ipairs(listHolder:GetChildren()) do
					if c:IsA("TextButton") then c:Destroy() end
				end
				for _, it in ipairs(newItems) do
					local opt, _ = buttonBase(listHolder, it)
					opt.Size = UDim2.new(1, 0, 0, 22)
					opt.MouseButton1Click:Connect(function()
						current = it
						choice.Text = it
						listHolder.Visible = false
						cb(it)
					end)
				end
			end

			populate(items)

			box.MouseButton1Click:Connect(function()
				listHolder.Visible = not listHolder.Visible
			end)

			return {
				Set = function(_, it: string) current = it; choice.Text = it; cb(it) end,
				Get = function() return current end,
				SetItems = function(_, it: {string}) items = it; populate(items) end,
				OnChanged = function(_, f) cb = f end,
			}
		end

		local function addKeybind(labelText: string, defaultKey: Enum.KeyCode?, cb: () -> ()): KeybindHandle
			local current = defaultKey
			local r = row(28)
			local left = label(r, labelText, 14)
			left.Size = UDim2.new(0.6, -6, 1, 0)

			local keyBtn, keyText = buttonBase(r, current and current.Name or "None")
			keyBtn.Size = UDim2.new(0.4, -6, 1, 0)
			keyBtn.Position = UDim2.new(0.6, 6, 0, 0)

			local waiting = false
			keyBtn.MouseButton1Click:Connect(function()
				waiting = true
				keyText.Text = "Press a key..."
			end)

			UserInputService.InputBegan:Connect(function(inp: InputObject, gp)
				if waiting and not gp and inp.KeyCode ~= Enum.KeyCode.Unknown then
					waiting = false
					current = inp.KeyCode
					keyText.Text = current.Name
					cb()
				end
			end)

			UserInputService.InputBegan:Connect(function(inp, gp)
				if not gp and current and inp.KeyCode == current then
					cb()
				end
			end)

			return {
				Set = function(_, key) current = key; keyText.Text = key and key.Name or "None" end,
				Get = function() return current end,
				OnActivated = function(_, fn) cb = fn end,
			}
		end

		local function addTextbox(labelText: string, placeholder: string?, cb: (string) -> ())
			local r = row(28)
			local left = label(r, labelText, 14)
			left.Size = UDim2.new(0.4, -6, 1, 0)

			local box = new("TextBox", r)
			box.ClearTextOnFocus = false
			box.PlaceholderText = placeholder or ""
			box.Text = ""
			box.BackgroundColor3 = THEME.Panel
			box.Size = UDim2.new(0.6, -6, 1, 0)
			box.Position = UDim2.new(0.4, 6, 0, 0)
			box.TextColor3 = THEME.Text
			box.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")
			box.TextSize = 14
			corner(box, 6)
			makeStroke(box)
			box.FocusLost:Connect(function(enter)
				if enter then cb(box.Text) end
			end)
		end

		-- grow section height as rows added
		section:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			local total = 0
			for _, child in ipairs(section:GetChildren()) do
				if child:IsA("GuiObject") then total += child.AbsoluteSize.Y end
			end
			section.Size = UDim2.new(1, -4, 0, math.max(44, total + 16))
		end)

		return {
			AddToggle = addToggle,
			AddButton = addButton,
			AddSlider = addSlider,
			AddDropdown = addDropdown,
			AddKeybind = addKeybind,
			AddTextbox = addTextbox,
		}
	end

	tabHandle = {
		AddSection = addSection,
		SetIcon = function(_, image) if image then tabText.Text = "  " .. tabText.Text end end,
	}

	return tabHandle
end

function Lib.new(opts: { title: string?, accent: Color3? }?): WindowHandle
	local title = (opts and opts.title) or "V4 UI"
	local accent = (opts and opts.accent) or THEME.Accent
	local root = makeScreenGui("V4_UI")
	local ui = makeWindow(root, title, accent)

	local windowHandle: WindowHandle
	windowHandle = {
		AddTab = function(_, name: string, icon: string?)
			return createTab(ui, name, icon)
		end,
		SetWatermark = function(_, text: string?) ui.SetWatermark(text) end,
		Show = function(_) ui.SetVisible(true) end,
		Hide = function(_) ui.SetVisible(false) end,
		Destroy = function(_)
			root:Destroy()
		end,
	}
	return windowHandle
end

return Lib
