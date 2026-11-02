-- FeatherHub Loader
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/Featheroff/FeatherHub/main/FeatherHubLoader.lua"))()

-- ════════════════════════════════════════════════════════════════
-- НАСТРОЙКИ
-- ════════════════════════════════════════════════════════════════

local SCRIPT_URL = "https://raw.githubusercontent.com/Featheroff/FeatherHub/main/FeatherHub.lua"
local KEYS_URL = "https://raw.githubusercontent.com/Featheroff/FeatherHub/main/keys.json"
local LOADER_VERSION = "1.0"

-- ════════════════════════════════════════════════════════════════
-- СЕРВИСЫ
-- ════════════════════════════════════════════════════════════════

local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LocalPlayer = game:GetService("Players").LocalPlayer
local CoreGui = game:GetService("CoreGui")

-- ════════════════════════════════════════════════════════════════
-- ЦВЕТА
-- ════════════════════════════════════════════════════════════════

local C = {
    Bg          = Color3.fromRGB(10, 14, 26),
    Card        = Color3.fromRGB(14, 20, 36),
    CardHover   = Color3.fromRGB(18, 26, 46),
    Input       = Color3.fromRGB(18, 26, 44),
    InputBorder = Color3.fromRGB(36, 50, 76),
    Accent      = Color3.fromRGB(125, 211, 252),
    AccentDark  = Color3.fromRGB(56, 140, 180),
    AccentGlow  = Color3.fromRGB(125, 211, 252),
    Text        = Color3.fromRGB(226, 232, 240),
    TextDim     = Color3.fromRGB(100, 116, 139),
    TextMuted   = Color3.fromRGB(71, 85, 105),
    Success     = Color3.fromRGB(52, 211, 153),
    Error       = Color3.fromRGB(248, 113, 113),
    Warning     = Color3.fromRGB(251, 191, 36),
    Divider     = Color3.fromRGB(30, 41, 59),
    BtnSecondary= Color3.fromRGB(18, 26, 44),
}

local TI = { Quick = TweenInfo.new(0.15, Enum.EasingStyle.Quad), Smooth = TweenInfo.new(0.3, Enum.EasingStyle.Quart), Spring = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 1) }

local function Tween(Obj, Props, Info) TweenService:Create(Obj, Info or TI.Smooth, Props):Play() end

-- ════════════════════════════════════════════════════════════════
-- СИСТЕМА КЛЮЧЕЙ (GitHub keys.json)
-- ════════════════════════════════════════════════════════════════

local ValidKeys = nil
local KeysLoading = false

local function LoadKeys()
    if ValidKeys or KeysLoading then return end
    KeysLoading = true
    local Ok, Res = pcall(function() return game:HttpGet(KEYS_URL) end)
    KeysLoading = false
    if Ok then
        local POk, Keys = pcall(function() return HttpService:JSONDecode(Res) end)
        if POk and type(Keys) == "table" then
            ValidKeys = {}
            for _, Key in ipairs(Keys) do
                ValidKeys[tostring(Key):upper()] = true
            end
        end
    end
end

local function VerifyKey(Key)
    if not Key or Key == "" then return false, "Введите ключ доступа" end
    -- Загружаем ключи если ещё не загружены
    LoadKeys()
    if KeysLoading then return false, "Загрузка ключей..." end
    if not ValidKeys then return false, "Не удалось загрузить ключи" end
    -- Проверяем ключ
    if ValidKeys[Key:upper()] then
        return true, "Ключ подтверждён"
    end
    return false, "Неверный ключ"
end

-- ════════════════════════════════════════════════════════════════
-- UI: КОНТЕЙНЕР
-- ════════════════════════════════════════════════════════════════

local Gui = Instance.new("ScreenGui")
Gui.Name = "FeatherHubLoader"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.DisplayOrder = 100
Gui.Parent = CoreGui

-- Затемнение фона
local Overlay = Instance.new("Frame")
Overlay.Size = UDim2.new(1, 0, 1, 0)
Overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Overlay.BackgroundTransparency = 1
Overlay.BorderSizePixel = 0
Overlay.Parent = Gui
Tween(Overlay, { BackgroundTransparency = 0.55 }, TweenInfo.new(0.6, Enum.EasingStyle.Quad))

-- ════════════════════════════════════════════════════════════════
-- UI: КАРТОЧКА
-- ════════════════════════════════════════════════════════════════

