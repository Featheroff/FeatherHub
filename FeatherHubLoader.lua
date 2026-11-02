-- FeatherHub Loader с KeyAuth системой ключей
-- Документация: https://docs.keyauth.cc/api/getting-started/initialization

-- ════════════════════════════════════════════════════════════════
-- НАСТРОЙКИ KEYAUTH
-- ════════════════════════════════════════════════════════════════

-- URL основного скрипта (замени на свой после загрузки)
local SCRIPT_URL = "https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/FeatherHub.lua"

-- KeyAuth настройки (возьми из https://keyauth.cc/app/?page=manage-apps)
local KEYAUTH_APP_NAME = "FeatherHUB - Loader"  -- Application Name
local KEYAUTH_OWNER_ID = "l7G7j8LbHP"        -- Account Owner ID (10 символов)
local KEYAUTH_VERSION = "1.0"                    -- Application Version

-- ════════════════════════════════════════════════════════════════
-- СЕРВИСЫ
-- ════════════════════════════════════════════════════════════════

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- ════════════════════════════════════════════════════════════════
-- KEYAUTH API 1.3
-- ════════════════════════════════════════════════════════════════

local KEYAUTH_API_URL = "https://keyauth.win/api/1.3/"
local SessionId = nil
local HWID = tostring(LocalPlayer.UserId) -- Используем UserId как HWID

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

    if not Success then
        return nil, "Ошибка соединения с KeyAuth"
    end

    local ParseSuccess, JsonData = pcall(function()
        return HttpService:JSONDecode(Response)
    end)

    if not ParseSuccess then
        return nil, "Ошибка парсинга ответа KeyAuth"
    end

    return JsonData, nil
end

local function KeyAuthInit()
    local Data, Error = KeyAuthRequest({
        type = "init",
        ver = KEYAUTH_VERSION
    })

    if not Data then
        return false, Error
    end

    if Data.success then
        SessionId = Data.sessionid
        return true, "Инициализация успешна"
    else
        return false, Data.message or "Ошибка инициализации"
    end
end

local function KeyAuthLicense(Key)
    if not SessionId then
        return false, "Сессия не инициализирована"
    end

    local Data, Error = KeyAuthRequest({
        type = "license",
        key = Key,
        hwid = HWID,
        sessionid = SessionId
    })

    if not Data then
        return false, Error
    end

    if Data.success then
        return true, Data.message or "Ключ подтверждён"
    else
        return false, Data.message or "Неверный ключ"
    end
end

-- ════════════════════════════════════════════════════════════════
-- UI БИБЛИОТЕКА (упрощённая для лоадера)
-- ════════════════════════════════════════════════════════════════

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FeatherHubLoader"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = game:GetService("CoreGui")

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 400, 0, 300)
MainFrame.Position = UDim2.new(0.5, -200, 0.5, -150)
MainFrame.BackgroundColor3 = Color3.fromRGB(16, 24, 39)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(45, 64, 91)
UIStroke.Thickness = 2
UIStroke.Parent = MainFrame

-- Заголовок
local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, 0, 0, 50)
Title.Position = UDim2.new(0, 0, 0, 20)
Title.BackgroundTransparency = 1
Title.Text = "FeatherHub"
Title.TextColor3 = Color3.fromRGB(125, 211, 252)
Title.TextSize = 28
Title.Font = Enum.Font.GothamBold
Title.Parent = MainFrame

local Subtitle = Instance.new("TextLabel")
Subtitle.Name = "Subtitle"
Subtitle.Size = UDim2.new(1, 0, 0, 20)
Subtitle.Position = UDim2.new(0, 0, 0, 55)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "Key System"
Subtitle.TextColor3 = Color3.fromRGB(148, 163, 184)
Subtitle.TextSize = 14
Subtitle.Font = Enum.Font.Gotham
Subtitle.Parent = MainFrame

-- Поле ввода ключа
local KeyBox = Instance.new("TextBox")
KeyBox.Name = "KeyBox"
KeyBox.Size = UDim2.new(0.8, 0, 0, 40)
KeyBox.Position = UDim2.new(0.1, 0, 0, 100)
KeyBox.BackgroundColor3 = Color3.fromRGB(24, 34, 53)
KeyBox.BorderSizePixel = 0
KeyBox.PlaceholderText = "Введите ключ доступа..."
KeyBox.PlaceholderColor3 = Color3.fromRGB(100, 116, 139)
KeyBox.Text = ""
KeyBox.TextColor3 = Color3.fromRGB(231, 237, 247)
KeyBox.TextSize = 16
KeyBox.Font = Enum.Font.Gotham
KeyBox.ClearTextOnFocus = false
KeyBox.Parent = MainFrame

local KeyBoxCorner = Instance.new("UICorner")
KeyBoxCorner.CornerRadius = UDim.new(0, 8)
KeyBoxCorner.Parent = KeyBox

local KeyBoxStroke = Instance.new("UIStroke")
KeyBoxStroke.Color = Color3.fromRGB(45, 64, 91)
KeyBoxStroke.Thickness = 1
KeyBoxStroke.Parent = KeyBox

