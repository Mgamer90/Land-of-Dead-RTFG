class UmodDOTZSurvivor extends DOTZInvasion;

const MIN_BOTS_RATIO = 0.10;
const MAX_BOTS = 3;
const MIN_BOTS = 2;

var int IdealBotsCount;

var int BotsCount;

var config class<Pawn> OverridePawnClass;

var UnrealRepository ModRepo;

// Runaway loop detected (over 1000000 iteration
const MAX_LOOP = 1000000;

// Shared veteran-wander route cache. Built once per level/game mode and reused by all bots.
const BOT_ROUTE_MAX_TARGETS = 64;
const BOT_ROUTE_MAX_NAV_NODES = 768;
const BOT_ROUTE_INFINITY = 999999999.0;

var protected bool bBotInstantRespawn;

var protected array<Actor> BotRouteTargets;
var protected array<NavigationPoint> BotRouteTargetNodes;
var protected array<NavigationPoint> BotRouteNavNodes;
var protected array<float> BotRouteDistances;
var protected array<int> BotRouteOrder;
var protected bool bBotRouteCacheBuilt;

/*******************************************************************
 * Initialize the game.  The GameInfo's InitGame() function is called
 * before any other scripts (including PreBeginPlay() ), and is used
 * by the GameInfo to initialize parameters and spawn its helper
 * classes.  Warning: this is called before actors' PreBeginPlay.
 *******************************************************************
 */
event InitGame(String options, out String error)
{
    local WaveMultiPlayerLevelInfo theWaveMultiPlayerLevelInfo;
    local MultiPlayerLevelInfo theMultiPlayerLevelInfo;

    Super.InitGame(options, error);

    theWaveMultiPlayerLevelInfo = WaveMultiPlayerLevelInfo(Level.GameSpecificLevelInfo);
    if (theWaveMultiPlayerLevelInfo != None)
    {
        InitialWaveSize = theWaveMultiPlayerLevelInfo.InitialWaveSize;
        WaveSizeIncrement = theWaveMultiPlayerLevelInfo.WaveSizeIncrement;
    }
    else
    {
        theMultiPlayerLevelInfo = MultiPlayerLevelInfo(Level.GameSpecificLevelInfo);
        if (theMultiPlayerLevelInfo != None)
        {
            InitialWaveSize = theMultiPlayerLevelInfo.InitialInPlayLimit;
            WaveSizeIncrement = theMultiPlayerLevelInfo.InitialInPlayLimit + 1;
        }
    }

    bFirstWave = true;
    SetMultiTimer(WAVE_TIMER, WAVEDELAY, false);

    IdealBotsCount = InitialWaveSize;
    if (IdealBotsCount > MAX_BOTS)
        IdealBotsCount = MAX_BOTS;
    else if (IdealBotsCount < MIN_BOTS)
        IdealBotsCount = MIN_BOTS;

    GoalScore = -1;

    ModRepo = new class'UMODDOTZGame.UnrealRepository';

    if (ModRepo != None)
    {
		OverridePlayerControllerClass = class<PlayerController>(DynamicLoadObject(ModRepo.InvasionPlayerControllerClassName, class'Class'));

	   if (OverridePlayerControllerClass == none)
	   {OverridePlayerControllerClass = class<PlayerController>(DynamicLoadObject(ModRepo.PlayerControllerClassName, class'Class'));}

	   if (OverridePlayerControllerClass != none){PlayerControllerClass = OverridePlayerControllerClass;}

		OverridePawnClass = class<Pawn>(DynamicLoadObject(ModRepo.InvasionPawnClassName, class'Class'));

	   if (OverridePawnClass == none)
	   {OverridePawnClass = class<Pawn>(DynamicLoadObject(ModRepo.PlayerPawnClassName, class'Class'));}

	   if (OverridePawnClass == none)
	   {OverridePawnClass = class<Pawn>(DynamicLoadObject(DefaultPlayerClassName, class'Class'));}
    }
    //DestroyAllBotsControllers();

	//ModRepo.SaveConfig();
	
    BuildBotRouteCache(true);
}

/*****************************************************************
 * InitGameReplicationInfo
 * Something just for invasion so the switc teams stuff doesn't come
 * up in the menu
 *****************************************************************
 */