local Card = Instance.new("Frame")
Card.Name = "Card"
Card.Size = UDim2.new(0, 400, 0, 460)
Card.Position = UDim2.new(0.5, -200, 0.5, -250)
Card.BackgroundColor3 = C.Card
Card.BorderSizePixel = 0
Card.ClipsDescendants = true
Card.Parent = Gui

Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 18)

local CardStroke = Instance.new("UIStroke", Card)
CardStroke.Color = C.InputBorder
CardStroke.Thickness = 1.5
CardStroke.Transparency = 0.3

-- Свечение карточки (большой UIStroke снаружи)
local GlowStroke = Instance.new("UIStroke", Card)
GlowStroke.Color = C.AccentGlow
GlowStroke.Thickness = 0
GlowStroke.Transparency = 0.7
GlowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- Градиентный фон карточки
local Gradient = Instance.new("UIGradient", Card)
Gradient.Rotation = 135
Gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 24, 42)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 14, 26)),
})

-- ════════════════════════════════════════════════════════════════
-- UI: ВЕРХНЯЯ ПОЛОСКА-АКЦЕНТ
-- ════════════════════════════════════════════════════════════════

local AccentBar = Instance.new("Frame")
AccentBar.Size = UDim2.new(0.6, 0, 0, 3)
AccentBar.Position = UDim2.new(0.2, 0, 0, 0)
AccentBar.BackgroundColor3 = C.Accent
AccentBar.BorderSizePixel = 0
AccentBar.Parent = Card

Instance.new("UICorner", AccentBar).CornerRadius = UDim.new(0, 2)

-- Свечение полоски
local BarGlow = Instance.new("UIStroke", AccentBar)
BarGlow.Color = C.AccentGlow
BarGlow.Thickness = 4
BarGlow.Transparency = 0.5
BarGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- ════════════════════════════════════════════════════════════════
-- UI: ИКОНКА ПЕРА
-- ════════════════════════════════════════════════════════════════

local IconHolder = Instance.new("Frame")
IconHolder.Size = UDim2.new(0, 56, 0, 56)
IconHolder.Position = UDim2.new(0.5, -28, 0, 28)
IconHolder.BackgroundTransparency = 1
IconHolder.Parent = Card

-- Круглый фон иконки
local IconBg = Instance.new("Frame")
IconBg.Size = UDim2.new(1, 0, 1, 0)
IconBg.BackgroundColor3 = C.Accent
IconBg.BackgroundTransparency = 0.85
IconBg.BorderSizePixel = 0
IconBg.Parent = IconHolder
Instance.new("UICorner", IconBg).CornerRadius = UDim.new(1, 0)

-- Символ пера
local FeatherIcon = Instance.new("TextLabel")
FeatherIcon.Size = UDim2.new(1, 0, 1, 0)
FeatherIcon.BackgroundTransparency = 1
FeatherIcon.Text = "F"
FeatherIcon.TextSize = 28
FeatherIcon.Font = Enum.Font.GothamBold
FeatherIcon.TextColor3 = C.Accent
FeatherIcon.Parent = IconHolder

-- ════════════════════════════════════════════════════════════════
-- UI: ЗАГОЛОВОК
-- ════════════════════════════════════════════════════════════════

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 32)
Title.Position = UDim2.new(0, 0, 0, 92)
Title.BackgroundTransparency = 1
Title.Text = "FeatherHub"
Title.TextColor3 = C.Text
Title.TextSize = 26
Title.Font = Enum.Font.GothamBold
Title.TextStrokeTransparency = 0.8
Title.Parent = Card

local Subtitle = Instance.new("TextLabel")
Subtitle.Size = UDim2.new(1, 0, 0, 18)
Subtitle.Position = UDim2.new(0, 0, 0, 122)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "Key System"
Subtitle.TextColor3 = C.TextDim
Subtitle.TextSize = 12
Subtitle.Font = Enum.Font.Gotham
Subtitle.LetterSpacing = 1.5
Subtitle.Parent = Card

-- ════════════════════════════════════════════════════════════════
-- UI: РАЗДЕЛИТЕЛЬ
-- ════════════════════════════════════════════════════════════════

local Div1 = Instance.new("Frame")
Div1.Size = UDim2.new(0.8, 0, 0, 1)
Div1.Position = UDim2.new(0.1, 0, 0, 152)
Div1.BackgroundColor3 = C.Divider
Div1.BorderSizePixel = 0
Div1.Parent = Card

-- ════════════════════════════════════════════════════════════════
-- UI: ПОЛЕ ВВОДА
-- ════════════════════════════════════════════════════════════════

