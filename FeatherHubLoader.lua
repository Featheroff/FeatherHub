-- FeatherHub Loader — KeyAuth
-- Ссылка для распространения:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/Featheroff/FeatherHub/main/FeatherHubLoader.lua"))()

-- ════════════════════════════════════════════════════════════════
-- НАСТРОЙКИ
-- ════════════════════════════════════════════════════════════════

local SCRIPT_URL = "https://raw.githubusercontent.com/Featheroff/FeatherHub/main/FeatherHub.lua"

local KEYAUTH_APP_NAME = "FeatherHUB - Loader"
local KEYAUTH_OWNER_ID = "l7G7j8LbHP"
local KEYAUTH_VERSION = "1.0"

-- Ссылка на панель KeyAuth (куда пользователь идёт за ключом)
local KEYAUTH_PANEL_URL = "https://keyauth.cc/app/?page=licenses"

-- ════════════════════════════════════════════════════════════════
-- СЕРВИСЫ
-- ════════════════════════════════════════════════════════════════

local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = game:GetService("Players").LocalPlayer

-- ════════════════════════════════════════════════════════════════
-- KEYAUTH API 1.3
-- ════════════════════════════════════════════════════════════════

local KEYAUTH_API_URL = "https://keyauth.win/api/1.3/"
local SessionId = nil
local HWID = tostring(LocalPlayer.UserId)

local function KeyAuthRequest(Data)
    local Success, Response = pcall(function()
        return game:HttpGet(KEYAUTH_API_URL .. "?type=" .. HttpService:UrlEncode(Data.type)
            .. "&name=" .. HttpService:UrlEncode(KEYAUTH_APP_NAME)
            .. "&ownerid=" .. HttpService:UrlEncode(KEYAUTH_OWNER_ID)
            .. (Data.ver and "&ver=" .. HttpService:UrlEncode(Data.ver) or "")
            .. (Data.key and "&key=" .. HttpService:UrlEncode(Data.key) or "")
            .. (Data.hwid and "&hwid=" .. HttpService:UrlEncode(Data.hwid) or "")
            .. (Data.sessionid and "&sessionid=" .. HttpService:UrlEncode(Data.sessionid) or "")
            .. (Data.code and "&code=" .. HttpService:UrlEncode(Data.code) or "")
        )
    end)
    if not Success then return nil, "Ошибка соединения с KeyAuth" end

    local Ok, Json = pcall(function() return HttpService:JSONDecode(Response) end)
    if not Ok then return nil, "Ошибка парсинга ответа" end
    return Json, nil
end

local function KeyAuthInit()
    local Data, Err = KeyAuthRequest({ type = "init", ver = KEYAUTH_VERSION })
    if not Data then return false, Err end
    if Data.success then SessionId = Data.sessionid; return true end
    return false, Data.message or "Ошибка инициализации"
end

local function KeyAuthLicense(Key)
    if not SessionId then return false, "Сессия не инициализирована" end
    local Data, Err = KeyAuthRequest({ type = "license", key = Key, hwid = HWID, sessionid = SessionId })
    if not Data then return false, Err end
    if Data.success then return true, Data.message or "Ключ подтверждён" end
    return false, Data.message or "Неверный ключ"
end

-- ════════════════════════════════════════════════════════════════
-- UI
-- ════════════════════════════════════════════════════════════════

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FeatherHubLoader"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 100
ScreenGui.Parent = game:GetService("CoreGui")

-- Затемнённый фон
local Overlay = Instance.new("Frame")
Overlay.Size = UDim2.new(1, 0, 1, 0)
Overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Overlay.BackgroundTransparency = 0.5
Overlay.BorderSizePixel = 0
Overlay.Parent = ScreenGui

-- Главная карточка
local Card = Instance.new("Frame")
Card.Name = "Card"
Card.Size = UDim2.new(0, 380, 0, 420)
Card.Position = UDim2.new(0.5, -190, 0.5, -210)
Card.BackgroundColor3 = Color3.fromRGB(13, 19, 33)
Card.BorderSizePixel = 0
Card.Parent = ScreenGui

