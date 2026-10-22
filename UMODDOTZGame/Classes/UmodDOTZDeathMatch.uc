// Copyright (C) 2005 Brainbox Games. All Rights Reserved.
// September 27, 2005
//-----------------------------------------------------------
//
//-----------------------------------------------------------
class UmodDOTZDeathMatch extends DOTZDeathMatch;

const MAX_BOTS = 8;
const MIN_BOTS = 5;

var int IdealBotsCount;

var int BotsCount;

var bool bBonusSystem;

var UnrealRepository ModRepo;

var config class<Pawn> OverridePawnClass;

// Shared veteran-wander route cache. Built once per level/game mode and reused by all bots.
const BOT_ROUTE_MAX_TARGETS = 64;
const BOT_ROUTE_MAX_NAV_NODES = 768;
const BOT_ROUTE_INFINITY = 999999999.0;

var protected array<Actor> BotRouteTargets;
var protected array<NavigationPoint> BotRouteTargetNodes;
var protected array<NavigationPoint> BotRouteNavNodes;
var protected array<float> BotRouteDistances;
var protected array<int> BotRouteOrder;
var protected bool bBotRouteCacheBuilt;

var protected int MinPlayers;
var protected bool bPlayersVsBots;
var protected bool bKillBots;

/*******************************************************************
 * Initialize the game.  The GameInfo's InitGame() function is called
 * before any other scripts (including PreBeginPlay() ), and is used
 * by the GameInfo to initialize parameters and spawn its helper
 * classes.  Warning: this is called before actors' PreBeginPlay.
 *******************************************************************
 */
event InitGame(String options, out String error)
{
   super.InitGame(options, error);

   ModRepo = new class'UMODDOTZGame.UnrealRepository';

    if (ModRepo != None)
    {
		OverridePlayerControllerClass = class<PlayerController>(DynamicLoadObject(ModRepo.DeathMatchPlayerControllerClassName, class'Class'));

	   if (OverridePlayerControllerClass == none)
	   {OverridePlayerControllerClass = class<PlayerController>(DynamicLoadObject(ModRepo.PlayerControllerClassName, class'Class'));}

	   if (OverridePlayerControllerClass != none){PlayerControllerClass = OverridePlayerControllerClass;}

		OverridePawnClass = class<Pawn>(DynamicLoadObject(ModRepo.DeathMatchPawnClassName, class'Class'));

	   if (OverridePawnClass == none)
	   {OverridePawnClass = class<Pawn>(DynamicLoadObject(ModRepo.PlayerPawnClassName, class'Class'));}

	   if (OverridePawnClass == none)
	   {OverridePawnClass = class<Pawn>(DynamicLoadObject(DefaultPlayerClassName, class'Class'));}
    }

   BuildBotRouteCache(false);
}

event PostBeginPlay()
{
    local Controller P;
    local int i;
    local int BotsCount;
    local int iNewBots;

    Super.PostBeginPlay();

    BotsCount = 0;
    for (P = Level.ControllerList; P != None; P = P.NextController)
    {
        if (P.IsA('PlayerController') || P.IsA('UmodBotController'))
            BotsCount++;
    }

    if (BotsCount < MIN_BOTS)
    {
        iNewBots = MIN_BOTS - BotsCount;

        if (iNewBots > 0)
		{
			for (i = 0; i < iNewBots; i++)
			{
				P = SpawnBot(iNewBots+i);

				if (P != None)
				{
					if (P.Pawn == None || P.Pawn.Health <= 0)
						RestartBot(P);
				}
				else
					Log("UmodDOTZDeathMatch: failed to spawn bot " $ i);
			}
		}
    }
}

//
// Accept or reject a player on the server.
// Fails login if you set the Error to a non-empty string.
//
/*event PreLogin
(
	string Options,
	string Address,
	out string Error,
	out string FailCode
)
{
	local bool bSpectator;

    bSpectator = ( ParseOption( Options, "SpectatorOnly" ) ~= "true" );
	AccessControl.PreLogin(Options, Address, Error, FailCode, bSpectator);
}*/

//
// Log a player in.
// Fails login if you set the Error string.
// PreLogin is called before Login, but significant game time may pass before
// Login is called, especially if content is downloaded.
//
event PlayerController Login
(
	string Portal,
	string Options,
	out string Error
)
{
	local Controller BotToBeKicked;
    local bool bSpectator;

    bSpectator = ( ParseOption( Options, "SpectatorOnly" ) ~= "true" );

    if ( AtCapacity(bSpectator) )
	{
		for (BotToBeKicked = Level.ControllerList; BotToBeKicked != None; BotToBeKicked = BotToBeKicked.NextController)
		{
			if (BotToBeKicked.IsA('UmodBotController'))
			{
				BotToBeKicked.GotoState('Spectating');
				
				if (BotToBeKicked.Pawn != None)
					BotToBeKicked.Pawn.Died( BotToBeKicked, class'Suicided', BotToBeKicked.Pawn.Location );

				BotToBeKicked.UnPossess();
				BotToBeKicked.Pawn = None;
				BotToBeKicked.Destroy();

				break;
			}
		}
	}

	return Super.Login(Portal, Options, Error);
}

/*****************************************************************
 * ScoreKill
 *****************************************************************
 */