function InitGameReplicationInfo()
{
    Super.InitGameReplicationInfo();

    if (GameReplicationInfo != None)
    {
        GameReplicationInfo.bAllowedToSwitchTeams = false;
        GameReplicationInfo.MatchID = ID_INV;
    }
}

/*****************************************************************
 * PickTeam
 * When starting a team match we assing teams alternately to each
 * side based upon order of entry.
 *****************************************************************
 */
function byte PickTeam(byte Current, Controller C)
{
   return 0;
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
				//BotToBeKicked.Destroy();
				
				break;
			}
		}
	}

	return Super.Login(Portal, Options, Error);
}

/*****************************************************************
 * RestartPlayer
 *****************************************************************
 */
function RestartPlayer( Controller c )
{
	local PlayerController thePlayerController;

   thePlayerController = PlayerController(c);
   if (thePlayerController != none && thePlayerController.CanRestartPlayer())
   {
      super.RestartPlayer(c);

      thePlayerController.PlayerReplicationInfo.bOnlySpectator = true;
   }
}

//event PlayerController Login(string Portal,string Options,out string Error){
//   super.Login(Portal,Options,Error);
//   log(self $ " " $ NumPlayers $ " : " $ MaxPlayers);
//}


/*****************************************************************
 * PostLogin
 *****************************************************************
 */
event PostLogin(PlayerController NewPlayer)
{
    Super.PostLogin(NewPlayer);

    if (NewPlayer != None && NewPlayer.PlayerReplicationInfo != None)
        NewPlayer.PlayerReplicationInfo.bOnlySpectator = false;
}

/*****************************************************************
 * StartWave
 *****************************************************************
 */
function StartWave()
{
    local Controller P;
    local int i;
    local int WaveBotsNeeded;

    if (bGameEnded)
        return;

    WaveSize = InitialWaveSize + (WaveSizeIncrement * NumWaves);
    WaveRemaining = WaveSize;
    NumWaves++;

    BotsCount = 0;
    for (P = Level.ControllerList; P != None; P = P.NextController)
    {
        if (P.IsA('PlayerController') || P.IsA('UmodBotController'))
            BotsCount++;
    }

    IdealBotsCount = int(WaveSize * MIN_BOTS_RATIO);

    if (IdealBotsCount > MAX_BOTS)
        IdealBotsCount = MAX_BOTS;
    else if (IdealBotsCount < MIN_BOTS)
        IdealBotsCount = MIN_BOTS;

    WaveBotsNeeded = IdealBotsCount - BotsCount;

    if (WaveBotsNeeded > 0 && WaveBotsNeeded < MAX_BOTS)
    {
		for (i = 0; i < WaveBotsNeeded; i++)
		{
			P = SpawnBot(WaveBotsNeeded+i);
			if (P == None)
			{
				Log("UmodDOTZInvasion: failed to spawn bot " $ i);
			}
		}
    }

    if (!bGameEnded)
        GlobalAnnouncement(NewWave);

    for (P = Level.ControllerList; P != None; P = P.NextController)
    {
        if (bGameEnded)
            return;

        if (P == None || P.PlayerReplicationInfo == None)
            continue;

        P.PlayerReplicationInfo.bOnlySpectator = false;

        if (P.IsA('PlayerController'))
        {
            if (P.Pawn == None || P.Pawn.Health <= 0)
                RestartPlayer(P);
        }
        else if (P.IsA('UmodBotController'))
        {
            if (P.Pawn == None || P.Pawn.Health <= 0)
                RestartBot(P);
        }
    }

    TriggerEvent('NEW_WAVE', self, None);

    if (GameReplicationInfo != None &&
        ArrayCount(GameReplicationInfo.Teams) > 0 &&
        GameReplicationInfo.Teams[0] != None)
    {
        GameReplicationInfo.Teams[0].Score += 1;
    }

    bFirstWave = false;
}

/*****************************************************************
 * WaveComplete
 *****************************************************************
 */
function WaveComplete()
{
   SetMultiTimer(WAVE_TIMER, 12, false);
   SetMultiTimer(ANNOUNCE_DELAY, 2, false);
}

/*****************************************************************
 * EndGameAnnouncement
 * Instead of the normal 'you win' 'you lose' crap, just say
 * game over, cause you always lose eventually
 *****************************************************************
 */
