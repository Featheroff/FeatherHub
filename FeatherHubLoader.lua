-- FeatherHub Loader (KeyAuth Key System)
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/Featheroff/FeatherHub/main/FeatherHubLoader.lua"))()

-- ════════════════════════════════════════════════════════════════
-- КОНФИГУРАЦИЯ
-- ════════════════════════════════════════════════════════════════
local CONFIG = {
    ScriptURL    = "https://raw.githubusercontent.com/Featheroff/FeatherHub/main/FeatherHub.lua",
    KeyAuthName  = "FeatherHUB - Loader",
    KeyAuthOwner = "l7G7j8LbHP",
    KeyAuthVer   = "1.0",
    Linkvertise  = "https://featherhub-keys.xyz-206.workers.dev",
}
-- ════════════════════════════════════════════════════════════════

local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Язык
local SharedEnv = type(getgenv) == "function" and getgenv() or _G
local Language = SharedEnv.FeatherHubLanguage
local PreferencePath = "RushHub/UserData.json"
if Language ~= "RU" and Language ~= "EN" then
    if type(isfile) == "function" and type(readfile) == "function" then
        pcall(function()
            if isfile(PreferencePath) then
                local Data = HttpService:JSONDecode(readfile(PreferencePath))
                if type(Data) == "table" then Language = Data.Language end
            end
        end)
    end
end
if Language ~= "RU" and Language ~= "EN" then
    local Locale = "en-us"
    pcall(function()
        local Player = game:GetService("Players").LocalPlayer
        Locale = Player and Player.LocaleId or game:GetService("LocalizationService").RobloxLocaleId
    end)
    Language = type(Locale) == "string" and Locale:lower():sub(1, 2) == "ru" and "RU" or "EN"
end
SharedEnv.FeatherHubLanguage = Language

-- Переводы
local English = {
    ["Исполнитель не поддерживает HTTP-запросы"] = "Your executor does not support HTTP requests",
    ["Ошибка подключения к KeyAuth"] = "Could not connect to KeyAuth",
    ["Приложение KeyAuth не найдено"] = "KeyAuth application not found",
    ["Неверный ответ KeyAuth"] = "Invalid response from KeyAuth",
    ["Не удалось создать сессию KeyAuth"] = "Could not start a KeyAuth session",
    ["Сервер не подключён"] = "Not connected to the server",
    ["Неверный ключ"] = "Invalid key",
    ["Сессия истекла. Нажми «Подтвердить» ещё раз"] = "Session expired. Click Verify again",
    ["Ошибка привязки устройства (HWID)"] = "Device binding error (HWID)",
    ["Ключ не найден"] = "Key not found",
    ["Срок действия ключа истёк"] = "Key has expired",
    ["Ключ заблокирован"] = "Key is blocked",
    ["Введите ключ..."] = "Enter your key...",
    ["Подтвердить"] = "Verify",
    ["Получить ключ"] = "Get key",
    ["Пройди Linkvertise → получи ключ"] = "Complete Linkvertise → get a key",
    ["Пока можно ввести имеющийся ключ KeyAuth"] = "You can enter an existing KeyAuth key",
    ["Введите ключ"] = "Enter your key",
    ["Проверка..."] = "Verifying...",
    ["Проверка ключа на сервере..."] = "Verifying your key on the server...",
    ["Ошибка проверки. Попробуй ещё раз"] = "Verification failed. Please try again",
    ["Ключ подтверждён! Загрузка..."] = "Key verified! Loading...",
    ["Не удалось загрузить FeatherHub. Повтори"] = "Could not load FeatherHub. Please try again",
    ["Сайт выдачи ключей ещё не подключён"] = "The key website is not connected yet",
    ["Ссылка на получение ключа скопирована"] = "Key link copied to clipboard",
    ["Ссылка выведена в консоль исполнителя"] = "Link printed to executor console",
    ["Подключение..."] = "Connecting...",
    ["Не удалось подключиться. Нажми «Подтвердить»"] = "Connection failed. Click Verify to retry",
    ["Готово! Введи ключ"] = "Ready! Enter your key",
    ["Создаём сессию..."] = "Creating session...",
    ["Не удалось создать сессию"] = "Could not create session",
    ["Ошибка сервера. Попробуй позже"] = "Server error. Try again later",
    ["Ссылка скопирована — открой в браузере"] = "Link copied — open in browser",
}
local Russian = {}
for RU, EN in pairs(English) do Russian[EN] = RU end
local function Canonical(Text)
    if Russian[Text] then return Russian[Text] end
    local Code = Text:match("^KeyAuth HTTP error (.+)$")
    if Code then return "Ошибка KeyAuth HTTP " .. Code end
    return Text