function ScoreKill(Controller Killer, Controller Other)
{
    local Controller P;
    local int i;
    local int iBonus;
    local int BotsCount;
    local int iNewBots;
    local PlayerReplicationInfo KillerPRI;
    local PlayerReplicationInfo OtherPRI;

    BotsCount = 0;

    for (P = Level.ControllerList; P != None; P = P.NextController)
    {
        if (P.IsA('PlayerController'))
        {
            BotsCount++;
        }
        else if (P.IsA('UmodBotController'))
        {
            BotsCount++;

            if (P.Pawn == None || P.Pawn.Health < 1)
                RestartBot(P);
        }
    }

	iNewBots = MAX_BOTS - BotsCount;

	if (iNewBots > 0 && iNewBots < MAX_BOTS)
	{
		for (i = 0; i < iNewBots; i++)
		{
			P = SpawnBot(iNewBots+i);

			if (P != None)
			{
				if (P.Pawn == None || P.Pawn.Health <= 0)
					RestartBot(P);
			}
			else
				Log("UmodDOTZDeathMatch: failed to spawn bot " $ i);
		}
	}

    if (Other != None)
    {
		iBonus = 1;

		OtherPRI = Other.PlayerReplicationInfo;

		if (Killer != None && Killer != Other)
		{
			KillerPRI = Killer.PlayerReplicationInfo;

			if (KillerPRI != None && OtherPRI != None)
			{
				if (Other.IsA('PlayerController') || Other.IsA('UmodBotController'))
				{
					if (bBonusSystem && KillerPRI.Kills > 5)
					{
						if (KillerPRI.Deaths == 0)
						{
							if (Killer.Pawn != None && Killer.Pawn.Health == 100)
							{
								iBonus = 4;
							}
							else
							{
								iBonus = 3;
							}
						}
						else if ( 2 * KillerPRI.Deaths < KillerPRI.Kills )
						{
							iBonus = 2;
						}
					}

					if (!bTeamGame)
					{
						KillerPRI.Score += (iBonus * 1);
					}

					else if (KillerPRI.Team != None && OtherPRI.Team != None)
					{
						if (KillerPRI.Team.TeamIndex != OtherPRI.Team.TeamIndex)
						{
							KillerPRI.Team.Score += 1;
							KillerPRI.Score += (iBonus * 1);
						}
						else if (bTeamGame)
						{
							KillerPRI.Score -= 1;
							//KillerPRI.Kills -= 2;
						}
					}
				}

				KillerPRI.Kills++;
				ScoreEvent(KillerPRI, 1, "frag");
			}
		}
		else
		{
			if (Killer == Other && OtherPRI != None)
			{
				OtherPRI.Score -= 1;
				ScoreEvent(OtherPRI, -1, "self_frag");
			}
		}

		if (GameRulesModifiers != None)
			GameRulesModifiers.ScoreKill(Killer, Other);

		if (KillerPRI != None)
			CheckScore(KillerPRI);
    }
}

/*****************************************************************
 * InitGameReplicationInfo
 * Set up data that players will use
 *****************************************************************
 */
function InitGameReplicationInfo()
{
   /*GameReplicationInfo.TimeLimit = TimeLimit;
   if (TimeLimit == -1){
      GameReplicationInfo.RemainingTime = -1;
   } else {
      GameReplicationInfo.RemainingTime = (RemainingTime /60) + 1;
   }
   GameReplicationInfo.GoalScore = GoalScore;

   if (bTeamGame){
      GameReplicationInfo.Teams[0] = Spawn(class'TeamInfo');
      GameReplicationInfo.Teams[1] = Spawn(class'TeamInfo');

      GameReplicationInfo.Teams[0].TeamName = "Red";
      GameReplicationInfo.Teams[0].TeamIndex = 0;

      GameReplicationInfo.Teams[1].TeamName = "Blue";
      GameReplicationInfo.Teams[1].TeamIndex = 1;
   }
   GameReplicationInfo.bMatchHasBegun = true;
  //  super.InitGameReplicationInfo();
  */
    super.InitGameReplicationInfo();
    if( bTeamGame )
        GameReplicationInfo.MatchID = ID_TDM;
    else
        GameReplicationInfo.MatchID = ID_DM;
}

//
// Spawn any default inventory for the player.
//
function AddDefaultInventory( pawn PlayerPawn )
{
	local Weapon newWeapon;
	local class<Weapon> WeapClass;
	local int num, idx;
    local PlayerReplicationInfo PawnPRI;

	if ( PlayerPawn == None )
		return;

	PawnPRI = PlayerPawn.PlayerReplicationInfo;

	if ( PawnPRI == None && PlayerPawn.Controller != None )
		PawnPRI = PlayerPawn.Controller.PlayerReplicationInfo;

	// Spawn default weapon.
	if( BaseMutator != None && BaseMutator.IsA('Weapon'))
	{
		WeapClass = BaseMutator.GetDefaultWeapon();

		if( (WeapClass!=None) && (PlayerPawn.FindInventoryType(WeapClass)==None) )
		{
			newWeapon = Spawn(WeapClass,,,PlayerPawn.Location);
			if( newWeapon != None )
			{
				newWeapon.GiveTo(PlayerPawn);
				//newWeapon.BringUp();
				newWeapon.bCanThrow = false; // don't allow default weapon to be thrown out
			}
		}
	}
	else
	{
		if(ModRepo != None)
		{
			if(PawnPRI != None)
			{
				// New players: all weapons
				if (PawnPRI.Deaths == 0 && PawnPRI.Kills == 0)
				{
					num = ModRepo.AllWeaponClassList.Length;

					if (num > 0)
					{
						idx = Rand(num);

						WeapClass = class<Weapon>(DynamicLoadObject(ModRepo.AllWeaponClassList[idx], class'Class'));
					}
				}
				// Balancing: Be more generous with struggling players
				else if ( PawnPRI.Kills > 1 && 2 * PawnPRI.Kills < PawnPRI.Deaths )
				{
					//num = ModRepo.SpecialWeaponNameList.Length;
					num = ModRepo.PrimaryWeaponNameList.Length;

					if (num > 0)
					{
						idx = Rand(num);

						WeapClass = class<Weapon>(DynamicLoadObject(ModRepo.PrimaryWeaponNameList[idx], class'Class'));
					}
				}
			}

			if(WeapClass == None)
			{
				num = ModRepo.BackupWeaponNameList.Length;

				if (num > 0)
				{
					idx = Rand(num);

					WeapClass = class<Weapon>(DynamicLoadObject(ModRepo.BackupWeaponNameList[idx], class'Class'));
				}
			}
		}

		if(WeapClass == None)
		{
			WeapClass = class<Weapon>(DynamicLoadObject("DOTZWeapons.GlockWeapon", class'Class'));
		}

		newWeapon = Spawn(WeapClass,,,PlayerPawn.Location);
		if( newWeapon != None )
		{
			newWeapon.GiveTo(PlayerPawn);
			//newWeapon.BringUp();
			newWeapon.bCanThrow = false; // don't allow default weapon to be thrown out
		}
	}

	SetPlayerDefaults(PlayerPawn);
}

