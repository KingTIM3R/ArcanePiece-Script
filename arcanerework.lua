-- ==============================================================
-- Combined Script: GrandHubX UI for Boss Farm & NPC Insta-Kill + Teleport Cycle
-- ==============================================================

-- 1. Load the GrandHubX Library
local GrandHubX = loadstring(game:HttpGet("https://raw.githubusercontent.com/KingTIM3R/UI_Final/refs/heads/main/GrandHubXUI.lua", true))()
if not GrandHubX then
    warn("Failed to load GrandHubX library!")
    return -- Stop if library fails to load
end

-- 2. Shared Services and Variables
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

-- Helper: Function to get character safely
local function getCharacter()
    local char = player.Character
    if not char or not char.Parent then
        player.CharacterAdded:Wait()
        char = player.Character
    end
    return char
end

-- Helper: Function to trim whitespace from a string
local function trim(s)
  return s:match'^%s*(.*%S)' or ''
end

-- Helper: Generic Teleport Function
local function teleportToPosition(targetPosition)
    local char = getCharacter()
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    if not rootPart or not targetPosition then return false end

    local success, err = pcall(function()
        rootPart.CFrame = CFrame.new(targetPosition)
    end)
    if not success then
        warn("Teleport failed:", err)
        return false
    end
    return true
end

-- ==============================================================
-- SECTION: Teleport Data Processing
-- ==============================================================

local rawTeleportData = {
    "Anos Boss, 1614, 56, 221",
    "Atomic, 1614, 56, 221",
    "Strongest, 1439, 267, 1410",
    "Aizen, 303, 80, 1933",
    "Asta, -1043, 10, 1207",
    "Sukuna, -2347, 149, -59",
    "Dungeon, -786, 15, -1158", -- This will be skipped in the cycle
    "Sjw Boss, -2524, 621, 3574"
}

local teleportLocations = {} -- Dictionary: Name -> Vector3
local teleportLocationNames = {} -- Array of names for dropdown/cycle

for _, dataString in ipairs(rawTeleportData) do
    local parts = {}
    for part in string.gmatch(dataString, "[^,]+") do table.insert(parts, trim(part)) end

    if #parts == 4 then
        local name = parts[1]; local x = tonumber(parts[2]); local y = tonumber(parts[3]); local z = tonumber(parts[4])
        if name and x and y and z then
            teleportLocations[name] = Vector3.new(x, y, z)
            table.insert(teleportLocationNames, name)
        else warn("Failed to process teleport data:", dataString) end
    else warn("Incorrect format for teleport data:", dataString) end
end

local selectedTeleportLocationName = nil
if #teleportLocationNames > 0 then selectedTeleportLocationName = teleportLocationNames[1] end

-- ==============================================================
-- SECTION: Auto Teleport Cycle Logic
-- ==============================================================

local teleportCycleConfig = {
    enabled = false, -- Master toggle for the cycle
    active = false, -- Is the loop currently running?
    delay = 3,      -- Delay in seconds between teleports
    excludedLocation = "Dungeon" -- Location name to skip
}

-- The loop function for the teleport cycle
local function teleportCycleLoop()
    print("Teleport Cycle Loop Started.")
    teleportCycleConfig.active = true

    local currentIndex = 1 -- Start from the first location

    while teleportCycleConfig.enabled do
        local char = getCharacter()
        local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")

        -- Stop if player is invalid or cycle disabled
        if not humanoid or humanoid.Health <= 0 then
            print("Teleport Cycle: Player invalid, stopping cycle.")
            teleportCycleConfig.enabled = false -- Disable the feature if player dies
            -- Need code here to update the UI toggle state if possible, otherwise user must manually re-enable
            break -- Exit the loop
        end

        -- Get the next location name, wrapping around if needed
        if currentIndex > #teleportLocationNames then
            currentIndex = 1 -- Wrap back to the beginning
        end
        local locationName = teleportLocationNames[currentIndex]

        -- Check if it's the excluded location
        if locationName == teleportCycleConfig.excludedLocation then
            print("Teleport Cycle: Skipping", locationName)
        else
            -- Get coordinates and teleport
            local targetPos = teleportLocations[locationName]
            if targetPos then
                print("Teleport Cycle: Teleporting to", locationName)
                teleportToPosition(targetPos)
            else
                warn("Teleport Cycle: Could not find coordinates for", locationName)
            end
        end

        -- Increment index for the next iteration
        currentIndex = currentIndex + 1

        -- Wait for the configured delay (check if still enabled during wait)
        local waitEndTime = tick() + teleportCycleConfig.delay
        while tick() < waitEndTime and teleportCycleConfig.enabled do
            task.wait(0.1)
        end
    end

    print("Teleport Cycle Loop Ended.")
    teleportCycleConfig.active = false
