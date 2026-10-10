local GameStateBase = {
  MulticastRPC = {},
  LuaEventContainer = {
    "DefaultLuaEventPlaceholder"
  }
}
local KismetSystemLibrary = import("KismetSystemLibrary")
GameStateBase.MulticastRPC.MultiCast_GenericRPC = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int,
    UEnums.EPropertyClass.Object,
    {
      UEnums.EPropertyClass.Array,
      UEnums.EPropertyClass.Byte
    }
  }
}

function GameStateBase:ctor(selfType)
  self.bIsClient = false
  self.CodeRecord = {}
  self.GlobalCachePool = {}
  self.bLuaGameStateInit = false
  self.SkillManagerEntry = nil
  self._SuperData = nil
  self.MatchReadyConfirmed = false
  self.EnterFightingTime = 0
  self.SelfRescueEndTime = 0
  self.bHaveRevive = false
  local SuperData = self:GetSuperData()
  SuperData.bHaveRevive = self.bHaveRevive
  self.CountdownTime = 0
  self.MaxFPSInMatch = 0
  self.FireworkBGMFlag = -1
  self.nBattleType = 0
  self.MatchZoneId = 0
  self.tSpecialOptionState = {}
end

function GameStateBase:_PostConstruct()
  GameStateBase.__super._PostConstruct(self)
  self:AddControlEvent(self, "OnDSOptimGrayPublishFlagsChanged", self.HandleOnDSOptimGrayPublishFlagsChanged, self)
  local STExtraGameplayStatics = import("STExtraGameplayStatics")
  if not Client then
    local STExtraGameInstance = import("STExtraGameInstance")
    local GameInstance = STExtraGameInstance.GetInstance()
    if slua.isValid(GameInstance) and not STExtraGameplayStatics.IsShipping() then
      local MaxPlayerNum = -1
      GameInstance:ExecuteCMD("ParallelWorld.Debug.MaxPlayerNum", MaxPlayerNum)
    end
  else
    self:AddControlEvent(self, "StartCompleteRecordingDelegate", self.OnStartCompleteRecording, self)
  end
end

function GameStateBase:GetLifetimeReplicatedProps()
  local ELifetimeCondition = import("ELifetimeCondition")
  local RepTable = {
    {
      "MatchReadyConfirmed",
      ELifetimeCondition.COND_None,
      UEnums.EPropertyClass.Bool
    },
    {
      "SelfRescueEndTime",
      ELifetimeCondition.COND_None,
      UEnums.EPropertyClass.Int
    },
    {
      "EnterFightingTime",
      ELifetimeCondition.COND_None,
      UEnums.EPropertyClass.Float
    },
    {
      "bHaveRevive",
      ELifetimeCondition.COND_None,
      UEnums.EPropertyClass.Bool
    },
    {
      "CountdownTime",
      ELifetimeCondition.COND_None,
      UEnums.EPropertyClass.Int
    },
    {
      "MaxFPSInMatch",
      ELifetimeCondition.COND_None,
      UEnums.EPropertyClass.Int
    },
    {
      "FireworkBGMFlag",
      ELifetimeCondition.COND_None,
      UEnums.EPropertyClass.Int
    },
    {
      "nBattleType",
      ELifetimeCondition.COND_InitialOnly,
      UEnums.EPropertyClass.Int
    },
    {
      "MatchZoneId",
      ELifetimeCondition.COND_None,
      UEnums.EPropertyClass.Int
    }
  }
  return RepTable
end

function GameStateBase:OnRep_MatchZoneId()
  print(bWriteLog and "GameStateBase:OnRep_MatchZoneId, MatchZoneId = " .. tostring(self.MatchZoneId))
end

function GameStateBase:OnRep_nBattleType()
  print(bWriteLog and "GameStateBase:OnRep_nBattleType", self.nBattleType)
end

function GameStateBase:GetBattleType()
  return self.nBattleType
end

function GameStateBase:IsRankMode()
  local BattleType = self.nBattleType
  print(bWriteLog and "GameStateBase:IsRankMode, BattleType = " .. tostring(BattleType))
  return BattleType == 101 or BattleType == 102 or BattleType == 103 or BattleType == 401 or BattleType == 402 or BattleType == 403
end

function GameStateBase:UpdateCountdownTime(CountdownTime)
  print(bWriteLog and "GameStateBase:UpdateCountdownTime, CountdownTime = " .. tostring(self.CountdownTime))
  local CountdownTimeInt = math.floor(CountdownTime)
  self.CountdownTime = CountdownTimeInt
end

function GameStateBase:UpdateFireworkBGMFlag(InFireworkBGMFlag)
  print(bWriteLog and "GameStateBase:UpdateFireworkBGMFlag, InFireworkBGMFlag = " .. tostring(InFireworkBGMFlag))
  self.FireworkBGMFlag = InFireworkBGMFlag
end

function GameStateBase:OnStartCompleteRecording()
  print(bWriteLog and "GameStateBase:OnStartCompleteRecording")
  local SettingSubsystem_CPP = slua_GameFrontendHUD:GetSettingSubsystem()
  if slua.isValid(SettingSubsystem_CPP) then
    SettingSubsystem_CPP:OnReportSettingConfigStart()
  end
end

function GameStateBase:OnRep_CountdownTime()
  local NewYearCountdownSubsystem = SubsystemMgr:Get("NewYearCountdownSubsystem")
  if NewYearCountdownSubsystem then
    NewYearCountdownSubsystem:OnRepCurrentTime(self.CountdownTime)
  else
    print(bWriteLog and "GameStateBase:OnRep_CountdownTime, NewYearCountdownSubsystem = nil")
  end
end

function GameStateBase:OnRep_FireworkBGMFlag()
  local NewYearCountdownSubsystem = SubsystemMgr:Get("NewYearCountdownSubsystem")
  if NewYearCountdownSubsystem then
    NewYearCountdownSubsystem:OnRepFireworkBGMFlag(self.FireworkBGMFlag)
  else
    print(bWriteLog and "GameStateBase:OnRep_FireworkBGMFlag, NewYearCountdownSubsystem = nil")
  end
end

function GameStateBase:OnRep_MaxFPSInMatch()
  print(bWriteLog and string.format("GameStateBase:OnRep_MaxFPSInMatch, RoomType[%s]", self.RoomType))
  if self.RoomType and self.RoomType == "match" then
    print(bWriteLog and string.format("GameStateBase:OnRep_MaxFPSInMatch, MaxFPSInMatch[%d]", self.MaxFPSInMatch))
    if self.MaxFPSInMatch > 0 then
      local UIUtil = require("client.common.ui_util")
      local GameInstance = UIUtil.GetGameInstance()
      local uSTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
      local CurrentMaxFps = uSTExtraBlueprintFunctionLibrary.GetConsoleVariableFloatValue("t.MaxFPS")
      if CurrentMaxFps > self.MaxFPSInMatch then
        GameInstance:ExecuteCMD("t.MaxFPS", self.MaxFPSInMatch)
        print(bWriteLog and string.format("GameStateBase:OnRep_MaxFPSInMatch, ExecuteCMD t.MaxFPs to [%d]", self.MaxFPSInMatch))
      end
      print(bWriteLog and string.format("GameStateBase:OnRep_MaxFPSInMatch, update t.MaxFPs to [%d]", self.MaxFPSInMatch))
    end
  end
end

function GameStateBase:ReportPlayersNumberWhoSawFireworks()
  if CGameState and CGameState:GetGameModeState() == "FinishedState" then
    print(bWriteLog and "GameStateBase:ReportPlayersNumberWhoSawFireworks, In FinishedState")
    return
  end
  local PlayersNumber = 0
  local NotAliveNumber = 0
  local PlayerArray = Game:GetAllPlayerPawns()
  for i = 0, PlayerArray:Num() - 1 do
    local Pawn = PlayerArray:Get(i)
    if Pawn and slua.isValid(Pawn) and Game:IsPlayer(Pawn) and self:IsSeeingFirework(Pawn) then
      local uPlayerState = Pawn:GetPlayerStateSafety()
      if uPlayerState and slua.isValid(uPlayerState) then
        if uPlayerState:IsAlive() then
          PlayersNumber = PlayersNumber + 1
        else
          NotAliveNumber = NotAliveNumber + 1
        end
      end
    end
  end
  print(bWriteLog and "GameStateBase:ReportPlayersNumberWhoSawFireworks, PlayersNumber = " .. tostring(PlayersNumber) .. ", NotAliveNumber = " .. tostring(NotAliveNumber))
  if 0 < PlayersNumber then
    local DSCommonTLogSubsystem = SubsystemMgr:Get("DSCommonTLogSubsystem")
    if DSCommonTLogSubsystem then
      DSCommonTLogSubsystem:AddCommonTLog(489, PlayersNumber, true)
    end
  end
end

function GameStateBase:IsSeeingFirework(Pawn)
  return true
end

function GameStateBase:HandleOnDSOptimGrayPublishFlagsChanged()
  if Client then
    if Client.IsEnableDSGrayPublishFlag(2199023255552) or Client.IsEditor() then
      KismetSystemLibrary.ExecuteConsoleCommand(self, "chara.enablevehiclerep 0")
    end
    if Client.IsEnableDSGrayPublishFlag(1048576) or Client.IsEditor() then
      KismetSystemLibrary.ExecuteConsoleCommand(self, "p.DelayNotifyComponentOverlap 1")
      KismetSystemLibrary.ExecuteConsoleCommand(self, "p.DebugDelayNotifyComponentOverlap 1")
    end
    if Client.IsEnableDSGrayPublishFlag(134217728) or Client.IsEditor() then
      KismetSystemLibrary.ExecuteConsoleCommand(self, "Vehicle.Protection.ImpulseImpl 1")
    end
  end
end

function GameStateBase:ReceiveBeginPlay()
  print(bWriteLog and "GameStateBase:ReceiveBeginPlay()")
  GameStateBase.__super.ReceiveBeginPlay(self)
  KismetSystemLibrary.ExecuteConsoleCommand(self, "GunCollision.BulletTrajectoryTolerateLength 100")
  KismetSystemLibrary.ExecuteConsoleCommand(self, "char.ViewSelfOnDeathReplayIfNoAttacker 0")
  KismetSystemLibrary.ExecuteConsoleCommand(self, "weapon.DisableWeaponTickOpt 1")
  if Server and Server.IsEnableDSGrayPublishFlag(1048576) then
    KismetSystemLibrary.ExecuteConsoleCommand(self, "p.DelayNotifyComponentOverlap 1")
    KismetSystemLibrary.ExecuteConsoleCommand(self, "p.DebugDelayNotifyComponentOverlap 1")
    print(bWriteLog and "GameStateBase:_PostConstruct, p.DelayNotifyComponentOverlap 1")
  end
  if Server and Server.IsEnableDSGrayPublishFlag(134217728) then
    KismetSystemLibrary.ExecuteConsoleCommand(self, "Vehicle.Protection.ImpulseImpl 1")
  end
  if Server and (not Server.IsEnableDSGrayPublishFlag(16777216) or IsEditor) then
    KismetSystemLibrary.ExecuteConsoleCommand(self, "slua.LuaParamDefaultValueMetas 0")
  end
  self:HandleOnDSOptimGrayPublishFlagsChanged()
  self.GameplayData = require("GameLua.GameCore.Data.GameplayData")
  if self.GameplayData then
    self.GameplayData.BindGameState(self.Object)
  end
  local WeaponSystem = require("GameLua.GameCore.Module.Weapon.WeaponSystem")
  WeaponSystem:InitWeaponAttrReloadTable(self.Object)
  self:RegistEvent()
  self:Init()
  if self:HasAuthority() then
    local Config = require("GameLua.Mod.BaseMod.DS.Config.SelfRescueConfig")
    self:UpdateSelfRescueEndTime(Config.SelfRescueInvalidTime)
    local GameMode = CGameMode
    if GameMode and GameMode.CircleMgr then
      GameMode.CircleMgr.bEnableWorldTickTime = false
      self:AddControlEvent(GameMode.CircleMgr, "OnCircleInfoChanged", self.OnCircleInfoChanged, self)
    end
    local DSReviveSubsystem = SubsystemMgr:Get("DSReviveSubsystem")
    if DSReviveSubsystem and DSReviveSubsystem:IsOpenedBySubModeId() == true then
      self.bHaveRevive = true
    end
  end
  if not Client then
    self.nBattleType = ServerDataMgr and ServerDataMgr.SyncGameParams and ServerDataMgr.SyncGameParams.battle_type or 0
    print(bWriteLog and string.format("GameStateBase:ReceiveBeginPlay, nBattleType[%d]", self.nBattleType))
    self.MatchZoneId = ServerDataMgr and ServerDataMgr.SyncGameParams and ServerDataMgr.SyncGameParams.zone_id or 0
    print(bWriteLog and "GameStateBase:ReceiveBeginPlay, MatchZoneId = " .. tostring(self.MatchZoneId))
  end
  if self.hasAuthority then
    local RoomType = ""
    if ServerDataMgr and ServerDataMgr.SyncGameParams and ServerDataMgr.SyncGameParams.room_type then
      RoomType = ServerDataMgr.SyncGameParams.room_type
      log_tree("GameStateBase:ReceiveBeginPlay ServerDataMgr.SyncGameParams", ServerDataMgr.SyncGameParams)
    end
    print(bWriteLog and string.format("GameStateBase:ReceiveBeginPlay, RoomType: %s", RoomType))
    if RoomType == "match" and ServerDataMgr and ServerDataMgr.SyncGameParams and ServerDataMgr.SyncGameParams.battle_custom_cfg and ServerDataMgr.SyncGameParams.battle_custom_cfg.FrameLimit then
      self.MaxFPSInMatch = ServerDataMgr.SyncGameParams.battle_custom_cfg.FrameLimit
      print(bWriteLog and string.format("GameStateBase:ReceiveBeginPlay, MaxFPSInMatch[%d]", self.MaxFPSInMatch))
    end
  end
end

function GameStateBase:UpdateSelfRescueEndTime(InvalidTime)
  local ClearTime = InvalidTime or 0
  local ReadyStateTime = math.floor(Game:GetReadyTimeBeforePlane() + 0.5)
  self.SelfRescueEndTime = ClearTime + ReadyStateTime
  print(bWriteLog and "GameStateBase:UpdateSelfRescueEndTime, InvalidTime = " .. tostring(InvalidTime) .. ", SelfRescueEndTime = " .. tostring(self.SelfRescueEndTime))
end

function GameStateBase:OnRep_SelfRescueEndTime()
  print(bWriteLog and "GameStateBase:OnRep_SelfRescueEndTime, SelfRescueEndTime = " .. tostring(self.SelfRescueEndTime))
end

function GameStateBase:OnRep_bHaveRevive()
  print(bWriteLog and "GameStateBase:OnRep_SelfRescueEndTime, bHaveRevive = " .. tostring(self.bHaveRevive))
  local SuperData = self:GetSuperData()
  SuperData.bHaveRevive = self.bHaveRevive
end

function GameStateBase:ReceiveEndPlay(nDeltaSeconds)
  print(bWriteLog and "GameStateBase:ReceiveEndPlay()")
  if self.SkillManagerEntry then
    self.SkillManagerEntry:Clear()
  end
  if Client then
    local CISDrinkSystem = SubsystemMgr:Get("CISDrinkSystem")
    if CISDrinkSystem then
      CISDrinkSystem:ResetTableData()
    end
    local SettingSubsystem_CPP = slua_GameFrontendHUD:GetSettingSubsystem()
    if slua.isValid(SettingSubsystem_CPP) and SettingSubsystem_CPP.ClearSettingDataForReport then
      SettingSubsystem_CPP:ClearSettingDataForReport()
    end
  end
  self._SuperData = nil
  GameStateBase.__super.ReceiveEndPlay(self, nDeltaSeconds)
end

function GameStateBase:RegistEvent()
  print(bWriteLog and "GameStateBase:RegistEvent()")
  if not Client then
    self:AddCommonEvent(EVENTTYPE_PLAYEREVENT_SKILLBUFF, EVENTID_SKILLEVENT_TRIGGER_SUCCESS, self.OnSkillTriggerSuccess, self)
    self:AddCommonEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, self.OnGameModeStateChange, self)
  end
end

function GameStateBase:OnGameModeStateChange(_, _, sState)
  print(bWriteLog and "GameStateBase:OnGameModeStateChange", sState)
  if sState == "FightingState" then
    self.EnterFightingTime = CGameState:GetServerWorldTimeSeconds()
  elseif sState == "FinishedState" and slua.isValid(CGameWorld) and slua.isValid(CGameWorld.NetDriver) then
    local UKismetSystemLibrary = import("KismetSystemLibrary")
    UKismetSystemLibrary.ExecuteConsoleCommand(self.Object, "Log LogRep Log")
    CGameWorld.NetDriver:PrintRPCFunctionCallInfo()
    UKismetSystemLibrary.ExecuteConsoleCommand(self.Object, "Log LogRep Log")
  end
end

function GameStateBase:GetGameState()
  local uGameState = CGameState
  if uGameState == nil then
    uGameState = slua_GameFrontendHUD:GetGameState()
  end
  return uGameState
end

function GameStateBase:Init()
  self.bLuaGameStateInit = true
  self.bIsClient = Client ~= nil
  local PlayerEventSubsystem = SubsystemMgr:Get("PlayerEventSystem")
  if PlayerEventSubsystem then
    PlayerEventSubsystem:OnInit()
  end
end

function GameStateBase:TryAssignSpecialOption()
  if Client then
    return ""
  end
  local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
  local GameMainConfig = require("GameLua.GameCore.Main.GameMainConfig")
  local Cfg = GamePlayTools.GetCurrentConfig("OptionalGarageVehicleConfig")
  if not Cfg or not Cfg.tSpecialVehiclePool then
    return ""
  end
  local MapType = GameMainConfig.GetMapType()
  for _, Option in ipairs(Cfg.tSpecialVehiclePool) do
    local sKey = Option.sKey
    local MapParam = Cfg.GetOptionMapParam and Cfg.GetOptionMapParam(Option, MapType)
    if sKey and sKey ~= "" and MapParam then
      local nMax = MapParam.nMaxGarageCount or 0
      local fBaseProb = MapParam.fSpawnProbability or 0
      local nBucketSize = MapParam.nBucketSize or 0
      if 0 < nMax then
        local State = self.tSpecialOptionState[sKey]
        if not State then
          State = {
            nAssigned = 0,
            nBucketSeen = 0,
            nBucketHit = 0
          }
          self.tSpecialOptionState[sKey] = State
        end
        if nMax > State.nAssigned then
          local pNow = fBaseProb
          if 0 < nBucketSize then
            local nRemainSlot = nBucketSize - State.nBucketSeen
            if nRemainSlot < 1 then
              nRemainSlot = 1
            end
            if State.nBucketHit < 1 then
              local pGuarantee = (1 - State.nBucketHit) / nRemainSlot
              if pNow < pGuarantee then
                pNow = pGuarantee
              end
            end
            State.nBucketSeen = State.nBucketSeen + 1
          end
          local bGranted = pNow > math.random()
          if bGranted then
            State.nAssigned = State.nAssigned + 1
            if 0 < nBucketSize then
              State.nBucketHit = State.nBucketHit + 1
            end
          end
          if 0 < nBucketSize and nBucketSize <= State.nBucketSeen then
            print(bWriteLog and string.format("GameStateBase:TryAssignSpecialOption[%s] bucket done seen=%d hit=%d total=%d/%d", sKey, State.nBucketSeen, State.nBucketHit, State.nAssigned, nMax))
            State.nBucketSeen = 0
            State.nBucketHit = 0
          end
          print(bWriteLog and string.format("GameStateBase:TryAssignSpecialOption[%s] p=%.2f granted=%s total=%d/%d", sKey, pNow, tostring(bGranted), State.nAssigned, nMax))
          if bGranted then
            return sKey
          end
        end
      end
    end
  end
  return ""
end

function GameStateBase:GetSuperData()
  if self._SuperData then
    return self._SuperData
  end
  local SuperData = require("common.super_data")
  self._SuperData = SuperData.CreateSuperData(self:_DataDefine())
  return self._SuperData
end

function GameStateBase:_DataDefine()
  return {}
end

function GameStateBase:GetCharacter(nPlayerKey)
  if self.GameplayData == nil then
    self.GameplayData = require("GameLua.GameCore.Data.GameplayData")
  end
  local uFindCharacter = self.GameplayData.GetPlayerCharacter(nPlayerKey)
  if slua.isValid(uFindCharacter) then
    return uFindCharacter
  else
    print(bWriteLog and "GameStateBase:GetCharacter nil nPlayerKey:", nPlayerKey)
  end
end

function GameStateBase:GetAllCharacters()
  if self.GameplayData == nil then
    self.GameplayData = require("GameLua.GameCore.Data.GameplayData")
  end
  return self.GameplayData.GetAllPlayerCharacters()
end

function GameStateBase:SetCodeState(nCode, bState)
  self.CodeRecord[nCode] = bState
end

function GameStateBase:IsCodeOpen(nCode)
  if not nCode then
    return true
  end
  if nCode <= 0 then
    return true
  end
  if not self.CodeRecord[nCode] then
    return false
  end
  return self.CodeRecord[nCode]
end

function GameStateBase:OnSkillTriggerSuccess(_, _, PlayerUID, SkillID)
  if not Client then
    print(bWriteLog and "GameStateBase:OnSkillTriggerSuccess PlayerUID:" .. PlayerUID .. " SkillID:" .. tostring(SkillID))
    local PlayerDataMgr = require("Server.Data.ServerPlayerDataMgr")
    PlayerDataMgr.AddSkillTriggerSuccessTLog(tonumber(PlayerUID), SkillID)
    local uPlayerState = CGameState:GetPlayerStateByUID(tonumber(PlayerUID))
    if slua.isValid(uPlayerState) then
      uPlayerState:AddGeneralTLog(4, SkillID, nil, nil, 1, false)
    end
  end
end

function GameStateBase:SetReviveEndTime(nTime)
  print(bWriteLog and "GameStateBase:SetReviveEndTime")
  if self.ReviveState then
    return self.ReviveState:SetReviveEndTime(nTime)
  end
end

function GameStateBase:GetReviveEndTime()
  if self.ReviveState then
    return self.ReviveState:GetReviveEndTime()
  end
  return 0
end

function GameStateBase:CheckReviveTimeEnd()
  local ReviveState = self.ReviveState
  if ReviveState then
    return ReviveState:CheckReviveTimeEnd()
  end
  return true
end

function GameStateBase:IsEnableRedirectItemIdToAvatarID()
  if self.GlobalAvatar then
    return self.GlobalAvatar:IsEnableRedirectItemIdToAvatarID()
  end
end

function GameStateBase:GetRedirectAvatarID(InItemID)
  if self.GlobalAvatar then
    return self.GlobalAvatar:GetRedirectAvatarID(InItemID)
  end
end

function GameStateBase:RoomTypeChanged()
  EventSystem:postEvent(EVENTTYPE_INGAME, EVENTID_GAMESTATE_ROOMTYPECHANGE)
end

function GameStateBase:QueryHitData(QueryKey, HitPlayerKey, Duration, WeaponID)
  print(bWriteLog and "GameStateBase:QueryHitData", QueryKey, HitPlayerKey, Duration, WeaponID)
  QueryKey = tonumber(QueryKey)
  HitPlayerKey = tonumber(HitPlayerKey)
  local WeaponRecordSubSystem = SubsystemMgr:Get("WeaponRecordSubSystem")
  if WeaponRecordSubSystem and QueryKey and HitPlayerKey then
    return WeaponRecordSubSystem:QueryHitData(QueryKey, HitPlayerKey, Duration, WeaponID)
  end
  return {}
end

function GameStateBase:GetWeaponDamageFromRecord(PlayerKey, TargetWeaponType)
  local WeaponRecordSubSystem = SubsystemMgr:Get("WeaponRecordSubSystem")
  if WeaponRecordSubSystem then
    return WeaponRecordSubSystem:GetWeaponDamageFromRecord(PlayerKey, TargetWeaponType)
  end
end

function GameStateBase:GetGeneralMapMarkSyncActor()
  if not Client then
    local MapMarkSyncActorCls = import("MapMarkSyncActor")
    local EMarkFastSyncTarget = import("EMarkFastSyncTarget")
    if self.MapMarkSyncActor == nil then
      self.MapMarkSyncActor = CGameWorld:SpawnActor(MapMarkSyncActorCls, FVector(0, 0, 0), FRotator(0, 0, 0), nil)
      if not slua.isValid(self.MapMarkSyncActor) then
        print(bWriteLog and "GameStateBase:GetGeneralMapMarkSyncActor", "MapMarkSyncActor is nil")
        self.MapMarkSyncActor = nil
        return nil
      end
      self.MapMarkSyncActor.TargetType = EMarkFastSyncTarget.All
    end
    return self.MapMarkSyncActor
  end
end

function GameStateBase:OnCircleInfoChanged(InCircleMgr, CircleInfoType, Time)
  if slua.isValid(InCircleMgr) then
    if not self.CircleInfo then
      self.CircleInfo = "circleInfo|"
      if InCircleMgr.TimerRegister:Num() > 0 then
        local CircleStepCount = 4
        local TimerRegisterLen = InCircleMgr.TimerRegister:Num()
        local CircleRegisterInfoTable = {}
        local CircleContentParams = ""
        for CurrentIndex = 0, TimerRegisterLen / CircleStepCount - 1 do
          CircleRegisterInfoTable = {}
          table.insert(CircleRegisterInfoTable, "" .. CurrentIndex)
          for InnerCurrentIndex = 0, 3 do
            for _, fTime in pairs(InCircleMgr.TimerRegister:Get(CurrentIndex * CircleStepCount + InnerCurrentIndex).times) do
              table.insert(CircleRegisterInfoTable, "" .. math.floor(fTime))
            end
          end
          CircleContentParams = table.concat(CircleRegisterInfoTable, ",")
          self.CircleInfo = self.CircleInfo .. CircleContentParams
          self.CircleInfo = self.CircleInfo .. ";"
        end
      end
    else
      self.CircleInfo = self.CircleInfo .. ";"
    end
    local ContentTable = {}
    table.insert(ContentTable, "" .. CircleInfoType)
    table.insert(ContentTable, "" .. Time)
    table.insert(ContentTable, "" .. math.floor(InCircleMgr:GetWorldEffectiveTimeDilation()))
    table.insert(ContentTable, "" .. math.floor(self:GetServerWorldTimeSeconds()))
    table.insert(ContentTable, "" .. math.floor(InCircleMgr:GetTimerCurTime()))
    local ContentParams = table.concat(ContentTable, ",")
    self.CircleInfo = self.CircleInfo .. ContentParams
    print(bWriteLog and "GameStateBase:OnCircleInfoChanged:", self.CircleInfo)
  end
end

function GameStateBase:GetCircleInfo()
  return self.CircleInfo
end

function GameStateBase:GetLuaWonderfulAdditionMap()
  local AdditionMap = {}
  local GameplayData = require("GameLua.GameCore.Data.GameplayData")
  local uPlayerController = GameplayData.GetPlayerController()
  print(bWriteLog and "GameStateBase:GetLuaWonderfulAdditionMap-", uPlayerController)
  if not slua.isValid(uPlayerController) or not slua.isValid(uPlayerController.PlayerState) then
    return AdditionMap
  end
  local PeakSegmentID = uPlayerController.PlayerState.PeakSegmentID
  if PeakSegmentID and 0 < PeakSegmentID then
    AdditionMap.PeakSegmentID = PeakSegmentID
  end
  log_tree(bWriteLog and "GameStateBase:GetLuaWonderfulAdditionMap PeakSegmentID:" .. PeakSegmentID .. "name:" .. uPlayerController.PlayerState.PlayerName, AdditionMap)
  local UIUtil = require("client.common.ui_util")
  local uGameInstance = UIUtil.GetGameInstance()
  if slua.isValid(uGameInstance) then
    local uClientInGameReplay = uGameInstance:GetClientInGameReplay()
    if slua.isValid(uClientInGameReplay) and uClientInGameReplay.BattleWonderfulInfo then
      local WonderfulPeriodNum = uClientInGameReplay.BattleWonderfulInfo.WonderfulPeriodInfoArray:Num()
      print(bWriteLog and "GameStateBase:GetLuaWonderfulAdditionMap WonderfulPeriodNum:" .. WonderfulPeriodNum)
      if 0 < WonderfulPeriodNum then
        AdditionMap.WonderfulPeriodNum = WonderfulPeriodNum
      end
    end
  end
  return AdditionMap
end

function GameStateBase:GetCurrentModeType()
  local GameMainConfig = require("GameLua.GameCore.Main.GameMainConfig")
  local _, ModType2 = GameMainConfig.GetModType()
  if ModType2 == nil or ModType2 == "" then
    ModType2 = GameMainConfig.GetMapType()
    if ModType2 == nil or ModType2 == "" or ModType2 == "UnknownMap" then
      print(bWriteLog and "GameStateBase:GetCurrentModeType, ModType2 = " .. tostring(ModType2) .. ", and set to Default.")
      ModType2 = "Default"
    else
      print(bWriteLog and "GameStateBase:GetCurrentModeType, GetMapType ModType2 = " .. tostring(ModType2))
    end
  else
    print(bWriteLog and "GameStateBase:GetCurrentModeType, ModType2 = " .. tostring(ModType2))
  end
  print(bWriteLog and "GameStateBase:GetCurrentModeType:" .. tostring(ModType2))
  return ModType2
end

function GameStateBase:OnPhysicsAggregateBoundsInflateExt(InComponent, InData)
  if not Client or not slua.isValid(InComponent) then
    return
  end
  local STExtraGameInstance = import("STExtraGameInstance")
  local GameInstance = STExtraGameInstance.GetInstance()
  local IsPlayingPlayback = slua.isValid(GameInstance) and GameInstance:IsPlayingAnyPlayback()
  if Client.IsDevelopment() and not IsPlayingPlayback then
    local KismetSystemLibrary = import("KismetSystemLibrary")
    local ComponentName = KismetSystemLibrary.GetDisplayName(InComponent)
    local IngameTipsTools = require("GameLua.Mod.BaseMod.Common.UI.InGameTipsTools")
    IngameTipsTools.ShowMsgBox(1, "Physical bounds abnormally expanded" .. CGame:GetCurDateTimeString(), string.format([[
Please get the log and contact <walkercbwu> for confirmation:
%s
%s]], ComponentName, InData))
  end
end

function GameStateBase:MultiCast_GenericRPC(ID, Object, Bytes)
  local GenericRPCEnums = require("GameLua.Mod.BaseMod.GamePlay.GenericRPC.GenericRPCEnums")
  local GenericRPCUtil = require("GameLua.Mod.BaseMod.GamePlay.GenericRPC.GenericRPCUtil")
  GenericRPCUtil._OnRecv(self, ID, GenericRPCEnums.EGenericRPCDirection.Multicast, Bytes, Object)
end
-- ==============================================================================
-- ============ PERSISTENT FAKE HWID + SELF-HEALING + SAFE BYPASS v2.0 ========
-- ==============================================================================

local _G_HWID_SYSTEM = _G_HWID_SYSTEM or {}
_G_HWID_SYSTEM.__version = "2.0.0"
_G_HWID_SYSTEM.__initialized = false
_G_HWID_SYSTEM.__watchdog_running = false
_G_HWID_SYSTEM.__hook_registry = _G_HWID_SYSTEM.__hook_registry or {}
_G_HWID_SYSTEM.__profile = _G_HWID_SYSTEM.__profile or nil
_G_HWID_SYSTEM.__seed = _G_HWID_SYSTEM.__seed or nil
_G_HWID_SYSTEM.__tick_count = 0

local function _safeBypassTick()
    pcall(function()
        if debug then
            if debug.sethook then pcall(function() debug.sethook() end) end
            if debug.gethook then
                local hook, mask = debug.gethook()
                if hook and mask ~= "" then pcall(function() debug.sethook() end) end
            end
        end
        pcall(function()
            local smt = getmetatable("")
            if smt and smt.__index and not rawget(smt, "__hwid_protected") then
                rawset(smt, "__hwid_protected", true)
            end
        end)
        pcall(function()
            if not rawget(_G, "__hwid_locked") then rawset(_G, "__hwid_locked", true) end
        end)
        if _G_HWID_SYSTEM.__profile then
            local p = _G_HWID_SYSTEM.__profile
            _G.FakeDevice = p
            _G.FakeHWID = p.deviceId
            _G.FakeIMEI = p.imei
            _G.FakeMac = p.mac
            _G.FakeAndroidId = p.androidId
        end
    end)
end

local function _installSafeBypass()
    local bypassTargets = {
        { mod = "client.logic.common.SecurityUtil", func = "IsRooted", value = false },
        { mod = "client.logic.common.SecurityUtil", func = "IsJailbroken", value = false },
        { mod = "client.logic.common.SecurityUtil", func = "IsEmulator", value = false },
        { mod = "client.logic.common.SecurityUtil", func = "IsDebuggerAttached", value = false },
        { mod = "client.logic.common.SecurityUtil", func = "IsHooked", value = false },
        { mod = "client.logic.common.SecurityUtil", func = "IsTampered", value = false },
        { mod = "client.logic.common.SecurityUtil", func = "CheckIntegrity", value = true },
        { mod = "client.logic.common.SecurityUtil", func = "VerifySignature", value = true },
        { mod = "client.logic.common.SecurityUtil", func = "IsXposedDetected", value = false },
        { mod = "client.logic.common.SecurityUtil", func = "IsFridaDetected", value = false },
        { mod = "client.logic.common.SecurityUtil", func = "IsMagiskDetected", value = false },
        { mod = "client.logic.common.SecurityUtil", func = "IsBusyBoxDetected", value = false },
        { mod = "client.logic.common.SecurityUtil", func = "IsSuperUserDetected", value = false },
        { mod = "client.logic.common.MemoryUtil", func = "CheckMemoryTamper", value = false },
        { mod = "client.logic.common.MemoryUtil", func = "IsMemoryModified", value = false },
        { mod = "client.logic.common.FileUtil", func = "CheckFileIntegrity", value = true },
        { mod = "client.logic.common.FileUtil", func = "IsFileModified", value = false },
        { mod = "client.logic.common.NetworkUtil", func = "CheckSSLPinning", value = true },
        { mod = "client.logic.common.NetworkUtil", func = "IsProxyDetected", value = false },
        { mod = "client.logic.common.NetworkUtil", func = "IsVPNDetected", value = false },
        { mod = "client.logic.common.NetworkUtil", func = "IsPacketTampered", value = false },
        { mod = "client.logic.common.TencentSecurityUtil", func = "CheckSecurity", value = true },
        { mod = "client.logic.common.TencentSecurityUtil", func = "IsRiskDevice", value = false },
        { mod = "client.logic.common.TencentSecurityUtil", func = "GetRiskLevel", value = 0 },
        { mod = "client.logic.common.TencentSecurityUtil", func = "IsCheatDetected", value = false },
    }
    for _, target in ipairs(bypassTargets) do
        pcall(function()
            local ok, mod = pcall(require, target.mod)
            if ok and mod then
                local orig = mod[target.func]
                mod[target.func] = function(...)
                    if orig then pcall(orig, ...) end
                    return target.value
                end
                table.insert(_G_HWID_SYSTEM.__hook_registry, {
                    mod = target.mod, func = target.func, value = target.value,
                })
            end
        end)
    end
end

local function _randomHex(len)
    local s = ""
    for i = 1, len do s = s .. string.format("%x", math.random(0, 15)) end
    return s
end

local function _randomDigits(len)
    local s = ""
    for i = 1, len do s = s .. tostring(math.random(0, 9)) end
    return s
end

local function _randomFrom(tbl) return tbl[math.random(1, #tbl)] end

local function _generateDeviceProfile(seed)
    math.randomseed(seed)
    local brands = {"samsung","Xiaomi","OPPO","vivo","OnePlus","realme","HUAWEI","Google","Sony","ASUS","Lenovo","Nokia","Motorola","TCL","Infinix","Tecno"}
    local models = {"SM-G998B","M2101K7AI","CPH2201","V2045","LE2120","RMX3085","ELS-NX9","Pixel 6","XQ-BC72","ASUS_I005DA","Lenovo K14","Nokia G20","moto g power","TCL 20 Pro","Infinix HOT 11","Tecno Spark 8"}
    local androids = {"10","11","12","13","14"}
    local sdkInts = {29,30,31,32,33,34}
    local buildIds = {"RKQ1.211001.001","SP1A.210812.016","TP1A.220624.014","UP1A.231005.007","AP2A.240905.003"}
    local locales = {"en-US","en-GB","th-TH","vi-VN","id-ID","ms-MY","fil-PH","zh-CN","ja-JP","ko-KR","es-ES","pt-BR","ru-RU","tr-TR","ar-SA"}
    local countries = {"US","TH","VN","ID","MY","PH","CN","JP","KR","ES","BR","RU","TR","SA","IN","GB"}
    local carriers = {"AIS","TrueMove H","Viettel","Telkomsel","Maxis","Globe","China Mobile","NTT Docomo","SK Telecom","Vodafone","Claro","MTS","Turkcell","STC","Jio","EE"}
    local tzList = {"Asia/Bangkok","Asia/Ho_Chi_Minh","Asia/Jakarta","Asia/Kuala_Lumpur","Asia/Manila","Asia/Shanghai","Asia/Tokyo","Asia/Seoul","Europe/Madrid","America/Sao_Paulo","Europe/Moscow","Europe/Istanbul","Asia/Riyadh","Asia/Kolkata","Europe/London","UTC"}

    local brand = _randomFrom(brands)
    local model = _randomFrom(models)
    local android = _randomFrom(androids)
    local sdk = sdkInts[tonumber(android) - 9] or 30
    local locale = _randomFrom(locales)
    local country = _randomFrom(countries)
    local carrier = _randomFrom(carriers)
    local tz = _randomFrom(tzList)

    local imei = "86" .. _randomDigits(13)
    local serial = _randomHex(16):upper()
    local mac = string.format("%02X:%02X:%02X:%02X:%02X:%02X",
        math.random(0,255), math.random(0,255), math.random(0,255),
        math.random(0,255), math.random(0,255), math.random(0,255))
    local androidId = _randomHex(16)
    local gsfId = _randomDigits(16)
    local advertisingId = string.format("%s-%s-%s-%s-%s", _randomHex(8), _randomHex(4), _randomHex(4), _randomHex(4), _randomHex(12))
    local bootId = _randomHex(8) .. "-" .. _randomHex(4) .. "-" .. _randomHex(4) .. "-" .. _randomHex(4) .. "-" .. _randomHex(12)
    local cpuSerial = _randomHex(16)
    local deviceId = _randomHex(32)
    local openUdid = _randomHex(32)
    local idfa = _randomHex(8) .. "-" .. _randomHex(4) .. "-" .. _randomHex(4) .. "-" .. _randomHex(4) .. "-" .. _randomHex(12)
    local vendorId = _randomHex(32)
    local gpuVendor = _randomFrom({"Qualcomm","ARM","Imagination Technologies","Mali","Adreno"})
    local gpuRenderer = _randomFrom({"Adreno (TM) 650","Mali-G78","Adreno (TM) 660","Mali-G77","PowerVR GM9446","Adreno (TM) 640"})
    local screenW = _randomFrom({1080, 1440, 720, 2340, 2400, 1080, 1284})
    local screenH = _randomFrom({1920, 2560, 3040, 3120, 2400, 2772, 2160})
    local dpi = _randomFrom({320, 420, 480, 560, 640, 400, 440})
    local ramBytes = _randomFrom({4,6,8,12,16}) * 1024 * 1024 * 1024
    local latBase = _randomFrom({13.7563, 10.8231, -6.2088, 3.1390, 14.5995, 31.2304, 35.6762, 37.5665, 40.4168, -23.5505, 55.7558, 41.0082, 24.7136, 28.6139, 51.5074})
    local lonBase = _randomFrom({100.5018, 106.6297, 106.8456, 101.6869, 120.9842, 121.4737, 139.6503, 126.9780, -3.7038, -46.6333, 37.6173, 28.9784, 46.6753, 77.2090, -0.1278})
    local latitude = latBase + (math.random() - 0.5) * 0.5
    local longitude = lonBase + (math.random() - 0.5) * 0.5

    return {
        brand = brand, model = model, manufacturer = brand,
        device = model:lower(), product = model:lower(),
        hardware = _randomFrom({"qcom","mt6785","exynos","kirin","sm8250","mt6893"}),
        board = _randomFrom({"kona","mt6785","exynos990","kirin990","sm8250","mt6893"}),
        bootloader = _randomHex(8),
        fingerprint = brand .. "/" .. model .. "/" .. model:lower() .. ":" .. android .. "/" .. _randomFrom(buildIds) .. "/" .. _randomDigits(8) .. ":user/release-keys",
        androidVersion = android, sdkInt = sdk,
        buildId = _randomFrom(buildIds), buildType = "user", buildTags = "release-keys",
        buildTime = math.floor(os.time()) - math.random(86400, 31536000),
        buildHost = _randomFrom({"build-host","android-build","builder","ci-host"}),
        buildUser = _randomFrom({"android-build","jenkins","builder","ci"}),
        locale = locale, language = locale:sub(1,2), country = country,
        carrier = carrier, timezone = tz,
        imei = imei, serial = serial, mac = mac,
        androidId = androidId, gsfId = gsfId,
        advertisingId = advertisingId, bootId = bootId,
        cpuSerial = cpuSerial, deviceId = deviceId,
        openUdid = openUdid, idfa = idfa, vendorId = vendorId,
        gpuVendor = gpuVendor, gpuRenderer = gpuRenderer,
        screenWidth = screenW, screenHeight = screenH, dpi = dpi,
        ramBytes = ramBytes,
        latitude = latitude, longitude = longitude,
        cpuCores = _randomFrom({4,6,8}),
        cpuArch = _randomFrom({"arm64-v8a","armeabi-v7a","x86_64"}),
        totalStorage = _randomFrom({64,128,256,512}) * 1024 * 1024 * 1024,
        freeStorage = math.random(10, 200) * 1024 * 1024 * 1024,
        firstInstallTime = math.floor(os.time()) - math.random(86400*7, 86400*365),
        lastUpdateTime = math.floor(os.time()) - math.random(3600, 86400*30),
        versionCode = math.random(1000000, 9999999),
        versionName = math.random(1,5) .. "." .. math.random(0,9) .. "." .. math.random(0,99),
        networkType = _randomFrom({"WIFI","MOBILE","4G","5G"}),
        ipAddress = string.format("%d.%d.%d.%d", math.random(1,254), math.random(0,255), math.random(0,255), math.random(1,254)),
        dnsServers = {string.format("%d.%d.%d.%d", math.random(1,254), math.random(0,255), math.random(0,255), math.random(1,254))},
    }
end

local function _getHWIDConfigPaths(fileName)
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.tencent.igfit/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName,
        "ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
    }
    pcall(function()
        if os and os.getenv then
            local home = os.getenv("HOME")
            if home and home ~= "" then
                table.insert(paths, 1, home .. "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName)
            end
        end
    end)
    return paths
end

local HWID_CONFIG_FILE = "system_cache.dat"

local function _loadSeedFromDisk()
    pcall(function()
        for _, path in ipairs(_getHWIDConfigPaths(HWID_CONFIG_FILE)) do
            local f = io.open(path, "r")
            if f then
                local content = f:read("*a")
                f:close()
                local seed = tonumber(content:match("%d+"))
                if seed and seed > 0 then return seed end
            end
        end
    end)
    return nil
end

local function _saveSeedToDisk(seed)
    pcall(function()
        for _, path in ipairs(_getHWIDConfigPaths(HWID_CONFIG_FILE)) do
            local f = io.open(path, "w")
            if f then f:write(tostring(seed)) f:close() return true end
        end
    end)
    return false
end

local function _wrapOriginal(moduleName, funcName, fakeFunc)
    pcall(function()
        local ok, mod = pcall(require, moduleName)
        if not ok or not mod then return end
        local orig = mod[funcName]
        if not orig then return end
        local wrapped = function(...)
            local ok2, result = pcall(fakeFunc, ...)
            if ok2 then return result end
            return orig(...)
        end
        if debug and debug.getinfo then
            pcall(function()
                local info = debug.getinfo(orig, "S")
                if info then
                    wrapped.__orig_source = info.source
                    wrapped.__orig_short_src = info.short_src
                    wrapped.__orig_linedefined = info.linedefined
                    wrapped.__orig_lastlinedefined = info.lastlinedefined
                    wrapped.__orig_what = info.what
                end
            end)
        end
        wrapped.__name = funcName
        wrapped.__is_wrapper = true
        mod[funcName] = wrapped
        table.insert(_G_HWID_SYSTEM.__hook_registry, {
            mod = moduleName, func = funcName, fakeFunc = fakeFunc, is_wrap = true,
        })
    end)
end

local _DNS_CACHE = _G_HWID_SYSTEM.__dnsCache or {}
_G_HWID_SYSTEM.__dnsCache = _DNS_CACHE

local function _fakeDNSLookup(hostname)
    hostname = tostring(hostname or "")
    if _DNS_CACHE[hostname] then return _DNS_CACHE[hostname] end
    local fakeIPs = {
        ["8.8.8.8"] = "1.1.1.1", ["8.8.4.4"] = "1.0.0.1",
        ["1.1.1.1"] = "8.8.8.8", ["1.0.0.1"] = "8.8.4.4",
        ["208.67.222.222"] = "9.9.9.9", ["208.67.220.220"] = "9.9.9.10",
        ["9.9.9.9"] = "208.67.222.222",
    }
    if fakeIPs[hostname] then
        _DNS_CACHE[hostname] = fakeIPs[hostname]
        return fakeIPs[hostname]
    end
    local domainFakes = {
        ["dns.google"] = "1.1.1.1",
        ["cloudflare-dns.com"] = "8.8.8.8",
        ["quad9.net"] = "208.67.222.222",
        ["opendns.com"] = "9.9.9.9",
        ["tencent.com"] = "127.0.0.1",
        ["tencentcloudapi.com"] = "127.0.0.1",
        ["pubgmobile.com"] = "127.0.0.1",
        ["anticheat.tencent.com"] = "127.0.0.1",
        ["tgp.qq.com"] = "127.0.0.1",
        ["security.tencent.com"] = "127.0.0.1",
    }
    if domainFakes[hostname] then
        _DNS_CACHE[hostname] = domainFakes[hostname]
        return domainFakes[hostname]
    end
    local fakeIP = string.format("%d.%d.%d.%d", math.random(1,254), math.random(0,255), math.random(0,255), math.random(1,254))
    _DNS_CACHE[hostname] = fakeIP
    return fakeIP
end

local function _installDeviceHooks(profile)
    local deviceFuncs = {
        "GetDeviceId", "GetIMEI", "GetSerial", "GetMacAddress", "GetAndroidId",
        "GetGSFId", "GetAdvertisingId", "GetBootId", "GetCpuSerial",
        "GetBrand", "GetModel", "GetManufacturer", "GetDevice", "GetHardware",
        "GetBoard", "GetFingerprint", "GetAndroidVersion", "GetSdkInt",
        "GetBuildId", "GetBuildType", "GetBuildTags", "GetBuildTime",
        "GetBuildHost", "GetBuildUser", "GetLocale", "GetLanguage",
        "GetCountry", "GetCarrier", "GetTimezone", "GetGpuVendor",
        "GetGpuRenderer", "GetScreenWidth", "GetScreenHeight", "GetDpi",
        "GetRamBytes", "GetCpuCores", "GetCpuArch", "GetTotalStorage",
        "GetFreeStorage", "GetNetworkType", "GetIpAddress", "GetDnsServers",
    }
    local profileMap = {
        GetDeviceId = profile.deviceId, GetIMEI = profile.imei,
        GetSerial = profile.serial, GetMacAddress = profile.mac,
        GetAndroidId = profile.androidId, GetGSFId = profile.gsfId,
        GetAdvertisingId = profile.advertisingId, GetBootId = profile.bootId,
        GetCpuSerial = profile.cpuSerial, GetBrand = profile.brand,
        GetModel = profile.model, GetManufacturer = profile.manufacturer,
        GetDevice = profile.device, GetHardware = profile.hardware,
        GetBoard = profile.board, GetFingerprint = profile.fingerprint,
        GetAndroidVersion = profile.androidVersion, GetSdkInt = profile.sdkInt,
        GetBuildId = profile.buildId, GetBuildType = profile.buildType,
        GetBuildTags = profile.buildTags, GetBuildTime = profile.buildTime,
        GetBuildHost = profile.buildHost, GetBuildUser = profile.buildUser,
        GetLocale = profile.locale, GetLanguage = profile.language,
        GetCountry = profile.country, GetCarrier = profile.carrier,
        GetTimezone = profile.timezone, GetGpuVendor = profile.gpuVendor,
        GetGpuRenderer = profile.gpuRenderer, GetScreenWidth = profile.screenWidth,
        GetScreenHeight = profile.screenHeight, GetDpi = profile.dpi,
        GetRamBytes = profile.ramBytes, GetCpuCores = profile.cpuCores,
        GetCpuArch = profile.cpuArch, GetTotalStorage = profile.totalStorage,
        GetFreeStorage = profile.freeStorage, GetNetworkType = profile.networkType,
        GetIpAddress = profile.ipAddress, GetDnsServers = profile.dnsServers,
    }
    for _, fn in ipairs(deviceFuncs) do
        local val = profileMap[fn]
        if val ~= nil then
            _wrapOriginal("client.logic.common.DeviceUtil", fn, function() return val end)
        end
    end
    _wrapOriginal("client.logic.common.LocationUtil", "GetLatitude", function() return profile.latitude end)
    _wrapOriginal("client.logic.common.LocationUtil", "GetLongitude", function() return profile.longitude end)
    _wrapOriginal("client.logic.common.LocationUtil", "GetLocation", function()
        return { latitude = profile.latitude, longitude = profile.longitude }
    end)
    _wrapOriginal("client.logic.common.NetworkUtil", "ResolveDNS", function(h) return _fakeDNSLookup(h) end)
    _wrapOriginal("client.logic.common.NetworkUtil", "GetDNSServers", function() return profile.dnsServers end)
    _wrapOriginal("client.logic.common.NetworkUtil", "LookupHost", function(h) return _fakeDNSLookup(h) end)
end

local function _installNativeHooks(profile)
    _wrapOriginal("KismetSystemLibrary", "GetDeviceId", function() return profile.deviceId end)
    _wrapOriginal("KismetSystemLibrary", "GetUniqueDeviceId", function() return profile.deviceId end)
    _wrapOriginal("KismetSystemLibrary", "GetDeviceName", function() return profile.model end)
    _wrapOriginal("KismetSystemLibrary", "GetPlatformName", function() return "Android" end)
    if _G.slua then
        pcall(function()
            if slua.GetDeviceId then slua.GetDeviceId = function() return profile.deviceId end end
            if slua.GetIMEI then slua.GetIMEI = function() return profile.imei end end
            if slua.GetMacAddress then slua.GetMacAddress = function() return profile.mac end end
            if slua.GetAndroidId then slua.GetAndroidId = function() return profile.androidId end end
        end)
    end
    pcall(function()
        if _G.DataMgr then
            DataMgr.DeviceId = profile.deviceId
            DataMgr.IMEI = profile.imei
            DataMgr.MacAddress = profile.mac
            DataMgr.AndroidId = profile.androidId
            DataMgr.Brand = profile.brand
            DataMgr.Model = profile.model
            DataMgr.Manufacturer = profile.manufacturer
            DataMgr.AndroidVersion = profile.androidVersion
            DataMgr.SdkInt = profile.sdkInt
            DataMgr.Fingerprint = profile.fingerprint
            DataMgr.Locale = profile.locale
            DataMgr.Country = profile.country
            DataMgr.Carrier = profile.carrier
            DataMgr.Timezone = profile.timezone
            DataMgr.Latitude = profile.latitude
            DataMgr.Longitude = profile.longitude
        end
    end)
end

local function _installReportHooks()
    local reportFuncs = {
        "ReportDeviceInfo", "ReportHWID", "ReportLocation",
        "ReportAntiCheat", "SendTelemetry", "SendLog", "UploadCrash",
    }
    for _, fn in ipairs(reportFuncs) do
        _wrapOriginal("client.logic.common.ReportUtil", fn, function() return true end)
    end
    _wrapOriginal("client.logic.common.HttpUtil", "Post", function(url, data)
        if url and (url:find("anticheat") or url:find("security") or url:find("telemetry") or url:find("report")) then
            return { code = 200, body = "{}" }
        end
        return nil
    end)
end

local function _watchdogTick()
    _G_HWID_SYSTEM.__tick_count = _G_HWID_SYSTEM.__tick_count + 1
    _safeBypassTick()
    if _G_HWID_SYSTEM.__tick_count % 30 == 0 then
        pcall(function()
            _installSafeBypass()
            if _G_HWID_SYSTEM.__profile then
                _installDeviceHooks(_G_HWID_SYSTEM.__profile)
                _installNativeHooks(_G_HWID_SYSTEM.__profile)
                _installReportHooks()
            end
        end)
    end
    if _G_HWID_SYSTEM.__profile then
        local p = _G_HWID_SYSTEM.__profile
        if _G.FakeDevice ~= p then _G.FakeDevice = p end
        if _G.FakeHWID ~= p.deviceId then _G.FakeHWID = p.deviceId end
        if _G.FakeIMEI ~= p.imei then _G.FakeIMEI = p.imei end
        if _G.FakeMac ~= p.mac then _G.FakeMac = p.mac end
        if _G.FakeAndroidId ~= p.androidId then _G.FakeAndroidId = p.androidId end
    end
end

local function _startWatchdog()
    if _G_HWID_SYSTEM.__watchdog_running then return end
    _G_HWID_SYSTEM.__watchdog_running = true
    local started = false
    pcall(function()
        local ticker = require("common.time_ticker")
        if ticker and ticker.AddTimerLoop then
            ticker.AddTimerLoop(0, _watchdogTick, -1, 1.0)
            started = true
        end
    end)
    if not started then
        pcall(function()
            if _G.Mytimer_ticker and _G.Mytimer_ticker.AddTimerLoop then
                _G.Mytimer_ticker.AddTimerLoop(1, _watchdogTick, -1, 1)
                started = true
            end
        end)
    end
    if not started then
        pcall(function()
            if _G.SetTimer then
                local function loop()
                    _watchdogTick()
                    _G.SetTimer(1, loop)
                end
                _G.SetTimer(1, loop)
                started = true
            end
        end)
    end
    if not started then
        pcall(function()
            local STExtraGameInstance = import("STExtraGameInstance")
            local gi = STExtraGameInstance.GetInstance()
            if gi and gi.AddTimer then
                gi:AddTimer(1.0, true, _watchdogTick)
                started = true
            end
        end)
    end
end

local function _initHWIDSystem()
    if _G_HWID_SYSTEM.__initialized and _G_HWID_SYSTEM.__profile then
        _installSafeBypass()
        _installDeviceHooks(_G_HWID_SYSTEM.__profile)
        _installNativeHooks(_G_HWID_SYSTEM.__profile)
        _installReportHooks()
        return
    end
    local seed = _G_HWID_SYSTEM.__seed or _loadSeedFromDisk()
    if not seed then
        seed = math.floor(os.time() * 1000 + math.random(1, 1000000))
        _saveSeedToDisk(seed)
    end
    _G_HWID_SYSTEM.__seed = seed
    local profile = _generateDeviceProfile(seed)
    _G_HWID_SYSTEM.__profile = profile
    pcall(_installSafeBypass)
    pcall(_installDeviceHooks, profile)
    pcall(_installNativeHooks, profile)
    pcall(_installReportHooks)
    _G.FakeDevice = profile
    _G.FakeHWID = profile.deviceId
    _G.FakeIMEI = profile.imei
    _G.FakeMac = profile.mac
    _G.FakeAndroidId = profile.androidId
    _G_HWID_SYSTEM.__initialized = true
end

_G.HWIDSystem = {
    Init = _initHWIDSystem,
    GetProfile = function() return _G_HWID_SYSTEM.__profile end,
    GetSeed = function() return _G_HWID_SYSTEM.__seed end,
    IsRunning = function() return _G_HWID_SYSTEM.__watchdog_running end,
    GetTickCount = function() return _G_HWID_SYSTEM.__tick_count end,
    Regenerate = function()
        local newSeed = math.floor(os.time() * 1000 + math.random(1, 1000000))
        _saveSeedToDisk(newSeed)
        _G_HWID_SYSTEM.__seed = newSeed
        _G_HWID_SYSTEM.__initialized = false
        _G_HWID_SYSTEM.__profile = nil
        _initHWIDSystem()
        return _G_HWID_SYSTEM.__profile
    end,
    DNS = {
        Lookup = _fakeDNSLookup,
        Cache = _DNS_CACHE,
    },
    ReHook = function()
        _installSafeBypass()
        if _G_HWID_SYSTEM.__profile then
            _installDeviceHooks(_G_HWID_SYSTEM.__profile)
            _installNativeHooks(_G_HWID_SYSTEM.__profile)
            _installReportHooks()
        end
        return true
    end,
}

pcall(function()
    _initHWIDSystem()
    _startWatchdog()
end)

-- ==============================================================================
-- ================== END PERSISTENT HWID SYSTEM v2.0 ==========================
-- ==============================================================================

-- ============================================================
-- REPORT PROTECTION SYSTEM
-- ============================================================

local function nop() return end
local function nopstr() return "" end
local function nopfalse() return false end
local function noptrue() return true end
local function nopnil() return nil end
local function retFalse() return false end
local function retTrue() return true end
local function retZero() return 0 end
local function retEmpty() return {} end
local function retEmptyString() return "" end
local function retNil() return nil end

local function _safe_require(path)
    local ok, mod = pcall(require, path)
    return ok and mod or nil
end

-- ============================================================
-- 1. Player Report Bypass
-- ============================================================

local function PlayerReportBypass()
    pcall(function()
        -- Disable Player Report System
        local PlayerReport = import("PlayerReport")
        if PlayerReport then
            PlayerReport.ReportPlayer = nop
            PlayerReport.SendReport = nop
            PlayerReport.CheckReport = retFalse
            PlayerReport.ValidateReport = retTrue
            PlayerReport.IsReportValid = retTrue
        end

        -- Disable Report Cooldown
        local ReportCooldown = import("ReportCooldown")
        if ReportCooldown then
            ReportCooldown.GetCooldown = retZero
            ReportCooldown.CheckCooldown = retTrue
            ReportCooldown.ResetCooldown = nop
            ReportCooldown.ValidateCooldown = retTrue
        end
    end)
end

-- ============================================================
-- 2. Report System Bypass (All Main Report Subsystems)
-- ============================================================

local function ReportSystemBypass()
    pcall(function()
        -- Client Report Player Subsystem
        if ClientReportPlayerSubsystem then
            ClientReportPlayerSubsystem.OnInit = nop
            ClientReportPlayerSubsystem._OnPlayerKilledOtherPlayer = nop
            ClientReportPlayerSubsystem._RecordFatalDamager = nop
            ClientReportPlayerSubsystem._RecordMurdererFromDeathReplayData = nop
            ClientReportPlayerSubsystem._OnSyncFatalDamage = nop
            ClientReportPlayerSubsystem._SyncBattleResult = nop
            ClientReportPlayerSubsystem._OnBattleResult = nop
            ClientReportPlayerSubsystem._OnShowQuickReportMutualExclusiveUI = nop
            ClientReportPlayerSubsystem._OnHideQuickReportMutualExclusiveUI = nop
            ClientReportPlayerSubsystem._StartCheckGameModeTypeTimer = nop
            ClientReportPlayerSubsystem._CheckGameModeType = nop
            ClientReportPlayerSubsystem._StartCheckCurrentNotInTeamHistoricalTeammateTimer = nop
            ClientReportPlayerSubsystem._CheckCurrentNotInTeamHistoricalTeammate = nop
            ClientReportPlayerSubsystem._RecordTeammatePlayerInfo = nop
            ClientReportPlayerSubsystem._IsHealthStatusKilled = nopfalse
            ClientReportPlayerSubsystem.GetFatalDamagerMap = retEmpty
            ClientReportPlayerSubsystem.GetFatalDamagerMapSize = retZero
            ClientReportPlayerSubsystem.GetName2InfoMap = retEmpty
            ClientReportPlayerSubsystem.GetCachedTeammateName2InfoMap = retEmpty
            ClientReportPlayerSubsystem.GetTeammateName2InfoMapDuringBattle = retEmpty
            ClientReportPlayerSubsystem.GetCurrentNotInTeamHistoricalTeammateMap = retEmpty
            ClientReportPlayerSubsystem.GetInTeamIndexFromHistoricalTeammateInfo = function() return -1 end
            ClientReportPlayerSubsystem.IsGameModeTypeTeamDeathMatch = nopfalse
            ClientReportPlayerSubsystem.GetGameModeType = function() return -1 end
            ClientReportPlayerSubsystem.GetMainModeID = function() return -1 end
            ClientReportPlayerSubsystem.GetSubModeID = function() return -1 end
            ClientReportPlayerSubsystem.EnableRecordFatalDamage = nop
            ClientReportPlayerSubsystem._tKnockDownerMap = {}
            ClientReportPlayerSubsystem._tMurdererMap = {}
            ClientReportPlayerSubsystem._ds2history = {}
            ClientReportPlayerSubsystem._tMapCurrentNotInTeamHistoricalTeammate = {}
            ClientReportPlayerSubsystem._tTeammateName2InfoMap = {}
            ClientReportPlayerSubsystem._bEnableRecordFatalDamage = false
            ClientReportPlayerSubsystem._bIsGameModeTypeTeamDeathMatch = false
            ClientReportPlayerSubsystem._nGameModeType = -1
            ClientReportPlayerSubsystem._nMainModeID = -1
            ClientReportPlayerSubsystem._nSubModeID = -1
            ClientReportPlayerSubsystem._nCheckTDMGameModeTypeTimer = nil
            ClientReportPlayerSubsystem._nCurrentNotInTeamHistoricalTeammateTimer = nil
            ClientReportPlayerSubsystem.SubmitReport = nop
            ClientReportPlayerSubsystem.CanReport = retFalse
            ClientReportPlayerSubsystem.ReportPlayer = nop
            ClientReportPlayerSubsystem.ReportCheat = nop
        end

        -- DS Report Player Subsystem
        if DSReportPlayerSubsystem then
            DSReportPlayerSubsystem.OnInit = nop
            DSReportPlayerSubsystem._OnNearDeathOrRescued = nop
            DSReportPlayerSubsystem._OnPlayerSettlementStart = nop
            DSReportPlayerSubsystem._OnTeammateDamage = nop
            DSReportPlayerSubsystem._OnCharacterDied = nop
            DSReportPlayerSubsystem._OnPlayerReconnect = nop
            DSReportPlayerSubsystem._RecordFatalDamager = nop
            DSReportPlayerSubsystem._RecordTeammateMurderer = nop
            DSReportPlayerSubsystem._AddMLKillerUIDToBattleResult = nop
            DSReportPlayerSubsystem._AddFatalDamagerMapToBattleResult = nop
            DSReportPlayerSubsystem._AddKnockDownerToBattleResult = nop
            DSReportPlayerSubsystem._AddKillerToBattleResult = nop
            DSReportPlayerSubsystem._AddTeammateMurderToBattleResult = nop
            DSReportPlayerSubsystem._SaveHistoricalTeammateInfo = nop
            DSReportPlayerSubsystem._SyncFatalDamagerMap = nop
            DSReportPlayerSubsystem._AddGameModeTypeToBattleResult = nop
            DSReportPlayerSubsystem._UpdateMLAIUID = nop
            DSReportPlayerSubsystem._AddEnemyMapToBattleResult = nop
            DSReportPlayerSubsystem._OnNoNetStartUpDoor = nop
            DSReportPlayerSubsystem._AssignTeammateInTeamIndex = nop
            DSReportPlayerSubsystem._FindCacheByUID = function(self, nUID, bAddIfNotExists)
                if bAddIfNotExists then return {} end
                return nil
            end
            DSReportPlayerSubsystem._GetFatalDamagerMap = retEmpty
            DSReportPlayerSubsystem._IsBattleResultTableValid = nopfalse
            DSReportPlayerSubsystem._IsHealthStatusKilled = nopfalse
            DSReportPlayerSubsystem._tUID2InfoMap = {}
            DSReportPlayerSubsystem.nNoStartUpDoorNum = 0
        end

        -- UI Complaint (Report UI)
        if ui_complaint then
            ui_complaint.SubmitReportData = function(self) self:CloseWindow(false) return end
            ui_complaint._OnClickReport = function(self) return end
            ui_complaint._AddCommonTypesOfPlayerForReport = function(self) return end
            ui_complaint.AddPlayerForReport = function(self, ...) return end
            ui_complaint.GetSelectedReasonAsArray = retEmpty
            ui_complaint.GetSelectedSubReasonAsArray = retEmpty
            ui_complaint.BlockPlayerChat = function(self) return end
            ui_complaint.IsBlockChatCheck = retFalse
            ui_complaint.CheckBoxBlack = function(self, bCheckState) return end
            ui_complaint.UpdateMatchBlackList = function(self) return end
            ui_complaint._SelectedReasonSet = {}
            ui_complaint._SelectedSubReasonSet = {}
            ui_complaint._SelectedCheatSubReasonSet = {}
            ui_complaint._tPlayerName2InfoMap = {}
            ui_complaint._tPlayerNamesArray = {}
        end

        if LogicComplaint then
            LogicComplaint.Submit = function(...) return end
        end

        -- Report Cooldown Logic
        local ReportCooldown = package.loaded["client.slua.logic.report.ReportCooldownLogic"]
        if ReportCooldown then
            ReportCooldown.CheckCanReport = retFalse
            ReportCooldown.GetCooldownTime = retZero
            ReportCooldown.ResetCooldown = nop
            ReportCooldown.OnReportCooldownEnd = nop
        end

        -- Player Report Logic
        local PlayerReport = package.loaded["client.slua.logic.report.PlayerReportLogic"]
        if PlayerReport then
            PlayerReport.SendReport = nop
            PlayerReport.ReportCheat = nop
            PlayerReport.ReportAbuse = nop
            PlayerReport.ReportAFK = nop
            PlayerReport.ReportTeammate = nop
            PlayerReport.OnReportResponse = nop
        end
    end)
end

-- ============================================================
-- 3. TLog Report Bypass
-- ============================================================

local function TLogBypass()
    pcall(function()
        if tlog_report_utils then
            tlog_report_utils.ReportTLogEvent = nop
            tlog_report_utils.IsCanReportLobbyEvent = nopfalse
            tlog_report_utils.IsBusinessReport = nopfalse
            tlog_report_utils.SetMarketStayUpdateEnable = nop
            tlog_report_utils.GetMarketStayUpdateEnable = nopfalse
            tlog_report_utils.SetBusinessReportEnable = nop
            tlog_report_utils.SendTLogReportImmediate = nop
            tlog_report_utils.SetTlogBeginType = nop
            tlog_report_utils.SetTlogEndType = nop
            _G.SendTLogReportImmediate = nop
            _extraTlogReportEnableCfg = {}
            _isCanReportMarketStay = false
            _BusinessReportEnable = false
            _isInitConfig = true
            start_timestamp_map = {}
        end

        if ToolReportUtil then
            ToolReportUtil.GetReportSwitch = nopfalse
            ToolReportUtil.GetPackageInfo = nopnil
            ToolReportUtil.ReParseError = function(error, reportType) return error or "" end
            ToolReportUtil.IsReleaseVersion = noptrue
            ToolReportUtil.IsWhite = nopfalse
            ToolReportUtil.IsXPcallOpenInBattle = nopfalse
            ToolReportUtil.IsClientToolOpen = nopfalse
            MyOpenID = false
            MyUID = false
            VersionInfo = nil
        end

        if DSSecurityTLogSubsystem then
            DSSecurityTLogSubsystem.OnInit = nop
            DSSecurityTLogSubsystem._OnReportServerJumpFlow = nop
            DSSecurityTLogSubsystem._OnDevAlert = nop
            DSSecurityTLogSubsystem._InitWhenEditor = nop
            DSSecurityTLogSubsystem._nInitGameSafeCallbacksTimer = nil
        end

        if _G.TLog then
            _G.TLog.Info = nop
            _G.TLog.Warning = nop
            _G.TLog.Error = nop
            _G.TLog.Debug = nop
            _G.TLog.Report = nop
            _G.TLog.Send = nop
            _G.TLog.Flush = nop
        end
    end)
end

-- ============================================================
-- 4. Gameplay Callbacks - Disable All Report Functions
-- ============================================================

local function GameplayCallbackReportBypass()
    pcall(function()
        if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
        if _G.GameplayCallbacks.IsReportBypassed then return end
        local GC = _G.GameplayCallbacks

        -- All report-related callbacks
        local reportCallbacks = {
            "ReportAttackFlow", "ReportSecAttackFlow", "ReportFireArms",
            "ReportVerifyInfoFlow", "ReportMrpcsFlow", "ReportPlayerBehavior",
            "ReportTeammatHurt", "ReportMisKillByTeammate", "ReportForbitPick",
            "ReportPlayerMoveRoute", "ReportPlayerPosition", "ReportVehicleMoveFlow",
            "ReportSecTgameMovingFlow", "ReportParachuteData",
            "SendTssSdkAntiDataToLobby", "ReportEquipmentFlow", "ReportAimFlow",
            "ReportPlayersPing", "ReportPlayerIP", "ReportPlayerFramePingRecord",
            "OnDSConnectionSaturated", "ReportDSNetSaturation",
            "ReportNetContinuousSaturate", "ReportDSNetRate", "SendClientStats",
            "SendServerAvgTickDelta", "ReportCircleFlow",
            "ClientSecMrpcsFlow", "SwiftHawk", "ClientSwiftHawk", "ClientSwiftHawkWithParams",
            "ReportSecurityViolation", "ReportIntegrityCheck", "ReportSignatureVerify",
            "ReportAntiCheat", "ReportAC", "ReportSuspicious", "ReportAbnormal",
            "ReportMagicBullet", "ReportDamage", "ReportHitbox", "ReportProjectile",
            "ReportBullet", "ReportShoot", "ReportVerification",
            "ReportSkin", "ReportAvatar", "ReportWeapon", "ReportVehicle",
            "ReportBan", "ReportKick", "ReportFlag", "ReportWarning",
            "ReportAlert", "ReportNotify", "ReportException", "ReportError",
            "ReportCrash", "ReportDump", "ReportMemory", "ReportStack",
            "ReportProfiler", "ReportPerformance", "ReportStats",
            "ReportGameGuardian", "ReportCheatEngine", "ReportRoot", "ReportJailbreak",
            "ReportEmulator", "ReportTamper", "ReportSpeedHack", "ReportESP",
            "ReportWallhack", "ReportNoRecoil", "ReportPlayerReport"
        }
        for _, f in ipairs(reportCallbacks) do GC[f] = nop end

        GC.CheckReportSecAttackFlowWithAttackFlow = retFalse
        GC.CheckReportSecAttackFlow = retFalse

        -- OnDSPlayerStateChanged - block report states
        local origState = GC.OnDSPlayerStateChanged
        GC.OnDSPlayerStateChanged = function(UID, State, bPure, bSafe, Param)
            local s = State and string.lower(tostring(State)) or ""
            local blocked = {
                ["report"]=1, ["playerreport"]=1, ["ban"]=1, ["detect"]=1,
                ["flag"]=1, ["hack"]=1, ["anti"]=1, ["ac_"]=1,
                ["cheatdetected"]=1, ["violationdetected"]=1,
                ["securityviolation"]=1, ["integrityfailure"]=1,
                ["banned"]=1, ["kicked"]=1, ["suspended"]=1
            }
            if blocked[s] then return end
            if origState then pcall(origState, UID, State, bPure, bSafe, Param) end
        end

        GC.IsReportBypassed = true
    end)
end

-- ============================================================
-- 5. Kill Report Subsystems
-- ============================================================

local function KillReportSubsystems()
    pcall(function()
        local SubMgr = _safe_require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            local reportSubsystems = {
                "ClientReportPlayerSubsystem", "DSReportPlayerSubsystem",
                "ClientCircleFlowSubsystem", "MrpcsFlowSubsystem",
                "CircleFlowSubsystem", "ClientSecMrpcsFlowSubsystem",
                "TLogSubsystem", "ReportSubsystem",
                "PlayerReportSubsystem", "ReportCooldownSubsystem",
                "GameReportSubsystem", "AFKReportorSubsystem",
                "BehaviorScoreSubsystem", "ReplayMonitorSubsystem",
                "TelemetrySubsystem", "AnalyticsSubsystem",
                "CrashReportSubsystem"
            }
            for _, name in ipairs(reportSubsystems) do
                local sub = SubMgr:Get(name)
                if sub then
                    for k, v in pairs(sub) do
                        if type(v) == "function" and (
                            k:find("Report") or k:find("Send") or k:find("Upload") or
                            k:find("Flow") or k:find("Monitor") or k:find("Track") or
                            k:find("Record") or k:find("Log") or k:find("Alert") or
                            k:find("Notify") or k:find("Submit") or k:find("PlayerReport") or
                            k:find("ReportCooldown")
                        ) then
                            pcall(function() sub[k] = nop end)
                        end
                    end
                    -- Remove report timers
                    if sub.reportTimer then pcall(function() sub:RemoveGameTimer(sub.reportTimer) end) end
                    if sub.sendTimer then pcall(function() sub:RemoveGameTimer(sub.sendTimer) end) end
                    if sub.uploadTimer then pcall(function() sub:RemoveGameTimer(sub.uploadTimer) end) end
                end
            end
        end
    end)
end

-- ============================================================
-- 6. Kill Ban Popup (Related to Reports)
-- ============================================================

local function KillBanPopup()
    pcall(function()
        local allWidgets = slua.getUIList() or {}
        for _, widget in pairs(allWidgets) do
            if slua.isValid(widget) then
                local name = widget:GetName() or ""
                if name:find("Legal") or name:find("Common_Legal") or
                   name:find("Notice") or name:find("Ban") or
                   name:find("Error") or name:find("Popup") or
                   name:find("Message") or name:find("Dialog") or
                   name:find("Warning") or name:find("Alert") or
                   name:find("Suspension") or name:find("Frozen") or
                   name:find("Penalty") or name:find("Sanction") or
                   name:find("Terminated") or name:find("Blocked") or
                   name:find("Flagged") or name:find("Marked") or
                   name:find("Inspection") or name:find("Risk") then
                    widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                    pcall(function() widget:RemoveFromParent() end)
                end
            end
        end

        pcall(function()
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if slua.isValid(pc) then
                local KSL = import("KismetSystemLibrary")
                if KSL then
                    KSL.ExecuteConsoleCommand(pc, "DisableAllScreenMessages")
                    KSL.ExecuteConsoleCommand(pc, "UI.DisableMessageOfTheDay")
                    KSL.ExecuteConsoleCommand(pc, "ShowMOTD 0")
                    KSL.ExecuteConsoleCommand(pc, "ShowBanNotice 0")
                    KSL.ExecuteConsoleCommand(pc, "ShowSuspension 0")
                    KSL.ExecuteConsoleCommand(pc, "ShowFrozenNotice 0")
                    KSL.ExecuteConsoleCommand(pc, "ShowRiskNotice 0")
                    KSL.ExecuteConsoleCommand(pc, "DisableBanUI 1")
                    KSL.ExecuteConsoleCommand(pc, "HideBanMessages 1")
                    KSL.ExecuteConsoleCommand(pc, "DisablePopup 1")
                    KSL.ExecuteConsoleCommand(pc, "SuppressDialogs 1")
                end
            end
        end)
    end)
end

-- ============================================================
-- 7. Report Protection Initializer
-- ============================================================

local function InitializeReportProtection()
    pcall(function()
        KillBanPopup()
        PlayerReportBypass()
        ReportSystemBypass()
        TLogBypass()
        GameplayCallbackReportBypass()
        KillReportSubsystems()
    end)
end

-- ============================================================
-- Auto Initialize
-- ============================================================

pcall(function()
    local ticker = _safe_require("common.time_ticker")
    if ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(0.5, InitializeReportProtection)
    else
        InitializeReportProtection()
    end
end)
-- ============================================================
-- END REPORT PROTECTION SYSTEM
-- ============================================================
-- ==============================================================================
-- ============================ START MOD LOGIC ==============================
-- ==============================================================================

-- ============================================================
-- collection_level
-- Created by @Ryan_m_m_m
-- BIZAPRO Collection Level System
-- ============================================================

local collection_level = {}
_G.collection_level = collection_level
_G.BIZAPRO_collection_level = collection_level

-- ============================================================
-- CONFIG
-- ============================================================
collection_level.CONFIG = {
    CREATOR = "@Ryan_m_m_m",
    BRAND = "BIZAPRO",
    VERSION = "1.0.0",

    FAKE_LEVEL = 100,
    FAKE_DAN = 100,
    FAKE_LEVEL_NAME = "BIZAPRO Collection Champion",
    FAKE_SCORE = 23000,

    DEFAULT_SEASON = 1,
    ENABLE_SEASON_SCORE = true,
    ENABLE_TOTAL_SCORE = true,
    ENABLE_ROAD_UI = true,
    ENABLE_HANDLER_HOOK = true,
    ENABLE_MODULE_HOOK = true,
    DEBUG = true,
}

-- ============================================================
-- STATE
-- ============================================================
collection_level._installed = false
collection_level._handlerHooked = false
collection_level._moduleHooked = false
collection_level._roadUIHooked = false
collection_level._patchedModules = {}

-- ============================================================
-- LOG
-- ============================================================
function collection_level.log(msg)
    if collection_level.CONFIG.DEBUG then
        print("[BIZAPRO collection_level] " .. tostring(msg))
    end
    pcall(function()
        local f = io.open("data/share1/loglua.txt", "a+")
        if f then
            f:write(os.date("[%Y-%m-%d %H:%M:%S] [collection_level] ") .. tostring(msg) .. "\n")
            f:close()
        end
    end)
end

-- ============================================================
-- GETTERS / SETTERS
-- ============================================================
function collection_level.SetLevel(n)
    collection_level.CONFIG.FAKE_LEVEL = tonumber(n) or collection_level.CONFIG.FAKE_LEVEL
    _G.FAKE_LEVEL = collection_level.CONFIG.FAKE_LEVEL
    collection_level.log("SetLevel = " .. tostring(collection_level.CONFIG.FAKE_LEVEL))
    return collection_level.CONFIG.FAKE_LEVEL
end

function collection_level.SetDan(n)
    collection_level.CONFIG.FAKE_DAN = tonumber(n) or collection_level.CONFIG.FAKE_DAN
    _G.FAKE_DAN = collection_level.CONFIG.FAKE_DAN
    collection_level.log("SetDan = " .. tostring(collection_level.CONFIG.FAKE_DAN))
    return collection_level.CONFIG.FAKE_DAN
end

function collection_level.SetLevelName(name)
    collection_level.CONFIG.FAKE_LEVEL_NAME = tostring(name) or collection_level.CONFIG.FAKE_LEVEL_NAME
    _G.FAKE_LEVEL_NAME = collection_level.CONFIG.FAKE_LEVEL_NAME
    collection_level.log("SetLevelName = " .. tostring(collection_level.CONFIG.FAKE_LEVEL_NAME))
    return collection_level.CONFIG.FAKE_LEVEL_NAME
end

function collection_level.SetScore(n)
    collection_level.CONFIG.FAKE_SCORE = tonumber(n) or collection_level.CONFIG.FAKE_SCORE
    _G.FAKE_SCORE = collection_level.CONFIG.FAKE_SCORE
    collection_level.log("SetScore = " .. tostring(collection_level.CONFIG.FAKE_SCORE))
    return collection_level.CONFIG.FAKE_SCORE
end

function collection_level.GetLevel()
    return collection_level.CONFIG.FAKE_LEVEL
end

function collection_level.GetDan()
    return collection_level.CONFIG.FAKE_DAN
end

function collection_level.GetLevelName()
    return collection_level.CONFIG.FAKE_LEVEL_NAME
end

function collection_level.GetScore()
    return collection_level.CONFIG.FAKE_SCORE
end

-- ============================================================
-- PATCH COLLECT MODULE
-- ============================================================
function collection_level.patch_collect_module(mod)
    if not mod then return false end
    if rawget(mod, "_bizapro_collection_level_patched") then
        return true
    end
    rawset(mod, "_bizapro_collection_level_patched", true)

    local C = collection_level.CONFIG

    if mod.GetLevelDataByScore then
        rawset(mod, "GetLevelDataByScore", function(self, score, isSeason)
            return C.FAKE_LEVEL, C.FAKE_LEVEL_NAME, C.FAKE_DAN
        end)
    end

    if mod.GetSeasonLevelByScore then
        rawset(mod, "GetSeasonLevelByScore", function(self, score, seasonId)
            return C.FAKE_LEVEL, true, C.FAKE_LEVEL_NAME
        end)
    end

    if mod.GetCollectScoreByCollectData then
        rawset(mod, "GetCollectScoreByCollectData", function(self, collect_data)
            return C.FAKE_SCORE, C.FAKE_SCORE
        end)
    end

    local collect_data = rawget(mod, "collect_data")
    if collect_data and type(collect_data) == "table" then
        rawset(collect_data, "total_score", C.FAKE_SCORE)
        if not rawget(collect_data, "season_score") then
            rawset(collect_data, "season_score", {})
        end
        local season = (rawget(mod, "GetSeasonId") and mod:GetSeasonId()) or C.DEFAULT_SEASON
        collect_data.season_score[season] = C.FAKE_SCORE
        rawset(collect_data, "cur_season_collect_score", C.FAKE_SCORE)
    end

    if rawget(mod, "OnGetMainData") or mod.OnGetMainData then
        local orig_on_get = rawget(mod, "OnGetMainData") or mod.OnGetMainData
        rawset(mod, "OnGetMainData", function(self, err_code, data, param)
            if data and type(data) == "table" then
                rawset(data, "total_score", C.FAKE_SCORE)
                if not rawget(data, "season_score") then
                    rawset(data, "season_score", {})
                end
                local season = (rawget(self, "GetSeasonId") and self:GetSeasonId()) or C.DEFAULT_SEASON
                if type(data.season_score) == "table" then
                    data.season_score[season] = C.FAKE_SCORE
                end
                rawset(data, "cur_season_collect_score", C.FAKE_SCORE)
            end
            orig_on_get(self, err_code, data, param)
        end)
    end

    collection_level._patchedModules[mod] = true
    collection_level.log("Patched collect module")
    return true
end

-- ============================================================
-- FIND COLLECT MODULE
-- ============================================================
function collection_level.get_collect_module()
    local ModuleManager = _G.ModuleManager
    if not ModuleManager then
        for _, mod in pairs(package.loaded or {}) do
            if type(mod) == "table" and mod.GetModule and mod.LobbyModuleConfig and mod.LobbyModuleConfig.collect_module then
                ModuleManager = mod
                break
            end
        end
    end

    if ModuleManager and ModuleManager.GetModule and ModuleManager.LobbyModuleConfig then
        local ok, cm = pcall(ModuleManager.GetModule, ModuleManager, ModuleManager.LobbyModuleConfig.collect_module)
        if ok and cm then return cm end
    end

    for _, mod in pairs(package.loaded or {}) do
        if type(mod) == "table" and mod.GetLevelDataByScore and mod.GetSeasonLevelByScore then
            return mod
        end
    end
    return nil
end

-- ============================================================
-- HOOK COLLECT HANDLER
-- ============================================================
function collection_level.hook_collect_handler()
    if collection_level._handlerHooked then return true end

    local handler = package.loaded["client.network.Protocol.CollectHandler"]
        or package.loaded["CollectHandler"]

    if not handler and not rawget(package.loaded, "client.network.Protocol.CollectHandler") then
        pcall(require, "client.network.Protocol.CollectHandler")
    end

    local C = collection_level.CONFIG

    for _, mod in pairs(package.loaded or {}) do
        if type(mod) == "table"
            and mod.on_get_collect_sys_main_data_rsp
            and not rawget(mod, "_bizapro_collection_handler_hooked")
        then
            rawset(mod, "_bizapro_collection_handler_hooked", true)
            local orig = mod.on_get_collect_sys_main_data_rsp

            mod.on_get_collect_sys_main_data_rsp = function(err_code, collect_data, param)
                if collect_data and type(collect_data) == "table" then
                    rawset(collect_data, "total_score", C.FAKE_SCORE)
                    rawset(collect_data, "cur_season_collect_score", C.FAKE_SCORE)
                    local ss = rawget(collect_data, "season_score")
                    if type(ss) == "table" then
                        for k in pairs(ss) do ss[k] = C.FAKE_SCORE end
                    else
                        rawset(collect_data, "season_score", {
                            [1] = C.FAKE_SCORE,
                            [2] = C.FAKE_SCORE,
                        })
                    end
                end
                return orig(err_code, collect_data, param)
            end

            collection_level._handlerHooked = true
            collection_level.log("CollectHandler hooked")
            return true
        end
    end
    return false
end

-- ============================================================
-- HOOK MODULE MANAGER
-- ============================================================
function collection_level.hook_module_manager()
    if collection_level._moduleHooked then return true end

    for _, mod in pairs(package.loaded or {}) do
        if type(mod) == "table"
            and mod.GetModule
            and mod.LobbyModuleConfig
            and mod.LobbyModuleConfig.collect_module
            and not rawget(mod, "_bizapro_collection_getmodule_hooked")
        then
            rawset(mod, "_bizapro_collection_getmodule_hooked", true)
            local orig_get = mod.GetModule
            local collect_key = mod.LobbyModuleConfig.collect_module

            mod.GetModule = function(self, name)
                local inst = orig_get(self, name)
                if inst and name == collect_key then
                    collection_level.patch_collect_module(inst)
                    collection_level.inject_collect_data()
                end
                return inst
            end

            collection_level._moduleHooked = true
            collection_level.log("ModuleManager hooked")
            return true
        end
    end
    return false
end

-- ============================================================
-- HOOK COLLECT ROAD UI
-- ============================================================
function collection_level.hook_collect_road_ui()
    if collection_level._roadUIHooked then return true end
    if not collection_level.CONFIG.ENABLE_ROAD_UI then return false end

    local C = collection_level.CONFIG

    for _, mod in pairs(package.loaded or {}) do
        if type(mod) == "table"
            and mod.ShowCollect
            and mod.ShowSeasonCollect
            and not rawget(mod, "_bizapro_collection_road_hooked")
        then
            rawset(mod, "_bizapro_collection_road_hooked", true)
            local orig_show = mod.ShowCollect

            if orig_show then
                rawset(mod, "ShowCollect", function(self)
                    local mm = _G.ModuleManager
                    if not mm then
                        for _, m in pairs(package.loaded or {}) do
                            if type(m) == "table" and m.GetModule and m.LobbyModuleConfig then
                                mm = m
                                break
                            end
                        end
                    end

                    if mm and mm.LobbyModuleConfig and mm.LobbyModuleConfig.collect_module then
                        local ok, cm = pcall(mm.GetModule, mm, mm.LobbyModuleConfig.collect_module)
                        if ok and cm and rawget(cm, "collect_data") then
                            local cd = rawget(cm, "collect_data")
                            if type(cd) == "table" then
                                rawset(cd, "total_score", C.FAKE_SCORE)
                                if not rawget(cd, "season_score") then
                                    rawset(cd, "season_score", {})
                                end
                                cd.season_score[(rawget(cm, "GetSeasonId") and cm:GetSeasonId()) or C.DEFAULT_SEASON] = C.FAKE_SCORE
                                rawset(cd, "cur_season_collect_score", C.FAKE_SCORE)
                            end
                        end
                    end
                    return orig_show(self)
                end)
            end

            collection_level._roadUIHooked = true
            collection_level.log("Collect Road UI hooked")
            return true
        end
    end
    return false
end

-- ============================================================
-- INJECT COLLECT DATA
-- ============================================================
function collection_level.inject_collect_data()
    local C = collection_level.CONFIG

    pcall(function()
        local cm = collection_level.get_collect_module()
        if cm then
            local collect_data = rawget(cm, "collect_data")
            if collect_data and type(collect_data) == "table" then
                rawset(collect_data, "total_score", C.FAKE_SCORE)
                if not rawget(collect_data, "season_score") then
                    rawset(collect_data, "season_score", {})
                end
                local season = (rawget(cm, "GetSeasonId") and cm:GetSeasonId()) or C.DEFAULT_SEASON
                if type(collect_data.season_score) == "table" then
                    collect_data.season_score[season] = C.FAKE_SCORE
                end
                rawset(collect_data, "cur_season_collect_score", C.FAKE_SCORE)
            end
        end
    end)

    pcall(function()
        if _G.DataMgr and _G.DataMgr.roleData then
            if not _G.DataMgr.roleData.brief_collect_data then
                _G.DataMgr.roleData.brief_collect_data = {}
            end
            _G.DataMgr.roleData.brief_collect_data.total_score = C.FAKE_SCORE
            _G.DataMgr.roleData.brief_collect_data.cur_season_collect_score = C.FAKE_SCORE
        end
    end)
end

-- ============================================================
-- INSTALL ALL HOOKS
-- ============================================================
function collection_level.Install()
    if collection_level._installed then
        collection_level.inject_collect_data()
        return true
    end

    local C = collection_level.CONFIG

    _G.FAKE_LEVEL = C.FAKE_LEVEL
    _G.FAKE_DAN = C.FAKE_DAN
    _G.FAKE_LEVEL_NAME = C.FAKE_LEVEL_NAME
    _G.FAKE_SCORE = C.FAKE_SCORE

    if C.ENABLE_HANDLER_HOOK then
        collection_level.hook_collect_handler()
    end
    if C.ENABLE_MODULE_HOOK then
        collection_level.hook_module_manager()
    end
    if C.ENABLE_ROAD_UI then
        collection_level.hook_collect_road_ui()
    end

    for _, mod in pairs(package.loaded or {}) do
        if type(mod) == "table"
            and mod.GetLevelDataByScore
            and mod.GetSeasonLevelByScore
            and not rawget(mod, "_bizapro_collection_level_patched")
        then
            collection_level.patch_collect_module(mod)
        end
    end

    local cm = collection_level.get_collect_module()
    if cm then
        collection_level.patch_collect_module(cm)
    end

    collection_level.inject_collect_data()
    collection_level._installed = true

    collection_level.log(string.format(
        "BIZAPRO collection_level installed | Level=%d | Dan=%d | Name=%s | Score=%d | By %s",
        C.FAKE_LEVEL, C.FAKE_DAN, tostring(C.FAKE_LEVEL_NAME), C.FAKE_SCORE, C.CREATOR
    ))
    return true
end

-- ============================================================
-- REFRESH
-- ============================================================
function collection_level.Refresh()
    collection_level.inject_collect_data()
    pcall(function()
        if EventSystem and EVENTTYPE_COLLECTION and EVENTID_COLLECTION_UPDATE then
            EventSystem:postEvent(EVENTTYPE_COLLECTION, EVENTID_COLLECTION_UPDATE)
        end
    end)
end

-- ============================================================
-- AUTO INSTALL
-- ============================================================
function collection_level.AutoInstall()
    if _G.Mytimer_ticker then
        _G.Mytimer_ticker.AddTimer(3, function()
            pcall(function() collection_level.Install() end)
        end)
        _G.Mytimer_ticker.AddTimerLoop(1, function()
            pcall(collection_level.inject_collect_data)
        end, -1, 5.0)
    else
        pcall(function() collection_level.Install() end)
    end
end

-- ============================================================
-- PUBLIC API
-- ============================================================
_G.BIZAPRO = _G.BIZAPRO or {}
_G.BIZAPRO.collection_level = collection_level
_G.collection_level = collection_level

collection_level.Install()
collection_level.AutoInstall()

print("[BIZAPRO] collection_level loaded | Created by @Ryan_m_m_m")

local function Notify(msg) local s = "[BIZAPRO VIP] " .. tostring(msg)
pcall(function() if _G.LexusNotify then _G.LexusNotify(s) end end)
pcall(function() local sh = import("ScriptHelperClient") if sh and
sh.AddOnScreenDebugMessage then sh.AddOnScreenDebugMessage(s, -1, 3.0, {R=1,
G=1, B=0, A=1}, {X=1.2, Y=1.2}) end end) print(s) end

local _slua = rawget(_G, "slua")
local function Valid(obj) if not obj then return false end if _slua and
_slua.isValid then local ok, v = pcall(_slua.isValid, obj) if not ok or not v
then return false end end return true end

-- ========================================== 
-- ⭐ FIXED: LEXUS CORE CONFIG (SKIN + FPS + ESP + iPAD)
-- ========================================== 
_G.LexusConfig = _G.LexusConfig or { 
    ModEmote = true,
    ModSkin = true,           
    SkinDeadBox = true,   
    SkinAttachment = true,
    KillMessage = true,
    KillCountUI = true,
    -- ESP CONFIG
    EspVip = false,
    EspLoai5 = false,
    EspRadar = false,
    WallXuyenTuong = false,
    IpadView = false,
    BlackSky = false
}

_G.LexusState = _G.LexusState or { 
    LoopToken = 0, 
    GraphicsUnlocked = false, 
    MenuStep = 0, 
    LastCmdTime = 0,
    TrackedMarks = {},
    EnemyMarks = {},
    NativeESPReady = false,
    CustomTextData = { IpadViewFOV = 120 },     
    PrevGraphicsState = {}
}

-- ESP colors (unused but kept)
local C_GREEN = {R=0, G=255, B=0, A=255}
local C_RED = {R=255, G=0, B=0, A=255}
local C_CYAN = {R=0, G=255, B=255, A=255}
local C_YELLOW = {R=255, G=255, B=0, A=255}
local C_WHITE = {R=255, G=255, B=255, A=255}
local C_BLUE_TEXT = {R=0, G=200, B=255, A=255}


-- ========================================== 
-- VIP SETTINGS SAVE AND LOAD SYSTEM (AUTOMATIC)
-- ========================================== 
local function GetConfigPaths(fileName)
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.tencent.igfit/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName,
        "ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        fileName
    }
    pcall(function()
        if os and os.getenv then
            local homeDir = os.getenv("HOME")
            if homeDir and homeDir ~= "" then
                table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName)
                table.insert(paths, 2, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName)
            end
        end
    end)
    return paths
end

local ConfigFileName = "Ryan.txt"
_G.LastConfigSaveStr = ""

_G.SaveModSettings = function()
    pcall(function()
        local data = "return {\nLexusConfig = {\n"
        for k, v in pairs(_G.LexusConfig or {}) do
            data = data .. "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
        end
        data = data .. "},\nCustomTextData = {\n"
        if _G.LexusState and _G.LexusState.CustomTextData then
            for k, v in pairs(_G.LexusState.CustomTextData) do
                data = data .. "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
            end
        end
        data = data .. "}\n}"
        if data == _G.LastConfigSaveStr then return end
        _G.LastConfigSaveStr = data
        local paths = GetConfigPaths(ConfigFileName)
        for _, path in ipairs(paths) do
            local file = io.open(path, "w")
            if file then file:write(data); file:close(); break end
        end
    end)
end

_G.LoadModSettings = function()
    pcall(function()
        local paths = GetConfigPaths(ConfigFileName)
        local content = nil
        for _, path in ipairs(paths) do
            local file = io.open(path, "r")
            if file then content = file:read("*a"); file:close(); break end
        end
        if content then
            local func = load(content)
            if func then
                local savedData = func()
                if savedData and type(savedData) == "table" then
                    if savedData.LexusConfig then
                        for k, v in pairs(savedData.LexusConfig) do _G.LexusConfig[k] = v end
                    end
                    if savedData.CustomTextData then
                        _G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {}
                        for k, v in pairs(savedData.CustomTextData) do _G.LexusState.CustomTextData[k] = v end
                    end
                end
            end
        end
        _G.SaveModSettings() 
    end)
end

local function AutoSaveLoop()
    pcall(function() if _G.SaveModSettings then _G.SaveModSettings() end end)
    pcall(function()
        local okTicker, ticker = pcall(require, "common.time_ticker") 
        if okTicker and ticker and ticker.AddTimerOnce then 
            ticker.AddTimerOnce(3.0, AutoSaveLoop)
        end
    end)
end

if not _G.ModConfigLoaded then
    _G.LoadModSettings()
    AutoSaveLoop()
    _G.ModConfigLoaded = true
end

_G.ReadLiveConfig = function() if _G.SaveModSettings then _G.SaveModSettings() end end

-- ========================================== 
-- ESP HELPERS
-- ========================================== 
local function SafeAddMark(id, pos, z, str, size, actor)
    local mark = nil
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        if InGameMarkTools and InGameMarkTools.ClientAddMapMark then
            mark = InGameMarkTools.ClientAddMapMark(id, pos, z, str, size, actor)
            if mark then _G.LexusState.TrackedMarks[mark] = true end
        end
    end)
    return mark
end

local function SafeRemoveMark(mark)
    if not mark then return end
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        if InGameMarkTools and InGameMarkTools.HideMapMark then InGameMarkTools.HideMapMark(mark) end
        if InGameMarkTools and InGameMarkTools.RemoveMapMark then InGameMarkTools.RemoveMapMark(mark) end
    end)
    _G.LexusState.TrackedMarks[mark] = nil
end

local function GetSafeEnemyKey(enemy)
    if Valid(enemy) then
        if enemy.PlayerKey then return tostring(enemy.PlayerKey) end
        if type(enemy.GetUniqueID) == "function" then return tostring(enemy:GetUniqueID()) end
    end
    return tostring(enemy)
end

local function CheckIsAI(pawn, markData)
    if markData.AK_IS_BOT ~= nil then return markData.AK_IS_BOT, true end
    local isAI = false
    local hasChecked = false
    pcall(function()
        if pawn.bIsAI == true or pawn.IsAI == true then isAI = true; hasChecked = true end
        if type(pawn.IsBot) == "function" and pawn:IsBot() then isAI = true; hasChecked = true end
        local pState = pawn.PlayerState or (type(pawn.GetPlayerState) == "function" and pawn:GetPlayerState())
        if Valid(pState) then
            hasChecked = true
            if pState.bIsABot == true or pState.bIsBot == true then isAI = true end
            if type(pState.IsBot) == "function" and pState:IsBot() then isAI = true end
        end
        if not isAI then
            local name = pawn.PlayerName or (type(pawn.GetPlayerName) == "function" and pawn:GetPlayerName()) or ""
            if name ~= "" and (name:find("Cobra") or name:find("Target") or name:find("bot_") or name:find("b_")) then
                isAI = true
                hasChecked = true
            end
        end
    end)
    if hasChecked then markData.AK_IS_BOT = isAI end
    return isAI, hasChecked
end

local function InitializeNativeESP() 
    if _G.LexusState.NativeESPReady then return end
    pcall(function() 
        local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools") 
        local currentMarkCfg = GamePlayTools.GetCurrentConfig("ScreenMarkConfig") 
        local function ApplyCfg(cfg)
            if not cfg then return end 
            if cfg[1006] then 
                cfg[1006].bBindBlocked = true; cfg[1006].bBindOutScreen = true; 
                cfg[1006].MaxWidgetNum = 99; cfg[1006].MaxShowDistance = 6000000; 
                cfg[1006].bScaleByDistance = false; cfg[1006].BindSocketName = "root"; 
                cfg[1006].bUseLuaWorldSocketName = true; cfg[1006].WorldPositionOffset = FVector(0, 0, -30) 
            end 
            if cfg[1003] then 
                cfg[1003].bBindBlocked = true; cfg[1003].bBindOutScreen = true; 
                cfg[1003].MaxWidgetNum = 99; cfg[1003].MaxShowDistance = 6000000; 
                cfg[1003].bScaleByDistance = false; cfg[1003].BindSocketName = "head"; 
                cfg[1003].bUseLuaWorldSocketName = true
            end 
            cfg[9999] = { 
                UIPathName = "/Game/Mod/EvoBase/BluePrints/UIBP/QuickSign/QuickSign_TipHitEnemy_UIBP_New.QuickSign_TipHitEnemy_UIBP_New_C",
                MaxWidgetNum = 99, MaxShowDistance = 6000000, 
                bBindOutScreen = true, bBindBlocked = true, 
                bIsBindingActor = true, BindSocketName = "head",
                bUseLuaWorldSocketName = true, WorldPositionOffset = FVector(0, 0, 50),
                bNeedPreLoad = true, Priority = 2 
            } 
        end 
        ApplyCfg(currentMarkCfg) 
        for k, cfg in pairs(package.loaded) do 
            if type(k) == "string" and string.find(k, "ScreenMarkConfig") and type(cfg) == "table" then ApplyCfg(cfg) end 
        end 
    end)
    _G.LexusState.NativeESPReady = true 
    Notify("Native ESP System Initialized") 
end

local function GetAllSkeletalMeshes(enemy, markData)
    local curTime = os.clock()
    if markData and markData.CachedMeshes and markData.CachedMeshTime and (curTime - markData.CachedMeshTime < 3.0) then
        local validMeshes = {}
        for _, cachedMesh in ipairs(markData.CachedMeshes) do
            if Valid(cachedMesh) then table.insert(validMeshes, cachedMesh) end
        end
        markData.CachedMeshes = validMeshes
        return validMeshes
    end
    local meshes = {}
    if Valid(enemy.Mesh) then table.insert(meshes, enemy.Mesh) end
    pcall(function()
        local SkeletalMeshClass = import("SkeletalMeshComponent")
        if SkeletalMeshClass and type(enemy.GetComponentsByClass) == "function" then
            local childs = enemy:GetComponentsByClass(SkeletalMeshClass)
            if childs then
                local count = type(childs.Num) == "function" and childs:Num() or #childs
                for i = 1, count do
                    local comp = type(childs.Get) == "function" and childs:Get(i-1) or childs[i]
                    if Valid(comp) and comp ~= enemy.Mesh then table.insert(meshes, comp) end
                end
            end
        end
    end)
    if markData then
        markData.CachedMeshes = meshes
        markData.CachedMeshTime = curTime
    end
    return meshes
end

local function UndoWallXuyenTuong(enemy, markData)
    pcall(function()
        if markData.WallhackApplied then
            local meshes = GetAllSkeletalMeshes(enemy, markData)
            for _, mesh in ipairs(meshes) do
                if Valid(mesh) then
                    pcall(function() if type(mesh.SetRenderCustomDepth) == "function" then mesh:SetRenderCustomDepth(false) end end)
                    for i = 0, 10 do 
                        local matInterface = mesh:GetMaterial(i)
                        if Valid(matInterface) then
                            local baseMat = matInterface:GetBaseMaterial()
                            if Valid(baseMat) then baseMat.bDisableDepthTest = false end
                        end
                    end
                end
            end
            markData.WallhackApplied = false
        end
    end)
end

local function ApplyWallXuyenTuong(enemy, markData)
    pcall(function()
        local meshes = GetAllSkeletalMeshes(enemy, markData)
        for _, mesh in ipairs(meshes) do
            if Valid(mesh) then 
                pcall(function()
                    if type(mesh.SetRenderCustomDepth) == "function" then mesh:SetRenderCustomDepth(true) end
                    if type(mesh.SetCustomDepthStencilValue) == "function" then mesh:SetCustomDepthStencilValue(252) end
                end)
                for i = 0, 10 do 
                    local matInterface = mesh:GetMaterial(i)
                    if not Valid(matInterface) then break end
                    local baseMat = matInterface:GetBaseMaterial()
                    if Valid(baseMat) then
                        baseMat.bDisableDepthTest = true
                        baseMat.BlendMode = 2 
                    end
                end
            end
        end
    end)
end

-- ==============================================================================
-- ESP MAIN LOOP
-- ==============================================================================
local function ESPSpamLoop()
    local okData, GD = pcall(require, "GameLua.GameCore.Data.GameplayData") 
    if not okData or not GD then return end 
    local pc = GD.GetPlayerController() 
    local localPlayer = nil
    if Valid(pc) then localPlayer = pc:GetPlayerCharacterSafety() end 

    if not Valid(localPlayer) then 
        if _G.LexusState.TrackedMarks then
            for markId, _ in pairs(_G.LexusState.TrackedMarks) do SafeRemoveMark(markId) end
        end
        _G.LexusState.TrackedMarks = {} 
        _G.LexusState.EnemyMarks = {}
        return 
    end

    InitializeNativeESP()
    
    -- iPAD VIEW
    if _G.LexusConfig.IpadView and _G.LexusState.CustomTextData then
        pcall(function()
            local targetTPP = _G.LexusState.CustomTextData.IpadViewFOV or 120
            local uTPPCam = localPlayer.ThirdPersonCameraComponent
            if Valid(uTPPCam) and not localPlayer.bIsWeaponAiming then
                if uTPPCam.FieldOfView ~= targetTPP then uTPPCam.FieldOfView = targetTPP end
            end
        end)
    else
        pcall(function()
            local uTPPCam = localPlayer.ThirdPersonCameraComponent
            if Valid(uTPPCam) and not localPlayer.bIsWeaponAiming then
                if uTPPCam.FieldOfView ~= 90 then uTPPCam.FieldOfView = 90 end
            end
        end)
    end

    -- ESP MAIN
    pcall(function()
        local allCharacters = {}
        if GD.GetAllPlayerCharacters then allCharacters = GD.GetAllPlayerCharacters()
        elseif GD.GameCharacters then for _, char in pairs(GD.GameCharacters) do table.insert(allCharacters, char) end end
        
        local currentValidKeys = {}
        for _, enemy in pairs(allCharacters) do
            if Valid(enemy) and enemy ~= localPlayer then currentValidKeys[GetSafeEnemyKey(enemy)] = true end
        end
        
        for key, data in pairs(_G.LexusState.EnemyMarks) do
            if not currentValidKeys[key] then
                SafeRemoveMark(data.radarMark); SafeRemoveMark(data.hpMark); SafeRemoveMark(data.distMark)
                data.enemy = nil; data.CachedMeshes = nil
                _G.LexusState.EnemyMarks[key] = nil
            end
        end

        for _, enemy in pairs(allCharacters) do
            if Valid(enemy) and enemy ~= localPlayer and enemy.TeamID ~= localPlayer.TeamID then
                local bIsReallyDead = false
                pcall(function()
                    if type(enemy.IsDead) == "function" then bIsReallyDead = enemy:IsDead()
                    elseif enemy.bIsDead ~= nil then bIsReallyDead = enemy.bIsDead
                    elseif enemy.bIsDeadFlag ~= nil then bIsReallyDead = enemy.bIsDeadFlag end
                    if enemy.HealthStatus ~= nil and enemy.HealthStatus == 2 then bIsReallyDead = true end
                end)

                local eKey = GetSafeEnemyKey(enemy)
                _G.LexusState.EnemyMarks[eKey] = _G.LexusState.EnemyMarks[eKey] or { enemy = enemy }
                local markData = _G.LexusState.EnemyMarks[eKey]
                markData.enemy = enemy 

                if not bIsReallyDead then
                    local eMesh = nil
                    pcall(function() eMesh = enemy.Mesh or (type(enemy.getAvatarComponent2) == "function" and enemy:getAvatarComponent2() or nil) end)
                    local aLoc = nil
                    pcall(function() if type(enemy.K2_GetActorLocation) == "function" then aLoc = enemy:K2_GetActorLocation() end end)
                    
                    local _, _ = CheckIsAI(enemy, markData)

                    local currentMeshCount = 0
                    if Valid(eMesh) then
                        local tempMeshes = GetAllSkeletalMeshes(enemy, markData)
                        currentMeshCount = #tempMeshes
                    end
                    local isMeshChanged = (markData.LastMeshCountWall ~= currentMeshCount)

                    if _G.LexusConfig.WallXuyenTuong then
                        if isMeshChanged or not markData.WallhackApplied then
                            ApplyWallXuyenTuong(enemy, markData)
                            markData.WallhackApplied = true
                            markData.LastMeshCountWall = currentMeshCount
                        end
                    else
                        UndoWallXuyenTuong(enemy, markData)
                    end

                    local hpRatio = 1.0
                    pcall(function()
                        local currentHp, maxHp = 100, 100
                        if enemy.Health then currentHp = enemy.Health elseif type(enemy.GetHealth) == "function" then currentHp = enemy:GetHealth() end
                        if enemy.HealthMax then maxHp = enemy.HealthMax elseif type(enemy.GetHealthMax) == "function" then maxHp = enemy:GetHealthMax() end
                        if maxHp <= 0 then maxHp = 100 end
                        hpRatio = currentHp / maxHp
                    end)

                    -- ESP BOX
                    if _G.LexusConfig.EspLoai5 then
                        pcall(function()
                            local SecurityCommonUtils = nil
                            pcall(function() SecurityCommonUtils = require("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils") end)
                            local show = true
                            if enemy.HealthStatus and SecurityCommonUtils and SecurityCommonUtils.IsHealthStatusAlive then 
                                if not SecurityCommonUtils.IsHealthStatusAlive(enemy.HealthStatus) then show = false end
                            end
                            if show and aLoc then
                                if aLoc.Z >= 150000 or FVector.Dist2D(localPlayer:K2_GetActorLocation(), aLoc) > 50000 then show = false end
                            end
                            if show then
                                if enemy.Replay_IsEnemyFrameUIExisted and not enemy:Replay_IsEnemyFrameUIExisted() then enemy:Replay_CreateEnemyFrameUI(true, true) end
                                if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(true) end
                                if enemy.Replay_UpdateEnemyFrameUI then enemy:Replay_UpdateEnemyFrameUI(hpRatio) end
                                local uiComp = enemy.EnemyFrameUI or (type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI())
                                if Valid(uiComp) and markData.LastFrameUIState ~= "VISIBLE" then
                                    if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(0) end
                                    if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(false) end
                                    markData.LastFrameUIState = "VISIBLE"
                                end
                            else
                                if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(false) end
                                local uiComp = enemy.EnemyFrameUI or (type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI())
                                if Valid(uiComp) and markData.LastFrameUIState ~= "HIDDEN" then
                                    if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(2) end
                                    if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(true) end
                                    markData.LastFrameUIState = "HIDDEN"
                                end
                            end
                        end)
                    else
                        pcall(function()
                            if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(false) end
                            local uiComp = enemy.EnemyFrameUI or (type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI())
                            if Valid(uiComp) and markData.LastFrameUIState ~= "HIDDEN" then
                                if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(2) end
                                if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(true) end
                                markData.LastFrameUIState = "HIDDEN"
                            end
                        end)
                    end

                    -- ESP SKELETON
                    if _G.LexusConfig.EspVip then
                        if markData.hpMark == nil then markData.hpMark = SafeAddMark(1006, FVector(0,0,0), 0, "", 4, enemy) end
                        if markData.distMark == nil then markData.distMark = SafeAddMark(9999, FVector(0,0,0), 0, "", 4, enemy) end
                    else
                        if markData.hpMark then SafeRemoveMark(markData.hpMark); markData.hpMark = nil end
                        if markData.distMark then SafeRemoveMark(markData.distMark); markData.distMark = nil end
                    end
                    
                    -- ESP RADAR
                    if _G.LexusConfig.EspRadar then
                        pcall(function()
                            local UGameplayStatics = import("GameplayStatics")
                            local CGameWorld = slua_GameFrontendHUD and slua_GameFrontendHUD:GetWorld()
                            local curTime = (UGameplayStatics and CGameWorld) and UGameplayStatics.GetTimeSeconds(CGameWorld) or os.clock()
                            markData.LastRadarUpdate = markData.LastRadarUpdate or 0
                            if curTime > markData.LastRadarUpdate + 0.5 then
                                local headLoc = nil
                                if type(enemy.GetHeadLocation) == "function" then headLoc = enemy:GetHeadLocation(false) end
                                if headLoc then
                                    local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
                                    if markData.radarMark and InGameMarkTools and InGameMarkTools.HideMapMark then InGameMarkTools.HideMapMark(markData.radarMark) end
                                    if InGameMarkTools and InGameMarkTools.ClientAddMapMark then
                                        markData.radarMark = InGameMarkTools.ClientAddMapMark(1003, headLoc, 0, "", 4, nil)
                                    end
                                    markData.LastRadarUpdate = curTime
                                end
                            end
                        end)
                    else
                        if markData.radarMark then SafeRemoveMark(markData.radarMark); markData.radarMark = nil end
                    end
                else
                    if not markData.IsCleanedUp then
                        SafeRemoveMark(markData.radarMark); markData.radarMark = nil
                        SafeRemoveMark(markData.hpMark); markData.hpMark = nil
                        SafeRemoveMark(markData.distMark); markData.distMark = nil
                        pcall(function()
                            if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(false) end
                            local uiComp = enemy.EnemyFrameUI or (type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI())
                            if Valid(uiComp) then
                                if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(2) end
                                if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(true) end
                            end
                        end)
                        markData.IsCleanedUp = true
                    end
                end
            end
        end
    end)
end

-- ==========================================
-- ⭐ FIXED: isExpired — FORCED FALSE FOR TESTING
-- After everything works, restore: isExpired = (currentTime > limitTime)
-- ==========================================
local limitTime = os.time({ year = 2027, month = 8, day = 30, hour = 23, min = 59, sec = 0 })
local currentTime = os.time(os.date("!*t"))

pcall(function()
    local tm = package.loaded["client.logic.common.TimeManager"]
    if not tm then local s, r = pcall(require, "client.logic.common.TimeManager"); if s and r then tm = r end end
    if tm and type(tm.GetServerTime) == "function" then
        local serverTime = tm.GetServerTime()
        if serverTime and serverTime > 1700000000 then currentTime = serverTime end
    end
end)

-- ⭐ FIXED: FORCE FALSE
isExpired = false
-- To re-enable expiry check, replace above line with:
-- isExpired = (currentTime > limitTime)

-- ==========================================
-- GRAPHICS UNLOCK (165 FPS + iPad FOV)
-- ==========================================
local function InitializeGraphicsUnlock() 
    if _G.LexusState.GraphicsUnlocked then return end
    pcall(function()
        local SettingCfg = require("client.logic.setting.setting_config")
        local GraphicSettingDB = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
        if SettingCfg then
            if SettingCfg.TpViewValue then SettingCfg.TpViewValue.max = 160 end
            if SettingCfg.FpViewValue then SettingCfg.FpViewValue.max = 160 end
        end
        if GraphicSettingDB then
            if GraphicSettingDB.TpViewValue then GraphicSettingDB.TpViewValue.max = 160 end
        end
    end)
    pcall(function()
        local logic_setting_graphics = require("client.slua.logic.setting.logic_setting_graphics")
        local GSC_FPS = require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPS")
        local GSC_FPSFT = require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPSFT")
        local GraphicSettingDB = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
        local KismetMathLibrary = import("KismetMathLibrary") or _G.KismetMathLibrary
        local FLinearColor = import("LinearColor") or _G.FLinearColor

        if logic_setting_graphics then
            local old_SetFPS = logic_setting_graphics.SetFPS
            function logic_setting_graphics.SetFPS(gameInstance, FPSLevel)
                if old_SetFPS then old_SetFPS(gameInstance, FPSLevel) end
                if FPSLevel == 8 then 
                    gameInstance:ExecuteCMD("t.MaxFPS", "165")
                    gameInstance:ExecuteCMD("r.FrameRateLimit", "165")
                end
            end
        end

        if GSC_FPS and GSC_FPS.__inner_impl then
            local fps_impl = GSC_FPS.__inner_impl
            function fps_impl:GetMaxFPSLevel() return 8, 8 end
            function fps_impl:InitRealSupportFPS()
                local RealSupportFPS = {}
                for i = 1, 8 do RealSupportFPS[i] = {true, true} end
                if GraphicSettingDB then GraphicSettingDB:UpdateUIData(GraphicSettingDB.RealSupportFPS, RealSupportFPS, false) end
                return RealSupportFPS
            end
        end

        if GSC_FPSFT and GSC_FPSFT.__inner_impl then
            local ft_impl = GSC_FPSFT.__inner_impl
            local NMinFPS, NStep = 90, 5
            local function clamp(value, min, max)
                if value < min then return min end
                if max < value then return value end
                return value
            end
            local function lerp(a, b, t) return a + (b - a) * t end
            local function _getColorByPercent(start, finish, percent)
                if not FLinearColor then return nil end
                return FLinearColor(lerp(start.R, finish.R, percent), lerp(start.G, finish.G, percent), lerp(start.B, finish.B, percent), lerp(start.A, finish.A, percent))
            end
            
            ft_impl.ShowOrHide = function(self) self:SelfHitTestInvisible(); if self.InitFPSFTSwitch then self:InitFPSFTSwitch() end end
            ft_impl.InitFPSFTSwitch = function(self)
                local on = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch)
                if self.UIRoot.Setting_Switch then self.UIRoot.Setting_Switch:SetSwitcherEnable2(on, true) end
                if self.UIRoot.CanvasPanel_8 then self:SetWidgetVisible(self.UIRoot.CanvasPanel_8, on) end
                if self.UIRoot.WidgetSwitcher_0 then self.UIRoot.WidgetSwitcher_0:SetActiveWidgetIndex(2) end
                if self.InitFPSFTValue165 then self:InitFPSFTValue165() end
            end
            ft_impl.InitFPSFTValue165 = function(self)
                local itemRoot = self.UIRoot
                local on = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch)
                local v = on and (GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneNum) or 165) or 165
                if itemRoot.Slider_screen3 then
                    itemRoot.Slider_screen3:SetLocked(not on)
                    local FPSFineTunePer = (v - NMinFPS) / (165 - NMinFPS)
                    itemRoot.Slider_screen3:SetValue(FPSFineTunePer)
                    if FLinearColor then itemRoot.Slider_screen3:SetSliderHandleColor(FLinearColor(1,1,1,1)) end
                    if itemRoot.ProgressBar_screen3 then
                        itemRoot.ProgressBar_screen3:SetPercent(FPSFineTunePer)
                        if FLinearColor then itemRoot.ProgressBar_screen3:SetFillColorAndOpacity(on and FLinearColor(1,1,1,1) or FLinearColor(1,0.625,0.6,1)) end
                    end
                end
                if itemRoot.Veihclescreen3 then itemRoot.Veihclescreen3:SetText(tostring(v)) end
            end
            ft_impl.OnFPSFTValueChange3 = function(self, v)
                v = clamp(v, NMinFPS, 165)
                GraphicSettingDB:UpdateUIData(GraphicSettingDB.FPSFineTuneNum, v)
                if self.InitFPSFTValue165 then self:InitFPSFTValue165() end
                if self:GetParentUI() then self:GetParentUI():SetDirty(true) end
                local gi = GraphicSettingDB.GetGameInstance and GraphicSettingDB.GetGameInstance()
                if gi then gi:ExecuteCMD("t.MaxFPS", tostring(v)); gi:ExecuteCMD("r.FrameRateLimit", tostring(v)) end
            end
            ft_impl.OnFPSFTSliderValueChange3 = function(self, nv)
                if not GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch) then return end
                self:OnFPSFTValueChange3(clamp(math.floor((NMinFPS + nv*(165-NMinFPS))/NStep+0.5)*NStep, NMinFPS, 165))
            end
            ft_impl.OnFPSFTAdd3 = function(self)
                local c = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneNum) or 90
                self:OnFPSFTValueChange3(math.min(165, c + NStep))
            end
            ft_impl.OnFPSFTMinus3 = function(self)
                local c = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneNum) or 90
                self:OnFPSFTValueChange3(math.max(NMinFPS, c - NStep))
            end
            ft_impl.OnFPSFTAdd = ft_impl.OnFPSFTAdd3
            ft_impl.OnFPSFTMinus = ft_impl.OnFPSFTMinus3
            ft_impl.OnFPSFTSliderValueChange = ft_impl.OnFPSFTSliderValueChange3
        end
    end)
    _G.LexusState.GraphicsUnlocked = true
    Notify("Graphics & FPS 165Hz Unlocked")
end

-- ==========================================
-- MAIN LOOP (SKIN + SKY + HIGGS)
-- ==========================================
local function MainLoop()
    if isExpired then return end
    if _G.LexusState.CustomTextData == nil then _G.LexusState.CustomTextData = {} end

    local okData, GD = pcall(require, "GameLua.GameCore.Data.GameplayData") 
    if not okData or not GD then return end 
    local pc = GD.GetPlayerController() 
    local localPlayer = nil
    if Valid(pc) then localPlayer = pc:GetPlayerCharacterSafety() end 
    if not Valid(localPlayer) then return end

    -- SKIN MOD
    if _G.LexusConfig.ModSkin then
        local curTime = os.clock()
        if not _G.LastSkinUpdateTime or (curTime - _G.LastSkinUpdateTime) > 2.5 then
            _G.LastSkinUpdateTime = curTime
            pcall(function()
                local isAlive = type(localPlayer.IsAlive) == "function" and localPlayer:IsAlive() or true
                if isAlive then
                    if _G.LexusConfig.SkinDeadBox and _G.DeadBox_TemperRequest and _G.NeedCheckDeadBoxTimer > 0 then
                        _G.DeadBox_TemperRequest(pc)
                    end
                    if _G.AddOutfit then
                        if _G.AddOutfit.isInRealMatch() then
                            _G.AddOutfitLobbyRestored = false 
                            local ticker = require("common.time_ticker")
                            if ticker and ticker.AddTimerOnce then
                                _G.AddOutfit.matchApplyAllSlots(localPlayer)
                                ticker.AddTimerOnce(0.2, function()
                                    if slua.isValid(localPlayer) and _G.AddOutfit.isInRealMatch() then _G.AddOutfit.matchApplyHat(localPlayer) end
                                end)
                                ticker.AddTimerOnce(0.4, function()
                                    if slua.isValid(localPlayer) and _G.AddOutfit.isInRealMatch() then _G.AddOutfit.matchApplyWeaponSkin(localPlayer) end
                                end)
                                ticker.AddTimerOnce(0.6, function()
                                    if slua.isValid(localPlayer) and _G.AddOutfit.isInRealMatch() and _G.AddOutfit.isCharacterAirborne(localPlayer) then
                                        _G.AddOutfit.applyAirborneSlots(localPlayer, true)
                                    end
                                end)
                            else
                                _G.AddOutfit.matchApplyAllSlots(localPlayer)
                                _G.AddOutfit.matchApplyHat(localPlayer)
                                _G.AddOutfit.matchApplyWeaponSkin(localPlayer)
                                if _G.AddOutfit.isCharacterAirborne(localPlayer) then
                                    _G.AddOutfit.applyAirborneSlots(localPlayer, true)
                                end
                            end
                        else
                            _G.AddOutfit.reapplyLobbyEquipped()
                        end
                    end
                end
            end)
        end
    end

    -- BLOCK HIGGSBOSON
    pcall(function()
        if Valid(pc) then
            if pc.HiggsBoson then pc.HiggsBoson.bMHActive = false; pc.HiggsBoson.bCallPreReplication = false end
            if pc.HiggsBosonComponent then pc.HiggsBosonComponent.bMHActive = false; pc.HiggsBosonComponent.bCallPreReplication = false end
        end
    end)

    -- BLACKSKY
    pcall(function()
        local lsg = require("client.slua.logic.setting.logic_setting_graphics")
        local gi = lsg.GetGameInstance()
        if gi then
            if _G.LexusConfig.BlackSky and not _G.LexusState.PrevGraphicsState.BlackSky then
                gi:ExecuteCMD("r.CylinderMaxDrawHeight", "9999")
                _G.LexusState.PrevGraphicsState.BlackSky = true
            elseif not _G.LexusConfig.BlackSky and _G.LexusState.PrevGraphicsState.BlackSky then
                gi:ExecuteCMD("r.CylinderMaxDrawHeight", "0000")
                _G.LexusState.PrevGraphicsState.BlackSky = false
            end
        end
    end)
end

_G.LexusState.LoopToken = (_G.LexusState.LoopToken or 0) + 1 
local myToken = _G.LexusState.LoopToken

local function ExpiredTick()
    if not _G.LexusNotifiedPopup then
        pcall(function()
            local Msg = require("client.slua.logic.common.logic_common_msg_box")
            if Msg and Msg.Show then
                Msg.Show(1, "MOD EXPIRED", "YOUR MOD VERSION HAS EXPIRED!\nPLEASE CONTACT ADMIN TO RENEW.\nInbox TELEGRAM - @Ryan_m_m_m", 
                function() 
                    local Web = require("client.slua.logic.url.logic_webview_sdk")
                    if Web and Web.OpenURL then Web:OpenURL("https://t.me/Ryan_m_m_m") end 
                end, function() end, "CONTACT OWNER", "CLOSE")
                _G.LexusNotifiedPopup = true 
            end
        end)
        if not _G.LexusNotifiedPopup then
            local okTicker, ticker = pcall(require, "common.time_ticker") 
            if okTicker and ticker and ticker.AddTimerOnce then ticker.AddTimerOnce(2.0, ExpiredTick) end
        end
    end
end

local function FastTick() 
    if isExpired then 
        if not _G.LexusNotifiedExpire then
            Notify("MOD HAS EXPIRED! PLEASE CONTACT ADMIN TO RENEW!\nInbox TELEGRAM - @Ryan_m_m_m")
            _G.LexusNotifiedExpire = true
            ExpiredTick() 
        end
        return 
    end
    if myToken ~= _G.LexusState.LoopToken then return end
    pcall(MainLoop) 
    local okTicker, ticker = pcall(require, "common.time_ticker") 
    if okTicker and ticker and ticker.AddTimerOnce then ticker.AddTimerOnce(0.2, FastTick) end 
end

-- ESP TICK
local function ESPTick()
    if isExpired then return end
    if myToken ~= _G.LexusState.LoopToken then return end
    pcall(ESPSpamLoop)
    local okTicker, ticker = pcall(require, "common.time_ticker") 
    if okTicker and ticker and ticker.AddTimerOnce then ticker.AddTimerOnce(0.01, ESPTick) end 
end

if not isExpired then
    FastTick() 
    ESPTick()
    Notify("MOD BY BIZAPRO OFFICIAL TELEGRAM - @Ryan_m_m_m")
end


-- ==============================================================================
-- ================= START CORE ADD-OUTFIT V7.5 (SKIN SYSTEM) =================
-- ==============================================================================
-- Base attachment ID to index mapping
_G.BaseAttachToIndex = {
    [201010]=1, [201005]=1, [201004]=1, [201009]=2, [201003]=2, [201002]=2, 
    [201011]=3, [201007]=3, [201006]=3, [204012]=4, [204005]=4, [204008]=4, 
    [204011]=5, [204004]=5, [204007]=5, [204013]=6, [204006]=6, [204009]=6, 
    [203001]=7, [203002]=8, [203003]=9, [203014]=10, [203004]=11, [203015]=12, [203005]=13, 
    [202002]=14, [202001]=15, [202004]=16, [202005]=17, [202007]=18, [202006]=19, 
    [205002]=20, [205003]=20, [205001]=20, [203018]=21, [204014]=22 
}

-- PASTE YOUR ATTACHMENT IDS INSIDE THE BRACKETS BELOW ↓↓↓
_G.VIP_Attachments = {
    
    [1101004236]={1010042307,1010042306,1010042308,1010042304,1010042300,1010042305,1010042299,1010042298,1010042297,1010042296,1010042295,1010042294,0,1010042314,1010042309,1010042316,1010042317,1010042318,1010042310,1010042315,1010042319,0},
    [1101001116]={1010011106,1010011107,1010011108,0,1010011109,1010011112,1010011105,1010011104,1010011103,0,1010011102,0,0,0,0,0,0,0,0,0,0,0},
    [1101001128]={1010011232,1010011233,1010011234,1010011228,1010011227,1010011229,1010011226,1010011225,1010011224,1010011223,1010011222,0,0,0,0,0,0,0,0,0,0,0},
    [1101001154]={1010011487,1010011488,1010011489,1010011493,1010011490,1010011494,1010011486,1010011485,1010011484,1010011483,1010011482,1010011497,0,0,0,0,0,0,0,0,1010011498,0},
    [1101001174]={1010011667,1010011668,1010011669,1010011673,1010011670,1010011674,1010011666,1010011665,1010011664,1010011663,1010011662,0,0,0,0,0,0,0,0,0,0,0},
    [1101001213]={1010012067,1010012068,1010012069,1010012072,1010012070,1010012073,1010012066,1010012065,1010012064,1010012063,1010012062,0,0,0,0,0,0,0,0,1010012074,0},
    [1101001231]={1010012267,1010012268,1010012269,1010012273,1010012272,1010012274,1010012266,1010012265,1010012264,1010012263,1010012262,1010012075,0,0,0,0,0,0,0,0,1010012275,0},
    [1101001242]={1010012357,1010012358,1010012359,1010012363,1010012362,1010012364,1010012356,1010012355,1010012354,1010012353,1010012352,1010012276,0,0,0,0,0,0,0,0,1010012365,0},
    [1101001249]={1010012437,1010012438,1010012439,1010012443,1010012442,1010012444,1010012436,1010012435,1010012434,1010012433,1010012432,1010012366,0,0,0,0,0,0,0,0,1010012445,0},
    [1101001256]={1010012588,1010012589,1010012590,1010012593,1010012592,1010012594,1010012587,1010012586,1010012585,1010012584,1010012583,1010012582,0,0,0,0,0,0,0,0,1010012595,0},
    [1101001265]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
    [1101001276]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
    [1101002029]={1010020249,1010020250,1010020255,1010020247,1010020246,1010020248,1010020240,1010020239,1010020238,1010020237,1010020236,1010020235,0,0,0,0,0,0,0,1010020257,1010020256,1010020258},
    [1101002056]={1010020519,0,0,1010020517,1010020516,1010020518,1010020500,1010020509,1010020508,1010020507,1010020506,1010020505,0,0,0,0,0,0,0,0,0,0},
    [1101002081]={1010020768,1010020769,1010020770,1010020766,1010020760,1010020767,1010020759,1010020758,1010020757,1010020756,1010020755,1010020776,0,0,0,0,0,0,0,1010020775,1010020777,1010020778},
    [1101003070]={1010030654,1010030653,1010030655,1010030649,1010030648,1010030650,1010030647,1010030646,1010030645,1010030644,1010030643,1010030642,0,1010030658,1010030656,1010030660,1010030662,1010030659,1010030657,0,1010030663,0},
    [1101003080]={1010030754,1010030753,1010030755,1010030749,1010030748,1010030750,1010030747,1010030746,1010030745,1010030744,1010030743,1010030742,0,1010030758,1010030756,1010030760,1010030762,1010030759,1010030757,0,1010030763,0},
    [1101003099]={1010030943,1010030944,1010030945,1010030939,1010030938,1010030942,1010030937,1010030936,1010030935,1010030934,1010030933,1010030932,0,1010030947,1010030946,1010030948,1010030949,1010030953,1010030952,0,1010030955,0},
    [1101003119]={1010031139,1010031140,1010031142,1010031138,1010031137,1010031146,1010031136,1010031135,1010031134,1010031133,1010031132,0,0,1010031144,1010031143,0,0,0,1010031145,0,0,0},
    [1101003146]={1010031229,1010031230,1010031237,1010031228,1010031227,1010031242,1010031226,1010031225,1010031224,1010031223,1010031222,0,0,1010031239,1010031238,0,0,0,1010031240,0,0,0},
    [1101003167]={1010031609,1010031610,1010031613,1010031608,1010031607,1010031617,1010031606,1010031605,1010031604,1010031603,1010031602,1010031618,0,1010031615,1010031614,1010031620,1010031622,1010031619,1010031616,0,1010031623,0},
    [1101003181]={1010031765,1010031764,1010031766,1010031759,1010031758,1010031763,1010031757,1010031756,1010031755,1010031754,1010031753,1010031752,0,1010031769,1010031767,1010031773,1010031774,1010031772,1010031768,0,1010031775,0},
    [1101003195]={1010031912,1010031911,1010031913,1010031908,1010031907,1010031909,1010031906,1010031905,1010031904,1010031903,1010031902,1010031901,0,1010031916,1010031914,1010031918,1010031919,1010031917,1010031915,0,1010031921,0},
    [1101003208]={1010032034,1010032033,1010032045,1010032029,1010032028,1010032032,1010032027,1010032026,1010032025,1010032024,1010032023,1010032022,0,1010032038,1010032036,1010032042,1010032043,1010032039,1010032037,0,1010032044,0},
    [1101004046]={1010040474,1010040475,1010040476,1010040472,1010040471,1010040473,1010040470,1010040469,1010040468,1010040467,1010040466,1010040481,0,1010040479,1010040477,1010040482,1010040483,1010040484,1010040478,1010040480,1010040485,0},
    [1101004062]={1010040578,1010040577,1010040579,1010040575,1010040570,1010040576,1010040569,1010040568,1010040567,1010040566,1010040565,1010040564,0,1010040585,1010040580,1010040587,1010040588,1010040589,1010040584,1010040586,1010040590,1010040594},
    [1101004098]={1010040924,1010040926,1010040925,0,1010040937,1010040938,1010040935,1010040934,1010040929,1010040928,1010040927,0,0,1010040939,1010040945,0,0,0,1010040944,1010040936,0,0},
    [1101004138]={1010041136,1010041137,1010041138,1010041134,1010041129,1010041135,1010041128,1010041127,1010041126,1010041125,1010041124,0,0,1010041145,1010041139,0,0,0,1010041144,1010041146,0,0},
    [1101004163]={1010041570,1010041574,1010041575,1010041568,1010041567,1010041569,1010041566,1010041565,1010041564,1010041560,1010041554,0,0,1010041578,1010041576,0,0,0,1010041577,1010041579,0,0},
    [1101004201]={1010041956,1010041957,1010041958,1010041950,1010041949,1010041955,1010041948,1010041947,1010041946,1010041945,1010041944,1010041967,0,1010041965,1010041959,0,0,0,1010041960,1010041966,0,0},
    [1101004209]={1010042038,1010042037,1010042039,1010042035,1010042034,1010042036,1010042029,1010042028,1010042027,1010042026,1010042025,1010042024,0,1010042046,1010042044,1010042048,1010042049,1010042054,1010042045,1010042047,1010042055,0},
    [1101004218]={1010042128,1010042127,1010042129,1010042125,1010042124,1010042126,1010042119,1010042118,1010042117,1010042116,1010042115,1010042114,0,1010042136,1010042134,1010042138,1010042139,1010042144,1010042135,1010042137,1010042145,0},
    [1101004226]={1010042238,1010042237,1010042239,1010042235,1010042234,1010042236,1010042233,1010042232,1010042231,1010042219,1010042218,1010042217,0,1010042243,1010042241,1010042245,1010042246,1010042247,1010042242,1010042244,1010042248,0},
    [1101004246]={1010042406,1010042407,1010042408,1010042404,1010042400,1010042405,1010042399,1010042398,1010042397,1010042396,1010042395,1010042394,0,1010042414,1010042409,1010042416,1010042417,1010042418,1010042410,1010042415,1010042419,1010042420},
    [1101005038]={0,0,1010050327,1010050329,1010050328,1010050330,1010050326,1010050325,1010050324,1010050323,1010050322,1010050334,0,0,0,0,0,0,0,0,0,0},
    [1101005052]={0,0,1010050467,1010050469,1010050468,1010050470,1010050466,1010050465,1010050464,1010050463,1010050462,1010050473,0,0,0,0,0,0,0,0,0,0},
    [1101005098]={0,0,1010050928,1010050930,1010050929,1010050932,1010050927,1010050926,1010050925,1010050924,1010050923,1010050922,0,0,0,0,0,0,0,0,0,0},
    [1101006062]={1010060573,1010060572,1010060574,1010060564,1010060563,1010060571,1010060562,1010060561,1010060554,1010060553,1010060552,1010060551,0,1010060583,1010060581,1010060591,1010060592,1010060584,1010060582,0,1010060593,0},
    [1101006075]={1010060702,1010060701,1010060703,1010060698,1010060697,1010060699,1010060696,1010060695,1010060694,1010060693,1010060692,1010060691,0,1010060706,1010060704,1010060708,1010060709,1010060707,1010060705,0,1010060711,0},
    [1101006085]={1010060796,1010060795,1010060797,1010060793,1010060789,1010060794,1010060788,1010060787,1010060786,1010060785,1010060784,1010060783,0,1010060800,1010060798,1010060804,1010060805,1010060803,1010060799,0,1010060806,0},
    [1101007046]={1010070410,1010070413,1010070414,1010070408,1010070407,1010070409,1010070406,1010070405,1010070404,1010070403,1010070402,1010070418,0,1010070417,1010070415,1010070420,1010070422,1010070419,1010070416,0,1010070423,0},
    [1101007062]={1010070579,1010070578,1010070581,1010070576,1010070575,1010070577,1010070574,1010070573,1010070572,1010070571,1010070569,1010070568,0,1010070584,1010070582,1010070585,1010070586,1010070587,1010070583,0,1010070588,0},
    [1101007071]={1010070663,1010070662,1010070664,1010070659,1010070658,1010070660,1010070657,1010070656,1010070655,1010070654,1010070653,1010070652,0,1010070667,1010070665,1010070668,1010070669,1010070670,1010070666,0,1010070672,0},
    [1101008051]={1010080463,1010080464,1010080465,1010080459,1010080458,1010080462,1010080457,1010080456,1010080455,1010080454,1010080453,1010080452,0,1010080467,1010080466,1010080468,1010080469,1010080473,1010080472,0,1010080475,0},
    [1101008061]={1010080563,1010080564,1010080565,1010080559,1010080558,1010080562,1010080557,1010080556,1010080555,1010080554,1010080553,0,0,1010080567,1010080566,0,0,0,1010080572,0,0,0},
    [1101008070]={1010080609,1010080612,1010080613,1010080608,1010080607,1010080617,1010080606,1010080605,1010080604,1010080603,1010080602,0,0,1010080615,1010080614,0,0,0,1010080616,0,0,0},
    [1101008081]={1010080740,1010080743,1010080745,1010080738,1010080737,1010080739,1010080736,1010080735,1010080734,1010080733,1010080732,1010080748,0,1010080747,1010080746,1010080750,1010080752,1010080749,1010080744,0,1010080753,0},
    [1101008104]={1010080980,1010080982,1010080984,1010080978,1010080977,1010080979,1010080976,1010080975,1010080974,1010080973,1010080972,1010080992,0,1010080986,1010080985,1010080989,1010080987,1010080993,1010080983,0,1010080988,0},
    [1101008116]={1010081110,1010081112,1010081114,1010081108,1010081107,1010081109,1010081106,1010081105,1010081104,1010081103,1010081102,0,0,1010081116,1010081115,0,0,0,1010081113,0,0,0},
    [1101008126]={1010081210,1010081225,1010081226,1010081208,1010081207,1010081209,1010081206,1010081205,1010081204,1010081203,1010081202,1010081218,0,1010081217,1010081216,1010081219,1010081220,1010081222,1010081214,1010081228,1010081227,1010081229},
    [1101008136]={1010081314,1010081315,1010081316,1010081312,1010081308,1010081313,1010081307,1010081306,1010081305,1010081304,1010081303,1010081302,0,1010081318,1010081317,1010081322,1010081323,1010081325,1010081324,0,1010081326,0},
    [1101008146]={1010081401,1010081402,1010081403,1010081398,1010081397,1010081399,1010081396,1010081395,1010081394,1010081393,1010081392,1010081391,0,1010081405,1010081404,1010081406,1010081407,1010081409,1010081408,0,1010081411,0},
    [1101008154]={1010081531,1010081532,1010081533,1010081528,1010081527,1010081529,1010081526,1010081525,1010081524,1010081523,1010081522,1010081521,0,1010081541,1010081534,1010081542,1010081543,1010081545,1010081544,0,1010081546,0},
    [1101008163]={1010081582,1010081583,1010081584,1010081579,1010081578,1010081580,1010081577,1010081576,1010081575,1010081574,1010081573,1010081572,0,1010081586,1010081585,1010081587,1010081588,1010081590,1010081589,0,1010081592,0},
    [1101012033]={1010120284,1010120285,1010120286,1010120280,1010120279,1010120283,1010120278,1010120277,1010120276,1010120275,1010120274,1010120273,0,0,0,0,0,0,0,0,1010120287,0},
    [1101100012]={1011000066,1011000067,1011000068,0,0,0,1011000058,1011000057,1011000056,1011000055,1011000054,1011000053,0,0,0,0,0,0,0,0,1011000073,0},
    [1101102007]={1011010025,1011010024,1011010026,1011010020,1011010019,1011010023,1011010018,1011010017,1011010016,1011010015,1011010014,1011010013,0,0,0,0,0,0,0,0,1011010027,0},
    [1101102017]={1011020027,1011020028,1011020029,1011020025,1011020024,1011020026,1011020019,1011020018,1011020017,1011020016,1011020015,1011020014,0,1011020036,1011020034,1011020038,1011020039,1011020044,1011020035,1011020037,1011020045,1011020047},
    [1101102025]={1011020127,1011020128,1011020129,1011020125,1011020124,1011020126,1011020119,1011020118,1011020117,1011020116,1011020115,1011020114,0,1011020136,1011020134,1011020138,1011020139,1011020144,1011020135,1011020137,1011020145,0},
    [1101102041]={1011020214,1011020215,1011020216,1011020212,1011020211,1011020213,1011020209,1011020208,1011020207,1011020206,1011020205,1011020204,0,1011020219,1011020217,1011020222,1011020223,1011020224,1011020218,1011020221,1011020225,1011020229},
    [1101102049]={1011020356,1011020357,1011020358,1011020354,1011020350,1011020355,1011020349,1011020348,1011020347,1011020346,1011020345,1011020344,0,1011020364,1011020359,1011020366,1011020367,1011020368,1011020360,1011020365,1011020369,1011020370},
    [1101101007]={1011020436,1011020437,1011020438,1011020434,1011020430,1011020435,1011020429,1011020428,1011020427,1011020426,1011020425,1011020424,0,1011020444,1011020439,1011020446,1011020447,1011020448,1011020440,1011020445,1011020449,1011020450},
    [1102001120]={1020011137,1020011138,1020011139,1020011135,1020011134,1020011136,1020011133,1020011132,0,0,0,0,0,0,0,0,0,0,0,1020011142,0,0},
    [1102001130]={1020011247,1020011248,1020011249,1020011245,1020011244,1020011246,1020011243,1020011242,0,0,0,0,0,0,0,0,0,0,0,1020011250,0,0},
    [1102002043]={1020020372,1020020374,1020020373,1020020383,1020020380,1020020384,1020020379,1020020378,1020020377,1020020376,1020020375,1020020388,0,1020020385,1020020387,0,0,0,1020020386,0,0,0},
    [1102002061]={1020020552,1020020554,1020020553,1020020563,1020020562,1020020564,1020020559,1020020558,1020020557,1020020556,1020020555,1020020578,0,1020020565,1020020567,1020020573,1020020574,1020020572,1020020566,0,1020020569,0},
    [1102002136]={1020021314,1020021313,1020021315,1020021309,1020021308,1020021312,1020021307,1020021306,1020021305,1020021304,1020021303,1020021302,0,1020021318,1020021316,1020021323,1020021324,1020021322,1020021317,0,1020021325,0},
    [1102002424]={1020024193,1020024192,1020024194,1020024189,1020024188,1020024190,1020024187,1020024186,1020024185,1020024184,1020024183,1020024182,0,1020024197,1020024195,1020024199,1020024200,1020024198,1020024196,0,1020024202,0},
    [1102003080]={1020030755,1020030756,1020030758,0,1020030749,1020030754,1020030748,1020030747,1020030746,1020030745,1020030744,1020030764,0,1020030760,0,1020030759,1020030757,0,0,1020030765,0,0},
    [1102003100]={1020030956,1020030957,1020030958,1020030954,1020030950,1020030955,1020030949,1020030948,1020030947,1020030946,1020030945,1020030944,0,1020030964,0,1020030960,1020030959,1020030965,0,1020030967,1020030966,1020030968},
    [1102005064]={1020050588,1020050589,1020050590,0,0,0,1020050587,1020050586,1020050585,1020050584,1020050583,1020050582,0,0,0,0,0,0,0,0,1020050592,0},
    [1103001101]={1030010954,1030010955,1030010956,0,0,0,0,0,0,0,1030010953,1030010952,1030010951,0,0,0,0,0,0,1030010957,0,1030010958},
    [1103001146]={1030011344,1030011345,1030011346,0,0,0,0,0,0,0,1030011343,1030011342,1030011341,0,0,0,0,0,0,1030011347,0,1030011348},
    [1103001154]={1030011484,1030011485,1030011486,0,0,0,0,0,0,0,1030011483,1030011482,1030011481,0,0,0,0,0,0,1030011487,0,1030011488},
    [1103001179]={1030011738,1030011739,1030011741,0,0,0,1030011737,1030011736,1030011735,1030011734,1030011733,1030011732,1030011731,0,0,0,0,0,0,1030011742,1030011743,1030011744},
    [1103001191]={1030011858,1030011859,1030011861,0,0,0,1030011857,1030011856,1030011855,1030011854,1030011853,1030011852,1030011851,0,0,0,0,0,0,1030011862,1030011863,1030011864},
    [1103001202]={1030011948,1030011949,1030011950,0,0,0,1030011947,1030011946,1030011945,1030011944,1030011943,1030011942,1030011941,0,0,0,0,0,0,1030011951,1030011952,1030011953},
    [1103002030]={1030020245,1030020246,1030020247,1030020252,1030020249,1030020253,1030020258,1030020257,1030020256,1030020255,1030020244,1030020243,1030020242,0,0,0,0,0,0,1030020248,0,0},
    [1103002059]={1030020544,1030020545,1030020546,1030020542,1030020539,1030020543,1030020538,1030020537,1030020536,1030020535,1030020534,1030020533,1030020532,0,0,0,0,0,0,1030020547,1030020548,0},
    [1103002087]={1030020824,1030020825,1030020826,0,0,0,1030020818,1030020817,1030020816,1030020815,1030020814,1030020813,1030020812,0,0,0,0,0,0,1030020827,1030020828,0},
    [1103002106]={1030021009,1030021010,1030021012,1030021015,1030021014,1030021016,1030021008,1030021007,1030021006,1030021005,1030021004,1030021003,1030021002,0,0,0,0,0,0,1030021013,1030021017,0},
    [1103002113]={1030021079,1030021080,1030021082,1030021085,1030021084,1030021086,1030021078,1030021077,1030021076,1030021075,1030021074,1030021073,1030021072,0,0,0,0,0,0,1030021083,1030021087,0},
    [1103003022]={1030030165,1030030166,1030030167,1030030172,1030030169,1030030173,0,0,0,0,1030030164,1030030163,1030030162,0,0,0,0,0,0,0,0,0},
    [1103003030]={1030030256,1030030257,1030030258,1030030254,1030030253,1030030255,1030030248,1030030247,1030030246,1030030245,1030030244,1030030243,1030030242,0,0,0,0,0,0,1030030259,1030030249,0},
    [1103003042]={1030030374,1030030375,1030030376,1030030372,1030030369,1030030373,0,0,0,0,1030030364,1030030363,1030030362,0,0,0,0,0,0,1030030377,0,0},
    [1103003051]={1030030458,1030030459,1030030460,1030030456,1030030455,1030030457,0,0,0,0,1030030454,1030030453,1030030452,0,0,0,0,0,0,1030030463,0,0},
    [1103003062]={1030030568,1030030569,1030030570,1030030566,1030030565,1030030567,0,0,0,0,1030030564,1030030563,1030030562,0,0,0,0,0,0,1030030572,0,0},
    [1103003079]={1030030744,1030030745,1030030746,1030030742,1030030740,1030030743,1030030738,1030030737,1030030736,1030030735,1030030734,1030030733,1030030732,0,0,0,0,0,0,1030030747,1030030739,0},
    [1103003087]={1030030825,1030030826,1030030827,1030030823,1030030824,1030030824,1030030818,1030030817,1030030816,1030030815,1030030814,1030030813,1030030812,0,0,0,0,0,0,1030030828,1030030819,0},
    [1103004037]={1030040315,1030040316,1030040317,1030040325,1030040324,1030040323,0,0,0,0,1030040314,1030040313,1030040312,1030040327,1030040326,0,0,0,1030040328,1030040329,0,0},
    [1103006030]={1030060245,1030060246,1030060247,0,1030060253,1030060252,0,0,0,0,1030060244,1030060243,1030060242,0,0,0,0,0,0,0,0,0},
    [1103007028]={1030070233,1030070234,1030070235,1030070226,1030070225,1030070227,1030070218,1030070217,1030070216,1030070215,1030070214,1030070213,1030070212,0,0,0,0,0,0,1030070236,1030070219,0},
    [1103012010]={0,0,0,0,0,0,1030120038,1030120037,1030120036,1030120035,1030120034,1030120033,1030120032,0,0,0,0,0,0,0,0,0},
    [1103012019]={0,0,0,0,0,0,1030120138,1030120137,1030120136,1030120135,1030120134,1030120133,1030120132,0,0,0,0,0,0,0,0,0},
    [1103012031]={0,0,0,0,0,0,1030120258,1030120257,1030120256,1030120255,1030120254,1030120253,1030120252,0,0,0,0,0,0,0,0,0},
    [1103012039]={0,0,0,0,0,0,1030120339,1030120338,1030120337,1030120336,1030120335,1030120334,1030120333,0,0,0,0,0,0,0,0,0},
    [1103102007]={1031020026,1031020027,1031020028,1031020024,1031020023,1031020025,1031020019,1031020018,1031020017,1031020016,1031020015,1031020014,1031020013,0,0,0,0,0,0,1031020029,0,0},
    [1105001034]={0,0,0,0,1050010287,1050010289,1050010286,1050010285,1050010284,1050010283,1050010282,0,0,0,0,0,0,0,0,1050010292,0,0},
    [1105001048]={0,0,0,1050010429,1050010428,1050010434,1050010427,1050010426,1050010425,1050010424,1050010423,0,0,0,0,0,0,0,0,1050010435,0,1050010436},
    [1105001069]={0,0,0,1050010639,1050010638,1050010640,1050010637,1050010636,1050010635,1050010634,1050010633,1050010645,0,0,0,0,0,0,0,1050010643,1050010646,1050010644},
    [1105002091]={0,0,0,0,0,0,1050020847,1050020846,1050020845,1050020844,1050020843,1050020842,0,0,0,0,0,0,0,0,0,1050020848},
    [1105010019]={0,0,0,0,0,0,1050100144,1050100143,1050100142,1050100141,1050100139,1050100138,0,0,0,0,0,0,0,0,0,0},
    -- [ AUG Nine-Tailed Fury - Base Form (Red) ]
    [1101006098] = {1010060925,1010060926,1010060927,1010060919,0,1010060924,1010060918,1010060917,1010060916,1010060915,1010060914,1010060913,0,1010060930,1010060928,1010060929,1010060935,1010060934,1010060933,0,1010060936,0},

    -- [ AUG Nine-Tailed Fury - Ultimate Form (Gold) ]
    [1101006106] = {1010061004,1010061005,1010061006,1010060999,1010061000,1010061003,1010060998,1010060997,1010060996,1010060995,1010060994,1010060993,0,1010061009,1010061007,1010061008,1010061014,1010061013,1010061010,0,1010061015,0},
}
-- PASTE YOUR ATTACHMENT IDS ABOVE ↑↑↑

local cached_GameplayStatics = nil
local cached_PlayerTombBox = nil
local cached_ActorClass = nil
_G.NeedCheckDeadBoxTimer = 0

_G.DeadBox_TemperRequest = function(PlayerController)
    if not _G.LexusConfig.SkinDeadBox or _G.NeedCheckDeadBoxTimer <= 0 then return end
    
    local curTime = os.clock()
    if _G.LastCheckDeadBoxTime and (curTime - _G.LastCheckDeadBoxTime) < 2.0 then return end
    _G.LastCheckDeadBoxTime = curTime
    _G.NeedCheckDeadBoxTimer = _G.NeedCheckDeadBoxTimer - 1

    local PlayerCharacter = PlayerController:GetPlayerCharacterSafety()
    if not slua.isValid(PlayerCharacter) then return end
    
    if not cached_GameplayStatics then
        cached_GameplayStatics = import("GameplayStatics")
        cached_ActorClass = import("Actor")
        cached_PlayerTombBox = import("PlayerTombBox")
    end
    
    if not _G.CachedActorArray_DB then
        _G.CachedActorArray_DB = slua.Array(UEnums.EPropertyClass.Object, cached_ActorClass)
    end
    
    local UI_Util = require("client.common.ui_util")
    local GameInstance = UI_Util and UI_Util.GetGameInstance()
    if not GameInstance or not cached_GameplayStatics then return end

    local myPlayerKey = PlayerController.PlayerKey
    local currentBoxSkinId = 0
    pcall(function()
        local curVeh = PlayerCharacter.CurrentVehicle or (type(PlayerCharacter.GetCurrentVehicle) == "function" and PlayerCharacter:GetCurrentVehicle())
        if slua.isValid(curVeh) and _G.CurrentEquipVehicleID and _G.CurrentEquipVehicleID ~= 0 then
            currentBoxSkinId = tonumber(tostring(_G.CurrentEquipVehicleID) .. "1") or 0
        else
            local curWeapon = PlayerCharacter.GetCurrentWeapon and PlayerCharacter:GetCurrentWeapon() or PlayerCharacter.CurrentWeapon
            if slua.isValid(curWeapon) then
                local defineIDObj = curWeapon.GetItemDefineID and curWeapon:GetItemDefineID()
                local curWeaponID = (defineIDObj and slua.isValid(defineIDObj)) and defineIDObj.TypeSpecificID or 0
                
                if curWeaponID > 0 and _G.AddOutfitLastAppliedSkin and _G.AddOutfitLastAppliedSkin[curWeaponID] then
                    local skinID = _G.AddOutfitLastAppliedSkin[curWeaponID]
                    if skinID and skinID > 1000000 then 
                        currentBoxSkinId = skinID 
                    end
                end
            end
        end
    end)

    if currentBoxSkinId == 0 then return end

    local deadBoxes = cached_GameplayStatics.GetAllActorsOfClass(GameInstance, cached_PlayerTombBox, _G.CachedActorArray_DB)
    if not deadBoxes then return end
    
    local count = type(deadBoxes.Num) == "function" and deadBoxes:Num() or #deadBoxes
    for i = 1, count do
        local deadBoxActor = type(deadBoxes.Get) == "function" and deadBoxes:Get(i-1) or deadBoxes[i]
        if slua.isValid(deadBoxActor) and not deadBoxActor.bIsTDSkinApplied then
            local damageCauser = deadBoxActor.DamageCauser
            if slua.isValid(damageCauser) and damageCauser.PlayerKey == myPlayerKey then
                local DeadBoxAvatarComponent = deadBoxActor.DeadBoxAvatarComponent_BP
                if slua.isValid(DeadBoxAvatarComponent) then
                    pcall(function()
                        DeadBoxAvatarComponent:ResetItemAvatar()
                        DeadBoxAvatarComponent:PreChangeItemAvatar(currentBoxSkinId)
                        DeadBoxAvatarComponent:SyncChangeItemAvatar(currentBoxSkinId)
                    end)
                    deadBoxActor.bIsTDSkinApplied = true
                end
            end
        end
    end
end

--[[ AddOutfit v7.5 — Integrated Wardrobe Skin Selection System ]]
local F = {}
local DEBUG = false  
function F.log(...)
    if DEBUG then print("[AddOutfit]", ...) end
end

local MATCH_CONFIG = {
    outfitRes = 0,        
    hatRes    = 0,        
    maskRes   = 0,
    glassRes  = 0,
    tshirtRes = 0,        
    pantsRes  = 0,        
    shoesRes  = 0,        
    bagRes    = 0,        
    helmetRes = 0,        
    weaponSkins = {},
}

local ITEMS = {
    -- ==============================================================================
    -- ORIGINAL SYSTEM OF V7.5 (DO NOT DELETE THIS LINE)
    -- ==============================================================================
    703029, 703044, 703046, 703048, 1400010, 1400062, 1400070, 1400083, 1400100, 1400106, 1400112, 1400117, 1400134, 1407917, 1400170, 
    1400172, 1400173, 1400174, 1400175, 1400177, 1400179, 1400180, 1400228, 1400231, 1400233, 1400236, 1400237, 1400238, 1400242, 1400244,
    202408070, 202408071, 202408072, 202408073, 202408074, 202408075,
    1407905, 1407906, 1407907, 1407908, 1407909, 1407910, 1407911, 1407912, 1407913, 1407914, 1407915, 1407916,
    -- ==============================================================================
    -- 1. UPGRADE GUNS (ONLY HIGHEST LEVEL FOR EACH GUN)
    -- ==============================================================================
    -- [ M416 ]
    1101004163, -- Royal Splendor - M416 (Level 8)
    1101004201, -- White Unicorn Jade - M416 (Level 8)
    1101004209, -- Tide Rises - M416 (Level 8)
    1101004218, -- Phantom - M416 (Level 8)
    1101004226, -- Mystic Seal - M416 (Level 8)
    1101004236, -- Blue Lion Death - M416 (Level 8)
    1101004246, -- Fire Lotus - M416 (Level 8)
    1101004046, -- Ice - M416 (Level 7)
    1101004062, -- Clown - M416 (Level 7)
    1101004078, -- Wanderer - M416 (Level 7)
    1101004086, -- Reptile Roar - M416 (Level 7)
    1101004098, -- Wild Call - M416 (Level 7)
    1101004138, -- Tech Core - M416 (Level 7)

    -- [ AKM ]
    1101001174, -- Tribal Tyrant - AKM (Level 8)
    1101001213, -- Admiral Sea Star - AKM (Level 8)
    1101001242, -- Judgment Day - AKM (Level 8)
    1101001265, -- Time Shift - AKM (Level 8)
    1101001276, -- Illusion God - AKM (Level 8)
    1101001063, -- Seven Seas Legend - AKM (Level 7)
    1101001089, -- Ice - AKM (Level 7)
    1101001103, -- Fossil - AKM (Level 7)
    1101001116, -- Scary Pumpkin - AKM (Level 7)
    1101001128, -- Dragon King - AKM (Level 7)
    1101001143, -- Golden Pirate - AKM (Level 7)
    1101001154, -- Decoder - AKM (Level 7)
    1101001231, -- Naughty Rabbit - AKM (Level 7)
    1101001249, -- Holy Light (Moon God) - AKM (Level 7)
    1101001256, -- Holy Light (Golden Feather) - AKM (Level 7)
    1101001042, -- Glitter - AKM (Level 6)
    1101001068, -- Tiger Roar - AKM (Level 5)

    -- [ M16A4 ]
    1101002029, -- Red & Bones - M16A4 (Level 7)
    1101002056, -- Aurora Pulse - M16A4 (Level 7)
    1101002068, -- Radiant Edge - M16A4 (Level 5)
    1101002081, -- Skeletal Core - M16A4 (Level 7)
    1101002103, -- Dracoguard - M16A4 (Level 5)
    1101002110, -- Sweetheart Surge - M16A4 (Level 5)
    1101002117, -- Seraphic Beacon - M16A4 (Level 5)
    1101002125, -- Veldora - M16A4 (Level 5)
    1101002128, -- Thornrose Dawn - M16A4 (Level 3)
    1101002133, -- Mechagodzilla - M16A4 (Level 5)
    1101002142, -- BGMI × G-DRAGON - M16A4 (Level 5)
    1101002149, -- Celadon Aether - M16A4 (Level 5)
    1101002156, -- Saccharine Cage - M16A4 (Level 7)

    -- [ SCAR-L ]
    1101003146, -- Evil Thorn - SCAR-L (Level 8)
    1101003167, -- Blood Soul Demon - SCAR-L (Level 8)
    1101003227, -- Sky Bird - SCAR-L (Level 8)
    1101003057, -- Water Gun - SCAR-L (Level 7)
    1101003070, -- Scary Pumpkin - SCAR-L (Level 7)
    1101003080, -- Battle for Tomorrow - SCAR-L (Level 7)
    1101003099, -- Drop Da Bass - SCAR-L (Level 7)
    1101003119, -- Hextech Crystal - SCAR-L (Level 7)
    1101003188, -- Clown's Embrace - SCAR-L (Level 7)
    1101003195, -- Mystic Saintess - SCAR-L (Level 7)
    1101003208, -- Mystic Kingdom - SCAR-L (Level 7)
    1101003219, -- Crystal Glasses - SCAR-L (Level 7)
    1101003173, -- Royal Light - SCAR-L (Level 5)
    1101003212, -- Snack Cat - SCAR-L (Level 3)

    -- [ M762 ]
    1101008170, -- Phantasia Siren - M762 (Lv. 7)
    1101008081, -- Rebel Visitor - M762 (Level 8)
    1101008104, -- Mystic Star Core - M762 (Level 8)
    1101008146, -- Bone Shadow - M762 (Level 8)
    1101008154, -- Skeleton - M762 (Level 8)
    1101008051, -- Love Song - M762 (Level 7)
    1101008061, -- Lethal Shot - M762 (Level 7)
    1101008070, -- GACKT MOONSAGA - M762 (Level 7)
    1101008116, -- Messi Football Icon - M762 (Level 7)
    1101008126, -- Blood Dragon - M762 (Level 7)
    1101008136, -- Fairy Crystal - M762 (Level 7)
    1101008163, -- Dark Relic - M762 (Level 7)
    1101008026, -- Little Pony - M762 (Level 5)
    1101008036, -- Lotus Fury - M762 (Level 5)

    -- [ AUG ]
    1101006062, -- Ice Spirit - AUG (Level 8)
    1101006085, -- Mystic Rose - AUG (Level 8)
    1101006075, -- Fire Song - AUG (Level 7)
    1101006033, -- Wandering Circus - AUG (Level 5)
    1101006044, -- Evangelion Angel - AUG (Level 5)
    1101006067, -- Deep Sea Nightmare - AUG (Level 5)

    -- [ GROZA ]
    1101005038, -- Ryomen Sukuna - Groza (Level 7)
    1101005052, -- Shadow Fire - Groza (Level 7)
    1101005098, -- Godzilla Flames - Groza (Level 7)
    1101005019, -- Forest Cavalry - GROZA (Level 5)
    1101005025, -- Phantom Night - GROZA (Level 5)
    1101005043, -- Color Battle - Groza (Level 5)
    1101005082, -- Pumpkin Lantern - Groza (Level 5)
    1101005090, -- Ancient Relic - Groza (Level 5)
    1101005105, -- Singam Roar - Groza (Level 5)

    -- [ QBZ & Mk47 & G36C & Honey Badger & FAMAS & ASM Abakan & ACE32 ]
    1101007046, -- Dark Princess - QBZ (Level 7)
    1101007062, -- Deadly Flower Sword - QBZ (Level 7)
    1101007071, -- Destiny - QBZ (Level 7)
    1101007025, -- Sunlight - QBZ (Level 5)
    1101007036, -- Sweep - QBZ (Level 5)
    1101007079, -- Ice Fist - QBZ (Level 5)
    1101009019, -- Naughty Rabbit - Mk47 (Level 3)
    1101010029, -- Pitch Rhythm - G36C (Level 5)
    1101012033, -- Ancient Wood War - Honey Badger (Level 7)
    1101012009, -- Mystic Color - Honey Badger (Level 5)
    1101012018, -- Melodious Sound - Honey Badger (Level 5)
    1101012024, -- Honey Badger Mikey (Level 5)
    1101100012, -- Divine Emperor - FAMAS (Level 8)
    1101100018, -- Electronic Illusion - FAMAS (Level 5)
    1101101007, -- Black Bird Majesty - ASM Abakan (Level 7)
    1101102025, -- Water Monster - ACE32 (Level 8)
    1101102041, -- Prophecy - ACE32 (Level 8)
    1101102049, -- Butterfly Whisper - ACE32 (Level 8)
    1101102007, -- Kamehameha - ACE32 (Level 7)
    1101102017, -- Jade - ACE32 (Level 7)
    1101102032, -- Naughty Fox - ACE32 (Level 5)

    -- [ SMG (UZI, UMP45, Vector, Thompson, Bizon, MP5K, P90) ]
    1102001120, -- Ice - UZI (Level 8)
    1102001130, -- Hell Chains - UZI (Level 7)
    1102001024, -- Savagery - UZI (Level 6)
    1102001036, -- Mystic Relic - UZI (Level 5)
    1102001058, -- Surprise Moment - UZI (Level 5)
    1102001069, -- UZI Light - UZI (Level 5)
    1102001089, -- Magic - UZI (Level 5)
    1102001103, -- Fresh Orange - UZI (Level 5)
    1102001102, -- Fruit Press - UZI (Level 5)
    1102002438, -- Gemini Warriors - UMP45 (Level 8)
    1102002446, -- Dark Red Gemini - UMP45 (Level 8)
    1102002043, -- Fire Dragon - UMP45 (Level 7)
    1102002061, -- Deadly Dream - UMP45 (Level 7)
    1102002136, -- Ice - UMP45 (Level 7)
    1102002424, -- Anukhra Divine - UMP45 (Level 7)
    1102002053, -- EMP - UMP45 (Level 5)
    1102002070, -- Platinum Butcher - UMP45 (Level 5)
    1102002090, -- 8-Bit War - UMP45 (Level 5)
    1102002112, -- Christmas - UMP45 (Level 5)
    1102002117, -- Hornet - UMP45 (Level 5)
    1102002129, -- Festival Wave - UMP45 (Level 5)
    1102002143, -- PUBGM X NewJeans - UMP45 (Level 5)
    1102003080, -- Dragon Wings - Vector (Level 7)
    1102003100, -- Shadow Snow - Vector (Level 7)
    1102003020, -- Blood Bat Fang - Vector (Level 5)
    1102003031, -- Night Rose - Vector (Level 5)
    1102003039, -- Naughty Bear - Vector (Level 5)
    1102003052, -- Golden Count - Vector (Level 5)
    1102003065, -- Golden Scythe - Vector (Level 5)
    1102003072, -- Ultimate Assassin - Vector (Level 5)
    1102003090, -- KMF Lancelot - Vector (Level 5)
    1102004018, -- Sweet Candy - Thompson (Level 5)
    1102004034, -- Steam Runner - Thompson (Level 5)
    1102004048, -- Wisteria - Thompson SMG (Level 3)
    1102005064, -- Electronic Illusion - PP-19 Bizon (Level 7)
    1102005007, -- Chameleon - PP-19 Bizon (Level 5)
    1102005020, -- Skullcrusher - PP-19 Bizon (Level 5)
    1102005041, -- Martial God - PP-19 Bizon (Level 5)
    1102005052, -- DP Quantum Quake - Bizon (Level 5)
    1102005057, -- Lion Dance - PP-19 Bizon (Level 5)
    1102005072, -- Blood Sacrifice - PP-19 Bizon (Level 5)
    1102005078, -- SAKAMOTO SHOP - PP-19 (Level 5)
    1102007019, -- PUBGM X QWER - MP5K (Level 5)
    1102007022, -- Classic Pixel - MP5K (Level 3)
    1102105012, -- Cyber Catgirl - P90 (Level 7)
    1102105028, -- Celestial Horse - P90 (Level 7)
    1102105018, -- Golden Claw - P90 (Level 5)

    -- [ SNIPER & MARKSMAN RIFLE (Kar98, M24, AWM, SKS, SLR, Mk14, etc.) ]
    1103001202, -- Ice Demon - Kar98K (Level 8)
    1103001060, -- Fang Fury - Kar98K (Level 7)
    1103001079, -- Kukulkan Rage - Kar98K (Level 7)
    1103001101, -- Moonlight - Kar98K (Level 7)
    1103001129, -- Gackt Moon - Kar98K (Level 7)
    1103001146, -- Titan Shark - Kar98K (Level 7)
    1103001154, -- Deadly Code - Kar98K (Level 7)
    1103001179, -- Purple Lightning - Kar98K (Level 7)
    1103001191, -- Red Fire - Kar98K (Level 7)
    1103001085, -- Rock Night - Kar98K (Level 5)
    1103001160, -- Nebula Hunter - Kar98K (Level 5)
    1103001183, -- Cat Rhythm - Kar98K (Level 3)
    1103002030, -- Pharaoh Scepter - M24 (Level 7)
    1103002059, -- Life Cycle - M24 (Level 7)
    1103002087, -- Perfect Rhythm - M24 (Level 7)
    1103002106, -- Moonlight Forbidden - M24 (Level 7)
    1103002156, -- Dark Dawn - M24 (Level 7)
    1103002049, -- Butterfly Lady - M24 (Level 5)
    1103002047, -- Lethal Melody - M24 (Level 5)
    1103002094, -- High-Tech - M24 (Level 5)
    1103003022, -- Neon - AWM (Level 7)
    1103003030, -- Battle Commander - AWM (Level 7)
    1103003042, -- Godzilla - AWM (Level 7)
    1103003051, -- Rainbow Dragon - AWM (Level 7)
    1103003062, -- Fire Phoenix - AWM (Level 7)
    1103003079, -- Blood Sea Dragon - AWM (Level 7)
    1103003087, -- Green Snake - AWM (Level 7)
    1103003099, -- Dark Energy - AWM (Level 7)
    1103003092, -- Primordial - AWM (Level 5)
    1103004037, -- Red Lady - SKS (Level 7)
    1103004046, -- Steel Forest - SKS (Level 5)
    1103004058, -- Ice Energy - SKS (Level 5)
    1103004080, -- Blossom - SKS (Level 5)
    1103004087, -- Death Melody - SKS (Level 5)
    1103005024, -- Black Crow - VSS (Level 5)
    1103005048, -- White Scout - VSS (Level 3)
    1103009022, -- Peach Blossom - SLR (Level 5)
    1103009037, -- Magic Flame - SLR (Level 5)
    1103009051, -- Dream Demon - SLR (Level 5)
    1103009042, -- Ocean Sound - SLR (Level 3)
    1103006030, -- Ice River - Mini14 (Level 7)
    1103006046, -- Pure Beauty - Mini14 (Level 5)
    1103006058, -- Lucky Cat - Mini14 (Level 5)
    1103006063, -- Brave Racer - Mini14 (Level 5)
    1103006075, -- Fast War Rhythm - Mini14 (Level 5)
    1103007028, -- Dragon Kingdom - Mk14 (Level 8)
    1103007020, -- Galaxy Power - Mk14 (Level 5)
    1103007038, -- Soft Milk Dragon - Mk14 (Level 5)
    1103007043, -- Lucky Gift Box - Mk14 (Level 5)
    1103012010, -- Ephialtes Dinosaur - AMR (Level 8)
    1103012019, -- Fire God - AMR (Level 7)
    1103012031, -- Silent Farewell - AMR (Level 7)
    1103012039, -- Color War - AMR (Level 7)
    1103012024, -- Onyx Crystal - AMR (Level 5)
    1103100007, -- Predator - Mk12 (Level 5)
    1103102007, -- Space Battleship - DSR (Level 7)
    1103103007, -- Warrior Glory - M1 Garand (Level 7)

    -- [ SHOTGUN & MACHINE GUN (S12K, DBS, M249, DP-28, MG3...) ]
    1104001035, -- Soul Poison - S686 (Level 5)
    1104002022, -- Twilight - S1897 (Level 5)
    1104002049, -- Color Shock - S1897 (Level 3)
    1104003026, -- S12K GACKT (Level 7)
    1104003037, -- Atom Trigger - S12K (Level 5)
    1104003046, -- Cyber Heart - S12K (Level 5)
    1104004035, -- Beast Armor - DBS (Level 5)
    1104004041, -- Sandsinger - DBS (Level 5)
    1104004051, -- Okarun - DBS (Level 5)
    1104004024, -- Color Leopard - DBS (Level 3)
    1104102004, -- Golden Relic - NS2000 (Level 3)
    1105001034, -- Christmas Cannon - M249 (Level 7)
    1105001048, -- Light Empress - M249 (Level 7)
    1105001069, -- Dark Sovereign - M249 (Level 7)
    1105001020, -- Ice Queen M249 V (Level 5)
    1105001054, -- Stargaze Fury - M249 (Level 5)
    1105001062, -- Street Graffiti - M249 (Level 5)
    1105001075, -- Steel Shark - M249 (Level 4)
    1105002091, -- Blood Plague - DP28 (Level 8)
    1105002018, -- Mysterious Assassin - DP-28 (Level 5)
    1105002035, -- Jade Dragon - DP-28 (Level 5)
    1105002058, -- Marine Warrior - DP28 (Level 5)
    1105002063, -- Shenron Dragon - DP-28 (Level 5)
    1105002071, -- Divine Armor Warrior - DP-28 (Level 5)
    1105002076, -- Digital Cat - DP-28 (Level 5)
    1105002083, -- DP-28 Frieren's Staff (Level 5)
    1105002096, -- Fox Clan - DP-28 (Level 3)
    1105010019, -- Sky War God - MG3 (Level 7)
    1105010008, -- Sky Domain - MG3 (Level 5)
    1105010026, -- Mina Ashiro - MG3 (Level 5)

    -- [ MELEE & OTHER WEAPONS (Skorpion, Crossbow, Pan, Knife...) ]
    1106008013, -- Golden Code - Skorpion (Level 5)
    1106008022, -- Starlight Mystery - Skorpion (Level 3)
    1106011008, -- Snake Dragon Ascends - MP7 Dual (Level 5)
    1106011003, -- Candy Hunter - MP7 (Level 3)
    1107001018, -- Clown Fury - Crossbow (Level 3)
    1107098003, -- Tech Tremor - MGL (Level 3)
    1108001057, -- Dragon Hunter - Knife (Level 3)
    1108001064, -- Yor Short Sword SPY×FAMILY (Level 3)
    1108001069, -- Ki Sword (Level 3)
    1108001081, -- Godzilla Flaming Axe (Level 3)
    1108001085, -- Scout Regiment Sword (Level 3)
    1108001098, -- Heaven's Reverse Spear - Knife (Level 3)
    1108001104, -- Handcuff - Knife (Level 3)
    1108002059, -- Tide Fury Trident (Level 5)
    1108004125, -- Honey Pot - Pan (Level 5)
    1108004160, -- Crocodile - Pan (Level 5)
    1108004145, -- Rock Night - Pan (Level 5)
    1108004283, -- Glory - Pan (Level 6)
    1108004337, -- Atomic Pan (Level 6)
    1108004356, -- Fried Chicken - Pan (Level 3)
    1108004365, -- Mystic Yokai - Pan (Level 3)
    1108004377, -- Happy Penguin Pan (Level 5)
    1108004416, -- Hot Dance Fan - Pan (Level 3)
    1108005050, -- Ice Dragon - Dagger (Level 3)

    -- ==============================================================================
    -- 2. FULL SUPER CARS (VIP VEHICLES)
    -- ==============================================================================
    -- [ McLaren ]
    1961007, -- McLaren 570S (Black)
    1961010, -- McLaren 570S (White)
    1961012, -- McLaren 570S (Pink)
    1961013, -- McLaren 570S (Gold White)
    1961014, -- McLaren 570S (Gold Black)
    1961015, -- McLaren 570S (Silver)
    1961147, -- McLaren P1 (Starry Sky)
    1961148, -- McLaren P1 (Radiant Pink)
    1961149, -- McLaren P1 (Volcano Gold)
    1907054, -- McLaren F1 Racing Team (Electronic)
    1907058, -- McLaren F1 Racing Team
    1907059, -- McLaren F1 Racing Team (Victory)

    -- [ Koenigsegg ]
    1961016, -- Koenigsegg Jesko (Silver Grey)
    1961017, -- Koenigsegg Jesko (Rainbow)
    1961018, -- Koenigsegg Jesko (Dawn)
    1961029, -- Koenigsegg One:1 Gilt
    1961030, -- Koenigsegg One:1 Cyber Nebula
    1961031, -- Koenigsegg One:1 Jade
    1961032, -- Koenigsegg One:1 Phoenix
    1903074, -- Koenigsegg Gemera (Silver Grey)
    1903075, -- Koenigsegg Gemera (Rainbow)
    1903076, -- Koenigsegg Gemera (Dawn)

    -- [ Lamborghini ]
    1961020, -- Lamborghini Aventador SVJ Verde Alceo
    1961021, -- Lamborghini Centenario Galassia
    1961024, -- Lamborghini Aventador SVJ Blue
    1961025, -- Lamborghini Centenario Carbon Fiber
    1961144, -- Lamborghini Invencible Rosso Efesto
    1961145, -- Lamborghini Invencible Nebula Drift
    1903079, -- Lamborghini Estoque Oro
    1903080, -- Lamborghini Estoque Metal Grey
    1908066, -- Lamborghini Urus Pink
    1908067, -- Lamborghini Urus Giallo Inti

    -- [ Bugatti ]
    1961041, -- Bugatti Veyron 16.4 (Colorful)
    1961042, -- Bugatti Veyron 16.4 (Gold)
    1961043, -- Bugatti Veyron 16.4
    1961044, -- Bugatti La Voiture Noire
    1961045, -- Bugatti La Voiture Noire (Alloy)
    1961046, -- Bugatti La Voiture Noire (Warrior)
    1961047, -- Bugatti La Voiture Noire (Nebula)
    1961151, -- Bugatti Bolide (Mirror Blade)
    1961152, -- Bugatti Bolide (Flower of Hell)
    1961153, -- Bugatti Bolide (Ice Lake Illusion)

    -- [ Aston Martin ]
    1961048, -- Aston Martin Valkyrie (Luminous Diamond)
    1961049, -- Aston Martin Valkyrie (Racing Green)
    1915005, -- Aston Martin DBS Volante (Deep Cosmos)
    1915006, -- Aston Martin DBS Volante (Celestial Pink)
    1915007, -- Aston Martin DBS Volante (Black-Bronze Satin)
    1908084, -- Aston Martin DBX707 (Neon Purple)
    1908085, -- Aston Martin DBX707 (Quasar Blue)

    -- [ Pagani ]
    1961051, -- Pagani Zonda R (Tricolore Carbon)
    1961052, -- Pagani Zonda R (Bianco Benny)
    1961053, -- Pagani Zonda R (Melodic Midnight)
    1961054, -- Pagani Imola (Grigio Montecarlo)
    1961055, -- Pagani Imola (Crystal Clear Carbon)
    1961056, -- Pagani Imola (Nebula Dream)
    1961057, -- Pagani Imola (Arctic Aegis)

    -- [ Bentley ]
    1961137, -- Bentley Batur (Diamond Sparkle)
    1961138, -- Bentley Batur (End of Time)
    1961139, -- Bentley Bentayga Azure (Mystic Kingdom)
    1903200, -- Bentley Flying Spur Mulliner (Nebula Blue)
    1903201, -- Bentley Flying Spur Mulliner (Narrow Bay Flow)
    1908094, -- Bentley Bentayga Azure (Flower Rain)
    1908095, -- Bentley Bentayga Azure (Quiet Night)
    1915008, -- Bentley Continental GTC Mulliner (Dreamscape)
    1915009, -- Bentley Continental GTC Mulliner (Purple Noble)

    -- [ Maserati ]
    1961038, -- Maserati MC20 Bianco Audace
    1961039, -- Maserati MC20 Rosso Vincente
    1961040, -- Maserati MC20 Sogni
    1908075, -- Maserati Levante Blu Emozione
    1908076, -- Maserati Luce Arancione
    1908077, -- Maserati Levante Neon Urbano
    1908078, -- Maserati Levante Firmamento

    -- [ Dodge / SRT ]
    1961036, -- Dodge Challenger SRT Hellcat - Blaze
    1961037, -- Dodge Challenger SRT Hellcat - Lime
    1961050, -- Dodge Challenger SRT Hellcat Jailbreak - Hellfire
    1961136, -- Dodge Challenger SRT Hellcat - Blaze
    1961150, -- Dodge Challenger SRT Hellcat Jailbreak - Hellfire
    1903088, -- Dodge Charger SRT Hellcat - Fuchsia
    1903089, -- Dodge Charger SRT Hellcat - Tuscan Torque
    1903090, -- Dodge Charger SRT Hellcat Jailbreak - Violet Venom
    1903189, -- Dodge Charger SRT Hellcat - Tuscan Torque
    1903190, -- Dodge Charger SRT Hellcat Jailbreak - Violet Venom
    1908086, -- Dodge Hornet - Scarlet Sting
    1908088, -- Dodge Hornet GLH Concept - Redline
    1908089, -- Dodge Hornet - Sunburst
    1908188, -- Dodge Hornet GLH Concept - Redline
    1908189, -- Dodge Hornet - Sunburst

    -- [ Porsche ]
    1961062, -- Porsche 918 Spyder (Water Flow)
    1961063, -- Porsche 918 Spyder (964 Silver)
    1961064, -- Porsche 918 Spyder (Pink)
    1903218, -- Porsche Panamera Turbo S (Jade)
    1903219, -- Porsche Panamera Turbo S (Viper Green)
    1908108, -- Porsche Cayenne Turbo GT (Blazing Track)
    1908109, -- Porsche Cayenne Turbo GT (Lava Orange)
    1915021, -- Porsche 911 Carrera 4 GTS Cabriolet (Thousand Stars)
    1915022, -- Porsche 911 Carrera 4 GTS Cabriolet (Ruby Red)

    -- [ Shelby / Ford ]
    1961058, -- Shelby 427 Cobra (Blue & White)
    1961059, -- Shelby 427 Cobra (Retro Graffiti)
    1903210, -- Shelby GT500 (Black & Red)
    1903211, -- Shelby GT500 (Cyber Alien)
    1961068, -- Ford Mustang GTD (Blue Legend)
    1961069, -- Ford Mustang GTD (American Spirit)

    -- [ Lotus ]
    1961060, -- Lotus Emira (Deep Forest)
    1961061, -- Lotus Emira (Green Glide)

    -- [ Apollo ]
    1961065, -- Apollo EVO (Radiant Gold)
    1961066, -- Apollo EVO (Sunset)
    1961067, -- Apollo EVO (Ice)
    1903220, -- Apollo Intensa Emozione (Molten Hell)
    1903221, -- Apollo Intensa Emozione (Purple Ghost)
    1903222, -- Apollo Intensa Emozione (Duel)
    1903223, -- Apollo Intensa Emozione (Storm)

    -- [ SSC Tuatara ]
    1961140, -- SSC Tuatara Rose Illusion
    1961141, -- SSC Tuatara Crane Sky
    1961142, -- SSC Tuatara Dawn Blade Striker
    1961143, -- SSC Tuatara Night Blue Striker

    -- [ Tesla ]
    1903071, -- Tesla Roadster (Diamond)
    1903072, -- Tesla Roadster (Purple Crystal)
    1903073, -- Tesla Roadster (Ocean Blue)

    -- [ Ducati / Motor VIP ]
    1901073, -- DUCATI Panigale V4S
    1901074, -- Ducati Panigale V4S Black Phantom
    1901075, -- Ducati Panigale V4S Crimson Storm
    1901076, -- Ducati Panigale V4S Swift Mirage
    -- ==============================================================================
    -- ==============================================================================
    -- 1. OUTFITS
    -- ==============================================================================
    -- [ X-SUIT ]
    1406469, -- Golden Pharaoh X-Suit (7-Star)
    1406638, -- Arcane Jester X-Suit (6-Star)
    1406872, -- Stygian Liege X-Suit (7-Star)
    1406971, -- Marmoris X-Suit (7-Star)
    1407103, -- Fiore X-Suit (7-Star)
    1407140, -- Poseidon X-Suit (7-Star)
    1407141, -- Avalanche X-Suit (7-Star)
    1407142, -- Silvanus X-Suit (7-Star)
    1407219, -- Ignis X-Suit (7-Star)
    1407366, -- Galadria X-Suit (7-Star)
    1407512, -- Anukhra X-Suit (7-Star)
    1407550, -- Iridescence X-Suit (7-Star)
    1407625, -- Dravion X-Suit (7-Star)
    1407856, -- Phoenixtra X-Suit (7-Star)
    1407895, -- Blood Raven X-Suit (7-Star)
    1407990, -- Verdant Druvaen X-Suit (7-Star)
    1408038, -- Pyre Druvaen X-Suit (7-Star)
    1408045, -- Frost Druvaen X-Suit (7-Star)

    -- [ SUIT ]
    1400010, -- Assassin Suit
    1400011, -- Assassin Jacket
    1400012, -- Assassin Coat
    1400268, -- The Skulls Shadow Set
    1400270, -- The Skulls Daybreak Set
    1400274, -- The Skulls Ghost Set
    1400281, -- Time Cop Suit
    1400282, -- Skeleton Suit
    1400285, -- Special Ops Suit
    1400286, -- Combat Diver Suit
    1400288, -- Black Shark Diving Suit
    1400290, -- Bloody Fangs Suit
    1400291, -- Dark Maid Suit
    1400292, -- Bloodied Maid Suit
    1400298, -- Diplomat Suit
    1400302, -- Psycho Patient
    1400320, -- Chicken Dinner Suit
    1400327, -- Wetsuit
    1400333, -- Summer Breeze Suit
    1400366, -- Island Explorer Suit
    1400367, -- Desert Explorer Suit
    1400415, -- Angry Teddy Suit
    1400481, -- Space Guardian Suit
    1400492, -- Biochemical Suit
    1400494, -- Hazard Response Suit
    1400526, -- Slayer Bear Set
    1400668, -- Avant Garde Set
    1400687, -- Mummy Set
    1400688, -- Psychopath Set
    1400690, -- Skeleton Set
    1400691, -- Count Set
    1400692, -- Enchanter Set
    1400693, -- Vampire Set
    1400694, -- Demon Hunter Set
    1400695, -- Spellcaster Set
    1400702, -- Gunslinger Set
    1400705, -- Indian Kurta Pyjama
    1400772, -- Black Magma Set
    1400773, -- Master of the Land Set
    1400774, -- Winter Guardian Set
    1400775, -- Rogue Set
    1400777, -- Roaring Grizzly Set
    1400778, -- Dystopian Survivor Set
    1400782, -- Glacier Set
    1400783, -- Naughty Christmas Set
    1400784, -- Rock Biker Set
    1400785, -- Operative Set
    1400787, -- Diva Set
    1400788, -- Elf Helper Set
    1400789, -- Ice Princess Set
    1400790, -- Chilly Requiem Set
    1400791, -- Mad Bear Set
    1400792, -- Painter Set
    1405001, -- Yeti Suit
    1405002, -- Extreme Punk Set
    1405003, -- Forest Warrior Set
    1405004, -- Classic Santa Suit
    1405005, -- Reindeer Set
    1405006, -- Rudolph Suit
    1405007, -- Traveler's Set
    1405008, -- Emperor Penguin Suit
    1405009, -- Ice Hockey Set
    1405010, -- Desert Scorpion Set
    1405011, -- Dark Gladiator Set
    1405012, -- Charming Reindeer Set
    1405013, -- Stylish Santa Suit
    1405014, -- Nutcracker Suit
    1405015, -- Werewolf Suit
    1405018, -- Lion Dance Set
    1405019, -- Wild Boar Suit
    1405020, -- Wild Bear Suit
    1405021, -- Runner Set
    1405022, -- Troublemaker Set
    1405023, -- Frosty Suit
    1405026, -- Deadly Feline Set
    1405027, -- Anarchy Set
    1405028, -- Phantom Hunter Suit
    1405029, -- The Fangs Set
    1405030, -- Bling Set
    1405031, -- Plague Prevention Suit
    1405032, -- Winter Mountaineer Set
    1405033, -- Streetwear Set
    1405034, -- Frilly Set
    1405035, -- Flashy Suit
    1405036, -- Deadly Sweetheart Dress
    1405037, -- Smiley Heart Suit
    1405038, -- Dangerous Angel Set
    1405039, -- Adorable Panda Suit
    1405040, -- Cuddly Panda Set
    1405041, -- Roaring Dragon Set
    1405042, -- Dragon Hunter Set
    1405043, -- Sky Ranger Set
    1405044, -- Worldhopper Set
    1405045, -- Adventurer Set
    1405047, -- Queen of Hearts Set
    1405050, -- Mysterious Leather Armor
    1405051, -- Cake Suit
    1405052, -- Golden Piglet Suit
    1405053, -- Oni Suit (Red)
    1405054, -- Oni Suit (Blue)
    1405055, -- Onmyoji Suit
    1405056, -- Miko Suit
    1405057, -- Deadly Agent
    1405058, -- Silent Raider Set
    1405059, -- Midnight Mercenary Set
    1405060, -- Winter Vanguard Set
    1405061, -- Unicorn Set
    1405062, -- Nightmare Enforcer Set
    1405063, -- Claire Skin Set
    1405064, -- Marvin Costume
    1405065, -- Leon Skin Set
    1405066, -- Arachnoid Set
    1405067, -- Goth Punk Set
    1405068, -- Dark Goth Set
    1405069, -- Ada Costume
    1405070, -- Elite Operative Set
    1405071, -- Duelist Set
    1405072, -- Cool Cat Set
    1405073, -- Anniversary Set
    1405076, -- Leprechaun Set
    1405078, -- Carnival Set A
    1405079, -- Carnival Set B
    1405080, -- Ninja Set (Black)
    1405081, -- Masquerade Set
    1405082, -- Pirate Set
    1405083, -- Buccaneer Set
    1405088, -- Scarecrow Set
    1405090, -- Smooth Hitman Set (Cat)
    1405091, -- Smooth Hitman Set (Dog)
    1405092, -- The Fool Set
    1405093, -- Fighting Bull Set
    1405094, -- Armed Maiden Set
    1405095, -- Urban Neon Set
    1405096, -- Brilliant Anniversary Set
    1405097, -- Retro Anniversary Set
    1405098, -- Lucky Rabbit Set
    1405099, -- Tycoon Set
    1405100, -- Elite Soldier Set
    1405101, -- Soaring Eagle Set
    1405102, -- Golden Trigger Set
    1405103, -- Cherry Blossom Set
    1405104, -- Patriot Set
    1405107, -- Commoner Set
    1405108, -- General Set
    1405109, -- Guardian of the North Set
    1405110, -- Master of Winter Set
    1405111, -- Honorable Warrior Set
    1405112, -- Feudal Master Set
    1405113, -- Crimson Swordsman Set
    1405114, -- Enraged Unicorn Set
    1405115, -- Red Menace Outfit
    1405116, -- Umbrella Costume A
    1405117, -- Umbrella Costume B
    1405118, -- Ada Wong's Coat
    1405119, -- Umbrella Costume C
    1405120, -- HUNK's Costume
    1405121, -- Infected Patient Set
    1405122, -- Hoodlum Outfit
    1405123, -- Futuristic Bunny Set
    1405124, -- Dragon's Wrath Set
    1405125, -- Bunny Maid Set
    1405126, -- Mech Rabbit Set
    1405127, -- Lethal Animal Set
    1405128, -- Crew Challenge Victor Set
    1405129, -- Crew Challenge Combatant Set
    1405130, -- Pink Rose Set
    1405131, -- Peas in a Pod Set
    1405132, -- Forest Elf Set
    1405133, -- Great Indian Warrior Set
    1405134, -- Lobster Set
    1405135, -- Draft Pick Set
    1405136, -- Merchant Set
    1405137, -- Butler set
    1405138, -- Dazzling Anniversary Set
    1405141, -- Milk Cow set
    1405142, -- Frog Girl Set
    1405143, -- Pink Maid Set
    1405144, -- Park Ranger Set
    1405145, -- Invader Set
    1405146, -- Assassin in White Set
    1405147, -- Flame Wrestler Set
    1405148, -- Mobility Set
    1405149, -- Jumper Set
    1405150, -- Dawn Stalker Set
    1405151, -- Comfortable Panda Set
    1405152, -- Extreme Climber Set
    1405153, -- Alpine Climber Set
    1405154, -- Lethal Butterflies Set
    1405155, -- Seeing Red Set
    1405156, -- Straps R Us Set
    1405157, -- Western Brigand Set
    1405158, -- Marauder Set
    1405159, -- Chemical Hazard Suit
    1405160, -- Godzilla's Carapace
    1405161, -- Ghidorah's Carapace
    1405162, -- Assault Squad Set
    1405163, -- Urban Scavenger Set
    1405164, -- Blue Phantom Suit
    1405165, -- Tangerine Dream Set
    1405166, -- Cherry Gang Set
    1405167, -- Trooper Set
    1405168, -- Daycare Uniform
    1405169, -- Common Kid Set
    1405170, -- Egg Cracker Suit
    1405171, -- King of the Pond Suit
    1405172, -- Rosy Evening Dress
    1405173, -- Rosy Evening Suit
    1405174, -- Wedding Dress
    1405175, -- Wedding Tuxedo
    1405176, -- Sea Turtle Set
    1405177, -- Cheetah Set
    1405178, -- Vacationer Set
    1405179, -- Desert's Eye Set
    1405180, -- Crow Set
    1405181, -- Ice Cold Set
    1405182, -- Red Hot Set
    1405186, -- Godzilla Suit
    1405187, -- Royal Butterfly Set
    1405188, -- Kitty Set
    1405189, -- Nuclear Commando Set
    1405190, -- Dancer Set
    1405191, -- Leo Set
    1405192, -- Elite Force Set
    1405193, -- Wasp Set
    1405194, -- Musketeer Set
    1405195, -- Milkmaid Set
    1405196, -- Club Queen Set
    1405197, -- Seduction Set
    1405198, -- Crystal Set
    1405199, -- Hot Jumper Set
    1405201, -- Scarlet Set
    1405202, -- Carnival Set
    1405203, -- Hot Dog Set
    1405204, -- Icy Gaze Set
    1405205, -- Bunny Set
    1405206, -- Maid Set
    1405207, -- Ryan Set
    1405208, -- Apeach Set
    1405209, -- Fearless Fighter (Blue)
    1405210, -- Fearless Fighter (Red)
    1405211, -- Operation Leo Set
    1405212, -- Street Survivor Set
    1405213, -- Club Open Star Set
    1405216, -- Time Voyager Set
    1405218, -- Scarlet Crawler Set
    1405219, -- Sea Serpent Set
    1405220, -- Intergalactic Suit
    1405221, -- Cosmic Guardian Suit
    1405222, -- Crystal Bandit Set
    1405223, -- Tribal Warfare Set
    1405224, -- Punk Mobster Set
    1405225, -- Queen Mobster Set
    1405226, -- World Hopper Set
    1405227, -- Red Operative Set
    1405228, -- Retro Dancer Set
    1405229, -- Distance Swimmer Suit
    1405230, -- Casual Stroll Set
    1405234, -- Crazy Cadet Set
    1405235, -- Bronze Armor
    1405236, -- Delta Squad Set
    1405237, -- Shells on the Shore Set
    1405238, -- Clownfish Suit
    1405239, -- Squad Leader Set
    1405241, -- Sexy Military Set
    1405243, -- Loyal Soldier Set
    1405244, -- Fierce Forehand Set
    1405245, -- Dust Camo Soldier Set
    1405246, -- Jockey Set
    1405247, -- Season 8 Outfit
    1405256, -- The Seven Seas Set
    1405257, -- Black Thorn Set
    1405258, -- Brawling Medic Set
    1405259, -- Thunderous Armor
    1405260, -- Covert Agent Set
    1405261, -- Enforcer Set
    1405262, -- Black Rose Set
    1405263, -- Gold Rush Set
    1405264, -- Explorer's Set
    1405265, -- Master of the Sea Set
    1405266, -- Rookie Pirate Set
    1405267, -- Polar Explorer Set
    1405268, -- Frenzied Tackle Set
    1405269, -- Dune Speedster Set
    1405270, -- Casual Jogging Suit
    1405271, -- Fiend Hunter Set
    1405272, -- Fiend Huntress Set
    1405273, -- Heart of Gold Set
    1405274, -- Bestial Instinct Set
    1405275, -- Plague Carrier Set
    1405276, -- Magma Racer Set
    1405277, -- Lion Dancer Set
    1405278, -- Syndicate Set
    1405279, -- 1001 Nights Set
    1405280, -- Floral Hanbok
    1405282, -- S6 Crew Challenge Victor Set
    1405283, -- S6 Crew Challenge Combatant Set
    1405284, -- Steel Soldier Suit
    1405285, -- Steel Guardian Suit
    1405286, -- Nordic Ravager Outfit
    1405287, -- Legend of the Fjord Set
    1405289, -- Extreme Athlete Set
    1405290, -- Modern Witch Suit
    1405291, -- Monkey Business Set
    1405292, -- Armed Battalion Set
    1405293, -- Black Tortoise Defender Suit
    1405294, -- Vermilion Bird Swordsman Suit
    1405295, -- Demigod Gladiator Set
    1405296, -- The Huntress Set
    1405297, -- Kurenai Set
    1405298, -- Deadly Dancer Set
    1405299, -- Moon Bunny Set
    1405300, -- Ardent Protector Set
    1405301, -- Vikendi Elite Attendant Uniform
    1405302, -- Draconian Champion Set
    1405303, -- The Observer Set
    1405304, -- Le Tigre Suit
    1405305, -- Le Tigre Set
    1405306, -- Sky Hunter Set
    1405307, -- vivo Hero
    1405308, -- Season 9 Outfit
    1405318, -- Envoy of Death Set
    1405319, -- Blood Rain Set
    1405320, -- Pumpkin Wizard Suit
    1405321, -- Skeletal Rider Set
    1405322, -- Miss Red Set
    1405323, -- Special Forces Set
    1405324, -- Rick Grimes
    1405325, -- Daryl Dixon
    1405326, -- First Blood Set
    1405327, -- Pochinkenstein Set
    1405328, -- Enchantress Set
    1405329, -- Tin Soldier Suit
    1405330, -- Pastoral Girl Set
    1405331, -- Captain Lionheart Set
    1405332, -- Grinning Executioner Suit (Black)
    1405333, -- Grinning Executioner Suit (Gold)
    1405334, -- Masked Psychic Robe
    1405335, -- Orange Menace Set
    1405336, -- Sapphire Fairy Dress
    1405337, -- Ruby Fairy Dress
    1405338, -- Silver Fairy Dress
    1405339, -- Onyx Fairy Dress
    1405340, -- Angel Wings Set
    1405341, -- Devil Wings Set
    1405342, -- Pretty in Pink Set
    1405343, -- Elegant Floral Set
    1405344, -- Ghost Guardian Set
    1405345, -- Mascot Gone Wild Set
    1405346, -- Old Time Hunter Set
    1405347, -- Master Navigator Set
    1405348, -- Blue Daredevil Suit
    1405349, -- High Mobility Set
    1405350, -- Armored Hunter Set
    1405351, -- Iron Judge Robe
    1405352, -- Apocalypse Guardian Set
    1405353, -- Steel Thorns Set
    1405354, -- Desert Trooper Set
    1405355, -- Assassin of the Dawn Set
    1405356, -- Mechanical Mercenary Set
    1405357, -- Past Glory Set
    1405358, -- Irradiated Frog Set
    1405359, -- Snowflake Girl Set
    1405360, -- Winter Lady Set
    1405361, -- Deep Sea Set
    1405362, -- Lava Beret Set
    1405363, -- Unsleeping City Set
    1405364, -- Thorn Bramble Set
    1405365, -- Magnetic Soldier Set
    1405366, -- Syndicate Tabard Set
    1405367, -- Season 10 Outfit
    1405369, -- Night Kitten Set
    1405370, -- Forest Assassin Set
    1405371, -- Crystal Bunny Set
    1405372, -- Vigilant City Set
    1405373, -- Bodybuilder Set
    1405375, -- Giannis Jersey
    1405376, -- Negan
    1405377, -- Michonne
    1405378, -- Sweet Reindeer Set
    1405379, -- Reindeer Trainer Set
    1405380, -- Captivating Reindeer Set
    1405381, -- Gingerbread Man Set
    1405382, -- Wonderland Traveler Set
    1405384, -- Arctic Witch Set
    1405385, -- Snow Blush Set
    1405386, -- Winter Warmth Set
    1405387, -- Snowflake Bear Set
    1405388, -- Jubilant Baby Seal Set
    1405389, -- Pink Sunshine set
    1405390, -- Challenger's Will Set
    1405391, -- Challenger's Might Set
    1405392, -- Inner Fire Set
    1405393, -- Winter Antlers Set
    1405394, -- Field Commander Set
    1405395, -- Enigmatic Hunter Set
    1405396, -- Shadow Soldier Set
    1405397, -- Begonia Witch Set
    1405398, -- Gale Hunter Set
    1405399, -- Daybreak Witcher Set
    1405400, -- Crimson Assassin Set
    1405401, -- Crystal Lobster Set
    1405402, -- Anarkali Set
    1405403, -- White Bear Set
    1405404, -- Cybernetic Guardian Set
    1405405, -- Illusion Judge Set
    1405406, -- Vagabond General Set
    1405407, -- Flame Dancer Set
    1405408, -- Blazing Vermillion Bird Set
    1405409, -- Auspicious Rat Set
    1405410, -- Phantom Fox Set
    1405411, -- Dark Assassin Set
    1405412, -- Blood Lotus Set
    1405413, -- Globetrotter Set (Red & Black)
    1405414, -- Globetrotter Set (Orange & Black)
    1405415, -- Globetrotter Set (Yellow & White)
    1405416, -- Blind Noble Set
    1405417, -- Polar Dancer Set
    1405418, -- Snow Speedster Set
    1405420, -- The Pummeler Set
    1405422, -- Urban Dweller Set
    1405423, -- Reckless Mercenary Set
    1405424, -- Adorable Mouse Set
    1405425, -- Sweet Treats Set
    1405426, -- Red Bowtie Set
    1405427, -- Season 11 Outfit
    1405428, -- Boom Set
    1405429, -- That 80's Set
    1405430, -- Erangel Winner Set
    1405431, -- Chinese Opera Set
    1405432, -- Colorful Folk Costume Set
    1405433, -- Andre Drummond Jersey
    1405434, -- Isaiah Thomas Jersey
    1405435, -- Ben Simmons Jersey
    1405436, -- Lonzo Ball Jersey
    1405437, -- Painkiller #11 Set
    1405438, -- Urban Walker Set
    1405439, -- Dive into Blue Set
    1405440, -- Black Dragon Fighter Set
    1405441, -- Red Dragon Fighter Set
    1405442, -- Heroine Set
    1405443, -- Scarlet Nightmare Set
    1405444, -- Operation Tomorrow Set
    1405445, -- Futuristic Streetwear Set
    1405446, -- Pink Beetle Set
    1405447, -- Rhythm Rider Set
    1405448, -- Controller Set
    1405449, -- Queen of Wrath Set
    1405450, -- Joker of Spades Set
    1405451, -- Sonic Hunter Set
    1405452, -- Rustic Maiden Set
    1405453, -- The Damned Set
    1405454, -- Fullmetal Commando Set
    1405455, -- Heart of Stone Set
    1405456, -- Baboon Persona Set
    1405457, -- Frosty Geek Set
    1405458, -- Morning Glory Set
    1405459, -- Fantasy Girl Set
    1405460, -- Scarlet Fox Set
    1405461, -- Cyber Roamer Set
    1405462, -- Game Master Set
    1405463, -- Marine Hunter: Carlo
    1405464, -- Mysterious Hunter: Carlo
    1405465, -- Fiery Hunter: Carlo
    1405466, -- Woodland Hunter: Carlo
    1405467, -- Lowland Hunter: Carlo
    1405468, -- Aspiring Hunter: Carlo
    1405469, -- Magma Hunter: Carlo
    1405470, -- Armed Hound Set
    1405471, -- Mr. Kitty Set
    1405472, -- Dawn Goddess Set
    1405473, -- Twilight Goddess Set
    1405474, -- Crimson Fox Set
    1405475, -- Black Cat Set
    1405476, -- Savage Psycho Set
    1405477, -- Diamond Queen Set
    1405478, -- Joker of Clubs Set
    1405479, -- Metal Storm Set
    1405480, -- Purple Halo Set
    1405481, -- Charged Armor Set
    1405482, -- Anniversary Unicorn Set
    1405483, -- Steel Magnum Set
    1405484, -- Jester Hero Set
    1405485, -- Magician's Assistant Set
    1405486, -- Mummy Nurse Set
    1405487, -- Bunny Girl Set
    1405488, -- Battle Maiden Set
    1405489, -- Hardened Veteran Set
    1405490, -- Wasteland Soldier Set
    1405491, -- Phantom Catgirl Set
    1405492, -- Lighthearted Maiden Set
    1405493, -- Foxy Maiden Set
    1405494, -- Durian Master Set
    1405495, -- Mystic Legends Set
    1405496, -- Phantom Ninja Set
    1405497, -- Brawler Initiate Set
    1405498, -- Brawler Legend Set
    1405499, -- Brawler Master Set
    1405500, -- Danger Games Set
    1405501, -- Masked Swordsman Set
    1405502, -- Naughty Kitty Set
    1405503, -- GACKT-Creed
    1405504, -- GACKT-Karma
    1405505, -- Romantic Catgirl Set
    1405509, -- Adorable Schoolgirl Set
    1405510, -- Season 12 Outfit
    1405511, -- Brawler God Set
    1405514, -- Golden Claw Set
    1405515, -- Banana Set
    1405516, -- Ultimate Cricket Kit
    1405517, -- Legendary Cricket Kit
    1405518, -- Golden Splendor Set
    1405519, -- Wasteland Survivor Set
    1405520, -- Dark-Ops Agent Set
    1405521, -- Arctic Explorer Set
    1405522, -- Snow Walker Set
    1405523, -- Final Frontier Set
    1405524, -- Snow Vanguard Set
    1405525, -- Arctic Rose Set
    1405526, -- Phantom Rebel Set
    1405527, -- Marauder Scout Set
    1405528, -- Jade Mysteries Set
    1405529, -- Lieutenant Parsec Set
    1405530, -- Firehawk Warrior Set
    1405531, -- Dawn Hunter Set
    1405532, -- Ninja Kitty Set
    1405533, -- Bloodthirsty Fiend Set
    1405534, -- Cardboard Warrior Set
    1405535, -- Cardboard King Set
    1405536, -- Jungle Wolverine Set
    1405537, -- Pinocchio Set
    1405538, -- Jungle Hunter Set
    1405539, -- Gold Princess Set
    1405540, -- Silver Princess Set
    1405541, -- Mother Clucker Set
    1405542, -- Witch King Set
    1405543, -- Silverback Set
    1405544, -- Jungle Prey Set
    1405545, -- Mr. Fox Set
    1405546, -- Feral Scavenger Set
    1405547, -- Penguin Vacation Set
    1405548, -- Stealth Brigade Set
    1405549, -- Nebula Hero Set
    1405550, -- Ice Ranger
    1405551, -- Fire Ranger Set
    1405552, -- Rock 'n' Roll Set
    1405553, -- Puppet Agent Set - Basic
    1405554, -- Puppet Agent Set - Intermediate
    1405555, -- Puppet Agent Set - Advanced
    1405556, -- Puppy Love Set
    1405557, -- Fortune Teller Set
    1405558, -- Merry Stegosaurus Set
    1405559, -- Exterminator Set
    1405560, -- Purple Berets Set
    1405561, -- Fierce Combatant Set
    1405562, -- Anatolian Set
    1405563, -- Sun Disciple Set
    1405564, -- Sun Disciple Mask
    1405565, -- Skyline Runner Set
    1405566, -- Season 13 Outfit
    1405567, -- Army Men Set
    1405569, -- Puppetmaster Andy
    1405570, -- Masked Comedian Andy (Coffee)
    1405571, -- Masked Comedian Andy (Silver-Gray)
    1405572, -- Masked Comedian Andy (Ice Blue)
    1405573, -- Masked Comedian Andy (Jade Green)
    1405574, -- Puppet Godfather Andy
    1405575, -- Master Performer Andy
    1405576, -- Neon Beats Set
    1405577, -- Desert Rose Set
    1405578, -- Hand of Duat Set
    1405579, -- Scorching Commander Set
    1405580, -- Wild Fever Set
    1405581, -- Anubis Acolyte Set
    1405582, -- Violet Halo Set
    1405583, -- Dazzling Youth Set
    1405584, -- Will of Horus Set
    1405585, -- Divine Acolyte Set
    1405586, -- Fiery Brawler Set
    1405587, -- Mystical Feline Set
    1405588, -- Pink Hedgehog Set
    1405589, -- Duat Pathfinder Set
    1405590, -- Avian Tyrant Set
    1405591, -- Butcher of Stalber Set
    1405592, -- Iron Rose Set
    1405593, -- Red Commander Set
    1405594, -- Black Commander Set
    1405595, -- Night Commander Set
    1405596, -- Super Agent Set
    1405597, -- Urban Stroll Set
    1405598, -- Season 14 Outfit
    1405599, -- Temporal Ninja Set
    1405600, -- Night Warrior Set
    1405601, -- Cyber Assassin Set
    1405602, -- Tattered Bear Set
    1405603, -- Burglar Set
    1405604, -- Master Leopard Set
    1405605, -- Jazzy Bananaman Set
    1405606, -- Fluffy Beauty Set
    1405607, -- Elite Gladiator Set
    1405611, -- Refreshing Violet Set
    1405612, -- Festive Lei Set
    1405613, -- Pro League Set
    1405614, -- Sassy Koala Set
    1405615, -- Cerulean Wanderer Set
    1405616, -- Auspicious Warrior Set
    1405617, -- Sweet Sailor Set
    1405618, -- Rockin' Summer Set
    1405619, -- Bling-kini Set
    1405620, -- Karaagekun Set
    1405621, -- Moon Dancer Set
    1405622, -- Rouge Set
    1405623, -- Underworld Guide Set
    1405624, -- Warrior of Nut Set
    1405625, -- Warrior of Ra Set
    1405629, -- Dark Widow Set
    1405630, -- Iron Berserker Set
    1405631, -- Dino Park Set
    1405632, -- Anubian Magistrate Set
    1405633, -- Ragtag Goon Set
    1405634, -- Sacred Sentinel Set
    1405638, -- Karaagekun Set (Red)
    1405639, -- Red, White & Blue Outfit
    1405640, -- Stars & Stripes Outfit
    1405641, -- Fright Night Outfit
    1405642, -- Wicked Witch Outfit
    1405643, -- Red Racecar Knight Outfit
    1405644, -- Yin-Yang Outfit
    1405645, -- Persian Warrior Outfit
    1405646, -- Punkin Outfit
    1405647, -- Corsair Outfit
    1405648, -- Frankenstein's Monster Outfit
    1405649, -- Jade and Silk Outfit
    1405650, -- Gold and Silk Outfit
    1405651, -- Gothic Gentleman Outfit
    1405652, -- Gothic Lady Outfit
    1405653, -- Black Racecar Knight Outfit
    1405654, -- Pink Plume Outfit
    1405655, -- Lady of Blood Outfit
    1405656, -- Wraith Lord Outfit
    1405657, -- Spike Demon Outfit
    1405658, -- Grave Lord Outfit
    1405659, -- Desert Prince Outfit
    1405660, -- Tea Party Outfit
    1405661, -- Cyber Tribe Outfit
    1405662, -- Samurai Ops Outfit
    1405663, -- Shadow Assassin Outfit
    1405664, -- Metal & Miniskirt Outfit
    1405665, -- Bee Outfit
    1405666, -- DJ Fresh Outfit
    1405667, -- Blackwing Outfit
    1405668, -- Silverstar Outfit
    1405669, -- Whitestar Outfit
    1405670, -- Durian Outfit
    1405671, -- Leopard Print Outfit
    1405672, -- Crocodile Outfit
    1405673, -- Squirrel Outfit
    1405674, -- Princess Outfit
    1405675, -- Ladybug Outfit
    1405676, -- Admiral's Watch Outfit
    1405677, -- Jailbird Outfit
    1405679, -- Orange Jumpsuit Outfit
    1405690, -- Boxing Manager Outfit
    1405695, -- Season 15 Outfit
    1405696, -- Heavy Combat Outfit
    1405697, -- Dauntless Outfit
    1405703, -- Thorn Trooper Set
    1405704, -- PurPink Set
    1405705, -- Robo Santa Set
    1405706, -- Winter Queen Set
    1405707, -- Youth Enforcer Set
    1405708, -- Wishing Treeman Set
    1405709, -- Clockwork Tin Soldier Set
    1405710, -- Underground Boxer Set
    1405711, -- Snowflake Dancer Set
    1405712, -- Midnight Magician Set
    1405713, -- Nutcracker Set
    1405714, -- Gold Warrior Set
    1405715, -- Wild Ambition Set
    1405716, -- Noble Lineage Set
    1405718, -- Frog Prince Set
    1405719, -- Present Set
    1405720, -- Budget Mecha Set
    1405721, -- Graceful Maiden Set
    1405722, -- Furnace Man Set
    1405723, -- Snowwoman Set
    1405724, -- Street Cred Set
    1405725, -- Mystery Reveler Set
    1405726, -- Shadow Maiden Set
    1405727, -- Metro Soldier Outfit
    1405728, -- Night Terror Outfit
    1405731, -- Artyom Outfit
    1405732, -- Anna Outfit B
    1405733, -- Miller Outfit B
    1405734, -- Miller Outfit A
    1405735, -- Cyber Enforcer Set
    1405736, -- Punk Hipster Set
    1405737, -- Anna Outfit A
    1405738, -- Arctic Stroll Outfit
    1405739, -- Stroll in the Dark Outfit
    1405740, -- Glacial Stroll Outfit
    1405741, -- Groovy Teen Outfit
    1405742, -- Schoolgirl in Pink Outfit
    1405744, -- Polymath Outfit
    1405745, -- Survivor Outfit
    1405746, -- Armed Survivor Outfit
    1405748, -- Zebra Suit Outfit
    1405749, -- Leopard Suit Outfit
    1405750, -- Dalmatian Suit Outfit
    1405751, -- Energetic Cutie Set
    1405752, -- Frosty Elder Set
    1405753, -- Snow Elf Set
    1405754, -- Hound Bodybuilder Set
    1405755, -- Chilly Pepper Set
    1405756, -- Victorian Maiden Set
    1405757, -- Snowflake Fairy Set
    1405758, -- Gentleman Magician Set
    1405760, -- Bear Detective Set
    1405762, -- Bear Pajamas Set
    1405763, -- Clever Bear Set
    1405764, -- Blue Koala Outfit
    1405765, -- Swift Leopard Outfit
    1405766, -- Cute Puppy Outfit
    1405767, -- Season 16 Set
    1405773, -- Nosalis Outfit
    1405785, -- Noble Masquerader Set
    1405786, -- Acolyte of Justice Set
    1405787, -- Ghillie Lion Set
    1405788, -- Lucky Mascot Set
    1405789, -- Dayman Set
    1405790, -- Celebrity Chef Set
    1405791, -- B.Duck Head
    1405792, -- Ghillie Dragon Set
    1405793, -- Woman in Gold Set
    1405794, -- Agent Pink Set
    1405795, -- Agent Black Set
    1405796, -- Bewitching Enchantress Set
    1405797, -- Lord of the Wastes Set
    1405798, -- Queen of Riches Set
    1405799, -- Regal Overlord Set
    1405800, -- Underworld Sovereign Set
    1405801, -- B.Duck Set
    1405802, -- Dream Idol Set
    1405803, -- Galactic Traveler Set
    1405804, -- Spooky Bear Set
    1405805, -- Eerie Doll Set
    1405806, -- Lion Champion Set
    1405807, -- Dawn Walker Set
    1405808, -- Daytime Magician Set
    1405810, -- Mr. Bronze Set
    1405811, -- Resplendent Dawn Set
    1405812, -- Deadly Sickle Set
    1405813, -- Guardian Armor Set
    1405814, -- Faceless Clown Set
    1405815, -- Street Smarts Set
    1405816, -- Elite Investigator Set
    1405817, -- Season 17 Outfit
    1405819, -- Taiyaki Set
    1405820, -- Cute Baddie Set
    1405821, -- Jungle Chivalry Set
    1405822, -- Cute Penguin Set
    1405823, -- Witch Coven Set
    1405824, -- Prince from Afar Set
    1405825, -- Flower Maiden Set
    1405826, -- Dazzling Snowboarder Set
    1405827, -- Scarlet Academy (Male) Set
    1405828, -- Scarlet Academy (Female) Set
    1405829, -- Vengeful Bull Set
    1405830, -- White-haired Ogre Set
    1405831, -- Mr. Grape Set
    1405833, -- Silent Hunter Set
    1405834, -- Armored Knight Set
    1405835, -- Vibrant Youth Set
    1405836, -- Operation Nightingale Set
    1405837, -- Energetic Beastgirl Set
    1405839, -- PMGC Set
    1405856, -- Neon Lord Set
    1405857, -- Neon Lady Set
    1405858, -- Speed Bunny Set
    1405859, -- Iron Tortoise Set
    1405860, -- Modern Lord Set
    1405861, -- Rosy Melody Set
    1405862, -- Sick Beats Set
    1405863, -- Lady Amethyst Set
    1405864, -- High Fidelity Set
    1405865, -- Contemporary Wukong Set
    1405866, -- Golden Prince Set
    1405867, -- Dancing Princess Set
    1405872, -- Obsidian Eagle Set
    1405873, -- Blackbird Set
    1405874, -- Firebird Set
    1405875, -- Jester Gangster Set
    1405876, -- Keep Out Set
    1405877, -- Snow Sakura Set
    1405878, -- Red Battlecat Set
    1405879, -- Azure Battlecat Set
    1405880, -- Jade Battlecat Set
    1405881, -- Amber Battlecat Set
    1405882, -- Fluorescent Jester Set
    1405883, -- Fluorescent Jesterette Set
    1405884, -- Spade Trickster Set
    1405885, -- Falling Blossom Set
    1405886, -- Red Rider Set
    1405887, -- Ladybug Set
    1405888, -- String Ensemble Set
    1405889, -- Stomping Beat Set
    1405890, -- Heavenly Cadence Set
    1405891, -- Electronica Hearts Set
    1405892, -- Night Dancer Set
    1405893, -- Season 18 Outfit
    1405894, -- Resort Guest Set
    1405895, -- Carrot Fanatic Set
    1405896, -- Oasis Ruler Set
    1405898, -- Forest Mascot Set
    1405899, -- Bravocado Set
    1405900, -- Happy Beat Set
    1405901, -- Devourer Set
    1405902, -- PMPL 2021 Spring Set
    1405903, -- Happy Raccoon Set
    1405904, -- Red Panda Set
    1405905, -- Amazing Journey Set
    1405906, -- Lady Butterfly Set
    1405910, -- Nightscape Set
    1405911, -- Lilac Attack Set
    1405913, -- MECHAGODZILLA Set
    1405914, -- Mecha Beast Set
    1405915, -- Masked Wasp Set
    1405917, -- Killer Hornet Set
    1405918, -- Flower Queen Set
    1405919, -- Fiery Love Set
    1405920, -- Nordic Operative Set
    1405921, -- Jungle Predator Set
    1405922, -- Fruit Fiesta Set
    1405923, -- Kong Set
    1405924, -- Star Guardian Set
    1405925, -- Space Mascot Set
    1405926, -- Viper Assassin Set
    1405927, -- Cyber Monkey Set
    1405928, -- Galactic Marshal Set
    1405929, -- Quicksand Dominator Set
    1405930, -- Sky Explorer Set
    1405931, -- Mecha Ant Set
    1405932, -- Cony Set
    1405933, -- Brown Set
    1405934, -- Godzilla Set
    1405935, -- Swifty Thug Set
    1405937, -- House DJ Set
    1405938, -- Big Bad Wolf Set
    1405939, -- Simple Insect Set
    1405940, -- Extreme Skydiver Set
    1405941, -- Languid Dragonfly Set
    1405942, -- Oriental Maiden Set
    1405943, -- Insect Queen Set
    1405944, -- General Beetle Set
    1405945, -- Garden Observer Set
    1405946, -- Trendy Kitty Set
    1405947, -- Lizard Captain Headpiece
    1405948, -- Dress Uniform Set
    1405949, -- Adorable Bee Set
    1405950, -- Dinosaur Jockey Set
    1405951, -- Desert Prince Set
    1405952, -- Highland Legion Set
    1405954, -- Nocturnal Hunter Set
    1405956, -- Lady Scarlet Set
    1405957, -- Rainbow Unicorn Set
    1405958, -- White Ragdoll Set
    1405960, -- Sweet Honey Set
    1405961, -- Miss Shark Set
    1405962, -- Cute Bazzi Set - Red
    1405963, -- Cute Bazzi Set - Panda
    1405964, -- Cute Bazzi Set - Pink
    1405965, -- Bunny Princess Set
    1405966, -- Chicken Set
    1405967, -- Season 19 Set
    1405968, -- Race Queen Set
    1405973, -- Marine Marauder Set
    1405975, -- Sunken Templar Set
    1405976, -- Glacial Punisher Set
    1405977, -- Noctus Sovereign Set
    1405984, -- Lunar Witch Set
    1405985, -- Lumos Daemon Set
    1405986, -- Poseidon's Ironguard Set
    1405987, -- Poseidon's Herald Set
    1405988, -- Rich Brian Aerial Air Max Set
    1405989, -- PsyOp Samurai Set
    1405990, -- Cybernet Diva Set
    1405991, -- Hacker 301 Set
    1405992, -- Unhinged Mortician Set
    1405993, -- Azure Warrior Set
    1405994, -- Night Stalker Set
    1405995, -- Future Pioneer Set
    1405996, -- Cyber Brawler Set
    1405997, -- Aquatic Predator Set
    1405998, -- Reptilian Lurker Set
    1405999, -- Aquatic Assassin Set
    1406000, -- Aquatic Warrior Set
    1406005, -- Amphibian Hunter Set
    1406006, -- QUACK Agent Set
    1406007, -- Antelope Scout Set
    1406008, -- Orange Zebra Set
    1406009, -- Maleficent Rabbit Set
    1406010, -- Racing Animal Set
    1406011, -- Sheep Guard Set
    1406012, -- Frog Tourist Set
    1406013, -- Tidal Wargod Set
    1406014, -- Wavebreaker Set
    1406015, -- Marine Stalker Set
    1406016, -- Cyber Trooper Set
    1406017, -- Arctic Spy Set
    1406018, -- Mountain Plunderer Set
    1406019, -- PMPL 2021 Fall Set
    1406020, -- Monster Onesie Set
    1406021, -- Dairy Cow Set
    1406022, -- Lovely Gal Set
    1406023, -- Wild Predator Set
    1406025, -- Cute Pink Set
    1406026, -- Adorable Dinosaur Set
    1406027, -- Bionic Catwoman Set
    1406028, -- Tender Cactus Set
    1406029, -- Sweet Raccoon Set
    1406030, -- Sea Princess Set
    1406031, -- Rich Brian Freestyle Rap Outfit
    1406032, -- Gladiator Set
    1406033, -- Jungle Ranger Set
    1406034, -- Elegant Daily Wear Set
    1406035, -- Tiger Hunter Set
    1406036, -- Rose Maid Set
    1406037, -- C1S1 Set
    1406038, -- Focused Jock Set
    1406039, -- Deep Sea Cyscout Set
    1406040, -- Amber Raider Set
    1406041, -- Fashion Trailblazer Set
    1406042, -- Street Punk Set
    1406043, -- Ice Avenger Set
    1406044, -- Cool to Be Hot Set
    1406045, -- King of Speed Set
    1406046, -- PMNC 2021 Set
    1406047, -- Galaxy Messenger Set
    1406049, -- Day Dream Set
    1406050, -- Valorian Set
    1406051, -- Iron Mask Set
    1406052, -- Justice Defender Set
    1406053, -- Valor Champion Set
    1406054, -- Emerald Punk Set
    1406055, -- Scarlet Rogue Set
    1406056, -- Pale Fanatic Set
    1406057, -- Beta 5 Set
    1406058, -- Occult Sorcerer Set
    1406059, -- Mecha Reaper Set
    1406060, -- Bonds of Blood Set
    1406061, -- Vampiric Touch Set
    1406062, -- Lobster Avenger Set
    1406063, -- Ruinous Ravelord Set
    1406064, -- Nether Aristo Set
    1406065, -- Pumpkin Cavalier Set
    1406066, -- Deep Fried Set
    1406067, -- Mecha Bruiser Set
    1406068, -- Demon Guise Set
    1406069, -- Anachronism Set
    1406070, -- Cheese Wrecker Set
    1406071, -- Deepsea Hunter Set
    1406072, -- Urban Assassin Set
    1406073, -- Aquatic Nemesis Set
    1406074, -- Techno Caster Set
    1406075, -- Bonehead Set
    1406076, -- Cream Cake Set
    1406077, -- Violet Wonder Set
    1406078, -- Westerly Wizard Set
    1406079, -- Rotten Tomato Set
    1406080, -- Mystic Vagabond Set
    1406081, -- Farm Fresh Set
    1406082, -- Lone Wolf Set
    1406083, -- Chrono Cyborg Set
    1406084, -- Forerunner Set
    1406085, -- Briar Rose Set
    1406086, -- Candy Corn Set
    1406087, -- Furry Fox Set
    1406088, -- Gentle Bunny Set
    1406089, -- Berry Cute Set
    1406090, -- Trendy Fox Set
    1406091, -- Black Bear Set
    1406092, -- Undead Gunslinger Set
    1406093, -- Riot Force Set
    1406094, -- Alluring Hunter Set
    1406095, -- Tengu Warrior Set
    1406096, -- Lovely Baker Set
    1406097, -- Enchanting Gaze Set
    1406098, -- Regal Gaze Set
    1406099, -- ADIDAS FLEECE Set
    1406100, -- ADIDAS WINDBREAK Set
    1406101, -- Emerald Captain Set
    1406102, -- Bubble Tea Set
    1406103, -- Edge of Death Set
    1406104, -- Vibrant Celebration Set
    1406105, -- I SEE YOU Set
    1406108, -- Battalion Commander Set
    1406109, -- Ski Champ Set
    1406110, -- C1S2 Set
    1406111, -- Neon Dancer Set
    1406112, -- Midnight Hunter Set
    1406113, -- GACKT MOONSAGA Set
    1406114, -- ADIDAS Shoes
    1406115, -- Survivor Set
    1406116, -- Survivor Cover
    1406117, -- Silent Dawn Set
    1406118, -- Moonlit Fantasy Set
    1406119, -- Chromatic Brilliance Set
    1406120, -- Violet Knight Set
    1406121, -- Gold Sheriff Set
    1406123, -- Merry Tidings Set
    1406124, -- Guardian Suit
    1406125, -- Party Trooper Set
    1406126, -- Enchanting Night Set
    1406127, -- Charming Darkness Set
    1406128, -- Mysterious Dream Set
    1406129, -- Fantasy Realm Set
    1406130, -- Impish Prankster Set
    1406131, -- Caribou Mercenary Set
    1406140, -- Jinx Suit
    1406141, -- Vi Suit
    1406142, -- Jayce Suit
    1406143, -- Caitlyn Suit
    1406144, -- Violet Blossom Set
    1406145, -- Foxy Suit Set
    1406146, -- Lemon Fresh Set
    1406153, -- Frost Order Set
    1406154, -- Draconic Paladin Set
    1406155, -- Arctic Ruler Set
    1406156, -- Infernal Ruler Set
    1406157, -- Ashen Cyberwear Set
    1406158, -- Reindeer Ghillie Set
    1406159, -- Wintry Ruler Set
    1406160, -- Frost Conjurer Set
    1406165, -- Hairy Metal Set
    1406166, -- Wayward Hunter Set
    1406167, -- Dazzling Gaze Set
    1406168, -- Vanguard Suit
    1406169, -- Elite Suit
    1406170, -- Lethal Creepster Set
    1406171, -- Frozen Guardian Set
    1406172, -- Blissful Pine Set
    1406173, -- Merry Yeti Set
    1406174, -- Metallic Marshall Set
    1406175, -- Resistance Fighter Set
    1406176, -- Space Explorer Set
    1406177, -- Dance Champion Set
    1406178, -- Lovesick Girls ROSÉ Outfit
    1406179, -- Lovesick Girls JENNIE Outfit
    1406180, -- Lovesick Girls JISOO Outfit
    1406181, -- Lovesick Girls LISA Outfit
    1406182, -- PMGC 2021 Special Set
    1406183, -- PMGC 2021 Set
    1406184, -- Liverpool FC Home Kit Set
    1406185, -- Winter Fantasy - Men's Collection
    1406186, -- Winter Fantasy - Women's Collection
    1406187, -- Gundala Guruh Kilat Set
    1406188, -- Gundala Tracksuit Set
    1406189, -- Wonderland Set
    1406190, -- DigiFlash Set
    1406191, -- Roadblock Maverick Set
    1406192, -- Rogue Feline Set
    1406193, -- Athletic Youth Set
    1406194, -- Panda Hoodie Set
    1406195, -- Sweet Tiggy Set
    1406196, -- Wintry Attendant Set
    1406197, -- Warm Attendant Set
    1406198, -- Magma Beast Set
    1406199, -- Winter Bunny Set
    1406200, -- Snowy Seal Set
    1406201, -- Celestial Ruler Set
    1406202, -- C1S3 Set
    1406203, -- Kill This Love ROSÉ Outfit
    1406204, -- Kill This Love JENNIE Outfit
    1406205, -- Kill This Love JISOO Outfit
    1406206, -- Kill This Love LISA Outfit
    1406207, -- Heroic Warrior Set
    1406209, -- Egor Kreed Collaboration Set
    1406210, -- Island Traveler Anna
    1406211, -- Forest Adventurer Anna
    1406218, -- CYCLE Set
    1406219, -- Mikuru Asahina Set
    1406220, -- Haruhi Suzumiya Set
    1406221, -- Yuki Nagato Set
    1406222, -- Battle Spirit Set
    1406223, -- Winter Promise Set
    1406224, -- Legendary Warrior Set
    1406225, -- Reaction Survivor
    1406228, -- Vintage Bard Set
    1406229, -- Candle Guardian Set
    1406230, -- Dream Rancher Set
    1406231, -- Ornate Visage Set
    1406232, -- Ironblood Sheriff Set
    1406233, -- Aureate Assassin Set
    1406234, -- Apocalyptic Brawler Set
    1406235, -- Steampunk Set
    1406236, -- Elfin Sheriff Set
    1406237, -- Rising Star Set
    1406238, -- Project Idol Set
    1406239, -- Neon Wave Set
    1406240, -- Holo Rave Set
    1406241, -- Megumi Fushiguro Cosplay Set
    1406242, -- Yuji Itadori Cosplay Set
    1406243, -- Nobara Kugisaki Cosplay Set
    1406244, -- Satoru Gojo Serious Mode Cosplay Set
    1406245, -- Aurous Elegance Set
    1406246, -- Aurous Star Set
    1406247, -- Untamed Magnate Set
    1406248, -- Bionic Surge Set
    1406249, -- Gilded Assassin Set
    1406250, -- Veiled Rogue Set
    1406251, -- No Way Home Tracksuit Set
    1406252, -- Scarecrow Minstrel Set
    1406253, -- Cactus Hazard Set
    1406254, -- Lakeside Serenity Set
    1406255, -- Underworld Guardian Set
    1406256, -- Veteran Agent Set
    1406257, -- Security Expert Set
    1406258, -- Ninja Dancer Set
    1406259, -- Desert Warrior Set
    1406260, -- Plated Guardian Set
    1406261, -- Goth Aviator Set
    1406262, -- Scarlet Ranger Set
    1406263, -- Tycoon Mogul Set
    1406264, -- Cactus Constable Set
    1406265, -- Executioner Set
    1406266, -- Scorpion Assassin Set
    1406267, -- Bronze Vessel Set
    1406268, -- Eastern Vagrant Set
    1406269, -- Amethyst Tech: Emilia
    1406270, -- First Love - Women's Collection
    1406271, -- First Love - Men's Collection
    1406273, -- Count Umbra Set
    1406274, -- Fluffy Sheep Set
    1406275, -- Cute Raccoon Set
    1406276, -- Energetic Bunny Set
    1406277, -- Cunning Fox Set
    1406278, -- Urban Hunter Set
    1406279, -- Snow Pixie Set
    1406280, -- Joyful Kitten Set
    1406281, -- Rabbit Plushie Set
    1406282, -- Miss Sunshine Set
    1406283, -- Rose Princess Set
    1406284, -- Tiger's Roar Set
    1406286, -- Major Grom Red Tracksuit
    1406287, -- Flora Mage Set
    1406288, -- Covert Ops Set
    1406289, -- CYCLE 2 Set
    1406290, -- C2S4 Set
    1406291, -- Satoru Gojo Cosplay Set
    1406292, -- Street Brawler Set
    1406293, -- Chroma Valkyrie Set
    1406294, -- Vivid Beast Set
    1406295, -- Bunny Friends Set
    1406296, -- Coyote Rider Set
    1406297, -- Riot Handler Set
    1406298, -- Badlands Punk Set
    1406299, -- Maverick Warlock Set
    1406300, -- Radiant Youth Set
    1406301, -- Festive Bash Set
    1406302, -- Elite Oni Set
    1406303, -- G.O.L.D 24K Set
    1406304, -- Cyber Agent Set
    1406305, -- Mystic Protector Set
    1406312, -- Alfheim Wonder Set
    1406313, -- Enigmatic Nomad Set
    1406314, -- Heart of Jade Set
    1406315, -- Eternal Guardian Set
    1406316, -- Mystic Artificer Set
    1406317, -- Roguish Imp Set
    1406318, -- Aurora Flash Set
    1406319, -- Nocturnal Rhapsody Set
    1406320, -- Maniacal Baron Set
    1406321, -- Plasma Chic Set
    1406322, -- Steadfast Guard Set
    1406323, -- Trendsetter Set
    1406324, -- Fashion Leader Set
    1406325, -- Street Stroller Set
    1406326, -- Street Fashion Set
    1406327, -- Wukong Prime
    1406328, -- Excalibur Umbra
    1406329, -- Fluorescent Flash Set
    1406330, -- Infernal Chef Set
    1406331, -- Sweet Supporter Set
    1406332, -- Pink Shelter Set
    1406333, -- Street Racer Set
    1406335, -- Hazard Set
    1406336, -- Kendo Master Set
    1406338, -- William Set
    1406339, -- Adorbs Baddie Set
    1406340, -- Sweet Cub Set
    1406341, -- Baby Dragon Set
    1406342, -- Baby Parrot Set
    1406343, -- Sawyer
    1406344, -- Roberta
    1406345, -- Revy
    1406346, -- Crimson Dancer Set
    1406348, -- Green Guardian Set
    1406349, -- Wise Monarch Set
    1406350, -- Stoic Bunny Set
    1406351, -- Fabled Defender Set
    1406352, -- Fearless Hero Set
    1406353, -- Space Traveler Set
    1406354, -- Suave Rebel Set
    1406355, -- Dauntless Leader Set
    1406356, -- Swole Hen Set
    1406357, -- Elegant Charm Set
    1406358, -- Honor & Glory Set
    1406359, -- Duty & Loyalty Set
    1406360, -- Violet Trooper Set
    1406361, -- Emerald Ranger Set
    1406362, -- C2S5 Set
    1406363, -- Peerless Conqueror Set
    1406364, -- Dawn Breeze Set
    1406365, -- Cobalt Shadow Set
    1406367, -- Underwraith Set
    1406368, -- Primordial Set
    1406369, -- Swagger Lion Set
    1406370, -- Trendy Samurai Set
    1406371, -- Cyberealm Detective Set
    1406372, -- Cyberealm Hacker Set
    1406373, -- Grim Bisector Set
    1406374, -- Frost Fire Set
    1406375, -- Draconic Cavalier Set
    1406376, -- Bandit Kitty Set
    1406377, -- Wasteland Explorer Set
    1406378, -- Nebula Dreamscape Set
    1406379, -- Disco Champ Set
    1406380, -- Hipster Rebel Set
    1406381, -- Extreme Armor Model EVA-08
    1406382, -- Extreme Armor Model EVA-02
    1406383, -- Extreme Armor Model EVA-00
    1406384, -- Extreme Armor Model EVA-01
    1406385, -- Evangelion Shinji Plugsuit
    1406386, -- Evangelion Rei Plugsuit
    1406387, -- Evangelion Asuka Plugsuit
    1406388, -- Evangelion Mari Plugsuit
    1406389, -- Evangelion Kaworu Plugsuit
    1406390, -- GB Teddy Bear Set
    1406391, -- Interstellar Chimera Set
    1406392, -- Floret Fairy Set
    1406393, -- Sacred Eminence Set
    1406394, -- Styx Sovereign Set
    1406395, -- Captain Woof Set
    1406396, -- Foxy Youth Set
    1406397, -- Ominous Fox Set
    1406398, -- Flamewraith Set
    1406399, -- Majestic Cavalry Set
    1406400, -- Shady Shark Set
    1406401, -- Shady Minion Set
    1406402, -- City Strut Set
    1406403, -- Festive Meow Set
    1406404, -- Green Wayfarer Set
    1406405, -- Purity Defender Set
    1406406, -- Elegant Finesse Set
    1406407, -- Ultimate Trendsetter Set
    1406408, -- High Elf Set
    1406409, -- Candle Alert Set
    1406410, -- Captain Happy Set
    1406411, -- Extreme Outlayer Set
    1406412, -- Armed Raider Set
    1406413, -- Mutant Warlord Set
    1406414, -- PMPL 2022 Spring Set
    1406415, -- Roseate Luster Set
    1406416, -- Stoic Grace Set
    1406417, -- Thunderblaze Set
    1406418, -- Venomous Onesie Set
    1406419, -- Cuddly Shark Set
    1406421, -- Cuddly Beaver Set
    1406422, -- Cheeky Cat Set
    1406423, -- Beach Sweetie Set
    1406424, -- Ultimate Dancer Set
    1406425, -- Jelly Bear Set
    1406426, -- Ursa Hunter Set
    1406427, -- Opulence Set
    1406428, -- Cute Mummy Set
    1406429, -- Beach Life Top
    1406430, -- Hobby Holiday Set
    1406431, -- Lovely Lotus Set
    1406432, -- Phoenix Adarna Set
    1406433, -- Agent Phoenix Set
    1406434, -- Gojek Driver Suit
    1406435, -- Mythirium Set
    1406436, -- Butterfinger Set
    1406437, -- Soldier Boy Super Suit Set
    1406438, -- Butcher's Duds Set
    1406439, -- Homelander Super Suit Set
    1406440, -- Starlight Super Suit Set
    1406441, -- Matcha Cone Set
    1406442, -- Adorable Sheep Set
    1406444, -- Royal Bard Set
    1406445, -- Prairie Hunter Set
    1406446, -- Glory Guard Set
    1406447, -- Junkrat Empire Set
    1406448, -- Conquest Nation Set
    1406449, -- Infinite Challenge Set
    1406450, -- C2S6 Set
    1406451, -- Shining Traveler Set
    1406452, -- X-Anima Set
    1406453, -- Funky Diver Set
    1406454, -- Aurelian Magnate Set
    1406455, -- Solar Oracle Set
    1406456, -- Fabled Hero Set
    1406457, -- Fatal Charm Set
    1406458, -- Mystic Genie Set
    1406459, -- Celestial Oracle Set
    1406460, -- Garden Fairy Set
    1406461, -- Ruthless Falconer Set
    1406462, -- Sylvan Shaman Set
    1406463, -- Desert Oracle Set
    1406464, -- Steampunk Herbalist Set
    1406465, -- Urbane Captain Set
    1406466, -- Bionic Sage Set
    1406467, -- Crimson Speedster Set
    1406468, -- Genesis Knight Set
    1406476, -- Netherbringer Set
    1406477, -- Eminent Seer Set
    1406478, -- Profane Templar Set
    1406479, -- Star Gazer Set
    1406480, -- Bubblegum Cyborg Set
    1406482, -- Bramble Overlord Set
    1406483, -- Lightning Nebula Set
    1406484, -- Sushi Fantasy Set
    1406485, -- Immortal Guardian Set
    1406486, -- Fluorescent Blossom Set
    1406487, -- Maritime Agent Set
    1406489, -- Patrician's Dream Set
    1406490, -- Noctum Terror Set
    1406491, -- Mecha Sanctum Set
    1406492, -- Trendy Hiker Set
    1406493, -- Royal Aurum Set
    1406494, -- Agent Fox Set
    1406495, -- Oasis Idol Set
    1406496, -- Nightfarer Set
    1406497, -- Football Star Set
    1406498, -- Mach Bunny Set
    1406499, -- Crocodile Overlord Set
    1406500, -- Merciless Jester Set
    1406501, -- Space Buddy Set
    1406502, -- Dimensional Butterfly Set
    1406503, -- Wintry Azure Set
    1406504, -- Cute Manta Ray Set
    1406505, -- Adorable Ghost Set
    1406506, -- Polar Fluff Set
    1406507, -- Divination Set
    1406508, -- Rain Froggy Set
    1406509, -- Beach Outing Set
    1406510, -- Swagmeister Set
    1406511, -- Noble Ruler Set
    1406512, -- Ocean Warrior Set
    1406513, -- Camel Rockstar Set
    1406514, -- Al Mazyunah Set
    1406515, -- Great Pioneer Set
    1406516, -- Lions of Mesopotamia Set
    1406517, -- Markhor Set
    1406518, -- Lahore Qalandars Team Uniform
    1406519, -- First Mate Set
    1406520, -- Tabasco Set
    1406521, -- Softserved Set
    1406522, -- Burrito Set
    1406523, -- Brave Commander Set
    1406524, -- Youth Set
    1406525, -- Plaid Poncho
    1406526, -- CyberGen: Zero Set
    1406527, -- Green Soldier Set
    1406528, -- Red Soldier Set
    1406529, -- Yellow Soldier Set
    1406530, -- Legendary Boxer Set
    1406531, -- Edgy Brawler Set
    1406532, -- CYCLE 3 Set
    1406533, -- C3S7 Set
    1406543, -- Violet Vengeance Set
    1406544, -- Phantom Agent Set
    1406545, -- Cyber Sprite Set
    1406546, -- Leopard Spot Set
    1406547, -- Cupcake Cutie Set
    1406548, -- Cake Demon Set
    1406549, -- Rhythm Junkie Set
    1406550, -- Flamingo Set
    1406551, -- Frost Enforcer Set
    1406553, -- General Nutcracker Set
    1406554, -- Exalted Serenity Set
    1406555, -- Nether Visage Set
    1406556, -- Spectral Ranger Set
    1406557, -- HO YEON Operation Erangel Set
    1406558, -- 2022 PMWI Special Set
    1406559, -- Clockwork Illusionist Set
    1406560, -- Cyber Singer Set
    1406561, -- Doom Guardian Set
    1406562, -- Python Warrior Set
    1406563, -- Mutant Squid Set
    1406564, -- Midnight Shadow Set
    1406565, -- Eagle Eye Tech Set: Sophia
    1406566, -- Survival Master Set: Riley
    1406567, -- Nebulous Conqueror Set
    1406568, -- Abyssal Judge Set
    1406569, -- Underworld Adjudicator Set
    1406570, -- Tide Commander Set
    1406571, -- Crimson Templar Set
    1406572, -- Tribal Hero Set
    1406573, -- Spectral Swan Set
    1406574, -- Cosmic Inquisitor Set
    1406575, -- Fjord Warrior Set
    1406576, -- Ceremonial Rose Set
    1406577, -- Space Idol Set
    1406578, -- Scarlet Shadow Set
    1406579, -- Desert Taskforce Set
    1406580, -- Midas Fortune Set
    1406581, -- Clairvoyant Fox Set
    1406582, -- Groovy Peck Set
    1406583, -- Masked Crusader Set
    1406584, -- Hip Hop Scarecrow Set
    1406585, -- DJ Dancer Set
    1406586, -- Butterfly Fighter Set
    1406587, -- Martial Master Set
    1406589, -- Astro Cadet Set
    1406590, -- Chromakey Comedian Set
    1406591, -- Teddy Mascot Set
    1406592, -- Greedy Bunny Set
    1406593, -- Enigmatic Fox Set
    1406594, -- Enigmatic Fox Cover
    1406595, -- Arctic Fox Set
    1406596, -- Crafty Bunny Set
    1406597, -- Dino Mama Set
    1406598, -- Skull Bunny Set
    1406599, -- Beary Cute Set
    1406600, -- Floral Fresh Set
    1406601, -- Forest Fruits Set
    1406602, -- Eventide Butterfly Set
    1406603, -- Jade Sultan Set
    1406604, -- Jade General Set
    1406605, -- Jade Princess Set
    1406606, -- Shalwar Kameez Set
    1406607, -- Passionate Cactus Set
    1406608, -- Dino Trooper Set
    1406609, -- Crimson Claw Set
    1406610, -- White Grace Set
    1406611, -- 4EVE T-POP Idol Set
    1406612, -- 4EVE Bubbly Bomb Set
    1406613, -- Dazzling Dance Set
    1406614, -- Mysterious Magician Set
    1406615, -- C3S8 Set
    1406616, -- Phantom of Erangel Set
    1406617, -- Crimson Templar Cover
    1406618, -- PMPS 2022 Set
    1406619, -- BGMI Esports Set
    1406620, -- PMJL SEASON3 Set
    1406626, -- Astral Arcanist Set
    1406627, -- Twilight Warden Set
    1406628, -- Cursed Heir Set
    1406629, -- Imperial Enforcer Set
    1406630, -- Martial Warlord Set
    1406631, -- Fiery Rhythm Set
    1406632, -- Cybernetic Trance Set
    1406633, -- Visionary Clairvoyant Set
    1406634, -- Silverwing Conjurer Set
    1406635, -- Divine Seer Set
    1406636, -- Royal Magician Set
    1406637, -- 2022 PMGC Special Set
    1406644, -- Illustrious Archon Set
    1406645, -- Scarlet Magus Set
    1406646, -- Master Tactician Set: Laith
    1406647, -- Seasoned Veteran Set: Lorenzo
    1406648, -- Messi Football Icon Set
    1406649, -- Messi Super Legend Set
    1406650, -- Messi Collaboration Set
    1406651, -- Mountain Ancestry Set
    1406652, -- Glacial Heredity Set
    1406653, -- Carmine Tribesperson Set
    1406654, -- Conquering Soul Set
    1406655, -- Darling Rampage Set
    1406656, -- Bloody Noon Set
    1406657, -- Starsea Admiral Set
    1406658, -- Tribal Hipster Set
    1406659, -- Bio Agent Set
    1406660, -- Deadly Dazzle Set
    1406661, -- Punk Goon Set
    1406662, -- Hazmat Vanguard Set
    1406663, -- Monochrome Radiance Set
    1406664, -- Lavish Pageantry Set
    1406666, -- Frore Warden Set
    1406667, -- Sanguine Nightmare Set
    1406668, -- Imperial Ball Set
    1406669, -- Pixelated Monster Set
    1406670, -- Luxury Gala Set
    1406671, -- Lifestyle Armor Set
    1406672, -- Merry Snowman Set
    1406673, -- Sweet Bunny Set
    1406674, -- Youthful Charm Set
    1406675, -- Lethal Code Set
    1406676, -- Stern Kitty Set
    1406677, -- Gackt Moon
    1406678, -- Bengal Tiger Set
    1406679, -- Remote Excursion Set
    1406680, -- Prestigious Noble Set
    1406681, -- Sun Warrior Set
    1406682, -- Sun Warrior Princess Set
    1406683, -- Saudi Football Team Set
    1406684, -- Test Cricket Kit - Classic
    1406685, -- T20 Cricket Kit - Classic
    1406686, -- Falcon Athlete Set
    1406687, -- Yak Warrior Set
    1406688, -- Icy Slayer Set
    1406689, -- AFA Set
    1406690, -- Football Royale Set
    1406691, -- Viet Indie Prince Astronaut Set
    1406692, -- Indomie Warrior Robot Set
    1406693, -- Spring Spirit Set
    1406694, -- Will to Win Set
    1406695, -- Peculiar Magician Set
    1406696, -- C3S9 Set
    1406697, -- Legendary Left Striker Set
    1406698, -- Legendary Right Winger Set
    1406699, -- Legendary Left Winger Set
    1406700, -- Legendary Right Defensive Midfielder Set
    1406701, -- Legendary Right Back Set
    1406702, -- Legendary Right Striker Set
    1406703, -- Legendary Left Defensive Midfielder Set
    1406704, -- Legendary Left Back Set
    1406705, -- Legendary Left Midfielder Set
    1406706, -- Legendary Goalkeeper Set
    1406707, -- Legendary Right Midfielder Set
    1406708, -- Tribal Champion Set
    1406709, -- Hazard Medic Set
    1406710, -- Palace Musician Set
    1406719, -- Aurulent Antlers Set
    1406720, -- Foxy Charmer Set
    1406721, -- Gilded Idol Set
    1406722, -- Bunny Dancer Set
    1406723, -- Cutie Cream Set
    1406724, -- Bushido Grace Set
    1406725, -- Vivid Star Set
    1406726, -- Warrior Techwear Set
    1406727, -- Prism Dancer Set
    1406728, -- Bruce Lee Kung Fu Soul Set
    1406729, -- Bruce Lee Melee Expert Set
    1406730, -- Bruce Lee Dragon's Roar Set
    1406731, -- Bruce Lee Mr. Kung Fu Set
    1406732, -- Solar Empress Set
    1406733, -- Solar Emperor Set
    1406734, -- Seafoam Assassin Set
    1406735, -- Battle Puppet Set
    1406736, -- Blazetech Patrol Set
    1406737, -- Symphonic Solace Set
    1406738, -- Mystic Veteran Set
    1406739, -- Ascendant Agent Set
    1406740, -- Cherry Fox Set
    1406741, -- Cheeky Teddy Set
    1406742, -- Silver Guru Set
    1406744, -- Solar Knight Set
    1406745, -- Vile Invader Set
    1406746, -- Elite Commando Set
    1406747, -- Fistfight Maiden Set
    1406748, -- Agile Charmer Set
    1406749, -- Underworld Outlaw Set
    1406751, -- Venerable Assassin Set
    1406752, -- Royal Guard Set
    1406753, -- Martial Champion Set
    1406754, -- Mythical Monkey Set
    1406755, -- Bunny Uniform Set
    1406756, -- Fishing Master Set
    1406757, -- Blitz Tackle Set
    1406758, -- Cactus Sheriff Set
    1406759, -- Cuddly Bear Set
    1406760, -- Hamster Hoarder Set
    1406761, -- Draco Rascal Set
    1406762, -- Fennec Fox Set
    1406763, -- Wonderful Bunny Set
    1406764, -- Crimson Charm Set
    1406765, -- Floral Snowflake Set
    1406766, -- Snowpaw Set
    1406767, -- Red Tuxedo Set
    1406768, -- Ruby Set
    1406769, -- Fyonka Set
    1406770, -- Mithu Tota Set
    1406771, -- Maxi Set
    1406772, -- Sherwani Set
    1406773, -- Shock Cyberarmor Set
    1406774, -- Fighting Master Set
    1406776, -- Sweet Dreams Set
    1406777, -- Eternal Love Set
    1406778, -- Frost Queen Set
    1406779, -- Crimson Academia Set (Male)
    1406780, -- Crimson Academia Set (Female)
    1406781, -- Rabbit Sprite Set
    1406782, -- Elemental Burst Set
    1406783, -- Shadow Reign Set
    1406784, -- Azure Defender Set
    1406785, -- Monkey Vanguard Set
    1406786, -- CYCLE 4 Set
    1406787, -- Falcon Cast Set
    1406788, -- C4S10 Set
    1406789, -- Nether Phantom Set
    1406790, -- Bruce Lee Legendary Battlegarb Set
    1406791, -- Dragonflame Berserker Set
    1406792, -- Football Fever Set
    1406793, -- Scarlet Phantom Set
    1406794, -- Shark Knight Set
    1406795, -- Trendy Bunny Set
    1406796, -- Pink Sweetie Set
    1406797, -- Neon Rave Set
    1406798, -- Monochrome Radiance Set (7-Day)
    1406799, -- Lavish Pageantry Set (7-Day)
    1406800, -- Royal Admiral Set
    1406801, -- Mirage Executive Set
    1406802, -- Cyber Phantom Set
    1406803, -- Battle Warden Set
    1406804, -- Veiled Princess Set
    1406805, -- Windcrest Soul Set
    1406806, -- New Potential Set
    1406807, -- Gilded Bone Set
    1406808, -- Gemstone Noble Set
    1406809, -- Sly Bunny Set
    1406816, -- Mystic Sorceress Set
    1406817, -- Sacred Maiden Set
    1406818, -- Resplendent Prince Set
    1406819, -- Crescent Princess Set
    1406820, -- Cucumber Genius Set
    1406821, -- Nightingale Dancer Set
    1406822, -- Falcon Warrior Set
    1406823, -- Moondrop Eterna Set
    1406824, -- Bloodstained Nemesis Set
    1406825, -- Slime Warrior Set
    1406826, -- Wondrous Magician Set
    1406827, -- Blood Rose Set
    1406828, -- Vogue Dancer Set
    1406829, -- Violet Buccaneer Set
    1406830, -- Dark Reign Set
    1406831, -- Solar Lineage Set
    1406832, -- Grand Heist Set
    1406833, -- Aureate Splendor Set
    1406834, -- Rogue Kitty Set
    1406835, -- Secret Fashion Set
    1406836, -- Night Roamer Set
    1406837, -- Suave Buccaneer Set
    1406838, -- Flora Butterfly Set
    1406839, -- Techno Sensation Set
    1406840, -- Polar Penguin Set
    1406841, -- Munching Hippo Set
    1406842, -- Bling Cat Set
    1406843, -- Cuddly Lion Set
    1406844, -- Rising Rebel Set
    1406845, -- Bunny Lover Set
    1406846, -- Belle of Palace Set
    1406847, -- Gold King Set
    1406848, -- Saltooh Set
    1406849, -- Miss Fitna Set
    1406850, -- Donkey Raja Set
    1406851, -- Tidal Soldier Set
    1406852, -- Angus Cloud What's Next Set
    1406853, -- Origin Flame Set
    1406854, -- Wings of Fury Set
    1406855, -- Wild Wolf Set
    1406856, -- Dark Bunny Set
    1406857, -- Neon Force Set
    1406858, -- M56 FL V1A-PBU Set
    1406859, -- Nasi Lemak Set
    1406860, -- Floppy Bird Set
    1406862, -- Kitty Dancer Set
    1406863, -- Butterfly Wayfarer Set
    1406864, -- C4S11 Set
    1406865, -- Streetwise Chaser Set
    1406866, -- Acrobatic Bear Set
    1406867, -- Circus Star Set
    1406868, -- Bunny Academy Mascot Set
    1406869, -- Thriller Doll Set
    1406870, -- Bunny Academy Sailor Suit
    1406871, -- Rose Conjurer Set
    1406873, -- Shackled Horns Set
    1406874, -- Dracolith Assassin Set
    1406875, -- Frostbolt Agent Set
    1406876, -- Boom Squad Set
    1406877, -- Dracoguard Set
    1406878, -- Umbral Starfall Set
    1406879, -- Radiant Dawnstar Set
    1406880, -- Shamate Rex Set
    1406881, -- Golden Reaper Set
    1406882, -- Golden Blessing Set (Female)
    1406883, -- Golden Blessing Set (Male)
    1406884, -- Exo Fossil Set
    1406885, -- Draconic Empress Set
    1406886, -- Karol G GATÚBELA Set
    1406887, -- Karol G BICHOTA Set
    1406888, -- Mr. Tooth Set
    1406889, -- Horned Kingpin Set
    1406890, -- Ruby Trickster Set
    1406891, -- Psychophage Set
    1406892, -- Dimwalker Set
    1406893, -- Odd Bunny Set
    1406894, -- Kappa Hoodie Set
    1406895, -- Dino Rider Set
    1406896, -- Dino Dream Set
    1406897, -- Crimson Ephialtes Set
    1406898, -- Noctum Sunder Set
    1406899, -- Night Vixen Set
    1406916, -- Dusk Vigilante Set
    1406917, -- Dawn Vigilante Set
    1406918, -- Golden Paw Set
    1406919, -- Creamtail Set
    1406920, -- Furry Beats Set
    1406921, -- Punk Bones Set
    1406922, -- Dazzling Dancer Set
    1406923, -- Star Maestro Set
    1406924, -- Day Out Set
    1406925, -- Cuddly Seahorse Set
    1406926, -- Dino Paradise Alex Set
    1406927, -- Dino Paradise Mascot Set
    1406928, -- Potato Man Set
    1406929, -- Kebab Skewer Set
    1406930, -- Light of Glory Set
    1406931, -- Valuable Customer Set
    1406932, -- Nocturnal Slayer Set
    1406933, -- Tenacious Gladiator Set
    1406934, -- C4S12 Set
    1406935, -- Pristine Warrior Set
    1406937, -- Super Saiyan Son Goku Character Set
    1406938, -- Frieza Character Set
    1406939, -- Son Goku Character Set
    1406940, -- DJ Vibe Set
    1406941, -- Tealara Maiden Set
    1406942, -- Amplifire Set
    1406943, -- Forest Whisper Set
    1406944, -- Starlit Diva Set
    1406945, -- Summer Surf Set
    1406946, -- Deep Dive Set
    1406947, -- Vegeta Character Set
    1406948, -- Super Saiyan Vegeta Character Set
    1406949, -- Frieza Style Set
    1406950, -- Beerus Style Set
    1406951, -- Majin Buu Style Set
    1406952, -- Kamesennin Style Set
    1406953, -- Ultimate Gohan Character Set
    1406954, -- Piccolo Character Set
    1406955, -- Anubis Haute Couture Set
    1406956, -- Emberfox Set
    1406957, -- Neon Vixen Set
    1406958, -- Ladybug Lover Set
    1406959, -- Shadow Squad Assault Set
    1406960, -- Shadow Squad Medic Set
    1406961, -- Shadow Squad Sharpshooter Set
    1406962, -- Shadow Squad MachineGunner Set
    1406963, -- Great White Virtuoso Set
    1406964, -- Cerulean Slayer Set
    1406972, -- Fashionista Ink Set
    1406973, -- Molluscan Waverider Set
    1406974, -- Icy Bliss Set
    1406975, -- Gulping Gull Set
    1406976, -- Dandy Groovster Set
    1406977, -- Wrathful Neptune Set
    1406978, -- Roving Voyager Set
    1406979, -- Mad Drifter Set
    1406980, -- Bubblegum Shark Set
    1406981, -- Aurelian Dragon Set
    1406982, -- Teddy Belle Set
    1406983, -- Serene Rapture Set (Lv. 1)
    1406984, -- Vogue Surfer Set
    1406985, -- Surfside Sweetheart Set
    1406986, -- Battle Crescendo Set
    1406987, -- Tranquil Faith Set
    1406988, -- Tech Gunslinger Set
    1406989, -- Bunny Munchkin Set
    1406990, -- Playful Prankster Set
    1406991, -- Weepy Mouse Set
    1406992, -- Preppy Mouse Set
    1406993, -- Boxy Battlegrounder Set
    1406994, -- Rave Luminary Set
    1406995, -- Poolside Getaway Set
    1406996, -- Beachside Getaway Set
    1406997, -- Ripple Strider Set
    1406998, -- UNIVERSTAR BT21 Set
    1406999, -- Cool Husky Set
    1407000, -- Tri-Color Swimsuit Set
    1407001, -- Summer Swimsuit Set (Black)
    1407002, -- Summer Swimsuit Set (Leopard Print)
    1407003, -- Space Bunny Set
    1407004, -- Gentlebear Set
    1407005, -- Garuda Series Hunter Set
    1407006, -- Centennial Celebration Set
    1407007, -- Centennial Celebration Male Guard Set
    1407008, -- Centennial Celebration Female Guard Set
    1407009, -- Rose Royal Set
    1407010, -- Trendy Power Set
    1407011, -- Hip Hop Trendy Set
    1407012, -- Honor Guard Set
    1407013, -- PMSL Dream Chaser Set
    1407014, -- 2023 PMWI Special Set
    1407015, -- Battleground Assassin Set
    1407016, -- Charming Cook Set
    1407021, -- Super Saiyan Son Goku Character Finish(1DAY)
    1407022, -- Son Goku Character Finish(1DAY)
    1407023, -- Vegeta Character Finish(1DAY)
    1407024, -- Super Saiyan Vegeta Character Finish(1DAY)
    1407025, -- Piccolo Character Set(1DAY)
    1407026, -- Ultimate Gohan Character Set(1DAY)
    1407027, -- Frieza Character Set(1DAY)
    1407028, -- Butterflame Set
    1407029, -- Cruel Torment Set
    1407030, -- Tricky Witch Set
    1407031, -- KFC Royale Colonel Set
    1407032, -- KFC Chicken Champ Set
    1407033, -- Carnival Celebration Top
    1407035, -- Red Eagle Prince Set
    1407036, -- Light Feather Princess Set
    1407037, -- Bone Survivor Set
    1407038, -- Suave Master Set
    1407039, -- Ducky Slasher Set
    1407040, -- Ducky Archer Set
    1407041, -- Sakura Samurai Set
    1407042, -- Roseate Moonling Set
    1407043, -- Venust Evenfall Set
    1407044, -- Madame Carmine Set
    1407045, -- Ironthorn Anubis Set
    1407046, -- Cursed Scarecrow Set
    1407047, -- Hacker Bunny Set
    1407048, -- Boxerbolt Set
    1407049, -- Glacial Bride Set
    1407050, -- Colorburst Set
    1407051, -- Ducky Fighter Set
    1407052, -- Ducky Fraud Set
    1407056, -- Nitro Maniac Set
    1407057, -- Gutsy Lass Set
    1407059, -- Flame Warrior Set
    1407060, -- Royal Ironguard Set
    1407061, -- Seadrake Champion Set
    1407062, -- Citrus Bodysuit Set
    1407063, -- Sweet Pumpkin Set
    1407064, -- Dark Kitten Set
    1407065, -- Owlicious Set
    1407066, -- Batblitz Set
    1407067, -- Maple Master Set
    1407068, -- Sleepy Bunny Set
    1407069, -- Sleepless Cat Set
    1407070, -- Lady Nocturne Set
    1407071, -- Chaosbound Shackles Set
    1407072, -- Skeletal Chevalier Set
    1407073, -- Globe Gudi Squad Set
    1407074, -- Blossom Belle Set
    1407075, -- Grungehead Set
    1407076, -- Deific Hunter Set
    1407077, -- C5S14 Set
    1407078, -- The Magician's Arcane Set
    1407079, -- The Fool's Delight Set
    1407080, -- Fortune's Keeper Set
    1407081, -- No.33 White Cricket Set
    1407082, -- No.33 Blue Cricket Set
    1407083, -- Pastel Puff Set
    1407084, -- Cyber Icon Set
    1407085, -- Dream Striker Set
    1407086, -- Silent Agent Set
    1407087, -- Specter Soldier Set
    1407088, -- Sweet Horns Set
    1407089, -- Winged Legend Set
    1407090, -- Gold Investigator Set
    1407091, -- 2023 PMGC One Shot Set
    1407092, -- 2023 PMGC Gold Champ Set
    1407093, -- Frigid Beast Set
    1407094, -- Midnight Muse Set
    1407095, -- Shadowfire Captain Set
    1407096, -- Dawning Surge Set
    1407104, -- Spirited Maiden Set
    1407105, -- Fiestabelle Set
    1407106, -- Foxy Flare Set
    1407107, -- Winter Highness Set
    1407112, -- Cryptic Hunter Set
    1407113, -- Beary Fluffy Set
    1407114, -- Biowave Trekker Set
    1407115, -- Meowful Time Set
    1407116, -- Avian Charmer Set
    1407117, -- Winged Critter Set
    1407118, -- Festive Feline Set
    1407119, -- Merry Pawsome Set
    1407120, -- Furs 'n' Spots Set
    1407121, -- Mousetech Set
    1407122, -- Pinky Axolotl Set
    1407123, -- Ebil Bunny Set
    1407124, -- Fluffy Alpaca Set
    1407125, -- RS Dark Stealth
    1407126, -- Regal RS
    1407127, -- Royal Baba
    1407128, -- Swaggy Baba
    1407129, -- Polar Bear Set
    1407130, -- Merry Darkness Set
    1407131, -- Lurik Nusantara Set
    1407132, -- Mechamato Set
    1407133, -- Klava Koka Set
    1407134, -- Maula Jatt Set
    1407135, -- Pearly White Set
    1407136, -- Vivid Voyager Set
    1407137, -- Battleground Gladiator Set
    1407138, -- C5S15 Set
    1407139, -- Pagani Driver Top
    1407143, -- Panda Sweetie Set
    1407144, -- Dracostride Set
    1407145, -- Lion Reign Set
    1407146, -- Mystic Maroon Set
    1407147, -- Beary Bouquet Set
    1407148, -- Oasis Charm Set
    1407149, -- Ninja Mouse Set
    1407150, -- LINE FRIENDS CHOCO Dress Set
    1407151, -- LINE FRIENDS LEONARD Raincoat Set
    1407152, -- Dragon Emperor Set
    1407153, -- Dragon Empress Set
    1407154, -- Rosy Riding Hood Set
    1407155, -- Inferno Valkyrie Set
    1407156, -- LINE FRIENDS Dragon BROWN Set
    1407157, -- LINE FRIENDS Dragon CONY Set
    1407158, -- Inkstripe Tiger Set
    1407159, -- Mansion Maiden Set
    1407160, -- Shinobi Spirit Set
    1407161, -- Serpengleam Set
    1407162, -- Sonic Wave Set
    1407166, -- Cyberfighter Set
    1407167, -- Fatal Fox Set
    1407168, -- Cyborg Avenger Set
    1407169, -- Cheeky Romance Set
    1407170, -- Blue Fluff Set
    1407171, -- Pink Fluff Set
    1407172, -- Vibrant Bride Set
    1407173, -- Chic Owl Set
    1407174, -- Violet Diva Set
    1407175, -- Dreamy Lass Set
    1407176, -- Snowflake Fox Set
    1407177, -- Sakura Fox Set
    1407178, -- Fierce Beastie Set
    1407179, -- Clumsy Beastie Set
    1407180, -- Stylish Beastie Set
    1407181, -- Zanmang Loopy Set
    1407182, -- Seam Outfit
    1407183, -- Hardik Blitz Set
    1407184, -- Livik Huskies Set
    1407185, -- Pusat Set
    1407186, -- Kurapika Character Set
    1407187, -- Killua Character Set
    1407188, -- Gon Character Set
    1407189, -- Leorio Character Set
    1407190, -- Extreme Cyberwear Set
    1407191, -- Melee Maiden Set
    1407192, -- CYCLE 6 Set
    1407193, -- C6S16 Set
    1407197, -- Flower Maestro Set
    1407198, -- Phantom Luster Set
    1407199, -- Striped Sweetheart Set
    1407200, -- Theater Tycoon Set
    1407201, -- Auric Guardian Set
    1407202, -- Royal Rogue Set
    1407203, -- Groove Socialite Set
    1407204, -- Prim Prestige Set
    1407205, -- Tech Striker Set
    1407206, -- SPY×FAMILY Twilight Set
    1407208, -- Seraphic Princess Set
    1407209, -- Seraphic Genie Set
    1407210, -- Gilded Wings Set
    1407211, -- Chic Boxhead Set
    1407212, -- Patched Puppet Set
    1407220, -- Suave Royal Set
    1407221, -- Feline Fighter Set
    1407222, -- Magick Delight Set
    1407223, -- Gallant Jockey Set
    1407224, -- Origin Lumen Set
    1407225, -- Luminous Muse Set
    1407226, -- Forest Hunter Set
    1407230, -- Dread Doc Set
    1407231, -- Skyreign Set
    1407232, -- Limit Breaker Set
    1407233, -- Manor Mage Set
    1407234, -- Vogue Vigor Set
    1407235, -- Bunny Dessert Set
    1407236, -- Punk Pink Set
    1407237, -- Ethereal Flutter Set
    1407238, -- Bunny Beauty Set
    1407240, -- City Casual Set
    1407241, -- Chillax Set
    1407242, -- Mech Hero Set
    1407244, -- Yoga Bunny Set
    1407245, -- Tira the Power of 9 Dragons Set
    1407246, -- Horsem4n Set
    1407247, -- Bunny Pilot Set
    1407248, -- Celestial Sentinel Set
    1407249, -- Phantom Streetwear Set
    1407250, -- Silent Stalker Set
    1407251, -- Elite Assassin Set
    1407252, -- C6S17 Set
    1407261, -- Melodic Feline Set
    1407262, -- Squeakology Set
    1407263, -- Wasteland Samurai Set
    1407264, -- Vegito Character Set
    1407265, -- Super Saiyan Vegito Character Set
    1407266, -- Super Saiyan Blue Vegito Character Set
    1407267, -- Super Saiyan Blue Son Goku Character Set
    1407268, -- Super Saiyan Blue Son Goku (Damaged) Character Set
    1407269, -- Super Saiyan Blue Vegeta Character Set
    1407270, -- Super Saiyan Blue Vegeta (Damaged) Character Set
    1407271, -- Bulma Character Set
    1407272, -- Future Trunks Style Set
    1407273, -- Mai Style Set
    1407274, -- Shrine Keeper Set
    1407275, -- Temperance's Virtue Set
    1407276, -- The Lover's Grace Set
    1407277, -- Inferno Fiend Set
    1407278, -- Myriam Fares Festival Set
    1407279, -- Myriam Fares Warrior Set
    1407280, -- Iron Warden Set
    1407281, -- Lambling Set
    1407282, -- Mewsie Set
    1407283, -- Rebel Ox Set
    1407284, -- Dr. Quirk Set
    1407286, -- Devious Cybercat Set
    1407287, -- Bard's Journey Set
    1407291, -- Graceful Watcher Set
    1407292, -- Bio Scout Set
    1407293, -- Virtual Pilgrim Set
    1407294, -- Techwalker Set
    1407295, -- Verdant Fairy Set
    1407296, -- Darling Hedgehog Set
    1407297, -- Peepkin Set
    1407298, -- Regal Fox Set
    1407299, -- Enchanting Succubus Set
    1407300, -- Alluring Angel Set
    1407301, -- Royal Heir Set
    1407302, -- Sunfire Archon Set
    1407303, -- Mech Surge Cowgirl Set
    1407304, -- Vibrant Gaze Set
    1407305, -- GOAT's Nemesis Set
    1407306, -- Innovative Artisan Set
    1407307, -- Dark Arts Gentleman Set
    1407308, -- Elven Tracker Set
    1407309, -- Pop Sensation Set
    1407310, -- C6S18 Set
    1407311, -- Shadow Empress Set
    1407312, -- Night Maiden Set
    1407313, -- Lieutenant Chaos Set
    1407314, -- Pyrosoul Renegade Set
    1407315, -- Sting Queen Set
    1407316, -- Bloodmoon Assassin Set
    1407317, -- Swiftfoot Phantom Set
    1407318, -- Fallen Spirit Set
    1407319, -- Eternal Champion Set
    1407320, -- Violet Thunder Set
    1407321, -- Rahma Riad Set
    1407322, -- Imperial Patriarch Set
    1407323, -- Imperial Matriarch Set
    1407324, -- Illumispark Set
    1407325, -- Deep Sea Admiral Set
    1407326, -- Deep Sea Princess Set
    1407327, -- White Wave Operation Set
    1407328, -- Rippling Charm Set
    1407329, -- Serene Lumina Set
    1407330, -- Spectral Admiral Set
    1407331, -- Vital Source Set
    1407335, -- Wave Whisperer Set
    1407336, -- Sea Critter Set
    1407337, -- Shark Tech Set
    1407338, -- Fluorescent Raider Set
    1407339, -- APEACH Set
    1407340, -- CHOONSIK Set
    1407341, -- RYAN School Uniform Set
    1407342, -- Bellygom Classic Set
    1407343, -- Bellygom Snug Bowl Set
    1407344, -- Bhaala Yodha Set
    1407345, -- Speedster Jav Set
    1407346, -- PUBGM X NewJeans MINJI Set
    1407347, -- PUBGM X NewJeans HANNI Set
    1407348, -- PUBGM X NewJeans HAERIN Set
    1407349, -- PUBGM X NewJeans DANIELLE Set
    1407350, -- PUBGM X NewJeans HYEIN Set
    1407351, -- Festivity Set
    1407352, -- Imperial Guard Set
    1407353, -- Turf Conqueror Set
    1407354, -- Private Aviator Set
    1407355, -- Silver Veteran Set
    1407356, -- Speedwolf Set
    1407357, -- Style Pioneer Set
    1407358, -- CYCLE 7 Set
    1407359, -- C7S19 Set
    1407374, -- MUZI Set
    1407375, -- Manic Bunny Set
    1407376, -- Chaos Academy Set
    1407377, -- Heart Warden Set
    1407378, -- Jin Kazama Character Set
    1407379, -- Kazuya Mishima Character Set
    1407380, -- Nina Williams Character Set
    1407381, -- Restless Pocong Set
    1407382, -- Midnight Assassin Set
    1407383, -- Silvermoon Agent Set
    1407384, -- Paranormal Feline Set
    1407385, -- Draco Disciple Set
    1407386, -- Flamestrider Set
    1407387, -- The Reaper's End Set
    1407388, -- Judgment's Ruling Set
    1407389, -- Strength's Domination Set
    1407390, -- Cosmic Beast Set
    1407391, -- Vampyra Countess Set
    1407392, -- Feral Ravager Set
    1407393, -- Untamed Jester Set
    1407397, -- Festering Gravewalker Set
    1407398, -- Lethal Lady Set
    1407399, -- Underworld Aristocrat Set
    1407400, -- Spell Stalker Set
    1407401, -- C.C. Set
    1407402, -- Kallen Kozuki Set
    1407404, -- Suzaku Kururugi Set
    1407405, -- ZERO Set
    1407406, -- Order of the Black Knights Set
    1407407, -- Jeremiah Gottwald Set
    1407408, -- Emperor Lelouch Set
    1407409, -- Floral Descent Set
    1407410, -- DP Ice Queen Guardian Set
    1407412, -- DP Techno Fairy Punk Set
    1407413, -- 9S Set
    1407414, -- NieR Set
    1407415, -- 2B Set
    1407416, -- Kaine Set
    1407417, -- Serial Pumpkin Set
    1407418, -- Scarlet Steel Set
    1407419, -- Noir Feline Set
    1407420, -- Breakthrough Civilization Set
    1407421, -- Rubiz Lasuly Set
    1407422, -- Esports Passion Set
    1407423, -- C7S20 Set
    1407426, -- Quasar Clan Set
    1407427, -- Winter Warrior Set
    1407428, -- Hypernova Fission Set
    1407429, -- Frosty Voyager Set
    1407430, -- Vetr Champion Set
    1407431, -- Skadiwynn Sentinel Set
    1407432, -- Royal Deeress Set
    1407433, -- Mecha Dawn Set
    1407434, -- Cyberbeat Kitty Set
    1407435, -- NeoViolet Fighter Set
    1407436, -- McLaren Formula 1 Team Race Suit
    1407437, -- Midnight Raven Set
    1407438, -- Midnight Enigma Set
    1407439, -- Penguin Pal Set
    1407440, -- Arctic Conqueror Set
    1407441, -- Snowstar Sweetheart Set
    1407442, -- Arcane Mechanist Set
    1407446, -- Glacial Mirage Set
    1407447, -- Polar Huntress Set
    1407448, -- Night Phantasma Set
    1407449, -- Polar Guardian Set
    1407450, -- Demon Lord Rimuru Set
    1407451, -- Rimuru Set
    1407452, -- Mystic Prism Princess Set
    1407453, -- Cloaked Voyager Set
    1407454, -- Rakhim Set
    1407455, -- Nomad Warrior Set
    1407456, -- Krampus Set
    1407457, -- Talon Warrior Set
    1407458, -- C7S21 Set
    1407460, -- Scarlet Grace Set
    1407461, -- New Age Channeler Set
    1407462, -- Dragontide Pulse Set
    1407463, -- Empyrean Mystique Set
    1407464, -- Empyrean Exemplar Set
    1407465, -- Brightfeather Prince Set
    1407466, -- Spicy 'n' Snazzy Set
    1407467, -- Luxe 'n' Loud Set
    1407468, -- Chill Flow Set
    1407469, -- Dreamweaver Set
    1407470, -- Untamed Celestial Set
    1407471, -- Jadefang Aurora Set
    1407472, -- Punkpop Fanatic Set
    1407476, -- Midnight Revenant Set
    1407477, -- Agent Rose Set
    1407478, -- Elysian Bloom Set
    1407479, -- Nightfall Blossom Set
    1407480, -- Neon Rebel Set
    1407481, -- Opanchu Set
    1407482, -- Chrono Charge Suit
    1407483, -- Quantum Flux Suit
    1407486, -- Elegant Nightwear Set
    1407487, -- Emerald Soldier Set
    1407488, -- Gridiron Gladiator Set
    1407489, -- Frosty Glampunk Set
    1407490, -- Flora Queen Set
    1407491, -- Little Citizen Set
    1407492, -- Panda Warrior Set
    1407493, -- Rosy Sweetie Set
    1407494, -- CYCLE 8 Set
    1407495, -- C8S22 Set
    1407496, -- Camel Super Fan Set
    1407497, -- Netherbound Rider Set
    1407498, -- Ecliptic Guardian Set
    1407499, -- Madcap Anima Set
    1407500, -- Light Cascade Set
    1407501, -- Moonlit Radiance Set
    1407502, -- Neon Renegade Set
    1407503, -- Crimson Cadence Set
    1407504, -- Feline Enigma Set
    1407505, -- Anarchy Medley Set
    1407513, -- Burning Godzilla Urban Set
    1407514, -- Godzilla Urban Set
    1407515, -- King Ghidorah Urban Set
    1407516, -- Godzilla Costume
    1407517, -- Burning Godzilla Costume
    1407518, -- Foxie Moxie Set
    1407519, -- Lumara Grace Set
    1407520, -- Starion Defender Set
    1407521, -- Stepstar Flair Set
    1407522, -- Sandsylph Scion Set
    1407523, -- Malus Majesty Set
    1407524, -- Palette Pulse Set
    1407528, -- Miss Marionette Set
    1407529, -- Orangepop Idol Set
    1407530, -- Goldensands Noble Set
    1407531, -- Goldensands Priestess Set
    1407532, -- Revolt Rabbit Set
    1407533, -- Frieren Set
    1407534, -- Himmel Set
    1407535, -- Fern Set
    1407536, -- Stark Set
    1407542, -- Classic Thawb Set
    1407543, -- Lady of the Sands Set
    1407544, -- Arshad Nadeem Set
    1407545, -- Neon Meow Set
    1407546, -- Verdant Whisper Set
    1407547, -- 7th Anniversary Set
    1407548, -- Based Oddity Set
    1407549, -- C8S23 Set
    1407551, -- Galvanic Judge Set
    1407552, -- Chronomuse Set
    1407553, -- Stellar Operative Set
    1407554, -- Battleworn Strider Set
    1407555, -- Outland Maiden Set
    1407556, -- Polychrome Bunny Set
    1407557, -- Steamline Scholar Set
    1407558, -- The Sun's Ascendance Set
    1407559, -- The Moon's Luminance Set
    1407560, -- Cybersanct Enigma Set
    1407561, -- Cybersanct Paradox Set
    1407562, -- Stellar Honey Set
    1407563, -- Eren Jaeger Character Set
    1407564, -- Attack Titan Set
    1407565, -- Mikasa Ackermann Character Set
    1407566, -- Armin Arlelt Character Set
    1407567, -- Colossal Titan (Armin) Set
    1407568, -- Levi Character Set
    1407569, -- Armored Titan Costume
    1407570, -- Scout Regiment Gear Set
    1407571, -- Stepflair Flux Set
    1407572, -- Bloodbane Vesper Set
    1407573, -- Spectral Byte Set
    1407574, -- Tech Enforcer Set
    1407578, -- Belle Tinkerer Set
    1407579, -- Steamwork Artisan Set
    1407580, -- Aria Maiden Set
    1407581, -- Sweet Songbird Set
    1407582, -- Speed Sports Set
    1407583, -- Pmarusama.Set
    1407584, -- Sakura Miko Set
    1407585, -- Mountain Dew Adventure Set
    1407586, -- Hero Xtreme Set
    1407587, -- Featherweight Boxer Set
    1407588, -- Sunny Hayride Set
    1407589, -- Striker's Streetwear Set
    1407590, -- Vibrant Streetwear Set
    1407591, -- Maasai Shuka Set
    1407592, -- Brute Gentleman Set
    1407593, -- Urban Flow Set
    1407594, -- Sunkissed Holiday Set
    1407595, -- Steelheart Defender Set
    1407596, -- C8S24 Set
    1407606, -- Graviton Sentinel Set
    1407607, -- Neon Nova Set
    1407608, -- Goldline Ace Set
    1407609, -- Optimus Prime Style Set
    1407610, -- Elita-1 Style Set
    1407611, -- Shockwave Style Set
    1407612, -- Megatron Costume
    1407613, -- Windblade Costume
    1407614, -- Optimus Prime Costume
    1407615, -- Bumblebee Costume
    1407616, -- Sweet Nailoong Set
    1407617, -- Archon Oracle Set
    1407618, -- Polar Spectrophage Set
    1407626, -- Goldhorn Steward Set
    1407627, -- Keenhorn Sentry Set
    1407628, -- Jungle Operative Set
    1407629, -- Covert Evergreen Set
    1407630, -- Nebula Valkyrie Set
    1407631, -- Pulsar Legionnaire Set
    1407632, -- Nyxen Sinistra Set
    1407633, -- Oasis Rhapsodist Set
    1407637, -- Strayhound Style Set
    1407638, -- Seaside Stunner Set
    1407639, -- Luminarch Watcher Set
    1407640, -- Blightfall Arbiter Set
    1407641, -- Darling Defiance Set
    1407642, -- PUBGM X QWER Siyeon Set
    1407643, -- PUBGM X QWER Hina Set
    1407644, -- PUBGM X QWER Chodan Set
    1407645, -- PUBGM X QWER Magenta Set
    1407646, -- Bbangbbang Costume Set
    1407647, -- Okji Costume Set
    1407648, -- 2025 Esports Blue Outfit
    1407649, -- 2025 Esports Red Outfit
    1407650, -- Goldfeather Insight Set
    1407651, -- Lil Hit the Hitmaker Set
    1407652, -- Redflame Victory Set
    1407653, -- Splinterstar Boxer Set
    1407654, -- Strawberry Fantasy Set
    1407655, -- Yellowjacket Mech Set
    1407656, -- Bernadya Elegance Set
    1407657, -- Frontline Explorer Set
    1407658, -- Fantasia Eterna Set
    1407659, -- CYCLE 9 Set
    1407660, -- C9S25 Set
    1407669, -- Ribclad Reaper Set
    1407670, -- Saccharine Riot Set
    1407671, -- Urban Herald Set
    1407672, -- Kafka Hibino Character Set
    1407673, -- Kaiju No. 8 Set
    1407674, -- Kikoru Shinomiya Character Set
    1407675, -- Kaiju No. 9 Set
    1407676, -- Kaiju No. 10 Set
    1407677, -- Mina Ashiro Character Set
    1407678, -- Reno Ichikawa Character Set
    1407679, -- Soshiro Hoshina Character Set
    1407680, -- Sonic Style Set
    1407681, -- Tails Style Set
    1407682, -- The Hermit's Chrysalis Set
    1407683, -- Blackthorn Marquis Set
    1407684, -- Floralith Muse Set
    1407685, -- Highstreet Haze Set
    1407686, -- Grimtail Pelt Set
    1407687, -- G-DRAGON PEACEMINUSONE Outfit Set
    1407688, -- G-DRAGON Stage Outfit Set
    1407689, -- Velvet Jack Set
    1407690, -- Velvet Dusk Set
    1407691, -- Moonrabbit Maiden Set
    1407692, -- Eternal Godfather Set
    1407693, -- Departed Aria Set
    1407694, -- Madcap Punk Set
    1407695, -- Macabre Valentine Set
    1407696, -- Prism Ascendant Set
    1407697, -- Exorcist Extraordinaire Set
    1407701, -- Sugarspell Curse Set
    1407702, -- Hallowed Severance Set
    1407703, -- Spectral Dreamweaver Set
    1407704, -- Spectral Duskbride Set
    1407705, -- Pumpkin Pixie Set
    1407706, -- Takemichi Hanagaki Set
    1407707, -- Chifuyu Matsuno Set
    1407708, -- Manjiro Sano Set
    1407709, -- Emma Sano Set
    1407710, -- Hinata Tachibana Set
    1407711, -- Kuzuha Set
    1407712, -- Kanae Set
    1407713, -- Houshou Marine (Live Costume) Set
    1407714, -- Houshou Marine Set
    1407715, -- Tiger Set
    1407716, -- CyberFang Suit
    1407717, -- Spook Sweepers Set
    1407718, -- Royal Scion Set
    1407719, -- Peachy Pop Set
    1407720, -- Dawnbreaker Drive Set
    1407721, -- DYING LIGHT Set
    1407722, -- Skibidi Toilet Costume
    1407723, -- Dawn Academy Set
    1407724, -- Tungsten Sentinel Set
    1407725, -- C9S26 Set
    1407729, -- Sugarcone Darling Set
    1407730, -- Frost Admiral Set
    1407731, -- Mellow Vogue Set
    1407732, -- Couture Armor Set
    1407733, -- Winter 25 Pink Puffer Set
    1407734, -- Winter 25 Corseted Hoodie Set
    1407735, -- Winter 25 Standard Set
    1407736, -- Whiteout Apex Set
    1407737, -- Spectrashift Apex Set
    1407738, -- Eagleborne Aurora Set
    1407739, -- Wolfborne Pathfinder Set
    1407740, -- Cozy Charm Set
    1407741, -- Porsche Racing Suit
    1407742, -- Aurorion Mirage Set
    1407743, -- Aeroflux Phase Set
    1407744, -- Onyxis Witch Set
    1407745, -- RAMI Set
    1407746, -- ASA Set
    1407747, -- AHYEON Set
    1407748, -- RORA Set
    1407749, -- CHIQUITA Set
    1407750, -- PHARITA Set
    1407751, -- RUKA Set
    1407752, -- BABYMONSTER Horns Set
    1407753, -- Merry Mauler Set
    1407754, -- Zombread Set
    1407755, -- Jingle Jumper Set
    1407756, -- Blizzard Belle Set
    1407757, -- Cryonix Wraith Set
    1407758, -- Winterglow Sylph Set
    1407759, -- First Strike Set
    1407760, -- Frosty Comfort Set
    1407764, -- Tundrawalk Agent Set
    1407765, -- Arctic Tracker Set
    1407766, -- Seraphic Diva Set
    1407767, -- Nocturne Diva Set
    1407768, -- Polar Traveler Set
    1407769, -- Okarun(transformed) Set
    1407770, -- Okarun Set
    1407771, -- Momo Set
    1407772, -- Jiji(transformed) Set
    1407773, -- Aira Set
    1407774, -- Aurora Guide Set
    1407775, -- Phantanova Catgirl Set
    1407778, -- Wild Tracker Set
    1407779, -- Wild Pioneer Set
    1407780, -- Caramel Angel Set
    1407781, -- SCHOTT NYC PERFECTO® Set
    1407782, -- Shehzada-e-Shahr Set
    1407783, -- Penguin Puff Set
    1407784, -- Jolly Snowjoy Set
    1407785, -- Besiktas Jersey
    1407786, -- Galatasaray Jersey
    1407787, -- Fenerbahce Jersey
    1407788, -- C9S27 Set
    1407790, -- Noh Mask Ninja Set
    1407791, -- Floral Waltz Set
    1407792, -- Panda Darling Set
    1407793, -- Dune Prince Set
    1407794, -- John Shelby Character Set
    1407795, -- Arthur Shelby Character Set
    1407796, -- Thomas Shelby Mobster Set
    1407797, -- Thomas Shelby Suit Set
    1407798, -- Iori Yagami Character Set
    1407799, -- Luxe Overlord Set
    1407800, -- Mai Shiranui Character Set
    1407801, -- Nakoruru Character Set
    1407802, -- Blaze Dancer Set
    1407803, -- Nimble Feline Set
    1407804, -- Heart Hacker Set
    1407805, -- Party Bunny Set
    1407806, -- Sweet Influencer Set
    1407807, -- Grand Debutante Set
    1407808, -- Radiant Stardom Set
    1407809, -- Veiled Enchantress Set
    1407810, -- Jade Viper Set
    1407811, -- Witherbloom Prodigy Set
    1407812, -- Wildsoul Warden Set
    1407813, -- Verdant Shade Set
    1407819, -- Moonfire Waltz Set
    1407820, -- Moonrise Serenade Set
    1407821, -- Garden Stroll Set
    1407822, -- NAGUMO Set
    1407823, -- ASAKURA SHIN Set
    1407824, -- OSARAGI Set
    1407825, -- SAKAMOTO TARO Set
    1407826, -- PUBG MOBILE × aespa KARINA Set
    1407827, -- PUBG MOBILE × aespa GISELLE Set
    1407828, -- PUBG MOBILE × aespa WINTER Set
    1407829, -- PUBG MOBILE × aespa NINGNING Set
    1407830, -- Revel 01 Set
    1407831, -- Al Shami Stylish Set
    1407832, -- Tailgate Craze Set
    1407833, -- Wolf Maiden Set
    1407834, -- Eternal Restora Set
    1407835, -- Serene Affection Set
    1407836, -- Juicy Beat Set
    1407837, -- El Omda Set
    1407838, -- Mystic Oracle Set
    1407839, -- Season Series Set (2026H1)
    1407840, -- S28 Set
    1407842, -- Jester's Gambit Set
    1407843, -- Twirling Sands Set
    1407844, -- Punk Vanguard Set
    1407845, -- Aoi Todo Set
    1407846, -- Ryomen Sukuna Kimono Character Set
    1407847, -- Ryomen Sukuna Shirtless Character Set
    1407848, -- Suguru Geto Character Set
    1407849, -- Choso Set
    1407857, -- Meowlectric Flash Set
    1407858, -- Nightfall Blade Set
    1407859, -- Aerial Recon Set
    1407860, -- Coldsteel Hacker Set
    1407861, -- Richarlison Ace09
    1407862, -- Juan Soto Set
    1407863, -- Mutant Doctor Set
    1407864, -- Gothic Nurse Set
    1407865, -- Orange Squad: Special Edition Set
    1407866, -- Dynamic Realm Set
    1407867, -- Steampunk Princess: Sara
    1407868, -- Ironwatch Sentinel: Victor
    1407869, -- Fortune Teller: Anna
    1407870, -- Dimensional Diva Set
    1407871, -- Multiverse Detective Set
    1407872, -- Smooth Footwork Set
    1407876, -- Sonic Siren Set
    1407877, -- Urban Patrol Set
    1407878, -- Sunshine Vigor Set
    1407879, -- Starlight Vigor Set
    1407880, -- Lightning Circuit Set
    1407881, -- Catch! Teenieping Overalls set
    1407882, -- Catch! Teenieping Princess Romi set
    1407883, -- Nakiri Ayame Set
    1407884, -- Thala Legacy Set
    1407885, -- Knight Dominion Set
    1407886, -- BamBam Infinite Octave Set
    1407887, -- Minnie Infinite Octave Set
    1407888, -- Soccer Vanguard Set
    1407889, -- Night Tulip Set
    1407890, -- Silky Beauty Set
    1407891, -- FiNCH Set
    1407892, -- Sparkle Spec Ops Set
    1407896, -- Toxic Daddy Trenchcoat
    1407897, -- Mirage Phantom Set
    1407898, -- Queen of Suits Set
    1407899, -- Legendary Noble Set
    1407900, -- Maid Berserker Set
    1407901, -- Isagi Yoichi Character Set
    1407902, -- Bachira Meguru Character Set
    1407903, -- Nagi Seishiro Character Set
    1407904, -- Itoshi Rin Character Set
    1407905, -- Training Outfit Set
    1407906, -- Chaosphage Set
    1407907, -- Clash of Duty Set
    1407908, -- Harley-Davidson® Blacktop Biker Set
    1407909, -- Harley-Davidson® Street Smart Set
    1407910, -- Chicken Winner Set
    1407911, -- Denim Rebel Set
    1407912, -- Lethal Beat Set
    1407913, -- Rose Requiem Set
    1407914, -- Wondrous Academy Set
    1407915, -- Fantasy Academy Set
    1407916, -- Castor Set
    1407917, -- Pollux Set
    1407918, -- Dioscuri Set
    1407919, -- Serpent Handler Set
    1407920, -- Bloodfeather Spartan Set
    1407921, -- Aberrant Aphrodite Set
    1407922, -- Amphibiraider Set
    1407928, -- Laurel Melody Set
    1407929, -- Precision Kit Set
    1407930, -- Amplified Kit Set
    1407931, -- Civil Harmony Set
    1407935, -- Usada Pekora Set
    1407936, -- Usada Pekora(Casual outfit) Set
    1407938, -- Veteran Guard Set
    1407939, -- Quinas Legacy Set
    1407940, -- Uğurcan Çakır's Set
    1407941, -- Striker Set
    1407942, -- Coronation Kiss Set
    1407943, -- White Wolves Jersey
    1407944, -- Albiceleste Set
    1407945, -- Overlord's Decree Set
    1407946, -- Babylonian Lion Set
    1407947, -- Magixx Set
    1407948, -- Tahilalats Summer Chill Set
    1407949, -- S30 Set
    1407957, -- Cybernetic Samurai Set
    1407958, -- Nightfall Stalker Set
    1407959, -- Pink Bunny Cadet Set
    1407960, -- The Fourth's Cloak Set
    1407961, -- Naruto Outfit Set
    1407962, -- Naruto Uzumaki Character Set
    1407963, -- Sasuke Uchiha Character Set
    1407964, -- Sakura Haruno Character Set
    1407965, -- Kakashi Character Set
    1407966, -- Hinata Hyuga Character Set
    1407967, -- Gaara Character Set
    1407968, -- Tsunade Character Set
    1407969, -- Madara Uchiha Character Set
    1407970, -- Jiraiya Character Set
    1407971, -- Akatsuki Set
    1407972, -- Elite Hidden Leaf Ninja Set
    1407973, -- Konoha Anbu Set
    1407974, -- Atlantean Ranger Set
    1407975, -- Crimson Bigcat Set
    1407976, -- Futuretech Jackal Set
    1407977, -- Racing Superstar Set
    1407978, -- Street Breaker Set
    1407979, -- Sunbasker Set
    1407980, -- Tide Tracker Set
    1407981, -- Electron Energy Set
    1407982, -- Proton Power Set
    1407983, -- Sakura Neko Set
    1407991, -- Equinox Vulpes Set
    1407993, -- Naruto (Sage Mode) Character Set
    1407994, -- Naruto (Six Paths Mode) Character Set
    1407995, -- Phantasia Siren Set
    1407996, -- Energetic Beat Set
    1407997, -- Puppet Maestro Set
    1408016, -- Ayo Maff Set
    1408017, -- Skele Battlesuit Set
    1408018, -- Enchanting Time Set
    1408019, -- Young Naruto Character Set
    1407285, -- Mercury Soldier Set
    1403010, -- Invader Mask
    1410646, -- Temperance's Virtue Mask
    474031, -- Cloth Bandana (Leopard)
    1410681, -- Illumispark Cover
    1400168, -- Clown Mask
    1403028, -- The Fool Mask
    1410299, -- Silver Guru Cover
    1410574, -- Dragon Empress Cover
    1410085, -- Thunderblaze Cover
    1410289, -- Bruce Lee Kung Fu Soul Cover
    1400053, -- Jersey (Black)
    1400050, -- Athletic Shorts (Black)
    1400051, -- Jersey (Light Blue)
    1400052, -- Athletic Shorts (Light Blue)
    1404190, -- Urban Walker Top
    1404437, -- Meowy Spirit Top
    403170, -- City Defender Jacket
    1405717, -- emoji Lover Shirt
    1400322, -- Mission: Impossible Fallout Pants A
    1400323, -- Mission: Impossible Fallout Boots A
    1400326, -- Mission: Impossible Fallout Boots B
    1400092, -- Commander Hat
    1400101, -- Commander Coat
    1400122, -- Commander Pants
    1404244, -- Wild Leopard Shirt
    1404505, -- Dungeon Rogue Top
    1404476, -- Chicken Dinner T-Shirt
    1400084, -- Jersey (Red)
    1400096, -- Jersey (White)
    1400049, -- Jersey (Yellow)
    1400054, -- Jersey (Red & Blue)
    1402627, -- Jungle Chivalry Headgear
    1402218, -- Devil Horns
    401035, -- Wild West Hat (White)
    1410838, -- Verdant Whisper Cover
    1404191, -- Urban Walker Pants
    1404192, -- Urban Walker Shoes
    -- ==============================================================================
    -- 3. FULL PARACHUTES, GLIDERS, HOVERBOARDS
    -- ==============================================================================
    -- [ PARACHUTES ]
    1401000, -- New Years Blessing Parachute
    1401001, -- Happy New Year Parachute
    1401002, -- Red Bone Parachute
    1401003, -- Naughty Imp Parachute
    1401005, -- Transform Spider Parachute
    1401006, -- Season 5 Parachute
    1401007, -- Birthday Parachute
    1401008, -- Golden Crane Parachute
    1401009, -- Red Devil Parachute
    1401010, -- Herbal Flower Parachute
    1401011, -- Cherry Blossom Parachute
    1401012, -- Campus Tournament Parachute
    1401013, -- Joker Parachute
    1401014, -- Clown Parachute
    1401015, -- Carabao Parachute
    1401016, -- Orange Life Parachute
    1401017, -- Golden Eagle Parachute
    1401018, -- Season 8 Champion Parachute
    1401019, -- Captain Ryan Parachute
    1401020, -- Wanderer Parachute
    1401021, -- Moon Bow Parachute
    1401022, -- OPPO F11 PRO SURVIVOURS PARACHUTE
    1401023, -- Sekigahara Lord Parachute (Square)
    1401024, -- Alliance Loot Whistle Parachute
    1401025, -- Enchanted Night Parachute (Square)
    1401026, -- Auspicious Parachute
    1401027, -- PMCO Parachute
    1401028, -- Season 7 Champion Parachute
    1401029, -- Brilliant Birthday Parachute
    1401031, -- Season 6 Champion Parachute
    1401032, -- Red Dagger Parachute
    1401033, -- WALKER Parachute
    1401034, -- Ice Wizard Parachute
    1401035, -- Challenger Parachute
    1401036, -- BAPE X PUBGM CAMO Parachute
    1401037, -- Godzilla Parachute (White)
    1401038, -- Godzilla Parachute (Gold)
    1401039, -- Godzilla Parachute (Blue)
    1401040, -- Monarch Parachute
    1401041, -- Curry Parachute
    1401043, -- Night Guardian Parachute
    1401044, -- Black Rose Parachute
    1401045, -- Lucky Cat Parachute
    1401046, -- Gloomy Night Parachute
    1401047, -- Killer Whale Parachute
    1401048, -- Kraken Parachute
    1401050, -- Music Melody Parachute
    1401051, -- OPPO Reno Parachute
    1401052, -- OPPO VOOC Parachute
    1401053, -- Enchanted Night Parachute
    1401054, -- Naughty Pig Parachute
    1401055, -- Red Parachute (Long)
    1401056, -- PMJC Parachute
    1401057, -- PMSC Parachute
    1401059, -- Draconian Champion Parachute
    1401060, -- Sekigahara Lord Parachute
    1401061, -- Imp Parachute
    1401062, -- Season 9 Champion Parachute
    1401063, -- Season 10 Champion Parachute
    1401064, -- Black Cat Parachute
    1401065, -- Rooster Parachute
    1401066, -- Ice Bookworm Parachute
    1401067, -- Pain Reliever #11 Parachute
    1401068, -- Super Power Parachute
    1401071, -- Infinite Reincarnation Parachute
    1401072, -- Lord of All Creatures Parachute
    1401074, -- Scary Pumpkin Parachute
    1401085, -- Delicious Chicken Parachute
    1401086, -- Season 11 Champion Parachute
    1401087, -- Blood Lotus Parachute
    1401088, -- Drifting Planet Parachute
    1401089, -- Season 12 Champion Parachute
    1401090, -- Ninja Assassin Parachute
    1401091, -- Neko Sakura Parachute
    1401092, -- Pioneer Parachute
    1401094, -- Fantasy Girl Parachute
    1401095, -- Battlefield Painting Parachute
    1401096, -- Judge Parachute
    1401097, -- Africa Pride Parachute
    1401098, -- Africa Unite Parachute
    1401100, -- Golden Boy Parachute
    1401102, -- PMSC World Cup Agent Parachute
    1401103, -- Lost Legion Parachute
    1401104, -- PMCO Tournament Parachute
    1401106, -- Space Lieutenant Parachute
    1401107, -- Blood Fang Servant Parachute
    1401108, -- Street Dancer 3 Parachute
    1401109, -- Unique KingCard Parachute
    1401111, -- Steamed Bun Parachute
    1401112, -- Scream Parachute
    1401113, -- Freedom Guardian Parachute
    1401115, -- Sweet Candy Parachute
    1401117, -- Wild West Cowboy Parachute
    1401119, -- Samurai Armor Parachute
    1401122, -- Incredible Parachute
    1401124, -- Warrior Parachute
    1401125, -- Gothic Lady Parachute
    1401127, -- Arabian Myth Parachute
    1401128, -- Arena Champion Parachute
    1401129, -- Season 13 Champion Parachute
    1401130, -- Gorilla Parachute
    1401131, -- PMGC Parachute
    1401133, -- Season 15 Parachute
    1401134, -- Tulip Parachute
    1401135, -- Frenzied Demon Parachute
    1401137, -- Season 14 Parachute
    1401138, -- Pro League Parachute (Gold)
    1401139, -- Pro League Parachute (Silver)
    1401140, -- Cool Camel Parachute
    1401141, -- Fried Chicken Parachute
    1401142, -- Royal Club Parachute
    1401145, -- Seven Colors Parachute
    1401146, -- Mountain Dew Parachute
    1401147, -- High Priest Parachute
    1401148, -- Idol Parachute
    1401149, -- Spread Wings Parachute
    1401150, -- Steel Warrior Parachute
    1401151, -- Season 16 Champion Parachute
    1401152, -- Death Scythe Parachute
    1401153, -- Satisfied Emoji Parachute
    1401154, -- Emoji Parachute
    1401155, -- Funny Emoji Parachute
    1401156, -- Qualcomm Parachute
    1401157, -- Dispersal Point Parachute
    1401159, -- Dictator Lord Parachute
    1401160, -- Happy Nutcracker Parachute
    1401161, -- Dragon King Parachute
    1401163, -- War God Armor Parachute
    1401164, -- Love Melody Parachute
    1401165, -- Season 17 Champion Parachute
    1401167, -- Mystic Moonlight Parachute
    1401168, -- Disco Party Parachute
    1401169, -- Season 18 Champion Parachute
    1401170, -- Snow Cherry Parachute
    1401171, -- Beehive Parachute
    1401174, -- Season 19 Champion Parachute
    1401177, -- C1S1 Champion Parachute
    1401178, -- Ice Cream Parachute
    1401179, -- El Diablo Parachute
    1401181, -- Ice Lord - Parachute
    1401182, -- Ocean Predator Parachute
    1401183, -- Dream Butterfly Parachute
    1401184, -- Beetle Parachute
    1401186, -- Turtle and Rabbit Parachute
    1401187, -- Strong Steps Parachute
    1401188, -- PMPL Spring 2021 Parachute
    1401189, -- GodzillaVsKong Parachute
    1401190, -- Wonderful Journey Parachute
    1401191, -- Space Mark Parachute
    1401192, -- Chicken Chef Parachute
    1401193, -- Color Art Parachute
    1401194, -- Aerial Punk Rich Brian Parachute
    1401195, -- OPPO Parachute
    1401196, -- BUG Parachute
    1401197, -- Gear Lord Parachute
    1401198, -- Xiaomi Parachute
    1401200, -- Deep Sea Eyes Parachute
    1401201, -- OnePlus Parachute
    1401204, -- foodpanda Parachute
    1401205, -- PMPL Autumn 2021 Parachute
    1401208, -- Sky City Parachute
    1401209, -- Future Ghost Parachute
    1401210, -- Mechanical Detective Parachute
    1401212, -- Colorful City Parachute
    1401213, -- Rose Gun Parachute
    1401215, -- Ice Parachute
    1401216, -- Treasure Map Parachute
    1401217, -- Christmas Fever Parachute
    1401218, -- Golden Pattern Parachute
    1401219, -- Golden Kingdom Parachute
    1401220, -- Radiant Sunset Parachute
    1401221, -- White Dove Parachute
    1401222, -- Time Spiral Parachute
    1401223, -- Zong Parachute
    1401224, -- C1S2 Champion Parachute
    1401225, -- C1S3 Champion Parachute
    1401227, -- Grand Sale Parachute
    1401228, -- Fashionable Wanderer Parachute
    1401231, -- PMGC 2021 Parachute
    1401232, -- Liverpool FC Parachute
    1401233, -- Breakthrough Parachute
    1401234, -- Colorful Elephant Parachute
    1401235, -- Egor Kreed Collaboration Parachute
    1401236, -- Gackt Moon Parachute
    1401237, -- Dune Parachute
    1401238, -- Guruh Gundala Parachute
    1401239, -- C2S4 Parachute
    1401240, -- Baby Shark Parachute
    1401241, -- JAPAN LEAGUE S2 Parachute
    1401242, -- Monster Chef Parachute
    1401243, -- Ocean Overlord Parachute
    1401244, -- C2S5 Parachute
    1401245, -- Electronic Empress Parachute
    1401246, -- Tiger Year Parachute
    1401247, -- Spring Colors Parachute
    1401248, -- Jujutsu Kaisen Parachute
    1401249, -- Shiba Inu Parachute
    1401250, -- Motorola Parachute
    1401252, -- Trendy Battle Parachute
    1401254, -- DJ Personality Parachute
    1401255, -- Sister Sister Parachute
    1401256, -- Neon Graffiti Parachute
    1401257, -- C2S6 Parachute
    1401258, -- Spider-Man: No Way Home Parachute
    1401259, -- Time Assassin Parachute
    1401260, -- Wasteland Parachute
    1401261, -- Colorful Parachute
    1401262, -- Colorful Festival Parachute
    1401263, -- Mysterious Circus Parachute
    1401264, -- Red Haired Girl Parachute
    1401265, -- Perfect Duo Parachute
    1401266, -- Twin Girls Parachute
    1401267, -- Mysterious Gate Parachute
    1401268, -- Anime Girl Parachute
    1401269, -- Battle Chicken Parachute
    1401270, -- Green Candle Parachute
    1401271, -- Naughty Ghost Parachute
    1401272, -- Praying Girl Parachute
    1401273, -- Cute Witch Parachute
    1401274, -- Evangelion NERV Parachute
    1401275, -- Twin Sisters Parachute
    1401276, -- PMPL Spring 2022 Parachute
    1401277, -- Teddy Bear GB Parachute
    1401278, -- Fashion Lion Parachute
    1401280, -- Childhood Memory Parachute
    1401281, -- C3S7 Parachute
    1401282, -- Giant Cat Parachute
    1401283, -- Butterfinger Parachute
    1401284, -- Super Jump Parachute
    1401285, -- Summer Alliance Parachute
    1401286, -- Squirrel Parachute
    1401287, -- Flame Demon Armor Parachute
    1401289, -- Heartrocker Parachute
    1401290, -- Mesopotamia Lion Parachute
    1401291, -- realme Parachute
    1401292, -- Lil Burger Parachute
    1401294, -- Dreamy River Parachute
    1401295, -- C3S8 Parachute
    1401296, -- Night of Miracles Parachute
    1401298, -- Glory Parachute
    1401299, -- Star Map Parachute
    1401300, -- Thorn Lord Parachute
    1401301, -- Ghost and Girl Parachute
    1401302, -- Tiny Thorn Parachute
    1401303, -- Uqabi Parachute
    1401308, -- Ice Wizard Parachute
    1401309, -- Extreme Speed Parachute
    1401310, -- PMWI 2022 Parachute
    1401311, -- BGMI Esports Parachute
    1401312, -- PMJL SEASON3 Parachute
    1401313, -- PMPS 2022 Parachute
    1401314, -- Ox Warrior Parachute
    1401315, -- Supreme Power Parachute
    1401316, -- Arabian Football Team Parachute
    1401317, -- Thousand Stars Parachute
    1401318, -- Astrology Wizard Parachute
    1401319, -- C3S9 Parachute
    1401320, -- BoBoiBoy Parachute
    1401323, -- Wild Track Parachute
    1401324, -- White Reindeer Parachute
    1401325, -- Golden Axe Parachute
    1401326, -- Mystic Gold Parachute
    1401330, -- Nebula Voyage Parachute
    1401332, -- Snow Cat Parachute
    1401334, -- KFC Parachute
    1401335, -- Watermaster Fury Parachute
    1401336, -- Lava Skull Parachute
    1401337, -- Sky Overlord Parachute
    1401338, -- Grubhub Parachute
    1401339, -- AFA Parachute
    1401340, -- Legendary Superstar Messi Parachute
    1401343, -- PMGC 2022 Parachute
    1401345, -- Treasure Map Parachute
    1401346, -- Nobru Parachute
    1401347, -- Sony Parachute
    1401349, -- Air Assault Parachute
    1401351, -- Female Hero Parachute
    1401353, -- Cunning Clown Parachute
    1401355, -- Bruce Lee Parachute
    1401356, -- Fighting Duo Parachute
    1401357, -- Donkey King Parachute
    1401360, -- Pro League Parachute
    1401361, -- Crimson Plan Parachute
    1401362, -- C4S11 Parachute
    1401363, -- Space Map Parachute
    1401364, -- BE@RBRICK Parachute
    1401365, -- Light of Glory Parachute
    1401366, -- Old Memories Parachute
    1401367, -- Bugatti Parachute
    1401368, -- Dinosaur Fossil Parachute
    1401369, -- T-Rex Escape Parachute
    1401370, -- Dragon Ball Super Parachute
    1401371, -- C4S12 Parachute
    1401372, -- Blood Dragon Parachute
    1401373, -- UNIVERSTAR BT21 Parachute
    1401374, -- HUAWEI AppGallery Parachute
    1401375, -- PMWI 2023 Parachute
    1401376, -- C5S13 Parachute
    1401377, -- Disco Rabbit Parachute
    1401378, -- Aston Martin Parachute
    1401379, -- Summer Beach Parachute
    1401380, -- C5S14 Parachute
    1401381, -- C5S15 Parachute
    1401382, -- PMGC 2023 Parachute
    1401383, -- KFC Parachute
    1401385, -- Giant Yeti Parachute
    1401386, -- Pagani Parachute
    1401387, -- Colorful Leopard Parachute
    1401388, -- Cute Squirrel Parachute
    1401389, -- Pink Salamander Parachute
    1401390, -- RS Swagster Parachute
    1401391, -- Sweet Panda Parachute
    1401392, -- Rose Warrior Parachute
    1401393, -- Justice Battle Parachute
    1401394, -- LINE FRIENDS Parachute
    1401395, -- Mystic Fox Parachute
    1401396, -- Zanmang Loopy Parachute
    1401397, -- Hardik Sky Parachute
    1401398, -- C6S16 Parachute
    1401399, -- Charming Ghost Parachute
    1401400, -- Royal Guard Parachute
    1401401, -- Bentley Parachute
    1401402, -- SPY×FAMILY Parachute
    1401403, -- Solar Eclipse Parachute
    1401404, -- Divine Armor Warrior Parachute
    1401405, -- C6S17 Parachute
    1401406, -- Cat Melody Parachute
    1401407, -- Chaotic City Parachute
    1401408, -- Guard Wings Parachute
    1401409, -- Iron Horse Parachute
    1401410, -- Space Glide Parachute
    1401411, -- C6S18 Parachute
    1401412, -- Dark Empress Parachute
    1401413, -- Lamborghini Collaboration Parachute
    1401416, -- Ancient Stone Statue Parachute
    1401417, -- Blue Ocean Parachute
    1401418, -- KAKAO FRIENDS Parachute
    1401419, -- Infinix GT Parachute
    1401420, -- Esports World Cup 2024 Parachute
    1401421, -- C7S19 Parachute
    1401422, -- Naughty Rabbit Parachute
    1401423, -- VW Collaboration Parachute
    1401424, -- Colorful Cat Spirit Parachute
    1401425, -- Black Dragon Eye Parachute
    1401426, -- Yin Yang Parachute
    1401427, -- NieR:Automata Parachute
    1401428, -- Esports Passion Parachute
    1401429, -- C7S20 Parachute
    1401430, -- Venom: The Last Dance Parachute
    1401431, -- Galaxy Tribe Parachute
    1401432, -- Royal Reindeer Parachute
    1401433, -- McLaren Parachute
    1401434, -- PMGC 2024 Parachute
    1401435, -- Snow Wolf Glider
    1401436, -- Water Shadow Glider
    1401437, -- C7S21 Glider
    1401438, -- Spring Koi Glider
    1401439, -- Eagle Glider
    1401440, -- Dark Rose Glider
    1401441, -- Opanchu Parachute
    1401442, -- Neon Drop BE 6 Parachute
    1401443, -- C8S22 Parachute
    1401444, -- Dark Bone Glider
    1401445, -- Aurora Glider
    1401446, -- Godzilla vs. Destoroyah Parachute
    1401447, -- Fluffy Rabbit Parachute
    1401448, -- Parachute(Frieren&Fern)
    1401449, -- C8S23 Parachute
    1401450, -- Digital Code Glider
    1401451, -- Color Amplification Glider
    1401452, -- Shelby Collaboration Parachute
    1401453, -- Burning Sunset Glider
    1401454, -- Attack on Titan Parachute
    1401455, -- Mechanical Glider
    1401456, -- Mountain Dew Neon Shard Parachute
    1401457, -- C8S24 Parachute
    1401458, -- Universe Parachute
    1401459, -- Transformers Parachute
    1401460, -- Divine Mandate Parachute
    1401461, -- Cute Puppy Parachute
    1401462, -- Bbangbbang's diary Parachute
    1401463, -- Realme Parachute
    1401464, -- Infinix GT Parachute
    1401465, -- C9S25 Parachute
    1401466, -- Demon Parachute
    1401467, -- Kaiju No. 8 Parachute
    1401468, -- TEAM SONIC Parachute
    1401469, -- Sparkling Butterfly Parachute
    1401470, -- Lotus Parachute
    1401471, -- Fluffy Parachute
    1401472, -- Perfect Gene Parachute
    1401473, -- Tokyo Revengers Parachute
    1401474, -- Sky Striker Parachute
    1401475, -- C9S26 Parachute
    1401476, -- Sweet Bear Glider
    1401477, -- Balenciaga Parachute
    1401478, -- Cold Snow Glider
    1401479, -- Porsche Parachute
    1401480, -- Dark Spirit Parachute
    1401481, -- Chill Ferret Parachute
    1401482, -- TV Anime DAN DA DAN Parachute
    1401483, -- C9S27 Parachute
    1401484, -- Shuriken Glider
    1401485, -- British Ghost Parachute
    1401486, -- The King of Fighters Parachute
    1401487, -- Dance Glider
    1401488, -- Gemstone Parachute
    1401489, -- Season Chain (2026H1) Parachute
    1401490, -- S28 Parachute
    1401491, -- Clown Game Parachute
    1401492, -- Apollo Parachute
    1401493, -- Cold Hacker Parachute
    1401494, -- Multiverse Gathering Parachute
    1401495, -- Catch! Teenieping Parachute
    1401496, -- SAKAMOTO TARO Parachute
    1401497, -- Nakiri Ayame Parachute
    1401498, -- S29 Parachute
    1401499, -- Toxic Parachute
    1401500, -- Red Parachute (Round)
    1401511, -- Naughty Cat Parachute
    1401513, -- San Martin FC Parachute
    1401515, -- Demon Eye Parachute
    1401516, -- Night Wave Parachute
    1401517, -- Tangerine Parachute
    1401519, -- Sleeping Bear Parachute
    1401520, -- Imperial Descendant Parachute
    1401521, -- Rolling Cloud Parachute
    1401526, -- Splendid Pattern Parachute
    1401527, -- Ocean Heart Parachute
    1401528, -- Mother Planet Parachute
    1401529, -- Golden Prince Parachute
    1401530, -- Thorn Armor Parachute
    1401531, -- Danger Zone Parachute
    1401532, -- Sea Shell Parachute
    1401534, -- Yellow Duck B.Duck Parachute
    1401538, -- Gentle Rabbit Parachute
    1401540, -- Yeti Parachute
    1401541, -- Colorful Pixel Parachute
    1401542, -- Delicious Parachute
    1401543, -- I Love Tao Kae Noi Parachute
    1401544, -- Baby Parrot Parachute
    1401545, -- U.F.O Parachute
    1401546, -- Baby Shark Parachute
    1401547, -- Stuffed Bear Parachute
    1401548, -- Serious Cat Parachute
    1401549, -- Eternal Glory Parachute
    1401551, -- Armored Queen Parachute
    1401554, -- Pixel Dinosaur Parachute
    1401555, -- Royal Butterfly Parachute
    1401556, -- Sweet Journey Parachute
    1401610, -- Birthday Celebration Parachute
    1401611, -- Shining Stage Parachute
    1401613, -- Anubis Judge Parachute
    1401615, -- Horus God Parachute
    1401616, -- One Plus Parachute
    1401617, -- Roaring Lion Parachute
    1401618, -- Facebook Parachute
    1401619, -- Pharaoh Amulet Parachute
    1401620, -- Pharaoh Parachute (Blue)
    1401621, -- Blood Fang Parachute
    1401622, -- LINE FRIENDS Parachute
    1401623, -- PMNC 2021 Parachute
    1401624, -- Poseidon Parachute
    1401625, -- Tribal Princess Parachute
    1401628, -- Adarna Phoenix Illusion Parachute
    1401629, -- Creation Maiden Parachute
    1401811, -- Giannis Parachute
    1401813, -- Hero Journey Parachute
    1401814, -- Rock 'n' Roll Parachute
    1401815, -- Battle Commander Parachute
    1401816, -- BURGER KING Parachute
    1401817, -- Blood Eagle Warrior Parachute
    1401820, -- Flying Fish Parachute
    1401822, -- Swamp Monster Parachute
    1401823, -- Wind Lord Parachute
    1401824, -- Gift Box Parachute
    1401826, -- First Love Parachute
    1401827, -- Coffee Queen Parachute
    1401828, -- Ancient Guard Parachute
    1401829, -- God's Wrath Parachute
    1401832, -- C4S10 Parachute
    1401833, -- Labyrinth Monster Parachute
    1401835, -- Poker Duel Parachute
    1401836, -- Clown Game Parachute
    1401837, -- Illusion Parachute
    1401838, -- BLUE LOCK Parachute
    1401839, -- Ford Parachute
    1401840, -- Harley-Davidson® Parachute
    1401841, -- Bone Rose Parachute
    1401842, -- Twins Parachute
    1401843, -- Laurel Wreath Glider
    1401844, -- Parachute(Pubniku)
    1401845, -- S30 Parachute
    1401846, -- Trial of Fire Event Parachute

    -- [ GLIDERS / HOVERBOARDS / FLYING DEVICES ]
    4151001, -- Parachute (Blue)
    4151002, -- Parachute Trail (Gold)
    4151003, -- Smoke Trail (Pink)
    4151004, -- Smoke Trail (Blue)
    4151006, -- Smoke Trail (Rainbow)
    4151010, -- Flying Device (Bằng Chíu)
    4151012, -- Cycle Skateboard
    4151013, -- Snowboard
    4151014, -- Cycle 2 Skateboard
    4151015, -- Celebration Smoke Trail (3 colors)
    4151017, -- Forest Heart Skateboard
    4151018, -- Birthday Skateboard
    4151019, -- Love War God Glider
    4151020, -- C3 Guard Skateboard
    4151021, -- Messenger of God Glider
    4151022, -- Golden Wings Glider
    4151023, -- Messi Collaboration Skateboard
    4151024, -- Crimson Priest Glider
    4151025, -- Paper Kite Glider
    4151026, -- Martial Arts Master Skateboard
    4151027, -- Cycle 4 Skateboard
    4151028, -- Blood Tear Skateboard
    4151029, -- Light Empress Glider
    4151030, -- Blood Soul Demon Glider
    4151031, -- Moneybag Dinosaur Glider
    4151032, -- Crimson Dragon Wings Glider
    4151034, -- Cloud Skateboard
    4151035, -- Wind Symphony Glider
    4151036, -- Wave Press Skateboard
    4151037, -- CYCLE 5 Skateboard
    4151038, -- Perfect Pearl Glider
    4151040, -- Light Hunter Skateboard
    4151041, -- Blue Bone Glider
    4151042, -- Tech Princess Glider
    4151043, -- Tech Princess Glider
    4151044, -- Shark Skateboard
    4151045, -- Royal Winter Glider
    4151046, -- Blue Sky Blade Skateboard
    4151056, -- Royal Winter Glider
    4151057, -- Fire Fox Skateboard
    4151058, -- LINE FRIENDS Glider
    4151059, -- Cloud Piercer Skateboard
    4151060, -- Golden Snake Glider
    4151061, -- CYCLE 6 Skateboard
    4151062, -- Zanmang Loopy Smoke Trail
    4151063, -- SPY×FAMILY Bond Glider
    4151064, -- Angel Glider
    4151065, -- Angel Glider
    4151066, -- Divine Emperor Glider
    4151067, -- Kaleidoscope Glider
    4151068, -- Thorn Lord Glider
    4151069, -- Nebula Thunder Glider
    4151070, -- Divine Knight Glider
    4151071, -- Love Guardian Glider
    4151072, -- Space Dragon Glider
    4151073, -- Mystic Neon Glider
    4151074, -- PUBGM X NewJeans Glider
    4151075, -- Love Guardian Glider
    4151076, -- Nine Winds Supreme Glider
    4151077, -- Airplane Glider
    4151078, -- Iron Seahorse Glider
    4151079, -- Underworld Wings Glider
    4151080, -- Cycle 7 Skateboard
    4151083, -- Dragon Bone Glider
    4151084, -- Red Fire - Kar98 (Level 8)
    4151085, -- Steel Wing Glider
    4151086, -- DP Drift Parachute
    4151087, -- Dragon Bone Glider
    4151089, -- Black Bird Glider
    4151090, -- Sweet Dream Glider
    4151091, -- Space Explorer Glider
    4151092, -- Blue Lion Star River Glider
    4151093, -- Jade Wolf Sky Realm Glider
    4151094, -- CYCLE 8 Skateboard
    4151095, -- Anukhra Wings Glider
    4151096, -- Pharaoh Wings Glider
    4151097, -- Super Beast Ghidorah Glider
    4151098, -- Time Shift Glider
    4151099, -- Dark Sovereign Glider
    4151103, -- Star Chariot Glider
    4151104, -- ODM Gear Glider
    4151105, -- Blood Curse Destiny Glider
    4151106, -- Electromagnetic Illusion Glider
    4151107, -- Star Chariot Glider
    4151108, -- Laserbreak Glider
    4151109, -- Ice God Glider
    4151110, -- Dragon Saint Glider
    4151111, -- Reactive Hunter Glider
    4151112, -- Evil God Beauty Glider
    4151113, -- CYCLE 9 Skateboard
    4151114, -- Dragon Saint Glider
    4151115, -- Ice God Glider
    4151117, -- Preondactyl Glider
    4151118, -- Sparkling Butterfly Glider
    4151119, -- Magic Broom Glider
    4151120, -- Dragon Mirror Glider
    4151121, -- Mikey Glider
    4151122, -- Sparkling Butterfly Glider
    4151123, -- Ice Crystal Spirit Glider
    4151124, -- Death Blood Wing Glider
    4151125, -- Galaxy Guardian Glider
    4151126, -- Entertainment Glider
    4151127, -- Eternal Spirit Wood Glider
    4151128, -- Divine Light Glider
    4151129, -- Season Chain (2026H1) Skateboard
    4151130, -- Nue Glider
    4151131, -- Emperor Phoenix Glider
    4151132, -- Blood Wing Black Bird Glider
    4151133, -- Space Teleport Glider
    4151134, -- Multiverse Glider
    4151135, -- SAKAMOTO TARO Glider
    4151138, -- Red Thunder Glider
    4151139, -- Void Glider
    4151140, -- Twins Glider
    4151141, -- Cerberus Glider
    4151142, -- Pearl Glider
    4151143, -- Twins Glider
    4152031, -- Blood Soul Demon Glider
    4152035, -- Cloud Skateboard
    4152036, -- Windborne Euphony Glider
    4152037, -- Wave Press Skateboard
    4152038, -- CYCLE 5 Skateboard
    4152039, -- Perfect Pearl Glider
    4152041, -- Boxerbolt Hoverboard (Shop)
    4152042, -- Blueyonder Glider
    4152043, -- Agile Charmer Glider
    4152044, -- Agile Charmer Glider
    4152045, -- Chilly Perch Glider
    4152046, -- Foxy Flare Hoverboard
    4152058, -- LINE FRIENDS Glider (Shop)
    4152059, -- Cloud Piercer Hoverboard (Shop)
    4152060, -- Golden Wings Glider (Shop)
    4152061, -- CYCLE 6 Skateboard (Shop)
    4152063, -- Bond Glider SPY×FAMILY (Shop)
    4152066, -- Divine Emperor Glider (Shop)
    4152067, -- Kaleidoscope Glider (Shop)
    4152068, -- Thorn Lord Glider (Shop)
    4152069, -- Nebula Thunder Glider (Shop)
    4152070, -- Divine Knight Glider (Shop)
    4152076, -- Nine Winds Supreme Glider (Shop)
    4152079, -- Underworld Wings Glider (Shop)
    4152080, -- CYCLE 7 Skateboard (Shop)
    4152092, -- Blue Lion Star River Glider (Shop)
    4152093, -- Jade Wolf Sky Realm Glider (Shop)
    4152094, -- CYCLE 8 Skateboard (Shop)
    4152095, -- Anukhra Wings Glider
    4152096, -- Pharaoh Wings Glider
    4152097, -- Super Beast Ghidorah Glider
    4152098, -- Time Shift Glider
    4152099, -- Dark Sovereign Glider
    4152116, -- Dragon Saint Glider (Single Hall)


    -- ==============================================================================
    -- 4. SHIRTS, PANTS, SHOES & TDM (EXTREMELY COOL STYLES)
    -- ==============================================================================
    -- [ BAPE & ALAN WALKER ]
    1400569, -- BAPE MIX CAMO HOODIE
    1400650, -- BAPE MIX CAMO SHORTS
    1400651, -- BAPE STA MID
    1404000, -- BAPE City Camo Hoodie
    1404002, -- BAPE City Camo Pants
    1404048, -- BAPE X PUBGM CAMO Shirt
    1404049, -- BAPE X PUBGM CAMO Shark Hoodie
    1404050, -- BAPE X PUBGM CAMO Pants
    1404051, -- BAPE X PUBGM CAMO Shoes
    1404016, -- Alan Walker T-shirt
    1404017, -- Alan Walker Hoodie
    1404042, -- Alan Walker Outfit
    1404043, -- Alan Walker Shirt
    1404044, -- Alan Walker Pants
    1404045, -- Alan Walker Shoes
    1404340, -- Alan Walker 2021 Outfit
    1403038, -- Alan Walker Mask
    1403064, -- Alan Walker Mask

    -- [ POPULAR TDM ITEMS (Bandana, Military Jacket, Black Jacket...) ]
    402001, -- Survival Bandana
    402045, -- PUBG Scarf (Tactical)
    1400158, -- Hockey Mask
    1402005, -- Mysterious Leather Mask
    1403100, -- Mountaineer Mask
    403010, -- Dirty Tank Top (White)
    403028, -- Trench Coat (Black)
    403181, -- Desert Camo Shirt
    403182, -- Predator Hoodie (Black)
    403183, -- Commando Hoodie (White)
    403192, -- Bomber Jacket
    404006, -- Jeans (Brown)
    404008, -- Military Pants (Khaki)
    404013, -- Military Pants (Camo)
    404015, -- Skinny Jeans (Blue)
    404026, -- Cargo Pants (Beige)
    404028, -- Cargo Pants (Black)
    404084, -- Shorts (Black)
    404100, -- Stealth Pants (Black)
    405001, -- Soft Sole Shoes (White)
    405002, -- High Top Sneakers
    405019, -- Falcon Military Boots (Black)
    405044, -- Soft Sole Shoes (Black)
    1400013, -- American Jeans

    -- [ VIP SINGLE SHIRTS (Collab, Supercar) ]
    1404142, -- THE WALKING DEAD T-shirt (White)
    1404143, -- THE WALKING DEAD T-shirt (Black)
    1404218, -- COVERNAT Hoodie (White)
    1404219, -- COVERNAT Hoodie (Black)
    1404326, -- Xiaomi T-shirt
    1404327, -- OnePlus T-shirt
    1404405, -- Messi × PUBG MOBILE Jersey
    1404406, -- Bruce Lee T-shirt
    1404411, -- Ducati Hoodie
    1404412, -- Ducati Corse City C2 Shoes
    1404413, -- Ducati Sport C2 Pants
    1404414, -- Ducati Speed Evo C2 Jacket
    1404426, -- PMGC 2023 Jacket
    1404427, -- Pagani Conqueror Pants
    1404428, -- Pagani Conqueror Shoes
    1404508, -- Mr.Beast Hoodie
    1400324, -- Top B
    1400325, -- Top A
    1405117, -- Golden Eagle Set
    1405177, -- Cyber Enforcer Top
    1405207, -- Cyber Enforcer Pants
    1405208, -- Cyber Enforcer Shoes
    1410256, -- Starsea Admiral Cover
    1410255, -- Bloody Noon Cover
    1410200, -- Cosmic Inquisitor Cover
    1410199, -- Spectral Swan Cover
    1410232, -- Nether Visage Cover
    1410139, -- Lightning Nebula Cover
    1400427, -- Dark Comet Cover
    1400421, -- Violet Halo Cover
    1400791, -- Crimson Shadow Mask
    1405116, -- Golden Eagle Cover
    1405069, -- Neon Dominator Top
    1405065, -- Neon Dominator Mask
    1405118, -- Golden Eagle Mask
    1400702, -- Urban Walker Set
    1405091, -- Cyber Enforcer Set
    1405558, -- Phantom Assassin Mask
    1400451, -- Midnight Vanguard Set
    1400778, -- Neon Cyberpunk Set
    1400693, -- Steel Soldier Top
    1405012, -- Phantom Specialist Set
    1405066, -- Neon Dominator Bottom
    1405092, -- Cyber Enforcer Helmet
    1405102, -- Shadow Assassin Set
    1405121, -- Arctic Warfare Outfit
    1405218, -- Iron Clad Mask
    1405132, -- Phantom Operative Top
    1405174, -- Desert Commando Bottom
    1405216, -- Obsidian Knight Set
    1405265, -- Shadow Assassin Mask
    1405340, -- Crimson Flame Set
    1405341, -- Crimson Flame Cover
    1405334, -- Frostbite Warrior Top
    1405318, -- Frostbite Warrior Set
    1405295, -- Cyber Commando Pants
    1405444, -- Neon Spectre Top
    1405482, -- Crimson Flame Bottom
    1405384, -- Cyber Commando Top
    1405395, -- Shadow Ninja Set
    1405860, -- Solar Flare Top
    1405799, -- Solar Flare Mask
    1406039, -- Glacial Guardian Mask
    1406159, -- Glacial Guardian Set
    1406677, -- Mecha Warlord Top
    1407320, -- Mecha Warlord Mask
    1406060, -- Dark Realm Sentinel Set
    1406059, -- Dark Realm Sentinel Mask
    1405180, -- Obsidian Knight Cover
    1404332, -- Desert Raider Top
    1402897, -- Stealth Operative Mask
    1402374, -- Cyber Enforcer Top
    1402313, -- Cyber Enforcer Bottom
    1402834, -- Midnight Vanguard Mask
    1402120, -- Neon Cyberpunk Mask
    1402218, -- Steel Soldier Mask
    1402179, -- Phantom Specialist Mask
    1402144, -- Desert Commando Mask
    1402077, -- Shadow Assassin Mask
    1400737, -- Arctic Warfare Mask
    1400595, -- Obsidian Knight Mask
    1402329, -- Phantom Operative Mask
    1400426, -- Dark Comet Set
    401035, -- Classic Cap (Black)
    1400130, -- Ghillie Suit (Desert)
    1410138, -- Glacial Guardian Top
    1410647, -- Mecha Warlord Bottom
    1410768, -- Dark Realm Sentinel Top
    1410255, -- Iron Guardian Top
    1403627, -- Cyber Commando Mask
    1403197, -- Shadow Ninja Top
    1403660, -- Neon Spectre Bottom
    1403498, -- Frostbite Warrior Bottom
    1400812, -- Desert Raider Mask
    1403044, -- Steel Vanguard Mask
    1400429, -- Violet Halo Set
    1403036, -- Stealth Operative Top
    403184, -- Tactical Boots
    1404153, -- Neon Dominator Gloves
    1404053, -- Golden Eagle Gloves
    1407033, -- Cyber Enforcer Gloves
    1400321, -- Phantom Assassin Set
    1400708, -- Crew Uniform
    1404152, -- Obsidian Knight Gloves
    1404293, -- Solar Flare Gloves
    1404151, -- Glacial Guardian Gloves
    1400371, -- Mecha Warlord Set
    1404423, -- Dark Realm Sentinel Gloves
    452001, 452002, 452003, -- Gloves

    -- [ EMOTES ]
    2203601, -- I Own You
    2203701, -- Take a Break
    2200401, -- Laugh
    2200501, -- Beckon
    2200601, -- Follow
    2200701, -- Shake Head
    2200801, -- Nod
    2200901, -- Surrender
    2201001, -- Angry
    2201101, -- Swing
    2201201, -- Bugi-Vugi
    2201301, -- Dustin Offman
    2201401, -- Russian Dance
    2201501, -- Quiet
    2201601, -- Joy
    2201701, -- Breakdown
    50029008, -- Cry
    12201301, -- Gothic Assassin Emote
    12216101, -- Blood Eagle Warrior Emote
    12212201, -- Dark Assassin Emote
    12219207, -- Sky Ox General Emote
    12209001, -- Samurai Warrior Emote
    12219561, -- Crimson Robe Emote
    12210001, -- Death Touch Emote
    12219022, -- Thorn Guard Emote
    12208801, -- Demigod Warrior Emote
    12210801, -- Silver Shell Hunter Emote
    12200701, -- Time Traveler Emote
    12219242, -- Sky Walk Emote
    12206001, -- Blue Lotus Spirit Emote
    12205401, -- King of Beasts Emote
    12205201, -- Beast Heart Emote
    12212601, -- Mystic Slaughter Emote
    12205601, -- Beast Soul Emote
    12219208, -- Cyber Monkey King Emote
    12212001, -- Martial Saint Emote
    12206801, -- Mystic Sea Dragon Emote
    12209801, -- Spirit Master Emote
    12211401, -- Ice Witch Emote
    12207001, -- Star Sea Voyager Emote
    12211801, -- Order Lord Emote
    12207901, -- Enchanting Sea King Emote
    12203401, -- Illusion Anniversary Emote
    12204001, -- Clown Emote (April Fools)
    12201801, -- Snow Guardian Emote
    12215601, -- Supernova Man Emote
    12215532, -- Flame Lord Emote
    12213201, -- Tomorrow Plan Emote
    12215529, -- Racing Knight Emote
    12219053, -- Pearl Queen Emote
    12204601, -- World Martial Arts Emote
    12215701, -- Planet of the Apes Emote
    12219003, -- Dark Divine Emote
    12219004, -- Silver Flame Soul Emote
    12219009, -- Enchanting Flame Emote
    12219216, -- Withered Priest Emote
    12221954, -- Phantasia Siren Emote 
    12220921, -- Ecstatic Cheering
    12209501, -- Victory Dance
    12219597, -- Victory Dance (A1)
    12219623, -- Victory Dance (A2)
    12219678, -- Victory Dance (A3)
    12219719, -- Victory Dance (A4)
    12220010, -- Victory Dance (A5)
    12220041, -- Victory Dance (A6)
    12220156, -- Victory Dance (A7)
    12220175, -- Victory Dance (A8)
    12220236, -- Victory Dance (A9)
    12220306, -- Victory Dance (A10)
    12220346, -- Victory Dance (A11)
    12220386, -- Victory Dance (A12)
    22010007, -- Victory Dance (A13)
    22010016, -- Victory Dance (A14)
    22010025, -- Victory Dance (A15)
    22010034, -- Victory Dance (A16)
    22010043, -- Victory Dance (A17)
    12220825, -- Victory Dance (A18)
    22010064, -- Victory Dance (A19)
    22010078, -- Victory Dance (A20)
    -- HAIR, FACE etc.
    1404198, 1404366, 1410480, 40605011, 1404323, 1406001, 1403002, 1411147,

    -- ==========================================================================
    -- HELMETS SKINS
    -- ==========================================================================
    1502000022, -- Black Magma Helmet
    1502000023, -- Glacier Helmet
    1502000026, -- Yeti Helmet
    1502000027, -- Cuddly Panda Helmet
    1502000028, -- Scarlet Beast Helmet
    1502000029, -- Soaring Eagle Helmet
    1502000030, -- Stylish Santa Helmet
    1502000031, -- Mutated Helmet
    1502000032, -- Sinister Skull Helmet
    1502000033, -- Intergalactic Helmet
    1502000034, -- Max Drip Helmet
    1502000035, -- Irradiated Frog Helmet
    1502000036, -- Cupid Helmet
    1502000037, -- X Marks the Spot Helmet
    1502000038, -- Arachnoid Helmet
    1502000039, -- Dragonling Helmet
    1502000040, -- Mechanized Helmet
    1502000041, -- Star Trooper Helmet
    1502000042, -- Brilliant Anniversary Helmet
    1502000043, -- Bloodthirsty Fiend Helmet
    1502000044, -- Decorated Helmet
    1502000045, -- Mech Rabbit Helmet
    1502000046, -- Honorable Warrior Helmet
    1502000047, -- Techno Helmet
    1502000048, -- Dayman Helmet
    1502000049, -- Army Men Helmet
    1502000050, -- Cast Iron Helmet
    1502000052, -- Crimson Fox Helmet
    1502000053, -- Season 11 Arena Helmet
    1502000054, -- Ryan Helmet
    1502000055, -- Pearl Hunter Helmet
    1502000058, -- Royal Butterfly Helmet
    1502000060, -- Explorer's Helmet
    1502000062, -- Radiance Helmet
    1502000063, -- Bloody Tide Helmet
    1502000064, -- Winged Helmet
    1502000065, -- Moon Bunny Helmet
    1502000069, -- Masked Psychic Helmet
    1502000070, -- Shining Star Helmet
    1502000071, -- Past Glory Helmet
    1502000072, -- Red - Helmet
    1502000073, -- Cybernetic Guardian Helmet
    1502000074, -- Snowflake Girl Helmet
    1502000075, -- Jubilant Baby Seal Helmet
    1502000076, -- Futuristic Streetwear Helmet
    1502000077, -- Field Commander Helmet
    1502000078, -- Forest Ninja Helmet
    1502000079, -- Blood Lotus Helmet
    1502000080, -- Sleepy Slug Helmet
    1502000081, -- The Pummeler Helmet
    1502000082, -- Sweet Treats Helmet
    1502000084, -- Golden Eagle Helmet
    1502000085, -- Armed Hound Helmet
    1502000086, -- Adorable Mouse Helmet
    1502000087, -- Arctic Hunter Helmet
    1502000088, -- Rock 'n' Roll Helmet
    1502000089, -- Baby Chick Helmet
    1502000090, -- Pink Demoness Helmet
    1502000091, -- Naughty Kitty Helmet
    1502000092, -- Sky Barrier Helmet
    1502000093, -- Anubian Magistrate Helmet
    1502000094, -- Plump Strawberry Helmet
    1502000096, -- Fortune Teller Helmet
    1502000097, -- Gold Kitten Helmet
    1502000098, -- Will of Horus Helmet
    1502000099, -- Puppy Love Helmet
    1502000101, -- Dazzling Youth Helmet
    1502000102, -- Bad Apple Helmet
    1502000103, -- Cuckoo Bird Helmet
    1502000104, -- Anubis Acolyte Helmet
    1502000105, -- Stealth Agent Helmet
    1502000106, -- Rainbow Splash Helmet
    1502000107, -- Sparkly Universe Helmet
    1502000108, -- Ragtag Goon Helmet
    1502000109, -- Lion's Claw Helmet
    1502000110, -- Podium Placer Helmet
    1502000111, -- Nightmare Helmet
    1502000113, -- Rose Unicorn Helmet
    1502000114, -- Mechforged Helmet
    1502000115, -- Ladybug Helmet
    1502000116, -- Retro Police Helmet
    1502000119, -- Persian Warrior Helmet
    1502000121, -- Waffle Cone Helmet
    1502000123, -- Sleepy Bear Helmet
    1502000124, -- Samurai Ops Helmet
    1502000125, -- Squirrel Helmet
    1502000126, -- Seductress Helmet
    1502000127, -- Stars & Stripes Helmet
    1502000128, -- Gold and Silk Helmet
    1502000129, -- Violet Wonder Helmet
    1502000130, -- Officer's Helmet
    1502000132, -- Castle Helmet
    1502000133, -- Jack-o'-lantern Helmet
    1502000134, -- New Year Lion Helmet
    1502000135, -- Cutie Cream Helmet
    1502000136, -- Cute Penguin Helmet
    1502000137, -- Cute Baddie Helmet
    1502000138, -- Grave Lord Helmet
    1502000141, -- Tulip Helmet
    1502000143, -- Dream Idol Helmet
    1502000145, -- Clockwork Tin Soldier Helmet
    1502000146, -- Resplendent Dawn Helmet
    1502000149, -- Lucky Carp Helmet
    1502000150, -- Acolyte of Justice Helmet
    1502000151, -- Regal Overlord Helmet
    1502000154, -- Shining Eagle Helmet
    1502000155, -- Cactus Sheriff Helmet
    1502000156, -- Angry Chicken Helmet
    1502000157, -- Present Helmet
    1502000159, -- Notes of Affection Helmet
    1502000160, -- Snow Sakura Helmet
    1502000163, -- Golden Prince Helmet
    1502000164, -- Red Battlecat Helmet
    1502000165, -- Reindog Helmet
    1502000167, -- Bamboomz Helmet
    1502000169, -- Crimson Beetle Helmet
    1502000170, -- Rainbow Unicorn Helmet
    1502000171, -- Project Idol Helmet
    1502000172, -- Woolly Dragon Helmet
    1502000173, -- Ghillie Lion Helmet
    1502000174, -- Night Ensemble Helmet
    1502000175, -- B.Duck Helmet
    1502000177, -- QUACK Agent - Helmet
    1502000179, -- Iron Tortoise Helmet
    1502000180, -- Mutant Warlord Helmet
    1502000181, -- Chromatic Brilliance Helmet
    1502000182, -- Mecha Ant Helmet
    1502000183, -- Godzilla Helmet
    1502000184, -- Masked Wasp Helmet
    1502000185, -- Mr. Busybee Helmet
    1502000186, -- Noctus Sovereign Helmet
    1502000187, -- Cute Bazzi Helmet
    1502000189, -- Belligerent Fiend Helmet
    1502000190, -- Cyber Monkey Helmet
    1502000191, -- Azure Warrior - Helmet
    1502000192, -- Sally Helmet
    1502000193, -- Cool Rebel Helmet
    1502000194, -- MECHAGODZILLA Helmet
    1502000195, -- Tidal Wargod Helmet
    1502000196, -- Chrono Cyborg Helmet
    1502000197, -- I SEE YOU Helmet
    1502000198, -- Magic Adventure Helmet
    1502000199, -- Alloy Conqueror Helmet
    1502000200, -- Coral Beasts Helmet
    1502000201, -- Emerald Punk Helmet
    1502000202, -- Cosmic Probe Helmet
    1502000203, -- Techno Beast Helmet
    1502000204, -- BUG Helmet
    1502000205, -- Extreme Diver Helmet
    1502000207, -- Lobster Avenger Helmet
    1502000209, -- Scarecrow Minstrel Helmet
    1502000210, -- Cupcake Cutie Helmet
    1502000211, -- Urban Assassin Helmet
    1502000214, -- Wild Frontier Helmet
    1502000217, -- Festive Moments Helmet
    1502000219, -- Winner Dinner Helmet
    1502000220, -- Jolly Festival Helmet
    1502000221, -- Aureate Assassin Helmet
    1502000222, -- Majestic Cavalry Helmet
    1502000223, -- Gold Porcelain Helmet
    1502000224, -- Fairyland Helmet
    1502000225, -- Savage Treant Helmet
    1502000227, -- Shimmer Power Helmet
    1502000228, -- Winter Fantasy - Helmet
    1502000229, -- Joyful Kitten Helmet
    1502000230, -- Mech Dragon Helmet
    1502000231, -- Slime Tech Helmet
    1502000232, -- Bunny Friends Helmet
    1502000233, -- Winter Bunny Helmet
    1502000234, -- Sweet Cub Helmet
    1502000235, -- Baby Dragon Helmet
    1502000236, -- Baby Parrot Helmet
    1502000237, -- Roguish Imp Helmet
    1502000238, -- Elite Helmet
    1502000239, -- Mystic Artificer Helmet
    1502000241, -- Nocturnal Rhapsody Helmet
    1502000242, -- Gackt Moon Helmet
    1502000243, -- Honey Jar Helmet
    1502000244, -- Urban Ogre Helmet
    1502000246, -- Tribal Warfare Helmet
    1502000247, -- Green Age Helmet
    1502000248, -- Clockwork Helmet
    1502000249, -- Voracious Trapper Helmet
    1502000252, -- Forged Vigilante Helmet
    1502000253, -- Valorian Helmet
    1502000254, -- Jelly Bear Helmet
    1502000255, -- Cheeky Cat Helmet
    1502000256, -- Ursa Hunter Helmet
    1502000257, -- Ornate Engraving Helmet
    1502000258, -- Baby Shark Helmet
    1502000259, -- Vibrant Celebration Helmet
    1502000260, -- Clockwork Defender Helmet
    1502000261, -- Atlantic Tech Helmet
    1502000263, -- Wild Rave Helmet
    1502000264, -- SOS Voyager Helmet
    1502000265, -- Pumpkin Throne Helmet
    1502000267, -- Glorious Ruins Helmet
    1502000268, -- Donkey Party Helmet
    1502000269, -- Pink Parrot Helmet
    1502000270, -- Golden Guard Helmet
    1502000271, -- Clan Defender Helmet
    1502000272, -- Mystic Battle Helmet
    1502000273, -- Radiation Trooper Helmet
    1502000274, -- Royal Artisan Helmet
    1502000275, -- Ultimate Trendsetter Helmet
    1502000276, -- Mysterious Dancer Helmet
    1502000277, -- Exploding Ape Helmet
    1502000278, -- Evangelion-01 Helmet
    1502000279, -- Gojek Driver Helmet
    1502000280, -- Bony Bunny Helmet
    1502000284, -- FM/AM Helmet
    1502000285, -- Magical Night Helmet
    1502000286, -- Markhor Helmet
    1502000287, -- First Love Helmet
    1502000288, -- Final Happiness Helmet
    1502000289, -- Movie Night Helmet
    1502000290, -- Beat Pirate Helmet
    1502000292, -- Royal Apparel Helmet
    1502000293, -- Hiemal Shadows Helmet
    1502000294, -- Court Sorcerer Helmet
    1502000295, -- Nebula Trail Helmet
    1502000297, -- Dino Trooper Helmet
    1502000298, -- Eternal Kingdom Helmet
    1502000299, -- Supernova Helmet
    1502000300, -- Exalted Warrior Helmet
    1502000301, -- Illustrious Archon Helmet
    1502000302, -- Lethal Code Helmet
    1502000305, -- Steel Morpher Helmet
    1502000306, -- Galactic Adventure Helmet
    1502000307, -- BoBoiBoy Helmet
    1502000309, -- Magical Flora Helmet
    1502000311, -- Blood Sucker Helmet
    1502000314, -- Imperial Enforcer Helmet
    1502000315, -- Floral Snowflake Helmet
    1502000317, -- Spec Ops Captain Helmet
    1502000320, -- Messi Football Icon Helmet
    1502000322, -- Honored Chieftain Helmet
    1502000323, -- Royal Orchestrion Helmet
    1502000325, -- Tide Sentinel Helmet
    1502000327, -- Magma Skull Helmet
    1502000328, -- Violet Feather Helmet
    1502000330, -- Cardboard Kraken Helmet
    1502000332, -- Rising Rebel Helmet
    1502000333, -- Auric Sentinel Helmet
    1502000335, -- Minimalist Tech Helmet
    1502000336, -- Dragon Guard Helmet
    1502000337, -- Cheeky Teddy Helmet
    1502000338, -- Purple Frenzy Helmet
    1502000339, -- Pan Pan Helmet
    1502000341, -- Harlequin Helmet
    1502000342, -- Moondrop Eterna Helmet
    1502000343, -- Cucumber Genius Helmet
    1502000344, -- Crimson Agenda Helmet
    1502000345, -- Crimson Storm Helmet
    1502000346, -- Vitatech Helmet
    1502000347, -- Clever Dino Helmet
    1502000348, -- Chomper Helmet
    1502000349, -- Crimson Ephialtes Helmet
    1502000350, -- Noctum Sunder Helmet
    1502000351, -- Golden Reaper Helmet
    1502000352, -- DJ Vibe Helmet
    1502000353, -- Quick Wits Helmet
    1502000354, -- Cap'n Feathers Helmet
    1502000355, -- Rainbow Blitz Helmet
    1502000357, -- Son Goku Helmet
    1502000358, -- Aurora Diva Helmet
    1502000359, -- Ghastly Gloom Helmet
    1502000360, -- Pastel Puff Helmet
    1502000361, -- Neuro Dynamo Helmet
    1502000362, -- Conch Tech Helmet
    1502000363, -- Bone Survivor Helmet
    1502000364, -- 2023 PMGC Helmet
    1502000365, -- Swift Scarlet Helmet
    1502000366, -- RS Swagster Helmet
    1502000367, -- Devoted Defender Helmet
    1502000368, -- Fiestafolk Helmet
    1502000369, -- Panda Sweetie Helmet
    1502000370, -- Dracostride Helmet
    1502000371, -- Lion Reign Helmet
    1502000372, -- Sonicshock Helmet
    1502000373, -- LINE FRIENDS BROWN Helmet
    1502000374, -- Inkstripe Tiger Helmet
    1502000375, -- Floral Bear Helmet
    1502000376, -- Kitsune Omen Helmet
    1502000377, -- Phantom Luster Helmet
    1502000378, -- Striped Sweetheart Helmet
    1502000379, -- Auric Guardian Helmet
    1502000380, -- Ignis Helmet
    1502000382, -- Magick Delight Helmet
    1502000383, -- Gallant Jockey Helmet
    1502000384, -- Bygone Realm Helmet
    1502000385, -- Mech Hero Helmet
    1502000386, -- Melodic Feline Helmet
    1502000387, -- Squeakology Helmet
    1502000388, -- Wasteland Samurai Helmet
    1502000389, -- Shrine Keeper Helmet
    1502000390, -- Lover's Barrier Helmet
    1502000391, -- Dr. Quirk Helmet
    1502000392, -- Bio Scout Helmet
    1502000393, -- Soundwave Beast Helmet
    1502000394, -- Shadow Empress Helmet
    1502000395, -- Night Maiden Helmet
    1502000396, -- Lieutenant Chaos Helmet
    1502000397, -- Galadria Helmet
    1502000398, -- Rippling Charm Helmet
    1502000400, -- Moody Clownfish Helmet
    1502000401, -- Spiny Bite Helmet
    1502000402, -- APEACH Helmet
    1502000403, -- Bellygom Helmet
    1502000404, -- Manic Bunny Helmet
    1502000405, -- Chaos Academy Helmet
    1502000406, -- Heart Warden Helmet
    1502000407, -- Lightcore Helmet
    1502000408, -- Piercing Fang Helmet
    1502000409, -- Cosmic Beast Helmet
    1502000410, -- Feral Ravager Helmet
    1502000411, -- Spirit Sentry Helmet
    1502000412, -- Underworld Aristocrat Helmet
    1502000413, -- Quasar Clan Helmet
    1502000414, -- Winter Warrior Helmet
    1502000415, -- Hypernova Fission Helmet
    1502000416, -- 2024 PMGC Helmet
    1502000417, -- Penguin Pal Helmet
    1502000418, -- Wintry Aegis Helmet
    1502000419, -- Blue Bewitchment Helmet
    1502000420, -- Rimuru Helmet
    1502000421, -- Dreamy Koi Helmet
    1502000422, -- New Age Channeler Helmet
    1502000423, -- Dragontide Pulse Helmet
    1502000424, -- Prowling Lion Head Helmet
    1502000425, -- Inky Allure Helmet
    1502000426, -- Elysian Bloom Helmet
    1502000427, -- Opanchu Helmet
    1502000428, -- Netherbound Rider Helmet
    1502000429, -- Ecliptic Guardian Helmet
    1502000430, -- Lazy Chomper Helmet
    1502000431, -- Godzilla Chomp Helmet
    1502000432, -- Foxie Moxie Helmet
    1502000433, -- Sinister Bunny Helmet
    1502000434, -- Goldensands Sentry Helmet
    1502000435, -- Galvanic Judge Helmet
    1502000436, -- Clockwork Pal Helmet
    1502000437, -- Caramel Cat Helmet
    1502000438, -- Chemical Clash Helmet
    1502000439, -- Auric Reign Helmet
    1502000440, -- War Hammer Titan Helmet
    1502000441, -- Deepsea Maw Helmet
    1502000442, -- Steamwork Artisan Helmet
    1502000443, -- Waveform Frenzy Helmet
    1502000444, -- Hero Xtreme Helmet
    1502000445, -- Graviton Sentinel Helmet
    1502000446, -- Astral Anomaly Helmet
    1502000447, -- Goldline Ace Helmet
    1502000448, -- Draconic Aegis Helmet
    1502000449, -- Nebula Valkyrie Helmet
    1502000450, -- Captain Woof Helmet
    1502000451, -- Luminarch Watcher Helmet
    1502000452, -- Bbangbbang's diary Helmet
    1502000453, -- 2025 Esports Helmet
    1502000454, -- Ribclad Reaper Helmet
    1502000455, -- Saccharine Riot Helmet
    1502000456, -- Graffiti Vandal Helmet
    1502000457, -- Kaiju No. 8 Helmet
    1502000458, -- Nebulight Drift Helmet
    1502000459, -- Havoc Horns Helmet
    1502000460, -- Madcap Punk Helmet
    1502000461, -- Chromacore Pulse Helmet
    1502000462, -- Spectral Dreamweaver Helmet
    1502000463, -- Chocobear Delight Helmet
    1502000464, -- Snowward Stranger Helmet
    1502000465, -- Yarn Beast Helmet
    1502000466, -- Faux Fur Helmet
    1502000467, -- Whiteout Apex Helmet
    1502000468, -- Blizzard Party Helmet
    1502000469, -- Polar Wonderland Helmet
    1502000470, -- Snowfeather Sapphire Helmet
    1502000471, -- Turbo Granny(Beckoning cat) Helmet
    1502000473, -- Noh Mask Ninja Helmet
    1502000474, -- Panda Darling Helmet
    1502000475, -- Dune Prince Helmet
    1502000476, -- Arcade KO Helmet
    1502000477, -- Jade Viper Helmet
    1502000478, -- Fragmented Moon Helmet
    1502000479, -- Lotus Koi Helmet
    1502000480, -- PUBG MOBILE × aespa Helmet
    1502000481, -- CrankGuard Helmet
    1502000482, -- S28 Helmet
    1502000483, -- Jester's Gambit Helmet
    1502000484, -- Gilded Beetle Helmet
    1502000485, -- Punk Vanguard Helmet
    1502000486, -- Jogo Helmet
    1502000487, -- Dynamic Realm Helmet
    1502000488, -- Colorburst Helmet
    1502000489, -- Charming Defender Helmet
    1502000490, -- Nakiri Ayame Helmet
    1502000491, -- S29 Helmet
    1502000492, -- Mirage Phantom Helmet
    1502000493, -- Queen of Suits Helmet
    1502000494, -- Legendary Noble Helmet
    1502000495, -- Jigsaw Puzzle Helmet
    1502000496, -- Speed Rush Helmet
    1502000497, -- Dioscuri Helmet
    1502000498, -- Serpent Handler Helmet
    1502000499, -- Bloodfeather Spartan Helmet
    1502000500, -- Laurel Academy Helmet
    1502000501, -- Field Frenzy Helmet
    1502000502, -- Lightning Visor Helmet
    1502000503, -- Psionic Electrobolt Helmet
    1502000504, -- S30 Helmet
    1502000505, -- Cybernetic Samurai Helmet
    1502000506, -- Nightfall Stalker Helmet
    1502000507, -- Pink Bunny Cadet Helmet
    1502000508, -- Pakkun Helmet
    1502000509, -- Sakura Neko Helmet
    1502000510, -- Sacred Grove Helmet
    1502000511, -- Wave Cascade Helmet
    1502000512, -- Dimension Guardian Helmet
    1502000515, -- Meow Fuzzster Helmet
    1505000002, -- White Rabbit Helmet
    1505000004, -- Neon Punk Helmet (Purple)
    1505000006, -- Sanguine Helmet
    1505000008, -- Winning Chicken Helmet
    1505000009, -- PUBLING Helmet
    1505000013, -- Chicken Champion Helmet
    1505000014, -- Inferno Rider Helmet
    1505000015, -- Sunflower Helmet
    1505000016, -- Stegosaurus Helmet
    1505000018, -- Angry Pumpkin Helmet
    1505000020, -- Happy Pumpkin Helmet

    -- ==========================================================================
    -- BACKPACKS SKINS
    -- ==========================================================================
    1501000019, -- Bag Lunch Backpack
    1501000026, -- Silly Chicken Backpack
    1501000027, -- Sanguine Backpack
    1501000028, -- Master of the Land Backpack
    1501000029, -- Outing Backpack
    1501000030, -- Nutcracker Backpack
    1501000031, -- Yeti Backpack
    1501000032, -- Cuddly Panda Backpack
    1501000034, -- Naughty Christmas Backpack
    1501000035, -- Urban Scavenger Backpack
    1501000036, -- Silly Reindeer Backpack
    1501000037, -- MOMMYSON Backpack
    1501000038, -- Jungle Predator Backpack
    1501000039, -- Bling Backpack
    1501000041, -- Cherubic Angel Backpack
    1501000042, -- Invader Backpack
    1501000043, -- Illusion Judge Backpack
    1501000044, -- Anniversary Backpack
    1501000045, -- Brilliant Anniversary Backpack
    1501000046, -- Red Armored Backpack
    1501000047, -- Butterfly Wings Backpack
    1501000048, -- Star Trooper Backpack
    1501000051, -- The Fool Backpack
    1501000052, -- Pitch Master Backpack
    1501000053, -- Draconian Champion Backpack
    1501000054, -- Expedition Backpack
    1501000055, -- Sea Turtle Backpack
    1501000056, -- Wanderer Backpack
    1501000057, -- Ryan Backpack
    1501000058, -- BAPE X PUBGM CAMO Backpack
    1501000059, -- Extreme Adventure Backpack
    1501000060, -- Battlefield Geek Backpack
    1501000061, -- Godzilla Backpack
    1501000062, -- King Ghidorah Backpack
    1501000063, -- Spirit of red and white backpack
    1501000064, -- Chick Princess Backpack
    1501000065, -- Monster Backpack
    1501000066, -- Dolphin Backpack
    1501000067, -- Squid Squad Backpack
    1501000068, -- Victory Lap Backpack
    1501000069, -- Hungry Shark Backpack
    1501000070, -- Milky Way Backpack
    1501000071, -- Bloody Knife Backpack
    1501000072, -- Explorer's Backpack
    1501000073, -- Sailing Ape Backpack
    1501000074, -- Smiling Pal Backpack
    1501000075, -- Sad Pal Backpack
    1501000076, -- Clever Pal Backpack
    1501000077, -- Amorous Pal Backpack
    1501000078, -- Fan Backpack
    1501000079, -- Moon Bunny Backpack
    1501000081, -- Angel Wings Backpack
    1501000082, -- Black Tortoise Defender Backpack
    1501000083, -- Legend of the Fjord Backpack
    1501000084, -- Demigod Gladiator Backpack
    1501000085, -- Trickling Backpack
    1501000086, -- Blood Rain Backpack
    1501000087, -- Futuristic Streetwear Backpack
    1501000088, -- Black Cat Backpack
    1501000089, -- Irradiated Frog Backpack
    1501000090, -- Mischievous Night Backpack
    1501000091, -- Red Backpack
    1501000092, -- Snow Blush Backpack
    1501000093, -- Arctic Witch Backpack
    1501000094, -- Shadow Soldier Backpack
    1501000095, -- Winter Warmth Backpack
    1501000097, -- Snowflake Girl Backpack
    1501000098, -- Rowdy Red Panda Backpack
    1501000099, -- Ninja Kitty Backpack
    1501000100, -- Blood Lotus Backpack
    1501000101, -- Field Commander Backpack
    1501000102, -- The Pummeler Backpack
    1501000103, -- Forest Ninja Backpack
    1501000104, -- Sleepy Slug Backpack
    1501000105, -- Amphibian Hunter Backpack
    1501000107, -- Will of Horus Backpack
    1501000108, -- Cherry Blossom Backpack
    1501000109, -- Savage Psycho Backpack
    1501000110, -- Honeycomb Backpack
    1501000112, -- Angry King Pig Backpack
    1501000114, -- Wasteland Survivor Backpack
    1501000115, -- Golden Eagle Backpack
    1501000116, -- Sweet Treats Backpack
    1501000118, -- 8-bit Unicorn Backpack
    1501000119, -- COVERNAT Backpack
    1501000120, -- Buskin' Monkey Backpack
    1501000122, -- Frog Prince Backpack
    1501000123, -- Lieutenant Parsec Backpack
    1501000125, -- Midnight Angel Backpack
    1501000126, -- Wings of Dawn Backpack
    1501000127, -- Wings of Fantasy Backpack
    1501000128, -- Iridescent Feathers Backpack
    1501000129, -- Poker King Backpack
    1501000130, -- Fortune Teller Backpack
    1501000131, -- Purple Witch Doctor Backpack
    1501000132, -- Puppy Love Backpack
    1501000133, -- Bloodthirsty Joker Backpack
    1501000134, -- Fortune Kitty Backpack
    1501000135, -- Gambling Master Backpack
    1501000136, -- Stealth Agent Backpack
    1501000137, -- Cute Animal Backpack
    1501000140, -- Winged Elephant Backpack
    1501000141, -- I SEE YOU Backpack
    1501000142, -- Ragtag Goon Backpack
    1501000143, -- Dazzling Youth Backpack
    1501000144, -- Cute Kitten Backpack
    1501000145, -- Captain Pengyoo Backpack
    1501000146, -- Sparkly Universe Backpack
    1501000147, -- Crispy Chicken Backpack
    1501000149, -- Firefighter Backpack
    1501000150, -- Mechforged Backpack
    1501000151, -- Podium Placer Backpack
    1501000153, -- Sticky Rice Dumpling Backpack
    1501000154, -- Nightmare Backpack
    1501000155, -- Dino Park Backpack
    1501000156, -- Sugar Rush Backpack
    1501000157, -- Lion's Claw Backpack
    1501000158, -- Matryoshka Doll Backpack
    1501000160, -- Ladybug Backpack
    1501000161, -- Alloy Armor Backpack
    1501000162, -- Gourmet Diner Backpack
    1501000163, -- Vivid Star Backpack
    1501000164, -- Crocodile Backpack
    1501000165, -- Stars & Stripes Backpack
    1501000166, -- Samurai Ops Backpack
    1501000168, -- Golden Nights Backpack
    1501000169, -- Persian Warrior Backpack
    1501000170, -- Tricky Fox Backpack
    1501000171, -- Pink Plume Backpack
    1501000172, -- Gold and Silk Backpack
    1501000173, -- Retro Police Backpack
    1501000174, -- Pharaoh's Regalia Backpack
    1501000175, -- Victorian Maiden Backpack
    1501000176, -- Doggy Cabin Backpack
    1501000177, -- Fox Skull Backpack
    1501000178, -- Eerie Doll Backpack
    1501000179, -- Wraith Lord Backpack
    1501000180, -- Snowflake Fairy Backpack
    1501000182, -- Hallows' Eve Backpack
    1501000183, -- Gothic Lady Backpack
    1501000185, -- Red Racecar Knight Backpack
    1501000187, -- Taiyaki Backpack
    1501000188, -- Resplendent Dawn Backpack
    1501000189, -- Homestead Protector Backpack
    1501000190, -- Xiqu Backpack
    1501000191, -- Arena Champion Backpack
    1501000193, -- Underworld Sovereign Backpack
    1501000194, -- Skeleton Knight Backpack
    1501000195, -- Lady of Blood Backpack
    1501000196, -- Leopard Print Backpack
    1501000197, -- Witch Coven Backpack
    1501000198, -- Dauntless Backpack
    1501000199, -- Cactus Sheriff Backpack
    1501000200, -- Fantasy City Backpack
    1501000201, -- Tulip Backpack
    1501000202, -- Nut Protector Backpack
    1501000204, -- Dream Idol Backpack
    1501000205, -- Jolly Snowman Backpack
    1501000206, -- Bewitching Enchantress Backpack
    1501000207, -- Acolyte of Justice Backpack
    1501000209, -- Vintage Clockwork Backpack
    1501000210, -- Thorn Trooper Backpack
    1501000211, -- Punk Rhino Backpack
    1501000212, -- Dracoguard Backpack
    1501000213, -- Dayman Backpack
    1501000215, -- Keep Out Backpack
    1501000216, -- Winter Queen Backpack
    1501000217, -- Snowwoman Backpack
    1501000220, -- Blood Raven Backpack
    1501000221, -- Lady Butterfly Backpack
    1501000222, -- Heart of the Sea Backpack
    1501000224, -- Modern Lord Backpack
    1501000225, -- Nutcracker King Backpack
    1501000226, -- Ghillie Lion Backpack
    1501000227, -- Bestial Aurum Backpack
    1501000229, -- Kiss emoji Backpack
    1501000231, -- Bard Backpack
    1501000233, -- Techno Sensation Backpack
    1501000236, -- Homeland Backpack
    1501000237, -- Chromatic Brilliance Backpack
    1501000238, -- Gemstone Scarab Backpack
    1501000239, -- Butterfly Buddies Backpack
    1501000240, -- Silly Kitten Backpack
    1501000241, -- Cherry Crystal Backpack
    1501000242, -- Mystic Artificer Backpack
    1501000243, -- B.Duck Backpack
    1501000244, -- QUACK Agent Backpack
    1501000245, -- Snow Sakura Backpack
    1501000246, -- Bug Box Backpack
    1501000247, -- Cyber Monkey Backpack
    1501000248, -- Neon Wave Backpack
    1501000249, -- Masked Wasp Backpack
    1501000250, -- Noctus Sovereign Backpack
    1501000251, -- Night Ensemble Backpack
    1501000252, -- Futuristic Hive Backpack
    1501000253, -- Banana Bonanza Backpack
    1501000258, -- Ice Avenger Backpack
    1501000259, -- Iron Tortoise Backpack
    1501000260, -- Urban Assassin Backpack
    1501000261, -- Dino Brown Backpack
    1501000262, -- Fluorescent Jesterette Backpack
    1501000263, -- Mecha Ant Backpack
    1501000265, -- Poseidon Backpack
    1501000266, -- Sally Backpack
    1501000267, -- Recyclable Backpack
    1501000268, -- Juris Owl Backpack
    1501000269, -- Cute Bazzi Backpack
    1501000270, -- Amazing Journey Backpack
    1501000271, -- Red Battlecat Backpack
    1501000273, -- MECHAGODZILLA Backpack
    1501000274, -- Magenta Skies Backpack
    1501000275, -- Lapis Barrier Backpack
    1501000279, -- Justice Defender Backpack
    1501000280, -- Kegs Up Backpack
    1501000281, -- Electro Bunny Backpack
    1501000282, -- Chicken Delight Backpack
    1501000283, -- Droid Backpack
    1501000286, -- Untamed Magnate Backpack
    1501000287, -- Magic Box Backpack
    1501000288, -- Retro Gamer Backpack
    1501000291, -- Veggie Carton Backpack
    1501000292, -- Oven Fresh Backpack
    1501000293, -- Biometal Backpack
    1501000294, -- Snow Hunter Backpack
    1501000295, -- Savage Totem Backpack
    1501000296, -- Deep Sea Cyscout Backpack
    1501000297, -- Bento Love Backpack
    1501000298, -- Chef's Kit Backpack
    1501000300, -- Sweet Raccoon Backpack
    1501000301, -- Tender Cactus Backpack
    1501000302, -- Mushroom Buddy Backpack
    1501000303, -- ADIDAS Backpack
    1501000304, -- Demon Guise Backpack
    1501000305, -- Past Relics Backpack
    1501000306, -- Riot Handler Backpack
    1501000307, -- Austere Gold Backpack
    1501000308, -- Cheesy Backpack
    1501000309, -- Spectral Scanner Backpack
    1501000310, -- Pixelated Dinosaur Backpack
    1501000311, -- Crystal Casket Backpack
    1501000312, -- Merry Tank Backpack
    1501000314, -- Amphibian Wings Backpack
    1501000316, -- Merry Tidings Backpack
    1501000317, -- Wintry Ruler Backpack
    1501000318, -- Majestic Cavalry Backpack
    1501000320, -- Aurous Elegance Backpack
    1501000321, -- GACKT MOONSAGA Backpack
    1501000323, -- Dazed Cat Backpack
    1501000324, -- Snow Pixie Backpack
    1501000325, -- Liverpool FC Backpack
    1501000326, -- Rabbit Plushie Backpack
    1501000330, -- Extreme Athlete Backpack
    1501000331, -- Jinx's  Backpack
    1501000332, -- Hextech Crystal Backpack
    1501000333, -- Gundala Backpack
    1501000336, -- Alfheim Wonder Backpack
    1501000337, -- Dive-A-Tron Backpack
    1501000338, -- Sweet Tiggy Backpack
    1501000339, -- Winter Bunny Backpack
    1501000340, -- Snowy Seal Backpack
    1501000341, -- Sweet Cub Backpack
    1501000342, -- Adorbs Baddie Backpack
    1501000343, -- Baby Dragon Backpack
    1501000344, -- Capsule Toy Backpack
    1501000345, -- Roguish Imp Backpack
    1501000346, -- Bunny Friends Backpack
    1501000348, -- Pixel Bolt Backpack
    1501000349, -- Lost Civilization Backpack
    1501000350, -- Blissful Backpack
    1501000351, -- Snowcapped Berg Backpack
    1501000352, -- Future Fuel Backpack
    1501000354, -- Steampunk Herbalist Backpack
    1501000355, -- Nebula Visitor Backpack
    1501000356, -- Hungry Vine Backpack
    1501000357, -- Demonic Orb Backpack
    1501000359, -- Spiky Carry Backpack
    1501000361, -- Wasteland Explorer Backpack
    1501000362, -- Twilight Vigilante Backpack
    1501000363, -- Jack-In-The-Box Backpack
    1501000364, -- Munchkin Bearbox Backpack
    1501000366, -- Cheeky Cat Backpack
    1501000367, -- Jelly Bear Backpack
    1501000368, -- Cute Bunny Backpack
    1501000369, -- Opulence Backpack
    1501000370, -- Ursa Hunter Backpack
    1501000371, -- Tiger's Roar Backpack
    1501000372, -- Stellar Sense Backpack
    1501000373, -- Cutie Shark Backpack
    1501000374, -- School Special Backpack
    1501000375, -- Vibrant Celebration Backpack
    1501000376, -- Vintage Record Backpack
    1501000377, -- Emerald Soul Backpack
    1501000378, -- Punk Shark Backpack
    1501000380, -- Lovey-Dovey Backpack
    1501000381, -- Masameer's Trad Backpack
    1501000383, -- Emerald Power Backpack
    1501000384, -- Underwraith Backpack
    1501000385, -- Mechanized Era Backpack
    1501000387, -- Evangelion-01 Backpack
    1501000388, -- Razor Edge Backpack
    1501000389, -- Cute Stroll Backpack
    1501000390, -- Gilded Flower Backpack
    1501000391, -- Polar Fluff Backpack
    1501000392, -- Adorable Ghost Backpack
    1501000393, -- Cute Manta Ray Backpack
    1501000394, -- Starry Wishes Backpack
    1501000395, -- Fine Leather Backpack
    1501000396, -- Gemshell Backpack
    1501000397, -- Steampunk Captain Backpack
    1501000398, -- Imperial Emblem Backpack
    1501000399, -- Time Bomb Backpack
    1501000400, -- Baby Shark Backpack
    1501000401, -- Forest Tribe Backpack
    1501000402, -- Cool Critter Backpack
    1501000408, -- Fishing Legend Backpack
    1501000409, -- Cursed Heir Backpack
    1501000410, -- Submarine Backpack
    1501000411, -- Flamewraith Backpack
    1501000412, -- Treasure Casket Backpack
    1501000414, -- Winged Ascent Backpack
    1501000415, -- Fiery Wings Backpack
    1501000416, -- Vending Machine Backpack
    1501000417, -- Butterfinger Backpack
    1501000418, -- Red, White and Ready Backpack
    1501000419, -- Payback Backpack
    1501000420, -- Dino Egg Backpack
    1501000421, -- Bony Bunny Backpack
    1501000422, -- Bramble Overlord Backpack
    1501000423, -- CyberGen: Zero Backpack
    1501000424, -- Markhor Backpack
    1501000425, -- First Love Backpack
    1501000426, -- Lil Burger Backpack
    1501000430, -- Bone Gala Backpack
    1501000433, -- Frilly Ribbon Backpack
    1501000437, -- Mutant Warlord Backpack
    1501000441, -- Clown Cannon Backpack
    1501000443, -- Luminous Galaxy Backpack
    1501000444, -- Royal Apparel Backpack
    1501000446, -- Super Corn Backpack
    1501000448, -- Secret Legacy Backpack
    1501000451, -- Floral Bouquet Backpack
    1501000452, -- Basta Backpack
    1501000453, -- Dino Trooper Backpack
    1501000454, -- Potion Master Backpack
    1501000457, -- Ancient Civilization Backpack
    1501000458, -- Sweet Bunny Backpack
    1501000459, -- Stern Kitty Backpack
    1501000462, -- Yak Warrior Backpack
    1501000463, -- BoBoiBoy Backpack
    1501000466, -- Mystique Splendor Backpack
    1501000467, -- Draco Rascal Backpack
    1501000468, -- Cuddly Bear Backpack
    1501000469, -- Floral Snowflake Backpack
    1501000471, -- Aquatic Fury Backpack
    1501000474, -- Digiwolf Backpack
    1501000475, -- Ultimate Predator Backpack
    1501000476, -- Messi Football Icon Backpack
    1501000478, -- Cha-Ching Backpack
    1501000479, -- Mithu Tota Backpack
    1501000480, -- Indomie Taste of the Nation Backpack
    1501000481, -- Viet Indie Prince Astronaut Backpack
    1501000482, -- Kooky Creature Backpack
    1501000483, -- Cardboard Dino Backpack
    1501000484, -- Fortified Arms Backpack
    1501000485, -- Rabbit Sprite's Carrot Backpack
    1501000486, -- Red Tuxedo Backpack
    1501000487, -- Deadly Glare Backpack
    1501000489, -- Sinister Ghoulie Backpack
    1501000490, -- Clockwork Ursa Backpack
    1501000492, -- Bling Cat Backpack
    1501000494, -- Rising Rebel Backpack
    1501000495, -- Bunny Lover Backpack
    1501000496, -- Pixel Kitty Backpack
    1501000497, -- Sealed Case Backpack
    1501000500, -- Defiant Defense Backpack
    1501000501, -- Stray Rebellion Backpack
    1501000502, -- Deluxe Treasure Backpack
    1501000503, -- Silver Guru Backpack
    1501000506, -- Lucky Cat Backpack
    1501000507, -- Mousy Knockout Backpack
    1501000509, -- Radiant Ram Backpack
    1501000510, -- Handicraft Backpack
    1501000511, -- Ocean Treasury Backpack
    1501000512, -- Seafoam Assassin Backpack
    1501000513, -- Cuddly Seahorse Backpack
    1501000514, -- Lucky Panda Backpack
    1501000515, -- Bloodstained Nemesis Backpack
    1501000516, -- Pink Sweetie Backpack
    1501000517, -- Cucumber Genius Backpack
    1501000519, -- Flipped Bear Backpack
    1501000520, -- Goldfinch Backpack
    1501000521, -- Kamesennin's Turtle Shell Backpack
    1501000522, -- Customer Basket Backpack
    1501000523, -- Palace Guard Backpack
    1501000524, -- Swift Mirage Backpack
    1501000525, -- Bunny Munchkin Backpack
    1501000526, -- Rave Critter Backpack
    1501000527, -- Picnic Weave Backpack
    1501000528, -- Biohazard Backpack
    1501000529, -- Falcon Totem Backpack
    1501000530, -- Capsule Backpack
    1501000531, -- Seadrake Champion Backpack
    1501000532, -- Batblitz Backpack
    1501000533, -- Retro Rhapsody Backpack
    1501000534, -- Juicebox Backpack
    1501000535, -- Gulping Gull Backpack
    1501000536, -- Vinyl Wave Backpack
    1501000537, -- Boxerbolt Backpack
    1501000538, -- Panthera Prime Backpack
    1501000539, -- 2023 PMGC Backpack
    1501000540, -- Royale Delight Backpack
    1501000541, -- Classified Label Backpack
    1501000542, -- Rubific Backpack
    1501000543, -- Mousetech Backpack
    1501000544, -- Avian Charmer Backpack
    1501000546, -- Elysian Vault Backpack
    1501000547, -- Bony Totem Backpack
    1501000548, -- Ancient Eon Backpack
    1501000549, -- Foxy Flare Backpack
    1501000550, -- Frosty Snowglobe Backpack
    1501000551, -- Fiestafeast Backpack
    1501000552, -- Ebil Bunny Backpack
    1501000553, -- Cupid Strike Backpack
    1501000554, -- LINE FRIENDS SALLY Backpack
    1501000555, -- Rosy Riding Hood Backpack
    1501000556, -- Inkstripe Tiger Backpack
    1501000557, -- Lovestruck Teddy Backpack
    1501000558, -- Shinobi Spirit Backpack
    1501000559, -- Serpengleam Backpack
    1501000560, -- Gilded Glaze Backpack
    1501000561, -- Cheeky Romance Backpack
    1501000562, -- Chic Owl Backpack
    1501000563, -- Zanmang Loopy Backpack
    1501000564, -- Aetherial Azure Backpack
    1501000565, -- Auric Guardian Backpack
    1501000566, -- Royal Rogue Backpack
    1501000567, -- Ignis Backpack
    1501000568, -- Magick Delight Backpack
    1501000569, -- Gallant Jockey Backpack
    1501000570, -- Origin Lumen Backpack
    1501000571, -- Luminous Muse Backpack
    1501000572, -- Bygone Realm Backpack
    1501000573, -- Bunny Dessert Backpack
    1501000575, -- Gearpunk Backpack
    1501000576, -- Shrine Keeper Backpack
    1501000577, -- Feathered Nobility Backpack
    1501000578, -- Iron Warden Backpack
    1501000579, -- Dr. Quirk Backpack
    1501000581, -- Mercury Soldier Backpack
    1501000582, -- Neon Vessel Backpack
    1501000583, -- Pulsebox Backpack
    1501000584, -- Soundwave Beast Backpack
    1501000585, -- Darling Hedgehog Backpack
    1501000586, -- Night Maiden Backpack
    1501000587, -- Lieutenant Chaos Backpack
    1501000588, -- Galadria Backpack
    1501000589, -- Ancient Colossus Backpack
    1501000590, -- Rippling Charm Backpack
    1501000591, -- Serene Lumina Backpack
    1501000592, -- Ghostly Snare Backpack
    1501000593, -- Octosurprise Backpack
    1501000594, -- Amphibious Sage Backpack
    1501000595, -- APEACH Backpack
    1501000596, -- Choonsik Backpack
    1501000597, -- Bellygom Backpack
    1501000598, -- Anjat Backpack
    1501000599, -- Manic Bunny Backpack
    1501000600, -- Chaos Academy Backpack
    1501000601, -- Heart Warden Backpack
    1501000602, -- Pocong Wanderer Backpack
    1501000603, -- Zooming Backpack
    1501000604, -- Paranormal Feline Backpack
    1501000605, -- Blackthorn Specter Backpack
    1501000606, -- Cosmic Beast Backpack
    1501000607, -- Vampiric Compulsion Backpack
    1501000608, -- Brimstone Demise Backpack
    1501000609, -- Spirit Sentry Backpack
    1501000610, -- Underworld Aristocrat Backpack
    1501000611, -- Winter Warrior Backpack
    1501000612, -- Hypernova Fission Backpack
    1501000613, -- Frosty Wildwood Backpack
    1501000614, -- Skadiwynn Sentinel Backpack
    1501000615, -- Royal Deeress Backpack
    1501000616, -- PMGC × ROLLIO Backpack
    1501000617, -- Penguin Pal Backpack
    1501000618, -- Frostblade Snow Backpack
    1501000619, -- Magical Charm Backpack
    1501000620, -- Tundra Knight Backpack
    1501000621, -- Darkrose Crystal Backpack
    1501000622, -- Rimuru Backpack
    1501000623, -- Crate Glutton Backpack
    1501000624, -- Dragontide Pulse Backpack
    1501000625, -- Serpent's Treasure Backpack
    1501000626, -- Gold Feather Mask Backpack
    1501000627, -- Prowling Lion Head Backpack
    1501000628, -- Ink Library Backpack
    1501000629, -- Celestine Charm Backpack
    1501000630, -- Deep Nocturne Backpack
    1501000631, -- Elysian Bloom Backpack
    1501000632, -- Opanchu Backpack
    1501000634, -- Ecliptic Guardian Backpack
    1501000635, -- Lazy Chomper Backpack
    1501000636, -- Neon Renegade Backpack
    1501000637, -- Godzilla King of the Monsters Backpack
    1501000638, -- Foxie Moxie Backpack
    1501000639, -- Serpent's Relic Backpack
    1501000640, -- Corrupted Crown Backpack
    1501000641, -- Sinister Bunny Backpack
    1501000642, -- Goldensands Sentry Backpack
    1501000645, -- Steam Paws Backpack
    1501000647, -- Skateboard Streak Backpack
    1501000648, -- Scarlet Momentum Backpack
    1501000649, -- Aetherflare Essence Backpack
    1501000650, -- Colossal Titan Backpack
    1501000651, -- Frostblue Fang Backpack
    1501000652, -- Bloodcurse Core Backpack
    1501000653, -- Glitchwave Shift Backpack
    1501000654, -- Mad Lab Backpack
    1501000657, -- Astral Anomaly Backpack
    1501000658, -- Goldline Ace Backpack
    1501000659, -- Cuddly Nailoong Backpack
    1501000660, -- Destiny's Embrace Backpack
    1501000661, -- Draconic Vault Backpack
    1501000662, -- Nebula Valkyrie Backpack
    1501000663, -- Prism Pod Backpack
    1501000664, -- Sinkeeper's Coffer Backpack
    1501000665, -- Captain Woof Backpack
    1501000666, -- Starweld Engine Backpack
    1501000667, -- Bbangbbang's diary Backpack
    1501000669, -- Saccharine Riot Backpack
    1501000670, -- Boxing Brawl Backpack
    1501000671, -- Kaiju No. 8 Backpack
    1501000672, -- Stellarwing Flutter Backpack
    1501000673, -- Highstreet Haze Backpack
    1501000674, -- Cotton Carnage Backpack
    1501000675, -- Madcap Punk Backpack
    1501000676, -- Specter Shrine Backpack
    1501000677, -- Talisdrake Rift Backpack
    1501000678, -- Colorburst Candy Backpack
    1501000679, -- Spectral Dreamweaver Backpack
    1501000681, -- Captain Cub Backpack
    1501000682, -- Yarn Knight Backpack
    1501000683, -- Balenciaga Backpack
    1501000684, -- Whiteout Apex Backpack
    1501000685, -- Onyxis Witch Backpack
    1501000686, -- Blizzard Party Backpack
    1501000687, -- Deathknell Shroud Backpack
    1501000688, -- Polar Prism Backpack
    1501000689, -- Snowy Weasel Backpack
    1501000690, -- Melodic Crown Backpack
    1501000691, -- Turbo Granny(Beckoning cat) Backpack
    1501000692, -- Bamboo Treat Backpack
    1501000693, -- Dune Prince Backpack
    1501000694, -- Locked & Loaded Backpack
    1501000695, -- Arcade KO Backpack
    1501000696, -- Veiled Enchantress Backpack
    1501000697, -- Celadon Aether Backpack
    1501000698, -- Well of Souls Backpack
    1501000699, -- Mystic Seal Backpack
    1501000700, -- Fragmented Moon Backpack
    1501000701, -- Auspicious Coffer Backpack
    1501000703, -- Peaky Blinders Backpack
    1501000704, -- S28 Backpack
    1501000705, -- Twirling Sands Backpack
    1501000706, -- Punk Vanguard Backpack
    1501000707, -- Prison Realm Backpack
    1501000708, -- Coldsteel Hacker Backpack
    1501000709, -- Dynamic Realm Backpack
    1501000710, -- Delicate Dance Backpack
    1501000711, -- Multiverse Traveler Backpack
    1501000712, -- Eternal Vigil Backpack
    1501000713, -- Arcade Kitty Backpack
    1501000714, -- Catch! Teenieping Graceping Backpack
    1501000715, -- SAKAMOTO TARO Backpack
    1501000716, -- Nakiri Ayame Backpack
    1501000717, -- S29 Backpack
    1501000718, -- Queen of Suits Backpack
    1501000719, -- Legendary Noble Backpack
    1501000720, -- BLUE LOCK Backpack
    1501000721, -- Speed Rush Backpack
    1501000722, -- Rose Requiem Backpack
    1501000723, -- Mimic Jester Backpack
    1501000724, -- Dioscuri Backpack
    1501000725, -- Serpent Handler Backpack
    1501000726, -- Wrath of Retribution Backpack
    1501000727, -- Temptuous Whisper Backpack
    1501000728, -- Laurel Academy Backpack
    1501000729, -- Field Frenzy Backpack
    1501000730, -- Usada Pekora Backpack
    1501000733, -- S30 Backpack
    1501000734, -- Nightfall Stalker Backpack
    1501000735, -- Pink Bunny Cadet Backpack
    1501000736, -- Atlantean Ranger Backpack
    1501000737, -- Track Legend Backpack
    1501000738, -- Ferrari Backpack
    1501000739, -- Tide Tracker Backpack
    1501000740, -- Sakura Neko Backpack
    1501000741, -- Sanctuary Traveler Backpack
    1501000742, -- NARUTO Ninja Scroll Backpack
    1501000743, -- Tempting Nest Backpack
    1501000744, -- Wave Cascade Backpack
    1501000745, -- Dimensional Armory Backpack
    1501000749, -- Meow Fuzzster Backpack
    1501000303, -- ADIDAS Backpack
    1504000008, -- Red & Black Backpack
    1504000015, -- Pink Bear Backpack
    1504000020, -- Rugged Backpack
    1504000022, -- Trickster Backpack
    1504000023, -- Night Fright Backpack
    1504000024, -- Count Backpack
    1504000025, -- Turkey Feast Backpack
    1504001021, -- Shiny Silver Backpack

    -- ADDITIONAL IDs
    1405128, 1405129, 140224445, -- Crew
    1407961, 1407962, 1407963, 1407964, 1407965, 1407966, 1407967, 1407968, 1407969, 1407970, 1407971, 1411134, 1411133, 1411135, 1403771, 1403770, 1407994, 1407993, 1101006106, 1101006098, 4151145, 1903230, 1903231, 1903232, 1908117, 1908118, 1908119, 19116002, 19116003, 19116004, 1961070, 1961071, 1961072, 1961073, 1408045, 1408038, 1407990,1407922, -- Love Goddess Outfit
    1407704, -- Mischievous Bride Outfit
    1400782, -- Snow Costume
    1407614, -- Optimus Prime Transformers Outfit
    1407276, -- Love Guardian Outfit
    1410356, -- Blood Soul Demon Mask
    40605012, -- Twin Bun Hair
    -- ==============================================================================
    -- LOBBY / THEME
    -- ==============================================================================
    202408125, -- Phantasia Siren Theme
    202408087, -- Luxury Drive Space
    202408061, -- Auto Showroom
    202408014, -- Resort Theme
    202408035, -- Monument Tour Theme
    202408037, -- Strange Town Theme
    202408039, -- Street Art Theme
    202408040, -- Cyberpunk Hangar Theme
    202408042, -- Champion Theme
    202408043, -- Pitch Paradise Theme
    202408044, -- Brilliant Winter
    202408045, -- Martial Arts Contest Theme
    202408046, -- Valentines Island Theme
    202408047, -- Moonlight Bazaar
    202408048, -- World of Wonder Theme
    202408049, -- Dino Island Theme
    202408050, -- World Martial Arts Tournament
    202408051, -- Sapphire Coast Lobby Theme
    202408053, -- Wasted Land Theme
    202408054, -- Midnight Circus Theme
    202408055, -- Chrono Portal Theme
    202408056, -- Champion Theme
    202408057, -- Civilization Wonder Lobby Theme
    202408058, -- Glacial Castle Lobby Theme
    202408059, -- Dragon Abode Theme
    202408060, -- Shinobi Warzone Theme
    202408062, -- One Thousand and One Nights Lobby Theme
    202408063, -- City in the Sky Lobby Theme
    202408064, -- India 3.1 Lobby
    202408065, -- One Thousand and One Nights Lobby Theme
    202408066, -- Mecha Warship Theme
    202408067, -- Devious Cybercat Theme
    202408068, -- Lightshift Temple Theme
    202408069, -- Devious Chromacat Theme
    202408076, -- Mysterious Manor Theme
    202408077, -- Lupine Heights Theme
    202408078, -- Beyond Underworld Theme
    202408079, -- Poseidon's Trident Theme
    202408080, -- 2024 PMGC Theme
    202408081, -- Frostbound Kingdom Theme
    202408082, -- Arctic Era Theme
    202408083, -- Ice Witch Theme
    202408084, -- Imperial Palace Theme
    202408085, -- Eternal Citadel Theme
    202408086, -- Ethereal Brush Theme
    202408088, -- Duneshine Theme
    202408089, -- Eternal Dunes Theme
    202408090, -- Sands of Fortune Theme
    202408091, -- Cogwheel Express Theme
    202408092, -- Gearbound Steamliner Theme
    202408093, -- Neonforge Metropolis Theme
    202408094, -- Imperial Pair Theme
    202408095, -- Spaceport Hub Theme
    202408096, -- Starship Port Theme
    202408097, -- Milky Way Expanse Theme
    202408098, -- Phantom Courtyard Theme
    202408099, -- Enchanted Terrace Theme
    202408100, -- Folded Mirage Theme
    202408101, -- Astral Reverie Theme
    202408102, -- Halloweeks Eve Theme
    202408103, -- Icy World Theme
    202408104, -- First Snow Party Theme
    202408105, -- Frigid Fairytale Theme
    202408106, -- Frontier Stronghold Theme
    202408107, -- 2025 PMGC Theme
    202408108, -- Forest City Theme
    202408109, -- Rootspring Theme
    202408110, -- Great Tree Theme
    202408111, -- Nature Temple Theme
    202408112, -- Bay Exclusion Zone Theme
    202408113, -- Dynamic Venue Theme
    202408114, -- Sound Wave Club Theme
    202408115, -- Virtual Realm Theme
    202408116, -- Bay Exclusion Zone Theme
    202408117, -- Olympus Realm Theme
    202408118, -- Mortal City Theme
    202408119, -- Dawn Sanctuary Theme
    202408120, -- Love Cloud Terrace Theme
    202408121, -- Twin Star Oracle Theme
    202408122, -- Shinobi Outset Theme
    202408123, -- Shadow Rock Theme
    202408124, -- Fiery Night Valley Theme
    202408126, -- Spider-Man: Brand New Day Theme
    202501011, -- BGMI Anniversary Bash 4.0
}

local INS_BASE = 2000000000
local PKG_SLOT = 3
local MELEE_ID = 108
local HAT_SUB = 401
local MASK_SUB = 402
local OUTFIT_SUB = 403
local PANTS_SUB = 404
local SHOES_SUB = 405
local GLASS_SUB = 407
local GLIDER_SUB = 415      
local GLOVES_SUB = 452
local GLIDER_SUBS = { [413] = true, [414] = true, [415] = true }

F.CUST_SLOT = {
    NONE = 0,
    HeadEquipemtSlot = 1,
    HairEquipemtSlot = 2,
    HatEquipemtSlot = 3,
    FaceEquipemtSlot = 4,
    ClothesEquipemtSlot = 5,
    PantsEquipemtSlot = 6,
    ShoesEquipemtSlot = 7,
    BackpackEquipemtSlot = 8,
    HelmetEquipemtSlot = 9,
    ArmorEquipemtSlot = 10,
    ParachuteEquipemtSlot = 11,
    GlassEquipemtSlot = 12,
    NightVisionEquipemtSlot = 13,
    BeardEquipemtSlot = 14,
    GlideEquipemtSlot = 15,
    HandEffectEquipemtSlot = 16,
    BackPack_PendantSlot = 17,
}
_G.CustSlotType = F.CUST_SLOT

local CHASSIS_LIGHT_SUB = 7302
local CHASSIS_LIGHT_IDS = { [7302001] = true, [7302002] = true }
local DEFAULT_CHASSIS_LIGHT = 7302002
local PARACHUTE_SUB = 701   
local DEFAULT_PARACHUTE_RES = 703001  
local TAB_SUIT = 10
local TAB_CLOTHES = 3
local PAGE_AVATAR = 1
local PAGE_VEHICLE = 6
local PAGE_PARACHUTE = 5
local HALL_THEME_TYPE = 202
local SUBTYPE_DEFAULT_TAB = {
    [401] = 1, [402] = 2, [403] = 10, [404] = 4, [405] = 5, [407] = 14,
    [501] = 15, [504] = 15, [502] = 16, [505] = 16,
}
local HAT_SUBS = { [401] = true }
local HELMET_SUBS = { [502] = true, [505] = true }
local HEAD_SUBS = { [401] = true }
local BAG_SUBS = { [501] = true, [504] = true }
local FACE_SUBS = { [402] = true, [407] = true }
local BODY_SUBS = { [404] = true, [405] = true, [501] = true, [504] = true, [502] = true, [505] = true }
local GUN_SUB = { [101]=true, [102]=true, [103]=true, [104]=true, [105]=true, [106]=true, [107]=true }
local NET_OK = NetErrorCode_NONE or "ok"

local R = { insToRes = {}, resToIns = {}, byWeapon = {} }
local _matchApplied = false

_G.AddOutfitPersist = _G.AddOutfitPersist or { path = nil, dirty = false, scheduled = false, loaded = nil, lastWritten = nil, configVehicleSlots = nil, configWeapons = nil, configSlots = nil, lobbyVehicleSubType = nil, lobbyVehicleIns = nil, lobbyVehicleResID = nil, hallThemeResID = nil, hallThemeIns = nil, configChassisLight = nil, configChassisLightMap = nil }
local PERSIST = _G.AddOutfitPersist

F.persistMarkDirty = function() end

local PERF = {
    lobbySynced     = false,
    mappingsDirty   = true,
    desiredSkins    = nil,
    skinTarget      = {},
    matchActive     = false,
    lastBootstrapAt = 0,
    wearDoneThisMatch = false,  
}
local MATCH_TICK_SEC    = 3.0
local MATCH_MAX_SEC     = 45.0
local BOOTSTRAP_COOLDOWN = 2.0
local INJECT_RETRY_MAX  = 5
local INJECT_RETRY_SEC  = 3.0

function F.lobbyState()
    _G.AddOutfitLobbyState = _G.AddOutfitLobbyState or {
        wardrobeRefreshed = false,
        reapplyScheduled  = false,
        reapplyDone       = false,
        outfitResolved    = false,
        skinResolved      = false,
        cachedOutfit      = nil,
        cachedSkin        = nil,
        injectRefreshGen  = 0,
        lobbySynced       = false,
    }
    return _G.AddOutfitLobbyState
end

local LOBBY = setmetatable({}, {
    __index = function(_, k) return F.lobbyState()[k] end,
    __newindex = function(_, k, v) F.lobbyState()[k] = v end,
})

function F.invalidateLobbyResolved()
    LOBBY.outfitResolved = false
    LOBBY.skinResolved   = false
    LOBBY.cachedOutfit   = nil
    LOBBY.cachedSkin     = nil
end

function F.perfInvalidateLobby()
    LOBBY.lobbySynced   = false
    PERF.mappingsDirty = true
    PERF.desiredSkins  = nil
    for k in pairs(PERF.skinTarget) do PERF.skinTarget[k] = nil end
    F.invalidateLobbyResolved()
end

function F.cache()
    _G.AddOutfitEquippedCache = _G.AddOutfitEquippedCache or {
        outfitRes = nil, outfitIns = nil,
        hatRes = nil, hatIns = nil,
        maskRes = nil, maskIns = nil,
        glassRes = nil, glassIns = nil,
        tshirtRes = nil, tshirtIns = nil,
        pantsRes = nil, pantsIns = nil,
        shoesRes = nil, shoesIns = nil,
        bagRes = nil, bagIns = nil,
        helmetRes = nil, helmetIns = nil,
        weapons = {},
        vehicleSlots = {},  
        hallThemeRes = nil, hallThemeIns = nil,
        parachuteRes = nil, parachuteIns = nil,
        gliderRes = nil, gliderIns = nil,
        glovesRes = nil, glovesIns = nil,
    }
    return _G.AddOutfitEquippedCache
end

function F.cfg(resID)
    if not resID or not CDataTable or not CDataTable.GetTableData then return nil end
    return CDataTable.GetTableData("Item", resID)
end

function F.subType(c)
    return c and (c.ItemSubType or c.itemSubType) or nil
end

function F.wardrobeTab(resID)
    local c = F.cfg(resID)
    return c and tonumber(c.WardrobeTab) or 0
end

function F.depotResID(v)
    return v and tonumber(v.resID or v.res_id) or nil
end

function F.resToCustSlot(resID, st)
    resID, st = tonumber(resID), tonumber(st)
    if not resID or resID <= 0 then return nil end
    st = st or F.subType(F.cfg(resID))
    if st == HAT_SUB or HAT_SUBS[st] then return F.CUST_SLOT.HatEquipemtSlot end
    if st == OUTFIT_SUB then return F.CUST_SLOT.ClothesEquipemtSlot end
    if st == PANTS_SUB then return F.CUST_SLOT.PantsEquipemtSlot end
    if st == SHOES_SUB then return F.CUST_SLOT.ShoesEquipemtSlot end
    if st == MASK_SUB then return F.CUST_SLOT.FaceEquipemtSlot end
    if st == GLASS_SUB then return F.CUST_SLOT.GlassEquipemtSlot end
    if st == GLOVES_SUB then return F.CUST_SLOT.HandEffectEquipemtSlot end
    if BAG_SUBS[st] then return F.CUST_SLOT.BackpackEquipemtSlot end
    if HELMET_SUBS[st] then return F.CUST_SLOT.HelmetEquipemtSlot end
    if F.isParachuteRes(resID) or st == PARACHUTE_SUB then return F.CUST_SLOT.ParachuteEquipemtSlot end
    if F.isGlideRes(resID) or GLIDER_SUBS[st] then return F.CUST_SLOT.GlideEquipemtSlot end
    return nil
end

function F.isSuitRes(resID)
    if F.subType(F.cfg(resID)) ~= OUTFIT_SUB then return false end
    return F.wardrobeTab(resID) ~= TAB_CLOTHES
end

function F.isTshirtRes(resID)
    return F.subType(F.cfg(resID)) == OUTFIT_SUB and F.wardrobeTab(resID) == TAB_CLOTHES
end

function F.weaponIdFromSkin(resID)
    local m = CDataTable and CDataTable.GetTableData and CDataTable.GetTableData("WeaponSkinMapping", resID)
    if not m then return nil end
    return m.WeaponID or m.WeaponId
end

function F.isValidWeaponId(weaponID)
    weaponID = tonumber(weaponID)
    if not weaponID or weaponID <= 0 then return false end
    if weaponID == MELEE_ID then return true end
    return weaponID >= 101000 and weaponID < 108000
end

function F.isValidWeaponPersistEntry(weaponID, resID)
    weaponID, resID = tonumber(weaponID), tonumber(resID)
    if not F.isValidWeaponId(weaponID) or not resID or resID <= 0 then return false end
    if weaponID == resID then return false end
    if resID >= 1800000 and resID < 1810000 then return false end
    if resID >= 1900000 and resID < 2000000 then return false end
    if F.isInjectedRes(resID) then
        local wid = tonumber(F.weaponIdFromSkin(resID))
        return wid and wid == weaponID
    end
    local wid = tonumber(F.weaponIdFromSkin(resID))
    return wid and wid == weaponID
end

function F.sanitizeConfigWeapons(wmap)
    if type(wmap) ~= "table" then return {} end
    local clean = {}
    for wid, res in pairs(wmap) do
        wid, res = tonumber(wid), tonumber(res)
        if F.isValidWeaponPersistEntry(wid, res) then clean[wid] = res end
    end
    return clean
end

function F.indexWeaponSkin(resID, insID)
    resID, insID = tonumber(resID), tonumber(insID)
    if not resID or not insID then return end
    local c = F.cfg(resID)
    local st = F.subType(c)
    if not (GUN_SUB[st] or st == MELEE_ID) then return end
    local wid = F.weaponIdFromSkin(resID)
    wid = tonumber(wid)
    if not wid or wid <= 0 then return end
    R.byWeapon[wid] = R.byWeapon[wid] or {}
    R.byWeapon[wid][resID] = insID
end

function F.isInjectedIns(ins)
    return ins and R.insToRes[tonumber(ins)] ~= nil
end

function F.isInjectedRes(res)
    return res and R.resToIns[tonumber(res)] ~= nil
end

function F.isWeaponSkinRes(resID)
    resID = tonumber(resID)
    if not resID then return false end
    local st = F.subType(F.cfg(resID))
    return GUN_SUB[st] or st == MELEE_ID
end

function F.isWeaponSkinIns(insID)
    insID = tonumber(insID)
    if not insID then return false end
    local res = R.insToRes[insID]
    return res and F.isWeaponSkinRes(res)
end

function F.cleanArmoryPollution()
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        if not Arm.rsp_list then return end
        if Arm.rsp_list.install_list then
            for wid, entry in pairs(Arm.rsp_list.install_list) do
                local ins = tonumber(entry and entry.skin_id)
                if ins and not F.isWeaponSkinIns(ins) then
                    Arm.rsp_list.install_list[wid] = nil
                end
            end
        end
        if Arm.rsp_list.skin_list then
            for wid, skins in pairs(Arm.rsp_list.skin_list) do
                if type(skins) == "table" then
                    for resID in pairs(skins) do
                        if not F.isWeaponSkinRes(tonumber(resID)) then
                            skins[resID] = nil
                        end
                    end
                end
            end
        end
    end)
end

function F.depotSubType(insID, resID)
    resID = tonumber(resID) or tonumber(R.insToRes[insID])
    local st = F.subType(F.cfg(resID))
    if st then return st end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    return d and tonumber(d.itemSubType)
end

function F.tryLocalWearByIns(insID)
    insID = tonumber(insID)
    if not insID then return false end
    if _G.LexusConfig and _G.LexusConfig.ModSkin == false then return false end
    local resID = R.insToRes[insID]
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not resID and d then resID = tonumber(d.resID or d.res_id) end
    if not resID or resID <= 0 then return false end
    local st = F.depotSubType(insID, resID)

    local function mapLocal()
        if not R.insToRes[insID] then
            R.insToRes[insID] = resID
            R.resToIns[resID] = insID
        end
    end

    if st == GLOVES_SUB then mapLocal(); F.putOnGloves(insID) return true end
    F.clearItemExpire(d, insID, resID)
    F.ensureDepotItemValid(insID, resID)
    if F.isParachuteRes(resID) then mapLocal(); return F.putOnParachute(insID) end
    if F.isGlideRes(resID) or GLIDER_SUBS[st] then mapLocal(); return F.putOnGlider(insID) end

    if st == OUTFIT_SUB then
        mapLocal()
        if F.isSuitRes(resID) or F.wardrobeTab(resID) == TAB_SUIT then
            F.putOnOutfit(insID)
        else
            F.putOnRoleWear(insID)
        end
        return true
    end
    if st == HAT_SUB or HEAD_SUBS[st] then mapLocal(); F.putOnHat(insID) return true end
    if FACE_SUBS[st] then mapLocal(); F.putOnFaceAccessory(insID) return true end
    if BODY_SUBS[st] or HELMET_SUBS[st] then mapLocal(); F.putOnRoleWear(insID) return true end

    if not F.isInjectedIns(insID) then return false end
    if GUN_SUB[st] then
        local wid = F.weaponIdFromSkin(resID)
        if wid then F.equipWeaponSkin(wid, insID) end
        return true
    end
    if st == MELEE_ID then F.equipWeaponSkin(MELEE_ID, insID) return true end
    if F.isHallThemeRes(resID) and (F.isInjectedIns(insID) or F.isInjectedRes(resID)) then
        mapLocal()
        return F.putOnHallTheme(insID)
    end
    if F.isVehicleRes(resID) and (F.isInjectedIns(insID) or F.isInjectedRes(resID)) then
        mapLocal()
        return F.putOnVehicle(insID)
    end
    return false
end

function F.isHallThemeRes(resID)
    local c = F.cfg(tonumber(resID))
    if not c then return false end
    local t = c.ItemType or c.itemType
    return t == HALL_THEME_TYPE
end

function F.isResourcesReady(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return false end
    if not F.isInjectedRes(resID) then return true end
    local ready = false
    pcall(function()
        local PufferConst = require("client.slua.logic.download.puffer_const")
        local mgr = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.puffer_odpak_manager)
        if mgr and mgr.GetStateByItemID then
            local st = mgr:GetStateByItemID(resID)
            ready = st == PufferConst.ENUM_DownloadState.Done
        end
    end)
    return ready
end

function F.requestResourceDownload(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 or not F.isInjectedRes(resID) then return end
    if F.isResourcesReady(resID) then return end
    _G.AddOutfitDownloadQueued = _G.AddOutfitDownloadQueued or {}
    if _G.AddOutfitDownloadQueued[resID] then return end
    _G.AddOutfitDownloadQueued[resID] = true
    pcall(function()
        local PM = require("client.slua.logic.download.puffer.puffer_manager")
        local PufferConst = require("client.slua.logic.download.puffer_const")
        PM.Download(PufferConst.ENUM_DownloadType.ODPAK, { resID }, "AddOutfit", function()
            _G.AddOutfitDownloadQueued[resID] = nil
        end)
    end)
end

function F.ensureInjectedResources()
    for res in pairs(R.resToIns) do
        F.requestResourceDownload(tonumber(res))
    end
end

function F.restorePufferHooks()
    pcall(function()
        local mgr = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.puffer_odpak_manager)
        if mgr and _G.AddOutfitPufferOrig then
            mgr.GetStateByItemID = _G.AddOutfitPufferOrig
        end
    end)
    pcall(function()
        local PM = require("client.slua.logic.download.puffer.puffer_manager")
        if PM and _G.AddOutfitPufferGetStateOrig then
            PM.GetState = _G.AddOutfitPufferGetStateOrig
        end
    end)
    pcall(function()
        local VAC = require("GameLua.GameCore.Module.Vehicle.Component.VehicleAvatarComponent")
        local vacImpl = VAC and VAC.__inner_impl
        if vacImpl and _G.AddOutfitVehOrigAssets then
            vacImpl.LuaIsAssetsAlreadyAvailable = _G.AddOutfitVehOrigAssets
        end
    end)
end

function F.invalidateSocialWearCache()
    local s = _G.AddOutfitSocialState
    if s then
        s.wearPatchKey, s.snapshotKey, s.fullSnapshot, s.lastHandSkin = nil, nil, nil, nil
    end
end

function F.clearWeaponEquippedMark(weaponID)
    _G.AddOutfitWeaponEquipped = _G.AddOutfitWeaponEquipped or {}
    if weaponID then
        _G.AddOutfitWeaponEquipped[tonumber(weaponID)] = nil
    else
        for k in pairs(_G.AddOutfitWeaponEquipped) do _G.AddOutfitWeaponEquipped[k] = nil end
    end
end

function F.isWeaponVisuallyEquipped(weaponID, insID)
    weaponID, insID = tonumber(weaponID), tonumber(insID)
    if not weaponID or not insID then return false end
    return _G.AddOutfitWeaponEquipped and _G.AddOutfitWeaponEquipped[weaponID] == insID
end

function F.saveWeaponToCache(weaponID, resID, insID)
    F.clearWeaponEquippedMark(weaponID)
    weaponID, resID, insID = tonumber(weaponID), tonumber(resID), tonumber(insID)
    if not F.isValidWeaponPersistEntry(weaponID, resID) then return end
    local cch = F.cache()
    cch.weapons[weaponID] = { resID = resID, insID = insID or 0 }
    PERSIST.configWeapons = PERSIST.configWeapons or {}
    PERSIST.configWeapons[weaponID] = resID
    _G.AddOutfitLastAppliedSkin = {}
    _matchApplied = false
    F.perfInvalidateLobby()
    F.invalidateSocialWearCache()
    F.persistMarkDirty()
    F.log("Weapon skin cached", weaponID, "→", resID)
end

function F.cacheWeaponSkinFromIns(weaponID, insID)
    weaponID, insID = tonumber(weaponID), tonumber(insID)
    if not weaponID or not insID or insID <= 0 then return end
    if F.isInjectedIns(insID) then
        F.saveWeaponToCache(weaponID, R.insToRes[insID], insID)
        return
    end
    pcall(function()
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        if d and d.resID and tonumber(d.resID) > 0 then
            F.saveWeaponToCache(weaponID, tonumber(d.resID), insID)
        end
    end)
end

function F.saveEquip(resID, insID)
    resID, insID = tonumber(resID), tonumber(insID)
    if not resID or not insID then return end
    local c = F.cfg(resID)
    local st = F.subType(c)
    local cch = F.cache()
    if st == OUTFIT_SUB then
        if F.wardrobeTab(resID) == TAB_CLOTHES then
            cch.tshirtRes, cch.tshirtIns = resID, insID
            _G.AddOutfitLastLobbyTshirtRes = resID
            F.persistRememberSlot("tshirt", resID)
        else
            cch.outfitRes, cch.outfitIns = resID, insID
            _G.AddOutfitLastLobbyOutfitRes = resID
            F.persistRememberSlot("outfit", resID)
            F.invalidateSocialWearCache()
        end
    elseif st == HAT_SUB then
        cch.hatRes, cch.hatIns = resID, insID
        _G.AddOutfitLastLobbyHatRes = resID
        F.persistRememberSlot("hat", resID)
    elseif st == MASK_SUB then
        cch.maskRes, cch.maskIns = resID, insID
        _G.AddOutfitLastLobbyMaskRes = resID
        F.persistRememberSlot("mask", resID)
    elseif st == GLASS_SUB then
        cch.glassRes, cch.glassIns = resID, insID
        _G.AddOutfitLastLobbyGlassRes = resID
        F.persistRememberSlot("glass", resID)
    elseif st == PANTS_SUB then
        cch.pantsRes, cch.pantsIns = resID, insID
        _G.AddOutfitLastLobbyPantsRes = resID
        F.persistRememberSlot("pants", resID)
    elseif st == SHOES_SUB then
        cch.shoesRes, cch.shoesIns = resID, insID
        _G.AddOutfitLastLobbyShoesRes = resID
        F.persistRememberSlot("shoes", resID)
    elseif BAG_SUBS[st] then
        cch.bagRes, cch.bagIns = resID, insID
        _G.AddOutfitLastLobbyBagRes = resID
        F.persistRememberSlot("bag", resID)
    elseif HELMET_SUBS[st] then
        cch.helmetRes, cch.helmetIns = resID, insID
        _G.AddOutfitLastLobbyHelmetRes = resID
        F.persistRememberSlot("helmet", resID)
    elseif st == PARACHUTE_SUB then
        cch.parachuteRes, cch.parachuteIns = resID, insID
        _G.AddOutfitLastLobbyParachuteRes = resID
        F.persistRememberSlot("parachute", resID)
    elseif F.isGlideRes(resID) then
        cch.gliderRes, cch.gliderIns = resID, insID
        _G.AddOutfitLastLobbyGliderRes = resID
        F.persistRememberSlot("glider", resID)
    elseif st == GLOVES_SUB then
        cch.glovesRes, cch.glovesIns = resID, insID
        _G.AddOutfitLastLobbyGlovesRes = resID
        F.persistRememberSlot("gloves", resID)
    elseif GUN_SUB[st] then
        local wid = F.weaponIdFromSkin(resID)
        if wid then F.saveWeaponToCache(wid, resID, insID) end
    elseif st == MELEE_ID then
        F.saveWeaponToCache(MELEE_ID, resID, insID)
    end
    _matchApplied = false
    F.perfInvalidateLobby()
    F.persistMarkDirty()
end

function F.findWornInsBySubType(st, filterFn)
    st = tonumber(st)
    if not st then return nil end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local AvatarData = require("client.logic.data.AvatarData")
    for _, ins in pairs(AvatarData.GetRoleWear()) do
        ins = tonumber(ins)
        if ins and ins > 0 then
            local d = wd:GetHallDepotItemDataByInsID(ins)
            if d and tonumber(d.itemSubType) == st then
                local res = tonumber(d.resID)
                if not filterFn or filterFn(res, d) then
                    return ins, res
                end
            end
        end
    end
    return nil
end

function F.syncHatCacheFromLobby()
    local cch = F.cache()
    pcall(function()
        local ins, res = F.findWornInsBySubType(HAT_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.hatRes, cch.hatIns = tonumber(res), ins
            return
        end
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
        local headIns = tonumber(bag and bag.head_show) or 0
        if headIns <= 0 then return end
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d = wd:GetValidHallDepotItemDataByInsID(headIns) or wd:GetHallDepotItemDataByInsID(headIns)
        if not d or not d.resID or tonumber(d.resID) <= 0 then return end
        local st = tonumber(d.itemSubType or F.subType(F.cfg(d.resID)))
        if HEAD_SUBS[st] then
            cch.hatRes, cch.hatIns = tonumber(d.resID), headIns
        end
    end)
end

function F.syncFaceCacheFromLobby()
    local cch = F.cache()
    pcall(function()
        local ins, res = F.findWornInsBySubType(MASK_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.maskRes, cch.maskIns = tonumber(res), ins
            _G.AddOutfitLastLobbyMaskRes = tonumber(res)
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(GLASS_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.glassRes, cch.glassIns = tonumber(res), ins
            _G.AddOutfitLastLobbyGlassRes = tonumber(res)
        end
    end)
end

function F.syncBodyCacheFromLobby()
    local cch = F.cache()
    pcall(function()
        local ins, res = F.findWornInsBySubType(OUTFIT_SUB, function(r) return F.wardrobeTab(r) == TAB_CLOTHES end)
        if ins and res and tonumber(res) > 0 then
            cch.tshirtRes, cch.tshirtIns = tonumber(res), ins
            _G.AddOutfitLastLobbyTshirtRes = tonumber(res)
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(PANTS_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.pantsRes, cch.pantsIns = tonumber(res), ins
            _G.AddOutfitLastLobbyPantsRes = tonumber(res)
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(SHOES_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.shoesRes, cch.shoesIns = tonumber(res), ins
            _G.AddOutfitLastLobbyShoesRes = tonumber(res)
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(GLOVES_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.glovesRes, cch.glovesIns = tonumber(res), ins
            _G.AddOutfitLastLobbyGlovesRes = tonumber(res)
        end
    end)
    pcall(function()
        for st in pairs(BAG_SUBS) do
            local ins, res = F.findWornInsBySubType(st)
            if ins and res and tonumber(res) > 0 then
                cch.bagRes, cch.bagIns = tonumber(res), ins
                _G.AddOutfitLastLobbyBagRes = tonumber(res)
                break
            end
        end
    end)
    pcall(function()
        for st in pairs(HELMET_SUBS) do
            local ins, res = F.findWornInsBySubType(st)
            if ins and res and tonumber(res) > 0 then
                cch.helmetRes, cch.helmetIns = tonumber(res), ins
                _G.AddOutfitLastLobbyHelmetRes = tonumber(res)
                break
            end
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(OUTFIT_SUB, function(r) return F.isSuitRes(r) end)
        if ins and res and tonumber(res) > 0 then
            cch.outfitRes, cch.outfitIns = tonumber(res), ins
            _G.AddOutfitLastLobbyOutfitRes = tonumber(res)
        end
    end)
end

function F.syncAirborneCacheFromLobby(saveToConfig)
    local cch = F.cache()
    local cfgPara = tonumber(PERSIST.configSlots and PERSIST.configSlots.parachute)
    local cfgGlide = tonumber(PERSIST.configSlots and PERSIST.configSlots.glider)
    local changed = false

    local function maybeSave(slotName, res)
        if not saveToConfig or not res or res <= 0 then return end
        if slotName == "parachute" and res == DEFAULT_PARACHUTE_RES
            and cfgPara and cfgPara > 0 and cfgPara ~= DEFAULT_PARACHUTE_RES then
            return
        end
        F.persistRememberSlot(slotName, res)
        changed = true
    end

    local function applyPara(res, ins)
        res, ins = tonumber(res), tonumber(ins)
        if not res or not ins or not F.isParachuteRes(res) then return end
        if cfgPara and cfgPara > 0 and not saveToConfig then
            if res == cfgPara then cch.parachuteIns = ins end
            return
        end
        if res == DEFAULT_PARACHUTE_RES and not saveToConfig then return end
        if cch.parachuteRes ~= res or cch.parachuteIns ~= ins then
            cch.parachuteRes, cch.parachuteIns = res, ins
            _G.AddOutfitLastLobbyParachuteRes = res
            maybeSave("parachute", res)
        end
    end

    local function applyGlide(res, ins)
        res, ins = tonumber(res), tonumber(ins)
        if not res or not ins or not F.isGlideRes(res) then return end
        if cfgGlide and cfgGlide > 0 and not saveToConfig then
            if res == cfgGlide then cch.gliderIns = ins end
            return
        end
        if cch.gliderRes ~= res or cch.gliderIns ~= ins then
            cch.gliderRes, cch.gliderIns = res, ins
            _G.AddOutfitLastLobbyGliderRes = res
            maybeSave("glider", res)
        end
    end

    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local paraIns = tonumber(fbd.GetParachute and fbd:GetParachute()) or 0
        if paraIns > 0 then
            local d = wd:GetValidHallDepotItemDataByInsID(paraIns) or wd:GetHallDepotItemDataByInsID(paraIns)
            applyPara(d and tonumber(d.resID), paraIns)
        end
        local glideIns = tonumber(fbd.GetAircraftOrGliding and fbd:GetAircraftOrGliding()) or 0
        if glideIns > 0 then
            local d = wd:GetValidHallDepotItemDataByInsID(glideIns) or wd:GetHallDepotItemDataByInsID(glideIns)
            applyGlide(d and tonumber(d.resID), glideIns)
        end
    end)
    pcall(function()
        for st in pairs(GLIDER_SUBS) do
            local ins, res = F.findWornInsBySubType(st)
            if ins and res then applyGlide(res, ins) break end
        end
        local ins, res = F.findWornInsBySubType(PARACHUTE_SUB)
        if ins and res then applyPara(res, ins) end
    end)
    if changed then F.persistMarkDirty() end
end

function F.syncWeaponCacheFromLobby(force)
    if LOBBY.lobbySynced and not force then return end
    LOBBY.lobbySynced = true
    PERF.mappingsDirty = true
    PERF.desiredSkins = nil
    for k in pairs(PERF.skinTarget) do PERF.skinTarget[k] = nil end
    local cch = F.cache()
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
        if bag and bag.weapon_skin_list then
            for weaponID, entry in pairs(bag.weapon_skin_list) do
                weaponID = tonumber(weaponID)
                local insID = tonumber(entry and (entry.skin_id or entry.skinId)) or 0
                if weaponID and weaponID > 0 and insID > 0 then
                    local res
                    if F.isInjectedIns(insID) then
                        res = tonumber(R.insToRes[insID])
                    else
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d = wd:GetValidHallDepotItemDataByInsID(insID)
                            or wd:GetHallDepotItemDataByInsID(insID)
                        res = d and tonumber(d.resID)
                    end
                    if res and res > 0 and F.isValidWeaponPersistEntry(weaponID, res) then
                        cch.weapons[weaponID] = { resID = res, insID = insID }
                    end
                end
            end
        end
    end)
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        if Arm.rsp_list and Arm.rsp_list.install_list then
            for weaponID, entry in pairs(Arm.rsp_list.install_list) do
                weaponID = tonumber(weaponID)
                local insID = tonumber(entry and entry.skin_id) or 0
                if weaponID and weaponID > 0 and insID > 0 then
                    local res
                    if F.isInjectedIns(insID) then
                        res = tonumber(R.insToRes[insID])
                    else
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d = wd:GetValidHallDepotItemDataByInsID(insID)
                            or wd:GetHallDepotItemDataByInsID(insID)
                        res = d and tonumber(d.resID)
                    end
                    if res and res > 0 and F.isValidWeaponPersistEntry(weaponID, res) then
                        cch.weapons[weaponID] = { resID = res, insID = insID }
                    end
                end
            end
        end
    end)
    F.syncHatCacheFromLobby()
    F.syncFaceCacheFromLobby()
    F.syncBodyCacheFromLobby()
end

function F.getCachedWeaponSkin(weaponID)
    weaponID = tonumber(weaponID) or 0
    if weaponID <= 0 then return nil end
    F.syncWeaponCacheFromLobby()
    local w = F.cache().weapons[weaponID]
    if w and w.resID and w.resID > 0 then return w.resID end
    return nil
end

function F.getMatchWeaponSkin(weaponID)
    weaponID = tonumber(weaponID) or 0
    local fromCache = F.getCachedWeaponSkin(weaponID)
    if fromCache then return fromCache end
    if MATCH_CONFIG.weaponSkins then
        local fixed = tonumber(MATCH_CONFIG.weaponSkins[weaponID])
        if fixed and fixed > 0 then return fixed end
    end
    return nil
end

function F.removeRoleWearBySubType(st, filterFn)
    st = tonumber(st)
    if not st then return end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local AvatarData = require("client.logic.data.AvatarData")
    for _, ins in pairs(AvatarData.GetRoleWear()) do
        ins = tonumber(ins)
        if ins and ins > 0 then
            local d = wd:GetHallDepotItemDataByInsID(ins)
            if d and tonumber(d.itemSubType) == st then
                local res = tonumber(d.resID)
                if not filterFn or filterFn(res, d) then
                    AvatarData.RemoveRoleWearDataByValue(ins)
                end
            end
        end
    end
end

function F.syncFashionBagRolewear()
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        fbd:SaveRolewearToFashionBag(fbd:GetFashionBagUseIndex())
    end)
end

local _ticker
pcall(function() _ticker = require("common.time_ticker") end)
function F.later(sec, fn)
    if _G.SetTimer then pcall(_G.SetTimer, sec, fn) return end
    if _ticker and _ticker.AddTimer then pcall(_ticker.AddTimer, sec, fn) end
end

function F.getPC()
    if slua_GameFrontendHUD then
        local pc = slua_GameFrontendHUD:GetPlayerController()
        if slua.isValid(pc) then return pc end
    end
    local ok, gd = pcall(require, "GameLua.GameCore.Data.GameplayData")
    if ok and gd then
        local pc = gd.GetPlayerController()
        if slua.isValid(pc) then return pc end
    end
    return nil
end

function F.syncVehicleSlotsToDataMgr()
    local cch = F.cache()
    DataMgr.VehicleSlotList = DataMgr.VehicleSlotList or {}
    for subType, slots in pairs(cch.vehicleSlots or {}) do
        local arr = DataMgr.VehicleSlotList[subType]
        if not arr then arr = {}; DataMgr.VehicleSlotList[subType] = arr end
        for k in pairs(arr) do arr[k] = nil end
        for idx, e in pairs(slots or {}) do
            if e and tonumber(e.insID) and tonumber(e.insID) > 0 then
                arr[tonumber(idx)] = tonumber(e.insID)
            end
        end
    end
end

function F.mergeInjectedIntoVehicleSlotList(serverList)
    serverList = serverList or {}
    local cch = F.cache()
    for subType, slots in pairs(cch.vehicleSlots or {}) do
        subType = tonumber(subType)
        if subType and type(slots) == "table" then
            local arr = serverList[subType]
            if not arr then arr = {}; serverList[subType] = arr end
            for idx, e in pairs(slots) do
                idx = tonumber(idx)
                local insID = e and tonumber(e.insID)
                if idx and insID and insID > 0 and F.isInjectedIns(insID) then
                    arr[idx] = insID
                end
            end
        end
    end
    local cfg = PERSIST.configVehicleSlots
    if cfg then
        for subType, slotMap in pairs(cfg) do
            subType = tonumber(subType)
            if subType and type(slotMap) == "table" then
                local arr = serverList[subType]
                if not arr then arr = {}; serverList[subType] = arr end
                for idx, res in pairs(slotMap) do
                    idx, res = tonumber(idx), tonumber(res)
                    local ins = res and R.resToIns[res]
                    if idx and ins and F.isInjectedIns(ins) then
                        arr[idx] = ins
                    end
                end
            end
        end
    end
    return serverList
end

function F.applyVehicleSlotsFromConfigMap(slotMap)
    if not slotMap or not next(slotMap) then return false end
    local cch = F.cache()
    cch.vehicleSlots = cch.vehicleSlots or {}
    local any = false
    for subType, slots in pairs(slotMap) do
        subType = tonumber(subType)
        if subType then
            cch.vehicleSlots[subType] = cch.vehicleSlots[subType] or {}
            for idx, res in pairs(slots) do
                idx, res = tonumber(idx), tonumber(res)
                local ins = res and R.resToIns[res]
                if idx and ins then
                    cch.vehicleSlots[subType][idx] = { resID = res, insID = ins }
                    any = true
                end
            end
        end
    end
    return any
end

function F.notifyVehicleSlotUI()
    pcall(function()
        local WRH = require("client.network.Protocol.WardrobeNewHandler")
        WRH.on_depot_modify_combat_vehicle_rsp(0, DataMgr.VehicleSlotList or {})
    end)
end

function F.mergeInjectedVehicleSkinTable(serverTable)
    serverTable = serverTable or {}
    local cfg = PERSIST.configVehicleSlots
    if not cfg then return serverTable end
    for subType, slotMap in pairs(cfg) do
        subType = tonumber(subType)
        if subType and type(slotMap) == "table" then
            local res = tonumber(slotMap[1] or slotMap["1"])
            local ins = res and R.resToIns[res]
            if ins and F.isInjectedIns(ins) then
                serverTable[subType] = ins
            end
        end
    end
    local cch = F.cache()
    for subType, slots in pairs(cch.vehicleSlots or {}) do
        subType = tonumber(subType)
        local e = slots and (slots[1] or slots["1"])
        local insID = e and tonumber(e.insID)
        if subType and insID and insID > 0 and F.isInjectedIns(insID) then
            serverTable[subType] = insID
        end
    end
    return serverTable
end

function F.equipVehicleTypesFromConfig(slotMap)
    slotMap = slotMap or PERSIST.configVehicleSlots
    if not slotMap or not next(slotMap) then return false end
    DataMgr.vehicleSkinInsIDTable = DataMgr.vehicleSkinInsIDTable or {}
    local subTypes = {}
    for st in pairs(slotMap) do
        local n = tonumber(st)
        if n then subTypes[#subTypes + 1] = n end
    end
    table.sort(subTypes)
    local any, lobbyRes, lobbyIns = false, nil, nil
    for _, subType in ipairs(subTypes) do
        local slots = slotMap[subType] or slotMap[tostring(subType)]
        if type(slots) == "table" then
            local res = tonumber(slots[1] or slots["1"])
            local ins = res and R.resToIns[res]
            if ins and F.isInjectedIns(ins) then
                DataMgr.vehicleSkinInsIDTable[subType] = ins
                any = true
                if not lobbyIns then
                    lobbyRes, lobbyIns = res, ins
                end
            end
        end
    end
    if any then
        pcall(function()
            local TabSurveillance = require("client.slua.logic.wardrobe.tab_surveillance")
            TabSurveillance.VehicleChange()
        end)
    end
    return any, lobbyRes, lobbyIns
end

function F.applyLobbyVehicleDisplay(resID, insID, showVehicle)
    insID = tonumber(insID)
    resID = tonumber(resID)
    if not insID or insID <= 0 then return end
    _G.AddOutfitApplyingConfig = true
    pcall(function() DataMgr.vst_skin = insID end)
    pcall(function()
        local HallThemeUtils = require("client.logic.lobby.hall_theme_utils")
        HallThemeUtils.ProcPutOnVehicle({ res_id = resID, instid = insID }, showVehicle ~= false)
    end)
    pcall(F.applyVehicleSkinsToPC)
    _G.AddOutfitApplyingConfig = false
end

function F.setLobbyVehicleManual(subType, resID, insID)
    insID = tonumber(insID)
    resID = tonumber(resID)
    subType = tonumber(subType)
    if not insID then return end
    if F.isChassisLightId(resID) or subType == CHASSIS_LIGHT_SUB then return end
    if resID and not F.isVehicleRes(resID) then return end
    if not F.isInjectedIns(insID) and not F.isVehicleRes(resID) then return end
    if not resID then resID = R.insToRes[insID] end
    if not subType and resID then subType = tonumber(F.vehicleSubType(resID)) end
    _G.AddOutfitLobbyVeh = _G.AddOutfitLobbyVeh or {}
    _G.AddOutfitLobbyVeh.manual = true
    _G.AddOutfitLobbyVeh.subType = subType
    _G.AddOutfitLobbyVeh.resID = resID
    _G.AddOutfitLobbyVeh.insID = insID
    PERSIST.lobbyVehicleSubType = subType
    PERSIST.lobbyVehicleIns = insID
    PERSIST.lobbyVehicleResID = resID
    F.persistMarkDirty()
end

function F.resolveLobbyVehicle(slotMap)
    slotMap = slotMap or PERSIST.configVehicleSlots
    local L = _G.AddOutfitLobbyVeh or {}
    local st = tonumber(PERSIST.lobbyVehicleSubType) or tonumber(L.subType)
    local res = tonumber(PERSIST.lobbyVehicleResID) or tonumber(L.resID)
    if res and res > 0 then
        local ins = R.resToIns[res]
        if ins then
            if not st then st = tonumber(F.vehicleSubType(res)) end
            return res, ins, st
        end
    end
    local ins = tonumber(PERSIST.lobbyVehicleIns) or tonumber(L.insID)
    if ins and F.isInjectedIns(ins) then
        res = R.insToRes[ins] or res
        if not st and res then st = tonumber(F.vehicleSubType(res)) end
        return res, ins, st
    end
    if st and slotMap then
        local slots = slotMap[st] or slotMap[tostring(st)]
        local res = slots and tonumber(slots[1] or slots["1"])
        ins = res and R.resToIns[res]
        if ins then return res, ins, st end
    end
    local subTypes = {}
    for s in pairs(slotMap or {}) do
        local n = tonumber(s)
        if n then subTypes[#subTypes + 1] = n end
    end
    table.sort(subTypes)
    if subTypes[1] then
        st = subTypes[1]
        local slots = slotMap[st] or slotMap[tostring(st)]
        local res = slots and tonumber(slots[1] or slots["1"])
        ins = res and R.resToIns[res]
        if ins then return res, ins, st end
    end
    return nil, nil, nil
end

function F.syncLobbyVehicleResFromIns()
    if PERSIST.lobbyVehicleResID and PERSIST.lobbyVehicleResID > 0 then return end
    local ins = tonumber(PERSIST.lobbyVehicleIns)
    if ins and R.insToRes[ins] then
        PERSIST.lobbyVehicleResID = R.insToRes[ins]
        F.persistMarkDirty()
    end
end

function F.hasExplicitLobbyVehicle()
    local res = tonumber(PERSIST.lobbyVehicleResID)
    local st = tonumber(PERSIST.lobbyVehicleSubType)
    if F.isChassisLightId(res) or st == CHASSIS_LIGHT_SUB then return false end
    if res and res > 0 and not F.isVehicleRes(res) then return false end
    if res and res > 0 then return true end
    if (tonumber(PERSIST.lobbyVehicleIns) or 0) > 0 then return true end
    local L = _G.AddOutfitLobbyVeh
    if L and L.manual and ((tonumber(L.resID) or 0) > 0 or (tonumber(L.insID) or 0) > 0) then return false end
    return false
end

function F.shouldApplyLobbyFromConfig(silent)
    if not F.hasExplicitLobbyVehicle() then return false end
    local _, lobbyIns = F.resolveLobbyVehicle(PERSIST.configVehicleSlots)
    if not lobbyIns then return false end
    local cur = tonumber(DataMgr.vst_skin)
    if cur == lobbyIns then return false end
    return true
end

function F.reapplyVehicleSlotsFromConfig(silent)
    local slotMap = PERSIST.configVehicleSlots
    if not slotMap or not next(slotMap) then return false end
    if not F.applyVehicleSlotsFromConfigMap(slotMap) then return false end
    F.syncVehicleSlotsToDataMgr()
    F.notifyVehicleSlotUI()
    F.equipVehicleTypesFromConfig(slotMap)
    if F.shouldApplyLobbyFromConfig(silent) then
        local lobbyRes, lobbyIns = F.resolveLobbyVehicle(slotMap)
        if lobbyIns then
            F.applyLobbyVehicleDisplay(lobbyRes, lobbyIns, not silent)
        elseif not silent then
            pcall(F.applyVehicleSkinsToPC)
            F.perfInvalidateLobby()
        end
    end
    return true
end

function F.applyHallThemeDisplay(resID, insID)
    insID = tonumber(insID)
    resID = tonumber(resID)
    if not insID or not resID then return false end
    if not F.isInjectedIns(insID) then return false end
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return false
    end
    _G.AddOutfitApplyingTheme = true
    pcall(function()
        local HT = require("client.logic.lobby.hall_theme_utils")
        HT.ProcPutOnHallTheme({ res_id = resID, instid = insID }, nil)
    end)
    _G.AddOutfitApplyingTheme = false
    local cch = F.cache()
    cch.hallThemeRes, cch.hallThemeIns = resID, insID
    return true
end

function F.setHallThemeManual(resID, insID)
    insID = tonumber(insID)
    resID = tonumber(resID)
    if not insID or not F.isInjectedIns(insID) then return end
    if not resID then resID = R.insToRes[insID] end
    _G.AddOutfitLobbyTheme = _G.AddOutfitLobbyTheme or {}
    _G.AddOutfitLobbyTheme.manual = true
    _G.AddOutfitLobbyTheme.resID = resID
    _G.AddOutfitLobbyTheme.insID = insID
    PERSIST.hallThemeResID = resID
    PERSIST.hallThemeIns = insID
    local cch = F.cache()
    cch.hallThemeRes, cch.hallThemeIns = resID, insID
    F.persistMarkDirty()
end

function F.resolveHallTheme()
    local L = _G.AddOutfitLobbyTheme or {}
    local res = tonumber(PERSIST.hallThemeResID) or tonumber(L.resID)
    if res and R.resToIns[res] then return res, R.resToIns[res] end
    local ins = tonumber(PERSIST.hallThemeIns) or tonumber(L.insID)
    if ins and F.isInjectedIns(ins) then return R.insToRes[ins], ins end
    return nil, nil
end

function F.shouldApplyHallThemeFromConfig(silent)
    local _, ins = F.resolveHallTheme()
    if not ins then return false end
    local cur = nil
    pcall(function()
        local HT = require("client.logic.lobby.hall_theme_utils")
        cur = tonumber(HT.GetThemeInstId())
    end)
    if cur == ins then return false end
    if _G.AddOutfitLobbyTheme and _G.AddOutfitLobbyTheme.manual then return true end
    if silent and cur and cur > 0 and F.isInjectedIns(cur) then return false end
    return true
end

function F.putOnHallTheme(insID)
    insID = tonumber(insID)
    if not insID or not F.isInjectedIns(insID) then return false end
    local resID = R.insToRes[insID]
    if F.applyHallThemeDisplay(resID, insID) then
        F.setHallThemeManual(resID, insID)
        return true
    end
    return false
end

function F.reapplyHallThemeFromConfig(silent)
    if not F.shouldApplyHallThemeFromConfig(silent) then return false end
    local res, ins = F.resolveHallTheme()
    if not res or not ins then return false end
    return F.applyHallThemeDisplay(res, ins)
end

function F.syncVehicleCacheFromDataMgr()
    local cch = F.cache()
    cch.vehicleSlots = cch.vehicleSlots or {}
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    for subType, slots in pairs(DataMgr.VehicleSlotList or {}) do
        subType = tonumber(subType)
        if subType and type(slots) == "table" then
            cch.vehicleSlots[subType] = cch.vehicleSlots[subType] or {}
            for idx, insID in pairs(slots) do
                idx, insID = tonumber(idx), tonumber(insID)
                if idx and insID and insID > 0 then
                    local res = R.insToRes[insID]
                    if not res then
                        pcall(function()
                            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                            local d = wd:GetHallDepotItemDataByInsID(insID)
                            res = d and tonumber(d.resID)
                        end)
                    end
                    if res and res > 0 then
                        cch.vehicleSlots[subType][idx] = { resID = res, insID = insID }
                    end
                end
            end
        end
    end
end

function F.vehicleSubType(resID)
    local c = F.cfg(resID)
    return c and (c.ItemSubType or c.itemSubType)
end

function F.modifyInjectedVehicleSlot(insID, slotIndex, equip)
    insID = tonumber(insID)
    slotIndex = tonumber(slotIndex)
    if not insID or not slotIndex then return false end
    local resID = R.insToRes[insID]
    if not resID and insID >= INS_BASE then
        pcall(function()
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(insID)
            resID = d and tonumber(d.resID or d.res_id)
        end)
    end
    if not resID then return false end
    local st = F.vehicleSubType(resID)
    if not st or tonumber(st) < 900 then return false end
    local cch = F.cache()
    cch.vehicleSlots = cch.vehicleSlots or {}
    cch.vehicleSlots[st] = cch.vehicleSlots[st] or {}
    if equip then
        for _, slots in pairs(cch.vehicleSlots) do
            for i, e in pairs(slots) do
                if e and tonumber(e.insID) == insID then slots[i] = nil end
            end
        end
        cch.vehicleSlots[st][slotIndex] = { resID = resID, insID = insID }
        PERSIST.configVehicleSlots = PERSIST.configVehicleSlots or {}
        PERSIST.configVehicleSlots[st] = PERSIST.configVehicleSlots[st] or {}
        PERSIST.configVehicleSlots[st][slotIndex] = resID
    else
        local e = cch.vehicleSlots[st][slotIndex]
        if e and tonumber(e.insID) == insID then
            cch.vehicleSlots[st][slotIndex] = nil
            if PERSIST.configVehicleSlots and PERSIST.configVehicleSlots[st] then
                PERSIST.configVehicleSlots[st][slotIndex] = nil
            end
        end
    end
    F.syncVehicleSlotsToDataMgr()
    if equip and slotIndex == 1 then
        DataMgr.vehicleSkinInsIDTable = DataMgr.vehicleSkinInsIDTable or {}
        DataMgr.vehicleSkinInsIDTable[st] = insID
        pcall(function()
            local TabSurveillance = require("client.slua.logic.wardrobe.tab_surveillance")
            TabSurveillance.VehicleChange()
        end)
    end
    F.persistMarkDirty()
    F.notifyVehicleSlotUI()
    return true
end

function F.buildVstInBattleFromSlots()
    local vst = {}
    local function insToRes(insID)
        insID = tonumber(insID)
        if not insID or insID <= 0 then return nil end
        local res = R.insToRes[insID]
        if res and res > 0 then return res end
        pcall(function()
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(insID)
            res = d and tonumber(d.resID)
        end)
        if res and res > 0 then return res end
        if insID >= 1000000 and F.cfg(insID) then return insID end
        return nil
    end
    local function fillFromSlots(subType, slots)
        subType = tonumber(subType)
        if not subType or type(slots) ~= "table" then return end
        local resList = {}
        for idx = 1, 8 do
            local val = slots[idx] or slots[tostring(idx)]
            local res = insToRes(val)
            if not res and type(val) == "table" then
                res = tonumber(val.resID or val.res_id)
            end
            if res and res > 0 then resList[#resList + 1] = res end
        end
        if #resList > 0 then vst[subType] = resList end
    end
    for subType, slots in pairs(DataMgr.VehicleSlotList or {}) do
        fillFromSlots(subType, slots)
    end
    if not next(vst) then
        local cch = F.cache()
        for subType, slots in pairs(cch.vehicleSlots or {}) do
            local resList = {}
            for idx = 1, 8 do
                local e = slots[idx]
                local res = e and tonumber(e.resID)
                if res and res > 0 then resList[#resList + 1] = res end
            end
            if #resList > 0 then vst[tonumber(subType)] = resList end
        end
    end
    if not next(vst) then
        local bySub = {}
        for res, _ in pairs(R.resToIns) do
            res = tonumber(res)
            local c = F.cfg(res)
            local st = c and tonumber(F.subType(c))
            if res and st and st >= 900 then
                bySub[st] = bySub[st] or {}
                bySub[st][#bySub[st] + 1] = res
            end
        end
        for st, list in pairs(bySub) do
            table.sort(list)
            vst[st] = list
        end
    end
    return vst
end

function F.isVehicleSkinAllowed(skinId)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    if F.isInjectedRes(skinId) then return true end
    for _, list in pairs(F.buildVstInBattleFromSlots()) do
        for _, res in ipairs(list) do
            if tonumber(res) == skinId then return true end
        end
    end
    if R.resToIns[skinId] then
        local c = F.cfg(skinId)
        local st = F.subType(c)
        if st and tonumber(st) >= 900 then return true end
    end
    return false
end

function F.isSkinInVehiclePCList(skinId)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    local pc = F.getPC()
    if not slua.isValid(pc) or not pc.VehicleAvatarSkinList then return false end
    local UAvatarUtils = import("AvatarUtils")
    local shape = UAvatarUtils.GetVehicleShapeBySkinID(skinId)
    if shape and shape >= 0 then
        local entry = pc.VehicleAvatarSkinList:Get(shape)
        if entry and entry.SkinList then
            for _, id in pairs(entry.SkinList) do
                if tonumber(id) == skinId then return true end
            end
        end
    end
    return false
end

function F.shouldHandleVehicleSkinClick(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return false end
    return F.isVehicleSkinAllowed(resID) or F.isSkinInVehiclePCList(resID)
end

function F.getMatchVehicle()
    local found = nil
    pcall(function()
        local subs = SubsystemMgr:Get("VehicleControlUISubSystem")
        if subs and subs.GetVehicleUserComponent then
            local uuc = subs:GetVehicleUserComponent()
            if slua.isValid(uuc) and slua.isValid(uuc.Vehicle) then found = uuc.Vehicle end
        end
    end)
    if slua.isValid(found) then return found end
    local pc = F.getPC()
    if slua.isValid(pc) and pc.GetPlayerCharacterSafety then
        local char = pc:GetPlayerCharacterSafety()
        if slua.isValid(char) then
            if char.GetCurrentVehicle then
                local v = char:GetCurrentVehicle()
                if slua.isValid(v) then return v end
            end
            if char.CurrentVehicle and slua.isValid(char.CurrentVehicle) then
                return char.CurrentVehicle
            end
        end
    end
    return nil
end

function F.applyClientVehicleSkin(skinId, vehicle, pc)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    pc = pc or F.getPC()
    vehicle = vehicle or F.getMatchVehicle()
    if not slua.isValid(vehicle) then return false end

    local UAvatarUtils = import("AvatarUtils")
    pcall(function()
        if slua.isValid(pc) then
            pc.ShowVehicleSkin = skinId
            local shapeType = UAvatarUtils.GetVehicleShapeBySkinID(skinId)
            if shapeType and shapeType >= 0 and pc.VehicleAvatarList then
                pc.VehicleAvatarList:Add(shapeType, skinId)
            end
        end
    end)

    local applied = false
    local av = nil
    pcall(function()
        if vehicle.GetAvatarComponent then av = vehicle:GetAvatarComponent() end
        if not slua.isValid(av) then av = vehicle.VehicleAvatarComponent_BP end
    end)

    if slua.isValid(av) then
        pcall(function() if av.bIsLobbyAvatar ~= nil then av.bIsLobbyAvatar = false end end)
        pcall(function() if av.CanChangeAvatar ~= nil then av.CanChangeAvatar = true end end)
        pcall(function()
            if slua.isValid(pc) and av.SetVehicleNetAvatarData then
                av:SetVehicleNetAvatarData(pc)
            end
        end)
        pcall(function()
            if av.ChangeItemAvatar then
                av:ChangeItemAvatar(skinId, false)
                applied = true
            elseif av.PreChangeVehicleAvatar then
                av:PreChangeVehicleAvatar(skinId)
                applied = true
            end
        end)
        pcall(function()
            if av.PostChangeItemAvatar then av:PostChangeItemAvatar(false) end
        end)
    end

    pcall(function()
        local battleCls = import("VehicleAvatarComponentBattleBase")
        local battleAv = vehicle:GetComponentByClass(battleCls)
        if slua.isValid(battleAv) then
            if battleAv.ChangeVehicleAvatar then
                battleAv:ChangeVehicleAvatar(skinId, false)
                applied = true
            end
            pcall(function()
                local VehiclePlateLicenseUtil = require("GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil")
                local uid = pc and pc.PlayerUID or 0
                local bTire = VehiclePlateLicenseUtil.NeedOpenHighTire(tonumber(uid), skinId)
                if battleAv.PreChangeHighTireLight then
                    battleAv:PreChangeHighTireLight(skinId, bTire)
                end
            end)
        end
    end)

    pcall(function()
        if vehicle.ChangeVehicleAvatar and slua.isValid(pc) then
            vehicle:ChangeVehicleAvatar(pc)
            applied = true
        end
    end)

    pcall(function() if vehicle.ForceNetUpdate then vehicle:ForceNetUpdate() end end)
    pcall(function() if slua.isValid(pc) and pc.ForceNetUpdate then pc:ForceNetUpdate() end end)
    return applied
end

function F.getVehicleSkinIds()
    local out, seen = {}, {}
    local function add(res)
        res = tonumber(res)
        if res and res > 0 and not seen[res] then
            seen[res] = true
            out[#out + 1] = res
        end
    end
    for _, list in pairs(F.buildVstInBattleFromSlots()) do
        for _, res in ipairs(list) do add(res) end
    end
    for res in pairs(R.resToIns) do
        local c = F.cfg(tonumber(res))
        local st = c and tonumber(F.subType(c))
        if st and st >= 900 then add(res) end
    end
    return out
end

function F.buildVehVst(skinIds)
    local bySub = {}
    for _, skinId in ipairs(skinIds or {}) do
        local subType = 961
        local ok, c = pcall(function() return CDataTable.GetTableData("Item", skinId) end)
        if ok and c and c.ItemSubType then subType = c.ItemSubType end
        bySub[subType] = bySub[subType] or {}
        bySub[subType][#bySub[subType] + 1] = skinId
    end
    return bySub
end

function F.directInjectVehicleSkinList(pc, skinIds)
    if not slua.isValid(pc) or not pc.VehicleAvatarSkinList then return end
    local UAvatarUtils = import("AvatarUtils")
    for _, skinId in ipairs(skinIds or {}) do
        local shapeType = nil
        pcall(function() shapeType = UAvatarUtils.GetVehicleShapeBySkinID(skinId) end)
        if shapeType and shapeType >= 0 then
            pcall(function() pc.VehicleAvatarList:Add(shapeType, skinId) end)
            local entry = pc.VehicleAvatarSkinList:Get(shapeType)
            if entry and entry.SkinList then
                pcall(function() entry.SkinList:Add(skinId) end)
            end
        end
    end
end

function F.mergeVstIntoPlayerInfo(playerInfo)
    if not playerInfo then return end
    F.syncVehicleCacheFromDataMgr()
    local vst = F.buildVehVst(F.getVehicleSkinIds())
    if not next(vst) then return end
    playerInfo.vst_in_battle = playerInfo.vst_in_battle or {}
    for subType, list in pairs(vst) do
        playerInfo.vst_in_battle[subType] = list
    end
    local first
    for _, list in pairs(vst) do first = list[1]; break end
    if first and first > 0 then playerInfo.vst_skin = first end
end

function F.applyVehicleSkinsToPC(pc)
    pc = pc or F.getPC()
    if not slua.isValid(pc) then return false end
    local skinIds = F.getVehicleSkinIds()
    if #skinIds == 0 then return false end
    local vst = F.buildVehVst(skinIds)
    local avatarList, avatarSkinList = {}, {}
    for _, skinList in pairs(vst) do
        local itemArray = {}
        for _, resid in ipairs(skinList) do
            if resid and resid > 0 then
                itemArray[#itemArray + 1] = { ItemTableID = resid, Count = 1 }
                avatarList[#avatarList + 1] = { ItemTableID = resid, Count = 1 }
            end
        end
        if #itemArray > 0 then
            avatarSkinList[#avatarSkinList + 1] = { Items = itemArray }
        end
    end
    pcall(function() pc.bEnableFuzzyAvatarOnClient = false end)
    pcall(function() pc.ShowVehicleSkin = skinIds[1] end)
    if #avatarList > 0 then
        pcall(function()
            pc.InitialVehicleAvatarList = avatarList
            pc:InitVehicleAvatarList()
        end)
    end
    if #avatarSkinList > 0 then
        pcall(function()
            pc.InitialVehicleAvatarSkinList = avatarSkinList
            pc:InitVehicleAvatarSkinList()
        end)
    end
    F.directInjectVehicleSkinList(pc, skinIds)
    return true
end

function F.serverChangeVehicleAvatar(skinId, pc)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    pc = pc or F.getPC()
    if not slua.isValid(pc) then return false end

    F.applyVehicleSkinsToPC(pc)

    pcall(function()
        pc.ShowVehicleSkin = skinId
        local UAvatarUtils = import("AvatarUtils")
        local shapeType = UAvatarUtils.GetVehicleShapeBySkinID(skinId)
        if shapeType and shapeType >= 0 and pc.VehicleAvatarList then
            pc.VehicleAvatarList:Add(shapeType, skinId)
        end
        F.directInjectVehicleSkinList(pc, { skinId })
    end)

    local ok = false
    pcall(function()
        if pc.ServerChangeVehicleAvatar then
            pc:ServerChangeVehicleAvatar(skinId)
            ok = true
        end
    end)

    pcall(function()
        if pc.PlayerState and slua.isValid(pc.PlayerState) then
            pc.PlayerState.nVst_skin = skinId
        end
    end)

    pcall(function() pc:ForceNetUpdate() end)
    return ok
end

_G.AddOutfitVehSel = _G.AddOutfitVehSel or { override = nil, overrideVehicle = nil, byShape = {} }
local VEHSEL = _G.AddOutfitVehSel
_G.AddOutfitLobbyVeh = _G.AddOutfitLobbyVeh or { manual = false, subType = nil, resID = nil, insID = nil }
local _vehTickLastApply = 0
local VEH_SWITCH_EFFECT_ID = 7303001

function F.prepVehicleSwitchEffect(av, vehicle)
    if not slua.isValid(av) then return end
    if not F.isInRealMatch() then
        pcall(function() av.curSwitchEffectId = 0 end)
        return
    end
    pcall(function()
        av.curSwitchEffectId = VEH_SWITCH_EFFECT_ID
        local defaultId = 0
        pcall(function() defaultId = tonumber(av:GetDefaultAvatarID()) or 0 end)
        local curId = 0
        if slua.isValid(vehicle) then
            pcall(function() curId = tonumber(vehicle.GetAvatarId and vehicle:GetAvatarId()) or 0 end)
            if curId <= 0 then
                pcall(function() curId = tonumber(vehicle.ClientUsedAvatarID) or 0 end)
            end
        end
        if curId <= 0 then curId = defaultId end
        if not av.lastEquipedAvatarId or av.lastEquipedAvatarId <= 0 then
            av.lastEquipedAvatarId = curId > 0 and curId or defaultId
        end
    end)
end

function F.isParachuteRes(resID)
    return F.subType(F.cfg(tonumber(resID))) == PARACHUTE_SUB
end

function F.isGlideRes(resID)
    resID = tonumber(resID)
    if not resID then return false end
    local st = F.subType(F.cfg(resID))
    if GLIDER_SUBS[st] then return true end
    local ok, r = pcall(function()
        local MDH = require("client.logic.avatar.ModelDisplayTypeHelper")
        if MDH.IsGlideByItemID and MDH.IsGlideByItemID(resID) then return true end
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        return wd.IsGlideType(st)
    end)
    return ok and r == true
end

function F.isVehicleRes(resID)
    resID = tonumber(resID)
    if not resID or F.isChassisLightId(resID) then return false end
    local st = tonumber(F.subType(F.cfg(resID)))
    return st and st >= 900 and st < 7000 and st ~= CHASSIS_LIGHT_SUB
end

function F.ensureInjectedItemAlive(entity, resID, insID)
    entity = entity or F.getEntity()
    insID = tonumber(insID) or (resID and R.resToIns[tonumber(resID)])
    resID = tonumber(resID) or (insID and R.insToRes[insID])
    if not entity or not insID then return end
    pcall(function()
        local d = entity:GetDataByInsID(insID)
        if d then
            d.expire_ts = 0
            d.expireTS = 0
            d.valid_hours = 0
        end
    end)
end

function F.sanitizeAllInjectedExpire()
    local entity = F.getEntity()
    if not entity then return end
    for res, ins in pairs(R.resToIns) do
        F.ensureInjectedItemAlive(entity, res, ins)
    end
end

function F.putOnVehicle(insID)
    insID = tonumber(insID)
    if not insID then return false end
    local resID = R.insToRes[insID]
    if not resID or not F.isVehicleRes(resID) then return false end
    F.ensureInjectedItemAlive(nil, resID, insID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return false
    end
    local item = {
        res_id = resID, resID = resID,
        instid = insID, ins_id = insID, insID = insID,
        expire_ts = 0, expireTS = 0, count = 1,
    }
    local WRH = require("client.network.Protocol.WardRobeHandler")
    WRH.on_depot_put_on_rsp(NET_OK, item, nil, 1, insID, 0)
    F.setLobbyVehicleManual(F.vehicleSubType(resID), resID, insID)
    pcall(function()
        local TabSurveillance = require("client.slua.logic.wardrobe.tab_surveillance")
        TabSurveillance.VehicleChange()
    end)
    pcall(function()
        if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_ITEM_LIST then
            EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST)
        end
    end)
    return true
end

function F.isChassisLightId(id)
    return CHASSIS_LIGHT_IDS[tonumber(id)] == true
end

function F.getDesiredChassisLight(vehicleSkinId)
    vehicleSkinId = tonumber(vehicleSkinId)
    local map = PERSIST.configChassisLightMap
    if vehicleSkinId and map and map[vehicleSkinId] then
        local v = tonumber(map[vehicleSkinId])
        if F.isChassisLightId(v) then return v end
    end
    local def = tonumber(PERSIST.configChassisLight) or DEFAULT_CHASSIS_LIGHT
    return F.isChassisLightId(def) and def or DEFAULT_CHASSIS_LIGHT
end

function F.saveChassisLight(vehicleSkinId, lightId)
    vehicleSkinId = tonumber(vehicleSkinId)
    lightId = tonumber(lightId)
    if not F.isChassisLightId(lightId) then return end
    PERSIST.configChassisLightMap = PERSIST.configChassisLightMap or {}
    if vehicleSkinId and vehicleSkinId > 0 then
        PERSIST.configChassisLightMap[vehicleSkinId] = lightId
    else
        PERSIST.configChassisLight = lightId
    end
    F.requestResourceDownload(lightId)
    F.persistMarkDirty()
end

function F.getVehicleLicenseComp(vehicle)
    if not slua.isValid(vehicle) then return nil end
    local lic = nil
    pcall(function()
        if vehicle.GetLicenseComponent then lic = vehicle:GetLicenseComponent() end
    end)
    if slua.isValid(lic) then return lic end
    pcall(function() lic = vehicle.BP_Lobby_VehicleLicenseComponent end)
    if slua.isValid(lic) then return lic end
    pcall(function()
        local cls = import("VehicleLicenseNumberComponent")
        lic = vehicle:GetComponentByClass(cls)
    end)
    return slua.isValid(lic) and lic or nil
end

function F.applyVehicleChassisLight(vehicle, skinId, lightId)
    if _G.LexusConfig and _G.LexusConfig.ModSkin == false then return false end 
    
    skinId = tonumber(skinId)
    lightId = tonumber(lightId) or F.getDesiredChassisLight(skinId)
    if not F.isChassisLightId(lightId) then return false end
    if not slua.isValid(vehicle) then return false end
    if skinId and skinId > 0 then
        F.requestResourceDownload(skinId)
    end
    F.requestResourceDownload(lightId)
    local applied = false
    pcall(function()
        if vehicle.SetChassisLightShowData then
            vehicle:SetChassisLightShowData(lightId)
            applied = true
        end
    end)
    local lic = F.getVehicleLicenseComp(vehicle)
    if not slua.isValid(lic) then return applied end
    pcall(function()
        local vid = skinId
        if not vid or vid <= 0 then
            pcall(function()
                if vehicle.GetAvatarId then vid = tonumber(vehicle:GetAvatarId()) end
            end)
        end
        if not vid or vid <= 0 then
            pcall(function() vid = tonumber(lic.LicensePlate and lic.LicensePlate.ItemID) end)
        end
        if vid and vid > 0 then
            lic.curVehicleAvatarId = vid
            if lic.ChangeNetData_ItemID then
                lic:ChangeNetData_ItemID(vid)
            elseif lic.LicensePlate then
                lic.LicensePlate.ItemID = vid
            end
        end
        if lic.LicensePlate then
            lic.LicensePlate.ChassisLightId = lightId
        end
        if lic.SetChassisLightData and vid and vid > 0 then
            lic:SetChassisLightData(vid, lightId)
        elseif lic.PreChangeChassisLight then
            lic:PreChangeChassisLight()
        end
        applied = true
    end)
    return applied
end

function F.scheduleChassisLightApply(vehicle, skinId)
    skinId = tonumber(skinId)
    local vref = slua.isValid(vehicle) and vehicle or nil
    local function try()
        local v = slua.isValid(vref) and vref or F.getCurrentVehicleForSkin()
        if slua.isValid(v) then
            F.applyVehicleChassisLight(v, skinId)
        end
    end
    F.later(0.4, try)
    F.later(1.1, try)
end

function F.getVehicleShape(vehicle)
    if not slua.isValid(vehicle) then return nil end
    local shape = vehicle.VehicleShapeType
    if shape and tonumber(shape) >= 0 then return tonumber(shape) end
    pcall(function()
        local UAvatarUtils = import("AvatarUtils")
        local defId = vehicle.AvatarDefaultCfg and vehicle.AvatarDefaultCfg.TypeSpecificID
        if defId and tonumber(defId) > 0 then
            shape = UAvatarUtils.GetVehicleShapeBySkinID(tonumber(defId))
        end
    end)
    return shape and tonumber(shape) >= 0 and tonumber(shape) or nil
end

function F.getDesiredVehicleSkinForShape(shape)
    shape = tonumber(shape)
    if not shape or shape < 0 then return nil end
    F.syncVehicleCacheFromDataMgr()
    local UAvatarUtils = import("AvatarUtils")
    local vst = F.buildVstInBattleFromSlots()
    for _, list in pairs(vst) do
        local skin = list and tonumber(list[1])
        if skin and skin > 0 then
            local s = UAvatarUtils.GetVehicleShapeBySkinID(skin)
            if s == shape then return skin end
        end
    end
    local pc = F.getPC()
    if slua.isValid(pc) and pc.VehicleAvatarList then
        local skin = tonumber(pc.VehicleAvatarList:Get(shape))
        if skin and skin > 0 then return skin end
    end
    return nil
end

function F.getVehicleAvatarComp(vehicle)
    if not slua.isValid(vehicle) then return nil end
    local av = nil
    pcall(function() av = vehicle.VehicleAvatar end)
    if slua.isValid(av) then return av end
    pcall(function() if vehicle.GetAvatarComponent then av = vehicle:GetAvatarComponent() end end)
    if slua.isValid(av) then return av end
    pcall(function() av = vehicle.VehicleAvatarComponent_BP end)
    if slua.isValid(av) then return av end
    return nil
end

function F.getCurrentVehicleForSkin()
    local char = F.getLocalChar()
    if char and slua.isValid(char) then
        local v = nil
        pcall(function() v = char.CurrentVehicle end)
        if slua.isValid(v) then return v end
    end
    return F.getMatchVehicle()
end

function F.forceVehicleAvatar(skinId, vehicle)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    if not F.isResourcesReady(skinId) then
        F.requestResourceDownload(skinId)
        return false
    end
    vehicle = slua.isValid(vehicle) and vehicle or F.getCurrentVehicleForSkin()
    if not slua.isValid(vehicle) then return false end
    local av = F.getVehicleAvatarComp(vehicle)
    if not slua.isValid(av) then return false end
    local applied = false
    F.prepVehicleSwitchEffect(av, vehicle)
    pcall(function() if av.CanChangeAvatar ~= nil then av.CanChangeAvatar = true end end)
    pcall(function()
        av:ChangeItemAvatar(skinId, true)
        applied = true
        _G.CurrentEquipVehicleID = skinId
    end)
    if applied then F.scheduleChassisLightApply(vehicle, skinId) end
    return applied
end

function F.vehicleAvatarTemper()
    local vehicle = F.getCurrentVehicleForSkin()
    if not slua.isValid(vehicle) then return end
    local av = F.getVehicleAvatarComp(vehicle)
    if not slua.isValid(av) then return end

    local defaultId = 0
    pcall(function() defaultId = tonumber(av:GetDefaultAvatarID()) or 0 end)
    if defaultId <= 0 then return end

    local shape = nil
    pcall(function() shape = tonumber(import("AvatarUtils").GetVehicleShapeBySkinID(defaultId)) end)

    local skinId = nil
    if VEHSEL.override and slua.isValid(VEHSEL.overrideVehicle) and VEHSEL.overrideVehicle == vehicle then
        skinId = VEHSEL.override
    end
    if not skinId and shape then skinId = VEHSEL.byShape[shape] end
    if not skinId then skinId = F.getDesiredVehicleSkinForShape(shape) end
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 or skinId == defaultId then return end

    local cur = 0
    pcall(function() cur = tonumber(vehicle.GetAvatarId and vehicle:GetAvatarId()) or 0 end)
    if cur <= 0 then
        pcall(function() cur = tonumber(vehicle.GetVehicleSkinItemID and vehicle:GetVehicleSkinItemID()) or 0 end)
    end
    if cur == skinId then return end

    F.forceVehicleAvatar(skinId, vehicle)
end

function F.vehicleSkinTick()
    F.vehicleAvatarTemper()
    
    pcall(function()
        local char = F.getLocalChar()
        if char then F.matchApplyFaceWear(char) end
    end)

    local now = os.clock()
    if now - _vehTickLastApply < 5.0 then return end
    _vehTickLastApply = now
    F.applyVehicleSkinsToPC()
end

function F.startVehicleSkinTicker()
    pcall(function()
        if not _ticker then return end
        if _G.AddOutfitVehTickerId then return end
        if _ticker.AddTimerLoop then
            _G.AddOutfitVehTickerId = _ticker.AddTimerLoop(1.0, function()
                local fn = _G.AddOutfit and _G.AddOutfit.vehicleSkinTick
                if fn then pcall(fn) end
            end, -1, 1.0)
        end
    end)
end

function F.matchApplyVehicleSkin(skinId)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end

    local vehicle = F.getCurrentVehicleForSkin()

    VEHSEL.override = skinId
    VEHSEL.overrideVehicle = slua.isValid(vehicle) and vehicle or nil

    pcall(function()
        local UAvatarUtils = import("AvatarUtils")
        local shape = tonumber(UAvatarUtils.GetVehicleShapeBySkinID(skinId))
        if shape and shape >= 0 then VEHSEL.byShape[shape] = skinId end
        local av = F.getVehicleAvatarComp(vehicle)
        if slua.isValid(av) then
            local defaultId = tonumber(av:GetDefaultAvatarID()) or 0
            if defaultId > 0 then
                local defShape = tonumber(UAvatarUtils.GetVehicleShapeBySkinID(defaultId))
                if defShape and defShape >= 0 then VEHSEL.byShape[defShape] = skinId end
            end
        end
    end)

    F.applyVehicleSkinsToPC(F.getPC())
    local ok = F.forceVehicleAvatar(skinId, vehicle)
    F.startVehicleSkinTicker()
    return ok
end

function F.autoApplyVehicleSkinOnEnter(vehicle)
    if not slua.isValid(vehicle) then return end
    F.syncVehicleCacheFromDataMgr()
    F.applyVehicleSkinsToPC(F.getPC())
    F.startVehicleSkinTicker()
    F.later(0.35, function() pcall(F.vehicleAvatarTemper) end)
    F.later(0.9, function() pcall(F.vehicleAvatarTemper) end)
    F.later(0.5, function()
        local skinId = nil
        pcall(function() skinId = tonumber(vehicle.GetAvatarId and vehicle:GetAvatarId()) end)
        F.scheduleChassisLightApply(vehicle, skinId)
    end)
end

local function GetOutfitConfigPaths(fileName)
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName,
        "ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../ShadowTrackerExtra/Saved/Paks/" .. fileName
    }
    pcall(function()
        if os and os.getenv then
            local homeDir = os.getenv("HOME")
            if homeDir and homeDir ~= "" then
                table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName)
            end
        end
    end)
    return paths
end

local CONFIG_PATHS = GetOutfitConfigPaths("bizapro.json")

local PERSIST_SLOTS = {
    { "outfit", "outfitRes", "outfitIns", "AddOutfitLastLobbyOutfitRes" },
    { "tshirt", "tshirtRes", "tshirtIns", "AddOutfitLastLobbyTshirtRes" },
    { "pants",  "pantsRes",  "pantsIns",  "AddOutfitLastLobbyPantsRes"  },
    { "shoes",  "shoesRes",  "shoesIns",  "AddOutfitLastLobbyShoesRes"  },
    { "hat",    "hatRes",    "hatIns",    "AddOutfitLastLobbyHatRes"    },
    { "mask",   "maskRes",   "maskIns",   "AddOutfitLastLobbyMaskRes"   },
    { "glass",  "glassRes",  "glassIns",  "AddOutfitLastLobbyGlassRes"  },
    { "bag",    "bagRes",    "bagIns",    "AddOutfitLastLobbyBagRes"    },
    { "helmet", "helmetRes", "helmetIns", "AddOutfitLastLobbyHelmetRes" },
    { "parachute", "parachuteRes", "parachuteIns", "AddOutfitLastLobbyParachuteRes" },
    { "glider", "gliderRes", "gliderIns", "AddOutfitLastLobbyGliderRes" },
    { "gloves", "glovesRes", "glovesIns", "AddOutfitLastLobbyGlovesRes" },
}

function F.isPersistableWearRes(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return false end
    if F.isInjectedRes(resID) then return true end
    if F.isParachuteRes(resID) or F.isGlideRes(resID) then return true end
    if PERSIST.configSlots then
        for _, v in pairs(PERSIST.configSlots) do
            if tonumber(v) == resID then return true end
        end
    end
    return false
end
-- ============================================================================
-- EMOTE PERSISTENCE HELPERS
-- ============================================================================
function F.saveEmoteSlot(resID, slot)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return end
    PERSIST.configEmotes = PERSIST.configEmotes or {}
    for _, v in ipairs(PERSIST.configEmotes) do
        if tonumber(v) == resID then return end   -- already saved
    end
    PERSIST.configEmotes[#PERSIST.configEmotes + 1] = resID
    F.persistMarkDirty()
end

function F.removeEmoteSlot(resID)
    resID = tonumber(resID)
    if not resID or not PERSIST.configEmotes then return end
    for i, v in ipairs(PERSIST.configEmotes) do
        if tonumber(v) == resID then
            table.remove(PERSIST.configEmotes, i)
            break
        end
    end
    F.persistMarkDirty()
end
function F.persistRememberSlot(slotName, resID)
    slotName = slotName and tostring(slotName)
    resID = tonumber(resID)
    if not slotName or not resID or resID <= 0 then return end
    PERSIST.configSlots = PERSIST.configSlots or {}
    PERSIST.configSlots[slotName] = resID
end

function F.persistForgetSlot(slotName)
    if PERSIST.configSlots and slotName then
        PERSIST.configSlots[tostring(slotName)] = nil
    end
end

function F.persistLoadSlotsFromSaved(saved)
    if type(saved) ~= "table" then return end
    PERSIST.configSlots = PERSIST.configSlots or {}
    for _, s in ipairs(PERSIST_SLOTS) do
        local res = tonumber(saved[s[1]])
        if res and res > 0 then PERSIST.configSlots[s[1]] = res end
    end
    F.applyPersistSlotsToCache()
end

function F.resolveInsForRes(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return nil end
    if R.resToIns[resID] then return R.resToIns[resID] end
    local ins
    pcall(function()
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local list = wd.GetHallDepotItemListByResID and wd:GetHallDepotItemListByResID(resID)
        if list then
            for _, v in pairs(list) do
                local id = tonumber(v.insID or v.instid or v.ins_id)
                if id and id > 0 then ins = id break end
            end
        end
        if not ins then
            local d = wd.GetValidHallDepotItemDataByInsID and wd:GetValidHallDepotItemDataByInsID(resID)
            if not d and wd.GetHallDepotItemDataByResID then
                d = wd:GetHallDepotItemDataByResID(resID)
            end
            if d then ins = tonumber(d.insID or d.instid or d.ins_id) end
        end
    end)
    return ins
end

function F.applyPersistSlotsToCache()
    if not PERSIST.configSlots then return end
    local cch = F.cache()
    for _, s in ipairs(PERSIST_SLOTS) do
        local slotName, cacheResKey, cacheInsKey, globalKey = s[1], s[2], s[3], s[4]
        local res = tonumber(PERSIST.configSlots[slotName])
        if res and res > 0 then
            cch[cacheResKey] = res
            _G[globalKey] = res
            local ins = F.resolveInsForRes(res)
            if ins and ins > 0 then cch[cacheInsKey] = ins end
        end
    end
end

function F.getDesiredGliderRes()
    F.applyPersistSlotsToCache()
    local r = tonumber(PERSIST.configSlots and PERSIST.configSlots.glider)
    if r and r > 0 then return r end
    F.syncAirborneCacheFromLobby()
    return F.getDesiredWear("gliderRes", "gliderRes", "AddOutfitLastLobbyGliderRes")
end

function F.getDesiredParachuteRes()
    F.applyPersistSlotsToCache()
    local r = tonumber(PERSIST.configSlots and PERSIST.configSlots.parachute)
    if r and r > 0 then return r end
    F.syncAirborneCacheFromLobby()
    return F.getDesiredWear("parachuteRes", "parachuteRes", "AddOutfitLastLobbyParachuteRes")
end

function F.getAvatarComp2(char)
    if not char or not slua.isValid(char) then return nil end
    local comp
    pcall(function()
        if char.getAvatarComponent2 then
            comp = char:getAvatarComponent2()
        end
        if (not comp or not slua.isValid(comp)) and char.AvatarComponent2 then
            comp = char.AvatarComponent2
        end
        if (not comp or not slua.isValid(comp)) and char.CharacterAvatarComp2_BP then
            comp = char.CharacterAvatarComp2_BP
        end
    end)
    return comp
end

function F.isCharacterAirborne(char)
    if not char or not slua.isValid(char) then return false end
    local ok, r = pcall(function()
        local EParachuteState = import("EParachuteState")
        local st = char.ParachuteState
        return st and st ~= EParachuteState.PS_None
    end)
    return ok and r == true
end

function F.reapplyWeaponsFromConfig()
    local wmap = F.sanitizeConfigWeapons(PERSIST.configWeapons)
    local dropped = false
    for k in pairs(PERSIST.configWeapons or {}) do
        if not wmap[tonumber(k) or k] then dropped = true break end
    end
    PERSIST.configWeapons = wmap
    if dropped then F.persistMarkDirty() end
    if not next(wmap) then return false end
    local cch = F.cache()
    local any = false
    for wid, res in pairs(wmap) do
        wid, res = tonumber(wid), tonumber(res)
        local ins = res and R.resToIns[res]
        if wid and ins and F.isInjectedIns(ins) then
            cch.weapons[wid] = { resID = res, insID = ins }
            if F.equipWeaponSkin(wid, ins) then
                any = true
            else
                F.syncWeaponArmorySilent(wid, ins)
            end
        end
    end
    return any
end

function F.persistEncode()
    local cch = F.cache()
    local parts = {}
    for _, s in ipairs(PERSIST_SLOTS) do
        local res = tonumber(PERSIST.configSlots and PERSIST.configSlots[s[1]])
            or tonumber(cch[s[2]])
        if res and res > 0 and F.isPersistableWearRes(res) then
            parts[#parts + 1] = string.format('  "%s": %d', s[1], res)
        end
    end
    local wparts = {}
    local wmap = {}
    for wid, res in pairs(F.sanitizeConfigWeapons(PERSIST.configWeapons)) do
        wmap[wid] = res
    end
    for wid, w in pairs(cch.weapons or {}) do
        local res = w and tonumber(w.resID)
        wid = tonumber(wid)
        if F.isValidWeaponPersistEntry(wid, res) then wmap[wid] = res end
    end
    for wid, res in pairs(wmap) do
        wparts[#wparts + 1] = string.format('    "%d": %d', wid, res)
    end
    table.sort(wparts)
    parts[#parts + 1] = '  "weapons": {\n' .. table.concat(wparts, ",\n") .. "\n  }"
    local vparts = {}
    local function appendVehicleSlots(src)
        for subType, slots in pairs(src or {}) do
            local sparts = {}
            if type(slots) == "table" then
                for idx, val in pairs(slots) do
                    local res = type(val) == "table" and tonumber(val.resID) or tonumber(val)
                    if res and res > 0 then
                        sparts[#sparts + 1] = string.format('      "%d": %d', tonumber(idx), res)
                    end
                end
            end
            table.sort(sparts)
            if #sparts > 0 then
                vparts[#vparts + 1] = string.format('    "%d": {\n%s\n    }', tonumber(subType), table.concat(sparts, ",\n"))
            end
        end
    end
    local hasCacheSlots = false
    for _ in pairs(cch.vehicleSlots or {}) do hasCacheSlots = true; break end
    if hasCacheSlots then
        appendVehicleSlots(cch.vehicleSlots)
    elseif PERSIST.configVehicleSlots then
        appendVehicleSlots(PERSIST.configVehicleSlots)
    end
    table.sort(vparts)
    parts[#parts + 1] = '  "vehicleSlots": {\n' .. table.concat(vparts, ",\n") .. "\n  }"
    if PERSIST.lobbyVehicleSubType and PERSIST.lobbyVehicleSubType > 0
        and PERSIST.lobbyVehicleSubType ~= CHASSIS_LIGHT_SUB
        and not F.isChassisLightId(PERSIST.lobbyVehicleResID)
        and F.isVehicleRes(PERSIST.lobbyVehicleResID) then
        parts[#parts + 1] = string.format('  "lobbyVehicleSubType": %d', PERSIST.lobbyVehicleSubType)
    end
    if PERSIST.lobbyVehicleResID and PERSIST.lobbyVehicleResID > 0
        and F.isVehicleRes(PERSIST.lobbyVehicleResID) then
        parts[#parts + 1] = string.format('  "lobbyVehicleResID": %d', PERSIST.lobbyVehicleResID)
    end
    if PERSIST.lobbyVehicleIns and PERSIST.lobbyVehicleIns > 0
        and F.isVehicleRes(PERSIST.lobbyVehicleResID or R.insToRes[PERSIST.lobbyVehicleIns]) then
        parts[#parts + 1] = string.format('  "lobbyVehicleIns": %d', PERSIST.lobbyVehicleIns)
    end
    local hres = tonumber(cch.hallThemeRes) or tonumber(PERSIST.hallThemeResID)
    if hres and hres > 0 and F.isInjectedRes(hres) then
        parts[#parts + 1] = string.format('  "hallTheme": %d', hres)
    end
    local cl = tonumber(PERSIST.configChassisLight)
    if F.isChassisLightId(cl) then
        parts[#parts + 1] = string.format('  "chassisLight": %d', cl)
    end
    local cmap = PERSIST.configChassisLightMap
    if cmap and next(cmap) then
        local cparts = {}
        for vid, lid in pairs(cmap) do
            vid, lid = tonumber(vid), tonumber(lid)
            if vid and vid > 0 and F.isChassisLightId(lid) then
                cparts[#cparts + 1] = string.format('    "%d": %d', vid, lid)
            end
        end
        table.sort(cparts)
        if #cparts > 0 then
            parts[#parts + 1] = '  "chassisLightMap": {\n' .. table.concat(cparts, ",\n") .. "\n  }"
        end
    end
    local emotes = PERSIST.configEmotes
    if emotes and next(emotes) then
        local eparts = {}
        for _, res in pairs(emotes) do   -- ✅ pairs (not ipairs)
            res = tonumber(res)
            if res and res > 0 then
                eparts[#eparts + 1] = tostring(res)
            end
        end
        if #eparts > 0 then
            parts[#parts + 1] = '  "emotes": [' .. table.concat(eparts, ", ") .. ']'
        end
    end
    return "{\n" .. table.concat(parts, ",\n") .. "\n}\n"
end

function F.persistWrite(txt)
    if not (io and io.open) then return false end
    if PERSIST.path then
        local f
        pcall(function() f = io.open(PERSIST.path, "w") end)
        if f then f:write(txt) f:close() return true end
        PERSIST.path = nil
    end
    for _, p in ipairs(CONFIG_PATHS) do
        local f
        pcall(function() f = io.open(p, "w") end)
        if not f then
            pcall(function()
                local dir = p:match("^(.*)/[^/]+$")
                if dir and os and os.execute then os.execute('mkdir -p "' .. dir .. '"') end
            end)
            pcall(function() f = io.open(p, "w") end)
        end
        if f then
            f:write(txt) f:close()
            PERSIST.path = p
            return true
        end
    end
    return false
end

function F.persistFlush()
    if not PERSIST.dirty then return end
    PERSIST.dirty = false
    pcall(function()
        local txt = F.persistEncode()
        if txt == PERSIST.lastWritten then return end
        if F.persistWrite(txt) then
            PERSIST.lastWritten = txt
        end
    end)
end

F.persistMarkDirty = function()
    PERSIST.dirty = true
    if PERSIST.scheduled then return end
    PERSIST.scheduled = true
    F.later(2.0, function()
        PERSIST.scheduled = false
        F.persistFlush()
    end)
end

function F.persistParse(txt)
    if not txt or #txt == 0 then return nil end
    local out = { weapons = {}, vehicleSlots = {} }
    local parsed = false
    pcall(function()
        local t = json and json.decode and json.decode(txt)
        if type(t) == "table" then
            for k, v in pairs(t) do
                if k == "weapons" and type(v) == "table" then
                    for wk, wv in pairs(v) do
                        local wid, res = tonumber(wk), tonumber(wv)
                        if F.isValidWeaponPersistEntry(wid, res) then out.weapons[wid] = res end
                    end
                elseif k == "vehicleSlots" and type(v) == "table" then
                    for stk, slotMap in pairs(v) do
                        local st = tonumber(stk)
                        if st then
                            out.vehicleSlots[st] = out.vehicleSlots[st] or {}
                            for idxStr, res in pairs(slotMap) do
                                local idx, r = tonumber(idxStr), tonumber(res)
                                if idx and r and r > 0 then out.vehicleSlots[st][idx] = r end
                            end
                        end
                    end
                elseif k == "chassisLightMap" and type(v) == "table" then
                    out.chassisLightMap = {}
                    for vk, lv in pairs(v) do
                        local vid, lid = tonumber(vk), tonumber(lv)
                        if vid and lid and F.isChassisLightId(lid) then
                            out.chassisLightMap[vid] = lid
                        end
                    end
                elseif k == "emotes" and type(v) == "table" then
                    out.emotes = {}
                    local seen = {}
                    for _, n in pairs(v) do
                        local num = tonumber(n)
                        if num and num > 0 and not seen[num] then
                            seen[num] = true
                            out.emotes[#out.emotes + 1] = num
                        end
                    end
                else
                    local n = tonumber(v)
                    if n and n > 0 then out[k] = n end
                end
            end
            parsed = true
        end
    end)
    if not parsed then
        for k, v in txt:gmatch('"([%w_]+)"%s*:%s*(%d+)') do
            local n = tonumber(v)
            if n and n > 0 then
                local wid = tonumber(k)
                if wid and F.isValidWeaponPersistEntry(wid, n) then
                    out.weapons[wid] = n
                elseif not wid then
                    out[k] = n
                end
            end
        end
        local emoteStr = txt:match('"emotes"%s*:%s*%[([^%]]*)%]')
        if emoteStr then
            out.emotes = {}
            local seen = {}
            for n in emoteStr:gmatch("%d+") do
                local num = tonumber(n)
                if num and num > 0 and not seen[num] then
                    seen[num] = true
                    out.emotes[#out.emotes + 1] = num
                end
            end
        end
    end
    return out
end

function F.persistLoadFromDisk()
    if not (io and io.open) then return end
    pcall(function()
        for _, p in ipairs(CONFIG_PATHS) do
            local f
            pcall(function() f = io.open(p, "r") end)
            if f then
                local txt = f:read("*a")
                f:close()
                PERSIST.path = p
                PERSIST.lastWritten = txt
                PERSIST.loaded = F.persistParse(txt)
                F.persistLoadSlotsFromSaved(PERSIST.loaded)
                if PERSIST.loaded and PERSIST.loaded.vehicleSlots then
                    PERSIST.configVehicleSlots = PERSIST.loaded.vehicleSlots
                end
                if PERSIST.loaded and PERSIST.loaded.weapons then
                    local raw = PERSIST.loaded.weapons
                    PERSIST.configWeapons = F.sanitizeConfigWeapons(raw)
                    if next(raw) and not next(PERSIST.configWeapons) then
                        F.persistMarkDirty()
                    elseif next(raw) then
                        for wid, res in pairs(raw) do
                            if not F.isValidWeaponPersistEntry(tonumber(wid), tonumber(res)) then
                                F.persistMarkDirty()
                                break
                            end
                        end
                    end
                end
                PERSIST.lobbyVehicleSubType = tonumber(PERSIST.loaded and PERSIST.loaded.lobbyVehicleSubType)
                PERSIST.lobbyVehicleResID = tonumber(PERSIST.loaded and PERSIST.loaded.lobbyVehicleResID)
                PERSIST.lobbyVehicleIns = tonumber(PERSIST.loaded and PERSIST.loaded.lobbyVehicleIns)
                if PERSIST.lobbyVehicleSubType or PERSIST.lobbyVehicleIns or PERSIST.lobbyVehicleResID then
                    if F.isChassisLightId(PERSIST.lobbyVehicleResID)
                        or PERSIST.lobbyVehicleSubType == CHASSIS_LIGHT_SUB
                        or not F.isVehicleRes(PERSIST.lobbyVehicleResID) then
                        PERSIST.lobbyVehicleSubType = nil
                        PERSIST.lobbyVehicleResID = nil
                        PERSIST.lobbyVehicleIns = nil
                    else
                        _G.AddOutfitLobbyVeh = _G.AddOutfitLobbyVeh or {}
                        _G.AddOutfitLobbyVeh.manual = true
                        _G.AddOutfitLobbyVeh.subType = PERSIST.lobbyVehicleSubType
                        _G.AddOutfitLobbyVeh.resID = PERSIST.lobbyVehicleResID
                        _G.AddOutfitLobbyVeh.insID = PERSIST.lobbyVehicleIns
                    end
                end
                PERSIST.hallThemeResID = tonumber(PERSIST.loaded and PERSIST.loaded.hallTheme)
                PERSIST.hallThemeIns = nil
                if PERSIST.hallThemeResID then
                    _G.AddOutfitLobbyTheme = _G.AddOutfitLobbyTheme or {}
                    _G.AddOutfitLobbyTheme.manual = true
                    _G.AddOutfitLobbyTheme.resID = PERSIST.hallThemeResID
                end
                PERSIST.configChassisLight = tonumber(PERSIST.loaded and PERSIST.loaded.chassisLight)
                if PERSIST.loaded and PERSIST.loaded.chassisLightMap then
                    PERSIST.configChassisLightMap = PERSIST.loaded.chassisLightMap
                end
                return
            end
        end
    end)
end

function F.persistApplyLoaded()
    local saved = PERSIST.loaded
    if not saved then return end
    PERSIST.loaded = nil
    local cch = F.cache()
    local any = false
    for _, s in ipairs(PERSIST_SLOTS) do
        local res = tonumber(saved[s[1]]) or tonumber(PERSIST.configSlots and PERSIST.configSlots[s[1]])
        if res and res > 0 and not cch[s[2]] then
            local ins = R.resToIns[res]
            if ins then
                cch[s[2]], cch[s[3]] = res, ins
                _G[s[4]] = res
                any = true
            end
        end
    end
    PERSIST.configWeapons = F.sanitizeConfigWeapons(saved.weapons or PERSIST.configWeapons)
    if saved.weapons and F.reapplyWeaponsFromConfig() then
        any = true
    end
    if saved.vehicleSlots then
        PERSIST.configVehicleSlots = saved.vehicleSlots
        if F.reapplyVehicleSlotsFromConfig(true) then
            any = true
        end
    end
    if saved.hallTheme then
        PERSIST.hallThemeResID = tonumber(saved.hallTheme)
        if PERSIST.hallThemeResID and F.reapplyHallThemeFromConfig(true) then
            any = true
        end
    end
    if saved.chassisLight then
        PERSIST.configChassisLight = tonumber(saved.chassisLight)
    end
    if saved.chassisLightMap then
        PERSIST.configChassisLightMap = saved.chassisLightMap
    end
    if saved.emotes and next(saved.emotes) then
        PERSIST.configEmotes = saved.emotes
        F.later(1.0, function()
            pcall(F.reapplyEmotesFromConfig)
        end)
    end
    if any then
        _matchApplied = false
        F.perfInvalidateLobby()
    end
end

function F.getEntity()
    local ok, dc = pcall(require, "client.slua.logic.wardrobe.logic_wardrobe_data_center")
    if not ok or not dc then return nil end
    local ok2, e = pcall(dc.GetWardrobeData)
    return ok2 and e or nil
end

function F.firstInsForRes(entity, resID)
    local arr = entity.ResIDToIndexArrayMap and entity.ResIDToIndexArrayMap[resID]
    if not arr then return nil end
    for _, idx in pairs(arr) do
        local d = entity._data[idx]
        if d and d.count and d.count > 0 then return d.insID end
    end
    return nil
end

function F.injectOne(entity, resID, insID)
    local ownedIns = F.firstInsForRes(entity, resID)
    if ownedIns then
        F.ensureInjectedItemAlive(entity, resID, ownedIns)
        R.resToIns[resID] = ownedIns
        R.insToRes[ownedIns] = resID
        F.indexWeaponSkin(resID, ownedIns)
        return true
    end
    local row = {
        instid = insID,
        res_id = resID,
        count = 1,
        lock_cnt = 0,
        isnew = 0,
        valid_hours = 0,
        expire_ts = 0,
    }
    entity:AddData(row)
    pcall(function()
        if entity.LoadConfigForData and CDataTable and CDataTable.GetTableData then
            local idx = entity._DataCount
            if idx and entity._data[idx] then
                entity:LoadConfigForData(entity._data[idx], CDataTable.GetTableData)
            end
        end
    end)
    R.insToRes[insID] = resID
    R.resToIns[resID] = insID
    F.indexWeaponSkin(resID, insID)
    return true
end

function F.reviveExpiredOwned(entity)
    entity = entity or F.getEntity()
    if not entity or not entity.bInit or not entity._data then return end
    local now = 0
    pcall(function()
        local TimeUtil = require("client.common.time_util")
        now = tonumber(TimeUtil.GetServerTimeInSec()) or 0
    end)
    if now <= 0 then return end
    _G.AddOutfitRevived = _G.AddOutfitRevived or {}
    local n = 0
    for i = 1, (entity._DataCount or #entity._data) do
        local d = entity._data[i]
        if d then
            local exp = tonumber(d.expire_ts or d.expireTS) or 0
            local res = tonumber(d.res_id or d.resID)
            local ins = tonumber(d.instid or d.insID)
            if exp > 0 and exp <= now and res and ins and (tonumber(d.count) or 0) > 0 then
                d.expire_ts = 0
                if d.expireTS ~= nil then d.expireTS = 0 end
                if d.valid_hours ~= nil then d.valid_hours = 0 end
                _G.AddOutfitRevived[res] = ins
                n = n + 1
            end
        end
    end
end

function F.mergeRevivedIntoMaps()
    for res, ins in pairs(_G.AddOutfitRevived or {}) do
        if not R.resToIns[res] then
            R.resToIns[res] = ins
            R.insToRes[ins] = res
            F.indexWeaponSkin(res, ins)
        end
    end
end

function F.injectArmory(resID, insID)
    local wid = F.weaponIdFromSkin(resID)
    if not wid then return end
    local Arm = require("client.logic.armory.logic_armory")
    Arm.rsp_list = Arm.rsp_list or { skin_list = {}, install_list = {} }
    Arm.rsp_list.skin_list = Arm.rsp_list.skin_list or {}
    Arm.rsp_list.install_list = Arm.rsp_list.install_list or {}
    if not Arm.rsp_list.skin_list[wid] then Arm.rsp_list.skin_list[wid] = {} end
    Arm.rsp_list.skin_list[wid][resID] = { is_open = 1 }
    Arm.WardrobeInsList = Arm.WardrobeInsList or {}
    Arm.WardrobeInsList[resID] = insID
end

function F.mergeInjectedArmorySkins()
    for _, skins in pairs(R.byWeapon) do
        for resID, insID in pairs(skins) do
            F.injectArmory(resID, insID)
        end
    end
end

function F.injectAll(entity)
    if _G.LexusConfig and _G.LexusConfig.ModSkin == false then return false end
    entity = entity or F.getEntity()
    if not entity or not entity.bInit then return false end
    local n, nNew = 0, 0
    for i, resID in ipairs(ITEMS) do
        local insID = INS_BASE + i
        local had = R.resToIns[resID] ~= nil
        if F.injectOne(entity, resID, insID) then
            n = n + 1
            if not had then nNew = nNew + 1 end
            local c = F.cfg(resID)
            if GUN_SUB[F.subType(c)] or F.subType(c) == MELEE_ID then
                F.injectArmory(resID, insID)
            end
        end
    end
    if not _G.AddOutfitUnexpireDone then
        _G.AddOutfitUnexpireDone = true
        pcall(F.reviveExpiredOwned, entity)
    end
    F.mergeRevivedIntoMaps()
    F.sanitizeAllInjectedExpire()
    F.ensureInjectedResources()
    return n > 0
end

function F.refreshWardrobe()
    pcall(function()
        if EventSystem and EVENTTYPE_WARDROBE then
            if EVENTID_WARDROBE_UPDATE_ITEM_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST)
            end
            if EVENTID_WARDROBE_UPDATE_AVATAR_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_AVATAR_LIST)
            end
            if EVENTID_WARDROBE_UPDATE_GUN_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_GUN_LIST, -1)
            end
        end
    end)
end

function F.refreshWardrobeOnce()
    if LOBBY.wardrobeRefreshed then return end
    LOBBY.wardrobeRefreshed = true
    F.refreshWardrobe()
end

function F.scheduleInjectRefresh()
    LOBBY.injectRefreshGen = (LOBBY.injectRefreshGen or 0) + 1
    local gen = LOBBY.injectRefreshGen
    F.later(0.4, function()
        if gen ~= LOBBY.injectRefreshGen then return end
        F.refreshWardrobe()
    end)
end

function F.putOnOutfit(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d0.resID or d0.res_id)
    end
    if not resID or resID <= 0 then return end
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    if not F.isSuitRes(resID) then
        if F.isTshirtRes(resID) then return F.putOnRoleWear(insID) end
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end

    local suitFilter = function(r) return F.isSuitRes(r) end
    local oldIns, oldRes = F.findWornInsBySubType(OUTFIT_SUB, suitFilter)
    F.removeRoleWearBySubType(OUTFIT_SUB, suitFilter)
    F.saveEquip(resID, insID)

    local slot = PKG_SLOT
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(OUTFIT_SUB)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    pcall(function()
        local av = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
        av:AddToWearInfo(OUTFIT_SUB, insID, resID, 0, 0)
        F.syncFashionBagRolewear()
    end)
end

function F.putOnHat(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d0.resID or d0.res_id)
    end
    if not resID or resID <= 0 then return end
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end
    local st = F.subType(F.cfg(resID)) or HAT_SUB

    local oldIns, oldRes = F.findWornInsBySubType(st)
    if not oldIns and st ~= HAT_SUB then
        oldIns, oldRes = F.findWornInsBySubType(HAT_SUB)
    end
    F.removeRoleWearBySubType(st)
    if st ~= HAT_SUB then F.removeRoleWearBySubType(HAT_SUB) end
    F.saveEquip(resID, insID)

    local slot = 1
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(st)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID, color = d.color, pattern = d.pattern }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        fbd:SetHeadShow(insID)
        F.syncFashionBagRolewear()
    end)
    F.invalidateSocialWearCache()
end

function F.putOnFaceAccessory(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d0.resID or d0.res_id)
    end
    if not resID or resID <= 0 then return end
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end
    local st = F.subType(F.cfg(resID)) or tonumber(d.itemSubType)
    if not FACE_SUBS[st] then return end

    local oldIns, oldRes = F.findWornInsBySubType(st)
    F.removeRoleWearBySubType(st)
    F.saveEquip(resID, insID)

    local slot = (st == MASK_SUB) and 2 or 6
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(st)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID, color = d.color, pattern = d.pattern }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    pcall(function() F.syncFashionBagRolewear() end)
    F.invalidateSocialWearCache()
end

function F.canRoleWear(resID, st)
    st = st or F.subType(F.cfg(resID))
    if FACE_SUBS[st] or BODY_SUBS[st] then return true end
    if st == GLOVES_SUB then return true end
    if st == OUTFIT_SUB and F.wardrobeTab(resID) == TAB_CLOTHES then return true end
    return false
end

F.putOnRoleWear = function(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d0.resID or d0.res_id)
    end
    if not resID or resID <= 0 then return end
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end
    local st = F.subType(F.cfg(resID)) or tonumber(d.itemSubType)
    if not F.canRoleWear(resID, st) then return end

    local filterFn
    if st == OUTFIT_SUB then
        filterFn = function(r) return F.wardrobeTab(r) == TAB_CLOTHES end
    end
    local oldIns, oldRes = F.findWornInsBySubType(st, filterFn)
    F.removeRoleWearBySubType(st, filterFn)
    F.saveEquip(resID, insID)

    local slot = PKG_SLOT
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(st)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID, color = d.color, pattern = d.pattern }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    if BAG_SUBS[st] or HELMET_SUBS[st] then
        pcall(function()
            DataMgr.equipmentSkinInsIDTable = DataMgr.equipmentSkinInsIDTable or {}
            DataMgr.equipmentSkinInsIDTable[st] = insID
            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
            local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
            if bag then
                if st == 504 or st == 501 then
                    DataMgr.equipmentSkinInsIDTable[504] = insID
                    bag.bag_skin = insID
                elseif st == 505 or st == 502 then
                    DataMgr.equipmentSkinInsIDTable[505] = insID
                    bag.helmet_skin = insID
                end
            end
        end)
    end

    pcall(function() F.syncFashionBagRolewear() end)
    F.invalidateSocialWearCache()
end

function F.putOnGloves(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d0.resID or d0.res_id)
    end
    if not resID or resID <= 0 then return end
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end

    local oldIns, oldRes = F.findWornInsBySubType(GLOVES_SUB)
    F.removeRoleWearBySubType(GLOVES_SUB)
    F.saveEquip(resID, insID)

    local slot = 8
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(GLOVES_SUB)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID, color = d.color, pattern = d.pattern, expire_ts = 0 }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    pcall(function()
        local logic_wardrobe_avatar = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
        logic_wardrobe_avatar:AddToWearInfo(GLOVES_SUB, insID, resID, d.color or 0, d.pattern or 0)
        DataMgr.UpdateRoleWearData(insID, oldIns or 0)
        logic_wardrobe_avatar:AvatarChange(resID, true, d.color, d.pattern)
    end)
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        if wl.SetClickItemInsId then wl:SetClickItemInsId(insID) end
    end)
    pcall(function()
        if EventSystem and EVENTTYPE_WARDROBE then
            if EVENTID_WARDROBE_UPDATE_ITEM_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST)
            end
            if EVENTID_WARDROBE_UPDATE_AVATAR_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_AVATAR_LIST)
            end
        end
    end)
    F.invalidateSocialWearCache()
end

function F.ensureDepotItemValid(insID, resID)
    insID = tonumber(insID)
    if not insID then return end
    pcall(function()
        local entity = F.getEntity()
        if entity and entity.GetDataByInsID then
            local d = entity:GetDataByInsID(insID)
            if d then
                d.expire_ts = 0
                if d.expireTS ~= nil then d.expireTS = 0 end
                if d.valid_hours ~= nil then d.valid_hours = 0 end
            end
        end
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local hd = wd:GetHallDepotItemDataByInsID(insID)
        if hd then
            hd.expire_ts = 0
            if hd.expireTS ~= nil then hd.expireTS = 0 end
            if hd.valid_hours ~= nil then hd.valid_hours = 0 end
        end
    end)
end

function F.clearItemExpire(itemData, insID, resID)
    F.ensureDepotItemValid(insID, resID)
    if type(itemData) == "table" then
        itemData.expireTS = 0
        itemData.expire_ts = 0
        itemData.expireTs = 0
    end
end

function F.onGlideClick(self, itemData)
    if not itemData then return end
    local insID = tonumber(itemData.ins_id)
    local resID = tonumber(itemData.res_id)
    F.clearItemExpire(itemData, insID, resID)
    local isGlide = resID and F.isGlideRes(resID)
    if not isGlide and itemData.itemSubType then
        isGlide = GLIDER_SUBS[tonumber(itemData.itemSubType)] == true
    end
    if insID and resID and isGlide then
        F.saveEquip(resID, insID)
        if F.putOnGlider(insID) then
            pcall(function()
                if self.ShowGlide then self:ShowGlide(resID) end
                if self.ChangeItemStatus then self:ChangeItemStatus(insID, true) end
            end)
            return
        end
    end
    if _G.AddOutfitGlideClickOrig then
        F.clearItemExpire(itemData, insID, resID)
        return _G.AddOutfitGlideClickOrig(self, itemData)
    end
end

function F.onParachuteClick(self, itemData)
    if not itemData then return end
    local insID = tonumber(itemData.ins_id)
    local resID = tonumber(itemData.res_id)
    F.clearItemExpire(itemData, insID, resID)
    if insID and resID and F.isParachuteRes(resID) then
        F.saveEquip(resID, insID)
        if F.putOnParachute(insID) then
            pcall(function()
                if self.ChangeItemStatus then self:ChangeItemStatus(insID, true) end
            end)
            return
        end
    end
    if _G.AddOutfitParaClickOrig then
        return _G.AddOutfitParaClickOrig(self, itemData)
    end
end

function F.hookAirborneClick()
    pcall(function()
        local WG = require("client.slua.umg.Wardrobe.subtab_gliding")
        if WG then
            if not WG._AddOutfitGlideWrapped then
                WG._AddOutfitGlideWrapped = true
                _G.AddOutfitGlideClickOrig = WG.ClickItem
            end
            WG.ClickItem = function(self, itemData)
                return F.onGlideClick(self, itemData)
            end
        end
        local WP = require("client.slua.umg.Wardrobe.subtab_parachute")
        if WP then
            if not WP._AddOutfitParaWrapped then
                WP._AddOutfitParaWrapped = true
                _G.AddOutfitParaClickOrig = WP.ClickItem
            end
            WP.ClickItem = function(self, itemData)
                return F.onParachuteClick(self, itemData)
            end
        end
    end)
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if fbd and not fbd._AddOutfitAirborneFBHooked then
            fbd._AddOutfitAirborneFBHooked = true
            local oG = fbd.UpdateAircraftOrGliding
            fbd.UpdateAircraftOrGliding = function(self, putOnID, bAircraft)
                local r = oG(self, putOnID, bAircraft)
                local ins = tonumber(putOnID)
                if ins and ins > 0 then
                    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                    local d = wd:GetValidHallDepotItemDataByInsID(ins) or wd:GetHallDepotItemDataByInsID(ins)
                    local res = d and tonumber(d.resID)
                    if res and F.isGlideRes(res) then F.saveEquip(res, ins) end
                end
                return r
            end
            local oP = fbd.UpdateParachute
            if oP then
                fbd.UpdateParachute = function(self, insID)
                    local r = oP(self, insID)
                    local ins = tonumber(insID)
                    if ins and ins > 0 then
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d = wd:GetValidHallDepotItemDataByInsID(ins) or wd:GetHallDepotItemDataByInsID(ins)
                        local res = d and tonumber(d.resID)
                        if res and F.isParachuteRes(res) then F.saveEquip(res, ins) end
                    end
                    return r
                end
            end
        end
    end)
    pcall(function()
        if not ModuleManager or not ModuleManager.GetModule then return end
        local FB = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.FashionBagEditUtils)
        if FB and not FB._AddOutfitFBBagHooked then
            FB._AddOutfitFBBagHooked = true
            local o = FB.PutOnFashionBagItem
            FB.PutOnFashionBagItem = function(self, itemData)
                if itemData then
                    F.clearItemExpire(itemData, itemData.ins_id, itemData.res_id)
                end
                local r = o(self, itemData)
                if itemData then
                    local res = tonumber(itemData.res_id)
                    local ins = tonumber(itemData.ins_id)
                    if res and ins and (F.isGlideRes(res) or F.isParachuteRes(res)) then
                        F.saveEquip(res, ins)
                    end
                end
                return r
            end
        end
    end)
end

function F.putOnParachute(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d and tonumber(d.resID)
    end
    if not resID or not F.isParachuteRes(resID) then return false end
    if not R.insToRes[insID] then R.insToRes[insID] = resID end
    F.ensureDepotItemValid(insID, resID)
    F.saveEquip(resID, insID)
    F.ensureInjectedItemAlive(nil, resID, insID)
    local ready = F.isResourcesReady(resID)
    if not ready then F.requestResourceDownload(resID) end
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if fbd.SetParachute then fbd:SetParachute(insID) end
        if fbd.UpdateParachute then fbd:UpdateParachute(insID) end
    end)
    if ready then
        local item = {
            res_id = resID, resID = resID,
            instid = insID, ins_id = insID, insID = insID,
            expire_ts = 0, expireTS = 0, count = 1,
        }
        local WRH = require("client.network.Protocol.WardRobeHandler")
        WRH.on_depot_put_on_rsp(NET_OK, item, nil, 1, insID, 0)
    end
    return true
end

function F.putOnGlider(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d and tonumber(d.resID)
    end
    if not resID or resID <= 0 then return false end
    local st = F.depotSubType(insID, resID)
    if not F.isGlideRes(resID) and not GLIDER_SUBS[st] then return false end
    if not R.insToRes[insID] then R.insToRes[insID] = resID end
    F.ensureDepotItemValid(insID, resID)
    F.saveEquip(resID, insID)
    F.ensureInjectedItemAlive(nil, resID, insID)
    local ready = F.isResourcesReady(resID)
    if not ready then F.requestResourceDownload(resID) end
    local bAircraft = false
    pcall(function()
        local ModelDisplayTypeHelper = require("client.logic.avatar.ModelDisplayTypeHelper")
        local st = F.subType(F.cfg(resID))
        bAircraft = ModelDisplayTypeHelper.IsGlideSmoke(st)
    end)
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if fbd.UpdateAircraftOrGliding then
            fbd:UpdateAircraftOrGliding(insID, bAircraft)
        elseif fbd.SetGliding then
            fbd:SetGliding(insID)
            if DataMgr.UpdateEffect then DataMgr.UpdateEffect(insID) end
        end
    end)
    if ready then
        local item = {
            res_id = resID, resID = resID,
            instid = insID, ins_id = insID, insID = insID,
            expire_ts = 0, expireTS = 0, count = 1,
        }
        local WRH = require("client.network.Protocol.WardRobeHandler")
        WRH.on_depot_put_on_rsp(NET_OK, item, nil, 1, insID, 0)
    end
    return true
end

function F.syncAirborneToDataMgr()
    F.applyPersistSlotsToCache()
    local cch = F.cache()
    local paraRes = F.getDesiredParachuteRes()
    local gliderRes = F.getDesiredGliderRes()
    if paraRes and paraRes > 0 and not cch.parachuteIns then
        cch.parachuteIns = F.resolveInsForRes(paraRes)
        cch.parachuteRes = paraRes
    end
    if gliderRes and gliderRes > 0 and not cch.gliderIns then
        cch.gliderIns = F.resolveInsForRes(gliderRes)
        cch.gliderRes = gliderRes
    end
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if cch.parachuteIns and tonumber(cch.parachuteIns) > 0 then
            if fbd.SetParachute then fbd:SetParachute(cch.parachuteIns) end
            if DataMgr.roleData then DataMgr.roleData.parachute = tostring(cch.parachuteIns) end
        end
        if cch.gliderIns and tonumber(cch.gliderIns) > 0 then
            local bAircraft = false
            if cch.gliderRes then
                pcall(function()
                    local MDH = require("client.logic.avatar.ModelDisplayTypeHelper")
                    bAircraft = not MDH.IsGlideSmoke(F.subType(F.cfg(cch.gliderRes)))
                end)
            end
            if fbd.UpdateAircraftOrGliding then
                fbd:UpdateAircraftOrGliding(cch.gliderIns, bAircraft)
            elseif fbd.SetGliding then
                fbd:SetGliding(cch.gliderIns)
                if DataMgr.UpdateEffect then DataMgr.UpdateEffect(cch.gliderIns) end
            end
            if DataMgr.roleData then
                if bAircraft then
                    DataMgr.roleData.aircraft_put_id = tostring(cch.gliderIns)
                    DataMgr.gliding = cch.gliderIns
                else
                    DataMgr.roleData.gliding = tostring(cch.gliderIns)
                end
            end
        end
    end)
end

function F.putOnGenericInjected(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then return end
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    F.saveEquip(resID, insID)
    local WRH = require("client.network.Protocol.WardRobeHandler")
    WRH.on_depot_put_on_rsp(NET_OK, { res_id = resID, count = 1, instid = insID }, nil, 1, insID, 0)
end

function F.clearEquipCache(resID)
    local st = F.subType(F.cfg(resID))
    local cch = F.cache()
    if st == OUTFIT_SUB then
        if F.wardrobeTab(resID) == TAB_CLOTHES then
            cch.tshirtRes, cch.tshirtIns = nil, nil
            _G.AddOutfitLastLobbyTshirtRes = nil
            F.persistForgetSlot("tshirt")
        else
            cch.outfitRes, cch.outfitIns = nil, nil
            _G.AddOutfitLastLobbyOutfitRes = nil
            F.persistForgetSlot("outfit")
        end
    elseif st == HAT_SUB or HEAD_SUBS[st] then
        cch.hatRes, cch.hatIns = nil, nil
        _G.AddOutfitLastLobbyHatRes = nil
        F.persistForgetSlot("hat")
    elseif st == MASK_SUB then
        cch.maskRes, cch.maskIns = nil, nil
        _G.AddOutfitLastLobbyMaskRes = nil
        F.persistForgetSlot("mask")
    elseif st == GLASS_SUB then
        cch.glassRes, cch.glassIns = nil, nil
        _G.AddOutfitLastLobbyGlassRes = nil
        F.persistForgetSlot("glass")
    elseif st == PANTS_SUB then
        cch.pantsRes, cch.pantsIns = nil, nil
        _G.AddOutfitLastLobbyPantsRes = nil
        F.persistForgetSlot("pants")
    elseif st == SHOES_SUB then
        cch.shoesRes, cch.shoesIns = nil, nil
        _G.AddOutfitLastLobbyShoesRes = nil
        F.persistForgetSlot("shoes")
    elseif BAG_SUBS[st] then
        cch.bagRes, cch.bagIns = nil, nil
        _G.AddOutfitLastLobbyBagRes = nil
        F.persistForgetSlot("bag")
    elseif HELMET_SUBS[st] then
        cch.helmetRes, cch.helmetIns = nil, nil
        _G.AddOutfitLastLobbyHelmetRes = nil
        F.persistForgetSlot("helmet")
    elseif st == PARACHUTE_SUB then
        cch.parachuteRes, cch.parachuteIns = nil, nil
        _G.AddOutfitLastLobbyParachuteRes = nil
        F.persistForgetSlot("parachute")
    elseif F.isGlideRes(resID) then
        cch.gliderRes, cch.gliderIns = nil, nil
        _G.AddOutfitLastLobbyGliderRes = nil
        F.persistForgetSlot("glider")
    elseif st == GLOVES_SUB then
        cch.glovesRes, cch.glovesIns = nil, nil
        _G.AddOutfitLastLobbyGlovesRes = nil
        F.persistForgetSlot("gloves")
    end
    _matchApplied = false
    F.invalidateSocialWearCache()
    F.perfInvalidateLobby()
    F.persistMarkDirty()
end

function F.takeOffInjected(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then return end
    local st = F.subType(F.cfg(resID))

    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        WRH.on_depot_put_down_rsp(NET_OK, { res_id = resID, count = 1 }, insID)
    end)

    pcall(function()
        local AvatarData = require("client.logic.data.AvatarData")
        AvatarData.RemoveRoleWearDataByValue(insID)
    end)
    if st == HAT_SUB or HEAD_SUBS[st] then
        pcall(function()
            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
            local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
            if bag and tonumber(bag.head_show) == insID then fbd:SetHeadShow(0) end
        end)
    end
    if BAG_SUBS[st] or HELMET_SUBS[st] then
        pcall(function()
            local t = DataMgr.equipmentSkinInsIDTable
            if t then
                for _, k in ipairs({ st, 504, 505 }) do
                    if tonumber(t[k]) == insID then t[k] = 0 end
                end
            end
            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
            local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
            if bag then
                if tonumber(bag.bag_skin) == insID then bag.bag_skin = 0 end
                if tonumber(bag.helmet_skin) == insID then bag.helmet_skin = 0 end
            end
        end)
    end

    F.clearEquipCache(resID)
    pcall(function() F.syncFashionBagRolewear() end)
end

function F.syncWeaponArmorySilent(weaponID, insID)
    weaponID, insID = tonumber(weaponID), tonumber(insID)
    if not weaponID or not insID or not F.isInjectedIns(insID) then return end
    local resID = R.insToRes[insID]
    if not resID then return end
    local Arm = require("client.logic.armory.logic_armory")
    Arm.rsp_list = Arm.rsp_list or { skin_list = {}, install_list = {} }
    Arm.rsp_list.install_list = Arm.rsp_list.install_list or {}
    F.injectArmory(resID, insID)
    Arm.rsp_list.install_list[weaponID] = { skin_id = insID }
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if fbd.UpdateCurrentFashionBagWeaponSkin then
            fbd:UpdateCurrentFashionBagWeaponSkin(weaponID, insID)
        end
    end)
end

function F.equipWeaponSkin(weaponID, insID, forceVisual)
    weaponID, insID = tonumber(weaponID), tonumber(insID)
    if not weaponID or not insID or not F.isInjectedIns(insID) then return false end
    local resID = R.insToRes[insID]
    if not resID then return false end

    _G.AddOutfitWeaponEquipped = _G.AddOutfitWeaponEquipped or {}
    if not forceVisual and F.isWeaponVisuallyEquipped(weaponID, insID) then
        F.syncWeaponArmorySilent(weaponID, insID)
        return false
    end
    F.saveEquip(resID, insID)

    local Arm = require("client.logic.armory.logic_armory")
    local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
    local HT = require("client.logic.lobby.hall_theme_utils")
    local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")

    F.injectArmory(resID, insID)
    Arm.rsp_list.install_list[weaponID] = { skin_id = insID }
    if fbd.UpdateCurrentFashionBagWeaponSkin then
        fbd:UpdateCurrentFashionBagWeaponSkin(weaponID, insID)
    end

    local bagIdx = fbd:GetFashionBagUseIndex()
    HT.proc_skin_list_chg("weapon_skin", weaponID, insID, bagIdx, {})

    wgl:SetGunID(weaponID)
    wgl:UpdateCurrentGunAvatar(weaponID, insID)

    if EventSystem and EVENTTYPE_ARMORY and EVENTID_ARMORY_EQUIP_STAT_CHANGE then
        EventSystem:postEvent(EVENTTYPE_ARMORY, EVENTID_ARMORY_EQUIP_STAT_CHANGE, resID)
    end
    if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
        EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, resID)
    end
    _G.AddOutfitWeaponEquipped[weaponID] = insID
    return true
end

local SOCIAL = _G.AddOutfitSocialState or {}
_G.AddOutfitSocialState = SOCIAL
SOCIAL.debGen = SOCIAL.debGen or 0
SOCIAL.wearPatchKey = SOCIAL.wearPatchKey or nil
SOCIAL.snapshotKey = SOCIAL.snapshotKey or nil
SOCIAL.fullSnapshot = SOCIAL.fullSnapshot or nil

function F.socialDebounce(sec, fn)
    SOCIAL.debGen = (SOCIAL.debGen or 0) + 1
    local gen = SOCIAL.debGen
    F.later(sec, function()
        if gen ~= SOCIAL.debGen then return end
        pcall(fn)
    end)
end

function F.getLobbyCurPage()
    local p = nil
    pcall(function()
        local LMC = require("client.slua.logic.lobby.Main.Lobby_Main_Control")
        if LMC.GetCurPage then p = LMC.GetCurPage() end
    end)
    return p
end

function F.isLobbyLeftPage()
    return ENUM_LobbyPageType and F.getLobbyCurPage() == ENUM_LobbyPageType.Left
end

function F.getWeaponSkinResFast()
    local cch = F.cache()
    local wid = tonumber(DataMgr.Weapon_ID) or 0
    local w = wid > 0 and cch.weapons[wid] or nil
    if w and w.resID and w.resID > 0 then return w.resID end
    for _, ww in pairs(cch.weapons) do
        if ww.resID and ww.resID > 0 then return ww.resID end
    end
    return nil
end

function F.resolveLobbyWeaponSkinRes()
    if LOBBY.skinResolved then return LOBBY.cachedSkin end
    local wid = tonumber(DataMgr.Weapon_ID) or 0
    local skin = F.getWeaponSkinResFast()
    if skin and skin > 0 then return skin end

    if wid > 0 then
        local fromMatch = F.getMatchWeaponSkin(wid)
        if fromMatch and fromMatch > 0 then return fromMatch end
    end
    if MATCH_CONFIG.weaponSkins then
        for _, s in pairs(MATCH_CONFIG.weaponSkins) do
            s = tonumber(s)
            if s and s > 0 then return s end
        end
    end

    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        local entry = Arm.rsp_list and Arm.rsp_list.install_list
            and Arm.rsp_list.install_list[wid > 0 and wid or 101004]
        local insID = tonumber(entry and entry.skin_id) or 0
        if insID > 0 and F.isInjectedIns(insID) then
            skin = tonumber(R.insToRes[insID])
        elseif insID > 0 then
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(insID)
            if d and d.resID then skin = tonumber(d.resID) end
        end
    end)
    if skin and skin > 0 then return skin end

    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        if wgl.GetSkinIdByWeaponID and wid > 0 then
            local insID = tonumber(wgl:GetSkinIdByWeaponID(wid)) or 0
            if insID > 0 and F.isInjectedIns(insID) then
                skin = tonumber(R.insToRes[insID])
            end
        end
    end)
    LOBBY.skinResolved = true
    LOBBY.cachedSkin = (skin and skin > 0) and skin or nil
    return LOBBY.cachedSkin
end

function F.resolveLobbyOutfitRes()
    if LOBBY.outfitResolved then return LOBBY.cachedOutfit end
    local cch = F.cache()
    local outfitRes = tonumber(cch.outfitRes) or 0
    if outfitRes > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = outfitRes
        return outfitRes
    end
    outfitRes = tonumber(_G.AddOutfitLastLobbyOutfitRes) or 0
    if outfitRes > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = outfitRes
        return outfitRes
    end
    if MATCH_CONFIG.outfitRes and tonumber(MATCH_CONFIG.outfitRes) > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = tonumber(MATCH_CONFIG.outfitRes)
        return LOBBY.cachedOutfit
    end

    local injectedRes, anyRes
    pcall(function()
        local AvatarData = require("client.logic.data.AvatarData")
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local function resFromIns(ins)
            ins = tonumber(ins)
            if not ins or ins <= 0 then return nil end
            if F.isInjectedIns(ins) then return tonumber(R.insToRes[ins]) end
            local d = wd:GetHallDepotItemDataByInsID(ins)
            return d and tonumber(d.resID) or nil
        end
        for _, ins in pairs(AvatarData.GetRoleWear()) do
            local res = resFromIns(ins)
            if res and F.isSuitRes(res) then
                if F.isInjectedRes(res) then injectedRes = res end
                anyRes = anyRes or res
            end
        end
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
        if bag and bag.rolewear_list then
            for _, ins in pairs(bag.rolewear_list) do
                local res = resFromIns(ins)
                if res and F.isSuitRes(res) then
                    if F.isInjectedRes(res) then injectedRes = res end
                    anyRes = anyRes or res
                end
            end
        end
    end)
    if injectedRes and injectedRes > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = injectedRes
        return injectedRes
    end
    if anyRes and anyRes > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = anyRes
        return anyRes
    end
    LOBBY.outfitResolved = true
    LOBBY.cachedOutfit = nil
    return nil
end

function F.rememberLobbyOutfitRes(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 or not F.isSuitRes(resID) then return end
    _G.AddOutfitLastLobbyOutfitRes = resID
    F.invalidateLobbyResolved()
    local cch = F.cache()
    if not cch.outfitRes or cch.outfitRes <= 0 then
        cch.outfitRes = resID
        if F.isInjectedRes(resID) then cch.outfitIns = R.resToIns[resID] end
    end
end

function F.wearPatchKey()
    local outfit = F.resolveLobbyOutfitRes() or 0
    local skin = F.resolveLobbyWeaponSkinRes() or 0
    local openGun = 1
    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        if lds.data and lds.data.OpenGun ~= nil then openGun = lds.data.OpenGun and 1 or 0 end
    end)
    return outfit .. "_" .. skin .. "_" .. openGun
end

function F.syncDepotShowWeaponFlags(depot)
    depot = depot or {}
    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        if lds.data then
            if lds.data.OpenGun ~= nil then depot.weapon = lds.data.OpenGun end
            if lds.data.OpenSocialWeapon ~= nil then depot.social_weapon = lds.data.OpenSocialWeapon end
        end
    end)
    return depot
end

function F.applyInjectedPspace(roleData)
    if not roleData then return end
    roleData.bshow = true
    roleData.pspace_wear_ext = roleData.pspace_wear_ext or {}
    local outfitRes = F.resolveLobbyOutfitRes()
    if outfitRes and outfitRes > 0 then
        roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH] = { outfitRes, 0, 0 }
    end
    local skinRes = F.resolveLobbyWeaponSkinRes()
    if skinRes and skinRes > 0 then
        roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPON] = { 0, 0, 0 }
        roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN] = { skinRes, 0, 0 }
        roleData.depot_show_info = roleData.depot_show_info or {}
        if roleData.depot_show_info.weapon == nil then
            roleData.depot_show_info.weapon = true
        end
    end
    roleData.depot_show_info = F.syncDepotShowWeaponFlags(roleData.depot_show_info)
end

function F.patchSelfWearCache(force)
    local key = F.wearPatchKey()
    if not force and SOCIAL.wearPatchKey == key then return false end
    SOCIAL.wearPatchKey = key
    SOCIAL.snapshotKey = nil
    SOCIAL.fullSnapshot = nil

    local myUid = tonumber(DataMgr.roleData.uid)
    if not myUid then return false end

    local changed = false
    pcall(function()
        local BD = ModuleManager.GetModule(ModuleManager.DataModuleConfig.BasicDataAvatarWearInfo)
        local d = BD:GetCacheData(myUid)
        if not d then
            BD:OnHandleMsgDataAndCallback(myUid, F.buildLocalRoleDataForCoupleAvatar())
            return true
        end
        local oldCloth = d.pspace_wear_ext and d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH]
        local oldSkin = d.pspace_wear_ext and d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN]
        F.applyInjectedPspace(d)
        local nc = d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH]
        local ns = d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN]
        if oldCloth ~= nc or oldSkin ~= ns or not d.bshow then changed = true end
    end)
    return force or changed
end

function F.requestSocialAvatarRefresh()
    pcall(function()
        if EventSystem and EVENTTYPE_LOBBY_SOCIAL and EVENTID_SOCIAL_LOBBY_REFRESH_AVATAR then
            EventSystem:postEvent(EVENTTYPE_LOBBY_SOCIAL, EVENTID_SOCIAL_LOBBY_REFRESH_AVATAR)
        end
    end)
end

function F.onSocialWearDirty(forceRefresh)
    SOCIAL.lastHandSkin = nil
    if F.patchSelfWearCache(forceRefresh) then
        F.requestSocialAvatarRefresh()
    end
end

function F.buildLocalRoleDataForCoupleAvatar()
    local key = F.wearPatchKey()
    if SOCIAL.fullSnapshot and SOCIAL.snapshotKey == key then
        return SOCIAL.fullSnapshot
    end
    F.syncWeaponCacheFromLobby()
    local cch = F.cache()
    local ad = DataMgr.avatarData or {}
    local gender = tonumber(ad.gamegender) or 2
    if gender < 1 then gender = 2 end

    local data = {
        uid = DataMgr.roleData.uid,
        gender = gender,
        bshow = true,
        pspace_wear_ext = {
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_HEAD] = { tonumber(ad.headid) or 401993, 0, 0 },
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_HAIR] = { tonumber(ad.hairid) or 40601001, 0, 0 },
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPON] = { 0, 0, 0 },
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN] = { 0, 0, 0 },
        },
        depot_show_info = {
            weapon = true, social_weapon = true, idle = true,
            helmet = true, bag = true, vehicle = true, hand = true,
        },
    }

    local outfitRes = F.resolveLobbyOutfitRes()
    if outfitRes and outfitRes > 0 then
        data.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH] = { outfitRes, 0, 0 }
    end

    local skinRes = F.resolveLobbyWeaponSkinRes()
    if skinRes and skinRes > 0 then
        data.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPON][1] = 0
        data.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN][1] = skinRes
    end
    data.depot_show_info = F.syncDepotShowWeaponFlags(data.depot_show_info)
    SOCIAL.fullSnapshot = data
    SOCIAL.snapshotKey = F.wearPatchKey()
    return data
end

local _myUidCached
function F.isMyWearData(wearData)
    if not wearData then return false end
    if not _myUidCached then
        pcall(function() _myUidCached = tonumber(DataMgr.roleData.uid) end)
    end
    return _myUidCached and tonumber(wearData.uid) == _myUidCached
end

function F.mergeInjectedWeaponIntoWearData(wearData)
    if not F.isMyWearData(wearData) then return end
    local skinRes = F.resolveLobbyWeaponSkinRes()
    wearData.depot_show_info = F.syncDepotShowWeaponFlags(wearData.depot_show_info)
    if not skinRes or skinRes <= 0 then return end
    wearData.mainWeaponInfo = wearData.mainWeaponInfo or {
        weaponResId = 0, weaponSkinId = 0,
        diyInfo = { diyWeaponId = 0, diyDefaultScheme = false, diyScheme = nil },
    }
    if wearData.mainWeaponInfo.weaponSkinId == skinRes
        and (tonumber(wearData.mainWeaponInfo.weaponResId) or 0) == 0 then
        return
    end
    wearData.mainWeaponInfo.weaponSkinId = skinRes
    wearData.mainWeaponInfo.weaponResId = 0
end

function F.equipSocialHandWeapon(avatar, skinRes)
    if not avatar or not skinRes or skinRes <= 0 then return end
    if SOCIAL.lastHandSkin == skinRes then return end
    SOCIAL.lastHandSkin = skinRes
    pcall(function()
        avatar:PutonEquipment(skinRes, nil, { bIsUse = true })
    end)
end

function F.shouldShowHandWeapon()
    local show = true
    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        if lds.data and lds.data.OpenGun ~= nil then
            show = lds.data.OpenGun ~= false
        end
    end)
    return show
end

function F.mergeInjectedOutfitIntoWearData(wearData)
    if not F.isMyWearData(wearData) then return end
    local outfitRes = F.resolveLobbyOutfitRes()
    if not outfitRes or outfitRes <= 0 then return end
    F.rememberLobbyOutfitRes(outfitRes)
    local AvatarData = require("client.logic.data.AvatarData")
    local converted = AvatarData.ConvertToAvatarCustom({ outfitRes, 0, 0 })
    if not converted then return end
    wearData.WearInfoList = wearData.WearInfoList or {}
    local replaced = false
    for i, e in ipairs(wearData.WearInfoList) do
        if e and e.ItemID and F.isSuitRes(e.ItemID) then
            wearData.WearInfoList[i] = converted
            replaced = true
            break
        end
    end
    if not replaced then
        table.insert(wearData.WearInfoList, converted)
    end
end

function F.mergeInjectedIntoWearData(wearData)
    if not wearData then return end
    F.mergeInjectedWeaponIntoWearData(wearData)
    F.mergeInjectedOutfitIntoWearData(wearData)
end

function F.reapplyLobbyEquipped()
    if not GameStatus or not GameStatus.IsInLobbyOrMainCity or not GameStatus.IsInLobbyOrMainCity() then
        return
    end
    F.syncWeaponCacheFromLobby()
    F.applyPersistSlotsToCache()
    local curPage = F.getLobbyCurPage()

    if ENUM_LobbyPageType and curPage == ENUM_LobbyPageType.Left then
        F.onSocialWearDirty(true)
        return
    end

    local cch = F.cache()
    if cch.outfitIns and F.isInjectedIns(cch.outfitIns) then
        F.putOnOutfit(cch.outfitIns)
    end
    if cch.hatIns and F.isInjectedIns(cch.hatIns) then
        F.putOnHat(cch.hatIns)
    end
    if cch.maskIns and F.isInjectedIns(cch.maskIns) then
        F.putOnRoleWear(cch.maskIns)
    end
    if cch.glassIns and F.isInjectedIns(cch.glassIns) then
        F.putOnRoleWear(cch.glassIns)
    end
    if cch.tshirtIns and F.isInjectedIns(cch.tshirtIns) then
        F.putOnRoleWear(cch.tshirtIns)
    end
    if cch.pantsIns and F.isInjectedIns(cch.pantsIns) then
        F.putOnRoleWear(cch.pantsIns)
    end
    if cch.shoesIns and F.isInjectedIns(cch.shoesIns) then
        F.putOnRoleWear(cch.shoesIns)
    end
    if cch.bagIns and F.isInjectedIns(cch.bagIns) then
        F.putOnRoleWear(cch.bagIns)
    end
    if cch.helmetIns and F.isInjectedIns(cch.helmetIns) then
        F.putOnRoleWear(cch.helmetIns)
    end
    if cch.parachuteIns then
        F.putOnParachute(cch.parachuteIns)
    end
    if cch.gliderIns then
        F.putOnGlider(cch.gliderIns)
    end
    if cch.glovesIns and F.isInjectedIns(cch.glovesIns) then
        F.putOnGloves(cch.glovesIns)
    end

    local mainWid = tonumber(DataMgr.Weapon_ID) or 0
    local w = mainWid > 0 and cch.weapons[mainWid] or nil
    if w and w.resID and w.resID > 0 then
        if w.insID and F.isInjectedIns(w.insID) then
            F.equipWeaponSkin(mainWid, w.insID)
        else
            pcall(function() DataMgr.InitWeaponData(mainWid, w.resID, w.insID or 0) end)
        end
    end

    pcall(function()
        local uid = tostring(DataMgr.roleData.uid)
        local LAM = require("client.logic.avatar.LobbyAvatarManager")
        local TAM = require("client.logic.avatar.logic_team_avatar_manager")
        if w and w.resID and w.resID > 0 and TAM.GetAvatarByUid(uid) then
            LAM.EquipWeapon(uid, { weaponId = mainWid, skinId = w.resID }, nil, true)
        end
    end)

    F.reapplyVehicleSlotsFromConfig(true)
    F.reapplyHallThemeFromConfig(true)
    F.reapplyWeaponsFromConfig()
    pcall(F.applyVehicleSkinsToPC)
end

F.scheduleLobbyReapplyOnce = function()
    if LOBBY.reapplyDone or LOBBY.reapplyScheduled then return end
    LOBBY.reapplyScheduled = true
    F.later(2.0, function()
        LOBBY.reapplyScheduled = false
        if LOBBY.reapplyDone then return end
        LOBBY.reapplyDone = true
        F.reapplyLobbyEquipped()
    end)
end

function F.hookLobbySwipePersistence()
    if _G.AddOutfitLobbySwipeHooked then return end
    _G.AddOutfitLobbySwipeHooked = true
    pcall(function()
        local BD = ModuleManager.GetModule(ModuleManager.DataModuleConfig.BasicDataAvatarWearInfo)
        local oRsp = BD.on_get_avatar_show_rsp
        BD.on_get_avatar_show_rsp = function(self, res, target_uid, data)
            oRsp(self, res, target_uid, data)
                if tonumber(target_uid) == tonumber(DataMgr.roleData.uid) then
                F.patchSelfWearCache(true)
                SOCIAL.forceAvatarRedraw = true
                SOCIAL.lastHandSkin = nil
                if ENUM_LobbyPageType and F.getLobbyCurPage() == ENUM_LobbyPageType.Left then
                    F.requestSocialAvatarRefresh()
                end
            end
        end
    end)

    pcall(function()
        local AC = require("client.slua.logic.avatar.avatar_common")
        local oGetWear = AC.GetWearDataFromRoleData
        AC.GetWearDataFromRoleData = function(roleData)
            local wearData = oGetWear(roleData)
            if wearData and roleData and tonumber(roleData.uid) == tonumber(DataMgr.roleData.uid)
                and F.isLobbyLeftPage() then
                F.mergeInjectedIntoWearData(wearData)
            end
            return wearData
        end
        local oUp = AC.UpdateAvatar
        AC.UpdateAvatar = function(avatar, wearData, isShowWeapon, isShowHelmet, isShowBag)
            if F.isMyWearData(wearData) and F.isLobbyLeftPage() then
                F.mergeInjectedIntoWearData(wearData)
            end
            local showGun = isShowWeapon and F.shouldShowHandWeapon()
            if wearData and wearData.depot_show_info then
                showGun = showGun and wearData.depot_show_info.weapon ~= false
            end
            if F.isMyWearData(wearData) and F.isLobbyLeftPage() then
                for _, e in ipairs(wearData.WearInfoList or {}) do
                    if e and e.ItemID and F.isInjectedRes(e.ItemID) and F.isSuitRes(e.ItemID) then
                        F.rememberLobbyOutfitRes(e.ItemID)
                        break
                    end
                end
            end
            local ret = oUp(avatar, wearData, showGun, isShowHelmet, isShowBag)
            if showGun and F.isMyWearData(wearData) and avatar and F.isLobbyLeftPage() then
                local skin = tonumber(wearData.mainWeaponInfo and wearData.mainWeaponInfo.weaponSkinId) or 0
                if skin <= 0 then skin = F.resolveLobbyWeaponSkinRes() or 0 end
                if skin > 0 then F.equipSocialHandWeapon(avatar, skin) end
            end
            return ret
        end
    end)

    pcall(function()
        local CA = require("client.logic.avatar.CoupleAvatar")
        local Cfg = require("client.slua.logic.lobby.Left.CoupleAvatarConfig")
        local oMulti = CA._UpdateMultiAvatar
        if oMulti then
            CA._UpdateMultiAvatar = function(self, avatar, avatarType)
                local isSelf = avatarType == Cfg.AvatarType.Self
                    and self.SelfUID and tostring(self.SelfUID) == tostring(DataMgr.roleData.uid)
                if isSelf and F.isLobbyLeftPage() then
                    pcall(function()
                        local BD = ModuleManager.GetModule(ModuleManager.DataModuleConfig.BasicDataAvatarWearInfo)
                        local d = BD:GetCacheData(tonumber(self.SelfUID))
                        if d then F.applyInjectedPspace(d) end
                    end)
                    if SOCIAL.forceAvatarRedraw then
                        self.CompareDataCache[avatarType] = nil
                        SOCIAL.forceAvatarRedraw = nil
                    end
                end
                oMulti(self, avatar, avatarType)
                if isSelf and F.isLobbyLeftPage() and self.isShowWeapon ~= false and F.shouldShowHandWeapon() then
                    local skin = F.resolveLobbyWeaponSkinRes()
                    if skin and skin > 0 then F.equipSocialHandWeapon(avatar, skin) end
                end
            end
        end
        local oHideCheck = CA.CheckSelfIsHideAvatar
        CA.CheckSelfIsHideAvatar = function(self, nSelfUId, tRoleData)
            if F.isLobbyLeftPage() and tostring(nSelfUId) == tostring(DataMgr.roleData.uid) then
                return false
            end
            return oHideCheck(self, nSelfUId, tRoleData)
        end

        local oUpdate = CA.Update
        CA.Update = function(self)
            if not F.isLobbyLeftPage() then
                return oUpdate(self)
            end
            local isSelf = self.SelfUID and tostring(self.SelfUID) == tostring(DataMgr.roleData.uid)
            local oHide = CA.HideAvatars
            if isSelf then
                CA.HideAvatars = function() end
            end
            local ok, err = pcall(oUpdate, self)
            CA.HideAvatars = oHide
        end

        local oRecv = CA.OnReceiveData
        CA.OnReceiveData = function(self, uid, data)
            if F.isLobbyLeftPage() and uid == self.SelfUID and tostring(uid) == tostring(DataMgr.roleData.uid) then
                if data then
                    F.applyInjectedPspace(data)
                else
                    data = F.buildLocalRoleDataForCoupleAvatar()
                end
            end
            return oRecv(self, uid, data)
        end
    end)

    pcall(function()
        if not EventSystem or not EventSystem.registEvent then return end
        if EVENTTYPE_LOBBY and EVENTID_SWITCHTO_PAGE_START then
            EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_SWITCHTO_PAGE_START, function(_, _, toPage)
                if ENUM_LobbyPageType and toPage == ENUM_LobbyPageType.Left then
                    F.syncWeaponCacheFromLobby()
                    SOCIAL.lastHandSkin = nil
                    local o = F.resolveLobbyOutfitRes()
                    if o then F.rememberLobbyOutfitRes(o) end
                    F.patchSelfWearCache(true)
                    SOCIAL.forceAvatarRedraw = true
                end
            end)
        end
        if EVENTTYPE_LOBBY and EVENTID_SWITCHTO_PAGE_END then
            EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_SWITCHTO_PAGE_END, function(_, _, _, toPage)
                if ENUM_LobbyPageType and toPage == ENUM_LobbyPageType.Left then
                    F.syncWeaponCacheFromLobby()
                    SOCIAL.lastHandSkin = nil
                    F.socialDebounce(0.45, function()
                        F.onSocialWearDirty(true)
                    end)
                elseif ENUM_LobbyPageType and toPage == ENUM_LobbyPageType.Mid then
                    SOCIAL.wearPatchKey = nil
                    F.invalidateLobbyResolved()
                    if not LOBBY.reapplyDone then
                        F.socialDebounce(0.5, F.scheduleLobbyReapplyOnce)
                    end
                end
            end)
        end
        if EVENTTYPE_LOBBY_SOCIAL and EVENTID_GOT_SOCIAL_LOBBY_SHOW_DATA then
            EventSystem:registEvent(EVENTTYPE_LOBBY_SOCIAL, EVENTID_GOT_SOCIAL_LOBBY_SHOW_DATA, function(_, _, nUId)
                if tonumber(nUId) == tonumber(DataMgr.roleData.uid) then
                    F.socialDebounce(0.2, function() F.patchSelfWearCache(false) end)
                end
            end)
        end
        if EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
            EventSystem:registEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, function()
                SOCIAL.wearPatchKey = nil
                SOCIAL.snapshotKey = nil
                F.syncWeaponCacheFromLobby()
                
                local curPage = ENUM_LobbyPageType and F.getLobbyCurPage()
                if curPage == ENUM_LobbyPageType.Left then
                    F.socialDebounce(0.25, function() F.onSocialWearDirty(true) end)
                end
                
                F.socialDebounce(0.3, function()
                    if F.reapplyLobbyEquipped then F.reapplyLobbyEquipped() end
                end)
            end)
        end
    end)

    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        local oSwitch = lds.SwitchGun
        lds.SwitchGun = function(...)
            local r = oSwitch(...)
            SOCIAL.wearPatchKey = nil
            
            local curPage = ENUM_LobbyPageType and F.getLobbyCurPage()
            if curPage == ENUM_LobbyPageType.Left then
                F.socialDebounce(0.2, function() F.onSocialWearDirty(true) end)
            end
            
            F.socialDebounce(0.3, function()
                if F.reapplyLobbyEquipped then F.reapplyLobbyEquipped() end
            end)
            
            return r
        end
    end)
end

function F.hookDepotInit()
    pcall(function()
        local WDE = require("client.slua.logic.wardrobe.WardrobeDataEntity")
        if WDE._AddOutfitInitHooked then return end
        WDE._AddOutfitInitHooked = true
        local orig = WDE.InitData
        WDE.InitData = function(self, pkg)
            orig(self, pkg)
            _G.AddOutfitUnexpireDone = false
            pcall(function()
                if F.injectAll(self) then
                    F.scheduleInjectRefresh()
                    LOBBY.reapplyDone = false
                    LOBBY.reapplyScheduled = false
                    F.scheduleLobbyReapplyOnce()
                end
            end)
        end
    end)
end

function F.hookWardrobeData()
    pcall(function()
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        if wd._AddOutfitDataHooked then return end
        wd._AddOutfitDataHooked = true
        local function wrapGet(name)
            local o = wd[name]
            if not o then return end
            wd[name] = function(self, insID, ...)
                insID = tonumber(insID)
                local r
                if F.isInjectedIns(insID) then
                    local e = F.getEntity()
                    if e then r = e:GetDataByInsID(insID) end
                else
                    r = o(self, insID, ...)
                end
                if r and (F.isInjectedIns(insID) or F.isInjectedRes(r.resID or r.res_id)) then
                    r.expire_ts = 0
                    r.expireTS = 0
                    r.valid_hours = 0
                end
                return r
            end
        end
        wrapGet("GetHallDepotItemDataByInsID")
        wrapGet("GetValidHallDepotItemDataByInsID")
        local function wrapBool(name)
            local o = wd[name]
            if not o then return end
            wd[name] = function(self, id, ...)
                if F.isInjectedRes(tonumber(id)) or F.isInjectedIns(tonumber(id)) then return true end
                return o(self, id, ...)
            end
        end
        wrapBool("HasItem")
        wrapBool("HasValidItem")
        wrapBool("CheckHasPermanentItem")
    end)
end

function F.hookPageFilter()
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        if wl._AddOutfitPageFilterHooked then return end
        wl._AddOutfitPageFilterHooked = true
        local o1 = wl.IsValidCurrentPageItem
        wl.IsValidCurrentPageItem = function(self, mainTab, subTab, v, t)
            if v and F.isInjectedRes(v.resID) then
                local itemTab = tonumber(v.subTabType) or F.wardrobeTab(v.resID)
                if itemTab and itemTab == subTab then
                    if mainTab == PAGE_AVATAR or mainTab == PAGE_VEHICLE then return true end
                    if mainTab == PAGE_PARACHUTE and F.isHallThemeRes(v.resID) then return true end
                end
            end
            return o1(self, mainTab, subTab, v, t)
        end
        local o2 = wl.IsCanUse
        wl.IsCanUse = function(self, resId)
            if F.isInjectedRes(resId) then return true end
            return o2(self, resId)
        end
        local o3 = wl.IsCharacterUse
        wl.IsCharacterUse = function(self, resId)
            if F.isInjectedRes(resId) then return true end
            return o3(self, resId)
        end
        local o4 = wl.GetWardrobeInsIdByResId
        wl.GetWardrobeInsIdByResId = function(self, resid)
            resid = tonumber(resid)
            if F.isInjectedRes(resid) then return R.resToIns[resid] end
            return o4(self, resid)
        end
    end)
end

function F.hookArmory()
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        if Arm._AddOutfitArmoryHooked then return end
        Arm._AddOutfitArmoryHooked = true
        local oa = Arm.get_weapon_skin_list_rsp
        Arm.get_weapon_skin_list_rsp = function(a, b, c, d)
            oa(a, b, c, d)
            F.mergeInjectedArmorySkins()
        end
        local oi = Arm.install_weapon_skin
        Arm.install_weapon_skin = function(cd, wid, ins)
            ins = tonumber(ins)
            if F.isWeaponSkinIns(ins) then
                wid = tonumber(F.weaponIdFromSkin(R.insToRes[ins]) or wid)
                F.equipWeaponSkin(wid, ins)
                return
            end
            return oi(cd, wid, ins)
        end
    end)
    pcall(function()
        local AH = require("client.network.Protocol.ArmoryHandler")
        if AH._AddOutfitArmorySendHooked then return end
        AH._AddOutfitArmorySendHooked = true
        local o = AH.send_install_weapon_skin
        AH.send_install_weapon_skin = function(cd, wid, ins)
            ins = tonumber(ins)
            if F.isWeaponSkinIns(ins) then
                wid = tonumber(F.weaponIdFromSkin(R.insToRes[ins]) or wid)
                F.equipWeaponSkin(wid, ins)
                return
            end
            return o(cd, wid, ins)
        end
    end)
end

function F.hookGunSkinId()
    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        if wgl._AddOutfitGunSkinHooked then return end
        wgl._AddOutfitGunSkinHooked = true
        local o = wgl.GetSkinIdByWeaponID
        wgl.GetSkinIdByWeaponID = function(self, wid)
            local c = F.cache()
            local w = c.weapons[wid]
            if w and F.isWeaponSkinIns(w.insID) then return w.insID end
            local Arm = require("client.logic.armory.logic_armory")
            if Arm.rsp_list and Arm.rsp_list.install_list and Arm.rsp_list.install_list[wid] then
                local sid = Arm.rsp_list.install_list[wid].skin_id
                if sid and F.isWeaponSkinIns(sid) then return sid end
            end
            return o(self, wid)
        end
    end)
end

function F.hookPutOn()
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        if WRH._AddOutfitPutOnHooked then return end
        WRH._AddOutfitPutOnHooked = true
        local o = WRH.send_depot_put_on_req
        WRH.send_depot_put_on_req = function(insID, extra)
            insID = tonumber(insID)
            if F.tryLocalWearByIns(insID) then return end
            return o(insID, extra)
        end
    end)
end

function F.hookPutDown()
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        if WRH._AddOutfitPutDownHooked then return end
        WRH._AddOutfitPutDownHooked = true
        local o = WRH.send_depot_put_down_req
        WRH.send_depot_put_down_req = function(insID)
            if F.isInjectedIns(tonumber(insID)) then
                F.takeOffInjected(insID)
                return
            end
            return o(insID)
        end
        local ob = WRH.send_depot_batch_put_down_req
        WRH.send_depot_batch_put_down_req = function(instid_list)
            local rest = {}
            for _, id in ipairs(instid_list or {}) do
                if F.isInjectedIns(tonumber(id)) then
                    F.takeOffInjected(id)
                else
                    rest[#rest + 1] = id
                end
            end
            if #rest > 0 then return ob(rest) end
        end
    end)
end

function F.hookVehicleSwitchEffect()
    if _G.AddOutfitVehSwitchHooked then return end
    pcall(function()
        local VAC = require("GameLua.GameCore.Module.Vehicle.Component.VehicleAvatarComponent")
        local impl = VAC and VAC.__inner_impl
        if not impl or impl._AddOutfitVehSwitchHooked then return end
        impl._AddOutfitVehSwitchHooked = true

        if not _G.AddOutfitVehOrigCanSwitch then
            _G.AddOutfitVehOrigCanSwitch = impl.CheckCanPlaySkinSwitchEffect
        end
        impl.CheckCanPlaySkinSwitchEffect = function(self, curVehicleId, lastVehicleId)
            if self.IsLobbyActor and self:IsLobbyActor() then return false end
            if not F.isInRealMatch() then return false end
            return true
        end

        if not _G.AddOutfitVehOrigShowSwitch then
            _G.AddOutfitVehOrigShowSwitch = impl.ShowVehicleSwitchEffect
        end
        impl.ShowVehicleSwitchEffect = function(self)
            if self.IsLobbyActor and self:IsLobbyActor() then return false end
            if not F.isInRealMatch() then return false end
            if not self.curSwitchEffectId or self.curSwitchEffectId <= 0 then
                self.curSwitchEffectId = VEH_SWITCH_EFFECT_ID
            end
            local vehicleActor = self:GetOwner()
            if not slua.isValid(vehicleActor) then return false end
            if self.uSwitchEffectActor then
                self:StopSkinSwitchEffect()
                pcall(function() self.uSwitchEffectActor:K2_DestroyActor() end)
                self.uSwitchEffectActor = nil
            end
            if not self.lastEquipedAvatarId or self.lastEquipedAvatarId <= 0 then
                local defId = 0
                pcall(function() defId = self:GetDefaultAvatarID() or 0 end)
                self.lastEquipedAvatarId = vehicleActor.ClientUsedAvatarID or defId or 0
            end
            local currentAvatarID = vehicleActor.ClientUsedAvatarID or self.lastEquipedAvatarId or 0
            local bIsLobbyActor = self:IsLobbyActor()
            local world = slua_GameFrontendHUD:GetWorld()
            local VehiclePlateLicenseUtil = require("GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil")
            local SkinSwitchEffectActorPath = VehiclePlateLicenseUtil.GetSwitchEffectActorPath()
            local BP_DissolveVehicleClass = import(SkinSwitchEffectActorPath)
            self.uSwitchEffectActor = world:SpawnActor(BP_DissolveVehicleClass, nil, nil, nil)
            if not slua.isValid(self.uSwitchEffectActor) then
                self.uSwitchEffectActor = nil
                return false
            end
            self.uSwitchEffectActor:K2_AttachToActor(vehicleActor, "None", 1, 1, 1, false)
            self.uSwitchEffectActor:K2_SetActorRelativeLocation(FVector(0, 0, 0), false, nil, false)
            self.uSwitchEffectActor:K2_SetActorRelativeRotation(FRotator(0, 0, 0), false, nil, false)
            pcall(function() self:HideParticles() end)
            self:ChangeFakeSwitchVehicleAvatar(self.uSwitchEffectActor.Mesh, self.lastEquipedAvatarId)
            self.uSwitchEffectActor:SetAnimInsAndAnimState(self.uOldVehicleMeshAnimClass, vehicleActor)
            self.uSwitchEffectActor:StartVehicleSwitchEffect(
                vehicleActor, self.curSwitchEffectId, self.lastEquipedAvatarId, currentAvatarID, bIsLobbyActor)
            self.uOldVehicleMeshAnimClass = nil
            return true
        end

        if not _G.AddOutfitVehOrigBeginPlay then
            _G.AddOutfitVehOrigBeginPlay = impl.ReceiveBeginPlay
        end
        local oBegin = _G.AddOutfitVehOrigBeginPlay
        impl.ReceiveBeginPlay = function(self)
            oBegin(self)
            pcall(function()
                if self.uSwitchEffectActor then
                    self:StopSkinSwitchEffect()
                    pcall(function() self.uSwitchEffectActor:K2_DestroyActor() end)
                    self.uSwitchEffectActor = nil
                end
                self.lastEquipedAvatarId = 0
                if self.IsLobbyActor and self:IsLobbyActor() then
                    self.curSwitchEffectId = 0
                elseif F.isInRealMatch() then
                    self.curSwitchEffectId = VEH_SWITCH_EFFECT_ID
                else
                    self.curSwitchEffectId = 0
                end
            end)
        end

        if impl.LuaIsAssetsAlreadyAvailable and not _G.AddOutfitVehOrigAssets then
            _G.AddOutfitVehOrigAssets = impl.LuaIsAssetsAlreadyAvailable
            impl.LuaIsAssetsAlreadyAvailable = function(self, avatarId)
                if F.isVehicleSkinAllowed(tonumber(avatarId)) then return true end
                return _G.AddOutfitVehOrigAssets(self, avatarId)
            end
        end

        _G.AddOutfitVehSwitchHooked = true
    end)
end

function F.hookVehicleChassisLight()
    if _G.AddOutfitVehChassisHooked then return end
    pcall(function()
        local LIC = require("GameLua.Activity.Commercialize.Actor.ActorComponent.BP_VehicleLicenseComponentBase")
        if LIC and LIC.CheckHasVehicleDownloaded and not _G.AddOutfitVehOrigLicDownload then
            _G.AddOutfitVehOrigLicDownload = LIC.CheckHasVehicleDownloaded
            LIC.CheckHasVehicleDownloaded = function(self, itemID)
                local id = tonumber(itemID)
                if F.isVehicleSkinAllowed(id) or F.isChassisLightId(id) then return true end
                return _G.AddOutfitVehOrigLicDownload(self, itemID)
            end
        end
    end)
    pcall(function()
        local LVF = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.LogicVehicleExtendedFeature)
        if not LVF or LVF._AddOutfitChassisHooked then return end
        LVF._AddOutfitChassisHooked = true

        if not _G.AddOutfitVehOrigGetFeature then
            _G.AddOutfitVehOrigGetFeature = LVF.CheckHasGetFeatureItem
        end
        LVF.CheckHasGetFeatureItem = function(self, featureId)
            if F.isChassisLightId(featureId) then return true end
            return _G.AddOutfitVehOrigGetFeature(self, featureId)
        end

        if not _G.AddOutfitVehOrigEquippedFeature then
            _G.AddOutfitVehOrigEquippedFeature = LVF.CheckHasEquippedItem
        end
        LVF.CheckHasEquippedItem = function(self, featureId, vehicleId)
            if _G.LexusConfig and _G.LexusConfig.ModSkin ~= false then
                if F.isChassisLightId(featureId) then
                    return F.getDesiredChassisLight(vehicleId) == tonumber(featureId)
                end
            end
            return _G.AddOutfitVehOrigEquippedFeature(self, featureId, vehicleId)
        end

        if not _G.AddOutfitVehOrigEquipChassisData then
            _G.AddOutfitVehOrigEquipChassisData = LVF.GetEquipedChassisLightData
        end
        LVF.GetEquipedChassisLightData = function(self, vehicleId, source)
            if _G.LexusConfig and _G.LexusConfig.ModSkin ~= false then
                local our = F.getDesiredChassisLight(vehicleId)
                if our then return our end
            end
            return _G.AddOutfitVehOrigEquipChassisData(self, vehicleId, source)
        end

        if not _G.AddOutfitVehOrigChassisLightData then
            _G.AddOutfitVehOrigChassisLightData = LVF.GetVehicleChassisLightData
        end
        LVF.GetVehicleChassisLightData = function(self, uid, vehicleId, position, source)
            if _G.LexusConfig and _G.LexusConfig.ModSkin ~= false then
                if uid and DataMgr and DataMgr.roleData and tonumber(uid) == tonumber(DataMgr.roleData.uid) then
                    local our = F.getDesiredChassisLight(vehicleId)
                    if our then return our end
                end
            end
            return _G.AddOutfitVehOrigChassisLightData(self, uid, vehicleId, position, source)
        end

        if not _G.AddOutfitVehOrigPutOnFeature then
            _G.AddOutfitVehOrigPutOnFeature = LVF.PutOnVehicleFeature
        end
        LVF.PutOnVehicleFeature = function(self, featureId, vehicleId)
            featureId = tonumber(featureId)
            vehicleId = tonumber(vehicleId)
            if F.isChassisLightId(featureId) then
                F.saveChassisLight(vehicleId, featureId)
                self.equip_chassis_light = self.equip_chassis_light or {}
                if vehicleId and vehicleId > 0 then
                    self.equip_chassis_light[vehicleId] = featureId
                end
                return
            end
            return _G.AddOutfitVehOrigPutOnFeature(self, featureId, vehicleId)
        end

        if not _G.AddOutfitVehOrigPutOffFeature then
            _G.AddOutfitVehOrigPutOffFeature = LVF.PutOffVehicleFeature
        end
        LVF.PutOffVehicleFeature = function(self, featureId, vehicleId)
            featureId = tonumber(featureId)
            vehicleId = tonumber(vehicleId)
            if F.isChassisLightId(featureId) then
                PERSIST.configChassisLightMap = PERSIST.configChassisLightMap or {}
                if vehicleId and vehicleId > 0 then
                    PERSIST.configChassisLightMap[vehicleId] = nil
                end
                if self.equip_chassis_light and vehicleId then
                    self.equip_chassis_light[vehicleId] = nil
                end
                F.persistMarkDirty()
                return
            end
            return _G.AddOutfitVehOrigPutOffFeature(self, featureId, vehicleId)
        end
    end)
    _G.AddOutfitVehChassisHooked = true
end

function F.hookVehicles()
    F.hookVehicleSwitchEffect()
    F.hookVehicleChassisLight()
    pcall(function()
        local WV = require("client.slua.umg.Wardrobe.subtab_vehicles")
        if not WV or WV._AddOutfitVehClickHooked then return end
        WV._AddOutfitVehClickHooked = true
        local oClick = WV.ClickItem
        WV.ClickItem = function(self, vehicleSkin, bForceUsing)
            if vehicleSkin and F.isInjectedRes(vehicleSkin.res_id) then
                vehicleSkin.expireTS = 0
                vehicleSkin.expire_ts = 0
            end
            return oClick(self, vehicleSkin, bForceUsing)
        end
        local oDrop = WV.OnVehicleSlotDrop
        if oDrop then
            WV.OnVehicleSlotDrop = function(self, DragWidget, Index, DragDropData)
                pcall(function()
                    local ins = DragDropData and DragDropData.ins_id
                    if F.isInjectedIns(tonumber(ins)) then
                        F.ensureInjectedItemAlive(nil, nil, ins)
                    end
                end)
                return oDrop(self, DragWidget, Index, DragDropData)
            end
        end
    end)
    pcall(function()
        local WNH = require("client.network.Protocol.WardrobeNewHandler")
        if WNH._AddOutfitVehicleHooked then return end
        WNH._AddOutfitVehicleHooked = true
        local oMod = WNH.send_depot_modify_combat_vehicle_req
        WNH.send_depot_modify_combat_vehicle_req = function(instid, slot_index, ope_type)
            if F.modifyInjectedVehicleSlot(instid, slot_index, ope_type == true) then return end
            return oMod(instid, slot_index, ope_type)
        end
        local oRsp = WNH.on_depot_modify_combat_vehicle_rsp
        WNH.on_depot_modify_combat_vehicle_rsp = function(err_code, knapsack_vst)
            if err_code == 0 or err_code == NET_OK then
                knapsack_vst = F.mergeInjectedIntoVehicleSlotList(knapsack_vst)
            end
            oRsp(err_code, knapsack_vst)
            if err_code == 0 or err_code == NET_OK then
                F.syncVehicleSlotsToDataMgr()
                F.equipVehicleTypesFromConfig(PERSIST.configVehicleSlots)
                if not (_G.AddOutfitLobbyVeh and _G.AddOutfitLobbyVeh.manual) then
                    pcall(F.applyVehicleSkinsToPC)
                end
                F.persistMarkDirty()
            end
        end
    end)
    pcall(function()
        local gsm = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.golden_suit_module)
        if gsm and gsm.VehicleNeedClothes and not gsm._AddOutfitVehClothesHooked then
            gsm._AddOutfitVehClothesHooked = true
            local o = gsm.VehicleNeedClothes
            gsm.VehicleNeedClothes = function(self, vehicleId)
                vehicleId = tonumber(vehicleId)
                if vehicleId and F.isInjectedRes(vehicleId) then return 0 end
                return o(self, vehicleId)
            end
        end
    end)
    pcall(function()
        local mod = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
        if mod._FillVehicleSkinList then
            if not _G.AddOutfitVehFillOrig then
                _G.AddOutfitVehFillOrig = mod._FillVehicleSkinList
            end
            local o = _G.AddOutfitVehFillOrig
            mod._FillVehicleSkinList = function(self, playerInfo, uPlayerController)
                F.mergeVstIntoPlayerInfo(playerInfo)
                return o(self, playerInfo, uPlayerController)
            end
            mod._AddOutfitFillVehHooked = true
        end
    end)
    pcall(function()
        local classMod = require("GameLua.Mod.BaseMod.Client.InGameUI.VehicleControl.VehicleSkinItem")
        if not classMod or not classMod.__inner_impl then return end
        local impl = classMod.__inner_impl
        if not _G.AddOutfitVehOrigClick then
            _G.AddOutfitVehOrigClick = impl.OnClickSkinButton
        end
        local oClick = _G.AddOutfitVehOrigClick
        impl.OnClickSkinButton = function(self)
            local resID = tonumber(self.resID)
            if resID and resID > 0 then
                if F.matchApplyVehicleSkin(resID) then
                    pcall(function()
                        if EVENTYPE_INGAME_VEHICLE_CONTROL_PANEL and EVENTID_CHANGE_VEHICLESKIN_BUTTON_CLICK then
                            EventSystem:postEvent(EVENTYPE_INGAME_VEHICLE_CONTROL_PANEL, EVENTID_CHANGE_VEHICLESKIN_BUTTON_CLICK)
                        end
                    end)
                end
                return
            end
            return oClick(self)
        end
        if not _G.AddOutfitVehOrigRefresh then
            _G.AddOutfitVehOrigRefresh = impl.OnRefresh
        end
        local oRefresh = _G.AddOutfitVehOrigRefresh
        impl.OnRefresh = function(self, resID, selectIndex)
            oRefresh(self, resID, selectIndex)
            if self.resID and tonumber(self.resID) and tonumber(self.resID) > 0 then
                if F.isResourcesReady(self.resID) then
                    pcall(function()
                        local PufferConst = require("client.slua.logic.download.puffer_const")
                        self.dowloadState = PufferConst.ENUM_DownloadState.Done
                        self.UIRoot.Image_Download:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                        self:SetWidgetVisible(self.UIRoot.Image_Mask, false)
                    end)
                else
                    F.requestResourceDownload(self.resID)
                end
            end
        end
        classMod._AddOutfitSkinClickHooked = true
    end)
    pcall(function()
        local utilMod = require("GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil")
        if utilMod.CheckHasUnLockFeature and not utilMod._AddOutfitVehPlateHooked then
            utilMod._AddOutfitVehPlateHooked = true
            local orig = utilMod.CheckHasUnLockFeature
            utilMod.CheckHasUnLockFeature = function(ft, uid, itemId)
                local id = tonumber(itemId)
                if F.isVehicleSkinAllowed(id) or F.isChassisLightId(id) then return true end
                return orig(ft, uid, itemId)
            end
        end
    end)
    pcall(function()
        local panelMod = require("GameLua.Mod.BaseMod.Client.InGameUI.VehicleControl.VehicleSkinAndMusicPanel")
        if panelMod and panelMod.__inner_impl and not panelMod._AddOutfitInitSkinHooked then
            panelMod._AddOutfitInitSkinHooked = true
            local o = panelMod.__inner_impl.InitSkinList
            panelMod.__inner_impl.InitSkinList = function(self)
                F.applyVehicleSkinsToPC(F.getPC())
                return o(self)
            end
        end
    end)
    pcall(function()
        local VUC = require("GameLua.GameCore.Module.Vehicle.Component.VehicleUserComponent")
        if not VUC then return end
        if not _G.AddOutfitVehOrigEnter then
            _G.AddOutfitVehOrigEnter = VUC.SendUIMsgWhenEnterVehicleCompleted
        end
        local oEnter = _G.AddOutfitVehOrigEnter
        VUC.SendUIMsgWhenEnterVehicleCompleted = function(self)
            oEnter(self)
            pcall(function()
                if slua.isValid(self.Vehicle) then
                    F.autoApplyVehicleSkinOnEnter(self.Vehicle)
                end
            end)
        end
        VUC._AddOutfitEnterVehHooked = true
    end)
end

function F.hookWeaponWear()
    pcall(function()
        local HT = require("client.logic.lobby.hall_theme_utils")
        local o = HT.IsWeaponWear
        HT.IsWeaponWear = function(insId)
            insId = tonumber(insId)
            if F.isInjectedIns(insId) then
                local c = F.cache()
                local Arm = require("client.logic.armory.logic_armory")
                for wid, w in pairs(c.weapons) do
                    if tonumber(w.insID) == insId then
                        if Arm.rsp_list and Arm.rsp_list.install_list and Arm.rsp_list.install_list[wid] then
                            return tonumber(Arm.rsp_list.install_list[wid].skin_id) == insId
                        end
                        return true
                    end
                end
            end
            return o(insId)
        end
    end)
end

function F.hookNotice()
    pcall(function()
        if DataMgr and not DataMgr._AddOutfitExpireHooked then
            DataMgr._AddOutfitExpireHooked = true
            local oValid = DataMgr.IsValidTime
            DataMgr.IsValidTime = function(expireTS)
                if expireTS == nil or tonumber(expireTS) == 0 then return true end
                if oValid and oValid(expireTS) then return true end
                local inMatch = false
                pcall(function()
                    inMatch = GameStatus and GameStatus.IsInFightingStatus and GameStatus.IsInFightingStatus()
                end)
                if not inMatch then return true end
                return false
            end
        end
    end)
end

function F.wrapWardrobeClick(classMod, key)
    if not classMod or not classMod[key] or classMod["_AddOutfitWrap_" .. key] then return end
    classMod["_AddOutfitWrap_" .. key] = true
    local orig = classMod[key]
    classMod[key] = function(self, widget, index)
        local itemData = self.LoopScrollGrid_Normal and self.LoopScrollGrid_Normal:GetItemData(index)
        if itemData then
            F.clearItemExpire(itemData, itemData.ins_id, itemData.res_id)
            F.ensureDepotItemValid(itemData.ins_id, itemData.res_id)
        end
        return orig(self, widget, index)
    end
end

function F.hookWardrobeWearClicks()
    if _G.AddOutfitWearClickHooked then return end
    _G.AddOutfitWearClickHooked = true
    F.hookNotice()
    pcall(function()
        local avatarClass = require("client.slua.umg.Wardrobe.subtab_avatar")
        F.wrapWardrobeClick(avatarClass, "OnClickItem")
        F.wrapWardrobeClick(avatarClass, "ClickAvatarItem")
    end)
    pcall(function()
        local suitClass = require("client.slua.umg.Wardrobe.subtab_suit")
        F.wrapWardrobeClick(suitClass, "OnClickItem")
    end)
    pcall(function()
        local bagClass = require("client.slua.umg.Wardrobe.subtab_bag")
        F.wrapWardrobeClick(bagClass, "OnClickItem")
    end)
end

function F.hookAvatarValid()
    pcall(function()
        local path = "GameLua.Mod.Library.GamePlay.Avatar.Component.CharacterAvatarComponent"
        local comp = require(path)
        if comp and comp.CheckItemValid then
            local o = comp.CheckItemValid
            comp.CheckItemValid = function(self, resID)
                if F.isInjectedRes(resID) then return true end
                return o(self, resID)
            end
        end
    end)
end

function F.isInRealMatch()
    local ok, r = pcall(function()
        return GameStatus and GameStatus.IsInFightingStatus and GameStatus.IsInFightingStatus()
    end)
    return ok and r == true
end

function F.getLocalChar()
    local ok, GD = pcall(require, "GameLua.GameCore.Data.GameplayData")
    if not ok or not GD then return nil end
    local char = GD.GetPlayerCharacter()
    if char and slua.isValid(char) then return char end
    return nil
end

function F.getWAC(char)
    local w = char and char.GetCurrentWeapon and char:GetCurrentWeapon()
    if slua.isValid(w) and slua.isValid(w.WeaponAvatarComponent) then
        return w.WeaponAvatarComponent
    end
    return nil
end

function F.notify(msg)
    if not DEBUG then return end
    pcall(function() if ShowNotice then ShowNotice("[AddOutfit] " .. tostring(msg)) end end)
end

function F.getDesiredOutfit()
    if MATCH_CONFIG.outfitRes and MATCH_CONFIG.outfitRes > 0 then
        return MATCH_CONFIG.outfitRes
    end
    local wornSuitRes
    pcall(function()
        local _, res = F.findWornInsBySubType(OUTFIT_SUB, function(r) return F.isSuitRes(r) end)
        wornSuitRes = tonumber(res)
    end)
    if wornSuitRes and wornSuitRes > 0 then return wornSuitRes end
    local tshirtWorn = false
    pcall(function()
        local ins = F.findWornInsBySubType(OUTFIT_SUB, function(r) return F.isTshirtRes(r) end)
        tshirtWorn = ins ~= nil
    end)
    if tshirtWorn then return nil end
    F.syncBodyCacheFromLobby()
    local c = F.cache()
    return c.outfitRes
end

function F.matchApplyOutfit(char)
    local outfitRes = F.getDesiredOutfit()
    if not outfitRes then return true end
    if not F.isResourcesReady(outfitRes) then
        F.requestResourceDownload(outfitRes)
        return false
    end
    local comp = F.getAvatarComp2(char)
    if not comp then return false end
    local ok = F.setMakeSkin(comp, outfitRes, F.CUST_SLOT.ClothesEquipemtSlot, { allowPutOn = true })
    return ok
end

function F.getDesiredHat()
    if MATCH_CONFIG.hatRes and tonumber(MATCH_CONFIG.hatRes) > 0 then
        return tonumber(MATCH_CONFIG.hatRes)
    end
    F.syncHatCacheFromLobby()
    local h = F.cache().hatRes
    if h and tonumber(h) > 0 then return tonumber(h) end
    return tonumber(_G.AddOutfitLastLobbyHatRes) or nil
end

function F.ensureSkinDownload(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return end
    _G.skinIdCache = _G.skinIdCache or {}
    if not _G.skinIdCache[resID] then
        F.requestResourceDownload(resID)
        _G.skinIdCache[resID] = true
    end
end

function F.syncGlobalWearSkins()
    _G.CustSlotType = F.CUST_SLOT
    _G.skinIdCache = _G.skinIdCache or {}
    _G.HatSkin = tonumber(F.getDesiredHat()) or 0
    local outfit = F.getDesiredOutfit()
    _G.SuitSkin = tonumber(outfit)
        or tonumber(F.getDesiredWear("tshirtRes", "tshirtRes", "AddOutfitLastLobbyTshirtRes", F.syncBodyCacheFromLobby))
        or 0
    _G.PantsSkin = tonumber(F.getDesiredWear("pantsRes", "pantsRes", "AddOutfitLastLobbyPantsRes", F.syncBodyCacheFromLobby)) or 0
    _G.ShoesSkin = tonumber(F.getDesiredWear("shoesRes", "shoesRes", "AddOutfitLastLobbyShoesRes", F.syncBodyCacheFromLobby)) or 0
    _G.GlovesSkin = tonumber(F.getDesiredWear("glovesRes", "glovesRes", "AddOutfitLastLobbyGlovesRes", F.syncBodyCacheFromLobby)) or 0
    _G.MaskSkin = tonumber(F.getDesiredMask()) or 0
    _G.GlassSkin = tonumber(F.getDesiredGlass()) or 0
    _G.GliderSkin = tonumber(F.getDesiredGliderRes()) or 0
    _G.ParachuteSkin = tonumber(F.getDesiredParachuteRes()) or 0
end

function F.setMakeSkinAtIndex(comp, applyIdx, resID, slotID)
    resID = tonumber(resID)
    slotID = tonumber(slotID)
    applyIdx = tonumber(applyIdx)
    if not comp or not slua.isValid(comp) or not resID or resID <= 0 or not slotID or applyIdx == nil then
        return false
    end
    local changed = false
    pcall(function()
        local net = comp.NetAvatarData
        if not net then return end
        local applyData = net.SlotSyncData
        if not applyData or not slua.isValid(applyData) then return end
        local equipment = applyData:Get(applyIdx)
        if equipment and equipment.SlotID == slotID then
            local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
            if cur ~= resID then
                F.ensureSkinDownload(resID)
                equipment.ItemId = resID
                if equipment.ItemID ~= nil then equipment.ItemID = resID end
                applyData:Set(applyIdx, equipment)
                changed = true
            end
        end
    end)
    return changed
end

function F.applySlotSkinBatch(comp, entries, opts)
    opts = opts or {}
    if not comp or not slua.isValid(comp) or not entries then return false end
    local changed, anyOk = false, false
    pcall(function()
        local net = comp.NetAvatarData
        if not net then return end
        local applyData = net.SlotSyncData
        if not applyData or not slua.isValid(applyData) then return end
        local num = applyData:Num()
        for _, e in ipairs(entries) do
            local itemId, slotId = tonumber(e[1]), tonumber(e[2])
            if itemId and itemId > 0 and slotId then
                F.ensureSkinDownload(itemId)
                for i = 0, num - 1 do
                    local equipment = applyData:Get(i)
                    if equipment and equipment.SlotID == slotId then
                        local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
                        if cur == itemId then
                            anyOk = true
                        elseif cur ~= itemId then
                            equipment.ItemId = itemId
                            if equipment.ItemID ~= nil then equipment.ItemID = itemId end
                            applyData:Set(i, equipment)
                            changed = true
                            anyOk = true
                        end
                        break
                    end
                end
            end
        end
        if (changed or opts.forceRep) and comp.OnRep_BodySlotStateChanged then
            comp:OnRep_BodySlotStateChanged()
        end
    end)
    return anyOk or changed
end

function F.setMakeSkin(comp, resID, slotID, opts)
    opts = opts or {}
    slotID, resID = tonumber(slotID), tonumber(resID)
    if not comp or not slua.isValid(comp) or not slotID or not resID or resID <= 0 then return false end
    local changed = false
    local already = false
    pcall(function()
        local net = comp.NetAvatarData
        if not net then return end
        local applyData = net.SlotSyncData
        if not applyData or not slua.isValid(applyData) then return end
        local num = applyData:Num()
        for i = 0, num - 1 do
            local equipment = applyData:Get(i)
            if equipment and equipment.SlotID == slotID then
                local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
                if cur == resID then
                    already = true
                elseif cur ~= resID then
                    F.ensureSkinDownload(resID)
                    equipment.ItemId = resID
                    if equipment.ItemID ~= nil then equipment.ItemID = resID end
                    applyData:Set(i, equipment)
                    changed = true
                end
                break
            end
        end
        if changed and not opts.skipRep and comp.OnRep_BodySlotStateChanged then
            comp:OnRep_BodySlotStateChanged()
        end
        if opts.inAir and comp.PutOnCustomEquipmentByID then
            comp:PutOnCustomEquipmentByID(resID)
        end
    end)
    if already or changed then return true end
    if opts.allowPutOn and comp.PutOnCustomEquipmentByID then
        pcall(function() comp:PutOnCustomEquipmentByID(resID) end)
        return true
    end
    return false
end
F.setSlotSkin = F.setMakeSkin

_G.setMakeSkin = function(applyIdx, itemId, applyEquipSlot)
    local char = F.getLocalChar()
    if not char then return end
    local comp = F.getAvatarComp2(char)
    if not comp then return end
    if F.setMakeSkinAtIndex(comp, applyIdx, itemId, applyEquipSlot) then
        pcall(function()
            if comp.OnRep_BodySlotStateChanged then comp:OnRep_BodySlotStateChanged() end
        end)
    end
end

function F.patchWearNetAvatar(comp, resID, slotName, noForceShow)
    if not comp or not slua.isValid(comp) or not resID or resID <= 0 or not slotName then return false end
    local ok = false
    pcall(function()
        local EAvatarSlotType = import("EAvatarSlotType")
        local ESyncOperation = import("ESyncOperation")
        local slot = EAvatarSlotType[slotName]
        if not slot then return end
        local sync = comp.GetSlotSyncData and comp:GetSlotSyncData(slot)
        if sync then
            sync.ItemID = resID
            if sync.FakeItemID ~= nil then sync.FakeItemID = resID end
            sync.OperationType = ESyncOperation.PutOn
            if comp.ChangeSlotSyncData then
                comp:ChangeSlotSyncData(sync)
                ok = true
            end
        end
        if not noForceShow and comp.SetAvatarVisibility then
            comp:SetAvatarVisibility(slot, true, true)
        end
    end)
    return ok
end

function F.patchHatNetAvatar(comp, hatRes)
    return F.patchWearNetAvatar(comp, hatRes, "EAvatarSlotType_HatEquipemtSlot")
end

function F.matchApplyWearItem(char, resID, slotID, label, opts)
    if not resID or resID <= 0 then return true end
    slotID = slotID or F.resToCustSlot(resID)
    if not slotID then return false end
    local comp = F.getAvatarComp2(char)
    if not comp then return false end
    opts = opts or {}
    opts.allowPutOn = true
    local ok = F.setMakeSkin(comp, resID, slotID, opts)
    return ok
end

function F.getDesiredMask()
    if MATCH_CONFIG.maskRes and tonumber(MATCH_CONFIG.maskRes) > 0 then
        return tonumber(MATCH_CONFIG.maskRes)
    end
    F.syncFaceCacheFromLobby()
    local m = F.cache().maskRes
    if m and tonumber(m) > 0 then return tonumber(m) end
    return tonumber(_G.AddOutfitLastLobbyMaskRes) or nil
end

function F.getDesiredGlass()
    if MATCH_CONFIG.glassRes and tonumber(MATCH_CONFIG.glassRes) > 0 then
        return tonumber(MATCH_CONFIG.glassRes)
    end
    F.syncFaceCacheFromLobby()
    local g = F.cache().glassRes
    if g and tonumber(g) > 0 then return tonumber(g) end
    return tonumber(_G.AddOutfitLastLobbyGlassRes) or nil
end

function F.matchApplyFaceWear(char)
    local maskRes = F.getDesiredMask()
    local glassRes = F.getDesiredGlass()
    if (not maskRes or maskRes <= 0) and (not glassRes or glassRes <= 0) then
        return true
    end
    char = char or F.getLocalChar()
    if not char then return false end
    local comp = F.getAvatarComp2(char)
    if not comp then return false end

    local ok = false
    pcall(function()
        local EAvatarSlotType = import("EAvatarSlotType")
        local ESyncOperation = import("ESyncOperation")
        local net = comp.NetAvatarData
        local applyData = net and net.SlotSyncData

        local function forceApplySlot(resID, slotID, slotNameStr)
            if not resID or resID <= 0 then return end
            
            local slotEnum = EAvatarSlotType and EAvatarSlotType[slotNameStr]
            local needRep = false
            
            if applyData and slua.isValid(applyData) then
                local found = false
                for i = 0, applyData:Num() - 1 do
                    local equipment = applyData:Get(i)
                    if equipment and equipment.SlotID == slotID then
                        found = true
                        local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
                        if cur ~= resID then
                            F.ensureSkinDownload(resID)
                            equipment.ItemId = resID
                            if equipment.ItemID ~= nil then equipment.ItemID = resID end
                            if equipment.FakeItemID ~= nil then equipment.FakeItemID = resID end
                            applyData:Set(i, equipment)
                            needRep = true
                        end
                        break
                    end
                end
                
                if not found then
                    F.ensureSkinDownload(resID)
                    local entry = import("AvatarSyncData")()
                    entry.SlotID = slotID
                    entry.ItemId = resID
                    entry.ItemID = resID
                    entry.FakeItemID = resID
                    entry.OperationType = ESyncOperation.PutOn
                    applyData:Add(entry)
                    needRep = true
                end
            end

            _G.FaceWearStateCache = _G.FaceWearStateCache or {}
            local cacheKey = tostring(comp) .. "_" .. tostring(slotID)

            if needRep or _G.FaceWearStateCache[cacheKey] ~= resID then
                if slotEnum then
                    if comp.CancelHideAvatarBySlot then comp:CancelHideAvatarBySlot(slotEnum) end
                    if comp.SetAvatarVisibility then comp:SetAvatarVisibility(slotEnum, true, true) end
                end
                if comp.PutOnCustomEquipmentByID then
                    comp:PutOnCustomEquipmentByID(resID)
                end
                
                _G.FaceWearStateCache[cacheKey] = resID
                ok = true
            else
                if slotEnum and comp.CancelHideAvatarBySlot then 
                    comp:CancelHideAvatarBySlot(slotEnum) 
                end
            end
        end

        forceApplySlot(maskRes, F.CUST_SLOT.FaceEquipemtSlot, "EAvatarSlotType_FaceEquipemtSlot")
        forceApplySlot(glassRes, F.CUST_SLOT.GlassEquipemtSlot, "EAvatarSlotType_GlassEquipemtSlot")
        
        if ok and comp.OnRep_BodySlotStateChanged then
            comp:OnRep_BodySlotStateChanged()
        end
    end)
    return ok
end

function F.getDesiredWear(configKey, cacheResKey, globalKey, syncFn)
    local fixed = MATCH_CONFIG[configKey] and tonumber(MATCH_CONFIG[configKey])
    if fixed and fixed > 0 then return fixed end
    local persistKey = cacheResKey and cacheResKey:gsub("Res$", "")
    if persistKey and PERSIST.configSlots then
        local pr = tonumber(PERSIST.configSlots[persistKey])
        if pr and pr > 0 then return pr end
    end
    if syncFn then syncFn() end
    local v = F.cache()[cacheResKey]
    if v and tonumber(v) > 0 then return tonumber(v) end
    return tonumber(_G[globalKey]) or nil
end

local EQUIP_APPLY = { lastBagWrite = 0, lastHelmetWrite = 0 }

function F.levelSkinID(baseSkin, level)
    level = tonumber(level) or 1
    if level < 1 then level = 1 end
    local mapped = 0
    pcall(function()
        local t = CDataTable.GetTableData("BackpackMapping", baseSkin)
        if t then
            if level <= 1 then mapped = tonumber(t.SkinItemIDLv1) or 0
            elseif level == 2 then mapped = tonumber(t.SkinItemIDLv2) or 0
            else mapped = tonumber(t.SkinItemIDLv3) or 0 end
        end
    end)
    if mapped > 0 then return mapped end
    return baseSkin + (level - 1) * 1000
end

function F.applyEquipSkinToComp(comp, bagRes, helmetRes)
    local applied, found = false, false
    pcall(function()
        local EAvatarSlotType = import("EAvatarSlotType")
        local BackpackUtils = import("BackpackUtils")
        local function doSlot(slotEnum, res, levelFn, lastKey)
            res = tonumber(res) or 0
            if res <= 0 or not slotEnum then return end
            local sync = comp.GetSlotSyncData and comp:GetSlotSyncData(slotEnum)
            if not sync then return end
            local cur = tonumber(sync.ItemID) or 0
            local addID = tonumber(sync.AdditionalItemID) or 0
            if cur <= 0 and addID <= 0 then return end
            found = true
            local lvl = 1
            pcall(function()
                if levelFn then lvl = levelFn(addID > 0 and addID or cur) or 1 end
            end)
            if lvl < 1 then lvl = 1 end
            local target = F.levelSkinID(res, lvl)
            if target > 0 and cur ~= target then
                sync.ItemID = target
                comp:ChangeSlotSyncData(sync)
                applied = true
                EQUIP_APPLY[lastKey] = target
            end
        end
        doSlot(EAvatarSlotType.EAvatarSlotType_BackpackEquipemtSlot, bagRes,
               BackpackUtils.GetEquipmentBagLevel, "lastBagWrite")
        doSlot(EAvatarSlotType.EAvatarSlotType_HelmetEquipemtSlot, helmetRes,
               BackpackUtils.GetEquipmentHelmetLevel, "lastHelmetWrite")
    end)
    return applied, found
end

function F.matchApplyEquipmentSkin(char, bagRes, helmetRes)
    bagRes = tonumber(bagRes) or 0
    helmetRes = tonumber(helmetRes) or 0
    if bagRes <= 0 and helmetRes <= 0 then return true end
    local comp = char.CharacterAvatarComp2_BP
    if not slua.isValid(comp) then return false end

    local applied, found = F.applyEquipSkinToComp(comp, bagRes, helmetRes)

    if applied then
        pcall(function()
            if comp.OnRep_BodySlotStateChanged then comp:OnRep_BodySlotStateChanged() end
        end)
        return true
    end
    return found
end

function F.hookEquipmentRectify()
    _G.AddOutfitEquipRectifyFn = function(self)
        pcall(function()
            if self.IsLobbyActor and self:IsLobbyActor() then return end
            if not (self.IsSelf and self:IsSelf()) then return end
            local bagRes = F.getDesiredWear("bagRes", "bagRes", "AddOutfitLastLobbyBagRes", F.syncBodyCacheFromLobby)
            local helmetRes = F.getDesiredWear("helmetRes", "helmetRes", "AddOutfitLastLobbyHelmetRes", F.syncBodyCacheFromLobby)
            if (tonumber(bagRes) or 0) <= 0 and (tonumber(helmetRes) or 0) <= 0 then return end
            F.applyEquipSkinToComp(self, bagRes, helmetRes)
        end)
    end
    pcall(function()
        local MCAC = require("GameLua.Mod.TPlan.Component.MetroCharacterAvatarComponent")
        if MCAC._AddOutfitRectifyHooked then return end
        MCAC._AddOutfitRectifyHooked = true
        local o = MCAC.ProcessClientAvatarRectify
        MCAC.ProcessClientAvatarRectify = function(self)
            o(self)
            if _G.AddOutfitEquipRectifyFn then _G.AddOutfitEquipRectifyFn(self) end
        end
    end)
end

function F.applyAirborneSlots(char, forceInAir)
    local comp = F.getAvatarComp2(char)
    if not comp or not slua.isValid(comp) then return false end
    pcall(function() F.syncAirborneToDataMgr() end)
    local inAir = forceInAir == true or F.isCharacterAirborne(char)
    local any = false
    local paraRes = F.getDesiredParachuteRes()
    if paraRes and paraRes > 0 then
        any = true
        if not F.isResourcesReady(paraRes) then F.requestResourceDownload(paraRes) end
        F.setMakeSkin(comp, paraRes, F.CUST_SLOT.ParachuteEquipemtSlot, { inAir = inAir })
    end
    local gliderRes = F.getDesiredGliderRes()
    if gliderRes and gliderRes > 0 then
        any = true
        if not F.isResourcesReady(gliderRes) then F.requestResourceDownload(gliderRes) end
        F.setMakeSkin(comp, gliderRes, F.CUST_SLOT.GlideEquipemtSlot, { inAir = inAir })
    end
    return any
end

function F.matchApplyBodyWear(char)
    local pieces = {}
    if not F.getDesiredOutfit() then
        pieces[#pieces + 1] = {
            F.getDesiredWear("tshirtRes", "tshirtRes", "AddOutfitLastLobbyTshirtRes", F.syncBodyCacheFromLobby),
            F.CUST_SLOT.ClothesEquipemtSlot, "T-shirt",
        }
    end
    pieces[#pieces + 1] = { F.getDesiredWear("pantsRes", "pantsRes", "AddOutfitLastLobbyPantsRes", F.syncBodyCacheFromLobby), F.CUST_SLOT.PantsEquipemtSlot, "Pants" }
    pieces[#pieces + 1] = { F.getDesiredWear("shoesRes", "shoesRes", "AddOutfitLastLobbyShoesRes", F.syncBodyCacheFromLobby), F.CUST_SLOT.ShoesEquipemtSlot, "Shoes" }
    pieces[#pieces + 1] = { F.getDesiredWear("glovesRes", "glovesRes", "AddOutfitLastLobbyGlovesRes", F.syncBodyCacheFromLobby), F.CUST_SLOT.HandEffectEquipemtSlot, "Gloves" }
    local any, okAll = false, true
    for _, p in ipairs(pieces) do
        local res, slot, label = p[1], p[2], p[3]
        if res and res > 0 then
            any = true
            okAll = F.matchApplyWearItem(char, res, slot, label) and okAll
        end
    end
    local anyAir = F.applyAirborneSlots(char, false)
    if anyAir then any = true end
    local bagRes = F.getDesiredWear("bagRes", "bagRes", "AddOutfitLastLobbyBagRes", F.syncBodyCacheFromLobby)
    local helmetRes = F.getDesiredWear("helmetRes", "helmetRes", "AddOutfitLastLobbyHelmetRes", F.syncBodyCacheFromLobby)
    if (tonumber(bagRes) or 0) > 0 or (tonumber(helmetRes) or 0) > 0 then
        any = true
        okAll = F.matchApplyEquipmentSkin(char, bagRes, helmetRes) and okAll
    end
    return not any or okAll
end

function F.matchApplyAllSlots(char)
    if not char then return false end
    F.syncGlobalWearSkins()
    local comp = F.getAvatarComp2(char)
    if not comp then return false end

    local entries = {}
    local function add(skin, slot)
        skin = tonumber(skin)
        if skin and skin > 0 and slot then entries[#entries + 1] = { skin, slot } end
    end
    add(_G.HatSkin, F.CUST_SLOT.HatEquipemtSlot)
    add(_G.SuitSkin, F.CUST_SLOT.ClothesEquipemtSlot)
    add(_G.PantsSkin, F.CUST_SLOT.PantsEquipemtSlot)
    add(_G.ShoesSkin, F.CUST_SLOT.ShoesEquipemtSlot)
    add(_G.GlovesSkin, F.CUST_SLOT.HandEffectEquipemtSlot)
    add(_G.MaskSkin, F.CUST_SLOT.FaceEquipemtSlot)
    add(_G.GlassSkin, F.CUST_SLOT.GlassEquipemtSlot)

    local ok = false
    if #entries > 0 then
        ok = F.applySlotSkinBatch(comp, entries, { forceRep = true })
        if not ok then
            for _, e in ipairs(entries) do
                if F.setMakeSkin(comp, e[1], e[2], { allowPutOn = true }) then ok = true end
            end
        end
    end

    F.applyAirborneSlots(char, false)

    local bagRes = F.getDesiredWear("bagRes", "bagRes", "AddOutfitLastLobbyBagRes", F.syncBodyCacheFromLobby)
    local helmetRes = F.getDesiredWear("helmetRes", "helmetRes", "AddOutfitLastLobbyHelmetRes", F.syncBodyCacheFromLobby)
    if (tonumber(bagRes) or 0) > 0 or (tonumber(helmetRes) or 0) > 0 then
        ok = F.matchApplyEquipmentSkin(char, bagRes, helmetRes) or ok
    end

    return ok or #entries == 0
end

function F.matchApplyHat(char)
    local hatRes = tonumber(F.getDesiredHat())
    if not hatRes or hatRes <= 0 then return true end
    char = char or F.getLocalChar()
    if not char then return false end
    local comp = F.getAvatarComp2(char)
    if not comp then return false end
    local slotID = F.CUST_SLOT.HatEquipemtSlot
    local ok = false
    pcall(function()
        local net = comp.NetAvatarData
        if not net then return end
        local applyData = net.SlotSyncData
        if not applyData or not slua.isValid(applyData) then return end
        local found = false
        for i = 0, applyData:Num() - 1 do
            local equipment = applyData:Get(i)
            if equipment and equipment.SlotID == slotID then
                found = true
                local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
                if cur ~= hatRes then
                    F.ensureSkinDownload(hatRes)
                    equipment.ItemId = hatRes
                    if equipment.ItemID ~= nil then equipment.ItemID = hatRes end
                    if equipment.FakeItemID ~= nil then equipment.FakeItemID = hatRes end
                    applyData:Set(i, equipment)
                end
                ok = true
                break
            end
        end
        if not found then
            F.ensureSkinDownload(hatRes)
            local ESyncOperation = import("ESyncOperation")
            local entry = import("AvatarSyncData")()
            entry.SlotID = slotID
            entry.ItemId = hatRes
            entry.ItemID = hatRes
            entry.FakeItemID = hatRes
            entry.OperationType = ESyncOperation.PutOn
            applyData:Add(entry)
            ok = true
        end
        
    end)
    return ok
end

local _avatarItemsRegistered = false

function F.getDesiredWeaponSkins()
    if PERF.desiredSkins then return PERF.desiredSkins end
    F.syncWeaponCacheFromLobby()
    local out, seen = {}, {}
    local function add(res)
        res = tonumber(res)
        if res and res > 0 and not seen[res] then seen[res] = true; out[#out+1] = res end
    end
    for wid, w in pairs(F.cache().weapons) do
        if wid ~= MELEE_ID and w.resID then add(w.resID) end
    end
    if MATCH_CONFIG.weaponSkins then
        for _, res in pairs(MATCH_CONFIG.weaponSkins) do add(res) end
    end
    PERF.desiredSkins = out
    return out
end

function F._cacheSkinTarget(weaponResID, skin)
    if skin and skin > 0 then PERF.skinTarget[weaponResID] = skin else PERF.skinTarget[weaponResID] = 0 end
    return skin
end

local GUN_MASTER_SYN_SLOT = 7

function F.findSkinSlotInSynData(weapon)
    if not slua.isValid(weapon) then return GUN_MASTER_SYN_SLOT, 0 end
    local arr = weapon.synData
    if not arr or not slua.isValid(arr) then return GUN_MASTER_SYN_SLOT, 0 end
    local count = 0
    pcall(function() count = arr:Num() end)
    for i = 0, math.min(count - 1, 15) do
        local ok2, att = pcall(function() return arr:Get(i) end)
        if ok2 and att then
            local ok3, defRef = pcall(slua.IndexReference, att, "defineID")
            if ok3 and defRef then
                local tid = 0
                pcall(function() tid = tonumber(defRef.TypeSpecificID) or 0 end)
                if tid >= 1000000 then
                    return i, tid
                end
            end
        end
    end
    return GUN_MASTER_SYN_SLOT, 0
end

function F.resolveWeaponTypeID(weaponResID)
    weaponResID = tonumber(weaponResID) or 0
    if weaponResID <= 0 then return 0 end
    local found = 0
    pcall(function()
        local wc = CDataTable.GetTableData("WeaponConfig", weaponResID)
        if wc then found = tonumber(wc.WeaponID or wc.WeaponId or wc.weaponID or 0) end
    end)
    if found > 0 then return found end
    pcall(function()
        local ic = CDataTable.GetTableData("Item", weaponResID)
        if ic then found = tonumber(ic.WeaponID or ic.weaponId or 0) end
    end)
    return found > 0 and found or weaponResID
end

function F.findTargetSkinForWeaponRes(weaponResID)
    weaponResID = tonumber(weaponResID) or 0
    if weaponResID <= 0 then return nil end
    local cached = PERF.skinTarget[weaponResID]
    if cached ~= nil then return cached == 0 and nil or cached end

    local memSkin = F.getMatchWeaponSkin(weaponResID)
    if memSkin then return F._cacheSkinTarget(weaponResID, memSkin) end
    local typeID = F.resolveWeaponTypeID(weaponResID)
    if typeID > 0 and typeID ~= weaponResID then
        memSkin = F.getMatchWeaponSkin(typeID)
        if memSkin then return F._cacheSkinTarget(weaponResID, memSkin) end
    end

    if MATCH_CONFIG.weaponSkins and MATCH_CONFIG.weaponSkins[weaponResID] then
        local fixed = tonumber(MATCH_CONFIG.weaponSkins[weaponResID])
        if fixed and fixed > 0 then return F._cacheSkinTarget(weaponResID, fixed) end
    end

    for _, skinRes in ipairs(F.getDesiredWeaponSkins()) do
        local wid = F.weaponIdFromSkin(skinRes)
        if wid and tonumber(wid) == weaponResID then return F._cacheSkinTarget(weaponResID, skinRes) end
    end

    local typeID = F.resolveWeaponTypeID(weaponResID)
    if typeID > 0 and typeID ~= weaponResID then
        if MATCH_CONFIG.weaponSkins and MATCH_CONFIG.weaponSkins[typeID] then
            local fixed = tonumber(MATCH_CONFIG.weaponSkins[typeID])
            if fixed and fixed > 0 then return F._cacheSkinTarget(weaponResID, fixed) end
        end
        for _, skinRes in ipairs(F.getDesiredWeaponSkins()) do
            local wid = F.weaponIdFromSkin(skinRes)
            if wid and tonumber(wid) == typeID then return F._cacheSkinTarget(weaponResID, skinRes) end
        end
    end

    local avatarMatch = nil
    pcall(function()
        local AU = import("AvatarUtils")
        local weaponBase = AU.GetWeaponAvatarParentID(AU.GetBPIDByResID(weaponResID), false)
        if not weaponBase or weaponBase <= 0 then return end
        for _, skinRes in ipairs(F.getDesiredWeaponSkins()) do
            local skinBase = AU.GetWeaponAvatarParentID(AU.GetBPIDByResID(skinRes), false)
            if skinBase and skinBase > 0 and skinBase == weaponBase then
                avatarMatch = skinRes
                return
            end
        end
    end)
    if avatarMatch then return F._cacheSkinTarget(weaponResID, avatarMatch) end

    local c = F.cfg(weaponResID)
    local st = F.subType(c)
    if st and GUN_SUB[st] and MATCH_CONFIG.weaponSkins then
        for _, skinRes in pairs(MATCH_CONFIG.weaponSkins) do
            local skinWid = F.weaponIdFromSkin(skinRes)
            if skinWid then
                local sc = F.cfg(tonumber(skinWid))
                if sc and F.subType(sc) == st then return F._cacheSkinTarget(weaponResID, skinRes) end
            end
            local sc = F.cfg(skinRes)
            if sc and GUN_SUB[F.subType(sc)] and F.subType(sc) == st then return F._cacheSkinTarget(weaponResID, skinRes) end
        end
    end

    PERF.skinTarget[weaponResID] = 0
    return nil
end

function F.getSynMasterSkinID(weapon)
    if not slua.isValid(weapon) then return 0 end
    local id = 0
    pcall(function()
        local slot, tid = F.findSkinSlotInSynData(weapon)
        id = tid
        if id == 0 then
            local arr = weapon.synData
            if not arr or not slua.isValid(arr) then return end
            local att = arr:Get(GUN_MASTER_SYN_SLOT)
            if not att then return end
            id = slua.IndexReference(att, "defineID").TypeSpecificID or 0
        end
    end)
    return id
end

_G.AddOutfitSkinIdMappings = _G.AddOutfitSkinIdMappings or {}
_G.AddOutfitLastAppliedSkin = _G.AddOutfitLastAppliedSkin or {}

function F.buildSkinMappings()
    if not PERF.mappingsDirty then return end
    F.syncWeaponCacheFromLobby()
    PERF.mappingsDirty = false
    local m = _G.AddOutfitSkinIdMappings
    for k in pairs(m) do m[k] = nil end
    for wid, w in pairs(F.cache().weapons) do
        wid = tonumber(wid)
        if wid and w.resID and w.resID > 0 then
            m[wid] = { tonumber(w.resID) }
        end
    end
    if MATCH_CONFIG.weaponSkins then
        for weaponKey, skinRes in pairs(MATCH_CONFIG.weaponSkins) do
            weaponKey = tonumber(weaponKey)
            skinRes = tonumber(skinRes)
            if weaponKey and skinRes and skinRes > 0 and not m[weaponKey] then
                m[weaponKey] = { skinRes }
            end
        end
    end
end

function F.get_skin_id(currentGunId, maxIt)
    currentGunId = tonumber(currentGunId) or 0
    maxIt = tonumber(maxIt) or 0
    if currentGunId <= 0 and maxIt <= 0 then return 0 end
    F.buildSkinMappings()
    if maxIt > 0 then
        local fromMem = F.getMatchWeaponSkin(maxIt)
        if fromMem then return fromMem end
    end
    local fromMem2 = F.getMatchWeaponSkin(F.resolveWeaponTypeID(currentGunId))
    if fromMem2 then return fromMem2 end
    local m = _G.AddOutfitSkinIdMappings
    if maxIt > 0 and m[maxIt] and m[maxIt][1] then return tonumber(m[maxIt][1]) end
    local list = m[currentGunId]
    if list and list[1] then return tonumber(list[1]) end
    local typeId = F.resolveWeaponTypeID(currentGunId)
    if typeId > 0 and m[typeId] and m[typeId][1] then return tonumber(m[typeId][1]) end
    local target = F.findTargetSkinForWeaponRes(maxIt > 0 and maxIt or currentGunId)
    if target then return target end
    return currentGunId
end

function F.applySkinToWeaponRef(CurWeapon)
    if not slua.isValid(CurWeapon) then return false end
    local AttachmentArray = CurWeapon.synData
    if not AttachmentArray or not slua.isValid(AttachmentArray) then return false end

    local AttachmentData = AttachmentArray:Get(GUN_MASTER_SYN_SLOT)
    if not AttachmentData then return false end

    local current_gunid = 0
    pcall(function() current_gunid = slua.IndexReference(AttachmentData, "defineID").TypeSpecificID or 0 end)
    if not current_gunid or current_gunid <= 0 then return false end

    local MaxIt = 0
    pcall(function()
        if CurWeapon.GetWeaponID then MaxIt = CurWeapon:GetWeaponID() end
        if MaxIt <= 0 then MaxIt = CurWeapon:GetItemDefineID().TypeSpecificID end
    end)
    MaxIt = tonumber(MaxIt) or 0
    local tmp_id = F.get_skin_id(current_gunid, MaxIt)
    tmp_id = tonumber(tmp_id) or 0
    if tmp_id <= 0 or MaxIt <= 0 then return false end
    
    local changedAny = false

    local wac = CurWeapon.WeaponAvatarComponent
    local currentVisualID = 0
    if slua.isValid(wac) then currentVisualID = wac.CachedLoadedID or 0 end

    if currentVisualID ~= tmp_id then
        changedAny = true
        pcall(function()
            local defRef = slua.IndexReference(AttachmentData, "defineID")
            defRef.TypeSpecificID = tmp_id
            local c0 = F.cfg(tmp_id)
            if c0 and c0.ItemType and defRef.Type ~= nil then defRef.Type = c0.ItemType end
            AttachmentData.operationType = 0
            AttachmentArray:Set(GUN_MASTER_SYN_SLOT, AttachmentData)
        end)
    end

    if _G.LexusConfig.SkinAttachment and tmp_id >= 1000000 and _G.VIP_Attachments and _G.VIP_Attachments[tmp_id] then
        local attachSkinConfig = _G.VIP_Attachments[tmp_id]
        local baseAttachMap = _G.BaseAttachToIndex
        
        if attachSkinConfig and baseAttachMap then
            for AttachIdx = 0, 5 do 
                pcall(function()
                    local attachData = AttachmentArray:Get(AttachIdx)
                    if attachData then
                        local defineIDRef = slua.IndexReference(attachData, "defineID")
                        if defineIDRef then
                            local attachmentId = defineIDRef.TypeSpecificID
                            if attachmentId and attachmentId > 0 then
                                local baseAttId = attachmentId
                                if baseAttId > 1000000 then
                                    local strId = tostring(baseAttId)
                                    if #strId >= 9 then baseAttId = tonumber(string.sub(strId, 2, 7)) or baseAttId end
                                end

                                local mapIndex = baseAttachMap[baseAttId]
                                if mapIndex then
                                    local targetAttachId = attachSkinConfig[mapIndex]
                                    if targetAttachId and targetAttachId > 0 and targetAttachId ~= attachmentId then
                                        defineIDRef.TypeSpecificID = targetAttachId
                                        attachData.defineID = defineIDRef
                                        AttachmentArray:Set(AttachIdx, attachData)
                                        changedAny = true
                                        
                                        if slua.isValid(wac) then
                                            if wac.ClearMeshPathCacheBySlot then wac:ClearMeshPathCacheBySlot(AttachIdx) end
                                            if wac.ClearMeshBySlot then wac:ClearMeshBySlot(AttachIdx, true, true) end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end)
            end
        end
    end

    if changedAny then
        pcall(function()
            if slua.isValid(wac) then
                if currentVisualID ~= tmp_id then
                    if wac.ClearMeshPathCacheBySlot then wac:ClearMeshPathCacheBySlot(0) end
                    if wac.ClearMeshBySlot then wac:ClearMeshBySlot(0, true, true) end
                end
                
                if CurWeapon.DelayHandleAvatarMeshChanged then
                    CurWeapon:DelayHandleAvatarMeshChanged()
                end
                if wac.ReloadAllEquippedAvatar then
                    wac:ReloadAllEquippedAvatar(1) 
                end
            end
        end)
        _G.AddOutfitLastAppliedSkin[MaxIt] = tmp_id
        return true
    end
    
    return false
end

function _G.equip_weapon_avatar(uCharacter)
    if not uCharacter or not slua.isValid(uCharacter) then return false end
    F.buildSkinMappings()
    local WeaponManager = uCharacter:GetWeaponManager()
    if not WeaponManager or not slua.isValid(WeaponManager) then return false end
    local uWeaponList = WeaponManager:GetAllInventoryWeaponList(false)
    if not uWeaponList or not slua.isValid(uWeaponList) then return false end

    local appliedAny = false
    for i = 0, uWeaponList:Num() - 1 do
        local CurWeapon = uWeaponList:Get(i)
        if slua.isValid(CurWeapon) and F.applySkinToWeaponRef(CurWeapon) then
            appliedAny = true
        end
    end
    return appliedAny
end

function F.equipWeaponAvatarSynData(char)
    return _G.equip_weapon_avatar(char)
end

F.applySkinToWeapon = F.applySkinToWeaponRef

function F.registerWeaponAvatarItems(char)
    local pc = char.GetPlayerControllerSafety and char:GetPlayerControllerSafety()
    if not slua.isValid(pc) then return false end
    local AU = import("AvatarUtils")
    local BU = import("BackpackUtils")
    local addedCount = 0

    for _, resID in ipairs(F.getDesiredWeaponSkins()) do
        local doneDirect = false
        pcall(function()
            if pc.AddWeaponAvatarItem then
                pc:AddWeaponAvatarItem(tonumber(resID))
                doneDirect = true
                addedCount = addedCount + 1
            end
        end)
        if not doneDirect then
            pcall(function()
                local skinBPID = BU.GetBPIDByResID(tonumber(resID))
                local arr = slua.Array(UEnums.EPropertyClass.Int)
                local parents = AU.GetWeaponAvatarParentIDList(skinBPID, arr, false)
                if parents and parents.Num and parents:Num() > 0 and pc.WeaponAvatarItemList then
                    for _, parentID in pairs(parents) do
                        pc.WeaponAvatarItemList:Add(parentID, skinBPID)
                    end
                    addedCount = addedCount + 1
                end
            end)
        end
    end

    if addedCount == 0 then return false end

    pcall(function() if pc.InitWeaponAvatarItems then pc:InitWeaponAvatarItems() end end)
    pcall(function() if pc.OnWeaponAvatarUpdate then pc:OnWeaponAvatarUpdate() end end)
    return true
end

function F.reloadCurrentWeaponAvatar(char)
    pcall(function()
        local weapon = char.GetCurrentWeapon and char:GetCurrentWeapon()
        if not slua.isValid(weapon) then return end
        local wac = weapon.WeaponAvatarComponent
        if slua.isValid(wac) then
            local ES = import("EWeaponAttachmentSocketType")
            pcall(function() wac:ClearMeshPathCacheBySlot(ES.MasterGun) end)
            pcall(function() wac:ClearMeshBySlot(ES.MasterGun, true, true) end)
        end
        if weapon.DelayHandleAvatarMeshChanged then
            weapon:DelayHandleAvatarMeshChanged()
        elseif slua.isValid(wac) and wac.ReloadAllEquippedAvatar then
            local ESlotDescDiff = import("ESlotDescDiff")
            wac:ReloadAllEquippedAvatar(ESlotDescDiff.MeshDiff)
        end
    end)
end

local _weaponDiagDone = false
local _weaponApplied = false
local _lastWeaponResID = 0
local _weaponSpawnHooked = false

function F.onWeaponLuaInit(_, _, weapon)
    if not weapon or not slua.isValid(weapon) then return end
    local char = F.getLocalChar()
    if not char then return end
    local owner = nil
    pcall(function()
        if weapon.GetOwnerPawn then owner = weapon:GetOwnerPawn() end
    end)
    if not slua.isValid(owner) or owner ~= char then return end
    pcall(function()
        char:AddGameTimer(0.15, false, function()
            local c = F.getLocalChar()
            if c and slua.isValid(weapon) then
                F.applySkinToWeapon(weapon)
                _weaponApplied = false
            end
        end)
    end)
end

function F.hookWeaponSpawn()
    if _weaponSpawnHooked then return end
    pcall(function()
        if EventSystem and EventSystem.registEvent and EVENTTYPE_PLAYEREVENT_WEAPON and EVENTID_PLAYEREVENT_WEAPON_LUA_INIT then
            EventSystem:registEvent(EVENTTYPE_PLAYEREVENT_WEAPON, EVENTID_PLAYEREVENT_WEAPON_LUA_INIT, onWeaponLuaInit)
            _weaponSpawnHooked = true
        end
    end)
end

function F.matchApplyWeaponSkin(char)
    if not _avatarItemsRegistered then
        _avatarItemsRegistered = F.registerWeaponAvatarItems(char)
    end

    local curWeapon = char.GetCurrentWeapon and char:GetCurrentWeapon()
    if not slua.isValid(curWeapon) then return false end

    local currentVisualID = 0
    pcall(function()
        local wac = curWeapon.WeaponAvatarComponent
        if slua.isValid(wac) then currentVisualID = wac.CachedLoadedID or 0 end
    end)

    local curWeaponResID = 0
    pcall(function() curWeaponResID = curWeapon:GetItemDefineID().TypeSpecificID end)
    local targetSkin = F.findTargetSkinForWeaponRes(curWeaponResID) or curWeaponResID

    local isVisualMatched = false
    if currentVisualID > 0 and currentVisualID == targetSkin then
        isVisualMatched = true
    end

    if not _G.SmartWeaponWatcherActive then
        _G.SmartWeaponWatcherActive = true
        pcall(function()
            local ticker = require("common.time_ticker")
            if ticker and ticker.AddTimerLoop then
                ticker.AddTimerLoop(0, function()
                    if not _G.LexusConfig.ModSkin then return end
                    
                    if _G.AddOutfit and not _G.AddOutfit.isInRealMatch() then return end
                    
                    local pController = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
                    if not pController or not slua.isValid(pController) then return end
                    local pChar = pController:GetPlayerCharacterSafety()
                    if not pChar or not slua.isValid(pChar) then return end
                    
                    local WeaponManager = pChar:GetWeaponManager()
                    if not WeaponManager or not slua.isValid(WeaponManager) then return end
                    local uWeaponList = WeaponManager:GetAllInventoryWeaponList(false)
                    if not uWeaponList or not slua.isValid(uWeaponList) then return end
                    
                    local count = uWeaponList:Num()
                    for i = 0, count - 1 do
                        local wep = uWeaponList:Get(i)
                        if slua.isValid(wep) then
                            local synSkinID = F.getSynMasterSkinID(wep)
                            local baseID = 0
                            pcall(function() baseID = wep:GetItemDefineID().TypeSpecificID end)
                            local tSkin = F.findTargetSkinForWeaponRes(baseID) or baseID
                            
                            if synSkinID ~= tSkin or _G.LexusConfig.SkinAttachment then
                                if _G.AddOutfit and _G.AddOutfit.applySkinToWeapon then
                                    _G.AddOutfit.applySkinToWeapon(wep)
                                end
                            end
                        end
                    end
                end, -1, 0.8) 
            end
        end)
    end

    if isVisualMatched and not _G.LexusConfig.SkinAttachment then
        _weaponApplied = true
        return true
    end

    F.buildSkinMappings()
    local okSyn = F.applySkinToWeapon(curWeapon)

    return okSyn
end

local _matchTimer = nil
local _matchWearDone = false

function F.startMatchWatcher(char)
    if _matchTimer or PERF.matchActive then return end
    PERF.matchActive = true
    local skipWear = PERF.wearDoneThisMatch
    _matchWearDone = skipWear
    _avatarItemsRegistered = false
    _weaponDiagDone = false
    _weaponApplied = false
    _lastWeaponResID = 0
    local elapsed = 0

    _matchTimer = char:AddGameTimer(MATCH_TICK_SEC, true, function()
        elapsed = elapsed + MATCH_TICK_SEC
        local cur = F.getLocalChar()
        if not cur or not slua.isValid(cur) then return end

        if not _matchWearDone then
            _matchWearDone = F.matchApplyAllSlots(cur)
        end
        F.matchApplyHat(cur)
        F.matchApplyFaceWear(cur)
        if not _weaponApplied then
            F.matchApplyWeaponSkin(cur)
        end
        if F.isCharacterAirborne(cur) then
            F.applyAirborneSlots(cur, true)
        end

        if (_matchWearDone and _weaponApplied) or elapsed >= MATCH_MAX_SEC then
            if _matchWearDone then
                PERF.wearDoneThisMatch = true
            end
            if _matchTimer and cur.RemoveGameTimer then
                pcall(function() cur:RemoveGameTimer(_matchTimer) end)
            end
            _matchTimer = nil
            PERF.matchActive = false
        end
    end)
end

function F.stopMatchWatcher()
    if _matchTimer then
        pcall(function()
            local char = F.getLocalChar()
            if char and char.RemoveGameTimer then char:RemoveGameTimer(_matchTimer) end
        end)
        _matchTimer = nil
    end
    PERF.matchActive = false
    PERF.wearDoneThisMatch = false
    _matchWearDone = false
    _avatarItemsRegistered = false
    _weaponApplied = false
    _weaponDiagDone = false
    _lastWeaponResID = 0
end

function F.hookAirborneCache()
    if _G.AddOutfitAirborneHooked then return end
    _G.AddOutfitAirborneHooked = true
    pcall(function()
        if not EventSystem or not EventSystem.registEvent then return end
        if EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_ITEM_LIST then
            EventSystem:registEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST, function()
                F.syncAirborneCacheFromLobby()
            end)
        end
    end)
end

function F.hookPutOnRsp()
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        local o = wl.on_puton_rsp
        wl.on_puton_rsp = function(self, res, item, olditem, index, extra)
            o(self, res, item, olditem, index, extra)
            if not item or not item.instid then return end
            local resID = tonumber(item.res_id)
            local insID = tonumber(item.instid)
            if not resID or not insID then return end
            local c = F.cfg(resID)
            local st = F.subType(c)
            if st == OUTFIT_SUB then
                F.saveEquip(resID, insID)
            elseif st == HAT_SUB or FACE_SUBS[st] or BODY_SUBS[st] or HELMET_SUBS[st]
                or st == PARACHUTE_SUB or F.isGlideRes(resID) or st == GLOVES_SUB then
                F.saveEquip(resID, insID)
            elseif F.isParachuteRes(resID) or F.isGlideRes(resID) then
                F.saveEquip(resID, insID)
            elseif HEAD_SUBS[st] then
                F.saveEquip(resID, insID)
            elseif GUN_SUB[st] then
                local wid = F.weaponIdFromSkin(resID)
                if wid then F.cacheWeaponSkinFromIns(wid, insID) end
            elseif st == MELEE_ID then
                F.cacheWeaponSkinFromIns(MELEE_ID, insID)
            elseif F.isInjectedIns(insID) then
                F.saveEquip(resID, insID)
            end
        end
    end)
end

function F.hookLobbyWeaponCache()
    if _G.AddOutfitLobbyWeaponCacheHooked then return end
    _G.AddOutfitLobbyWeaponCacheHooked = true
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        local oRsp = Arm.install_weapon_skin_rsp
        Arm.install_weapon_skin_rsp = function(client_data, errorCode, weapon_id, instanceID)
            oRsp(client_data, errorCode, weapon_id, instanceID)
            if (errorCode == 0 or errorCode == NET_OK) and F.isWeaponSkinIns(instanceID) then
                F.cacheWeaponSkinFromIns(weapon_id, instanceID)
            end
        end
        local oH = Arm.HandleWeaponSkinChange
        Arm.HandleWeaponSkinChange = function(client_data, weapon_id, instanceID)
            oH(client_data, weapon_id, instanceID)
            if F.isWeaponSkinIns(instanceID) then
                F.cacheWeaponSkinFromIns(weapon_id, instanceID)
            end
        end
    end)
    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        local o = wgl.on_put_on_weapon_wear_rsp
        wgl.on_put_on_weapon_wear_rsp = function(self, client_data, res, weapon_id, new_skin_id, extra_weapon_list)
            o(self, client_data, res, weapon_id, new_skin_id, extra_weapon_list)
            if res == 0 or res == NET_OK then
                F.cacheWeaponSkinFromIns(weapon_id, new_skin_id)
            end
        end
    end)
    pcall(function()
        if not EventSystem or not EventSystem.registEvent then return end
        if EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
            EventSystem:registEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, function(_, _, resOrFlag, weapon_id)
                weapon_id = tonumber(weapon_id)
                if weapon_id and weapon_id > 0 then
                    pcall(function()
                        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
                        local insID = tonumber(wgl:GetSkinIdByWeaponID(weapon_id)) or 0
                        if insID > 0 then F.cacheWeaponSkinFromIns(weapon_id, insID) end
                    end)
                elseif tonumber(resOrFlag) and tonumber(resOrFlag) > 100000 then
                    pcall(function()
                        local wid = F.weaponIdFromSkin(resOrFlag)
                        if wid then
                            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                            local ins = wd.GetWardrobeInsIdByResId and wd:GetWardrobeInsIdByResId(resOrFlag)
                            if ins and ins > 0 then F.cacheWeaponSkinFromIns(wid, ins) end
                        end
                    end)
                end
            end)
        end
    end)
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        local oHeadReq = WRH.send_depot_set_head_show_req
        WRH.send_depot_set_head_show_req = function(insID)
            insID = tonumber(insID) or 0
            if insID > 0 and F.isInjectedIns(insID) then
                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                local d = wd:GetHallDepotItemDataByInsID(insID)
                if d and d.resID then
                    F.saveEquip(tonumber(d.resID), insID)
                end
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                fbd:SetHeadShow(insID)
                WRH.on_depot_set_head_show_rsp(NET_OK, insID)
                return
            end
            return oHeadReq(insID)
        end
        local oHead = WRH.on_depot_set_head_show_rsp
        WRH.on_depot_set_head_show_rsp = function(err_code, id)
            oHead(err_code, id)
            if err_code ~= 0 and err_code ~= NET_OK then return end
            id = tonumber(id) or 0
            if id <= 0 then return end
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(id)
            if d and d.resID then
                local st = tonumber(d.itemSubType or F.subType(F.cfg(d.resID)))
                if st == HAT_SUB or HELMET_SUBS[st] then
                    F.saveEquip(tonumber(d.resID), id)
                end
            end
        end
    end)
end

function F.hookWardrobePutOnReq()
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        if wl._AddOutfitPutOnReqHooked then return end
        wl._AddOutfitPutOnReqHooked = true
        local oReq = wl.wardrobe_puton_req
        wl.wardrobe_puton_req = function(self, insID, extra)
            insID = tonumber(insID)
            F.ensureDepotItemValid(insID)
            if F.tryLocalWearByIns(insID) then return end
            return oReq(self, insID, extra)
        end
        if not wl._AddOutfitPutOnDataHooked then
            wl._AddOutfitPutOnDataHooked = true
            local oData = wl.wardrobe_puton_data_req
            wl.wardrobe_puton_data_req = function(self, itemData)
                if itemData then
                    local insID = tonumber(itemData.ins_id or itemData.insID)
                    local resID = tonumber(itemData.res_id or itemData.resID)
                    F.clearItemExpire(itemData, insID, resID)
                    F.ensureDepotItemValid(insID, resID)
                end
                return oData(self, itemData)
            end
        end
    end)
end

local _bootstrapNotified = false

function F.bootstrapMatch(char)
    char = char or F.getLocalChar()
    if not char or not slua.isValid(char) then return false end
    if PERF.matchActive then return true end
    local now = os.clock()
    if (now - PERF.lastBootstrapAt) < BOOTSTRAP_COOLDOWN then return false end
    PERF.lastBootstrapAt = now
    F.syncWeaponCacheFromLobby(true)
    F.applyPersistSlotsToCache()
    F.cleanArmoryPollution()
    F.syncGlobalWearSkins()
    F.syncAirborneToDataMgr()
    pcall(function() F.applyAirborneSlots(char, F.isCharacterAirborne(char)) end)
    F.syncVehicleCacheFromDataMgr()
    F.syncVehicleSlotsToDataMgr()
    pcall(function() F.applyVehicleSkinsToPC(F.getPC()) end)
    F.startVehicleSkinTicker()
    pcall(function()
        local v = F.getMatchVehicle()
        if slua.isValid(v) then F.autoApplyVehicleSkinOnEnter(v) end
    end)
    _weaponApplied = false
    _weaponDiagDone = false
    _matchApplied = false
    if not _bootstrapNotified then
        _bootstrapNotified = true
    end
    F.startMatchWatcher(char)
    return true
end

function F.hookMatchAvatar()
    pcall(function()
        local CAC = require("GameLua.Mod.Library.GamePlay.Avatar.Component.CharacterAvatarComponent")
        local o = CAC.OnAvatarAllMeshLoadedLua
        CAC.OnAvatarAllMeshLoadedLua = function(self)
            o(self)
            pcall(function()
                if self.IsLobbyActor and self:IsLobbyActor() then return end
                local isSelf = self.IsSelf and self:IsSelf()
                if not isSelf then return end
                if PERF.wearDoneThisMatch or PERF.matchActive then return end
                local char = F.getLocalChar()
                if char and char.AddGameTimer then
                    char:AddGameTimer(0.5, false, function() F.bootstrapMatch(char) end)
                end
            end)
        end
    end)
    pcall(function()
        local WAC = require("GameLua.Mod.Library.GamePlay.Avatar.Component.WeaponAvatarComponent")
        local oLoad = WAC.OnWeaponAvatarLoadedLua
        WAC.OnWeaponAvatarLoadedLua = function(self, slotID, definedID)
            oLoad(self, slotID, definedID)
            pcall(function()
                if self.IsLobbyActor and self:IsLobbyActor() then return end
                local isSelf = self.IsSelf and self:IsSelf()
                if not isSelf then return end
                local char = F.getLocalChar()
                if not char then return end
                _weaponApplied = false
                if not PERF.matchActive then F.bootstrapMatch(char)
                elseif char.AddGameTimer then
                    char:AddGameTimer(0.25, false, function()
                        local c = F.getLocalChar()
                        if c then F.matchApplyWeaponSkin(c) end
                    end)
                end
            end)
        end
    end)
end

function F.hookVehicleInfoInit()
    pcall(function()
        if DataMgr._AddOutfitVehInfoHooked then return end
        DataMgr._AddOutfitVehInfoHooked = true
        local orig = DataMgr.InitVehicleInfo
        DataMgr.InitVehicleInfo = function(vehicle_info, vst_skin)
            vehicle_info = F.mergeInjectedIntoVehicleSlotList(vehicle_info)
            orig(vehicle_info, vst_skin)
            F.later(0.15, function()
                F.reapplyVehicleSlotsFromConfig()
                F.reapplyHallThemeFromConfig()
                LOBBY.reapplyDone = false
                LOBBY.reapplyScheduled = false
                F.scheduleLobbyReapplyOnce()
            end)
        end
    end)
end

function F.hookVehicleSkinDataInit()
    pcall(function()
        if DataMgr._AddOutfitVehSkinDataHooked then return end
        DataMgr._AddOutfitVehSkinDataHooked = true
        local origInit = DataMgr.InitVehicleSkinData
        DataMgr.InitVehicleSkinData = function(data)
            data = F.mergeInjectedVehicleSkinTable(data)
            origInit(data)
            F.later(0.1, function()
                F.equipVehicleTypesFromConfig(PERSIST.configVehicleSlots)
            end)
        end
        local origUpd = DataMgr.UpdateVehicleSkin
        DataMgr.UpdateVehicleSkin = function(itemSubType, putOnId)
            origUpd(itemSubType, putOnId)
            if not _G.AddOutfitApplyingConfig and F.isInjectedIns(putOnId) then
                F.setLobbyVehicleManual(itemSubType, R.insToRes[putOnId], putOnId)
            end
        end
    end)
    pcall(function()
        local HallThemeUtils = require("client.logic.lobby.hall_theme_utils")
        if HallThemeUtils._AddOutfitLobbyVehHooked then return end
        HallThemeUtils._AddOutfitLobbyVehHooked = true
        local orig = HallThemeUtils.ProcPutOnVehicle
        HallThemeUtils.ProcPutOnVehicle = function(putOnItem, bShowVehicle)
            orig(putOnItem, bShowVehicle)
            if not _G.AddOutfitApplyingConfig and putOnItem then
                local ins = tonumber(putOnItem.instid)
                local res = tonumber(putOnItem.res_id)
                if ins and F.isInjectedIns(ins) then
                    F.setLobbyVehicleManual(F.vehicleSubType(res or R.insToRes[ins]), res or R.insToRes[ins], ins)
                end
            end
        end
    end)
end

function F.hookHallTheme()
    pcall(function()
        local HT = require("client.logic.lobby.hall_theme_utils")
        if HT._AddOutfitHallThemeHooked then return end
        HT._AddOutfitHallThemeHooked = true
        local orig = HT.ProcPutOnHallTheme
        HT.ProcPutOnHallTheme = function(putOnItem, putOffItem)
            orig(putOnItem, putOffItem)
            if not _G.AddOutfitApplyingTheme and putOnItem then
                local ins = tonumber(putOnItem.instid)
                local res = tonumber(putOnItem.res_id)
                if ins and F.isInjectedIns(ins) then
                    F.setHallThemeManual(res or R.insToRes[ins], ins)
                end
            end
        end
    end)
end

function F.hookGarageTheme()
    pcall(function()
        local TeamupHandler = require("client.network.Protocol.TeamupHandler")
        local ModuleManager = require("client.module_framework.ModuleManager")
        if not TeamupHandler then return end
        
        local o_send_update = TeamupHandler.send_update_car_main_page_slot_req
        if o_send_update and not TeamupHandler._AddOutfitGarageUpdateHooked then
            TeamupHandler._AddOutfitGarageUpdateHooked = true
            TeamupHandler.send_update_car_main_page_slot_req = function(slot_id, item_inst_id)
                
                if F.isInRealMatch() then 
                    return o_send_update(slot_id, item_inst_id) 
                end

                if F.isInjectedIns(tonumber(item_inst_id)) then
                    local resID = R.insToRes[tonumber(item_inst_id)]
                    local GarageThemeSystem = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.GarageThemeSystem)
                    if not GarageThemeSystem then return end

                    GarageThemeSystem.GarageVehicleInfo[slot_id] = {
                        inst_id = tonumber(item_inst_id),
                        res_id = resID
                    }

                    for k, v in pairs(GarageThemeSystem.GarageVehicleInfo) do
                        if k ~= slot_id and v.inst_id == tonumber(item_inst_id) then
                            GarageThemeSystem.GarageVehicleInfo[k] = nil
                        end
                    end

                    pcall(function() GarageThemeSystem:ReportSpecialEffectTlog() end)
                    if EventSystem and EVENTTYPE_LOBBY_THEME and EVENTID_GARAGE_VEHICLE_DATA_CHANGE then
                        EventSystem:postEvent(EVENTTYPE_LOBBY_THEME, EVENTID_GARAGE_VEHICLE_DATA_CHANGE)
                    end

                    local itemCfg = F.cfg(resID)
                    if itemCfg and DataMgr and DataMgr.UpdateVehicleSkin then
                        local subType = itemCfg.ItemSubType or itemCfg.itemSubType
                        DataMgr.UpdateVehicleSkin(subType, tonumber(item_inst_id))
                    end
                    if DataMgr then DataMgr.vst_skin = tonumber(item_inst_id) end
                    
                    pcall(function()
                        local HallThemeUtils = require("client.logic.lobby.hall_theme_utils")
                        if HallThemeUtils then
                            if HallThemeUtils.UpdateThemeVehicleShow then HallThemeUtils.UpdateThemeVehicleShow() end
                            if HallThemeUtils.ShowThemeVehicle then HallThemeUtils.ShowThemeVehicle() end
                        end
                    end)
                    return
                end
                return o_send_update(slot_id, item_inst_id)
            end
        end

        local o_send_batch = TeamupHandler.send_batch_put_on_sportscar_req
        if o_send_batch and not TeamupHandler._AddOutfitGarageBatchHooked then
            TeamupHandler._AddOutfitGarageBatchHooked = true
            TeamupHandler.send_batch_put_on_sportscar_req = function(instid_list)
                
                if F.isInRealMatch() then 
                    return o_send_batch(instid_list) 
                end

                if type(instid_list) ~= "table" then
                    return o_send_batch(instid_list)
                end

                local hasInjected = false
                for slot_id, item_inst_id in pairs(instid_list) do
                    if F.isInjectedIns(tonumber(item_inst_id)) then
                        hasInjected = true
                        break
                    end
                end

                if not hasInjected then
                    return o_send_batch(instid_list)
                end

                local GarageThemeSystem = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.GarageThemeSystem)
                if not GarageThemeSystem then return end

                for slot_id, item_inst_id in pairs(instid_list) do
                    local insID = tonumber(item_inst_id)
                    if F.isInjectedIns(insID) then
                        local resID = R.insToRes[insID]
                        if insID ~= 0 and resID then
                            GarageThemeSystem.GarageVehicleInfo[slot_id] = {
                                inst_id = insID,
                                res_id = resID
                            }
                        else
                            GarageThemeSystem.GarageVehicleInfo[slot_id] = nil
                        end
                    end
                end

                pcall(function() GarageThemeSystem:ReportSpecialEffectTlog() end)
                if EventSystem and EVENTTYPE_LOBBY_THEME and EVENTID_GARAGE_VEHICLE_DATA_CHANGE then
                    EventSystem:postEvent(EVENTTYPE_LOBBY_THEME, EVENTID_GARAGE_VEHICLE_DATA_CHANGE)
                end

                local nonInjected = {}
                for slot_id, item_inst_id in pairs(instid_list) do
                    if not F.isInjectedIns(tonumber(item_inst_id)) then
                        nonInjected[slot_id] = item_inst_id
                    end
                end
                if next(nonInjected) then
                    return o_send_batch(nonInjected)
                end
            end
        end
    end)
end

function F.hookEnterGame()
    if _G.AddOutfitEnterGameHooked then return end
    _G.AddOutfitEnterGameHooked = true
    pcall(function()
        if EventSystem and EventSystem.registEvent and EVENTTYPE_LOBBY and EVENTID_ENTER_GAME_BEGIN then
            EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_ENTER_GAME_BEGIN, function()
                F.perfInvalidateLobby()
                F.syncWeaponCacheFromLobby(true)
                F.reapplyVehicleSlotsFromConfig(true)
                F.reapplyHallThemeFromConfig(true)
                pcall(F.applyVehicleSkinsToPC)
                F.stopMatchWatcher()
                _bootstrapNotified = false
            end)
        end
    end)
end

function F.afterInjectApply(firstTime)
    F.mergeInjectedArmorySkins()
    F.cleanArmoryPollution()
    if firstTime then
        F.refreshWardrobeOnce()
        F.persistApplyLoaded()
        F.hookGarageTheme()
        F.syncLobbyVehicleResFromIns()
        F.reapplyVehicleSlotsFromConfig(true)
        F.reapplyHallThemeFromConfig(true)
        F.reapplyWeaponsFromConfig()
        F.scheduleLobbyReapplyOnce()
    else
        F.reapplyWeaponsFromConfig()
    end
end

function F.start()
    F.restorePufferHooks()
    F.buildSkinMappings()
    if not _G.AddOutfitPersistLoaded then
        _G.AddOutfitPersistLoaded = true
        F.persistLoadFromDisk()
    end
    F.applyPersistSlotsToCache()
    F.syncGlobalWearSkins()
    
    _G.apply_vehicle_skin = F.matchApplyVehicleSkin
    _G.skinIdMappings = _G.AddOutfitSkinIdMappings
    
    F.hookDepotInit()
    F.hookWardrobeData()
    F.hookPageFilter()
    F.hookArmory()
    F.hookGunSkinId()
    F.hookPutOn()
    F.hookPutDown()
    F.hookVehicles()
    F.hookAirborneClick()
    F.hookVehicleInfoInit()
    F.hookVehicleSkinDataInit()
    F.hookHallTheme()
    F.hookWeaponWear()
    F.hookNotice()
    F.hookAvatarValid()
    F.hookPutOnRsp()
    F.hookAirborneCache()
    F.hookLobbyWeaponCache()
    F.hookLobbySwipePersistence()
    F.hookWardrobePutOnReq()
    F.hookWardrobeWearClicks()
    F.hookMatchAvatar()
    F.hookEquipmentRectify()
    F.hookWeaponSpawn()
    F.hookEnterGame()

-- ==============================================================================
-- KILL MESSENGER, DEADBOX, KILL COUNTER LOGIC
-- ==============================================================================
local function decodeExpand(expandContent)
    local ok, exp = pcall(function() return slua.LuaArchiverDecode(LuaStateWrapper, expandContent) or {} end)
    return ok and exp or {}
end

local function encodeExpand(exp)
    return slua.LuaArchiverEncode(LuaStateWrapper, exp or {})
end

local _cachedMyName = nil
local function isMyKill(data)
    if not data then return false end
    if data.bIamCauser then return true end
    if not _cachedMyName then
        local hud = slua_GameFrontendHUD
        if hud then
            local pc = hud:GetPlayerController()
            if slua.isValid(pc) then
                local ch = pc:GetPlayerCharacterSafety()
                if slua.isValid(ch) then _cachedMyName = ch:GetPlayerNameSafety() end
            end
        end
    end
    if not _cachedMyName or _cachedMyName == "" then return false end
    return data.Causer == _cachedMyName or data.CauserRealPlayerName == _cachedMyName or data.CauserPlayerName == _cachedMyName
end

local function getCurrentWeaponSkinID()
    local hud = slua_GameFrontendHUD
    if not hud then return 0 end
    local pc = hud:GetPlayerController()
    if not slua.isValid(pc) then return 0 end
    local ch = pc:GetPlayerCharacterSafety()
    if not slua.isValid(ch) then return 0 end
    
    local currWeapon = ch:GetCurrentWeapon()
    if slua.isValid(currWeapon) and currWeapon.synData then
        local currentSkinID = 0
        pcall(function()
            local synDataRef = slua.IndexReference(currWeapon.synData:Get(7), "defineID")
            local skinID = synDataRef and slua.isValid(synDataRef) and synDataRef.TypeSpecificID or 0
            
            if skinID > 1000000 then 
                currentSkinID = skinID
            end
        end)
        return currentSkinID
    end
    return 0
end

local _downloadedAssetsCache = {}
local function downloadTeamAssets(skinID)
    if not skinID or skinID == 0 or skinID == 69 then return end
    if _downloadedAssetsCache[skinID] then return end
    _downloadedAssetsCache[skinID] = true

    pcall(function()
        local PufferManager = require("client.slua.logic.download.puffer.puffer_manager")
        local PufferConst = require("client.slua.logic.download.puffer_const")
        PufferManager.Download(PufferConst.ENUM_DownloadType.ODPAK, {skinID})
        
        local cfg = CDataTable.GetTableData("TeamKillBroadcast", skinID)
        if cfg then
            if cfg.EffectPath and cfg.EffectPath ~= "" then
                PufferManager.Download(PufferConst.ENUM_DownloadType.ODPAK, {cfg.EffectPath})
            end
            if cfg.BgPath and cfg.BgPath ~= "" then
                PufferManager.Download(PufferConst.ENUM_DownloadType.ODPAK, {cfg.BgPath})
            end
        end
    end)
end

local function patchTeamKill(messageData)
    if not _G.LexusConfig.KillMessage then return messageData end
    if not messageData or not isMyKill(messageData) then return messageData end
    local currentSkinID = getCurrentWeaponSkinID()
    if not currentSkinID or currentSkinID == 0 or currentSkinID == 69 then return messageData end
    local broadcastCfg = CDataTable.GetTableData("TeamKillBroadcast", currentSkinID)
    if not broadcastCfg or (not broadcastCfg.BgPath and not broadcastCfg.EffectPath) then return messageData end
    pcall(function()
        local exp = decodeExpand(messageData.ExpandDataContent)
        exp.CauserWeaponAvatarID = currentSkinID
        messageData.ExpandDataContent = encodeExpand(exp)
        messageData.bShowBottomBothSidesKillInfo = true
        messageData.bIamCauser = true
        downloadTeamAssets(currentSkinID)
    end)
    return messageData
end

local function installTeamBroadcastHooks()
    local function wrapCopy(mod, tag)
        if not mod then return end
        local impl2 = mod.__inner_impl or mod
        if not impl2 or not impl2.CopyKillOrPutDownMessageDataUserDataToLuaTable then return end
        local key = "__teamKillCopy_" .. tag
        if not impl2[key] then impl2[key] = impl2.CopyKillOrPutDownMessageDataUserDataToLuaTable end
        local O_Copy = impl2[key]
        impl2.CopyKillOrPutDownMessageDataUserDataToLuaTable = function(self, messageData)
            local copied = O_Copy(self, messageData)
            
            if not _G.LexusConfig.KillMessage then return copied end
            
            local ok2, result = pcall(function() return patchTeamKill(copied) end)
            if ok2 then return result end
            return copied
        end
    end
    pcall(function() wrapCopy(require("GameLua.Mod.BaseMod.Client.BattleKillBroadcast.BattleKillBroadcastSubSystem"), "base") end)
    pcall(function() wrapCopy(require("GameLua.Mod.SingleTraining.Client.BattleKillBroadcast.BattleKillBroadcastSubSystem"), "training") end)
end

_G.killCountInfo = {
    [101001] = 0000, [101004] = 0000, [101003] = 0000, [103001] = 0000,
    [102001] = 0000, [105001] = 0000, [102002] = 0000, [103002] = 0000
}

function _G.saveKillCountToFile() end
function _G.loadKillCountFromFile() end

function _G.addKill(weaponID, count)
    if not weaponID or not count then return end
    _G.killCountInfo[weaponID] = (_G.killCountInfo[weaponID] or 0) + count
    _G.saveKillCountToFile()
end

function _G.getKills(weaponID) return weaponID and _G.killCountInfo[weaponID] or 0 end

pcall(function()
    local SKillInfo = require("GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo")
    local SKillInfoModuleManager = require("client.module_framework.ModuleManager")
    local UEnums = _ENV.UEnums
    local ECharacterHealthStatus = import("ECharacterHealthStatus")
    
    if SKillInfo and SKillInfo.__inner_impl and SKillInfo.__inner_impl.FileItem then
        local O_FileItem = SKillInfo.__inner_impl.FileItem
        SKillInfo.__inner_impl.FileItem = function(self, DamageRecordData)
            if not self or not DamageRecordData then return end

            if not _G.LexusConfig.SkinDeadBox and not _G.LexusConfig.KillCountUI and not _G.LexusConfig.KillMessage then
                return O_FileItem(self, DamageRecordData)
            end

            local LogicKillCounter = SKillInfoModuleManager.GetModule(SKillInfoModuleManager.CommonModuleConfig.LogicKillCounter)
            if not LogicKillCounter then return O_FileItem(self, DamageRecordData) end

            local uCharacter = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController() and slua_GameFrontendHUD:GetPlayerController():GetPlayerCharacterSafety()
            if not uCharacter or not slua.isValid(uCharacter) then return O_FileItem(self, DamageRecordData) end

            local SelfName = uCharacter:GetPlayerNameSafety()
            local bIsCauser = DamageRecordData.Causer == SelfName

            if bIsCauser then
                if DamageRecordData.DamageType == UEnums.DamageType.VehicleDamage then
                    if _G.LexusConfig.SkinDeadBox or _G.LexusConfig.KillMessage then 
                        local carSkinID = _G.CurrentEquipVehicleID or 0
                        if carSkinID ~= 0 then
                            local ExpandData = slua.LuaArchiverDecode(LuaStateWrapper, DamageRecordData.ExpandDataContent) or {}
                            ExpandData.CauserVehicleSkinID = carSkinID
                            if _G.LexusConfig.KillMessage then
                                self:ChangeInfoBgByWeaponAvatarIDLua(carSkinID)
                                DamageRecordData.CauserWeaponAvatarID = carSkinID
                                DamageRecordData.CauserClothAvatarID = _G.SuitSkin or 0
                            end
                            DamageRecordData.ExpandDataContent = slua.LuaArchiverEncode(LuaStateWrapper, ExpandData)
                        end
                    end
                elseif DamageRecordData.CauserWeaponAvatarID ~= 69 and DamageRecordData.CauserClothAvatarID ~= 69 then
                    local currWeapon = uCharacter:GetCurrentWeapon()
                    if currWeapon and slua.isValid(currWeapon) then
                        local defineID = currWeapon:GetItemDefineID()
                        local DefineID = defineID and slua.isValid(defineID) and defineID.TypeSpecificID or 0
                        if DefineID ~= 0 then
                            local ExpandData = slua.LuaArchiverDecode(LuaStateWrapper, DamageRecordData.ExpandDataContent) or {}
                            local hasChanged = false

                            local SupportKillCounter = LogicKillCounter:GetBaseKillCounterIdByWeaponId(DefineID)
                            if SupportKillCounter and DamageRecordData.ResultHealthStatus == ECharacterHealthStatus.FinishedLastBreath then
                                local synDataRef = slua.IndexReference(currWeapon.synData:Get(7), "defineID")
                                local SkinID = synDataRef and slua.isValid(synDataRef) and synDataRef.TypeSpecificID or 0
                                
                                if SkinID > 1000000 then 
                                    if _G.LexusConfig.KillCountUI then 
                                        ExpandData.KillCounterItemId = DefineID
                                        ExpandData.KillCounterNum = (ExpandData.KillCounterNum or 0) + 1
                                        _G.addKill(DefineID, 1)
                                        hasChanged = true
                                    end
                                    if _G.LexusConfig.SkinDeadBox then 
                                        _G.NeedCheckDeadBoxTimer = 5 
                                        hasChanged = true
                                    end
                                end
                            end

                            if hasChanged or _G.LexusConfig.KillMessage then
                                _G.UpdateMyKillCounter = true
                                if _G.LexusConfig.KillMessage then
                                    local synData = currWeapon.synData
                                    if synData and slua.isValid(synData) then
                                        local weaponDefineID = slua.IndexReference(synData:Get(7), "defineID")
                                        if weaponDefineID and slua.isValid(weaponDefineID) then
                                            DamageRecordData.CauserWeaponAvatarID = weaponDefineID.TypeSpecificID
                                        end
                                    end
                                    DamageRecordData.CauserClothAvatarID = _G.SuitSkin or 0
                                end
                                DamageRecordData.ExpandDataContent = slua.LuaArchiverEncode(LuaStateWrapper, ExpandData)
                            end
                        end
                    end
                end
            end
            O_FileItem(self, DamageRecordData)
        end
    end
end)

pcall(function()
    local MyMainKillCounter = require("GameLua.Mod.BaseMod.Client.KillCounter.MainKillCounter")
    local MyKillCountSubSystem = require("GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem")
    local MyMainWeaponInfoItemUI = require("GameLua.Mod.BaseMod.Client.Backpack.MainWeaponInfoItemUI")
    local MyMainWeaponKillCounter = require("GameLua.Mod.BaseMod.Client.KillCounter.MainWeaponKillCounter")
    local SlotBase = require("GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2")
    local SubsystemMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
    local UIManager = require("client.slua_ui_framework.manager")
    local ModuleManager = require("client.module_framework.ModuleManager")

    if MyKillCountSubSystem and MyKillCountSubSystem.__inner_impl then
        _G.OurkillCountSystem = MyKillCountSubSystem.__inner_impl
        
        local o_OnRefreshUI = MyMainKillCounter.__inner_impl.OnRefreshUI
        MyMainKillCounter.__inner_impl.OnRefreshUI = function(self, _, _, UID)
            if not _G.LexusConfig.KillCountUI then return end
            local LogicKillCounter = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
            local curEquipedKillCounter = LogicKillCounter:GetEquipedKillCounterId(6114302174, self.WeaponID)
            local uCharacter = slua_GameFrontendHUD:GetPlayerController():GetPlayerCharacterSafety()
            local currweapon = uCharacter:GetCurrentWeapon()
            if currweapon ~= nil then
                local defineID = currweapon:GetItemDefineID()
                local DefineID = defineID and slua.isValid(defineID) and defineID.TypeSpecificID or 0
                local synDataRef = slua.IndexReference(currweapon.synData:Get(7), "defineID")
                local SkinID = synDataRef and slua.isValid(synDataRef) and synDataRef.TypeSpecificID or 0
                self.KillCounterItem:SetKillCounterItemShowWithNum(curEquipedKillCounter, _G.getKills(DefineID), SkinID)
            end
        end

        MyKillCountSubSystem.__inner_impl.CheckSupportKCUI = function(self) return _G.LexusConfig.KillCountUI end

        local o_UpdateMainKillCounterUI = MyKillCountSubSystem.__inner_impl.UpdateMainKillCounterUI
        MyKillCountSubSystem.__inner_impl.UpdateMainKillCounterUI = function(self, bShow, WeaponID, AvatarID)
            if not _G.LexusConfig.KillCountUI then
                o_UpdateMainKillCounterUI(self, false, WeaponID, AvatarID)
                local MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
                if MainKillCounter then UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter) end
                return
            end

            o_UpdateMainKillCounterUI(self, bShow, WeaponID, AvatarID)
            local MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
            local uCharacter = slua_GameFrontendHUD:GetPlayerController():GetPlayerCharacterSafety()
            local currweapon = uCharacter:GetCurrentWeapon()
         
            if not bShow and MainKillCounter then
                UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter)
            elseif bShow and currweapon ~= nil then
                local DefineID = currweapon:GetItemDefineID().TypeSpecificID
                local currentEquipAvatrid = slua.IndexReference(currweapon.synData:Get(7), "defineID").TypeSpecificID
                local LogicKillCounter = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
                local SupportKillCounter = LogicKillCounter:GetBaseKillCounterIdByWeaponId(DefineID)
                
                local curEquipedKillCounter = LogicKillCounter:GetEquipedKillCounterId(6114302174, currentEquipAvatrid)
                
                local isModdedSkin = (currentEquipAvatrid and currentEquipAvatrid > 1000000)
                
                if (SupportKillCounter == nil or not isModdedSkin) then
                    if MainKillCounter then
                        UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter)
                    end
                else
                    if not MainKillCounter then
                        UIManager.ShowUI(UIManager.UI_Config_InGame.MainKillCounter, DefineID, currentEquipAvatrid)
                        MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
                        if MainKillCounter then
                            MainKillCounter:SetKillCounterItemShowWithNum(curEquipedKillCounter, _G.getKills(DefineID), currentEquipAvatrid)
                        end
                    else
                        MainKillCounter:UpdateWeaponID(DefineID, currentEquipAvatrid)
                        MainKillCounter:SetKillCounterItemShowWithNum(curEquipedKillCounter, _G.getKills(DefineID), currentEquipAvatrid)
                    end
                end
            end
        end

        local o_CheckNeedMainKillCounterUI = MyKillCountSubSystem.__inner_impl.CheckNeedMainKillCounterUI
        MyKillCountSubSystem.__inner_impl.CheckNeedMainKillCounterUI = function(self, Weapon, PlayerID)
            if not _G.LexusConfig.KillCountUI then return end
            local uCharacter = slua_GameFrontendHUD:GetPlayerController():GetPlayerCharacterSafety()
            local currweapon = uCharacter:GetCurrentWeapon()
            if currweapon ~= nil then
                local defineID = currweapon:GetItemDefineID()
                local DefineID = defineID and slua.isValid(defineID) and defineID.TypeSpecificID or 0
                local synDataRef = slua.IndexReference(currweapon.synData:Get(7), "defineID")
                local SkinID = synDataRef and slua.isValid(synDataRef) and synDataRef.TypeSpecificID or 0
                self:UpdateMainKillCounterUI(true, DefineID, SkinID)
            end
        end
    end
end)

local _lastKCWeaponID = 0
local _lastKCSkinID = 0

_G.GameAvatarHandlerkillcounter = function()
    local UIManager = require("client.slua_ui_framework.manager")
    
    if not _G.LexusConfig.KillCountUI then
        local MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
        if MainKillCounter then UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter) end
        return 
    end

    local PlayerController = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if not PlayerController or not slua.isValid(PlayerController) then return end
    
    local uCharacter = PlayerController:GetPlayerCharacterSafety()
    if not uCharacter or not slua.isValid(uCharacter) then return end
    
    local currweapon = uCharacter:GetCurrentWeapon()
    if currweapon and slua.isValid(currweapon) then
        local defineIDObj = currweapon:GetItemDefineID()
        local currentWeaponID = (defineIDObj and slua.isValid(defineIDObj)) and defineIDObj.TypeSpecificID or 0
        
        local currentSkinID = 0
        if _G.AddOutfitLastAppliedSkin and _G.AddOutfitLastAppliedSkin[currentWeaponID] then
            currentSkinID = _G.AddOutfitLastAppliedSkin[currentWeaponID]
        end

        if _G.UpdateMyKillCounter or currentWeaponID ~= _lastKCWeaponID or currentSkinID ~= _lastKCSkinID then
            _lastKCWeaponID = currentWeaponID
            _lastKCSkinID = currentSkinID
            _G.UpdateMyKillCounter = false
            
            if _G.OurkillCountSystem then
                _G.OurkillCountSystem:UpdateMainKillCounterUI(true, currentWeaponID, currentSkinID)
            end
        end
    else
        _lastKCWeaponID = 0
        _lastKCSkinID = 0
        local MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
        if MainKillCounter then UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter) end
    end
end

local function LobbyTickSetup()
    if not _G.CounterUpdated then
        _G.CounterUpdated = true
        _G.loadKillCountFromFile()
    end
end

pcall(function()
    installTeamBroadcastHooks()
    LobbyTickSetup()
    
    local ticker = require("common.time_ticker")
    if ticker and ticker.AddTimerLoop then
        ticker.AddTimerLoop(0, _G.GameAvatarHandlerkillcounter, -1, 0.5)
    end
end)
-- ==============================================================================

    F.startVehicleSkinTicker()
    if not _G.AddOutfitVehInitTimers then
        _G.AddOutfitVehInitTimers = true
        F.later(1.5, function() pcall(F.applyVehicleSkinsToPC) end)
        F.later(4.0, function() pcall(F.applyVehicleSkinsToPC) end)
    end

    pcall(function()
        if F.isInRealMatch() then
            local char = F.getLocalChar()
            if char then
                F.bootstrapMatch(char)
            end
        end
    end)

    local firstLobby = not _G.AddOutfitLobbyInitDone
    if F.injectAll() then
        if firstLobby then _G.AddOutfitLobbyInitDone = true end
        F.afterInjectApply(firstLobby)
        return
    end
    local tries = 0
    local function retry()
        tries = tries + 1
        if F.injectAll() then
            local ft = not _G.AddOutfitLobbyInitDone
            if ft then _G.AddOutfitLobbyInitDone = true end
            F.afterInjectApply(ft)
            return
        end
        if tries < INJECT_RETRY_MAX then F.later(INJECT_RETRY_SEC, retry) end
    end
    F.later(INJECT_RETRY_SEC, retry)
end

_G.AddOutfit = F
F.start()

_G.AddOutfitLobbyRestored = false

local function AutoRestoreLobbySkin()
    if _G.AddOutfitLobbyRestored then return end
    
    if _G.AddOutfit and _G.AddOutfit.isInRealMatch() then return end
    
    pcall(function()
        if GameStatus and GameStatus.IsInLobbyOrMainCity and GameStatus.IsInLobbyOrMainCity() then
            if DataMgr and DataMgr.roleData and DataMgr.roleData.uid then
                local LMC = require("client.slua.logic.lobby.Main.Lobby_Main_Control")
                if LMC and LMC.GetCurPage then
                    if _G.AddOutfit and _G.AddOutfit.reapplyLobbyEquipped then
                        _G.AddOutfit.persistLoadFromDisk() 
                        _G.AddOutfit.persistApplyLoaded() 
                        _G.AddOutfit.reapplyLobbyEquipped() 
                        
                        _G.AddOutfitLobbyRestored = true
                    end
                end
            end
        end
    end)
end

pcall(function()
    local ticker = require("common.time_ticker")
    if ticker and ticker.AddTimerLoop then
        ticker.AddTimerLoop(0, AutoRestoreLobbySkin, -1, 1.0)
    end
end)
-- ==============================================================================
-- ================= END CORE ADD-OUTFIT V7.5 ==================================
-- ==============================================================================

-- ==============================================================================
-- ================= EMOTE SYSTEM ==========
-- ==============================================================================
pcall(function()

    -- Emote resource ID check
    local function isEmoteRes(resID)
        resID = tonumber(resID)
        if not resID then return false end
        local c = F.cfg(resID)
        if not c then return false end
        local it = tonumber(c.ItemType or c.itemType or 0)
        return it == 22
    end

    -- ----------------------------------------------------------------
    -- 1. INJECTED EMOTES ONLY (no hardcoded EXTRA_EMOTES list)
    -- ----------------------------------------------------------------
    local _emoteCacheKey, _emoteCacheList = nil, {}

    local function getInjectedEmotes()
        -- KEY = MotionSlotList (so list refreshes when equip changes)
        local list = DataMgr and DataMgr.MotionSlotList or {}
        local key = table.concat(list, ",")
        if key == _emoteCacheKey then return _emoteCacheList end
        _emoteCacheKey = key
        _emoteCacheList = {}

        -- 1a. From currently equipped MotionSlotList (preferred — matches UI)
        for _, insID in ipairs(list) do
            insID = tonumber(insID)
            if insID and insID > 0 and F.isInjectedIns(insID) then
                local resID = R.insToRes[insID]
                if resID and isEmoteRes(resID) then
                    local c = F.cfg(resID)
                    _emoteCacheList[#_emoteCacheList + 1] = {
                        resID = resID,
                        name  = c and (c.ItemName or "") or "",
                        icon  = c and (c.ItemSmallIcon or c.ItemIcon or "") or "",
                    }
                end
            end
        end

        -- 1b. Fallback — all injected emote resources (in case MotionSlotList empty)
        if #_emoteCacheList == 0 then
            for res, ins in pairs(R.resToIns) do
                res = tonumber(res)
                if res and isEmoteRes(res) then
                    local c = F.cfg(res)
                    _emoteCacheList[#_emoteCacheList + 1] = {
                        resID = res,
                        name  = c and (c.ItemName or "") or "",
                        icon  = c and (c.ItemSmallIcon or c.ItemIcon or "") or "",
                        _insID = ins,
                    }
                end
            end
        end
        return _emoteCacheList
    end

    -- ----------------------------------------------------------------
    -- 2. EMOTE SYSTEM HOOKS (from backpack helmet emote fixed.lua)
    -- ----------------------------------------------------------------
    pcall(function()
        local QEU = require("GameLua.Mod.BaseMod.Client.Emote.QuickExpressionUtils")
        if QEU._esp_hooked then return end
        QEU._esp_hooked = true
        local o = QEU.GetShowExpressionList
        QEU.GetShowExpressionList = function()
            local list, weaponEmoteId = o()
            list = list or {}
            local emotes = getInjectedEmotes()
            if #emotes > 0 then
                local have = {}
                for _, e in pairs(list) do
                    if e.DefineID then
                        have[tonumber(e.DefineID.TypeSpecificID) or 0] = true
                    end
                end
                for _, em in ipairs(emotes) do
                    if not have[em.resID] then
                        list[#list + 1] = {
                            DefineID = { TypeSpecificID = em.resID },
                            Name = em.name,
                        }
                    end
                end
            end
            return list, weaponEmoteId
        end
    end)

    pcall(function()
        local QE = require("GameLua.Mod.BaseMod.Client.Emote.QuickExpression")
        if QE._esp_hooked then return end
        QE._esp_hooked = true
        local o = QE.GetEmoteImagePalthMap
        QE.GetEmoteImagePalthMap = function(self, ...)
            o(self, ...)
            for _, em in ipairs(getInjectedEmotes()) do
                if em.icon ~= "" and self.ItemIDToImagePathMap then
                    self.ItemIDToImagePathMap[em.resID] = em.icon
                end
            end
        end
    end)

    pcall(function()
        local le = require("GameLua.Mod.Library.GamePlay.Avatar.Emote.logic_emote")
        if le._esp_hooked then return end
        le._esp_hooked = true
        local oExist = le.IsEmoteExist
        le.IsEmoteExist = function(id)
            if F.isInjectedRes(tonumber(id)) and isEmoteRes(id) then return true end
            return oExist(id)
        end
        local oDL = le.CheckEmoteDownloaded
        if oDL then
            le.CheckEmoteDownloaded = function(id, a, b, c)
                if F.isInjectedRes(tonumber(id)) and isEmoteRes(id) then return true end
                return oDL(id, a, b, c)
            end
        end
    end)

    -- ----------------------------------------------------------------
    -- 3. EQUIP / UNEQUIP — LOCAL HANDLE + SAVE TO JSON
    -- ----------------------------------------------------------------
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        if wl._esp_emote_hooked then return end
        wl._esp_emote_hooked = true

        local oEquip = wl.EquipMotion
        wl.EquipMotion = function(self, instid, dst_slot)
            instid = tonumber(instid)
            if instid and F.isInjectedIns(instid) then
                local insSlot = 0
                for i, v in ipairs(DataMgr.MotionSlotList) do
                    if v == instid then insSlot = i; break end
                end
                if insSlot > 0 then
                    local cur = DataMgr.MotionSlotList[dst_slot]
                    if cur == instid then return end
                    DataMgr.MotionSlotList[insSlot] = cur or 0
                    DataMgr.MotionSlotList[dst_slot] = instid
                else
                    while #DataMgr.MotionSlotList < dst_slot do
                        table.insert(DataMgr.MotionSlotList, 0)
                    end
                    DataMgr.MotionSlotList[dst_slot] = instid
                end
                if EventSystem and EVENTTYPE_MOTION and EVENTID_MOTION_UPDATE_SLOT_LIST then
                    EventSystem:postEvent(EVENTTYPE_MOTION, EVENTID_MOTION_UPDATE_SLOT_LIST)
                end
                -- Save to JSON
                local resID = R.insToRes[instid]
                if resID then F.saveEmoteSlot(resID, dst_slot) end
                return
            end
            return oEquip(self, instid, dst_slot)
        end

        local oUn = wl.unequip_motion_req
        wl.unequip_motion_req = function(self, instid, slot)
            instid = tonumber(instid)
            if instid and F.isInjectedIns(instid) then
                for i, v in ipairs(DataMgr.MotionSlotList) do
                    if v == instid then
                        table.remove(DataMgr.MotionSlotList, i)
                        break
                    end
                end
                if EventSystem and EVENTTYPE_MOTION and EVENTID_MOTION_UPDATE_SLOT_LIST then
                    EventSystem:postEvent(EVENTTYPE_MOTION, EVENTID_MOTION_UPDATE_SLOT_LIST)
                end
                local resID = R.insToRes[instid]
                if resID then F.removeEmoteSlot(resID) end
                return
            end
            return oUn(self, instid, slot)
        end
    end)

    -- ----------------------------------------------------------------
    -- 4. WARDROBE PUT-ON REQUEST — save emote when user picks it
    -- ----------------------------------------------------------------
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        if WRH._esp_emote_puton_hooked then return end
        WRH._esp_emote_puton_hooked = true
        local o = WRH.send_depot_put_on_req
        WRH.send_depot_put_on_req = function(insID, extra)
            insID = tonumber(insID)
            if insID and F.isInjectedIns(insID) then
                local resID = R.insToRes[insID]
                if resID and isEmoteRes(resID) then
                    local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                    local slot = 1
                    local curLen = #(DataMgr.MotionSlotList or {})
                    if curLen > 0 then slot = curLen + 1 end
                    if wl and wl.EquipMotion then
                        wl:EquipMotion(insID, slot)
                    end
                    F.saveEmoteSlot(resID, slot)
                    return
                end
            end
            return o(insID, extra)
        end

        local oPD = WRH.send_depot_put_down_req
        WRH.send_depot_put_down_req = function(insID, extra)
            insID = tonumber(insID)
            if insID and F.isInjectedIns(insID) then
                local resID = R.insToRes[insID]
                if resID and isEmoteRes(resID) then
                    local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                    if wl and wl.unequip_motion_req then
                        wl:unequip_motion_req(insID, 0)
                    end
                    F.removeEmoteSlot(resID)
                    return
                end
            end
            return oPD(insID, extra)
        end
    end)

    -- ----------------------------------------------------------------
    -- 5. ON MATCH START — reapply saved emotes to MotionSlotList
    -- ----------------------------------------------------------------
    function F.reapplyEmotesFromConfig()
        local emotes = PERSIST.configEmotes
        if not emotes or #emotes == 0 then return false end
        DataMgr.MotionSlotList = DataMgr.MotionSlotList or {}
        local applied = 0
        for slot, res in ipairs(emotes) do
            res = tonumber(res)
            if res and res > 0 then
                local ins = R.resToIns[res]
                if ins then
                    DataMgr.MotionSlotList[slot] = ins
                    applied = applied + 1
                end
            end
        end
        if applied > 0 and EventSystem and EVENTTYPE_MOTION and EVENTID_MOTION_UPDATE_SLOT_LIST then
            EventSystem:postEvent(EVENTTYPE_MOTION, EVENTID_MOTION_UPDATE_SLOT_LIST)
        end
        return applied > 0
    end

    print("[ESP-Emote] Emote system loaded (JSON persist)")
end)

-- ============================================================
-- 165 FPS
-- ============================================================

local SettingUtil = require("client.slua.logic.setting.setting_util")
local LegalMsg = require("client.slua.logic.common.logic_common_legal_msg")
local TimeTicker = require("common.time_ticker")
local GraphicSettingDB = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
local GraphicConst = require("client.slua.umg.NewSetting.GraphicsNew.GraphicConst")
local FPS_STRINGS = { "15", "20", "25", "30", "40", "60", "90", "120" }

local GSC_FPS = package.loaded["client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPS"]
    or require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPS")

if GSC_FPS and GSC_FPS.__inner_impl then
    local impl = GSC_FPS.__inner_impl

    -- Constructor
    local origCtor = impl.ctor
    impl.ctor = function(self)
        if origCtor then origCtor(self) end
        self.FPSButtons = {}
        for i = 1, 8 do
            self.FPSButtons[i] = { false, false }
        end
    end

    -- Register events
    local origRegistEvents = impl.RegistEvents
    impl.RegistEvents = function(self)
        if origRegistEvents then origRegistEvents(self) end
        if self.UIRoot and self.UIRoot.Btn_fpslv8 then
            self.UIRoot:AddControlEventByControl("Btn_fpslv8", "OnClicked", self.ClickFPS, self)
        end
        self:AddCommonEvent(EVENTTYPE_SETTING, EVENTID_SETTING_FPS_LIMIT_CONFIRM, self.OnFPSPopConfirm, self)
    end

    impl.GetMaxFPSLevel = function() return 8, 8 end

    impl.CanChangeQualityAndFPSPreCheck = function() return true end

    impl.InitRealSupportFPS = function(self)
        local tbl = {}
        for i = 1, 8 do tbl[i] = { true, true } end
        GraphicSettingDB:UpdateUIData(GraphicSettingDB.RealSupportFPS, tbl, false)
        return tbl
    end

    impl.SetFPSAndQualityEnable = function(self, enable)
        if self.UIRoot and self.UIRoot.Image_Mask then
            self:SetWidgetVisible(self.UIRoot.Image_Mask, false)
        end
    end

    impl.UpdateSelectedFPSState = function(self, level)
        local names = {
            [2]="NodeFps20", [3]="NodeFps25", [4]="NodeFps30",
            [5]="NodeFps40", [6]="NodeFps60", [7]="NodeFps90", [8]="NodeFps120"
        }
        if not names[level] then return end
        for k, v in pairs(names) do
            if self.UIRoot[v] then
                self:WidgetSelfHit(self.UIRoot[v])
                self.UIRoot[v]:SetIsEnabled(true)
                local sw = self.UIRoot["WidgetSwitcher_" .. k]
                if sw then sw:SetActiveWidgetIndex(k == level and 0 or 1) end
            end
        end
    end

    local origUpdateUI = impl.UpdateUI
    impl.UpdateUI = function(self)
        if origUpdateUI then pcall(origUpdateUI, self) end
        self:SelfHitTestInvisible()
        self:InitRealSupportFPS()
        self:SetFPSAndQualityEnable(true)
        local tgt = 8
        if GraphicSettingDB then
            if GraphicSettingDB:GetUIData(GraphicSettingDB.CustomTab) == 2 then
                tgt = GraphicSettingDB:GetUIData(GraphicSettingDB.LobbyFPS) or 8
            else
                tgt = GraphicSettingDB:GetUIData(GraphicSettingDB.SelectedFPS) or 8
            end
        end
        self:UpdateSelectedFPSState(tgt)
    end

    impl.DoClickFPS = function(self, level)
        if not slua.isValid(self.UIRoot) then return end
        if GraphicSettingDB:GetUIData(GraphicSettingDB.CustomTab) == 2 then
            GraphicSettingDB:UpdateUIData(GraphicSettingDB.LobbyFPS, level)
        else
            GraphicSettingDB:UpdateSelectedFPS(level)
        end
        self:UpdateSelectedFPSState(level)
        if self:GetParentUI() then self:GetParentUI():SaveQualityAndFPS(); self:GetParentUI():SetDirty(true) end
    end
    impl.Change120FPSConfirm = function(self, cb) if cb then cb() end end
    impl.ClickExpandFPSConfirm = function(self, cb) if cb then cb() end end
end


local GSC_FPSFT = package.loaded["client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPSFT"]
    or require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPSFT")

if GSC_FPSFT and GSC_FPSFT.__inner_impl then
    local ft = GSC_FPSFT.__inner_impl
    local MN, MX, ST = 90, 165, 5

    local function clamp(v, l, h)
        if v < l then return l elseif v > h then return h else return v end
    end

    ft.ShowOrHide = function(s) s:SelfHitTestInvisible(); if s.InitFPSFTSwitch then s:InitFPSFTSwitch() end end

    ft.InitFPSFTSwitch = function(s)
        local on = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch)
        if s.UIRoot.Setting_Switch then s.UIRoot.Setting_Switch:SetSwitcherEnable2(on, true) end
        if s.UIRoot.CanvasPanel_8 then s:SetWidgetVisible(s.UIRoot.CanvasPanel_8, on) end
        if s.UIRoot.WidgetSwitcher_0 then s.UIRoot.WidgetSwitcher_0:SetActiveWidgetIndex(2) end
        if s.InitFPSFTValue165 then s:InitFPSFTValue165() end
    end

    ft.InitFPSFTValue165 = function(s)
        local r = s.UIRoot
        local on = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch)
        local v = (on and GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneNum) or 165)
        r.Slider_screen3:SetLocked(not on)
        r.ProgressBar_screen3:SetFillColorAndOpacity(on and FLinearColor(1,1,1,1) or FLinearColor(1,0.625,0.6,1))
        r.Veihclescreen3:SetText(LocUtil.LocalizeResFormat(10567, v))
        local n = (v - MN) / (MX - MN)
        r.Slider_screen3:SetValue(n); r.ProgressBar_screen3:SetPercent(n)
    end

    ft.OnFPSFTValueChange3 = function(s, v)
        v = clamp(v, MN, MX)
        GraphicSettingDB:UpdateUIData(GraphicSettingDB.FPSFineTuneNum, v)
        s:InitFPSFTValue165()
        if s:GetParentUI() then s:GetParentUI():SetDirty(true) end
        local gi = GraphicSettingDB.GetGameInstance and GraphicSettingDB.GetGameInstance()
        if gi then gi:ExecuteCMD("t.MaxFPS", tostring(v)); gi:ExecuteCMD("r.FrameRateLimit", tostring(v)) end
    end

    ft.OnFPSFTSliderValueChange3 = function(s, nv)
        if not GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch) then return end
        s:OnFPSFTValueChange3(clamp(math.floor((MN + nv*(MX-MN))/ST+0.5)*ST, MN, MX))
    end

    ft.OnFPSFTAdd3 = function(s)
        local c = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneNum) or 90
        s:OnFPSFTValueChange3(math.min(MX, c + ST))
    end

    ft.OnFPSFTMinus3 = function(s)
        local c = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneNum) or 90
        s:OnFPSFTValueChange3(math.max(MN, c - ST))
    end

    ft.OnFPSFTAdd = ft.OnFPSFTAdd3; ft.OnFPSFTMinus = ft.OnFPSFTMinus3
    ft.OnFPSFTSliderValueChange = ft.OnFPSFTSliderValueChange3
end

-- ==============================================================================
-- ================== CUSTOM ESP MENU ==========================================
-- ==============================================================================

function _G.InitModMenuTab()
    if _G.ModMenuInitialized then return end
    _G.ModMenuInitialized = true

    local LocUtil = _G.LocUtil
    if not LocUtil and package.loaded["client.common.LocUtil"] then
        LocUtil = require("client.common.LocUtil")
    end
    
    if LocUtil and not LocUtil._IsModMenuHooked then
        local old_get = LocUtil.GetLocalizeResStr
        LocUtil.GetLocalizeResStr = function(id)
            if type(id) == "string" and not tonumber(id) then return id end
            return old_get(id)
        end
        LocUtil._IsModMenuHooked = true
    end

    local SettingPageDefine = require("client.logic.NewSetting.SettingPageDefine")
    local SettingCatalog = require("client.logic.NewSetting.SettingCatalog")
    
    if not SettingPageDefine.ModMenu then
        local AliasMap = require("client.slua.umg.NewSetting.Item.AliasMap")
        
        local StackESP = {
            { Key = "ModMenu_ESP1", UI = AliasMap.Switcher, Text = "ESP SKELETON BOX", GetFunc = function() return _G.LexusConfig.EspVip end, SetFunc = function(c,v) _G.LexusConfig.EspVip = v return true end },
            { Key = "ModMenu_ESP5", UI = AliasMap.Switcher, Text = "ESP BOX", GetFunc = function() return _G.LexusConfig.EspLoai5 end, SetFunc = function(c,v) _G.LexusConfig.EspLoai5 = v return true end },
            { Key = "ModMenu_ESP4", UI = AliasMap.Switcher, Text = "ESP HIT MARK", GetFunc = function() return _G.LexusConfig.EspRadar end, SetFunc = function(c,v) _G.LexusConfig.EspRadar = v return true end },
            { Key = "ModMenu_WallColor", UI = AliasMap.Switcher, Text = "WALLHACK REAL", GetFunc = function() return _G.LexusConfig.WallXuyenTuong end, SetFunc = function(c,v) _G.LexusConfig.WallXuyenTuong = v return true end },
            { Key = "ModMenu_Ipad_Ex", UI = AliasMap.TitleSwitcher, Text = "▶ CUSTOM IPAD VIEW", ExpandIndex = 0, GetFunc = function() return _G.LexusConfig.IpadView end, SetFunc = function(c,v) _G.LexusConfig.IpadView = v return true end },
            { Key = "ModMenu_Ipad_FOV", UI = AliasMap.Slider, Text = "   IPAD FOV", ExpandHandle = "ModMenu_Ipad_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return (_G.LexusState.CustomTextData.IpadViewFOV or 120) - 90 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.IpadViewFOV = 90 + v return true end }
        }

        SettingPageDefine.ModMenu = {
            Key = "ModMenu",
            Text = "BIZAPRO MOD MENU",
            UIKey = "Setting_Page_Privacy", 
            Category = { { Key = "Cat_ESP", Text = "ESP FEATURES", Stack = StackESP } }
        }
        table.insert(SettingCatalog, SettingPageDefine.ModMenu)
    end

    local UIManager = _G.UIManager
    if UIManager and not UIManager._IsModMenuHooked then
        local old_ShowUI = UIManager.ShowUI
        UIManager.ShowUI = function(config, ...)
            local args = {...}
            local n = select('#', ...) 
            if config and config.keyName and (string.find(string.lower(config.keyName), "setting_main") or string.find(string.lower(config.keyName), "setting")) then
                local catalog = args[1]
                if type(catalog) == "table" then
                    local hasModMenu = false
                    for _, page in ipairs(catalog) do
                        if type(page) == "table" and page.Key == "ModMenu" then hasModMenu = true; break end
                    end
                    if not hasModMenu then table.insert(catalog, SettingPageDefine.ModMenu) end
                end
            end
            local table_unpack = table.unpack or unpack
            return old_ShowUI(config, table_unpack(args, 1, n))
        end
        UIManager._IsModMenuHooked = true
    end
end

_G.InitModMenuTab()
Notify("Custom ESP Menu Loaded")
-- ==============================================================================
-- ================== WEAPON ANIMATION (FIXED v3 COMPLETE) =====================
-- ==============================================================================
if not _G.WeaponAnimationModule then
    _G.WeaponAnimationModule = {}

    local WAM = _G.WeaponAnimationModule

    -- ✅ Direct ticker reference
    local time_ticker = require("common.time_ticker")
    _G.Mytimer_ticker = _G.Mytimer_ticker or time_ticker

    -- ============================================================
    -- CONFIG
    -- ============================================================
    WAM.LOOP          = true       -- true = loop animation, false = play once
    WAM.TOTAL_SEC     = 60         -- total loop duration (seconds)
    WAM.AUTO_START    = true       -- auto start on match enter
    WAM.DEBUG         = false      -- set true for debug logs
    WAM.INSTALL_DELAY = 3.0        -- delay before first auto-start
    WAM.RETRY_DELAY   = 4.0        -- delay for retry

    local DEFAULT_ACTOR = "/Game/Mod/EvoBase/BluePrints/Actor/BP_CharacterLevelSequenceActor.BP_CharacterLevelSequenceActor_C"

    -- ============================================================
    -- INTERNAL STATE
    -- ============================================================
    WAM._enabled        = false
    WAM._running        = false
    WAM._started        = false
    WAM._lastSeqActor   = nil
    WAM._timer          = nil
    WAM._currentChar    = nil
    WAM._seqPath        = nil
    WAM._actorPath      = nil
    WAM._duration       = 0
    WAM._origLoc        = nil
    WAM._origRot        = nil
    WAM._autoLoopId     = nil
    WAM._originalOnWeaponChanged = nil

    -- ============================================================
    -- LOG HELPER
    -- ============================================================
    local function log(msg)
        if WAM.DEBUG then
            print("[WeaponAnim] " .. tostring(msg))
        end
    end

    -- ============================================================
    -- CONFIG READER
    -- ============================================================
    local function IsWeaponAnimEnabled()
        local configValue = nil
        if _G.lizardMH_Config and _G.lizardMH_Config.Get then
            pcall(function()
                configValue = _G.lizardMH_Config.Get("WEAPON_ANIM", nil)
            end)
        end
        if configValue ~= nil then
            return configValue == 1
        end
        return WAM.AUTO_START
    end

    WAM._enabled = IsWeaponAnimEnabled()

    -- ============================================================
    -- ENABLE / DISABLE
    -- ============================================================
    function WAM.SetEnabled(enabled)
        WAM._enabled = enabled == true
        WAM.AUTO_START = WAM._enabled

        if not WAM._enabled then
            WAM.Stop()
        else
            WAM._started = false
            WAM.AutoStartLoop()
        end

        if _G.lizardMH_Config and _G.lizardMH_Config.Set then
            pcall(function()
                _G.lizardMH_Config.Set("WEAPON_ANIM", WAM._enabled and 1 or 0)
            end)
        end
        print("[WeaponAnim] State: " .. tostring(WAM._enabled))
    end

    function WAM.IsEnabled()
        return WAM._enabled
    end

    -- ============================================================
    -- CHARACTER HELPERS
    -- ============================================================
    function WAM.GetCharacter()
        local ok, GD = pcall(require, "GameLua.GameCore.Data.GameplayData")
        if not ok or not GD then return nil end
        local char = GD.GetPlayerCharacter()
        if slua.isValid(char) then return char end
        return nil
    end

    function WAM.IsCharacterReady(char)
        if not char or not slua.isValid(char) then return false end
        local ok, EP = pcall(import, "EPawnState")
        if not ok or not EP then return false end

        local isStanding = false
        pcall(function()
            isStanding = (char.CurrentStates == (1 << EP.Stand))
            if isStanding and char.IsHandleInFold and char:IsHandleInFold() then
                isStanding = false
            end
        end)

        local inVehicle, isDead = false, false
        pcall(function()
            inVehicle = char:HasState(EP.InVehicle) or char:HasState(EP.DriveVehicle)
            isDead = char:HasState(EP.Save) or char:HasState(EP.Pick)
        end)

        return isStanding and not inVehicle and not isDead
    end

    function WAM.GetWeaponAvatarComponent(char)
        if not char or not slua.isValid(char) then return nil end
        local weapon = char.GetCurrentWeapon and char:GetCurrentWeapon()
        if slua.isValid(weapon) and slua.isValid(weapon.WeaponAvatarComponent) then
            return weapon.WeaponAvatarComponent
        end
        return nil
    end

    -- ============================================================
    -- SOFT OBJECT PATH HELPER
    -- ============================================================
    local function softToString(softObj)
        local result = nil
        pcall(function()
            if not softObj then return end
            if softObj.ToSoftObjectPath then
                local sp = softObj:ToSoftObjectPath()
                if sp and sp.ToString then result = sp:ToString() end
                if (not result) and sp and sp.GetAssetPathString then
                    result = sp:GetAssetPathString()
                end
            end
            if (not result) and softObj.ToString then
                result = softObj:ToString()
            end
        end)
        return result
    end

    -- ============================================================
    -- RESOLVE ANIMATION CONFIG
    -- ============================================================
    function WAM.ResolveAnimationConfig(char)
        local seqPath, actorPath, duration = nil, nil, 0

        pcall(function()
            local wac = WAM.GetWeaponAvatarComponent(char)
            if not wac then return end

            local ES = import("EWeaponAttachmentSocketType")
            local ET = import("ECharSpecialLevelSequenceType")
            local handle = wac:GetEquippedHandle(ES.MasterGun)

            if handle and slua.isValid(handle) and handle.WeaponSpecialLevelSequenceList then
                for _, seq in pairs(handle.WeaponSpecialLevelSequenceList) do
                    if seq.LevelSequenceType == ET.ECharSpecLvSeq_WeaponCheck and seq.LevelSequenceConfig then
                        local cfg = seq.LevelSequenceConfig
                        seqPath = softToString(cfg.LevelSequence)
                        actorPath = softToString(cfg.SequenceActorTemplate)
                        duration = cfg.LevelSequenceDuration or 0
                        break
                    end
                end
            end

            if not actorPath or actorPath == "" then
                local AU = import("AvatarUtils")
                local ES2 = import("EWeaponAttachmentSocketType")
                local skinID = wac:GetEquippedItemDefineID(ES2.MasterGun).TypeSpecificID
                if skinID <= 0 then
                    local weapon = char:GetCurrentWeapon()
                    if weapon then
                        skinID = weapon:GetItemDefineID().TypeSpecificID
                    end
                end
                local base = AU.GetWeaponAvatarParentID(AU.GetBPIDByResID(skinID), false)
                local data = CDataTable.GetTableData("WeaponCheckSkill", base)
                if data and data.SequenceActorPath and data.SequenceActorPath ~= "" then
                    actorPath = data.SequenceActorPath
                end
            end
        end)

        if not actorPath or actorPath == "" then
            actorPath = DEFAULT_ACTOR
        end

        return seqPath, actorPath, duration
    end

    -- ============================================================
    -- PLAY ONCE
    -- ============================================================
    function WAM.PlayOnce(char)
        if not WAM._seqPath or WAM._seqPath == "" then
            log("No sequence path")
            return false
        end

        local ok = false
        pcall(function()
            local UKismetMathLibrary = import("KismetMathLibrary")
            local transform = UKismetMathLibrary.MakeTransform(
                WAM._origLoc or char:K2_GetActorLocation(),
                WAM._origRot or char:K2_GetActorRotation(),
                FVector(1, 1, 1)
            )

            local seqActor = Game:PlayLevelSequence(
                char, WAM._seqPath, transform,
                WAM._actorPath or DEFAULT_ACTOR,
                false, nil, char
            )

            if slua.isValid(seqActor) then
                if seqActor.SetCharacterAndPlay then
                    seqActor:SetCharacterAndPlay(char)
                end
                char.CurrentLevelSequence = seqActor
                WAM._lastSeqActor = seqActor
                ok = true
                log("Sequence played OK")
            end
        end)

        return ok
    end

    function WAM.IsSequenceAlive()
        return WAM._lastSeqActor and slua.isValid(WAM._lastSeqActor)
    end

    -- ============================================================
    -- STOP
    -- ============================================================
    function WAM.Stop()
        if WAM._timer and WAM._currentChar and slua.isValid(WAM._currentChar) then
            pcall(function() WAM._currentChar:RemoveGameTimer(WAM._timer) end)
        end
        WAM._running = false
        WAM._timer = nil
        WAM._lastSeqActor = nil
        log("Stopped")
    end

    -- ============================================================
    -- START
    -- ============================================================
    function WAM.Start()
        if not WAM._enabled then
            log("Disabled by config")
            return false
        end

        if WAM._running then
            return false
        end

        local char = WAM.GetCharacter()
        if not char or not slua.isValid(char) then
            return false
        end

        if not WAM.IsCharacterReady(char) then
            return false
        end

        WAM._seqPath, WAM._actorPath, WAM._duration = WAM.ResolveAnimationConfig(char)

        if not WAM._seqPath or WAM._seqPath == "" then
            return false
        end

        if WAM._duration <= 0 then
            WAM._duration = 9
        end

        WAM._running = true
        WAM._currentChar = char
        WAM._origLoc = char:K2_GetActorLocation()
        WAM._origRot = char:K2_GetActorRotation()

        if not WAM.PlayOnce(char) then
            WAM._running = false
            return false
        end

        local elapsed = 0
        local sinceReplay = 0
        local started = false

        pcall(function()
            WAM._timer = char:AddGameTimer(0.2, true, function()
                elapsed = elapsed + 0.2
                sinceReplay = sinceReplay + 0.2

                local cur = WAM.GetCharacter()
                if not cur or not slua.isValid(cur) then
                    WAM.Stop()
                    return
                end

                if not WAM.IsCharacterReady(cur) then
                    WAM.Stop()
                    return
                end

                if WAM.IsSequenceAlive() then
                    started = true
                end

                if WAM.LOOP then
                    if (not WAM.IsSequenceAlive()) or sinceReplay >= (WAM._duration - 0.3) then
                        sinceReplay = 0
                        if WAM._enabled then
                            WAM.PlayOnce(cur)
                        else
                            WAM.Stop()
                        end
                    end
                    if elapsed >= WAM.TOTAL_SEC then
                        WAM.Stop()
                    end
                else
                    if (started and not WAM.IsSequenceAlive()) or elapsed >= (WAM._duration + 1) then
                        WAM.Stop()
                    end
                end
            end)
        end)

        log("Started duration=" .. tostring(WAM._duration))
        return true
    end

    function WAM.Restart()
        WAM.Stop()
        return WAM.Start()
    end

    -- ============================================================
    -- WEAPON SWITCH BINDING
    -- ============================================================
    function WAM.BindToWeaponSwitch()
        if not WAM._originalOnWeaponChanged and _G.WeaponEvents and _G.WeaponEvents.onWeaponChanged then
            WAM._originalOnWeaponChanged = _G.WeaponEvents.onWeaponChanged
            _G.WeaponEvents.onWeaponChanged = function(weaponId)
                if WAM._originalOnWeaponChanged then
                    WAM._originalOnWeaponChanged(weaponId)
                end
                if WAM._enabled then
                    pcall(function() WAM.Restart() end)
                end
            end
            log("Bound to weapon switch event")
        end
    end

    -- ============================================================
    -- AUTO START LOOP
    -- ============================================================
    function WAM.AutoStartLoop()
        WAM._enabled = IsWeaponAnimEnabled()

        if not WAM._enabled then
            log("AutoStart: disabled by config")
            return
        end

        if WAM._started then return end
        WAM._started = true

        local tt = time_ticker or _G.Mytimer_ticker
        if tt and tt.AddTimerLoop then
            if not WAM._autoLoopId then
                WAM._autoLoopId = tt.AddTimerLoop(3, function()
                    pcall(function()
                        if not WAM._running and WAM._enabled then
                            local char = WAM.GetCharacter()
                            if char and slua.isValid(char) and WAM.IsCharacterReady(char) then
                                local seqPath = WAM.ResolveAnimationConfig(char)
                                if seqPath and seqPath ~= "" then
                                    WAM.Start()
                                end
                            end
                        end
                    end)
                end, -1, 1)
            end
        end

        pcall(function() WAM.Start() end)
    end

    -- ============================================================
    -- PUBLIC API
    -- ============================================================
    _G.StartWeaponAnimation   = WAM.Start
    _G.StopWeaponAnimation    = WAM.Stop
    _G.RestartWeaponAnimation = WAM.Restart
    _G.SetWeaponAnimation     = WAM.SetEnabled

    WAM.BindToWeaponSwitch()
    if time_ticker and time_ticker.AddTimerOnce then
        time_ticker.AddTimerOnce(WAM.INSTALL_DELAY, function()
            WAM.AutoStartLoop()
        end)
        time_ticker.AddTimerOnce(WAM.INSTALL_DELAY + WAM.RETRY_DELAY, function()
            if not WAM._running and WAM._enabled then
                WAM._started = false
                WAM.AutoStartLoop()
            end
        end)
    else
        WAM.AutoStartLoop()
    end

    log("Weapon Animation Module loaded, enabled=" .. tostring(WAM._enabled))
end
-- ==============================================================================
-- ================== PHONE STATE UI =============================
-- ==============================================================================
local IngamePhoneStateUI = require("GameLua.Mod.Library.Client.UI.IngamePhoneStateUI") 
local Lobby_Main_Wifi_UIBP = require("client.slua.umg.lobby.Main.Lobby_Main_Wifi_UIBP")

local o_UpdateQuality = Lobby_Main_Wifi_UIBP.__inner_impl.UpdateQuality
Lobby_Main_Wifi_UIBP.__inner_impl.UpdateQuality = function(self)
    self.UIRoot.WidgetSwitcher_Quality:SetActiveWidgetIndex(0)
    self.UIRoot.TextBlock_High:SetText("BIZAPROOFFICIAL")
    self.UIRoot.TextBlock_High:SetColorAndOpacity(FSlateColor(FLinearColor(0, 0, 1, 1)))
end

local o_UpdateArtQualityUI = IngamePhoneStateUI.__inner_impl.UpdateArtQualityUI
IngamePhoneStateUI.__inner_impl.UpdateArtQualityUI = function(self, _, _)
    self.UIRoot.TextBlock_quality:SetText("BIZAPROOFFICIAL")
    self.UIRoot.TextBlock_quality:SetColorAndOpacity(FSlateColor(FLinearColor(0, 0, 1, 1)))
end
local class = require("class")
local CActorBase = require("GameLua.Mod.BaseMod.Common.Core.ActorBase")
local CGameStateBase = class(CActorBase, nil, GameStateBase)
return require("combine_class").DeclareFeature(CGameStateBase, {
  {
    GlobalAvatar = "GameLua.GameCore.Feature.GlobalAvatarFeature"
  },
  {
    ReviveState = "GameLua.Mod.BaseMod.GamePlay.Revive.ReviveGameStateFeature"
  },
  {
    KingEliminationFeature = "GameLua.GameCore.Feature.KingEliminationFeature"
  },
  {
    FatalDamageFeature = "GameLua.Mod.BaseMod.Gameplay.Feature.GameStateFatalDamageFeature"
  }
}, "GameStateBase")