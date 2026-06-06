local addonName, CDT = ...

local framePool
local activeCastFrames = {}

CDT_Backdrop = {
    edgeFile = "Interface/AddOns/DungeonCastTracker/Media/DropShadowBorder.blp",
    edgeSize = PixelUtil.GetNearestPixelSize(1, UIParent:GetEffectiveScale(), 1) * 3,
    bgFile = ""
}

local function SetupDB()
    CDT_DB = {}
    CDT_DB.OffsetX = -190
    CDT_DB.OffsetY = 200
    CDT_DB.Width = 175
    CDT_DB.Height = 15
    CDT_DB.Spacing = 2

    CDT_DB.ColorInt = {
        ["R"] = 1,
        ["G"] = 1,
        ["B"] = 0,
    }

    CDT_DB.ColorNotInt = {
        ["R"] = 0.5,
        ["G"] = 0.5,
        ["B"] = 0.5,
    }
end

local function UpdateCastBarPositions()
    local i = 0
    for _, frame in pairs(activeCastFrames) do
        frame:SetSize(CDT_DB.Width, CDT_DB.Height)
        frame:SetPoint("CENTER", UIParent, "CENTER", CDT_DB.OffsetX, CDT_DB.OffsetY + (i * (CDT_DB.Height + CDT_DB.Spacing)))
        i = i + 1
    end
end

local function UpdateCastBar(unit)
    if not C_ChallengeMode.IsChallengeModeActive() or not string.match(unit, "nameplate%d+") then return end

    local frame = activeCastFrames[unit]
    if not frame then
        frame = framePool:Acquire()
        activeCastFrames[unit] = frame
        frame:Show()
    end

    local castDuration = UnitCastingDuration(unit)
    local channelDuration = UnitChannelDuration(unit)
    local spellName, displayName, textureID, notInterruptible
    if castDuration then
        spellName, displayName, textureID, _, _, _, _, notInterruptible = UnitCastingInfo(unit)
        frame.StatusBar:SetTimerDuration(castDuration, 0, 0)
    elseif channelDuration then
        spellName, displayName, textureID, _, _, _, notInterruptible = UnitChannelInfo(unit)
        frame.StatusBar:SetTimerDuration(channelDuration, 0, 1)
    else
        if frame then
            frame:Hide()
            framePool:Release(frame)
            activeCastFrames[unit] = nil
        end
    end

    if spellName then
        frame.StatusBar:GetStatusBarTexture():SetVertexColorFromBoolean(notInterruptible,
            CreateColor(CDT_DB.ColorNotInt.R, CDT_DB.ColorNotInt.G, CDT_DB.ColorNotInt.B), CreateColor(CDT_DB.ColorInt.R, CDT_DB.ColorInt.G, CDT_DB.ColorInt.B))

        frame.StatusBar:SetPoint("TOPLEFT", frame, "TOPLEFT", CDT_DB.Height, 0)

        local targetName = UnitSpellTargetName(unit)
        if targetName then
            local targetClass = UnitSpellTargetClass(unit)
            local classColor = C_ClassColor.GetClassColor(targetClass)
            frame.SpellName:SetPoint("LEFT", frame.StatusBar, "LEFT", 1, 0)
            frame.SpellName:SetText(spellName.." → ")
            frame.TargetName:SetPoint("LEFT", frame.SpellName, "RIGHT")
            frame.TargetName:SetText(targetName)
            frame.TargetName:SetTextColor(classColor.r, classColor.g, classColor.b)
        else
            frame.SpellName:SetPoint("LEFT", frame.StatusBar, "LEFT", 1, 0)
            frame.SpellName:SetText(spellName)
            frame.TargetName:SetText("")
        end

        frame.Icon:SetWidth(CDT_DB.Height)
        frame.Icon:SetTexture(textureID)

        local marker = GetRaidTargetIndex(unit)
        if marker then
            frame.Marker:SetSize(CDT_DB.Height, CDT_DB.Height)
            SetRaidTargetIconTexture(frame.Marker, marker)
            frame.Marker:Show()
        else
            frame.Marker:Hide()
        end

    end

    UpdateCastBarPositions()
end

local function RemoveAllCastBars()
    for _, frame in pairs(activeCastFrames) do
        frame:Hide()
        framePool:Release(frame)
    end

    table.wipe(activeCastFrames)
end

local f = CreateFrame("Frame", nil)
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("UNIT_SPELLCAST_START")
f:RegisterEvent("UNIT_SPELLCAST_STOP")
f:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
f:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
f:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        framePool = CreateFramePool("Frame", UIParent, "CDT_CastBarTemplate")
        SetupDB()
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local unit = ...
        local frame = activeCastFrames[unit]

        if frame then
            frame:Hide()
            framePool:Release(frame)
            activeCastFrames[unit] = nil
            UpdateCastBarPositions()
        end
    else
        local unit = ...
        UpdateCastBar(unit)
    end
end)