--//====================================================================--
--// Wolf UI Library V1 (Fluent-Inspired Modular UI Framework)
--//====================================================================--

local Wolf = {
	Tabs = {},
	ActiveTab = nil,
	Elements = {},
	OpenDropdowns = {},
	Locked = false,
}
Wolf.__index = Wolf

---------------------------------------------------------------------
-- SERVICES & SETUP
---------------------------------------------------------------------

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

---------------------------------------------------------------------
-- ICON MODULE (Lucide + Spritesheet Cropping)
---------------------------------------------------------------------

local Lucide
do
	local Success, Module = pcall(function()
		local Source =
			game:HttpGet("https://raw.githubusercontent.com/SOUSHI45099/Assets/refs/heads/main/LucideRoblox.lua")
		return loadstring(Source)()
	end)
	Lucide = Success and Module or nil
end

local function IsValidCustomIcon(Icon)
	return typeof(Icon) == "string"
		and (
			Icon:match("^rbxasset://textures/")
			or Icon:match("^rbxassetid://")
			or Icon:match("^rbxthumb://type=")
			or Icon:match("roblox%.com/asset/%?id=")
		)
end

local function ApplyIcon(ImageObject, iconName)
	if not iconName or iconName == "" then
		ImageObject.Visible = false
		return
	end
	ImageObject.Visible = true
	ImageObject.ImageTransparency = 0

	if tonumber(iconName) then
		iconName = "rbxassetid://" .. iconName
	end

	if IsValidCustomIcon(iconName) then
		ImageObject.Image = iconName
		ImageObject.ImageRectOffset = Vector2.new(0, 0)
		ImageObject.ImageRectSize = Vector2.new(0, 0)
		return
	end

	if Lucide then
		local Success, Asset = pcall(function()
			return Lucide.GetAsset(iconName)
		end)

		if Success and Asset then
			ImageObject.Image = Asset.Url
			ImageObject.ImageRectOffset = Asset.ImageRectOffset
			ImageObject.ImageRectSize = Asset.ImageRectSize
			return
		end
	end

	-- Fallback icon
	ImageObject.Image = "rbxassetid://10709782497"
	ImageObject.ImageRectOffset = Vector2.new(0, 0)
	ImageObject.ImageRectSize = Vector2.new(0, 0)
end

local function CreateIcon(Parent, IconName, Position, Size, Color, ZIndex)
	local Icon = Instance.new("ImageLabel")
	Icon.Name = "Icon"
	Icon.BackgroundTransparency = 1
	Icon.Position = Position
	Icon.Size = Size or UDim2.fromOffset(16, 16)
	Icon.ImageColor3 = Color or Wolf.Theme.Text
	Icon.ZIndex = ZIndex or 2
	ApplyIcon(Icon, IconName)
	Icon.Parent = Parent
	return Icon
end

---------------------------------------------------------------------
-- FONTS & THEME DEFINITION
---------------------------------------------------------------------

Wolf.Fonts = {
	Logo = Font.fromName("Bangers", Enum.FontWeight.Bold),
	Title = Font.fromName("BuilderSans", Enum.FontWeight.SemiBold),
	Body = Font.fromName("BuilderSans", Enum.FontWeight.Medium),
	Small = Font.fromName("BuilderSans", Enum.FontWeight.Regular),
	Button = Font.fromName("BuilderSans", Enum.FontWeight.Bold),
}

Wolf.Theme = {
	Background = Color3.fromRGB(15, 15, 17),
	Sidebar = Color3.fromRGB(22, 22, 25),
	Header = Color3.fromRGB(18, 18, 20),
	Card = Color3.fromRGB(28, 28, 32),

	Surface = Color3.fromRGB(38, 38, 42),
	SurfaceHover = Color3.fromRGB(50, 50, 56),

	Accent = Color3.fromRGB(130, 6, 6),
	AccentDark = Color3.fromRGB(90, 0, 0),

	Text = Color3.fromRGB(245, 245, 245),
	SubText = Color3.fromRGB(155, 155, 160),

	Border = Color3.fromRGB(50, 50, 55),
}

---------------------------------------------------------------------
-- UTILITY HELPERS
---------------------------------------------------------------------

local FastTween = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function Tween(Object, Properties, Time)
	local Info = Time and TweenInfo.new(Time, Enum.EasingStyle.Quint, Enum.EasingDirection.Out) or FastTween
	TweenService:Create(Object, Info, Properties):Play()
end

local function Corner(Object, Radius)
	local C = Instance.new("UICorner")
	C.CornerRadius = UDim.new(0, Radius or 6)
	C.Parent = Object
	return C
end

local function Stroke(Object, Color, Transparency)
	local S = Instance.new("UIStroke")
	S.Color = Color or Wolf.Theme.Border
	S.Thickness = 1
	S.Transparency = Transparency or 0.5
	S.Parent = Object
	return S
end

local function Padding(Object, L, R, T, B)
	local P = Instance.new("UIPadding")
	P.PaddingLeft = UDim.new(0, L or 0)
	P.PaddingRight = UDim.new(0, R or 0)
	P.PaddingTop = UDim.new(0, T or 0)
	P.PaddingBottom = UDim.new(0, B or 0)
	P.Parent = Object
	return P
end

local function ElementParent(Tab, Config)
	local RequestedSection = typeof(Config) == "table" and Config.Section
	if RequestedSection == false then
		return Tab.Page
	end
	if RequestedSection then
		if typeof(RequestedSection) == "table" and RequestedSection.Content then
			return RequestedSection.Content
		end
		if typeof(RequestedSection) == "Instance" then
			if RequestedSection.Name == "SectionContent" then
				return RequestedSection
			end
			local Content = RequestedSection:FindFirstChild("SectionContent")
			if Content then
				return Content
			end
		elseif typeof(RequestedSection) == "string" then
			for _, Candidate in ipairs(Tab.Page:GetChildren()) do
				if Candidate:IsA("GuiObject") and Candidate:GetAttribute("WolfSectionTitle") == RequestedSection then
					local Content = Candidate:FindFirstChild("SectionContent")
					if Content then
						return Content
					end
				end
			end
		end
	end
	return Tab.Page
end

---------------------------------------------------------------------
-- WINDOW CREATION
---------------------------------------------------------------------

