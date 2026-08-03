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

-- ===================== نظام Wallhack (بدون أي تغيير) =====================
local IsValidWH = function(obj) return slua and slua.isValid and slua.isValid(obj) end

local LinearColor = import("LinearColor")
local AVATAR_SLOTS = {0,1,2,3,4,5,6,7}
local WH_TIMER = nil
local TICK_INTERVAL = 0.3
local MAX_PAWNS_PER_TICK = 5

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
        if not KismetSystemLibrary or not world then return end
        KismetSystemLibrary.ExecuteConsoleCommand(world, "r.EnableDrawDyeingColor 1")
        KismetSystemLibrary.ExecuteConsoleCommand(world, "r.CustomDepth 3")
        KismetSystemLibrary.ExecuteConsoleCommand(world, "r.IdeaOutline.Enable 1")
        KismetSystemLibrary.ExecuteConsoleCommand(world, "r.Highlight.Enable 1")
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
    if pawn.Health and pawn.Health > 0 then return true end
    return false
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
        pcall(function()
            local SkeletalMeshComponent = import("SkeletalMeshComponent")
            if SkeletalMeshComponent then
                local skComps = pawn:GetComponentsByClass(SkeletalMeshComponent)
                if skComps then
                    for i = 0, skComps:Num() - 1 do
                        local comp = skComps:Get(i)
                        if slua.isValid(comp) and comp ~= pawn.Mesh then ApplyToMesh(comp, vis, occ, visOutline, occOutline) end
                    end
                end
            end
        end)
        pcall(function()
            local StaticMeshComponent = import("StaticMeshComponent")
            if StaticMeshComponent then
                local stComps = pawn:GetComponentsByClass(StaticMeshComponent)
                if stComps then
                    for i = 0, stComps:Num() - 1 do
                        local comp = stComps:Get(i)
                        if slua.isValid(comp) then ApplyToMesh(comp, vis, occ, visOutline, occOutline) end
                    end
                end
            end
        end)
        local weapon = pawn:GetCurrentWeapon()
        if slua.isValid(weapon) and slua.isValid(weapon.Mesh) then ApplyToMesh(weapon.Mesh, vis, occ, visOutline, occOutline) end
    end)
end

local function WallhackTick()
    pcall(function()
        if not _G.WallhackProcessed then
            _G.WallhackProcessed = {}
        end

        local localPawn = GameplayData.GetPlayerCharacter()
        if not IsValidWH(localPawn) then return end
        if not colors then return end

        if IsPawnAlive(localPawn) then
            ProcessPawnMeshes(localPawn, colors.localPlayerVis, colors.localPlayerOcc, colors.localPlayerVis, colors.localPlayerOcc)
        end

        local processed = _G.WallhackProcessed
        local myTeamId = localPawn.TeamID or 0
        local allPawns = Game.GetAllPlayerPawns() or {}
        local processedCount = 0

        for _, pawn in pairs(allPawns) do
            if processedCount >= MAX_PAWNS_PER_TICK then break end
            
            if not slua.isValid(pawn) or pawn == localPawn then goto continue_wh end

            local key = pawn.PlayerKey
            if not key then key = "AI_" .. tostring(pawn) end
            if processed[key] then
                if IsPawnAlive(pawn) then
                    goto continue_wh
                else
                    processed[key] = nil
                end
            end

            if IsPawnAlive(pawn) and pawn.TeamID and pawn.TeamID ~= myTeamId then
                local isAI = pcall(Game.IsAI, pawn) and true or false
                local vis = isAI and colors.botVis or colors.playerVis
                local occ = isAI and colors.botOcc or colors.playerOcc
                local visOutline = isAI and (colors.botVisOutline or colors.botVis) or colors.playerVis
                local occOutline = isAI and (colors.botOccOutline or colors.botOcc) or colors.playerOcc

                ProcessPawnMeshes(pawn, vis, occ, visOutline, occOutline)
                processed[key] = true
                processedCount = processedCount + 1
            end
            ::continue_wh::
        end
    end)
end


local function StartWallhackSystem()
    _G.WallhackProcessed = {}

    local function tryStart()
        pcall(function()
            if slua_GameFrontendHUD and Game then
                local pc = slua_GameFrontendHUD:GetPlayerController()
                if IsValidWH(pc) then
                    SetupConsole()
                    if WH_TIMER then
                        WH_TIMER = nil
                    end
                    WH_TIMER = pc:AddGameTimer(TICK_INTERVAL, true, WallhackTick)
                    return
                end
            end
            if slua_GameFrontendHUD then
                local retryPC = slua_GameFrontendHUD:GetPlayerController()
                if IsValidWH(retryPC) then
                    retryPC:AddGameTimer(1.0, false, tryStart)
                end
            end
        end)
    end
    tryStart()
end
StartWallhackSystem()

