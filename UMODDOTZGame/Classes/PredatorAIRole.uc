//=============================================================================
// PredatorAIRole.
//=============================================================================
class PredatorAIRole extends DOTZAIRole
    placeable;

const RANGE_ATTACK_DIST = 3000.0;

const MELEE_ATTACK_DIST = 85.0;

const START_REACQUIRE_TIMER = 2; //68694;
const THINK_AGAIN_TIMER     =  1;//92843;
const DONT_BE_STUPID_TIMER  = 2; //29384;
const CHARGE_TIMER          = 8375093;
const PRE_CHARGE_TIMER      = 8375094;
const MELEE_RANGE           = 150;

const REACQUIRE_DELAY = 0.5;
const STUPID_DELAY = 0.5;

var int AttackRange;
var float MinWanderDelay;
var float MaxWanderDelay;

// wander
var protected int numLooks;

// seek
var protected Vector SeekLocation;
var protected Actor  LastSeekInstigator;
var protected float LastSeekRefreshTime;

// obstacle smashing
var protected Smashable CurrentObstacle;
var protected AttackPoint CurrentAttackPoint;
var protected int NumClearAttempts;
var protected float ClearStartTime;

// eating
var protected Actor SpecialTarget;
var protected int FailedSpecialAttempts;
var protected float DistToSpecialTarget;
var int SpecialTime;

// enemy management
var protected float LastHeardEnemyTime;

// charging
var protected int NumChargingZombies;
var protected const int MaxChargingZombies;
var protected const float MaxChargeDist;
var protected const float MinChargeDist;
var protected float MinTimeBetweenCharges;
var protected float MaxTimeBetweenCharges;
var protected float LastChargeTime;
var protected float ChargeStartTime;
var protected bool bIsCharging;
var protected float ChargeDuration;
var protected bool bIgnoreBumps;
var() bool bAllowedToCharge;

// other
var protected bool bActivated;

var() UmodBotController zombieBot;
var() protected float OtisWeaponRange;

//===========================================================================
// Utility helpers
//===========================================================================

/**
 * Returns true if the controller, pawn and enemy are all valid.
 */
function bool HasValidEnemy()
{
    return (
        bot != None
        && bot.Pawn != None
        && bot.Enemy != None
        && bot.Enemy.Health > 0
        && bot.Enemy != bot.Pawn
    );
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
    if (!IsValidEnemy(P))
        return false;

    if (
		bot.Enemy == None || 
		(
			bot.Enemy.Health <= 0 || 
			VSize(bot.Enemy.Location - bot.Pawn.Location) > VSize(P.Location - bot.Pawn.Location)
		)
	)
    {
        bot.AcquireEnemy(P, bCanSee);
        GotoState('Attacking');
        return true;
    }

    return false;
}

/**
 * Pick the nearest living player/controller pawn.
 *
 * This is primarily used to prevent Otis from standing still in
 * standalone/co-op when he has no enemy.
 */
function Pawn GetNearestFriendlyPlayer()
{
    local Controller C;
    local Pawn P;
    local Pawn BestPawn;
    local float BestDist;
    local float Dist;

    if (bot == None || bot.Pawn == None)
        return None;

    BestDist = 999999999.0;

    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        P = C.Pawn;

        if (P == None || P == bot.Pawn)
            continue;

        if (P.Health <= 0)
            continue;

        // We only want players/friendly controllers here.
        if (!bot.SameTeamAs(C))
            continue;

        if (!C.bIsPlayer)
            continue;

        Dist = VSize(P.Location - bot.Pawn.Location);

        if (Dist < BestDist)
        {
            BestDist = Dist;
            BestPawn = P;
        }
    }

    return BestPawn;
}

/**
 * Returns the closest friendly player if one exists.
 */
function Pawn GetFollowTarget()
{
    local Pawn P;

    // Preserve the old standalone behavior as a fallback.
    if (Level.NetMode == NM_Standalone /*&& Level.GetLocalPlayerController() != None*/)
    {
        return Level.GetLocalPlayerController().Pawn;
    }

    return None;
    P = GetNearestFriendlyPlayer();

    if (P != None)
        return P;

    return None;
}

/**
 * Determines whether Otis should move toward his friendly player.
 */