end

-- ==============================================================
-- SECTION: Boss Auto Farm Logic
-- [ ... Same Boss Farm Code as before ... ]
-- ==============================================================

local bossFarmConfig = {
    enabled = false,             -- Master toggle controlled by UI
    autoFarmActive = false,      -- Internal flag to know if the loop is running
    autoAttack = true,
    autoSkills = true,
    skills = {
        z = {enabled = true, cooldown = 0},
        x = {enabled = true, cooldown = 0},
        c = {enabled = true, cooldown = 0}
    },
    bossDetection = {
        maxDistance = 100000000,
        bossNameContains = {"Anos", "Shadow Monarch", "Asta", "Aizen Sosuke", "The Strongest Sorcerer", "Atomic", "Curse King"},
        ignoredBosses = {"Anos Buyer"}
    },
    teleportDelay = 0,
    attackDelay = 0,
    updateInterval = 0.5
}

local currentTargetBoss = nil
local bossSkillCooldowns = { z = 0, x = 0, c = 0 }

-- Boss Farm Helper Functions (Copied/Adapted from Script 1)
local function isBoss(instance)
    if not instance:IsA("Model") then return false end
    local humanoid = instance:FindFirstChildWhichIsA("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    if not instance:FindFirstChild("HumanoidRootPart") then return false end

    local name = instance.Name
    for _, partialName in ipairs(bossFarmConfig.bossDetection.bossNameContains) do
        if string.find(name, partialName) then
            for _, ignoredName in ipairs(bossFarmConfig.bossDetection.ignoredBosses) do
                if name == ignoredName then return false end
            end
            return true
        end
    end
    return false
end

local function findNearestBoss()
    local nearestBoss = nil
    local minDistance = bossFarmConfig.bossDetection.maxDistance
    local char = getCharacter()
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end

    for _, instance in pairs(Workspace:GetChildren()) do
        if isBoss(instance) then
            local bossRootPart = instance:FindFirstChild("HumanoidRootPart")
            if bossRootPart then
                local distance = (rootPart.Position - bossRootPart.Position).Magnitude
                if distance < minDistance then
                    minDistance = distance
                    nearestBoss = instance
                end
            end
        end
    end
    return nearestBoss
end

local function teleportToBoss(boss)
    local char = getCharacter()
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    if not rootPart or not boss or not boss:FindFirstChild("HumanoidRootPart") then return end

    local bossRootPart = boss:FindFirstChild("HumanoidRootPart")
    local bossPosition = bossRootPart.Position
    local playerPosition = rootPart.Position
    local direction = (playerPosition - bossPosition).Unit
    if direction.Magnitude < 0.1 then direction = Vector3.new(1,0,0) end -- Avoid zero vector
    local teleportPosition = bossPosition + direction * 14

    teleportToPosition(teleportPosition) -- Use the generic function
end

local function performBossAttack()
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
    end)
end

local function useBossSkill(key)
    local keyCode = nil
    if key == "z" then keyCode = Enum.KeyCode.Z
    elseif key == "x" then keyCode = Enum.KeyCode.X
    elseif key == "c" then keyCode = Enum.KeyCode.C end

    if keyCode then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
        end)
    end
end