function Wolf:CreateWindow(Config)
	Config = Config or {}
	self.Tabs = {}
	self.Elements = {}
	self.ActiveTab = nil
	self.ShortcutHolder = nil
	self.ShortcutCount = 0
	self.ShortcutButtons = {}
	self.ShortcutChevrons = {}
	self.ShortcutTriggers = {}
	self.ShortcutSideCounts = { S1 = 0, S2 = 0 }
	self._ShortcutConnections = self._ShortcutConnections or {}
	for _, Connection in ipairs(self._ShortcutConnections) do
		Connection:Disconnect()
	end
	table.clear(self._ShortcutConnections)
	self.OpenDropdowns = {}
	if self._RenderConnection then
		self._RenderConnection:Disconnect()
		self._RenderConnection = nil
	end

	local ParentContainer = CoreGui
	pcall(function()
		if not RunService:IsStudio() then
			ParentContainer = (gethui and gethui()) or CoreGui
		else
			ParentContainer = LocalPlayer:WaitForChild("PlayerGui")
		end
	end)

	if ParentContainer:FindFirstChild("WolfUI") then
		ParentContainer.WolfUI:Destroy()
	end
	if ParentContainer:FindFirstChild("WolfUIToggle") then
		ParentContainer.WolfUIToggle:Destroy()
	end
	if ParentContainer:FindFirstChild("WolfUIShortcuts") then
		ParentContainer.WolfUIShortcuts:Destroy()
	end

	local WolfUI = Instance.new("ScreenGui")
	WolfUI.Name = "WolfUI"
	WolfUI.ResetOnSpawn = false
	WolfUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	WolfUI.Parent = ParentContainer

	local IsMobile = UserInputService.TouchEnabled
	local DeviceWindowSize = IsMobile and UDim2.fromOffset(380, 520) or UDim2.fromOffset(720, 460)

	local MainFrame = Instance.new("Frame")
	MainFrame.Name = "MainFrame"
	MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	MainFrame.Position = UDim2.fromScale(0.5, 0.5)
	MainFrame.Size = DeviceWindowSize
	MainFrame.BackgroundColor3 = self.Theme.Background
	MainFrame.BackgroundTransparency = 0.05
	MainFrame.BorderSizePixel = 0
	MainFrame.ClipsDescendants = true
	MainFrame.Parent = WolfUI

	Corner(MainFrame, 8)
	Stroke(MainFrame, self.Theme.Border)

	-- Sidebar (Left Area)
	local Sidebar = Instance.new("Frame")
	Sidebar.Name = "Sidebar"
	Sidebar.Size = UDim2.new(0, 190, 1, 0)
	Sidebar.BackgroundColor3 = self.Theme.Sidebar
	Sidebar.BorderSizePixel = 0
	Sidebar.ClipsDescendants = true
	Sidebar.ZIndex = 1
	Sidebar.Parent = MainFrame

	local Divider = Instance.new("Frame")
	Divider.Size = UDim2.new(0, 1, 1, 0)
	Divider.Position = UDim2.new(1, -1, 0, 0)
	Divider.BorderSizePixel = 0
	Divider.BackgroundColor3 = self.Theme.Border
	Divider.Parent = Sidebar

	local SidebarResizeHandle = Instance.new("TextButton")
	SidebarResizeHandle.Name = "SidebarResizeHandle"
	SidebarResizeHandle.Position = UDim2.new(0, 186, 0, 0)
	SidebarResizeHandle.Size = UDim2.new(0, 8, 1, 0)
	SidebarResizeHandle.BackgroundTransparency = 1
	SidebarResizeHandle.Text = ""
	SidebarResizeHandle.AutoButtonColor = false
	SidebarResizeHandle.Active = true
	SidebarResizeHandle.ZIndex = 20
	SidebarResizeHandle.Parent = MainFrame

	-- Profile Card
	local ProfileCard = Instance.new("Frame")
	ProfileCard.Size = UDim2.new(1, 0, 0, 110)
	ProfileCard.BackgroundColor3 = self.Theme.Card
	ProfileCard.BorderSizePixel = 0
	ProfileCard.Parent = Sidebar

	local Avatar = Instance.new("ImageLabel")
	Avatar.Position = UDim2.fromOffset(12, 18)
	Avatar.Size = UDim2.fromOffset(48, 48)
	Avatar.BackgroundTransparency = 1
	ApplyIcon(Avatar, "user")
	Avatar.ImageColor3 = self.Theme.Text
	Avatar.Parent = ProfileCard
	Corner(Avatar, 100)

	pcall(function()
		Avatar.Image = Players:GetUserThumbnailAsync(
			LocalPlayer.UserId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size100x100
		)
	end)

	local PlayerName = Instance.new("TextLabel")
	PlayerName.BackgroundTransparency = 1
	PlayerName.Position = UDim2.fromOffset(68, 20)
	PlayerName.Size = UDim2.new(1, -76, 0, 18)
	PlayerName.FontFace = self.Fonts.Body
	PlayerName.TextSize = 14
	PlayerName.TextColor3 = self.Theme.Text
	PlayerName.TextXAlignment = Enum.TextXAlignment.Left
	PlayerName.TextTruncate = Enum.TextTruncate.AtEnd
	PlayerName.Text = LocalPlayer.DisplayName
	PlayerName.Parent = ProfileCard

	local Username = Instance.new("TextLabel")
	Username.BackgroundTransparency = 1
	Username.Position = UDim2.fromOffset(68, 38)
	Username.Size = UDim2.new(1, -76, 0, 15)
	Username.FontFace = self.Fonts.Small
	Username.TextSize = 10
	Username.TextColor3 = self.Theme.SubText
	Username.TextXAlignment = Enum.TextXAlignment.Left
	Username.TextTruncate = Enum.TextTruncate.AtEnd
	Username.Text = "@" .. LocalPlayer.Name
	Username.Parent = ProfileCard

	local DeviceIcon = Instance.new("ImageButton")
	DeviceIcon.Position = UDim2.new(1, -40, 0, 80)
	DeviceIcon.Size = UDim2.fromOffset(24, 24)
	DeviceIcon.BackgroundTransparency = 1
	DeviceIcon.AutoButtonColor = false
	DeviceIcon.Active = true
	ApplyIcon(DeviceIcon, UserInputService.TouchEnabled and "smartphone" or "monitor")
	DeviceIcon.ImageColor3 = self.Theme.Accent
	DeviceIcon.Parent = ProfileCard

	local DeviceLabel = Instance.new("TextLabel")
	DeviceLabel.BackgroundTransparency = 1
	DeviceLabel.Position = UDim2.fromOffset(12, 78)
	DeviceLabel.Size = UDim2.new(1, -60, 0, 18)
	DeviceLabel.FontFace = self.Fonts.Small
	DeviceLabel.TextSize = 11
	DeviceLabel.TextColor3 = self.Theme.SubText
	DeviceLabel.TextXAlignment = Enum.TextXAlignment.Left
	DeviceLabel.Text = UserInputService.TouchEnabled and "MOBILE" or "PC"
	DeviceLabel.Parent = ProfileCard

	-- Tab Container
	local TabContainer = Instance.new("ScrollingFrame")
	TabContainer.Name = "TabContainer"
	TabContainer.Position = UDim2.fromOffset(0, 110)
	TabContainer.Size = UDim2.new(1, 0, 1, -110)
	TabContainer.BackgroundTransparency = 1
	TabContainer.BorderSizePixel = 0
	TabContainer.ScrollBarThickness = 2
	TabContainer.ScrollBarImageColor3 = self.Theme.Accent
	TabContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
	TabContainer.CanvasSize = UDim2.new()
	TabContainer.Parent = Sidebar

	Padding(TabContainer, 2, 8, 8, 8)

	local TabLayout = Instance.new("UIListLayout")
	TabLayout.Padding = UDim.new(0, 4)
	TabLayout.Parent = TabContainer

	-- Header Frame
	local HeaderFrame = Instance.new("Frame")
	HeaderFrame.Name = "HeaderFrame"
	HeaderFrame.Position = UDim2.new(0, 190, 0, 0)
	HeaderFrame.Size = UDim2.new(1, -190, 0, 52)
	HeaderFrame.BackgroundColor3 = self.Theme.Header
	HeaderFrame.BorderSizePixel = 0
	HeaderFrame.ZIndex = 2
	HeaderFrame.Parent = MainFrame

	local AccentBar = Instance.new("Frame")
	AccentBar.Size = UDim2.new(1, 0, 0, 2)
	AccentBar.BorderSizePixel = 0
	AccentBar.BackgroundColor3 = self.Theme.Accent
	AccentBar.Parent = MainFrame

	local HeaderTitle = Instance.new("TextLabel")
	HeaderTitle.BackgroundTransparency = 1
	HeaderTitle.Position = UDim2.fromOffset(16, 0)
	HeaderTitle.Size = UDim2.fromOffset(200, 52)
	HeaderTitle.FontFace = self.Fonts.Logo
	HeaderTitle.Text = Config.Title or "WOLF UI"
	HeaderTitle.TextSize = 25
	HeaderTitle.TextColor3 = self.Theme.Accent
	HeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
	HeaderTitle.Parent = HeaderFrame

	local ControlsHolder = Instance.new("Frame")
	ControlsHolder.BackgroundTransparency = 1
	ControlsHolder.AnchorPoint = Vector2.new(1, 0.5)
	ControlsHolder.Position = UDim2.new(1, -44, 0.5, 0)
	ControlsHolder.Size = UDim2.fromOffset(230, 34)
	ControlsHolder.Parent = HeaderFrame

	local ControlsLayout = Instance.new("UIListLayout")
	ControlsLayout.FillDirection = Enum.FillDirection.Horizontal
	ControlsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	ControlsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	ControlsLayout.Padding = UDim.new(0, 8)
	ControlsLayout.Parent = ControlsHolder

	-- Drag Icon
	local DragIcon = Instance.new("ImageButton")
	DragIcon.Name = "DragIcon"
	DragIcon.AnchorPoint = Vector2.new(1, 0.5)
	DragIcon.Position = UDim2.new(1, -10, 0.5, 0)
	DragIcon.Size = UDim2.fromOffset(24, 24)
	DragIcon.BackgroundTransparency = 1
	ApplyIcon(DragIcon, "move")
	DragIcon.ImageColor3 = self.Theme.Accent
	DragIcon.Parent = HeaderFrame

	-- Search Box
	local SearchContainer = Instance.new("Frame")
	SearchContainer.Name = "SearchContainer"
	SearchContainer.Size = UDim2.fromOffset(130, 30)
	SearchContainer.BackgroundColor3 = self.Theme.Surface
	SearchContainer.Parent = ControlsHolder
	Corner(SearchContainer, 6)
	Stroke(SearchContainer, self.Theme.Border)

	local SearchBox = Instance.new("TextBox")
	SearchBox.Name = "SearchBox"
	SearchBox.Position = UDim2.fromOffset(24, 0)
	SearchBox.Size = UDim2.new(1, -24, 1, 0)
	SearchBox.BackgroundTransparency = 1
	SearchBox.TextColor3 = self.Theme.Text
	SearchBox.PlaceholderColor3 = self.Theme.SubText
	SearchBox.Text = ""
	SearchBox.PlaceholderText = "Search..."
	SearchBox.FontFace = self.Fonts.Body
	SearchBox.TextSize = 12
	SearchBox.ClearTextOnFocus = false
	SearchBox.ClipsDescendants = true
	SearchBox.Parent = SearchContainer

	local SearchIcon = Instance.new("ImageLabel")
	SearchIcon.Name = "SearchIcon"
	SearchIcon.BackgroundTransparency = 1
	SearchIcon.Size = UDim2.fromOffset(14, 14)
	SearchIcon.Position = UDim2.new(0, 8, 0.5, 0)
	SearchIcon.AnchorPoint = Vector2.new(0, 0.5)
	SearchIcon.ImageColor3 = self.Theme.SubText
	SearchIcon.Parent = SearchContainer
	ApplyIcon(SearchIcon, "search")

	-- Lock Button
	local LockButton = Instance.new("TextButton")
	LockButton.Name = "LockButton"
	LockButton.Size = UDim2.fromOffset(68, 30)
	LockButton.BackgroundColor3 = self.Theme.AccentDark
	LockButton.TextColor3 = Color3.new(1, 1, 1)
	LockButton.FontFace = self.Fonts.Button
	LockButton.TextSize = 11
	LockButton.Text = ""
	LockButton.Parent = ControlsHolder
	Corner(LockButton, 6)
	local LockIcon =
		CreateIcon(LockButton, "lock", UDim2.fromOffset(7, 8), UDim2.fromOffset(13, 13), Color3.new(1, 1, 1), 2)
	local LockText = Instance.new("TextLabel")
	LockText.BackgroundTransparency = 1
	LockText.Position = UDim2.fromOffset(25, 0)
	LockText.Size = UDim2.new(1, -29, 1, 0)
	LockText.FontFace = self.Fonts.Button
	LockText.Text = "LOCK"
	LockText.TextSize = 11
	LockText.TextColor3 = Color3.new(1, 1, 1)
	LockText.TextXAlignment = Enum.TextXAlignment.Left
	LockText.Parent = LockButton

	-- Main Display Container
	local ContentArea = Instance.new("ScrollingFrame")
	ContentArea.Name = "ContentArea"
	ContentArea.Position = UDim2.new(0, 190, 0, 52)
	ContentArea.Size = UDim2.new(1, -190, 1, -76)
	ContentArea.BackgroundTransparency = 1
	ContentArea.BorderSizePixel = 0
	ContentArea.ClipsDescendants = true
	ContentArea.ScrollBarThickness = 2
	ContentArea.ScrollBarImageColor3 = self.Theme.Accent
	ContentArea.AutomaticCanvasSize = Enum.AutomaticSize.Y
	ContentArea.CanvasSize = UDim2.new()
	ContentArea.ZIndex = 2
	ContentArea.Parent = MainFrame

	Padding(ContentArea, 16, 16, 8, 16)

	local ContentLayout = Instance.new("UIListLayout")
	ContentLayout.Padding = UDim.new(0, 8)
	ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	ContentLayout.Parent = ContentArea

	-- Footer
	local Footnote = Instance.new("Frame")
	Footnote.Size = UDim2.new(1, -190, 0, 24)
	Footnote.Position = UDim2.new(0, 190, 1, -24)
	Footnote.BackgroundColor3 = self.Theme.Header
	Footnote.BorderSizePixel = 0
	Footnote.ZIndex = 2
	Footnote.Parent = MainFrame

	local FootText = Instance.new("TextLabel")
	FootText.BackgroundTransparency = 1
	FootText.Position = UDim2.fromOffset(12, 0)
	FootText.Size = UDim2.new(1, -40, 1, 0)
	FootText.FontFace = self.Fonts.Small
	FootText.Text = Config.Footnote or "Wolf UI | Fluent Engine"
	FootText.TextColor3 = self.Theme.SubText
	FootText.TextSize = 11
	FootText.TextXAlignment = Enum.TextXAlignment.Center
	FootText.Parent = Footnote

	local FooterIcon =
		CreateIcon(Footnote, Config.Icon, UDim2.new(0, 8, 0.5, 0), UDim2.fromOffset(14, 14), self.Theme.SubText, 3)
	FooterIcon.AnchorPoint = Vector2.new(0, 0.5)
	FootText.Position = UDim2.fromOffset(Config.Icon and 28 or 12, 0)
	FootText.Size = UDim2.new(1, Config.Icon and -56 or -40, 1, 0)

	local ResizeIcon = Instance.new("ImageButton")
	ResizeIcon.Name = "ResizeIcon"
	ResizeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	ResizeIcon.Position = UDim2.new(1, -14, 1, -14)
	ResizeIcon.Size = UDim2.fromOffset(18, 18)
	ResizeIcon.BackgroundTransparency = 1
	ResizeIcon.AutoButtonColor = false
	ResizeIcon.Active = true
	ResizeIcon.ZIndex = 20
	ApplyIcon(ResizeIcon, "minimize-2")
	ResizeIcon.ImageColor3 = self.Theme.SubText
	ResizeIcon.Rotation = 90
	ResizeIcon.Parent = MainFrame

	local ToggleGui = Instance.new("ScreenGui")
	ToggleGui.Name = "WolfUIToggle"
	ToggleGui.ResetOnSpawn = false
	ToggleGui.DisplayOrder = 100
	ToggleGui.Parent = ParentContainer

	local ToggleButton = Instance.new("ImageButton")
	ToggleButton.Name = "ToggleButton"
	ToggleButton.AnchorPoint = Vector2.new(0, 0)
	ToggleButton.Position = UDim2.fromOffset(18, 18)
	ToggleButton.Size = UDim2.fromOffset(46, 46)
	ToggleButton.BackgroundTransparency = 1
	ToggleButton.AutoButtonColor = false
	ToggleButton.Image = "rbxthumb://type=Asset&id=112381138279003&w=150&h=150"
	ToggleButton.ImageColor3 = self.Theme.Text
	ToggleButton.ZIndex = 100
	ToggleButton.Parent = ToggleGui
	Corner(ToggleButton, 8)

	local uiVisible = true
	self._UIVisible = true
	local TargetWindowSize = DeviceWindowSize
	local TargetWindowPosition = MainFrame.Position
	local function ComfortableWindowSize()
		local ViewportSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		local Width
		local Height
		if UserInputService.TouchEnabled then
			Width = math.min(380, math.max(300, ViewportSize.X - 24))
			Height = math.min(560, math.max(360, ViewportSize.Y - 80))
		else
			Width = math.min(800, math.max(560, ViewportSize.X - 80))
			Height = math.min(560, math.max(380, ViewportSize.Y - 100))
		end
		return UDim2.fromOffset(Width, Height)
	end

	local function FitWindowToDevice()
		TargetWindowSize = ComfortableWindowSize()
		MainFrame.Size = TargetWindowSize
		MainFrame.Position = UDim2.fromScale(0.5, 0.5)
	end

	DeviceIcon.MouseButton1Click:Connect(function()
		FitWindowToDevice()
	end)
	local ToggleDragging = false
	local ToggleMoved = false
	local ToggleStartInputPosition
	local ToggleStartButtonPosition

	local function ToggleCenterPosition()
		return ToggleButton.AbsolutePosition + ToggleButton.AbsoluteSize / 2
	end

	local function SetUIVisible(Visible)
		uiVisible = Visible
		self._UIVisible = Visible
		if self.ShortcutGui then
			self.ShortcutGui.Enabled = true
		end
		if self.ShortcutHolder then
			self.ShortcutHolder.Visible = true
		end
		local ToggleCenter = ToggleCenterPosition()
		if Visible then
			TargetWindowPosition = TargetWindowPosition or MainFrame.Position
			MainFrame.Visible = true
			MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
			MainFrame.Position = UDim2.fromOffset(ToggleCenter.X, ToggleCenter.Y)
			MainFrame.Size = UDim2.fromOffset(0, 0)
			MainFrame.BackgroundTransparency = 1
			Tween(MainFrame, {
				Position = TargetWindowPosition,
				Size = TargetWindowSize,
				BackgroundTransparency = 0.05,
			}, 0.3)
		else
			TargetWindowPosition = MainFrame.Position
			TargetWindowSize = MainFrame.Size
			Tween(MainFrame, {
				Position = UDim2.fromOffset(ToggleCenter.X, ToggleCenter.Y),
				Size = UDim2.fromOffset(0, 0),
				BackgroundTransparency = 1,
			}, 0.24)
			task.delay(0.26, function()
				if not uiVisible then
					MainFrame.Visible = false
				end
			end)
		end
	end

	ToggleButton.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			ToggleDragging = true
			ToggleMoved = false
			ToggleStartInputPosition = input.Position
			ToggleStartButtonPosition = ToggleButton.Position
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if
			ToggleDragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			local Delta = input.Position - ToggleStartInputPosition
			ToggleMoved = ToggleMoved or Delta.Magnitude > 6
			if ToggleMoved then
				ToggleButton.Position = UDim2.new(
					ToggleStartButtonPosition.X.Scale,
					ToggleStartButtonPosition.X.Offset + Delta.X,
					ToggleStartButtonPosition.Y.Scale,
					ToggleStartButtonPosition.Y.Offset + Delta.Y
				)
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if
			ToggleDragging
			and (
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			ToggleDragging = false
			if not ToggleMoved then
				SetUIVisible(not uiVisible)
			end
		end
	end)
	self.SetVisible = SetUIVisible
	self.ToggleButton = ToggleButton
	MainFrame.Size = UDim2.fromOffset(0, 0)
	MainFrame.BackgroundTransparency = 1
	task.defer(function()
		SetUIVisible(true)
	end)

	---------------------------------------------------------
	-- RESIZING MECHANISM
	---------------------------------------------------------

	local resizing = false
	local resizeStartPos
	local startSize

	-- Minimum allowed window dimensions to prevent UI collapse
	local MinSize = Vector2.new(360, 220)
	-- Maximum allowed window dimensions
	local MaxSize = Vector2.new(1000, 700)

	local SidebarWidth = IsMobile and 110 or 190
	local SidebarMinWidth = 110
	local SidebarMaxWidth = 300
	local SidebarRatio = SidebarWidth / (IsMobile and 380 or 720)

	local function UpdateSidebarLayout()
		Sidebar.Size = UDim2.new(0, SidebarWidth, 1, 0)
		SidebarResizeHandle.Position = UDim2.new(0, SidebarWidth - 4, 0, 0)
		HeaderFrame.Position = UDim2.new(0, SidebarWidth, 0, 0)
		HeaderFrame.Size = UDim2.new(1, -SidebarWidth, 0, 52)
		ContentArea.Position = UDim2.new(0, SidebarWidth, 0, 52)
		ContentArea.Size = UDim2.new(1, -SidebarWidth, 1, -76)
		Footnote.Position = UDim2.new(0, SidebarWidth, 1, -24)
		Footnote.Size = UDim2.new(1, -SidebarWidth, 0, 24)
	end
	UpdateSidebarLayout()
	FitWindowToDevice()

	local function CloseDropdowns()
		for _, Dropdown in ipairs(self.OpenDropdowns) do
			Dropdown.Frame.Visible = false
			if Dropdown.Chevron then
				ApplyIcon(Dropdown.Chevron, Dropdown.ClosedIcon or "chevron-down")
			end
		end
		table.clear(self.OpenDropdowns)
	end
	self._CloseDropdowns = CloseDropdowns

	local function IsPointInside(Object, Point)
		if not Object or not Object.Visible then
			return false
		end
		local Position = Object.AbsolutePosition
		local Size = Object.AbsoluteSize
		return Point.X >= Position.X
			and Point.X <= Position.X + Size.X
			and Point.Y >= Position.Y
			and Point.Y <= Position.Y + Size.Y
	end

	UserInputService.InputBegan:Connect(function(Input)
		if
			Input.UserInputType ~= Enum.UserInputType.MouseButton1
			and Input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		local Point = Vector2.new(Input.Position.X, Input.Position.Y)
		for _, Dropdown in ipairs(self.OpenDropdowns) do
			if IsPointInside(Dropdown.Frame, Point) or IsPointInside(Dropdown.Anchor, Point) then
				return
			end
		end
		if #self.OpenDropdowns > 0 then
			CloseDropdowns()
		end
	end)

	local function UpdateDropdownPositions()
		for _, Dropdown in ipairs(self.OpenDropdowns) do
			local Anchor = Dropdown.Anchor
			if
				Dropdown.Frame.Visible
				and (Dropdown.Frame.Parent == self.Gui or Dropdown.Frame.Parent == self.ShortcutGui)
				and Anchor
				and Anchor.Parent
			then
				local IsDetached = Dropdown.Frame.Parent == self.ShortcutGui
				local WindowPosition = IsDetached and Vector2.zero or MainFrame.AbsolutePosition
				local WindowSize = IsDetached
						and (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720))
					or MainFrame.AbsoluteSize
				local AnchorPosition = Anchor.AbsolutePosition
				local AnchorSize = Anchor.AbsoluteSize
				local FrameSize = Dropdown.Frame.AbsoluteSize
				local X
				local Y
				if Dropdown.SideAnchor then
					local RightX = AnchorPosition.X + AnchorSize.X + 4
					local LeftX = AnchorPosition.X - FrameSize.X - 4
					X = RightX + FrameSize.X <= WindowPosition.X + WindowSize.X - 4 and RightX or LeftX
					Y = AnchorPosition.Y + (AnchorSize.Y - FrameSize.Y) / 2
				else
					X = AnchorPosition.X + AnchorSize.X - FrameSize.X
					Y = AnchorPosition.Y + AnchorSize.Y + 4
				end
				local MinX = WindowPosition.X + 4
				local MaxX = WindowPosition.X + WindowSize.X - FrameSize.X - 4
				local MinY = WindowPosition.Y + 4
				local MaxY = WindowPosition.Y + WindowSize.Y - FrameSize.Y - 4

				X = math.clamp(X, MinX, math.max(MinX, MaxX))
				Y = math.clamp(Y, MinY, math.max(MinY, MaxY))
				Dropdown.Frame.Position = UDim2.fromOffset(X, Y)
			end
		end
	end
	self._UpdateDropdownPositions = UpdateDropdownPositions
	self._RenderConnection = RunService.RenderStepped:Connect(UpdateDropdownPositions)

	local sidebarResizing = false
	local sidebarResizeStartX
	local sidebarResizeStartWidth

	SidebarResizeHandle.InputBegan:Connect(function(input)
		if
			not self.Locked
			and (
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			sidebarResizing = true
			sidebarResizeStartX = input.Position.X
			sidebarResizeStartWidth = SidebarWidth
		end
	end)

	ResizeIcon.InputBegan:Connect(function(input)
		if
			not self.Locked
			and (
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			resizing = true
			resizeStartPos = input.Position
			startSize = MainFrame.AbsoluteSize
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			resizing = false
			sidebarResizing = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if
			sidebarResizing
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			SidebarWidth = math.clamp(
				sidebarResizeStartWidth + (input.Position.X - sidebarResizeStartX),
				SidebarMinWidth,
				SidebarMaxWidth
			)
			SidebarRatio = SidebarWidth / MainFrame.AbsoluteSize.X
			UpdateSidebarLayout()
		end

		if
			resizing
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			local Delta = input.Position - resizeStartPos

			-- Calculate new pixel sizes within constraints
			local NewWidth = math.clamp(startSize.X + Delta.X, MinSize.X, MaxSize.X)
			local NewHeight = math.clamp(startSize.Y + Delta.Y, MinSize.Y, MaxSize.Y)

			MainFrame.Size = UDim2.fromOffset(NewWidth, NewHeight)
			TargetWindowSize = MainFrame.Size
			UpdateSidebarLayout()
		end
	end)

	---------------------------------------------------------
	-- DRAGGING MECHANISM
	---------------------------------------------------------

	local dragging, dragStart, startPos = false, nil, nil

	DragIcon.InputBegan:Connect(function(input)
		if
			not self.Locked
			and (
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			dragging = true
			dragStart = input.Position
			startPos = MainFrame.Position
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			local Delta = input.Position - dragStart
			MainFrame.Position =
				UDim2.new(startPos.X.Scale, startPos.X.Offset + Delta.X, startPos.Y.Scale, startPos.Y.Offset + Delta.Y)
		end
	end)

	-- Lock Handler
	LockButton.MouseButton1Click:Connect(function()
		self.Locked = not self.Locked
		LockText.Text = self.Locked and "UNLOCK" or "LOCK"
		ApplyIcon(LockIcon, self.Locked and "unlock" or "lock")
		Tween(LockButton, {
			BackgroundColor3 = self.Locked and self.Theme.Surface or self.Theme.AccentDark,
		})
	end)

	-- Search Filter Logic
	SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		local Query = SearchBox.Text:lower()
		local FirstMatchTab
		if Query ~= "" then
			for _, ExistingTab in ipairs(self.Tabs) do
				ExistingTab.Page.Visible = false
			end
		end
		for _, ElementData in ipairs(self.Elements) do
			local Match = Query == "" or tostring(ElementData.Text):lower():find(Query, 1, true) ~= nil
			ElementData.Frame.Visible = Match
			if Match then
				for _, ExistingTab in ipairs(self.Tabs) do
					if ElementData.Frame:IsDescendantOf(ExistingTab.Page) then
						FirstMatchTab = FirstMatchTab or ExistingTab
						ExistingTab.Page.Visible = true
						local Parent = ElementData.Frame.Parent
						while Parent and Parent ~= ExistingTab.Page do
							if Parent:IsA("GuiObject") then
								Parent.Visible = true
							end
							Parent = Parent.Parent
						end
					end
				end
			end
		end
		if Query ~= "" and FirstMatchTab then
			self.ActiveTab = FirstMatchTab
		end
		if Query == "" then
			for _, ExistingTab in ipairs(self.Tabs) do
				ExistingTab.Page.Visible = ExistingTab == self.ActiveTab
			end
		end
	end)

	self.Gui = WolfUI
	self.MainFrame = MainFrame
	self.ContentArea = ContentArea
	self.TabContainer = TabContainer

	return self
end

---------------------------------------------------------------------
-- TAB CREATION
---------------------------------------------------------------------

function Wolf:AddTab(Config)
	Config = typeof(Config) == "table" and Config or { Title = Config }

	local TabTitle = Config.Title or "Tab"
	local TabIcon = Config.Icon or Config.icon
	local TabPage = Instance.new("Frame")
	TabPage.Name = TabTitle .. "Page"
	TabPage.Size = UDim2.new(1, 0, 0, 0)
	TabPage.AutomaticSize = Enum.AutomaticSize.Y
	TabPage.BackgroundTransparency = 1
	TabPage.LayoutOrder = #self.Tabs + 2
	TabPage.Visible = false
	TabPage.Parent = self.ContentArea

	local PageTitle = Instance.new("TextLabel")
	PageTitle.Name = "TabTitle"
	PageTitle.LayoutOrder = -1
	PageTitle.Size = UDim2.new(1, 0, 0, 42)
	PageTitle.BackgroundTransparency = 1
	PageTitle.FontFace = Font.fromName("PermanentMarker", Enum.FontWeight.Bold)
	PageTitle.Text = TabTitle
	PageTitle.TextColor3 = self.Theme.Text
	PageTitle.TextSize = 20
	PageTitle.TextXAlignment = Enum.TextXAlignment.Left
	PageTitle.Parent = TabPage

	local PageLayout = Instance.new("UIListLayout")
	PageLayout.Padding = UDim.new(0, 8)
	PageLayout.SortOrder = Enum.SortOrder.LayoutOrder
	PageLayout.Parent = TabPage

	local TabButton = Instance.new("TextButton")
	TabButton.Name = TabTitle .. "Tab"
	TabButton.Size = UDim2.new(1, 0, 0, 34)
	TabButton.BackgroundColor3 = self.Theme.Card
	TabButton.BackgroundTransparency = 1
	TabButton.TextColor3 = self.Theme.Text
	TabButton.FontFace = self.Fonts.Body
	TabButton.Text = ""
	TabButton.TextSize = 12
	TabButton.ZIndex = 2
	TabButton.Parent = self.TabContainer
	Corner(TabButton, 6)
	Stroke(TabButton, self.Theme.Border)
	Padding(TabButton, TabIcon and 21 or 4, 6, 0, 0)
	CreateIcon(TabButton, TabIcon, UDim2.fromOffset(0, 10), UDim2.fromOffset(14, 14), self.Theme.Text, 3)
	local TabText = Instance.new("TextLabel")
	TabText.BackgroundTransparency = 1
	TabText.Position = UDim2.fromOffset(TabIcon and 18 or 4, 0)
	TabText.Size = UDim2.new(1, TabIcon and -35 or -16, 1, 0)
	TabText.FontFace = self.Fonts.Body
	TabText.Text = TabTitle
	TabText.TextSize = 12
	TabText.TextColor3 = self.Theme.Text
	TabText.TextXAlignment = Enum.TextXAlignment.Left
	TabText.TextTruncate = Enum.TextTruncate.AtEnd
	TabText.ZIndex = 4
	TabText.Parent = TabButton

	TabButton.MouseEnter:Connect(function()
		if not self.ActiveTab or self.ActiveTab.Button ~= TabButton then
			Tween(TabButton, { BackgroundTransparency = 0.25 })
		end
	end)
	TabButton.MouseLeave:Connect(function()
		if not self.ActiveTab or self.ActiveTab.Button ~= TabButton then
			Tween(TabButton, { BackgroundTransparency = 1 })
		end
	end)

	local Tab = setmetatable({
		Library = self,
		Page = TabPage,
		Title = TabTitle,
		Button = TabButton,
	}, { __index = Wolf })

	table.insert(self.Tabs, Tab)

	local function SelectTab()
		if self._CloseDropdowns then
			self._CloseDropdowns()
		end
		for _, ExistingTab in ipairs(self.Tabs) do
			ExistingTab.Page.Visible = ExistingTab == Tab
			ExistingTab.Button.BackgroundColor3 = ExistingTab == Tab and self.Theme.Accent or self.Theme.Card
			ExistingTab.Button.BackgroundTransparency = ExistingTab == Tab and 0 or 1
		end
		self.ActiveTab = Tab
		self.ContentArea.CanvasPosition = Vector2.new(0, 0)
	end

	TabButton.MouseButton1Click:Connect(SelectTab)

	if not self.ActiveTab then
		SelectTab()
	end

	return Tab
end

function Wolf:AddToggleLegacy(Idx, Config)
	Config = Config or {}
	local Title = Config.Title or Idx
	local Default = Config.Default or false
	local Callback = Config.Callback or function() end

	local State = Default

	local ToggleFrame = Instance.new("Frame")
	ToggleFrame.Size = UDim2.new(1, 0, 0, 36)
	ToggleFrame.BackgroundColor3 = self.Theme.Card
	ToggleFrame.Parent = ElementParent(self, Config)
	Corner(ToggleFrame, 6)
	Stroke(ToggleFrame, self.Theme.Border)

	local Label = Instance.new("TextLabel")
	Label.Position = UDim2.new(0, 12, 0, 0)
	Label.Size = UDim2.new(1, -60, 1, 0)
	Label.BackgroundTransparency = 1
	Label.FontFace = self.Fonts.Body
	Label.Text = Title
	Label.TextColor3 = self.Theme.Text
	Label.TextSize = 12
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.Parent = ToggleFrame

	local Indicator = Instance.new("Frame")
	Indicator.AnchorPoint = Vector2.new(1, 0.5)
	Indicator.Position = UDim2.new(1, -10, 0.5, 0)
	Indicator.Size = UDim2.fromOffset(36, 18)
	Indicator.BackgroundColor3 = State and self.Theme.Accent or self.Theme.Surface
	Indicator.Parent = ToggleFrame
	Corner(Indicator, 5)

	local Knob = Instance.new("Frame")
	Knob.AnchorPoint = Vector2.new(0, 0.5)
	Knob.Position = State and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
	Knob.Size = UDim2.fromOffset(14, 14)
	Knob.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
	Knob.Parent = Indicator
	Corner(Knob, 4)

	local ClickBtn = Instance.new("TextButton")
	ClickBtn.Size = UDim2.new(1, 0, 1, 0)
	ClickBtn.BackgroundTransparency = 1
	ClickBtn.Text = ""
	ClickBtn.Parent = ToggleFrame

	local ToggleObj = {
		Value = State,
		OnChanged = Instance.new("BindableEvent"), -- Fluent-like event listener
	}

	local function Update()
		ToggleObj.Value = State
		Tween(Indicator, { BackgroundColor3 = State and self.Theme.Accent or self.Theme.Surface })
		Tween(Knob, { Position = State and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0, 2, 0.5, 0) })
		Callback(State)
		ToggleObj.OnChanged:Fire(State)
	end

	ClickBtn.MouseButton1Click:Connect(function()
		State = not State
		Update()
	end)

	function ToggleObj:Toggle()
		State = not State
		Update()
	end
	function ToggleObj:Activate()
		self:Toggle()
	end

	function ToggleObj:SetValue(Val)
		State = Val
		Update()
	end
	function ToggleObj:SetShortcutHooked(Hooked)
		Indicator.Position = Hooked and UDim2.new(1, -42, 0.5, 0) or UDim2.new(1, -10, 0.5, 0)
		Label.Size = Hooked and UDim2.new(1, -94, 1, 0) or UDim2.new(1, -60, 1, 0)
	end

	table.insert(self.Library.Elements, { Text = Title, Frame = ToggleFrame })
	return ToggleObj
end

-- AddButton(Idx, Config) or AddButton(Config)
function Wolf:AddButtonLegacy(Config)
	if typeof(Config) == "string" then
		Config = { Title = Config }
	end
	local Title = Config.Title or "Button"
	local Callback = Config.Callback or function() end

	local ButtonFrame = Instance.new("Frame")
	ButtonFrame.Size = UDim2.new(1, 0, 0, 36)
	ButtonFrame.BackgroundColor3 = self.Theme.Card
	ButtonFrame.Parent = ElementParent(self, Config)
	Corner(ButtonFrame, 6)
	Stroke(ButtonFrame, self.Theme.Border)

	local TextBtn = Instance.new("TextButton")
	TextBtn.Size = UDim2.new(1, 0, 1, 0)
	TextBtn.BackgroundTransparency = 1
	TextBtn.FontFace = self.Fonts.Body
	TextBtn.Text = Title
	TextBtn.TextColor3 = self.Theme.Text
	TextBtn.TextSize = 12
	TextBtn.Parent = ButtonFrame

	TextBtn.MouseEnter:Connect(function()
		Tween(ButtonFrame, { BackgroundColor3 = self.Theme.SurfaceHover })
	end)
	TextBtn.MouseLeave:Connect(function()
		Tween(ButtonFrame, { BackgroundColor3 = self.Theme.Card })
	end)
	TextBtn.MouseButton1Click:Connect(function()
		Tween(ButtonFrame, { BackgroundColor3 = self.Theme.Accent }, 0.08)
		task.delay(0.08, function()
			Tween(ButtonFrame, { BackgroundColor3 = self.Theme.SurfaceHover })
		end)
		Callback()
	end)

	table.insert(self.Library.Elements, { Text = Title, Frame = ButtonFrame })
	return ButtonFrame
end

---------------------------------------------------------------------
-- COMPONENT FACTORIES (Elements)
---------------------------------------------------------------------

-- Section Header
function Wolf:AddSection(Title)
	local SectionConfig = typeof(Title) == "table" and Title or { Title = Title }
	local SectionTitle = SectionConfig.Title or SectionConfig.title or "Section"
	local IconName = SectionConfig.Icon or SectionConfig.icon
	local Collapsed = SectionConfig.Collapsed == true
	local SectionFrame = Instance.new("Frame")
	SectionFrame:SetAttribute("WolfSectionTitle", tostring(SectionTitle))
	SectionFrame.Size = UDim2.new(1, 0, 0, 24)
	SectionFrame.AutomaticSize = Enum.AutomaticSize.Y
	SectionFrame.BackgroundColor3 = self.Theme.Card
	SectionFrame.Parent = self.Page
	Corner(SectionFrame, 6)
	Stroke(SectionFrame, self.Theme.Border)

	local SectionLayout = Instance.new("UIListLayout")
	SectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
	SectionLayout.Padding = UDim.new(0, 0)
	SectionLayout.Parent = SectionFrame

	local SectionHeader = Instance.new("TextButton")
	SectionHeader.Name = "SectionHeader"
	SectionHeader.Size = UDim2.new(1, 0, 0, 30)
	SectionHeader.LayoutOrder = 1
	SectionHeader.BackgroundTransparency = 1
	SectionHeader.Text = ""
	SectionHeader.AutoButtonColor = false
	SectionHeader.Parent = SectionFrame

	local Label = Instance.new("TextLabel")
	Label.Position = UDim2.fromOffset(12, 0)
	Label.Size = UDim2.new(1, -42, 1, 0)
	Label.BackgroundTransparency = 1
	Label.FontFace = self.Fonts.Title
	Label.Text = tostring(SectionTitle):upper()
	Label.TextColor3 = self.Theme.Accent
	Label.TextSize = 11
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.Parent = SectionHeader
	if IconName then
		Label.Position = UDim2.fromOffset(36, 0)
		Label.Size = UDim2.new(1, -66, 1, 0)
		CreateIcon(SectionHeader, IconName, UDim2.fromOffset(12, 7), UDim2.fromOffset(16, 16), self.Theme.Accent, 2)
	end

	local Chevron = CreateIcon(
		SectionHeader,
		Collapsed and "chevron-down" or "chevron-up",
		UDim2.new(1, -28, 0.5, 0),
		UDim2.fromOffset(16, 16),
		self.Theme.SubText,
		2
	)
	Chevron.AnchorPoint = Vector2.new(0, 0.5)

	local SectionContent = Instance.new("Frame")
	SectionContent.Name = "SectionContent"
	SectionContent.Size = UDim2.new(1, 0, 0, 0)
	SectionContent.AutomaticSize = Enum.AutomaticSize.Y
	SectionContent.LayoutOrder = 2
	SectionContent.BackgroundTransparency = 1
	SectionContent.Visible = not Collapsed
	SectionContent.Parent = SectionFrame
	Padding(SectionContent, 8, 8, 0, 8)

	local ContentLayout = Instance.new("UIListLayout")
	ContentLayout.Padding = UDim.new(0, 8)
	ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	ContentLayout.Parent = SectionContent

	SectionHeader.MouseButton1Click:Connect(function()
		Collapsed = not Collapsed
		SectionContent.Visible = not Collapsed
		ApplyIcon(Chevron, Collapsed and "chevron-down" or "chevron-up")
	end)

	table.insert(self.Library.Elements, { Text = SectionTitle, Frame = SectionFrame })
	local Section = {
		Library = self,
		Frame = SectionFrame,
		Content = SectionContent,
		Title = tostring(SectionTitle),
	}
	local function SectionConfig(Config)
		if typeof(Config) == "table" then
			local RoutedConfig = table.clone(Config)
			RoutedConfig.Section = Section
			return RoutedConfig
		end
		return { Title = Config, Section = Section }
	end
	local RoutedMethods = {
		"AddButton",
		"AddToggle",
		"AddSlider",
		"AddTextbox",
		"AddRGBColorPickerLegacy",
		"AddColorPicker",
		"AddDropdown",
		"AddMultiDropdown",
	}
	for _, MethodName in ipairs(RoutedMethods) do
		Section[MethodName] = function(_, Config)
			return self[MethodName](self, SectionConfig(Config))
		end
	end
	Section.AddToggleLegacy = function(_, Idx, Config)
		return self:AddToggleLegacy(Idx, SectionConfig(Config))
	end
	self[tostring(SectionTitle)] = Section
	return Section
end

-- Button Component
function Wolf:AddButton(Config)
	Config = typeof(Config) == "table" and Config or { Title = Config }
	local Title = Config.Title or "Button"
	local IconName = Config.Icon or Config.icon
	local Callback = Config.Callback or function() end

	local ButtonFrame = Instance.new("Frame")
	ButtonFrame.Size = UDim2.new(1, 0, 0, 36)
	ButtonFrame.BackgroundColor3 = self.Theme.Card
	ButtonFrame.Parent = ElementParent(self, Config)
	Corner(ButtonFrame, 6)
	Stroke(ButtonFrame, self.Theme.Border)

	local TextBtn = Instance.new("TextButton")
	TextBtn.Size = UDim2.new(1, 0, 1, 0)
	TextBtn.BackgroundTransparency = 1
	TextBtn.FontFace = self.Fonts.Body
	TextBtn.Text = Title
	TextBtn.TextXAlignment = IconName and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
	TextBtn.TextTruncate = Enum.TextTruncate.AtEnd
	TextBtn.TextColor3 = self.Theme.Text
	TextBtn.TextSize = 12
	TextBtn.ZIndex = 1
	TextBtn.Parent = ButtonFrame
	if IconName then
		TextBtn.Position = UDim2.fromOffset(36, 0)
		TextBtn.Size = UDim2.new(1, -48, 1, 0)
		CreateIcon(ButtonFrame, IconName, UDim2.fromOffset(12, 10), UDim2.fromOffset(16, 16), self.Theme.SubText, 2)
	end

	TextBtn.MouseEnter:Connect(function()
		Tween(ButtonFrame, { BackgroundColor3 = self.Theme.SurfaceHover })
	end)
	TextBtn.MouseLeave:Connect(function()
		Tween(ButtonFrame, { BackgroundColor3 = self.Theme.Card })
	end)
	TextBtn.MouseButton1Click:Connect(function()
		Tween(ButtonFrame, { BackgroundColor3 = self.Theme.Accent }, 0.08)
		task.delay(0.08, function()
			Tween(ButtonFrame, { BackgroundColor3 = self.Theme.SurfaceHover })
		end)
		Callback()
	end)

	table.insert(self.Library.Elements, { Text = Title, Frame = ButtonFrame })
	return ButtonFrame
end

-- Toggle Component
function Wolf:AddToggle(Config)
	Config = typeof(Config) == "table" and Config or { Title = Config }
	local Title = Config.Title or "Toggle"
	local IconName = Config.Icon or Config.icon
	local Default = Config.Default or false
	local Callback = Config.Callback or function() end

	local State = Default

	local ToggleFrame = Instance.new("Frame")
	ToggleFrame.Size = UDim2.new(1, 0, 0, 36)
	ToggleFrame.BackgroundColor3 = self.Theme.Card
	ToggleFrame.Parent = ElementParent(self, Config)
	Corner(ToggleFrame, 6)
	Stroke(ToggleFrame, self.Theme.Border)

	local Label = Instance.new("TextLabel")
	Label.Name = "ToggleLabel"
	Label.Position = UDim2.new(0, 12, 0, 0)
	Label.Size = UDim2.new(1, -60, 1, 0)
	Label.BackgroundTransparency = 1
	Label.FontFace = self.Fonts.Body
	Label.Text = Title
	Label.TextColor3 = self.Theme.Text
	Label.TextSize = 12
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.Parent = ToggleFrame
	if IconName then
		Label.Position = UDim2.fromOffset(36, 0)
		Label.Size = UDim2.new(1, -84, 1, 0)
		CreateIcon(ToggleFrame, IconName, UDim2.fromOffset(12, 10), UDim2.fromOffset(16, 16), self.Theme.SubText, 2)
	end

	local Indicator = Instance.new("Frame")
	Indicator.AnchorPoint = Vector2.new(1, 0.5)
	Indicator.Position = UDim2.new(1, -10, 0.5, 0)
	Indicator.Size = UDim2.fromOffset(36, 18)
	Indicator.BackgroundColor3 = State and self.Theme.Accent or self.Theme.Surface
	Indicator.Parent = ToggleFrame
	Corner(Indicator, 5)

	local Knob = Instance.new("Frame")
	Knob.AnchorPoint = Vector2.new(0, 0.5)
	Knob.Position = State and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
	Knob.Size = UDim2.fromOffset(14, 14)
	Knob.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
	Knob.Parent = Indicator
	Corner(Knob, 4)

	local ClickBtn = Instance.new("TextButton")
	ClickBtn.Size = UDim2.new(1, 0, 1, 0)
	ClickBtn.BackgroundTransparency = 1
	ClickBtn.Text = ""
	ClickBtn.Parent = ToggleFrame

	local ToggleObj = {
		Value = State,
		OnChanged = Instance.new("BindableEvent"),
	}

	local function Update()
		ToggleObj.Value = State
		Tween(Indicator, { BackgroundColor3 = State and self.Theme.Accent or self.Theme.Surface })
		Tween(Knob, { Position = State and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0, 2, 0.5, 0) })
		Callback(State)
		ToggleObj.OnChanged:Fire(State)
	end

	ClickBtn.MouseButton1Click:Connect(function()
		State = not State
		Update()
	end)

	function ToggleObj:Toggle()
		State = not State
		Update()
	end
	function ToggleObj:Activate()
		self:Toggle()
	end

	table.insert(self.Library.Elements, { Text = Title, Frame = ToggleFrame })
	return {
		Frame = ToggleFrame,
		Title = Title,
		Toggle = function()
			State = not State
			Update()
		end,
		Activate = function(Self)
			Self:Toggle()
		end,
		SetValue = function(_, Val)
			State = Val
			Update()
		end,
		SetShortcutHooked = function(_, Hooked)
			Indicator.Position = Hooked and UDim2.new(1, -42, 0.5, 0) or UDim2.new(1, -10, 0.5, 0)
			Label.Size = Hooked and UDim2.new(1, -94, 1, 0) or UDim2.new(1, -60, 1, 0)
		end,
	}
