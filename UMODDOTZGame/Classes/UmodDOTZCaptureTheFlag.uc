class UmodDOTZCaptureTheFlag extends DOTZCaptureTheFlag;

const MIN_BOTS_RATIO = 0.10;
const MAX_BOTS = 6;
const MIN_BOTS = 2;
const MAX_BOTS_CLASS = 16;

var int IdealBotsCount;

var int BotsCount;

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
		OverridePlayerControllerClass = class<PlayerController>(DynamicLoadObject(ModRepo.CaptureTheFlagPlayerControllerClassName, class'Class'));

	   if (OverridePlayerControllerClass == none)
	   {OverridePlayerControllerClass = class<PlayerController>(DynamicLoadObject(ModRepo.PlayerControllerClassName, class'Class'));}

	   if (OverridePlayerControllerClass != none){PlayerControllerClass = OverridePlayerControllerClass;}

		OverridePawnClass = class<Pawn>(DynamicLoadObject(ModRepo.CaptureTheFlagPawnClassName, class'Class'));

	   if (OverridePawnClass == none)
	   {OverridePawnClass = class<Pawn>(DynamicLoadObject(ModRepo.PlayerPawnClassName, class'Class'));}

	   if (OverridePawnClass == none)
	   {OverridePawnClass = class<Pawn>(DynamicLoadObject(DefaultPlayerClassName, class'Class'));}
    }


   // TO DO: in CaptureTheFlag the bots objectives are different:
   //1. capture the enemy flag and bring to our base.
   //2. kill the enemy stealing our flag
   //Flag factory and PlayerStarts are placed inside the team's base. Any ZombieFactory is irrelevant now!

   // Additional info:
   //FLAG SPAWNER CLASS: DOTZCTFBase EXTENDS ACTOR
   //TeamType = DOTZCTFBase.TeamType==TT_BLUE || DOTZCTFBase.TeamType==TT_RED;
   //myFlag = CTFFlag(DOTZCTFBase.myFlag);
   //BlueFlagType=CTFFlag(DOTZCTFBase.BlueFlagType)
   //RedFlagType=CTFFlag(DOTZCTFBase.RedFlagType)

   //FLAG CLASS: Flag = CTFFlag(PlayerReplicationInfo.HasFlag);
   //HomeBase = CTFBase(Flag.HomeBase);
   //TeamType = int(Flag.TeamType);
   //Team = TeamInfo(Flag.Team);
   //OldHolder = Pawn(Flag.OldHolder);

   BuildBotRouteCache(false);
}

/*****************************************************************
 * PostBeginPlay
 *****************************************************************
 */

function PostBeginPlay()
{
    local Controller P;
    local int i;
    local int BotsCount;
    local int iNewBots;

    Super.PostBeginPlay();
    SetTeamFlags();

    BotsCount = 0;
    for (P = Level.ControllerList; P != None; P = P.NextController)
    {
        if (P.IsA('UmodBotController'))
            BotsCount++;
    }

    if (BotsCount < 4)
    {
        iNewBots = 4 - BotsCount;
        for (i = 0; i < iNewBots; i++)
        {
            P = SpawnBot(i);
            if (P != None)
                RestartBot(P);
        }
    }
}

function Pawn FindTheEnemyWithFlag(Controller Requester, TeamInfo inTeam)
{
    local Controller P;
    local CTFFlag theFlag;

    /*for (P = Level.ControllerList; P != None; P = P.NextController)
    {
        if (!Requester.SameTeamAs(P) && P.PlayerReplicationInfo != None && P.PlayerReplicationInfo.HasFlag != None)
		{
			theFlag = CTFFlag(P.PlayerReplicationInfo.HasFlag);

			if (theFlag != None && theFlag.Team != inTeam)
				return P.Pawn;
		}
    }*/

	return None;
}

/*****************************************************************
 * SetTeamFlags
 *****************************************************************
 */
