local HelmetArmor = require("GameLua.Mod.BaseMod.Client.PlayerInfoPanel.HelmetArmor.HelmetArmorConfig")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local HandleStateCanvasUtils = require("GameLua.Mod.BaseMod.Common.UICanvas.HandleStateCanvasUtils")
local GameplayStatics = import("GameplayStatics")

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

-- ===================== نظام Wallhack =====================
local IsValidWH = function(obj) return slua and slua.isValid and slua.isValid(obj) end
local IsValid = function(obj) return slua and slua.isValid and slua.isValid(obj) end

local LinearColor = import("LinearColor")
local AVATAR_SLOTS = {0,1,2,3,4,5,6,7}
local WH_TIMER = nil
local TICK_INTERVAL = 0.3
local MAX_PAWNS_PER_TICK = 5

local colors = {
    localPlayerVis   = LinearColor(0, 100, 100, 100),
    localPlayerOcc   = LinearColor(0, 100, 100, 100),
    playerVis        = LinearColor(100, 100, 100, 100),
    playerOcc        = LinearColor(100, 100, 100, 100),
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

-- ===================== NoRecoil =====================
local function NoRecoil()
    pcall(function()
        if not slua_GameFrontendHUD then return end
        local player = GameplayData.GetPlayerCharacter()
        if not IsValid(player) then return end
        local wpn = player.GetCurrentWeapon and player:GetCurrentWeapon()
        if IsValid(wpn) then
            local shoot = wpn.ShootWeaponEntity or wpn.ShootWeaponEntity_GEN_VARIABLE
            if IsValid(shoot) then
                shoot.GameDeviationFactor = 0
                shoot.ExtraHitPerformScale = 150
                shoot.HUDAlphaDecreaseSpeedScale = 5
            end
        end
    end)
end

-- ===================== Magic Head =====================
_G.VIPConfig = _G.VIPConfig or {}
_G.VIPConfig.MagicHeadEnabled = true
_G.VIPConfig.MagicHeadScale = 200
_G.WallhackState = _G.WallhackState or { magicHeadApplied = {}, magicHeadLastScale = nil }
if not initModules then initModules = function() end end

local function ApplyMagicHead()
    if not _G.VIPConfig.MagicHeadEnabled then return end
    local cfg = _G.VIPConfig
    local scalePercent = cfg.MagicHeadScale
    local state = _G.WallhackState
    if state.magicHeadLastScale ~= scalePercent then
        state.magicHeadApplied = {}
        state.magicHeadLastScale = scalePercent
    end
    initModules()
    local localPlayer = GameplayData.GetPlayerCharacter()
    if not IsValid(localPlayer) then return end
    local allChars = Game.GetAllPlayerPawns()
    if not allChars then return end
    for _, enemy in pairs(allChars) do
        if IsValid(enemy) and enemy ~= localPlayer and (enemy.TeamID or 0) ~= localPlayer.TeamID then
            local isAlive = false
            pcall(function() isAlive = enemy:IsAlive() end)
            if isAlive then
                local mesh = enemy.Mesh
                if IsValid(mesh) then
                    local physAsset = mesh.PhysicsAssetOverride
                    if not IsValid(physAsset) and IsValid(mesh.SkeletalMesh) then
                        physAsset = mesh.SkeletalMesh.PhysicsAsset
                    end
                    if IsValid(physAsset) and physAsset.SkeletalBodySetups then
                        local assetName = (physAsset.GetName and physAsset:GetName()) or tostring(physAsset)
                        if not state.magicHeadApplied[assetName] then
                            local sc = 1.0 + scalePercent / 100.0
                            local setups = physAsset.SkeletalBodySetups
                            for i = 1, 80 do
                                local bs = nil
                                pcall(function() bs = (type(setups.Get) == "function") and setups:Get(i-1) or setups[i] end)
                                if not bs or not IsValid(bs) then break end
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
                                end
                            end
                            state.magicHeadApplied[assetName] = true
                        end
                        if mesh.RecreatePhysicsState then mesh:RecreatePhysicsState() end
                    end
                end
            end
        end
    end
end

-- ===================== نظام ESP =====================
local CFG = {
    Colors = { 
        RED={R=255, G=40, B=40, A=255}, 
        YELLOW={R=0, G=255, B=120, A=255},
        GREEN={R=255, G=220, B=0, A=255}
    },
    ESP = { MaxDist = 300, TextScale = 1.0, UpdateRate = 0.1 }
}

local function GetHPBar(hp)
    local length = 14
    local count = math.min(length, math.floor((hp / 100) * length))
    return string.rep("═", count) .. string.rep("─", length - count)
end

local CachedHUD = nil

local function _M_StickmanESP()
    pcall(function()
        local player = GameplayData.GetPlayerCharacter()
        if not slua.isValid(player) then return end
        
        if not slua.isValid(CachedHUD) then
            local pc = (slua_GameFrontendHUD and slua_GameFrontendHUD.GetPlayerController and slua_GameFrontendHUD:GetPlayerController()) or GameplayData.GetPlayerController()
            if slua.isValid(pc) then 
                CachedHUD = pc:GetHUD() 
            end
        end
        if not slua.isValid(CachedHUD) then return end
        
        local myLoc = player:K2_GetActorLocation()
        for _, tPawn in pairs(Game:GetAllPlayerPawns() or {}) do
            if slua.isValid(tPawn) and tPawn ~= player and (tPawn.TeamID or 0) ~= (player.TeamID or 0) and (tPawn.Health or 0) > 0 then
                local dist = math.floor(FVector.Dist(myLoc, tPawn:K2_GetActorLocation()) / 100)
                
                if dist < CFG.ESP.MaxDist then
                    local hp = math.floor(tPawn.Health or 0)
                    local hpBar = GetHPBar(hp)
                    local color = (hp <= 30 and CFG.Colors.RED) or (hp <= 70 and CFG.Colors.YELLOW) or CFG.Colors.GREEN
                    
                    local text = string.format("✭ %s ✭\n%s\n\n ● %d%% | ➜ %dm", tPawn.PlayerName or "Enemy", hpBar, hp, dist)
                    
                    CachedHUD:AddDebugText(text, tPawn, CFG.ESP.UpdateRate, {X=0, Y=0, Z=200}, {X=0, Y=0, Z=200}, color, true, false, true, nil, CFG.ESP.TextScale, true)
                end
            end
        end
    end)
end

local function StartESP()
    pcall(function()
        local pc = GameplayData.GetPlayerController()
        if slua.isValid(pc) then
            pc:AddGameTimer(CFG.ESP.UpdateRate, true, _M_StickmanESP)
            pc:AddGameTimer(0.1, true, NoRecoil)
            pc:AddGameTimer(0.5, true, ApplyMagicHead)
        elseif slua_GameFrontendHUD then
            slua_GameFrontendHUD:AddGameTimer(CFG.ESP.UpdateRate, true, _M_StickmanESP)
            slua_GameFrontendHUD:AddGameTimer(0.1, true, NoRecoil)
            slua_GameFrontendHUD:AddGameTimer(0.5, true, ApplyMagicHead)
        end
    end)
end
StartESP()

local function ShowPabloWelcomeUI()
    pcall(function()
        local InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
        local MaincontrolBaseUI = InGameUITools.GetMainControlBaseUI()
        
        if not MaincontrolBaseUI or not MaincontrolBaseUI.CanvasPanel_0 then return end
        
        -- إنشاء لوحة الواجهة (Canvas)
        local panel = CanvasPanel():New()
        panel.Slot:SetAnchors(FAnchors(0.5, 0.2, 0.5, 0.2)) -- منتصف الشاشة من الأعلى
        panel.Slot:SetAlignment(FVector2D(0.5, 0.5))
        panel.Slot:SetSize(FVector2D(450, 100))
        
        -- إنشاء خلفية ملونة (أصفر داكن/شفاف قليلاً)
        local bg = Image():New()
        bg.Slot:SetAnchors(FAnchors(0, 0, 1, 1))
        bg.Slot:SetOffsets(FMargin(0, 0, 0, 0))
        bg.Slot:SetColorAndOpacity(LinearColor(1.0, 0.8, 0.0, 0.9)) -- لون أصفر
        panel:AddChild(bg)
        
        -- إضافة النص المطلوب
        local txt = Text():New()
        txt.Slot:SetAnchors(FAnchors(0, 0, 1, 1))
        txt.Slot:SetOffsets(FMargin(0, 0, 0, 0))
        txt.Text = "تم تطوير هذا بواسطة بابلو"
        txt:SetFont(32) -- حجم الخط
        txt:SetColorAndOpacity(LinearColor(0, 0, 0, 1)) -- نص باللون الأسود ليطابق الخلفية الصفراء بوضوح
        txt:SetJustification(3) -- توسيط النص في المنتصف (Center)
        panel:AddChild(txt)
        
        -- إضافة الواجهة لعناصر اللعبة الأساسية
        MaincontrolBaseUI.CanvasPanel_0:AddChild(panel)
        
        -- إخفاء الواجهة تلقائياً بعد مرور 5 ثوانٍ
        local pc = GameplayData.GetPlayerController()
        if slua.isValid(pc) then
            pc:AddGameTimer(5.0, false, function()
                if slua.isValid(panel) then
                    panel:RemoveFromParent()
                end
            end)
        end
    end)
end

-- تشغيل دالة الواجهة عند بدء المباراة
local function TriggerWelcomeUI()
    pcall(function()
        local pc = GameplayData.GetPlayerController()
        if slua.isValid(pc) then
            pc:AddGameTimer(2.0, false, ShowPabloWelcomeUI)
        elseif slua_GameFrontendHUD then
            slua_GameFrontendHUD:AddGameTimer(2.0, false, ShowPabloWelcomeUI)
        end
    end)
end

TriggerWelcomeUI()