function bool ShouldFollowPlayer()
{
    local Pawn P;
    local float Dist;

    if (bot == None || bot.Pawn == None)
        return false;

    if (HasValidEnemy())
        return false;

    P = GetFollowTarget();

    if (P == None || P.Health <= 0)
        return false;

    Dist = VSize(P.Location - bot.Pawn.Location);

    // Don't run directly into the player.
    if (Dist < 180)
        return false;

    return Level.NetMode == NM_Standalone;
}

/**
 * Safe transition back to the appropriate non-combat state.
 */
function ReturnToIdleBehaviour()
{
    if (HasValidEnemy())
    {
        GotoState('Attacking');
        return;
    }

    if (LastSeekInstigator != None)
    {
        GotoState('Seeking');
        return;
    }

    GotoState('Wander');
}

//===========================================================================
// Enemy events
//===========================================================================

function OnTakingDamage(Pawn Other, float Damage)
{
    super.OnTakingDamage(Other, Damage);

    if (TryAcquireEnemy(Other, true))
        return;
}

// Called whenever an enemy pawn is in sight.
function OnThreatSpotted(Pawn Threat)
{
    if (TryAcquireEnemy(Threat, true))
        return;

    // If we already have a valid enemy, don't replace it with a worse target.
    if (HasValidEnemy())
        return;
}

// Analagous to OnThreatSpotted().
function OnThreatHeard(Pawn Threat)
{
    if (Threat == None)
        return;

    if (TryAcquireEnemy(Threat, false))
        return;
}

/**
 * Called whenever something makes noise.
 * A heard pawn is not necessarily visible.
 */
function OnHeardNoise(float Loudness, Actor NoiseMaker)
{
    local Pawn HeardPawn;

    if (NoiseMaker == None)
        return;

    if (NoiseMaker == bot.Enemy)
    {
        LastHeardEnemyTime = Level.TimeSeconds;
        return;
    }

    HeardPawn = Pawn(NoiseMaker);

    if (HeardPawn != None && IsValidEnemy(HeardPawn))
    {
        if (TryAcquireEnemy(HeardPawn, false))
            return;
    }

    if (TrySeekTarget(NoiseMaker))
    {
        GotoState('Seeking', 'BEGIN');
    }
}

/**
 * Death of Otis.
 */
function OnKilled(Controller Killer)
{
    super.OnKilled(Killer);
    EndCharge();
}

/**
 * Killed an enemy.
 */
function OnWitnessedKill(Controller Killer, Pawn Victim)
{
    local Pawn KillerPawn;

    super.OnWitnessedKill(Killer, Victim);

    if (Killer == None)
        return;

    if (bot == None || bot.Pawn == None)
        return;

    if (bot.SameTeamAs(Killer))
        return;

    KillerPawn = Killer.Pawn;

    if (KillerPawn != None)
        TryAcquireEnemy(KillerPawn, true);
}

//===========================================================================
// Seeking
//===========================================================================