function int SpawnWeaponPickUp( int idx, vector inLocation )
{
	local Pickup newWeapon;
	local class<Pickup> WeapClass;
	local int i;

	if(ModRepo != None)
	{
		if(idx < ModRepo.AllWeaponPickupClassList.Length)
		{
			WeapClass = class<Pickup>(DynamicLoadObject(ModRepo.AllWeaponPickupClassList[idx], class'Class'));

			if(WeapClass == None)
			{
				for(i = 0; i < ModRepo.AllWeaponPickupClassList.Length; i++)
				{
					WeapClass = class<Pickup>(DynamicLoadObject(ModRepo.AllWeaponPickupClassList[i], class'Class'));
					
					if(WeapClass != None)
					{
						idx = i;
						break;
					}
				}
			}

			if(WeapClass != None)
			{
				inLocation.Z = inLocation.Z - 70.0;
				newWeapon = Spawn(WeapClass,,,inLocation);
				idx++;
			}
		}
	}

	return idx;
}

//
// Player exits.
//
function Logout_bkp( Controller Exiting )
{
	local bool bMessage;
	local int Index;

	bMessage = true;
	if ( PlayerController(Exiting) != None )
	{
//FIXME_MERGE		if ( AccessControl.AdminLogout( PlayerController(Exiting) ) )
//			AccessControl.AdminExited( PlayerController(Exiting) );

        if ( PlayerController(Exiting).PlayerReplicationInfo.bOnlySpectator )
		{
			bMessage = false;
				NumSpectators--;
		}
		else
        {
			NumPlayers--;
        }

		if( Level.NetMode != NM_Standalone )
		{
			for( Index=0; Index<VoiceChatters.Length; Index++ )
			{
				if( VoiceChatters[Index].Controller == Exiting )
				{
					ChangeVoiceChatter( PlayerController(Exiting), VoiceChatters[Index].IpAddr, VoiceChatters[Index].Handle, false );
				}
			}
		}

		if( Level.NetMode == NM_Client )
		{
			PlayerController(Exiting).ClientLeaveVoiceChat();
		}
	}
	if( bMessage && (Level.NetMode==NM_DedicatedServer || Level.NetMode==NM_ListenServer) )
		BroadcastLocalizedMessage(GameMessageClass, 4, Exiting.PlayerReplicationInfo);

	if ( GameStats!=None)
		GameStats.DisconnectEvent(Exiting.PlayerReplicationInfo);

   if (class'UtilsXbox'.static.Get_Reboot_Type() == 3) { // if live host
       if (IsPrivateGame) {
           class'UtilsXbox'.static.Live_Host_Set_PublicFilled(0);
           class'UtilsXbox'.static.Live_Host_Set_PublicOpen(0);
           class'UtilsXbox'.static.Live_Host_Set_PrivateFilled(NumPlayers);
           class'UtilsXbox'.static.Live_Host_Set_PrivateOpen(MaxPlayers - NumPlayers);

            if (MaxPlayers - NumPlayers > 0) {
               class'UtilsXbox'.static.Set_Player_Joinable      ();
               GameFilled = false;
               GameReplicationInfo.GameFilled = GameFilled;
            } else {
               class'UtilsXbox'.static.Set_Player_Not_Joinable  ();
               GameFilled = true;
               GameReplicationInfo.GameFilled = GameFilled;
            }
       } else {
           class'UtilsXbox'.static.Live_Host_Set_PublicFilled(NumPlayers);
           class'UtilsXbox'.static.Live_Host_Set_PublicOpen(MaxPlayers - NumPlayers);
           class'UtilsXbox'.static.Live_Host_Set_PrivateFilled(0);
           class'UtilsXbox'.static.Live_Host_Set_PrivateOpen(0);

           if (MaxPlayers - NumPlayers > 0) {
               class'UtilsXbox'.static.Set_Player_Joinable      ();
               GameFilled = false;
               GameReplicationInfo.GameFilled = GameFilled;
           } else {
               class'UtilsXbox'.static.Set_Player_Not_Joinable  ();
               GameFilled = true;
               GameReplicationInfo.GameFilled = GameFilled;
           }

       }
       class'UtilsXbox'.static.Live_Host_Update_Session();
   } else {
       class'UtilsXbox'.static.Set_Player_Not_Joinable();
   }
}