local InputLabel = Instance.new("TextLabel")
InputLabel.Size = UDim2.new(0.8, 0, 0, 16)
InputLabel.Position = UDim2.new(0.1, 0, 0, 168)
InputLabel.BackgroundTransparency = 1
InputLabel.Text = "КЛЮЧ ДОСТУПА"
InputLabel.TextColor3 = C.TextMuted
InputLabel.TextSize = 10
InputLabel.Font = Enum.Font.GothamBold
InputLabel.TextXAlignment = Enum.TextXAlignment.Left
InputLabel.LetterSpacing = 1
InputLabel.Parent = Card

local KeyBox = Instance.new("TextBox")
KeyBox.Size = UDim2.new(0.8, 0, 0, 46)
KeyBox.Position = UDim2.new(0.1, 0, 0, 190)
KeyBox.BackgroundColor3 = C.Input
KeyBox.BorderSizePixel = 0
KeyBox.PlaceholderText = "Вставьте ключ..."
KeyBox.PlaceholderColor3 = C.TextMuted
KeyBox.Text = ""
KeyBox.TextColor3 = C.Text
KeyBox.TextSize = 15
KeyBox.Font = Enum.Font.Gotham
KeyBox.ClearTextOnFocus = false
KeyBox.Parent = Card

Instance.new("UICorner", KeyBox).CornerRadius = UDim.new(0, 10)

local KeyBoxStroke = Instance.new("UIStroke", KeyBox)
KeyBoxStroke.Color = C.InputBorder
KeyBoxStroke.Thickness = 1

-- Иконка ключа внутри поля
local KeyIcon = Instance.new("TextLabel")
KeyIcon.Size = UDim2.new(0, 20, 0, 20)
KeyIcon.Position = UDim2.new(0, 12, 0.5, -10)
KeyIcon.BackgroundTransparency = 1
KeyIcon.Text = ">"
KeyIcon.TextSize = 14
KeyIcon.Font = Enum.Font.GothamBold
KeyIcon.TextColor3 = C.TextMuted
KeyIcon.ZIndex = 2
KeyIcon.Parent = KeyBox

KeyBox.PaddingLeft = UDim.new(0, 36)

-- Подсветка при фокусе
KeyBox.Focused:Connect(function()
    Tween(KeyBoxStroke, { Color = C.Accent, Thickness = 1.5 }, TI.Quick)
    Tween(KeyIcon, { TextColor3 = C.Accent }, TI.Quick)
end)
KeyBox.FocusLost:Connect(function()
    Tween(KeyBoxStroke, { Color = C.InputBorder, Thickness = 1 }, TI.Quick)
    Tween(KeyIcon, { TextColor3 = C.TextMuted }, TI.Quick)
end)

-- ════════════════════════════════════════════════════════════════
-- UI: СТАТУС
-- ════════════════════════════════════════════════════════════════

local StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.new(0, 7, 0, 7)
StatusDot.Position = UDim2.new(0.1, 0, 0, 252)
StatusDot.BackgroundColor3 = C.TextMuted
StatusDot.BorderSizePixel = 0
StatusDot.Visible = false
StatusDot.Parent = Card
Instance.new("UICorner", StatusDot).CornerRadius = UDim.new(1, 0)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(0.75, 0, 0, 20)
StatusLabel.Position = UDim2.new(0.1, 0, 0, 248)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = ""
StatusLabel.TextColor3 = C.TextDim
StatusLabel.TextSize = 12
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = Card

-- ════════════════════════════════════════════════════════════════
-- UI: СПИННЕР ЗАГРУЗКИ
-- ════════════════════════════════════════════════════════════════

local SpinnerHolder = Instance.new("Frame")
SpinnerHolder.Size = UDim2.new(0, 22, 0, 22)
SpinnerHolder.Position = UDim2.new(0.5, -11, 0, 248)
SpinnerHolder.BackgroundTransparency = 1
SpinnerHolder.Visible = false
SpinnerHolder.Parent = Card

local SpinnerArc = Instance.new("Frame")
SpinnerArc.Size = UDim2.new(1, 0, 1, 0)
SpinnerArc.BackgroundColor3 = C.Accent
SpinnerArc.BackgroundTransparency = 0.3
SpinnerArc.BorderSizePixel = 0
SpinnerArc.AnchorPoint = Vector2.new(0.5, 0.5)
SpinnerArc.Position = UDim2.new(0.5, 0, 0.5, 0)
SpinnerArc.Parent = SpinnerHolder
Instance.new("UICorner", SpinnerArc).CornerRadius = UDim.new(1, 0)

