//=============================================================================
// UmodBotAIRole.
//=============================================================================
class UmodBotAIRoleInvasion extends UmodBotAIRole
    placeable;

/**
 * Retreat from a zombie that is inside the minimum combat distance.
 * Returns true when a retreat command was issued.
 */
function bool MaintainMinimumAttackDistance(Pawn inEnemy)
{
    local Vector Away;
    local Vector RetreatLocation;
    local float Dist;
    local Actor RetreatActor;

    if (bot == None || bot.Pawn == None)
        return false;

    if (inEnemy == None || !inEnemy.IsA('ZombiePawnBase'))
        return false;

    if (BotController != None && BotController.HasMeleeWeapon())
        return false;

    Dist = VSize(inEnemy.Location - bot.Pawn.Location);

    if (Dist >= MIN_TARGET_DISTANCE)
        return false;

    // Direction from the enemy toward this bot.
    Away = bot.Pawn.Location - inEnemy.Location;

    // Avoid a zero-length direction when both actors overlap.
    if (VSize(Away) < 1.0)
        Away = vect(1,0,0);
    else
        Away = Normal(Away);

    // Aim beyond the minimum to prevent oscillation at the boundary.
    RetreatLocation = inEnemy.Location
        + Away * (MIN_TARGET_DISTANCE + 40.0);

    RetreatActor = bot.FindPathTo(RetreatLocation);

    if (RetreatActor != None)
        bot.Perform_MoveToLocation(RetreatActor.Location, 40);
    else
        bot.Perform_MoveToLocation(RetreatLocation, 40);

    return true;
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