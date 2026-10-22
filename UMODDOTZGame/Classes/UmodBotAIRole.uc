//=============================================================================
// UmodBotAIRole.
//=============================================================================
class UmodBotAIRole extends DOTZAIRole
    placeable;

const MIN_TARGET_DISTANCE = 150.0;

const RANGE_ATTACK_DIST = 3000.0;

const MELEE_ATTACK_DIST = 85.0;

const START_REACQUIRE_TIMER = 68694;
const THINK_AGAIN_TIMER     =  92843;
const DONT_BE_STUPID_TIMER  = 29384;
const CHARGE_TIMER          = 8375093;
const PRE_CHARGE_TIMER      = 8375094;
const MELEE_RANGE           = 150;

const REACQUIRE_DELAY = 0.5;
const STUPID_DELAY = 0.5;

var protected Pawn  CachedFollowTarget;
var protected float CachedFollowTime;

var int AttackRange;
var float MinWanderDelay;
var float MaxWanderDelay;

// wander
var protected int numLooks;
var protected int VeteranRouteOriginIndex;
var protected int VeteranRouteRank;
var protected Actor VeteranRouteTarget;
var protected NavigationPoint VeteranRouteNode;


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

var() UmodBotController BotController;
var() protected float OtisWeaponRange;

var() bool  bStrafeWhileShooting;       // default False (default behaviour unchanged)
var() float StrafeOdds;                 // default 0.35
var() float MinStrafeInterval;          // default 1.5

//===========================================================================
// PreBeginPlay
//===========================================================================

function PreBeginPlay()
{
    super.PreBeginPlay();

    ChargeStartTime = Level.TimeSeconds - MinTimeBetweenCharges;

    LastChargeTime = ChargeStartTime;
}

event Destroyed()
{
    EndCharge();
    CurrentObstacle = None;
    CurrentAttackPoint = None;
    SpecialTarget = None;
    LastSeekInstigator = None;
    CachedFollowTarget = None;
    VeteranRouteTarget = None;
    VeteranRouteNode = None;
    BotController = None;
    Super.Destroyed();
}

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

    if (P == bot.Pawn || P.Health <= 0 || P.Controller == None)
        return false;

    return !bot.SameTeamAs(P.Controller);
}

/**
 * Retreat from a zombie that is inside the minimum combat distance.
 * Returns true when a retreat command was issued.
 */
function bool MaintainMinimumAttackDistance(Pawn inEnemy)
{
    local Vector Away;
    local Vector RetreatLocation;
    local float Dist;

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

    bot.Perform_MoveToLocation(RetreatLocation, 40);

    return true;
}

/**
 * Safely acquire an enemy.
 */