-- Статус
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "Status"
StatusLabel.Size = UDim2.new(0.8, 0, 0, 30)
StatusLabel.Position = UDim2.new(0.1, 0, 0, 150)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = ""
StatusLabel.TextColor3 = Color3.fromRGB(248, 113, 113)
StatusLabel.TextSize = 14
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.Parent = MainFrame

-- Кнопка подтверждения
local VerifyButton = Instance.new("TextButton")
VerifyButton.Name = "VerifyButton"
VerifyButton.Size = UDim2.new(0.8, 0, 0, 45)
VerifyButton.Position = UDim2.new(0.1, 0, 0, 200)
VerifyButton.BackgroundColor3 = Color3.fromRGB(125, 211, 252)
VerifyButton.BorderSizePixel = 0
VerifyButton.Text = "Подтвердить"
VerifyButton.TextColor3 = Color3.fromRGB(16, 24, 39)
VerifyButton.TextSize = 18
VerifyButton.Font = Enum.Font.GothamBold
VerifyButton.AutoButtonColor = true
VerifyButton.Parent = MainFrame

local ButtonCorner = Instance.new("UICorner")
ButtonCorner.CornerRadius = UDim.new(0, 8)
ButtonCorner.Parent = VerifyButton

-- Кнопка получения ключа
local GetKeyButton = Instance.new("TextButton")
GetKeyButton.Name = "GetKeyButton"
GetKeyButton.Size = UDim2.new(0.8, 0, 0, 35)
GetKeyButton.Position = UDim2.new(0.1, 0, 0, 255)
GetKeyButton.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
GetKeyButton.BorderSizePixel = 0
GetKeyButton.Text = "Получить ключ"
GetKeyButton.TextColor3 = Color3.fromRGB(125, 211, 252)
GetKeyButton.TextSize = 14
GetKeyButton.Font = Enum.Font.Gotham
GetKeyButton.AutoButtonColor = true
GetKeyButton.Parent = MainFrame

local GetKeyCorner = Instance.new("UICorner")
GetKeyCorner.CornerRadius = UDim.new(0, 8)
GetKeyCorner.Parent = GetKeyButton

local GetKeyStroke = Instance.new("UIStroke")
GetKeyStroke.Color = Color3.fromRGB(125, 211, 252)
GetKeyStroke.Thickness = 1
GetKeyStroke.Parent = GetKeyButton

-- ════════════════════════════════════════════════════════════════
-- ФУНКЦИИ ПРОВЕРКИ
-- ════════════════════════════════════════════════════════════════

local function SetStatus(Text, Color)
    StatusLabel.Text = Text
    StatusLabel.TextColor3 = Color or Color3.fromRGB(248, 113, 113)
end

local function CloseLoader()
    ScreenGui:Destroy()
end

local function LoadScript()
    CloseLoader()
    task.wait(0.3)
    
    local Success, Error = pcall(function()
        loadstring(game:HttpGet(SCRIPT_URL))()
    end)
    
    if not Success then
        warn("[FeatherHub] Ошибка загрузки скрипта: " .. tostring(Error))
        
        -- Показываем ошибку через CoreGui
        local ErrorGui = Instance.new("ScreenGui")
        ErrorGui.Name = "FeatherHubError"
        ErrorGui.Parent = game:GetService("CoreGui")
        
        local ErrorFrame = Instance.new("Frame")
        ErrorFrame.Size = UDim2.new(0, 400, 0, 150)
        ErrorFrame.Position = UDim2.new(0.5, -200, 0.5, -75)
        ErrorFrame.BackgroundColor3 = Color3.fromRGB(16, 24, 39)
        ErrorFrame.Parent = ErrorGui
        
        local ErrorCorner = Instance.new("UICorner")
        ErrorCorner.CornerRadius = UDim.new(0, 12)
        ErrorCorner.Parent = ErrorFrame
        
        local ErrorLabel = Instance.new("TextLabel")
        ErrorLabel.Size = UDim2.new(1, -40, 1, -40)
        ErrorLabel.Position = UDim2.new(0, 20, 0, 20)
        ErrorLabel.BackgroundTransparency = 1
        ErrorLabel.Text = "Ошибка загрузки FeatherHub:\n" .. tostring(Error)
        ErrorLabel.TextColor3 = Color3.fromRGB(248, 113, 113)
        ErrorLabel.TextSize = 14
        ErrorLabel.Font = Enum.Font.Gotham
        ErrorLabel.TextWrapped = true
        ErrorLabel.Parent = ErrorFrame
        
        game:GetService("Debris"):AddItem(ErrorGui, 10)
    end
end

-- ════════════════════════════════════════════════════════════════
-- KEYAUTH ПРОВЕРКА КЛЮЧА
-- ════════════════════════════════════════════════════════════════

