class UmodBotControllerSurvivor extends UmodBotController;

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

event PostBeginPlay()
{
    Super.PostBeginPlay();

   BuildBotRouteCache(false);
}

function Possess(Pawn P)
{
    local int I;

	if ( Level.NetMode != NM_Standalone )
	{
		I = Rand(class'UnrealRepository'.default.PrimaryWeaponNameList.length);

		CurrentWeaponName = class'UnrealRepository'.default.PrimaryWeaponNameList[I];
	}
	else
	{
		I = Rand(class'UnrealRepository'.default.BackupWeaponNameList.length);

		CurrentWeaponName = class'UnrealRepository'.default.BackupWeaponNameList[I];
	}

	Super.Possess(P);
}

/*function Possessa(Pawn P)
{
    local WaveMultiPlayerLevelInfo waveInfo;
    local MultiPlayerLevelInfo mpInfo;

    if (P == None)
        return;

    if (P.Weapon == None)
    {
        if (PrimaryWeaponType == "") PrimaryWeaponType = DefaultPrimaryWeaponType;
        if (BackupWeaponType == "")  BackupWeaponType  = DefaultBackupWeaponType;

        waveInfo = WaveMultiPlayerLevelInfo(Level.GameSpecificLevelInfo);
        mpInfo   = MultiPlayerLevelInfo(Level.GameSpecificLevelInfo);

        if (bBotInstantRespawn)
		{
			P.GiveWeapon(PrimaryWeaponType);
		}
        else
		{
			if (waveInfo != None && waveInfo.InitialWaveSize > 6)
				P.GiveWeapon(PrimaryWeaponType);
			else if (waveInfo == None && mpInfo != None && mpInfo.InitialInPlayLimit > 6)
				P.GiveWeapon(PrimaryWeaponType);
			else
				P.GiveWeapon(BackupWeaponType);
		}
    }

    if (P.Weapon == None)
        P.GiveWeapon(DefaultBackupWeaponType);

}*/

function bool SameTeamAs_Controller(Controller C)
{
	if (PlayerReplicationInfo == None ||
		C == None ||
		C.PlayerReplicationInfo == None ||
		PlayerReplicationInfo.Team == None)
	{
		return false;
	}

	return Level.Game.IsOnTeam(
		C,
		PlayerReplicationInfo.Team.TeamIndex
	);
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
    //local int idx;

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
				//idx = SpawnWeaponPickUp( idx, ZF.Location );

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

				//idx = SpawnWeaponPickUp( idx, N.Location );

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

			//idx = SpawnWeaponPickUp( idx, N.Location );

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

defaultproperties
{
	PawnClass=Class'UMODDOTZGame.UmodHumanPawn'
	AIType=Class'UMODDOTZGame.UmodBotAIRoleSurvivor'

	PlayerReplicationInfoClass=Class'UMODDOTZGame.UmodBotReplicationInfo'

    TheExclaimManagerclass=Class'UMODDOTZGame.UmodBotExclaimMgr'

	xboxMsg="Game Over. Press START to continue."
	PCMsg="Game Over. Press fire to continue."

	MinNumShots=5
	MaxNumShots=15

	MinShotPeriod=0.800000
	MaxShotPeriod=2.200000

	MaxAimRange=3000.000000
	MaxSecondsOfLOS=5.000000

	iAwarenessRange=4000

	bMeleeAttackCapable=True
	bRangedAttackCapable=True

	bAdvancedTactics=True
	bCanOpenDoors=True
	bCanDoSpecial=True
	bAdjusting=True
	bJumpOverWall=True

	bCoopGameMode=True

	CurrentWeaponName = "DOTZWeapons.M16Weapon"

     bIsPlayer=False
}