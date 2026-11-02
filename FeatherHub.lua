local LoadStart = tick()

if shared.FeatherHubLoaded or shared.RushHubLoaded then
    return
end
shared.FeatherHubLoaded = true
shared.RushHubLoaded = true

getgenv().FeatherHub = {
    Legit = true
}

-- ════════════════════════════════════════════════════════════════
-- ENVIRONMENT (inlined)
-- ════════════════════════════════════════════════════════════════
local Environment = {}
local Log = {}
local Tested = 0
local Failed = 0
local Passed = 0

local BrokenFeatures = {
    ["Volcano"] = {"run_on_actor", "oth"},
    ["Opiumware"] = {"gethiddenproperty"},
    ["Solara"] = {"require"},
    ["Xeno"] = {"require"},
}

local RootEnv = getfenv(0)

local function GetGlobal(Path)
    local Value = RootEnv
    while Value ~= nil and Path ~= "" do
        local Name, NextPath = string.match(Path, "^([^.]+)%.?(.*)$")
        Value = Value[Name]
        Path = NextPath
    end
    return Value
end

local Global = setmetatable({}, {
    __index = function(Self, Name)
        return GetGlobal(Name)
    end,
})

local EnvServices = setmetatable({}, {
    __index = function(Self, Name)
        return game:GetService(Name)
    end,
})

local Results = {}

local function AddResult(Name, Text, DidPass)
    table.insert(Results, Text)
    Log[Name] = { Passed = DidPass, Reason = Text }
end

Environment.Results = Results
Environment.PrintResults = function()
    local Executor = Environment.identifyexecutor and Environment.identifyexecutor() or "Неизвестно"
    print("Результаты проверки")
    for _, Result in ipairs(Results) do
        print(Result)
        task.wait()
    end
    print("Исполнитель — " .. Executor)
    print("Пройдено тестов: " .. Passed .. "/" .. Tested)
    print("Результат проверки: " .. math.floor((Passed / Tested) * 100 + 0.5) .. "%")
end

local function RunTest(Name, Test, InternalName)
    local TimedOut = false
    Tested = Tested + 1

    local ExecutorName = Global.identifyexecutor and Global.identifyexecutor() or "Неизвестно"
    local BrokenList = BrokenFeatures[ExecutorName]
    if BrokenList and table.find(BrokenList, Name) then
        AddResult(Name, "❌ " .. Name .. " — ошибка: тест пропущен", false)
        Failed = Failed + 1
        return
    end

    local TargetGlobal = Global[Name]
    if not TargetGlobal then
        AddResult(Name, "❌ " .. Name .. " — ошибка: функция отсутствует", false)
        Failed = Failed + 1
        return
    end

    local Time = 0
    local Finished = false

    task.spawn(function()
        local Success, Result = pcall(Test)
        if not TimedOut then
            if Success then
                local Key = InternalName or Name
                Environment[Key] = TargetGlobal
                AddResult(Name, "✅ " .. Name, true)
                Passed = Passed + 1
            else
                AddResult(Name, "❌ " .. Name .. " — ошибка: " .. tostring(Result), false)
                Failed = Failed + 1
            end
        end
        Finished = true
    end)

    while not Finished do
        Time = Time + 1
        if Time > 100 then
            AddResult(Name, "❌ " .. Name .. " — ошибка: время проверки истекло", false)
            Failed = Failed + 1
            TimedOut = true
            break
        end
        task.wait(0.1)
    end
end

RunTest("getgenv", function()
    assert(typeof(Global.getgenv()) == "table", "Не возвращена таблица")
    Global.getgenv().Example = "Test"
    assert(Example == "Test", "Не удалось задать глобальную переменную")
    Global.getgenv().Example = nil
end)

RunTest("getrenv", function()
    assert(Environment.getgenv, "Для проверки необходима getgenv")
    local Env = Global.getrenv()
    assert(typeof(Env) == "table", "Не возвращена таблица")
    assert(typeof(Env.print) == "function", "Не возвращена таблица окружения")
    assert(Global.getrenv ~= Global.getgenv, "getrenv является псевдонимом getgenv")
    assert(Global.getgenv() ~= Global.getrenv(), "Возвращено окружение исполнителя")
    local Success = pcall(function()
        return Env.loadstring([[return 10]])()
    end)
    assert(Success == false, "Вызов loadstring из окружения Roblox должен вызывать ошибку")
end)

RunTest("getgc", function()
    local TestFunction = function() return 10 end
    local TestTable = { Value = 10 }
    local YesTables = Global.getgc(true)
    local NoTables = Global.getgc(false)
    assert(table.find(YesTables, TestTable), "Не удалось найти таблицу")
    assert(table.find(YesTables, TestFunction), "Не удалось найти функцию")
    assert(not table.find(NoTables, TestTable), "При вызове с false таблица не должна возвращаться")
    assert(table.find(NoTables, TestFunction), "Не удалось найти функцию")
end)

RunTest("identifyexecutor", function()
    assert(typeof(Global.identifyexecutor()) == "string", "Не возвращена строка")
end)

RunTest("request", function()
    local Response = Global.request({
        Url = "https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/Library.lua",
        Method = "GET",
    })
    assert(Response.StatusCode == 200, "Код ответа должен быть 200")
    assert(typeof(Response.Body) == "string", "Тело ответа должно быть строкой")
end)

RunTest("cloneref", function()
    local TestPart = Instance.new("Part")
    local Clone = Global.cloneref(TestPart)
    assert(typeof(Clone) == "Instance", "Должен возвращаться Instance")
    assert(TestPart ~= Clone, "Копия не должна совпадать с оригиналом")
    TestPart.Name = "Test"
    assert(Clone.Name == "Test", "Изменение оригинала не изменило копию")
    TestPart:Destroy()
end)

RunTest("gethui", function()
    local Hui = Global.gethui()
    assert(typeof(Hui) == "Instance", "Должен возвращаться Instance")
    local ValidClasses = { "ScreenGui", "Folder", "BasePlayerGui", "CoreGui" }
    if not Hui:IsDescendantOf(EnvServices.CoreGui) and Hui.ClassName ~= "CoreGui" or not table.find(ValidClasses, Hui.ClassName) then
        error("Не возвращён допустимый контейнер GUI")
    end
end)

RunTest("getcallbackvalue", function()
    local TestBindable = Instance.new("BindableFunction")
    TestBindable.OnInvoke = function(Value) return Value * 10 end
    local Callback = Global.getcallbackvalue(TestBindable, "OnInvoke")
    local Success, Result = pcall(function()
        assert(typeof(Callback) == "function", "Не возвращена функция")
        assert(Callback(5) == 50, "Не возвращено значение обратного вызова")
    end)
    TestBindable:Destroy()
    assert(Success, Result)
end)

RunTest("getinstances", function()
    local TestPart1 = Instance.new("Part")
    local TestPart2 = Instance.new("Part", EnvServices.Workspace)
    local InstanceList = Global.getinstances()
    local Found1 = table.find(InstanceList, TestPart1)
    local Found2 = table.find(InstanceList, TestPart2)
    TestPart1:Destroy()
    TestPart2:Destroy()
    assert(Found2, "Не возвращён Instance")
    assert(Found1, "Не возвращён Instance с родителем nil")
end)

RunTest("getnilinstances", function()
    local TestPart1 = Instance.new("Part")
    local TestPart2 = Instance.new("Part", EnvServices.Workspace)
    local InstanceList = Global.getnilinstances()
    local FoundNil = table.find(InstanceList, TestPart1)
    local FoundParented = table.find(InstanceList, TestPart2)
    TestPart1:Destroy()
    TestPart2:Destroy()
    assert(not FoundParented, "Возвращён Instance с родителем, отличным от nil")
    assert(FoundNil, "Не возвращён Instance с родителем nil")
end)

RunTest("fireproximityprompt", function()
    local TestPart = Instance.new("Part", EnvServices.Workspace)
    local TestPrompt = Instance.new("ProximityPrompt", TestPart)
    local Fired = false
    local Connection = TestPrompt.Triggered:Connect(function() Fired = true end)
    Global.fireproximityprompt(TestPrompt)
    local Tries = 0
    while not Fired and Tries < 10 do Tries = Tries + 1 task.wait(0.1) end
    Connection:Disconnect()
    TestPart:Destroy()
    assert(Fired == true, "Не удалось активировать взаимодействие")
end)

RunTest("fireclickdetector", function()
    local TestPart = Instance.new("Part", EnvServices.Workspace)
    local TestClick = Instance.new("ClickDetector", TestPart)
    local Fired = false
    local Connection = TestClick.MouseClick:Connect(function() Fired = true end)
    Global.fireclickdetector(TestClick)
    local Tries = 0
    while not Fired and Tries < 10 do Tries = Tries + 1 task.wait(0.1) end
    Connection:Disconnect()
    TestPart:Destroy()
    assert(Fired == true, "Не удалось активировать детектор клика")
end)

RunTest("firetouchinterest", function()
    local TestPart1 = Instance.new("Part", EnvServices.Workspace)
    TestPart1.Position = Vector3.new(0, 1000, 0)
    local TestPart2 = Instance.new("Part", EnvServices.Workspace)
    TestPart2.Position = Vector3.new(0, 1000, 0)
    local Fired = false
    local Connection = TestPart1.Touched:Connect(function(Child)
        if Child == TestPart2 then Fired = true end
    end)
    Global.firetouchinterest(TestPart1, TestPart2, 0)
    task.wait()
    Global.firetouchinterest(TestPart1, TestPart2, 1)
    local Tries = 0
    while not Fired and Tries < 10 do Tries = Tries + 1 task.wait(0.1) end
    Connection:Disconnect()
    TestPart1:Destroy()
    TestPart2:Destroy()
    assert(Fired == true, "Не удалось активировать событие касания")
end)

RunTest("clonefunction", function()
    local TestFunction = function() return 10 end
    local TestClone = Global.clonefunction(TestFunction)
    assert(TestFunction ~= TestClone, "Возвращена исходная функция")
    assert(TestFunction() == TestClone(), "Копия вернула не то же значение, что оригинал")
end)

RunTest("newcclosure", function()
    local TestFunction = function() return 10 end
    local TestC = Global.newcclosure(TestFunction)
    assert(TestFunction ~= TestC, "Возвращена исходная функция")
    assert(TestFunction() == TestC(), "Возвращено не то же значение, что у оригинала")
    assert(TestC() == 10, "Не возвращено правильное значение")
    assert(debug.info(TestC, "s") == "[C]", "Не возвращена функция C")
end)

RunTest("hookfunction", function()
    local TestFunction = function() return 10 end
    local TestC = Global.newcclosure(function() return 25 end)
    local TestHook = function() return 100 end
    local Old = Global.hookfunction(TestFunction, TestHook)
    local OldC = Global.hookfunction(TestC, TestHook)
    assert(TestFunction ~= TestHook, "Оригинал и перехватчик являются одной функцией")
    assert(debug.info(TestC, "s") == "[C]", "Перехваченная функция C больше не является функцией C")
    assert(TestFunction() == 100, "Возвращаемое значение не изменилось")
    assert(Old() == 10, "Не возвращена исходная функция")
    assert(OldC() == 25, "Не возвращена исходная функция C")
end)

RunTest("restorefunction", function()
    assert(Environment.hookfunction, "Для проверки необходима hookfunction")
    local TestFunction = function() return 10 end
    local TestHook = function() return 100 end
    Global.hookfunction(TestFunction, TestHook)
    Global.restorefunction(TestFunction)
    assert(TestFunction() == 10, "Не удалось снять перехват функции")
end)

RunTest("isfunctionhooked", function()
    assert(Environment.hookfunction, "Для проверки необходима hookfunction")
    assert(Environment.restorefunction, "Для проверки необходима restorefunction")
    local TestFunction = function() return 10 end
    local TestHook = function() return 100 end
    Global.hookfunction(TestFunction, TestHook)
    assert(Global.isfunctionhooked(TestFunction) == true, "Не возвращено true для перехваченной функции")
    Global.restorefunction(TestFunction)
    assert(Global.isfunctionhooked(TestFunction) == false, "Не возвращено false для функции без перехвата")
end)

RunTest("isexecutorclosure", function()
    assert(Environment.newcclosure, "Для проверки необходима newcclosure")
    local TestFunction = function() return 10 end
    local TestC = Global.newcclosure(TestFunction)
    assert(Global.isexecutorclosure(TestFunction) == true, "Не возвращено true для функции исполнителя")
    assert(Global.isexecutorclosure(Global.newcclosure) == true, "Не возвращено true для глобальной функции исполнителя")
    assert(Global.isexecutorclosure(warn) == false, "Не возвращено false для глобальной функции Roblox")
    assert(Global.isexecutorclosure(TestC) == true, "Не возвращено true для функции C исполнителя")
end)

RunTest("getnamecallmethod", function()
    pcall(function() game:ExampleNamecall() end)
    assert(typeof(Global.getnamecallmethod()) == "string", "Не возвращена строка")
    assert(Global.getnamecallmethod() == "ExampleNamecall", "Не возвращён правильный метод")
end)

RunTest("hookmetamethod", function()
    assert(Environment.getnamecallmethod, "Для проверки необходима getnamecallmethod")
    assert(Environment.newcclosure, "Для проверки необходима newcclosure")
    local TestTable = setmetatable({}, {
        __index = Global.newcclosure(function() return "normal" end),
    })
    Global.hookmetamethod(TestTable, "__index", Global.newcclosure(function() return "hooked" end))
    assert(TestTable.Example == "hooked", "Не удалось перехватить метаметод")
end)

RunTest("getrawmetatable", function()
    local TestTable = { __metatable = "Locked!" }
    local TestObject = setmetatable({}, TestTable)
    assert(Global.getrawmetatable(TestObject) == TestTable, "Не возвращена метатаблица")
end)

RunTest("setrawmetatable", function()
    assert(Environment.getrawmetatable, "Для проверки необходима getrawmetatable")
    local TestTable = { __metatable = "Locked!" }
    local TestObject = setmetatable({}, TestTable)
    Global.setrawmetatable(TestObject, { __index = function() return "Edited!" end })
    assert(TestObject.Example == "Edited!", "Не удалось задать метатаблицу")
end)

RunTest("isreadonly", function()
    local TestTable = {}
    local FrozenTable = table.freeze({})
    assert(Global.isreadonly(TestTable) == false, "Не возвращено false для изменяемой таблицы")
    assert(Global.isreadonly(FrozenTable) == true, "Не возвращено true для таблицы только для чтения")
end)

RunTest("setreadonly", function()
    assert(Environment.isreadonly, "Для проверки необходима isreadonly")
    local TestTable = { Value = 10 }
    table.freeze(TestTable)
    Global.setreadonly(TestTable, false)
    TestTable.Value = 100
    assert(Global.isreadonly(TestTable) == false, "Не удалось задать режим только для чтения")
end)

RunTest("Drawing.new", function()
    assert(typeof(Global.Drawing.new) == "function", "Drawing.new не является функцией")
    local NewShape = Global.Drawing.new("Circle")
    NewShape.Visible = false
    NewShape.Radius = 10
    NewShape.Thickness = 1
    NewShape.Filled = false
    NewShape.NumSides = 10
    NewShape:Remove()
end, "Drawing_New")

RunTest("Drawing.Fonts", function()
    assert(typeof(Global.Drawing.Fonts) == "table", "Drawing.Fonts не является таблицей")
end, "Drawing_Fonts")

RunTest("writefile", function()
    Global.writefile("FeatherHub_Test_File", "example")
    assert(Global.isfile("FeatherHub_Test_File") == true, "Не удалось создать файл")
    assert(Global.readfile("FeatherHub_Test_File") == "example", "Файл не содержит ожидаемых данных")
end)

RunTest("isfile", function()
    assert(Global.isfile("FeatherHub_Test_File") == true, "Не возвращено true для существующего файла")
end)

RunTest("readfile", function()
    assert(Global.readfile("FeatherHub_Test_File") == "example", "Не возвращены ожидаемые данные")
end)

RunTest("appendfile", function()
    Global.appendfile("FeatherHub_Test_File", "_appended")
    assert(Global.readfile("FeatherHub_Test_File") == "example_appended", "Не удалось дописать содержимое файла")
end)

RunTest("loadfile", function()
    Global.writefile("FeatherHub_Test_Load", [[return 25]])
    assert(Global.loadfile("FeatherHub_Test_Load")() == 25, "Не удалось загрузить и выполнить файл")
end)

RunTest("delfile", function()
    Global.delfile("FeatherHub_Test_File")
    Global.delfile("FeatherHub_Test_Load")
    assert(Global.isfile("FeatherHub_Test_File") == false, "Не удалось удалить файл")
end)

RunTest("makefolder", function()
    Global.makefolder("FeatherHub_Test_Folder")
    assert(Global.isfolder("FeatherHub_Test_Folder") == true, "Не удалось создать папку")
end)

RunTest("delfolder", function()
    Global.delfolder("FeatherHub_Test_Folder")
    assert(Global.isfolder("FeatherHub_Test_Folder") == false, "Не удалось удалить папку")
end)

RunTest("listfiles", function()
    Global.makefolder("FeatherHub_ListFiles_Test")
    Global.writefile("FeatherHub_ListFiles_Test/Test1", "test 1")
    Global.writefile("FeatherHub_ListFiles_Test/Test2", "test 2")
    local FilesList = Global.listfiles("FeatherHub_ListFiles_Test")
    local Found1, Found2 = false, false
    assert(#FilesList == 2, "Не возвращено правильное число файлов")
    for _, File in ipairs(FilesList) do
        local Content = Global.readfile(File)
        if Content == "test 1" then Found1 = true
        elseif Content == "test 2" then Found2 = true end
    end
    Global.delfolder("FeatherHub_ListFiles_Test")
    assert(Found1 == true, "Не возвращён первый файл")
    assert(Found2 == true, "Не возвращён второй файл")
end)

RunTest("getcustomasset", function()
    assert(Environment.writefile, "Для проверки необходима writefile")
    local Content = game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/Library.lua")
    Global.writefile("FeatherHub_Test_Image", Content)
    local Asset = Global.getcustomasset("FeatherHub_Test_Image")
    local TestImage = Instance.new("ImageLabel", EnvServices.CoreGui.RobloxGui)
    TestImage.Image = Asset
    local Tries = 0
    while not TestImage.IsLoaded and Tries < 10 do Tries = Tries + 1 task.wait(0.1) end
    local IsLoaded = TestImage.IsLoaded
    TestImage:Destroy()
    Global.delfile("FeatherHub_Test_Image")
    assert(string.find(Asset, "rbxasset://"), "Должен возвращаться идентификатор rbxasset")
    assert(IsLoaded == true, "Не удалось загрузить изображение PNG")
end)

RunTest("gethiddenproperty", function()
    local TestPart = Instance.new("Part")
    local Value = Global.gethiddenproperty(TestPart, "NetworkIsSleeping")
    TestPart:Destroy()
    assert(Value == false, "Не возвращено правильное значение свойства")
end)

RunTest("sethiddenproperty", function()
    assert(Environment.gethiddenproperty, "Для проверки необходима gethiddenproperty")
    local TestPart = Instance.new("Part")
    Global.sethiddenproperty(TestPart, "NetworkIsSleeping", true)
    local Value = Global.gethiddenproperty(TestPart, "NetworkIsSleeping")
    TestPart:Destroy()
    assert(Value == true, "Не удалось задать скрытое свойство")
end)

RunTest("getthreadidentity", function()
    local Identity = Global.getthreadidentity()
    assert(typeof(Identity) == "number", "Не возвращено число")
    assert(Identity > 0, "Возвращён недопустимый уровень доступа")
    assert(Identity < 9, "Возвращён недопустимый уровень доступа")
end)

RunTest("setthreadidentity", function()
    assert(Environment.getthreadidentity, "Для проверки необходима getthreadidentity")
    local Old = Global.getthreadidentity()
    Global.setthreadidentity(2)
    assert(EnvServices.CoreGui == nil, "Возможности не соответствуют заданному уровню доступа")
    Global.setthreadidentity(Old)
end)

RunTest("isnetworkowner", function()
    local Test = Instance.new("Part", EnvServices.Workspace)
    local RootPart = EnvServices.Players.LocalPlayer.Character.HumanoidRootPart
    local TestPart
    for _, Part in ipairs(EnvServices.Workspace:GetDescendants()) do
        if Part:IsA("BasePart") and Part.Anchored then TestPart = Part break end
    end
    RootPart.Anchored = true
    local IsOwned = Global.isnetworkowner(RootPart)
    RootPart.Anchored = false
    local IsClientOwned = Global.isnetworkowner(Test)
    local IsNotOwned = TestPart and Global.isnetworkowner(TestPart)
    Test:Destroy()
    assert(TestPart ~= nil, "Пропущено: нет закреплённой детали для проверки")
    assert(IsClientOwned == true, "Не возвращено true для детали, принадлежащей клиенту")
    assert(IsNotOwned == false, "Не возвращено false для детали, не принадлежащей клиенту")
    assert(IsOwned == true, "Не возвращено true для закреплённой детали, принадлежащей клиенту")
end)

RunTest("firesignal", function()
    local TestEvent = Instance.new("RemoteEvent")
    local Fired = false
    local Value1, Value2, Value3
    local Connection = TestEvent.OnClientEvent:Connect(function(Arg1, Arg2, Arg3)
        Fired = true Value1 = Arg1 Value2 = Arg2 Value3 = Arg3
    end)
    Global.firesignal(TestEvent.OnClientEvent, "Example", 10, true)
    local Tries = 0
    while not Fired and Tries < 10 do Tries = Tries + 1 task.wait(0.1) end
    Connection:Disconnect()
    TestEvent:Destroy()
    assert(Fired == true, "Не удалось вызвать сигнал")
    assert(Value1 == "Example", "Сигнал вызван с неверными данными")
    assert(Value2 == 10, "Сигнал вызван с неверными данными")
    assert(Value3 == true, "Сигнал вызван с неверными данными")
end)

RunTest("replicatesignal", function()
    local TestButton = Instance.new("Frame")
    Global.replicatesignal(TestButton.MouseWheelForward, 69, 420)
    local Success = pcall(function()
        Global.replicatesignal(TestButton.MouseWheelForward)
        Global.replicatesignal(TestButton.MouseWheelForward, 69)
    end)
    TestButton:Destroy()
    assert(Success == false, "Неверные аргументы не вызвали ошибку")
end)

RunTest("getconnections", function()
    local Fired = false
    local Connection = game.ChildAdded:Connect(function(Child)
        if Child == "Example" then Fired = true end
    end)
    for _, Conn in ipairs(getconnections(game.ChildAdded)) do
        Conn:Fire("Example")
    end
    local Tries = 0
    while not Fired and Tries < 10 do Tries = Tries + 1 task.wait(0.1) end
    Connection:Disconnect()
    assert(Fired == true, "Не удалось вызвать сигналы соединения")
end)

RunTest("require", function()
    local TestScript = Global.require(EnvServices.Players.LocalPlayer.PlayerScripts.PlayerModule)
    assert(typeof(TestScript) == "table", "Не возвращена таблица")
    assert(typeof(TestScript.GetControls) == "function", "Не возвращены ожидаемые данные")
    local Original = TestScript.GetControls
    TestScript.GetControls = function() return "test" end
    assert(TestScript.GetControls() == "test", "Не удалось изменить значения модуля")
    TestScript.GetControls = Original
    TestScript = nil
end)

getgenv().FeatherHub.Environment = Environment

-- ════════════════════════════════════════════════════════════════
-- ESP LIBRARY (inlined) — FPS FIX APPLIED
-- Single centralized render loop replaces per-object Heartbeat connections
-- Highlight instances pooled (toggle Enabled instead of destroy/create)
-- ════════════════════════════════════════════════════════════════
local ESPLibrary = {
    Font = Enum.Font.RobotoCondensed,
    Rainbow = false,
    Tracers = false,
    Unloaded = false,
    ShowDistance = false,
    MatchColors = true,
    Arrows = false,
    TextTransparency = 0,
    TracerOrigin = "Bottom",
    FillTransparency = 0.75,
    OutlineTransparency = 0,
    TextOutlineTransparency = 0,
    FadeTime = 0,
    RenderLimit = 240,
    TracerSize = 0.5,
    ArrowRadius = 200,
    TextSize = 20,
    DistanceSizeRatio = 1,
    OutlineColor = Color3.fromRGB(255, 255, 255),
    RainbowColor = Color3.fromRGB(255, 255, 255),
    ElementsEnabled = {},
    TransparencyEnabled = {},
    Highlights = {},
    Labels = {},
    Frames = {},
    Lines = {},
    ArrowsTable = {},
    ColorTable = {},
    TextTable = {},
    ConnectionsTable = {},
    Objects = {},
    TotalObjects = {},
    -- FPS FIX: centralized render loop fields
    RenderConnection = nil,
    RenderAccumulator = 0,
}

local RainbowState = { HueSetup = 0, Hue = 0, Step = 0, Color = Color3.new() }

local ESPCloneRef = cloneref or function(O) return O end
local ESPPlayers = ESPCloneRef(game:GetService("Players"))
local ESPCoreGui = getgenv and ESPCloneRef(game:GetService("CoreGui")) or ESPPlayers.LocalPlayer.PlayerGui
local ESPWorkspace = ESPCloneRef(workspace)
local ESPRunService = ESPCloneRef(game:GetService("RunService"))
local ESPTweenService = ESPCloneRef(game:GetService("TweenService"))
local ESPUserInputService = ESPCloneRef(game:GetService("UserInputService"))
local ESPDebris = ESPCloneRef(game:GetService("Debris"))
local ESPLocalPlayer = ESPPlayers.LocalPlayer

local function GetHiddenUI()
    if gethui then return gethui() end
    local Folder = Instance.new("Folder", ESPCoreGui)
    Folder.Name = ("%032x"):format(math.random(0, 2^31))
    return Folder
end

function ESPLibrary:GenerateRandomString()
    local Chars = {}
    local Pool = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local PoolLen = #Pool
    for I = 1, 24 do
        Chars[I] = Pool:sub(math.random(1, PoolLen), math.random(1, PoolLen))
    end
    return table.concat(Chars)
end

local ESPHiddenUI = GetHiddenUI()
local ESPCamera = ESPWorkspace.CurrentCamera

local ESPScreenGui = Instance.new("ScreenGui")
ESPScreenGui.ResetOnSpawn = false
ESPScreenGui.IgnoreGuiInset = true
ESPScreenGui.Name = ESPLibrary:GenerateRandomString()
ESPScreenGui.Parent = ESPHiddenUI

local ESPHighlightsFolder = Instance.new("Folder")
ESPHighlightsFolder.Name = ESPLibrary:GenerateRandomString()
ESPHighlightsFolder.Parent = ESPScreenGui

local ESPBillboardsFolder = Instance.new("Folder")
ESPBillboardsFolder.Name = ESPLibrary:GenerateRandomString()
ESPBillboardsFolder.Parent = ESPScreenGui

local ESPTracersFrame = Instance.new("Frame")
ESPTracersFrame.Size = UDim2.new(1, 0, 1, 0)
ESPTracersFrame.BackgroundTransparency = 1
ESPTracersFrame.Visible = false
ESPTracersFrame.Name = ESPLibrary:GenerateRandomString()
ESPTracersFrame.Parent = ESPScreenGui

local ESPArrowsFrame = Instance.new("Frame")
ESPArrowsFrame.Size = UDim2.new(1, 0, 1, 0)
ESPArrowsFrame.BackgroundTransparency = 1
ESPArrowsFrame.Visible = false
ESPArrowsFrame.Name = ESPLibrary:GenerateRandomString()
ESPArrowsFrame.Parent = ESPScreenGui

local ArrowTemplate = Instance.new("ImageLabel")
ArrowTemplate.Image = "rbxassetid://16368985219"
ArrowTemplate.Size = UDim2.new(0, 50, 0, 50)
ArrowTemplate.AnchorPoint = Vector2.new(0.5, 0.5)
ArrowTemplate.BackgroundTransparency = 1
ArrowTemplate.ImageTransparency = 1
local ArrowConstraint = Instance.new("UIAspectRatioConstraint")
ArrowConstraint.AspectRatio = 1
ArrowConstraint.Name = ESPLibrary:GenerateRandomString()
ArrowConstraint.Parent = ArrowTemplate

local function ESPMakeTween(Instance_, Props)
    local Info = TweenInfo.new(ESPLibrary.FadeTime, Enum.EasingStyle.Quad)
    return ESPTweenService:Create(Instance_, Info, Props)
end

local function ESPPlayTween(Instance_, Props)
    ESPMakeTween(Instance_, Props):Play()
end

local function DestroyObjectData(Object)
    local Highlight = ESPLibrary.Highlights[Object]
    if Highlight then Highlight:Destroy() ESPLibrary.Highlights[Object] = nil end
    local Frame = ESPLibrary.Frames[Object]
    if Frame then Frame:Destroy() ESPLibrary.Frames[Object] = nil end
    local LineData = ESPLibrary.Lines[Object]
    if LineData then if LineData[1] then LineData[1]:Destroy() end ESPLibrary.Lines[Object] = nil end
    local Arrow = ESPLibrary.ArrowsTable[Object]
    if Arrow then Arrow:Destroy() ESPLibrary.ArrowsTable[Object] = nil end
    local Conns = ESPLibrary.ConnectionsTable[Object]
    if Conns then for _, Conn in ipairs(Conns) do Conn:Disconnect() end ESPLibrary.ConnectionsTable[Object] = nil end
    ESPLibrary.Labels[Object] = nil
    ESPLibrary.ColorTable[Object] = nil
    ESPLibrary.TextTable[Object] = nil
    ESPLibrary.ElementsEnabled[Object] = nil
    ESPLibrary.TransparencyEnabled[Object] = nil
    ESPLibrary.Objects[Object] = nil
    for Idx = #ESPLibrary.TotalObjects, 1, -1 do
        if ESPLibrary.TotalObjects[Idx] == Object then table.remove(ESPLibrary.TotalObjects, Idx) break end
    end
end

-- ════════════════════════════════════════════════════════════════
-- FPS FIX: Centralized render function for a single object
-- Replaces the per-object Heartbeat connection approach
-- ════════════════════════════════════════════════════════════════
function ESPLibrary:RenderObject(Object)
    if self.ElementsEnabled[Object] ~= true then return end
    if not Object or not Object.Parent or not Object:IsDescendantOf(game) then
        self:RemoveESP(Object)
        return
    end

    local ObjectPos = Object:GetPivot().Position
    local ScreenPoint, OnScreen = ESPCamera:WorldToViewportPoint(ObjectPos)
    local Frame = self.Frames[Object]
    local Label = self.Labels[Object]
    local CachedHighlight = self.Highlights[Object]
    local LineData = self.Lines[Object]

    -- FPS FIX: Toggle Highlight.Enabled instead of destroy/create
    if not OnScreen then
        if CachedHighlight then CachedHighlight.Enabled = false end
        if Frame then Frame.Visible = false end
        if LineData and LineData[1] then LineData[1].Visible = false end
    else
        if self.ElementsEnabled[Object] == true then
            if not CachedHighlight or not CachedHighlight.Parent then
                if CachedHighlight then CachedHighlight:Destroy() end
                CachedHighlight = Instance.new("Highlight")
                CachedHighlight.FillTransparency = self.FillTransparency
                CachedHighlight.OutlineTransparency = self.OutlineTransparency
                CachedHighlight.Name = self:GenerateRandomString()
                CachedHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                CachedHighlight.Adornee = Object
                CachedHighlight.Parent = ESPHighlightsFolder
                self.Highlights[Object] = CachedHighlight
            end
            CachedHighlight.Enabled = true
        end

        if Frame then
            Frame.Visible = true
            Frame.Position = UDim2.new(0, ScreenPoint.X, 0, ScreenPoint.Y)
        end
    end

    local ActiveColor = self.Rainbow and RainbowState.Color or self.ColorTable[Object] or Color3.fromRGB(255, 255, 255)
    if Label then Label.TextColor3 = ActiveColor end

    if CachedHighlight and CachedHighlight.Enabled then
        local Distance = math.floor((ESPCamera.CFrame.Position - ObjectPos).Magnitude)
        local DistanceText = self.ShowDistance and ("\n" .. '<font size="' .. math.round(self.TextSize * self.DistanceSizeRatio) .. '">[' .. Distance .. ']</font>') or ""
        if Label then Label.Text = self.TextTable[Object] .. DistanceText end
        CachedHighlight.FillColor = ActiveColor
        CachedHighlight.OutlineColor = self.MatchColors and ActiveColor or self.OutlineColor
        if self.TransparencyEnabled[Object] == true then
            CachedHighlight.FillTransparency = self.FillTransparency
            CachedHighlight.OutlineTransparency = self.OutlineTransparency
            if Label then
                Label.TextTransparency = self.TextTransparency
                Label.TextStrokeTransparency = self.TextOutlineTransparency
            end
        end
    end

    -- Tracers
    if LineData and CachedHighlight and self.Tracers == true and OnScreen then
        local ScreenSize = ESPCamera.ViewportSize
        local Origin
        if self.TracerOrigin == "Center" then Origin = Vector2.new(ScreenSize.X / 2, ScreenSize.Y / 2)
        elseif self.TracerOrigin == "Top" then Origin = Vector2.new(ScreenSize.X / 2, 0)
        elseif self.TracerOrigin == "Mouse" then
            local MouseLoc = ESPUserInputService:GetMouseLocation()
            Origin = Vector2.new(ESPLocalPlayer:GetMouse().X, MouseLoc.Y)
        else Origin = Vector2.new(ScreenSize.X / 2, ScreenSize.Y) end
        local Destination = Vector2.new(ScreenPoint.X, ScreenPoint.Y)
        local MidPoint = (Origin + Destination) / 2
        local Rotation = math.deg(math.atan2(Destination.Y - Origin.Y, Destination.X - Origin.X))
        local Length = (Origin - Destination).Magnitude
        LineData[1].Position = UDim2.new(0, MidPoint.X, 0, MidPoint.Y)
        LineData[1].Size = UDim2.new(0, Length, 0, 1)
        LineData[1].Rotation = Rotation
        LineData[1].BackgroundColor3 = ActiveColor
        LineData[1].BorderSizePixel = 0
        LineData[1].Visible = true
        LineData[2].Color = ActiveColor
        LineData[2].Thickness = self.TracerSize
    end

    -- Arrows (shown for off-screen, hidden for on-screen)
    if self.Arrows == true then
        local Arrow = self.ArrowsTable[Object]
        if Arrow == nil and self.ElementsEnabled[Object] == true then
            Arrow = ArrowTemplate:Clone()
            Arrow.Name = self:GenerateRandomString()
            Arrow:WaitForChild(ArrowConstraint.Name, 5)
            Arrow.Parent = ESPArrowsFrame
            self.ArrowsTable[Object] = Arrow
            ESPPlayTween(Arrow, { ImageTransparency = 0 })
        elseif Arrow and self.ElementsEnabled[Object] == true then
            if OnScreen and ScreenPoint.Z > 0 then
                Arrow.Visible = false
            else
                local ScreenSize = ESPCamera.ViewportSize
                local ScreenCenter = Vector2.new(ScreenSize.X / 2, ScreenSize.Y / 2)
                local ToObj = (ObjectPos - ESPCamera.CFrame.Position).Unit
                local Dir = Vector2.new(ScreenPoint.X, ScreenPoint.Y) - ScreenCenter
                if ESPCamera.CFrame.LookVector:Dot(ToObj) < 0 then Dir = -Dir end
                local Angle = math.atan2(Dir.Y, Dir.X)
                local Radius = math.min(ScreenSize.X, ScreenSize.Y) / 2 - (400 - self.ArrowRadius)
                local ArrowPos = ScreenCenter + Dir.Unit * Radius
                Arrow.Position = UDim2.new(0, ArrowPos.X, 0, ArrowPos.Y)
                Arrow.Rotation = math.deg(Angle) - 90
                Arrow.Visible = true
                Arrow.ImageColor3 = self.Rainbow and self.RainbowColor or self.ColorTable[Object]
            end
        end
    end
end

-- FPS FIX: Single centralized render loop for ALL ESP objects
function ESPLibrary:StartRenderLoop()
    if self.RenderConnection then return end
    self.RenderConnection = ESPRunService.Heartbeat:Connect(function(Delta)
        if self.Unloaded then return end
        self.RenderAccumulator = self.RenderAccumulator + Delta
        local MinInterval = 1 / self.RenderLimit
        if self.RenderAccumulator < MinInterval then return end
        self.RenderAccumulator = 0

        for _, Object in ipairs(self.TotalObjects) do
            if self.ElementsEnabled[Object] == true then
                self:RenderObject(Object)
            end
        end
    end)
end

function ESPLibrary:AddESP(Parameters)
    local Object = Parameters.Object
    if self.ElementsEnabled[Object] == true or self.Unloaded == true then return end
    if not Object:IsA("BasePart") and not Object:IsA("Model") then return end

    -- FPS FIX: Clean up any stale connections from previous AddESP calls
    if self.ConnectionsTable[Object] then
        for _, Conn in ipairs(self.ConnectionsTable[Object]) do
            pcall(function() Conn:Disconnect() end)
        end
        table.clear(self.ConnectionsTable[Object])
    else
        self.ConnectionsTable[Object] = {}
    end

    self.ElementsEnabled[Object] = true
    self.TransparencyEnabled[Object] = false

    if self.Highlights[Object] then self.Highlights[Object]:Destroy() self.Highlights[Object] = nil end

    local Highlight = Instance.new("Highlight")
    Highlight.FillTransparency = 1
    Highlight.OutlineTransparency = 1
    Highlight.Name = self:GenerateRandomString()
    Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    Highlight.Adornee = Object
    Highlight.Parent = ESPHighlightsFolder
    self.Highlights[Object] = Highlight

    local TextFrame = Instance.new("Frame")
    TextFrame.Visible = false
    TextFrame.Name = self:GenerateRandomString()
    TextFrame.Size = UDim2.fromScale(1, 1)
    TextFrame.BackgroundTransparency = 1
    TextFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    TextFrame.Parent = ESPBillboardsFolder

    local TextLabel = Instance.new("TextLabel")
    TextLabel.Name = self:GenerateRandomString()
    TextLabel.BackgroundTransparency = 1
    TextLabel.Text = Parameters.Text
    TextLabel.TextTransparency = 1
    TextLabel.TextStrokeTransparency = self.TextOutlineTransparency
    TextLabel.Size = UDim2.new(1, 0, 1, 0)
    TextLabel.Font = self.Font
    TextLabel.TextSize = self.TextSize
    TextLabel.RichText = true
    TextLabel.TextColor3 = Parameters.Color
    TextLabel.Parent = TextFrame

    self.Frames[Object] = TextFrame
    self.Labels[Object] = TextLabel
    self.ColorTable[Object] = Parameters.Color
    self.TextTable[Object] = Parameters.Text
    self.Objects[Object] = Object
    table.insert(self.TotalObjects, Object)

    ESPPlayTween(Highlight, { FillTransparency = self.FillTransparency })
    ESPPlayTween(Highlight, { OutlineTransparency = self.OutlineTransparency })

    local TextFadeIn = ESPMakeTween(TextLabel, { TextTransparency = self.TextTransparency })
    TextFadeIn.Completed:Once(function() self.TransparencyEnabled[Object] = true end)
    TextFadeIn:Play()
    ESPPlayTween(TextLabel, { TextStrokeTransparency = self.TextOutlineTransparency })

    local LineFrame = Instance.new("Frame")
    LineFrame.Size = UDim2.new(0, 0, 0, 0)
    LineFrame.BackgroundTransparency = 1
    LineFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    LineFrame.Name = self:GenerateRandomString()
    LineFrame.Parent = ESPTracersFrame

    local Stroke = Instance.new("UIStroke")
    Stroke.Thickness = self.TracerSize
    Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    Stroke.Transparency = 1
    Stroke.Name = self:GenerateRandomString()
    Stroke.Parent = LineFrame

    ESPPlayTween(LineFrame, { BackgroundTransparency = 0 })
    ESPPlayTween(Stroke, { Transparency = 0 })
    self.Lines[Object] = { LineFrame, Stroke }

    -- FPS FIX: No per-object Heartbeat connection. Centralized loop handles rendering.
    self:StartRenderLoop()
end

function ESPLibrary:RemoveESP(Object)
    if self.Unloaded == true or self.ElementsEnabled[Object] ~= true then return end
    self.ElementsEnabled[Object] = false
    self.TransparencyEnabled[Object] = false
    local Label = self.Labels[Object]
    if Label then ESPPlayTween(Label, { TextTransparency = 1 }) end
    local LineData = self.Lines[Object]
    if LineData then
        if LineData[1] then ESPPlayTween(LineData[1], { BackgroundTransparency = 1 }) end
        if LineData[2] then ESPPlayTween(LineData[2], { Transparency = 1 }) end
    end
    local Highlight = self.Highlights[Object]
    if Highlight then
        ESPPlayTween(Highlight, { FillTransparency = 1 })
        ESPPlayTween(Highlight, { OutlineTransparency = 1 })
    end
    local Arrow = self.ArrowsTable[Object]
    if Arrow then ESPPlayTween(Arrow, { ImageTransparency = 1 }) end
    local FadeTime = self.FadeTime
    task.delay(FadeTime + 0.05, function()
        if self.ElementsEnabled[Object] == false then
            DestroyObjectData(Object)
        else
            local ReHighlight = self.Highlights[Object]
            if ReHighlight then
                ESPPlayTween(ReHighlight, { FillTransparency = self.FillTransparency })
                ESPPlayTween(ReHighlight, { OutlineTransparency = self.OutlineTransparency })
            end
        end
    end)
end

function ESPLibrary:UpdateObjectText(Object, Text) if self.TextTable[Object] ~= nil then self.TextTable[Object] = Text end end
function ESPLibrary:UpdateObjectColor(Object, Color) self.ColorTable[Object] = Color if self.Labels[Object] and self.Rainbow ~= true then self.Labels[Object].TextColor3 = Color end end
function ESPLibrary:SetColorTable(Name, Color) self.ColorTable[Name] = Color end
function ESPLibrary:SetFadeTime(Number) self.FadeTime = Number end
function ESPLibrary:SetRenderLimit(Number) self.RenderLimit = Number end
function ESPLibrary:SetTextTransparency(Number) self.TextTransparency = Number for _, Label in pairs(self.Labels) do Label.TextTransparency = Number end end
function ESPLibrary:SetFillTransparency(Number) self.FillTransparency = Number for _, H in pairs(self.Highlights) do if H:IsA("Highlight") then H.FillTransparency = Number end end end
function ESPLibrary:SetOutlineTransparency(Number) self.OutlineTransparency = Number for _, H in pairs(self.Highlights) do if H:IsA("Highlight") then H.OutlineTransparency = Number end end end
function ESPLibrary:SetTextSize(Number) self.TextSize = Number for _, Label in pairs(self.Labels) do Label.TextSize = Number end end
function ESPLibrary:SetTextOutlineTransparency(Number) self.TextOutlineTransparency = Number for _, Label in pairs(self.Labels) do Label.TextStrokeTransparency = Number end end
function ESPLibrary:SetFont(Font) self.Font = Font for _, Label in pairs(self.Labels) do Label.Font = Font end end
function ESPLibrary:SetOutlineColor(Color) self.OutlineColor = Color end
function ESPLibrary:SetRainbow(Value) self.Rainbow = Value end
function ESPLibrary:SetShowDistance(Value) self.ShowDistance = Value end
function ESPLibrary:SetMatchColors(Value) self.MatchColors = Value end
function ESPLibrary:SetTracers(Value) self.Tracers = Value ESPTracersFrame.Visible = Value end
function ESPLibrary:SetArrows(Value) self.Arrows = Value ESPArrowsFrame.Visible = Value end
function ESPLibrary:SetArrowRadius(Value) self.ArrowRadius = Value end
function ESPLibrary:SetTracerOrigin(Value) self.TracerOrigin = Value end
function ESPLibrary:SetDistanceSizeRatio(Value) self.DistanceSizeRatio = Value end
function ESPLibrary:SetTracerSize(Value) self.TracerSize = 0.5 * Value end

function ESPLibrary:Unload()
    if self.Unloaded then return end
    self.Unloaded = true
    -- FPS FIX: Disconnect centralized render loop
    if self.RenderConnection then self.RenderConnection:Disconnect() self.RenderConnection = nil end
    for _, Object in pairs(self.Objects) do self:RemoveESP(Object) end
    for _, Conns in pairs(self.ConnectionsTable) do for _, Conn in ipairs(Conns) do Conn:Disconnect() end end
    if self.RainbowConnection then self.RainbowConnection:Disconnect() end
    if self.CameraConnection then self.CameraConnection:Disconnect() end
    ESPScreenGui.Enabled = false
end

-- FPS FIX: Store connections on library table for proper cleanup
ESPLibrary.RainbowConnection = ESPRunService.RenderStepped:Connect(function(Delta)
    RainbowState.Step = RainbowState.Step + Delta
    if RainbowState.Step >= (1 / 60) then
        RainbowState.Step = 0
        RainbowState.HueSetup = RainbowState.HueSetup + (1 / 400)
        if RainbowState.HueSetup > 1 then RainbowState.HueSetup = 0 end
        RainbowState.Hue = RainbowState.HueSetup
        RainbowState.Color = Color3.fromHSV(RainbowState.Hue, 0.8, 1)
        ESPLibrary.RainbowColor = RainbowState.Color
    end
end)

ESPLibrary.CameraConnection = ESPWorkspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    ESPCamera = ESPWorkspace.CurrentCamera
end)

getgenv().FeatherHub.ESPLibrary = ESPLibrary

-- ════════════════════════════════════════════════════════════════
-- INTERFACE (inlined — Obsidian library still fetched from GitHub)
-- Credits modified: only Feather (purple) + player (green)
-- ════════════════════════════════════════════════════════════════
local ObsidianBaseUrl = "https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/"

local Interface = {
    Library = loadstring(game:HttpGet(ObsidianBaseUrl .. "Library.lua"))(),
    SaveManager = loadstring(game:HttpGet(ObsidianBaseUrl .. "addons/SaveManager.lua"))(),
    ThemeManager = loadstring(game:HttpGet(ObsidianBaseUrl .. "addons/ThemeManager.lua"))(),
    Language = "RU", -- Язык интерфейса: "RU" или "EN"
}

-- ════════════════════════════════════════════════════════════════
-- ВЫБОР ЯЗЫКА (Language Selection Dialog)
-- ════════════════════════════════════════════════════════════════
do
    local Library = Interface.Library
    
    -- Создаём диалог выбора языка перед основным окном
    local LanguageGui = Instance.new("ScreenGui")
    LanguageGui.Name = "FeatherHubLanguageSelect"
    LanguageGui.ResetOnSpawn = false
    LanguageGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    LanguageGui.DisplayOrder = 100
    LanguageGui.Parent = game:GetService("CoreGui")
    
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 350, 0, 200)
    MainFrame.Position = UDim2.new(0.5, -175, 0.5, -100)
    MainFrame.BackgroundColor3 = Color3.fromRGB(16, 24, 39)
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = LanguageGui
    
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 12)
    UICorner.Parent = MainFrame
    
    local UIStroke = Instance.new("UIStroke")
    UIStroke.Color = Color3.fromRGB(125, 211, 252)
    UIStroke.Thickness = 2
    UIStroke.Parent = MainFrame
    
    -- Заголовок
    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Size = UDim2.new(1, 0, 0, 40)
    Title.Position = UDim2.new(0, 0, 0, 15)
    Title.BackgroundTransparency = 1
    Title.Text = "FeatherHub"
    Title.TextColor3 = Color3.fromRGB(125, 211, 252)
    Title.TextSize = 24
    Title.Font = Enum.Font.GothamBold
    Title.Parent = MainFrame
    
    local Subtitle = Instance.new("TextLabel")
    Subtitle.Name = "Subtitle"
    Subtitle.Size = UDim2.new(1, 0, 0, 25)
    Subtitle.Position = UDim2.new(0, 0, 0, 55)
    Subtitle.BackgroundTransparency = 1
    Subtitle.Text = "Select Language / Выберите язык"
    Subtitle.TextColor3 = Color3.fromRGB(148, 163, 184)
    Subtitle.TextSize = 14
    Subtitle.Font = Enum.Font.Gotham
    Subtitle.Parent = MainFrame
    
    -- Кнопка English
    local ENButton = Instance.new("TextButton")
    ENButton.Name = "ENButton"
    ENButton.Size = UDim2.new(0.4, 0, 0, 50)
    ENButton.Position = UDim2.new(0.05, 0, 0, 100)
    ENButton.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
    ENButton.BorderSizePixel = 0
    ENButton.Text = "English"
    ENButton.TextColor3 = Color3.fromRGB(231, 237, 247)
    ENButton.TextSize = 18
    ENButton.Font = Enum.Font.GothamBold
    ENButton.AutoButtonColor = true
    ENButton.Parent = MainFrame
    
    local ENCorner = Instance.new("UICorner")
    ENCorner.CornerRadius = UDim.new(0, 8)
    ENCorner.Parent = ENButton
    
    local ENStroke = Instance.new("UIStroke")
    ENStroke.Color = Color3.fromRGB(45, 64, 91)
    ENStroke.Thickness = 2
    ENStroke.Parent = ENButton
    
    -- Кнопка Русский
    local RUButton = Instance.new("TextButton")
    RUButton.Name = "RUButton"
    RUButton.Size = UDim2.new(0.4, 0, 0, 50)
    RUButton.Position = UDim2.new(0.55, 0, 0, 100)
    RUButton.BackgroundColor3 = Color3.fromRGB(125, 211, 252)
    RUButton.BorderSizePixel = 0
    RUButton.Text = "Русский"
    RUButton.TextColor3 = Color3.fromRGB(16, 24, 39)
    RUButton.TextSize = 18
    RUButton.Font = Enum.Font.GothamBold
    RUButton.AutoButtonColor = true
    RUButton.Parent = MainFrame
    
    local RUCorner = Instance.new("UICorner")
    RUCorner.CornerRadius = UDim.new(0, 8)
    RUCorner.Parent = RUButton
    
    local RUStroke = Instance.new("UIStroke")
    RUStroke.Color = Color3.fromRGB(125, 211, 252)
    RUStroke.Thickness = 2
    RUStroke.Parent = RUButton
    
    -- Обработчики кнопок
    local LanguageSelected = false
    
    ENButton.MouseButton1Click:Connect(function()
        if LanguageSelected then return end
        LanguageSelected = true
        Interface.Language = "EN"
        
        -- Анимация выбора
        ENStroke.Color = Color3.fromRGB(125, 211, 252)
        ENButton.BackgroundColor3 = Color3.fromRGB(125, 211, 252)
        ENButton.TextColor3 = Color3.fromRGB(16, 24, 39)
        
        task.wait(0.3)
        LanguageGui:Destroy()
    end)
    
    RUButton.MouseButton1Click:Connect(function()
        if LanguageSelected then return end
        LanguageSelected = true
        Interface.Language = "RU"
        
        -- Анимация выбора
        RUStroke.Color = Color3.fromRGB(74, 222, 128)
        RUButton.BackgroundColor3 = Color3.fromRGB(74, 222, 128)
        
        task.wait(0.3)
        LanguageGui:Destroy()
    end)
    
    -- Ожидаем выбора языка (таймаут 60 секунд, потом RU по умолчанию)
    local StartTime = tick()
    while not LanguageSelected and (tick() - StartTime) < 60 do
        task.wait(0.1)
    end
    
    -- Если таймаут, используем RU
    if not LanguageSelected then
        Interface.Language = "RU"
        LanguageGui:Destroy()
    end
    
    print("[FeatherHub] Language selected: " .. Interface.Language)
end

-- Локализация только GUI: значения контролов, ввод и игровые строки не меняются.
do
    local Library = Interface.Library
    local Translations = {
        ["Info"] = "Информация",
        ["User Info"] = "Пользователь",
        ["Username: "] = "Имя пользователя: ",
        ["Executions: "] = "Запусков: ",
        ["Credits"] = "Благодарности",
        ["Changelog"] = "История изменений",
        ["Environment Test Results"] = "Результаты проверки среды",
        ["Executor: "] = "Исполнитель: ",
        ["Unknown"] = "Неизвестно",
        ["Actions"] = "Действия",
        ["Copy Discord Invite"] = "Discord",
        ["Copies the Discord invite to clipboard."] = "Копирует приглашение в Discord в буфер обмена.",
        ["Discord invite copied."] = "Приглашение в Discord скопировано.",
        ["Settings"] = "Настройки",
        ["Menu"] = "Меню",
        ["Open Keybind Menu"] = "Показать меню горячих клавиш",
        ["Custom Cursor"] = "Свой курсор",
        ["Queue On Teleport"] = "Загрузка после телепорта",
        ["Automatically reloads FeatherHub when you teleport to another server."] = "Автоматически загружает FeatherHub после телепорта на другой сервер.",
        ["UI Style"] = "Стиль интерфейса",
        ["DPI Scale"] = "Масштаб интерфейса",
        ["Menu bind"] = "Клавиша меню",
        ["Menu keybind"] = "Клавиша меню",
        ["Unload"] = "Выгрузить скрипт",
        ["Ping: 0ms"] = "Пинг: 0 мс",
        ["Ping: %dms"] = "Пинг: %d мс",
        ["Your executor doesn't support this feature."] = "Ваш исполнитель не поддерживает эту функцию.",
        ["Find a hiding spot."] = "Найдите укрытие.",
        ["Dont worry, hes only annoying."] = "Не волнуйтесь, он лишь досаждает.",
        ["Avoid looking at it."] = "Не смотрите на него.",
        ["Avoid looking at its eyes."] = "Не смотрите ему в глаза.",
        ["Avoid stepping on the grass."] = "Не наступайте на траву.",
        ["Keep all light sources turned off."] = "Выключите все источники света.",
        ["It can't move while you are looking at it."] = "Он не двигается, пока вы смотрите на него.",
        ["Avoid touching him."] = "Не касайтесь его.",
        ["Drop an item for her."] = "Бросьте ей предмет.",
        ["NOTIFICATION"] = "УВЕДОМЛЕНИЕ",
        ["WARNING"] = "ПРЕДУПРЕЖДЕНИЕ",
        ["Sem Título"] = "Без заголовка",
        ["Sem Descrição"] = "Без описания",
        ["Waiting for the game to load..."] = "Ожидание загрузки игры...",
        ["Oxygen: "] = "Кислород: ",
        ["dsc.gg/rushhub"] = "DOORS • Русская версия",
        ["General"] = "Основное",
        ["Exploits"] = "Эксплойты",
        ["Visuals"] = "Визуал",
        ["Floors"] = "Этажи",
        ["New - Archives"] = "Новое — Архивы",
        ["New - Stairwell"] = "Новое — Лестница",
        ["Character"] = "Персонаж",
        ["Speed Boost"] = "Прибавка скорости",
        ["Enable Speed Boost"] = "Включить ускорение",
        ["Increases your walkspeed by the specified amount."] = "Увеличивает скорость ходьбы на указанную величину.",
        ["Fly"] = "Полёт",
        ["Allows you to freely fly around the map."] = "Позволяет свободно летать по карте.",
        ["Fly Speed"] = "Скорость полёта",
        ["Noclip"] = "Сквозь стены",
        ["Allows your character to pass through solid objects."] = "Позволяет проходить сквозь твёрдые объекты.",
        ["Remove Closet Delay"] = "Без задержки выхода из шкафа",
        ["Removes the short window where you can't exit out of a closet after the animation finishes."] = "Убирает задержку выхода из шкафа после завершения анимации.",
        ["Remove Acceleration"] = "Без инерции",
        ["Prevents your character from sliding while moving."] = "Убирает скольжение персонажа при движении.",
        ["Enable Jumping"] = "Разрешить прыжки",
        ["Allows your character to jump."] = "Позволяет персонажу прыгать.",
        ["Enable Sliding"] = "Разрешить подкат",
        ["Allows your character to slide."] = "Позволяет персонажу делать подкат.",
        ["Infinite Jumps"] = "Бесконечные прыжки",
        ["Allows you to jump while in the air."] = "Позволяет прыгать в воздухе.",
        ["Self"] = "Личные настройки",
        ["Door Reach"] = "Дальность открытия дверей",
        ["Allows you to open doors from further away."] = "Позволяет открывать двери с большего расстояния.",
        ["Disable Idle Kick"] = "Защита от AFK-кика",
        ["Prevents the kick from being idle for 20 minutes."] = "Не даёт исключить вас за 20 минут бездействия.",
        ["Prompt Reach Multiplier"] = "Множитель дальности взаимодействия",
        ["Instant Prompts"] = "Мгновенное взаимодействие",
        ["Allows you to trigger all prompts instantly."] = "Позволяет мгновенно активировать взаимодействия.",
        ["Prompt Clip"] = "Взаимодействие сквозь стены",
        ["Allows you to interact with prompts through walls."] = "Позволяет взаимодействовать с объектами сквозь стены.",
        ["Automation"] = "Автоматизация",
        ["Auto Breaker Box"] = "Автоматический электрощит",
        ["Automatically solves the breaker box."] = "Автоматически решает головоломку электрощита.",
        ["Auto Solve Anchors"] = "Автоматические якоря",
        ["Automatically enters the correct code into anchors when you are near them."] = "Автоматически вводит правильный код в ближайшие якоря.",
        ["Interact with the breaker box."] = "Взаимодействуйте с электрощитом.",
        ["It will be automatically solved."] = "Головоломка будет решена автоматически.",
        ["Auto Heartbeat Minigame"] = "Автоматическая мини-игра сердцебиения",
        ["Prevents the 'Figure' minigame from ever failing."] = "Не даёт проиграть мини-игру Figure.",
        ["Auto Unlock Padlock"] = "Автоматический кодовый замок",
        ["Automatically enters the code into the library padlock."] = "Автоматически вводит код в замок библиотеки.",
        ["Unlock Distance"] = "Дальность открытия замка",
        ["Guess Library Code"] = "Подбор кода библиотеки",
        ["Attempts to guess the library code, but collecting some books is also necessary."] = "Пытается подобрать код библиотеки; часть книг всё равно нужно собрать.",
        ["Auto Interact"] = "Автовзаимодействие",
        ["Automatically triggers nearby prompts."] = "Автоматически активирует ближайшие взаимодействия.",
        ["Ignore List"] = "Список исключений",
        ["Auto Closet"] = "Автоукрытие в шкафу",
        ["Automatically hides in a nearby closet when an entity is near."] = "Автоматически прячет в ближайший шкаф при приближении сущности.",
        ["Spectate Entity"] = "Наблюдать за сущностью",
        ["Spectates the entity while auto hiding."] = "Наблюдает за сущностью во время автоукрытия.",
        ["Miscellaneous"] = "Разное",
        ["Play Again"] = "Играть снова",
        ["Makes you join a new run, click again to cancel."] = "Запускает новый забег; нажмите ещё раз для отмены.",
        ["Return to Lobby"] = "Вернуться в лобби",
        ["Makes you teleport back to the lobby."] = "Телепортирует вас обратно в лобби.",
        ["Revive"] = "Возродиться",
        ["Makes you revive, if you have a revive and haven't already revived in this run."] = "Возрождает, если у вас есть возрождение и вы ещё не использовали его в этом забеге.",
        ["Reset Character"] = "Сбросить персонажа",
        ["Kills your character on the server."] = "Убивает вашего персонажа на сервере.",
        ["Debug"] = "Отладка",
        ["Void"] = "В пустоту",
        ["Teleports your character to Y -120."] = "Телепортирует персонажа на высоту Y = -120.",
        ["Exit Closet"] = "Выйти из шкафа",
        ["Exits the current closet."] = "Выводит из текущего шкафа.",
        ["Bypass / Solve"] = "Обход / Решение",
        ["Bypass Giggle"] = "Обход Giggle",
        ["Bypass Dupe"] = "Обход Dupe",
        ["Bypass Eyes"] = "Обход Eyes",
        ["Bypass Lookman"] = "Обход Lookman",
        ["Bypass Gloombat Eggs"] = "Обход яиц Gloombat",
        ["Bypass Seek Obstructions"] = "Обход препятствий Seek",
        ["Bypass Vacuum"] = "Обход Vacuum",
        ["Bypass Killbricks"] = "Обход смертельных блоков",
        ["Bypass Seeking Wall"] = "Обход стены Seek",
        ["Bypass Snare"] = "Обход Snare",
        ["Bypass Banana"] = "Обход банановой кожуры",
        ["Bypass Jeff"] = "Обход Jeff",
        ["Prevents 'Giggle' from attacking you."] = "Защищает от атак Giggle.",
        ["Prevents you from open 'Dupe' fake doors."] = "Не даёт открыть ложные двери Dupe.",
        ["Prevents 'Eyes' from hurting you."] = "Защищает от урона Eyes.",
        ["Prevents 'Lookman' from hurting you."] = "Защищает от урона Lookman.",
        ["Prevents taking damage from stepping on 'Gloombat' eggs."] = "Защищает от урона при наступании на яйца Gloombat.",
        ["Prevents obstacles in the 'Seek' chase from harming you."] = "Защищает от препятствий в погоне Seek.",
        ["Prevents you from falling into 'Vacuum' fake doors."] = "Не даёт провалиться в ложные двери Vacuum.",
        ["Prevents 'Lava' from hurting you."] = "Защищает от урона лавы.",
        ["Prevents 'ScaryWall' from hurting you."] = "Защищает от урона ScaryWall.",
        ["Prevents 'Snare' from trapping you."] = "Не даёт попасть в ловушку Snare.",
        ["Prevents 'Banana Peel' from slipping you up (sometimes doesn't work)."] = "Защищает от скольжения на банановой кожуре (работает не всегда).",
        ["Prevents 'Jeff the Killer' from stabbing you (sometimes doesn't work)."] = "Защищает от ножа Jeff the Killer (работает не всегда).",
        ["Anti-Lag"] = "Оптимизация",
        ["Disable Particles"] = "Отключить частицы",
        ["Disables particle emitters locally."] = "Локально отключает эмиттеры частиц.",
        ["Disable Trails / Beams"] = "Отключить следы / лучи",
        ["Disables Trails and Beams locally."] = "Локально отключает следы и лучи.",
        ["Disable Lights"] = "Отключить источники света",
        ["Disables PointLights, SpotLights, and SurfaceLights locally."] = "Локально отключает точечные, направленные и поверхностные источники света.",
        ["Hide Textures"] = "Скрыть текстуры",
        ["Hides Decals and Textures locally."] = "Локально скрывает декали и текстуры.",
        ["Reduce Materials"] = "Упростить материалы",
        ["Changes BaseParts to SmoothPlastic locally."] = "Локально заменяет материалы деталей на гладкий пластик.",
        ["Disable Post Effects"] = "Отключить постобработку",
        ["Disables post-processing effects locally."] = "Локально отключает эффекты постобработки.",
        ["Disable Shadows"] = "Отключить тени",
        ["Disables global lighting shadows locally."] = "Локально отключает глобальные тени освещения.",
        ["Exploits / Anti"] = "Эксплойты / Защита",
        ["Anti Ransom"] = "Защита от Ransom",
        ["Prevents 'Ransom' from attacking you."] = "Защищает от атак Ransom.",
        ["Anti Closet Trash"] = "Без мусора в шкафах",
        ["Prevents 'Closet Trash' from spawning."] = "Предотвращает появление мусора в шкафах.",
        ["Forget Me Not Skipper"] = "Пропуск Forget Me Not",
        ["Automatically Skippes Forget Me Not doors."] = "Автоматически пропускает двери Forget Me Not.",
        ["Time Shower"] = "Показать время",
        ["Shows the Archives clock time."] = "Показывает время на часах Архивов.",
        ["Stop Time/Anti Stampede"] = "Остановка времени / Защита от стада",
        ["Prevents 'The Drones Stampede' from attacking you."] = "Защищает от атак The Drones Stampede.",
        ["Time: --:--"] = "Время: --:--",
        ["Time: "] = "Время: ",
        ["Bypasses"] = "Обходы",
        ["Bypass Electric Water"] = "Обход воды под напряжением",
        ["Prevents electric water from hurting you."] = "Защищает от урона воды под напряжением.",
        ["Bypass Alma"] = "Обход Alma",
        ["Prevents 'Alma' from spawning."] = "Предотвращает появление Alma.",
        ["Bypass Drones"] = "Обход дронов",
        ["Prevents 'Drones' from attacking you."] = "Защищает от атак дронов.",
        ["Bypass Scribbles"] = "Обход Scribbles",
        ["Prevents 'Scribbles' from attacking you."] = "Защищает от атак Scribbles.",
        ["Experimental"] = "Экспериментальное",
        ["Please Enter The First ForgetMeNot Door"] = "Войдите в первую дверь Forget Me Not.",
        ["Spam Void In Debug If Stuck In ForgetMeNot"] = "Если застряли в Forget Me Not, нажимайте «В пустоту» в разделе «Отладка».",
        ["PositionSpoof Will Break This!."] = "Подмена позиции нарушит работу этой функции!",
        ["Water Bypass removed: Softlock."] = "Обход воды отключён: риск застревания.",
        ["Bypass"] = "Обход",
        ["Anticheat Bypass"] = "Обход античита",
        ["Completely disables the anticheat, after interacting with a ladder."] = "Полностью отключает античит после взаимодействия с лестницей.",
        ["Velocity Manipulation"] = "Управление скоростью",
        ["Moves your character forward slowly, mitigating the game's anti-noclip."] = "Медленно перемещает персонажа вперёд, ослабляя защиту игры от прохода сквозь стены.",
        ["Manipulation Method"] = "Способ перемещения",
        ["Infinite Items"] = "Бесконечные предметы",
        ["Allows certain items to be used without draining their uses."] = "Позволяет использовать некоторые предметы без расходования зарядов.",
        ["Item List"] = "Список предметов",
        ["Infinite Crucifix"] = "Бесконечное распятие",
        ["Risky! You can die or lose the Crucifix. Recommended to have low ping and stable fps."] = "Рискованно! Можно погибнуть или потерять распятие. Рекомендуются низкий пинг и стабильный FPS.",
        ["Position Spoof"] = "Подмена позиции",
        ["Makes your character appear underground on the server, protecting you from rush-like entities."] = "На сервере персонаж находится под землёй, что защищает от сущностей типа Rush.",
        ["Crouch Spoof"] = "Подмена приседания",
        ["Makes the game think you are always crouching."] = "Игра считает, что вы постоянно приседаете.",
        ["Remove"] = "Удаление",
        ["Remove Screech"] = "Удалить Screech",
        ["Remove Halt"] = "Удалить Halt",
        ["Remove A-90"] = "Удалить A-90",
        ["Remove Dread"] = "Удалить Dread",
        ["Remove Surge"] = "Удалить Surge",
        ["Prevents 'Screech' from spawning."] = "Предотвращает появление Screech.",
        ["Prevents 'Halt' from spawning."] = "Предотвращает появление Halt.",
        ["Prevents 'A-90' from spawning."] = "Предотвращает появление A-90.",
        ["Prevents 'Dread' from spawning."] = "Предотвращает появление Dread.",
        ["Prevents 'Surge' from spawning."] = "Предотвращает появление Surge.",
        ["No Screech Damage"] = "Без урона Screech",
        ["No Halt Damage"] = "Без урона Halt",
        ["No A-90 Damage"] = "Без урона A-90",
        ["No Surge Damage"] = "Без урона Surge",
        ["Prevents 'Screech' from hurting you."] = "Защищает от урона Screech.",
        ["Prevents 'Halt' from hurting you."] = "Защищает от урона Halt.",
        ["Prevents 'A-90' from hurting you."] = "Защищает от урона A-90.",
        ["Prevents 'Surge' from hurting you."] = "Защищает от урона Surge.",
        ["Audio"] = "Звук",
        ["Remove Footstep Sounds"] = "Без звуков шагов",
        ["Removes the sounds when walking."] = "Убирает звуки ходьбы.",
        ["Remove Jammin Music"] = "Без музыки Jammin",
        ["Removes the music and muffle effect from the 'Jammin' modifier."] = "Убирает музыку и приглушение от модификатора Jammin.",
        ["Remove Interacting Sounds"] = "Без звуков взаимодействия",
        ["Removes the sounds when interacting with proximity prompts."] = "Убирает звуки взаимодействия с объектами.",
        ["Camera / Effects"] = "Камера / Эффекты",
        ["Camera"] = "Камера",
        ["Ambient"] = "Окружающее освещение",
        ["Changes the lighting color to the specified value."] = "Меняет цвет освещения на указанный.",
        ["Field of View"] = "Угол обзора",
        ["Custom FOV"] = "Свой угол обзора",
        ["Custom Fov"] = "Свой угол обзора",
        ["Only applies the Field of View slider when enabled."] = "Применяет настройку угла обзора только при включении.",
        ["Remove Camera Shake"] = "Без тряски камеры",
        ["Prevents the camera from shaking."] = "Убирает тряску камеры.",
        ["Remove Camera Bobbing"] = "Без покачивания камеры",
        ["Prevents the camera from bobbing when moving."] = "Убирает покачивание камеры при движении.",
        ["Remove Cutscenes"] = "Без кат-сцен",
        ["Removes all non-necessary cutscenes."] = "Убирает необязательные кат-сцены.",
        ["Remove Fog"] = "Без тумана",
        ["Removes all fog effects from the camera."] = "Убирает эффекты тумана с камеры.",
        ["Third Person"] = "Вид от третьего лица",
        ["Zooms out your camera, allowing you to see your character from behind."] = "Отдаляет камеру, позволяя видеть персонажа со спины.",
        ["X Offset"] = "Смещение X",
        ["Y Offset"] = "Смещение Y",
        ["Z Offset"] = "Смещение Z",
        ["Wall Check"] = "Проверка стен",
        ["Prevents third person from going through walls."] = "Не даёт камере от третьего лица проходить сквозь стены.",
        ["Viewmodel Offset"] = "Смещение модели рук",
        ["Changes the offset of your viewmodel while holding an item."] = "Меняет положение модели рук при удержании предмета.",
        ["Effects"] = "Эффекты",
        ["Transparent Hiding Spots"] = "Прозрачные укрытия",
        ["Makes a hiding spot transparent when you enter it."] = "Делает укрытие прозрачным, когда вы в него входите.",
        ["Transparency"] = "Прозрачность",
        ["Disable Glitch Jumpscare"] = "Без скримера Glitch",
        ["Disable Timothy Jumpscare"] = "Без скримера Timothy",
        ["Disable Void Jumpscare"] = "Без скримера Void",
        ["Disables the jumpscare from 'Glitch'"] = "Отключает скример Glitch.",
        ["Disables the jumpscare from 'Timothy'"] = "Отключает скример Timothy.",
        ["Disables the jumpscare from 'Void'"] = "Отключает скример Void.",
        ["Disable Hide Vignette"] = "Без затемнения в укрытии",
        ["Disables the hiding screen effect."] = "Отключает экранный эффект при укрытии.",
        ["Disable Firedamp Effect"] = "Без эффекта рудничного газа",
        ["Disables the firedamp screen effect."] = "Отключает экранный эффект рудничного газа.",
        ["Disable Entity Jumpscares"] = "Без скримеров сущностей",
        ["Disables jumpscares from entities like Rush and Ambush."] = "Отключает скримеры сущностей вроде Rush и Ambush.",
        ["Entities / Settings"] = "Сущности / Настройки",
        ["Entities"] = "Сущности",
        ["Entity List"] = "Список сущностей",
        ["Notify Entities"] = "Уведомлять о сущностях",
        ["Sends a notification when an entity spawns."] = "Уведомляет о появлении сущности.",
        ["Notify Items"] = "Уведомлять о предметах",
        ["Sends a notification when an item spawns."] = "Уведомляет о появлении предмета.",
        ["Show Distance"] = "Показать расстояние",
        ["Shows how far away the item is in the notification."] = "Показывает расстояние до предмета в уведомлении.",
        ["Notify Library Code"] = "Уведомлять о коде библиотеки",
        ["Automatically solves the code for the library padlock."] = "Автоматически определяет код замка библиотеки.",
        ["Notify Oxygen Level"] = "Уведомлять об уровне кислорода",
        ["Shows how much oxygen you have remaining."] = "Показывает оставшийся кислород.",
        ["Notify Haste Time"] = "Уведомлять о таймере Haste",
        ["Shows how much time you have remaining before 'Haste' spawns."] = "Показывает время до появления Haste.",
        ["Padlock code found!"] = "Код замка найден!",
        ["The code is: '"] = "Код: '",
        ["Notify Chat"] = "Уведомлять в чате",
        ["Sends a message in the chat when an entity spawns."] = "Отправляет сообщение в чат при появлении сущности.",
        ["Message"] = "Сообщение",
        ["spawned!"] = "появился!",
        ["Notify Style"] = "Стиль уведомлений",
        ["Sound Volume"] = "Громкость звука",
        ["Play Sound"] = "Воспроизводить звук",
        ["Makes notifications play an alert sound."] = "Воспроизводит звуковой сигнал при уведомлении.",
        ["Keep Notifications"] = "Сохранять уведомления",
        ["Certain notifications will stay on screen until they are no longer needed."] = "Некоторые уведомления остаются на экране, пока актуальны.",
        ["Test Notification"] = "Проверить уведомления",
        ["Sends a test notification."] = "Отправляет тестовое уведомление.",
        ["This is a test."] = "Это тестовое уведомление.",
        ["ESP/Settings"] = "ESP / Настройки",
        ["Objectives"] = "Цели",
        ["Highlights all objects required to progress."] = "Подсвечивает объекты, необходимые для прохождения.",
        ["Doors"] = "Двери",
        ["Highlights the next door."] = "Подсвечивает следующую дверь.",
        ["Hiding Spots"] = "Укрытия",
        ["Highlights places where you can hide from entities"] = "Подсвечивает места, где можно спрятаться от сущностей.",
        ["Players"] = "Игроки",
        ["Highlights other players."] = "Подсвечивает других игроков.",
        ["Chests"] = "Сундуки",
        ["Highlights objects that can contain loot."] = "Подсвечивает объекты, в которых может быть добыча.",
        ["Items"] = "Предметы",
        ["Highlights all collectable items/consumables."] = "Подсвечивает все подбираемые предметы и расходники.",
        ["Currency"] = "Валюта",
        ["Highlights all currency that spawns."] = "Подсвечивает появляющуюся валюту.",
        ["Ladders"] = "Лестницы",
        ["Highlights ladders that can be used to disable the anticheat."] = "Подсвечивает лестницы, позволяющие отключить античит.",
        ["Highlights all entities that spawn."] = "Подсвечивает появляющиеся сущности.",
        ["Rainbow Effect"] = "Радужный эффект",
        ["Makes the esp objects change colour like a rainbow."] = "Меняет цвета ESP по цветам радуги.",
        ["Shows how far away your character is from the object."] = "Показывает расстояние от персонажа до объекта.",
        ["Fill Transparency"] = "Прозрачность заливки",
        ["Outline Transparency"] = "Прозрачность контура",
        ["Text Transparency"] = "Прозрачность текста",
        ["Text Outline Transparency"] = "Прозрачность обводки текста",
        ["Fade Time"] = "Время затухания",
        ["Render Limit"] = "Лимит отрисовки",
        ["Text Size"] = "Размер текста",
        ["Text Font"] = "Шрифт текста",
        ["Tracer Origin"] = "Начало линий",
        ["Tracer Thickness"] = "Толщина линий",
        ["Enable Tracers"] = "Показать линии",
        ["Draws a line to highlighted objects."] = "Рисует линии до подсвеченных объектов.",
        ["Arrow Radius"] = "Радиус стрелок",
        ["Enable Arrows"] = "Показать стрелки",
        ["Shows arrows that point to off-screen objects."] = "Показывает стрелки к объектам за пределами экрана.",
        ["Compatability Warning"] = "Предупреждение о совместимости",
        ["Features highlighted in red do not work in the current floor."] = "Функции, выделенные красным, не работают на текущем этаже.",
        ["Auto Steer Minecart"] = "Автоуправление вагонеткой",
        ["Automatically completes the minecart chase."] = "Автоматически проходит погоню на вагонетке.",
        ["Turn Distance"] = "Дальность поворота",
        ["Crouch Distance"] = "Дальность приседания",
        ["Auto Rooms"] = "Автопрохождение Rooms",
        ["Automatically moves and hides from entities in The Rooms."] = "Автоматически идёт и прячется от сущностей в The Rooms.",
        ["Pathfind Timeout"] = "Тайм-аут поиска пути",
        ["Ignore A-60"] = "Игнорировать A-60",
        ["Continues to walk if entity 'A-60' is present, enables position spoof automatically."] = "Продолжает идти при наличии A-60 и автоматически включает подмену позиции.",
        ["Show Path"] = "Показать путь",
        ["Shows the current path of rooms auto-walk."] = "Показывает текущий путь автопрохождения Rooms.",
        ["Spoof Footsteps"] = "Подмена шагов",
        ["Makes it appear as if your character is walking normally."] = "Создаёт видимость обычной ходьбы персонажа.",
        ["Path"] = "Путь",
        ["Completion"] = "Прохождение",
        ["Auto Complete Dam Seek"] = "Автопрохождение плотины Seek",
        ["Automatically teleports to and interacts with each water pump."] = "Автоматически телепортируется к каждому насосу и взаимодействует с ним.",
        ["You must be in Room 200 to do this."] = "Для этого нужно находиться в комнате 200.",
        ["Attempting to complete the valves."] = "Попытка закрыть вентили.",
        ["Please wait."] = "Подождите.",
        ["Successfully completed the valves."] = "Вентили успешно закрыты.",
        ["Auto Complete Cringle"] = "Автоматическое задание Cringle",
        ["Instantly completes the quest."] = "Мгновенно выполняет задание.",
        ["Show Seek Path"] = "Показать путь Seek",
        ["Shows you the correct path in seek chases."] = "Показывает правильный путь в погонях Seek.",
        ["Seek Path"] = "Путь Seek",
        ["Show Eyestalk Path"] = "Показать путь Eyestalk",
        ["Shows you the correct path in the eyestalk chase."] = "Показывает правильный путь в погоне Eyestalk.",
        ["Eyestalk Path"] = "Путь Eyestalk",
        ["Delete Seek Trigger"] = "Удалить триггер Seek",
        ["Disables the 'Seek' chase trigger."] = "Отключает триггер погони Seek.",
        ["Delete Figure"] = "Удалить Figure",
        ["Completely removes the entity 'Figure' (doesn't always work)."] = "Полностью удаляет Figure (работает не всегда).",
        ["Infinite Revives"] = "Бесконечные возрождения",
        ["Automatically revives after dying, with unlimited respawns."] = "Автоматически возрождает после смерти без ограничения числа возрождений.",
        ["Figure Godmode"] = "Неуязвимость к Figure",
        ["Prevents 'Figure' from hurting you."] = "Защищает от урона Figure.",
        ["Remove Basement Gate"] = "Удалить ворота подвала",
        ["Removes the gate from basement rooms."] = "Удаляет ворота в подвальных комнатах.",
        ["Remove Paintings Door"] = "Удалить дверь с картинами",
        ["Removes the fireplace doors from painting rooms."] = "Удаляет двери камина в комнатах с картинами.",
        ["Remove Skeleton Door"] = "Удалить дверь скелета",
        ["Removes the skeleton door from the infirmary."] = "Удаляет дверь скелета в лазарете.",
        ["Farming"] = "Фарм",
        ["Knob Farm"] = "Фарм Knobs",
        ["Automatically gains knobs for you, dies and revives repeatedly."] = "Автоматически зарабатывает Knobs, повторяя смерть и возрождение.",
        ["Start Knob Farm"] = "Начать фарм Knobs",
        ["Starts farming knobs, click this when you have enough gold."] = "Начинает фарм Knobs; нажмите, когда соберёте достаточно золота.",
        ["You must be in Room 0 to use this."] = "Для этого нужно находиться в комнате 0.",
        ["You must have gold to do this."] = "Для этого нужно золото.",
        ["Start Death Farm"] = "Начать фарм смертей",
        ["Automatically farms deaths, joining new runs."] = "Автоматически набирает смерти, присоединяясь к новым забегам.",
        ["Death Farm"] = "Фарм смертей",
        ["Starting death farm..."] = "Запуск фарма смертей...",
        ["Incompatible"] = "Несовместимо",
        ["Copy Death Farm Loadstring"] = "Скопировать код фарма смертей",
        ["Copies the death farm loadstring to your clipboard."] = "Копирует код запуска фарма смертей в буфер обмена.",
        ["Loadstring has been copied to your clipboard."] = "Код запуска скопирован в буфер обмена.",
        ["Please collect some gold to earn knobs."] = "Соберите немного золота, чтобы заработать Knobs.",
        ["Click 'Start Knob Farm' when you're ready."] = "Когда будете готовы, нажмите «Начать фарм Knobs».",
        ["Successfully disabled the anticheat."] = "Античит успешно отключён.",
        ["It will be re-enabled after a cutscene or halt room."] = "Он снова включится после кат-сцены или комнаты Halt.",
        ["The anticheat has been re-enabled."] = "Античит снова включён.",
        ["Interact with a ladder to disable it again."] = "Взаимодействуйте с лестницей, чтобы снова его отключить.",
        ["Died to FeatherHub"] = "Смерть от FeatherHub",
        ["Door Key"] = "Ключ от двери",
        ["Electrical Key"] = "Электрический ключ",
        ["Time Lever [+"] = "Рычаг времени [+",
        ["s]"] = " с]",
        ["Cellar"] = "Подвал",
        ["Fih Tank"] = "Аквариум Fih",
        ["Hint Book"] = "Книга-подсказка",
        ["Fuse Breaker"] = "Выключатель электрощита",
        ["Hint Paper"] = "Лист-подсказка",
        ["Anchor ["] = "Якорь [",
        ["Water Pump"] = "Водяной насос",
        ["Present"] = "Подарок",
        ["Gate Lever"] = "Рычаг ворот",
        ["Vine Lever"] = "Рычаг лозы",
        ["Generator"] = "Генератор",
        ["Generator Fuse"] = "Предохранитель генератора",
        ["Gate Button"] = "Кнопка ворот",
        ["Ladder"] = "Лестница",
        ["Door "] = "Дверь ",
        ["Closet"] = "Шкаф",
        ["Locker"] = "Шкафчик",
        ["Hiding_Spot"] = "Укрытие",
        ["Hiding Spot"] = "Укрытие",
        ["Bed"] = "Кровать",
        ["Double Bed"] = "Двуспальная кровать",
        ["Vent"] = "Вентиляция",
        ["Dumpster"] = "Мусорный контейнер",
        ["Locked Chest"] = "Запертый сундук",
        ["Chest"] = "Сундук",
        ["Locked Toolbox"] = "Запертый ящик с инструментами",
        ["Toolbox"] = "Ящик с инструментами",
        ["Vine Chest"] = "Сундук с лозой",
        ["Toolshed"] = "Сарай",
        ["Locked Item Locker"] = "Запертый шкафчик с предметами",
        ["Green Herb"] = "Зелёная трава",
        ["Gold Pile ["] = "Куча золота [",
        ["Stardust Pile"] = "Куча звёздной пыли",
        ["Gloombat Eggs"] = "Яйца Gloombat",
        ["Mandrake Hole"] = "Нора мандрагоры",
        ["DronesStampede"] = "Стадо дронов",
        ["Drones Stampede"] = "Стадо дронов",
        ["Gloombat Swarm"] = "Рой Gloombat",
        ["Custom Entity"] = "Пользовательская сущность",
        ["Frozen Ambush"] = "Замёрзший Ambush",
        ["Item '"] = "Появился предмет '",
        ["' has spawned."] = "'.",
        ["It is '"] = "До него '",
        ["' studs away from you."] = "' студов.",
        ["Entity 'Halt' will spawn in the next room."] = "Сущность 'Halt' появится в следующей комнате.",
        ["Attempting to solve the breaker box."] = "Попытка решить электрощит.",
        ["Successfully solved the breaker box."] = "Электрощит успешно решён.",
        ["Try going to the elevator!"] = "Попробуйте пройти к лифту!",
        ["Successfully loaded in "] = "Успешно загружено за ",
        [" seconds."] = " с.",
        ["Press '"] = "Нажмите '",
        ["' to toggle the UI."] = "', чтобы открыть или закрыть меню.",
        -- Только статические режимы dropdown; имена предметов, игроков и тем не переводятся.
        ["RushHub"] = "FeatherHub",
        ["Library"] = "Библиотека",
        ["Bottom"] = "Снизу",
        ["Center"] = "По центру",
        ["Top"] = "Сверху",
        ["Mouse"] = "Курсор",
        ["Player to Entity"] = "Игрок → Сущность",
        ["Entity to Player"] = "Сущность → Игрок",
        ["Glitch Fragments"] = "Фрагменты Glitch",
        ["Jeff Items"] = "Предметы Jeff",
        ["Dropped Items"] = "Брошенные предметы",
        ["Minecarts"] = "Вагонетки",
        ["Locks"] = "Замки",
        ["Always"] = "Всегда",
        ["Toggle"] = "Переключение",
        ["Hold"] = "Удержание",
        ["Press"] = "Нажатие",
        ["Lock"] = "Закрепить",
        ["Unlock"] = "Открепить",
        ["Search"] = "Поиск",
        ["Search..."] = "Поиск...",
        ["Keybinds"] = "Горячие клавиши",
        ["Visible Keybinds"] = "Видимые горячие клавиши",
        ["None"] = "Нет",
        ["Notification"] = "Уведомление",
        ["No Title"] = "Без заголовка",
        ["No Footer"] = "Без подписи",
        ["Dialog"] = "Диалог",
        ["Description"] = "Описание",
        ["Input"] = "Ввод",
        ["Slider"] = "Ползунок",
        ["KeyPicker"] = "Выбор клавиши",
        ["Key"] = "Клавиша",
        ["Execute"] = "Выполнить",
        ["Error"] = "Ошибка",
        ["Error Message"] = "Сообщение об ошибке",
        ["Are you sure?"] = "Вы уверены?",
        ["Copy color"] = "Скопировать цвет",
        ["Paste color"] = "Вставить цвет",
        ["Copied color"] = "Цвет скопирован",
        ["Pasted color"] = "Цвет вставлен",
        ["Nothing to paste"] = "Нечего вставлять",
        ["Copy Hex"] = "Скопировать HEX",
        ["Copy RGB"] = "Скопировать RGB",
        -- SaveManager / ThemeManager: только известные интерфейсные строки.
        ["Configuration"] = "Конфигурация",
        ["Config name"] = "Название конфигурации",
        ["Create config"] = "Создать конфигурацию",
        ["Configuration name cannot be empty."] = "Название конфигурации не может быть пустым.",
        ["Invalid config name provided."] = "Недопустимое название конфигурации.",
        ["Invalid config name provided"] = "Недопустимое название конфигурации",
        ["Config already exists"] = "Конфигурация уже существует",
        ["Config list"] = "Список конфигураций",
        ["Load config"] = "Загрузить конфигурацию",
        ["Please select a config first."] = "Сначала выберите конфигурацию.",
        ["Overwrite config"] = "Перезаписать конфигурацию",
        ["Delete config"] = "Удалить конфигурацию",
        ["Refresh list"] = "Обновить список",
        ["Set as autoload"] = "Загружать автоматически",
        ["Reset autoload"] = "Сбросить автозагрузку",
        ["Reset autoload config"] = "Сбросить конфигурацию автозагрузки",
        ["Are you sure you want to clear the autoload config? No config will be loaded automatically on next launch."] = "Сбросить автозагрузку? При следующем запуске конфигурация не будет загружена автоматически.",
        ["Successfully reset autoload config."] = "Автозагрузка конфигурации сброшена.",
        ["Config JSON"] = "JSON конфигурации",
        ["Import config"] = "Импортировать конфигурацию",
        ["Configuration JSON cannot be empty"] = "JSON конфигурации не может быть пустым",
        ["Are you sure you want to import this configuration? Your current settings will be overwritten."] = "Импортировать эту конфигурацию? Текущие настройки будут перезаписаны.",
        ["Successfully imported config"] = "Конфигурация импортирована",
        ["Export current config"] = "Экспортировать текущую конфигурацию",
        ["Copied config to your clipboard"] = "Конфигурация скопирована в буфер обмена",
        ["No config is selected"] = "Конфигурация не выбрана",
        ["Config file does not exist"] = "Файл конфигурации не существует",
        ["Config file not found"] = "Файл конфигурации не найден",
        ["Config does not exist"] = "Конфигурация не существует",
        ["Failed to read config file"] = "Не удалось прочитать файл конфигурации",
        ["Autoload config is not set"] = "Конфигурация автозагрузки не задана",
        ["Failed to decode config data"] = "Не удалось декодировать данные конфигурации",
        ["Themes"] = "Темы",
        ["Background color"] = "Цвет фона",
        ["Main color"] = "Основной цвет",
        ["Accent color"] = "Цвет акцента",
        ["Outline color"] = "Цвет контура",
        ["Font color"] = "Цвет текста",
        ["Contrast check: n/a"] = "Проверка контраста: нет данных",
        ["Font Face"] = "Шрифт",
        ["Background Image"] = "Фоновое изображение",
        ["Theme list"] = "Список тем",
        ["Set as default"] = "Использовать по умолчанию",
        ["Custom theme name"] = "Название своей темы",
        ["Create theme"] = "Создать тему",
        ["Theme name cannot be empty."] = "Название темы не может быть пустым.",
        ["Invalid theme name provided."] = "Недопустимое название темы.",
        ["Invalid theme name provided"] = "Недопустимое название темы",
        ["Theme already exists"] = "Тема уже существует",
        ["Custom themes"] = "Свои темы",
        ["Load theme"] = "Загрузить тему",
        ["Please select a theme first."] = "Сначала выберите тему.",
        ["Overwrite theme"] = "Перезаписать тему",
        ["Delete theme"] = "Удалить тему",
        ["Reset default"] = "Сбросить тему по умолчанию",
        ["Reset default theme"] = "Сбросить тему по умолчанию",
        ["Are you sure you want to clear the default theme? The library will revert to its built-in default on next load."] = "Сбросить тему по умолчанию? При следующей загрузке будет использована встроенная тема.",
        ["Successfully reset default theme."] = "Тема по умолчанию сброшена.",
        ["Theme JSON"] = "JSON темы",
        ["Import theme"] = "Импортировать тему",
        ["Theme JSON cannot be empty"] = "JSON темы не может быть пустым",
        ["Are you sure you want to import this theme? Your current colors will be overwritten."] = "Импортировать эту тему? Текущие цвета будут перезаписаны.",
        ["Successfully imported theme"] = "Тема импортирована",
        ["Export current theme"] = "Экспортировать текущую тему",
        ["Copied theme to your clipboard"] = "Тема скопирована в буфер обмена",
        ["No theme is selected"] = "Тема не выбрана",
        ["Theme file does not exist"] = "Файл темы не существует",
        ["Theme file not found"] = "Файл темы не найден",
        ["Theme not found"] = "Тема не найдена",
        ["Theme does not exist"] = "Тема не существует",
        ["Default theme is not set"] = "Тема по умолчанию не задана",
        ["Invalid theme data"] = "Недопустимые данные темы",
        ["Failed to decode theme data"] = "Не удалось декодировать данные темы",
        ["Invalid path provided"] = "Недопустимый путь",
        ["Failed to encode data"] = "Не удалось закодировать данные",
        ["No JSON provided"] = "JSON не указан",
        ["Cancel"] = "Отмена",
        ["Overwrite"] = "Перезаписать",
        ["Delete"] = "Удалить",
        ["Load"] = "Загрузить",
        ["Reset"] = "Сбросить",
        ["Import"] = "Импортировать",
        ["Low contrast theme"] = "Тема с низким контрастом",
        ["Save Anyway"] = "Всё равно сохранить",
        ["font color vs. background color"] = "цветом текста и цветом фона",
        ["font color vs. main color"] = "цветом текста и основным цветом",
    }
    local ItemTranslations = {
        ["Sally Toy"] = "Игрушка Sally", ["Lunch Box"] = "Ланч-бокс",
        ["Honey Pot"] = "Баночка мёда", ["Fih Food"] = "Корм Fih",
        ["CD Disc"] = "CD-диск", ["Pizza"] = "Пицца", ["Paper Plane"] = "Бумажный самолёт",
        ["Lighter"] = "Зажигалка", ["Flashlight"] = "Фонарик", ["Lockpicks"] = "Отмычки",
        ["Vitamins"] = "Витамины", ["Bandage"] = "Бинт",
        ["Starlight Vial"] = "Флакон звёздного света", ["Starlight Bottle"] = "Бутылка звёздного света",
        ["Starlight Barrel"] = "Бочка звёздного света", ["Gummy Flashlight"] = "Динамо-фонарик",
        ["Straplight"] = "Налобный фонарь", ["Spotlight"] = "Прожектор", ["Battery"] = "Батарейка",
        ["Candle"] = "Свеча", ["Crucifix"] = "Распятие", ["Glowstick"] = "Светящаяся палочка",
        ["Skeleton Key"] = "Ключ скелета", ["Candy"] = "Конфета",
        ["Mini Shield Potion"] = "Малое зелье щита", ["Big Shield Potion"] = "Большое зелье щита",
        ["Bandage Pack"] = "Набор бинтов", ["Battery Pack"] = "Набор батареек",
        ["Moonlight Candle"] = "Свеча лунного света", ["Laser Pointer"] = "Лазерная указка",
        ["Holy Hand Grenade"] = "Святая ручная граната", ["Shears"] = "Садовые ножницы",
        ["Smoothie"] = "Смузи", ["Cheese"] = "Сыр", ["Bread"] = "Хлеб", ["Alarm Clock"] = "Будильник",
        ["Moonlight Smoothie"] = "Смузи лунного света", ["Gween Soda"] = "Газировка Gween",
        ["Glitch Fragment"] = "Фрагмент глитча", ["Tablet"] = "Планшет", ["Bomb"] = "Бомба",
        ["Knockbomb"] = "Бомба Knockbomb", ["Nanner"] = "Банан Nanner", ["Big Bomb"] = "Большая бомба",
        ["Hiding Box"] = "Коробка для укрытия", ["Golden Gun"] = "Золотой пистолет",
        ["Stop Sign"] = "Знак «Стоп»", ["Tip Jar"] = "Банка для чаевых", ["Lantern"] = "Фонарь",
        ["Iron Key"] = "Железный ключ", ["Lotus Petal"] = "Лепесток лотоса", ["Compass"] = "Компас",
        ["Multitool"] = "Мультитул", ["Rift Jar"] = "Банка разлома", ["Aloe Vera"] = "Алоэ вера",
        ["Donut"] = "Пончик", ["Lotus"] = "Лотос", ["Boxing Gloves"] = "Боксёрские перчатки",
    }
    for Name, Text in pairs(ItemTranslations) do Translations[Name] = Text end
    Translations["Velocity"] = "Скорость"
    Translations["Pivot"] = "Позиция"
    local Modes = {
        ["RushHub"] = true, ["Doors"] = true, ["STX"] = true, ["Library"] = true,
        ["Velocity"] = true, ["Pivot"] = true,
        ["Bottom"] = true, ["Center"] = true, ["Top"] = true, ["Mouse"] = true,
        ["Player to Entity"] = true, ["Entity to Player"] = true,
        ["Glitch Fragments"] = true, ["Jeff Items"] = true, ["Dropped Items"] = true,
        ["Currency"] = true, ["Minecarts"] = true, ["Locks"] = true,
        ["Rush"] = true, ["Bash"] = true, ["Scribbles"] = true, ["Teller"] = true,
        ["DronesStampede"] = true, ["Ambush"] = true, ["Eyes"] = true, ["Halt"] = true,
        ["Blitz"] = true, ["Lookman"] = true, ["Dupe"] = true, ["Figure"] = true,
        ["Snare"] = true, ["Giggle"] = true, ["Gloombat Eggs"] = true, ["Gloombat Swarm"] = true,
        ["Grumble"] = true, ["A-60"] = true, ["A-120"] = true, ["Sally"] = true,
        ["Jeff the Killer"] = true, ["Groundskeeper"] = true, ["Mandrake Hole"] = true,
        ["Monument"] = true, ["Bramble"] = true, ["AR0xMBUSH"] = true, ["RNIUSHCG=="] = true,
    }
    for Name in pairs(ItemTranslations) do Modes[Name] = true end
    local ModeDropdowns = {
        NotifyStyle = true, ESPTracersOrigin = true,
        SpecateEntityMode = true, AutoInteractIgnoreList = true,
        AutoClosetEntityList = true, EntityList = true, EntityESPOptions = true,
        NotifyItemList = true, InfiniteItemsList = true, VelocityManipulationMode = true,
    }
    local Prefixes = {
        {"Current autoload config: ", "Текущая автозагрузка: "},
        {"Current default theme: ", "Текущая тема по умолчанию: "},
        {"Failed to load config list: ", "Не удалось загрузить список конфигураций: "},
        {"Failed to load theme list: ", "Не удалось загрузить список тем: "},
        {"Failed to load autoload config: ", "Не удалось загрузить конфигурацию автозагрузки: "},
        {"Failed to apply default theme: ", "Не удалось применить тему по умолчанию: "},
        {"Failed to reset autoload config: ", "Не удалось сбросить автозагрузку: "},
        {"Failed to reset default theme: ", "Не удалось сбросить тему по умолчанию: "},
        {"Failed to delete theme: ", "Не удалось удалить тему: "},
        {"Failed to import theme: ", "Не удалось импортировать тему: "},
        {"Failed to import config: ", "Не удалось импортировать конфигурацию: "},
        {"Failed to write theme file: ", "Не удалось записать файл темы: "},
        {"Failed to write config file: ", "Не удалось записать файл конфигурации: "},
        {"Failed to delete theme file: ", "Не удалось удалить файл темы: "},
        {"Failed to delete config file: ", "Не удалось удалить файл конфигурации: "},
        {"Successfully loaded autoload config ", "Загружена конфигурация автозагрузки "},
        {"Successfully applied default theme ", "Применена тема по умолчанию "},
        {"Successfully set default theme to ", "Тема по умолчанию установлена: "},
        {"Successfully set autoload config to ", "Конфигурация автозагрузки установлена: "},
        {"Successfully created config ", "Создана конфигурация "},
        {"Successfully loaded config ", "Загружена конфигурация "},
        {"Successfully overwrote config ", "Перезаписана конфигурация "},
        {"Successfully deleted config ", "Удалена конфигурация "},
        {"Successfully created theme ", "Создана тема "},
        {"Successfully loaded theme ", "Загружена тема "},
        {"Successfully overwrote theme ", "Перезаписана тема "},
        {"Successfully deleted theme ", "Удалена тема "},
        {"Failed to create config ", "Не удалось создать конфигурацию "},
        {"Failed to load config ", "Не удалось загрузить конфигурацию "},
        {"Failed to overwrite config ", "Не удалось перезаписать конфигурацию "},
        {"Failed to delete config ", "Не удалось удалить конфигурацию "},
        {"Failed to set autoload config ", "Не удалось установить конфигурацию автозагрузки "},
        {"Failed to save theme ", "Не удалось сохранить тему "},
    }
    local Templates = {
        {"A config named ", " already exists. Overwriting will replace it with your current settings.", "Конфигурация ", " уже существует. Перезапись заменит её текущими настройками."},
        {"A custom theme named ", " already exists. Overwriting it will replace it with your current colors.", "Своя тема ", " уже существует. Перезапись заменит её текущими цветами."},
        {"Are you sure you want to load ", "? Your current settings will be overwritten.", "Загрузить ", "? Текущие настройки будут перезаписаны."},
        {"Are you sure you want to overwrite ", " with your current settings? This cannot be undone.", "Перезаписать ", " текущими настройками? Это действие нельзя отменить."},
        {"Are you sure you want to overwrite ", " with your current colors? This cannot be undone.", "Перезаписать ", " текущими цветами? Это действие нельзя отменить."},
        {"Are you sure you want to delete ", "? This cannot be undone.", "Удалить ", "? Это действие нельзя отменить."},
    }
    local function TranslateText(Text)
        if type(Text) ~= "string" then return Text end
        -- Если выбран английский, не переводим
        if Interface.Language == "EN" then return Text end
        if Translations[Text] then return Translations[Text] end
        for _, Rule in ipairs(Templates) do
            if Text:sub(1, #Rule[1]) == Rule[1] and Text:sub(-#Rule[2]) == Rule[2] then
                return Rule[3] .. Text:sub(#Rule[1] + 1, #Text - #Rule[2]) .. Rule[4]
            end
        end
        for _, Rule in ipairs(Prefixes) do
            if Text:sub(1, #Rule[1]) == Rule[1] then
                local Payload = Text:sub(#Rule[1] + 1)
                if Rule[1]:sub(1, 6) == "Failed" then
                    local Name, Error = Payload:match('^(.*"): (.*)$')
                    Payload = Name and (Name .. ": " .. TranslateText(Error)) or TranslateText(Payload)
                elseif Payload == "none" then
                    if (Rule[1] == "Current autoload config: " and not Interface.SaveManager.AutoloadConfig)
                        or (Rule[1] == "Current default theme: " and not Interface.ThemeManager.DefaultThemeName) then
                        Payload = "не задано"
                    end
                end
                return Rule[2] .. Payload
            end
        end
        local Key, Label, Mode = Text:match("^(%b[]) (.-) %((%a+)%)$")
        if Key and (Mode == "Toggle" or Mode == "Hold" or Mode == "Always" or Mode == "Press") then
            return Key .. " " .. (Translations[Label] or Label) .. " (" .. Translations[Mode] .. ")"
        end
        local Ratio = Text:match("^Contrast check: good %(([%d%.]+):1%)$")
        if Ratio then return "Проверка контраста: хороший (" .. Ratio .. ":1)" end
        local Low, Pair, Target = Text:match("^Low contrast %(([%d%.]+):1%) between (.-)%. Aim for at least ([%d%.]+):1 so text stays readable%.$")
        if Low and Translations[Pair] then
            return "Низкий контраст (" .. Low .. ":1) между " .. Translations[Pair] .. ". Для читаемости нужно не менее " .. Target .. ":1."
        end
        Pair, Low, Target = Text:match("^Your (.-) has a contrast ratio of ([%d%.]+):1, below the recommended ([%d%.]+):1%. Text may be hard to read%.$")
        if Pair and Translations[Pair] then
            return "Контраст между " .. Translations[Pair] .. " составляет " .. Low .. ":1, ниже рекомендованных " .. Target .. ":1. Текст может быть трудно читать."
        end
        Low, Pair, Target = Text:match("^This theme has a contrast ratio of ([%d%.]+):1 between (.-), below the recommended ([%d%.]+):1%. Text may be hard to read%. Save anyway%?$")
        if Low and Translations[Pair] then
            return "Контраст темы между " .. Translations[Pair] .. " составляет " .. Low .. ":1, ниже рекомендованных " .. Target .. ":1. Текст может быть трудно читать. Всё равно сохранить?"
        end
        return Text
    end
    local function TranslateModes(Text, Values)
        if Modes[Text] then return TranslateText(Text) end
        local Result = {}
        local Position = 1
        while Position <= #Text do
            local Separator = Text:find(", ", Position, true)
            local Part = Separator and Text:sub(Position, Separator - 1) or Text:sub(Position)
            if Modes[Part] then
                table.insert(Result, TranslateText(Part))
            elseif not Separator and Part:sub(-3) == "..." then
                local Prefix = Part:sub(1, -4)
                local Match
                local Ambiguous = false
                local AllUnchanged = true
                for _, Value in ipairs(Values) do
                    if Modes[Value] and Prefix ~= "" and Value:sub(1, #Prefix) == Prefix then
                        Ambiguous = Match ~= nil or Ambiguous
                        Match = Value
                        AllUnchanged = AllUnchanged and TranslateText(Value) == Value
                    end
                end
                if not Match then return Text end
                if Ambiguous then
                    if not AllUnchanged then return Text end
                    table.insert(Result, Part)
                else
                    table.insert(Result, TranslateText(Match) .. "...")
                end
            else
                return Text
            end
            if not Separator then break end
            Position = Separator + 2
        end
        return #Result > 0 and table.concat(Result, ", ") or Text
    end
    local Connections = {}
    local Tracked = setmetatable({}, {__mode = "k"})
    local Active = true
    local function Apply(Object, Property)
        if not Active or not Object:IsDescendantOf(Library.ScreenGui) then return end
        local Text = Object[Property]
        local Translated
        if Property == "Text" then
            for Id, Option in pairs(Library.Options) do
                if Option.Type == "Dropdown" and Object ~= Option.Label then
                    local Menu = Option.Menu and Option.Menu.Menu
                    if (Option.Container and Object:IsDescendantOf(Option.Container)) or (Menu and Object:IsDescendantOf(Menu)) then
                        if ModeDropdowns[Id] then
                            Translated = TranslateModes(Text, Option.Values)
                        elseif Id == "SaveManager_ConfigList" or Id == "ThemeManager_ThemeList" or Id == "ThemeManager_CustomThemeList" then
                            local Suffix = Id == "SaveManager_ConfigList" and " (autoload)" or " (default)"
                            local RussianSuffix = Id == "SaveManager_ConfigList" and " (автозагрузка)" or " (по умолчанию)"
                            local Name
                            if Id == "SaveManager_ConfigList" then
                                Name = Interface.SaveManager.AutoloadConfig
                            else
                                Name = Interface.ThemeManager.DefaultThemeName
                            end
                            -- Переводим лишь служебный суффикс; имя конфигурации/темы сохраняется.
                            if type(Name) == "string" and Text == Name .. Suffix then
                                Translated = Name .. RussianSuffix
                            elseif Object.Parent == Option.Container and Option.Value == Name and type(Name) == "string" then
                                local Display = Name .. Suffix
                                if #Display > 25 and Text == Display:sub(1, 22) .. "..." then
                                    Translated = Name .. RussianSuffix
                                end
                            end
                            if not Translated then return end
                        else
                            return
                        end
                        break
                    end
                end
            end
        end
        Translated = Translated or TranslateText(Text)
        if Translated ~= Text then Object[Property] = Translated end
    end
    local function Track(Object)
        if not Active or Tracked[Object] or not Object:IsDescendantOf(Library.ScreenGui) then return end
        local Property
        if Object:IsA("TextBox") then
            Property = "PlaceholderText"
        elseif Object:IsA("TextLabel") or Object:IsA("TextButton") then
            Property = "Text"
        else
            return
        end
        Tracked[Object] = true
        local Updating = false
        table.insert(Connections, Object:GetPropertyChangedSignal(Property):Connect(function()
            if Updating then return end
            Updating = true
            Apply(Object, Property)
            Updating = false
        end))
        Apply(Object, Property)
    end
    Interface.Localization = {
        TranslateText = TranslateText,
        Disconnect = function()
            Active = false
            for _, Connection in ipairs(Connections) do Connection:Disconnect() end
            table.clear(Connections)
        end,
    }
    table.insert(Connections, Library.ScreenGui.DescendantAdded:Connect(function(Object)
        task.defer(Track, Object)
    end))
    for _, Object in ipairs(Library.ScreenGui:GetDescendants()) do Track(Object) end
end

Interface.ThemeManager.BuiltInThemes = {
    ["Default"]        = { 1,  { FontColor = "ffffff", MainColor = "1c1c1c", AccentColor = "0055ff", BackgroundColor = "141414", OutlineColor = "323232" } },
    ["BBot"]           = { 2,  { FontColor = "ffffff", MainColor = "1e1e1e", AccentColor = "7e48a3", BackgroundColor = "232323", OutlineColor = "141414" } },
    ["Fatality"]       = { 3,  { FontColor = "ffffff", MainColor = "1e1842", AccentColor = "c50754", BackgroundColor = "191335", OutlineColor = "3c355d" } },
    ["Jester"]         = { 4,  { FontColor = "ffffff", MainColor = "242424", AccentColor = "db4467", BackgroundColor = "1c1c1c", OutlineColor = "373737" } },
    ["Mint"]           = { 5,  { FontColor = "ffffff", MainColor = "242424", AccentColor = "3db488", BackgroundColor = "1c1c1c", OutlineColor = "373737" } },
    ["Tokyo Night"]    = { 6,  { FontColor = "ffffff", MainColor = "191925", AccentColor = "6759b3", BackgroundColor = "16161f", OutlineColor = "323232" } },
    ["Ubuntu"]         = { 7,  { FontColor = "ffffff", MainColor = "3e3e3e", AccentColor = "e2581e", BackgroundColor = "323232", OutlineColor = "191919" } },
    ["Quartz"]         = { 8,  { FontColor = "ffffff", MainColor = "232330", AccentColor = "426e87", BackgroundColor = "1d1b26", OutlineColor = "27232f" } },
    ["Nord"]           = { 9,  { FontColor = "eceff4", MainColor = "3b4252", AccentColor = "88c0d0", BackgroundColor = "2e3440", OutlineColor = "4c566a" } },
    ["Dracula"]        = { 10, { FontColor = "f8f8f2", MainColor = "44475a", AccentColor = "ff79c6", BackgroundColor = "282a36", OutlineColor = "6272a4" } },
    ["Monokai"]        = { 11, { FontColor = "f8f8f2", MainColor = "272822", AccentColor = "f92672", BackgroundColor = "1e1f1c", OutlineColor = "49483e" } },
    ["Gruvbox"]        = { 12, { FontColor = "ebdbb2", MainColor = "3c3836", AccentColor = "fb4934", BackgroundColor = "282828", OutlineColor = "504945" } },
    ["Solarized"]      = { 13, { FontColor = "839496", MainColor = "073642", AccentColor = "cb4b16", BackgroundColor = "002b36", OutlineColor = "586e75" } },
    ["Catppuccin"]     = { 14, { FontColor = "d9e0ee", MainColor = "302d41", AccentColor = "f5c2e7", BackgroundColor = "1e1e2e", OutlineColor = "575268" } },
    ["One Dark"]       = { 15, { FontColor = "abb2bf", MainColor = "282c34", AccentColor = "c678dd", BackgroundColor = "21252b", OutlineColor = "5c6370" } },
    ["Cyberpunk"]      = { 16, { FontColor = "f9f9f9", MainColor = "262335", AccentColor = "00ff9f", BackgroundColor = "1a1a2e", OutlineColor = "413c5e" } },
    ["Oceanic Next"]   = { 17, { FontColor = "d8dee9", MainColor = "1b2b34", AccentColor = "6699cc", BackgroundColor = "16232a", OutlineColor = "343d46" } },
    ["Material"]       = { 18, { FontColor = "eeffff", MainColor = "212121", AccentColor = "82aaff", BackgroundColor = "151515", OutlineColor = "424242" } },
}

-- Палитра FeatherHub по умолчанию; сохранённая тема загружается позже.
do
    local Palette = { FontColor = "e7edf7", MainColor = "182235", AccentColor = "7dd3fc", BackgroundColor = "101827", OutlineColor = "2d405b", FontFace = "Gotham" }
    Interface.ThemeManager.BuiltInThemes["FeatherHub"] = { 0, Palette }
    Interface.ThemeManager:SetLibrary(Interface.Library)
    Interface.ThemeManager:ApplyThemeData(Palette)
end

Interface.DiscordInvite = "https://discord.gg/TCkcAsPQpQ"
Interface.CopyDiscordInvite = function()
    local Copy = type(setclipboard) == "function" and setclipboard or toclipboard
    local Success = type(Copy) == "function" and pcall(Copy, Interface.DiscordInvite)
    local DescRU = Success and ("Приглашение скопировано. Открой ссылку в браузере:\n" .. Interface.DiscordInvite)
        or ("Не удалось скопировать приглашение. Открой ссылку вручную:\n" .. Interface.DiscordInvite)
    local DescEN = Success and ("Invite copied. Open the link in your browser:\n" .. Interface.DiscordInvite)
        or ("Failed to copy invite. Open the link manually:\n" .. Interface.DiscordInvite)
    Interface.Library:Notify({
        Title = "Discord FeatherHub",
        Description = Interface.Language == "RU" and DescRU or DescEN,
        Time = Success and 8 or 15,
    })
end

-- InfoTab (inlined, de-obfuscated, rebranded)
Interface.ApplyInfoTab = function(Window)
    local Library = getgenv().FeatherHub.Interface.Library
    local LocalPlayer = game:GetService("Players").LocalPlayer
    local InfoTab = Window:AddTab(Interface.Language == "RU" and "Информация" or "Info", "info")
    local LeftBox = InfoTab:AddLeftGroupbox("Пользователь")
    LeftBox:AddLabel("Имя пользователя: " .. LocalPlayer.Name, true)
    LeftBox:AddLabel("Запусков: " .. ((getgenv().FeatherHub.TotalExecutions and getgenv().FeatherHub.TotalExecutions) or "0"), true)
    local ThumbType, ThumbSize = Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420
    local Thumb = game:GetService("Players"):GetUserThumbnailAsync(LocalPlayer.UserId, ThumbType, ThumbSize)
    LeftBox:AddImage("Avatar", { Image = Thumb })

    local CreditsBox = InfoTab:AddRightGroupbox("Благодарности")
    -- Подпись Feather и благодарность пользователю.
    local Credits = {
        "<font color='rgb(125, 211, 252)'>Feather - Scripter</font>",
        "<font color='rgb(50, 205, 50)'>" .. LocalPlayer.Name .. " — Спасибо за использование скрипта</font>",
    }
    for _, Credit in ipairs(Credits) do CreditsBox:AddLabel(Credit, true) end

    local ChangelogBox = InfoTab:AddRightGroupbox("История изменений")
    -- MODIFIED: Removed creator references from changelog
    local Changelog = {
        "<font color='rgb(0, 255, 0)'>+ Создано Feather</font>",
        "<font color='rgb(0, 255, 0)'>+ Добавлена вкладка «Лестница»</font>",
        "<font color='rgb(0, 255, 0)'>+ Добавлена защита от повторного запуска</font>",
        "<font color='rgb(0, 255, 0)'>+ Добавлена игрушка Sally в список предметов</font>",
        "<font color='rgb(0, 255, 0)'>+ Добавлено исключение ящиков Архивов в автовзаимодействии</font>",
        "<font color='rgb(0, 255, 0)'>+ Добавлена поддержка подвала</font>",
        "<font color='rgb(0, 255, 0)'>+ Добавлены настройки оптимизации во вкладке «Основное»</font>",
        "<font color='rgb(0, 255, 0)'>+ Добавлена панель FPS и пинга</font>",
        "<font color='rgb(255, 255, 0)'>~ Увеличено скругление окна (2 → 6)</font>",
        "<font color='rgb(255, 255, 0)'>~ Улучшена очистка при выгрузке</font>",
        "<font color='rgb(255, 255, 0)'>~ Улучшено взаимодействие с объектами Архивов</font>",
        "<font color='rgb(0, 255, 0)'>+ Исправлено падение FPS из-за ESP в мультиплеере (единая отрисовка)</font>",
    }
    for _, Entry in ipairs(Changelog) do ChangelogBox:AddLabel(Entry, true) end

    local EnvBox = InfoTab:AddLeftGroupbox("Результаты проверки среды")
    EnvBox:AddLabel("Исполнитель: " .. (getgenv().FeatherHub.Environment.identifyexecutor and getgenv().FeatherHub.Environment.identifyexecutor() or "Неизвестно"), true)
    for _, Result in ipairs(getgenv().FeatherHub.Environment.Results) do
        local Safe = Result:gsub("<", "("):gsub(">", ")")
        EnvBox:AddLabel(Safe, true)
    end

    local ActionBox = InfoTab:AddLeftGroupbox("Действия")
    ActionBox:AddButton({
        Text = "Discord", Icon = "link",
        Tooltip = "Копирует приглашение на Discord-сервер FeatherHub.",
        Func = Interface.CopyDiscordInvite,
    })
end

-- SettingsTab (inlined, rebranded)
Interface.ApplySettingsTab = function(Window)
    local function CloneReference(Object)
        if getgenv().FeatherHub and getgenv().FeatherHub.Environment.cloneref then
            return getgenv().FeatherHub.Environment.cloneref(Object)
        else return Object end
    end
    local Services = setmetatable({}, { __index = function(_, Name) return CloneReference(game:GetService(Name)) end })
    local Library = getgenv().FeatherHub.Interface.Library
    local SaveManager = getgenv().FeatherHub.Interface.SaveManager
    local ThemeManager = getgenv().FeatherHub.Interface.ThemeManager
    local Toggles = Library.Toggles
    local Options = Library.Options

    local SettingsTab = Window:AddTab(Interface.Language == "RU" and "Настройки" or "Settings", "settings")
    local MenuGroup = SettingsTab:AddLeftGroupbox(Interface.Language == "RU" and "Меню" or "Menu")

    MenuGroup:AddToggle("KeybindMenuOpen", {
        Default = Library.KeybindFrame.Visible, Text = "Показать меню горячих клавиш",
        Callback = function(value) Library.KeybindFrame.Visible = value end,
    })
    MenuGroup:AddToggle("ShowStatsOverlay", {
        Text = "Показывать FPS и пинг", Default = true,
        Tooltip = "Показать или скрыть панель статистики FeatherHub.",
        Callback = function(Value)
            local Hub = getgenv().FeatherHub
            if Hub and Hub.StatsGui then Hub.StatsGui.Enabled = Value end
        end,
    })
    MenuGroup:AddToggle("ShowCustomCursor", {
        Text = "Свой курсор", Default = false,
        Callback = function(Value) Library.ShowCustomCursor = Value end,
    })
    MenuGroup:AddToggle("QueueOnTeleport", {
        Text = "Загрузка после телепорта", Default = false,
        Tooltip = "Автоматически загружает FeatherHub после телепорта на другой сервер.",
        Callback = function(Value)
            if not Value then return end
            if queue_on_teleport then
                queue_on_teleport([[loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/Library.lua"))()]])
            end
        end,
    })
    MenuGroup:AddDropdown("UILibrary", {
        Text = "Стиль интерфейса", Values = { "Obsidian", "Linoria" },
        Default = (getgenv().FeatherHub.UILibrary == "Linoria" and 2 or 1),
        Callback = function(Value)
            if getgenv().FeatherHub.Environment.writefile and getgenv().FeatherHub.Environment.readfile then
                if not getgenv().FeatherHub.Environment.isfile("RushHub/UserData.json") then
                    local Data = { TotalExecutions = 0, UILibrary = "Obsidian" }
                    getgenv().FeatherHub.Environment.writefile("RushHub/UserData.json", Services.HttpService:JSONEncode(Data))
                end
                local UserData = getgenv().FeatherHub.Environment.readfile("RushHub/UserData.json")
                local Decoded = Services.HttpService:JSONDecode(UserData)
                Decoded.UILibrary = Value
                if not Decoded.UILibrary then Decoded.UILibrary = "Obsidian" end
                getgenv().FeatherHub.TotalExecutions = Decoded.TotalExecutions
                getgenv().FeatherHub.UILibrary = Decoded.UILibrary
                getgenv().FeatherHub.Environment.writefile("RushHub/UserData.json", Services.HttpService:JSONEncode(Decoded))
            end
        end
    })
    MenuGroup:AddDropdown("DPIDropdown", {
        Values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" }, Default = "100%", Text = "Масштаб интерфейса",
        Callback = function(Value)
            Value = Value:gsub("%%", "")
            Library:SetDPIScale(tonumber(Value))
        end,
    })
    MenuGroup:AddDivider()
    MenuGroup:AddLabel("Клавиша меню"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Клавиша меню" })
    MenuGroup:AddButton({
        Text = "Discord", Icon = "link",
        Tooltip = "Копирует приглашение на Discord-сервер FeatherHub.",
        Func = Interface.CopyDiscordInvite,
    })
    MenuGroup:AddButton("Выгрузить скрипт", function() Library:Unload() end)

    Library.ToggleKeybind = Options.MenuKeybind
    ThemeManager:SetLibrary(Library)
    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({"UILibrary"})
    -- Пути RushHub сохранены для совместимости со старыми конфигами.
    ThemeManager:SetFolder("RushHub")
    SaveManager:SetFolder("RushHub/" .. getgenv().FeatherHub.SavePath)
    SaveManager:BuildConfigSection(SettingsTab)
    ThemeManager:ApplyToTab(SettingsTab)
    local _, HasSavedTheme = ThemeManager:GetDefaultTheme()
    if not HasSavedTheme then
        ThemeManager:ApplyTheme("FeatherHub")
        Options.ThemeManager_ThemeList:SetValue("FeatherHub")
    end
    SaveManager:LoadAutoloadConfig()
end

getgenv().FeatherHub.Interface = Interface

-- ════════════════════════════════════════════════════════════════
-- STX NOTIFICATION LIBRARY (inlined)
-- ════════════════════════════════════════════════════════════════
local STXGui = game:GetService("CoreGui"):FindFirstChild("STX_Nofitication")
if not STXGui then
    STXGui = Instance.new("ScreenGui")
    local Layout = Instance.new("UIListLayout")
    STXGui.Name = "STX_Nofitication"
    STXGui.Parent = game.CoreGui
    STXGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    STXGui.ResetOnSpawn = false
    Layout.Name = "STX_NofiticationUIListLayout"
    Layout.Parent = STXGui
    Layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
end

local STX = {}
function STX:Notify(nofdebug, middledebug, all)
    local SelectedType = string.lower(tostring(middledebug.Type))
    local ambientShadow = Instance.new("ImageLabel")
    local Window = Instance.new("Frame")
    local Outline_A = Instance.new("Frame")
    local WindowTitle = Instance.new("TextLabel")
    local WindowDescription = Instance.new("TextLabel")

    ambientShadow.Name = "ambientShadow"
    ambientShadow.Parent = STXGui
    ambientShadow.AnchorPoint = Vector2.new(0.5, 0.5)
    ambientShadow.BackgroundTransparency = 1.000
    ambientShadow.BorderSizePixel = 0
    ambientShadow.Position = UDim2.new(0.91525954, 0, 0.936809778, 0)
    ambientShadow.Size = UDim2.new(0, 0, 0, 0)
    ambientShadow.Image = "rbxassetid://1316045217"
    ambientShadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    ambientShadow.ImageTransparency = 0.400
    ambientShadow.ScaleType = Enum.ScaleType.Slice
    ambientShadow.SliceCenter = Rect.new(10, 10, 118, 118)

    Window.Name = "Window"
    Window.Parent = ambientShadow
    Window.BackgroundColor3 = Color3.fromRGB(16, 24, 39)
    Window.BorderSizePixel = 0
    Window.Position = UDim2.new(0, 5, 0, 5)
    Window.Size = UDim2.new(0, 230, 0, 80)
    Window.ZIndex = 2
    local WindowCorner = Instance.new("UICorner")
    WindowCorner.CornerRadius = UDim.new(0, 8)
    WindowCorner.Parent = Window

    Outline_A.Name = "Outline_A"
    Outline_A.Parent = Window
    Outline_A.BackgroundColor3 = middledebug.OutlineColor
    Outline_A.BorderSizePixel = 0
    Outline_A.Position = UDim2.new(0, 0, 0, 25)
    Outline_A.Size = UDim2.new(0, 230, 0, 2)
    Outline_A.ZIndex = 5

    WindowTitle.Name = "WindowTitle"
    WindowTitle.Parent = Window
    WindowTitle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    WindowTitle.BackgroundTransparency = 1.000
    WindowTitle.BorderSizePixel = 0
    WindowTitle.Position = UDim2.new(0, 8, 0, 2)
    WindowTitle.Size = UDim2.new(0, 222, 0, 22)
    WindowTitle.ZIndex = 4
    WindowTitle.Font = Enum.Font.GothamSemibold
    WindowTitle.Text = nofdebug.Title
    WindowTitle.TextColor3 = Color3.fromRGB(220, 220, 220)
    WindowTitle.TextSize = 12.000
    WindowTitle.TextXAlignment = Enum.TextXAlignment.Left

    WindowDescription.Name = "WindowDescription"
    WindowDescription.Parent = Window
    WindowDescription.BackgroundTransparency = 1.000
    WindowDescription.BorderSizePixel = 0
    WindowDescription.Position = UDim2.new(0, 8, 0, 34)
    WindowDescription.Size = UDim2.new(0, 216, 0, 40)
    WindowDescription.ZIndex = 4
    WindowDescription.Font = Enum.Font.GothamSemibold
    WindowDescription.Text = nofdebug.Description
    WindowDescription.TextColor3 = Color3.fromRGB(180, 180, 180)
    WindowDescription.TextSize = 12.000
    WindowDescription.TextWrapped = true
    WindowDescription.TextXAlignment = Enum.TextXAlignment.Left
    WindowDescription.TextYAlignment = Enum.TextYAlignment.Top

    if SelectedType == "default" then
        ambientShadow:TweenSize(UDim2.new(0, 240, 0, 90), "Out", "Linear", 0.2)
        Window.Size = UDim2.new(0, 230, 0, 80)
        if typeof(middledebug.Time) == "Instance" then
            middledebug.Time.Destroying:Wait()
        else
            Outline_A:TweenSize(UDim2.new(0, 0, 0, 2), "Out", "Linear", middledebug.Time)
            wait(middledebug.Time)
        end
        ambientShadow:TweenSize(UDim2.new(0, 0, 0, 0), "Out", "Linear", 0.2)
        wait(0.2)
        ambientShadow:Destroy()
    elseif SelectedType == "image" then
        ambientShadow:TweenSize(UDim2.new(0, 240, 0, 90), "Out", "Linear", 0.2)
        Window.Size = UDim2.new(0, 230, 0, 80)
        WindowTitle.Position = UDim2.new(0, 24, 0, 2)
        local ImageButton = Instance.new("ImageButton")
        ImageButton.Parent = Window
        ImageButton.BackgroundTransparency = 1.000
        ImageButton.BorderSizePixel = 0
        ImageButton.Position = UDim2.new(0, 4, 0, 4)
        ImageButton.Size = UDim2.new(0, 18, 0, 18)
        ImageButton.ZIndex = 5
        ImageButton.AutoButtonColor = false
        ImageButton.Image = all.Image
        ImageButton.ImageColor3 = all.ImageColor
        if typeof(middledebug.Time) == "Instance" then
            middledebug.Time.Destroying:Wait()
        else
            Outline_A:TweenSize(UDim2.new(0, 0, 0, 2), "Out", "Linear", middledebug.Time)
            wait(middledebug.Time)
        end
        ambientShadow:TweenSize(UDim2.new(0, 0, 0, 0), "Out", "Linear", 0.2)
        wait(0.2)
        ambientShadow:Destroy()
    elseif SelectedType == "option" then
        ambientShadow:TweenSize(UDim2.new(0, 240, 0, 110), "Out", "Linear", 0.2)
        Window.Size = UDim2.new(0, 230, 0, 100)
        local Uncheck = Instance.new("ImageButton")
        local Check = Instance.new("ImageButton")
        Uncheck.Name = "Uncheck"
        Uncheck.Parent = Window
        Uncheck.BackgroundTransparency = 1.000
        Uncheck.BorderSizePixel = 0
        Uncheck.Position = UDim2.new(0, 7, 0, 76)
        Uncheck.Size = UDim2.new(0, 18, 0, 18)
        Uncheck.ZIndex = 5
        Uncheck.AutoButtonColor = false
        Uncheck.Image = "http://www.roblox.com/asset/?id=6031094678"
        Uncheck.ImageColor3 = Color3.fromRGB(255, 84, 84)
        Check.Name = "Check"
        Check.Parent = Window
        Check.BackgroundTransparency = 1.000
        Check.BorderSizePixel = 0
        Check.Position = UDim2.new(0, 28, 0, 76)
        Check.Size = UDim2.new(0, 18, 0, 18)
        Check.ZIndex = 5
        Check.AutoButtonColor = false
        Check.Image = "http://www.roblox.com/asset/?id=6031094667"
        Check.ImageColor3 = Color3.fromRGB(83, 230, 50)
        local StillThere = true
        local function Unchecked()
            pcall(function() all.Callback(false) end)
            ambientShadow:TweenSize(UDim2.new(0, 0, 0, 0), "Out", "Linear", 0.2)
            wait(0.2) ambientShadow:Destroy() StillThere = false
        end
        local function Checked()
            pcall(function() all.Callback(true) end)
            ambientShadow:TweenSize(UDim2.new(0, 0, 0, 0), "Out", "Linear", 0.2)
            wait(0.2) ambientShadow:Destroy() StillThere = false
        end
        Uncheck.MouseButton1Click:Connect(Unchecked)
        Check.MouseButton1Click:Connect(Checked)
        Outline_A:TweenSize(UDim2.new(0, 0, 0, 2), "Out", "Linear", middledebug.Time)
        wait(middledebug.Time)
        if StillThere then
            ambientShadow:TweenSize(UDim2.new(0, 0, 0, 0), "Out", "Linear", 0.2)
            wait(0.2) ambientShadow:Destroy()
        end
    end
end

-- ════════════════════════════════════════════════════════════════
-- FPS & PING STATS OVERLAY (PulseHub-style)
-- ════════════════════════════════════════════════════════════════
local StatsService = game:GetService("Stats")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local StatsGui = Instance.new("ScreenGui")
StatsGui.Name = ESPLibrary:GenerateRandomString()
StatsGui.ResetOnSpawn = false
StatsGui.IgnoreGuiInset = true
StatsGui.DisplayOrder = 32766
StatsGui.Parent = GetHiddenUI()

local StatsFrame = Instance.new("Frame")
StatsFrame.Name = "StatsFrame"
StatsFrame.BackgroundColor3 = Color3.fromRGB(16, 24, 39)
StatsFrame.BackgroundTransparency = 0.08
StatsFrame.BorderSizePixel = 0
StatsFrame.Position = UDim2.new(0, 8, 0, 8)
StatsFrame.Size = UDim2.new(0, 200, 0, 88)
StatsFrame.Parent = StatsGui
getgenv().FeatherHub.StatsGui = StatsGui

do
    local Brand = Instance.new("TextLabel")
    Brand.BackgroundTransparency = 1
    Brand.Position = UDim2.fromOffset(12, 8)
    Brand.Size = UDim2.new(1, -24, 0, 18)
    Brand.Font = Enum.Font.GothamSemibold
    Brand.Text = "FeatherHub · DOORS"
    Brand.TextColor3 = Color3.fromRGB(231, 237, 247)
    Brand.TextSize = 13
    Brand.TextXAlignment = Enum.TextXAlignment.Left
    Brand.Parent = StatsFrame
end

local StatsCorner = Instance.new("UICorner")
StatsCorner.CornerRadius = UDim.new(0, 10)
StatsCorner.Parent = StatsFrame

local StatsStroke = Instance.new("UIStroke")
StatsStroke.Color = Color3.fromRGB(125, 211, 252)
StatsStroke.Thickness = 1
StatsStroke.Transparency = 0.5
StatsStroke.Parent = StatsFrame

local StatsGradient = Instance.new("UIGradient")
StatsGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(125, 211, 252)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(129, 140, 248)),
})
StatsGradient.Rotation = 90
StatsGradient.Parent = StatsStroke

local FPSLabel = Instance.new("TextLabel")
FPSLabel.Name = "FPS"
FPSLabel.BackgroundTransparency = 1
FPSLabel.Position = UDim2.new(0, 12, 0, 32)
FPSLabel.Size = UDim2.new(1, -16, 0, 20)
FPSLabel.Font = Enum.Font.GothamBold
FPSLabel.Text = "FPS: 60"
FPSLabel.TextColor3 = Color3.fromRGB(0, 255, 157)
FPSLabel.TextSize = 14
FPSLabel.TextXAlignment = Enum.TextXAlignment.Left
FPSLabel.Parent = StatsFrame

local PingLabel = Instance.new("TextLabel")
PingLabel.Name = "Ping"
PingLabel.BackgroundTransparency = 1
PingLabel.Position = UDim2.new(0, 12, 0, 56)
PingLabel.Size = UDim2.new(1, -16, 0, 20)
PingLabel.Font = Enum.Font.GothamBold
PingLabel.Text = "Пинг: 0 мс"
PingLabel.TextColor3 = Color3.fromRGB(0, 170, 255)
PingLabel.TextSize = 14
PingLabel.TextXAlignment = Enum.TextXAlignment.Left
PingLabel.Parent = StatsFrame

local FPSSmoothed = 60
local LastPingCheck = 0
local CurrentPing = 0
local Frames = 0
local LastFPSTime = tick()

local StatsConnection = RunService.RenderStepped:Connect(function()
    Frames += 1
    local Now = tick()
    local Elapsed = Now - LastFPSTime
    if Elapsed >= 0.5 then
        local RawFPS = Frames / Elapsed
        FPSSmoothed = FPSSmoothed * 0.7 + RawFPS * 0.3
        Frames = 0
        LastFPSTime = Now
        local FPSColor = FPSSmoothed >= 50 and Color3.fromRGB(0, 255, 157) or FPSSmoothed >= 30 and Color3.fromRGB(255, 170, 0) or Color3.fromRGB(255, 60, 60)
        FPSLabel.Text = string.format("FPS: %.0f", FPSSmoothed)
        FPSLabel.TextColor3 = FPSColor
    end
    if Now - LastPingCheck >= 1 then
        LastPingCheck = Now
        local Success, PingValue = pcall(function()
            return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        if Success and typeof(PingValue) == "number" then
            CurrentPing = PingValue
        end
        local PingColor = CurrentPing <= 100 and Color3.fromRGB(0, 170, 255) or CurrentPing <= 200 and Color3.fromRGB(255, 170, 0) or Color3.fromRGB(255, 60, 60)
        PingLabel.Text = string.format("Пинг: %d мс", CurrentPing)
        PingLabel.TextColor3 = PingColor
    end
end)

-- ════════════════════════════════════════════════════════════════
-- USER DATA & INITIALIZATION
-- ════════════════════════════════════════════════════════════════
local FeatherHub = getgenv().FeatherHub

local function CloneReference(Object)
    if FeatherHub and FeatherHub.Environment.cloneref then
        return FeatherHub.Environment.cloneref(Object)
    end
    return Object
end

local Services = setmetatable({}, {
    __index = function(Self, Name)
        return CloneReference(game:GetService(Name))
    end
})

-- Старый каталог нужен для совместимости конфигов RushHub.
if FeatherHub.Environment.makefolder and FeatherHub.Environment.isfolder and not FeatherHub.Environment.isfolder("RushHub") then
    FeatherHub.Environment.makefolder("RushHub")
end
if FeatherHub.Environment.writefile and FeatherHub.Environment.readfile and FeatherHub.Environment.isfile then
    if not FeatherHub.Environment.isfile("RushHub/UserData.json") then
        local Data = { TotalExecutions = 0, UILibrary = "Obsidian" }
        FeatherHub.Environment.writefile("RushHub/UserData.json", Services.HttpService:JSONEncode(Data))
    end
    local UserData = FeatherHub.Environment.readfile("RushHub/UserData.json")
    local Decoded = Services.HttpService:JSONDecode(UserData)
    if not Decoded.TotalExecutions then Decoded.TotalExecutions = 0 end
    Decoded.TotalExecutions = Decoded.TotalExecutions + 1
    if not Decoded.UILibrary then Decoded.UILibrary = "Obsidian" end
    FeatherHub.TotalExecutions = Decoded.TotalExecutions
    FeatherHub.UILibrary = Decoded.UILibrary
    FeatherHub.Environment.writefile("RushHub/UserData.json", Services.HttpService:JSONEncode(Decoded))
end

FeatherHub.SavePath = "Doors/Game"

local Library = FeatherHub.Interface.Library
local SaveManager = FeatherHub.Interface.SaveManager
local ThemeManager = FeatherHub.Interface.ThemeManager

local Toggles = Library.Toggles
local Options = Library.Options
-- ════════════════════════════════════════════════════════════════
-- PART 2: Variables, Tables, Notifications, Utilities, UI Start
-- ════════════════════════════════════════════════════════════════

FeatherHub.Analytics = {}

-- archives locals
local DroneWalkedIntoParents = {}
local DroneConnection = nil
local DronesStampedeParents = {}
local DronesStampedeConnection = nil
local AlmaConnection = nil
local ScribblesHook = nil
local WaterParts = {}
local WaterConnection = nil
local ForgetMeNotConnection
local ForgetMeNotSavedRoom
local ForgetMeNotProcessing = {}
local ForgetMeNotSolvedRooms = {}
local ForgetMeNotStorage
local ForgetMeNotRoomCount = 0
local ForgetMeNotHasSolved = false
local AntiScribbles_OldNamecall
local AntiScribbles_IsHooked = false
local TimeShowerConnection = nil
local TimeShowerClone = nil
local TimeShowerSourceLabel = nil
local TimeShowerLabel = nil
local TimeShowerToken = 0
local BypassDronesStampedeConnection
local AntiClosetTrash_Connection
local AntiRansom_Connection
local AntiScribbles_Connection
local WaterBypassConnection
local ForgetMeNotRunning = false
local ForgetMeNotNotified = {}

local Globals = {}
local Connections = {}
local ESPConnections = {}
local Groupboxes = {}
local FakePrompts = {}
local Functions = {}
local PartProperties = {}

local Objects = {
    Prompts = {},
    Objectives = {},
    Doors = {},
    HidingSpots = {},
    Entities = {},
    SeekObstructions = {},
    Items = {},
    Chests = {},
    Currency = {},
    Ladders = {},
    Obstructions = {},
    EventTriggers = {},
    JumpscareModules = {},
    SeekHighlights = {},
    EyestalkHighlights = {},
    SeekNodes = {},
    SeekDuckBoards = {},
    SeekBridges = {},
    PathLights = {}
}

Globals.IncompatibleMessage = "Ваш исполнитель не поддерживает эту функцию."

Functions.CheckCompatability = function(Array)
    for _, Name in Array do
        if not FeatherHub.Environment[Name] then
            return false
        end
    end
    return true
end

local Entities = {
    ["DronesStampede"] = {
        Alias = "DronesStampede",
        NotifyMessage = { Title = "Появилась сущность 'Стадо дронов'.", Body = "Найдите укрытие." }
    },
    ["TellerRig"] = {
        Alias = "Teller",
        NotifyMessage = { Title = "Появилась сущность 'Teller'.", Body = "Не волнуйтесь, он лишь досаждает." }
    },
    ["Scribbles"] = {
        Alias = "Scribbles",
        NotifyMessage = { Title = "Появилась сущность 'Scribbles'.", Body = "Найдите укрытие." }
    },
    ["BashMoving"] = {
        Alias = "Bash",
        NotifyMessage = { Title = "Появилась сущность 'Bash'.", Body = "Найдите укрытие."}
    },
    ["RushMoving"] = {
        Alias = "Rush",
        NotifyMessage = { Title = "Появилась сущность 'Rush'.", Body = "Найдите укрытие." }
    },
    ["AmbushMoving"] = {
        Alias = "Ambush",
        NotifyMessage = { Title = "Появилась сущность 'Ambush'.", Body = "Найдите укрытие." }
    },
    ["Eyes"] = {
        Alias = "Eyes",
        NotifyMessage = { Title = "Появилась сущность 'Eyes'.", Body = "Не смотрите на него." }
    },
    ["Lookman"] = {
        Alias = "Eyes",
        NotifyMessage = { Title = "Появилась сущность 'Eyes'.", Body = "Не смотрите на него." }
    },
    ["BackdoorRush"] = {
        Alias = "Blitz",
        NotifyMessage = { Title = "Появилась сущность 'Blitz'.", Body = "Найдите укрытие." }
    },
    ["BackdoorLookman"] = {
        Alias = "Lookman",
        NotifyMessage = { Title = "Появилась сущность 'Lookman'.", Body = "Не смотрите ему в глаза." }
    },
    ["Groundskeeper"] = {
        Alias = "Groundskeeper",
        NotifyMessage = { Title = "Появилась сущность 'Groundskeeper'.", Body = "Не наступайте на траву." }
    },
    ["A60"] = {
        Alias = "A-60",
        NotifyMessage = { Title = "Появилась сущность 'A-60'.", Body = "Найдите укрытие." }
    },
    ["A120"] = {
        Alias = "A-120",
        NotifyMessage = { Title = "Появилась сущность 'A-120'.", Body = "Найдите укрытие." }
    },
    ["GloombatSwarm"] = {
        Alias = "Gloombat Swarm",
        NotifyMessage = { Title = "Появилась сущность 'Рой Gloombat'.", Body = "Выключите все источники света." }
    },
    ["GlitchRush"] = {
        Alias = "RNIUSHCG==",
        NotifyMessage = { Title = "Появилась сущность 'RNIUSHCG=='.", Body = "Найдите укрытие." }
    },
    ["GlitchAmbush"] = {
        Alias = "AR0xMBUSH",
        NotifyMessage = { Title = "Появилась сущность 'AR0xMBUSH'.", Body = "Найдите укрытие." }
    },
    ["MonumentEntity"] = {
        Alias = "Monument",
        NotifyMessage = { Title = "Появилась сущность 'Monument'.", Body = "Он не двигается, пока вы смотрите на него." }
    },
    ["JeffTheKiller"] = {
        Alias = "Jeff the Killer",
        NotifyMessage = { Title = "Появилась сущность 'Jeff the Killer'.", Body = "Не касайтесь его." }
    },
    ["CustomEntity"] = {
        Alias = "Custom Entity",
        NotifyMessage = { Title = "Появилась сущность 'Пользовательская сущность'.", Body = "Найдите укрытие." }
    },
    ["FrozenAmbush"] = {
        Alias = "Frozen Ambush",
        NotifyMessage = { Title = "Появилась сущность 'Замёрзший Ambush'.", Body = "Найдите укрытие." }
    },
    ["SallyMoving"] = {
        Alias = "Sally",
        NotifyMessage = { Title = "Появилась сущность 'Sally'.", Body = "Бросьте ей предмет." }
    }
}

local EntityIcons = {
    ["RushMoving"]      = "rbxassetid://10716032262",
    ["AmbushMoving"]    = "rbxassetid://10110576663",
    ["A60"]             = "rbxassetid://12571092295",
    ["A120"]            = "rbxassetid://12711591665",
    ["BackdoorRush"]    = "rbxassetid://16602023490",
    ["Eyes"]            = "rbxassetid://10183704772",
    ["Lookman"]         = "rbxassetid://10183704772",
    ["BackdoorLookman"] = "rbxassetid://16764872677",
    ["GloombatSwarm"]   = "rbxassetid://79221203116470",
    ["Halt"]            = "rbxassetid://11331795398",
    ["JeffTheKiller"]   = "rbxassetid://94479432156278",
    ["GlitchRush"]      = "rbxassetid://73859273102919",
    ["GlitchAmbush"]    = "rbxassetid://88369678433359",
    ["SallyMoving"]     = "rbxassetid://10840888070",
    ["MonumentEntity"]  = "rbxassetid://88933556873017",
    ["Groundskeeper"]   = "rbxassetid://114991380115557"
}

local ItemNames = {
    ["SallyToyObtain"]    = "Sally Toy",
    ["Leftovers"]         = "Lunch Box",
    ["HoneyPot"]          = "Honey Pot",
    ["FihFlakes"]         = "Fih Food",
    ["SecretCD"]          = "CD Disc",
    ["Pizza"]             = "Pizza",
    ["PaperPlanePickup"]  = "Paper Plane",
    ["Lighter"]           = "Lighter",
    ["Flashlight"]        = "Flashlight",
    ["Lockpick"]          = "Lockpicks",
    ["Vitamins"]          = "Vitamins",
    ["Bandage"]           = "Bandage",
    ["StarVial"]          = "Starlight Vial",
    ["StarBottle"]        = "Starlight Bottle",
    ["StarJug"]           = "Starlight Barrel",
    ["Shakelight"]        = "Gummy Flashlight",
    ["Straplight"]        = "Straplight",
    ["Bulklight"]         = "Spotlight",
    ["Battery"]           = "Battery",
    ["Candle"]            = "Candle",
    ["Crucifix"]          = "Crucifix",
    ["CrucifixWall"]      = "Crucifix",
    ["Glowsticks"]        = "Glowstick",
    ["SkeletonKey"]       = "Skeleton Key",
    ["Candy"]             = "Candy",
    ["ShieldMini"]        = "Mini Shield Potion",
    ["ShieldBig"]         = "Big Shield Potion",
    ["BandagePack"]       = "Bandage Pack",
    ["BatteryPack"]       = "Battery Pack",
    ["RiftCandle"]        = "Moonlight Candle",
    ["LaserPointer"]      = "Laser Pointer",
    ["HolyGrenade"]       = "Holy Hand Grenade",
    ["Shears"]            = "Shears",
    ["Smoothie"]          = "Smoothie",
    ["Cheese"]            = "Cheese",
    ["Bread"]             = "Bread",
    ["AlarmClock"]        = "Alarm Clock",
    ["RiftSmoothie"]      = "Moonlight Smoothie",
    ["GweenSoda"]         = "Gween Soda",
    ["GlitchCube"]        = "Glitch Fragment",
    ["Scanner"]           = "Tablet",
    ["Bomb"]              = "Bomb",
    ["Knockbomb"]         = "Knockbomb",
    ["Nanner"]            = "Nanner",
    ["BigBomb"]           = "Big Bomb",
    ["SnakeBox"]          = "Hiding Box",
    ["GoldGun"]           = "Golden Gun",
    ["StopSign"]          = "Stop Sign",
    ["TipJar"]            = "Tip Jar",
    ["Lantern"]           = "Lantern",
    ["IronKey"]           = "Iron Key",
    ["LotusPetal"]        = "Lotus Petal",
    ["Compass"]           = "Compass",
    ["LotusPetalPickup"]  = "Lotus Petal",
    ["LanternLitItem"]    = "Lantern",
    ["KeyIron"]           = "Iron Key",
    ["IronKeyForCrypt"]   = "Iron Key",
    ["LotusHolder"]       = "Lotus Petal",
    ["Multitool"]         = "Multitool",
    ["RiftJar"]           = "Rift Jar",
    ["AloeVera"]          = "Aloe Vera",
    ["Donut"]             = "Donut",
    ["Lotus"]             = "Lotus",
    ["BoxingGloves"]      = "Boxing Gloves"
}

local CutsceneNames = {
    "Figure", "FigureEnd", "FigureHotelEnd", "FigureHotelFire",
    "SeekIntroFools", "SeekIntroHotel", "SeekIntroMines", "SeekIntroMines2",
    "SerewSeekDrain", "SewerSeekLower", "GrumbleNestEnd", "EyestalkIntro",
}

local Character
local Humanoid
local RootPart
local Collision
local CollisionClone
local CollisionPart
local CollisionPartClone
local Camera
local LocalPlayer = Services.Players.LocalPlayer

local RemotesFolder   = Services.ReplicatedStorage:FindFirstChild("RemotesFolder")
local LiveModifiers   = Services.ReplicatedStorage:FindFirstChild("LiveModifiers")
local FloorReplicated = Services.ReplicatedStorage:FindFirstChild("FloorReplicated")
local CurrentRooms    = Services.Workspace:FindFirstChild("CurrentRooms")
local Drops           = Services.Workspace:FindFirstChild("Drops")
local GameData        = Services.ReplicatedStorage:WaitForChild("GameData")
local Floor           = GameData:WaitForChild("Floor").Value
local LatestRoom      = GameData:WaitForChild("LatestRoom")
local FinishedLoadingRoom = GameData:FindFirstChild("FinishedLoadingRoom")
local RunService = game:GetService("RunService")

if FinishedLoadingRoom then
    FinishedLoadingRoom:Destroy()
end

local function GetHiddenContainer()
    if Functions.CheckCompatability({"gethui"}) then
        return FeatherHub.Environment.gethui()
    end
    return Services.CoreGui
end

-- ════════════════════════════════════════════════════════════════
-- NOTIFICATION SYSTEM
-- ════════════════════════════════════════════════════════════════
local NotificationLibrary = {
    LiveNotifications = 0,
    Notifications = 1,
    Cards = {}
}

local Container = Instance.new("ScreenGui")
Container.Name = FeatherHub.ESPLibrary:GenerateRandomString()
Container.Parent = GetHiddenContainer()
Container.DisplayOrder = 32767
Container.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Container.ResetOnSpawn = false
Container.IgnoreGuiInset = true

do
    local Stack = Instance.new("Frame")
    Stack.Name = "FeatherHubNotifications"
    Stack.AnchorPoint = Vector2.new(1, 0)
    Stack.Position = UDim2.new(1, -16, 0, 64)
    Stack.Size = UDim2.new(1, -32, 1, -80)
    Stack.BackgroundTransparency = 1
    Stack.Parent = Container
    local Layout = Instance.new("UIListLayout")
    Layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.Padding = UDim.new(0, 10)
    Layout.Parent = Stack
    NotificationLibrary.Stack = Stack
    Library:GiveSignal(Stack:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        for _, Card in ipairs(NotificationLibrary.Cards) do Card:Destroy() end
        table.clear(NotificationLibrary.Cards)
        NotificationLibrary.LiveNotifications = 0
    end))
end

if not Library.Scheme then
    Library.Scheme = setmetatable({}, {
        __index = function(Self, Name)
            return Library[Name]
        end
    })
end

function NotificationLibrary:Notify(TitleText, Desc, Delay)
    if Library.Unloaded then return end
    task.spawn(function()
        if Library.Unloaded then return end
        local Camera = workspace.CurrentCamera
        local Viewport = Camera and Camera.ViewportSize or Vector2.new(1280, 720)
        if Viewport.X < 160 or Viewport.Y < 160 then return end
        local Width = math.min(400, Viewport.X - 32)
        local TextWidth = Width - 68
        local TitleTextValue = tostring(TitleText or "FeatherHub")
        local BodyTextValue = tostring(Desc or "")
        local TitleHeight = math.min(36, math.max(18, Services.TextService:GetTextSize(TitleTextValue, 14, Enum.Font.GothamSemibold, Vector2.new(TextWidth, 10000)).Y))
        local BodyHeight = BodyTextValue ~= "" and math.max(18, Services.TextService:GetTextSize(BodyTextValue, 13, Enum.Font.Gotham, Vector2.new(TextWidth, 10000)).Y) or 0
        BodyHeight = math.min(BodyHeight, math.max(0, Viewport.Y - 132 - TitleHeight))
        local Height = TitleHeight + BodyHeight + (BodyHeight > 0 and 36 or 28)
        local Lifetime = tonumber(Delay) or 5
        if Lifetime ~= Lifetime or math.abs(Lifetime) == math.huge then Lifetime = 5 end
        Lifetime = math.clamp(Lifetime, 0.5, 300)
        local Cards = NotificationLibrary.Cards
        local TotalHeight = Height
        for _, Card in ipairs(Cards) do
            TotalHeight += Card.Size.Y.Offset + 10
        end
        while #Cards > 0 and (#Cards >= 4 or TotalHeight > Viewport.Y - 96) do
            local Oldest = table.remove(Cards, 1)
            TotalHeight -= Oldest.Size.Y.Offset + 10
            Oldest:Destroy()
        end

        local Root = Instance.new("Frame")
        Root.Name = "FeatherHubNotificationSlot"
        Root.BackgroundTransparency = 1
        Root.BorderSizePixel = 0
        Root.Size = UDim2.fromOffset(Width, Height)
        Root.LayoutOrder = NotificationLibrary.Notifications
        Root.Parent = NotificationLibrary.Stack
        table.insert(Cards, Root)
        NotificationLibrary.Notifications += 1
        NotificationLibrary.LiveNotifications = #Cards

        local Notification = Instance.new("Frame")
        Notification.Name = "Notification"
        Notification.BackgroundColor3 = Library.Scheme.BackgroundColor
        Notification.BackgroundTransparency = 0.06
        Notification.BorderSizePixel = 0
        Notification.Position = UDim2.new(1, 24, 0, 0)
        Notification.Size = UDim2.fromScale(1, 1)
        Notification.ClipsDescendants = true
        Notification.Parent = Root

        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 10)
        Corner.Parent = Notification
        local Stroke = Instance.new("UIStroke")
        Stroke.Color = Library.Scheme.OutlineColor
        Stroke.Transparency = 0.2
        Stroke.Parent = Notification

        Library:CreateIcon(Library:GetIcon("feather"), {
            Position = UDim2.fromOffset(14, 14),
            Size = UDim2.fromOffset(24, 24),
            ImageColor3 = Library.Scheme.AccentColor,
            Parent = Notification,
        })

        local Title = Instance.new("TextLabel")
        Title.BackgroundTransparency = 1
        Title.Position = UDim2.fromOffset(52, 12)
        Title.Size = UDim2.fromOffset(TextWidth, TitleHeight + 2)
        Title.Font = Enum.Font.GothamSemibold
        Title.Text = TitleTextValue
        Title.TextColor3 = Library.Scheme.FontColor
        Title.TextSize = 14
        Title.TextWrapped = true
        Title.TextTruncate = Enum.TextTruncate.AtEnd
        Title.TextXAlignment = Enum.TextXAlignment.Left
        Title.TextYAlignment = Enum.TextYAlignment.Top
        Title.Parent = Notification

        local Description = Instance.new("TextLabel")
        Description.BackgroundTransparency = 1
        Description.Position = UDim2.fromOffset(52, TitleHeight + 20)
        Description.Size = UDim2.fromOffset(TextWidth, BodyHeight + 2)
        Description.Font = Enum.Font.Gotham
        Description.Text = BodyTextValue
        Description.TextColor3 = Library.Scheme.FontColor
        Description.TextTransparency = 0.18
        Description.TextSize = 13
        Description.TextWrapped = true
        Description.TextTruncate = Enum.TextTruncate.AtEnd
        Description.TextXAlignment = Enum.TextXAlignment.Left
        Description.TextYAlignment = Enum.TextYAlignment.Top
        Description.Visible = BodyHeight > 0
        Description.Parent = Notification

        local Line = Instance.new("Frame")
        Line.BorderSizePixel = 0
        Line.BackgroundColor3 = Library.Scheme.AccentColor
        Line.Position = UDim2.new(0, 0, 1, -3)
        Line.Size = UDim2.new(1, 0, 0, 3)
        Line.Parent = Notification

        local TargetDestroyed = false
        local TargetConnection
        if typeof(Delay) == "Instance" then
            TargetConnection = Delay.Destroying:Connect(function() TargetDestroyed = true end)
        end
        if not TargetConnection then
            Services.TweenService:Create(Line, TweenInfo.new(Lifetime, Enum.EasingStyle.Linear), { Size = UDim2.fromOffset(0, 3) }):Play()
        end
        Services.TweenService:Create(Notification, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(0, 0) }):Play()
        -- Ограниченный срок исключает зависание на уже уничтоженном Instance.
        local Deadline = tick() + (TargetConnection and 300 or Lifetime)
        while Root.Parent and Container.Parent and not Library.Unloaded do
            if TargetDestroyed or tick() >= Deadline then break end
            task.wait(0.1)
        end
        if TargetConnection then TargetConnection:Disconnect() end
        if Root.Parent and Container.Parent and not Library.Unloaded then
            Services.TweenService:Create(Notification, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(1, 24, 0, 0) }):Play()
            task.wait(0.2)
        end
        local Index = table.find(Cards, Root)
        if Index then table.remove(Cards, Index) end
        NotificationLibrary.LiveNotifications = #Cards
        Root:Destroy()
    end)
end


Globals.DoorsNotify = function(NotifyOptions)
    local function PlaySound(Parent, SoundId, Volume)
        local Sound = Instance.new("Sound")
        Sound.SoundId = SoundId
        Sound.Volume = Volume or 1
        Sound.Parent = Parent
        task.spawn(function()
            task.wait(0.1)
            Sound:Play()
            Sound.Ended:Wait()
            Sound:Destroy()
        end)
    end

    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    local UIContainer = PlayerGui:FindFirstChild("GlobalUI") or PlayerGui:FindFirstChild("MainUI")
    if not UIContainer then return end

    local AchievementsHolder = UIContainer:FindFirstChild("AchievementsHolder")
    if not AchievementsHolder then return end

    local Achievement = AchievementsHolder.Achievement:Clone()
    Achievement.Size = UDim2.new(0, 0, 0, 0)
    Achievement.Frame.Position = UDim2.new(1.1, 0, 0, 0)
    Achievement.Name = "LiveAchievement"
    Achievement.Visible = true

    Achievement.Frame.TextLabel.Text = NotifyOptions.Style or "УВЕДОМЛЕНИЕ"
    Achievement.Frame.Details.Title.Text = NotifyOptions.Title or "Без заголовка"
    Achievement.Frame.Details.Desc.Text = NotifyOptions.Description or "Без описания"
    Achievement.Frame.Details.Reason.Text = NotifyOptions.Reason or ""
    Achievement.Frame.ImageLabel.Image = (NotifyOptions.Image ~= "" and NotifyOptions.Image) or "rbxassetid://6023426923"

    local Color = NotifyOptions.Color or Color3.new(1, 1, 1)
    Achievement.Frame.TextLabel.TextColor3 = Color
    Achievement.Frame.UIStroke.Color = Color
    Achievement.Frame.Glow.ImageColor3 = Color
    Achievement.Parent = AchievementsHolder

    PlaySound(AchievementsHolder, "rbxassetid://10469938989", 1)

    task.spawn(function()
        Achievement:TweenSize(UDim2.new(1, 0, 0.2, 0), "In", "Quad", 0.8, true)
        task.wait(0.8)
        Achievement.Frame:TweenPosition(UDim2.new(0, 0, 0, 0), "Out", "Quad", 0.5, true)
        Services.TweenService:Create(
            Achievement.Frame.Glow,
            TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { ImageTransparency = 1 }
        ):Play()

        if typeof(NotifyOptions.Time) == "Instance" then
            NotifyOptions.Time.Destroying:Wait()
        else
            task.wait(NotifyOptions.Time or 5)
        end

        Achievement.Frame:TweenPosition(UDim2.new(1.1, 0, 0, 0), "In", "Quad", 0.5, true)
        task.wait(0.5)
        Achievement:TweenSize(UDim2.new(1, 0, -0.1, 0), "InOut", "Quad", 0.5, true)
        task.wait(0.5)
        Achievement:Destroy()
    end)
end

Globals.STX = STX

Functions.Notify = function(Settings)
    local HiddenContainer = GetHiddenContainer()
    if not Settings.Body then Settings.Body = "..." end

    if not Options.NotifyStyle or Options.NotifyStyle.Value == "RushHub" then
        local Sound = Instance.new("Sound", HiddenContainer)
        Sound.SoundId = "rbxassetid://8784885431"
        Sound.Volume = (Toggles.NotifyPlaySound and Toggles.NotifyPlaySound.Value and Options.NotifySoundVolume.Value) or (Toggles.NotifyPlaySound and 0 or 3)
        Sound.PlayOnRemove = true
        Sound:Destroy()
        NotificationLibrary:Notify(Settings.Title, Settings.Body, Settings.Time or 5)
    elseif Options.NotifyStyle.Value == "Doors" then
        local IsEntity = false
        local EntityName = ""
        for Index, Object in pairs(Entities) do
            if Object.NotifyMessage.Title == Settings.Title or Object.NotifyMessage.Body == Settings.Body then
                IsEntity = true
                EntityName = Index
            end
        end
        Globals.DoorsNotify({
            Title = "FeatherHub",
            Description = Settings.Title,
            Reason = Settings.Body,
            Style = IsEntity and "ПРЕДУПРЕЖДЕНИЕ" or "УВЕДОМЛЕНИЕ",
            Color = IsEntity and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(255, 222, 189),
            Image = Settings.Image,
            Time = Settings.Time
        })
    elseif Options.NotifyStyle.Value == "STX" then
        local Sound = Instance.new("Sound", HiddenContainer)
        Sound.SoundId = "rbxassetid://4590657391"
        Sound.Volume = (Toggles.NotifyPlaySound and Toggles.NotifyPlaySound.Value and Options.NotifySoundVolume.Value) or (Toggles.NotifyPlaySound and 0 or 3)
        Sound.PlayOnRemove = true
        Sound:Destroy()

        if Settings.Image then
            Globals.STX:Notify(
                {Title = "FeatherHub", Description = Settings.Title .. "\n" .. Settings.Body},
                {OutlineColor = Library.Scheme.AccentColor, Time = Settings.Time or 5, Type = "image"},
                {Image = Settings.Image, ImageColor = Color3.fromRGB(255, 255, 255)}
            )
        else
            Globals.STX:Notify(
                {Title = "FeatherHub", Description = Settings.Title .. "\n" .. Settings.Body},
                {OutlineColor = Library.Scheme.AccentColor, Time = Settings.Time or 5, Type = "default"}
            )
        end
    else
        local Sound = Instance.new("Sound", HiddenContainer)
        Sound.SoundId = "rbxassetid://4590662766"
        Sound.Volume = (Toggles.NotifyPlaySound and Toggles.NotifyPlaySound.Value and Options.NotifySoundVolume.Value) or (Toggles.NotifyPlaySound and 0 or 3)
        Sound.PlayOnRemove = true
        Sound:Destroy()
        Library:OldNotify({ Title = Settings.Title, Description = Settings.Body, Time = Settings.Time })
    end
end

Functions.Caption = function(Text, PlaySound)
    if typeof(PlaySound) ~= "boolean" then PlaySound = true end
    local CaptionValue = Instance.new("NumberValue")
    local Caption = Globals.MainUI:WaitForChild("MainFrame"):WaitForChild("Caption"):Clone()
    local CaptionSound = Globals.MainUI:WaitForChild("Initiator"):WaitForChild("Main_Game"):WaitForChild("Reminder"):WaitForChild("Caption")
    local CaptionSoundClone = CaptionSound:Clone()
    CaptionSoundClone.Parent = CaptionSound.Parent
    CaptionSoundClone.Volume = 0.1

    Caption.Destroying:Connect(function() CaptionValue:Destroy() end)

    for _, Child in Globals.MainUI:GetChildren() do
        if Child.Name == "LiveCaption" then Child:Destroy() end
    end

    Caption.Parent = Globals.MainUI
    Caption.Visible = true
    Caption.Name = "LiveCaption"
    Caption.Text = Text

    if PlaySound then CaptionSoundClone:Play() end
    Services.Debris:AddItem(CaptionSoundClone, 5)

    local HolderTween = Services.TweenService:Create(CaptionValue, TweenInfo.new(3), { Value = 100 })
    HolderTween:Play()
    HolderTween.Completed:Connect(function()
        CaptionValue:Destroy()
        Services.TweenService:Create(Caption, TweenInfo.new(4, Enum.EasingStyle.Linear), { TextTransparency = 1 }):Play()
        Services.TweenService:Create(Caption, TweenInfo.new(4, Enum.EasingStyle.Linear), { TextStrokeTransparency = 1 }):Play()
    end)
end

Functions.GetHasteTime = function()
    local TimeRemaining = FloorReplicated.DigitalTimer.Value
    local Minutes = math.floor(TimeRemaining / 60)
    local Seconds = TimeRemaining - (Minutes * 60)
    local MinutesText = Minutes < 10 and ("0" .. tostring(Minutes)) or tostring(Minutes)
    local SecondsText = Seconds < 10 and ("0" .. tostring(Seconds)) or tostring(Seconds)
    return MinutesText .. ":" .. SecondsText
end

Library.OldNotify = Library.Notify
Library.Notify = function(Self, Data, Time)
    if typeof(Data) == "table" then
        Functions.Notify({
            Title = Interface.Localization.TranslateText(Data.Title or "FeatherHub"),
            Body = Interface.Localization.TranslateText(Data.Description or Data.Body or ""),
            Time = Data.Time or Time or 5,
            Image = Data.Image,
        })
    else
        Functions.Notify({ Title = Interface.Localization.TranslateText(tostring(Data or "FeatherHub")), Body = "", Time = Time or 5 })
    end
end

-- ════════════════════════════════════════════════════════════════
-- GAME LOAD WAIT
-- ════════════════════════════════════════════════════════════════
if not LocalPlayer.Character or not CurrentRooms:FindFirstChildOfClass("Model") then
    Functions.Notify({ Title = "Ожидание загрузки игры..." })
    while not LocalPlayer.Character or not CurrentRooms:FindFirstChildOfClass("Model") do
        task.wait()
    end
    task.wait(4)
end

if not RemotesFolder then
    if Services.ReplicatedStorage:FindFirstChild("EntityInfo") then
        RemotesFolder = Services.ReplicatedStorage:FindFirstChild("EntityInfo")
    elseif Services.ReplicatedStorage:FindFirstChild("Bricks") then
        RemotesFolder = Services.ReplicatedStorage:FindFirstChild("Bricks")
    end
end

if Floor == "Hotel" and RemotesFolder.Name == "Bricks" then
    Floor = "OldHotel"
end

if not LiveModifiers then
    LiveModifiers = Instance.new("Folder")
end

if not FloorReplicated then
    FloorReplicated = Instance.new("Folder")
end

-- ════════════════════════════════════════════════════════════════
-- FAKE EVENTS (remote hijacking for damage bypass)
-- ════════════════════════════════════════════════════════════════
local FakeEvents = {
    Screech = Instance.new("RemoteEvent"),
    Shade   = Instance.new("RemoteEvent"),
    A90     = Instance.new("RemoteEvent"),
    Surge   = Instance.new("RemoteEvent"),
}

FakeEvents.Screech.Name  = "Screech"
FakeEvents.Shade.Name    = "ShadeResult"
FakeEvents.A90.Name      = "A90"
FakeEvents.Surge.Name    = "SurgeRemote"

FakeEvents.Screech_Real = RemotesFolder:WaitForChild("Screech")
FakeEvents.Shade_Real   = RemotesFolder:WaitForChild("ShadeResult")
FakeEvents.A90_Real     = RemotesFolder:FindFirstChild("A90")
FakeEvents.Surge_Real   = RemotesFolder:FindFirstChild("SurgeRemote")

if RemotesFolder:FindFirstChild("FootstepRemoteThatWeNeed") then
    local RealRemote = RemotesFolder:FindFirstChild("FootstepRemoteThatWeNeed")
    RealRemote:Destroy()
    local FakeRemote = Instance.new("RemoteEvent", RemotesFolder)
    FakeRemote.Name = "FootstepRemoteThatWeNeed"
end

-- ════════════════════════════════════════════════════════════════
-- FOG HANDLING
-- ════════════════════════════════════════════════════════════════
Globals.FogInstances = {}
Globals.OldFog = Services.Lighting.FogEnd

for _, Object in Services.Lighting:GetChildren() do
    if Object:IsA("Atmosphere") then
        Object:SetAttribute("Density_Old", Object.Density)
        local AtmoConnection = Object:GetPropertyChangedSignal("Density"):Connect(function()
            if Object.Density ~= 0 then Object:SetAttribute("Density_Old", Object.Density) end
            if Toggles.RemoveCameraFog.Value then Object.Density = 0 end
        end)
        Object.Destroying:Once(function() AtmoConnection:Disconnect() end)
        table.insert(Connections, AtmoConnection)
        table.insert(Globals.FogInstances, Object)
    end
end

Globals.SeekNodesFolder = Instance.new("Folder", Services.Workspace)
Globals.SeekNodesFolder.Name = FeatherHub.ESPLibrary:GenerateRandomString()

Globals.RoomsNodesFolder = Instance.new("Folder", Services.Workspace)
Globals.RoomsNodesFolder.Name = FeatherHub.ESPLibrary:GenerateRandomString()

-- ════════════════════════════════════════════════════════════════
-- UTILITY FUNCTIONS
-- ════════════════════════════════════════════════════════════════
Functions.SendChat = function(Message)
    local Folder = Services.ReplicatedStorage:FindFirstChild("DefaultChatSystemEvents") or Instance.new("Folder")
    local Event = Folder:FindFirstChild("SayMessageRequest") or Instance.new("RemoteEvent")
    Event:FireServer(Message, "All")
    local Channel = (Services.TextChatService:FindFirstChild("TextChannels") and Services.TextChatService.TextChannels:FindFirstChild("RBXGeneral")) or Instance.new("TextChannel")
    Channel:SendAsync(Message)
end

Functions.IsCrouching = function()
    if Floor == "Fools" or Floor == "OldHotel" then
        return Character:GetAttribute("Crouching")
    end
    return CollisionPart.CollisionGroup == "PlayerCrouching"
end

Functions.GetInjuriesSpeed = function()
    return 0.075 * (Humanoid.MaxHealth - Humanoid.Health)
end

Functions.GetCurrentSpeed = function()
    local Speed = 15
    Speed += Character:GetAttribute("SpeedBoost") or 0
    Speed += Character:GetAttribute("SpeedBoostBehind") or 0
    Speed += Character:GetAttribute("SpeedBoostExtra") or 0
    Speed += (Floor == "Party" and 10 or 0)
    Speed += (LiveModifiers:FindFirstChild("PlayerFast") and 3 or 0)
    Speed += (LiveModifiers:FindFirstChild("PlayerFaster") and 6 or 0)
    Speed += (LiveModifiers:FindFirstChild("PlayerFastest") and 20 or 0)
    Speed -= (LiveModifiers:FindFirstChild("PlayerSlow") and 3 or 0)
    Speed -= (LiveModifiers:FindFirstChild("PlayerSlowHealth") and Functions.GetInjuriesSpeed() or 0)
    if Functions.IsCrouching() then
        if LiveModifiers:FindFirstChild("PlayerCrouchSlow") then Speed -= 8
        elseif LiveModifiers:FindFirstChild("PlayerSlow") then Speed -= 8
        else Speed -= 5 end
    end
    return Speed
end

Functions.GetMousePosition = function()
    if Library.IsMobile then
        return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    end
    local MouseLocation = Services.UserInputService:GetMouseLocation()
    return Vector2.new(MouseLocation.X, MouseLocation.Y)
end

Functions.FormatOxygen = function(Oxygen)
    return "Кислород: " .. (math.floor(Oxygen * 10) / 10) .. "%"
end

Functions.IsHidePersistent = function()
    return Floor == "Mines" or Floor == "Ripple" or Floor == "Party" or LiveModifiers:FindFirstChild("HideLevel2") ~= nil
end

Functions.GetPlayerFromMouse = function(TargetPart, MaxDistance)
    local Closest
    local ClosestDistance = math.huge
    for _, Player in Services.Players:GetPlayers() do
        local Char = Player.Character
        if Char then
            local Target = Char:FindFirstChild(TargetPart)
            if Target then
                local Result = Camera:WorldToViewportPoint(Target.Position)
                local ScreenPos = Vector2.new(Result.X, Result.Y)
                local Distance = (Functions.GetMousePosition() - ScreenPos).Magnitude
                if Player.Name ~= LocalPlayer.Name and Distance < ClosestDistance and Distance < MaxDistance then
                    Closest = Target
                    ClosestDistance = Distance
                end
            end
        end
    end
    return Closest
end

local EntityDistances = {
    ["RushMoving"]    = 85,
    ["Scribbles"]     = 100,
    ["BashMoving"]    = 150,
    ["DronesStampede"] = 100,
    ["AmbushMoving"]  = 150,
    ["A60"]           = 125,
    ["A120"]          = 85,
    ["GlitchRush"]    = 90,
    ["GlitchAmbush"]  = 175,
    ["BackdoorRush"]  = 85,
    ["CustomEntity"]  = 85,
}

Functions.GetNearestEntity = function(CheckDisabled, List, UseRaycasting)
    local Nearest = { Distance = math.huge, Object = nil }
    for _, Entity in Objects.Entities do
        if not Entity or not Entity:IsA("Model") or not Entity:IsDescendantOf(Services.Workspace) then continue end
        if not EntityDistances[Entity.Name] or not Entity.PrimaryPart then continue end
        local EntityData = Entities[Entity.Name]
        if not EntityData then continue end
        if List and List[EntityData.Alias] then continue end
        local Distance = LocalPlayer:DistanceFromCharacter(Entity.PrimaryPart.Position)
        if Distance < EntityDistances[Entity.Name] and Distance < Nearest.Distance then
            if not CheckDisabled or Entity:GetAttribute("Inactive") ~= true then
                Nearest.Distance = Distance
                Nearest.Object = Entity
            end
        end
    end
    return Nearest.Object
end

Functions.GetNearestFigure = function()
    local Nearest = { Distance = math.huge, Object = nil }
    local FigureNames = { FigureRig = true, FigureRagdoll = true, Figure = true }
    for _, Object in Objects.Entities do
        if Object:IsA("Model") and Object.PrimaryPart and FigureNames[Object.Name] then
            local Distance = LocalPlayer:DistanceFromCharacter(Object.PrimaryPart.Position)
            if Distance < Nearest.Distance and Distance < 25 then
                Nearest.Distance = Distance
                Nearest.Object = Object
            end
        end
    end
    return Nearest.Object
end

Functions.GetNearestHidingSpot = function()
    local Nearest = { Distance = math.huge, Object = nil }
    local LastHideSpot = Character:FindFirstChild("LastHideSpot")

    local function IsHidingSpotName(Name)
        if typeof(Name) ~= "string" then return false end
        return string.find(string.lower(Name), "hidingspot") or string.find(string.lower(Name), "hiding_spot")
    end

    local function GetHidePrompt(Object)
        if not Object then return nil end
        local Prompt = Object:FindFirstChild("HidePrompt") or Object:FindFirstChild("HidingPrompt")
        if Prompt then return Prompt end
        for _, Child in Object:GetDescendants() do
            if (Child:IsA("ProximityPrompt") or Child:IsA("InteractPrompt"))
                and (Child.Name == "HidePrompt" or Child.Name == "HidingPrompt" or IsHidingSpotName(Child.Name)) then
                return Child
            end
        end
        if IsHidingSpotName(Object.Name) or IsHidingSpotName(Object.Parent and Object.Parent.Name) then
            return Object:FindFirstChild("HidePrompt") or Object:FindFirstChild("HidingPrompt")
        end
        return nil
    end

    local function TryObject(Object)
        if not Object or not Object:IsDescendantOf(Services.Workspace) then return end
        if not Object.PrimaryPart and not Object:FindFirstChildOfClass("BasePart") then return end
        local Prompt = GetHidePrompt(Object)
        if not Prompt then return end
        local PrimaryPart = Object.PrimaryPart or Object:FindFirstChildOfClass("BasePart")
        if not PrimaryPart then return end
        local Distance = LocalPlayer:DistanceFromCharacter(PrimaryPart.Position)
        if Distance < Prompt.MaxActivationDistance and Distance < Nearest.Distance then
            local Persistent = Functions.IsHidePersistent()
            if not Persistent or (LastHideSpot and LastHideSpot.Value ~= Object) or not LastHideSpot then
                Nearest.Distance = Distance
                Nearest.Object = Object
            end
        end
    end

    for _, Object in Objects.HidingSpots do TryObject(Object) end
    return Nearest.Object
end

Functions.GetNearestTurnNode = function()
    local Nearest = { Distance = math.huge, Object = nil }
    for _, Node in Objects.SeekNodes do
        local Distance = LocalPlayer:DistanceFromCharacter(Node.Position)
        if Distance < Options.AutoSteerMinecartTurnDistance.Value and Distance < Nearest.Distance then
            Nearest.Distance = Distance
            Nearest.Object = Node
        end
    end
    return Nearest.Object
end

Functions.GetNearestDuckBoard = function()
    local Nearest = { Distance = math.huge, Object = nil }
    for _, Board in Objects.SeekDuckBoards do
        if Board.PrimaryPart then
            local Distance = LocalPlayer:DistanceFromCharacter(Board.PrimaryPart.Position)
            if Distance < Options.AutoSteerMinecartDuckDistance.Value and Distance < Nearest.Distance then
                Nearest.Distance = Distance
                Nearest.Object = Board
            end
        end
    end
    return Nearest.Object
end

Functions.GetCurrentAnchor = function()
    local AnchorCode = Globals.MainUI.AnchorHintFrame.AnchorCode.Text
    for _, Anchor in Objects.Objectives do
        if Anchor.Name == "MinesAnchor" and Anchor:FindFirstChild("Sign") then
            if Anchor.Sign.TextLabel.Text == AnchorCode then
                return Anchor
            end
        end
    end
end

Functions.GetMinecart = function()
    return Camera:FindFirstChild("MinecartRig") ~= nil
end

Functions.HasItem = function(Name, OnlyCharacter)
    if not OnlyCharacter and LocalPlayer.Backpack:FindFirstChild(Name) then
        return LocalPlayer.Backpack:FindFirstChild(Name)
    elseif Character:FindFirstChild(Name) then
        return Character:FindFirstChild(Name)
    end
end

Functions.GetFlyVelocity = function()
    if Humanoid.MoveDirection == Vector3.zero then
        return Humanoid.MoveDirection
    end
    local LookFlat = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z)
    local FlatFrame = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + LookFlat)
    local Velocity = (Camera.CFrame * CFrame.new(FlatFrame:VectorToObjectSpace(Humanoid.MoveDirection))).Position - Camera.CFrame.Position
    if Velocity == Vector3.zero then return Velocity end
    return Velocity.Unit
end

-- ════════════════════════════════════════════════════════════════
-- ESP FUNCTIONS
-- ════════════════════════════════════════════════════════════════
Globals.PromptContainer = Instance.new("Folder")
Globals.PromptContainer.Name = "PromptContainer"
Globals.PromptContainer.Parent = GetHiddenContainer()

local ESPBlacklist = {}

Functions.AddESP = function(ESPOptions, RoomBased)
    local Object = ESPOptions.Object
    if table.find(ESPBlacklist, Object) then return end

    if RoomBased then
        local CurrentRoom = tonumber(LocalPlayer:GetAttribute("CurrentRoom"))
        local ObjectRoom = tonumber(Object:GetAttribute("ParentRoom"))
        if ObjectRoom == CurrentRoom or (table.find(Objects.Doors, Object) and ObjectRoom == CurrentRoom + 1) then
            FeatherHub.ESPLibrary:AddESP(ESPOptions)
        end

        local RoomConnection = LocalPlayer:GetAttributeChangedSignal("CurrentRoom"):Connect(function()
            if FeatherHub.ESPLibrary.ColorTable[Object] then
                ESPOptions.Color = FeatherHub.ESPLibrary.ColorTable[Object]
            end
            local NewCurrentRoom = tonumber(LocalPlayer:GetAttribute("CurrentRoom"))
            local ObjRoom = tonumber(Object:GetAttribute("ParentRoom"))
            if ObjRoom == NewCurrentRoom or (table.find(Objects.Doors, Object) and ObjRoom == NewCurrentRoom + 1) then
                FeatherHub.ESPLibrary:AddESP(ESPOptions)
            else
                FeatherHub.ESPLibrary:RemoveESP(Object)
            end
        end)

        table.insert(Connections, RoomConnection)
        ESPConnections[Object] = RoomConnection

        Object.Destroying:Once(function()
            RoomConnection:Disconnect()
            if FeatherHub then FeatherHub.ESPLibrary:RemoveESP(Object) end
            local Pos = table.find(Connections, RoomConnection)
            if Pos then table.remove(Connections, Pos) end
        end)
    else
        FeatherHub.ESPLibrary:AddESP(ESPOptions)
    end
end

Functions.RemoveESP = function(Object)
    local Conn = ESPConnections[Object]
    if Conn then
        Conn:Disconnect()
        ESPConnections[Object] = nil
        local Pos = table.find(Connections, Conn)
        if Pos then table.remove(Connections, Pos) end
    end
    FeatherHub.ESPLibrary:RemoveESP(Object)
end

Functions.BlacklistESP = function(Object)
    table.insert(ESPBlacklist, Object)
end

Functions.GetDoorNumber = function(Object)
    local DoorNumber = tonumber(Object.Parent.Name) or tonumber(Object.Parent.Parent.Name)
    if DoorNumber then DoorNumber = DoorNumber + 1 end
    if Floor == "Mines" then DoorNumber = DoorNumber + 100 end
    if Floor == "Backdoor" then DoorNumber = DoorNumber - 50 end
    return tostring(DoorNumber)
end

Functions.GetLibraryCode = function()
    local Paper = Character:FindFirstChild("LibraryHintPaper")
        or Character:FindFirstChild("LibraryHintPaperHard")
        or LocalPlayer.Backpack:FindFirstChild("LibraryHintPaper")
        or LocalPlayer.Backpack:FindFirstChild("LibraryHintPaperHard")

    if Paper and Paper:FindFirstChild("UI") then
        local Code = {}
        local CodeLength = Floor == "Fools" and 10 or 5
        for I = 1, CodeLength do Code[I] = "_" end

        local HintChildren = LocalPlayer.PlayerGui.PermUI.Hints:GetChildren()
        local UIChildren = Paper.UI:GetChildren()

        for _, Hint in HintChildren do
            for _, UIChild in UIChildren do
                if Hint:IsA("ImageLabel") and UIChild:IsA("ImageLabel")
                    and Hint.ImageRectOffset == UIChild.ImageRectOffset
                    and Code[tonumber(UIChild.Name)] then
                    Code[tonumber(UIChild.Name)] = Hint.TextLabel.Text
                end
            end
        end
        return table.concat(Code)
    end
    return Floor == "Fools" and "__________" or "_____"
end

Globals.UsedRandomCodes = {}
Functions.GetRandomCode = function()
    local CodeTemplate = Functions.GetLibraryCode()
    if not CodeTemplate then return nil end
    local NewCode
    local Tries = 0
    repeat
        NewCode = CodeTemplate:gsub("_", function() return tostring(math.random(0, 9)) end)
        Tries = Tries + 1
    until not Globals.UsedRandomCodes[NewCode] or Tries >= 10
    Globals.UsedRandomCodes[NewCode] = true
    return NewCode
end

-- ════════════════════════════════════════════════════════════════
-- WINDOW & TABS CREATION
-- ════════════════════════════════════════════════════════════════
local Window = Library:CreateWindow({
    Title = "FeatherHub",
    Footer = "DOORS · Русский интерфейс",
    Icon = "feather",
    IconSize = UDim2.fromOffset(24, 24),
    Size = UDim2.fromOffset(880, 650),
    Font = Enum.Font.Gotham,
    NotifySide = "Right",
    ShowCustomCursor = false,
    AutoShow = true,
    Center = true,
    Resizable = true,
    GlobalSearch = true,
    EnableSidebarResize = true,
    MinSidebarWidth = 160,
    CornerRadius = 10,
    TabButtonsStyle = { Gap = 5, Padding = 8, CornerRadius = 7 },
    Animations = { ToggleWindow = true, TabSwitch = true, Groupbox = false, Dropdown = true, KeyPicker = true },
    TabTransitionTime = 0.16,
})-- ════════════════════════════════════════════════════════════════
-- SCRIPT ICON NEXT TO TITLE
-- ════════════════════════════════════════════════════════════════
-- Значок пера создаётся штатным API окна, без поиска внутренних Frame.

FeatherHub.Interface.ApplyInfoTab(Window)

local L = Interface.Language == "RU"
local Tabs = {
    General   = Window:AddTab(L and "Основное" or "General", "house"),
    Exploits  = Window:AddTab(L and "Эксплойты" or "Exploits", "shield"),
    Visuals   = Window:AddTab(L and "Визуал" or "Visuals", "eye"),
    Floors    = Window:AddTab(L and "Этажи" or "Floors", "earth"),
    Archives  = Window:AddTab(L and "Новое — Архивы" or "New — Archives", "rbxassetid://104508835882225"),
    Stairwell = Window:AddTab(L and "Новое — Лестница" or "New — Stairwell", "rbxassetid://80017304328364"),
}
Tabs.Stairwell:AddLeftGroupbox(L and "О разделе" or "About"):AddLabel(L and "В исходном скрипте функции для лестницы ещё не добавлены." or "Stairwell functions are not yet added in the original script.", true)


-- ════════════════════════════════════════════════════════════════
-- GENERAL TAB — CHARACTER GROUPBOX
-- ════════════════════════════════════════════════════════════════
Groupboxes.General_Character = Tabs.General:AddLeftGroupbox("Персонаж")
Groupboxes.General_Character:AddSlider("SpeedBoostSlider", {
    Text = "Прибавка скорости", Min = 0, Max = 100, Default = 0, Rounding = 0, Compact = true
})
Groupboxes.General_Character:AddToggle("SpeedBoostToggle", {
    Text = "Включить ускорение", Default = false, Tooltip = "Увеличивает скорость ходьбы на указанную величину."
})
Groupboxes.General_Character:AddToggle("FlyToggle", {
    Text = "Полёт", Default = false, Tooltip = "Позволяет свободно летать по карте."
})
Toggles.FlyToggle:AddKeyPicker("FlyKeybind", {
    Text = "Полёт", Default = "F", Mode = "Toggle", SyncToggleState = true
})
Groupboxes.General_Character:AddSlider("FlySpeed", {
    Text = "Скорость полёта", Min = 0, Max = 115, Default = 20, Rounding = 0, Compact = true
})
Groupboxes.General_Character:AddDivider()
Groupboxes.General_Character:AddToggle("NoclipToggle", {
    Text = "Сквозь стены", Default = false, Tooltip = "Позволяет проходить сквозь твёрдые объекты."
})
Groupboxes.General_Character:AddToggle("RemoveClosetDelay", {
    Text = "Без задержки выхода из шкафа", Default = false,
    Tooltip = "Убирает задержку выхода из шкафа после завершения анимации."
})
Groupboxes.General_Character:AddToggle("RemoveAcceleration", {
    Text = "Без инерции", Default = false, Tooltip = "Убирает скольжение персонажа при движении."
})

local CustomPhysics

Options.SpeedBoostSlider:OnChanged(function(Value)
    if RemotesFolder:FindFirstChild("Crouch") then
        RemotesFolder.Crouch:FireServer(Value and true or Functions.IsCrouching(), true)
    end
end)

Toggles.NoclipToggle:AddKeyPicker("NoclipKeybind", {
    Text = "Сквозь стены", Default = "N", Mode = "Toggle", SyncToggleState = true
})
Toggles.RemoveAcceleration:OnChanged(function(Value)
    for Index, Old in PartProperties do
        Index.CustomPhysicalProperties = Value and CustomPhysics or Old
    end
end)

Groupboxes.General_Character:AddDivider()
Groupboxes.General_Character:AddToggle("EnableCharacterJump", {
    Text = "Разрешить прыжки", Default = false, Tooltip = "Позволяет персонажу прыгать."
})
Groupboxes.General_Character:AddToggle("EnableCharacterSlide", {
    Text = "Разрешить подкат", Default = false, Tooltip = "Позволяет персонажу делать подкат."
})
Groupboxes.General_Character:AddToggle("InfiniteJumps", {
    Text = "Бесконечные прыжки", Default = false, Tooltip = "Позволяет прыгать в воздухе."
})

local OldJump = false
local OldSlide = false

Toggles.SpeedBoostToggle:OnChanged(function(Value)
    if Humanoid then
        Humanoid.WalkSpeed = Functions.GetCurrentSpeed() + (Value and Options.SpeedBoostSlider.Value or 0)
    end
end)
Toggles.EnableCharacterJump:OnChanged(function(Value)
    if Character then Character:SetAttribute("CanJump", Value and true or OldJump) end
end)
Toggles.EnableCharacterSlide:OnChanged(function(Value)
    if Character then Character:SetAttribute("CanSlide", Value and true or OldSlide) end
end)

-- ════════════════════════════════════════════════════════════════
-- GENERAL TAB — SELF GROUPBOX
-- ════════════════════════════════════════════════════════════════
Groupboxes.General_Self = Tabs.General:AddLeftGroupbox("Личные настройки")
Groupboxes.General_Self:AddToggle("DoorReachToggle", {
    Text = "Дальность открытия дверей", Default = false, Tooltip = "Позволяет открывать двери с большего расстояния."
})
Groupboxes.General_Self:AddToggle("DisableIdleKick", {
    Text = "Защита от AFK-кика", Default = false, Tooltip = "Не даёт исключить вас за 20 минут бездействия."
})
Toggles.DisableIdleKick:OnChanged(function(Value)
    if Functions.CheckCompatability({"getconnections"}) then
        for _, Conn in FeatherHub.Environment.getconnections(LocalPlayer.Idled) do
            if Value then Conn:Disable() else Conn:Enable() end
        end
    end
end)
LocalPlayer.Idled:Connect(function()
    if Toggles.DisableIdleKick.Value then
        Services.VirtualUser:CaptureController()
        Services.VirtualUser:ClickButton2(Vector2.new())
    end
end)

Groupboxes.General_Self:AddDivider()
Groupboxes.General_Self:AddSlider("PromptReachSlider", {
    Text = "Множитель дальности взаимодействия", Min = 1, Max = 2, Default = 1, Rounding = 1, Compact = true
})
Groupboxes.General_Self:AddToggle("InstantPrompts", {
    Text = "Мгновенное взаимодействие", Default = false, Tooltip = "Позволяет мгновенно активировать взаимодействия."
})
Groupboxes.General_Self:AddToggle("PromptClip", {
    Text = "Взаимодействие сквозь стены", Default = false, Tooltip = "Позволяет взаимодействовать с объектами сквозь стены."
})

Options.PromptReachSlider:OnChanged(function(Value)
    for _, Prompt in Objects.Prompts do
        Prompt.MaxActivationDistance = Prompt:GetAttribute("MaxActivationDistance_Old") * Value
    end
end)
Toggles.InstantPrompts:OnChanged(function(Value)
    for _, Prompt in Objects.Prompts do
        Prompt.HoldDuration = Value and 0 or Prompt:GetAttribute("HoldDuration_Old")
    end
end)
Toggles.PromptClip:OnChanged(function(Value)
    for _, Prompt in Objects.Prompts do
        Prompt.RequiresLineOfSight = Value and false or Prompt:GetAttribute("RequiresLineOfSight_Old")
    end
end)

-- ════════════════════════════════════════════════════════════════
-- GENERAL TAB — AUTOMATION GROUPBOX
-- ════════════════════════════════════════════════════════════════
Groupboxes.Self_Automation = Tabs.General:AddRightGroupbox("Автоматизация")
Groupboxes.Self_Automation:AddToggle("AutoBreakerBox", {
    Text = "Автоматический электрощит", Default = false, Tooltip = "Автоматически решает головоломку электрощита."
})
Groupboxes.Self_Automation:AddToggle("AutoSolveAnchors", {
    Text = "Автоматические якоря", Default = false,
    Tooltip = "Автоматически вводит правильный код в ближайшие якоря."
})
Toggles.AutoBreakerBox:OnChanged(function(Value)
    if Value and CurrentRooms:FindFirstChild("ElevatorBreaker", true) then
        if not Globals.BreakerBoxInteracted then
            if not Globals.BreakerBoxNotified then
                Functions.Notify({ Title = "Взаимодействуйте с электрощитом.", Body = "Головоломка будет решена автоматически." })
                Globals.BreakerBoxInteracted = true
            end
        else
            RemotesFolder.EBF:FireServer()
        end
    end
end)

Groupboxes.Self_Automation:AddToggle("AutoHeartbeatMinigame", {
    Text = "Автоматическая мини-игра сердцебиения", Default = false, Tooltip = "Не даёт проиграть мини-игру Figure.",
    Disabled = not Functions.CheckCompatability({"hookmetamethod", "newcclosure", "getnamecallmethod"}),
    DisabledTooltip = Globals.IncompatibleMessage
})
Groupboxes.Self_Automation:AddDivider()
Groupboxes.Self_Automation:AddToggle("AutoUnlockPadlockToggle", {
    Text = "Автоматический кодовый замок", Default = false, Tooltip = "Автоматически вводит код в замок библиотеки."
})
Groupboxes.Self_Automation:AddSlider("AutoUnlockPadlockSlider", {
    Text = "Дальность открытия замка", Min = 1, Max = 50, Default = 10, Rounding = 0, Compact = true
})
Groupboxes.Self_Automation:AddToggle("AutoLibraryGuessCode", {
    Text = "Подбор кода библиотеки", Default = false,
    Tooltip = "Пытается подобрать код библиотеки; часть книг всё равно нужно собрать."
})
Groupboxes.Self_Automation:AddDivider()
Groupboxes.Self_Automation:AddToggle("AutoInteractToggle", {
    Text = "Автовзаимодействие", Default = false, Tooltip = "Автоматически активирует ближайшие взаимодействия."
})
Toggles.AutoInteractToggle:AddKeyPicker("AutoInteractKeybind", {
    Text = "Автовзаимодействие", Default = "R",
    Mode = Library.IsMobile and "Toggle" or "Hold", SyncToggleState = true
})
Groupboxes.Self_Automation:AddDropdown("AutoInteractIgnoreList", {
    Text = "Список исключений",
    Values = { "Glitch Fragments", "Jeff Items", "Dropped Items", "Currency", "Minecarts", "Locks" },
    Default = { "Glitch Fragments", "Jeff Items", "Dropped Items" },
    Multi = true, AllowNull = true
})
Groupboxes.Self_Automation:AddDivider()
Groupboxes.Self_Automation:AddToggle("AutoClosetToggle", {
    Text = "Автоукрытие в шкафу", Default = false,
    Tooltip = "Автоматически прячет в ближайший шкаф при приближении сущности."
})
Toggles.AutoClosetToggle:AddKeyPicker("AutoClosetKeybind", {
    Text = "Автоукрытие в шкафу", Default = "Q", Mode = "Toggle", SyncToggleState = true
})
Groupboxes.Self_Automation:AddDropdown("AutoClosetEntityList", {
    Text = "Список исключений",
    Values = { "Rush", "Ambush", "Blitz", "DronesStampede", "Scribbles", "A-60", "A-120", "AR0xMBUSH", "RNIUSHCG==" },
    Multi = true, AllowNull = true
})
Groupboxes.Self_Automation:AddToggle("SpectateEntityToggle", {
    Text = "Наблюдать за сущностью", Default = false, Tooltip = "Наблюдает за сущностью во время автоукрытия."
})
Groupboxes.Self_Automation:AddDropdown("SpecateEntityMode", {
    Values = {"Player to Entity", "Entity to Player"}, Default = 1, AllowNull = true
})

-- ════════════════════════════════════════════════════════════════
-- GENERAL TAB — MISCELLANEOUS GROUPBOX
-- ════════════════════════════════════════════════════════════════
Groupboxes.Self_Misc = Tabs.General:AddRightGroupbox("Разное")
Groupboxes.Self_Misc:AddButton({
    Text = "Играть снова", Tooltip = "Запускает новый забег; нажмите ещё раз для отмены.", DoubleClick = true,
    Func = function() RemotesFolder.PlayAgain:FireServer() end
})
Groupboxes.Self_Misc:AddButton({
    Text = "Вернуться в лобби", Tooltip = "Телепортирует вас обратно в лобби.", DoubleClick = true,
    Func = function() RemotesFolder.Lobby:FireServer() end
})
Groupboxes.Self_Misc:AddButton({
    Text = "Возродиться",
    Tooltip = "Возрождает, если у вас есть возрождение и вы ещё не использовали его в этом забеге.",
    DoubleClick = true,
    Func = function() RemotesFolder.Revive:FireServer() end
})
Groupboxes.Self_Misc:AddButton({
    Text = "Сбросить персонажа",
    Tooltip = "Убивает вашего персонажа на сервере.",
    DoubleClick = true,
    Func = function()
        Globals.SelfKilled = true
        if Functions.CheckCompatability({"replicatesignal"}) then
            FeatherHub.Environment.replicatesignal(LocalPlayer.Kill)
        else
            if RemotesFolder:FindFirstChild("Underwater") then
                RemotesFolder.Underwater:FireServer(true)
            else
                Humanoid.Health = 0
            end
        end
    end
})

Groupboxes.Debug = Tabs.General:AddRightGroupbox("Отладка")
Groupboxes.Debug:AddButton({
    Text = "В пустоту", Tooltip = "Телепортирует персонажа на высоту Y = -120.",
    Func = function()
        if not Character then return end
        local Pivot = Character:GetPivot()
        for _ = 1, 22 do
            Character:PivotTo(Pivot + Vector3.new(0, -120 - Pivot.Position.Y, 0))
        end
    end
})
Groupboxes.Debug:AddButton({
    Text = "Выйти из шкафа", Tooltip = "Выводит из текущего шкафа.",
    Func = function()
        if RemotesFolder and RemotesFolder:FindFirstChild("CamLock") then
            RemotesFolder.CamLock:FireServer()
        end
    end
})
-- ════════════════════════════════════════════════════════════════
-- PART 3: Exploits Tab, Anti-Lag, Archives, Visuals Start
-- ════════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════════════════════════
-- EXPLOITS TAB — BYPASS / SOLVE
-- ════════════════════════════════════════════════════════════════
Groupboxes.Exploits_Bypass = Tabs.Exploits:AddLeftGroupbox("Обход / Решение")

Groupboxes.Exploits_Bypass:AddToggle("BypassGiggle",         { Text = "Обход Giggle",           Default = false, Tooltip = "Защищает от атак Giggle." })
Groupboxes.Exploits_Bypass:AddToggle("BypassDupe",           { Text = "Обход Dupe",             Default = false, Tooltip = "Не даёт открыть ложные двери Dupe." })
Groupboxes.Exploits_Bypass:AddToggle("BypassEyes",           { Text = "Обход Eyes",             Default = false, Tooltip = "Защищает от урона Eyes." })
Groupboxes.Exploits_Bypass:AddToggle("BypassLookman",        { Text = "Обход Lookman",          Default = false, Tooltip = "Защищает от урона Lookman." })
Groupboxes.Exploits_Bypass:AddToggle("BypassGloombatEggs",   { Text = "Обход яиц Gloombat",    Default = false, Tooltip = "Защищает от урона при наступании на яйца Gloombat." })
Groupboxes.Exploits_Bypass:AddToggle("BypassSeekObstructions", { Text = "Обход препятствий Seek", Default = false, Tooltip = "Защищает от препятствий в погоне Seek." })
Groupboxes.Exploits_Bypass:AddToggle("BypassVacuum",         { Text = "Обход Vacuum",           Default = false, Tooltip = "Не даёт провалиться в ложные двери Vacuum." })
Groupboxes.Exploits_Bypass:AddToggle("BypassKillbricks",     { Text = "Обход смертельных блоков",       Default = false, Tooltip = "Защищает от урона лавы." })
Groupboxes.Exploits_Bypass:AddToggle("BypassSeekingWall",    { Text = "Обход стены Seek",     Default = false, Tooltip = "Защищает от урона ScaryWall." })
Groupboxes.Exploits_Bypass:AddToggle("BypassSnare",          { Text = "Обход Snare",            Default = false, Tooltip = "Не даёт попасть в ловушку Snare." })
Groupboxes.Exploits_Bypass:AddToggle("BypassBanana",         { Text = "Обход банановой кожуры",           Default = false, Tooltip = "Защищает от скольжения на банановой кожуре (работает не всегда)." })
Groupboxes.Exploits_Bypass:AddToggle("BypassJeff",           { Text = "Обход Jeff",             Default = false, Tooltip = "Защищает от ножа Jeff the Killer (работает не всегда)." })

Toggles.BypassGiggle:OnChanged(function(Value)
    for _, Object in Objects.Entities do
        if Object.Name == "GiggleCeiling" then
            Object:WaitForChild("Hitbox").CanTouch = not Value
        end
    end
end)
Toggles.BypassDupe:OnChanged(function(Value)
    for _, Object in Objects.Entities do
        if Object.Name == "DoorFake" or Object.Name == "FakeDoor" then
            Object:WaitForChild("Hidden").CanTouch = not Value
            if Object:FindFirstChild("Lock") then
                Object.Lock.UnlockPrompt.Enabled = not Value
            end
        end
    end
end)
Toggles.BypassEyes:OnChanged(function(Value)
    if Value and Globals.IsEyes then
        if Floor == "Fools" or Floor == "OldHotel" then
            RemotesFolder.MotorReplication:FireServer(0, (Globals.SpoofOffset == 200 and 65 or -65), 0, false)
        else
            RemotesFolder.MotorReplication:FireServer(-650)
        end
    end
end)
Toggles.BypassLookman:OnChanged(function(Value)
    if Value and Globals.IsLookman then
        if Floor == "Fools" or Floor == "OldHotel" then
            RemotesFolder.MotorReplication:FireServer(0, (Globals.SpoofOffset == 200 and 65 or -65), 0, false)
        else
            RemotesFolder.MotorReplication:FireServer(-650)
        end
    end
end)
Toggles.BypassGloombatEggs:OnChanged(function(Value)
    for _, Object in Objects.Entities do
        for _, Part in Object:GetDescendants() do
            if Part:IsA("BasePart") then Part.CanTouch = not Value end
        end
    end
end)
Toggles.BypassSeekObstructions:OnChanged(function(Value)
    for _, Object in Objects.SeekObstructions do
        Object.CanTouch = not Value
        if Object.Name == "SeekFloodline" then Object.CanCollide = Value end
    end
    for _, Object in Objects.SeekBridges do
        Object.CanCollide = Value
        Object.Transparency = Value and 0 or 1
    end
end)
Toggles.BypassVacuum:OnChanged(function(Value)
    for _, Object in Objects.Entities do
        if Object.Name == "SideroomSpace" then
            Object:WaitForChild("Collision").CanCollide = Value
            Object:WaitForChild("Collision").CanTouch = not Value
        end
    end
end)
Toggles.BypassKillbricks:OnChanged(function(Value)
    for _, Object in Objects.Obstructions do
        if Object.Name == "Lava" then Object.CanTouch = not Value end
    end
end)
Toggles.BypassSeekingWall:OnChanged(function(Value)
    for _, Object in Objects.Obstructions do
        if Object.Name == "ScaryWall" then
            for _, Part in Object:GetDescendants() do
                if Part:IsA("BasePart") then
                    Part.CanTouch = not Value
                    Part.CanCollide = not Value
                end
            end
        end
    end
end)
Toggles.BypassSnare:OnChanged(function(Value)
    for _, Object in Objects.Entities do
        if Object.Name == "Snare" then
            for _, Part in Object:GetDescendants() do
                if Part:IsA("BasePart") then Part.CanTouch = not Value end
            end
        end
    end
end)
Toggles.BypassBanana:OnChanged(function(Value)
    for _, Object in Objects.Entities do
        if Object.Name == "BananaPeel" then Object.CanTouch = not Value end
    end
end)
Toggles.BypassJeff:OnChanged(function(Value)
    for _, Object in Objects.Entities do
        if Object.Name == "JeffTheKiller" then
            for _, Part in Object:GetDescendants() do
                if Part:IsA("BasePart") then
                    Part.CanCollide = not Value
                    Part.CanTouch = not Value
                end
            end
            Object:WaitForChild("Humanoid").Health = 0
        end
    end
end)

-- ════════════════════════════════════════════════════════════════
-- GENERAL TAB — ANTI-LAG GROUPBOX
-- ════════════════════════════════════════════════════════════════
Groupboxes.General_AntiLag = Tabs.General:AddRightGroupbox("Оптимизация")

Groupboxes.General_AntiLag:AddToggle("AntiLagParticles", {
    Text = "Отключить частицы", Default = false, Tooltip = "Локально отключает эмиттеры частиц."
})
Groupboxes.General_AntiLag:AddToggle("AntiLagTrails", {
    Text = "Отключить следы / лучи", Default = false, Tooltip = "Локально отключает следы и лучи."
})
Groupboxes.General_AntiLag:AddToggle("AntiLagLights", {
    Text = "Отключить источники света", Default = false, Tooltip = "Локально отключает точечные, направленные и поверхностные источники света."
})
Groupboxes.General_AntiLag:AddToggle("AntiLagTextures", {
    Text = "Скрыть текстуры", Default = false, Tooltip = "Локально скрывает декали и текстуры."
})
Groupboxes.General_AntiLag:AddToggle("AntiLagMaterials", {
    Text = "Упростить материалы", Default = false, Tooltip = "Локально заменяет материалы деталей на гладкий пластик."
})
Groupboxes.General_AntiLag:AddToggle("AntiLagEffects", {
    Text = "Отключить постобработку", Default = false, Tooltip = "Локально отключает эффекты постобработки."
})
Groupboxes.General_AntiLag:AddToggle("AntiLagShadows", {
    Text = "Отключить тени", Default = false, Tooltip = "Локально отключает глобальные тени освещения."
})

local AntiLagOriginals = {
    Particles = {}, Trails = {}, Lights = {}, Textures = {},
    Materials = {}, Reflectance = {}, Effects = {},
    GlobalShadows = Services.Lighting.GlobalShadows,
}

local function ApplyAntiLagToObject(Object)
    if Object:IsA("ParticleEmitter") then
        if AntiLagOriginals.Particles[Object] == nil then
            AntiLagOriginals.Particles[Object] = Object.Enabled
        end
        Object.Enabled = Toggles.AntiLagParticles.Value and false or AntiLagOriginals.Particles[Object]
    elseif Object:IsA("Trail") or Object:IsA("Beam") then
        if AntiLagOriginals.Trails[Object] == nil then
            AntiLagOriginals.Trails[Object] = Object.Enabled
        end
        Object.Enabled = Toggles.AntiLagTrails.Value and false or AntiLagOriginals.Trails[Object]
    elseif Object:IsA("PointLight") or Object:IsA("SpotLight") or Object:IsA("SurfaceLight") then
        if AntiLagOriginals.Lights[Object] == nil then
            AntiLagOriginals.Lights[Object] = Object.Enabled
        end
        Object.Enabled = Toggles.AntiLagLights.Value and false or AntiLagOriginals.Lights[Object]
    elseif Object:IsA("Decal") or Object:IsA("Texture") then
        if AntiLagOriginals.Textures[Object] == nil then
            AntiLagOriginals.Textures[Object] = Object.Transparency
        end
        Object.Transparency = Toggles.AntiLagTextures.Value and 1 or AntiLagOriginals.Textures[Object]
    elseif Object:IsA("BasePart") then
        if AntiLagOriginals.Materials[Object] == nil then
            AntiLagOriginals.Materials[Object] = Object.Material
        end
        if AntiLagOriginals.Reflectance[Object] == nil then
            AntiLagOriginals.Reflectance[Object] = Object.Reflectance
        end
        if Toggles.AntiLagMaterials.Value then
            Object.Material = Enum.Material.SmoothPlastic
            Object.Reflectance = 0
        else
            Object.Material = AntiLagOriginals.Materials[Object]
            Object.Reflectance = AntiLagOriginals.Reflectance[Object]
        end
    elseif Object:IsA("PostEffect") then
        if AntiLagOriginals.Effects[Object] == nil then
            AntiLagOriginals.Effects[Object] = Object.Enabled
        end
        Object.Enabled = Toggles.AntiLagEffects.Value and false or AntiLagOriginals.Effects[Object]
    end
end

game.DescendantAdded:Connect(ApplyAntiLagToObject)

for _, Object in ipairs(game:GetDescendants()) do
    task.spawn(ApplyAntiLagToObject, Object)
end

Toggles.AntiLagParticles:OnChanged(function()
    for _, Object in ipairs(game:GetDescendants()) do task.spawn(ApplyAntiLagToObject, Object) end
end)
Toggles.AntiLagTrails:OnChanged(function()
    for _, Object in ipairs(game:GetDescendants()) do task.spawn(ApplyAntiLagToObject, Object) end
end)
Toggles.AntiLagLights:OnChanged(function()
    for _, Object in ipairs(game:GetDescendants()) do task.spawn(ApplyAntiLagToObject, Object) end
end)
Toggles.AntiLagTextures:OnChanged(function()
    for _, Object in ipairs(game:GetDescendants()) do task.spawn(ApplyAntiLagToObject, Object) end
end)
Toggles.AntiLagMaterials:OnChanged(function()
    for _, Object in ipairs(game:GetDescendants()) do task.spawn(ApplyAntiLagToObject, Object) end
end)
Toggles.AntiLagEffects:OnChanged(function()
    for _, Object in ipairs(game:GetDescendants()) do task.spawn(ApplyAntiLagToObject, Object) end
end)
Toggles.AntiLagShadows:OnChanged(function(Value)
    Services.Lighting.GlobalShadows = Value and false or AntiLagOriginals.GlobalShadows
end)

-- ════════════════════════════════════════════════════════════════
-- ARCHIVES TAB — EXPLOITS / ANTI
-- ════════════════════════════════════════════════════════════════
Groupboxes.Archives_Misc = Tabs.Archives:AddRightGroupbox("Эксплойты / Защита")
Groupboxes.Archives_Misc:AddToggle("AntiRansom", { Text = "Защита от Ransom", Default = false, Tooltip = "Защищает от атак Ransom." })
Groupboxes.Archives_Misc:AddToggle("AntiClosetTrash", { Text = "Без мусора в шкафах", Default = false, Tooltip = "Предотвращает появление мусора в шкафах." })
Groupboxes.Archives_Misc:AddToggle("ForgetMeNotSolver", { Text = "Пропуск Forget Me Not", Default = false, Tooltip = "Автоматически пропускает двери Forget Me Not." })
Groupboxes.Archives_Misc:AddToggle("TimeShower", { Text = "Показать время", Default = false, Tooltip = "Показывает время на часах Архивов." })
Groupboxes.Archives_Misc:AddToggle("BypassDronesStampede", { Text = "Остановка времени / Защита от стада", Default = false, Tooltip = "Защищает от атак The Drones Stampede." })

TimeShowerLabel = Instance.new("TextLabel")
TimeShowerLabel.Name = "TimeShower"
TimeShowerLabel.AnchorPoint = Vector2.new(0, 1)
TimeShowerLabel.Position = UDim2.new(0, 12, 1, -12)
TimeShowerLabel.Size = UDim2.new(0, 180, 0, 32)
TimeShowerLabel.BackgroundTransparency = 1
TimeShowerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TimeShowerLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
TimeShowerLabel.TextStrokeTransparency = 0.35
TimeShowerLabel.Font = Enum.Font.GothamBold
TimeShowerLabel.TextSize = 18
TimeShowerLabel.TextXAlignment = Enum.TextXAlignment.Left
TimeShowerLabel.Text = "Время: --:--"
TimeShowerLabel.Visible = false
TimeShowerLabel.Parent = Container

local function GetArchivesClockLabel(Room)
    local Assets = Room and Room:FindFirstChild("Assets", true)
    local Clock = Assets and Assets:FindFirstChild("ArchivesClock", true)
    local Time = Clock and Clock:FindFirstChild("Time", true)
    local TextLabel = Time and Time:FindFirstChild("TextLabel")
    if TextLabel and TextLabel:IsA("TextLabel") then return TextLabel end
    return nil
end

local function ResolveClockLabel()
    if TimeShowerSourceLabel and TimeShowerSourceLabel.Parent and TimeShowerSourceLabel:IsDescendantOf(game) then
        return TimeShowerSourceLabel
    end
    local currentRooms = workspace:FindFirstChild("CurrentRooms")
    if not currentRooms then return nil end
    local rooms = {}
    for _, room in ipairs(currentRooms:GetChildren()) do
        local num = tonumber(room.Name)
        if num then table.insert(rooms, {room = room, num = num}) end
    end
    table.sort(rooms, function(a, b) return a.num > b.num end)
    local endIndex = math.min(6, #rooms)
    for i = 1, endIndex do
        local label = GetArchivesClockLabel(rooms[i].room)
        if label then TimeShowerSourceLabel = label return label end
    end
    return nil
end

local function ResolveClockRemote()
    local label = ResolveClockLabel()
    if not label then return nil end
    local clock = label:FindFirstAncestor("ArchivesClock")
    if not clock then return nil end
    local remote = clock:FindFirstChild("LookedAtRemote", true)
    return (remote and remote:IsA("RemoteEvent")) and remote or nil
end

task.spawn(function()
    local lastCheckedRoomCount = 0
    while game:IsLoaded() do
        local currentRooms = workspace:FindFirstChild("CurrentRooms")
        if currentRooms then
            local roomCount = 0
            for _, child in ipairs(currentRooms:GetChildren()) do
                if tonumber(child.Name) then roomCount += 1 end
            end
            if roomCount > 0 and (lastCheckedRoomCount == 0 or (roomCount - lastCheckedRoomCount) >= 10) then
                ResolveClockLabel()
                lastCheckedRoomCount = roomCount
            end
        end
        task.wait(0.5)
    end
end)

local function StopTimeShower()
    TimeShowerToken += 1
    if TimeShowerConnection then
        TimeShowerConnection:Disconnect()
        TimeShowerConnection = nil
    end
    if TimeShowerLabel then
        TimeShowerLabel.Visible = false
        TimeShowerLabel.Text = "Время: --:--"
    end
end

Toggles.TimeShower:OnChanged(function(Value)
    StopTimeShower()
    if not Value then return end
    local Token = TimeShowerToken
    TimeShowerLabel.Visible = true
    TimeShowerConnection = Services.RunService.Heartbeat:Connect(function()
        if Token ~= TimeShowerToken then return end
        local TextLabel = ResolveClockLabel()
        if TextLabel then
            TimeShowerLabel.Text = "Время: " .. TextLabel.Text
        else
            TimeShowerLabel.Text = "Время: --:--"
        end
    end)
end)

Toggles.BypassDronesStampede:OnChanged(function(enabled)
    if BypassDronesStampedeConnection then
        task.cancel(BypassDronesStampedeConnection)
        BypassDronesStampedeConnection = nil
    end
    if not enabled then return end
    BypassDronesStampedeConnection = task.spawn(function()
        while Toggles.BypassDronesStampede.Value do
            local remote = ResolveClockRemote()
            if remote then remote:FireServer() end
            task.wait(1)
        end
    end)
end)

-- ════════════════════════════════════════════════════════════════
-- ARCHIVES TAB — BYPASSES GROUPBOX
-- ════════════════════════════════════════════════════════════════
Groupboxes.Archives_Bypasses = Tabs.Archives:AddLeftGroupbox("Обходы")
Groupboxes.Archives_Bypasses:AddToggle("BypassWater", { Text = "Обход воды под напряжением", Default = false, Tooltip = "Защищает от урона воды под напряжением." })
Groupboxes.Archives_Bypasses:AddToggle("BypassAlma", { Text = "Обход Alma", Default = false, Tooltip = "Предотвращает появление Alma." })
Groupboxes.Archives_Bypasses:AddToggle("BypassDrones", { Text = "Обход дронов", Default = false, Tooltip = "Защищает от атак дронов." })
Groupboxes.Archives_Bypasses:AddToggle("AntiScribbles", { Text = "Обход Scribbles", Default = false, Tooltip = "Защищает от атак Scribbles." })

Groupboxes.Archives_Experimental = Tabs.Archives:AddLeftGroupbox("Экспериментальное")

Toggles.AntiClosetTrash:OnChanged(function(Value)
    if AntiClosetTrash_Connection then
        AntiClosetTrash_Connection:Disconnect()
        AntiClosetTrash_Connection = nil
    end
    if not Value then return end
    AntiClosetTrash_Connection = workspace.ChildAdded:Connect(function(Child)
        if not Toggles.AntiClosetTrash.Value then return end
        local Name = Child.Name
        if (Name:sub(1, 6) == "Binder" or Name:sub(1, 4) == "Shoe" or Name:sub(1, 5) == "Shelf") then
            Child:Destroy()
        end
    end)
end)

Toggles.AntiRansom:OnChanged(function(Value)
    if AntiRansom_Connection then
        AntiRansom_Connection:Disconnect()
        AntiRansom_Connection = nil
    end
    if not Value then return end
    AntiRansom_Connection = workspace.ChildAdded:Connect(function(Child)
        if Child.Name == "Ransom" and Toggles.AntiRansom.Value then
            Child:Destroy()
        end
    end)
end)

Toggles.ForgetMeNotSolver:OnChanged(function(Value)
    if ForgetMeNotConnection then
        ForgetMeNotConnection:Disconnect()
        ForgetMeNotConnection = nil
    end
    ForgetMeNotRunning = false
    ForgetMeNotProcessing = {}
    ForgetMeNotNotified = {}
    if not Value then return end
    ForgetMeNotRunning = true

    local function GetCharacter()
        return game.Players.LocalPlayer.Character or game.Players.LocalPlayer.CharacterAdded:Wait()
    end

    local function GetNextRoom(Number)
        while ForgetMeNotRunning do
            for RoomNumber = Number + 1, Number + 5 do
                local NextRoom = workspace.CurrentRooms:FindFirstChild(tostring(RoomNumber))
                if NextRoom then return NextRoom end
            end
            task.wait(0.1)
        end
        return nil
    end

    local function FireLookAts(Room)
        for i = 1, 6 do
            local Obj = Room:FindFirstChild(tostring(i))
            if Obj then
                local LookAt = Obj:FindFirstChild("LookAt")
                if LookAt then
                    pcall(function() LookAt:FireServer() end)
                end
            end
        end
    end

    local function Run(Room)
        if not ForgetMeNotRunning or ForgetMeNotProcessing[Room] then return end
        ForgetMeNotProcessing[Room] = true
        task.wait(2)
        if not ForgetMeNotRunning or not Room.Parent then ForgetMeNotProcessing[Room] = nil return end
        if not Room:FindFirstChild("ForgetMeNotVineDoors", true) then ForgetMeNotProcessing[Room] = nil return end
        FireLookAts(Room)

        local NextRoom = GetNextRoom(tonumber(Room.Name))
        if not NextRoom then ForgetMeNotProcessing[Room] = nil return end
        local Door = NextRoom:FindFirstChild("Door")
        if not Door then ForgetMeNotProcessing[Room] = nil return end
        if Door:GetAttribute("Opened") == true then ForgetMeNotProcessing[Room] = nil return end

        if not Room:FindFirstChild(game.Players.LocalPlayer.Name, true) then
            if not ForgetMeNotNotified[Room] then
                ForgetMeNotNotified[Room] = true
                Functions.Notify({Title = "Войдите в первую дверь Forget Me Not."})
            end
            repeat task.wait() until Room:FindFirstChild(game.Players.LocalPlayer.Name, true) or not ForgetMeNotRunning or not Room.Parent
            if not ForgetMeNotRunning or not Room.Parent then ForgetMeNotProcessing[Room] = nil return end
        end

        if not ForgetMeNotRunning or Door:GetAttribute("Opened") == true then ForgetMeNotProcessing[Room] = nil return end

        local Hidden = Door:WaitForChild("Hidden", 10)
        if not Hidden or not ForgetMeNotRunning or Door:GetAttribute("Opened") == true then ForgetMeNotProcessing[Room] = nil return end

        task.wait(3)
        if not ForgetMeNotRunning or not NextRoom.Parent or Door:GetAttribute("Opened") == true then ForgetMeNotProcessing[Room] = nil return end

        while ForgetMeNotRunning and NextRoom.Parent and Door:GetAttribute("Opened") ~= true do
            local Character = GetCharacter()
            if Character then
                if Hidden:IsA("BasePart") then Character:PivotTo(Hidden.CFrame)
                elseif Hidden:IsA("Model") then Character:PivotTo(Hidden:GetPivot()) end
            end
            pcall(function() Door.ClientOpen:Fire() end)
            pcall(function() Door.ClientOpen:FireServer() end)
            task.wait()
        end

        if ForgetMeNotRunning and Door:GetAttribute("Opened") == true then
            local Character = GetCharacter()
            if Character then
                for _ = 1, 4 do Character:PivotTo(CFrame.new(0, -120, 0)) end
                Functions.Notify({Title = "Если застряли в Forget Me Not, нажимайте «В пустоту» в разделе «Отладка»."})
            end
            ForgetMeNotNotified[Room] = nil
        end
        ForgetMeNotProcessing[Room] = nil
    end

    local function CheckRooms()
        local LatestRoomNumber = tonumber(LatestRoom.Value) or 0
        local FirstRoomNumber = math.max(0, LatestRoomNumber - 4)
        for RoomNumber = FirstRoomNumber, LatestRoomNumber do
            if not ForgetMeNotRunning then return end
            local Room = workspace.CurrentRooms:FindFirstChild(tostring(RoomNumber))
            if Room and not ForgetMeNotProcessing[Room] then task.spawn(Run, Room) end
        end
    end

    ForgetMeNotConnection = workspace.CurrentRooms.ChildAdded:Connect(function(Room)
        if not tonumber(Room.Name) then return end
        task.spawn(function()
            task.wait(2)
            if ForgetMeNotRunning and Room.Parent then task.spawn(Run, Room) end
        end)
    end)

    task.spawn(function()
        while ForgetMeNotRunning do CheckRooms() task.wait(2) end
    end)
    CheckRooms()
end)

Toggles.BypassWater:OnChanged(function(Value)
    Functions.Notify({Title = "Подмена позиции нарушит работу этой функции!"})
    if WaterBypassConnection then
        WaterBypassConnection:Disconnect()
        WaterBypassConnection = nil
    end
    if Value then
        local function ProcessWaterBypassRoom(WaterBypassRoom)
            if not tonumber(WaterBypassRoom.Name) then return end
            task.wait(3)
            local WaterBypassWater = WaterBypassRoom:FindFirstChild("Water")
            if not WaterBypassWater or WaterParts[WaterBypassWater] then return end

            local WaterBypassPart = Instance.new("Part")
            WaterBypassPart.Name = "WaterBypass"
            WaterBypassPart.Anchored = true
            WaterBypassPart.CanCollide = true
            WaterBypassPart.CanTouch = false
            WaterBypassPart.CanQuery = false
            WaterBypassPart.Transparency = 0.25
            WaterBypassPart.Color = Color3.fromRGB(0, 150, 255)
            WaterBypassPart.Material = Enum.Material.ForceField

            if WaterBypassWater:IsA("BasePart") then
                WaterBypassPart.Size = WaterBypassWater.Size + Vector3.new(0, 0.5, 0)
                WaterBypassPart.CFrame = WaterBypassWater.CFrame * CFrame.new(0, 0.25, 0)
            elseif WaterBypassWater:IsA("Model") then
                local WaterBypassCFrame, WaterBypassSize = WaterBypassWater:GetBoundingBox()
                WaterBypassPart.Size = WaterBypassSize + Vector3.new(0, 0.5, 0)
                WaterBypassPart.CFrame = WaterBypassCFrame * CFrame.new(0, 0.25, 0)
            else
                WaterBypassPart.Size = Vector3.new(10, 1.5, 10)
                WaterBypassPart.CFrame = WaterBypassWater:GetPivot() * CFrame.new(0, 0.25, 0)
            end

            if WaterBypassPart.Size.Y > 3 then
                WaterBypassPart:Destroy()
                Functions.Notify({Title = "Обход воды отключён: риск застревания."})
                return
            end

            WaterBypassPart.Parent = WaterBypassRoom
            WaterParts[WaterBypassWater] = WaterBypassPart
        end

        local WaterBypassLatestRoomNumber = tonumber(LatestRoom.Value) or 0
        for WaterBypassRoomNumber = math.max(0, WaterBypassLatestRoomNumber - 4), WaterBypassLatestRoomNumber do
            local WaterBypassRoom = workspace.CurrentRooms:FindFirstChild(tostring(WaterBypassRoomNumber))
            if WaterBypassRoom then task.spawn(ProcessWaterBypassRoom, WaterBypassRoom) end
        end

        WaterBypassConnection = workspace.CurrentRooms.ChildAdded:Connect(function(WaterBypassRoom)
            task.spawn(ProcessWaterBypassRoom, WaterBypassRoom)
        end)
    else
        for _, WaterBypassPart in pairs(WaterParts) do
            if WaterBypassPart then WaterBypassPart:Destroy() end
        end
        table.clear(WaterParts)
    end
end)

Toggles.BypassAlma:OnChanged(function(Value)
    if AlmaConnection then
        AlmaConnection:Disconnect()
        AlmaConnection = nil
    end
    if Value then
        for _, child in ipairs(workspace:GetChildren()) do
            if child.Name == "Alma" then child:Destroy() end
        end
        AlmaConnection = workspace.ChildAdded:Connect(function(child)
            if child.Name == "Alma" then child:Destroy() end
        end)
    end
end)

Toggles.AntiScribbles:OnChanged(function(Value)
    if AntiScribbles_Connection then
        AntiScribbles_Connection:Disconnect()
        AntiScribbles_Connection = nil
    end
    if not Value then return end
    AntiScribbles_Connection = workspace.ChildAdded:Connect(function(Child)
        if Child.Name == "Scribbles" and Toggles.AntiScribbles.Value then
            local ExploitSribbleWarning = Child:FindFirstChild("IfYoureExploitingDeleteThis")
            if ExploitSribbleWarning then ExploitSribbleWarning:Destroy() end
        end
    end)
end)

Toggles.BypassDrones:OnChanged(function(Value)
    local RS = game:GetService("ReplicatedStorage")
    local function ProcessDrones(drones)
        local WalkedInto = drones:FindFirstChild("WalkedInto") or drones:WaitForChild("WalkedInto", 3)
        if WalkedInto and not DroneWalkedIntoParents[WalkedInto] then
            DroneWalkedIntoParents[WalkedInto] = drones
            WalkedInto.Parent = RS
        end
    end
    if Value then
        for _, child in ipairs(workspace:GetChildren()) do
            if child.Name == "Drones" then ProcessDrones(child) end
        end
        if DroneConnection then DroneConnection:Disconnect() end
        DroneConnection = workspace.ChildAdded:Connect(function(child)
            if child.name == "Drones" then ProcessDrones(child) end
        end)
    else
        for WalkedInto, originalParent in pairs(DroneWalkedIntoParents) do
            if WalkedInto and WalkedInto.Parent and originalParent and originalParent.Parent then
                WalkedInto.Parent = originalParent
            end
        end
        table.clear(DroneWalkedIntoParents)
        if DroneConnection then DroneConnection:Disconnect() DroneConnection = nil end
    end
end)

-- ════════════════════════════════════════════════════════════════
-- EXPLOITS TAB — BYPASS RIGHT GROUPBOX
-- ════════════════════════════════════════════════════════════════
Groupboxes.Exploits_BypassRight = Tabs.Exploits:AddRightGroupbox("Обход")
Groupboxes.Exploits_BypassRight:AddToggle("DisableAnticheat", {
    Text = "Обход античита", Default = false,
    Tooltip = "Полностью отключает античит после взаимодействия с лестницей."
})
Groupboxes.Exploits_BypassRight:AddToggle("VelocityManipulationToggle", {
    Text = "Управление скоростью", Default = false,
    Tooltip = "Медленно перемещает персонажа вперёд, ослабляя защиту игры от прохода сквозь стены."
})
Toggles.DisableAnticheat:OnChanged(function(Value)
    if Globals.AnticheatDisabled == true and not Value then
        RemotesFolder.ClimbLadder:FireServer()
        Globals.AnticheatDisabled = false
    end
end)
Toggles.VelocityManipulationToggle:AddKeyPicker("VelocityManipulationKeybind", {
    Text = "Управление скоростью", Default = "V",
    Mode = Library.IsMobile and "Toggle" or "Hold", SyncToggleState = true
})
Groupboxes.Exploits_BypassRight:AddDropdown("VelocityManipulationMode", {
    Values = {"Velocity", "Pivot"}, Text = "Способ перемещения", Default = 1,
})

Groupboxes.Exploits_BypassRight:AddDivider()
Groupboxes.Exploits_BypassRight:AddToggle("InfiniteItemsToggle", {
    Text = "Бесконечные предметы", Default = false,
    Tooltip = "Позволяет использовать некоторые предметы без расходования зарядов.",
    Disabled = not Functions.CheckCompatability({"fireproximityprompt"}),
    DisabledTooltip = Globals.IncompatibleMessage
})
Groupboxes.Exploits_BypassRight:AddDropdown("InfiniteItemsList", {
    Text = "Список предметов",
    Values = { "Lockpicks", "Skeleton Key", "Shears", "Multitool" },
    Multi = true, AllowNull = true,
    Disabled = not Functions.CheckCompatability({"fireproximityprompt"}),
    DisabledTooltip = Globals.IncompatibleMessage
})

Groupboxes.Exploits_BypassRight:AddToggle("InfCrucifix", {
    Text = "Бесконечное распятие", Default = false,
    Tooltip = "Рискованно! Можно погибнуть или потерять распятие. Рекомендуются низкий пинг и стабильный FPS.",
})

local InfCrucifixDropTable = {
    RushMoving   = 54,
    AmbushMoving = 67,
    A60          = 70,
    GlitchRush   = 120,
    GlitchAmbush = 155,
    A120         = 75,
}

Toggles.InfCrucifix:OnChanged(function(Value)
    local InfCrucifixRaycastParams = RaycastParams.new()
    InfCrucifixRaycastParams.FilterType = Enum.RaycastFilterType.Blacklist

    local InfCrucifixConnection
    InfCrucifixConnection = RunService.RenderStepped:Connect(function()
        if not Toggles.InfCrucifix.Value then
            if InfCrucifixConnection then InfCrucifixConnection:Disconnect() end
            return
        end
        local InfCrucifixCharacter = game.Players.LocalPlayer
        if not InfCrucifixCharacter then return end
        local InfCrucifixCollision = InfCrucifixCharacter:FindFirstChild("CollisionPart")
        if not InfCrucifixCollision then return end
        InfCrucifixRaycastParams.FilterDescendantsInstances = {InfCrucifixCharacter}

        for _, InfCrucifixEntity in ipairs(Services.Workspace:GetChildren()) do
            local InfCrucifixMaxDistance = InfCrucifixDropTable[InfCrucifixEntity.Name]
            if not InfCrucifixMaxDistance or not InfCrucifixEntity.PrimaryPart then continue end
            InfCrucifixEntity.PrimaryPart.CanCollide = true
            InfCrucifixEntity.PrimaryPart.CanQuery = true

            local InfCrucifixOrigin = InfCrucifixCollision.Position
            local InfCrucifixDirection = InfCrucifixEntity.PrimaryPart.Position - InfCrucifixOrigin
            local InfCrucifixRayResult = Services.Workspace:Raycast(InfCrucifixOrigin, InfCrucifixDirection, InfCrucifixRaycastParams)
            if not InfCrucifixRayResult or not InfCrucifixRayResult.Instance:IsDescendantOf(InfCrucifixEntity) then continue end

            local InfCrucifixDistance = (InfCrucifixCollision.Position - InfCrucifixEntity.PrimaryPart.Position).Magnitude
            if InfCrucifixDistance >= InfCrucifixMaxDistance then continue end

            local InfCrucifixTool = InfCrucifixCharacter:FindFirstChildOfClass("Tool")
            if not InfCrucifixTool or InfCrucifixTool.Name ~= "Crucifix" then continue end

            task.spawn(function()
                Services.ReplicatedStorage.RemotesFolder.DropItem:FireServer(InfCrucifixTool)
                task.wait(0.54)
                local InfCrucifixDrops = Services.Workspace:FindFirstChild("Drops")
                if not InfCrucifixDrops then return end
                local InfCrucifixDropped = InfCrucifixDrops:FindFirstChild("Crucifix")
                if not InfCrucifixDropped then return end
                local InfCrucifixPrompt = InfCrucifixDropped:FindFirstChildOfClass("ProximityPrompt")
                if InfCrucifixPrompt then
                    FeatherHub.Environment.fireproximityprompt(InfCrucifixPrompt)
                end
            end)
            task.wait(0.6)
        end
    end)
end)

Groupboxes.Exploits_BypassRight:AddDivider()
Groupboxes.Exploits_BypassRight:AddToggle("PositionSpoof", {
    Text = "Подмена позиции", Default = false,
    Tooltip = "На сервере персонаж находится под землёй, что защищает от сущностей типа Rush."
})
Groupboxes.Exploits_BypassRight:AddToggle("CrouchSpoof", {
    Text = "Подмена приседания", Default = false, Tooltip = "Игра считает, что вы постоянно приседаете."
})
Toggles.PositionSpoof:OnChanged(function(Value)
    if Floor ~= "Fools" and Floor ~= "OldHotel" then
        if Value then
            RootPart.CFrame = RootPart.CFrame * CFrame.new(0, -2.346, 0)
            Humanoid.HipHeight = 0.05
            RemotesFolder.Crouch:FireServer(true, true)
        else
            RootPart.CFrame = RootPart.CFrame * CFrame.new(0, 2.346, 0)
            Humanoid.HipHeight = 2.396
        end
    end
end)
Toggles.PositionSpoof:AddKeyPicker("PositionSpoof", {
    Text = "Подмена позиции", Default = "B", Mode = "Toggle", SyncToggleState = true
})
Toggles.CrouchSpoof:OnChanged(function(Value)
    if RemotesFolder:FindFirstChild("Crouch") then
        RemotesFolder.Crouch:FireServer(Value and true or Functions.IsCrouching(), true)
    end
end)

-- ════════════════════════════════════════════════════════════════
-- EXPLOITS TAB — REMOVE GROUPBOX
-- ════════════════════════════════════════════════════════════════
Groupboxes.Exploits_Remove = Tabs.Exploits:AddRightGroupbox("Удаление")
Groupboxes.Exploits_Remove:AddToggle("RemoveScreech", { Text = "Удалить Screech",  Default = false, Tooltip = "Предотвращает появление Screech." })
Groupboxes.Exploits_Remove:AddToggle("RemoveHalt",    { Text = "Удалить Halt",     Default = false, Tooltip = "Предотвращает появление Halt." })
Groupboxes.Exploits_Remove:AddToggle("RemoveA90",     { Text = "Удалить A-90",     Default = false, Tooltip = "Предотвращает появление A-90." })
Groupboxes.Exploits_Remove:AddToggle("RemoveDread",   { Text = "Удалить Dread",    Default = false, Tooltip = "Предотвращает появление Dread." })
Groupboxes.Exploits_Remove:AddToggle("RemoveSurge", { Text = "Удалить Surge", Default = false, Tooltip = "Предотвращает появление Surge."})
Groupboxes.Exploits_Remove:AddDivider()
Groupboxes.Exploits_Remove:AddToggle("NoScreechDamage", { Text = "Без урона Screech", Default = false, Tooltip = "Защищает от урона Screech." })
Groupboxes.Exploits_Remove:AddToggle("NoHaltDamage",    { Text = "Без урона Halt",    Default = false, Tooltip = "Защищает от урона Halt." })
Groupboxes.Exploits_Remove:AddToggle("NoA90Damage",     { Text = "Без урона A-90",    Default = false, Tooltip = "Защищает от урона A-90." })
Groupboxes.Exploits_Remove:AddToggle("NoSurgeDamage",   { Text = "Без урона Surge",   Default = false, Tooltip = "Защищает от урона Surge." })

Toggles.NoScreechDamage:OnChanged(function(Value)
    if Value then
        FakeEvents.Screech.Parent = RemotesFolder
        FakeEvents.Screech_Real.Parent = nil
    else
        FakeEvents.Screech_Real.Parent = RemotesFolder
        FakeEvents.Screech.Parent = nil
    end
end)
Toggles.NoHaltDamage:OnChanged(function(Value)
    if Value then
        FakeEvents.Shade.Parent = RemotesFolder
        FakeEvents.Shade_Real.Parent = nil
    else
        FakeEvents.Shade_Real.Parent = RemotesFolder
        FakeEvents.Shade.Parent = nil
    end
end)
Toggles.NoA90Damage:OnChanged(function(Value)
    if RemotesFolder:FindFirstChild("A90") then
        if Value then
            FakeEvents.A90.Parent = RemotesFolder
            FakeEvents.A90_Real.Parent = nil
        else
            FakeEvents.A90_Real.Parent = RemotesFolder
            FakeEvents.A90.Parent = nil
        end
    end
end)
Toggles.NoSurgeDamage:OnChanged(function(Value)
    if RemotesFolder:FindFirstChild("SurgeRemote") then
        if Value then
            FakeEvents.Surge.Parent = RemotesFolder
            FakeEvents.Surge_Real.Parent = nil
        else
            FakeEvents.Surge_Real.Parent = RemotesFolder
            FakeEvents.Surge.Parent = nil
        end
    end
end)

local Modules = {}

Toggles.RemoveScreech:OnChanged(function(Value)
    if Value then
        task.spawn(function()
            while Toggles.RemoveScreech.Value do
                local Camera = workspace:FindFirstChild("Camera")
                if Camera then
                    local Screech = Camera:FindFirstChild("Screech")
                    if Screech then Screech:Destroy() end
                end
                task.wait()
            end
        end)
    end
end)
Toggles.RemoveHalt:OnChanged(function(Value)
    Modules.Shade.Name = Value and "Shade_Disabled" or "Shade"
end)
Toggles.RemoveA90:OnChanged(function(Value)
    if Modules.A90 then Modules.A90.Name = Value and "A90_Disabled" or "A90" end
end)
Toggles.RemoveDread:OnChanged(function(Value)
    if Modules.Dread then Modules.Dread.Name = Value and "Dread_Disabled" or "Dread" end
end)
Toggles.RemoveSurge:OnChanged(function(Value)
    if Globals.SurgeFrame then
        Globals.SurgeFrame.Name = (Value and "SurgeVignette_Disabled" or "SurgeVignette")
    end
end)

-- ════════════════════════════════════════════════════════════════
-- EXPLOITS TAB — AUDIO GROUPBOX
-- ════════════════════════════════════════════════════════════════
Groupboxes.Exploits_Audio = Tabs.Exploits:AddLeftGroupbox("Звук")
Globals.JamMuffle = Services.SoundService:WaitForChild("Main"):FindFirstChild("Jamming") or Instance.new("EqualizerSoundEffect")

Groupboxes.Exploits_Audio:AddToggle("RemoveFootstepSounds",    { Text = "Без звуков шагов",    Default = false, Tooltip = "Убирает звуки ходьбы." })
Groupboxes.Exploits_Audio:AddToggle("RemoveJamminMusic",       { Text = "Без музыки Jammin",       Default = false, Tooltip = "Убирает музыку и приглушение от модификатора Jammin." })
Groupboxes.Exploits_Audio:AddToggle("RemoveInteractingSounds", { Text = "Без звуков взаимодействия", Default = false, Tooltip = "Убирает звуки взаимодействия с объектами." })

Toggles.RemoveJamminMusic:OnChanged(function(Value)
    local Jam = Globals.MainUI.Initiator.Main_Game.Health:FindFirstChild("Jam")
    if Jam then
        Jam.Volume = Value and 0 or 0.45
        Globals.JamMuffle.Enabled = LiveModifiers:FindFirstChild("Jammin") and not Value or false
    end
end)
Toggles.RemoveInteractingSounds:OnChanged(function(Value)
    local PS = Globals.MainUI.Initiator.Main_Game.PromptService
    PS.Triggered.Volume   = Value and 0 or 0.04
    PS.Holding.Volume     = Value and 0 or 0.1
    PS.Notification.Volume = Value and 0 or 0.03
    Globals.MainUI.Initiator.Main_Game.Reminder.Caption.Volume = Value and 0 or 0.1
end)

-- ════════════════════════════════════════════════════════════════
-- VISUALS TAB — CAMERA / EFFECTS
-- ════════════════════════════════════════════════════════════════
Groupboxes.Visuals_LeftTab = Tabs.Visuals:AddLeftTabbox(L and "Камера / Эффекты" or "Camera / Effects")
Groupboxes.Visuals_Camera = Groupboxes.Visuals_LeftTab:AddTab(L and "Камера" or "Camera")
Groupboxes.Visuals_Camera:AddToggle("AmbientToggle", { Text = "Окружающее освещение", Default = false, Tooltip = "Меняет цвет освещения на указанный." })
Groupboxes.Visuals_Camera:AddSlider("FieldOfView", { Text = "Угол обзора", Min = 1, Max = 120, Default = 70, Rounding = 0 })
Groupboxes.Visuals_Camera:AddToggle("FOVToggle", { Text = "Свой угол обзора", Default = false, Tooltip = "Применяет настройку угла обзора только при включении." })
Toggles.FOVToggle:AddKeyPicker("FovToggle", {Text = "Свой угол обзора", Default = "O", Mode = "Toggle", SyncToggleState = true})
Groupboxes.Visuals_Camera:AddDivider()
Groupboxes.Visuals_Camera:AddToggle("RemoveCameraShake", {
    Text = "Без тряски камеры", Default = false, Tooltip = "Убирает тряску камеры.",
    Disabled = not Functions.CheckCompatability({"require"}), DisabledTooltip = Globals.IncompatibleMessage
})
Groupboxes.Visuals_Camera:AddToggle("RemoveCameraBobbing", {
    Text = "Без покачивания камеры", Default = false, Tooltip = "Убирает покачивание камеры при движении.",
    Disabled = not Functions.CheckCompatability({"require"}), DisabledTooltip = Globals.IncompatibleMessage
})
Groupboxes.Visuals_Camera:AddToggle("RemoveCutscenes", { Text = "Без кат-сцен", Default = false, Tooltip = "Убирает необязательные кат-сцены." })
Groupboxes.Visuals_Camera:AddToggle("RemoveCameraFog", { Text = "Без тумана", Default = false, Tooltip = "Убирает эффекты тумана с камеры." })
Groupboxes.Visuals_Camera:AddDivider()
Groupboxes.Visuals_Camera:AddToggle("ThirdPersonToggle", { Text = "Вид от третьего лица", Default = false, Tooltip = "Отдаляет камеру, позволяя видеть персонажа со спины." })
Toggles.ThirdPersonToggle:AddKeyPicker("ThirdPersonKeybind", { Text = "Вид от третьего лица", Default = "T", Mode = "Toggle", SyncToggleState = true })
Groupboxes.Visuals_Camera:AddSlider("ThirdPersonOffsetX", { Text = "Смещение X", Min = -10, Max = 10, Default = 1.5, Rounding = 1, Compact = true })
Groupboxes.Visuals_Camera:AddSlider("ThirdPersonOffsetY", { Text = "Смещение Y", Min = -10, Max = 10, Default = 1,   Rounding = 1, Compact = true })
Groupboxes.Visuals_Camera:AddSlider("ThirdPersonOffsetZ", { Text = "Смещение Z", Min = -10, Max = 10, Default = 5,   Rounding = 1, Compact = true })
Groupboxes.Visuals_Camera:AddToggle("ThirdPersonWallCheck", { Text = "Проверка стен", Default = false, Tooltip = "Не даёт камере от третьего лица проходить сквозь стены." })
Groupboxes.Visuals_Camera:AddDivider()
Groupboxes.Visuals_Camera:AddToggle("ViewmodelOffsetToggle", {
    Text = "Смещение модели рук", Default = false, Tooltip = "Меняет положение модели рук при удержании предмета.",
    Disabled = not Functions.CheckCompatability({"require"}), DisabledTooltip = Globals.IncompatibleMessage
})
Groupboxes.Visuals_Camera:AddSlider("ViewmodelOffsetX", { Text = "Смещение X", Min = -10, Max = 10, Default = 0, Rounding = 1, Compact = true, Disabled = not Functions.CheckCompatability({"require"}), DisabledTooltip = Globals.IncompatibleMessage })
Groupboxes.Visuals_Camera:AddSlider("ViewmodelOffsetY", { Text = "Смещение Y", Min = -10, Max = 10, Default = 0, Rounding = 1, Compact = true, Disabled = not Functions.CheckCompatability({"require"}), DisabledTooltip = Globals.IncompatibleMessage })
Groupboxes.Visuals_Camera:AddSlider("ViewmodelOffsetZ", { Text = "Смещение Z", Min = -10, Max = 10, Default = 0, Rounding = 1, Compact = true, Disabled = not Functions.CheckCompatability({"require"}), DisabledTooltip = Globals.IncompatibleMessage })

Toggles.AmbientToggle:AddColorPicker("AmbientColor", { Text = "Окружающее освещение", Default = Color3.fromRGB(255, 255, 255), Transparency = 0 })
Toggles.AmbientToggle:OnChanged(function(Value)
    local OldAmbient = CurrentRooms:FindFirstChild(tostring(LocalPlayer:GetAttribute("CurrentRoom"))):GetAttribute("Ambient")
    Services.TweenService:Create(Services.Lighting, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {
        Ambient = Value and Options.AmbientColor.Value or OldAmbient
    }):Play()
end)

local Main_Game
local ClientModules

Toggles.RemoveCameraBobbing:OnChanged(function(Value)
    if Main_Game then Main_Game.spring.Speed = Value and 9e9 or 8 end
end)
Toggles.RemoveCameraFog:OnChanged(function(Value)
    Services.Lighting.FogEnd = Value and 10000000 or Globals.OldFog
    for _, Object in Globals.FogInstances do
        Object.Density = Value and 0 or Object:GetAttribute("Density_Old")
    end
end)
Toggles.RemoveCutscenes:OnChanged(function(Value)
    local Cutscenes = Globals.MainUI.Initiator.Main_Game.RemoteListener.Cutscenes
    for _, Object in pairs(Cutscenes:GetChildren()) do
        if table.find(CutsceneNames, Object.Name) and Object:IsA("ModuleScript") or table.find(CutsceneNames, Object:GetAttribute("OriginalName")) and Object:IsA("ModuleScript") then
            Object.Name = (Value and Object.Name .. "_Disabled" or Object:GetAttribute("OriginalName"))
        end
    end
    for _, Object in pairs(FloorReplicated:GetChildren()) do
        if table.find(CutsceneNames, Object.Name) and Object:IsA("ModuleScript") or table.find(CutsceneNames, Object:GetAttribute("OriginalName")) and Object:IsA("ModuleScript") then
            Object.Name = (Value and Object.Name .. "_Disabled" or Object:GetAttribute("OriginalName"))
        end
    end
end)

-- ════════════════════════════════════════════════════════════════
-- VISUALS TAB — EFFECTS
-- ════════════════════════════════════════════════════════════════
Groupboxes.Visuals_Effects = Groupboxes.Visuals_LeftTab:AddTab(L and "Эффекты" or "Effects")
Groupboxes.Visuals_Effects:AddToggle("TransparentHidingSpotsToggle", { Text = "Прозрачные укрытия", Default = false, Tooltip = "Делает укрытие прозрачным, когда вы в него входите." })
Groupboxes.Visuals_Effects:AddSlider("TransparentHidingSpotsSlider", { Text = "Прозрачность", Min = 0, Max = 1, Default = 0.5, Rounding = 2, Compact = true })

local function ApplyHidingTransparency(Value, SliderValue)
    for _, Object in Objects.HidingSpots do
        local IsHiding = false
        for _, Child in Object:GetDescendants() do
            if Child.Name == "HiddenPlayer" and Child.Value == Character then
                IsHiding = true break
            end
        end
        for _, Part in Object:GetDescendants() do
            if Part:IsA("BasePart") and Part:GetAttribute("Transparency_Old") then
                Services.TweenService:Create(Part, TweenInfo.new(0.25, Enum.EasingStyle.Linear), {
                    Transparency = (Value and IsHiding) and SliderValue or Part:GetAttribute("Transparency_Old")
                }):Play()
            end
        end
    end
end

Toggles.TransparentHidingSpotsToggle:OnChanged(function(Value)
    ApplyHidingTransparency(Value, Options.TransparentHidingSpotsSlider.Value)
end)
Options.TransparentHidingSpotsSlider:OnChanged(function(Value)
    ApplyHidingTransparency(Toggles.TransparentHidingSpotsToggle.Value, Value)
end)

Groupboxes.Visuals_Effects:AddDivider()
Groupboxes.Visuals_Effects:AddToggle("DisableGlitchJumpscare",   { Text = "Без скримера Glitch",   Default = false, Tooltip = "Отключает скример Glitch." })
Groupboxes.Visuals_Effects:AddToggle("DisableTimothyJumpscare",  { Text = "Без скримера Timothy",  Default = false, Tooltip = "Отключает скример Timothy." })
Groupboxes.Visuals_Effects:AddToggle("DisableVoidJumpscare",     { Text = "Без скримера Void",     Default = false, Tooltip = "Отключает скример Void." })
Groupboxes.Visuals_Effects:AddDivider()
Groupboxes.Visuals_Effects:AddToggle("DisableHideVignette",      { Text = "Без затемнения в укрытии",      Default = false, Tooltip = "Отключает экранный эффект при укрытии." })
Groupboxes.Visuals_Effects:AddToggle("DisableFiredampEffect",    { Text = "Без эффекта рудничного газа",    Default = false, Tooltip = "Отключает экранный эффект рудничного газа." })
Groupboxes.Visuals_Effects:AddToggle("DisableEntityJumpscares",  { Text = "Без скримеров сущностей",  Default = false, Tooltip = "Отключает скримеры сущностей вроде Rush и Ambush." })

Toggles.DisableGlitchJumpscare:OnChanged(function(Value)
    Modules.Glitch.Name = Value and "Glitch_Disabled" or "Glitch"
end)
Toggles.DisableTimothyJumpscare:OnChanged(function(Value)
    Modules.SpiderJumpscare.Name = Value and "SpiderJumpscare_Disabled" or "SpiderJumpscare"
end)
Toggles.DisableVoidJumpscare:OnChanged(function(Value)
    if Modules.Void then Modules.Void.Name = Value and "Void_Disabled" or "Void" end
end)
Toggles.DisableHideVignette:OnChanged(function(Value)
    local Vignette = Globals.MainUI:FindFirstChild("HideVignette") or Globals.MainUI.MainFrame:FindFirstChild("HideVignette")
    if Vignette then Vignette.Image = Value and "Disabled" or "rbxassetid://6100076320" end
end)
Toggles.DisableFiredampEffect:OnChanged(function(Value)
    for _, Object in CurrentRooms:GetChildren() do
        if Value then
            Object:SetAttribute("Firedamp", false)
            for _, FiredampObj in Camera:GetChildren() do
                if FiredampObj.Name == "LiveFiredamp" then FiredampObj:Destroy() end
            end
        else
            Object:SetAttribute("Firedamp", Object:GetAttribute("Firedamp_Old"))
        end
    end
    local Old = LocalPlayer:GetAttribute("CurrentRoom")
    LocalPlayer:SetAttribute("CurrentRoom", 0)
    task.wait()
    LocalPlayer:SetAttribute("CurrentRoom", Old)
end)
Toggles.DisableEntityJumpscares:OnChanged(function(Value)
    local Jumpscares = Globals.MainUI.Initiator.Main_Game.RemoteListener:FindFirstChild("Jumpscares")
        or Globals.MainUI.Initiator.Main_Game.RemoteListener:FindFirstChild("Jumpscares_Disabled")
    if Jumpscares then
        Jumpscares.Name = Value and "Jumpscares_Disabled" or "Jumpscares"
        for _, Object in Objects.JumpscareModules do
            Object.Name = Value and (Object:GetAttribute("OriginalName") .. "_Disabled") or Object:GetAttribute("OriginalName")
        end
    end
end)
-- ════════════════════════════════════════════════════════════════
-- PART 4: Visuals ESP/Entities, Floors Tab, Main Handlers Start
-- ════════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════════════════════════
-- VISUALS TAB — ENTITIES / SETTINGS
-- ════════════════════════════════════════════════════════════════
Groupboxes.Visuals_RightTab         = Tabs.Visuals:AddRightTabbox(L and "Сущности / Настройки" or "Entities / Settings")
Groupboxes.Visuals_Entities         = Groupboxes.Visuals_RightTab:AddTab(L and "Сущности" or "Entities")
Groupboxes.Visuals_EntitySettings   = Groupboxes.Visuals_RightTab:AddTab(L and "Настройки" or "Settings")

Groupboxes.Visuals_Entities:AddDropdown("EntityList", {
    Text = "Список сущностей",
    Values = { "Rush","Bash","Scribbles","Teller","DronesStampede","Ambush","Eyes","Halt","Blitz","Lookman","Gloombat Swarm","A-60","A-120","Sally","Jeff the Killer","Groundskeeper","Monument","AR0xMBUSH","RNIUSHCG==" },
    Multi = true, AllowNull = true
})
Groupboxes.Visuals_Entities:AddToggle("NotifyEntities",    { Text = "Уведомлять о сущностях",    Default = false, Tooltip = "Уведомляет о появлении сущности." })
Groupboxes.Visuals_Entities:AddDivider()

local ItemsToNotify = {}
for Index, Name in pairs(ItemNames) do
    if not table.find(ItemsToNotify, Name) then table.insert(ItemsToNotify, Name) end
end
table.sort(ItemsToNotify)

Groupboxes.Visuals_Entities:AddDropdown("NotifyItemList", {
    Text = "Список предметов", Values = ItemsToNotify, Multi = true, AllowNull = true
})
Groupboxes.Visuals_Entities:AddToggle("NotifyItemsToggle",          { Text = "Уведомлять о предметах",    Default = false, Tooltip = "Уведомляет о появлении предмета." })
Groupboxes.Visuals_Entities:AddToggle("NotifyItemsShowDistance",    { Text = "Показать расстояние",    Default = false, Tooltip = "Показывает расстояние до предмета в уведомлении." })
Groupboxes.Visuals_Entities:AddDivider()
Groupboxes.Visuals_Entities:AddToggle("NotifyLibraryCode", { Text = "Уведомлять о коде библиотеки", Default = false, Tooltip = "Автоматически определяет код замка библиотеки." })
Groupboxes.Visuals_Entities:AddToggle("NotifyOxygen",      { Text = "Уведомлять об уровне кислорода", Default = false, Tooltip = "Показывает оставшийся кислород." })
Groupboxes.Visuals_Entities:AddToggle("NotifyHasteTime",   { Text = "Уведомлять о таймере Haste",   Default = false, Tooltip = "Показывает время до появления Haste." })

Globals.LibraryCodeFound = false
Toggles.NotifyLibraryCode:OnChanged(function(Value)
    if Value then
        local Code = Functions.GetLibraryCode()
        if Code and not Code:find("_") and not Globals.LibraryCodeFound and CurrentRooms:FindFirstChild("50") then
            local Lock = Services.Workspace:FindFirstChild("Padlock", true)
            Functions.Notify({ Title = "Код замка найден!", Body = "Код: '" .. Code .. "'", Time = Toggles.NotifyKeepNotifications.Value and Lock or 15 })
            Globals.LibraryCodeFound = true
        end
    end
end)

Groupboxes.Visuals_EntitySettings:AddToggle("EntityChatToggle", { Text = "Уведомлять в чате", Default = false, Tooltip = "Отправляет сообщение в чат при появлении сущности." })
Groupboxes.Visuals_EntitySettings:AddInput("EntityChatMessage", { Text = "Сообщение", Default = "появился!", Numeric = false, Placeholder = "Сообщение" })
Groupboxes.Visuals_EntitySettings:AddDivider()
Groupboxes.Visuals_EntitySettings:AddDropdown("NotifyStyle", { Text = "Стиль уведомлений", Values = { "RushHub", "Doors", "STX", "Library" }, Default = 1 })
Groupboxes.Visuals_EntitySettings:AddSlider("NotifySoundVolume", { Text = "Громкость звука", Min = 0, Max = 10, Default = 3, Rounding = 1 })
Groupboxes.Visuals_EntitySettings:AddToggle("NotifyPlaySound", { Text = "Воспроизводить звук", Default = true, Tooltip = "Воспроизводит звуковой сигнал при уведомлении." })
Groupboxes.Visuals_EntitySettings:AddToggle("NotifyKeepNotifications", { Text = "Сохранять уведомления", Default = false, Tooltip = "Некоторые уведомления остаются на экране, пока актуальны." })
Groupboxes.Visuals_EntitySettings:AddButton({ Text = "Проверить уведомления", DoubleClick = false, Tooltip = "Отправляет тестовое уведомление.", Func = function()
    Functions.Notify({Title = "Это тестовое уведомление."})
end})

-- ════════════════════════════════════════════════════════════════
-- VISUALS TAB — ESP / SETTINGS
-- ════════════════════════════════════════════════════════════════
Groupboxes.Visuals_ESP          = Tabs.Visuals:AddRightTabbox(L and "ESP / Настройки" or "ESP / Settings")
Groupboxes.Visuals_ESP_Toggles  = Groupboxes.Visuals_ESP:AddTab("ESP")
Groupboxes.Visuals_ESP_Settings = Groupboxes.Visuals_ESP:AddTab(L and "Настройки" or "Settings")

Groupboxes.Visuals_ESP_Toggles:AddToggle("ObjectiveESPToggle", { Text = "Цели", Default = false, Tooltip = "Подсвечивает объекты, необходимые для прохождения." })
Toggles.ObjectiveESPToggle:AddColorPicker("ObjectiveESPColor", { Text = "Цели", Default = Color3.fromRGB(0, 255, 0), Transparency = 0 })

local ObjectiveLabels = {
    ["Cellar"] = "Подвал", ["ArchivesFihTank"] = "Аквариум Fih", ["KeyObtain"] = "Ключ от двери",
    ["ElectricalKeyObtain"] = "Электрический ключ", ["MinesGenerator"] = "Генератор",
    ["FuseObtain"] = "Предохранитель генератора", ["LiveHintBook"] = "Книга-подсказка",
    ["LiveBreakerPolePickup"] = "Выключатель электрощита", ["LibraryHintPaper"] = "Лист-подсказка",
    ["PickupItem"] = "Лист-подсказка", ["CringlePresent"] = "Подарок",
    ["LeverForGate"] = "Рычаг ворот", ["MinesGateButton"] = "Кнопка ворот",
    ["GardenGateButton"] = "Кнопка ворот",
}

Toggles.ObjectiveESPToggle:OnChanged(function(Value)
    for _, Object in Objects.Objectives do
        if Value then
            local Label = ObjectiveLabels[Object.Name]
            if Object.Name == "TimerLever" then
                Label = "Рычаг времени [+" .. Object:GetAttribute("AddTime") .. " с]"
            elseif Object.Name == "MinesAnchor" then
                Label = "Якорь [" .. Object:WaitForChild("Sign").TextLabel.Text .. "]"
            elseif Object.Name == "WaterPump" then
                Functions.AddESP({ Object = Object.Wheel, Text = "Водяной насос", Color = Options.ObjectiveESPColor.Value }, true)
            elseif Object.Name == "VineGuillotine" then
                Functions.AddESP({ Object = Object.Lever, Text = "Рычаг лозы", Color = Options.ObjectiveESPColor.Value }, true)
            end
            if Label then
                Functions.AddESP({ Object = Object, Text = Interface.Localization.TranslateText(Label), Color = Options.ObjectiveESPColor.Value }, true)
            end
        else
            Functions.RemoveESP(Object)
        end
    end
end)
Options.ObjectiveESPColor:OnChanged(function(Value)
    for _, Object in Objects.Objectives do FeatherHub.ESPLibrary:UpdateObjectColor(Object, Value) end
end)

Groupboxes.Visuals_ESP_Toggles:AddToggle("DoorESPToggle",       { Text = "Двери",        Default = false, Tooltip = "Подсвечивает следующую дверь." })
Groupboxes.Visuals_ESP_Toggles:AddToggle("HidingSpotESPToggle", { Text = "Укрытия", Default = false, Tooltip = "Подсвечивает места, где можно спрятаться от сущностей." })
Groupboxes.Visuals_ESP_Toggles:AddToggle("PlayerESPToggle",     { Text = "Игроки",      Default = false, Tooltip = "Подсвечивает других игроков." })
Groupboxes.Visuals_ESP_Toggles:AddToggle("ChestESPToggle",      { Text = "Сундуки",       Default = false, Tooltip = "Подсвечивает объекты, в которых может быть добыча." })
Groupboxes.Visuals_ESP_Toggles:AddToggle("ItemESPToggle",       { Text = "Предметы",        Default = false, Tooltip = "Подсвечивает все подбираемые предметы и расходники." })
Groupboxes.Visuals_ESP_Toggles:AddToggle("CurrencyESPToggle",   { Text = "Валюта",     Default = false, Tooltip = "Подсвечивает появляющуюся валюту." })
Groupboxes.Visuals_ESP_Toggles:AddToggle("LadderESPToggle",     { Text = "Лестницы",      Default = false, Tooltip = "Подсвечивает лестницы, позволяющие отключить античит." })
Groupboxes.Visuals_ESP_Toggles:AddDivider()
Groupboxes.Visuals_ESP_Toggles:AddDropdown("EntityESPOptions", {
    Text = "Список сущностей",
    Values = { "Rush","Bash","Scribbles","Teller","DronesStampede","Ambush","Eyes","Dupe","Figure","Blitz","Lookman","Snare","Giggle","Gloombat Eggs","Grumble","A-60","A-120","Sally","Jeff the Killer","Groundskeeper","Mandrake Hole","Monument","Bramble","AR0xMBUSH","RNIUSHCG==" },
    Multi = true, AllowNull = true
})
Groupboxes.Visuals_ESP_Toggles:AddToggle("EntityESPToggle",     { Text = "Сущности",      Default = false, Tooltip = "Подсвечивает появляющиеся сущности." })

Toggles.DoorESPToggle:AddColorPicker("DoorESPColor",           { Text = "Двери",        Default = Color3.fromRGB(0, 200, 255),  Transparency = 0 })
Toggles.HidingSpotESPToggle:AddColorPicker("HidingSpotESPColor", { Text = "Укрытия", Default = Color3.fromRGB(255, 170, 0),  Transparency = 0 })
Toggles.PlayerESPToggle:AddColorPicker("PlayerESPColor",       { Text = "Игроки",      Default = Color3.fromRGB(255, 255, 255), Transparency = 0 })
Toggles.ChestESPToggle:AddColorPicker("ChestESPColor",         { Text = "Сундуки",       Default = Color3.fromRGB(255, 255, 0),   Transparency = 0 })
Toggles.ItemESPToggle:AddColorPicker("ItemESPColor",           { Text = "Предметы",        Default = Color3.fromRGB(170, 0, 255),   Transparency = 0 })
Toggles.CurrencyESPToggle:AddColorPicker("CurrencyESPColor",   { Text = "Валюта",     Default = Color3.fromRGB(255, 255, 0),   Transparency = 0 })
Toggles.LadderESPToggle:AddColorPicker("LadderESPColor",       { Text = "Лестницы",      Default = Color3.fromRGB(255, 255, 255), Transparency = 0 })
Toggles.EntityESPToggle:AddColorPicker("EntityESPColor",       { Text = "Сущности",     Default = Color3.fromRGB(255, 0, 0),     Transparency = 0 })

local HidingSpotLabels = {
    Wardrobe = "Шкаф", ["Backdoor_Wardrobe"] = "Шкаф", Toolshed = "Шкаф",
    RetroWardrobe = "Шкаф", ["Wardrobe-FOOLS26"] = "Шкаф",
    Locker_Large = "Шкафчик", Rooms_Locker = "Укрытие", Rooms_Locker_Fridge = "Шкафчик",
    Bed = "Кровать", Double_Bed = "Двуспальная кровать", CircularVent = "Вентиляция", Dumpster = "Мусорный контейнер"
}
local ChestLabels = {
    ChestBox = true, ChestBoxLocked = true, Toolbox = true, Toolbox_Locked = true,
    Chest_Vine = "Сундук с лозой", Toolshed_Small = "Сарай", Locker_Small_Locked = "Запертый шкафчик с предметами", MouseHole = "Мышиная нора"
}
local EntityESPLabels = {
    JeffTheKiller = "Jeff the Killer", GiggleCeiling = "Giggle",
    Snare = "Snare", GrumbleRig = "Grumble",
    Drakobloxxer = "Drakobloxxer", Hole = "Mandrake Hole", Groundskeeper = "Groundskeeper",
    LiveEntityBramble = "Bramble", Figure = "Figure", FigureRig = "Figure", FigureRagdoll = "Figure",
    FakeDoor = "Dupe", DoorFake = "Dupe"
}
local NodeEntities = {
    Rush = true, Bash = true, Scribbles = true, DronesStampede = true, Ambush = true, Eyes = true,
    Blitz = true, Lookman = true, ["A-60"] = true, ["A-120"] = true, Sally = true,
    ["Jeff The Killer"] = true, Monument = true, ["AR0xMBUSH"] = true, ["RNIUSHCG=="] = true
}

Toggles.DoorESPToggle:OnChanged(function(Value)
    for _, Object in Objects.Doors do
        if Value then Functions.AddESP({ Object = Object, Text = "Дверь " .. Functions.GetDoorNumber(Object), Color = Options.DoorESPColor.Value }, true)
        else Functions.RemoveESP(Object) end
    end
end)
Options.DoorESPColor:OnChanged(function(Value)
    for _, Object in Objects.Doors do FeatherHub.ESPLibrary:UpdateObjectColor(Object, Value) end
end)

Toggles.HidingSpotESPToggle:OnChanged(function(Value)
    for _, Object in Objects.HidingSpots do
        local Label = HidingSpotLabels[Object.Name]
        if Value and Label then Functions.AddESP({ Object = Object, Text = Interface.Localization.TranslateText(Label), Color = Options.HidingSpotESPColor.Value }, true)
        elseif not Value then Functions.RemoveESP(Object) end
    end
end)
Options.HidingSpotESPColor:OnChanged(function(Value)
    for _, Object in Objects.HidingSpots do FeatherHub.ESPLibrary:UpdateObjectColor(Object, Value) end
end)

Toggles.PlayerESPToggle:OnChanged(function(Value)
    task.wait()
    for _, Player in Services.Players:GetPlayers() do
        if Player.Character and Player ~= LocalPlayer then
            if Value and Player:GetAttribute("Alive") == true then
                Functions.AddESP({ Object = Player.Character, Text = Player.Name, Color = Options.PlayerESPColor.Value })
            else
                Functions.RemoveESP(Player.Character)
            end
        end
    end
end)
Options.PlayerESPColor:OnChanged(function(Value)
    for _, Player in Services.Players:GetPlayers() do
        if Player.Character and Player ~= LocalPlayer then
            FeatherHub.ESPLibrary:UpdateObjectColor(Player.Character, Value)
        end
    end
end)

Toggles.ChestESPToggle:OnChanged(function(Value)
    for _, Object in Objects.Chests do
        if Value then
            local Label
            if Object.Name == "ChestBox" or Object.Name == "ChestBoxLocked" then
                Label = Object:GetAttribute("Locked") and "Запертый сундук" or "Сундук"
            elseif Object.Name == "Toolbox" or Object.Name == "Toolbox_Locked" then
                Label = Object:GetAttribute("Locked") and "Запертый ящик с инструментами" or "Ящик с инструментами"
            elseif ChestLabels[Object.Name] and ChestLabels[Object.Name] ~= true then
                Label = ChestLabels[Object.Name]
            end
            if Label then Functions.AddESP({ Object = Object, Text = Interface.Localization.TranslateText(Label), Color = Options.ChestESPColor.Value }, true) end
        else
            Functions.RemoveESP(Object)
        end
    end
end)
Options.ChestESPColor:OnChanged(function(Value)
    for _, Object in Objects.Chests do FeatherHub.ESPLibrary:UpdateObjectColor(Object, Value) end
end)

Toggles.ItemESPToggle:OnChanged(function(Value)
    for _, Object in Objects.Items do
        if Value then
            local Label = ItemNames[Object.Name] or (Object.Name == "Green_Herb" and "Зелёная трава")
            if Label then
                Functions.AddESP({ Object = Object, Text = Interface.Localization.TranslateText(Label), Color = Options.ItemESPColor.Value }, Object:GetAttribute("ParentRoom") ~= nil)
            end
        else
            Functions.RemoveESP(Object)
        end
    end
end)
Options.ItemESPColor:OnChanged(function(Value)
    for _, Object in Objects.Items do FeatherHub.ESPLibrary:UpdateObjectColor(Object, Value) end
end)

Toggles.CurrencyESPToggle:OnChanged(function(Value)
    for _, Object in Objects.Currency do
        if Value then
            local Label
            if Object.Name == "GoldPile" and Object:GetAttribute("GoldValue") then
                Label = "Куча золота [" .. Object:GetAttribute("GoldValue") .. "]"
            elseif Object.Name == "StardustPickup" then
                Label = "Куча звёздной пыли"
            end
            if Label then Functions.AddESP({ Object = Object, Text = Interface.Localization.TranslateText(Label), Color = Options.CurrencyESPColor.Value }, true) end
        else
            Functions.RemoveESP(Object)
        end
    end
end)
Options.CurrencyESPColor:OnChanged(function(Value)
    for _, Object in Objects.Currency do FeatherHub.ESPLibrary:UpdateObjectColor(Object, Value) end
end)

Toggles.EntityESPToggle:OnChanged(function(Value)
    for _, Object in Objects.Entities do
        if Value then
            local Label = EntityESPLabels[Object.Name]
            if not Label and Entities[Object.Name] then Label = Entities[Object.Name].Alias end
            if Label and Options.EntityESPOptions.Value[Label] then
                Functions.AddESP({ Object = Object, Text = Interface.Localization.TranslateText(Label), Color = Options.EntityESPColor.Value }, NodeEntities[Label] ~= true)
            else
                Functions.RemoveESP(Object)
            end
        else
            Functions.RemoveESP(Object)
        end
    end
end)
Options.EntityESPOptions:OnChanged(function(Value)
    for _, Object in Objects.Entities do
        if Toggles.EntityESPToggle.Value then
            local Label = EntityESPLabels[Object.Name]
            if not Label and Entities[Object.Name] then Label = Entities[Object.Name].Alias end
            if Label and Options.EntityESPOptions.Value[Label] then
                Functions.AddESP({ Object = Object, Text = Interface.Localization.TranslateText(Label), Color = Options.EntityESPColor.Value }, NodeEntities[Label] ~= true)
            else
                Functions.RemoveESP(Object)
            end
        else
            Functions.RemoveESP(Object)
        end
    end
end)
Options.EntityESPColor:OnChanged(function(Value)
    for _, Object in Objects.Entities do FeatherHub.ESPLibrary:UpdateObjectColor(Object, Value) end
end)

Toggles.LadderESPToggle:OnChanged(function(Value)
    for _, Object in Objects.Ladders do
        if Value then Functions.AddESP({ Object = Object, Text = "Лестница", Color = Options.LadderESPColor.Value }, true)
        else Functions.RemoveESP(Object) end
    end
end)
Options.LadderESPColor:OnChanged(function(Value)
    for _, Object in Objects.Ladders do FeatherHub.ESPLibrary:UpdateObjectColor(Object, Value) end
end)

-- ESP Settings
Groupboxes.Visuals_ESP_Settings:AddToggle("ESPRainbow",     { Text = "Радужный эффект", Default = false, Tooltip = "Меняет цвета ESP по цветам радуги." })
Groupboxes.Visuals_ESP_Settings:AddToggle("ESPShowDistance",{ Text = "Показать расстояние",  Default = true,  Tooltip = "Показывает расстояние от персонажа до объекта." })
Groupboxes.Visuals_ESP_Settings:AddDivider()
Groupboxes.Visuals_ESP_Settings:AddSlider("ESPFillTransparency",        { Text = "Прозрачность заливки",         Min = 0, Max = 1, Default = 0.75, Rounding = 2, Compact = true })
Groupboxes.Visuals_ESP_Settings:AddSlider("ESPOutlineTransparency",     { Text = "Прозрачность контура",      Min = 0, Max = 1, Default = 0,    Rounding = 2, Compact = true })
Groupboxes.Visuals_ESP_Settings:AddSlider("ESPTextTransparency",        { Text = "Прозрачность текста",         Min = 0, Max = 1, Default = 0,    Rounding = 2, Compact = true })
Groupboxes.Visuals_ESP_Settings:AddSlider("ESPTextOutlineTransparency", { Text = "Прозрачность обводки текста", Min = 0, Max = 1, Default = 0,    Rounding = 2, Compact = true })
Groupboxes.Visuals_ESP_Settings:AddSlider("ESPFadeTime",                { Text = "Время затухания",                 Min = 0, Max = 1, Default = 0.25, Rounding = 2, Compact = true })
Groupboxes.Visuals_ESP_Settings:AddSlider("ESPRenderLimit",             { Text = "Лимит отрисовки",              Min = 30, Max = 240, Default = 240, Rounding = 0, Compact = true })
Groupboxes.Visuals_ESP_Settings:AddSlider("ESPTextSize",                { Text = "Размер текста",                 Min = 12, Max = 24, Default = 20, Rounding = 0, Compact = true })
Groupboxes.Visuals_ESP_Settings:AddDropdown("ESPTextFont", {
    Text = "Шрифт текста",
    Values = { "Legacy","Arial","ArialBold","SourceSans","SourceSansBold","SourceSansLight","SourceSansItalic","Bodoni","Garamond","Cartoon","Code","Highway","SciFi","Arcade","Fantasy","Antique","SourceSansSemibold","Gotham","GothamMedium","GothamBold","GothamBlack","AmaticSC","Bangers","Creepster","DenkOne","Fondamento","FredokaOne","GrenzeGotisch","IndieFlower","JosefinSans","Jura","Kalam","LuckiestGuy","Merriweather","Michroma","Nunito","Oswald","PatrickHand","PermanentMarker","Roboto","RobotoCondensed","RobotoMono","Sarpanch","SpecialElite","TitilliumWeb","Ubuntu","BuilderSans","BuilderSansMedium","BuilderSansBold","BuilderSansExtraBold","Arimo","ArimoBold" },
    Default = 12
})
Groupboxes.Visuals_ESP_Settings:AddDivider()
Groupboxes.Visuals_ESP_Settings:AddDropdown("ESPTracersOrigin",  { Text = "Начало линий", Values = { "Bottom","Center","Top","Mouse" }, Default = 1 })
Groupboxes.Visuals_ESP_Settings:AddSlider("ESPTracerThickness",  { Text = "Толщина линий", Min = 0.5, Max = 2, Default = 0.75, Rounding = 2, Compact = true })
Groupboxes.Visuals_ESP_Settings:AddToggle("ESPTracersToggle",    { Text = "Показать линии", Default = false, Tooltip = "Рисует линии до подсвеченных объектов." })
Groupboxes.Visuals_ESP_Settings:AddDivider()
Groupboxes.Visuals_ESP_Settings:AddSlider("ESPArrowsRadius",     { Text = "Радиус стрелок", Min = 100, Max = 500, Default = 250, Rounding = 0, Compact = true })
Groupboxes.Visuals_ESP_Settings:AddToggle("ESPArrowsToggle",     { Text = "Показать стрелки", Default = false, Tooltip = "Показывает стрелки к объектам за пределами экрана." })

FeatherHub.ESPLibrary:SetRainbow(false)
FeatherHub.ESPLibrary:SetShowDistance(true)
FeatherHub.ESPLibrary:SetFillTransparency(0.75)
FeatherHub.ESPLibrary:SetOutlineTransparency(0)
FeatherHub.ESPLibrary:SetTextTransparency(0)
FeatherHub.ESPLibrary:SetTextOutlineTransparency(0)
FeatherHub.ESPLibrary:SetRenderLimit(240)
FeatherHub.ESPLibrary:SetFadeTime(0.25)
FeatherHub.ESPLibrary:SetTextSize(20)
FeatherHub.ESPLibrary:SetFont(Enum.Font.Highway)
FeatherHub.ESPLibrary:SetTracers(false)
FeatherHub.ESPLibrary:SetTracerSize(0.75)
FeatherHub.ESPLibrary:SetTracerOrigin("Bottom")
FeatherHub.ESPLibrary:SetArrows(false)
FeatherHub.ESPLibrary:SetArrowRadius(250)
FeatherHub.ESPLibrary:SetDistanceSizeRatio(0.8)

Toggles.ESPRainbow:OnChanged(function(V)        FeatherHub.ESPLibrary:SetRainbow(V) end)
Toggles.ESPShowDistance:OnChanged(function(V)   FeatherHub.ESPLibrary:SetShowDistance(V) end)
Options.ESPFillTransparency:OnChanged(function(V)        FeatherHub.ESPLibrary:SetFillTransparency(V) end)
Options.ESPOutlineTransparency:OnChanged(function(V)     FeatherHub.ESPLibrary:SetOutlineTransparency(V) end)
Options.ESPTextTransparency:OnChanged(function(V)        FeatherHub.ESPLibrary:SetTextTransparency(V) end)
Options.ESPTextOutlineTransparency:OnChanged(function(V) FeatherHub.ESPLibrary:SetTextOutlineTransparency(V) end)
Options.ESPFadeTime:OnChanged(function(V)        FeatherHub.ESPLibrary:SetFadeTime(V) end)
Options.ESPRenderLimit:OnChanged(function(V)     FeatherHub.ESPLibrary:SetRenderLimit(V) end)
Options.ESPTextSize:OnChanged(function(V)        FeatherHub.ESPLibrary:SetTextSize(V) end)
Options.ESPTextFont:OnChanged(function(V)        FeatherHub.ESPLibrary:SetFont(Enum.Font[V]) end)
Toggles.ESPTracersToggle:OnChanged(function(V)   FeatherHub.ESPLibrary:SetTracers(V) end)
Options.ESPTracersOrigin:OnChanged(function(V)   FeatherHub.ESPLibrary:SetTracerOrigin(V) end)
Options.ESPTracerThickness:OnChanged(function(V) FeatherHub.ESPLibrary:SetTracerSize(V) end)
Toggles.ESPArrowsToggle:OnChanged(function(V)    FeatherHub.ESPLibrary:SetArrows(V) end)
Options.ESPArrowsRadius:OnChanged(function(V)    FeatherHub.ESPLibrary:SetArrowRadius(V) end)

-- ════════════════════════════════════════════════════════════════
-- FLOORS TAB
-- ════════════════════════════════════════════════════════════════
Tabs.Floors:UpdateWarningBox({
    Visible = true, Title = "Предупреждение о совместимости",
    Text = "Функции, выделенные красным, не работают на текущем этаже.",
})

Groupboxes.Floors_Automation = Tabs.Floors:AddRightGroupbox("Автоматизация")
Groupboxes.Floors_Automation:AddToggle("AutoSteerMinecart", {
    Text = "Автоуправление вагонеткой", Default = false, Tooltip = "Автоматически проходит погоню на вагонетке.",
    Disabled = not Functions.CheckCompatability({"require"}), DisabledTooltip = Globals.IncompatibleMessage
})
Groupboxes.Floors_Automation:AddSlider("AutoSteerMinecartTurnDistance", {
    Text = "Дальность поворота", Min = 20, Max = 40, Default = 30, Rounding = 0,
    Disabled = not Functions.CheckCompatability({"require"}), DisabledTooltip = Globals.IncompatibleMessage
})
Groupboxes.Floors_Automation:AddSlider("AutoSteerMinecartDuckDistance", {
    Text = "Дальность приседания", Min = 20, Max = 40, Default = 30, Rounding = 0,
    Disabled = not Functions.CheckCompatability({"require"}), DisabledTooltip = Globals.IncompatibleMessage
})
Groupboxes.Floors_Automation:AddDivider()
Groupboxes.Floors_Automation:AddToggle("RoomsAutoWalk",             { Text = "Автопрохождение Rooms",       Default = false, Tooltip = "Автоматически идёт и прячется от сущностей в The Rooms." })
Groupboxes.Floors_Automation:AddSlider("RoomsAutoWalkPathfindTimeout", { Text = "Тайм-аут поиска пути", Min = 0.5, Max = 3, Default = 1, Rounding = 1 })
Groupboxes.Floors_Automation:AddToggle("RoomsAutoWalkIgnoreA60",    { Text = "Игнорировать A-60",      Default = false, Tooltip = "Продолжает идти при наличии A-60 и автоматически включает подмену позиции." })
Groupboxes.Floors_Automation:AddToggle("RoomsAutoWalkShowPathToggle", { Text = "Показать путь",       Default = false, Tooltip = "Показывает текущий путь автопрохождения Rooms." })
Groupboxes.Floors_Automation:AddToggle("RoomsAutoWalkSpoofFootsteps", {
    Text = "Подмена шагов", Default = false, Tooltip = "Создаёт видимость обычной ходьбы персонажа.",
    Disabled = not Functions.CheckCompatability({"hookmetamethod", "newcclosure", "getnamecallmethod"}), DisabledTooltip = Globals.IncompatibleMessage
})

Toggles.RoomsAutoWalk:OnChanged(function()
    for _, Object in Globals.RoomsNodesFolder:GetChildren() do
        if Object.Name == "PathNode" then Object:Destroy() end
    end
end)
Toggles.RoomsAutoWalkShowPathToggle:AddColorPicker("RoomsAutoWalkShowPathColor", { Text = "Путь", Default = Color3.fromRGB(0, 255, 0), Transparency = 0 })
Toggles.RoomsAutoWalkShowPathToggle:OnChanged(function(Value)
    for _, Object in Globals.RoomsNodesFolder:GetChildren() do
        if Object.Name == "PathNode" then Object.Transparency = Value and 0.5 or 1 end
    end
end)
Options.RoomsAutoWalkShowPathColor:OnChanged(function(Value)
    for _, Object in Globals.RoomsNodesFolder:GetChildren() do
        if Object.Name == "PathNode" then Object.Color = Value end
    end
end)

Functions.RoomsAutoWalk = {}
Functions.RoomsAutoWalk.GetNearestHidingSpot = function()
    local Nearest = { Distance = math.huge, Object = nil }
    for _, Object in Objects.HidingSpots do
        if Object.PrimaryPart and Object:FindFirstChild("HidePrompt") then
            local Distance = LocalPlayer:DistanceFromCharacter(Object.PrimaryPart.Position)
            if Distance < Nearest.Distance and Object.PrimaryPart.Position.Y > -10 then
                local HiddenPlayer = Object:FindFirstChild("HiddenPlayer", true)
                if HiddenPlayer and not HiddenPlayer.Value then
                    Nearest.Distance = Distance
                    Nearest.Object = Object
                end
            end
        end
    end
    return Nearest.Object
end

local RoomsEntityList = { "RushMoving","AmbushMoving","BackdoorRush","A60","A120","CustomEntity","GlitchRush","GlitchAmbush" }
Functions.RoomsAutoWalk.GetPathfindTarget = function()
    for _, Object in Services.Workspace:GetChildren() do
        if table.find(RoomsEntityList, Object.Name) and Object.PrimaryPart then
            local Y = Object.PrimaryPart.Position.Y
            if Y > -10 and Y < 150 then
                if Object.Name == "A60" and not Toggles.RoomsAutoWalkIgnoreA60.Value or Object.Name ~= "A60" then
                    return Functions.RoomsAutoWalk.GetNearestHidingSpot() or CurrentRooms[tostring(LatestRoom.Value)]:FindFirstChild("RoomExit")
                end
            end
        end
    end
    return CurrentRooms[tostring(LatestRoom.Value)]:FindFirstChild("RoomExit")
end

Connections.RoomsAutoWalkHandler = Services.RunService.Heartbeat:Connect(function()
    if Floor ~= "Rooms" or not Toggles.RoomsAutoWalk.Value or Globals.RoomsAutoWalkActive or not CollisionPart or LatestRoom.Value >= 1000 then return end
    Globals.RoomsAutoWalkActive = true

    local Path = Services.PathfindingService:CreatePath({
        AgentCanJump = true, AgentCanClimb = false, WaypointSpacing = 4,
        AgentRadius = 1.5, AgentHeight = 1.5, Costs = { StuckPart = 8 }
    })

    if Toggles.RoomsAutoWalkIgnoreA60.Value and not Toggles.PositionSpoof.Value then
        Toggles.PositionSpoof:SetValue(true)
    end

    local TargetPart = Functions.RoomsAutoWalk.GetPathfindTarget()
    if not TargetPart then Globals.RoomsAutoWalkActive = false return end

    local TargetPosition
    if TargetPart.Name == "RoomExit" then
        TargetPosition = TargetPart.Position
    elseif TargetPart:FindFirstChild("HidePrompt") then
        for _, Part in TargetPart:GetDescendants() do
            if Part:IsA("BasePart") then Part.CanCollide = false end
        end
        TargetPosition = TargetPart.PrimaryPart.Position
    end

    if CollisionPart.Anchored and not TargetPart:FindFirstChild("HidePrompt") then
        Character:SetAttribute("Hiding", true)
        RemotesFolder.CamLock:FireServer()
        Character:SetAttribute("Hiding", false)
    end

    local CurrentRoom = CurrentRooms[tostring(LatestRoom.Value)]
    if CurrentRoom:FindFirstChild("Door") then CurrentRoom.Door.Door.CanCollide = false end

    if not TargetPosition or LocalPlayer:DistanceFromCharacter(TargetPosition) >= 750 then
        Globals.RoomsAutoWalkActive = false return
    end

    Path:ComputeAsync(CollisionPart.Position, TargetPosition)
    local Waypoints = Path:GetWaypoints()

    if #Waypoints == 0 then
        local RoomExit = CurrentRoom:FindFirstChild("RoomExit")
        if RoomExit then Humanoid:MoveTo(RoomExit.Position) end
        Globals.RoomsAutoWalkActive = false return
    end

    for _, Node in Globals.RoomsNodesFolder:GetChildren() do
        if Node.Name == "PathNode" then Node:Destroy() end
    end

    for _, Waypoint in Waypoints do
        local Block = Instance.new("Part", Globals.RoomsNodesFolder)
        Block.Transparency = Toggles.RoomsAutoWalkShowPathToggle.Value and 0.5 or 1
        Block.Size = Vector3.one
        Block.Position = Waypoint.Position
        Block.Shape = Enum.PartType.Ball
        Block.CanCollide = false
        Block.Anchored = true
        Block.Name = "PathNode"
        Block.Color = Options.RoomsAutoWalkShowPathColor.Value
        Block.Material = Enum.Material.Neon
    end

    local Stuck = false
    for _, Waypoint in Waypoints do
        if Stuck or not Toggles.RoomsAutoWalk.Value then break end
        local Finished = false
        local Start = tick()

        local StepConnection = Services.RunService.RenderStepped:Connect(function()
            if Stuck or not Toggles.RoomsAutoWalk.Value then Finished = true return end
            local NewTarget = Functions.RoomsAutoWalk.GetPathfindTarget()
            if NewTarget and NewTarget:FindFirstChild("HidePrompt") and not TargetPart:FindFirstChild("HidePrompt") then
                Finished = true return
            end
            if TargetPart:FindFirstChild("HidePrompt") then
                local HidePrompt = TargetPart:FindFirstChild("HidePrompt")
                if LocalPlayer:DistanceFromCharacter(TargetPosition) < HidePrompt.MaxActivationDistance
                    and Character:GetAttribute("Hiding") ~= true then
                    Functions.ForceFirePrompt(HidePrompt)
                end
            end
            local FlatPos = Vector3.new(Waypoint.Position.X, RootPart.Position.Y, Waypoint.Position.Z)
            if LocalPlayer:DistanceFromCharacter(FlatPos) < 5 then Finished = true end
            Humanoid:MoveTo(Waypoint.Position)
        end)

        while not Finished do
            if tick() - Start > Options.RoomsAutoWalkPathfindTimeout.Value then
                local StuckBlock = Instance.new("Part", Globals.RoomsNodesFolder)
                StuckBlock.Transparency = 1
                StuckBlock.Size = Vector3.one
                StuckBlock.CFrame = Collision.CFrame
                StuckBlock.Shape = Enum.PartType.Ball
                StuckBlock.CanCollide = false
                StuckBlock.Anchored = true
                StuckBlock.Name = "StuckPart"
                local Modifier = Instance.new("PathfindingModifier", StuckBlock)
                Modifier.Label = "StuckPart"
                Stuck = true
                break
            end
            task.wait()
        end
        StepConnection:Disconnect()
        Humanoid:MoveTo(RootPart.Position)
    end
    Globals.RoomsAutoWalkActive = false
end)

Connections.RoomsHandler = CurrentRooms.ChildAdded:Connect(function(Room)
    for _, Object in Globals.RoomsNodesFolder:GetChildren() do
        if Object.Name == "StuckPart" then Object:Destroy() end
    end

    if Room:GetAttribute("RawName") and string.find(Room:GetAttribute("RawName"), "Eyestalk") then
        local PreviousNode = nil
        local function CreateEyestalkNode(WaypointPos)
            local NewNode = Instance.new("Part")
            NewNode.Size = Vector3.one
            NewNode.Transparency = 1
            NewNode.Parent = Globals.SeekNodesFolder
            NewNode.Anchored = true
            NewNode.Position = WaypointPos
            NewNode.CanCollide = false
            NewNode.Name = "SeekLightNode"
            local PrevNode = PreviousNode or NewNode
            PreviousNode = NewNode
            local NewBeam = Instance.new("Beam")
            NewBeam.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Options.ShowEyestalkPathColor.Value), ColorSequenceKeypoint.new(1, Options.ShowEyestalkPathColor.Value) })
            NewBeam.FaceCamera = true
            NewBeam.Width0 = 0.2
            NewBeam.Width1 = 0.2
            NewBeam.Brightness = 10
            NewBeam.LightInfluence = 0
            NewBeam.LightEmission = 0
            NewBeam.Enabled = true
            local Vis = Toggles.ShowEyestalkPathToggle.Value and 0 or 1
            NewBeam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, Vis), NumberSequenceKeypoint.new(1, Vis) })
            NewBeam.Parent = Globals.SeekNodesFolder
            local A0 = Instance.new("Attachment", NewNode)
            local A1 = Instance.new("Attachment", PrevNode)
            NewBeam.Attachment0 = A0
            NewBeam.Attachment1 = A1
            table.insert(Objects.EyestalkHighlights, NewBeam)
        end

        Room:WaitForChild("RoomEntrance", 9e9)
        Room:WaitForChild("RoomExit", 9e9)

        while not Room:GetAttribute("PathFound") do
            if Toggles.ShowEyestalkPathToggle.Value then
                local EyePath = game:GetService("PathfindingService"):CreatePath({
                    AgentCanJump = false, AgentCanClimb = false, WaypointSpacing = 2, AgentRadius = 1, AgentHeight = 1
                })
                EyePath:ComputeAsync(RootPart.Position, Room.RoomExit.Position)
                if EyePath.Status == Enum.PathStatus.Success then
                    Room:SetAttribute("PathFound", true)
                    for _, Waypoint in EyePath:GetWaypoints() do
                        CreateEyestalkNode(Waypoint.Position)
                        task.wait()
                    end
                    break
                end
            end
            task.wait(0.25)
        end
    end
end)

Groupboxes.Floors_Completion = Tabs.Floors:AddRightGroupbox("Прохождение")
Groupboxes.Floors_Completion:AddButton({
    Text = "Автопрохождение плотины Seek",
    Tooltip = "Автоматически телепортируется к каждому насосу и взаимодействует с ним.",
    Func = function()
        if LatestRoom.Value < 100 or Floor ~= "Mines" then
            Functions.Notify({Title = "Для этого нужно находиться в комнате 200."})
            return
        end
        local IsCutscene = false
        local CutsceneConnection = RemotesFolder.Cutscene.OnClientEvent:Connect(function()
            IsCutscene = true task.wait(7) IsCutscene = false
        end)
        local function GetNextPump()
            local Highest = { Height = -69420, Object = nil }
            for _, Object in pairs(Objects.Objectives) do
                if Object.Name == "WaterPump" and Object:GetAttribute("FeatherHub_Completed") ~= true then
                    if Object.PrimaryPart and Object.PrimaryPart.Position.Y > Highest.Height then
                        Highest.Object = Object
                        Highest.Height = Object.PrimaryPart.Position.Y
                    end
                end
            end
            return Highest.Object
        end
        local function HandlePump(Pump)
            while task.wait(0.1) do
                if IsCutscene then continue end
                Character:PivotTo(Pump:GetPivot())
                local Prompt = Pump:FindFirstChild("ValvePrompt", true)
                if Prompt then Functions.ForceFirePrompt(Prompt) end
                if Pump:GetAttribute("FeatherHub_Completed") then break end
            end
        end
        Functions.Notify({Title = "Попытка закрыть вентили.", Body = "Подождите."})
        while task.wait(0.1) do
            local Pump = GetNextPump()
            if Pump then HandlePump(Pump) else break end
        end
        Functions.Notify({Title = "Вентили успешно закрыты."})
    end
})
Groupboxes.Floors_Completion:AddButton({
    Text = "Автоматическое задание Cringle",
    Tooltip = "Мгновенно выполняет задание.",
    Func = function()
        local TouchPart = CurrentRooms:FindFirstChild("RippleExitDoor", true)
        if TouchPart then Character:PivotTo(TouchPart:GetPivot()) end
    end
})

Groupboxes.Floors_Visuals = Tabs.Floors:AddLeftGroupbox("Визуал")
Groupboxes.Floors_Visuals:AddToggle("ShowSeekPathToggle", {
    Text = "Показать путь Seek", Default = false, Tooltip = "Показывает правильный путь в погонях Seek.",
    Risky = Floor ~= "Mines"
})
Toggles.ShowSeekPathToggle:AddColorPicker("ShowSeekPathColor", { Text = "Путь Seek", Default = Color3.fromRGB(0, 255, 0), Transparency = 0 })

local function UpdateBeamVisibility(BeamTable, ColorKey, Visible)
    local Vis = Visible and 0 or 1
    local Seq = NumberSequence.new({ NumberSequenceKeypoint.new(0, Vis), NumberSequenceKeypoint.new(1, Vis) })
    for _, Beam in BeamTable do Beam.Transparency = Seq end
end
local function UpdateBeamColor(BeamTable, Value)
    local Seq = ColorSequence.new({ ColorSequenceKeypoint.new(0, Value), ColorSequenceKeypoint.new(1, Value) })
    for _, Beam in BeamTable do Beam.Color = Seq end
end

Toggles.ShowSeekPathToggle:OnChanged(function(V)  UpdateBeamVisibility(Objects.SeekHighlights, "ShowSeekPathColor", V) end)
Options.ShowSeekPathColor:OnChanged(function(V)   UpdateBeamColor(Objects.SeekHighlights, V) end)

Groupboxes.Floors_Visuals:AddToggle("ShowEyestalkPathToggle", {
    Text = "Показать путь Eyestalk", Default = false, Tooltip = "Показывает правильный путь в погоне Eyestalk.",
    Risky = Floor ~= "Garden"
})
Toggles.ShowEyestalkPathToggle:AddColorPicker("ShowEyestalkPathColor", { Text = "Путь Eyestalk", Default = Color3.fromRGB(0, 255, 0), Transparency = 0 })
Toggles.ShowEyestalkPathToggle:OnChanged(function(V) UpdateBeamVisibility(Objects.EyestalkHighlights, "ShowEyestalkPathColor", V) end)
Options.ShowEyestalkPathColor:OnChanged(function(V)  UpdateBeamColor(Objects.EyestalkHighlights, V) end)

Groupboxes.Floors_Bypass = Tabs.Floors:AddLeftGroupbox("Обход")
Groupboxes.Floors_Bypass:AddToggle("RemoveSeekTrigger", {
    Text = "Удалить триггер Seek", Default = false, Tooltip = "Отключает триггер погони Seek.",
    Risky = not (Floor == "Fools" or Floor == "OldHotel"),
    Disabled = not Functions.CheckCompatability({"firetouchinterest"}), DisabledTooltip = Globals.IncompatibleMessage
})
Groupboxes.Floors_Bypass:AddToggle("RemoveFigure", {
    Text = "Удалить Figure", Default = false, Tooltip = "Полностью удаляет Figure (работает не всегда).",
    Risky = not (Floor == "Fools" or Floor == "OldHotel" or Floor == "Mines"),
    Disabled = not Functions.CheckCompatability({"isnetworkowner"}), DisabledTooltip = Globals.IncompatibleMessage
})
Groupboxes.Floors_Bypass:AddToggle("AutoRevive", {
    Text = "Бесконечные возрождения", Default = false, Tooltip = "Автоматически возрождает после смерти без ограничения числа возрождений.",
    Risky = not (Floor == "Fools" or Floor == "OldHotel")
})
Groupboxes.Floors_Bypass:AddToggle("FigureGodmode", {
    Text = "Неуязвимость к Figure", Default = false, Tooltip = "Защищает от урона Figure.",
    Risky = not (Floor == "Fools" or Floor == "OldHotel")
})
Groupboxes.Floors_Bypass:AddDivider()
Groupboxes.Floors_Bypass:AddToggle("RemoveBasementGate",  { Text = "Удалить ворота подвала",   Default = false, Tooltip = "Удаляет ворота в подвальных комнатах.",            Risky = not (Floor == "Fools" or Floor == "OldHotel") })
Groupboxes.Floors_Bypass:AddToggle("RemovePaintingsDoor", { Text = "Удалить дверь с картинами",  Default = false, Tooltip = "Удаляет двери камина в комнатах с картинами.", Risky = not (Floor == "Fools" or Floor == "OldHotel") })
Groupboxes.Floors_Bypass:AddToggle("RemoveSkeletonDoor",  { Text = "Удалить дверь скелета",   Default = false, Tooltip = "Удаляет дверь скелета в лазарете.",    Risky = Floor ~= "Fools" })

local ObstructionNames = { ThingToOpen = "RemoveBasementGate", MovingDoor = "RemovePaintingsDoor", Wax_Door = "RemoveSkeletonDoor" }
for ObjName, ToggleName in ObstructionNames do
    Toggles[ToggleName]:OnChanged(function(Value)
        for _, Object in Objects.Obstructions do
            if Object.Name == ObjName then
                Object:PivotTo(Value and CFrame.new(-10000, -10000, -10000) or Object:GetAttribute("OriginalPosition"))
            end
        end
    end)
end

Groupboxes.Floors_Farming = Tabs.Floors:AddLeftGroupbox("Фарм")
Groupboxes.Floors_Farming:AddToggle("KnobFarm", {
    Text = "Фарм Knobs", Default = false, Tooltip = "Автоматически зарабатывает Knobs, повторяя смерть и возрождение.",
})
Groupboxes.Floors_Farming:AddButton({
    Text = "Начать фарм Knobs",
    Tooltip = "Начинает фарм Knobs; нажмите, когда соберёте достаточно золота.",
    Func = function()
        if LatestRoom.Value ~= 0 then
            Functions.Notify({Title = "Для этого нужно находиться в комнате 0."})
            return
        end
        if LocalPlayer.PlayerGui:FindFirstChild("TopbarUI") then
            local GoldCount = LocalPlayer.PlayerGui.TopbarUI.Topbar.StatsTopbarHandler.StatModules.Gold.GoldVal
            if GoldCount.Value <= 0 then
                Functions.Notify({Title = "Для этого нужно золото."})
                return
            end
        end
        Globals.KnobFarmStarted = true
    end
})
Groupboxes.Floors_Farming:AddDivider()
Groupboxes.Floors_Farming:AddButton({
    Text = "Начать фарм смертей", DoubleClick = true,
    Tooltip = "Автоматически набирает смерти, присоединяясь к новым забегам.",
    Func = function()
        if Functions.CheckCompatability({"fireproximityprompt", "firesignal"}) then
            Functions.Notify({Title = "Фарм смертей", Body = "Запуск фарма смертей..."})
        else
            Functions.Notify({Title = "Несовместимо", Body = Globals.IncompatibleMessage})
        end
    end,
    Disabled = not Functions.CheckCompatability({"fireproximityprompt", "firesignal"}),
    DisabledTooltip = Globals.IncompatibleMessage
})
Groupboxes.Floors_Farming:AddButton({
    Text = "Скопировать код фарма смертей", DoubleClick = false,
    Tooltip = "Копирует код запуска фарма смертей в буфер обмена.",
    Func = function()
        if Functions.CheckCompatability({"fireproximityprompt", "firesignal"}) then
            toclipboard("loadstring(game:HttpGet('https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/Library.lua'))()")
            Library:Notify("Код запуска скопирован в буфер обмена.")
        end
    end,
    Disabled = not Functions.CheckCompatability({"fireproximityprompt", "firesignal"}),
    DisabledTooltip = Globals.IncompatibleMessage
})

Toggles.KnobFarm:OnChanged(function(Value)
    if Value then
        Functions.Notify({Title = "Соберите немного золота, чтобы заработать Knobs.", Body = "Когда будете готовы, нажмите «Начать фарм Knobs»."})
    else
        Globals.KnobFarmStarted = false
    end
end)

Globals.KnobFarmActive = false
Globals.KnobFarmStarted = false
Connections.KnobFarm = Services.RunService.Heartbeat:Connect(function()
    if Toggles.KnobFarm.Value and Globals.KnobFarmStarted then
        if not Globals.KnobFarmActive then
            Globals.KnobFarmActive = true
            if Functions.CheckCompatability({"replicatesignal"}) then
                FeatherHub.Environment.replicatesignal(LocalPlayer.Kill)
            else
                RemotesFolder.Underwater:FireServer(true)
            end
            while task.wait() do
                if LocalPlayer:GetAttribute("Alive") then break end
            end
            RemotesFolder.Statistics:FireServer()
            task.wait(0.25)
            Globals.KnobFarmActive = false
        end
    end
end)

-- ════════════════════════════════════════════════════════════════
-- METAMETHOD HOOKS
-- ════════════════════════════════════════════════════════════════
local MainHook
local OtherHook
if Functions.CheckCompatability({"hookmetamethod", "newcclosure", "getnamecallmethod"}) then
    MainHook = FeatherHub.Environment.hookmetamethod(game, "__namecall", FeatherHub.Environment.newcclosure(function(Self, ...)
        local Args = { ... }
        if FeatherHub and FeatherHub.Environment then
            local Method = FeatherHub.Environment.getnamecallmethod()
            if Self.Name == "Crouch" and Method == "FireServer" then
                if Toggles.CrouchSpoof.Value or Toggles.PositionSpoof.Value then Args[1] = true end
                Args[2] = true
            end
            if Self.Name == "ClutchHeartbeat" and Method == "FireServer" and Toggles.AutoHeartbeatMinigame.Value
                or Self.Name == "HideMonster" and Method == "FireServer" and Toggles.AutoHeartbeatMinigame.Value then
                return
            end
            if Self.Name == "MotorReplication" and Method == "FireServer" then
                local DoBypass = (Toggles.BypassEyes.Value and Globals.IsEyes) or (Toggles.BypassLookman.Value and Globals.IsLookman)
                if DoBypass then
                    if Floor == "Fools" or Floor == "OldHotel" then
                        Args[1] = 0 Args[2] = (Globals.SpoofOffset == 200 and 65 or -65) Args[3] = 0 Args[4] = false
                    else
                        Args[1] = -650
                    end
                end
            end
        end
        return MainHook(Self, table.unpack(Args))
    end))

    OtherHook = FeatherHub.Environment.hookmetamethod(game, "__index", FeatherHub.Environment.newcclosure(function(Self, Property)
        local Real = OtherHook(Self, Property)
        if Property == "MoveDirection" and Self == Humanoid and Globals.RoomsAutoWalkActive
            and Toggles.RoomsAutoWalkSpoofFootsteps.Value and Floor == "Rooms"
            and not Character:GetAttribute("Hiding") then
            return RootPart.CFrame.LookVector
        end
        return Real
    end))
end

if Services.ReplicatedStorage:FindFirstChild("ModulesClient") then
    ClientModules = Services.ReplicatedStorage.ModulesClient
else
    ClientModules = Services.ReplicatedStorage.ClientModules
end

Modules = {
    Glitch         = ClientModules.EntityModules.Glitch,
    Shade          = ClientModules.EntityModules.Shade,
    Void           = ClientModules.EntityModules:FindFirstChild("Void"),
    SpiderJumpscare = nil, A90 = nil, Screech = nil, Dread = nil, GlitchScreech = nil,
}

-- ════════════════════════════════════════════════════════════════
-- CHARACTER HANDLER
-- ════════════════════════════════════════════════════════════════
local CharacterOldConnectionKeys = {
    "MainHandler", "JumpHandler", "SlideHandler", "LibraryCodeHandler1", "LibraryCodeHandler2",
    "OxygenConnection", "AnimationHandler", "AutoHideConnection", "AutoReviveHandler",
    "SHMFixer", "AnticheatDisabler", "AnticheatEnableDetector1", "AnticheatEnableDetector2",
    "AutoSteerMinecartDuckHandler", "AutoSolveAnchorsConnection", "InfiniteJumpsConnection1", "InfiniteJumpsConnection2",
    "FootstepHandler"
}

Globals.IsTyping = false
Connections.TextBoxConnection1 = Services.UserInputService.TextBoxFocused:Connect(function() Globals.IsTyping = true end)
Connections.TextBoxConnection2 = Services.UserInputService.TextBoxFocusReleased:Connect(function() Globals.IsTyping = false end)

Functions.HandleCharacter = function(NewCharacter)
    for _, Key in CharacterOldConnectionKeys do
        if Connections[Key] then Connections[Key]:Disconnect() Connections[Key] = nil end
    end

    while not LocalPlayer.PlayerGui:FindFirstChild("MainUI") do task.wait() end

    Character = NewCharacter
    Humanoid = NewCharacter:WaitForChild("Humanoid", 9e9)
    RootPart = NewCharacter:FindFirstChild("HumanoidRootPart")
    Camera   = Services.Workspace.CurrentCamera

    Globals.OldCamera = Camera
    Globals.MainUI = LocalPlayer.PlayerGui.MainUI

    Collision = NewCharacter:WaitForChild("Collision")
    CollisionPart  = NewCharacter:FindFirstChild("CollisionPart") or NewCharacter:FindFirstChild("Collision")
    CollisionClone = Collision:Clone()
    CollisionClone.Parent = NewCharacter
    CollisionClone.Name = "CollisionClone"
    CollisionClone.Massless = true

    CollisionPartClone = CollisionPart:Clone()
    CollisionPartClone.Parent = NewCharacter
    CollisionPartClone.Name = "CollisionPartClone"
    CollisionPartClone.CanCollide = false
    CollisionPartClone.Massless = true
    if CollisionPartClone:FindFirstChild("CollisionCrouch") then CollisionPartClone.CollisionCrouch:Destroy() end

    Character:SetAttribute("SpeedBoost", 0)
    Character:SetAttribute("SpeedBoostBehind", 0)
    Character:SetAttribute("SpeedBoostExtra", 0)

    OldJump  = NewCharacter:GetAttribute("CanJump")
    OldSlide = NewCharacter:GetAttribute("CanSlide")
    if Toggles.EnableCharacterJump.Value  then Character:SetAttribute("CanJump",  true) end
    if Toggles.EnableCharacterSlide.Value then Character:SetAttribute("CanSlide", true) end

    if Functions.CheckCompatability({"require"}) then
        Main_Game = FeatherHub.Environment.require(Globals.MainUI.Initiator.Main_Game)
    end
    if Main_Game and Toggles.RemoveCameraBobbing.Value then Main_Game.spring.Speed = 9e9 end

    if Main_Game and Functions.CheckCompatability({"require"}) then
        local Controls = require(LocalPlayer.PlayerScripts.PlayerModule):GetControls()
        local OriginalGetMoveVector = Controls.GetMoveVector
        Globals.OriginalGetMoveVector = OriginalGetMoveVector
        Controls.GetMoveVector = function(...)
            if Toggles.AutoSteerMinecart.Value and Floor == "Mines" then
                local Node = Globals.NearestTurnNode
                if Node and Functions.GetMinecart() then
                    local Turn = Node:GetAttribute("Turn")
                    return Turn == "Left" and Vector3.new(-1, 0, 0) or Turn == "Right" and Vector3.new(1, 0, 0) or Vector3.zero
                end
            end
            return OriginalGetMoveVector(...)
        end
    end

    Globals.AutoMinecartDucked = false
    Globals.LastDuck = tick()
    Connections.AutoSteerMinecartDuckHandler = Services.RunService.Heartbeat:Connect(function()
        if not Toggles.AutoSteerMinecart.Value or not Functions.GetMinecart() or tick() - Globals.LastDuck < 0.1 then return end
        Globals.NearestTurnNode = Functions.GetNearestTurnNode()
        if not Globals.AutoMinecartDucked and Functions.GetNearestDuckBoard() then
            Main_Game.crouch(true)
            Globals.AutoMinecartDucked = true
        elseif not Functions.GetNearestDuckBoard() and Globals.AutoMinecartDucked then
            Main_Game.crouch(false)
            Globals.AutoMinecartDucked = false
        end
        if Main_Game then Main_Game.fovtarget = Options.FieldOfView.Value else Camera.FieldOfView = Options.FieldOfView.Value end
        Globals.LastDuck = tick()
    end)

    Globals.AnticheatDisabled = false

    local UIModules = Globals.MainUI.Initiator.Main_Game.RemoteListener.Modules
    Modules.A90             = UIModules:FindFirstChild("A90")
    Modules.Screech         = UIModules.Screech
    Modules.Dread           = UIModules:FindFirstChild("Dread")
    Modules.SpiderJumpscare = UIModules.SpiderJumpscare

    if Toggles.RemoveScreech.Value    then Modules.Screech.Name = "Screech_Disabled" end
    if Toggles.RemoveA90.Value and Modules.A90   then Modules.A90.Name = "A90_Disabled" end
    if Toggles.RemoveDread.Value and Modules.Dread then Modules.Dread.Name = "Dread_Disabled" end
    if Toggles.DisableTimothyJumpscare.Value then Modules.SpiderJumpscare.Name = "SpiderJumpscare_Disabled" end

    if Toggles.DisableHideVignette.Value then
        local Vignette = Globals.MainUI:FindFirstChild("HideVignette") or Globals.MainUI.MainFrame:FindFirstChild("HideVignette")
        if Vignette then Vignette.Image = "Disabled" end
    end
    if Toggles.RemoveInteractingSounds.Value then
        local PS = Globals.MainUI.Initiator.Main_Game.PromptService
        PS.Triggered.Volume = 0 PS.Holding.Volume = 0 PS.Notification.Volume = 0
        Globals.MainUI.Initiator.Main_Game.Reminder.Caption.Volume = 0
    end
    if Toggles.DisableEntityJumpscares.Value then
        local JS = Globals.MainUI.Initiator.Main_Game.RemoteListener:FindFirstChild("Jumpscares")
        if JS then JS.Name = "Jumpscares_Disabled" end
    end

    local Cutscenes = Globals.MainUI.Initiator.Main_Game.RemoteListener.Cutscenes
    for _, Object in pairs(Cutscenes:GetChildren()) do
        if table.find(CutsceneNames, Object.Name) and Object:IsA("ModuleScript") then
            Object:SetAttribute("OriginalName", Object.Name)
            if Toggles.RemoveCutscenes.Value then Object.Name = Object.Name .. "_Disabled" end
        end
    end
    for _, Object in pairs(FloorReplicated:GetChildren()) do
        if table.find(CutsceneNames, Object.Name) and Object:IsA("ModuleScript") then
            Object:SetAttribute("OriginalName", Object.Name)
            if Toggles.RemoveCutscenes.Value then Object.Name = Object.Name .. "_Disabled" end
        end
    end

    CustomPhysics = PhysicalProperties.new(100, RootPart.CustomPhysicalProperties.Friction, RootPart.CustomPhysicalProperties.Elasticity, RootPart.CustomPhysicalProperties.FrictionWeight, RootPart.CustomPhysicalProperties.ElasticityWeight)
    for _, Part in NewCharacter:GetDescendants() do
        if Part:IsA("BasePart") then
            PartProperties[Part] = Part.CustomPhysicalProperties
            if Toggles.RemoveAcceleration.Value then Part.CustomPhysicalProperties = CustomPhysics end
        end
    end

    Connections.LibraryCodeHandler1 = LocalPlayer.PlayerGui.PermUI.Hints.ChildAdded:Connect(function()
        if Toggles.NotifyLibraryCode.Value then
            local Code = Functions.GetLibraryCode()
            if Code and not Code:find("_") and not Globals.LibraryCodeFound then
                local Lock = Services.Workspace:FindFirstChild("Padlock", true)
                Functions.Notify({ Title = "Код замка найден!", Body = "Код: '" .. Code .. "'", Time = Toggles.NotifyKeepNotifications.Value and Lock or 15 })
                Globals.LibraryCodeFound = true
            end
        end
    end)

    Connections.LibraryCodeHandler2 = Character.ChildAdded:Connect(function(Child)
        if (Child.Name == "LibraryHintPaper" or Child.Name == "LibraryHintPaperHard") and Toggles.NotifyLibraryCode.Value then
            local Code = Functions.GetLibraryCode()
            if Code and not Code:find("_") and not Globals.LibraryCodeFound then
                local Lock = Services.Workspace:FindFirstChild("Padlock", true)
                Functions.Notify({ Title = "Код замка найден!", Body = "Код: '" .. Code .. "'", Time = Toggles.NotifyKeepNotifications.Value and Lock or 15 })
                Globals.LibraryCodeFound = true
            end
        end
    end)

    Connections.FootstepHandler = Character.ChildAdded:Connect(function(Object)
        if Object:IsA("Sound") and Object.Name == "Sound" and Toggles.RemoveFootstepSounds.Value then Object.Volume = 0 end
    end)

    Globals.OldOxygen = Character:GetAttribute("Oxygen")
    Connections.OxygenConnection = Character:GetAttributeChangedSignal("Oxygen"):Connect(function()
        local NewOxy = Character:GetAttribute("Oxygen")
        if NewOxy < Globals.OldOxygen and Toggles.NotifyOxygen.Value then
            Functions.Caption(Functions.FormatOxygen(NewOxy), true)
        end
        Globals.OldOxygen = NewOxy
    end)

    Connections.AutoReviveHandler = LocalPlayer:GetAttributeChangedSignal("Alive"):Connect(function()
        if LocalPlayer:GetAttribute("Alive") == false and Toggles.AutoRevive.Value then
            if Floor == "Fools" or Floor == "OldHotel" then
                while LocalPlayer:GetAttribute("Alive") ~= true do
                    RemotesFolder.Revive:FireServer()
                    task.wait(0.5)
                end
            end
        end
    end)

    Connections.SHMFixer = RootPart:GetPropertyChangedSignal("Anchored"):Connect(function()
        task.wait()
        if Floor == "Fools" and RootPart.Anchored and Character:GetAttribute("Hiding") ~= true then
            RootPart.Anchored = false
        end
    end)

    Connections.AnticheatDisabler = Character:GetAttributeChangedSignal("Climbing"):Connect(function()
        if Character:GetAttribute("Climbing") == true and Toggles.DisableAnticheat.Value and not Globals.AnticheatDisabled then
            task.wait(0.25)
            Character:SetAttribute("Climbing", false)
            Functions.Notify({ Title = "Античит успешно отключён.", Body = "Он снова включится после кат-сцены или комнаты Halt." })
            Globals.AnticheatDisabled = true
        end
    end)

    Connections.AnticheatEnableDetector1 = RemotesFolder:WaitForChild("Cutscene").OnClientEvent:Connect(function(CutsceneName)
        if Globals.AnticheatDisabled and not CutsceneName:find("SewerSeek") then
            Globals.AnticheatDisabled = false
            Functions.Notify({ Title = "Античит снова включён.", Body = "Взаимодействуйте с лестницей, чтобы снова его отключить." })
        end
    end)

    Connections.AnticheatEnableDetector2 = RemotesFolder:WaitForChild("UseEnemyModule").OnClientEvent:Connect(function(ModuleName)
        if ModuleName == "Void" or ModuleName == "Glitch" then
            if Globals.AnticheatDisabled then
                Globals.AnticheatDisabled = false
                Functions.Notify({ Title = "Античит снова включён.", Body = "Взаимодействуйте с лестницей, чтобы снова его отключить." })
            end
            LocalPlayer:SetAttribute("CurrentRoom", LatestRoom.Value)
        end
    end)

    Connections.AnimationHandler = Character.ChildAdded:Connect(function()
        local ToolNames = { "Lockpick","Shears","SkeletonKey","Key","GeneratorFuse","KeyElectrical","KeyBackdoor","KeyIron", "Multitool" }
        local Tool
        for _, Name in ToolNames do Tool = Character:FindFirstChild(Name) if Tool then break end end
        if not Tool then return end
        local UseAnim = Tool:FindFirstChild("use", true) or Tool:FindFirstChild("promptanim", true)
        if UseAnim then
            UseAnim = Humanoid:LoadAnimation(UseAnim)
            UseAnim.Priority = Enum.AnimationPriority.Action4
            Globals.UseAnimation = UseAnim
        end
        local UseAnimBreak = Tool:FindFirstChild("usefinish", true) or Tool:FindFirstChild("promptanimend", true) or Tool:FindFirstChild("lockpickuse", true)
        if UseAnimBreak then
            UseAnimBreak = Humanoid:LoadAnimation(UseAnimBreak)
            UseAnimBreak.Priority = Enum.AnimationPriority.Action4
            Globals.UseAnimationBreak = UseAnimBreak
        end
    end)

    Connections.JumpHandler = Character:GetAttributeChangedSignal("CanJump"):Connect(function()
        local Val = Character:GetAttribute("CanJump")
        if Toggles.EnableCharacterJump.Value and Val ~= true or not Toggles.EnableCharacterJump.Value then OldJump = Val end
        if Toggles.EnableCharacterJump.Value then Character:SetAttribute("CanJump", true) end
    end)

    Connections.SlideHandler = Character:GetAttributeChangedSignal("CanSlide"):Connect(function()
        local Val = Character:GetAttribute("CanSlide")
        if Toggles.EnableCharacterSlide.Value and Val ~= true or not Toggles.EnableCharacterSlide.Value then OldSlide = Val end
        if Toggles.EnableCharacterSlide.Value then Character:SetAttribute("CanSlide", true) end
    end)

    Connections.InfiniteJumpsConnection1 = Services.UserInputService.InputBegan:Connect(function(Input)
        if Input.KeyCode == Enum.KeyCode.Space and Toggles.InfiniteJumps.Value and not Globals.IsTyping then
            Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)

    local JumpButton = Globals.MainUI.MainFrame.MobileButtons:FindFirstChild("JumpButton")
    if JumpButton then
        Connections.InfiniteJumpsConnection2 = JumpButton.MouseButton1Down:Connect(function()
            if Toggles.InfiniteJumps.Value then Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end

    Globals.SpoofOffset = 0
    Globals.LastAutoHide = tick()
    Connections.AutoHideConnection = Services.RunService.Heartbeat:Connect(function()
        if not Toggles.AutoClosetToggle.Value or tick() - Globals.LastAutoHide <= 0.1 then
            Globals.AutoClosetActive = false return
        end
        local Entity = Functions.GetNearestEntity(true, Options.AutoClosetEntityList.Value)
        local EntityNearby = Entity and LocalPlayer:DistanceFromCharacter(Entity.PrimaryPart.Position) <= (EntityDistances[Entity.Name] or 150)
        if Character:GetAttribute("Hiding") == true then
            Globals.AutoClosetActive = false
            Globals.SpectateEntity = nil
            if not EntityNearby then RemotesFolder.CamLock:FireServer() end
            Globals.LastAutoHide = tick() return
        end
        if not Entity or not EntityNearby then
            Globals.SpectateEntity = nil
            Globals.AutoClosetActive = false
            Globals.LastAutoHide = tick() return
        end
        local Closet = Functions.GetNearestHidingSpot()
        if Character:GetAttribute("Hiding") ~= true and Closet then
            local Prompt = Closet:FindFirstChild("HidePrompt") or Closet:FindFirstChild("HidingPrompt")
                or Closet:FindFirstChild("HidePrompt", true) or Closet:FindFirstChild("HidingPrompt", true)
            if not Prompt then
                for _, Child in Closet:GetDescendants() do
                    if (Child:IsA("ProximityPrompt") or Child:IsA("InteractPrompt")) and (Child.Name == "HidePrompt" or Child.Name == "HidingPrompt") then
                        Prompt = Child break
                    end
                end
            end
            if Prompt then
                Globals.AutoClosetActive = true
                Functions.ForceFirePrompt(Prompt)
            end
        end
        if Character:GetAttribute("Hiding") then
            if Toggles.SpectateEntityToggle.Value and Entity.PrimaryPart then Globals.SpectateEntity = Entity end
        end
        Globals.LastAutoHide = tick()
    end)

    Globals.LastAutoAnchor = tick()
    Connections.AutoSolveAnchorsConnection = Services.RunService.Heartbeat:Connect(function()
        if not Toggles.AutoSolveAnchors.Value then return end
        if not Globals.MainUI:FindFirstChild("AnchorHintFrame") then return end
        if tick() - Globals.LastAutoAnchor <= 0.1 then return end
        local Anchor = Functions.GetCurrentAnchor()
        if Anchor and LocalPlayer:DistanceFromCharacter(Anchor.PrimaryPart.Position) < Anchor.ActivateEventPrompt.MaxActivationDistance and not Anchor:GetAttribute("Activated") then
            Anchor:WaitForChild("AnchorRemote"):InvokeServer(Globals.MainUI.AnchorHintFrame.Code.Text)
        end
        Globals.LastAutoAnchor = tick()
    end)

    Globals.ManipulateBody = Instance.new("BodyVelocity")
    Globals.ManipulateBody.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    Globals.FlyBody = Instance.new("BodyVelocity")
    Globals.FlyBody.MaxForce = Vector3.new(9e9, 9e9, 9e9)

    Globals.SelfKilled = false
    Globals.ThirdPersonParts = {}
    for _, Object in Character:GetDescendants() do
        if Object:IsA("Accessory") and Object:FindFirstChild("Handle") then table.insert(Globals.ThirdPersonParts, Object.Handle) end
    end
    table.insert(Globals.ThirdPersonParts, Character:WaitForChild("Head"))

    Globals.LastAnimationCheck = tick()
    Globals.LastCrouchFire = tick()
    Globals.OriginalC1 = Character.LowerTorso.Root.C1

    local RayParams = RaycastParams.new()
    RayParams.FilterType = Enum.RaycastFilterType.Exclude

    local MainFrame = Globals.MainUI:FindFirstChild("MainFrame")
    if MainFrame and MainFrame:FindFirstChild("SurgeVignette") then
        Globals.SurgeFrame = MainFrame.SurgeVignette
        if Toggles.RemoveSurge.Value then Globals.SurgeFrame.Name = "SurgeVignette_Disabled" end
    end

    Connections.MainHandler = Services.RunService.RenderStepped:Connect(function()
        if Services.Workspace:FindFirstChild("Camera") then Camera = Services.Workspace:FindFirstChild("Camera") end
        if Toggles.SpeedBoostToggle.Value then Humanoid.WalkSpeed = Functions.GetCurrentSpeed() + Options.SpeedBoostSlider.Value end
        if Globals.Lagging or (Options.SpeedBoostSlider.Value <= 6 and Options.FlySpeed.Value <= 21) then CollisionPartClone.Massless = true end
        Globals.IsEyes    = Services.Workspace:FindFirstChild("Eyes") ~= nil or Services.Workspace:FindFirstChild("Lookman") ~= nil
        Globals.IsLookman = Services.Workspace:FindFirstChild("BackdoorLookman") ~= nil

        if Toggles.AmbientToggle.Value then
            Services.TweenService:Create(Services.Lighting, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), { Ambient = Options.AmbientColor.Value }):Play()
        end

        if Main_Game then
            if Toggles.RemoveCameraShake.Value then Main_Game.csgo = CFrame.new() end
            if Toggles.ViewmodelOffsetToggle.Value then
                Main_Game.tooloffset = Vector3.new(Options.ViewmodelOffsetX.Value, Options.ViewmodelOffsetY.Value, Options.ViewmodelOffsetZ.Value)
            else
                Main_Game.tooloffset = Vector3.zero
            end
        end

        if Globals.SelfKilled and Globals.MainUI:FindFirstChild("Statistics") then
            Globals.MainUI.Statistics.Death.Text = "Смерть от FeatherHub"
        end

        local MainFrame = Globals.MainUI:FindFirstChild("MainFrame")
        if MainFrame then
            local Effects = MainFrame.Healthbar:FindFirstChild("Effects")
            if Effects and Effects:FindFirstChild("Crouching") then Effects.Crouching.Visible = Functions.IsCrouching() end
        end

        if (Toggles.CrouchSpoof.Value or Toggles.PositionSpoof.Value) and RemotesFolder:FindFirstChild("Crouch") then
            RemotesFolder.Crouch:FireServer(true, true)
        end

        if Floor ~= "Fools" and Floor ~= "OldHotel" and not Camera:FindFirstChild("MinecartRig") then
            RootPart.CanCollide = false
        end

        for _, Part in Character:GetChildren() do
            if Part:IsA("BasePart") then Part.CanCollide = false end
        end

        if LocalPlayer:GetAttribute("Alive") == true then
            Services.SoundService:WaitForChild("Main").Volume = 1
        end

        if Floor == "OldHotel" or Floor == "Fools" then
            local SpoofOffset = Toggles.PositionSpoof.Value and Functions.GetNearestEntity() and 200 or Toggles.FigureGodmode.Value and Functions.GetNearestFigure() and 200 or 0
            Globals.SpoofOffset = SpoofOffset
            Collision.Position = RootPart.Position + Vector3.new(0, SpoofOffset, 0)
            Collision.CanCollide = false
            if Floor == "Fools" then
                Collision.CollisionCrouch.CanCollide = false
                CollisionClone.CollisionCrouch.CanCollide = false
            end
            RootPart.CanCollide = not (Toggles.NoclipToggle.Value or Toggles.VelocityManipulationToggle.Value)
        else
            Collision.CanCollide = false
            if Collision:FindFirstChild("CollisionCrouch") then Collision.CollisionCrouch.CanCollide = false end
            if CollisionClone:FindFirstChild("CollisionCrouch") then
                local IsCrouch = Functions.IsCrouching()
                CollisionClone.CanCollide = not (Toggles.NoclipToggle.Value or Toggles.VelocityManipulationToggle.Value or IsCrouch)
                CollisionClone.CollisionCrouch.CanCollide = not (Toggles.NoclipToggle.Value or Toggles.VelocityManipulationToggle.Value or not IsCrouch)
            else
                RootPart.CanCollide = not (Toggles.NoclipToggle.Value or Toggles.VelocityManipulationToggle.Value)
            end
            if Character:FindFirstChild("LowerTorso") and Character.LowerTorso:FindFirstChild("Root") then
                Character.LowerTorso.Root.C1 = Globals.OriginalC1 * CFrame.new(0, Toggles.PositionSpoof.Value and -2.346 or 0, 0)
            end
            local SpoofY = Toggles.PositionSpoof.Value and 2.328 or 0.18
            Collision.Position     = RootPart.Position + Vector3.new(0, SpoofY, 0)
            CollisionPart.Position = RootPart.Position + Vector3.new(0, SpoofY, 0)
            if Collision:FindFirstChild("CollisionCrouch") and CollisionClone:FindFirstChild("CollisionCrouch") then
                local CrouchY = Toggles.PositionSpoof.Value and 1.328 or -0.982
                Collision.CollisionCrouch.Position = RootPart.Position + Vector3.new(0, CrouchY, 0)
                CollisionClone.CollisionCrouch.CollisionGroup = Collision.CollisionCrouch.CollisionGroup
            end
            if CollisionClone:FindFirstChild("CollisionCrouch") then
                CollisionClone.CollisionCrouch.Position = RootPart.Position + Vector3.new(0, Toggles.PositionSpoof.Value and 0.75 or -0.982, 0)
            end
        end

        CollisionClone.CollisionGroup = Collision.CollisionGroup
        CollisionClone.Position = RootPart.Position + Vector3.new(0, Toggles.PositionSpoof.Value and 1.75 or 0.18, 0)

        if Toggles.VelocityManipulationToggle.Value and Options.VelocityManipulationMode.Value == "Velocity" then
            Globals.ManipulateBody.Parent = RootPart
            Globals.ManipulateBody.Velocity = RootPart.CFrame.LookVector * 2.25
        else
            Globals.ManipulateBody.Parent = nil
        end

        if Toggles.VelocityManipulationToggle.Value and Options.VelocityManipulationMode.Value == "Pivot" and Floor ~= "Fools" and Floor ~= "OldHotel" then
            Character:PivotTo(Camera:GetPivot() * CFrame.new(0, 0, 2560))
        end

        if Toggles.FlyToggle.Value then
            Globals.FlyBody.Parent = RootPart
            Globals.FlyBody.Velocity = Functions.GetFlyVelocity() * Options.FlySpeed.Value
        else
            Globals.FlyBody.Parent = nil
        end

        local DoEyesBypass = (Toggles.BypassEyes.Value and Globals.IsEyes) or (Toggles.BypassLookman.Value and Globals.IsLookman)
        if DoEyesBypass then
            if Floor == "Fools" or Floor == "OldHotel" then
                RemotesFolder.MotorReplication:FireServer(0, (Globals.SpoofOffset == 200 and 65 or -65), 0, false)
            else
                RemotesFolder.MotorReplication:FireServer(-650)
            end
        end

        if RemotesFolder:FindFirstChild("Crouch") and tick() - Globals.LastCrouchFire > 0.1 then
            local IsCrouch = Functions.IsCrouching()
            if Toggles.CrouchSpoof.Value or Toggles.PositionSpoof.Value then IsCrouch = true end
            RemotesFolder.Crouch:FireServer(IsCrouch, true)
            Globals.LastCrouchFire = tick()
        end

        if tick() - Globals.LastAnimationCheck > 0.1 then
            local Sliding = false
            for _, Anim in Humanoid:GetPlayingAnimationTracks() do
                if Anim.Name == "Slide" then Sliding = true break end
            end
            Globals.Sliding = Sliding
            Globals.LastAnimationCheck = tick()
        end

        Character:SetAttribute("Sliding", Globals.Sliding)
        if Character:GetAttribute("Crouching") ~= Functions.IsCrouching() then
            Character:SetAttribute("Crouching", Functions.IsCrouching())
        end

        RayParams.FilterDescendantsInstances = { Character }
        local TPOffset = CFrame.new(Options.ThirdPersonOffsetX.Value, Options.ThirdPersonOffsetY.Value, Options.ThirdPersonOffsetZ.Value)
        local Direction = (Camera.CFrame * TPOffset).Position - Camera.CFrame.Position
        local WallResult = Services.Workspace:Spherecast(Camera.CFrame.Position, 0.2, Direction, RayParams)

        if Toggles.ThirdPersonToggle.Value then
            if Toggles.ThirdPersonWallCheck.Value and WallResult and WallResult.Instance.CanCollide then
                local NewPos = Camera.CFrame.Position + Direction.Unit * WallResult.Distance
                Camera.CFrame = CFrame.new(NewPos, NewPos + Camera.CFrame.LookVector)
            else
                Camera.CFrame = Camera.CFrame * TPOffset
            end
        end

        for _, Part in Globals.ThirdPersonParts do
            Part.Transparency = Toggles.ThirdPersonToggle.Value and 0 or 1
            Part.LocalTransparencyModifier = Toggles.ThirdPersonToggle.Value and 0 or 1
        end

        if Globals.SpectateEntity and Toggles.AutoClosetToggle.Value and Toggles.SpectateEntityToggle.Value then
            local Entity = Globals.SpectateEntity
            local CamPosition
            if Options.SpecateEntityMode.Value == "Player to Entity" then
                CamPosition = CFrame.lookAt(Character.Head.Position, Entity.PrimaryPart.Position)
            else
                CamPosition = CFrame.lookAt(Entity.PrimaryPart.Position, Character.Head.Position)
            end
            Camera.CFrame = CamPosition
        end

        if Toggles.FOVToggle.Value then
            if Main_Game then task.wait() Main_Game.fovtarget = Options.FieldOfView.Value else Camera.FieldOfView = Options.FieldOfView.Value end
        end

        if Toggles.RemoveClosetDelay.Value and Humanoid.MoveDirection ~= Vector3.zero
            and (CollisionPart.Anchored or RootPart.Anchored)
            and Character:GetAttribute("AnimatingClient") ~= true and Character:GetAttribute("Hiding") == true then
            RemotesFolder.CamLock:FireServer()
        end

        local ClosestPlayer = { Distance = math.huge, Object = nil }
        for _, Player in Services.Players:GetPlayers() do
            if Player.Character and Player ~= LocalPlayer then
                local Root = Player.Character:FindFirstChild("HumanoidRootPart")
                if Root then
                    local D = (Camera.CFrame.Position - Root.Position).Magnitude
                    if D < ClosestPlayer.Distance then ClosestPlayer.Distance = D ClosestPlayer.Object = Player end
                end
            end
        end
        if ClosestPlayer.Object and LocalPlayer:GetAttribute("Alive") ~= true then
            LocalPlayer:SetAttribute("CurrentRoom", ClosestPlayer.Object:GetAttribute("CurrentRoom"))
        end
    end)

    task.wait(1)
    if Toggles.PositionSpoof.Value and Floor ~= "Fools" and Floor ~= "OldHotel" then
        RootPart.CFrame = RootPart.CFrame * CFrame.new(0, -2.346, 0)
        Humanoid.HipHeight = 0.05
        RemotesFolder.Crouch:FireServer(true, true)
    end

    local Jam = Globals.MainUI.Initiator.Main_Game.Health:FindFirstChild("Jam")
    if Jam and Toggles.RemoveJamminMusic.Value then
        Jam.Volume = 0
        Globals.JamMuffle.Enabled = false
    end
end
-- ════════════════════════════════════════════════════════════════
-- PART 5: HandleObject, EntitySpawn, Prompts, AutoInteract, Unload, Init
-- ════════════════════════════════════════════════════════════════

Functions.HandleHidingTransparency = function(Model)
    local Parts = {}
    for _, Part in Model:GetDescendants() do
        if Part:IsA("BasePart") then
            Part:SetAttribute("Transparency_Old", Part.Transparency)
            table.insert(Parts, Part)
        end
        if Part.Name == "HiddenPlayer" then
            local HideConn = Part:GetPropertyChangedSignal("Value"):Connect(function()
                for _, P in Parts do
                    if P:GetAttribute("Transparency_Old") then
                        Services.TweenService:Create(P, TweenInfo.new(0.25, Enum.EasingStyle.Linear), {
                            Transparency = (Part.Value == Character and Toggles.TransparentHidingSpotsToggle.Value)
                                and Options.TransparentHidingSpotsSlider.Value
                                or P:GetAttribute("Transparency_Old")
                        }):Play()
                    end
                end
            end)
            table.insert(Connections, HideConn)
            Model.Destroying:Once(function()
                HideConn:Disconnect()
                local Pos = table.find(Connections, HideConn)
                if Pos then table.remove(Connections, Pos) end
            end)
        end
    end
end

Functions.HandleObject = function(Object)
    for _, Room in CurrentRooms:GetChildren() do
        if Object:IsDescendantOf(Room) then
            Object:SetAttribute("ParentRoom", tonumber(Room.Name))
            break
        end
        task.wait()
    end

    if Object.Parent == CurrentRooms then
        local FiredampVal = Object:GetAttribute("Firedamp")
        Object:SetAttribute("Firedamp_Old", FiredampVal ~= nil and FiredampVal or false)
        if Toggles.DisableFiredampEffect.Value then Object:SetAttribute("Firedamp", false) end
    end

    local Name = Object.Name

    if Name == "KeyObtain" then
        task.spawn(function()
            task.wait(0.5)
            if Object.Parent then
                if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Ключ от двери", Color = Options.ObjectiveESPColor.Value }, true) end
                table.insert(Objects.Objectives, Object)
            end
        end)
    elseif Name == "ElectricalKeyObtain" then
        task.spawn(function()
            task.wait(0.5)
            if Object.Parent then
                if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Электрический ключ", Color = Options.ObjectiveESPColor.Value }, true) end
                table.insert(Objects.Objectives, Object)
            end
        end)
    elseif Name == "TimerLever" then
        task.spawn(function()
            task.wait(0.5)
            if Object.Parent then
                Object:SetAttribute("AddTime", Object.TakeTimer.TextLabel.Text == "01:00" and 60 or 30)
                if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Рычаг времени [+" .. Object:GetAttribute("AddTime") .. " с]", Color = Options.ObjectiveESPColor.Value }, true) end
                Object:WaitForChild("Main").SoundToPlay.Played:Once(function()
                    Functions.RemoveESP(Object) Functions.BlacklistESP(Object)
                end)
                table.insert(Objects.Objectives, Object)
            end
        end)
    elseif Name == "Cellar" then
        if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Подвал", Color = Options.ObjectiveESPColor.Value }, true) end
        table.insert(Objects.Objectives, Object)
    elseif Name == "ArchivesFihTank" then
        if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Аквариум Fih", Color = Options.ObjectiveESPColor.Value }, true) end
        table.insert(Objects.Objectives, Object)
    elseif Name == "LiveHintBook" then
        if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Книга-подсказка", Color = Options.ObjectiveESPColor.Value }, true) end
        table.insert(Objects.Objectives, Object)
    elseif Name == "LiveBreakerPolePickup" then
        if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Выключатель электрощита", Color = Options.ObjectiveESPColor.Value }, true) end
        for _, Child in Object:GetChildren() do
            if Child.Name == "ActivateEventPrompt" and (Child.MaxActivationDistance == 5 or Child:GetAttribute("MaxActivationDistance_Old") == 5) then
                Child:Destroy()
            end
        end
        table.insert(Objects.Objectives, Object)
    elseif Name == "LibraryHintPaper" or Name == "PickupItem" then
        if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Лист-подсказка", Color = Options.ObjectiveESPColor.Value }, true) end
        table.insert(Objects.Objectives, Object)
    elseif Name == "MinesAnchor" then
        if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Якорь [" .. Object:WaitForChild("Sign").TextLabel.Text .. "]", Color = Options.ObjectiveESPColor.Value }, true) end
        Object:GetAttributeChangedSignal("Activated"):Once(function() Functions.RemoveESP(Object) Functions.BlacklistESP(Object) end)
        table.insert(Objects.Objectives, Object)
    elseif Name == "WaterPump" then
        if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object:WaitForChild("Wheel"), Text = "Водяной насос", Color = Options.ObjectiveESPColor.Value }, true) end
        Object:WaitForChild("Wheel").Sound.Played:Once(function()
            Object:SetAttribute("FeatherHub_Completed", true)
            Functions.RemoveESP(Object.Wheel) Functions.BlacklistESP(Object.Wheel)
        end)
        table.insert(Objects.Objectives, Object)
    elseif Name == "CringlePresent" then
        if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Подарок", Color = Options.ObjectiveESPColor.Value }, true) end
        Object:WaitForChild("ToolProp").Highlight:Destroy()
        table.insert(Objects.Objectives, Object)
    elseif Name == "LeverForGate" then
        if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Рычаг ворот", Color = Options.ObjectiveESPColor.Value }, true) end
        Object:WaitForChild("Main").SoundToPlay.Played:Once(function() Functions.RemoveESP(Object) Functions.BlacklistESP(Object) end)
        table.insert(Objects.Objectives, Object)
    elseif Name == "VineGuillotine" then
        if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object.Lever, Text = "Рычаг лозы", Color = Options.ObjectiveESPColor.Value }, true) end
        Object.Lever:WaitForChild("ActivateEventPrompt"):GetAttributeChangedSignal("Interactions"):Once(function() Functions.RemoveESP(Object) Functions.BlacklistESP(Object) end)
        table.insert(Objects.Objectives, Object)
    elseif Name == "MandrakeLive" then
        if Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value["Mandrake Hole"] then Functions.AddESP({ Object = Object.Hole, Text = "Нора мандрагоры", Color = Options.EntityESPColor.Value }, true) end
        table.insert(Objects.Entities, Object.Hole)
    elseif Name == "MinesGenerator" then
        task.spawn(function()
            task.wait(0.75)
            if Object.Parent then
                if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Генератор", Color = Options.ObjectiveESPColor.Value }, true) end
                Object:WaitForChild("Lever").Sound.Played:Once(function() Functions.RemoveESP(Object) Functions.BlacklistESP(Object) end)
                table.insert(Objects.Objectives, Object)
            end
        end)
    elseif Name == "FuseObtain" then
        if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Предохранитель генератора", Color = Options.ObjectiveESPColor.Value }, true) end
        Object:WaitForChild("Hitbox").FuseModel:GetPropertyChangedSignal("LocalTransparencyModifier"):Once(function() Functions.RemoveESP(Object) Functions.BlacklistESP(Object) end)
        table.insert(Objects.Objectives, Object)
    elseif Name == "MinesGateButton" then
        if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Кнопка ворот", Color = Options.ObjectiveESPColor.Value }, true) end
        Object.Parent:WaitForChild("MinesGate").Main.SoundOpen.Played:Once(function() Functions.RemoveESP(Object) Functions.BlacklistESP(Object) end)
        table.insert(Objects.Objectives, Object)
    elseif Name == "GardenGateButton" then
        if Toggles.ObjectiveESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Кнопка ворот", Color = Options.ObjectiveESPColor.Value }, true) end
        Object.Parent:WaitForChild("GardenGate").Collision.Sound.Played:Once(function() Functions.RemoveESP(Object) Functions.BlacklistESP(Object) end)
        table.insert(Objects.Objectives, Object)
    elseif Name == "Ladder" then
        if Toggles.LadderESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Лестница", Color = Options.LadderESPColor.Value }, true) end
        table.insert(Objects.Ladders, Object)
    elseif Name == "Door" and Object.Parent and tonumber(Object.Parent.Name) then
        local DoorParts = {}
        for _, Child in Object:GetChildren() do
            if Child.Name == "Door" and Child:IsA("BasePart") then table.insert(DoorParts, Child) end
        end
        if #DoorParts == 2 then
            local HighlightModel = Instance.new("Model", Object)
            HighlightModel.Name = "HighlightModel"
            Instance.new("Humanoid", HighlightModel).Name = "HighlightHumanoid"
            HighlightModel:SetAttribute("ParentRoom", tonumber(Object.Parent.Name))
            for _, DoorPart in DoorParts do
                local HP = Instance.new("Part", HighlightModel)
                HP.Transparency = 0.999 HP.Size = DoorPart.Size HP.CanCollide = false
                HP.CFrame = DoorPart.CFrame HP.Name = "HighlightPart" HP.Material = Enum.Material.Plastic
                HP:SetAttribute("ParentRoom", tonumber(Object.Parent.Name))
                local W = Instance.new("WeldConstraint", HP) W.Part0 = HP W.Part1 = DoorPart W.Enabled = true
            end
            table.insert(Objects.Doors, HighlightModel)
            if Toggles.DoorESPToggle.Value then Functions.AddESP({ Object = HighlightModel, Text = "Дверь " .. Functions.GetDoorNumber(Object), Color = Options.DoorESPColor.Value }, true) end
        else
            local Root = Object:WaitForChild("Door", 9e9)
            local HP = Instance.new("Part", Object)
            HP.Transparency = 0.999 HP.Size = Root.Size HP.CanCollide = false
            HP.CFrame = Root.CFrame HP.Name = "HighlightPart" HP.Material = Enum.Material.Plastic
            HP:SetAttribute("ParentRoom", tonumber(Object.Parent.Name))
            local W = Instance.new("WeldConstraint", HP) W.Part0 = HP W.Part1 = Root W.Enabled = true
            Instance.new("Humanoid", Object).Name = "HighlightHumanoid"
            table.insert(Objects.Doors, HP)
            if Toggles.DoorESPToggle.Value then Functions.AddESP({ Object = HP, Text = "Дверь " .. Functions.GetDoorNumber(Object), Color = Options.DoorESPColor.Value }, true) end
        end

        local LastDoorFire = tick()
        local DoorConn = Services.RunService.Heartbeat:Connect(function()
            if Object:FindFirstChild("Door") and Object:FindFirstChild("ClientOpen") then
                if LocalPlayer:DistanceFromCharacter(Object.Door.Position) < 75
                    and tick() - LastDoorFire > 0.1
                    and (Toggles.DoorReachToggle.Value or Functions.GetMinecart()) then
                    Object.ClientOpen:FireServer()
                    LastDoorFire = tick()
                end
            end
        end)
        Object.Destroying:Once(function() DoorConn:Disconnect() end)
        Object:WaitForChild("Door"):WaitForChild("Open").Played:Once(function() DoorConn:Disconnect() end)
        table.insert(Connections, DoorConn)

    elseif Name == "PathLights" then
        local ObjectsToHighlight = {}
        local PLConn = Object.ChildAdded:Connect(function(Child) table.insert(ObjectsToHighlight, Child) end)
        for _, Child in Object:GetChildren() do table.insert(ObjectsToHighlight, Child) end

        local function CreateSeekNode(Light)
            if Light.name ~= "SeekGuidingLight" or Light:GetAttribute("Highlighted") then return end
            Light:SetAttribute("Highlighted", true)
            local NewNode = Instance.new("Part")
            NewNode.Size = Vector3.one NewNode.Transparency = 1 NewNode.Parent = Globals.SeekNodesFolder
            NewNode.Anchored = true NewNode.CFrame = Light.CFrame NewNode.CanCollide = false NewNode.Name = "SeekLightNode"
            local PrevNode2 = PreviousNode or NewNode
            PreviousNode = NewNode
            local Beam = Instance.new("Beam")
            Beam.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Options.ShowSeekPathColor.Value), ColorSequenceKeypoint.new(1, Options.ShowSeekPathColor.Value) })
            Beam.FaceCamera = true Beam.Width0 = 0.2 Beam.Width1 = 0.2 Beam.Brightness = 10
            Beam.LightInfluence = 0 Beam.LightEmission = 0 Beam.Enabled = true
            local Vis = Toggles.ShowSeekPathToggle.Value and 0 or 1
            Beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, Vis), NumberSequenceKeypoint.new(1, Vis) })
            Beam.Parent = Globals.SeekNodesFolder
            local A0 = Instance.new("Attachment", NewNode) local A1 = Instance.new("Attachment", PrevNode2)
            Beam.Attachment0 = A0 Beam.Attachment1 = A1
            table.insert(Objects.SeekHighlights, Beam)
        end

        task.spawn(function()
            while task.wait() do
                local Light = table.remove(ObjectsToHighlight, 1)
                if Light then CreateSeekNode(Light) end
            end
        end)

        table.insert(Connections, PLConn)
        table.insert(Objects.PathLights, Object)
        Object.Destroying:Once(function() PLConn:Disconnect() end)
    elseif Name == "SeekMovingNewClone" then
        local Connection = Object.Destroying:Connect(function()
            for _, Folder in pairs(Objects.PathLights) do Folder:ClearAllChildren() end
            Globals.SeekNodesFolder:ClearAllChildren()
        end)
        table.insert(Connections, Connection)
    elseif Name == "Bridge" then
        for _, Child in Object:GetChildren() do
            if Child.Name == "PlayerBarrier" and Child.Size.Y == 2.75 and (Child.Rotation.X == 0 or Child.Rotation.X == 180) then
                local NewBridge = Child:Clone()
                NewBridge.CFrame = NewBridge.CFrame * CFrame.new(0, 0, -5)
                NewBridge.Name = FeatherHub.ESPLibrary:GenerateRandomString()
                NewBridge.Size = Vector3.new(NewBridge.Size.X, NewBridge.Size.Y, 11)
                NewBridge.Parent = Object
                NewBridge.CanCollide = Toggles.BypassSeekObstructions.Value
                NewBridge.Color = Color3.fromRGB(0, 255, 255)
                NewBridge.Transparency = Toggles.BypassSeekObstructions.Value and 0 or 1
                NewBridge.Material = Enum.Material.ForceField
                table.insert(Objects.SeekBridges, NewBridge)
            end
            task.wait()
        end
    elseif Name == "MinecartRig" then
        Globals.Minecart = Object
    elseif Name == "RunnerNodes" then
        local function IsBehind(Part1, Part2)
            local P1 = (Part1.CFrame + Part1.CFrame.LookVector).Position
            local P2 = (Part1.CFrame + Part1.CFrame.LookVector * -1).Position
            return (P1 - Part2.Position).Magnitude > (P2 - Part2.Position).Magnitude
        end
        local function GetDirection(Part1, Part2)
            local RightDist = Part1.CFrame.RightVector:Dot(Part1.Position - Part2.Position)
            if RightDist > 0.5 then return IsBehind(Part1, Part2) and "Right" or "Left" end
            if RightDist < -0.5 then return IsBehind(Part1, Part2) and "Left" or "Right" end
            return "Straight"
        end
        local function GetClosestNode(Node)
            local Best, BestDist = nil, math.huge
            local NodeID2 = tonumber(Node.Name:split("MinecartNode")[2])
            for _, OtherNode in Object:GetChildren() do
                local OtherID = tonumber(OtherNode.Name:split("MinecartNode")[2])
                if OtherNode ~= Node and OtherID and NodeID2 and OtherID > NodeID2 then
                    local D = (Node.Position - OtherNode.Position).Magnitude
                    if D < BestDist and OtherNode:GetAttribute("DistanceBlacklist") ~= true then BestDist = D Best = OtherNode end
                end
            end
            return Best
        end
        for _, Node in Object:GetChildren() do
            local NodeID = tonumber(Node.Name:split("MinecartNode")[2])
            if Node:GetAttribute("DeathType") then Node:SetAttribute("DistanceBlacklist", true) end
            for I = 1, 20 do
                local NextNode = NodeID and Object:FindFirstChild("MinecartNode" .. NodeID + I)
                if NextNode and NextNode:GetAttribute("DeathType") ~= nil then Node:SetAttribute("DistanceBlacklist", true) end
            end
            local PrevNode3 = NodeID and Object:FindFirstChild("MinecartNode" .. NodeID - 1)
            if PrevNode3 and PrevNode3:GetAttribute("ForceConnect") then Node:SetAttribute("DistanceBlacklist", nil) end
            task.wait()
        end
        for _, Node in Object:GetChildren() do
            if Node:GetAttribute("ForceConnect") then
                local NextNode = GetClosestNode(Node)
                if NextNode then
                    Node:SetAttribute("Turn", GetDirection(Node, NextNode))
                    table.insert(Objects.SeekNodes, Node)
                end
            end
            task.wait()
        end
    elseif Name == "EyestalkEndCutscene" then
        Object.Name = "_EyestalkEndCutscene"
    elseif Name == "DuckBoard" then
        table.insert(Objects.SeekDuckBoards, Object)
    elseif HidingSpotLabels[Name] or string.find(string.lower(Name), "hidingspot") then
        local Label = HidingSpotLabels[Name] or (string.find(string.lower(Name), "hidingspot") and "Укрытие" or nil)
        if Label and Toggles.HidingSpotESPToggle.Value then Functions.AddESP({ Object = Object, Text = Interface.Localization.TranslateText(Label), Color = Options.HidingSpotESPColor.Value }, true) end
        Functions.HandleHidingTransparency(Object)
        table.insert(Objects.HidingSpots, Object)
    elseif Object:FindFirstChild("HidingPrompt") or Object:FindFirstChild("HidePrompt") then
        Functions.HandleHidingTransparency(Object)
        table.insert(Objects.HidingSpots, Object)
    elseif Name == "Lava" then
        if Toggles.BypassKillbricks.Value then Object.CanTouch = false end
        table.insert(Objects.Obstructions, Object)
    elseif Name == "ScaryWall" then
        for _, Part in Object:GetDescendants() do
            if Part:IsA("BasePart") then
                Part.CanTouch = not Toggles.BypassSeekingWall.Value
                Part.CanCollide = not Toggles.BypassSeekingWall.Value
                local C1 = Part:GetPropertyChangedSignal("CanTouch"):Connect(function()
                    if Part.CanTouch == Toggles.BypassSeekingWall.Value then Part.CanTouch = not Toggles.BypassSeekingWall.Value end
                end)
                local C2 = Part:GetPropertyChangedSignal("CanCollide"):Connect(function()
                    if Part.CanCollide == Toggles.BypassSeekingWall.Value then Part.CanCollide = not Toggles.BypassSeekingWall.Value end
                end)
                table.insert(Connections, C1) table.insert(Connections, C2)
            end
        end
        table.insert(Objects.Obstructions, Object)
    elseif Name == "ChestBox" or Name == "ChestBoxLocked" then
        if Toggles.ChestESPToggle.Value then Functions.AddESP({ Object = Object, Text = Object:GetAttribute("Locked") and "Locked Chest" or "Chest", Color = Options.ChestESPColor.Value }, true) end
        table.insert(Objects.Chests, Object)
    elseif Name == "Toolbox" or Name == "Toolbox_Locked" then
        if Toggles.ChestESPToggle.Value then Functions.AddESP({ Object = Object, Text = Object:GetAttribute("Locked") and "Locked Toolbox" or "Toolbox", Color = Options.ChestESPColor.Value }, true) end
        table.insert(Objects.Chests, Object)
    elseif Name == "Chest_Vine" then
        if Toggles.ChestESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Сундук с лозой", Color = Options.ChestESPColor.Value }, true) end
        table.insert(Objects.Chests, Object)
    elseif Name == "Toolshed_Small" then
        if Toggles.ChestESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Сарай", Color = Options.ChestESPColor.Value }, true) end
        table.insert(Objects.Chests, Object)
    elseif Name == "Locker_Small_Locked" then
        if Toggles.ChestESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Запертый шкафчик с предметами", Color = Options.ChestESPColor.Value }, true) end
        table.insert(Objects.Chests, Object)
    elseif Name == "MouseHole" then
        if Toggles.ChestESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Мышиная нора", Color = Options.ChestESPColor.Value }, true) end
        table.insert(Objects.Chests, Object)
    elseif ItemNames[Name] and Object:FindFirstChild("ModulePrompt") then
        if Toggles.ItemESPToggle.Value then Functions.AddESP({ Object = Object, Text = ItemNames[Name], Color = Options.ItemESPColor.Value }, Object:GetAttribute("ParentRoom") ~= nil) end
        if Name == "LotusHolder" or Name == "LotusPetalPickup" then
            Object.Handle:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(function()
                FeatherHub.ESPLibrary:RemoveESP(Object) Functions.BlacklistESP(Object)
            end)
        end
        if Toggles.NotifyItemsToggle.Value and Options.NotifyItemList.Value[ItemNames[Name]] and Object.Parent.Name ~= "Drops" then
            if Toggles.NotifyItemsShowDistance.Value then
                Functions.Notify({ Title = "Появился предмет '" .. ItemNames[Name] .. "'.", Body = "До него '" .. math.round(LocalPlayer:DistanceFromCharacter(Object.PrimaryPart.Position)) .. "' студов." })
            else
                Functions.Notify({ Title = "Появился предмет '" .. ItemNames[Name] .. "'."})
            end
        end
        table.insert(Objects.Items, Object)
    elseif Name == "Green_Herb" then
        if Toggles.ItemESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Зелёная трава", Color = Options.ItemESPColor.Value }, true) end
        table.insert(Objects.Items, Object)
    elseif Name == "GoldPile" and Object:GetAttribute("GoldValue") then
        if Toggles.CurrencyESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Куча золота [" .. Object:GetAttribute("GoldValue") .. "]", Color = Options.CurrencyESPColor.Value }, true) end
        table.insert(Objects.Currency, Object)
    elseif Name == "StardustPickup" then
        if Toggles.CurrencyESPToggle.Value then Functions.AddESP({ Object = Object, Text = "Куча звёздной пыли", Color = Options.CurrencyESPColor.Value }, true) end
        table.insert(Objects.Currency, Object)
    elseif Name == "GiggleCeiling" then
        if Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value["Giggle"] then Functions.AddESP({ Object = Object, Text = "Giggle", Color = Options.EntityESPColor.Value }, true) end
        if Toggles.BypassGiggle.Value then Object:WaitForChild("Hitbox").CanTouch = false end
        table.insert(Objects.Entities, Object)
    elseif Name == "GloomPile" then
        if Toggles.BypassGloombatEggs.Value then
            for _, Part in Object:GetDescendants() do if Part:IsA("BasePart") then Part.CanTouch = false end end
        end
        local Connection = Object.DescendantAdded:Connect(function(Part) if Part:IsA("BasePart") then Part.CanTouch = false end end)
        if Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value["Gloombat Eggs"] then
            Functions.AddESP({ Object = Object, Text = "Яйца Gloombat", Color = Options.EntityESPColor.Value })
        end
        table.insert(Connections, Connection) table.insert(Objects.Entities, Object)
    elseif Name == "TriggerEventCollision" and Functions.CheckCompatability({"firetouchinterest"}) then
        if (Floor == "Fools" or Floor == "OldHotel") and Toggles.RemoveSeekTrigger.Value then
            task.spawn(function()
                while Object:IsDescendantOf(game) do
                    for _, Part in Object:GetChildren() do
                        if Part:IsA("BasePart") then
                            FeatherHub.Environment.firetouchinterest(RootPart, Part, 0) task.wait()
                            FeatherHub.Environment.firetouchinterest(RootPart, Part, 1)
                        end
                    end
                    task.wait()
                end
            end)
        end
        table.insert(Objects.EventTriggers, Object)
    elseif Name == "DoorFake" or Name == "FakeDoor" then
        if Object.Parent and Object:FindFirstChild("Hidden") then
            if Toggles.BypassDupe.Value then
                Object:WaitForChild("Hidden").CanTouch = false
                local Lock = Object:FindFirstChild("Lock")
                if Lock and Lock:FindFirstChild("UnlockPrompt") then Lock.UnlockPrompt.Enabled = false end
            end
            if Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value["Dupe"] then
                Functions.AddESP({ Object = Object, Text = "Dupe", Color = Options.EntityESPColor.Value }, true)
            end
            table.insert(Objects.Entities, Object)
        end
    elseif Name == "SideroomSpace" then
        if Toggles.BypassVacuum.Value then
            Object:WaitForChild("Collision").CanCollide = true
            Object:WaitForChild("Collision").CanTouch = false
        end
        table.insert(Objects.Entities, Object)
    elseif Name == "Snare" then
        if Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value["Snare"] then Functions.AddESP({ Object = Object, Text = "Snare", Color = Options.EntityESPColor.Value }, true) end
        for _, Part in Object:GetDescendants() do if Part:IsA("BasePart") then Part.CanTouch = not Toggles.BypassSnare.Value end end
        local Connection = Object.DescendantAdded:Connect(function(Part) if Part:IsA("BasePart") then Part.CanTouch = not Toggles.BypassSnare.Value end end)
        table.insert(Connections, Connection) table.insert(Objects.Entities, Object)
        if Object:FindFirstChild("Snare") then
            Object:WaitForChild("Snare"):WaitForChild("Roots").Transparency = 1
            Object:WaitForChild("Snare"):WaitForChild("SnareBase").Transparency = 1
        end
        if Object:FindFirstChild("Void") then
            Object.Void.Transparency = 0 Object.Void.Color = Color3.fromRGB(76, 67, 55)
        end
    elseif Name == "Seek_Arm" or Name == "ChandelierObstruction" then
        for _, Part in Object:GetDescendants() do
            if Part:IsA("BasePart") then
                Part.CanTouch = not Toggles.BypassSeekObstructions.Value
                table.insert(Objects.SeekObstructions, Part)
            end
        end
    elseif Name == "SeekFloodline" then
        Object.CanCollide = Toggles.BypassSeekObstructions.Value
        local FloodConn = Object:GetPropertyChangedSignal("CanCollide"):Connect(function()
            if Object.CanCollide ~= Toggles.BypassSeekObstructions.Value then Object.CanCollide = Toggles.BypassSeekObstructions.Value end
        end)
        Object.Destroying:Once(function() FloodConn:Disconnect() end)
        table.insert(Objects.SeekObstructions, Object)
    elseif Object:GetAttribute("RawName") and Object:GetAttribute("RawName"):find("Halt") or Object:GetAttribute("Shade") == true then
        if Toggles.NotifyEntities.Value and Options.EntityList.Value["Halt"] then
            Functions.Notify({ Title = "Сущность 'Halt' появится в следующей комнате.", Image = EntityIcons["Halt"] })
            if Toggles.EntityChatToggle.Value then Functions.SendChat("Halt next room!") end
        end
        local HaltLogConn
        HaltLogConn = Services.LogService.MessageOut:Connect(function(Message)
            if Message == "client teleporting" then
                if Globals.AnticheatDisabled then
                    Globals.AnticheatDisabled = false
                    Functions.Notify({ Title = "Античит снова включён.", Body = "Взаимодействуйте с лестницей, чтобы снова его отключить." })
                end
                HaltLogConn:Disconnect()
            end
        end)
    elseif Name == "BananaPeel" then
        if Toggles.BypassBanana.Value then Object.CanTouch = false end
        table.insert(Objects.Entities, Object)
    elseif Name == "JeffTheKiller" then
        if Toggles.BypassJeff.Value then
            for _, Part in Object:GetDescendants() do
                if Part:IsA("BasePart") then Part.CanCollide = false Part.CanTouch = false end
            end
            Object:WaitForChild("Humanoid").Health = 0
        end
    elseif Name == "GrumbleRig" then
        if Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value["Grumble"] then Functions.AddESP({ Object = Object, Text = "Grumble", Color = Options.EntityESPColor.Value }, true) end
        table.insert(Objects.Entities, Object)
    elseif Name == "LiveEntityBramble" then
        if Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value["Bramble"] then Functions.AddESP({ Object = Object, Text = "Bramble", Color = Options.EntityESPColor.Value }, true) end
        table.insert(Objects.Entities, Object)
    elseif Name == "Groundskeeper" then
        if Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value["Groundskeeper"] then Functions.AddESP({ Object = Object, Text = "Groundskeeper", Color = Options.EntityESPColor.Value }, true) end
        if Toggles.NotifyEntities.Value and Options.EntityList.Value["Groundskeeper"] then
            local ED = Entities["Groundskeeper"]
            Functions.Notify({ Title = ED.NotifyMessage.Title, Body = ED.NotifyMessage.Body, Image = EntityIcons["Groundskeeper"] })
        end
        table.insert(Objects.Entities, Object)
    elseif Name == "Figure" or Name == "FigureRig" or Name == "FigureRagdoll" then
        for _, Part in Object:GetDescendants() do if Part:IsA("BasePart") then Part.CanTouch = false end end
        if Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value["Figure"] then Functions.AddESP({ Object = Object, Text = "Figure", Color = Options.EntityESPColor.Value }, true) end
        table.insert(Objects.Entities, Object)
        if Toggles.RemoveFigure.Value and Functions.CheckCompatability({"isnetworkowner"}) then
            if Floor == "Mines" then
                for _, Part in Object:GetDescendants() do
                    if Part:IsA("BasePart") then
                        task.spawn(function()
                            if FeatherHub.Environment.isnetworkowner(Part) then Part.Position = Vector3.new(-49999, -49999, -49999) end
                        end)
                    end
                end
            elseif Floor == "OldHotel" or Floor == "Fools" then
                CurrentRooms.ChildAdded:Wait()
                for _, Part in Object:GetDescendants() do
                    if Part:IsA("BasePart") then
                        Part.CanCollide = false
                        task.spawn(function()
                            while FeatherHub.Environment.isnetworkowner(Part) do
                                Part.Position = Vector3.new(math.random(-29999,29999), math.random(-29999,29999), math.random(-29999,29999))
                                task.wait()
                            end
                        end)
                    end
                end
            end
        end
    elseif (Name == "ThingToOpen" or Name == "MovingDoor") and (Floor == "Fools" or Floor == "OldHotel")
        or Name == "Wax_Door" and Floor == "Fools" then
        Object:SetAttribute("OriginalPosition", Object:GetPivot())
        local ToggleMap = { ThingToOpen = "RemoveBasementGate", MovingDoor = "RemovePaintingsDoor", Wax_Door = "RemoveSkeletonDoor" }
        if ToggleMap[Name] and Toggles[ToggleMap[Name]].Value then Object:PivotTo(CFrame.new(-10000, -10000, -10000)) end
        table.insert(Objects.Obstructions, Object)
    elseif Name == "ElevatorBreaker" then
        if Toggles.AutoBreakerBox.Value and not Globals.BreakerBoxNotified then
            Functions.Notify({ Title = "Взаимодействуйте с электрощитом.", Body = "Головоломка будет решена автоматически." })
            Globals.BreakerBoxNotified = true
        end
        Connections.BreakerConnection = Object:WaitForChild("SurfaceGui").Frame.Code:GetPropertyChangedSignal("Text"):Connect(function()
            if Toggles.AutoBreakerBox.Value then
                if not Globals.BreakerBoxStartNotified and (Floor == "Fools" or Floor == "OldHotel") then
                    Functions.Notify({ Title = "Попытка решить электрощит.", Body = "Подождите." })
                    Globals.BreakerBoxStartNotified = true
                end
                RemotesFolder.EBF:FireServer()
            end
            Globals.BreakerBoxInteracted = true
        end)
    elseif Name == "ElevatorCar" then
        local ElevConn = Object.DescendantAdded:Connect(function(Desc)
            if Toggles.AutoBreakerBox.Value and Desc.Name == "TouchInterest" and not Globals.BreakerBoxFinishedNotified then
                Functions.Notify({ Title = "Электрощит успешно решён.", Body = "Попробуйте пройти к лифту!" })
                Globals.BreakerBoxFinishedNotified = true
            end
        end)
        Object.Destroying:Once(function() ElevConn:Disconnect() end)
    elseif Object.ClassName == "ProximityPrompt" and not Object:GetAttribute("FakePrompt") then
        if Object:HasTag("DisableWhenEnabledOnClient") then Object:RemoveTag("DisableWhenEnabledOnClient") end
        Object:SetAttribute("HoldDuration_Old", Object.HoldDuration)
        Object:SetAttribute("RequiresLineOfSight_Old", Object.RequiresLineOfSight)
        Object:SetAttribute("MaxActivationDistance_Old", Object.MaxActivationDistance)
        if Toggles.InstantPrompts.Value then Object.HoldDuration = 0 end
        if Toggles.PromptClip.Value then Object.RequiresLineOfSight = false end
        Object.MaxActivationDistance = Object:GetAttribute("MaxActivationDistance_Old") * Options.PromptReachSlider.Value

        local LockPromptNames = { UnlockPrompt=true, SkullPrompt=true, LockPrompt=true, ThingToEnable=true, FusesPrompt=true }

        if Functions.CheckCompatability({"fireproximityprompt"}) and Floor ~= "OldHotel" and Floor ~= "Fools" then
            local IsLockPrompt = LockPromptNames[Object.Name]
                or (Object.Parent and Object.Parent:GetAttribute("Locked") == true)
                or (Object.Parent and Object.Parent.Parent and Object.Parent.Parent.Name == "Locker_Small_Locked" and Object.Name == "ActivateEventPrompt")

            if IsLockPrompt then
                local FakePrompt = Object:Clone()
                FakePrompt:SetAttribute("FakePrompt", true)
                task.wait()
                FakePrompt.Parent = Object.Parent
                FakePrompt:SetAttribute("HoldDuration_Old", Object:GetAttribute("HoldDuration_Old"))
                FakePrompt:SetAttribute("RequiresLineOfSight_Old", Object:GetAttribute("RequiresLineOfSight_Old"))
                FakePrompt:SetAttribute("MaxActivationDistance_Old", Object:GetAttribute("MaxActivationDistance_Old"))
                FakePrompt.HoldDuration = Object.HoldDuration
                FakePrompt.RequiresLineOfSight = Object.RequiresLineOfSight
                FakePrompt.MaxActivationDistance = Object.MaxActivationDistance
                if Toggles.InstantPrompts.Value then FakePrompt.HoldDuration = 0 end
                if Toggles.PromptClip.Value then FakePrompt.RequiresLineOfSight = false end
                FakePrompt.MaxActivationDistance = FakePrompt:GetAttribute("MaxActivationDistance_Old") * Options.PromptReachSlider.Value
                FakePrompts[FakePrompt] = Object
                pcall(function() Object.Parent = Globals.PromptContainer end)
                local FPEnabledConn = Object:GetPropertyChangedSignal("Enabled"):Connect(function() FakePrompt.Enabled = Object.Enabled end)
                Object:GetPropertyChangedSignal("ActionText"):Once(function()
                    Object.Parent = FakePrompt.Parent FakePrompt:Destroy() FPEnabledConn:Disconnect()
                end)
                Object.Destroying:Once(function() FakePrompt:Destroy() FPEnabledConn:Disconnect() end)
                table.insert(Connections, FPEnabledConn)
                table.insert(Objects.Prompts, FakePrompt)
                FakePrompt.Enabled = false task.wait() FakePrompt.Enabled = Object.Enabled
            end
        end
        table.insert(Objects.Prompts, Object)
    elseif Name == "Padlock" then
        local PadlockConn = Services.RunService.Heartbeat:Connect(function()
            if Object.PrimaryPart then
                local Distance = LocalPlayer:DistanceFromCharacter(Object.PrimaryPart.Position)
                if Toggles.AutoUnlockPadlockToggle.Value then
                    local Code = Functions.GetLibraryCode()
                    if Code and tonumber(Code) and Distance < Options.AutoUnlockPadlockSlider.Value then
                        RemotesFolder.PL:FireServer(Code)
                    end
                end
                if Toggles.AutoLibraryGuessCode.Value and LatestRoom.Value == 50 then
                    local Code = Functions.GetRandomCode()
                    if Code then RemotesFolder.PL:FireServer(Code) end
                end
            end
        end)
        Object.Destroying:Once(function() PadlockConn:Disconnect() end)
    end
end

-- ════════════════════════════════════════════════════════════════
-- PROMPT ANIMATION FIXER
-- ════════════════════════════════════════════════════════════════
Connections.PromptAnimationFixer1 = Services.ProximityPromptService.PromptButtonHoldBegan:Connect(function(Object)
    if not Object:GetAttribute("FakePrompt") then return end
    local ToolNames = { "Lockpick","Shears","SkeletonKey","Key","GeneratorFuse","KeyElectrical","KeyBackdoor","KeyIron", "Multitool" }
    local AnimateToolNames = { "Lockpick","Shears","SkeletonKey","Key","KeyElectrical","KeyBackdoor","KeyIron", "Multitool" }
    local Tool
    for _, N in ToolNames do Tool = Character:FindFirstChild(N) if Tool then break end end
    local Prompt = Object
    local LockPromptNames = { UnlockPrompt=true, SkullPrompt=true, LockPrompt=true, ThingToEnable=true, FusesPrompt=true }
    local IsLockPrompt = LockPromptNames[Object.Name]
        or (Object.Parent and Object.Parent:GetAttribute("Locked") == true)
        or (Object.Parent and Object.Parent.Parent and Object.Parent.Parent.Name == "Locker_Small_Locked" and Object.Name == "ActivateEventPrompt")
    if IsLockPrompt then
        if Options.AutoInteractIgnoreList.Value["Locks"] then return end
        local KeyItems = { "Key","GeneratorFuse","KeyBackdoor","KeyElectrical","KeyIron","Lockpick","SkeletonKey","Shears","Multitool" }
        local OffhandKeyItems = { "Key","GeneratorFuse","KeyElectrical","KeyIron" }
        local HasKey = false
        for _, K in KeyItems do if Functions.HasItem(K, true) then HasKey = true break end end
        for _, K in OffhandKeyItems do if Functions.HasItem(K) then HasKey = true break end end
        if not HasKey then return end
    end
    if Prompt.Parent.Name == "CuttableVines" and not Functions.HasItem("Shears", true) and not Functions.HasItem("Multitool", true)
        or Prompt.Parent.Name == "Chest_Vine" and not Functions.HasItem("Shears", true) and not Functions.HasItem("Multitool", true)
        or Prompt.Parent.Name == "Cellar" and not Functions.HasItem("Shears", true) and not Functions.HasItem("Multitool", true) then return end
    if Prompt.Parent.Name == "SkullLock" and not Functions.HasItem("SkeletonKey", true) then return end
    if Prompt.Parent.Name == "Lock1" and not Functions.HasItem("Lockpick", true) and not Functions.HasItem("Multitool", true)
        or Prompt.Parent.Name == "Lock2" and not Functions.HasItem("Lockpick", true) and not Functions.HasItem("Multitool", true) then return end
    if Functions.HasItem("Shears", true) and IsLockPrompt and Prompt.Parent.Name ~= "CuttableVines" and Prompt.Parent.Name ~= "Chest_Vine" and Prompt.Parent.Name ~= "Cellar" then return end
    if Tool and table.find(AnimateToolNames, Tool.Name) and Globals.UseAnimation then
        Globals.UseAnimationBreak:Stop() Globals.UseAnimation:Stop() Globals.UseAnimation:Play()
        if Tool.Name == "Shears" then Tool:WaitForChild("Handle"):WaitForChild("sound_prompt"):Play() end
    end
end)

-- ════════════════════════════════════════════════════════════════
-- OBJECT QUEUE
-- ════════════════════════════════════════════════════════════════
Globals.ObjectQueue = {}
local AllowedInstances = {
    Lava=true, GoldPile=true, KeyObtain=true, Drakobloxxer=true, FuseObtain=true,
    MinesGenerator=true, JeffTheKiller=true, Snare=true, FakeDoor=true, DoorFake=true, SideroomSpace=true,
    ChestBox=true, ChestBoxLocked=true, Chest_Vine=true, Locker_Small_Locked=true, Toolbox=true,
    Toolbox_Locked=true, Wardrobe=true, ["Wardrobe-FOOLS26"]=true, Toolshed=true, Toolshed_Small=true,
    Bed=true, MinesAnchor=true, Double_Bed=true, RetroWardrobe=true, Backdoor_Wardrobe=true,
    Rooms_Locker=true, Rooms_Locker_Fridge=true, Locker_Large=true, FigureRig=true, FigureRagdoll=true,
    TimerLever=true, Lever=true, Seek_Arm=true, ChandelierObstruction=true, ScaryWall=true, Ladder=true,
    CircularVent=true, Dumpster=true, SquareGrate=true, TriggerEventCollision=true, GrumbleRig=true,
    GiggleCeiling=true, MinesGateButton=true, ElectricalKeyObtain=true, LibraryHintPaper=true,
    WaterPump=true, CringlePresent=true, Wheel=true, PickupItem=true, LiveHintBook=true,
    LiveBreakerPolePickup=true, LeverForGate=true, GloomPile=true, SeekFloodline=true, Door=true,
    Green_Herb=true, Bridge=true, MouseHole=true, BananaPeel=true, NannerPeel=true, PowerupPad=true,
    IndustrialGate=true, CollisionFloor=true, ElevatorCar=true, Wax_Door=true, ThingToOpen=true,
    MovingDoor=true, StardustPickup=true, Hole=true, Groundskeeper=true, MandrakeLive=true,
    GardenGateButton=true, LotusPetalPickup=true, VineGuillotine=true, LiveEntityBramble=true, ArchivesFihTank=true,
    RiftSpawn=true, ElevatorBreaker=true, RunnerNodes=true, PathLights=true, DuckBoard=true,
    Padlock=true, EyestalkEndCutscene=true, MinecartRig=true, SeekMovingNewClone=true, Cellar=true
}

Functions.QueueObject = function(Object)
    if TimeShowerClone and Object:IsDescendantOf(TimeShowerClone) then return end
    local IsHidingSpot = typeof(Object.Name) == "string" and string.find(string.lower(Object.Name), "hidingspot")
    if not AllowedInstances[Object.Name] and not IsHidingSpot and Object.ClassName ~= "ProximityPrompt" and Object.Parent ~= CurrentRooms and not ItemNames[Object.Name] then return end
    table.insert(Globals.ObjectQueue, Object)
end

Globals.QueueDone = true
Connections.QueueConnection = Services.RunService.RenderStepped:Connect(function()
    local Object = table.remove(Globals.ObjectQueue, 1)
    if Object then Functions.HandleObject(Object) end
end)

for _, Object in Services.Workspace:GetDescendants() do
    task.spawn(function() Functions.QueueObject(Object) end)
end

Connections.InstanceHandler = Services.Workspace.DescendantAdded:Connect(function(Object)
    Functions.QueueObject(Object)
end)

-- ════════════════════════════════════════════════════════════════
-- PLAYER HANDLERS
-- ════════════════════════════════════════════════════════════════
for _, Player in Services.Players:GetPlayers() do
    if Player ~= LocalPlayer then
        if Player.Character and Toggles.PlayerESPToggle.Value then
            Functions.AddESP({ Object = Player.Character, Text = Player.Name, Color = Options.PlayerESPColor.Value })
        end
        local CharConn = Player.CharacterAdded:Connect(function(NewCharacter)
            if Toggles.PlayerESPToggle.Value then
                Functions.AddESP({ Object = NewCharacter, Text = Player.Name, Color = Options.PlayerESPColor.Value })
            end
        end)
        local DeadConn = Player:GetAttributeChangedSignal("Alive"):Connect(function()
            if Player:GetAttribute("Alive") ~= true and Player.Character then Functions.RemoveESP(Player.Character) end
        end)
        table.insert(Connections, CharConn) table.insert(Connections, DeadConn)
        Player.Destroying:Once(function() CharConn:Disconnect() DeadConn:Disconnect() end)
    end
end

Connections.PlayerHandler = Services.Players.PlayerAdded:Connect(function(Player)
    if Player == LocalPlayer then return end
    if Player.Character and Toggles.PlayerESPToggle.Value then
        Functions.AddESP({ Object = Player.Character, Text = Player.Name, Color = Options.PlayerESPColor.Value })
    end
    local CharConn = Player.CharacterAdded:Connect(function(NewCharacter)
        if Toggles.PlayerESPToggle.Value then
            Functions.AddESP({ Object = NewCharacter, Text = Player.Name, Color = Options.PlayerESPColor.Value })
        end
    end)
    local DeadConn = Player:GetAttributeChangedSignal("Alive"):Connect(function()
        if Player:GetAttribute("Alive") ~= true and Player.Character then Functions.RemoveESP(Player.Character) end
    end)
    table.insert(Connections, CharConn) table.insert(Connections, DeadConn)
    Player.Destroying:Once(function() CharConn:Disconnect() DeadConn:Disconnect() end)
end)

-- ════════════════════════════════════════════════════════════════
-- PROMPT FIRING SYSTEM
-- ════════════════════════════════════════════════════════════════
local PromptsToFire = {}
local PromptCooldown = {}

Functions.FirePrompt      = FeatherHub.Environment.fireproximityprompt
Functions.ForceFirePrompt = FeatherHub.Environment.fireproximityprompt

if not Functions.FirePrompt then
    Functions.FirePrompt = function(Prompt)
        if not Prompt:IsA("ProximityPrompt") or PromptCooldown[Prompt] or table.find(PromptsToFire, Prompt) or not Camera then return end
        table.insert(PromptsToFire, Prompt)
    end
    Functions.ForceFirePrompt = Functions.FirePrompt

    task.spawn(function()
        while task.wait() do
            local Prompt = table.remove(PromptsToFire, 1)
            if not Prompt then continue end
            PromptCooldown[Prompt] = true
            local OldDist = Prompt.MaxActivationDistance
            local OldEnable = Prompt.Enabled
            local OldParent = Prompt.Parent
            local OldHold = Prompt.HoldDuration
            local OldLOS = Prompt.RequiresLineOfSight
            Prompt.MaxActivationDistance = 99999
            Prompt.Enabled = true
            Prompt.HoldDuration = 0
            Prompt.RequiresLineOfSight = false
            local TempPart = Instance.new("Part")
            TempPart.Parent = Services.Workspace
            TempPart.CanCollide = false TempPart.CanQuery = false TempPart.CanTouch = false
            TempPart.Anchored = true TempPart.Transparency = 1
            TempPart.Size = Vector3.new(0.001, 0.001, 0.001)
            TempPart.Position = Camera.CFrame:ToWorldSpace(CFrame.new(0, 0, -0.1)).Position
            if not Prompt or not OldParent then TempPart:Destroy() PromptCooldown[Prompt] = nil continue end
            pcall(function() Prompt.Parent = TempPart end)
            local Shown, Fired = false, false
            local ShownConn = Services.ProximityPromptService.PromptShown:Connect(function(P) if P == Prompt then Shown = true end end)
            local FiredConn = Prompt.Triggered:Connect(function() Fired = true end)
            local T1 = 0
            while not Shown and T1 < 5 do T1 += 1 task.wait() end
            local T2 = 0
            while not Fired and T2 < 5 do
                Prompt:InputHoldBegin() Prompt:InputHoldEnd() T2 += 1 task.wait()
            end
            Prompt.MaxActivationDistance = OldDist
            Prompt.Enabled = OldEnable
            Prompt.HoldDuration = OldHold
            Prompt.RequiresLineOfSight = OldLOS
            pcall(function() Prompt.Parent = OldParent end)
            task.wait()
            PromptCooldown[Prompt] = nil
            TempPart:Destroy()
            ShownConn:Disconnect()
            FiredConn:Disconnect()
        end
    end)
end

-- ════════════════════════════════════════════════════════════════
-- AUTO INTERACT
-- ════════════════════════════════════════════════════════════════
local AutoInteractBlacklist = {
    HidePrompt=true, RiftPrompt=true, StarRiftPrompt=true, InteractPrompt=true, ClimbPrompt=true,
    DonatePrompt=true, DialoguePrompt=true, RevivePrompt=true, EnterPrompt=true, AnimatePrompt=true,
    ToolEventPrompt=true, Prompt=true, PropPrompt=true
}

local TriggerDebounce = false

local function GetHidingSpotModel(Prompt)
    if not Prompt or not Prompt.Parent then return false end
    local Model = Prompt.Parent
    while Model and not Model:IsA("Model") do Model = Model.Parent end
    if not Model then return nil end
    local Name = string.lower(Model.Name)
    if not string.find(Name, "hidingspot") and not string.find(Name, "hiding_spot") then return nil end
    return Model
end

local function HasHidePrompt(Model)
    return Model and (Model:FindFirstChild("HidePrompt") or Model:FindFirstChild("HidingPrompt")) ~= nil
end

local function IsHidingSpotPrompt(Prompt)
    if not Prompt or not Prompt.Parent then return false end
    if Prompt.Name ~= "HidePrompt" and Prompt.Name ~= "HidingPrompt" then return false end
    return HasHidePrompt(GetHidingSpotModel(Prompt))
end

Functions.TriggerPrompt = function(Prompt)
    if not Prompt or not Prompt.Parent then return end
    if Character:GetAttribute("Hiding") == true then return end
    local HidingSpot = GetHidingSpotModel(Prompt)
    if HidingSpot and Prompt.Name ~= "InteractPrompt" then return end
    local IsHidingSpotInteractPrompt = HidingSpot and Prompt.Name == "InteractPrompt"
    if AutoInteractBlacklist[Prompt.Name] and not IsHidingSpotPrompt(Prompt) and not IsHidingSpotInteractPrompt then return end
    if (Prompt.Name == "HidePrompt" or Prompt.Name == "HidingPrompt") and not IsHidingSpotPrompt(Prompt) then return end
    if (Prompt.Name == "HidePrompt" or Prompt.Name == "HidingPrompt" or IsHidingSpotPrompt(Prompt)) then
        if not Toggles.AutoClosetToggle.Value then return end
        local Entity = Functions.GetNearestEntity(true, Options.AutoClosetEntityList.Value)
        if not Entity then return end
        local EntityDistance = LocalPlayer:DistanceFromCharacter(Entity.PrimaryPart.Position)
        if EntityDistance > (EntityDistances[Entity.Name] or 150) then return end
    end
    if TriggerDebounce then return end

    local ParentItem = Functions.HasItem(Prompt.Parent.Name)
    if ParentItem and ParentItem:GetAttribute("Durability") and ParentItem:GetAttribute("DurabilityMax")
        and ParentItem:GetAttribute("Durability") >= ParentItem:GetAttribute("DurabilityMax") then return end

    local LockPromptNames = { UnlockPrompt=true, SkullPrompt=true, LockPrompt=true, ThingToEnable=true, FusesPrompt=true }
    local IsLockPrompt = LockPromptNames[Prompt.Name]
        or (Prompt.Parent and Prompt.Parent:GetAttribute("Locked") == true)
        or (Prompt.Parent and Prompt.Parent.Parent and Prompt.Parent.Parent.Name == "Locker_Small_Locked" and Prompt.Name == "ActivateEventPrompt")

    if IsLockPrompt then
        if Options.AutoInteractIgnoreList.Value["Locks"] then return end
        local KeyItems = { "Key","GeneratorFuse","KeyBackdoor","KeyElectrical","KeyIron","Lockpick","SkeletonKey","Shears","Multitool" }
        local OffhandKeyItems = { "Key","GeneratorFuse","KeyElectrical","KeyIron" }
        local HasKey = false
        for _, K in KeyItems do if Functions.HasItem(K, true) then HasKey = true break end end
        for _, K in OffhandKeyItems do if Functions.HasItem(K) then HasKey = true break end end
        if not HasKey then return end
    end

    if Prompt.Parent.Name == "CuttableVines" and not Functions.HasItem("Shears", true) and not Functions.HasItem("Multitool", true)
        or Prompt.Parent.Name == "Chest_Vine" and not Functions.HasItem("Shears", true) and not Functions.HasItem("Multitool", true)
        or Prompt.Parent.Name == "Cellar" and not Functions.HasItem("Shears", true) and not Functions.HasItem("Multitool", true) then return end
    if Prompt.Parent.Name == "SkullLock" and not Functions.HasItem("SkeletonKey", true) then return end
    if Prompt.Parent.Name == "Lock1" and not Functions.HasItem("Lockpick", true) and not Functions.HasItem("Multitool", true)
        or Prompt.Parent.Name == "Lock2" and not Functions.HasItem("Lockpick", true) and not Functions.HasItem("Multitool", true) then return end
    if Functions.HasItem("Shears", true) and IsLockPrompt and Prompt.Parent.Name ~= "CuttableVines" and Prompt.Parent.Name ~= "Chest_Vine" and Prompt.Parent.Name ~= "Cellar" then return end

    if Prompt.Parent.Name == "GlitchCube" and Options.AutoInteractIgnoreList.Value["Glitch Fragments"] then return end
    if (Prompt.Parent.Name == "KeyObtain" and (Functions.HasItem("Key") or Functions.HasItem("KeyBackdoor")))
        or (Prompt.Parent.Name == "ElectricalKeyObtain" and Functions.HasItem("KeyElectrical")) then return end
    if Prompt:IsDescendantOf(Drops) and Options.AutoInteractIgnoreList.Value["Dropped Items"] then return end
    if Prompt.Parent.Name == "TrackLever" then return end
    if Prompt.Name == "ActivateEventPrompt" and (Prompt.ActionText == "Close"
        or Prompt.Parent.Name == "ElevatorBreaker"
        or (Prompt.Parent.Parent and Prompt.Parent.Parent.Name == "IndustrialGate")) then return end
    if Prompt.Name == "ActivateEventPrompt" and (Prompt.Parent.Name == "Padlock" or Prompt.Parent.Name == "MinesAnchor") then return end
    if Prompt.Parent.Name == "LeverForGate" and Prompt:GetAttribute("Interactions") then return end
    if Prompt.Parent.Parent and (Prompt.Parent.Parent.Name == "DoorFake" or Prompt.Parent.Parent.Name == "FakeDoor") then return end
    if Prompt.Parent:GetAttribute("JeffShop") and Options.AutoInteractIgnoreList.Value["Jeff Items"] then return end
    if Prompt:GetAttribute("AutoInteractIgnore") then return end
    if Prompt.Name == "PushPrompt" and Options.AutoInteractIgnoreList.Value["Minecarts"] then return end
    if (Prompt.Parent.Name == "GoldPile" or Prompt.Parent.Name == "StardustPickup") and Options.AutoInteractIgnoreList.Value["Currency"] then return end

    if Prompt.Parent.Name == "Bandage" then
        local BPack = Functions.HasItem("BandagePack")
        if Humanoid.Health >= Humanoid.MaxHealth and not BPack then return end
        if BPack and BPack:GetAttribute("Durability") >= BPack:GetAttribute("DurabilityMax") then return end
    end

    if Prompt.Parent.Name == "Battery" then
        local Tool = Character:FindFirstChildOfClass("Tool")
        local BPack = Functions.HasItem("BatteryPack")
        if not Tool and not BPack then return end
        if Tool and Tool:GetAttribute("LightSource") then
            if Tool:GetAttribute("Durability") and Tool:GetAttribute("DurabilityMax")
                and Tool:GetAttribute("Durability") > Tool:GetAttribute("DurabilityMax") then return end
        elseif not BPack then return end
        if BPack and BPack:GetAttribute("Durability") >= BPack:GetAttribute("DurabilityMax") then return end
    end

    if Prompt.Name == "HerbPrompt" then
        local Effects = Globals.MainUI.MainFrame.Healthbar:FindFirstChild("Effects")
        if Effects and Effects.HerbGreenEffect.Visible then return end
    end

    if (Prompt.Parent.Name == "LibraryHintPaper" or Prompt.Parent.Name == "PickupItem") and (Functions.HasItem("LibraryHintPaper") or Functions.HasItem("LibraryHintPaperHard")) then return end
    if Prompt.Parent.Name == "AlarmClock" and Functions.HasItem("AlarmClock") then return end
    if Prompt.Parent.Name == "KeyObtainFake" or Prompt.Parent.Name == "TithingPlate" then return end

    -- archives
    if Prompt.Parent.Name == "ArchivesStorageBox" then return end
    if Prompt.Parent.Name == "Briefcase" then return end
    if Prompt.Name == "SinkPrompt" or Prompt.Parent.Name == "Faucet" then return end
    if Prompt.Parent.Name == "PaperPlanePickup" or Prompt.Parent.Name == "PaperPlane" then return end
    if Prompt.Name == "ManualOpenPrompt" or Prompt.Name == "EntryPrompt" then return end
    if Prompt.Parent.Parent.Name == "ArchivesLargePrinter" then return end
    if Prompt.Name == "TrashcanPrompt" then return end
    if Prompt.Parent.Name == "Keyboard" then return end
    if Prompt.Name == "CartPrompt" or Prompt.Parent.Parent.Name == "ArchivesOfficeChair" then return end
    if Prompt.Parent.Name == "ArchivesTerminal" then return end
    if Prompt.Name == "VendorPrompt" then return end
    if Prompt.Parent.Name == "SeatPart" or Prompt.Name == "SeatPrompt" then return end

    Functions.FirePrompt(Prompt)
    TriggerDebounce = true
    if Floor == "OldHotel" then task.wait() end
    TriggerDebounce = false
end

Globals.LastAutoInteractFire = tick()
Connections.AutoInteract = Services.RunService.Heartbeat:Connect(function()
    local Active = Toggles.AutoInteractToggle.Value or Options.AutoInteractKeybind:GetState()
    if not Active then return end
    if tick() - Globals.LastAutoInteractFire < 1/60 then return end
    for _, Prompt in Objects.Prompts do
        if Prompt:GetAttribute("ParentRoom") and tonumber(Prompt:GetAttribute("ParentRoom")) ~= tonumber(LocalPlayer:GetAttribute("CurrentRoom")) then continue end
        if Prompt.Parent and (Prompt.Parent:IsA("BasePart") or Prompt.Parent:IsA("Model")) then
            local Distance
            if Prompt.Parent:IsA("BasePart") then
                Distance = LocalPlayer:DistanceFromCharacter(Prompt.Parent.Position)
            else
                Distance = LocalPlayer:DistanceFromCharacter(Prompt.Parent:GetPivot().Position)
            end
            if Distance <= Prompt.MaxActivationDistance and Prompt.Enabled
                or Distance <= Prompt.MaxActivationDistance and Prompt.Name == "LongPushPrompt"
                or Distance <= Prompt.MaxActivationDistance and Prompt.Name == "BigPropPrompt" then
                task.spawn(Functions.TriggerPrompt, Prompt)
            end
        end
    end
    Globals.LastAutoInteractFire = tick()
end)

-- ════════════════════════════════════════════════════════════════
-- INFINITE ITEMS HANDLER
-- ════════════════════════════════════════════════════════════════
Connections.InfiniteItemsHandler = Services.ProximityPromptService.PromptTriggered:Connect(function(Object)
    if not Object:GetAttribute("FakePrompt") then return end
    local ToolNames = { "Lockpick","Shears","SkeletonKey","Key","GeneratorFuse","KeyElectrical","KeyBackdoor","KeyIron", "Multitool" }
    local AnimateToolNames = { "Lockpick","Shears","SkeletonKey","Key","KeyElectrical","KeyBackdoor","KeyIron", "Multitool" }
    local Tool
    for _, N in ToolNames do Tool = Character:FindFirstChild(N) if Tool then break end end
    local Prompt = Object
    local LockPromptNames = { UnlockPrompt=true, SkullPrompt=true, LockPrompt=true, ThingToEnable=true, FusesPrompt=true }
    local IsLockPrompt = LockPromptNames[Object.Name]
        or (Object.Parent and Object.Parent:GetAttribute("Locked") == true)
        or (Object.Parent and Object.Parent.Parent and Object.Parent.Parent.Name == "Locker_Small_Locked" and Object.Name == "ActivateEventPrompt")
    if IsLockPrompt then
        if Options.AutoInteractIgnoreList.Value["Locks"] then return end
        local KeyItems = { "Key","GeneratorFuse","KeyBackdoor","KeyElectrical","KeyIron","Lockpick","SkeletonKey","Shears","Multitool" }
        local OffhandKeyItems = { "Key","GeneratorFuse","KeyElectrical","KeyIron" }
        local HasKey = false
        for _, K in KeyItems do if Functions.HasItem(K, true) then HasKey = true break end end
        for _, K in OffhandKeyItems do if Functions.HasItem(K) then HasKey = true break end end
        if not HasKey then return end
    end
    if Prompt.Parent.Name == "CuttableVines" and not Functions.HasItem("Shears", true) and not Functions.HasItem("Multitool", true)
        or Prompt.Parent.Name == "Chest_Vine" and not Functions.HasItem("Shears", true) and not Functions.HasItem("Multitool", true)
        or Prompt.Parent.Name == "Cellar" and not Functions.HasItem("Shears", true) and not Functions.HasItem("Multitool", true) then return end
    if Prompt.Parent.Name == "SkullLock" and not Functions.HasItem("SkeletonKey", true) then return end
    if Prompt.Parent.Name == "Lock1" and not Functions.HasItem("Lockpick", true) and not Functions.HasItem("Multitool", true)
        or Prompt.Parent.Name == "Lock2" and not Functions.HasItem("Lockpick", true) and not Functions.HasItem("Multitool", true) then return end
    if Functions.HasItem("Shears", true) and IsLockPrompt and Prompt.Parent.Name ~= "CuttableVines" and Prompt.Parent.Name ~= "Chest_Vine" and Prompt.Parent.Name ~= "Cellar" then return end

    if Tool and table.find(AnimateToolNames, Tool.Name) and Globals.UseAnimation and Globals.UseAnimationBreak then
        Globals.UseAnimation:Stop() Globals.UseAnimationBreak:Stop() Globals.UseAnimationBreak:Play()
        if Tool.Name == "Shears" then Tool:WaitForChild("Handle"):WaitForChild("sound_promptend"):Play() end
    end

    local AnyTool = Character:FindFirstChildOfClass("Tool")
    local ToolData = AnyTool and ItemNames[AnyTool.Name]
    if AnyTool and ToolData and Toggles.InfiniteItemsToggle.Value and Options.InfiniteItemsList.Value[ToolData] then
        Drops.ChildAdded:Once(function(NewTool)
            local P = NewTool:FindFirstChild("ModulePrompt")
            local RealPrompt = FakePrompts[Object]
            Functions.FirePrompt(P) Functions.FirePrompt(RealPrompt)
        end)
        Character.ChildAdded:Once(function(NewTool)
            if NewTool.Name == "Shears" then NewTool:WaitForChild("Handle"):WaitForChild("sound_promptend"):Play() end
        end)
        RemotesFolder.DropItem:FireServer(AnyTool)
    else
        local RealPrompt = FakePrompts[Object]
        Functions.FirePrompt(RealPrompt)
    end
end)

-- ════════════════════════════════════════════════════════════════
-- FLOOR REPLICATED & FOG HANDLERS
-- ════════════════════════════════════════════════════════════════
Connections.FloorReplicatedHandler = FloorReplicated.DescendantAdded:Connect(function(Object)
    if Object.Name == "GlitchScreech" then
        Modules.GlitchScreech = Object
        if Toggles.RemoveScreech.Value then Object.Name = "GlitchScreech_Disabled" end
    end
    if Object.Name:find("Jumpscare") and Object:IsA("ModuleScript")
        and not Object.Name:find("Eyestalk") and not Object.Name:find("Groundskeeper") and not Object.Name:find("Monument") then
        Object:SetAttribute("OriginalName", Object.Name)
        if Toggles.DisableEntityJumpscares.Value then Object.Name = Object.Name .. "_Disabled" end
        table.insert(Objects.JumpscareModules, Object)
    end
end)

if FloorReplicated:FindFirstChild("DigitalTimer") then
    Connections.HasteTimerConnection = FloorReplicated.DigitalTimer:GetPropertyChangedSignal("Value"):Connect(function()
        if Toggles.NotifyHasteTime.Value then Functions.Caption(Functions.GetHasteTime(), true) end
    end)
end

Connections.FogHandler = Services.Lighting:GetPropertyChangedSignal("FogEnd"):Connect(function()
    if Services.Lighting.FogEnd ~= 10000000 then Globals.OldFog = Services.Lighting.FogEnd end
    if Toggles.RemoveCameraFog.Value then Services.Lighting.FogEnd = 10000000 end
end)

Connections.FogHandler2 = Services.Lighting.DescendantAdded:Connect(function(Object)
    if not Object:IsA("Atmosphere") then return end
    Object:SetAttribute("Density_Old", Object.Density)
    if Toggles.RemoveCameraFog.Value then Object.Density = 0 end
    local AtmoConn2 = Object:GetPropertyChangedSignal("Density"):Connect(function()
        if Object.Density ~= 0 then Object:SetAttribute("Density_Old", Object.Density) end
        if Toggles.RemoveCameraFog.Value then Object.Density = 0 end
    end)
    Object.Destroying:Once(function() AtmoConn2:Disconnect() end)
    table.insert(Connections, AtmoConn2)
    table.insert(Globals.FogInstances, Object)
end)

-- ════════════════════════════════════════════════════════════════
-- ENTITY SPAWN HANDLER
-- ════════════════════════════════════════════════════════════════
local RusherAliases = {
    Rush=true, Bash=true, Scribbles=true, DronesStampede=true, Ambush=true, Eyes=true,
    Lookman=true, Blitz=true, ["A-60"]=true, ["A-120"]=true, AR0xMBUSH=true, ["RNIUSHCG=="]=true, ["Custom Entity"]=true
}

local function HandleEntitySpawn(Entity)
    if not Entity or typeof(Entity) ~= "Instance" then return end
    local Model = Entity
    if Entity:IsA("Humanoid") then Model = Entity.Parent end
    if not Model or not Model:IsA("Model") then return end
    local EntityData = Entities[Model.Name]
    if not EntityData then return end
    if Model:GetAttribute("FeatherHub_EntityHandled") then return end
    Model:SetAttribute("FeatherHub_EntityHandled", true)

    while not Model.PrimaryPart do
        for _, Child in Model:GetChildren() do
            if Child:IsA("BasePart") then Model.PrimaryPart = Child end
        end
        if not Model.PrimaryPart then task.wait() end
    end
    task.wait(0.1)

    if not Model.PrimaryPart or LocalPlayer:DistanceFromCharacter(Model.PrimaryPart.Position) >= 10000 then return end

    local Alias = EntityData.Alias
    local RealAlias = Alias
    if Options.EntityList.Value[Alias] and Toggles.NotifyEntities.Value then
        local NotifyTitle = EntityData.NotifyMessage.Title
        local NotifyBody  = EntityData.NotifyMessage.Body
        local NotifyImage = EntityIcons[Model.Name]
        if Model.Name == "RushMoving" and Model.PrimaryPart.Name ~= "RushNew" then
            NotifyTitle = NotifyTitle:gsub("Rush", Model.PrimaryPart.Name)
            NotifyImage = Model.PrimaryPart:WaitForChild("Attachment").ParticleEmitter.Texture
            Alias = Model.PrimaryPart.Name
        end
        Functions.Notify({ Title = NotifyTitle, Body = NotifyBody, Image = NotifyImage, Time = Toggles.NotifyKeepNotifications.Value and Model or nil })
        if Toggles.EntityChatToggle.Value then Functions.SendChat(Alias .. " " .. Options.EntityChatMessage.Value) end
    end

    if Model.Name ~= "GloombatSwarm" then
        if Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value[RealAlias] then
            if Model.Name == "MonumentEntity" then
                Functions.AddESP({ Object = Model.Top, Text = Interface.Localization.TranslateText(Alias), Color = Options.EntityESPColor.Value })
            else
                Functions.AddESP({ Object = Model, Text = Interface.Localization.TranslateText(Alias), Color = Options.EntityESPColor.Value })
            end
        end
        table.insert(Objects.Entities, Model)
    end

    if RusherAliases[EntityData.Alias] then
        Instance.new("Humanoid", Model).Name = "HighlightHumanoid"
        local Root = Model.PrimaryPart
        if Root then Root.Transparency = 0.999 Root.Material = Enum.Material.Plastic end
    end

    if Model.Name == "Lookman" then
        CurrentRooms.ChildAdded:Wait()
        task.wait(10)
        Model:Destroy()
    end
end

Connections.EntityHandler = Services.Workspace.ChildAdded:Connect(HandleEntitySpawn)
Connections.EntityDescendantHandler = Services.Workspace.DescendantAdded:Connect(function(Descendant)
    local EntityModel = Descendant:IsA("Humanoid") and Descendant.Parent or Descendant
    if EntityModel and EntityModel:IsA("Model") and Entities[EntityModel.Name] then
        task.defer(function() HandleEntitySpawn(Descendant) end)
    end
end)

-- ════════════════════════════════════════════════════════════════
-- CLEANER & PROMPT FIXER
-- ════════════════════════════════════════════════════════════════
local LastClean = tick()
Connections.Cleaner = Services.RunService.Heartbeat:Connect(function()
    if tick() - LastClean <= 0.5 then return end
    LastClean = tick()
    for ArrayName, Array in Objects do
        local I = #Array
        while I >= 1 do
            local Object = Array[I]
            if Object == nil or not Object:IsDescendantOf(Services.Workspace) then
                table.remove(Array, I)
                local Conn = ESPConnections[Object]
                if Conn then
                    Conn:Disconnect() ESPConnections[Object] = nil
                    local Pos = table.find(Connections, Conn)
                    if Pos then table.remove(Connections, Pos) end
                end
            end
            I -= 1
        end
    end
end)

local LastPromptFix = tick()
Connections.PromptFixer = Services.RunService.Heartbeat:Connect(function()
    if tick() - LastPromptFix <= 0.5 then return end
    LastPromptFix = tick()
    for _, Prompt in Objects.Prompts do
        if Prompt:HasTag("DisableWhenEnabledOnClient") then Prompt:RemoveTag("DisableWhenEnabledOnClient") end
    end
end)

-- ════════════════════════════════════════════════════════════════
-- CHARACTER ADDED
-- ════════════════════════════════════════════════════════════════
if LocalPlayer.Character then
    task.spawn(function() Functions.HandleCharacter(LocalPlayer.Character) end)
end

LocalPlayer.CharacterAdded:Connect(function(NewCharacter)
    if Connections.MainHandler then
        Connections.MainHandler:Disconnect()
        Connections.MainHandler = nil
    end
    task.wait(0.5)
    Functions.HandleCharacter(NewCharacter)
end)

-- ════════════════════════════════════════════════════════════════
-- UNLOAD
-- ════════════════════════════════════════════════════════════════
-- Очистка GUI выполняется независимо от восстановления игровых объектов.
Library:OnUnload(function()
    if Interface.Localization then Interface.Localization:Disconnect() end
    if StatsConnection then StatsConnection:Disconnect() end
    if StatsGui then StatsGui:Destroy() end
    if Container then Container:Destroy() end
    if STXGui then STXGui:Destroy() end
    table.clear(NotificationLibrary.Cards)
    NotificationLibrary.LiveNotifications = 0
end)
Library:OnUnload(function()
    StopTimeShower(true)
    for Key, Connection in Connections do
        if type(Key) == "string" then
            pcall(function() Connection:Disconnect() end)
        else
            pcall(function() Key:Disconnect() end)
            pcall(function() Connection:Disconnect() end)
        end
    end

    for _, Object in Objects.Entities do
        if Object.Name == "Snare" or Object.Name == "GiggleCeiling" then
            local Hitbox = Object:FindFirstChild("Hitbox")
            if Hitbox then Hitbox.CanTouch = true end
        end
        if Object.Name == "GloomPile" then
            for _, Part in Object:GetDescendants() do
                if Part:IsA("BasePart") then Part.CanTouch = true end
            end
        end
        if Object.Name == "FakeDoor" or Object.Name == "DoorFake" then
            local Hidden = Object:FindFirstChild("Hidden")
            if Hidden then Hidden.CanTouch = true end
            local Lock = Object:FindFirstChild("Lock")
            if Lock and Lock:FindFirstChild("UnlockPrompt") then Lock.UnlockPrompt.Enabled = true end
        end
        if Object.Name == "SideroomSpace" then
            local Coll = Object:FindFirstChild("Collision")
            if Coll then Coll.CanCollide = false Coll.CanTouch = true end
        end
    end

    for _, Object in Objects.SeekBridges do Object:Destroy() end

    for _, Fog in Globals.FogInstances do
        Fog.Density = Fog:GetAttribute("Density_Old")
    end
    Services.Lighting.FogEnd = Globals.OldFog

    local Vignette = Globals.MainUI:FindFirstChild("HideVignette") or Globals.MainUI.MainFrame:FindFirstChild("HideVignette")
    if Vignette then Vignette.Image = "rbxassetid://6100076320" end

    local ModuleRestores = {
        Screech = "Screech", Glitch = "Glitch", Shade = "Shade",
        SpiderJumpscare = "SpiderJumpscare", A90 = "A90", Dread = "Dread", Void = "Void"
    }
    for Key, OriginalName in ModuleRestores do
        if Modules[Key] then Modules[Key].Name = OriginalName end
    end

    FakeEvents.Screech:Destroy()
    FakeEvents.Screech_Real.Parent = RemotesFolder
    FakeEvents.Shade:Destroy()
    FakeEvents.Shade_Real.Parent = RemotesFolder
    if FakeEvents.A90_Real then FakeEvents.A90:Destroy() FakeEvents.A90_Real.Parent = RemotesFolder end
    if FakeEvents.Surge_Real then FakeEvents.Surge:Destroy() FakeEvents.Surge_Real.Parent = RemotesFolder end

    Globals.SeekNodesFolder:Destroy()
    Globals.RoomsNodesFolder:Destroy()
    Globals.ManipulateBody:Destroy()

    local OldAmbient = CurrentRooms:FindFirstChild(tostring(LocalPlayer:GetAttribute("CurrentRoom"))):GetAttribute("Ambient")
    Services.TweenService:Create(Services.Lighting, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), { Ambient = OldAmbient }):Play()

    for _, Prompt in Objects.Prompts do
        if FakePrompts[Prompt] then
            FakePrompts[Prompt].Parent = Prompt.Parent
            Prompt:Destroy()
        end
        if Prompt.Parent then
            Prompt.HoldDuration = Prompt:GetAttribute("HoldDuration_Old") or Prompt.HoldDuration
            Prompt.RequiresLineOfSight = Prompt:GetAttribute("RequiresLineOfSight_Old") or Prompt.RequiresLineOfSight
            Prompt.MaxActivationDistance = Prompt:GetAttribute("MaxActivationDistance_Old") or Prompt.MaxActivationDistance
        end
    end

    if Character then
        Character:SetAttribute("CanJump", OldJump)
        Character:SetAttribute("CanSlide", OldSlide)
    end

    for _, Object in Services.Workspace:GetDescendants() do
        task.spawn(function() Functions.RemoveESP(Object) end)
    end

    if Humanoid then
        Humanoid.WalkSpeed = Functions.GetCurrentSpeed()
        Humanoid.JumpPower = 5
        Humanoid.HipHeight = 2.367
    end

    if Collision and RootPart then
        local BaseY = 0.18
        Collision.Position = RootPart.Position + Vector3.new(0, BaseY, 0)
        CollisionPart.Position = RootPart.Position + Vector3.new(0, BaseY, 0)
        CollisionPartClone.Position = RootPart.Position + Vector3.new(0, BaseY, 0)
    end

    if Character and Character:FindFirstChild("LowerTorso") and Character.LowerTorso:FindFirstChild("Root") then
        Character.LowerTorso.Root.C1 = Globals.OriginalC1
    end
    if Collision and Collision:FindFirstChild("CollisionCrouch") and RootPart then
        Collision.CollisionCrouch.Position = RootPart.Position + Vector3.new(0, -0.982, 0)
    end

    if CollisionClone then CollisionClone:Destroy() end
    if CollisionPartClone then CollisionPartClone:Destroy() end
    FeatherHub.ESPLibrary:Unload()

    if Main_Game then
        Main_Game.fovtarget = 70
        Main_Game.spring.Speed = 8
        Main_Game.tooloffset = Vector3.zero
    end

    if Globals.OriginalGetMoveVector then
        local Controls = require(LocalPlayer.PlayerScripts.PlayerModule):GetControls()
        Controls.GetMoveVector = Globals.OriginalGetMoveVector
    end

    -- Destroy FPS/Ping stats

    getgenv().FeatherHub = nil
    shared.FeatherHubLoaded = false
    shared.RushHubLoaded = false
end)

-- ════════════════════════════════════════════════════════════════
-- FINAL INITIALIZATION
-- ════════════════════════════════════════════════════════════════
while not Globals.MainUI do task.wait() end
FeatherHub.Interface.ApplySettingsTab(Window)
Functions.Notify({
    Title = "Успешно загружено за " .. math.floor((tick() - LoadStart) * 1000) / 1000 .. " с.",
    Body = "Нажмите '" .. tostring(Options.MenuKeybind.Value) .. "', чтобы открыть или закрыть меню."
})

-- ════════════════════════════════════════════════════════════════
-- END OF FeatherHub
-- ════════════════════════════════════════════════════════════════