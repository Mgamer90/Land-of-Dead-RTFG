class UmodBotControllerCaptureTheFlag extends UmodBotController;

var UmodDOTZCaptureTheFlag CaptureTheFlagMode;

//
// Called after the actor has been spawned.
//
event PostBeginPlay()
{
    Super.PostBeginPlay();

    if (Level != None && Level.Game != None)
        CaptureTheFlagMode = UmodDOTZCaptureTheFlag(Level.Game);
}

function bool SameTeamAs(Controller C)
{
	if ( (PlayerReplicationInfo == None) || (C == None) || (C.PlayerReplicationInfo == None)
		|| (PlayerReplicationInfo.Team == None) )
		return false;
	return Level.Game.IsOnTeam(C,PlayerReplicationInfo.Team.TeamIndex);
}

function Possess(Pawn P)
{
    local int I;

	I = Rand(class'UnrealRepository'.default.AllWeaponClassList.length);

	CurrentWeaponName = class'UnrealRepository'.default.AllWeaponClassList[I];

	Super.Possess(P);

    if (CaptureTheFlagMode == None && Level != None && Level.Game != None)
        CaptureTheFlagMode = UmodDOTZCaptureTheFlag(Level.Game);

}

function bool ShouldWalk()
{
	if (Level.NetMode == NM_Standalone ){return ShouldWalk_Standalone();}

	return False;
}

// //Navigation functions - return the next path toward the goal
// native(518) final function Actor FindPathTo(vector aPoint);
// native(517) final function Actor FindPathToward(actor anActor, optional bool bWeightDetours);
// native final function Actor FindPathToIntercept(Pawn P, Actor RouteGoal, optional bool bWeightDetours);
// native final function Actor FindPathTowardNearest(class<NavigationPoint> GoalClass, optional bool bWeightDetours);
// native(525) final function NavigationPoint FindRandomDest();

function bool GetWanderTarget(
    int CurrentOriginIndex,
    int CurrentRank,
    out Actor Target,
    out NavigationPoint TargetNode,
    out int NewOriginIndex,
    out int NewRank)
{
    local Controller P;
    local Actor PathToward;

    Target = None;
    TargetNode = None;
    NewOriginIndex = -1;
    NewRank = 0;

    if (Level == None || Pawn == None)
        return false;

    for (P = Level.ControllerList; P != None; P = P.NextController)
    {
        if (!SameTeamAs(P) && P.Pawn != None)
		{
			Target = P.Pawn;
			PathToward = FindPathTo(P.Pawn.Location);
			TargetNode = NavigationPoint(PathToward);
			NewOriginIndex = -1;
			NewRank = 0;

			return true;
		}
    }

    if (CaptureTheFlagMode == None)
    {
		/*TargetNode = FindRandomDest();
        if (TargetNode != None)
		{
			Target = TargetNode;
			NewOriginIndex = -1;
			NewRank = 0;

			return true;
		}*/

		return false;
    }

	return CaptureTheFlagMode.GetBotWanderTarget(
		Pawn, CurrentOriginIndex, CurrentRank,
		Target, TargetNode, NewOriginIndex, NewRank
        );

    return false;
}

//=============================================================================
// DEFAULT PROPERTIES
//=============================================================================

defaultproperties
{
	PawnClass=Class'UMODDOTZGame.UmodHumanPawn'
	AIType=Class'UMODDOTZGame.UmodBotAIRoleCaptureTheFlag'

	//PlayerReplicationInfoClass=Class'Engine.PlayerReplicationInfo'
	PlayerReplicationInfoClass=Class'UMODDOTZGame.UmodBotReplicationInfo'

    TheExclaimManagerclass=Class'UMODDOTZGame.UmodBotExclaimMgr'

	xboxMsg="Game Over. Press START to continue."
	PCMsg="Game Over. Press fire to continue."

	MinNumShots=4
	MaxNumShots=7

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

	bCoopGameMode=False

	CustomRefireRate=0.2

	CurrentWeaponName = "DOTZWeapons.ShotgunWeapon"

     bIsPlayer=True
}