function SetTeamFlags()
{
    local CTFFlag F;

    if (GameReplicationInfo == None)
        return;

    foreach AllActors(Class'CTFFlag', F)
    {
        if (F == None)
            continue;

        if (F.TeamType < 0 || F.TeamType >= ArrayCount(GameReplicationInfo.Teams))
            continue;

        if (GameReplicationInfo.Teams[F.TeamType] == None)
            continue;

        F.Team = GameReplicationInfo.Teams[F.TeamType];
        F.Team.HomeBase = F.HomeBase;
    }
}

/*****************************************************************
 * ScoreKill
 *****************************************************************
 */
/*****************************************************************
 * ScoreKill
 *****************************************************************
 */
function ScoreKill(Controller Killer, Controller Other)
{
    local Controller P;
    local int i;
    local int BotsCount;
    local int iNewBots;
    local PlayerReplicationInfo KillerPRI;
    local PlayerReplicationInfo OtherPRI;

    BotsCount = 0;
    for (P = Level.ControllerList; P != None; P = P.NextController)
    {
        if (P.IsA('UmodBotController'))
        {
            BotsCount++;
            if (P.Pawn == None || P.Pawn.Health < 1)
                RestartBot(P);
        }
    }

    if (BotsCount < 4)
    {
        iNewBots = 4 - BotsCount;
        for (i = 0; i < iNewBots; i++)
        {
            P = SpawnBot(i);
            if (P != None)
                RestartBot(P);
        }
    }

    KillerPRI = None;
    OtherPRI = None;
    if (Killer != None)
        KillerPRI = Killer.PlayerReplicationInfo;
    if (Other != None)
        OtherPRI = Other.PlayerReplicationInfo;

    if (KillerPRI != None && OtherPRI != None && KillerPRI.Team != None && OtherPRI.Team != None)
    {
        if (KillerPRI.Team.TeamIndex != OtherPRI.Team.TeamIndex)
            KillerPRI.Kills++;
    }
}

/*****************************************************************
 * Killed
 * Monitor killed messages for fraglimit
 *****************************************************************
 */
//function Killed( Controller Killer, Controller Killed, Pawn KilledPawn, class<DamageType> damageType )
//{
   //super.Killed(Killer, Killed, KilledPawn, damageType);
   //CheckScore(Killer.PlayerReplicationInfo);
//}

/*****************************************************************
 * DiscardInventory
 *****************************************************************
 */
function DiscardInventory(Pawn Other)
{
    local CTFFlag Flag;

    if (Other != None)
    {
		if (Other.PlayerReplicationInfo != None && Other.PlayerReplicationInfo.HasFlag != None)
		{
			Flag = CTFFlag(Other.PlayerReplicationInfo.HasFlag);
			if (Flag != None)
				Flag.Drop(0.5 * Other.Velocity);

		}
    }

    Super.DiscardInventory(Other);
}

/*****************************************************************
 * Logout
 *****************************************************************
 */
function Logout(Controller Exiting)
{
    local CTFFlag Flag;

    if (Exiting != None)
    {
		if (Exiting.PlayerReplicationInfo != None && Exiting.PlayerReplicationInfo.HasFlag != None)
		{
			Flag = CTFFlag(Exiting.PlayerReplicationInfo.HasFlag);
			if (Flag != None)
				Flag.Drop(vect(0,0,0));

		}
    }

    Super.Logout(Exiting);
}

/*****************************************************************
 * ScoreObjective
 *****************************************************************
 */
function ScoreObjective(PlayerReplicationInfo Scorer, Int Score)
{
    local int TeamNum;

    if (Scorer == None || Scorer.Team == None)
        return;

    TeamNum = Scorer.Team.TeamIndex;
    Super.ScoreObjective(Scorer, Score);
    Scorer.Score += Score;

    if (TeamNum == 0)
    {
        TeamAnnounce(0, RedTeamScores);
        TeamAnnounce(1, RedTeamScores);
    }
    else
    {
        TeamAnnounce(0, BlueTeamScores);
        TeamAnnounce(1, BlueTeamScores);
    }
}

/*****************************************************************
 * InitGameReplicationInfo
 * Set up data that players will use
 *****************************************************************
 */
