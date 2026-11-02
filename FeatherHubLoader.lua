-- FeatherHub Loader
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/Featheroff/FeatherHub/main/FeatherHubLoader.lua"))()

local SCRIPT_URL = "https://raw.githubusercontent.com/Featheroff/FeatherHub/main/FeatherHub.lua"

local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

-- Создаём GUI
local Gui = Instance.new("ScreenGui")
Gui.Name = "FeatherHubLoader"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = CoreGui

-- Карточка
local Card = Instance.new("Frame")
Card.Size = UDim2.new(0, 400, 0, 500)
Card.Position = UDim2.new(0.5, -200, 0.5, -250)
Card.BackgroundColor3 = Color3.fromRGB(14, 20, 36)
Card.BorderSizePixel = 0
Card.Parent = Gui

Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 12)

local CardStroke = Instance.new("UIStroke", Card)
CardStroke.Color = Color3.fromRGB(45, 64, 91)
CardStroke.Thickness = 2

-- Заголовок
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 50)
Title.Position = UDim2.new(0, 0, 0, 20)
Title.BackgroundTransparency = 1
Title.Text = "FeatherHub"
Title.TextColor3 = Color3.fromRGB(125, 211, 252)
Title.TextSize = 28
Title.Font = Enum.Font.GothamBold
Title.Parent = Card

local Subtitle = Instance.new("TextLabel")
Subtitle.Size = UDim2.new(1, 0, 0, 20)
Subtitle.Position = UDim2.new(0, 0, 0, 55)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "Key System"
Subtitle.TextColor3 = Color3.fromRGB(148, 163, 184)
Subtitle.TextSize = 14
Subtitle.Font = Enum.Font.Gotham
Subtitle.Parent = Card

-- Поле ввода
local KeyBox = Instance.new("TextBox")
KeyBox.Size = UDim2.new(0.8, 0, 0, 40)
KeyBox.Position = UDim2.new(0.1, 0, 0, 100)
KeyBox.BackgroundColor3 = Color3.fromRGB(24, 34, 53)
KeyBox.BorderSizePixel = 0
KeyBox.PlaceholderText = "Введите ключ..."
KeyBox.PlaceholderColor3 = Color3.fromRGB(100, 116, 139)
KeyBox.Text = ""
KeyBox.TextColor3 = Color3.fromRGB(231, 237, 247)
KeyBox.TextSize = 16
KeyBox.Font = Enum.Font.Gotham
KeyBox.ClearTextOnFocus = false
KeyBox.Parent = Card

Instance.new("UICorner", KeyBox).CornerRadius = UDim.new(0, 8)

local KeyBoxStroke = Instance.new("UIStroke", KeyBox)
KeyBoxStroke.Color = Color3.fromRGB(45, 64, 91)
KeyBoxStroke.Thickness = 1

-- Статус
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(0.8, 0, 0, 30)
StatusLabel.Position = UDim2.new(0.1, 0, 0, 150)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = ""
StatusLabel.TextColor3 = Color3.fromRGB(248, 113, 113)
StatusLabel.TextSize = 14
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.Parent = Card

-- Кнопка подтверждения
local VerifyBtn = Instance.new("TextButton")
VerifyBtn.Size = UDim2.new(0.8, 0, 0, 45)
VerifyBtn.Position = UDim2.new(0.1, 0, 0, 200)
VerifyBtn.BackgroundColor3 = Color3.fromRGB(125, 211, 252)
VerifyBtn.BorderSizePixel = 0
VerifyBtn.Text = "Подтвердить"
VerifyBtn.TextColor3 = Color3.fromRGB(16, 24, 39)
VerifyBtn.TextSize = 18
VerifyBtn.Font = Enum.Font.GothamBold
VerifyBtn.AutoButtonColor = true
VerifyBtn.Parent = Card

Instance.new("UICorner", VerifyBtn).CornerRadius = UDim.new(0, 8)

-- Кнопка получения ключа
local GetKeyBtn = Instance.new("TextButton")
GetKeyBtn.Size = UDim2.new(0.8, 0, 0, 35)
GetKeyBtn.Position = UDim2.new(0.1, 0, 0, 260)
GetKeyBtn.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
GetKeyBtn.BorderSizePixel = 0
GetKeyBtn.Text = "Получить ключ"
GetKeyBtn.TextColor3 = Color3.fromRGB(125, 211, 252)
GetKeyBtn.TextSize = 14
GetKeyBtn.Font = Enum.Font.Gotham
GetKeyBtn.AutoButtonColor = true
GetKeyBtn.Parent = Card