end

-- Slider Component
function Wolf:AddSlider(Config)
	local Title = Config.Title or "Slider"
	local IconName = Config.Icon or Config.icon
	local Min = Config.Min or 0
	local Max = Config.Max or 100
	local Default = Config.Default or Min
	local Callback = Config.Callback or function() end

	local SliderFrame = Instance.new("Frame")
	SliderFrame.Size = UDim2.new(1, 0, 0, 50)
	SliderFrame.BackgroundColor3 = self.Theme.Card
	SliderFrame.Parent = ElementParent(self, Config)
	Corner(SliderFrame, 6)
	Stroke(SliderFrame, self.Theme.Border)

	local Label = Instance.new("TextLabel")
	Label.Position = UDim2.new(0, 12, 0, 6)
	Label.Size = UDim2.new(1, -70, 0, 18)
	Label.BackgroundTransparency = 1
	Label.FontFace = self.Fonts.Body
	Label.Text = Title
	Label.TextColor3 = self.Theme.Text
	Label.TextSize = 12
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.Parent = SliderFrame
	if IconName then
		Label.Position = UDim2.fromOffset(36, 6)
		Label.Size = UDim2.new(1, -94, 0, 18)
		CreateIcon(SliderFrame, IconName, UDim2.fromOffset(12, 8), UDim2.fromOffset(16, 16), self.Theme.SubText, 2)
	end

	local ValueLabel = Instance.new("TextLabel")
	ValueLabel.Position = UDim2.new(1, -60, 0, 6)
	ValueLabel.Size = UDim2.new(0, 50, 0, 18)
	ValueLabel.BackgroundTransparency = 1
	ValueLabel.FontFace = self.Fonts.Small
	ValueLabel.Text = tostring(Default)
	ValueLabel.TextColor3 = self.Theme.SubText
	ValueLabel.TextSize = 11
	ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
	ValueLabel.Parent = SliderFrame

	local Track = Instance.new("Frame")
	Track.Position = UDim2.new(0, 12, 0, 32)
	Track.Size = UDim2.new(1, -24, 0, 6)
	Track.BackgroundColor3 = self.Theme.Surface
	Track.Parent = SliderFrame
	Corner(Track, 100)

	local Fill = Instance.new("Frame")
	local Range = math.max(Max - Min, 1)
	Fill.Size = UDim2.new(math.clamp((Default - Min) / Range, 0, 1), 0, 1, 0)
	Fill.BackgroundColor3 = self.Theme.Accent
	Fill.Parent = Track
	Corner(Fill, 100)

	local UserDragging = false

	local function Update(input)
		local Pos = math.clamp((input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
		local Value = math.floor(Min + (Max - Min) * Pos)
		Fill.Size = UDim2.new(Pos, 0, 1, 0)
		ValueLabel.Text = tostring(Value)
		Callback(Value)
	end

	Track.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			UserDragging = true
			Update(input)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			UserDragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if
			UserDragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			Update(input)
		end
	end)

	table.insert(self.Library.Elements, { Text = Title, Frame = SliderFrame })
	return SliderFrame
end

-- Textbox Input Component
function Wolf:AddTextbox(Config)
	local Title = Config.Title or "Input"
	local IconName = Config.Icon or Config.icon
	local Placeholder = Config.Placeholder or "Enter text..."
	local Callback = Config.Callback or function() end

	local InputFrame = Instance.new("Frame")
	InputFrame.Size = UDim2.new(1, 0, 0, 36)
	InputFrame.BackgroundColor3 = self.Theme.Card
	InputFrame.Parent = ElementParent(self, Config)
	Corner(InputFrame, 6)
	Stroke(InputFrame, self.Theme.Border)

	local Label = Instance.new("TextLabel")
	Label.Position = UDim2.new(0, 12, 0, 0)
	Label.Size = UDim2.new(0.5, -12, 1, 0)
	Label.BackgroundTransparency = 1
	Label.FontFace = self.Fonts.Body
	Label.Text = Title
	Label.TextColor3 = self.Theme.Text
	Label.TextSize = 12
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.Parent = InputFrame
	if IconName then
		Label.Position = UDim2.fromOffset(36, 0)
		Label.Size = UDim2.new(0.5, -36, 1, 0)
		CreateIcon(InputFrame, IconName, UDim2.fromOffset(12, 10), UDim2.fromOffset(16, 16), self.Theme.SubText, 2)
	end

	local Box = Instance.new("TextBox")
	Box.AnchorPoint = Vector2.new(1, 0.5)
	Box.Position = UDim2.new(1, -10, 0.5, 0)
	Box.Size = UDim2.new(0.45, 0, 0, 24)
	Box.BackgroundColor3 = self.Theme.Surface
	Box.TextColor3 = self.Theme.Text
	Box.PlaceholderColor3 = self.Theme.SubText
	Box.PlaceholderText = Placeholder
	Box.FontFace = self.Fonts.Small
	Box.TextSize = 11
	Box.Text = ""
	Box.Parent = InputFrame
	Corner(Box, 4)
	Stroke(Box, self.Theme.Border)

	Box.FocusLost:Connect(function(enterPressed)
		Callback(Box.Text, enterPressed)
	end)

	table.insert(self.Library.Elements, { Text = Title, Frame = InputFrame })
	return InputFrame
end

-- Color picker component
function Wolf:AddRGBColorPickerLegacy(Config)
	Config = Config or {}
	local Library = self.Library or self
	local Title = Config.Title or "Color"
	local IconName = Config.Icon or Config.icon or "pipette"
	local Default = typeof(Config.Default) == "Color3" and Config.Default or Color3.fromRGB(255, 0, 0)
	local Callback = Config.Callback or function() end
	local CurrentColor = Default

	local PickerFrame = Instance.new("Frame")
	PickerFrame.Name = "ColorPicker"
	PickerFrame.Size = UDim2.new(1, 0, 0, 36)
	PickerFrame.BackgroundColor3 = self.Theme.Card
	PickerFrame.Parent = ElementParent(self, Config)
	Corner(PickerFrame, 6)
	Stroke(PickerFrame, self.Theme.Border)

	local Label = Instance.new("TextLabel")
	Label.Position = UDim2.fromOffset(36, 0)
	Label.Size = UDim2.new(1, -88, 1, 0)
	Label.BackgroundTransparency = 1
	Label.FontFace = self.Fonts.Body
	Label.Text = Title
	Label.TextColor3 = self.Theme.Text
	Label.TextSize = 12
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.Parent = PickerFrame
	CreateIcon(PickerFrame, IconName, UDim2.fromOffset(12, 10), UDim2.fromOffset(16, 16), self.Theme.SubText, 2)

	local ColorPickerButton = Instance.new("TextButton")
	ColorPickerButton.Name = "ColorPickerButton"
	ColorPickerButton.AnchorPoint = Vector2.new(1, 0.5)
	ColorPickerButton.Position = UDim2.new(1, -10, 0.5, 0)
	ColorPickerButton.Size = UDim2.fromOffset(42, 22)
	ColorPickerButton.BackgroundColor3 = CurrentColor
	ColorPickerButton.Text = ""
	ColorPickerButton.AutoButtonColor = false
	ColorPickerButton.Parent = PickerFrame
	Corner(ColorPickerButton, 4)
	Stroke(ColorPickerButton, self.Theme.Border)

	local Popup = Instance.new("Frame")
	Popup.Name = "ColorPickerPopup"
	Popup.Size = UDim2.fromOffset(220, 122)
	Popup.BackgroundColor3 = self.Theme.Surface
	Popup.Visible = false
	Popup.ZIndex = 150
	Popup.Parent = Library.Gui
	Corner(Popup, 6)
	Stroke(Popup, self.Theme.Border)
	Padding(Popup, 10, 10, 10, 10)

	local Preview = Instance.new("Frame")
	Preview.Size = UDim2.new(1, 0, 0, 24)
	Preview.BackgroundColor3 = CurrentColor
	Preview.ZIndex = 51
	Preview.Parent = Popup
	Corner(Preview, 4)

	local Inputs = {}
	local Channels = { "R", "G", "B" }
	local function ChannelValue(Color, Channel)
		return Color[Channel]
	end
	local function UpdateColor()
		local Values = {}
		for Index, Input in ipairs(Inputs) do
			Values[Index] = math.clamp(tonumber(Input.Text) or 0, 0, 255)
			Input.Text = tostring(Values[Index])
		end
		CurrentColor = Color3.fromRGB(Values[1], Values[2], Values[3])
		ColorPickerButton.BackgroundColor3 = CurrentColor
		Preview.BackgroundColor3 = CurrentColor
		Callback(CurrentColor)
	end

	for Index, Channel in ipairs(Channels) do
		local Input = Instance.new("TextBox")
		Input.Position = UDim2.new((Index - 1) / 3, (Index - 1) * 4, 0, 34)
		Input.Size = UDim2.new(1 / 3, -8, 0, 26)
		Input.BackgroundColor3 = self.Theme.Card
		Input.TextColor3 = self.Theme.Text
		Input.PlaceholderText = Channel
		Input.Text = tostring(math.floor(ChannelValue(Default, Channel) * 255 + 0.5))
		Input.FontFace = self.Fonts.Small
		Input.TextSize = 11
		Input.ClearTextOnFocus = false
		Input.ZIndex = 51
		Input.Parent = Popup
		Corner(Input, 4)
		Stroke(Input, self.Theme.Border)
		Inputs[Index] = Input
		Input.FocusLost:Connect(UpdateColor)
	end

	ColorPickerButton.MouseButton1Click:Connect(function()
		local WasVisible = Popup.Visible
		if Library._CloseDropdowns then
			Library._CloseDropdowns()
		end
		Popup.Visible = not WasVisible
		if Popup.Visible then
			table.insert(Library.OpenDropdowns, {
				Frame = Popup,
				Chevron = PickerFrame:FindFirstChild("Icon"),
				ClosedIcon = IconName,
				Anchor = ColorPickerButton,
			})
			Library._UpdateDropdownPositions()
		end
	end)

	table.insert(Library.Elements, { Text = Title, Frame = PickerFrame })
	return {
		SetValue = function(_, Value)
			if typeof(Value) == "Color3" then
				CurrentColor = Value
				for Index, Channel in ipairs(Channels) do
					Inputs[Index].Text = tostring(math.floor(ChannelValue(Value, Channel) * 255 + 0.5))
				end
				UpdateColor()
			end
		end,
		Value = CurrentColor,
	}
end

function Wolf:AddColorPicker(Config)
	Config = Config or {}
	local Library = self.Library or self
	local Title = Config.Title or "Color"
	local IconName = Config.Icon or Config.icon or "pipette"
	local Default = typeof(Config.Default) == "Color3" and Config.Default or Color3.fromRGB(255, 0, 0)
	local Callback = Config.Callback or function() end
	local H, S, V = Default:ToHSV()
	local A = Config.Alpha == nil and 1 or math.clamp(Config.Alpha, 0, 1)

	local PickerFrame = Instance.new("Frame")
	PickerFrame.Name = "ColorPicker"
	PickerFrame.Size = UDim2.new(1, 0, 0, 36)
	PickerFrame.BackgroundColor3 = self.Theme.Card
	PickerFrame.Parent = ElementParent(self, Config)
	Corner(PickerFrame, 6)
	Stroke(PickerFrame, self.Theme.Border)

	local Label = Instance.new("TextLabel")
	Label.Position = UDim2.fromOffset(36, 0)
	Label.Size = UDim2.new(1, -88, 1, 0)
	Label.BackgroundTransparency = 1
	Label.FontFace = self.Fonts.Body
	Label.Text = Title
	Label.TextColor3 = self.Theme.Text
	Label.TextSize = 12
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.Parent = PickerFrame
	CreateIcon(PickerFrame, IconName, UDim2.fromOffset(12, 10), UDim2.fromOffset(16, 16), self.Theme.SubText, 2)

	local ColorPickerButton = Instance.new("TextButton")
	ColorPickerButton.Name = "ColorPickerButton"
	ColorPickerButton.AnchorPoint = Vector2.new(1, 0.5)
	ColorPickerButton.Position = UDim2.new(1, -10, 0.5, 0)
	ColorPickerButton.Size = UDim2.fromOffset(42, 22)
	ColorPickerButton.BackgroundColor3 = Default
	ColorPickerButton.Text = ""
	ColorPickerButton.AutoButtonColor = false
	ColorPickerButton.Parent = PickerFrame
	Corner(ColorPickerButton, 4)
	Stroke(ColorPickerButton, self.Theme.Border)

	local Popup = Instance.new("Frame")
	Popup.Name = "ColorPickerPopup"
	Popup.Size = UDim2.fromOffset(260, 220)
	Popup.BackgroundTransparency = 1
	Popup.BorderSizePixel = 0
	Popup.Visible = false
	Popup.ZIndex = 150
	Popup.Parent = Library.Gui

	local MainContainer = Instance.new("Frame")
	MainContainer.Size = UDim2.fromOffset(260, 220)
	MainContainer.BackgroundColor3 = self.Theme.Background
	MainContainer.BackgroundTransparency = 0.35
	MainContainer.BorderSizePixel = 0
	MainContainer.Active = true
	MainContainer.ClipsDescendants = false
	MainContainer.ZIndex = 150
	MainContainer.Parent = Popup
	Corner(MainContainer, 12)
	Stroke(MainContainer, self.Theme.Text, 0.85)
	Padding(MainContainer, 8, 8, 8, 8)

	local Layout = Instance.new("UIListLayout")
	Layout.SortOrder = Enum.SortOrder.LayoutOrder
	Layout.Padding = UDim.new(0, 8)
	Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	Layout.Parent = MainContainer

	local function NewBar(Name, Height)
		local Bar = Instance.new("Frame")
		Bar.Name = Name
		Bar.Size = UDim2.new(1, 0, 0, Height)
		Bar.BorderSizePixel = 0
		Bar.ClipsDescendants = false
		Bar.ZIndex = 51
		Bar.Parent = MainContainer
		Corner(Bar, 6)
		return Bar
	end

	local SatValBox = NewBar("SaturationValue", 110)
	SatValBox.BackgroundColor3 = Color3.new(1, 1, 1)
	local SatGradient = Instance.new("UIGradient")
	SatGradient.Parent = SatValBox
	local ValOverlay = Instance.new("Frame")
	ValOverlay.Size = UDim2.fromScale(1, 1)
	ValOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
	ValOverlay.BorderSizePixel = 0
	ValOverlay.ClipsDescendants = true
	ValOverlay.ZIndex = 52
	ValOverlay.Parent = SatValBox
	Corner(ValOverlay, 6)
	local ValGradient = Instance.new("UIGradient")
	ValGradient.Rotation = 90
	ValGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	ValGradient.Parent = ValOverlay

	local SVCursor = Instance.new("Frame")
	SVCursor.Size = UDim2.fromOffset(14, 14)
	SVCursor.AnchorPoint = Vector2.new(0.5, 0.5)
	SVCursor.BackgroundTransparency = 1
	SVCursor.BorderSizePixel = 0
	SVCursor.ZIndex = 55
	SVCursor.Parent = ValOverlay
	Corner(SVCursor, 4)
	Stroke(SVCursor, Color3.new(1, 1, 1), 0)

	local HueBar = NewBar("Hue", 14)
	local HueGradient = Instance.new("UIGradient")
	HueGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
		ColorSequenceKeypoint.new(0.16, Color3.fromRGB(255, 255, 0)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(0, 0, 255)),
		ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
	})
	HueGradient.Parent = HueBar

	local HueCursor = Instance.new("Frame")
	HueCursor.Size = UDim2.fromOffset(10, 20)
	HueCursor.AnchorPoint = Vector2.new(0.5, 0.5)
	HueCursor.BackgroundTransparency = 1
	HueCursor.BorderSizePixel = 0
	HueCursor.ZIndex = 55
	HueCursor.Parent = HueBar
	Corner(HueCursor, 4)
	Stroke(HueCursor, Color3.new(1, 1, 1), 0)

	local AlphaBar = NewBar("Alpha", 14)
	local AlphaCanvas = Instance.new("Frame")
	AlphaCanvas.Size = UDim2.fromScale(1, 1)
	AlphaCanvas.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	AlphaCanvas.BorderSizePixel = 0
	AlphaCanvas.ZIndex = 51
	AlphaCanvas.Parent = AlphaBar
	Corner(AlphaCanvas, 6)
	local CheckerFrame = Instance.new("Frame")
	CheckerFrame.Size = UDim2.fromScale(1, 1)
	CheckerFrame.BackgroundTransparency = 1
	CheckerFrame.ZIndex = 51
	CheckerFrame.Parent = AlphaCanvas
	local Grid = Instance.new("UIGridLayout")
	Grid.CellSize = UDim2.new(1 / 30, 0, 0.5, 0)
	Grid.CellPadding = UDim2.fromOffset(0, 0)
	Grid.Parent = CheckerFrame
	for Row = 1, 2 do
		for Column = 1, 30 do
			local Tile = Instance.new("Frame")
			Tile.BorderSizePixel = 0
			Tile.BackgroundColor3 = (Row + Column) % 2 == 0 and Color3.fromRGB(220, 220, 220)
				or Color3.fromRGB(80, 80, 80)
			Tile.BackgroundTransparency = 0.35
			Tile.Parent = CheckerFrame
		end
	end
	local AlphaOverlay = Instance.new("Frame")
	AlphaOverlay.Size = UDim2.fromScale(1, 1)
	AlphaOverlay.BackgroundColor3 = Color3.new(1, 1, 1)
	AlphaOverlay.BorderSizePixel = 0
	AlphaOverlay.ClipsDescendants = true
	AlphaOverlay.ZIndex = 52
	AlphaOverlay.Parent = AlphaCanvas
	local AlphaGradient = Instance.new("UIGradient")
	AlphaGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.85),
		NumberSequenceKeypoint.new(1, 0),
	})
	AlphaGradient.Parent = AlphaOverlay

	local AlphaCursor = Instance.new("Frame")
	AlphaCursor.Size = UDim2.fromOffset(10, 20)
	AlphaCursor.AnchorPoint = Vector2.new(0.5, 0.5)
	AlphaCursor.BackgroundTransparency = 1
	AlphaCursor.BorderSizePixel = 0
	AlphaCursor.ZIndex = 55
	AlphaCursor.Parent = AlphaBar
	Corner(AlphaCursor, 4)
	Stroke(AlphaCursor, Color3.new(1, 1, 1), 0)

	local Footer = Instance.new("Frame")
	Footer.Size = UDim2.new(1, 0, 0, 32)
	Footer.BackgroundTransparency = 1
	Footer.LayoutOrder = 4
	Footer.ZIndex = 51
	Footer.Parent = MainContainer
	local HexBox = Instance.new("Frame")
	HexBox.Size = UDim2.new(1, -40, 1, 0)
	HexBox.BackgroundColor3 = self.Theme.Card
	HexBox.BackgroundTransparency = 0.3
	HexBox.ZIndex = 52
	HexBox.Parent = Footer
	Corner(HexBox, 6)
	Stroke(HexBox, self.Theme.Border)

	local ColorPreview = Instance.new("Frame")
	ColorPreview.Size = UDim2.fromOffset(20, 20)
	ColorPreview.Position = UDim2.new(0, 6, 0.5, -10)
	ColorPreview.BackgroundColor3 = Default
	ColorPreview.BorderSizePixel = 0
	ColorPreview.ZIndex = 53
	ColorPreview.Parent = HexBox
	Corner(ColorPreview, 4)

	local HexInput = Instance.new("TextBox")
	HexInput.Size = UDim2.new(0.5, -30, 1, 0)
	HexInput.Position = UDim2.new(0, 32, 0, 0)
	HexInput.BackgroundTransparency = 1
	HexInput.TextColor3 = self.Theme.Text
	HexInput.FontFace = self.Fonts.Small
	HexInput.TextSize = 11
	HexInput.TextXAlignment = Enum.TextXAlignment.Left
	HexInput.ClearTextOnFocus = false
	HexInput.ZIndex = 53
	HexInput.Parent = HexBox
	local FooterDivider = Instance.new("TextLabel")
	FooterDivider.Position = UDim2.new(0.58, 0, 0, 0)
	FooterDivider.Size = UDim2.new(0, 12, 1, 0)
	FooterDivider.BackgroundTransparency = 1
	FooterDivider.Text = "|"
	FooterDivider.TextColor3 = self.Theme.SubText
	FooterDivider.TextTransparency = 0.25
	FooterDivider.FontFace = self.Fonts.Small
	FooterDivider.TextSize = 11
	FooterDivider.TextXAlignment = Enum.TextXAlignment.Center
	FooterDivider.ZIndex = 54
	FooterDivider.Parent = HexBox
	local AlphaInput = Instance.new("TextBox")
	AlphaInput.Size = UDim2.new(0.4, -1, 1, 0)
	AlphaInput.Position = UDim2.new(0.6, 1, 0, 0)
	AlphaInput.BackgroundColor3 = self.Theme.Card
	AlphaInput.BackgroundTransparency = 0.3
	AlphaInput.TextColor3 = self.Theme.Text
	AlphaInput.FontFace = self.Fonts.Small
	AlphaInput.TextSize = 10
	AlphaInput.TextXAlignment = Enum.TextXAlignment.Center
	AlphaInput.ClearTextOnFocus = false
	AlphaInput.ZIndex = 53
	AlphaInput.Parent = HexBox
	Corner(AlphaInput, 6)
	Stroke(AlphaInput, self.Theme.Border)

	local PipetteButton = Instance.new("ImageButton")
	PipetteButton.AnchorPoint = Vector2.new(1, 0)
	PipetteButton.Position = UDim2.new(1, 0, 0, 0)
	PipetteButton.Size = UDim2.fromOffset(32, 32)
	PipetteButton.BackgroundColor3 = self.Theme.Card
	PipetteButton.BackgroundTransparency = 0.3
	PipetteButton.AutoButtonColor = false
	PipetteButton.ZIndex = 54
	PipetteButton.Parent = Footer
	Corner(PipetteButton, 6)
	Stroke(PipetteButton, self.Theme.Border)
	ApplyIcon(PipetteButton, "pipette")
	PipetteButton.ImageColor3 = self.Theme.Text

	local CurrentColor = Default
	local function UpdateUI(SkipText)
		CurrentColor = Color3.fromHSV(H, S, V)
		SatGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(H, 1, 1)),
		})
		AlphaGradient.Color = ColorSequence.new(CurrentColor)
		SVCursor.Position = UDim2.new(S, 0, 1 - V, 0)
		HueCursor.Position = UDim2.new(H, 0, 0.5, 0)
		AlphaCursor.Position = UDim2.new(A, 0, 0.5, 0)
		ColorPickerButton.BackgroundColor3 = CurrentColor
		ColorPreview.BackgroundColor3 = CurrentColor
		ColorPreview.BackgroundTransparency = 1 - A
		if not SkipText then
			HexInput.Text = "#" .. CurrentColor:ToHex():upper()
			AlphaInput.Text = tostring(math.round(A * 100)) .. "%"
		end
	end

	local ActiveSlider
	local function BindSlider(Frame, Update)
		Frame.InputBegan:Connect(function(Input)
			if
				Input.UserInputType == Enum.UserInputType.MouseButton1
				or Input.UserInputType == Enum.UserInputType.Touch
			then
				ActiveSlider = Update
				Update(Input)
			end
		end)
	end
	BindSlider(SatValBox, function(Input)
		local Size = SatValBox.AbsoluteSize
		local Position = SatValBox.AbsolutePosition
		S = math.clamp((Input.Position.X - Position.X) / Size.X, 0, 1)
		V = math.clamp(1 - (Input.Position.Y - Position.Y) / Size.Y, 0, 1)
		UpdateUI(false)
	end)
	BindSlider(HueBar, function(Input)
		H = math.clamp((Input.Position.X - HueBar.AbsolutePosition.X) / HueBar.AbsoluteSize.X, 0, 1)
		UpdateUI(false)
	end)
	BindSlider(AlphaBar, function(Input)
		A = math.clamp((Input.Position.X - AlphaBar.AbsolutePosition.X) / AlphaBar.AbsoluteSize.X, 0, 1)
		UpdateUI(false)
	end)
	UserInputService.InputChanged:Connect(function(Input)
		if
			ActiveSlider
			and (
				Input.UserInputType == Enum.UserInputType.MouseMovement
				or Input.UserInputType == Enum.UserInputType.Touch
			)
		then
			ActiveSlider(Input)
		end
	end)
	UserInputService.InputEnded:Connect(function(Input)
		if
			Input.UserInputType == Enum.UserInputType.MouseButton1
			or Input.UserInputType == Enum.UserInputType.Touch
		then
			ActiveSlider = nil
		end
	end)

	HexInput.FocusLost:Connect(function()
		local Success, Parsed = pcall(Color3.fromHex, HexInput.Text:gsub("#", ""))
		if Success and Parsed then
			H, S, V = Parsed:ToHSV()
		end
		UpdateUI(false)
	end)
	AlphaInput.FocusLost:Connect(function()
		local Value = tonumber(AlphaInput.Text:match("%d+"))
		if Value then
			A = math.clamp(Value / 100, 0, 1)
		end
		UpdateUI(false)
	end)

	ColorPickerButton.MouseButton1Click:Connect(function()
		local WasVisible = Popup.Visible
		if Library._CloseDropdowns then
			Library._CloseDropdowns()
		end
		Popup.Visible = not WasVisible
		if Popup.Visible then
			table.insert(Library.OpenDropdowns, { Frame = Popup, Anchor = ColorPickerButton })
			Library._UpdateDropdownPositions()
		end
	end)

	PipetteButton.MouseButton1Click:Connect(function()
		ColorPickerButton.BackgroundColor3 = CurrentColor
		Callback(CurrentColor, A)
		Popup.Visible = false
		table.clear(Library.OpenDropdowns)
	end)

	UpdateUI(false)
	table.insert(Library.Elements, { Text = Title, Frame = PickerFrame })
	local PickerObject = {
		Frame = PickerFrame,
		Popup = Popup,
		Title = Title,
		SetValue = function(_, Value, Alpha)
			if typeof(Value) == "Color3" then
				H, S, V = Value:ToHSV()
				if Alpha ~= nil then
					A = math.clamp(Alpha, 0, 1)
				end
				UpdateUI(false)
			end
		end,
		Value = CurrentColor,
		GetValue = function()
			return CurrentColor, A
		end,
	}
	function PickerObject:Open()
		if Library._CloseDropdowns then
			Library._CloseDropdowns()
		end
		Popup.Visible = true
		table.insert(Library.OpenDropdowns, { Frame = Popup, Anchor = ColorPickerButton })
		Library._UpdateDropdownPositions()
	end
	function PickerObject:Close()
		Popup.Visible = false
		table.clear(Library.OpenDropdowns)
	end
	function PickerObject:Toggle()
		if Popup.Visible then
			self:Close()
		else
			self:Open()
		end
	end
	function PickerObject:Activate()
		ColorPickerButton.BackgroundColor3 = CurrentColor
		Callback(CurrentColor, A)
		Popup.Visible = false
		table.clear(Library.OpenDropdowns)
	end
	return PickerObject