function InitGameReplicationInfo()
{
    Super.InitGameReplicationInfo();

    if (GameReplicationInfo != None)
        GameReplicationInfo.MatchID = ID_CTF;
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
    StartSpot = FindBotStart(None, InTeam, Portal);

    if (StartSpot == None)
    {
        Error = GameMessageClass.Default.FailedPlaceMessage;
        return None;
    }

    if (ModRepo == None || ModRepo.CaptureTheFlagBotControllerClass == None)
        return None;

    NewBot = Spawn(ModRepo.CaptureTheFlagBotControllerClass,,,StartSpot.Location,StartSpot.Rotation);

    if (NewBot == None)
    {
        NewBot = Spawn(Class'UMODDOTZGame.UmodBotControllerCaptureTheFlag',,,StartSpot.Location,StartSpot.Rotation);
    }

    if (NewBot == None)
    {
        Log("Couldn't spawn Bot controller of class " $ ModRepo.CaptureTheFlagBotControllerClass);
        Error = GameMessageClass.Default.FailedSpawnMessage;
        return None;
    }

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

    BotClassCount = ModRepo.BotPawnClassNameList.Length;
    if (BotClassCount <= 0)
    {
        NewBot.Destroy();
        return None;
    }

    if (inIndex < 0 || inIndex >= BotClassCount)
        inIndex = Rand(BotClassCount);

    NewBotPawnClassName = ModRepo.BotPawnClassNameList[inIndex];
    if (NewBotPawnClassName == "")
        NewBotPawnClassName = "UMODDOTZGame.UmodHumanPawn";

    NewBot.SetPawnClass(NewBotPawnClassName, InCharacter);

    NumPlayers++;
    bWelcomePending = true;

    if (bDelayedStart)
        NewBot.GotoState('PlayerWaiting');

    return NewBot;
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

    if (aPlayer == None)
        return;

    if (aPlayer.PlayerReplicationInfo == None || aPlayer.PlayerReplicationInfo.Team == None)
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

	foreach AllActors(class'Actor', A)
	{
		// if (A == None || (!A.IsA('DOTZCTFBase') || !A.IsA('PlayerStart')))
		if (A == None || !A.IsA('PlayerStart'))
			continue;

		if (BotRouteTargets.Length >= BOT_ROUTE_MAX_TARGETS)
			break;

		TargetNode = FindNearestBotRouteNav(A.Location);
		if (TargetNode == None)
			continue;

		BotRouteTargets[BotRouteTargets.Length] = A;
		BotRouteTargetNodes[BotRouteTargetNodes.Length] = TargetNode;
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
    local PlayerStart TargetPlayerStart;
    local int PlayerTeamIndex;

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
		
		PlayerTeamIndex = P.PlayerReplicationInfo.Team.TeamIndex;

        for (i = 0; i < TargetCount; i++)
        {
            if (BotRouteTargets[i] == None)
                continue;

			TargetPlayerStart = PlayerStart(BotRouteTargets[i]);

            if (TargetPlayerStart == None || TargetPlayerStart.TeamNumber == PlayerTeamIndex)
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
     RedTeamScores(0)=Sound'DOTZXAnnouncer.CTF.CTFRedScore01'
     RedTeamScores(1)=Sound'DOTZXAnnouncer.CTF.CTFRedScore02'
     BlueTeamScores(0)=Sound'DOTZXAnnouncer.CTF.CTFBlueScore01'
     BlueTeamScores(1)=Sound'DOTZXAnnouncer.CTF.CTFBlueScore02'
     RedTeamTakesLead(0)=Sound'DOTZXAnnouncer.CTF.CTFRedLead'
     BlueTeamTakesLead(0)=Sound'DOTZXAnnouncer.CTF.CTFBlueLead'
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
     bTeamGame=True
     //HUDType="DOTZGame.DOTZCaptureTheFlagHUD"
     HUDType="UMODDOTZGame.UmodDOTZCaptureTheFlagHUD"

}