-- ════════════════════════════════════════════════════════════════
-- UI: КНОПКА "ПОДТВЕРДИТЬ"
-- ════════════════════════════════════════════════════════════════

local VerifyBtn = Instance.new("TextButton")
VerifyBtn.Size = UDim2.new(0.8, 0, 0, 48)
VerifyBtn.Position = UDim2.new(0.1, 0, 0, 280)
VerifyBtn.BackgroundColor3 = C.Accent
VerifyBtn.BorderSizePixel = 0
VerifyBtn.Text = "Подтвердить"
VerifyBtn.TextColor3 = C.Bg
VerifyBtn.TextSize = 15
VerifyBtn.Font = Enum.Font.GothamBold
VerifyBtn.AutoButtonColor = false
VerifyBtn.Parent = Card

Instance.new("UICorner", VerifyBtn).CornerRadius = UDim.new(0, 10)

-- Свечение кнопки
local BtnGlow = Instance.new("UIStroke", VerifyBtn)
BtnGlow.Color = C.AccentGlow
BtnGlow.Thickness = 0
BtnGlow.Transparency = 0.4
BtnGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- Hover
VerifyBtn.MouseEnter:Connect(function()
    if VerifyBtn.Active then
        Tween(VerifyBtn, { BackgroundColor3 = Color3.fromRGB(155, 225, 255) }, TI.Quick)
        Tween(BtnGlow, { Thickness = 3 }, TI.Quick)
    end
end)
VerifyBtn.MouseLeave:Connect(function()
    Tween(VerifyBtn, { BackgroundColor3 = C.Accent }, TI.Quick)
    Tween(BtnGlow, { Thickness = 0 }, TI.Quick)
end)

-- Нажатие
VerifyBtn.MouseButton1Down:Connect(function()
    if VerifyBtn.Active then Tween(VerifyBtn, { Size = UDim2.new(0.8, 0, 0, 44) }, TI.Quick) end
end)
VerifyBtn.MouseButton1Up:Connect(function()
    if VerifyBtn.Active then Tween(VerifyBtn, { Size = UDim2.new(0.8, 0, 0, 48) }, TI.Quick) end
end)

-- ════════════════════════════════════════════════════════════════
-- UI: КНОПКА "ПОЛУЧИТЬ КЛЮЧ"
-- ════════════════════════════════════════════════════════════════

-- Подсказка над кнопкой "Получить ключ"
local HintLabel = Instance.new("TextLabel")
HintLabel.Size = UDim2.new(0.8, 0, 0, 14)
HintLabel.Position = UDim2.new(0.1, 0, 0, 322)
HintLabel.BackgroundTransparency = 1
HintLabel.Text = "Нажми чтобы скопировать ссылку на ключи"
HintLabel.TextColor3 = C.TextMuted
HintLabel.TextSize = 10
HintLabel.Font = Enum.Font.Gotham
HintLabel.TextXAlignment = Enum.TextXAlignment.Center
HintLabel.Parent = Card

local GetKeyBtn = Instance.new("TextButton")
GetKeyBtn.Size = UDim2.new(0.8, 0, 0, 42)
GetKeyBtn.Position = UDim2.new(0.1, 0, 0, 340)
GetKeyBtn.BackgroundColor3 = C.BtnSecondary
GetKeyBtn.BorderSizePixel = 0
GetKeyBtn.Text = "Получить ключ"
GetKeyBtn.TextColor3 = C.Accent
GetKeyBtn.TextSize = 13
GetKeyBtn.Font = Enum.Font.GothamBold
GetKeyBtn.AutoButtonColor = false
GetKeyBtn.Parent = Card

Instance.new("UICorner", GetKeyBtn).CornerRadius = UDim.new(0, 10)

local GetKeyStroke = Instance.new("UIStroke", GetKeyBtn)
GetKeyStroke.Color = C.InputBorder
GetKeyStroke.Thickness = 1

-- Иконка ссылки
local LinkIcon = Instance.new("TextLabel")
LinkIcon.Size = UDim2.new(0, 16, 0, 16)
LinkIcon.Position = UDim2.new(0, 12, 0.5, -8)
LinkIcon.BackgroundTransparency = 1
LinkIcon.Text = ">"
LinkIcon.TextSize = 12
LinkIcon.Font = Enum.Font.GothamBold
LinkIcon.TextColor3 = C.Accent
LinkIcon.ZIndex = 2
LinkIcon.Parent = GetKeyBtn