end
local function Translate(Text)
    Text = Canonical(Text)
    if Language == "RU" then return Text end
    local Code = Text:match("^Ошибка KeyAuth HTTP (.+)$")
    return English[Text] or (Code and ("KeyAuth HTTP error " .. Code)) or Text
end
local function SaveLanguage()
    SharedEnv.FeatherHubLanguage = Language
    if type(writefile) ~= "function" or type(isfile) ~= "function" or type(readfile) ~= "function" then return end
    pcall(function()
        local Data = {}
        if isfile(PreferencePath) then
            Data = HttpService:JSONDecode(readfile(PreferencePath))
            if type(Data) ~= "table" then return end
        elseif type(isfolder) == "function" and type(makefolder) == "function" then
            if not isfolder("RushHub") then makefolder("RushHub") end
        else return end
        Data.Language = Language
        writefile(PreferencePath, HttpService:JSONEncode(Data))
    end)
end

-- ════════════════════════════════════════════════════════════════
-- KEYAUTH API
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
    if not Send then return nil, "Исполнитель не поддерживает HTTP-запросы" end
    local ok, response = pcall(Send, {
        Url = KA_URL, Method = "POST",
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
    if response.Body == "KeyAuth_Invalid" then return nil, "Приложение KeyAuth не найдено" end
    local decoded, result = pcall(HttpService.JSONDecode, HttpService, response.Body)
    if not decoded or type(result) ~= "table" or type(result.success) ~= "boolean" then
        return nil, "Неверный ответ KeyAuth"
    end
    return result
end

local function SetStatus(StatusLabel, message, color)
    if not StatusLabel.Parent then return end
    StatusLabel.Text = message
    StatusLabel.TextColor3 = color or Color3.fromRGB(248, 113, 113)
end

local function InitKeyAuth(StatusLabel)
    if InitBusy then return false end
    InitBusy = true
    Session = nil
    local data, err = ApiRequest({
        type = "init", ver = CONFIG.KeyAuthVer, name = CONFIG.KeyAuthName,
        ownerid = CONFIG.KeyAuthOwner, enckey = HttpService:GenerateGUID(false):gsub("%-", ""),
    })
    InitBusy = false
    if not data then SetStatus(StatusLabel, err); return false end
    if data.success == true and type(data.sessionid) == "string" and data.sessionid ~= "" then
        Session = data.sessionid
        return true
    end
    SetStatus(StatusLabel, Translate("Не удалось создать сессию KeyAuth"))
    return false
end

local function VerifyKey(key, StatusLabel)
    if not Session then SetStatus(StatusLabel, Translate("Сервер не подключён")); return false end
    local params = {type = "license", key = key, sessionid = Session, name = CONFIG.KeyAuthName, ownerid = CONFIG.KeyAuthOwner}
    if type(gethwid) == "function" then
        local ok, hwid = pcall(gethwid)
        if ok and type(hwid) == "string" and hwid ~= "" then params.hwid = hwid end
    end
    local data, err = ApiRequest(params)
    if not data then SetStatus(StatusLabel, err); return false end
    if data.success == true then return true end
    local msg = tostring(data.message or "Неверный ключ")
    local lower = msg:lower()
    if lower:find("session", 1, true) then Session = nil; msg = "Сессия истекла. Нажми «Подтвердить» ещё раз"
    elseif lower:find("hwid", 1, true) then msg = "Ошибка привязки устройства (HWID)"
    elseif lower:find("key not found", 1, true) or lower:find("does not exist", 1, true) then msg = "Ключ не найден"
    elseif lower:find("expired", 1, true) then msg = "Срок действия ключа истёк"
    elseif lower:find("banned", 1, true) then msg = "Ключ заблокирован"
    else msg = "Неверный ключ" end
    SetStatus(StatusLabel, msg)
    return false
end

-- ════════════════════════════════════════════════════════════════
-- GUI
-- ════════════════════════════════════════════════════════════════
local old = CoreGui:FindFirstChild("FeatherHubLoader")
if old then old:Destroy() end

local Gui = Instance.new("ScreenGui")
Gui.Name = "FeatherHubLoader"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = CoreGui

-- Тень под карточкой
local ShadowHolder = Instance.new("Frame")
ShadowHolder.Size = UDim2.new(0, 420, 0, 500)
ShadowHolder.Position = UDim2.new(0.5, -210, 0.5, -250)
ShadowHolder.BackgroundTransparency = 1
ShadowHolder.ZIndex = 0
ShadowHolder.Parent = Gui

local Shadow = Instance.new("ImageLabel")
Shadow.Size = UDim2.new(1, 20, 1, 20)
Shadow.Position = UDim2.new(0, -10, 0, -10)
Shadow.BackgroundTransparency = 1
Shadow.Image = "rbxassetid://5554236805"
Shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
Shadow.ImageTransparency = 0.5
Shadow.ScaleType = Enum.ScaleType.Slice
Shadow.SliceCenter = Rect.new(23, 23, 277, 277)
Shadow.ZIndex = 0
Shadow.Parent = ShadowHolder

-- Карточка
local Card = Instance.new("Frame")
Card.Size = UDim2.new(0, 420, 0, 520)
Card.Position = UDim2.new(0.5, -210, 0.5, -260)
Card.BackgroundColor3 = Color3.fromRGB(30, 36, 56)
Card.BorderSizePixel = 0
Card.ClipsDescendants = true
Card.Parent = Gui

Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 20)

local CardStroke = Instance.new("UIStroke", Card)
CardStroke.Color = Color3.fromRGB(125, 211, 252)
CardStroke.Transparency = 0.5
CardStroke.Thickness = 1.5

-- Градиент карточки
local CardGrad = Instance.new("UIGradient", Card)
CardGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(38, 46, 72)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(30, 36, 56)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(24, 30, 48)),
})
CardGrad.Rotation = 135

