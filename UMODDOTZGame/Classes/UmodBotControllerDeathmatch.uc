class UmodBotControllerDeathmatch extends UmodBotController;

var UmodDOTZDeathMatch DeathMatchMode;

//
// Called after the actor has been spawned.
//
event PostBeginPlay()
{
    Super.PostBeginPlay();

    if (Level != None && Level.Game != None)
        DeathMatchMode = UmodDOTZDeathMatch(Level.Game);
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

    if (DeathMatchMode == None && Level != None && Level.Game != None)
        DeathMatchMode = UmodDOTZDeathMatch(Level.Game);

}


function bool ShouldWalk()
{
	if (Level.NetMode == NM_Standalone ){return ShouldWalk_Standalone();}

	return False;
}

function bool GetWanderTarget(
    int CurrentOriginIndex,
    int CurrentRank,
    out Actor Target,
    out NavigationPoint TargetNode,
    out int NewOriginIndex,
    out int NewRank)
{
    Target = None;
    TargetNode = None;
    NewOriginIndex = -1;
    NewRank = 0;

    if (Level == None || Level.Game == None || Pawn == None)
        return false;

    if (DeathMatchMode == None)
        return false;

	return DeathMatchMode.GetBotWanderTarget(
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
	AIType=Class'UMODDOTZGame.UmodBotAIRoleDeathmatch'

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

	//PlayerReplicationInfoClass=Class'Engine.PlayerReplicationInfo'
	PlayerReplicationInfoClass=Class'UMODDOTZGame.UmodBotReplicationInfo'

    TheExclaimManagerclass=Class'UMODDOTZGame.UmodBotExclaimMgr'

	bCoopGameMode=False

	CustomRefireRate=0.2

	CurrentWeaponName = "DOTZWeapons.ShotgunWeapon"

     bIsPlayer=True
}