Instance.new("UICorner", GetKeyBtn).CornerRadius = UDim.new(0, 8)

local GetKeyStroke = Instance.new("UIStroke", GetKeyBtn)
GetKeyStroke.Color = Color3.fromRGB(125, 211, 252)
GetKeyStroke.Thickness = 1

-- Подсказка
local HintLabel = Instance.new("TextLabel")
HintLabel.Size = UDim2.new(0.8, 0, 0, 20)
HintLabel.Position = UDim2.new(0.1, 0, 0, 310)
HintLabel.BackgroundTransparency = 1
HintLabel.Text = "Нажми чтобы получить ключ"
HintLabel.TextColor3 = Color3.fromRGB(100, 116, 139)
HintLabel.TextSize = 12
HintLabel.Font = Enum.Font.Gotham
HintLabel.Parent = Card

-- Футер
local Footer = Instance.new("TextLabel")
Footer.Size = UDim2.new(1, 0, 0, 20)
Footer.Position = UDim2.new(0, 0, 0, 460)
Footer.BackgroundTransparency = 1
Footer.Text = "Feather · Scripter"
Footer.TextColor3 = Color3.fromRGB(100, 116, 139)
Footer.TextSize = 12
Footer.Font = Enum.Font.Gotham
Footer.Parent = Card

-- ════════════════════════════════════════════════════════════════
-- ГЕНЕРАЦИЯ И ПРОВЕРКА КЛЮЧЕЙ
-- ════════════════════════════════════════════════════════════════

local CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

local function GenerateKey()
    local b1, b2 = "", ""
    for _ = 1, 4 do b1 = b1 .. CHARS:sub(math.random(1, #CHARS), math.random(1, #CHARS)) end
    for _ = 1, 4 do b2 = b2 .. CHARS:sub(math.random(1, #CHARS), math.random(1, #CHARS)) end
    return "FEATHER-" .. b1 .. "-" .. b2
end

local function IsValidKey(Key)
    if not Key then return false end
    Key = Key:upper():gsub("%s+", "")
    if #Key ~= 18 then return false end
    if Key:sub(1, 7) ~= "FEATHER" then return false end
    if Key:sub(8, 8) ~= "-" then return false end
    if Key:sub(13, 13) ~= "-" then return false end
    return true
end

-- Ссылка на Linkvertise (замени на свою)
local LINKVERTISE_URL = "https://link-to.net/YOUR_ID"

-- ════════════════════════════════════════════════════════════════
-- ОБРАБОТЧИКИ
-- ════════════════════════════════════════════════════════════════

GetKeyBtn.MouseButton1Click:Connect(function()
    local Copy = type(setclipboard) == "function" and setclipboard or toclipboard
    if type(Copy) == "function" then
        pcall(Copy, LINKVERTISE_URL)
        StatusLabel.Text = "Ссылка скопирована! Пройди оффер"
        StatusLabel.TextColor3 = Color3.fromRGB(125, 211, 252)
    else
        StatusLabel.Text = LINKVERTISE_URL
        StatusLabel.TextColor3 = Color3.fromRGB(125, 211, 252)
    end
end)

VerifyBtn.MouseButton1Click:Connect(function()
    local Key = KeyBox.Text:gsub("%s+", "")
    
    if Key == "" then
        StatusLabel.Text = "Введите ключ"
        StatusLabel.TextColor3 = Color3.fromRGB(248, 113, 113)
        return
    end
    
    if IsValidKey(Key) then
        StatusLabel.Text = "Ключ подтверждён!"
        StatusLabel.TextColor3 = Color3.fromRGB(74, 222, 128)
        VerifyBtn.BackgroundColor3 = Color3.fromRGB(74, 222, 128)
        task.wait(1)
        Gui:Destroy()
        loadstring(game:HttpGet(SCRIPT_URL))()
    else
        StatusLabel.Text = "Неверный ключ"
        StatusLabel.TextColor3 = Color3.fromRGB(248, 113, 113)
    end
end)

KeyBox.FocusLost:Connect(function(Enter)
    if Enter then
        VerifyBtn.MouseButton1Click:Fire()
    end
end)

print("[FeatherHub] Loader ready.")