-- Кнопки управления окном
local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Name = "MinimizeBtn"
MinimizeBtn.Size = UDim2.new(0, 28, 0, 28)
MinimizeBtn.Position = UDim2.new(1, -70, 0, 10)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(40, 50, 75)
MinimizeBtn.BackgroundTransparency = 0.2
MinimizeBtn.BorderSizePixel = 0
MinimizeBtn.Text = "—"
MinimizeBtn.TextColor3 = Color3.fromRGB(125, 211, 252)
MinimizeBtn.TextSize = 18
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.Parent = Card
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 6)
local MinStroke = Instance.new("UIStroke", MinimizeBtn)
MinStroke.Color = Color3.fromRGB(125, 211, 252)
MinStroke.Transparency = 0.4
MinStroke.Thickness = 1

local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "CloseBtn"
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -38, 0, 10)
CloseBtn.BackgroundColor3 = Color3.fromRGB(40, 50, 75)
CloseBtn.BackgroundTransparency = 0.2
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(248, 113, 113)
CloseBtn.TextSize = 14
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = Card
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)
local CloseStroke = Instance.new("UIStroke", CloseBtn)
CloseStroke.Color = Color3.fromRGB(248, 113, 113)
CloseStroke.Transparency = 0.5
CloseStroke.Thickness = 1

-- Кнопка языка
local LanguageBtn = Instance.new("TextButton")
LanguageBtn.Name = "LanguageSwitch"
LanguageBtn.Size = UDim2.new(0, 70, 0, 24)
LanguageBtn.Position = UDim2.new(1, -80, 0, 12)
LanguageBtn.BackgroundColor3 = Color3.fromRGB(40, 50, 75)
LanguageBtn.BackgroundTransparency = 0.2
LanguageBtn.BorderSizePixel = 0
LanguageBtn.Text = Language == "RU" and "RU / EN" or "ru / EN"
LanguageBtn.TextColor3 = Color3.fromRGB(125, 211, 252)
LanguageBtn.TextSize = 10
LanguageBtn.Font = Enum.Font.GothamBold
LanguageBtn.Parent = Card
Instance.new("UICorner", LanguageBtn).CornerRadius = UDim.new(0, 6)
local LangStroke = Instance.new("UIStroke", LanguageBtn)
LangStroke.Color = Color3.fromRGB(125, 211, 252)
LangStroke.Transparency = 0.5
LangStroke.Thickness = 1

