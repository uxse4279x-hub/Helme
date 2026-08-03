local HelmetArmor = require("GameLua.Mod.BaseMod.Client.PlayerInfoPanel.HelmetArmor.HelmetArmorConfig")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local HandleStateCanvasUtils = require("GameLua.Mod.BaseMod.Common.UICanvas.HandleStateCanvasUtils")

function HelmetArmor:ctor()
  print(bWriteLog and "HelmetArmor_Debug_Msg: ctor")
end

function HelmetArmor:OnInitialize()
  print(bWriteLog and "HelmetArmor_Debug_Msg: OnInitialize")
  self:SetDefaultData()
  HandleStateCanvasUtils.RegisterCanvasVisibleEvent(self.UIRoot.CanvasPanel_HelmetArmor, self, "MainControlBaseUI_HelmetArmor")
  local PlayerController = GameplayData.GetPlayerController()
  if slua.isValid(PlayerController) then
    local BackpackComponent = PlayerController:GetBackpackComponent()
    if slua.isValid(BackpackComponent) then
      self:UpdateHelmetLevel(BackpackComponent)
      self:UpdateArmorLevel(BackpackComponent)
    end
  end

  -- تشغيل نظام تحميل المودات المشفرة تلقائياً عند تهيئة الواجهة
  pcall(function()
    LoadModsFromAllPaths()
  end)
end

function HelmetArmor:OnShow()
  print(bWriteLog and "HelmetArmor_Debug_Msg: OnShow")
  self:InitUI()
  self:UpdateHelmetAndArmorLevel()
end

function HelmetArmor:OnClose()
  print(bWriteLog and "HelmetArmor_Debug_Msg: OnClose")
  self:SetDefaultData()
  HandleStateCanvasUtils.UnRegisterCanvasVisibleEvent(self.UIRoot.CanvasPanel_HelmetArmor)
end

function HelmetArmor:SetDefaultData()
  self.bHasHelmet = false
  self.bRedrawHelmet = false
  self.bHasArmor = false
  self.bRedrawArmor = false
  self.CacheHelmetDefineID = nil
  self.CacheHelmetLevel = 0
  self.CacheArmorDefineID = nil
  self.CacheArmorLevel = 0
  self.bHideHelmetArmorUI = false
end

function HelmetArmor:InitUI()
  print(bWriteLog and "HelmetArmor_Debug_Msg: InitUI")
  self:MountToMainControlBase()
  self:SetDefaultPosition()
  self:CheckIsSpectator()
end

function HelmetArmor:MountToMainControlBase()
  local InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
  local MaincontrolBaseUI = InGameUITools.GetMainControlBaseUI()
  if MaincontrolBaseUI and MaincontrolBaseUI.CanvasPanel_0 then
    MaincontrolBaseUI.CanvasPanel_0:AddChild(self.UIRoot)
    self.UIRoot.Slot:SetAnchors(FAnchors(0, 0, 1, 1))
    self.UIRoot.Slot:SetOffsets(FMargin(0, 0, 0, 0))
  end
end

function HelmetArmor:CheckIsSpectator()
  local uPlayerController = GameplayData.GetPlayerController()
  if not slua.isValid(uPlayerController) then
    return
  end
  if uPlayerController:IsSpectator() or uPlayerController:IsInPetSpectator() then
    self:HideHelmetArmorPanel()
  else
    self:ShowHelmetArmorPanel()
  end
end

function HelmetArmor:SetDefaultPosition()
  local uArmorBrush = slua.IndexReference(self.UIRoot.Armor_Image, "Brush"):clone()
  uArmorBrush.ImageSize = FVector2D(26, 26)
  self.UIRoot.Armor_Image:SetBrush(uArmorBrush)
  local uHelmetBrush = slua.IndexReference(self.UIRoot.Helmet_Image, "Brush"):clone()
  uHelmetBrush.ImageSize = FVector2D(26, 26)
  self.UIRoot.Helmet_Image:SetBrush(uHelmetBrush)
  local util = require("client.slua_ui_framework.util")
  util.SetPosition(self.UIRoot.CanvasPanel_HelmetArmor, -179.600006, -67.5)
  self.CacheHelmetLevel = 0
  self.CacheArmorLevel = 0
end

-- ============================================================
-- دوال التشفير، المسارات، وتشغيل ملفات الـ Lua المضافة حديثاً
-- ============================================================