-- ===================== No Recoil (ثابت مع HUD، لا يتأثر بتغيير المباراة) =====================
local function NoRecoil()
    pcall(function()
        if not slua_GameFrontendHUD then return end
        local player = GameplayData.GetPlayerCharacter()
        if not IsValidWH(player) then return end
        local wpn = player.GetCurrentWeapon and player:GetCurrentWeapon()
        if IsValidWH(wpn) then
            local shoot = wpn.ShootWeaponEntity or wpn.ShootWeaponEntity_GEN_VARIABLE
            if IsValidWH(shoot) then
                shoot.GameDeviationFactor = 0
                shoot.ExtraHitPerformScale = 150
                shoot.HUDAlphaDecreaseSpeedScale = 5
            end
        end
    end)
end

local function StartNoRecoil()
    local function tryStart()
        pcall(function()
            if slua_GameFrontendHUD then
                slua_GameFrontendHUD:AddGameTimer(0.013, true, NoRecoil)
            else
                -- إذا لم يكن HUD جاهزًا بعد، حاول مرة أخرى بعد 0.5 ثانية
                if _G.SetTimer then
                    _G.SetTimer(0.5, tryStart)
                end
            end
        end)
    end
    tryStart()
end
StartNoRecoil()

-- ===================== Magic Head (ثابت مع HUD، لا يتأثر بتغيير المباراة) =====================
_G.VIPConfig = _G.VIPConfig or {}
_G.VIPConfig.MagicHeadEnabled = true
_G.VIPConfig.MagicHeadScale = 200
_G.MagicHeadState = _G.MagicHeadState or { applied = {}, lastScale = nil }

local function ApplyMagicHead()
    if not _G.VIPConfig.MagicHeadEnabled then return end
    local cfg = _G.VIPConfig
    local scalePercent = cfg.MagicHeadScale
    local state = _G.MagicHeadState

    if state.lastScale ~= scalePercent then
        state.applied = {}
        state.lastScale = scalePercent
    end

    local localPlayer = GameplayData.GetPlayerCharacter()
    if not IsValidWH(localPlayer) then return end
    local allChars = Game.GetAllPlayerPawns()
    if not allChars then return end

    for _, enemy in pairs(allChars) do
        if IsValidWH(enemy) and enemy ~= localPlayer and (enemy.TeamID or 0) ~= localPlayer.TeamID then
            local isAlive = false
            pcall(function() isAlive = enemy:IsAlive() end)
            if not isAlive then goto continue_magic end

            local mesh = enemy.Mesh
            if not IsValidWH(mesh) then goto continue_magic end

            local physAsset = mesh.PhysicsAssetOverride
            if not IsValidWH(physAsset) and IsValidWH(mesh.SkeletalMesh) then
                physAsset = mesh.SkeletalMesh.PhysicsAsset
            end
            if not IsValidWH(physAsset) or not physAsset.SkeletalBodySetups then goto continue_magic end

            local assetName = (physAsset.GetName and physAsset:GetName()) or tostring(physAsset)
            if state.applied[assetName] then goto continue_magic end

            local sc = 1.0 + scalePercent / 100.0
            local setups = physAsset.SkeletalBodySetups
            for i = 1, 80 do
                local bs = nil
                pcall(function() bs = (type(setups.Get) == "function") and setups:Get(i-1) or setups[i] end)
                if not bs or not IsValidWH(bs) then break end
                local bn = tostring(bs.BoneName):lower()
                if bn == "head" or bn == "skull" or bn == "b_head" or bn == "c_head" then
                    local ag = bs.AggGeom
                    pcall(function()
                        local bx = (ag and ag.BoxElems) or bs.BoxElems
                        if bx then
                            local b = (type(bx.Get) == "function") and bx:Get(0) or bx[1]
                            if b then
                                b.X = (b.X or 30) * sc
                                b.Y = (b.Y or 30) * sc
                                b.Z = (b.Z or 60) * sc
                                if type(bx.Set) == "function" then bx:Set(0, b) else bx[1] = b end
                            end
                        end
                    end)
                    pcall(function()
                        local sp = (ag and ag.SphylElems) or bs.SphylElems
                        if sp then
                            local s = (type(sp.Get) == "function") and sp:Get(0) or sp[1]
                            if s then
                                if s.Radius then s.Radius = s.Radius * sc end
                                if s.Length then s.Length = s.Length * sc end
                                if type(sp.Set) == "function" then sp:Set(0, s) else sp[1] = s end
                            end
                        end
                    end)
                    pcall(function()
                        local sr = (ag and ag.SphereElems) or bs.SphereElems
                        if sr then
                            local r = (type(sr.Get) == "function") and sr:Get(0) or sr[1]
                            if r and r.Radius then
                                r.Radius = r.Radius * sc
                                if type(sr.Set) == "function" then sr:Set(0, r) else sr[1] = r end
                            end
                        end
                    end)
                    break
                end
            end
            if mesh.RecreatePhysicsState then mesh:RecreatePhysicsState() end
            state.applied[assetName] = true
            ::continue_magic::
        end
    end
end

local function StartMagicHead()
    local function tryStart()
        pcall(function()
            if slua_GameFrontendHUD then
                slua_GameFrontendHUD:AddGameTimer(5.0, true, ApplyMagicHead)
            else
                if _G.SetTimer then
                    _G.SetTimer(0.5, tryStart)
                end
            end
        end)
    end
    tryStart()
end
StartMagicHead()