-- Иконка с свечением
local IconGlow = Instance.new("Frame")
IconGlow.Size = UDim2.new(0, 90, 0, 90)
IconGlow.Position = UDim2.new(0.5, -45, 0, 15)
IconGlow.BackgroundColor3 = Color3.fromRGB(125, 211, 252)
IconGlow.BackgroundTransparency = 0.8
IconGlow.BorderSizePixel = 0
IconGlow.Parent = Card
Instance.new("UICorner", IconGlow).CornerRadius = UDim.new(1, 0)

local IconHolder = Instance.new("Frame")
IconHolder.Size = UDim2.new(0, 64, 0, 64)
IconHolder.Position = UDim2.new(0.5, -32, 0, 20)
IconHolder.BackgroundColor3 = Color3.fromRGB(40, 52, 80)
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
IconGrad.Rotation = 135

local FeatherIcon = Instance.new("TextLabel")
FeatherIcon.Size = UDim2.new(1, 0, 1, 0)
FeatherIcon.BackgroundTransparency = 1
FeatherIcon.Text = "F"
FeatherIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
FeatherIcon.TextSize = 30
FeatherIcon.Font = Enum.Font.GothamBold
FeatherIcon.Parent = IconHolder

-- Заголовок
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.Position = UDim2.new(0, 0, 0, 95)
Title.BackgroundTransparency = 1
Title.Text = "FeatherHub"
Title.TextColor3 = Color3.fromRGB(240, 245, 255)
Title.TextSize = 28
Title.Font = Enum.Font.GothamBold
Title.Parent = Card

local Subtitle = Instance.new("TextLabel")
Subtitle.Size = UDim2.new(1, 0, 0, 20)
Subtitle.Position = UDim2.new(0, 0, 0, 128)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "Key System"
Subtitle.TextColor3 = Color3.fromRGB(140, 155, 180)
Subtitle.TextSize = 13
Subtitle.Font = Enum.Font.Gotham
Subtitle.Parent = Card

-- Разделитель
local Divider = Instance.new("Frame")
Divider.Size = UDim2.new(0.75, 0, 0, 1)
Divider.Position = UDim2.new(0.125, 0, 0, 158)
Divider.BackgroundColor3 = Color3.fromRGB(125, 211, 252)
Divider.BackgroundTransparency = 0.7
Divider.BorderSizePixel = 0
Divider.Parent = Card

-- Поле ввода ключа
local KeyBox = Instance.new("TextBox")
KeyBox.Size = UDim2.new(0.8, 0, 0, 44)
KeyBox.Position = UDim2.new(0.1, 0, 0, 178)
KeyBox.BackgroundColor3 = Color3.fromRGB(35, 44, 68)
KeyBox.BackgroundTransparency = 0.15
KeyBox.BorderSizePixel = 0
KeyBox.PlaceholderText = Translate("Введите ключ...")
KeyBox.PlaceholderColor3 = Color3.fromRGB(100, 115, 140)
KeyBox.Text = ""
KeyBox.TextColor3 = Color3.fromRGB(240, 245, 255)
KeyBox.TextSize = 15
KeyBox.Font = Enum.Font.Gotham
KeyBox.ClearTextOnFocus = false
KeyBox.Parent = Card
Instance.new("UICorner", KeyBox).CornerRadius = UDim.new(0, 10)
local KeyBoxStroke = Instance.new("UIStroke", KeyBox)
KeyBoxStroke.Color = Color3.fromRGB(125, 211, 252)
KeyBoxStroke.Transparency = 0.6
KeyBoxStroke.Thickness = 1

-- Статус
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(0.8, 0, 0, 20)
StatusLabel.Position = UDim2.new(0.1, 0, 0, 232)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = ""
StatusLabel.TextColor3 = Color3.fromRGB(248, 113, 113)
StatusLabel.TextSize = 12
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.Parent = Card

-- Кнопка подтверждения
local VerifyBtn = Instance.new("TextButton")
VerifyBtn.Size = UDim2.new(0.8, 0, 0, 46)
VerifyBtn.Position = UDim2.new(0.1, 0, 0, 260)
VerifyBtn.BackgroundColor3 = Color3.fromRGB(125, 211, 252)
VerifyBtn.BorderSizePixel = 0
VerifyBtn.Text = Translate("Подтвердить")
VerifyBtn.TextColor3 = Color3.fromRGB(10, 15, 28)
VerifyBtn.TextSize = 16
VerifyBtn.Font = Enum.Font.GothamBold
VerifyBtn.AutoButtonColor = true
VerifyBtn.Parent = Card
Instance.new("UICorner", VerifyBtn).CornerRadius = UDim.new(0, 10)