local CardCorner = Instance.new("UICorner")
CardCorner.CornerRadius = UDim.new(0, 16)
CardCorner.Parent = Card

local CardStroke = Instance.new("UIStroke")
CardStroke.Color = Color3.fromRGB(45, 64, 91)
CardStroke.Thickness = 1.5
CardStroke.Parent = Card

-- Декоративная полоска сверху
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, -32, 0, 3)
TopBar.Position = UDim2.new(0, 16, 0, 16)
TopBar.BackgroundColor3 = Color3.fromRGB(125, 211, 252)
TopBar.BorderSizePixel = 0
TopBar.Parent = Card

local TopBarCorner = Instance.new("UICorner")
TopBarCorner.CornerRadius = UDim.new(1, 0)
TopBarCorner.Parent = TopBar

-- Логотип / заголовок
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 36)
Title.Position = UDim2.new(0, 0, 0, 32)
Title.BackgroundTransparency = 1
Title.Text = "FeatherHub"
Title.TextColor3 = Color3.fromRGB(125, 211, 252)
Title.TextSize = 30
Title.Font = Enum.Font.GothamBold
Title.Parent = Card

local Subtitle = Instance.new("TextLabel")
Subtitle.Size = UDim2.new(1, 0, 0, 20)
Subtitle.Position = UDim2.new(0, 0, 0, 66)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "Key Authentication"
Subtitle.TextColor3 = Color3.fromRGB(100, 116, 139)
Subtitle.TextSize = 13
Subtitle.Font = Enum.Font.Gotham
Subtitle.Parent = Card

-- Разделитель
local Divider = Instance.new("Frame")
Divider.Size = UDim2.new(0.85, 0, 0, 1)
Divider.Position = UDim2.new(0.075, 0, 0, 96)
Divider.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
Divider.BorderSizePixel = 0
Divider.Parent = Card

-- Метка поля ввода
local InputLabel = Instance.new("TextLabel")
InputLabel.Size = UDim2.new(0.85, 0, 0, 18)
InputLabel.Position = UDim2.new(0.075, 0, 0, 112)
InputLabel.BackgroundTransparency = 1
InputLabel.Text = "КЛЮЧ ДОСТУПА"
InputLabel.TextColor3 = Color3.fromRGB(100, 116, 139)
InputLabel.TextSize = 11
InputLabel.Font = Enum.Font.GothamBold
InputLabel.TextXAlignment = Enum.TextXAlignment.Left
InputLabel.Parent = Card

-- Поле ввода
local KeyBox = Instance.new("TextBox")
KeyBox.Size = UDim2.new(0.85, 0, 0, 44)
KeyBox.Position = UDim2.new(0.075, 0, 0, 136)
KeyBox.BackgroundColor3 = Color3.fromRGB(20, 28, 44)
KeyBox.BorderSizePixel = 0
KeyBox.PlaceholderText = "Вставьте ключ..."
KeyBox.PlaceholderColor3 = Color3.fromRGB(71, 85, 105)
KeyBox.Text = ""
KeyBox.TextColor3 = Color3.fromRGB(231, 237, 247)
KeyBox.TextSize = 15
KeyBox.Font = Enum.Font.Gotham
KeyBox.ClearTextOnFocus = false
KeyBox.Parent = Card

local KeyBoxCorner = Instance.new("UICorner")
KeyBoxCorner.CornerRadius = UDim.new(0, 10)
KeyBoxCorner.Parent = KeyBox

local KeyBoxStroke = Instance.new("UIStroke")
KeyBoxStroke.Color = Color3.fromRGB(45, 64, 91)
KeyBoxStroke.Thickness = 1
KeyBoxStroke.Parent = KeyBox

-- Фокус на поле ввода — подсветка
KeyBox.Focused:Connect(function()
    TweenService:Create(KeyBoxStroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(125, 211, 252) }):Play()