GetKeyBtn.PaddingLeft = UDim.new(0, 32)

GetKeyBtn.MouseEnter:Connect(function()
    Tween(GetKeyBtn, { BackgroundColor3 = C.CardHover }, TI.Quick)
    Tween(GetKeyStroke, { Color = C.Accent }, TI.Quick)
end)
GetKeyBtn.MouseLeave:Connect(function()
    Tween(GetKeyBtn, { BackgroundColor3 = C.BtnSecondary }, TI.Quick)
    Tween(GetKeyStroke, { Color = C.InputBorder }, TI.Quick)
end)

-- ════════════════════════════════════════════════════════════════
-- UI: РАЗДЕЛИТЕЛЬ 2 + ФУТЕР
-- ════════════════════════════════════════════════════════════════

local Div2 = Instance.new("Frame")
Div2.Size = UDim2.new(0.8, 0, 0, 1)
Div2.Position = UDim2.new(0.1, 0, 0, 398)
Div2.BackgroundColor3 = C.Divider
Div2.BorderSizePixel = 0
Div2.Parent = Card

local Footer = Instance.new("TextLabel")
Footer.Size = UDim2.new(1, 0, 0, 18)
Footer.Position = UDim2.new(0, 0, 0, 410)
Footer.BackgroundTransparency = 1
Footer.Text = "Feather  ·  Scripter"
Footer.TextColor3 = C.TextMuted
Footer.TextSize = 11
Footer.Font = Enum.Font.Gotham
Footer.LetterSpacing = 0.5
Footer.Parent = Card

local VersionLabel = Instance.new("TextLabel")
VersionLabel.Size = UDim2.new(0.8, 0, 0, 14)
VersionLabel.Position = UDim2.new(0.1, 0, 0, 430)
VersionLabel.BackgroundTransparency = 1
VersionLabel.Text = "v" .. LOADER_VERSION .. "  ·  FeatherHub"
VersionLabel.TextColor3 = Color3.fromRGB(50, 60, 80)
VersionLabel.TextSize = 10
VersionLabel.Font = Enum.Font.Gotham
VersionLabel.Parent = Card

-- ════════════════════════════════════════════════════════════════
-- ФУНКЦИИ
-- ════════════════════════════════════════════════════════════════

local SpinnerAngle = 0
local SpinnerConn = nil

local function StartSpinner()
    SpinnerHolder.Visible = true
    StatusDot.Visible = true
    Tween(StatusDot, { BackgroundColor3 = C.Accent }, TI.Quick)
    SpinnerConn = RunService.Heartbeat:Connect(function(dt)
        SpinnerAngle = SpinnerAngle + dt * 360
        SpinnerArc.Rotation = SpinnerAngle % 360
    end)
end

local function StopSpinner()
    SpinnerHolder.Visible = false
    if SpinnerConn then SpinnerConn:Disconnect(); SpinnerConn = nil end
end

local function SetStatus(Text, Color)
    StatusLabel.Text = Text
    StatusLabel.TextColor3 = Color or C.TextDim
    if Color then
        Tween(StatusDot, { BackgroundColor3 = Color }, TI.Quick)
        StatusDot.Visible = true
    else
        StatusDot.Visible = false
    end
end

local function LoadScript()
    -- Анимация исчезновения
    Tween(Card, { BackgroundTransparency = 1, Size = UDim2.new(0, 380, 0, 0) }, TweenInfo.new(0.4, Enum.EasingStyle.Quad))
    Tween(Overlay, { BackgroundTransparency = 1 }, TweenInfo.new(0.3, Enum.EasingStyle.Quad))
    task.wait(0.4)
    Gui:Destroy()
    task.wait(0.2)
    local Ok, Err = pcall(function() loadstring(game:HttpGet(SCRIPT_URL))() end)
    if not Ok then warn("[FeatherHub] Ошибка загрузки: " .. tostring(Err)) end
end

-- ════════════════════════════════════════════════════════════════
-- ОБРАБОТЧИКИ
-- ════════════════════════════════════════════════════════════════