/*****************************************************************
 * PickTeam
 * When starting a team match we assing teams alternately to each
 * side based upon order of entry.
 *****************************************************************
 */
function byte PickBotTeam(byte Current, Controller C){

   local int i;
   local int RedCount, BlueCount;

   //evaluate the current team distribution
   for (i=0; i < GameReplicationInfo.PRIArray.length; i++){
      if (GameReplicationInfo.PRIArray[i].Team.TeamIndex == 0){
         RedCount++;
      } else {
         BlueCount++;
      }
   }

   //put the new guy on the smaller team
   if (RedCount > BlueCount){
      return 1;
   } else {
      return 0;
   }
}

// Add one or num bots
exec function AddNamedBot(string botname)
{
    if (Level.NetMode != NM_Standalone)
        MinPlayers = Max(MinPlayers + 1, NumPlayers + NumBots + 1);
    AddBot(botName);
}

exec function AddBots(int num)
{
    num = Clamp(num, 0, 6 - (NumPlayers + NumBots));

    while (--num >= 0)
    {
        if ( Level.NetMode != NM_Standalone )
            MinPlayers = Max(MinPlayers + 1, NumPlayers + NumBots + 1);
        AddBot();
    }
}

// Kill all or num bots
exec function KillBots(int num)
{
    local Controller c, nextC;

	bPlayersVsBots = false;

    if (num == 0)
        num = NumBots;

    c = Level.ControllerList;
    if ( Level.NetMode != NM_Standalone )
		MinPlayers = 0;
    bKillBots = true;
    while (c != None && num > 0)
    {
        nextC = c.NextController;
        if (KillBot(c))
            --num;
        c = nextC;
    }
    bKillBots = false;
}

function bool KillBot(Controller c)
{
    local UmodBotController b;

    b = UmodBotController(c);
    if (b != None)
    {
        if (Level.NetMode != NM_Standalone)
            MinPlayers = Max(MinPlayers - 1, NumPlayers + NumBots - 1);

		if ( (Vehicle(b.Pawn) != None) /*&& (Vehicle(b.Pawn).Driver != None)*/ )
            b.Pawn.KilledBy( b.Pawn );
			//Vehicle(b.Pawn).Driver.KilledBy(Vehicle(b.Pawn).Driver);
		else if (b.Pawn != None)
            b.Pawn.KilledBy( b.Pawn );
		if (b != None)
			b.Destroy();
        return true;
    }
    return false;
}

function bool AddBot(optional string botName)
{
    local NavigationPoint StartSpot;
    local AIController NewBot;
    local string InCharacter;
    local string Error, Portal;
    local byte InTeam;
    //local bool bSpectator;
    local UmodBotController NewUmodBot;
    local string NewBotPawnClassName;
    local int BotClassCount;
    local int inIndex;
    local Pawn OldPawn;
    local Pawn NewPawn;

    InTeam = PickTeam(InTeam, None);
    StartSpot = FindPlayerStart(None, InTeam, Portal);

    if (StartSpot == None)
    {
        StartSpot = FindBotStart(None, InTeam, Portal);
    }

    if (StartSpot == None)
    {
        Error = GameMessageClass.Default.FailedPlaceMessage;
        return false;
    }

    if (ModRepo != None && ModRepo.InvasionBotControllerClass != None)
        NewBot = Spawn(ModRepo.InvasionBotControllerClass,,,StartSpot.Location,StartSpot.Rotation);
    else
        NewBot = Spawn(class'UMODDOTZGame.UmodBotController',,,StartSpot.Location,StartSpot.Rotation);

    if (NewBot != None)
    {
		NewBot.StartSpot = StartSpot;
		NewUmodBot = UmodBotController(NewBot);

		if (NewUmodBot != None)
		{
			NewUmodBot.GameReplicationInfo = GameReplicationInfo;
			NewUmodBot.bCoopGameMode = true;
		}

		NewBot.GotoState('Spectating');

		if (ModRepo != None)
		{
			BotClassCount = ModRepo.InvasionBotPawnClassNameList.Length;
			if (BotClassCount <= 0)
			{
				NewBotPawnClassName = "UMODDOTZGame.UmodHumanOtis";
			}
			else
			{
				if (inIndex < 0 || inIndex >= BotClassCount)
					inIndex = Rand(BotClassCount);

				NewBotPawnClassName = ModRepo.InvasionBotPawnClassNameList[inIndex];
			}
		}

		if (NewBotPawnClassName == "")
			NewBotPawnClassName = "UMODDOTZGame.UmodHumanOtis";

		NewBot.SetPawnClass(NewBotPawnClassName, InCharacter);

		NumPlayers++;
		bWelcomePending = true;

			OldPawn = NewBot.Pawn;
			if (OldPawn != None)
			{
				if (OldPawn.Health > 0)
					return false;

				NewBot.UnPossess();
				if (!OldPawn.bDeleteMe)
					OldPawn.Destroy();
				NewBot.Pawn = None;
			}

			if (NewBot.PawnClass != None)
				NewPawn = Spawn(NewBot.PawnClass,,,StartSpot.Location,StartSpot.Rotation);

			if (NewPawn == None && ModRepo != None && ModRepo.BotPawnClass != None)
				NewPawn = Spawn(ModRepo.BotPawnClass,,,StartSpot.Location,StartSpot.Rotation);

			if (NewPawn == None)
			{
				Log("Couldn't spawn player of type " $ NewBot.PawnClass $ " at " $ StartSpot);
				NewBot.GotoState('Dead');
				return false;
			}

			NewBot.Pawn = NewPawn;
			NewPawn.Anchor = StartSpot;
			NewPawn.LastStartSpot = PlayerStart(StartSpot);
			NewPawn.LastStartTime = Level.TimeSeconds;
			NewBot.PreviousPawnClass = NewPawn.Class;

			NewBot.Possess(NewPawn);
			if (NewBot.Pawn == None)
			{
				if (!NewPawn.bDeleteMe)
					NewPawn.Destroy();
				return false;
			}

			NewBot.PawnClass = NewBot.Pawn.Class;
			NewBot.Pawn.PlayTeleportEffect(true, true);
			NewBot.ClientSetRotation(NewBot.Pawn.Rotation);
			AddDefaultInventory(NewBot.Pawn);
			TriggerEvent(StartSpot.Event, StartSpot, NewBot.Pawn);
		return true;
	}

	Log("Couldn't spawn Bot controller of class " $ ModRepo.BotControllerClass);
	Error = GameMessageClass.Default.FailedSpawnMessage;

    return false;
}