-- Градиент кнопки подтверждения
local VerifyGrad = Instance.new("UIGradient", VerifyBtn)
VerifyGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(125, 211, 252)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(96, 165, 250)),
})
VerifyGrad.Rotation = 0

-- Кнопка получения ключа
local GetKeyBtn = Instance.new("TextButton")
GetKeyBtn.Size = UDim2.new(0.8, 0, 0, 40)
GetKeyBtn.Position = UDim2.new(0.1, 0, 0, 320)
GetKeyBtn.BackgroundColor3 = Color3.fromRGB(35, 44, 68)
GetKeyBtn.BackgroundTransparency = 0.15
GetKeyBtn.BorderSizePixel = 0
GetKeyBtn.Text = Translate("Получить ключ")
GetKeyBtn.TextColor3 = Color3.fromRGB(125, 211, 252)
GetKeyBtn.TextSize = 14
GetKeyBtn.Font = Enum.Font.GothamBold
GetKeyBtn.AutoButtonColor = true
GetKeyBtn.Parent = Card
Instance.new("UICorner", GetKeyBtn).CornerRadius = UDim.new(0, 10)
local GetKeyStroke = Instance.new("UIStroke", GetKeyBtn)
GetKeyStroke.Color = Color3.fromRGB(125, 211, 252)
GetKeyStroke.Transparency = 0.5
GetKeyStroke.Thickness = 1

-- Подсказка
local HintLabel = Instance.new("TextLabel")
HintLabel.Size = UDim2.new(0.8, 0, 0, 18)
HintLabel.Position = UDim2.new(0.1, 0, 0, 372)
HintLabel.BackgroundTransparency = 1
HintLabel.Text = CONFIG.Linkvertise ~= "" and Translate("Пройди Linkvertise → получи ключ") or Translate("Пока можно ввести имеющийся ключ KeyAuth")
HintLabel.TextColor3 = Color3.fromRGB(110, 125, 150)
HintLabel.TextSize = 11
HintLabel.Font = Enum.Font.Gotham
HintLabel.Parent = Card

-- Футер
local Footer = Instance.new("TextLabel")
Footer.Size = UDim2.new(1, 0, 0, 18)
Footer.Position = UDim2.new(0, 0, 0, 492)
Footer.BackgroundTransparency = 1
Footer.Text = "Feather · Scripter"
Footer.TextColor3 = Color3.fromRGB(90, 105, 130)
Footer.TextSize = 11
Footer.Font = Enum.Font.Gotham
Footer.Parent = Card

-- ════════════════════════════════════════════════════════════════
-- ПЕРЕВОД И ПРИВЯЗКИ
-- ════════════════════════════════════════════════════════════════
local Bindings = {}
local Connections = {}
local function RenderBinding(Object, State)
    if not Object.Parent then return end
    local Text = Translate(State.Source)
    State.Rendered = Text
    if Object[State.Property] ~= Text then Object[State.Property] = Text end
end
local function TrackText(Object)
    if Bindings[Object] then return end
    local Property
    if Object:IsA("TextBox") then Property = "PlaceholderText"
    elseif Object:IsA("TextLabel") or Object:IsA("TextButton") then Property = "Text"
    else return end
    local State = {Property = Property, Source = Canonical(Object[Property])}
    Bindings[Object] = State
    table.insert(Connections, Object:GetPropertyChangedSignal(Property):Connect(function()
        if Object[Property] == State.Rendered then return end
        State.Source = Canonical(Object[Property])
        RenderBinding(Object, State)
    end))
    RenderBinding(Object, State)
end
for _, Object in ipairs(Gui:GetDescendants()) do TrackText(Object) end
table.insert(Connections, Gui.DescendantAdded:Connect(TrackText))

LanguageBtn.MouseButton1Click:Connect(function()
    Language = Language == "RU" and "EN" or "RU"
    SaveLanguage()
    for Object, State in pairs(Bindings) do RenderBinding(Object, State) end
    LanguageBtn.Text = Language == "RU" and "RU / EN" or "ru / EN"
end)

Gui.Destroying:Connect(function()
    for _, c in ipairs(Connections) do c:Disconnect() end
    table.clear(Connections)
    table.clear(Bindings)
end)

-- ════════════════════════════════════════════════════════════════
-- АНИМАЦИЯ ПОЯВЛЕНИЯ
-- ════════════════════════════════════════════════════════════════