end

function Wolf:AddShortcut(Config)
	Config = Config or {}
	local Side = tostring(Config.Side or Config.Type or "S1"):upper()
	local IsToggleShortcut = Side == "S2"
	if Side ~= "S1" and Side ~= "S2" then
		Side = "S1"
		IsToggleShortcut = false
	end
	self.ShortcutSideCounts[Side] = (self.ShortcutSideCounts[Side] or 0) + 1
	local SideIndex = self.ShortcutSideCounts[Side]
	local ActionElement = Config.Element1 or Config.Element or Config.Target
	local Element = Config.Element2 or ActionElement
	local Callback = Config.Callback
	local function NormalizeElement(Value)
		if not Value then
			return nil
		end
		if typeof(Value) == "table" and Value.Frame then
			return Value
		end
		if typeof(Value) == "Instance" and Value:IsA("GuiObject") then
			return { Frame = Value }
		end
		return nil
	end
	ActionElement = NormalizeElement(ActionElement)
	Element = NormalizeElement(Element)
	if not ActionElement or not ActionElement.Frame or not Element or not Element.Frame then
		return nil
	end
	if ActionElement.SetShortcutHooked then
		ActionElement:SetShortcutHooked(true)
	end

	if not self.ShortcutHolder then
		local ShortcutGui = Instance.new("ScreenGui")
		ShortcutGui.Name = "WolfUIShortcuts"
		ShortcutGui.ResetOnSpawn = false
		ShortcutGui.DisplayOrder = 101
		ShortcutGui.Parent = self.Gui.Parent
		self.ShortcutGui = ShortcutGui

		local Holder = Instance.new("Frame")
		Holder.Name = "Shortcuts"
		Holder.Position = UDim2.fromScale(0, 0)
		Holder.Size = UDim2.fromScale(1, 1)
		Holder.BackgroundTransparency = 1
		Holder.ZIndex = 100
		Holder.ClipsDescendants = false
		Holder.Visible = self._UIVisible ~= false
		Holder.Parent = ShortcutGui

		self.ShortcutHolder = Holder
	end

	local ShortcutText = Config.Text or Config.text or Config.Title or ""
	local ShortcutIconName = Config.Icon or Config.icon
	local DefaultShortcutWidth = ShortcutText == "" and (ShortcutIconName and 34 or 86)
		or math.max(110, string.len(ShortcutText) * 7 + 42)
	local ShortcutWidth = Config.Width or DefaultShortcutWidth
	local ShortcutHeight = Config.Height or 34
	local Button = Instance.new("TextButton")
	Button.Name = IsToggleShortcut and "S2Btn" or "S1Btn"
	self.ShortcutCount = self.ShortcutCount + 1
	Button.Size = UDim2.fromOffset(ShortcutWidth, ShortcutHeight)
	Button.AnchorPoint = Vector2.new(1, 0)
	Button.Position = UDim2.new(1, 0, 0, (self.ShortcutCount - 1) * 42)
	Button.BackgroundColor3 = self.Theme.Card
	Button.BackgroundTransparency = 0.15
	Button.BorderSizePixel = 0
	Button.AutoButtonColor = false
	Button.Active = true
	Button.Selectable = true
	Button.Text = ""
	Button.TextColor3 = self.Theme.Text
	Button.FontFace = self.Fonts.Button
	Button.TextSize = 11
	Button.TextXAlignment = Enum.TextXAlignment.Center
	Button.TextTransparency = 1
	Button.ZIndex = 101
	Button.Parent = self.ShortcutHolder
	Button.Visible = false
	Button.AnchorPoint = Vector2.new(0, 0)
	table.insert(self.ShortcutButtons, Button)
	Corner(Button, 6)
	Stroke(Button, self.Theme.Border, 0.35)

	if ShortcutIconName then
		local ShortcutIcon =
			CreateIcon(Button, ShortcutIconName, UDim2.fromOffset(8, 9), UDim2.fromOffset(16, 16), self.Theme.Text, 102)
		if ShortcutText == "" then
			ShortcutIcon.Position = UDim2.fromScale(0.5, 0.5)
			ShortcutIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		else
			local ShortcutLabel = Instance.new("TextLabel")
			ShortcutLabel.BackgroundTransparency = 1
			ShortcutLabel.Position = UDim2.fromOffset(30, 0)
			ShortcutLabel.Size = UDim2.new(1, -38, 1, 0)
			ShortcutLabel.FontFace = self.Fonts.Button
			ShortcutLabel.Text = ShortcutText
			ShortcutLabel.TextColor3 = self.Theme.Text
			ShortcutLabel.TextSize = 11
			ShortcutLabel.TextXAlignment = Enum.TextXAlignment.Left
			ShortcutLabel.TextTruncate = Enum.TextTruncate.AtEnd
			ShortcutLabel.ZIndex = 103
			ShortcutLabel.Parent = Button
		end
	else
		local ShortcutLabel = Instance.new("TextLabel")
		ShortcutLabel.BackgroundTransparency = 1
		ShortcutLabel.Size = UDim2.fromScale(1, 1)
		ShortcutLabel.FontFace = self.Fonts.Button
		ShortcutLabel.Text = ShortcutText
		ShortcutLabel.TextColor3 = self.Theme.Text
		ShortcutLabel.TextSize = 11
		ShortcutLabel.TextXAlignment = Enum.TextXAlignment.Center
		ShortcutLabel.TextTruncate = Enum.TextTruncate.AtEnd
		ShortcutLabel.ZIndex = 103
		ShortcutLabel.Parent = Button
	end

	local ChevronButton
	local Chevron
	if IsToggleShortcut then
		ChevronButton = Instance.new("ImageButton")
		ChevronButton.Name = "S2Chevron"
		ChevronButton.Size = UDim2.fromOffset(22, ShortcutHeight)
		ChevronButton.BackgroundColor3 = self.Theme.Card
		ChevronButton.BackgroundTransparency = 0.05
		ChevronButton.BorderSizePixel = 0
		ChevronButton.AutoButtonColor = false
		ChevronButton.ZIndex = 104
		ChevronButton.Visible = false
		ChevronButton.Parent = self.ShortcutHolder
		Corner(ChevronButton, 6)
		Stroke(ChevronButton, self.Theme.Border, 0.25)
		Chevron = CreateIcon(
			ChevronButton,
			"chevron-right",
			UDim2.fromScale(0.5, 0.5),
			UDim2.fromOffset(16, 16),
			self.Theme.SubText,
			105
		)
		Chevron.AnchorPoint = Vector2.new(0.5, 0.5)
		table.insert(self.ShortcutChevrons, ChevronButton)
	end

	local DropdownSelection = Element.Frame:FindFirstChild("DropdownSelection", true)
	local ColorPickerControl = Element.Frame:FindFirstChild("ColorPickerButton", true)
	local ColorPickerPopup = ColorPickerControl and Element.Popup
	local TextBoxControl = Element.Frame:FindFirstChildWhichIsA("TextBox", true)
	local HookSource = DropdownSelection and DropdownSelection or ColorPickerPopup or TextBoxControl and TextBoxControl
	local IsColorPickerHook = HookSource == ColorPickerPopup
	local TriggerParent = DropdownSelection and DropdownSelection:FindFirstAncestorWhichIsA("TextButton") or Element.Frame
	local TriggerSlot = ActionElement.Frame:GetAttribute("WolfShortcutTriggerCount") or 0
	ActionElement.Frame:SetAttribute("WolfShortcutTriggerCount", TriggerSlot + 1)
	local HookClone
	local HookExpanded = false
	local HookSize = Vector2.new(0, 0)
	if IsToggleShortcut then
		if HookSource then
			HookClone = IsColorPickerHook and HookSource or HookSource:Clone()
			HookClone.Name = "S2HookedSelection"
			HookClone.AnchorPoint = Vector2.zero
			HookClone.Visible = false
			HookClone.ZIndex = 150
			if not IsColorPickerHook then
				HookClone.Parent = self.ShortcutGui
			end
			for _, Descendant in ipairs(HookClone:GetDescendants()) do
				if Descendant:IsA("GuiObject") then
					Descendant.ZIndex = 151
				end
			end
		end
		if Element.Popup then
			Element.Popup.Parent = self.ShortcutGui
		end
	end
	local TriggerButton = Instance.new("ImageButton")
	TriggerButton.Name = Side .. "Trigger"
	TriggerButton.Size = UDim2.fromOffset(26, 26)
	TriggerButton.BackgroundColor3 = self.Theme.Card
	TriggerButton.BackgroundTransparency = 0.1
	TriggerButton.BorderSizePixel = 0
	TriggerButton.AutoButtonColor = false
	TriggerButton.Active = true
	TriggerButton.ZIndex = 155
	TriggerButton.Parent = TriggerParent
	Corner(TriggerButton, 6)
	Stroke(TriggerButton, self.Theme.Border, 0.2)
	local TriggerIcon = CreateIcon(
		TriggerButton,
		"plug-zap",
		UDim2.fromScale(0.5, 0.5),
		UDim2.fromOffset(16, 16),
		self.Theme.Accent,
		111
	)
	TriggerIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	table.insert(self.ShortcutTriggers, TriggerButton)

	local function ReserveTriggerSpace()
		local Control = ActionElement.Frame:FindFirstChild("Indicator", true)
			or ActionElement.Frame:FindFirstChild("Box", true)
			or ActionElement.Frame:FindFirstChild("DropdownSelection", true)
			or ActionElement.Frame:FindFirstChild("ColorPickerButton", true)
		if Control and Control:IsA("GuiObject") then
			Control.AnchorPoint = Vector2.new(1, Control.AnchorPoint.Y)
			Control.Position = UDim2.new(1, -42 - TriggerSlot * 32, Control.Position.Y.Scale, Control.Position.Y.Offset)
		end
		local ToggleLabel = ActionElement.Frame:FindFirstChild("ToggleLabel", true)
		if ToggleLabel and ToggleLabel:IsA("TextLabel") then
			ToggleLabel.Size = UDim2.new(1, -94 - TriggerSlot * 32, ToggleLabel.Size.Y.Scale, ToggleLabel.Size.Y.Offset)
		end
	end
	ReserveTriggerSpace()

	local ShortcutOffset = Vector2.new(0, 0)
	local DragStartOffset = Vector2.new(0, 0)
	local function ClampShortcutPosition(Position, Size)
		local WindowSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		return Vector2.new(
			math.clamp(Position.X, 8, math.max(8, WindowSize.X - Size.X - 8)),
			math.clamp(Position.Y, 8, math.max(8, WindowSize.Y - Size.Y - 8))
		)
	end

	local function UpdateShortcutPosition(UseTargetPosition)
		if not ActionElement or not ActionElement.Frame or not ActionElement.Frame.Parent then
			return
		end
		local ElementPosition = ActionElement.Frame.AbsolutePosition
		if HookSource and HookSource.AbsoluteSize.X > 0 and HookSource.AbsoluteSize.Y > 0 then
			HookSize = HookSource.AbsoluteSize
		end
		local TotalWidth = Button.AbsoluteSize.X
			+ (ChevronButton and ChevronButton.AbsoluteSize.X + 4 or 0)
			+ (HookClone and not IsColorPickerHook and HookSize.X + 4 or 0)
		if UseTargetPosition then
			local ShortcutPosition = ClampShortcutPosition(
				ElementPosition - Vector2.new(TotalWidth + 10, 0),
				Vector2.new(TotalWidth, Button.AbsoluteSize.Y)
			)
			Button.Position = UDim2.fromOffset(ShortcutPosition.X, ShortcutPosition.Y)
			if ChevronButton then
				ChevronButton.Position =
					UDim2.fromOffset(ShortcutPosition.X + Button.AbsoluteSize.X + 4, ShortcutPosition.Y)
			end
		else
			local ShortcutPosition =
				ClampShortcutPosition(Button.AbsolutePosition, Vector2.new(TotalWidth, Button.AbsoluteSize.Y))
			Button.Position = UDim2.fromOffset(ShortcutPosition.X, ShortcutPosition.Y)
			if ChevronButton then
				ChevronButton.Position =
					UDim2.fromOffset(ShortcutPosition.X + Button.AbsoluteSize.X + 4, ShortcutPosition.Y)
			end
		end
	end

	if IsToggleShortcut then
		task.defer(function()
			UpdateShortcutPosition(true)
		end)
	else
		Button.Position = UDim2.fromOffset(
			math.max(
				8,
				(workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X or 1280)
					- Button.AbsoluteSize.X
					- 18
			),
			8 + (self.ShortcutCount - 1) * 42
		)
	end

	local function UpdateTriggerPosition()
		if not ActionElement or not ActionElement.Frame or not ActionElement.Frame.Parent then
			return
		end
		local TriggerOffsetX = TriggerSlot * 32
		local TriggerOffsetY = 0
		TriggerButton.AnchorPoint = Vector2.new(1, 0.5)
		TriggerButton.Position = UDim2.new(1, -6 - TriggerOffsetX, 0.5, 0)
		if HookClone and ChevronButton.Visible then
			local ChevronPosition = ChevronButton.AbsolutePosition
			local ChevronSize = ChevronButton.AbsoluteSize
			if HookSize.X == 0 or HookSize.Y == 0 then
				HookSize = HookClone.AbsoluteSize
			end
			HookClone.Size = UDim2.fromOffset(HookSize.X, HookSize.Y)
			local CloneSize = HookClone.AbsoluteSize
			if IsColorPickerHook then
				HookClone.Position = UDim2.fromOffset(ChevronPosition.X, ChevronPosition.Y + ChevronSize.Y + 8)
			else
				HookClone.Position = UDim2.fromOffset(
					ChevronPosition.X + ChevronSize.X + 4,
					ChevronPosition.Y + (ChevronSize.Y - CloneSize.Y) / 2
				)
			end
			HookClone.Visible = HookExpanded
			if DropdownSelection then
				local SourceValue = HookSource:FindFirstChildWhichIsA("TextLabel", true)
				local CloneValue = HookClone:FindFirstChildWhichIsA("TextLabel", true)
				if SourceValue and CloneValue then
					CloneValue.Text = SourceValue.Text
				end
			elseif HookSource:IsA("GuiButton") then
				HookClone.BackgroundColor3 = HookSource.BackgroundColor3
				local SourceKnob = HookSource:FindFirstChildWhichIsA("GuiObject", true)
				local CloneKnob = HookClone:FindFirstChildWhichIsA("GuiObject", true)
				if SourceKnob and CloneKnob then
					CloneKnob.Position = SourceKnob.Position
				end
			elseif HookSource:IsA("TextBox") then
				HookClone.Text = HookSource.Text
			end
		elseif HookClone then
			HookClone.Visible = false
		end
	end
	UpdateTriggerPosition()
	table.insert(self._ShortcutConnections, RunService.RenderStepped:Connect(UpdateTriggerPosition))

	local Dragging = false
	local DragMoved = false
	local DragStart
	local DragStartPosition
	local DragInput
	local function BeginShortcutDrag(Input)
		if
			Input.UserInputType == Enum.UserInputType.MouseButton1
			or Input.UserInputType == Enum.UserInputType.Touch
		then
			Dragging = true
			DragMoved = false
			DragInput = nil
			DragStart = Vector2.new(Input.Position.X, Input.Position.Y)
			DragStartOffset = ShortcutOffset
			DragStartPosition = Button.AbsolutePosition
		end
	end
	Button.InputBegan:Connect(BeginShortcutDrag)
	Button.InputChanged:Connect(function(Input)
		if
			Input.UserInputType == Enum.UserInputType.MouseMovement
			or Input.UserInputType == Enum.UserInputType.Touch
		then
			DragInput = Input
		end
	end)
	if ChevronButton then
		ChevronButton.InputBegan:Connect(BeginShortcutDrag)
		ChevronButton.InputChanged:Connect(function(Input)
			if
				Input.UserInputType == Enum.UserInputType.MouseMovement
				or Input.UserInputType == Enum.UserInputType.Touch
			then
				DragInput = Input
			end
		end)
	end
	table.insert(
		self._ShortcutConnections,
		UserInputService.InputChanged:Connect(function(Input)
			if
				Dragging
				and Input == DragInput
				and (
					Input.UserInputType == Enum.UserInputType.MouseMovement
					or Input.UserInputType == Enum.UserInputType.Touch
				)
			then
				local PointerPosition = Vector2.new(Input.Position.X, Input.Position.Y)
				local Delta = PointerPosition - DragStart
				DragMoved = DragMoved or Delta.Magnitude > 6
				if not DragMoved then
					return
				end
				if IsToggleShortcut then
					ShortcutOffset = DragStartOffset + Delta
					local GroupWidth = Button.AbsoluteSize.X
						+ ChevronButton.AbsoluteSize.X
						+ 4
						+ (HookClone and not IsColorPickerHook and HookSize.X + 4 or 0)
					local Position =
						ClampShortcutPosition(DragStartPosition + Delta, Vector2.new(GroupWidth, Button.AbsoluteSize.Y))
					Button.Position = UDim2.fromOffset(Position.X, Position.Y)
					ChevronButton.Position = UDim2.fromOffset(Position.X + Button.AbsoluteSize.X + 4, Position.Y)
					return
				end
				local Position = ClampShortcutPosition(DragStartPosition + Delta, Button.AbsoluteSize)
				Button.Position = UDim2.fromOffset(Position.X, Position.Y)
			end
		end)
	)
	table.insert(
		self._ShortcutConnections,
		UserInputService.InputEnded:Connect(function(Input)
			if
				Input.UserInputType == Enum.UserInputType.MouseButton1
				or Input.UserInputType == Enum.UserInputType.Touch
			then
				Dragging = false
				DragInput = nil
			end
		end)
	)

	local function ActivateShortcut()
		if ActionElement and ActionElement.Activate then
			ActionElement:Activate()
		elseif ActionElement and ActionElement.Toggle then
			ActionElement:Toggle()
		elseif ActionElement and ActionElement.Frame then
			local ActionButton = ActionElement.Frame:FindFirstChildWhichIsA("GuiButton", true)
			local ActionTextBox = ActionElement.Frame:FindFirstChildWhichIsA("TextBox", true)
			if ActionButton then
				ActionButton:Activate()
			elseif ActionTextBox then
				ActionTextBox:CaptureFocus()
			end
		elseif HookSource and HookSource:IsA("TextBox") then
			HookSource:CaptureFocus()
		elseif Callback then
			Callback(ActionElement)
		end
	end

	local function ToggleSelectionFrame()
		if not Element or not Element.Popup then
			return
		end
		if Element.Popup.Visible then
			Element.Popup.Visible = false
			table.clear(self.OpenDropdowns)
			ApplyIcon(Chevron, HookExpanded and "chevron-left" or "chevron-right")
		else
			if self._CloseDropdowns then
				self._CloseDropdowns()
			end
			Element.Popup.Visible = true
			table.insert(self.OpenDropdowns, {
				Frame = Element.Popup,
				Anchor = HookClone or ChevronButton,
				Chevron = Chevron,
				ClosedIcon = HookExpanded and "chevron-left" or "chevron-right",
			})
			self._UpdateDropdownPositions()
			ApplyIcon(Chevron, HookExpanded and "chevron-left" or "chevron-right")
		end
	end
	local function ToggleHookClone()
		if not HookClone or not ChevronButton then
			return
		end
		HookExpanded = not HookExpanded
		if IsColorPickerHook then
			Element.Popup.Visible = HookExpanded
		end
		if not HookExpanded and Element.Popup then
			Element.Popup.Visible = false
			table.clear(self.OpenDropdowns)
		end
		ApplyIcon(Chevron, HookExpanded and "chevron-left" or "chevron-right")
	end
	if HookClone and not IsColorPickerHook then
		local SelectionButton = Instance.new("TextButton")
		SelectionButton.Name = "S2SelectionButton"
		SelectionButton.Size = UDim2.fromScale(1, 1)
		SelectionButton.BackgroundTransparency = 1
		SelectionButton.Text = ""
		SelectionButton.AutoButtonColor = false
		SelectionButton.ZIndex = 152
		SelectionButton.Parent = HookClone
		SelectionButton.MouseButton1Click:Connect(function()
			if Element.Popup then
				ToggleSelectionFrame()
			else
				ActivateShortcut()
			end
		end)
	end

	Button.MouseButton1Click:Connect(function()
		if not DragMoved then
			ActivateShortcut()
		end
	end)
	if ChevronButton and not HookClone then
		ChevronButton.MouseButton1Click:Connect(function()
			if not DragMoved then
				ToggleSelectionFrame()
			end
		end)
	elseif ChevronButton then
		ChevronButton.MouseButton1Click:Connect(function()
			if not DragMoved then
				ToggleHookClone()
			end
		end)
	end

	TriggerButton.MouseButton1Click:Connect(function()
		local ShowShortcut = not Button.Visible
		if ShowShortcut then
			UpdateShortcutPosition(true)
		end
		Button.Visible = ShowShortcut
		if ChevronButton then
			ChevronButton.Visible = ShowShortcut
		end
		if not ShowShortcut then
			HookExpanded = false
			if ChevronButton then
				ApplyIcon(Chevron, "chevron-right")
			end
		end
		if not ShowShortcut and Element and Element.Popup then
			Element.Popup.Visible = false
			table.clear(self.OpenDropdowns)
		end
	end)

	return Button
