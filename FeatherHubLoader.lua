-- FeatherHub Loader (KeyAuth Key System)
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/Featheroff/FeatherHub/main/FeatherHubLoader.lua"))()

-- ════════════════════════════════════════════════════════════════
-- КОНФИГУРАЦИЯ — ЗАМЕНИ НА СВОИ ДАННЫЕ KeyAuth
-- ════════════════════════════════════════════════════════════════
local CONFIG = {
    ScriptURL    = "https://raw.githubusercontent.com/Featheroff/FeatherHub/main/FeatherHub.lua",
    KeyAuthName  = "FeatherHUB - Loader",    -- Имя приложения в KeyAuth
    KeyAuthOwner = "l7G7j8LbHP",           -- Твой Owner ID
    KeyAuthVer   = "1.0",                  -- Версия (должна совпадать с версией в KeyAuth)
    Linkvertise  = "https://link-to.net/YOUR_ID",  -- Замени на свою ссылку Linkvertise
}
-- ════════════════════════════════════════════════════════════════

local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

-- ════════════════════════════════════════════════════════════════
-- KEYAUTH API
-- ════════════════════════════════════════════════════════════════
local KA_URL = "https://keyauth.win/api/1.2/"
local Session = nil

local function Encode(data)
    local parts = {}
    for k, v in pairs(data) do
        table.insert(parts, HttpService:UrlEncode(tostring(k)) .. "=" .. HttpService:UrlEncode(tostring(v)))
    end
    return table.concat(parts, "&")
end

local function Decode(json)
    local ok, result = pcall(HttpService.JSONDecode, HttpService, json)
    if ok then return result end
    return nil
end

-- Инициализация приложения
local function InitKeyAuth(StatusLabel)
    local body = Encode({
        type = "init",
        ver = CONFIG.KeyAuthVer,
        name = CONFIG.KeyAuthName,
        ownerid = CONFIG.KeyAuthOwner,
    })

    local ok, response = pcall(function()
        return game:HttpPost({
            Url = KA_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/x-www-form-urlencoded"},
            Body = body,
        })
    end)

    if not ok or not response then
        StatusLabel.Text = "Ошибка подключения к серверу"
        StatusLabel.TextColor3 = Color3.fromRGB(248, 113, 113)
        return false
    end

    local data = Decode(response)
    if not data then
        StatusLabel.Text = "Ошибка сервера (неверный ответ)"
        StatusLabel.TextColor3 = Color3.fromRGB(248, 113, 113)
        return false
    end

    if data.success then
        Session = data.sessionid
        print("[FeatherHub] KeyAuth инициализирован. Сессия: " .. Session)
        return true
    else
        StatusLabel.Text = "Ошибка: " .. (data.message or "неизвестная")
        StatusLabel.TextColor3 = Color3.fromRGB(248, 113, 113)
        print("[FeatherHub] KeyAuth init failed: " .. tostring(data.message))
        return false
    end
end

-- Проверка лицензионного ключа
local function VerifyKey(key, StatusLabel)
    if not Session then
        StatusLabel.Text = "Сервер не инициализирован"
        StatusLabel.TextColor3 = Color3.fromRGB(248, 113, 113)
        return false
    end

    local body = Encode({
        type = "license",
        key = key,
        sessionid = Session,
        name = CONFIG.KeyAuthName,
        ownerid = CONFIG.KeyAuthOwner,
    })

    local ok, response = pcall(function()
        return game:HttpPost({
            Url = KA_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/x-www-form-urlencoded"},
            Body = body,
        })
    end)

    if not ok or not response then
        StatusLabel.Text = "Ошибка сети"
        StatusLabel.TextColor3 = Color3.fromRGB(248, 113, 113)
        return false
    end

    local data = Decode(response)
    if not data then
        StatusLabel.Text = "Ошибка сервера"
        StatusLabel.TextColor3 = Color3.fromRGB(248, 113, 113)
        return false
    end

    if data.success then
        print("[FeatherHub] Ключ подтверждён!")
        if data.info then
            print("[FeatherHub] Подписка: " .. tostring(data.info.subscriptions and data.info.subscriptions[1] and data.info.subscriptions[1].subscription or "N/A"))
        end
        return true
    else
        local msg = data.message or "Неверный ключ"
        -- Переводим частые ошибки
        if msg:find("Key not found") or msg:find("does not exist") then
            msg = "Ключ не найден"
        elseif msg:find("expired") then
            msg = "Срок действия ключа истёк"
        elseif msg:find("banned") then
            msg = "Ключ заблокирован"
        end
        StatusLabel.Text = msg
        StatusLabel.TextColor3 = Color3.fromRGB(248, 113, 113)
        return false
    end
