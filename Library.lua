--//====================================================================--
--// Wolf UI Library V1 (Fluent-Inspired Modular UI Framework)
--//====================================================================--

local Wolf = {
    Tabs = {},
    ActiveTab = nil,
    Elements = {},
    Locked = false
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
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/SOUSHI45099/Assets/refs/heads/main/LucideRoblox.lua"))()
end) and loadstring(game:HttpGet("https://raw.githubusercontent.com/SOUSHI45099/Assets/refs/heads/main/LucideRoblox.lua"))() or nil

local function IsValidCustomIcon(Icon)
    return typeof(Icon) == "string" and (
        Icon:match("^rbxasset://textures/") or
        Icon:match("^rbxassetid://") or
        Icon:match("^rbxthumb://type=") or
        Icon:match("roblox%.com/asset/%?id=")
    )
end

local function ApplyIcon(ImageObject, iconName)
    if not iconName or iconName == "" then 
        ImageObject.Visible = false
        return 
    end
    ImageObject.Visible = true

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

    Border = Color3.fromRGB(50, 50, 55)
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

---------------------------------------------------------------------
-- WINDOW CREATION
---------------------------------------------------------------------

function Wolf:CreateWindow(Config)
    Config = Config or {}

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
    Sidebar.ZIndex = 2
    Sidebar.Parent = MainFrame

    local Divider = Instance.new("Frame")
    Divider.Size = UDim2.new(0, 1, 1, 0)
    Divider.Position = UDim2.new(1, -1, 0, 0)
    Divider.BorderSizePixel = 0
    Divider.BackgroundColor3 = self.Theme.Border
    Divider.Parent = Sidebar

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
    PlayerName.Size = UDim2.fromOffset(110, 18)
    PlayerName.FontFace = self.Fonts.Body
    PlayerName.TextSize = 13
    PlayerName.TextColor3 = self.Theme.Text
    PlayerName.TextXAlignment = Enum.TextXAlignment.Left
    PlayerName.TextTruncate = Enum.TextTruncate.AtEnd
    PlayerName.Text = LocalPlayer.DisplayName
    PlayerName.Parent = ProfileCard

    local Username = Instance.new("TextLabel")
    Username.BackgroundTransparency = 1
    Username.Position = UDim2.fromOffset(68, 38)
    Username.Size = UDim2.fromOffset(110, 15)
    Username.FontFace = self.Fonts.Small
    Username.TextSize = 10
    Username.TextColor3 = self.Theme.SubText
    Username.TextXAlignment = Enum.TextXAlignment.Left
    Username.TextTruncate = Enum.TextTruncate.AtEnd
    Username.Text = "@" .. LocalPlayer.Name
    Username.Parent = ProfileCard

    local DeviceIcon = Instance.new("ImageLabel")
    DeviceIcon.Position = UDim2.fromOffset(12, 80)
    DeviceIcon.Size = UDim2.fromOffset(16, 16)
    DeviceIcon.BackgroundTransparency = 1
    ApplyIcon(DeviceIcon, UserInputService.TouchEnabled and "smartphone" or "monitor")
    DeviceIcon.ImageColor3 = self.Theme.Accent
    DeviceIcon.Parent = ProfileCard

    local DeviceLabel = Instance.new("TextLabel")
    DeviceLabel.BackgroundTransparency = 1
    DeviceLabel.Position = UDim2.fromOffset(34, 78)
    DeviceLabel.Size = UDim2.fromOffset(130, 18)
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

    Padding(TabContainer, 8, 8, 8, 8)

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
    HeaderTitle.TextSize = 24
    HeaderTitle.TextColor3 = self.Theme.Accent
    HeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
    HeaderTitle.Parent = HeaderFrame

    local ControlsHolder = Instance.new("Frame")
    ControlsHolder.BackgroundTransparency = 1
    ControlsHolder.AnchorPoint = Vector2.new(1, 0.5)
    ControlsHolder.Position = UDim2.new(1, -12, 0.5, 0)
    ControlsHolder.Size = UDim2.fromOffset(260, 34)
    ControlsHolder.Parent = HeaderFrame

    local ControlsLayout = Instance.new("UIListLayout")
    ControlsLayout.FillDirection = Enum.FillDirection.Horizontal
    ControlsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    ControlsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    ControlsLayout.Padding = UDim.new(0, 8)
    ControlsLayout.Parent = ControlsHolder

    -- Search Box
    local SearchBox = Instance.new("TextBox")
    SearchBox.Name = "SearchBox"
    SearchBox.Size = UDim2.fromOffset(130, 30)
    SearchBox.BackgroundColor3 = self.Theme.Surface
    SearchBox.TextColor3 = self.Theme.Text
    SearchBox.PlaceholderColor3 = self.Theme.SubText
    SearchBox.Text = ""
    SearchBox.PlaceholderText = "Search..."
    SearchBox.FontFace = self.Fonts.Body
    SearchBox.TextSize = 12
    SearchBox.ClearTextOnFocus = false
    SearchBox.Parent = ControlsHolder
    Corner(SearchBox, 6)
    Stroke(SearchBox, self.Theme.Border)

    local SearchPadding = Instance.new("UIPadding")
    SearchPadding.PaddingLeft = UDim.new(0, 28)
    SearchPadding.PaddingRight = UDim.new(0, 6)
    SearchPadding.Parent = SearchBox

    local SearchIcon = Instance.new("ImageLabel")
    SearchIcon.Name = "SearchIcon"
    SearchIcon.BackgroundTransparency = 1
    SearchIcon.Size = UDim2.fromOffset(14, 14)
    SearchIcon.Position = UDim2.new(0, 8, 0.5, 0)
    SearchIcon.AnchorPoint = Vector2.new(0, 0.5)
    SearchIcon.ImageColor3 = self.Theme.SubText
    SearchIcon.Parent = SearchBox
    ApplyIcon(SearchIcon, "search")

    -- Lock Button
    local LockButton = Instance.new("TextButton")
    LockButton.Name = "LockButton"
    LockButton.Size = UDim2.fromOffset(60, 30)
    LockButton.BackgroundColor3 = self.Theme.AccentDark
    LockButton.TextColor3 = Color3.new(1, 1, 1)
    LockButton.FontFace = self.Fonts.Button
    LockButton.TextSize = 11
    LockButton.Text = "LOCK"
    LockButton.Parent = ControlsHolder
    Corner(LockButton, 6)

    -- Drag Handle
    local DragIcon = Instance.new("ImageButton")
    DragIcon.BackgroundTransparency = 1
    DragIcon.Size = UDim2.fromOffset(28, 28)
    ApplyIcon(DragIcon, "move")
    DragIcon.ImageColor3 = self.Theme.Accent
    DragIcon.Parent = ControlsHolder

    -- Main Display Container
    local ContentArea = Instance.new("Frame")
    ContentArea.Name = "ContentArea"
    ContentArea.Position = UDim2.new(0, 190, 0, 52)
    ContentArea.Size = UDim2.new(1, -190, 1, -76)
    ContentArea.BackgroundTransparency = 1
    ContentArea.ClipsDescendants = true
    ContentArea.Parent = MainFrame

    -- Footer
    local Footnote = Instance.new("Frame")
    Footnote.Size = UDim2.new(1, -190, 0, 24)
    Footnote.Position = UDim2.new(0, 190, 1, -24)
    Footnote.BackgroundColor3 = self.Theme.Header
    Footnote.BorderSizePixel = 0
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

    ---------------------------------------------------------
    -- DRAGGING MECHANISM
    ---------------------------------------------------------

    local dragging, dragStart, startPos = false, nil, nil

    DragIcon.InputBegan:Connect(function(input)
        if not self.Locked and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local Delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + Delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + Delta.Y
            )
        end
    end)

    -- Lock Handler
    LockButton.MouseButton1Click:Connect(function()
        self.Locked = not self.Locked
        LockButton.Text = self.Locked and "UNLOCK" or "LOCK"
        Tween(LockButton, {
            BackgroundColor3 = self.Locked and self.Theme.Surface or self.Theme.AccentDark
        })
    end)

    -- Search Filter Logic
    SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local Query = SearchBox.Text:lower()
        for _, ElementData in ipairs(self.Elements) do
            if ElementData.Text:lower():find(Query) then
                ElementData.Frame.Visible = true
            else
                ElementData.Frame.Visible = false
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
    local TabName = Config.Title or "Tab"
    local IconName = Config.Icon or "folder"

    -- Tab Selection Button
    local TabButton = Instance.new("TextButton")
    TabButton.Name = TabName .. "Tab"
    TabButton.Size = UDim2.new(1, 0, 0, 34)
    TabButton.BackgroundColor3 = self.Theme.Surface
    TabButton.BackgroundTransparency = 1
    TabButton.Text = ""
    TabButton.AutoButtonColor = false
    TabButton.Parent = self.TabContainer
    Corner(TabButton, 6)

    local TabIcon = Instance.new("ImageLabel")
    TabIcon.Size = UDim2.fromOffset(18, 18)
    TabIcon.Position = UDim2.new(0, 10, 0.5, 0)
    TabIcon.AnchorPoint = Vector2.new(0, 0.5)
    TabIcon.BackgroundTransparency = 1
    TabIcon.ImageColor3 = self.Theme.SubText
    TabIcon.Parent = TabButton
    ApplyIcon(TabIcon, IconName)

    local TabLabel = Instance.new("TextLabel")
    TabLabel.Position = UDim2.new(0, 36, 0, 0)
    TabLabel.Size = UDim2.new(1, -40, 1, 0)
    TabLabel.BackgroundTransparency = 1
    TabLabel.FontFace = self.Fonts.Body
    TabLabel.Text = TabName
    TabLabel.TextColor3 = self.Theme.SubText
    TabLabel.TextSize = 12
    TabLabel.TextXAlignment = Enum.TextXAlignment.Left
    TabLabel.Parent = TabButton

    -- Container Frame for Elements inside Tab
    local TabPage = Instance.new("ScrollingFrame")
    TabPage.Name = TabName .. "Page"
    TabPage.Size = UDim2.new(1, 0, 1, 0)
    TabPage.BackgroundTransparency = 1
    TabPage.BorderSizePixel = 0
    TabPage.Visible = false
    TabPage.ScrollBarThickness = 3
    TabPage.ScrollBarImageColor3 = self.Theme.Accent
    TabPage.AutomaticCanvasSize = Enum.AutomaticSize.Y
    TabPage.CanvasSize = UDim2.new()
    TabPage.Parent = self.ContentArea

    Padding(TabPage, 14, 14, 14, 14)

    local PageLayout = Instance.new("UIListLayout")
    PageLayout.Padding = UDim.new(0, 8)
    PageLayout.Parent = TabPage

    local TabObj = {
        Button = TabButton,
        Page = TabPage,
        Icon = TabIcon,
        Label = TabLabel,
        Library = self
    }

    local function SwitchTab()
        for _, tab in ipairs(self.Tabs) do
            Tween(tab.Button, { BackgroundTransparency = 1 })
            Tween(tab.Label, { TextColor3 = self.Theme.SubText })
            Tween(tab.Icon, { ImageColor3 = self.Theme.SubText })
            tab.Page.Visible = false
        end

        Tween(TabButton, { BackgroundTransparency = 0 })
        Tween(TabLabel, { TextColor3 = self.Theme.Text })
        Tween(TabIcon, { ImageColor3 = self.Theme.Accent })
        TabPage.Visible = true
        self.ActiveTab = TabObj
    end

    TabButton.MouseButton1Click:Connect(SwitchTab)

    -- Activate first added tab by default
    if #self.Tabs == 0 then
        SwitchTab()
    end

    table.insert(self.Tabs, TabObj)

    -- Attach Fluent Element Factory Methods to Tab Instance
    setmetatable(TabObj, { __index = Wolf })
    return TabObj