end

-- Single-selection dropdown
function Wolf:AddDropdown(Config)
	Config = Config or {}
	local Library = self.Library or self
	local Title = Config.Title or "Select"
	local IconName = Config.Icon or Config.icon
	local Options = Config.Options or Config.Values or {}
	local Callback = Config.Callback or function() end
	local Selected = Config.Default

	local DropdownFrame = Instance.new("Frame")
	DropdownFrame.Name = "Dropdown"
	DropdownFrame.Size = UDim2.new(1, 0, 0, 0)
	DropdownFrame.AutomaticSize = Enum.AutomaticSize.Y
	DropdownFrame.BackgroundColor3 = self.Theme.Card
	DropdownFrame.Parent = ElementParent(self, Config)
	Corner(DropdownFrame, 6)
	Stroke(DropdownFrame, self.Theme.Border)

	local DropdownLayout = Instance.new("UIListLayout")
	DropdownLayout.SortOrder = Enum.SortOrder.LayoutOrder
	DropdownLayout.Padding = UDim.new(0, 0)
	DropdownLayout.Parent = DropdownFrame

	local DropdownButton = Instance.new("TextButton")
	DropdownButton.Size = UDim2.new(1, 0, 0, 40)
	DropdownButton.BackgroundTransparency = 1
	DropdownButton.Text = ""
	DropdownButton.AutoButtonColor = false
	DropdownButton.Parent = DropdownFrame

	local Label = Instance.new("TextLabel")
	Label.Position = UDim2.fromOffset(12, 0)
	Label.Size = UDim2.new(0.45, -12, 1, 0)
	Label.BackgroundTransparency = 1
	Label.FontFace = self.Fonts.Body
	Label.Text = Title
	Label.TextColor3 = self.Theme.Text
	Label.TextSize = 12
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.Parent = DropdownButton

	local ValueLabel = Instance.new("TextLabel")
	ValueLabel.Position = UDim2.new(0.45, 0, 0, 0)
	ValueLabel.Size = UDim2.new(0.55, -36, 1, 0)
	ValueLabel.BackgroundTransparency = 1
	ValueLabel.FontFace = self.Fonts.Small
	ValueLabel.TextColor3 = self.Theme.SubText
	ValueLabel.TextSize = 11
	ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
	ValueLabel.TextTruncate = Enum.TextTruncate.AtEnd
	ValueLabel.Parent = DropdownButton

	if IconName then
		Label.Position = UDim2.fromOffset(36, 0)
		Label.Size = UDim2.new(0.45, -36, 1, 0)
		CreateIcon(DropdownButton, IconName, UDim2.fromOffset(12, 12), UDim2.fromOffset(16, 16), self.Theme.SubText, 2)
	end

	local Chevron = CreateIcon(
		DropdownButton,
		"chevron-down",
		UDim2.new(1, -26, 0.5, 0),
		UDim2.fromOffset(16, 16),
		self.Theme.SubText,
		2
	)
	Chevron.AnchorPoint = Vector2.new(0, 0.5)

	local SelectionFrame = Instance.new("Frame")
	SelectionFrame.Name = "DropdownSelection"
	SelectionFrame.AnchorPoint = Vector2.new(1, 0.5)
	SelectionFrame.Position = UDim2.new(1, -10, 0.5, 0)
	SelectionFrame.Size = UDim2.new(0.45, 0, 0, 30)
	SelectionFrame.BackgroundColor3 = self.Theme.Surface
	SelectionFrame.BackgroundTransparency = 0.15
	SelectionFrame.BorderSizePixel = 0
	SelectionFrame.ZIndex = 2
	SelectionFrame.Parent = DropdownButton
	Corner(SelectionFrame, 4)
	Stroke(SelectionFrame, self.Theme.Border, 0.2)
	ValueLabel.Parent = SelectionFrame
	ValueLabel.Position = UDim2.fromOffset(8, 0)
	ValueLabel.Size = UDim2.new(1, -34, 1, 0)
	Chevron.Parent = SelectionFrame
	Chevron.Position = UDim2.new(1, -26, 0.5, 0)

	local OptionsFrame = Instance.new("ScrollingFrame")
	OptionsFrame.Name = "DropdownSelectionFrame"
	OptionsFrame.Size = UDim2.fromOffset(220, 140)
	OptionsFrame.CanvasSize = UDim2.new()
	OptionsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	OptionsFrame.BackgroundColor3 = self.Theme.Surface
	OptionsFrame.BackgroundTransparency = 0.18
	OptionsFrame.BorderSizePixel = 0
	OptionsFrame.ScrollBarThickness = 3
	OptionsFrame.ScrollBarImageColor3 = self.Theme.Accent
	OptionsFrame.Visible = false
	OptionsFrame.ZIndex = 50
	OptionsFrame.Parent = Library.Gui
	Corner(OptionsFrame, 6)
	Stroke(OptionsFrame, self.Theme.Accent, 0.15)
	Padding(OptionsFrame, 8, 8, 0, 8)

	local OptionsLayout = Instance.new("UIListLayout")
	OptionsLayout.Padding = UDim.new(0, 4)
	OptionsLayout.Parent = OptionsFrame

	local function OptionData(Option)
		if typeof(Option) == "table" then
			return tostring(Option.Title or Option.Name or Option.Value), Option.Value or Option.Title or Option.Name
		end
		return tostring(Option), Option
	end

	local OptionIcons = {}
	local function UpdateValue(Value)
		Selected = Value
		ValueLabel.Text = Value == nil and "Select..." or tostring(Value)
		for OptionValue, OptionIcon in pairs(OptionIcons) do
			OptionIcon.Visible = OptionValue == Selected
		end
		Callback(Value)
	end

	for _, Option in ipairs(Options) do
		local OptionTitle, OptionValue = OptionData(Option)
		local OptionButton = Instance.new("TextButton")
		OptionButton.Size = UDim2.new(1, 0, 0, 28)
		OptionButton.BackgroundColor3 = self.Theme.Surface
		OptionButton.Text = ""
		OptionButton.TextColor3 = self.Theme.Text
		OptionButton.FontFace = self.Fonts.Small
		OptionButton.TextSize = 11
		OptionButton.TextXAlignment = Enum.TextXAlignment.Left
		OptionButton.ZIndex = 51
		OptionButton.Parent = OptionsFrame
		Padding(OptionButton, 10, 8, 0, 0)
		Corner(OptionButton, 4)
		local OptionIcon =
			CreateIcon(OptionButton, "check", UDim2.fromOffset(8, 6), UDim2.fromOffset(16, 16), self.Theme.Accent, 52)
		OptionIcon.Visible = OptionValue == Selected
		OptionIcons[OptionValue] = OptionIcon
		local OptionText = Instance.new("TextLabel")
		OptionText.BackgroundTransparency = 1
		OptionText.Position = UDim2.fromOffset(30, 0)
		OptionText.Size = UDim2.new(1, -34, 1, 0)
		OptionText.FontFace = self.Fonts.Small
		OptionText.Text = OptionTitle
		OptionText.TextColor3 = self.Theme.Text
		OptionText.TextSize = 11
		OptionText.TextXAlignment = Enum.TextXAlignment.Left
		OptionText.ZIndex = 52
		OptionText.Parent = OptionButton
		OptionButton.MouseButton1Click:Connect(function()
			UpdateValue(OptionValue)
			OptionIcon.Visible = true
			for _, Sibling in ipairs(OptionsFrame:GetChildren()) do
				if Sibling:IsA("TextButton") and Sibling ~= OptionButton then
					local SiblingIcon = Sibling:FindFirstChild("Icon")
					if SiblingIcon then
						SiblingIcon.Visible = false
					end
				end
			end
			OptionsFrame.Visible = false
			table.clear(Library.OpenDropdowns)
			ApplyIcon(Chevron, "chevron-down")
		end)
	end

	ValueLabel.Text = Selected == nil and "Select..." or tostring(Selected)
	DropdownButton.MouseButton1Click:Connect(function()
		local WasVisible = OptionsFrame.Visible
		if Library._CloseDropdowns then
			Library._CloseDropdowns()
		end
		OptionsFrame.Visible = not WasVisible
		if OptionsFrame.Visible then
			table.insert(Library.OpenDropdowns, { Frame = OptionsFrame, Chevron = Chevron, Anchor = SelectionFrame })
			Library._UpdateDropdownPositions()
		end
		ApplyIcon(Chevron, OptionsFrame.Visible and "chevron-up" or "chevron-down")
	end)

	table.insert(Library.Elements, { Text = Title, Frame = DropdownFrame })
	local DropdownObject = {
		Frame = DropdownFrame,
		Popup = OptionsFrame,
		Title = Title,
		SetValue = function(_, Value)
			UpdateValue(Value)
		end,
		Value = Selected,
		GetValue = function()
			return Selected
		end,
	}
	function DropdownObject:Open()
		Library._CloseDropdowns()
		OptionsFrame.Visible = true
		table.insert(Library.OpenDropdowns, { Frame = OptionsFrame, Chevron = Chevron, Anchor = SelectionFrame })
		Library._UpdateDropdownPositions()
		ApplyIcon(Chevron, "chevron-up")
	end
	function DropdownObject:Close()
		OptionsFrame.Visible = false
		Library._CloseDropdowns()
	end
	function DropdownObject:Toggle()
		if OptionsFrame.Visible then
			self:Close()
		else
			self:Open()
		end
	end
	function DropdownObject:Activate()
		self:Toggle()
	end
	DropdownObject.Library = Library
	return DropdownObject
