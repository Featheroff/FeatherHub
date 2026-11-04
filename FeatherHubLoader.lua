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
    Linkvertise  = "",                     -- Сайт выдачи ключей пока не подключён
}
-- ════════════════════════════════════════════════════════════════

local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

-- ════════════════════════════════════════════════════════════════
-- KEYAUTH API — КЛЮЧИ НЕ ГЕНЕРИРУЮТСЯ И НЕ ХРАНЯТСЯ В ЛОАДЕРЕ
-- ════════════════════════════════════════════════════════════════
local KA_URL = "https://keyauth.win/api/1.2/"
local Session = nil
local InitBusy = false
local VerifyBusy = false

local function Encode(data)
    local parts = {}
    for k, v in pairs(data) do
        table.insert(parts, HttpService:UrlEncode(tostring(k)) .. "=" .. HttpService:UrlEncode(tostring(v)))
    end
    return table.concat(parts, "&")
end

local function GetRequest()
    if type(request) == "function" then return request end
    if type(http_request) == "function" then return http_request end
    if type(syn) == "table" and type(syn.request) == "function" then return syn.request end
    if type(http) == "table" and type(http.request) == "function" then return http.request end
    return nil
end

local function ApiRequest(data)
    local Send = GetRequest()
    if not Send then
        return nil, "Исполнитель не поддерживает HTTP-запросы"
    end

    local ok, response = pcall(Send, {
        Url = KA_URL,
        Method = "POST",
        Headers = {["Content-Type"] = "application/x-www-form-urlencoded"},
        Body = Encode(data),
    })
    if not ok or type(response) ~= "table" or type(response.Body) ~= "string" then
        return nil, "Ошибка подключения к KeyAuth"
    end

    local status = tonumber(response.StatusCode)
    if not status or status < 200 or status >= 300 then
        return nil, "Ошибка KeyAuth HTTP " .. tostring(status or "?")
    end
    if response.Body == "KeyAuth_Invalid" then
        return nil, "Приложение KeyAuth не найдено"
    end

    local decoded, result = pcall(HttpService.JSONDecode, HttpService, response.Body)
    if not decoded or type(result) ~= "table" or type(result.success) ~= "boolean" then
        return nil, "Неверный ответ KeyAuth"
    end
    return result
end

local function SetError(StatusLabel, message)
    if not StatusLabel.Parent then return end
    StatusLabel.Text = message
    StatusLabel.TextColor3 = Color3.fromRGB(248, 113, 113)
end

local function InitKeyAuth(StatusLabel)
    if InitBusy then return false end
    InitBusy = true
    Session = nil
    local data, err = ApiRequest({
        type = "init",
        ver = CONFIG.KeyAuthVer,
        name = CONFIG.KeyAuthName,
        ownerid = CONFIG.KeyAuthOwner,
        enckey = HttpService:GenerateGUID(false):gsub("%-", ""),
    })
    InitBusy = false

    if not data then
        SetError(StatusLabel, err)
        return false
    end
    if data.success == true and type(data.sessionid) == "string" and data.sessionid ~= "" then
        Session = data.sessionid
        return true
    end
    SetError(StatusLabel, tostring(data.message or "Не удалось создать сессию KeyAuth"))
    return false
end