end

---------------------------------------------------------------------
-- COMPONENT FACTORIES (Elements)
---------------------------------------------------------------------

-- Section Header
function Wolf:AddSection(Title)
    local SectionFrame = Instance.new("Frame")
    SectionFrame.Size = UDim2.new(1, 0, 0, 24)
    SectionFrame.BackgroundTransparency = 1
    SectionFrame.Parent = self.Page

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, 0, 1, 0)
    Label.BackgroundTransparency = 1
    Label.FontFace = self.Fonts.Title
    Label.Text = Title:upper()
    Label.TextColor3 = self.Theme.Accent
    Label.TextSize = 11
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = SectionFrame

    table.insert(self.Library.Elements, { Text = Title, Frame = SectionFrame })
    return SectionFrame
end

-- Button Component
function Wolf:AddButton(Config)
    Config = typeof(Config) == "table" and Config or { Title = Config }
    local Title = Config.Title or "Button"
    local Callback = Config.Callback or function() end

    local ButtonFrame = Instance.new("Frame")
    ButtonFrame.Size = UDim2.new(1, 0, 0, 36)
    ButtonFrame.BackgroundColor3 = self.Theme.Card
    ButtonFrame.Parent = self.Page
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

    TextBtn.MouseEnter:Connect(function() Tween(ButtonFrame, { BackgroundColor3 = self.Theme.SurfaceHover }) end)
    TextBtn.MouseLeave:Connect(function() Tween(ButtonFrame, { BackgroundColor3 = self.Theme.Card }) end)
    TextBtn.MouseButton1Click:Connect(function()
        Tween(ButtonFrame, { BackgroundColor3 = self.Theme.Accent }, 0.08)
        task.delay(0.08, function() Tween(ButtonFrame, { BackgroundColor3 = self.Theme.SurfaceHover }) end)
        Callback()
    end)

    table.insert(self.Library.Elements, { Text = Title, Frame = ButtonFrame })
    return ButtonFrame