function EndGameAnnouncement(PlayerReplicationInfo Winner)
{
    local Controller P;

    for (P = Level.ControllerList; P != None; P = P.NextController)
    {
        if (P != None && P.PlayerReplicationInfo != None && P.IsA('PlayerController'))
            P.PlayerReplicationInfo.bOnlySpectator = false;
    }

    SetMultiTimer(WAVE_TIMER, 0, false);
    SetMultiTimer(ANNOUNCE_DELAY, 0, false);
    GlobalAnnouncement(GameOver);

    if (GameReplicationInfo != None)
        GameReplicationInfo.bMatchHasBegun = false;
}

/*****************************************************************
 * TooManyBots
 * Coopted this function for use with the Multiplayer creation policy
 * in the opponent factory, so we can globally limit the number of monsters
 *****************************************************************
 */

function bool TooManyBots(Controller botToRemove)
{
   local int CurrentInPlayLimit;

   if (WaveRemaining > 0)
   {
	   CurrentInPlayLimit = InitialInPlayLimit + ((NumPlayers - 1.0) * PerPlayerInPlayLimitModifier);
	   CurrentInPlayLimit = Min(CurrentInPlayLimit, MaxInPlayLimit);
	   CurrentInPlayLimit = Max(CurrentInPlayLimit, MinInPlayLimit);
	   if (NumBots >= CurrentInPlayLimit){ return true; }

      //return super.TooManyBots(BotToRemove);
   }
   else
   {
      return true;
   }
}

/*****************************************************************
 * NotifyAddBot
 *****************************************************************
 */
function NotifyAddBot()
{
    if (WaveRemaining > 0)
        WaveRemaining--;

    WaveInPlay++;
    Super.NotifyAddBot();
}

/*****************************************************************
 * NotifyRemoveBot
 *****************************************************************
 */
function NotifyRemoveBot()
{
    if (WaveInPlay > 0)
        WaveInPlay--;

    Super.NotifyRemoveBot();

    if (!bGameEnded && WaveRemaining <= 0 && WaveInPlay <= 0)
        WaveComplete();
}

/*****************************************************************
 * MultiTimer
 *****************************************************************
 */
function MultiTimer(int SlotID){
   switch(SlotID){
      case WAVE_TIMER:
         StartWave();
         break;

      case ANNOUNCE_DELAY:
         if (GameReplicationInfo.bMatchHasBegun == true){
            GlobalAnnouncement(WaveCompleted);
         }

      default:
         super.MultiTimer(SlotID);
   }
}

/*****************************************************************
 * Killed
 *****************************************************************
 */