-- Boss Farming Loop Function
local function farmBossesLoop()
    print("Boss Farm Loop Started")
    bossFarmConfig.autoFarmActive = true -- Set flag indicating loop is running

    while bossFarmConfig.enabled do -- Check master toggle
        local char = getCharacter()
        local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
        local rootPart = char and char:FindFirstChild("HumanoidRootPart")

        if not humanoid or humanoid.Health <= 0 or not rootPart then
            print("Boss Farm: Player character invalid, waiting...")
            bossFarmConfig.autoFarmActive = false -- Stop if player is dead/invalid
            return -- Exit loop
        end

        currentTargetBoss = findNearestBoss()

        if currentTargetBoss then
            -- print("Boss Farm: Targeting", currentTargetBoss.Name) -- Optional print
            local targetStartTime = tick()

            -- Loop while target is valid and alive, and farm is still enabled
            while bossFarmConfig.enabled and
                  currentTargetBoss and currentTargetBoss.Parent and
                  currentTargetBoss:FindFirstChildWhichIsA("Humanoid") and
                  currentTargetBoss.Humanoid.Health > 0 and
                  (tick() - targetStartTime < 30) -- Timeout safeguard
            do
                -- Ensure character still valid inside inner loop
                char = getCharacter()
                humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
                rootPart = char and char:FindFirstChild("HumanoidRootPart")
                if not humanoid or humanoid.Health <= 0 or not rootPart then
                     print("Boss Farm: Player died/invalid while targeting.")
                     bossFarmConfig.autoFarmActive = false
                     return -- Exit inner and outer loop
                end

                teleportToBoss(currentTargetBoss)
                task.wait(bossFarmConfig.teleportDelay) -- Small delay after teleport

                -- Auto Attack
                if bossFarmConfig.autoAttack then
                    performBossAttack()
                    task.wait(bossFarmConfig.attackDelay)
                end

                -- Auto Skills
                if bossFarmConfig.autoSkills then
                    local currentTime = tick()
                    if bossFarmConfig.skills.z.enabled and (currentTime - bossSkillCooldowns.z) >= bossFarmConfig.skills.z.cooldown then
                        useBossSkill("z"); bossSkillCooldowns.z = currentTime
                    end
                    if bossFarmConfig.skills.x.enabled and (currentTime - bossSkillCooldowns.x) >= bossFarmConfig.skills.x.cooldown then
                        useBossSkill("x"); bossSkillCooldowns.x = currentTime
                    end
                    if bossFarmConfig.skills.c.enabled and (currentTime - bossSkillCooldowns.c) >= bossFarmConfig.skills.c.cooldown then
                        useBossSkill("c"); bossSkillCooldowns.c = currentTime
                    end
                end

                task.wait(0.05) -- Small loop delay
            end
            -- print("Boss Farm: Target", currentTargetBoss and currentTargetBoss.Name or "Unknown", "defeated or lost.") -- Optional print
            currentTargetBoss = nil -- Clear target after loop finishes

        else
            -- print("Boss Farm: No bosses found, waiting...") -- Optional print
            task.wait(bossFarmConfig.updateInterval) -- Wait before scanning again
        end

        task.wait(0.01) -- Yield at end of main loop
    end

    print("Boss Farm Loop Ended")
    bossFarmConfig.autoFarmActive = false -- Clear flag when loop naturally exits
end

-- ==============================================================
-- SECTION: NPC Insta-Kill Logic
-- [ ... Same NPC Kill Code as before ... ]
-- ==============================================================

local npcKillConfig = {
    enabled = false, -- Controlled by UI
    maxDistance = 1000,
    refreshRate = 2.5
}
local npcKillLastUpdateTime = 0
local function killNPC(npcModel)
    local success, err = pcall(function()
        if npcModel and npcModel.Parent then
             local humanoid = npcModel:FindFirstChildWhichIsA("Humanoid")
             if humanoid and humanoid.Health > 0 then humanoid.Health = 0 end
        end
    end)
    if not success then warn("NPC Kill Error:", err) end