function bool TryAcquireEnemy(Pawn P, bool bCanSee)
{
    if (!IsValidEnemy(P))
        return false;

    if (bot.Enemy == P)
        return true;

    if (bot.Enemy == None
        || bot.Enemy.Health <= 0
        || !IsValidEnemy(bot.Enemy)
        || !bot.EnemyIsVisible()
        || !bot.CanAttack(bot.Enemy)
        || VSize(bot.Enemy.Location - bot.Pawn.Location)
            > VSize(P.Location - bot.Pawn.Location))
    {
        bot.AcquireEnemy(P, bCanSee);

        if (bot.Enemy == P)
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

function CheckFollowTarget()
{
	if (
		CachedFollowTarget != None && !CachedFollowTarget.bDeleteMe && 
		CachedFollowTarget.Health > 0 && 
		(Level.NetMode == NM_Standalone || Level.TimeSeconds - CachedFollowTime < 0.5)
		)
		return;

	CachedFollowTarget = GetFollowTarget();
}

/**
 * Returns the closest friendly player if one exists.
 */
function Pawn GetFollowTarget()
{
    local PlayerController PC;

    if (Level.NetMode == NM_Standalone)
    {
        PC = Level.GetLocalPlayerController();
        if (PC != None && PC.Pawn != None && PC.Pawn.Health > 0)
            return PC.Pawn;
    }

    if (CachedFollowTarget != None && !CachedFollowTarget.bDeleteMe
        && CachedFollowTarget.Health > 0
        && Level.TimeSeconds - CachedFollowTime < 0.5)
        return CachedFollowTarget;

    CachedFollowTarget = GetNearestFriendlyPlayer();
    CachedFollowTime = Level.TimeSeconds;
    return CachedFollowTarget;
}

function bool ShouldFollowPlayer()
{
	return false;

    /*if (Level.NetMode != NM_Standalone || bot == None || bot.Pawn == None)
        return false;

    if (HasValidEnemy())
        return false;

    return (CachedFollowTarget != None && CachedFollowTarget.Health > 0
            && VSize(CachedFollowTarget.Location - bot.Pawn.Location) >= 180 && bot.ActorReachable(CachedFollowTarget));*/
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

/**
 * Death of Otis.
 */
function OnKilled(Controller Killer)
{
    super.OnKilled(Killer);
    EndCharge();
}

function HandleBump(Actor Other)
{
    local Pawn P;

    if (bot == None || bot.Pawn == None || Other == None)
        return;

    P = Pawn(Other);
    if (P != None && IsValidEnemy(P))
    {
        MaintainMinimumAttackDistance(P);

        // never treat a hostile pawn as an obstacle
        if (bot.Enemy == None || bot.Enemy.Health <= 0
            || VSize(bot.Enemy.Location - bot.Pawn.Location) > VSize(P.Location - bot.Pawn.Location))
        {
            if (bot.Pawn.Weapon != None)
            {
                bot.Target = P;
                bot.WeaponFireAgain(bot.Pawn.Weapon.RefireRate(), false);
            }
        }
        return;
    }
    TryClearObstacle(Other);
}

function OnBump(Actor Other)
{
    local Pawn OtherPawn;

    if (bot == None || bot.Pawn == None || Other == None)
        return;

    OtherPawn = Pawn(Other);

    if (OtherPawn != None)
    {
        if (IsValidEnemy(OtherPawn))
        {
			MaintainMinimumAttackDistance(OtherPawn);


            if (TryAcquireEnemy(OtherPawn, true))
                return;
        }

        // Do not retreat from friendly or invalid pawns.
        super.OnBump(Other);
        return;
    }

    TryClearObstacle(Other);
    super.OnBump(Other);
}

function OnTakingDamage(Pawn Other, float Damage)
{
    super.OnTakingDamage(Other, Damage);

	if (Other != None)
	{
		MaintainMinimumAttackDistance(Other);

		if (TryAcquireEnemy(Other, true))
			return;
	}
}

//===========================================================================
// Events of note, care of the controller...
//===========================================================================

/**
 */
function OnEnemyTooClose(){
    super.OnEnemyTooClose();
   //            // Log( self @ "OnEnemyTooClose" @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;


	if (bot != None)
	{
		MaintainMinimumAttackDistance(bot.Enemy);
	}
	


}

/**
 */
function OnEnemyAcquired(){
    super.OnEnemyAcquired();
    //            // Log( self @ "OnEnemyAcquired" @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;
}

/**
 */
function OnUnderFire() {
    super.OnUnderFire();
  //              // Log( self @ "OnUnderFire" @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;

}

/**
 */
function OnRegainedSight(){
    super.OnRegainedSight();
//               // Log( self @ "OnRegainedSight" @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;
}

/**
 * Death of a friendly...
 */
function OnWitnessedDeath(){
    super.OnWitnessedDeath();
   //            // Log( self @ "OnWitnessedDeath" @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;
}

/**
 */
function OnLostSight() {
    super.OnLostSight();
  //             // Log( self @ "OnLostSight" @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;

	if (bot.Enemy != None && bot.Enemy.Health > 0)
	{
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
	}
	else
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

/**
 */
function OnEnemyTooFar(){
    super.OnEnemyTooFar();
    //            // Log( self @ "OnEnemyToFar" @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;

	/*if (bot.Enemy != None && bot.Enemy.Health > 0)
	{
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
	}
	else
	{
		GotoState('Wander');
		return;
	}*/


}

// Called whenever an enemy pawn is in sight.
function OnThreatSpotted(Pawn Threat)
{
    if (Threat == None)
        return;

	MaintainMinimumAttackDistance(Threat);

    if (TryAcquireEnemy(Threat, true))
        return;

    // If we already have a valid enemy, don't replace it with a worse target.
    if (HasValidEnemy())
        return;

    // zombies have stiff necks, they can't look up and down very far...
    if ( abs(threat.location.z - bot.pawn.location.z) > 512 ) {
        return;
    }

    super.OnThreatSpotted(Threat);
}

// Analagous to OnThreatSpotted().
function OnThreatHeard(Pawn Threat)
{
    if (Threat == None)
        return;

	MaintainMinimumAttackDistance(Threat);

    if (TryAcquireEnemy(Threat, false))
        return;

    super.OnThreatHeard(Threat);
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

    if (HeardPawn != None)
    {
		MaintainMinimumAttackDistance(HeardPawn);

		if (TryAcquireEnemy(HeardPawn, false))
		{
			return;
		}
    }

    if (TrySeekTarget(NoiseMaker))
    {
        GotoState('Seeking', 'BEGIN');
    }

    super.OnHeardNoise(Loudness, NoiseMaker);
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

    if (bot == None || (bot == Killer || bot.Pawn == None))
        return;

    if (bot.SameTeamAs(Killer))
        return;

    KillerPawn = Killer.Pawn;

    if (KillerPawn != None)
        TryAcquireEnemy(KillerPawn, true);
}

/**
 */
function awakenSucceeded() {
    super.awakenSucceeded();
    //            // Log( self @ "awakenSucceeded" @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;
}

/**
 */
function acquireEnemySucceeded() {
    super.acquireEnemySucceeded();
    //            // Log( self @ "acquireEnemySucceeded"  @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;
}

/**
 */
function NotEngagedAtRestSucceeded() {
    super.NotEngagedAtRestSucceeded();
   //            // Log( self @ "NotEngagedRestSucceeded"  @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;
}

/**
 */
function NotEngagedWanderSucceeded() {
    super.NotEngagedWanderSucceeded();
    //            // Log( self @ "NotEngagedWanderSucceeded"  @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;
}

/**
 */
function MoveToPositionSucceeded() {
    super.MoveToPositionSucceeded();
    //            // Log( self @ "MoveToPositionSucceeded"  @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;
}

/**
 */
function StandGroundSucceeded() {
    super.StandGroundSucceeded();
    //            // Log( self @ "StandGroundSucceeded"  @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;
}

/**
 */
function FireAtTargetSucceeded() {
    super.FireAtTargetSucceeded();
   //            // Log( self @ "FireAtTargetSucceeded"  @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;
}

/**
 */
function RecoverEnemySucceeded() {
    super.RecoverEnemySucceeded();
   //            // Log( self @ "RecoverEnemySucceeded"  @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;
}

/**
 */
function GetLOSSucceeded() {
    super.GetLOSSucceeded();
   //            // Log( self @ "GetLOSSucceeded" @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;
}

/**
 */
function GetLOSFailed() {
    super.GetLOSFailed();
   //            // Log( self @ "GetLosFailed" @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;
}

/**
 */
function HideFromEnemySucceeded() {
    super.HideFromEnemySucceeded();
   //            // Log( self @ self $ " HideFromEnemySucceeded" @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;
}

/**
 */
function outFromCoverSucceeded() {
    super.outFromCoverSucceeded();
   //            // Log( self @ self $ " outofcoverSucceeded" @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;
}

/**
 */
function supressionFireSucceeded() {
    super.supressionFireSucceeded();
   //            // Log( self @ "SupressionFireSucceeded" @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;
}

/**
 */
function TakeCoverSucceeded() {
    super.TakeCoverSucceeded();
  //             // Log( self @ "TakeCoverSucceeded" @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;
}

/**
 */
function TakeCoverFailed() {
    super.TakeCoverFailed();
   //            // Log( self @ "TakeCoverFailed" @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;
}

/**
 */
function ChargeSucceeded() {
    super.ChargeSucceeded();
   //            // Log( self @ "ChargeSucceeded" @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;
}

function ChargeFailed() {
    super.ChargeFailed();
    //            // Log( self @ "ChargeFailed"  @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;
}

/**
 */
function strafeMoveSucceeded() {
    super.StrafeMoveSucceeded();
   //            // Log( self @ "strafeMoveSucceeded" @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;
}

/**
 */
function HuntSucceeded() {
    super.HuntSucceeded();
  //             // Log( self @ "HuntSucceeded" @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;
}

/**
 */
function PanicSucceeded() {
    super.PanicSucceeded();
   //            // Log( self @ "PanicSucceeded" @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;
}

/**
 */
function advanceMoveSucceeded() {
    super.AdvanceMoveSucceeded();
   //            // Log( self @ "advancemoveSucceeded" @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;
}

function errorStopSucceeded() {
    super.ErrorStopSucceeded();
}

/**
 */
function takePositionFailed() {
    super.takePositionFailed();
   //            // Log( self @ "takepositionfailed" @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;
}

/**
 */
function TakePositionSuceeded() {
    super.TakePositionSuceeded();
   //            // Log( self @ "takepositionSucceeded" @ "FOCUS:" @ bot.focus @ "BestAttract:" @ BestAttractor )    ;
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
    local ActionableStaticMesh PotentialActionable;

    if (Obstacle == None || bot == None || bot.Pawn == None)
        return;

    PotentialEnemy = Pawn(Obstacle);

    if (IsValidEnemy(PotentialEnemy))
    {
        bot.AcquireEnemy(PotentialEnemy, true);
        GotoState('Attacking');
        return;
    }

    PotentialActionable = ActionableStaticMesh(Obstacle);

    if (PotentialActionable != None)
    {
        NumClearAttempts = 0;
        PotentialActionable.DoActionableAction(bot);
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
    local float Dist;

    if (!bAllowedToCharge || !HasValidEnemy())
        return false;

    if (bot.Pawn == None)
        return false;

    if (Level.TimeSeconds - ChargeStartTime < MinTimeBetweenCharges)
        return false;

    if (Level.TimeSeconds - bot.Pawn.SpawnTime < 5.0)
        return false;

    if (MaxChargingZombies > 0 &&
        default.NumChargingZombies >= MaxChargingZombies &&
        Level.TimeSeconds - default.LastChargeTime < MaxTimeBetweenCharges)
    {
        return false;
    }

    Dist = VSize(bot.Enemy.Location - bot.Pawn.Location);

    if (bot.Pawn.IsA('ScuttlingZombie'))
    {
        if (Dist > MaxChargeDist * 1.5)
            return false;
    }
    else
    {
        if (Dist > MaxChargeDist || Dist < MinChargeDist)
            return false;
    }

    return bot.ActorReachable(bot.Enemy);
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

    if (BotController != None)
        BotController.bForceRun = true;

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

    if (BotController != None)
        BotController.bForceRun = false;
}

function NavigationPoint FindWanderPoint()
{
    local Actor Target;
    local NavigationPoint TargetNode;
    local int NewOriginIndex;
    local int NewRank;

    if (bot == None || bot.Pawn == None || BotController == None)
        return None;

    if (BotController.GetWanderTarget(
        VeteranRouteOriginIndex,
        VeteranRouteRank,
        Target,
        TargetNode,
        NewOriginIndex,
        NewRank))
    {
        VeteranRouteTarget = Target;
        VeteranRouteNode = TargetNode;
        VeteranRouteOriginIndex = NewOriginIndex;
        VeteranRouteRank = NewRank;
        return TargetNode;
    }

    // Route exhausted. Reset so the next request starts from the spawn point
    // physically closest to the bot. No AllActors/NavigationPoint scan occurs here.
    VeteranRouteTarget = None;
    VeteranRouteNode = None;
    VeteranRouteOriginIndex = -1;
    VeteranRouteRank = 0;

    if (BotController.GetWanderTarget(
        VeteranRouteOriginIndex,
        VeteranRouteRank,
        Target,
        TargetNode,
        NewOriginIndex,
        NewRank))
    {
        VeteranRouteTarget = Target;
        VeteranRouteNode = TargetNode;
        VeteranRouteOriginIndex = NewOriginIndex;
        VeteranRouteRank = NewRank;
        return TargetNode;
    }

    return None;
}

//===========================================================================
// Wander
//===========================================================================

//===========================================================================
// Wander
//===========================================================================

auto state Wander
{
    function BeginState()
    {
        if (bot != None)
            bot.StopFiring();

        if (BotController != None)
            BotController.CheckWeaponStatus();

        VeteranRouteTarget = None;
        VeteranRouteNode = None;
        VeteranRouteOriginIndex = -1;
        VeteranRouteRank = 0;
    }

    function EndState()
    {
        if (bot != None && bot.Pawn != None)
            bot.Pawn.Acceleration = vect(0,0,0);
    }

    function NotEngagedWanderFailed()
    {
        if (HasValidEnemy())
            GotoState('Attacking');
        else
            GotoState('Wander');
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
            if (CachedFollowTarget != None && bot.ActorReachable(CachedFollowTarget))
            {
                bot.Perform_MoveToLocation(
                    CachedFollowTarget.Location,
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
            // Veteran route: the map landmarks were cached once at level startup.
            // Selecting the next landmark is now an O(number of spawn targets) lookup;
            // there is no per-tick AllActors scan or path-distance calculation here.
            if (FindWanderPoint() != None)
            {
                bot.Perform_MoveToLocation(
                    VeteranRouteNode.Location,
                    160
                );

                WaitForNotification();

                if (HasValidEnemy())
                {
                    GotoState('Attacking');
                    break;
                }

                Sleep(RandRange(MinWanderDelay, MaxWanderDelay));
                continue;
            }

            // Fallback for maps without usable route targets.
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
			GotoState('Wander');

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

        if (BotController != None)
            BotController.CheckWeaponStatus();

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

    if (HasValidEnemy() && (bot.EnemyIsVisible() && bot.CanAttack(bot.Enemy)))
        GotoState('Attacking');

    if (LastSeekInstigator != None)
        SeekLocation = LastSeekInstigator.Location;

    bot.Perform_MoveToLocation(SeekLocation, 128);

    SetMultiTimer(THINK_AGAIN_TIMER, 0.5, false);

    WaitForNotification();

    SetMultiTimer(THINK_AGAIN_TIMER, 0.5, false);

    if (HasValidEnemy() && (bot.EnemyIsVisible() && bot.CanAttack(bot.Enemy)))
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

        if (BotController != None)
            BotController.CheckWeaponStatus();

    }

    function OnLostSight()
    {
		if (bot.Enemy != None && bot.Enemy.Health > 0)
		{
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
		}
		else
		{
            GotoState('Wander');
            return;
		}
        /*if (!HasValidEnemy())
        {
            GotoState('Wander');
            return;
        }*/

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
        return (bot != None && A == bot.Enemy && (!bot.EnemyIsVisible() || !bot.CanAttack(bot.Enemy)));
    }

BEGIN:

    while (HasValidEnemy())
    {
        // Enemy may have died between state iterations.
        if (bot.Enemy == None || bot.Enemy.Health <= 0)
        {
            bot.Enemy = None;
            //GotoState('Wander');
            break;
        }

        //=============================================================
        // Minimum combat distance
        //=============================================================

        if (MaintainMinimumAttackDistance(bot.Enemy))
        {
            // Do not attack while retreating.
            bIgnoreBumps = false;

            // Cancel any charge-related timers.
            SetMultiTimer(CHARGE_TIMER, 0, false);
            SetMultiTimer(PRE_CHARGE_TIMER, 0, false);

            // Stop an active charge before retreating.
            EndCharge();

            WaitForNotification();

            // Recheck distance and enemy state next iteration.
            Sleep(0.05);
            continue;
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
            if (bot.EnemyIsVisible() && bot.CanAttack(bot.Enemy))
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
                    1.0,
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

    if (bot == None || bot.Pawn == None)
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

    BotController = UmodBotController(C);

    if (BotController == None)
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

    Player = bot.Enemy;
    if (Player == None || Player.bDeleteMe || Player.Health <= 0)
        Player = GetFollowTarget();

    if (Player == None || Player.bDeleteMe || Player.Health <= 0)
        return;

    Dist = VSize(Player.Location - bot.Pawn.Location);

    if (Player.Controller != None && bot.SameTeamAs(Player.Controller))
    {
        if (Dist > 300 && !HasValidEnemy() && !IsInState('Wander') && bot.ActorReachable(Player))
            GotoState('Wander');
        return;
    }

    if (!IsValidEnemy(Player) || Abs(Player.Location.Z - bot.Pawn.Location.Z) >= 1024.0)
        return;

    if (IsInState('Attacking') && bot.Enemy == Player)
        return;                                   // already on it

    if (bot.CanSee(Player) && bot.ActorReachable(Player))
    {
        bot.AcquireEnemy(Player, true);
        if (!IsInState('Attacking'))
            GotoState('Attacking');
    }
}

//===========================================================================
// Attack range
//===========================================================================

function bool InAttackRange(Actor EnemyActor)
{
    local float Dist;

    if (EnemyActor == None || bot == None || bot.Pawn == None)
        return false;

    Dist = VSize(bot.Pawn.Location - EnemyActor.Location);

    if (EnemyActor.IsA('ZombiePawnBase')
        && Dist < MIN_TARGET_DISTANCE)
    {
        return false;
    }

    if (bot.Pawn.Weapon != None
        && bot.Pawn.Weapon.IsA('DOTZMeleeWeapon'))
    {
        return Dist < MELEE_ATTACK_DIST;
    }

    return Dist < RANGE_ATTACK_DIST;
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