local function VerifyKey(key, StatusLabel)
    if not Session then
        SetError(StatusLabel, "Сервер не подключён")
        return false
    end

    local params = {
        type = "license",
        key = key,
        sessionid = Session,
        name = CONFIG.KeyAuthName,
        ownerid = CONFIG.KeyAuthOwner,
    }
    if type(gethwid) == "function" then
        local ok, hwid = pcall(gethwid)
        if ok and type(hwid) == "string" and hwid ~= "" then params.hwid = hwid end
    end

    local data, err = ApiRequest(params)
    if not data then
        SetError(StatusLabel, err)
        return false
    end
    if data.success == true then return true end

    local msg = tostring(data.message or "Неверный ключ")
    local lower = msg:lower()
    if lower:find("session", 1, true) then
        Session = nil
        msg = "Сессия истекла. Нажми «Подтвердить» ещё раз"
    elseif lower:find("hwid", 1, true) then
        msg = "Ошибка привязки устройства (HWID)"
    elseif lower:find("key not found", 1, true) or lower:find("does not exist", 1, true) then
        msg = "Ключ не найден"
    elseif lower:find("expired", 1, true) then
        msg = "Срок действия ключа истёк"
    elseif lower:find("banned", 1, true) then
        msg = "Ключ заблокирован"
    end
    SetError(StatusLabel, msg)
    return false
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
HintLabel.Text = CONFIG.Linkvertise ~= "" and "Пройди Linkvertise → получи ключ" or "Пока можно ввести имеющийся ключ KeyAuth"
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
    if VerifyBusy or InitBusy or not Gui.Parent then return end

    local key = KeyBox.Text:gsub("%s+", "")
    if key == "" then
        SetError(StatusLabel, "Введите ключ")
        return
    end

    VerifyBusy = true
    VerifyBtn.Text = "Проверка..."
    VerifyBtn.BackgroundColor3 = Color3.fromRGB(100, 116, 139)
    VerifyBtn.AutoButtonColor = false
    StatusLabel.Text = "Проверка ключа на сервере..."
    StatusLabel.TextColor3 = Color3.fromRGB(125, 211, 252)

    local ran, success = pcall(function()
        if not Session and not InitKeyAuth(StatusLabel) then return false end
        return VerifyKey(key, StatusLabel)
    end)
    if not Gui.Parent then
        VerifyBusy = false
        return
    end
    if not ran then
        InitBusy = false
        SetError(StatusLabel, "Ошибка проверки. Попробуй ещё раз")
        success = false
    end

    if success == true then
        StatusLabel.Text = "Ключ подтверждён! Загрузка..."
        StatusLabel.TextColor3 = Color3.fromRGB(74, 222, 128)
        VerifyBtn.BackgroundColor3 = Color3.fromRGB(74, 222, 128)
        local loaded, err = pcall(function()
            local source = game:HttpGet(CONFIG.ScriptURL)
            local chunk, compileError = loadstring(source)
            assert(chunk, compileError)
            chunk()
        end)
        if loaded then
            Gui:Destroy()
            return
        end
        warn("[FeatherHub] Ошибка загрузки скрипта: " .. tostring(err))
        SetError(StatusLabel, "Не удалось загрузить FeatherHub. Повтори")
    end

    VerifyBusy = false
    VerifyBtn.Text = "Подтвердить"
    VerifyBtn.BackgroundColor3 = Color3.fromRGB(125, 211, 252)
    VerifyBtn.AutoButtonColor = true
end

-- Ссылка станет доступна после подключения сайта выдачи ключей
GetKeyBtn.MouseButton1Click:Connect(function()
    if VerifyBusy or InitBusy then return end
    local url = CONFIG.Linkvertise
    if type(url) ~= "string" or not url:match("^https://") or url:find("YOUR_ID", 1, true) then
        SetError(StatusLabel, "Сайт выдачи ключей ещё не подключён")
        return
    end

    local Copy = type(setclipboard) == "function" and setclipboard or toclipboard
    if type(Copy) == "function" then
        local copied = pcall(Copy, url)
        if copied then
            StatusLabel.Text = "Ссылка на получение ключа скопирована"
            StatusLabel.TextColor3 = Color3.fromRGB(125, 211, 252)
            return
        end
    end
    StatusLabel.Text = "Ссылка выведена в консоль исполнителя"
    StatusLabel.TextColor3 = Color3.fromRGB(125, 211, 252)
    print("[FeatherHub] Получить ключ: " .. url)
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

    local ran, ok = pcall(InitKeyAuth, StatusLabel)
    if not ran then
        InitBusy = false
        SetError(StatusLabel, "Не удалось подключиться. Нажми «Подтвердить»")
        return
    end
    if ok and StatusLabel.Parent and not VerifyBusy then
        StatusLabel.Text = "Готово! Введи ключ"
        StatusLabel.TextColor3 = Color3.fromRGB(74, 222, 128)
    end
end)

print("[FeatherHub] Loader with KeyAuth started.")