end

-- Multi-selection dropdown
function Wolf:AddMultiDropdown(Config)
	Config = Config or {}
	local Library = self.Library or self
	local Title = Config.Title or "Select multiple"
	local IconName = Config.Icon or Config.icon
	local Options = Config.Options or Config.Values or {}
	local Callback = Config.Callback or function() end
	local Selected = {}
	for _, Value in ipairs(Config.Default or {}) do
		Selected[Value] = true
	end

	local DropdownFrame = Instance.new("Frame")
	DropdownFrame.Name = "MultiDropdown"
	DropdownFrame.Size = UDim2.new(1, 0, 0, 0)
	DropdownFrame.AutomaticSize = Enum.AutomaticSize.Y
	DropdownFrame.BackgroundColor3 = self.Theme.Card
	DropdownFrame.Parent = ElementParent(self, Config)
	Corner(DropdownFrame, 6)
	Stroke(DropdownFrame, self.Theme.Border)

	local DropdownLayout = Instance.new("UIListLayout")
	DropdownLayout.SortOrder = Enum.SortOrder.LayoutOrder
	DropdownLayout.Padding = UDim.new(0, 0)
	DropdownLayout.Parent = DropdownFrame

	local DropdownButton = Instance.new("TextButton")
	DropdownButton.Size = UDim2.new(1, 0, 0, 40)
	DropdownButton.BackgroundTransparency = 1
	DropdownButton.Text = ""
	DropdownButton.AutoButtonColor = false
	DropdownButton.Parent = DropdownFrame

	local Label = Instance.new("TextLabel")
	Label.Position = UDim2.fromOffset(12, 0)
	Label.Size = UDim2.new(0.45, -12, 1, 0)
	Label.BackgroundTransparency = 1
	Label.FontFace = self.Fonts.Body
	Label.Text = Title
	Label.TextColor3 = self.Theme.Text
	Label.TextSize = 12
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.Parent = DropdownButton
	if IconName then
		Label.Position = UDim2.fromOffset(36, 0)
		Label.Size = UDim2.new(0.45, -36, 1, 0)
		CreateIcon(DropdownButton, IconName, UDim2.fromOffset(12, 12), UDim2.fromOffset(16, 16), self.Theme.SubText, 2)
	end

	local ValueLabel = Instance.new("TextLabel")
	ValueLabel.Position = UDim2.new(0.45, 0, 0, 0)
	ValueLabel.Size = UDim2.new(0.55, -36, 1, 0)
	ValueLabel.BackgroundTransparency = 1
	ValueLabel.FontFace = self.Fonts.Small
	ValueLabel.TextColor3 = self.Theme.SubText
	ValueLabel.TextSize = 11
	ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
	ValueLabel.TextTruncate = Enum.TextTruncate.AtEnd
	ValueLabel.Parent = DropdownButton

	local Chevron = CreateIcon(
		DropdownButton,
		"chevron-down",
		UDim2.new(1, -26, 0.5, 0),
		UDim2.fromOffset(16, 16),
		self.Theme.SubText,
		2
	)

	Chevron.AnchorPoint = Vector2.new(0, 0.5)

	local SelectionFrame = Instance.new("Frame")
	SelectionFrame.Name = "DropdownSelection"
	SelectionFrame.AnchorPoint = Vector2.new(1, 0.5)
	SelectionFrame.Position = UDim2.new(1, -10, 0.5, 0)
	SelectionFrame.Size = UDim2.new(0.45, 0, 0, 30)
	SelectionFrame.BackgroundColor3 = self.Theme.Surface
	SelectionFrame.BackgroundTransparency = 0.15
	SelectionFrame.BorderSizePixel = 0
	SelectionFrame.ZIndex = 2
	SelectionFrame.Parent = DropdownButton
	Corner(SelectionFrame, 4)
	Stroke(SelectionFrame, self.Theme.Border, 0.2)
	ValueLabel.Parent = SelectionFrame
	ValueLabel.Position = UDim2.fromOffset(8, 0)
	ValueLabel.Size = UDim2.new(1, -34, 1, 0)
	Chevron.Parent = SelectionFrame
	Chevron.Position = UDim2.new(1, -26, 0.5, 0)

	local OptionsFrame = Instance.new("ScrollingFrame")
	OptionsFrame.Name = "DropdownSelectionFrame"
	OptionsFrame.Size = UDim2.fromOffset(220, 140)
	OptionsFrame.CanvasSize = UDim2.new()
	OptionsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	OptionsFrame.BackgroundColor3 = self.Theme.Surface
	OptionsFrame.BackgroundTransparency = 0.18
	OptionsFrame.BorderSizePixel = 0
	OptionsFrame.ScrollBarThickness = 3
	OptionsFrame.ScrollBarImageColor3 = self.Theme.Accent
	OptionsFrame.Visible = false
	OptionsFrame.ZIndex = 50
	OptionsFrame.Parent = Library.Gui
	Corner(OptionsFrame, 6)
	Stroke(OptionsFrame, self.Theme.Accent, 0.15)
	Padding(OptionsFrame, 8, 8, 0, 8)

	local OptionsLayout = Instance.new("UIListLayout")
	OptionsLayout.Padding = UDim.new(0, 4)
	OptionsLayout.Parent = OptionsFrame

	local function OptionData(Option)
		if typeof(Option) == "table" then
			return tostring(Option.Title or Option.Name or Option.Value), Option.Value or Option.Title or Option.Name
		end
		return tostring(Option), Option
	end

	local OptionIcons = {}
	local function UpdateValueLabel()
		local Values = {}
		for _, Option in ipairs(Options) do
			local OptionTitle, OptionValue = OptionData(Option)
			if Selected[OptionValue] then
				table.insert(Values, OptionTitle)
			end
		end
		ValueLabel.Text = #Values == 0 and "None" or table.concat(Values, ", ")
		for OptionValue, OptionIcon in pairs(OptionIcons) do
			ApplyIcon(OptionIcon, Selected[OptionValue] and "square-check" or "square")
			OptionIcon.ImageColor3 = Selected[OptionValue] and self.Theme.Accent or self.Theme.SubText
		end
	end

	for _, Option in ipairs(Options) do
		local OptionTitle, OptionValue = OptionData(Option)
		local OptionButton = Instance.new("TextButton")
		OptionButton.Size = UDim2.new(1, 0, 0, 28)
		OptionButton.BackgroundColor3 = self.Theme.Surface
		OptionButton.Text = ""
		OptionButton.TextColor3 = self.Theme.Text
		OptionButton.FontFace = self.Fonts.Small
		OptionButton.TextSize = 11
		OptionButton.TextXAlignment = Enum.TextXAlignment.Left
		OptionButton.ZIndex = 51
		OptionButton.Parent = OptionsFrame
		Padding(OptionButton, 10, 8, 0, 0)
		Corner(OptionButton, 4)
		local OptionIcon = CreateIcon(
			OptionButton,
			Selected[OptionValue] and "square-check" or "square",
			UDim2.fromOffset(8, 6),
			UDim2.fromOffset(16, 16),
			Selected[OptionValue] and self.Theme.Accent or self.Theme.SubText,
			52
		)
		OptionIcons[OptionValue] = OptionIcon
		local OptionText = Instance.new("TextLabel")
		OptionText.BackgroundTransparency = 1
		OptionText.Position = UDim2.fromOffset(30, 0)
		OptionText.Size = UDim2.new(1, -34, 1, 0)
		OptionText.FontFace = self.Fonts.Small
		OptionText.Text = OptionTitle
		OptionText.TextColor3 = self.Theme.Text
		OptionText.TextSize = 11
		OptionText.TextXAlignment = Enum.TextXAlignment.Left
		OptionText.ZIndex = 52
		OptionText.Parent = OptionButton
		OptionButton.MouseButton1Click:Connect(function()
			Selected[OptionValue] = not Selected[OptionValue]
			UpdateValueLabel()
			Callback(Selected)
		end)
	end

	UpdateValueLabel()
	DropdownButton.MouseButton1Click:Connect(function()
		local WasVisible = OptionsFrame.Visible
		if Library._CloseDropdowns then
			Library._CloseDropdowns()
		end
		OptionsFrame.Visible = not WasVisible
		if OptionsFrame.Visible then
			table.insert(Library.OpenDropdowns, { Frame = OptionsFrame, Chevron = Chevron, Anchor = SelectionFrame })
			Library._UpdateDropdownPositions()
		end
		ApplyIcon(Chevron, OptionsFrame.Visible and "chevron-up" or "chevron-down")
	end)

	table.insert(Library.Elements, { Text = Title, Frame = DropdownFrame })
	local DropdownObject = {
		Frame = DropdownFrame,
		Popup = OptionsFrame,
		Title = Title,
		SetValue = function(_, Values)
			Selected = {}
			for _, Value in ipairs(Values or {}) do
				Selected[Value] = true
			end
			UpdateValueLabel()
			Callback(Selected)
		end,
		Value = Selected,
		GetValue = function()
			return Selected
		end,
	}
	function DropdownObject:Open()
		Library._CloseDropdowns()
		OptionsFrame.Visible = true
		table.insert(Library.OpenDropdowns, { Frame = OptionsFrame, Chevron = Chevron, Anchor = SelectionFrame })
		Library._UpdateDropdownPositions()
		ApplyIcon(Chevron, "chevron-up")
	end
	function DropdownObject:Close()
		OptionsFrame.Visible = false
		Library._CloseDropdowns()
	end
	function DropdownObject:Toggle()
		if OptionsFrame.Visible then
			self:Close()
		else
			self:Open()
		end
	end
	function DropdownObject:Activate()
		self:Toggle()
	end
	DropdownObject.Library = Library
	return DropdownObject