end

-- Toggle Component
function Wolf:AddToggle(Config)
    Config = typeof(Config) == "table" and Config or { Title = Config }
    local Title = Config.Title or "Toggle"
    local Default = Config.Default or false
    local Callback = Config.Callback or function() end

    local State = Default

    local ToggleFrame = Instance.new("Frame")
    ToggleFrame.Size = UDim2.new(1, 0, 0, 36)
    ToggleFrame.BackgroundColor3 = self.Theme.Card
    ToggleFrame.Parent = self.Page
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
    Corner(Indicator, 100)

    local Knob = Instance.new("Frame")
    Knob.AnchorPoint = Vector2.new(0, 0.5)
    Knob.Position = State and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
    Knob.Size = UDim2.fromOffset(14, 14)
    Knob.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
    Knob.Parent = Indicator
    Corner(Knob, 100)

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
        end
    }
end

-- Slider Component
function Wolf:AddSlider(Config)
    local Title = Config.Title or "Slider"
    local Min = Config.Min or 0
    local Max = Config.Max or 100
    local Default = Config.Default or Min
    local Callback = Config.Callback or function() end

    local SliderFrame = Instance.new("Frame")
    SliderFrame.Size = UDim2.new(1, 0, 0, 50)
    SliderFrame.BackgroundColor3 = self.Theme.Card
    SliderFrame.Parent = self.Page
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
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            UserDragging = true
            Update(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            UserDragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if UserDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            Update(input)
        end
    end)

    table.insert(self.Library.Elements, { Text = Title, Frame = SliderFrame })
    return SliderFrame
end

-- Textbox Input Component
function Wolf:AddTextbox(Config)
    local Title = Config.Title or "Input"
    local Placeholder = Config.Placeholder or "Enter text..."
    local Callback = Config.Callback or function() end

    local InputFrame = Instance.new("Frame")
    InputFrame.Size = UDim2.new(1, 0, 0, 36)
    InputFrame.BackgroundColor3 = self.Theme.Card
    InputFrame.Parent = self.Page
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

return Wolf