-- Начальное состояние — всё скрыто
local OriginalBg = {}
Card.BackgroundTransparency = 1
CardStroke.Transparency = 1

-- Скрываем тень
ShadowHolder.Position = UDim2.new(0.5, -210, 0.5, -200)
ShadowHolder.Size = UDim2.new(0, 100, 0, 100)

-- Скрываем все элементы карточки
for _, Desc in ipairs(Card:GetDescendants()) do
    if Desc:IsA("GuiObject") and Desc ~= Card then
        if Desc:IsA("TextLabel") or Desc:IsA("TextButton") or Desc:IsA("TextBox") then
            Desc.TextTransparency = 1
        end
        if Desc:IsA("Frame") or Desc:IsA("TextButton") or Desc:IsA("TextBox") or Desc:IsA("ImageLabel") then
            OriginalBg[Desc] = Desc.BackgroundTransparency
            Desc.BackgroundTransparency = 1
        end
        local Stroke = Desc:FindFirstChildOfClass("UIStroke")
        if Stroke then Stroke.Transparency = 1 end
    end
end

-- Запуск анимации
task.spawn(function()
    task.wait(0.1)

    -- Тень появляется первой
    TweenService:Create(ShadowHolder, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -210, 0.5, -260),
        Size = UDim2.new(0, 420, 0, 520)
    }):Play()
    TweenService:Create(Shadow, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        ImageTransparency = 0.5
    }):Play()

    task.wait(0.1)

    -- Карточка: появляется с увеличением (пружинный эффект)
    Card.Size = UDim2.new(0, 340, 0, 410)
    Card.Position = UDim2.new(0.5, -170, 0.5, -205)

    TweenService:Create(Card, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0), {
        BackgroundTransparency = 0,
        Size = UDim2.new(0, 420, 0, 520),
        Position = UDim2.new(0.5, -210, 0.5, -260)
    }):Play()

    TweenService:Create(CardStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Transparency = 0.7
    }):Play()

    -- Элементы появляются каскадом
    local Elements = {}
    for _, Desc in ipairs(Card:GetDescendants()) do
        if Desc:IsA("GuiObject") and Desc ~= Card then
            table.insert(Elements, Desc)
        end
    end

    for i, Desc in ipairs(Elements) do
        local Delay = 0.35 + (i / #Elements) * 0.6
        task.delay(Delay, function()
            if not Desc.Parent then return end
            local Tween = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

            if Desc:IsA("TextLabel") or Desc:IsA("TextButton") or Desc:IsA("TextBox") then
                TweenService:Create(Desc, Tween, {TextTransparency = 0}):Play()
            end
            if OriginalBg[Desc] ~= nil then
                TweenService:Create(Desc, Tween, {BackgroundTransparency = OriginalBg[Desc]}):Play()
            end
            local Stroke = Desc:FindFirstChildOfClass("UIStroke")
            if Stroke then
                TweenService:Create(Stroke, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = Stroke == CardStroke and 0.7 or 0}):Play()
            end
        end)
    end
end)

-- ════════════════════════════════════════════════════════════════
-- ОБРАБОТЧИКИ КНОПОК
-- ════════════════════════════════════════════════════════════════

local function DoVerify()
    if VerifyBusy or InitBusy or not Gui.Parent then return end
    local key = KeyBox.Text:gsub("%s+", "")
    if key == "" then SetStatus(StatusLabel, Translate("Введите ключ")); return end

    VerifyBusy = true
    VerifyBtn.Text = Translate("Проверка...")
    VerifyBtn.BackgroundColor3 = Color3.fromRGB(100, 116, 139)
    VerifyBtn.AutoButtonColor = false
    SetStatus(StatusLabel, Translate("Проверка ключа на сервере..."), Color3.fromRGB(125, 211, 252))

    local ran, success = pcall(function()
        if not Session and not InitKeyAuth(StatusLabel) then return false end
        return VerifyKey(key, StatusLabel)
    end)
    if not Gui.Parent then VerifyBusy = false; return end
    if not ran then InitBusy = false; SetStatus(StatusLabel, Translate("Ошибка проверки. Попробуй ещё раз")); success = false end

    if success == true then
        SetStatus(StatusLabel, Translate("Ключ подтверждён! Загрузка..."), Color3.fromRGB(74, 222, 128))
        VerifyBtn.BackgroundColor3 = Color3.fromRGB(74, 222, 128)
        local loaded, err = pcall(function()
            local source = game:HttpGet(CONFIG.ScriptURL)
            local chunk, compileError = loadstring(source)
            assert(chunk, compileError)
            chunk()
        end)
        if loaded then Gui:Destroy(); return end
        warn("[FeatherHub] " .. (Language == "RU" and "Ошибка загрузки скрипта: " or "Script load error: ") .. tostring(err))
        SetStatus(StatusLabel, Translate("Не удалось загрузить FeatherHub. Повтори"))
    end

    VerifyBusy = false
    VerifyBtn.Text = Translate("Подтвердить")
    VerifyBtn.BackgroundColor3 = Color3.fromRGB(125, 211, 252)
    VerifyBtn.AutoButtonColor = true