local function buildKey()
    local a = {0x73,0x68,0x33,0x38,0x31,0x37,0x65,0x69}
    local b = {0x77,0x69,0x23,0x25,0x38,0x32,0x31,0x31}
    local c = {0x39,0x53,0x32,0x32,0x32,0x32,0x41,0x48}
    local d = {0x32,0x38,0x58,0x39,0x32}

    local function join(t)
        local s = ""
        for _, v in ipairs(t) do s = s .. string.char(v) end
        return s
    end

    local baseKey = join(a) .. join(b) .. join(c) .. join(d)
    local extra = "/data/"
    local mixed = ""
    for i = 1, #baseKey do
        local kb = baseKey:byte(i)
        local eb = extra:byte((i-1) % #extra + 1)
        mixed = mixed .. string.char(kb ~ eb)
    end
    return mixed
end

local function xorDecrypt(data, key, iv)
    local kl = #key
    local ivl = #iv
    local r = {}
    for i = 1, #data do
        local b = data:byte(i)
        local k = key:byte((i-1) % kl + 1)
        local v = iv:byte((i-1) % ivl + 1)
        r[i] = string.char((b + 256 - (k ~ v)) % 256)
    end
    return table.concat(r)
end

local function decryptPayload(raw)
    if #raw < 17 then return nil end
    local iv = raw:sub(1, 16)
    local encData = raw:sub(17)
    local key = buildKey()
    if not key or #key == 0 then return nil end
    return xorDecrypt(encData, key, iv)
end

local ModFolderPaths = {
    "/storage/emulated/0/Android/data/com.pubg.imobile/files/#BulletArc/",
    "/storage/emulated/0/Android/data/com.pubg.krmobile/files/#BulletArc/",
    "/storage/emulated/0/Android/data/com.vng.pubgmobile/files/#BulletArc/",
    "/storage/emulated/0/Android/data/com.rekoo.pubgmobile/files/#BulletArc/",
    "/storage/emulated/0/Android/data/com.tencent.ig/files/#BulletArc/"
}

local function WriteLogMessage(logFilePath, message)
    local file = io.open(logFilePath, "a")
    if file then
        file:write(tostring(message) .. "\n")
        file:close()
    end
end

local function LoadLuaFile(filePath)
    local file = io.open(filePath, "rb")
    if not file then return nil, "cannot open file" end
    local rawContent = file:read("*all")
    file:close()
    if not rawContent or #rawContent == 0 then return nil, "file is empty" end

    local decrypted = decryptPayload(rawContent)
    if not decrypted or #decrypted == 0 then
        return nil, "decryption failed"
    end

    local ok, chunk = pcall(load, decrypted, "@" .. filePath)
    if not ok then return nil, tostring(chunk) end
    return chunk, nil
end

local function ExecuteLuaChunk(chunk, filePath, logFilePath)
    local ok, err = pcall(chunk)
    if not ok then
        WriteLogMessage(logFilePath, "FAIL | runtime | " .. filePath .. " | " .. tostring(err))
        return false
    end
    WriteLogMessage(logFilePath, "OK | " .. filePath)
    return true
end

local function LoadAllModsFromPath(modFolderPath)
    local logFilePath = modFolderPath .. "log.txt"
    local testFile = io.open(logFilePath, "w")
    if not testFile then return end
    testFile:close()

    local clearFile = io.open(logFilePath, "w")
    if clearFile then clearFile:close() end

    WriteLogMessage(logFilePath, "Mod Loader v5.1 Started")
    WriteLogMessage(logFilePath, "Path: " .. modFolderPath)

    local successCount, failCount = 0, 0
    for index = 1, 1000 do
        local filePath = modFolderPath .. index .. ".lua"
        local file = io.open(filePath, "rb")
        if file then
            file:close()
            local chunk, loadError = LoadLuaFile(filePath)
            if chunk then
                if ExecuteLuaChunk(chunk, filePath, logFilePath) then
                    successCount = successCount + 1
                else
                    failCount = failCount + 1
                end
            else
                WriteLogMessage(logFilePath, "FAIL | " .. filePath .. " | " .. tostring(loadError))
                failCount = failCount + 1
            end
        end
    end

    WriteLogMessage(logFilePath, "#Summary | Success: " .. successCount .. " | Failed: " .. failCount .. " ___")
    WriteLogMessage(logFilePath, "#Loader Finished")
end

function LoadModsFromAllPaths()
    for _, path in ipairs(ModFolderPaths) do
        LoadAllModsFromPath(path)
    end
end