function Killed(Controller Killer, Controller Killed, Pawn KilledPawn, class<DamageType> damageType)
{
    local bool bAllDead;
    local Controller P;

    bAllDead = true;
    Super.Killed(Killer, Killed, KilledPawn, damageType);

    for (P = Level.ControllerList; P != None; P = P.NextController)
    {
        if (P == None || P.Pawn == None || P.Pawn.Health <= 0)
            continue;

        if (P.IsA('PlayerController') || P.IsA('UmodBotController'))
        {
            bAllDead = false;
            break;
        }
    }

    if (bAllDead)
        EndGame(None, "Everyone is dead");
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
    local int iNewBots;
    local PlayerReplicationInfo KillerPRI;
    local PlayerReplicationInfo OtherPRI;

    if (bBotInstantRespawn)
    {
		BotsCount = 0;

		for (P = Level.ControllerList; P != None; P = P.NextController)
		{
			if (P.IsA('PlayerController'))
			{
				BotsCount++;

				//if (P.Pawn == None || P.Pawn.Health < 1)
				//	RestartBot(P);
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
					Log("UmodDOTZInvasion: failed to spawn bot " $ i);
			}
		}
    }

	iBonus = 1;

	if (Killer != None)
	{
		KillerPRI = Killer.PlayerReplicationInfo;

		if (KillerPRI != None)
		{
			if (KillerPRI.Kills > 5)
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

			KillerPRI.Score += (iBonus * 1);

			GiveDefaultInventoryBonus(Killer.Pawn, KillerPRI.Kills);

			KillerPRI.Kills++;
			ScoreEvent(KillerPRI, KillerPRI.Score, "frag");
		}
	}
	else if (Other != None)
	{
		OtherPRI = Other.PlayerReplicationInfo;

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

/* CheckScore()
see if this score means the game ends
*/
function CheckScore_BKP(PlayerReplicationInfo Scorer)
{
	if ( (GameRulesModifiers != None) && GameRulesModifiers.CheckScore(Scorer) )
		return;
}

function ScoreEvent_BKP(PlayerReplicationInfo Who, float Points, string Desc)
{
	if (GameStats!=None)
		GameStats.ScoreEvent(Who,Points,Desc);
}

function TeamScoreEvent_BKP(int Team, float Points, string Desc)
{
	if ( GameStats != None )
		GameStats.TeamScoreEvent(Team, Points, Desc);
}

function Logout(Controller Exiting)
{
    local PlayerController PC;

    PC = PlayerController(Exiting);
    if (PC != None && PC.PlayerReplicationInfo != None && PC.PlayerReplicationInfo.bOnlySpectator)
        NumPlayers--;

    Super.Logout(Exiting);
}

function class<Pawn> GetDefaultPlayerClass(Controller C)
{
    local PlayerController PC;
    local String PawnClassName;
    local class<Pawn> PawnClass;

    if( OverridePawnClass != None )
	{
        return OverridePawnClass;
	}

    PC = PlayerController( C );

    if( PC != None )
	{
        PawnClassName = PC.GetDefaultURL( "Class" );
        PawnClass = class<Pawn>( DynamicLoadObject( PawnClassName, class'Class') );

        if( PawnClass != None )return( PawnClass );
	}

    return( class<Pawn>( DynamicLoadObject( DefaultPlayerClassName, class'Class' ) ) );
}

//
// Restart a player.
//
function RestartPlayer2( Controller aPlayer )
{
	local NavigationPoint startSpot;
	local int TeamNum;
	local class<Pawn> DefaultPlayerClass;

	if( bRestartLevel && Level.NetMode!=NM_DedicatedServer && Level.NetMode!=NM_ListenServer )
		return;

	if ( (aPlayer.PlayerReplicationInfo == None) || (aPlayer.PlayerReplicationInfo.Team == None) )
		TeamNum = 255;
	else
		TeamNum = aPlayer.PlayerReplicationInfo.Team.TeamIndex;

	startSpot = FindPlayerStart(aPlayer, TeamNum);
	if( startSpot == None )
	{
		log(" Player start not found!!!");
		return;
	}

	if (aPlayer.PreviousPawnClass!=None && aPlayer.PawnClass != aPlayer.PreviousPawnClass)
		BaseMutator.PlayerChangedClass(aPlayer);

	if ( aPlayer.PawnClass != None )
		aPlayer.Pawn = Spawn(aPlayer.PawnClass,,,StartSpot.Location,StartSpot.Rotation);

	if( aPlayer.Pawn==None )
	{
        DefaultPlayerClass = GetDefaultPlayerClass(aPlayer);
		aPlayer.Pawn = Spawn(DefaultPlayerClass,,,StartSpot.Location,StartSpot.Rotation);
	}
	if ( aPlayer.Pawn == None )
	{
		log("Couldn't spawn player of type "$aPlayer.PawnClass$" at "$StartSpot);
		aPlayer.GotoState('Dead');
		return;
	}

    aPlayer.Pawn.Anchor = startSpot;
	aPlayer.Pawn.LastStartSpot = PlayerStart(startSpot);
	aPlayer.Pawn.LastStartTime = Level.TimeSeconds;
	aPlayer.PreviousPawnClass = aPlayer.Pawn.Class;

	aPlayer.Possess(aPlayer.Pawn);
	aPlayer.PawnClass = aPlayer.Pawn.Class;

    aPlayer.Pawn.PlayTeleportEffect(true, true);
	aPlayer.ClientSetRotation(aPlayer.Pawn.Rotation);
	AddDefaultInventory(aPlayer.Pawn);
	TriggerEvent( StartSpot.Event, StartSpot, aPlayer.Pawn);
}

//
// Spawn any default inventory for the player.
//
function AddDefaultInventory( pawn PlayerPawn )
{
	local Weapon newWeapon;
	local class<Weapon> WeapClass;
	local int num, idx;

	// if (!PlayerPawn.IsA('PlayerPawnBase')){return;}
	
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
			if(bBotInstantRespawn && PlayerPawn.IsA('UmodHumanPawn'))
			{
				num = ModRepo.PrimaryWeaponNameList.Length;

				if (num > 0)
				{
					idx = Rand(num);

					WeapClass = class<Weapon>(DynamicLoadObject(ModRepo.PrimaryWeaponNameList[idx], class'Class'));
				}
			}
			else if(!PlayerPawn.IsA('UmodHumanPawn'))
			{
				//WeapClass = class<Weapon>(DynamicLoadObject("DEWeapons.ColtWeapon", class'Class'));
				WeapClass = class<Weapon>(DynamicLoadObject("DEWeapons2.RaptorWeapon", class'Class'));

				if(WeapClass == None)
				{
					num = ModRepo.PrimaryWeaponNameList.Length;

					if (num > 0)
					{
						idx = Rand(num);

						WeapClass = class<Weapon>(DynamicLoadObject(ModRepo.PrimaryWeaponNameList[idx], class'Class'));
					}
				}
			}
			else
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

/*****************************************************************
 * GiveDefaultInventory
 *****************************************************************
 */
function GiveDefaultInventory3(Pawn P){
   AdvancedPawn(P).SetInventoryLimit(1,'MeleeWeapon');
   AdvancedPawn(P).SetInventoryLimit(1,'GlockWeapon');
   AdvancedPawn(P).SetInventoryLimit(1,'M16Weapon');
   AdvancedPawn(P).SetInventoryLimit(1,'RevolverWeapon');
   AdvancedPawn(P).SetInventoryLimit(1,'RifleWeapon');
   AdvancedPawn(P).SetInventoryLimit(1,'ShotgunWeapon');
   AdvancedPawn(P).SetInventoryLimit(1,'SniperWeapon');
   AdvancedPawn(P).SetInventoryLimit(1,'GrenadeWeapon');
   AdvancedPawn(P).SetInventoryLimit(1,'MolotovWeapon');
   Log("Giving Weapon to the player");
   P.GiveWeapon(DefaultInventory);
}

function int SpawnWeaponPickUp( int idx, vector inLocation )
{
	local Pickup newPickup;
	local class<Pickup> PickupClass;
	local int i;

	if(ModRepo != None && ModRepo.AllWeaponPickupClassList.Length > 0)
	{
		if(idx < ModRepo.AllWeaponPickupClassList.Length)
		{
			PickupClass = class<Pickup>(DynamicLoadObject(ModRepo.AllWeaponPickupClassList[idx], class'Class'));

			if(PickupClass == None)
			{
				for(i = idx; i < ModRepo.AllWeaponPickupClassList.Length; i++)
				{
					PickupClass = class<Pickup>(DynamicLoadObject(ModRepo.AllWeaponPickupClassList[i], class'Class'));
					
					if(PickupClass != None)
					{
						idx = i;
						break;
					}
				}
			}

			if(PickupClass != None)
			{
				inLocation.Z = inLocation.Z - 75.0;
				newPickup = Spawn(PickupClass,,,inLocation);
				idx++;
			}
		}
	}

	return idx;
}

/*****************************************************************
 * GiveDefaultInventory
 *****************************************************************
 */
function GiveDefaultInventoryBonus(Pawn P, int BonusID)
{
	local string newWeaponName;
	local Weapon newWeapon;
	local class<Weapon> WeapClass;
	local string newPickupName;
	local Pickup newPickup;
	local class<Pickup> newPickupClass;
	local vector newLocation;
	local int inIndex;

	if(ModRepo != None)
	{
		if(P != None && P.Health > 0)
		{
			for(inIndex = 0; inIndex < ModRepo.RewardList.length; inIndex++)
			{
				if(ModRepo.RewardList[inIndex].Points == BonusID )
				{
					newWeaponName = ModRepo.RewardList[inIndex].InventoryName;
					newPickupName = ModRepo.RewardList[inIndex].ExtraName;

					if(ModRepo.RewardList[inIndex].PlayersOnly && P.IsA('UmodHumanPawn') )
					{
						return;
					}

					break;
				}
			}

			WeapClass = class<Weapon>(DynamicLoadObject(newWeaponName, class'Class'));

			if(WeapClass != None)
			{
				if(P.FindInventoryType(WeapClass) == None)
				{
					if ( P.IsA('PlayerPawnBase') )
					{
						newWeapon = Spawn(WeapClass,,,P.Location);

						if( newWeapon != None )
						{
							newWeapon.GiveTo(P);
							newWeapon.BringUp();
						}
					}
					else if ( P.IsA('UmodHumanPawn') )
					{
						if(P.Weapon != None){P.Weapon.DropFrom(P.Location);}

						P.GiveWeapon(newWeaponName);
					}
				}
			}

			newPickupClass = class<Pickup>(DynamicLoadObject(newPickupName, class'Class'));

			if(newPickupClass != None)
			{
				newLocation = P.Location;
				newLocation.Z = newLocation.Z - 75.0;

				newPickup = spawn(newPickupClass,,,newLocation);
				

				if(newPickup != None)
				{
					P.HandlePickup(newPickup);
				}
			}
		}
	}
}

function AddDefaultInventoryBonus( pawn PlayerPawn )
{
	local Weapon newWeapon;
	local class<Weapon> WeapClass;

	if( PlayerPawn != None)
	{
		// Spawn default weapon.
		// if(BaseMutator!=None)
		// 	WeapClass = BaseMutator.GetDefaultWeapon();
		// else
			WeapClass = class<Weapon>(DynamicLoadObject("DOTZWeapons.KungFuWeapon", class'Class'));

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
		SetPlayerDefaults(PlayerPawn);
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

    if (ModRepo != None && ModRepo.InvasionBotControllerClass != None)
        NewBot = Spawn(ModRepo.InvasionBotControllerClass,,,StartSpot.Location,StartSpot.Rotation);
    else
        NewBot = Spawn(class'UMODDOTZGame.UmodBotControllerInvasion',,,StartSpot.Location,StartSpot.Rotation);

    if (NewBot != None)
    {
		NewBot.StartSpot = StartSpot;
		NewUmodBot = UmodBotController(NewBot);

		if (NewUmodBot != None)
		{
			NewUmodBot.GameReplicationInfo = GameReplicationInfo;
			NewUmodBot.bCoopGameMode = true;
			NewUmodBot.bBotInstantRespawn = bBotInstantRespawn;
		}

		NewBot.GotoState('Spectating');

		if (ModRepo != None)
		{
			/*BotClassCount = ArrayCount(ModRepo.InvasionBotPawnClassNameList);
			if (BotClassCount <= 0)
			{
				NewBotPawnClassName = "UMODDOTZGame.UmodHumanOtis";
			}
			else
			{
				if (inIndex < 0 || inIndex >= BotClassCount)
					inIndex = Rand(BotClassCount);

				NewBotPawnClassName = ModRepo.InvasionBotPawnClassNameList[inIndex];
			}*/

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

		if (NewBot.PlayerReplicationInfo != None)
		{
			if (bSpectator || NewBot.PlayerReplicationInfo.bOnlySpectator)
			{
				NewBot.PlayerReplicationInfo.bOnlySpectator = true;
				NewBot.PlayerReplicationInfo.bIsSpectator = true;
				NewBot.PlayerReplicationInfo.bOutOfLives = true;
				NumSpectators++;
				return NewBot;
			}

			/*if (!ChangeTeam(NewBot, InTeam, false))
			{
				Error = GameMessageClass.Default.FailedTeamMessage;
				NewBot.Destroy();
				return None;
			}*/

			NewBot.PlayerReplicationInfo.PlayerID = CurrentID++;
			if (NewBot.PlayerReplicationInfo.Team != None)
				NewBot.PlayerReplicationInfo.Team.TeamIndex = InTeam;
		}

		NumPlayers++;
		bWelcomePending = true;

		if (bDelayedStart)
			NewBot.GotoState('PlayerWaiting');

		return NewBot;
	}

	Log("Couldn't spawn Bot controller of class " $ ModRepo.InvasionBotControllerClass);
	Error = GameMessageClass.Default.FailedSpawnMessage;
	return None;
}

//
// Restart a Bot.
//
function RestartBot(Controller aPlayer)
{
    local NavigationPoint StartSpot;
    local int TeamNum;
    local Pawn OldPawn;
    local Pawn NewPawn;
    local int i;

    if (aPlayer != None)
    {
		if (aPlayer.PlayerReplicationInfo != None)
		{
			if (aPlayer.PlayerReplicationInfo.Team == None)
				TeamNum = PickTeam(0, None);
			else
				TeamNum = aPlayer.PlayerReplicationInfo.Team.TeamIndex;

			for (i = 0; i < BotRouteTargets.Length; i++)
			{
				StartSpot = NavigationPoint(BotRouteTargets[i]);

				if (StartSpot != None){break;}
			}

			//StartSpot = FindPlayerStart(aPlayer, TeamNum);
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
    local ZombieFactory ZF;
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
        foreach AllActors(class'ZombieFactory', ZF)
        {
            if (ZF != None)
			{
				idx = SpawnWeaponPickUp( idx, ZF.Location );

				if (!bBotInstantRespawn && ZF.TheCreationPolicy != None && !ZF.TheCreationPolicy.IsA('MultiplayerPolicy'))
				{
					bBotInstantRespawn = true;
				}

				if (BotRouteTargets.Length >= BOT_ROUTE_MAX_TARGETS)
					break;

				TargetNode = FindNearestBotRouteNav(ZF.Location);
				if (TargetNode == None)
					continue;
	 
				BotRouteTargets[BotRouteTargets.Length] = ZF;
				BotRouteTargetNodes[BotRouteTargetNodes.Length] = TargetNode;
			}
        }

		// Some invasion maps may not expose the factory actors at the time InitGame
		// runs. Falling back to PlayerStarts keeps the AI functional rather than
		// disabling veteran wandering entirely.
		if (BotRouteTargets.Length == 0)
		{
			for (N = Level.NavigationPointList; N != None; N = N.NextNavigationPoint)
			{
				if (BotRouteTargets.Length >= BOT_ROUTE_MAX_TARGETS)
					break;

				if (PlayerStart(N) == None || !PlayerStart(N).bEnabled)
					continue;

				idx = SpawnWeaponPickUp( idx, N.Location );

				BotRouteTargets[BotRouteTargets.Length] = N;
				BotRouteTargetNodes[BotRouteTargetNodes.Length] = N;
			}
		}
    }
    else
    {
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
// defaultproperties
//===========================================================================

defaultproperties
{
     NewWave(0)=Sound'DOTZXAnnouncer.Invasion.InvasionNewWave01'
     NewWave(1)=Sound'DOTZXAnnouncer.Invasion.InvasionNewWave02'
     NewWave(2)=Sound'DOTZXAnnouncer.Invasion.InvasionNewWave03'
     NewWave(3)=Sound'DOTZXAnnouncer.Invasion.InvasionNewWave04'
	 
     WaveCompleted(0)=Sound'DOTZXAnnouncer.Invasion.InvasionWaveComplete01'
     WaveCompleted(1)=Sound'DOTZXAnnouncer.Invasion.InvasionWaveComplete02'
     WaveCompleted(2)=Sound'DOTZXAnnouncer.Invasion.InvasionWaveComplete03'
	 
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
	 
     bRestartLevel=False
     bTeamGame=True
     bDelayedStart=True

     HUDType="DOTZGame.DOTZInvasionHUD"
     //HUDType="UMODDOTZGame.UmodDOTZInvasionHUD"

     OverridePlayerControllerClass=Class'UMODDOTZGame.UmodPlayerController'

     OverridePawnClass=Class'UMODDOTZGame.UmodPlayerPawn'

     bBotInstantRespawn=False

     // OverridePlayerControllerClass=Class'DOTZEngine.DOTZPlayerController'
     // DefaultInventory="DOTZWeapons.FistWeapon"
     // MutatorClass="Engine.Mutator"
     // AccessControlClass="Engine.AccessControl"
     // BroadcastHandlerClass="Engine.BroadcastHandler"
     // PlayerControllerClassName="Engine.PlayerController"
     // GameReplicationInfoClass=Class'Engine.GameReplicationInfo'
     // GameStatsClass="Engine.GameStats"
     // SecurityClass="Engine.Security"

}