end

GetKeyBtn.MouseButton1Click:Connect(function()
    if VerifyBusy or InitBusy then return end
    local url = CONFIG.Linkvertise
    if type(url) ~= "string" or not url:match("^https://") or url:find("YOUR_ID", 1, true) then
        SetStatus(StatusLabel, Translate("Сайт выдачи ключей ещё не подключён"))
        return
    end

    -- Создаём тикет через API
    SetStatus(StatusLabel, Translate("Создаём сессию..."), Color3.fromRGB(125, 211, 252))
    GetKeyBtn.AutoButtonColor = false
    GetKeyBtn.Text = "..."

    local Send = GetRequest()
    if not Send then
        SetStatus(StatusLabel, Translate("Исполнитель не поддерживает HTTP-запросы"))
        GetKeyBtn.AutoButtonColor = true
        GetKeyBtn.Text = Translate("Получить ключ")
        return
    end

    local ok, response = pcall(Send, {
        Url = url .. "/ticket",
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode({hwid = type(gethwid) == "function" and (pcall(gethwid) and gethwid() or "") or "anonymous"}),
    })

    GetKeyBtn.AutoButtonColor = true
    GetKeyBtn.Text = Translate("Получить ключ")

    if not ok or type(response) ~= "table" or type(response.Body) ~= "string" then
        SetStatus(StatusLabel, Translate("Не удалось создать сессию"))
        return
    end

    local decoded, data = pcall(HttpService.JSONDecode, HttpService, response.Body)
    if not decoded or not data or data.ok ~= true or type(data.ticket) ~= "string" then
        SetStatus(StatusLabel, Translate("Ошибка сервера. Попробуй позже"))
        return
    end

    -- Открываем сайт с тикетом
    local fullUrl = url .. "/#ticket=" .. data.ticket
    local Copy = type(setclipboard) == "function" and setclipboard or toclipboard
    if type(Copy) == "function" then
        pcall(Copy, fullUrl)
        SetStatus(StatusLabel, Translate("Ссылка скопирована — открой в браузере"), Color3.fromRGB(125, 211, 252))
    else
        SetStatus(StatusLabel, fullUrl, Color3.fromRGB(125, 211, 252))
    end
    print("[FeatherHub] Key link: " .. fullUrl)
end)

VerifyBtn.MouseButton1Click:Connect(DoVerify)