end

function Wolf:Notify(Config)
	Config = typeof(Config) == "table" and Config or { Content = tostring(Config) }
	local Holder = self.NotificationHolder
	if not Holder then
		Holder = Instance.new("Frame")
		Holder.Name = "Notifications"
		Holder.AnchorPoint = Vector2.new(1, 0)
		Holder.Position = UDim2.new(1, -16, 0, 16)
		Holder.Size = UDim2.fromOffset(280, 0)
		Holder.AutomaticSize = Enum.AutomaticSize.Y
		Holder.BackgroundTransparency = 1
		Holder.ZIndex = 80
		Holder.Parent = self.Gui

		local Layout = Instance.new("UIListLayout")
		Layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		Layout.Padding = UDim.new(0, 8)
		Layout.Parent = Holder
		self.NotificationHolder = Holder
	end

	local Toast = Instance.new("Frame")
	Toast.Size = UDim2.fromOffset(260, 64)
	Toast.BackgroundColor3 = self.Theme.Card
	Toast.BackgroundTransparency = 0.06
	Toast.BorderSizePixel = 0
	Toast.ZIndex = 81
	Toast.Parent = Holder
	Corner(Toast, 6)
	Stroke(Toast, self.Theme.Border)

	local Icon = CreateIcon(
		Toast,
		Config.Icon or "bell",
		UDim2.fromOffset(12, 12),
		UDim2.fromOffset(18, 18),
		self.Theme.Accent,
		82
	)
	local Title = Instance.new("TextLabel")
	Title.BackgroundTransparency = 1
	Title.Position = UDim2.fromOffset(38, 8)
	Title.Size = UDim2.new(1, -50, 0, 18)
	Title.FontFace = self.Fonts.Button
	Title.Text = Config.Title or "Wolf UI"
	Title.TextColor3 = self.Theme.Text
	Title.TextSize = 12
	Title.TextXAlignment = Enum.TextXAlignment.Left
	Title.ZIndex = 82
	Title.Parent = Toast

	local Content = Instance.new("TextLabel")
	Content.BackgroundTransparency = 1
	Content.Position = UDim2.fromOffset(38, 28)
	Content.Size = UDim2.new(1, -50, 0, 28)
	Content.FontFace = self.Fonts.Small
	Content.Text = Config.Content or Config.Message or ""
	Content.TextColor3 = self.Theme.SubText
	Content.TextSize = 11
	Content.TextWrapped = true
	Content.TextXAlignment = Enum.TextXAlignment.Left
	Content.ZIndex = 82
	Content.Parent = Toast

	Toast.Position = UDim2.fromOffset(300, 0)
	Tween(Toast, { Position = UDim2.fromOffset(0, 0) }, 0.22)
	local Duration = Config.Duration or 3
	task.delay(Duration, function()
		if Toast.Parent then
			Tween(Toast, { BackgroundTransparency = 1, Position = UDim2.fromOffset(300, 0) }, 0.2)
			task.delay(0.22, function()
				if Toast.Parent then
					Toast:Destroy()
				end
			end)
		end
	end)
	return Toast
end

return Wolf