local function VerifyKey(Key)
    if not Key or Key == "" then
        return false, "Введите ключ доступа"
    end
    
    -- Сначала инициализируем KeyAuth
    if not SessionId then
        SetStatus("Инициализация...", Color3.fromRGB(125, 211, 252))
        local InitSuccess, InitError = KeyAuthInit()
        
        if not InitSuccess then
            return false, InitError
        end
    end
    
    -- Проверяем ключ
    return KeyAuthLicense(Key)
end

-- ════════════════════════════════════════════════════════════════
-- ОБРАБОТЧИКИ КНОПОК
-- ════════════════════════════════════════════════════════════════

VerifyButton.MouseButton1Click:Connect(function()
    local Key = KeyBox.Text:gsub("%s+", "") -- Убираем пробелы
    
    SetStatus("Проверка...", Color3.fromRGB(125, 211, 252))
    VerifyButton.Active = false
    VerifyButton.BackgroundColor3 = Color3.fromRGB(100, 116, 139)
    
    -- Имитация загрузки для UX
    task.spawn(function()
        task.wait(0.5)
        
        local Success, Message = VerifyKey(Key)
        
        if Success then
            SetStatus(Message, Color3.fromRGB(74, 222, 128))
            task.wait(1)
            LoadScript()
        else
            SetStatus(Message, Color3.fromRGB(248, 113, 113))
            VerifyButton.Active = true
            VerifyButton.BackgroundColor3 = Color3.fromRGB(125, 211, 252)
            
            -- Анимация ошибки
            task.spawn(function()
                for i = 1, 3 do
                    KeyBox.BackgroundColor3 = Color3.fromRGB(127, 29, 29)
                    task.wait(0.1)
                    KeyBox.BackgroundColor3 = Color3.fromRGB(24, 34, 53)
                    task.wait(0.1)
                end
            end)
        end
    end)
end)

GetKeyButton.MouseButton1Click:Connect(function()
    -- Замени на свою ссылку для получения ключа
    local DISCORD_LINK = "https://discord.gg/TCkcAsPQpQ"
    
    local Success, CopyFunc = pcall(function()
        return setclipboard or toclipboard
    end)
    
    if Success and type(CopyFunc) == "function" then
        pcall(CopyFunc, DISCORD_LINK)
        SetStatus("Ссылка скопирована! Открой Discord", Color3.fromRGB(74, 222, 128))
    else
        SetStatus("Открой: " .. DISCORD_LINK, Color3.fromRGB(125, 211, 252))
    end
    
    -- Открываем ссылку в браузере (если возможно)
    pcall(function()
        if fireclicklabel then -- Некоторые эксплоиты поддерживают
            -- Невозможно открыть браузер напрямую, поэтому просто копируем
        end
    end)
end)

-- Enter для подтверждения
KeyBox.FocusLost:Connect(function(EnterPressed)
    if EnterPressed then
        VerifyButton:Fire()
    end
end)

-- ════════════════════════════════════════════════════════════════
-- ПЕРЕТАСКИВАНИЕ ОКНА
-- ════════════════════════════════════════════════════════════════

local Dragging, DragInput, DragStart, StartPos

local function UpdateInput(Input)
    local Delta = Input.Position - DragStart
    MainFrame.Position = UDim2.new(
        StartPos.X.Scale,
        StartPos.X.Offset + Delta.X,
        StartPos.Y.Scale,
        StartPos.Y.Offset + Delta.Y
    )
end

MainFrame.InputBegan:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
        Dragging = true
        DragStart = Input.Position
        StartPos = MainFrame.Position
        
        Input.Changed:Connect(function()
            if Input.UserInputState == Enum.UserInputState.End then
                Dragging = false
            end
        end)
    end
end)

MainFrame.InputChanged:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then
        DragInput = Input
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(Input)
    if Input == DragInput and Dragging then
        UpdateInput(Input)
    end
end)

-- ════════════════════════════════════════════════════════════════
-- АДАПТАЦИЯ ПОД МОБИЛЬНЫЕ УСТРОЙСТВА
-- ════════════════════════════════════════════════════════════════

if game:GetService("GuiService"):IsTenFootInterface() or game:GetService("UserInputService").TouchEnabled then
    -- Увеличиваем размер кнопок для мобильных
    KeyBox.Size = UDim2.new(0.9, 0, 0, 50)
    KeyBox.Position = UDim2.new(0.05, 0, 0, 100)
    KeyBox.TextSize = 20
    
    VerifyButton.Size = UDim2.new(0.9, 0, 0, 55)
    VerifyButton.Position = UDim2.new(0.05, 0, 0, 170)
    VerifyButton.TextSize = 22
    
    GetKeyButton.Size = UDim2.new(0.9, 0, 0, 45)
    GetKeyButton.Position = UDim2.new(0.05, 0, 0, 240)
    GetKeyButton.TextSize = 18
    
    MainFrame.Size = UDim2.new(0.9, 0, 0, 320)
    MainFrame.Position = UDim2.new(0.05, 0, 0.5, -160)
end

print("[FeatherHub] Loader загружен. Ожидание ввода ключа...")