function Controller SpawnBot(int inIndex)
{
    local NavigationPoint StartSpot;
    local AIController NewBot;
    local string InCharacter;
    local string Error, Portal;
    local byte InTeam;
    local bool bSpectator;
    local UmodBotController NewUmodBot;
    local string NewBotPawnClassName;
    local int BotClassCount;

    InTeam = PickTeam(InTeam, None);
    StartSpot = FindPlayerStart(None, InTeam, Portal);

    if (StartSpot == None)
    {
        StartSpot = FindBotStart(None, InTeam, Portal);
    }

    if (StartSpot == None)
    {
        Error = GameMessageClass.Default.FailedPlaceMessage;
        return None;
    }

    if (bTeamGame)
    {
		if (ModRepo != None && ModRepo.TeamDeathMatchBotControllerClass != None)
			NewBot = Spawn(ModRepo.TeamDeathMatchBotControllerClass,,,StartSpot.Location,StartSpot.Rotation);
		else
			NewBot = Spawn(class'UMODDOTZGame.UmodBotControllerTeamDeathmatch',,,StartSpot.Location,StartSpot.Rotation);
    }
    else
    {
		if (ModRepo != None && ModRepo.DeathMatchBotControllerClass != None)
			NewBot = Spawn(ModRepo.DeathMatchBotControllerClass,,,StartSpot.Location,StartSpot.Rotation);
		else
			NewBot = Spawn(class'UMODDOTZGame.UmodBotControllerDeathmatch',,,StartSpot.Location,StartSpot.Rotation);
    }

    if (NewBot != None)
    {
		NewBot.StartSpot = StartSpot;
		NewUmodBot = UmodBotController(NewBot);

		if (NewUmodBot != None)
		{
			NewUmodBot.GameReplicationInfo = GameReplicationInfo;
			NewUmodBot.bCoopGameMode = false;
		}

		NewBot.GotoState('Spectating');

		if (NewBot.PlayerReplicationInfo == None)
		{
			NewBot.Destroy();
			return None;
		}
		else
		{
			if (ModRepo != None)
			{
				//BotClassCount = ArrayCount(ModRepo.BotPawnClassNameList);
				BotClassCount = ModRepo.BotPawnClassNameList.Length;

				if (BotClassCount <= 0)
				{
					NewBotPawnClassName = "UMODDOTZGame.UmodHumanOtis";
				}
				else
				{
					if (inIndex < 0 || inIndex >= BotClassCount)
						inIndex = Rand(BotClassCount);

					NewBotPawnClassName = ModRepo.BotPawnClassNameList[inIndex];
				}
			}

			if (NewBotPawnClassName == "")
				NewBotPawnClassName = "UMODDOTZGame.UmodHumanOtis";

			NewBot.SetPawnClass(NewBotPawnClassName, InCharacter);

			if (bSpectator || NewBot.PlayerReplicationInfo.bOnlySpectator)
			{
				NewBot.PlayerReplicationInfo.bOnlySpectator = true;
				NewBot.PlayerReplicationInfo.bIsSpectator = true;
				NewBot.PlayerReplicationInfo.bOutOfLives = true;
				NumSpectators++;
				return NewBot;
			}

			if (!ChangeTeam(NewBot, InTeam, false))
			{
				Error = GameMessageClass.Default.FailedTeamMessage;
				NewBot.Destroy();
				return None;
			}

			NewBot.StartSpot = StartSpot;
			NewBot.PlayerReplicationInfo.PlayerID = CurrentID++;

			if (NewBot.PlayerReplicationInfo.Team != None)
				NewBot.PlayerReplicationInfo.Team.TeamIndex = InTeam;

			NumPlayers++;
			bWelcomePending = true;

			if (bDelayedStart)
				NewBot.GotoState('PlayerWaiting');
		}

		return NewBot;
    }

	Log("Couldn't spawn Bot controller of class " $ ModRepo.DeathMatchBotControllerClass);
	Error = GameMessageClass.Default.FailedSpawnMessage;
	return None;

}