VerifyBtn.MouseButton1Click:Connect(function()
    local Key = KeyBox.Text:gsub("%s+", "")
    if Key == "" then
        SetStatus("Введите ключ доступа", C.Error)
        -- Тряска
        for i = 1, 4 do
            Tween(KeyBox, { Position = UDim2.new(0.1 + (i % 2 == 0 and -0.015 or 0.015), 0, 0, 190) }, TweenInfo.new(0.06))
            task.wait(0.06)
        end
        Tween(KeyBox, { Position = UDim2.new(0.1, 0, 0, 190) }, TI.Quick)
        return
    end

    VerifyBtn.Active = false
    VerifyBtn.Text = ""
    Tween(VerifyBtn, { BackgroundColor3 = C.InputBorder, Size = UDim2.new(0.8, 0, 0, 48) }, TI.Quick)
    StartSpinner()
    SetStatus("Проверка ключа...", C.Accent)

    task.spawn(function()
        local Ok, Msg = VerifyKey(Key)
        StopSpinner()
        VerifyBtn.Active = true

        if Ok then
            VerifyBtn.Text = "OK"
            Tween(VerifyBtn, { BackgroundColor3 = C.Success }, TI.Smooth)
            SetStatus(Msg, C.Success)
            task.wait(0.8)
            LoadScript()
        else
            VerifyBtn.Text = "Подтвердить"
            Tween(VerifyBtn, { BackgroundColor3 = C.Accent }, TI.Smooth)
            SetStatus(Msg, C.Error)
            -- Тряска поля
            for i = 1, 4 do
                Tween(KeyBox, { Position = UDim2.new(0.1 + (i % 2 == 0 and -0.015 or 0.015), 0, 0, 190) }, TweenInfo.new(0.06))
                task.wait(0.06)
            end
            Tween(KeyBox, { Position = UDim2.new(0.1, 0, 0, 190) }, TI.Quick)
            -- Мигание бордера красным
            Tween(KeyBoxStroke, { Color = C.Error }, TI.Quick)
            task.wait(0.5)
            Tween(KeyBoxStroke, { Color = C.InputBorder }, TI.Smooth)
        end
    end)
end)

GetKeyBtn.MouseButton1Click:Connect(function()
    local Copy = type(setclipboard) == "function" and setclipboard or toclipboard
    if type(Copy) == "function" then
        pcall(Copy, KEYS_URL)
        SetStatus("Ссылка на ключи скопирована!", C.Success)
    else
        SetStatus(KEYS_URL, C.Accent)
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

-- ════════════════════════════════════════════════════════════════
-- АНИМАЦИЯ ПОЯВЛЕНИЯ
-- ════════════════════════════════════════════════════════════════

-- Начальное состояние — скрыто
Card.Position = UDim2.new(0.5, -200, 0.5, -200)
Card.BackgroundTransparency = 1
Overlay.BackgroundTransparency = 1

task.spawn(function()
    task.wait(0.1)
    -- Фон
    Tween(Overlay, { BackgroundTransparency = 0.55 }, TweenInfo.new(0.5, Enum.EasingStyle.Quad))
    task.wait(0.1)
    -- Карточка — появление
    Card.BackgroundTransparency = 0
    Tween(Card, { Position = UDim2.new(0.5, -200, 0.5, -230) }, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
    task.wait(0.15)
    -- Полоска
    Tween(AccentBar, { Size = UDim2.new(0.6, 0, 0, 3) }, TweenInfo.new(0.4, Enum.EasingStyle.Quad))
    task.wait(0.1)
    -- Иконка
    IconBg.BackgroundTransparency = 0.85
    Tween(FeatherIcon, { TextSize = 28 }, TI.Spring)
    task.wait(0.1)
    -- Заголовок
    Tween(Title, { TextTransparency = 0 }, TI.Smooth)
    Tween(Subtitle, { TextTransparency = 0 }, TI.Smooth)
    task.wait(0.15)
    -- Поле ввода
    Tween(KeyBox, { BackgroundTransparency = 0 }, TI.Smooth)
    task.wait(0.1)
    -- Кнопки
    Tween(VerifyBtn, { BackgroundTransparency = 0 }, TI.Smooth)
    Tween(GetKeyBtn, { BackgroundTransparency = 0 }, TI.Smooth)
end)

-- Пульсация свечения карточки
task.spawn(function()
    while Card and Card.Parent do
        Tween(GlowStroke, { Thickness = 2, Transparency = 0.85 }, TweenInfo.new(2, Enum.EasingStyle.Sine))
        task.wait(2)
        Tween(GlowStroke, { Thickness = 0, Transparency = 0.7 }, TweenInfo.new(2, Enum.EasingStyle.Sine))
        task.wait(2)
    end
end)

print("[FeatherHub] Loader ready.")