-- Кнопка минимизации — сворачивает карточку
local Minimized = false
MinimizeBtn.MouseButton1Click:Connect(function()
    Minimized = not Minimized
    if Minimized then
        -- Сворачиваем: оставляем только заголовок и кнопки управления
        TweenService:Create(Card, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 420, 0, 60)
        }):Play()
        -- Скрываем все элементы кроме заголовка, иконки и кнопок управления
        for _, Desc in ipairs(Card:GetDescendants()) do
            if Desc:IsA("GuiObject") and Desc ~= Card and Desc ~= MinimizeBtn and Desc ~= CloseBtn and Desc ~= LanguageBtn and Desc ~= IconGlow and Desc ~= IconHolder and Desc ~= FeatherIcon and Desc ~= Title and Desc ~= Subtitle then
                if Desc:IsA("TextLabel") or Desc:IsA("TextButton") or Desc:IsA("TextBox") then
                    TweenService:Create(Desc, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
                end
                if Desc:IsA("Frame") or Desc:IsA("TextButton") or Desc:IsA("TextBox") then
                    TweenService:Create(Desc, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
                end
                local Stroke = Desc:FindFirstChildOfClass("UIStroke")
                if Stroke then TweenService:Create(Stroke, TweenInfo.new(0.2), {Transparency = 1}):Play() end
                local Grad = Desc:FindFirstChildOfClass("UIGradient")
                if Grad then TweenService:Create(Grad, TweenInfo.new(0.2), {Transparency = 1}):Play() end
            end
        end
        MinimizeBtn.Text = "□"
    else
        -- Разворачиваем
        TweenService:Create(Card, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 420, 0, 520)
        }):Play()
        -- Показываем все элементы
        for _, Desc in ipairs(Card:GetDescendants()) do
            if Desc:IsA("GuiObject") and Desc ~= Card then
                if Desc:IsA("TextLabel") or Desc:IsA("TextButton") or Desc:IsA("TextBox") then
                    TweenService:Create(Desc, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
                end
                local OrigTransparency = OriginalBg[Desc]
                if OrigTransparency ~= nil then
                    TweenService:Create(Desc, TweenInfo.new(0.3), {BackgroundTransparency = OrigTransparency}):Play()
                end
                local Stroke = Desc:FindFirstChildOfClass("UIStroke")
                if Stroke then
                    local TargetTransparency = Stroke == CardStroke and 0.7 or (Stroke == LangStroke or Stroke == MinStroke) and 0.5 or Stroke == CloseStroke and 0.5 or 0
                    TweenService:Create(Stroke, TweenInfo.new(0.3), {Transparency = TargetTransparency}):Play()
                end
                local Grad = Desc:FindFirstChildOfClass("UIGradient")
                if Grad then TweenService:Create(Grad, TweenInfo.new(0.3), {Transparency = 0}):Play() end
            end
        end
        MinimizeBtn.Text = "—"
    end
end)

-- Кнопка закрытия — полностью удаляет GUI
CloseBtn.MouseButton1Click:Connect(function()
    TweenService:Create(Card, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 100, 0, 100),
        Position = UDim2.new(0.5, -50, 0.5, -50)
    }):Play()
    TweenService:Create(CardStroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
    task.delay(0.3, function()
        if Gui and Gui.Parent then Gui:Destroy() end
    end)
end)

KeyBox.FocusLost:Connect(function(entered)
    if entered then DoVerify() end
end)

KeyBox.Focused:Connect(function()
    if StatusLabel.TextColor3 == Color3.fromRGB(248, 113, 113) then StatusLabel.Text = "" end
end)

-- Hover эффекты кнопок
local function HoverEffect(Button, OriginalColor, OriginalTransparency)
    Button.MouseEnter:Connect(function()
        if Button.AutoButtonColor == false then return end
        TweenService:Create(Button, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            BackgroundColor3 = Color3.new(
                math.min(OriginalColor.R + 0.08, 1),
                math.min(OriginalColor.G + 0.08, 1),
                math.min(OriginalColor.B + 0.08, 1)
            ),
            BackgroundTransparency = math.max(OriginalTransparency - 0.1, 0)
        }):Play()
    end)
    Button.MouseLeave:Connect(function()
        if Button.AutoButtonColor == false then return end
        TweenService:Create(Button, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            BackgroundColor3 = OriginalColor,
            BackgroundTransparency = OriginalTransparency
        }):Play()
    end)
end

HoverEffect(VerifyBtn, Color3.fromRGB(125, 211, 252), 0)
HoverEffect(GetKeyBtn, Color3.fromRGB(35, 44, 68), 0.15)
HoverEffect(LanguageBtn, Color3.fromRGB(40, 50, 75), 0.2)
HoverEffect(MinimizeBtn, Color3.fromRGB(40, 50, 75), 0.2)
HoverEffect(CloseBtn, Color3.fromRGB(40, 50, 75), 0.2)

-- ════════════════════════════════════════════════════════════════
-- ИНИЦИАЛИЗАЦИЯ KEYAUTH
-- ════════════════════════════════════════════════════════════════
task.spawn(function()
    task.wait(1.2) -- Ждём окончания анимации
    SetStatus(StatusLabel, Translate("Подключение..."), Color3.fromRGB(125, 211, 252))
    local ran, ok = pcall(InitKeyAuth, StatusLabel)
    if not ran then
        InitBusy = false
        SetStatus(StatusLabel, Translate("Не удалось подключиться. Нажми «Подтвердить»"))
        return
    end
    if ok and StatusLabel.Parent and not VerifyBusy then
        SetStatus(StatusLabel, Translate("Готово! Введи ключ"), Color3.fromRGB(74, 222, 128))
    end
end)

print("[FeatherHub] Loader started.")