//
// Restart a player.
//
function RestartBot(Controller aPlayer)
{
    local NavigationPoint StartSpot;
    local int TeamNum;
    local Pawn OldPawn;
    local Pawn NewPawn;

    if (aPlayer != None)
    {
		if (aPlayer.PlayerReplicationInfo != None)
		{
			if (aPlayer.PlayerReplicationInfo.Team == None)
				TeamNum = PickTeam(0, None);
			else
				TeamNum = aPlayer.PlayerReplicationInfo.Team.TeamIndex;

			StartSpot = FindPlayerStart(aPlayer, TeamNum);
			if (StartSpot == None)
			{
				Log("Player start not found!!!");
				return;
			}

			OldPawn = aPlayer.Pawn;
			if (OldPawn != None)
			{
				if (OldPawn.Health > 0)
					return;

				aPlayer.UnPossess();
				if (!OldPawn.bDeleteMe)
					OldPawn.Destroy();
				aPlayer.Pawn = None;
			}

			if (aPlayer.PawnClass != None)
				NewPawn = Spawn(aPlayer.PawnClass,,,StartSpot.Location,StartSpot.Rotation);

			if (NewPawn == None && ModRepo != None && ModRepo.BotPawnClass != None)
				NewPawn = Spawn(ModRepo.BotPawnClass,,,StartSpot.Location,StartSpot.Rotation);

			if (NewPawn == None)
			{
				Log("Couldn't spawn player of type " $ aPlayer.PawnClass $ " at " $ StartSpot);
				aPlayer.GotoState('Dead');
				return;
			}

			aPlayer.Pawn = NewPawn;
			NewPawn.Anchor = StartSpot;
			NewPawn.LastStartSpot = PlayerStart(StartSpot);
			NewPawn.LastStartTime = Level.TimeSeconds;
			aPlayer.PreviousPawnClass = NewPawn.Class;

			aPlayer.Possess(NewPawn);
			if (aPlayer.Pawn == None)
			{
				if (!NewPawn.bDeleteMe)
					NewPawn.Destroy();
				return;
			}

			aPlayer.PawnClass = aPlayer.Pawn.Class;
			aPlayer.Pawn.PlayTeleportEffect(true, true);
			aPlayer.ClientSetRotation(aPlayer.Pawn.Rotation);
			AddDefaultInventory(aPlayer.Pawn);
			TriggerEvent(StartSpot.Event, StartSpot, aPlayer.Pawn);
		}
    }
}

/* Return the 'best' player start for this player to start from.
 */
function NavigationPoint FindBotStart( Controller Player, optional byte InTeam, optional string incomingName )
{
	local NavigationPoint N, BestStart;
	//local Teleporter Tel;
	local float BestRating, NewRating;
	//local byte Team;

	BestRating = -999999.0;

	// always pick StartSpot at start of match
    if ( (Player != None) && (Player.StartSpot != None) && (Level.NetMode == NM_Standalone)
		&& (bKeepSamePlayerStart || bWaitingToStartMatch || ((Player.PlayerReplicationInfo != None) && Player.PlayerReplicationInfo.bWaitingPlayer))  )
	{
		return Player.StartSpot;
	}

	/*if ( GameRulesModifiers != None )
	{
		N = GameRulesModifiers.FindPlayerStart(Player,InTeam,incomingName);
		if ( N != None )
		    return N;
	}

	// if incoming start is specified, then just use it
	if( incomingName!="" )
		foreach AllActors( class 'Teleporter', Tel )
			if( string(Tel.Tag)~=incomingName )
				return Tel;

	// use InTeam if player doesn't have a team yet
	if ( (Player != None) && (Player.PlayerReplicationInfo != None) )
	{
		if ( Player.PlayerReplicationInfo.Team != None )
			Team = Player.PlayerReplicationInfo.Team.TeamIndex;
		else
			Team = 0;
	}
	else
		Team = InTeam;

	for ( N=Level.NavigationPointList; N!=None; N=N.NextNavigationPoint )
	{
		NewRating = RatePlayerStart(N,InTeam,Player);
		if ( NewRating > BestRating )
		{
			BestRating = NewRating;
			BestStart = N;
		}
	}

	if ( BestStart == None )
	{
		log("Warning - PATHS NOT DEFINED or NO PLAYERSTART");
		foreach AllActors( class 'NavigationPoint', N )
		{
			NewRating = RatePlayerStart(N,0,Player);
			if ( NewRating > BestRating )
			{
				BestRating = NewRating;
				BestStart = N;
			}
		}
	}*/

	for ( N=Level.NavigationPointList; N!=None; N=N.NextNavigationPoint )
	{
		NewRating = RatePlayerStart(N,InTeam,Player);
		if ( NewRating > BestRating )
		{
			BestRating = NewRating;
			BestStart = N;
		}
	}

	return BestStart;
}

function int FindBotRouteNavIndex(NavigationPoint N)
{
    local int i;

    if (N == None)
        return -1;

    for (i = 0; i < BotRouteNavNodes.Length; i++)
    {
        if (BotRouteNavNodes[i] == N)
            return i;
    }

    return -1;
}

function NavigationPoint FindNearestBotRouteNav(vector Location)
{
    local NavigationPoint N;
    local NavigationPoint Best;
    local float BestDistSq;
    local float DistSq;

    BestDistSq = BOT_ROUTE_INFINITY;

    for (N = Level.NavigationPointList; N != None; N = N.NextNavigationPoint)
    {
        DistSq = (N.Location - Location) Dot (N.Location - Location);
        if (DistSq < BestDistSq)
        {
            BestDistSq = DistSq;
            Best = N;
        }
    }

    return Best;
}

function ClearBotRouteCache()
{
    BotRouteTargets.Length = 0;
    BotRouteTargetNodes.Length = 0;
    BotRouteNavNodes.Length = 0;
    BotRouteDistances.Length = 0;
    BotRouteOrder.Length = 0;
    bBotRouteCacheBuilt = false;
}

