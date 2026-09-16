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

local Lucide = pcall(function()
	return loadstring(
		game:HttpGet("https://raw.githubusercontent.com/SOUSHI45099/Assets/refs/heads/main/LucideRoblox.lua")
	)()
end) and loadstring(
	game:HttpGet("https://raw.githubusercontent.com/SOUSHI45099/Assets/refs/heads/main/LucideRoblox.lua")
)() or nil

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
	Body = Font.fromName("Code", Enum.FontWeight.Medium),
	Small = Font.fromName("Code", Enum.FontWeight.Regular),
	Button = Font.fromName("Code", Enum.FontWeight.Bold),
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

local function ElementParent(Tab)
	return Tab.CurrentSectionContent or Tab.Page
end

---------------------------------------------------------------------
-- WINDOW CREATION
---------------------------------------------------------------------

function Wolf:CreateWindow(Config)
	Config = Config or {}
	self.OpenDropdowns = {}

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

	local WolfUI = Instance.new("ScreenGui")
	WolfUI.Name = "WolfUI"
	WolfUI.ResetOnSpawn = false
	WolfUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	WolfUI.Parent = ParentContainer

	local MainFrame = Instance.new("Frame")
	MainFrame.Name = "MainFrame"
	MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	MainFrame.Position = UDim2.fromScale(0.5, 0.5)
	MainFrame.Size = UDim2.fromOffset(720, 460)
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

	local DeviceIcon = Instance.new("ImageLabel")
	DeviceIcon.Position = UDim2.new(1, -40, 0, 80)
	DeviceIcon.Size = UDim2.fromOffset(24, 24)
	DeviceIcon.BackgroundTransparency = 1
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
	ToggleButton.AnchorPoint = Vector2.new(0, 1)
	ToggleButton.Position = UDim2.new(0, 18, 1, -18)
	ToggleButton.Size = UDim2.fromOffset(46, 46)
	ToggleButton.BackgroundColor3 = self.Theme.Card
	ToggleButton.BackgroundTransparency = 0.08
	ToggleButton.AutoButtonColor = false
	ToggleButton.Image = "rbxthumb://type=Asset&id=112381138279003&w=150&h=150"
	ToggleButton.ImageColor3 = self.Theme.Text
	ToggleButton.ZIndex = 100
	ToggleButton.Parent = ToggleGui
	Corner(ToggleButton, 8)
	Stroke(ToggleButton, self.Theme.Border)

	local uiVisible = true
	local TargetWindowSize = UDim2.fromOffset(720, 460)
	local function SetUIVisible(Visible)
		uiVisible = Visible
		if Visible then
			MainFrame.Visible = true
			MainFrame.Size = UDim2.fromOffset(0, 0)
			MainFrame.BackgroundTransparency = 1
			Tween(MainFrame, { Size = TargetWindowSize, BackgroundTransparency = 0.05 }, 0.28)
		else
			if self._CloseDropdowns then
				self._CloseDropdowns()
			end
			Tween(MainFrame, { Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 }, 0.22)
			task.delay(0.24, function()
				if not uiVisible then
					MainFrame.Visible = false
				end
			end)
		end
	end

	ToggleButton.MouseButton1Click:Connect(function()
		SetUIVisible(not uiVisible)
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
	local MinSize = Vector2.new(500, 320)
	-- Maximum allowed window dimensions
	local MaxSize = Vector2.new(1000, 700)

	local SidebarWidth = 190
	local SidebarMinWidth = 140
	local SidebarMaxWidth = 300
	local SidebarRatio = SidebarWidth / 720

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

	local function CloseDropdowns()
		for _, Dropdown in ipairs(self.OpenDropdowns) do
			Dropdown.Frame.Visible = false
			ApplyIcon(Dropdown.Chevron, "chevron-down")
		end
		table.clear(self.OpenDropdowns)
	end
	self._CloseDropdowns = CloseDropdowns

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
			SidebarWidth = math.clamp(NewWidth * SidebarRatio, SidebarMinWidth, SidebarMaxWidth)

			MainFrame.Size = UDim2.fromOffset(NewWidth, NewHeight)
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
	TabButton.TextColor3 = self.Theme.Text
	TabButton.FontFace = self.Fonts.Body
	TabButton.Text = ""
	TabButton.TextSize = 12
	TabButton.ZIndex = 2
	TabButton.Parent = self.TabContainer
	Corner(TabButton, 6)
	Stroke(TabButton, self.Theme.Border)
	Padding(TabButton, TabIcon and 32 or 12, 8, 0, 0)
	CreateIcon(TabButton, TabIcon, UDim2.fromOffset(6, 10), UDim2.fromOffset(14, 14), self.Theme.Text, 3)
	local TabText = Instance.new("TextLabel")
	TabText.BackgroundTransparency = 1
	TabText.Position = UDim2.fromOffset(TabIcon and 31 or 12, 0)
	TabText.Size = UDim2.new(1, TabIcon and -39 or -20, 1, 0)
	TabText.FontFace = self.Fonts.Body
	TabText.Text = TabTitle
	TabText.TextSize = 12
	TabText.TextColor3 = self.Theme.Text
	TabText.TextXAlignment = Enum.TextXAlignment.Left
	TabText.TextTruncate = Enum.TextTruncate.AtEnd
	TabText.ZIndex = 4
	TabText.Parent = TabButton

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

function Wolf:AddToggle(Idx, Config)
	Config = Config or {}
	local Title = Config.Title or Idx
	local Default = Config.Default or false
	local Callback = Config.Callback or function() end

	local State = Default

	local ToggleFrame = Instance.new("Frame")
	ToggleFrame.Size = UDim2.new(1, 0, 0, 36)
	ToggleFrame.BackgroundColor3 = self.Theme.Card
	ToggleFrame.Parent = ElementParent(self)
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

	function ToggleObj:SetValue(Val)
		State = Val
		Update()
	end

	table.insert(self.Library.Elements, { Text = Title, Frame = ToggleFrame })
	return ToggleObj
end

-- AddButton(Idx, Config) or AddButton(Config)
function Wolf:AddButton(Config)
	if typeof(Config) == "string" then
		Config = { Title = Config }
	end
	local Title = Config.Title or "Button"
	local Callback = Config.Callback or function() end

	local ButtonFrame = Instance.new("Frame")
	ButtonFrame.Size = UDim2.new(1, 0, 0, 36)
	ButtonFrame.BackgroundColor3 = self.Theme.Card
	ButtonFrame.Parent = ElementParent(self)
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

	self.CurrentSectionContent = SectionContent

	table.insert(self.Library.Elements, { Text = SectionTitle, Frame = SectionFrame })
	return SectionFrame
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
	ButtonFrame.Parent = ElementParent(self)
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
	ToggleFrame.Parent = ElementParent(self)
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

	local function Update()
		Tween(Indicator, { BackgroundColor3 = State and self.Theme.Accent or self.Theme.Surface })
		Tween(Knob, { Position = State and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0, 2, 0.5, 0) })
		Callback(State)
	end

	ClickBtn.MouseButton1Click:Connect(function()
		State = not State
		Update()
	end)

	table.insert(self.Library.Elements, { Text = Title, Frame = ToggleFrame })
	return {
		SetValue = function(_, Val)
			State = Val
			Update()
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
	SliderFrame.Parent = ElementParent(self)
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
	Fill.Size = UDim2.new((Default - Min) / (Max - Min), 0, 1, 0)
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
	InputFrame.Parent = ElementParent(self)
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

-- Single-selection dropdown
function Wolf:AddDropdown(Config)
	Config = Config or {}
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
	DropdownFrame.Parent = ElementParent(self)
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

	local OptionsFrame = Instance.new("ScrollingFrame")
	OptionsFrame.Name = "Options"
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
	OptionsFrame.Parent = self.Library.Gui
	Corner(OptionsFrame, 6)
	Stroke(OptionsFrame, self.Theme.Border)
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
			table.clear(self.OpenDropdowns)
			ApplyIcon(Chevron, "chevron-down")
		end)
	end

	ValueLabel.Text = Selected == nil and "Select..." or tostring(Selected)
	DropdownButton.MouseButton1Click:Connect(function()
		local WasVisible = OptionsFrame.Visible
		if self._CloseDropdowns then
			self._CloseDropdowns()
		end
		OptionsFrame.Visible = not WasVisible
		OptionsFrame.Position = UDim2.fromOffset(
			DropdownButton.AbsolutePosition.X,
			DropdownButton.AbsolutePosition.Y + DropdownButton.AbsoluteSize.Y + 4
		)
		if OptionsFrame.Visible then
			table.insert(self.OpenDropdowns, { Frame = OptionsFrame, Chevron = Chevron })
		end
		ApplyIcon(Chevron, OptionsFrame.Visible and "chevron-up" or "chevron-down")
	end)

	table.insert(self.Library.Elements, { Text = Title, Frame = DropdownFrame })
	return {
		SetValue = function(_, Value)
			UpdateValue(Value)
		end,
		Value = Selected,
	}