end

-- ════════════════════════════════════════════════════════════════
-- СОЗДАНИЕ GUI
-- ════════════════════════════════════════════════════════════════

-- Удаляем старый лоадер если есть
local old = CoreGui:FindFirstChild("FeatherHubLoader")
if old then old:Destroy() end

local Gui = Instance.new("ScreenGui")
Gui.Name = "FeatherHubLoader"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = CoreGui

-- Карточка
local Card = Instance.new("Frame")
Card.Size = UDim2.new(0, 400, 0, 480)
Card.Position = UDim2.new(0.5, -200, 0.5, -240)
Card.BackgroundColor3 = Color3.fromRGB(14, 20, 36)
Card.BorderSizePixel = 0
Card.Parent = Gui

Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 12)

local CardStroke = Instance.new("UIStroke", Card)
CardStroke.Color = Color3.fromRGB(45, 64, 91)
CardStroke.Thickness = 2

-- Иконка
local IconHolder = Instance.new("Frame")
IconHolder.Size = UDim2.new(0, 60, 0, 60)
IconHolder.Position = UDim2.new(0.5, -30, 0, 25)
IconHolder.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
IconHolder.BorderSizePixel = 0
IconHolder.Parent = Card

Instance.new("UICorner", IconHolder).CornerRadius = UDim.new(1, 0)

local IconStroke = Instance.new("UIStroke", IconHolder)
IconStroke.Color = Color3.fromRGB(125, 211, 252)
IconStroke.Thickness = 2

local IconGrad = Instance.new("UIGradient", IconHolder)
IconGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(125, 211, 252)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(59, 130, 246)),
})
IconGrad.Rotation = 45

local FeatherIcon = Instance.new("TextLabel")
FeatherIcon.Size = UDim2.new(1, 0, 1, 0)
FeatherIcon.BackgroundTransparency = 1
FeatherIcon.Text = "F"
FeatherIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
FeatherIcon.TextSize = 28
FeatherIcon.Font = Enum.Font.GothamBold
FeatherIcon.Parent = IconHolder

-- Заголовок
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.Position = UDim2.new(0, 0, 0, 95)
Title.BackgroundTransparency = 1
Title.Text = "FeatherHub"
Title.TextColor3 = Color3.fromRGB(125, 211, 252)
Title.TextSize = 28
Title.Font = Enum.Font.GothamBold
Title.Parent = Card

local Subtitle = Instance.new("TextLabel")
Subtitle.Size = UDim2.new(1, 0, 0, 20)
Subtitle.Position = UDim2.new(0, 0, 0, 125)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "Key System"
Subtitle.TextColor3 = Color3.fromRGB(148, 163, 184)
Subtitle.TextSize = 14
Subtitle.Font = Enum.Font.Gotham
Subtitle.Parent = Card

-- Поле ввода ключа
local KeyBox = Instance.new("TextBox")
KeyBox.Size = UDim2.new(0.8, 0, 0, 40)
KeyBox.Position = UDim2.new(0.1, 0, 0, 165)
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
StatusLabel.Size = UDim2.new(0.8, 0, 0, 25)
StatusLabel.Position = UDim2.new(0.1, 0, 0, 215)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = ""
StatusLabel.TextColor3 = Color3.fromRGB(248, 113, 113)
StatusLabel.TextSize = 13
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.Parent = Card

-- Кнопка подтверждения
local VerifyBtn = Instance.new("TextButton")
VerifyBtn.Size = UDim2.new(0.8, 0, 0, 45)
VerifyBtn.Position = UDim2.new(0.1, 0, 0, 250)
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
GetKeyBtn.Position = UDim2.new(0.1, 0, 0, 310)
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
HintLabel.Position = UDim2.new(0.1, 0, 0, 355)
HintLabel.BackgroundTransparency = 1
HintLabel.Text = "Пройди Linkvertise → получи ключ"
HintLabel.TextColor3 = Color3.fromRGB(100, 116, 139)
HintLabel.TextSize = 12
HintLabel.Font = Enum.Font.Gotham
HintLabel.Parent = Card