function BuildBotRouteDistances()
{
    local int TargetCount;
    local int SourceTarget;
    local int Target;
    local vector Delta;
    local float DistanceSq;

    TargetCount = BotRouteTargets.Length;

    if (TargetCount <= 0)
        return;

    // Do NOT walk the entire navigation graph here.  The previous implementation
    // ran a Dijkstra search over every navigation node for every target and then
    // performed a linear node lookup for every ReachSpec.  On large maps this can
    // take tens of millions of script iterations and look like an infinite loop
    // to the engine watchdog.
    //
    // The veteran route only needs a stable distance ordering between the static
    // landmarks.  Cache their geometric distances once; movement/pathfinding is
    // still handled by the normal bot navigation when the bot travels to a target.
    BotRouteDistances.Length = TargetCount * TargetCount;

    for (SourceTarget = 0; SourceTarget < TargetCount; SourceTarget++)
    {
        for (Target = 0; Target < TargetCount; Target++)
        {
            if (SourceTarget == Target)
            {
                BotRouteDistances[SourceTarget * TargetCount + Target] = 0.0;
                continue;
            }

            if (BotRouteTargets[SourceTarget] == None || BotRouteTargets[Target] == None)
            {
                BotRouteDistances[SourceTarget * TargetCount + Target] = BOT_ROUTE_INFINITY;
                continue;
            }

            Delta = BotRouteTargets[Target].Location - BotRouteTargets[SourceTarget].Location;
            DistanceSq = Delta Dot Delta;

            // Keep the cached value finite.  UnrealScript float overflow is not
            // useful here and could corrupt the route ordering.
            if (DistanceSq >= BOT_ROUTE_INFINITY)
                BotRouteDistances[SourceTarget * TargetCount + Target] = BOT_ROUTE_INFINITY;
            else
                BotRouteDistances[SourceTarget * TargetCount + Target] = DistanceSq;
        }
    }
}

function BuildBotRouteOrder()
{
    local int TargetCount;
    local int Origin;
    local int Rank;
    local int i;
    local int BestIndex;
    local float BestDistance;
    local float CandidateDistance;
    local int MatrixBase;
    local array<byte> Used;

    TargetCount = BotRouteTargets.Length;
    if (TargetCount <= 0)
        return;

    BotRouteOrder.Length = TargetCount * TargetCount;

    for (Origin = 0; Origin < TargetCount; Origin++)
    {
        Used.Length = TargetCount;
        for (i = 0; i < TargetCount; i++)
            Used[i] = 0;

        MatrixBase = Origin * TargetCount;

        // Rank targets from nearest to farthest using the cached path distances.
        // The origin itself is always rank 0.
        for (Rank = 0; Rank < TargetCount; Rank++)
        {
            BestIndex = -1;
            BestDistance = BOT_ROUTE_INFINITY;

            for (i = 0; i < TargetCount; i++)
            {
                if (Used[i] != 0)
                    continue;

                CandidateDistance = BotRouteDistances[MatrixBase + i];
                if (CandidateDistance < BestDistance)
                {
                    BestDistance = CandidateDistance;
                    BestIndex = i;
                }
            }

            if (BestIndex < 0)
            {
                // Keep the table deterministic even for disconnected nodes.
                for (i = 0; i < TargetCount; i++)
                {
                    if (Used[i] == 0)
                    {
                        BestIndex = i;
                        break;
                    }
                }
            }

            if (BestIndex < 0)
                break;

            Used[BestIndex] = 1;
            BotRouteOrder[MatrixBase + Rank] = BestIndex;
        }
    }
}

function BuildBotRouteCache(bool bUseZombieFactories)
{
    local NavigationPoint N;
    local NavigationPoint TargetNode;
    local Actor A;
    local int TargetCount;
    local int NavCount;
    local int idx;

    ClearBotRouteCache();

    // Cache the complete navigation graph once. The graph is static for the map.
    for (N = Level.NavigationPointList; N != None; N = N.NextNavigationPoint)
    {
        if (BotRouteNavNodes.Length >= BOT_ROUTE_MAX_NAV_NODES)
            break;

        BotRouteNavNodes[BotRouteNavNodes.Length] = N;
    }

    NavCount = BotRouteNavNodes.Length;
    if (NavCount <= 0)
    {
        Log("[VeteranRoute] No navigation points found; route cache disabled.");
        return;
    }

    if (bUseZombieFactories)
    {
        // ZombieFactory is intentionally tested by name so this class does not
        // need a hard package dependency on the factory implementation.
        foreach AllActors(class'Actor', A)
        {
            if (A == None || !A.IsA('ZombieFactory'))
                continue;

			idx = SpawnWeaponPickUp( idx, A.Location );

            if (BotRouteTargets.Length >= BOT_ROUTE_MAX_TARGETS)
                break;

            TargetNode = FindNearestBotRouteNav(A.Location);
            if (TargetNode == None)
                continue;

            BotRouteTargets[BotRouteTargets.Length] = A;
            BotRouteTargetNodes[BotRouteTargetNodes.Length] = TargetNode;
        }
    }
    else
    {
        // DeathMatch/CTF: PlayerStarts are the veteran player's known landmarks.
        for (N = Level.NavigationPointList; N != None; N = N.NextNavigationPoint)
        {
            if (BotRouteTargets.Length >= BOT_ROUTE_MAX_TARGETS)
                break;

            if (PlayerStart(N) == None)
                continue;

            if (!PlayerStart(N).bEnabled)
                continue;

			idx = SpawnWeaponPickUp( idx, N.Location );

            BotRouteTargets[BotRouteTargets.Length] = N;
            BotRouteTargetNodes[BotRouteTargetNodes.Length] = N;
        }
    }

    // Some invasion maps may not expose the factory actors at the time InitGame
    // runs. Falling back to PlayerStarts keeps the AI functional rather than
    // disabling veteran wandering entirely.
    if (BotRouteTargets.Length == 0 && bUseZombieFactories)
    {
        for (N = Level.NavigationPointList; N != None; N = N.NextNavigationPoint)
        {
            if (BotRouteTargets.Length >= BOT_ROUTE_MAX_TARGETS)
                break;

            if (PlayerStart(N) == None || !PlayerStart(N).bEnabled)
                continue;

            BotRouteTargets[BotRouteTargets.Length] = N;
            BotRouteTargetNodes[BotRouteTargetNodes.Length] = N;
        }
    }

    TargetCount = BotRouteTargets.Length;
    if (TargetCount <= 0)
    {
        Log("[VeteranRoute] No route targets found; route cache disabled.");
        return;
    }

    BuildBotRouteDistances();
    BuildBotRouteOrder();

    bBotRouteCacheBuilt = (BotRouteOrder.Length == TargetCount * TargetCount);

    Log("[VeteranRoute] Built shared route cache: " $ TargetCount $
        " targets, " $ NavCount $ " navigation nodes.");
}