end

-- Multi-selection dropdown
function Wolf:AddMultiDropdown(Config)
	Config = Config or {}
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
	DropdownFrame.Parent = ElementParent(self)
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

	local OptionsFrame = Instance.new("ScrollingFrame")
	OptionsFrame.Name = "Options"
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
	OptionsFrame.Parent = self.Library.Gui
	Corner(OptionsFrame, 6)
	Stroke(OptionsFrame, self.Theme.Border)
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
		if self._CloseDropdowns then
			self._CloseDropdowns()
		end
		OptionsFrame.Visible = not WasVisible
		OptionsFrame.Position = UDim2.fromOffset(
			DropdownButton.AbsolutePosition.X,
			DropdownButton.AbsolutePosition.Y + DropdownButton.AbsoluteSize.Y + 4
		)
		if OptionsFrame.Visible then
			table.insert(self.OpenDropdowns, { Frame = OptionsFrame, Chevron = Chevron })
		end
		ApplyIcon(Chevron, OptionsFrame.Visible and "chevron-up" or "chevron-down")
	end)

	table.insert(self.Library.Elements, { Text = Title, Frame = DropdownFrame })
	return {
		SetValue = function(_, Values)
			Selected = {}
			for _, Value in ipairs(Values or {}) do
				Selected[Value] = true
			end
			UpdateValueLabel()
			Callback(Selected)
		end,
		Value = Selected,
	}
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
