//=============================================================================
// UmodBotAIRole.
//=============================================================================
class UmodBotAIRoleSurvivor extends UmodBotAIRole
    placeable;

function bool ShouldFollowPlayer()
{
    if (Level.NetMode != NM_Standalone || bot == None || bot.Pawn == None)
        return false;

    if (HasValidEnemy())
        return false;

    return (CachedFollowTarget != None && CachedFollowTarget.Health > 0 && bot.ActorReachable(CachedFollowTarget)
            && VSize(CachedFollowTarget.Location - bot.Pawn.Location) >= 180);
}

function bool IsValidEnemy(Pawn P)
{
    local VGSPAIController VGSPAIC;

    if (P == None)
        return false;

    if (bot == None || bot.Pawn == None)
        return false;

    if (P == bot.Pawn || P.Health <= 0 || P.Controller == None)
        return false;

    VGSPAIC = VGSPAIController(P.Controller);
    if (VGSPAIC != None && VGSPAIC.bHibernating)
        return false;

    return !bot.SameTeamAs(P.Controller);
}

//===========================================================================
// Obstacle handling
//===========================================================================

function bool OpenDoor(DOTZDoor CurrentDoor, float MinDoorDist)
{
    local Vector Away;
    local Vector RetreatLocation;
    local float Dist;

    if (CurrentDoor == None)
        return false;

    if (MinDoorDist < 10.0)
        MinDoorDist = 60.0;

    Dist = VSize(CurrentDoor.Location - bot.Pawn.Location);

    if (Dist >= MinDoorDist)
	{
		CurrentDoor.Open();
		return true;
	}

    // Direction from the enemy toward this bot.
    Away = bot.Pawn.Location - CurrentDoor.Location;

    // Avoid a zero-length direction when both actors overlap.
    if (VSize(Away) < 1.0)
        Away = vect(1,0,0);
    else
        Away = Normal(Away);

    // Aim beyond the minimum to prevent oscillation at the boundary.
    RetreatLocation = CurrentDoor.Location
        + Away * (MinDoorDist + 40.0);

	
    CurrentDoor.Open();

    bot.Perform_MoveToLocation(RetreatLocation, 40);

    return true;
}

function TryClearObstacle(Actor Obstacle)
{
    local Pawn PotentialEnemy;
    local ActionableStaticMesh PotentialActionable;
    local DOTZDoor CurrentDoor;

    if (Obstacle == None || bot == None || bot.Pawn == None)
        return;

    PotentialEnemy = Pawn(Obstacle);

    if (IsValidEnemy(PotentialEnemy))
    {
        bot.AcquireEnemy(PotentialEnemy, true);
        GotoState('Attacking');
        return;
    }

    CurrentDoor = DOTZDoor(Obstacle);

    if (CurrentDoor != None)
    {
        OpenDoor(CurrentDoor, 60.0);
		
		return;
    }

    PotentialActionable = ActionableStaticMesh(Obstacle);

    if (PotentialActionable != None)
    {
        NumClearAttempts = 0;
        PotentialActionable.DoActionableAction(bot);
		
		return;
    }

    CurrentObstacle = Smashable(Obstacle);

    if (CurrentObstacle != None)
    {
        NumClearAttempts = 0;
        GotoState('DoSpecial', 'SMASH_OBSTACLE');
    }
}

//===========================================================================
// Default Properties
//===========================================================================

defaultproperties
{
    OtisWeaponRange = 3000.0
 
    AttackRange=3000
    MinWanderDelay=0.100000
    MaxWanderDelay=0.250000

    LastSeekRefreshTime=-10.000000

    MaxChargingZombies=1
    MaxChargeDist=1750.000000
    MinChargeDist=100.000000

    MinTimeBetweenCharges=0.100000
    MaxTimeBetweenCharges=0.250000

    bAllowedToCharge=False

    DebugFlags=1

	bStrafeWhileShooting=False
	StrafeOdds=0.35
	MinStrafeInterval=1.5
}