function bool GetBotWanderTarget(
    Pawn P,
    int CurrentOriginIndex,
    int CurrentRank,
    out Actor Target,
    out NavigationPoint TargetNode,
    out int NewOriginIndex,
    out int NewRank)
{
    local int TargetCount;
    local int i;
    local int NearestIndex;
    local int CandidateIndex;
    local float NearestDistSq;
    local float DistSq;
    local float CachedDistance;

    Target = None;
    TargetNode = None;
    NewOriginIndex = -1;
    NewRank = 0;

    if (!bBotRouteCacheBuilt || P == None)
        return false;

    TargetCount = BotRouteTargets.Length;
    if (TargetCount <= 0)
        return false;

    // Start a fresh veteran route at the target physically closest to the bot.
    if (CurrentOriginIndex < 0 || CurrentOriginIndex >= TargetCount ||
        CurrentRank <= 0 || CurrentRank >= TargetCount)
    {
        NearestIndex = -1;
        NearestDistSq = BOT_ROUTE_INFINITY;

        for (i = 0; i < TargetCount; i++)
        {
            if (BotRouteTargets[i] == None)
                continue;

            DistSq = (BotRouteTargets[i].Location - P.Location) Dot (BotRouteTargets[i].Location - P.Location);
            if (DistSq < NearestDistSq)
            {
                NearestDistSq = DistSq;
                NearestIndex = i;
            }
        }

        if (NearestIndex < 0)
            return false;

        CurrentOriginIndex = NearestIndex;
        CurrentRank = 1;
    }

    // Walk the precomputed ordering from near to far. Skip disconnected targets.
    while (CurrentRank < TargetCount)
    {
        CandidateIndex = BotRouteOrder[
            CurrentOriginIndex * TargetCount + CurrentRank
        ];

        CachedDistance = BotRouteDistances[
            CurrentOriginIndex * TargetCount + CandidateIndex
        ];

        if (CandidateIndex != CurrentOriginIndex &&
            CachedDistance < BOT_ROUTE_INFINITY &&
            BotRouteTargets[CandidateIndex] != None &&
            BotRouteTargetNodes[CandidateIndex] != None)
        {
            Target = BotRouteTargets[CandidateIndex];
            TargetNode = BotRouteTargetNodes[CandidateIndex];
            NewOriginIndex = CurrentOriginIndex;
            NewRank = CurrentRank + 1;
            return true;
        }

        ++CurrentRank;
    }

    // We exhausted this route. Reinitialize from wherever the bot is now.
    NewOriginIndex = -1;
    NewRank = 0;
    return false;
}

//===========================================================================
// DefaultProperties
//===========================================================================

defaultproperties
{
     RedTeamWins(0)=Sound'DOTZXAnnouncer.CTF.CTFRedWon'
     BlueTeamWins(0)=Sound'DOTZXAnnouncer.CTF.CTFBlueWon'
     FiveMinuteWarning(0)=Sound'DOTZXAnnouncer.DeathMatch.DeathMatch5MinWarning01'
     FiveMinuteWarning(1)=Sound'DOTZXAnnouncer.DeathMatch.DeathMatch5MinWarning02'
     FiveMinuteWarning(2)=Sound'DOTZXAnnouncer.DeathMatch.DeathMatch5MinWarning03'
     OneMinuteWarning(0)=Sound'DOTZXAnnouncer.DeathMatch.DeathMatch1MinWarning01'
     OneMinuteWarning(1)=Sound'DOTZXAnnouncer.DeathMatch.DeathMatch1MinWarning02'
     OneMinuteWarning(2)=Sound'DOTZXAnnouncer.DeathMatch.DeathMatch1MinWarning03'
     OneMinuteWarning(3)=Sound'DOTZXAnnouncer.DeathMatch.DeathMatch1MinWarning04'
     YouWin(0)=Sound'DOTZXAnnouncer.DeathMatch.DeathMatchYouWin'
     YouLose(0)=Sound'DOTZXAnnouncer.DeathMatch.DeathMatchYouLose'
     //HUDType="DOTZGame.DOTZDeathMatchHUD"
     HUDType="UMODDOTZGame.UmodDOTZDeathMatchHUD"

     OverridePlayerControllerClass=Class'UMODDOTZGame.UmodPlayerController'

     OverridePawnClass=Class'UMODDOTZGame.UmodPlayerPawn'

	 bBonusSystem=true

}
