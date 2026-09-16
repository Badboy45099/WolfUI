local Wolf =
	loadstring(game:HttpGet("https://raw.githubusercontent.com/Badboy45099/WolfUI/refs/heads/main/Library.lua"))()

local Window = Wolf:CreateWindow({ Title = "WOLF UI", Footnote = "Wolf UI | Example", Icon = "paw-print" })
Window:Notify({ Title = "Ready", Content = "Wolf UI loaded successfully.", Icon = "check", Duration = 3 })

local MainTab = Window:AddTab({ Title = "Main", Icon = "house" })
local VisualTab = Window:AddTab({ Title = "Visual", Icon = "eye" })
local SettingsTab = Window:AddTab({ Title = "Settings", Icon = "settings" })

MainTab:AddSection({ Title = "General", Icon = "sliders-horizontal" })

MainTab:AddToggle({
	Title = "Enable feature",
	Default = false,
	Callback = function(Value)
		print("Feature enabled:", Value)
	end,
})

MainTab:AddButton({
	Title = "Run action",
	Icon = "play",
	Callback = function()
		print("Action clicked")
	end,
})

MainTab:AddSlider({
	Title = "Power",
	Icon = "gauge",
	Min = 0,
	Max = 100,
	Default = 50,
	Callback = function(Value)
		print("Power:", Value)
	end,
})

MainTab:AddTextbox({
	Title = "Message",
	Icon = "message-square",
	Placeholder = "Type something...",
	Callback = function(Text, EnterPressed)
		print(Text, EnterPressed)
	end,
})

MainTab:AddDropdown({
	Title = "Theme",
	Icon = "palette",
	Options = { "Red", "Blue", "Green" },
	Default = "Red",
	Callback = function(Value)
		print("Theme:", Value)
	end,
})

MainTab:AddMultiDropdown({
	Title = "Features",
	Icon = "list-checks",
	Options = { "ESP", "Sound", "Particles" },
	Default = { "ESP" },
	Callback = function(Values)
		print("Selected features:", Values)
	end,
})

SettingsTab:AddSection({ Title = "Preferences", Icon = "sliders-horizontal" })
SettingsTab:AddToggle({ Title = "Notification", Icon = "bell" })
SettingsTab:AddButton({ Title = "Reset settings", Icon = "rotate-ccw" })