end)
KeyBox.FocusLost:Connect(function()
    TweenService:Create(KeyBoxStroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(45, 64, 91) }):Play()
end)

-- Статус
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(0.85, 0, 0, 22)
StatusLabel.Position = UDim2.new(0.075, 0, 0, 190)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = ""
StatusLabel.TextColor3 = Color3.fromRGB(248, 113, 113)
StatusLabel.TextSize = 13
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.Parent = Card

-- Кнопка "Подтвердить"
local VerifyBtn = Instance.new("TextButton")
VerifyBtn.Size = UDim2.new(0.85, 0, 0, 46)
VerifyBtn.Position = UDim2.new(0.075, 0, 0, 220)
VerifyBtn.BackgroundColor3 = Color3.fromRGB(125, 211, 252)
VerifyBtn.BorderSizePixel = 0
VerifyBtn.Text = "Подтвердить"
VerifyBtn.TextColor3 = Color3.fromRGB(13, 19, 33)
VerifyBtn.TextSize = 16
VerifyBtn.Font = Enum.Font.GothamBold
VerifyBtn.AutoButtonColor = true
VerifyBtn.Parent = Card

local VerifyCorner = Instance.new("UICorner")
VerifyCorner.CornerRadius = UDim.new(0, 10)
VerifyCorner.Parent = VerifyBtn

-- Hover-эффект
VerifyBtn.MouseEnter:Connect(function()
    TweenService:Create(VerifyBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(160, 225, 255) }):Play()
end)
VerifyBtn.MouseLeave:Connect(function()
    TweenService:Create(VerifyBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(125, 211, 252) }):Play()
end)

-- Кнопка "Получить ключ" (ведёт на KeyAuth)
local GetKeyBtn = Instance.new("TextButton")
GetKeyBtn.Size = UDim2.new(0.85, 0, 0, 40)
GetKeyBtn.Position = UDim2.new(0.075, 0, 0, 278)
GetKeyBtn.BackgroundColor3 = Color3.fromRGB(20, 28, 44)
GetKeyBtn.BorderSizePixel = 0
GetKeyBtn.Text = "Получить ключ"
GetKeyBtn.TextColor3 = Color3.fromRGB(125, 211, 252)
GetKeyBtn.TextSize = 14
GetKeyBtn.Font = Enum.Font.Gotham
GetKeyBtn.AutoButtonColor = true
GetKeyBtn.Parent = Card

local GetKeyCorner = Instance.new("UICorner")
GetKeyCorner.CornerRadius = UDim.new(0, 10)
GetKeyCorner.Parent = GetKeyBtn

local GetKeyStroke = Instance.new("UIStroke")
GetKeyStroke.Color = Color3.fromRGB(45, 64, 91)
GetKeyStroke.Thickness = 1
GetKeyStroke.Parent = GetKeyBtn

GetKeyBtn.MouseEnter:Connect(function()
    TweenService:Create(GetKeyStroke, TweenInfo.new(0.15), { Color = Color3.fromRGB(125, 211, 252) }):Play()
end)
GetKeyBtn.MouseLeave:Connect(function()
    TweenService:Create(GetKeyStroke, TweenInfo.new(0.15), { Color = Color3.fromRGB(45, 64, 91) }):Play()
end)

-- Разделитель 2
local Divider2 = Instance.new("Frame")
Divider2.Size = UDim2.new(0.85, 0, 0, 1)
Divider2.Position = UDim2.new(0.075, 0, 0, 332)
Divider2.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
Divider2.BorderSizePixel = 0
Divider2.Parent = Card

-- Копирайт
local Footer = Instance.new("TextLabel")
Footer.Size = UDim2.new(1, 0, 0, 20)
Footer.Position = UDim2.new(0, 0, 0, 344)
Footer.BackgroundTransparency = 1
Footer.Text = "Feather - Scripter"
Footer.TextColor3 = Color3.fromRGB(71, 85, 105)
Footer.TextSize = 12
Footer.Font = Enum.Font.Gotham
Footer.Parent = Card