end
local function updateAndKillNPCs()
    if not npcKillConfig.enabled then return end
    local char = getCharacter()
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    local playerPos = rootPart.Position
    for _, entity in pairs(Workspace:GetDescendants()) do
        if entity:IsA("Model") and entity ~= char then
            local humanoid = entity:FindFirstChildWhichIsA("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local npcRoot = entity.PrimaryPart or entity:FindFirstChild("HumanoidRootPart")
                if npcRoot then
                    local successDist, distance = pcall(function() return (playerPos - npcRoot.Position).Magnitude end)
                    if successDist and distance <= npcKillConfig.maxDistance then killNPC(entity) end
                end
            end
        end
    end
end
RunService.Heartbeat:Connect(function(deltaTime)
    if tick() - npcKillLastUpdateTime >= (npcKillConfig.refreshRate / 2) then
        pcall(updateAndKillNPCs)
        npcKillLastUpdateTime = tick()
    end
end)

-- ==============================================================
-- SECTION: GrandHubX UI Setup
-- ==============================================================

-- Create the main window
local Library = GrandHubX:Window("GrandHubX", "", "", Enum.KeyCode.RightControl)

-- Tab for Boss Farm
local BossFarmTab = Library:Tab("Boss Farm")
-- Discord Button
BossFarmTab:Button("Copy Discord Link", function()
    local discordLink = "https://discord.gg/BV2qeDRD7x" -- <<< REPLACE
    if setclipboard then setclipboard(discordLink); print("Discord link copied!") else print("Clipboard failed. Link: " .. discordLink) end
end)
BossFarmTab:Line()
-- Boss Farm Controls
BossFarmTab:Label("Master Toggle & Settings")
BossFarmTab:Toggle("Enable Boss Farm", bossFarmConfig.enabled, function(value)
    bossFarmConfig.enabled = value; print("Boss Farm Enabled:", value)
    if value and not bossFarmConfig.autoFarmActive then task.spawn(farmBossesLoop) elseif not value then print("Boss Farm loop will stop.") end
end)
BossFarmTab:Toggle("Auto Attack (M1)", bossFarmConfig.autoAttack, function(value) bossFarmConfig.autoAttack = value end)
BossFarmTab:Toggle("Auto Use Skills", bossFarmConfig.autoSkills, function(value) bossFarmConfig.autoSkills = value end)
BossFarmTab:Seperator("Skill Toggles")
BossFarmTab:Toggle("Use Skill Z", bossFarmConfig.skills.z.enabled, function(value) bossFarmConfig.skills.z.enabled = value end)
BossFarmTab:Toggle("Use Skill X", bossFarmConfig.skills.x.enabled, function(value) bossFarmConfig.skills.x.enabled = value end)
BossFarmTab:Toggle("Use Skill C", bossFarmConfig.skills.c.enabled, function(value) bossFarmConfig.skills.c.enabled = value end)
BossFarmTab:Label("Status: (Check Output/Console)")

-- Tab for NPC Insta-Kill
local NpcKillTab = Library:Tab("NPC Insta-Kill")
NpcKillTab:Label("Enable / Disable")
NpcKillTab:Toggle("Enable NPC Insta-Kill", npcKillConfig.enabled, function(value) npcKillConfig.enabled = value; print("NPC Insta-Kill Enabled:", value) end)
NpcKillTab:Label("Range: " .. npcKillConfig.maxDistance .. " studs (Code Edit)")
NpcKillTab:Label("Status: Active when Enabled")

-- Tab for Teleports
local TeleportTab = Library:Tab("Teleports")

TeleportTab:Label("Manual Teleport")
TeleportTab:Dropdown("Location", teleportLocationNames, function(selectedName) selectedTeleportLocationName = selectedName end)
TeleportTab:Button("Teleport to Selected", function()
    if selectedTeleportLocationName and teleportLocations[selectedTeleportLocationName] then
        print("Teleporting to:", selectedTeleportLocationName)
        teleportToPosition(teleportLocations[selectedTeleportLocationName])
    else print("Teleport Error: Invalid location selected.") end
end)

TeleportTab:Seperator("Auto Cycle") -- Separator for the new feature

-- --- !!! NEW TELEPORT CYCLE TOGGLE !!! ---
TeleportTab:Toggle("Enable Auto Teleport Cycle", teleportCycleConfig.enabled, function(value)
    teleportCycleConfig.enabled = value
    print("Auto Teleport Cycle Enabled:", value)
    if value and not teleportCycleConfig.active then
        -- Start the cycle loop if enabled and not already running
        task.spawn(teleportCycleLoop)
    elseif not value then
        -- The loop will stop itself based on the 'enabled' flag check
        print("Auto Teleport Cycle loop will stop.")
    end
end)
-- You could add a Slider here to control teleportCycleConfig.delay if desired
TeleportTab:Label("Delay: " .. teleportCycleConfig.delay .. "s (Code Edit)")
TeleportTab:Label("(Excludes: " .. teleportCycleConfig.excludedLocation .. ")")
-- --- !!! END OF TELEPORT CYCLE TOGGLE !!! ---


-- ==============================================================
-- SECTION: Initialization and Cleanup
-- ==============================================================

-- Handle character respawning
player.CharacterAdded:Connect(function(newCharacter)
    task.wait(1)
    print("Character respawned.")
    -- Restart Boss Farm if needed
    if bossFarmConfig.enabled and not bossFarmConfig.autoFarmActive then
        print("Restarting Boss Farm loop after respawn.")
        task.spawn(farmBossesLoop)
    end
    -- Restart Teleport Cycle if needed
    if teleportCycleConfig.enabled and not teleportCycleConfig.active then
         print("Restarting Teleport Cycle loop after respawn.")
         task.spawn(teleportCycleLoop)
    end
end)

print("GrandLegacyX Hub Loaded. Press RightControl to toggle UI.")