function bool TrySeekTarget(Actor A)
{
    if (A == None || bot == None || bot.Pawn == None)
        return false;

    if (LastSeekInstigator == None
        || (LastSeekInstigator == A
            && Level.TimeSeconds - LastSeekRefreshTime > 3)
        || A.IsA('ZombiePawnBase'))
    {
        LastSeekInstigator = A;
        LastSeekRefreshTime = Level.TimeSeconds;
        SeekLocation = A.Location;
        return true;
    }

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
// Obstacle handling
//===========================================================================

function TryClearObstacle(Actor Obstacle)
{
    local Pawn PotentialEnemy;

    if (Obstacle == None || bot == None || bot.Pawn == None)
        return;

    PotentialEnemy = Pawn(Obstacle);

    if (IsValidEnemy(PotentialEnemy))
    {
        bot.AcquireEnemy(PotentialEnemy, true);
        GotoState('Attacking');
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
// Charging
//===========================================================================

function bool ShouldCharge()
{
    /*local bool Result;

    if (!bAllowedToCharge)
        return false;

    if (!HasValidEnemy())
        return false;

    if (bot.Pawn == None)
        return false;

    if (bot.Pawn.IsA('ScuttlingZombie'))
    {
        if ((Level.TimeSeconds - ChargeStartTime) < MinTimeBetweenCharges)
            return false;

        if (VSize(bot.Enemy.Location - bot.Pawn.Location)
            > MaxChargeDist * 1.5)
            return false;

        return true;
    }

    if (MaxChargingZombies > 0
        && default.NumChargingZombies >= MaxChargingZombies
        && Level.TimeSeconds - default.LastChargeTime < MaxTimeBetweenCharges)
    {
        return false;
    }

    if (Level.TimeSeconds - ChargeStartTime < MinTimeBetweenCharges)
        return false;

    if (Level.TimeSeconds - bot.Pawn.SpawnTime < 5)
        return false;

    if (VSize(bot.Enemy.Location - bot.Pawn.Location) > MaxChargeDist)
        return false;

    if (VSize(bot.Enemy.Location - bot.Pawn.Location) < MinChargeDist)
        return false;

    // Don't repeatedly perform expensive reachability checks after a failure.
    if (Level.TimeSeconds - ZombieBot.FailedReachTime <= 10)
        return false;

    Result = bot.ActorReachable(bot.Enemy);

    return Result;*/

    return bAllowedToCharge;

}

function float GetChargeDuration()
{
    local float Dist;

    if (!HasValidEnemy())
        return 0;

    if (bot.Pawn.GroundSpeed <= 0)
        return 0;

    Dist = VSize(bot.Enemy.Location - bot.Pawn.Location) * 0.8;

    return Dist / bot.Pawn.GroundSpeed;
}

function StartCharge()
{
    if (bIsCharging)
        return;

    ChargeStartTime = Level.TimeSeconds;
    default.LastChargeTime = ChargeStartTime;

    if (zombieBot != None)
        zombieBot.bForceRun = true;

    bIsCharging = true;
    default.NumChargingZombies++;
}

function EndCharge()
{
    if (!bIsCharging)
        return;

    if (default.NumChargingZombies > 0)
        default.NumChargingZombies--;

    bIsCharging = false;

    if (zombieBot != None)
        zombieBot.bForceRun = false;
}

//===========================================================================
// Wander
//===========================================================================

auto state Wander
{
    function BeginState()
    {
        if (bot != None)
            bot.StopFiring();
    }

    function EndState()
    {
        // Nothing special.
    }

    function NotEngagedWanderFailed()
    {
        if (HasValidEnemy())
            GotoState('Attacking');
        else
            GotoState('Wander');
    }

    function OnBump(Actor Other)
    {
        TryClearObstacle(Other);
    }

    function OnHitWall(Actor Other)
    {
        TryClearObstacle(Other);
    }

    function OnHitMover(Actor Other)
    {
        TryClearObstacle(Other);
    }

BEGIN:

    while (bot != None && bot.Pawn != None)
    {
        // Enemy acquisition always takes priority over wandering.
        if (HasValidEnemy())
        {
            GotoState('Attacking');
            break;
        }

        if (ShouldFollowPlayer())
        {
            if (bot.ActorReachable(GetFollowTarget()))
            {
                bot.Perform_MoveToLocation(
                    GetFollowTarget().Location,
                    160
                );

                WaitForNotification();
            }
            else
            {
                // Still give the normal AI a chance to find a path.
                bot.Perform_NotEngaged_Wander();
                WaitForNotification();
            }
        }
        else
        {
            // Look around instead of remaining completely static.
            numLooks = RandRange(2, 4);

            while (numLooks > 0)
            {
                if (HasValidEnemy())
                    break;

                bot.SetRandomFocalPointLocation(1200);
                Sleep(RandRange(0.15, 0.35));

                --numLooks;
            }

            if (HasValidEnemy())
            {
                GotoState('Attacking');
                break;
            }

            bot.Perform_NotEngaged_Wander();
            WaitForNotification();
        }

        // Never allow Wander to become a permanent blocking state.
        Sleep(RandRange(MinWanderDelay, MaxWanderDelay));

        // Re-evaluate quickly.
        if (HasValidEnemy())
        {
            GotoState('Attacking');
            break;
        }
    }
}

//===========================================================================
// Seeking
//===========================================================================

state Seeking
{
    function BeginState()
    {
        if (bot == None || bot.Pawn == None)
            return;

        if (LastSeekInstigator != None)
        {
            SeekLocation = LastSeekInstigator.Location;
            bot.UpdateFocus(LastSeekInstigator);
        }
    }

    function EndState()
    {
        if (bot != None)
            bot.Perform_Error_Stop();
    }

    function OnBump(Actor Other)
    {
        TryClearObstacle(Other);
    }

    function OnHitWall(Actor Other)
    {
        TryClearObstacle(Other);
    }

    function OnHitMover(Actor Other)
    {
        TryClearObstacle(Other);
    }

BEGIN:

    if (bot == None || bot.Pawn == None)
        GotoState('Wander');

    if (HasValidEnemy())
        GotoState('Attacking');

    if (LastSeekInstigator != None)
        SeekLocation = LastSeekInstigator.Location;

    bot.Perform_MoveToLocation(SeekLocation, 128);

    SetMultiTimer(THINK_AGAIN_TIMER, 0.5, false);

    WaitForNotification();

    SetMultiTimer(THINK_AGAIN_TIMER, 0.5, false);

    if (HasValidEnemy())
    {
        GotoState('Attacking');
    }
    else
    {
        LastSeekInstigator = None;
        GotoState('Wander');
    }
}

//===========================================================================
// Attacking
//===========================================================================

state Attacking
{
    function BeginState()
    {
        if (!HasValidEnemy())
        {
            GotoState('Wander');
            return;
        }

        LastSeekInstigator = bot.Enemy;
        bot.UpdateFocus(bot.Enemy);
        bot.SetCombatTimer();
    }

    function EndState()
    {
        if (bot != None)
            bot.SetTimer(0, false);

        EndCharge();
    }

    function OnLostSight()
    {
        if (!HasValidEnemy())
        {
            GotoState('Wander');
            return;
        }

        SetMultiTimer(
            START_REACQUIRE_TIMER,
            REACQUIRE_DELAY,
            false
        );
    }

    function ChargeFailed()
    {
        SetMultiTimer(
            START_REACQUIRE_TIMER,
            REACQUIRE_DELAY,
            false
        );
    }

    function OnBump(Actor Other)
    {
        local Pawn EnemyPawn;

        if (bIgnoreBumps)
            return;

        EnemyPawn = Pawn(Other);

        if (IsValidEnemy(EnemyPawn))
        {
            if (bot.Pawn.Weapon != None)
            {
                //if (bot.Pawn.Weapon.IsA('DOTZMeleeWeapon'))
                    bIgnoreBumps = true;

                bot.WeaponFireAgain( bot.Pawn.Weapon.RefireRate(), false );
            }
        }
    }

    function OnThreatSpotted(Pawn Threat)
    {
        super.OnThreatSpotted(Threat);
    }

    function OnHeardNoise(float Loudness, Actor NoiseMaker)
    {
        if (NoiseMaker == bot.Enemy)
            LastHeardEnemyTime = Level.TimeSeconds;

        super.OnHeardNoise(Loudness, NoiseMaker);
    }

    function bool TrySeekTarget(Actor A)
    {
        return false;
    }

BEGIN:

    while (HasValidEnemy())
    {
        // Enemy may have died between state iterations.
        if (bot.Enemy == None || bot.Enemy.Health <= 0)
        {
            bot.Enemy = None;
            GotoState('Wander');
            break;
        }

        //=============================================================
        // Charge attack
        //=============================================================

        if (ShouldCharge())
        {
            StartCharge();

            ChargeDuration = GetChargeDuration();

            if (ChargeDuration <= 0)
            {
                EndCharge();
            }
            else
            {
                if (ChargeDuration > 1.5)
                    SetMultiTimer(PRE_CHARGE_TIMER, 0.2, false);

                SetMultiTimer(
                    CHARGE_TIMER,
                    ChargeDuration,
                    false
                );

                bIgnoreBumps = false;

                bot.Perform_MoveToLocation(
                    bot.Pawn.Location
                    + ((bot.Enemy.Location - bot.Pawn.Location) * 0.9),
                    OtisWeaponRange
                );

                WaitForNotification();

                SetMultiTimer(CHARGE_TIMER, 0, false);
                SetMultiTimer(PRE_CHARGE_TIMER, 0, false);

                EndCharge();
            }
        }

        //=============================================================
        // Normal attack
        //=============================================================

        else if (bot.Pawn.Weapon != None)
        {
            OtisWeaponRange = 3000.0;

            if (bot.EnemyIsVisible() && VSize( bot.Enemy.Location - bot.Pawn.Location ) < OtisWeaponRange)
            {
                /*if (bot.Pawn.Weapon.IsA('DOTZMeleeWeapon'))
                {
                    bIgnoreBumps = true;

                    bot.Perform_MeleeAttack();
                    WaitForNotification();

                    bIgnoreBumps = false;
                }
                else
                {
                    bot.Perform_RangeAttack();
                    WaitForNotification();
                }*/
                    bIgnoreBumps = true;

                    bot.Perform_MeleeAttack();
                    WaitForNotification();

                    bIgnoreBumps = false;
            }
            else
            {
                /**
                 * Move toward the enemy rather than simply waiting.
                 *
                 * Re-evaluate frequently so an enemy that moves,
                 * disappears or dies does not leave Otis stuck in
                 * a movement state.
                 */
                if (bot.ActorReachable(bot.Enemy))
                {
                    bot.Perform_MoveToLocation(
                        bot.Pawn.Location
                        + ((bot.Enemy.Location - bot.Pawn.Location) * 0.75),
                        180
                    );
                }
                else
                {
                    bot.Perform_MoveToLocation(
                        bot.Enemy.Location,
                        180
                    );
                }

                SetMultiTimer(
                    THINK_AGAIN_TIMER,
                    1.0,
                    false
                );

                WaitForNotification();

                SetMultiTimer(
                    THINK_AGAIN_TIMER,
                    0,
                    false
                );
            }
        }

        Sleep(0.05);
    }

    EndCharge();

    if (bot != None)
    {
        bot.Target = None;
        bot.Focus = None;
        bot.UpdateFocus(None);
        bot.Enemy = None;
    }

    GotoState('Wander');
}

//===========================================================================
// Special activities
//===========================================================================

state DoSpecial
{
    function BeginState()
    {
        SpecialTime = int(Level.TimeSeconds);
    }

    function EndState()
    {
        if (bot != None)
        {
            bot.Target = None;
            bot.Focus = None;
            bot.UpdateFocus(None);
        }
    }

    function OnThreatSpotted(Pawn Threat)
    {
        super.OnThreatSpotted(Threat);
    }

    function OnHeardNoise(float Loudness, Actor NoiseMaker)
    {
        super.OnHeardNoise(Loudness, NoiseMaker);
    }

BEGIN:

    Goto('DONE');

SMASH_OBSTACLE:

    if (CurrentObstacle == None)
        Goto('DONE');

    CurrentAttackPoint =
        CurrentObstacle.GetAttackPoint(bot.Pawn);

    if (CurrentAttackPoint == None)
        Goto('DONE');

    bot.Perform_MoveToLocation(
        CurrentAttackPoint.GetAttackLocation()
    );

    WaitForNotification();

    if (CurrentObstacle == None)
        Goto('DONE');

    bot.Target = CurrentObstacle.GetSmashActor();
    bot.Focus = CurrentObstacle.GetSmashActor();

    Sleep(0.25);

    for (
        NumClearAttempts = 0;
        NumClearAttempts < 5;
        ++NumClearAttempts
    )
    {
        if (CurrentObstacle == None)
            break;

        bot.Perform_MeleeAttack();
        WaitForNotification();

        if (CurrentObstacle.GetAttackPoint(bot.Pawn) == None)
            break;
    }

    if (CurrentObstacle != None
        && CurrentObstacle.GetAttackPoint(bot.Pawn) != None)
    {
        CurrentObstacle.DoSmash(bot.Pawn);
    }

    CurrentObstacle = None;
    CurrentAttackPoint = None;

    Goto('DONE');

EAT_STUFF:

    FailedSpecialAttempts = 0;

    if (!HasValidEnemy())
        Goto('DONE');

    Goto('DONE');

DONE:

    if (bot != None)
    {
        bot.Target = None;
        bot.Focus = None;
        bot.UpdateFocus(None);
    }

    if (HasValidEnemy())
        GotoState('Attacking');
    else if (LastSeekInstigator != None)
        GotoState('Seeking');
    else
        GotoState('Wander');
}

//===========================================================================
// Initialization
//===========================================================================

function Init(VGSPAIController C)
{
    super.Init(C);

    zombieBot = UmodBotController(C);

    if (zombieBot == None)
        return;

    SetMultiTimer(
        DONT_BE_STUPID_TIMER,
        6.0 + RandRange(0, 2.5),
        false
    );
}

//===========================================================================
// Timers
//===========================================================================

function MultiTimer(int TimerID)
{
    switch (TimerID)
    {
        case START_REACQUIRE_TIMER:

            if (HasValidEnemy())
            {
                if (!bot.EnemyIsVisible())
                {
                    TrySeekTarget(bot.Enemy);
                    GotoState('Seeking');
                }
                else
                {
                    GotoState('Attacking');
                }
            }

            break;

        case PRE_CHARGE_TIMER:

            if (HasValidEnemy()
                && bot.Pawn != None
                && bot.Pawn.Weapon != None)
            {
                bot.WeaponFireAgain(
                    bot.Pawn.Weapon.RefireRate(),
                    false
                );
            }

            break;

        case CHARGE_TIMER:

            if (HasValidEnemy()
                && bot.Pawn != None
                && bot.Pawn.Weapon != None)
            {
                bot.WeaponFireAgain(
                    bot.Pawn.Weapon.RefireRate(),
                    false
                );
            }

            break;

        case THINK_AGAIN_TIMER:

            if (bot != None)
                bot.MoveTimer = -1;

            break;

        case DONT_BE_STUPID_TIMER:

            DontBeStupid();

            SetMultiTimer(
                DONT_BE_STUPID_TIMER,
                STUPID_DELAY,
                false
            );

            break;

        default:

            super.MultiTimer(TimerID);
            break;
    }
}

//===========================================================================
// Anti-stuck / anti-stupid watchdog
//===========================================================================

function DontBeStupid()
{
    local Pawn Player;
    local float Dist;

    if (bot == None || bot.Pawn == None)
        return;

    // Prefer current enemy.
    Player = bot.Enemy;

    // Otherwise find a friendly player.
    if (Player == None || Player.Health <= 0)
        Player = GetFollowTarget();

    if (Player == None)
        return;

    if (Player.Health <= 0)
        return;

    Dist = VSize(Player.Location - bot.Pawn.Location);

    /**
     * Never let the watchdog force Otis into combat against a
     * friendly player.
     */
    if (bot.SameTeamAs(Player.Controller))
    {
        if (Dist > 300 && !HasValidEnemy())
        {
            if (bot.ActorReachable(Player))
                GotoState('Wander');
        }

        return;
    }

    // Hostile target.
    if (Abs(Player.Location.Z - bot.Pawn.Location.Z) >= 1024.0)
        return;

    if (bot.ActorReachable(Player)
        && bot.CanSee(Player))
    {
        bot.AcquireEnemy(Player, true);
        GotoState('Attacking');
    }
}

//===========================================================================
// Attack range
//===========================================================================

function bool InAttackRange(Actor EnemyActor)
{
    if (EnemyActor == None || bot == None || bot.Pawn == None)
        return false;

	if (bot.Pawn.Weapon != None)
	{
		if (bot.Pawn.Weapon.IsA('DOTZMeleeWeapon'))
			return ( VSize(bot.Pawn.Location - EnemyActor.Location) < MELEE_ATTACK_DIST );

		return ( VSize(bot.Pawn.Location - EnemyActor.Location) < RANGE_ATTACK_DIST );
	}

    return ( VSize(bot.Pawn.Location - EnemyActor.Location) < RANGE_ATTACK_DIST );
}

//===========================================================================
// Debug
//===========================================================================

function DisplayDebug(
    Canvas C,
    out float YL,
    out float YPos
)
{
    super.DisplayDebug(C, YL, YPos);

    C.SetPos(4, YPos);

    C.DrawText(
        "LastSeekInstigator:" @ LastSeekInstigator
        @ "SeekLocation:" @ SeekLocation
        @ "Enemy:" @ bot.Enemy
        @ "State:" @ GetStateName()
        @ "Charging:" @ bIsCharging
    );

    YPos += YL;
}

//===========================================================================
// PreBeginPlay
//===========================================================================

function PreBeginPlay()
{
    super.PreBeginPlay();

    ChargeStartTime = Level.TimeSeconds - MinTimeBetweenCharges;

    LastChargeTime = ChargeStartTime;
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
}