-- ════════════════════════════════════════════════════════════════
-- ФУНКЦИИ
-- ════════════════════════════════════════════════════════════════

local function SetStatus(Text, Color)
    StatusLabel.Text = Text
    StatusLabel.TextColor3 = Color or Color3.fromRGB(248, 113, 113)
end

local function LoadScript()
    ScreenGui:Destroy()
    task.wait(0.3)
    local Ok, Err = pcall(function() loadstring(game:HttpGet(SCRIPT_URL))() end)
    if not Ok then
        warn("[FeatherHub] Ошибка загрузки: " .. tostring(Err))
    end
end

local function VerifyKey(Key)
    if not Key or Key == "" then return false, "Введите ключ доступа" end
    if not SessionId then
        SetStatus("Инициализация...", Color3.fromRGB(125, 211, 252))
        local Ok, Err = KeyAuthInit()
        if not Ok then return false, Err end
    end
    return KeyAuthLicense(Key)
end

-- ════════════════════════════════════════════════════════════════
-- ОБРАБОТЧИКИ
-- ════════════════════════════════════════════════════════════════

VerifyBtn.MouseButton1Click:Connect(function()
    local Key = KeyBox.Text:gsub("%s+", "")
    SetStatus("Проверка...", Color3.fromRGB(125, 211, 252))
    VerifyBtn.Active = false
    VerifyBtn.BackgroundColor3 = Color3.fromRGB(71, 85, 105)

    task.spawn(function()
        task.wait(0.4)
        local Ok, Msg = VerifyKey(Key)
        if Ok then
            SetStatus(Msg, Color3.fromRGB(74, 222, 128))
            task.wait(0.8)
            LoadScript()
        else
            SetStatus(Msg, Color3.fromRGB(248, 113, 113))
            VerifyBtn.Active = true
            VerifyBtn.BackgroundColor3 = Color3.fromRGB(125, 211, 252)
            -- Тряска поля ввода
            for i = 1, 3 do
                TweenService:Create(KeyBox, TweenInfo.new(0.08), { Position = UDim2.new(0.075 + (i % 2 == 0 and -0.01 or 0.01), 0, 0, 136) }):Play()
                task.wait(0.08)
            end
            TweenService:Create(KeyBox, TweenInfo.new(0.1), { Position = UDim2.new(0.075, 0, 0, 136) }):Play()
        end
    end)
end)

GetKeyBtn.MouseButton1Click:Connect(function()
    local Copy = type(setclipboard) == "function" and setclipboard or toclipboard
    if type(Copy) == "function" then
        pcall(Copy, KEYAUTH_PANEL_URL)
        SetStatus("Ссылка на KeyAuth скопирована!", Color3.fromRGB(74, 222, 128))
    else
        SetStatus(KEYAUTH_PANEL_URL, Color3.fromRGB(125, 211, 252))
    end
end)

KeyBox.FocusLost:Connect(function(Enter)
    if Enter then VerifyBtn:Fire() end
end)

-- ════════════════════════════════════════════════════════════════
-- ПЕРЕТАСКИВАНИЕ
-- ════════════════════════════════════════════════════════════════

local Dragging, DragStart, StartPos

Card.InputBegan:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
        Dragging = true
        DragStart = Input.Position
        StartPos = Card.Position
        Input.Changed:Connect(function()
            if Input.UserInputState == Enum.UserInputState.End then Dragging = false end
        end)
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(Input)
    if Dragging and (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch) then
        local Delta = Input.Position - DragStart
        Card.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + Delta.X, StartPos.Y.Scale, StartPos.Y.Offset + Delta.Y)
    end
end)

-- Анимация появления
Card.Position = UDim2.new(0.5, -190, 0.5, -230)
TweenService:Create(Card, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
    Position = UDim2.new(0.5, -190, 0.5, -210)
}):Play()

print("[FeatherHub] Loader ready.")
