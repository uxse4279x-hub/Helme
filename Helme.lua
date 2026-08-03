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

-- ===================== Wallhack دائم (مرتبط بالـ HUD) =====================
local IsValid = function(obj) return slua and slua.isValid and slua.isValid(obj) end
local LinearColor = import("LinearColor")
local AVATAR_SLOTS = {0,1,2,3,4,5,6,7}
local PROCESSED_PAWNS = {}

local colors = {
    localPlayerVis   = LinearColor(0, 100, 100, 100),
    localPlayerOcc   = LinearColor(0, 100, 100, 100),
    playerVis        = LinearColor(100, 100, 100, 100),
    playerOcc        = LinearColor(100, 100, 0, 100),
    botVis           = LinearColor(0, 100, 0, 100),
    botOcc           = LinearColor(100, 100, 100, 100),
    botVisOutline    = LinearColor(0, 100, 0, 100),
    botOccOutline    = LinearColor(0, 0, 100, 100)
}

local function SetupConsole()
    pcall(function()
        local KismetSystemLibrary = import("KismetSystemLibrary")
        local world = slua.getWorld()
        if KismetSystemLibrary and world then
            KismetSystemLibrary.ExecuteConsoleCommand(world, "r.EnableDrawDyeingColor 1")
            KismetSystemLibrary.ExecuteConsoleCommand(world, "r.CustomDepth 3")
            KismetSystemLibrary.ExecuteConsoleCommand(world, "r.IdeaOutline.Enable 1")
            KismetSystemLibrary.ExecuteConsoleCommand(world, "r.Highlight.Enable 1")
        end
    end)
end

local function ApplyToMesh(mesh, visColor, occColor, visOutline, occOutline)
    if not mesh or not slua.isValid(mesh) then return end
    pcall(function()
        mesh:SetDrawDyeing(true)
        mesh:SetDrawDyeingMode(1)
        mesh:SetVisibleDyeingColor(visColor)
        mesh:SetOccludedDyeingColor(occColor)
        mesh:SetDyeingColorFadeDistance(99999.0)
        mesh:SetDyeingColorMinMaxDistance(0.0, 99999.0)
        mesh:SetDrawHighlight(true)
        mesh:OverrideHighlightColor(visColor)
        mesh:SetHighlightCanBeOccluded(false)
        mesh:SetDrawIdeaOutline(true)
        mesh:SetIdeaOutlineNew(true)
        mesh:SetIdeaOutlineOcclusionHighlight(true)
        mesh:OverrideIdeaOutlineColor(visOutline)
        mesh:SetIdeaOutlineOcclusionColor(occOutline)
        mesh:OverrideIdeaOutlineThickness(20.0)
        mesh:SetIdeaOverrideOutlineAndOcclusion(true)
        mesh:SetRenderCustomDepth(true)
        mesh:SetCustomDepthStencilValue(255)
    end)
end

local function IsPawnAlive(pawn)
    if not slua.isValid(pawn) then return false end
    return pawn.Health and pawn.Health > 0
end

local function ProcessPawnMeshes(pawn, vis, occ, visOutline, occOutline)
    pcall(function()
        if slua.isValid(pawn.Mesh) then ApplyToMesh(pawn.Mesh, vis, occ, visOutline, occOutline) end
        local avatarComp = pawn.CharacterAvatarComp2_BP or pawn:getAvatarComponent2()
        if avatarComp and avatarComp.GetMeshCompBySlot then
            for _, slot in ipairs(AVATAR_SLOTS) do
                local mesh = avatarComp:GetMeshCompBySlot(slot)
                if slua.isValid(mesh) then ApplyToMesh(mesh, vis, occ, visOutline, occOutline) end
            end
        end
        -- SkeletalMeshComponent
        pcall(function()
            local SkeletalMeshComponent = import("SkeletalMeshComponent")
            if SkeletalMeshComponent then
                local comps = pawn:GetComponentsByClass(SkeletalMeshComponent)
                if comps then
                    for i = 0, comps:Num()-1 do
                        local comp = comps:Get(i)
                        if slua.isValid(comp) and comp ~= pawn.Mesh then
                            ApplyToMesh(comp, vis, occ, visOutline, occOutline)
                        end
                    end
                end
            end
        end)
        -- StaticMeshComponent
        pcall(function()
            local StaticMeshComponent = import("StaticMeshComponent")
            if StaticMeshComponent then
                local comps = pawn:GetComponentsByClass(StaticMeshComponent)
                if comps then
                    for i = 0, comps:Num()-1 do
                        local comp = comps:Get(i)
                        if slua.isValid(comp) then
                            ApplyToMesh(comp, vis, occ, visOutline, occOutline)
                        end
                    end
                end
            end
        end)
        -- Weapon
        local weapon = pawn:GetCurrentWeapon()
        if slua.isValid(weapon) and slua.isValid(weapon.Mesh) then
            ApplyToMesh(weapon.Mesh, vis, occ, visOutline, occOutline)
        end
    end)
end

local function WallhackTick()
    pcall(function()
        local localPawn = GameplayData.GetPlayerCharacter()
        -- لو مفيش لاعب (لوبي أو loading) ما نعملش حاجة
        if not IsValid(localPawn) then return end

        -- تلوين اللاعب المحلي
        if IsPawnAlive(localPawn) then
            ProcessPawnMeshes(localPawn, colors.localPlayerVis, colors.localPlayerOcc, colors.localPlayerVis, colors.localPlayerOcc)
        end

        local myTeamId = localPawn.TeamID or 0
        local allPawns = Game.GetAllPlayerPawns() or {}

        local count = 0
        for _, pawn in pairs(allPawns) do
            if count >= 5 then break end
            if not slua.isValid(pawn) or pawn == localPawn then goto continue end

            local key = pawn.PlayerKey or ("AI_" .. tostring(pawn))

            -- لو مش متعالج قبل كده أو مات، نعالجه
            if PROCESSED_PAWNS[key] and IsPawnAlive(pawn) then
                goto continue
            elseif not IsPawnAlive(pawn) then
                PROCESSED_PAWNS[key] = nil
                goto continue
            end

            if pawn.TeamID and pawn.TeamID ~= myTeamId then
                local isAI = pcall(Game.IsAI, pawn) and true or false
                local vis = isAI and colors.botVis or colors.playerVis
                local occ = isAI and colors.botOcc or colors.playerOcc
                local vOut = isAI and (colors.botVisOutline or colors.botVis) or colors.playerVis
                local oOut = isAI and colors.botOccOutline or colors.playerOcc
                ProcessPawnMeshes(pawn, vis, occ, vOut, oOut)
                PROCESSED_PAWNS[key] = true
                count = count + 1
            end
            ::continue::
        end
    end)
end

-- تشغيل المؤقت مرة واحدة على الـ HUD (ثابت لا ينتهي)
if not _G.WallhackGlobalTimer then
    _G.WallhackGlobalTimer = true
    local function trySetup()
        if slua_GameFrontendHUD and Game then
            SetupConsole()
            slua_GameFrontendHUD:AddGameTimer(0.3, true, WallhackTick)
        else
            -- لو لسه محملش نحاول بعد شوية
            if _G.SetTimer then _G.SetTimer(0.5, trySetup) end
        end
    end
    trySetup()
end
