//=============================================================================
// XOtisAIController. XDOTZOtisAI
//=============================================================================
class XOtisAIController extends OtisAIController
	placeable;
    //config(user);

// settings
var int iAwarenessRange;
var string DefaultWeaponType;

// internal
var class<ExclaimManager> TheExclaimManager;
var bool bForceRun;
const CONFIGURE_HACK_TIMER = 294850;
var bool bConfigured;
const EATCHANNEL = 20;

//
// Called immediately before gameplay begins.
//
event PreBeginPlay()
{
    super.PreBeginPlay();
	
     xboxMsg="Game Over. Press START to continue.";
     PCMsg="Game Over. Press fire to continue.";
     MinNumShots=5;
     MaxNumShots=15;
     MinShotPeriod=0.800000;
     MaxShotPeriod=2.200000;
     MaxAimRange=3000.000000;
     MaxSecondsOfLOS=0.100000;

     iAwarenessRange=3000;
     DefaultWeaponType="MyLevel.XOtisM16Weapon";
     bMeleeAttackCapable=False;
     bRangedAttackCapable=True;
     AIType=Class'MyLevel.XOtisAIRole';
}

function BeginPlay() {
    super.BeginPlay();
    SetMultiTimer( CONFIGURE_HACK_TIMER, 3, false );
}


//===========================================================================
//
//===========================================================================

/**
 */
function Possess( Pawn p )
{
    super.Possess( p );
    DefaultWeaponType="MyLevel.XOtisM16Weapon";    
    //p.GiveWeapon( "DOTZWeapons.OtisRevolverWeapon" );
    p.GiveWeapon( "DOTZWeapons.M16Weapon" );
}

/**
 */
function bool SameTeamAs(Controller C)
{
    // not a zombie, on my team.
    return (ZombieAIController(c) == None);
}


//===========================================================================
// Otis-death game logic...
//===========================================================================

/**
 */
function PawnDied(Pawn P)
{
    local AdvancedPlayerController apc;

    Super.PawnDied(P);
    /*
    apc = AdvancedPlayerController( Level.GetLocalPlayerController() );
    //make sure that the player doesn't die too
    AdvancedPawn(apc.Pawn).bGodMode = true;
    //make the view of the dead otis
    apc.bBehindView = true;
    apc.SetViewTarget(p);
    apc.Unpossess();
    //apc.SpectatingOverlay = OtisDeadOverlay;
    //XBOX
    if (apc.IsA('XDotzPlayerController') == true){
      apc.SpectatingMsg = xboxMsg;
    } else {
      apc.SpectatingMsg = PCMsg;
    }
    */
}

function bool FireWeaponAt(Actor A)
{
    //A.isA('ZombiePawnBase')
    //DebugLog( "Trying to fire at" @ A );
    if ( A == None ) A = Enemy;
    Target = A;
    if ( (Pawn.Weapon != None) && Pawn.Weapon.HasAmmo()
             && !Pawn.Weapon.IsFiring() ) {
        NumShotsToGo = iRandRange(MinNumShots,MaxNumShots);
        CalculateMissVectorScale();
        return WeaponFireAgain(Pawn.Weapon.RefireRate(),false);
    }
    else {
        DebugLog( "Unable to fire weapon:" @ Pawn.weapon, DEBUG_FIRING );
        return false;
    }
}


function Perform_NotEngaged_AtRest()
{
    curBehaviour = "Rest";
    //GotoState('NotEngaged_AtRest');
    Perform_Engaged_StandGround();
}

//===========================================================================
// Helpers
//===========================================================================


/**
 */
function bool shouldWalk() 
{return !bForceRun;}

/**
 */
function bool ShouldStrafe()
{return true;}

/**
 * Attempt a melee attack against the current enemy.
 */
function Perform_MeleeAttack()
{
     GotoState( 'MeleeAttack' );
}

/**
 */
state MeleeAttack
{

BEGIN:
    curBehaviour = "MeleeAttack";
    if ( Enemy != none ) updateFocus( Enemy, true );
    FinishRotation();
    //TODO: check range? move closer?
    Pawn.Acceleration = vect(0,0,0);
    Pawn.Velocity     = vect(0,0,0);
    //NOTE: with the current melee implementation, this just means firing the
    //      "weapon"
    WeaponFireAgain(Pawn.Weapon.RefireRate(),false);
    //TODO: sync up with completion of the attack animation...
    sleep( 2 + FRand() * 1 );
    //TODO: if we had feedback from the weapon about hit/miss, the role callback
    //      would be more meaningful...
    myAiRole.MeleeAttackSucceeded();
    curBehaviour = "MeleeAttack-done";
}

/****************************************************************
 * InAwarnessRange
 ****************************************************************
 */
function bool InAwarenessRange(actor enemy)
{
   if(VSize(pawn.location - enemy.location) < iAwarenessRange){
      return true;
   } else {
      return false;
   }
}

/**
function SpawnExclaimManager()
{
   exclaimMgr = Spawn(TheExclaimManager, self);
   exclaimMgr.init(self);
}

 * Override firing to trigger the melee flail of a zombie.
 *
 * NOTE This won't be necessary if we make the ZombieGrope weapon fully
 * NOTE functional.
 */
function TimedFireWeaponAtEnemy()
{
                // Log( self @ "firing!"  )    ;
    //NOTE assumes the weapon is a melee attack weapon...
    if ( (Pawn.Weapon != None) && !Pawn.Weapon.IsFiring() ) {
        WeaponFireAgain( Pawn.Weapon.RefireRate(), false );
    }
}


//===========================================================================
// Default Properties
//===========================================================================
/*
defaultproperties
{
     xboxMsg="Game Over. Press START to continue."
     PCMsg="Game Over. Press fire to continue."
     MinNumShots=5
     MaxNumShots=15
     MinShotPeriod=0.800000
     MaxShotPeriod=2.200000
     MaxAimRange=1000.000000
     MaxSecondsOfLOS=5.000000

     iAwarenessRange=1000
     DefaultWeaponType="DOTZWeapons.M16Weapon"
     bMeleeAttackCapable=True
     bRangedAttackCapable=True
     AIType=Class'XDOTZOtisAI.XOtisAIRole'
}
*/