-- Футер
local Footer = Instance.new("TextLabel")
Footer.Size = UDim2.new(1, 0, 0, 20)
Footer.Position = UDim2.new(0, 0, 0, 450)
Footer.BackgroundTransparency = 1
Footer.Text = "Feather · Scripter"
Footer.TextColor3 = Color3.fromRGB(100, 116, 139)
Footer.TextSize = 12
Footer.Font = Enum.Font.Gotham
Footer.Parent = Card

-- ════════════════════════════════════════════════════════════════
-- ОБРАБОТЧИКИ КНОПОК
-- ════════════════════════════════════════════════════════════════

-- Функция подтверждения (вызывается из двух мест)
local function DoVerify()
    if not Session then
        StatusLabel.Text = "Сервер не подключён"
        StatusLabel.TextColor3 = Color3.fromRGB(248, 113, 113)
        return
    end

    local key = KeyBox.Text:gsub("%s+", "")
    if key == "" then
        StatusLabel.Text = "Введите ключ"
        StatusLabel.TextColor3 = Color3.fromRGB(248, 113, 113)
        return
    end

    -- Показываем загрузку
    VerifyBtn.Text = "Проверка..."
    VerifyBtn.BackgroundColor3 = Color3.fromRGB(100, 116, 139)
    VerifyBtn.AutoButtonColor = false

    local success = VerifyKey(key, StatusLabel)

    if success then
        StatusLabel.Text = "Ключ подтверждён! Загрузка..."
        StatusLabel.TextColor3 = Color3.fromRGB(74, 222, 128)
        VerifyBtn.BackgroundColor3 = Color3.fromRGB(74, 222, 128)
        task.wait(1.5)
        Gui:Destroy()
        loadstring(game:HttpGet(CONFIG.ScriptURL))()
    else
        VerifyBtn.Text = "Подтвердить"
        VerifyBtn.BackgroundColor3 = Color3.fromRGB(125, 211, 252)
        VerifyBtn.AutoButtonColor = true
    end
end

-- Получить ключ — копируем ссылку Linkvertise
GetKeyBtn.MouseButton1Click:Connect(function()
    local url = CONFIG.Linkvertise
    local Copy = type(setclipboard) == "function" and setclipboard or toclipboard

    if type(Copy) == "function" then
        pcall(Copy, url)
        StatusLabel.Text = "Ссылка скопирована! Пройди оффер"
        StatusLabel.TextColor3 = Color3.fromRGB(125, 211, 252)
    else
        StatusLabel.Text = "Скопируй ссылку из чата"
        StatusLabel.TextColor3 = Color3.fromRGB(125, 211, 252)
        print("[FeatherHub] Linkvertise URL: " .. url)
    end

    -- Пытаемся открыть в браузере
    pcall(function()
        if game:GetService("GuiService"):GetGameplayBlocked() == false then
            -- Не работает в Roblox напрямую, но пробуем
        end
    end)
end)

-- Подтвердить ключ
VerifyBtn.MouseButton1Click:Connect(DoVerify)

-- Enter в поле ввода
KeyBox.FocusLost:Connect(function(entered)
    if entered then
        DoVerify()
    end
end)

-- Фокус на поле — убираем ошибку
KeyBox.Focused:Connect(function()
    if StatusLabel.TextColor3 == Color3.fromRGB(248, 113, 113) then
        StatusLabel.Text = ""
    end
end)

-- ════════════════════════════════════════════════════════════════
-- ИНИЦИАЛИЗАЦИЯ KeyAuth
-- ════════════════════════════════════════════════════════════════
task.spawn(function()
    StatusLabel.Text = "Подключение..."
    StatusLabel.TextColor3 = Color3.fromRGB(125, 211, 252)

    local ok = InitKeyAuth(StatusLabel)
    if ok then
        StatusLabel.Text = "Готово! Введи ключ"
        StatusLabel.TextColor3 = Color3.fromRGB(74, 222, 128)
        task.wait(2)
        StatusLabel.Text = ""
    end
end)

print("[FeatherHub] Loader with KeyAuth started.")
