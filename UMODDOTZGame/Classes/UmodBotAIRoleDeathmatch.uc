//=============================================================================
// UmodBotAIRole.
//=============================================================================
class UmodBotAIRoleDeathmatch extends UmodBotAIRole
    placeable;

function bool ShouldFollowPlayer()
{
    return false;
}

/**
 * Returns true if the supplied pawn is a valid hostile target.
 */
function bool IsValidEnemy(Pawn P)
{
    if (P == None)
        return false;

    if (bot == None || bot.Pawn == None)
        return false;

    if (P == bot.Pawn)
        return false;

    if (P.Health <= 0)
        return false;

    if (P.Controller == None)
        return false;

    return !bot.SameTeamAs(P.Controller);
}

/**
 * Safely acquire an enemy.
 */
function bool TryAcquireEnemy(Pawn P, bool bCanSee)
{
	local float P_Distance;

    if (!IsValidEnemy(P))
        return false;

    if (P != None)
	{
		P_Distance = VSize(P.Location - bot.Pawn.Location);

		if (P.IsA('ZombiePawnBase') && P_Distance > MIN_TARGET_DISTANCE)
			return false;

		if (
			bot.Enemy == None || 
			(
				bot.Enemy.Health <= 0 || 
				(!bot.EnemyIsVisible() || !bot.CanAttack(bot.Enemy) || VSize(bot.Enemy.Location - bot.Pawn.Location) > P_Distance)
			)
		)
		{
			bot.AcquireEnemy(P, bCanSee);
			GotoState('Attacking');
			return true;
		}
    }

    return false;
}

//===========================================================================
// Seeking
//===========================================================================

function bool TrySeekTarget(Actor A)
{
    if (bot == None || bot.Pawn == None)
        return false;

    if (A == None || A.IsA('ZombiePawnBase'))
        return false;

    if (VSize(bot.Pawn.Location - A.Location)
        <= VSize(bot.Pawn.Location - SeekLocation))
    {
        LastSeekInstigator = A;
        LastSeekRefreshTime = Level.TimeSeconds;
        SeekLocation = A.Location;
        bot.UpdateFocus(A);
        return true;
    }

    return false;
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