class UmodBotController extends DOTZAIController;

//=============================================================================
// CONFIG / CONSTANTS
//=============================================================================

const CONFIGURE_HACK_TIMER = 294850;

var const Material OtisDeadOverlay;

// Default weapons
const DefaultBackupWeaponType = "DOTZWeapons.GlockWeapon";

var string CurrentWeaponName;

var localized string xboxMsg;
var localized string PCMsg;

// ReplicationInfo
var GameReplicationInfo GameReplicationInfo;

var bool bLoggedOut;

// Game mode
var bool bCoopGameMode;

// Game mode
var bool bBotInstantRespawn;

// Awareness
var int iAwarenessRange;

// Awareness
var float CustomRefireRate;

var class<ExclaimManager> TheExclaimManagerclass;

var bool bForceRun;
var bool bConfigured;

var int CurrentPawnID;
var bool        bWantsToJump;
var bool        bDoubleJump;
var bool        bJumpStatus;    // used in net games
var bool        bUpdating;

var vector      LastDeathLocation;

//=============================================================================
// LIFECYCLE
//=============================================================================

//
// BeginPlay.
//
function BeginPlay()
{
	Super.BeginPlay();

	SetMultiTimer(CONFIGURE_HACK_TIMER, 3.0, false);
}

//
// Called after the actor has been spawned.
//
event PostBeginPlay()
{
    //local UmodHumanPawn theBotPawn;
	//local ZombieFactory ZF;

    if (Level.NetMode != NM_Standalone)
    {
		PickBotReplicationInfoClass();
    }

    Super.PostBeginPlay();

    bCoopGameMode = (Level.NetMode == NM_Standalone);

    if (Level.Game != None)
        GameReplicationInfo = Level.Game.GameReplicationInfo;

	/*if (ZF.TheCreationPolicy != None && !ZF.TheCreationPolicy.IsA('MultiplayerPolicy'))
	{
		bBotInstantRespawn = true;
	}*/
}

simulated event Destroyed()
{
    Cleanup();
    SetTimer(0.0, false);

    if (exclaimMgr != None) { exclaimMgr.Destroy(); exclaimMgr = None; }
    if (myAIRole != None)   { myAIRole.Destroy();   myAIRole = None; }

    // VERIFY: Super.Destroyed() in UT-style engines already calls Game.Logout
    // for bIsPlayer controllers. If scoreboards/bot counts drop by 2, remove this.
    if (Level.NetMode != NM_Standalone && Level.Game != None)
        Level.Game.Logout(Self);

    Super.Destroyed();
}

function Cleanup()
{
    if (currentStage != None)
    {
        currentStage.leaveStage(Self, RSN_Died);
        currentStage = None;
    }

    Enemy = None;  Target = None;  ShootTarget = None;  tmpTarget = None;
    pendingFocus = None;  VisibleEnemy = None;
    wanderDestination = None;  TakeUpPosition = None;

    if ((GoalScript != None) && (HoldSpot(GoalScript) == None))
        FreeScript();

    StopFiring();
    UnClaimPosition();

    /*
	Can't access private variable 'myCreator' in 'VGSPAIController'
	if (myCreator != None)
    {
        myCreator.OpponentDied(Self);
        myCreator = None;
    }*/
}

//=============================================================================
// POSSESSION
//=============================================================================

function Possess(Pawn P)
{
    if (Level.NetMode != NM_Standalone)
    {
        if (PlayerReplicationInfo == None)
        {
            PickBotReplicationInfoClass();

            if (PlayerReplicationInfoClass != None)
                PlayerReplicationInfo = Spawn(PlayerReplicationInfoClass, Self,,, rot(0,0,0));
        }

        if (PlayerReplicationInfo != None)
            InitPlayerReplicationInfo();
    }

    Super.Possess(P);

    if (P == None)
        return;

    if (P.Weapon == None)
        P.GiveWeapon(CurrentWeaponName);

    if (P.Weapon == None)
        P.GiveWeapon(DefaultBackupWeaponType);
}

//=============================================================================
// DEATH
//=============================================================================

function PawnDied(Pawn P)
{
    local NavigationPoint dest;

    if (P == None)
        return;

	LastDeathLocation = P.Location;

    if (P.Anchor != None) P.Anchor.FearCost += FEAR_PENALTY;
    dest = NavigationPoint(MoveTarget);
    if (dest != None) dest.FearCost += FEAR_PENALTY;

    if (myAIRole != None)
        myAIRole.OnKilled(None);

    Target = None;  Enemy = None;  Focus = None;
    bForceRun = false;
    StopFiring();

    Super.PawnDied(P);

    if (!bDeleteMe)
        GotoState('Dead');
}

simulated function String GetHumanReadableName()
{
	if ( PlayerReplicationInfo != None )
		return PlayerReplicationInfo.PlayerName;

	return "BOT Otis";
}

function InitPlayerReplicationInfo_bkp()
{
	if (PlayerReplicationInfo.PlayerName == "")
		PlayerReplicationInfo.SetPlayerName(class'GameInfo'.Default.DefaultPlayerName);
}

function PickBotReplicationInfoClass()
{
    local int idx, num;
    local Controller C;

    num = class'UnrealRepository'.default.BotReplicationInfoClassList.Length;
    if (num <= 0)
        return;

    for (C = Level.ControllerList; C != None; C = C.NextController)
        if (C != Self && C.IsA('UmodBotController'))
            idx++;

    if (idx >= num)
        idx = Rand(num);

    if (class'UnrealRepository'.default.BotReplicationInfoClassList[idx] != None)
        PlayerReplicationInfoClass = class'UnrealRepository'.default.BotReplicationInfoClassList[idx];

    if (PlayerReplicationInfoClass == None)
        PlayerReplicationInfoClass = class<PlayerReplicationInfo>(DynamicLoadObject("UMODDOTZGame.UmodBotReplicationInfo", class'Class'));

		/*
		theBotPawn = UmodHumanPawn(Pawn);

		if (theBotPawn != None && theBotPawn.BotReplicationInfoClass != None)
		{
			//PlayerReplicationInfo = Spawn(theBotPawn.BotReplicationInfoClass, Self,,, rot(0,0,0));
			PlayerReplicationInfoClass = theBotPawn.BotReplicationInfoClass;
		}

		//if (PlayerReplicationInfoClass == None)
		//{
			theIndex = 0;
			for (theController = Level.ControllerList; theController != None; theController = theController.NextController)
			{
				if (theController.IsA('UmodBotController'))
					theIndex++;
			}

			if (theIndex < 0 || theIndex >= class'UnrealRepository'.default.BotReplicationInfoClassList.Length)
			{
				theIndex = Rand(class'UnrealRepository'.default.BotReplicationInfoClassList.Length);
			}

			//PlayerReplicationInfo = Spawn(class'UnrealRepository'.default.BotReplicationInfoClassList[theIndex], Self,,, rot(0,0,0));
			if (class'UnrealRepository'.default.BotReplicationInfoClassList[theIndex] != None)
			{
				PlayerReplicationInfoClass = class'UnrealRepository'.default.BotReplicationInfoClassList[theIndex];
			}
		//}
		*/
}

//=============================================================================
// TEAM LOGIC
//=============================================================================

function bool SameTeamAs(Controller C)
{
	if (C == None){return false;}

	//
	// In coop, Otis is friendly to normal players and hostile to zombies.
	//
	if (bCoopGameMode)
	{
		// A zombie controller means hostile.
		return (ZombieAIController(C) == None);
	}

	return Super.SameTeamAs(C);
}


//=============================================================================
// RESPAWN
//=============================================================================

function bool CanRestartPlayer()
{
	return
	(
		(PlayerReplicationInfo == None ||
		 !PlayerReplicationInfo.bOnlySpectator)
		&&
		(Pawn == None || Pawn.Health <= 0)
	);
}

function MultiTimer(int timerID)
{
    switch (timerID)
    {
    case SIGHT_CHECK_TIMER:
        if (Enemy != None && Pawn != None
            && VSize(Enemy.Location - Pawn.Location) > Pawn.SightRadius)
        {
            EnemyNotVisible();
            Enemy = None;
        }
        break;

    case FOCUS_TIMER:
        Focus = PendingFocus;
        PendingFocus = None;
        break;

    case LOST_SIGHT_TIMER:
        Enable('EnemyNotVisible');
        break;

    case CONFIGURE_HACK_TIMER:     // was started in BeginPlay but never handled
        bConfigured = true;
        break;

    default:
        Super.MultiTimer(timerID);
    }
}

//=============================================================================
// ENEMY ACQUISITION
//=============================================================================

function AcquireEnemy(Pawn PotentialEnemy, bool bCanSeePotEnemy)
{
    if (Pawn == None || PotentialEnemy == None || PotentialEnemy == Enemy)
        return;

    AcquireTime = Level.TimeSeconds;
    Enemy = PotentialEnemy;
    FocalPoint = PotentialEnemy.Location;
    EnemyInSightTime = -1;
    MoveTimer = -1;
    SetCombatTimer();
    bEnemyAcquired = false;

    if (!bCanSeePotEnemy)
    {
        LastSeenTime = -1000;
        bEnemyInfoValid = false;
    }
    else
    {
        //if (exclaimMgr != None) exclaimMgr.Exclaim(EET_AcquireEnemy, 0);
        if (myAIRole != None)   myAIRole.OnEnemyAcquired();
        UpdateEnemyInfo();
    }

    SetCombatAttributes();
    if (myAIRole != None)
        myAIRole.AcquireEnemySucceeded();
}

function bool CanAttack(Actor Other)
{
    local bool result;

    if (Pawn == None || Pawn.Weapon == None || Other == None)
        return false;

	if (
		Enemy != None && Pawn != None &&
		(Pawn.Weapon.IsA('DOTZMeleeWeapon') || Pawn.Weapon.IsA('ChainsawWeapon')) &&
		VSize(Enemy.Location - Pawn.Location) > 150.0
	)
        return false;

    result = Pawn.Weapon.CanAttack(Other);
    if (bDebugLogging)
        DebugLog("Weapon.CanAttack() returned" @ result, DEBUG_FIRING);
    return result;
}

function bool isBehindMe(Actor a)
{
    if (a == None || Pawn == None) return false;
    return Vector(Pawn.Rotation) dot (a.Location - Pawn.Location) < 0.5;
}

function int iRandRange(int lo, int hi)
{
    if (hi < lo) hi = lo;
    return lo + Rand((hi - lo) + 1);
}

// Stub returned 0, so supression-fire Sleep(0) spun every tick
function float getWeaponFireRate(Weapon w) { return 0.15; }
// and in Engaged_SupressionFire BEGIN:
//   Sleep( FMax(0.1, NumShotsToGo * getWeaponFireRate(Pawn.Weapon)) );

// Stub always returned false; the commented body also had the bDeleteMe test inverted
function bool isTargetDestroyed()
{
    local Pawn p;
    if (ShootTarget == None || ShootTarget.bDeleteMe) return true;
    p = Pawn(ShootTarget);
    if (p != None) return p.Health <= 0;
    return false;
}

function TimedFireWeaponAtEnemy()
{
    if (Pawn == None || Pawn.Weapon == None || Enemy == None)
        return;
    if (EnemyInSightTime != -1 && !TimeElapsed(EnemyInSightTime, ReflexTime))
        return;
    if (Pawn.Weapon.IsFiring())
        return;

    NumShotsToGo = iRandRange(MinNumShots, MaxNumShots);
    CalculateMissVectorScale();
    WeaponFireAgain(Pawn.Weapon.RefireRate(), false);
}

function float ChanceToHit()
{
    local float skillOdds, range, relVelocity, losTime, result;

    if (Pawn == None || Enemy == None) return 0;

    skillOdds = FMin(MaxSkillOdds, Skill / 7.0);

    if (MaxAimRange <= 0) return 0;
    range = FClamp(1.0 - (VSize(Pawn.Location - Enemy.Location) / MaxAimRange), 0.0, 1.0);
    if (range == 0.0) return 0;

    relVelocity = Normal(Enemy.Location - Pawn.Location)
        dot Normal((Enemy.Location + 2.0*Enemy.Velocity) - (Pawn.Location + Pawn.Velocity));
    relVelocity = FClamp(relVelocity, 0.0, 1.0);
    if (relVelocity == 0.0) return 0;

    if (EnemyIsVisible() && MaxSecondsOfLOS > 0)
    {
        losTime = Level.TimeSeconds - EnemyInSightTime;
        losTime = FClamp(losTime / MaxSecondsOfLOS, 0.0, 1.0);
    }

    result = skillOdds * range * relVelocity * losTime;
    if (bDebugLogging)
        DebugLog("ChanceToHit:" @ result @ "skill:" @ skillOdds @ "range:" @ range
                 @ "relVel" @ relVelocity @ "los" @ losTime, DEBUG_FIRING);
    return result;
}

function rotator AdjustAim(Ammunition FiredAmmunition, vector projStart, int aimerror)
{
    if (FiredAmmunition != None && Target != None && Pawn != None)
        FiredAmmunition.WarnTarget(Target, Pawn, vect(1,0,0));

    if (aimError <= 0 || FRand() <= ChanceToHit())
        return AimToHit(FiredAmmunition, projStart, aimerror);

    return AimToMiss(FiredAmmunition, projStart, aimerror);
}

function Rotator AimToHit(Ammunition FiredAmmunition, vector projStart, int aimerror)
{
    local Vector FireSpot;
    local float projSpeed;
    local vector outHitLocation;
    local Pawn HitFriend;

    if (Target == None)
        return rotator(LastSeenPos - projStart);

    FireSpot = GetTweakedFireSpot(Target);

    if (FiredAmmunition != None && FiredAmmunition.bLeadTarget
        && FiredAmmunition.ProjectileClass != None)
    {
        projSpeed = FiredAmmunition.ProjectileClass.default.Speed;
        if (projSpeed > 0)
        {
            FireSpot += Target.Velocity * VSize(Target.Location - projStart) / projSpeed;
            if (WillFriendlyFire(projStart, FireSpot, HitFriend, outHitLocation))
                FireSpot = Target.Location;
        }
    }
    return Rotator(FireSpot - projStart);
}

function Rotator AimToMiss(Ammunition FiredAmmunition, vector projStart, int aimerror)
{
    local vector FireSpot, MissVector, outHitLocation;
    local rotator MissDir;
    local float dist, projSpeed, maxMiss;
    local Pawn HitFriend;

    if (Target == None || Pawn == None || !EnemyIsVisible())
        return rotator(LastSeenPos - projStart);

    dist = VSize(Target.Location - Pawn.Location);
    maxMiss = FMin(Target.CollisionRadius * 2.0, dist * 0.123);   // <= ~7 degree cone

    MissVector = vect(0,0,1) cross (Target.Location - Pawn.Location);
    MissVector.Z = 0;
    MissVector = MissVectorScale * Normal(MissVector) * maxMiss;
    MissVector.Z = RandRange(Target.CollisionHeight / 4, Target.CollisionHeight);

    FireSpot = Target.Location;
    if (FiredAmmunition != None && FiredAmmunition.bLeadTarget
        && FiredAmmunition.ProjectileClass != None)
    {
        projSpeed = FiredAmmunition.ProjectileClass.default.Speed;
        if (projSpeed > 0)
            FireSpot += Target.Velocity * VSize(Target.Location - projStart) / projSpeed;
    }

    MissDir = rotator((FireSpot + MissVector) - projStart);

    if (WillFriendlyFire(projStart, FireSpot + MissVector, HitFriend, outHitLocation))
        MissDir = rotator(outHitLocation + vect(0,0,1) * HitFriend.CollisionHeight - projStart);

    return MissDir;
}

function TrySpotEnemy(Pawn potentialEnemy, bool bCanSeePotEnemy,
                      optional bool bSuppressRoleNotifications)
{
    if (potentialEnemy == None || Enemy == potentialEnemy
        || potentialEnemy.Controller == None
        || SameTeamAs(potentialEnemy.Controller))
        return;

    if (!bSuppressRoleNotifications && myAIRole != None)
    {
        if (bCanSeePotEnemy) myAIRole.OnThreatSpotted(potentialEnemy);
        else                 myAIRole.OnThreatHeard(potentialEnemy);
    }

    if (currentStage != None)
        currentStage.Report_EnemySpotted(potentialEnemy, Self);
}

function DamageAttitudeTo(Pawn Other, float Damage)
{
    if (Pawn == None || Other == None)
        return;

    if (Pawn.Health > 0 && Damage > 0)
        TrySpotEnemy(Other, CanSee(Other));

    setLastHitTime();

    if (exclaimMgr != None)
    {
        //if (SameTeamAs(Other.Controller)){exclaimMgr.Exclaim(EET_FriendlyFire, 0);}
        //else{exclaimMgr.Exclaim(EET_Pain, RandRange(0, 0.5));}
    }

    if (myAIRole != None)
        myAIRole.OnTakingDamage(Other, Damage);
		//ClientMessage("DamageAttitudeTo", 'Event');
}

event HearNoise(float Loudness, Actor NoiseMaker)
{
    if (myAIRole != None)
        myAIRole.OnHeardNoise(Loudness, NoiseMaker);
    if (Pawn(NoiseMaker) != None)
        TrySpotEnemy(Pawn(NoiseMaker), false);
}

function ReceiveWarning(Pawn shooter, float projSpeed, vector FireDir)
{
    if (bDebugLogging && shooter != None)
        DebugLog("ReceivedWarning from " $ shooter $ shooter.Controller);
}

/* WeaponFireAgain()
Notification from weapon when it is ready to fire (either just finished firing,
or just finished coming up/reloading).
Returns true if weapon should fire.
If it returns false, can optionally set up a weapon change
*/

function bool WeaponFireAgain(float RefireRate, bool bFinishedFire)
{
    local bool bFireSuccess;
    local Ammunition theAmmunition;
    local Weapon W;

    if (Pawn == None)
    {
        StopFiring();
        return false;
    }

    W = Pawn.Weapon;
    if (W == None)
    {
        StopFiring();
        return false;
    }

    if (!W.HasAmmo())
    {
		//W.SwitchToWeaponWithAmmo();
        theAmmunition = W.AmmoType;
        if (theAmmunition != None)
            theAmmunition.AddAmmo(theAmmunition.MaxAmmo);
    }

    if (W.NeedsToReload())
    {
        ForceReload();
        W = Pawn.Weapon;
        if (W == None)
        {
            StopFiring();
            return false;
        }
    }

    if (Target == None)
        Target = Enemy;

    if (Target == None || (Target.bDeleteMe || !CanAttack(Target)))
    {
        bStopFireAnimation = true;
        StopFiring();
        return false;
    }

    if (!W.IsFiring())
    {
        if (W.IsA('DOTZMeleeWeapon') || (!NeedToTurn(Target.Location) && CanAttack(Target)))
        {
            if (exclaimMgr != None)
                exclaimMgr.Exclaim(EET_Attacking, 0, 0.5);

            if (NumShotsToGo > 0)
                NumShotsToGo--;

            UpdateFocus(Target, true);
            bFireSuccess = W.BotFire(bFinishedFire);

            if (!bFireSuccess)
                StopFiring();

            return bFireSuccess;
        }

        if (bFireAtLastLocation && !EnemyIsVisible() && !NeedToTurn(LastSeenPos))
            return W.BotFire(bFinishedFire);

        StopFiring();
        return false;
    }

    if (NumShotsToGo > 0)
    {
        NumShotsToGo--;

        if (Focus == Target && CanAttack(Target))
        {
            bFireSuccess = W.BotFire(bFinishedFire);

            if (!bFireSuccess)
                StopFiring();

            return bFireSuccess;
        }

        if (bFireAtLastLocation && !EnemyIsVisible() && !NeedToTurn(LastSeenPos))
            return W.BotFire(bFinishedFire);
    }

    bStopFireAnimation = true;
    StopFiring();
    return false;
}

function bool AdjustAround(Pawn Other)
{
    local float speed;
    local vector VelDir, OtherDir, SideDir;

    if (Pawn == None || Other == None) return false;

    speed = VSize(Pawn.Acceleration);
    if (speed <= 0 || speed < Pawn.WalkingPct * Pawn.GroundSpeed)
        return false;

    VelDir = Pawn.Acceleration / speed;
    VelDir.Z = 0;
    OtherDir = Other.Location - Pawn.Location;
    OtherDir.Z = 0;
    OtherDir = Normal(OtherDir);

    if ((VelDir Dot OtherDir) > 0.8)
    {
        bAdjusting = true;
        SideDir.X = VelDir.Y;
        SideDir.Y = -1 * VelDir.X;
        if ((SideDir Dot OtherDir) > 0)
            SideDir *= -1;
        AdjustLoc = Pawn.Location + 2 * Other.CollisionRadius * (0.5 * VelDir + SideDir);
        return true;
    }
    return false;
}

// // notifications of pawn events (from C++)
// // if return true, then pawn won't get notified 
// event bool NotifyPhysicsVolumeChange(PhysicsVolume NewVolume);
// event bool NotifyHeadVolumeChange(PhysicsVolume NewVolume);
// event bool NotifyLanded(vector HitNormal);
// event bool NotifyHitWall(vector HitNormal, actor Wall);
// event NotifyHitMover(vector HitNormal, mover Wall);
// event NotifyJumpApex();
// event NotifyMissedJump();

event bool NotifyBump(Actor Other)
{
    local Pawn P;

    Super.NotifyBump(Other);

    if (myAIRole != None) myAIRole.OnBump(Other);

    P = Pawn(Other);
    if (P == None) return false;

    TrySpotEnemy(P, true);

    if (Enemy != P)
        AdjustAround(P);

    return false;
}

function HandleWeaponPickUp( Pickup inPickup )
{
	/*local AdvancedWeapon oldWeapon;
	local RangedWeapon newWeapon;
	local class<RangedWeapon> WeapClass;

	oldWeapon = AdvancedWeapon(Pawn.Weapon);

	if(oldWeapon != None && (oldWeapon.WeaponMode == WM_Rapid))
	{
		return;
	}

	if(Pawn != None && inPickup != None)
	{
		WeapClass = class<RangedWeapon>(inPickup.InventoryType);

		if(WeapClass != None && (WeapClass.default.WeaponMode == WM_Rapid))
		{
			if(Pawn.FindInventoryType(WeapClass) == None)
			{
				newWeapon = Spawn(WeapClass,,,Pawn.Location);

				if( newWeapon != None && Pawn.Weapon != newWeapon)
				{
					if(Pawn.Weapon != None){Pawn.Weapon.DropFrom(Pawn.Location);}

					//Pawn.GiveWeapon(newWeaponName);
					//Pawn.AddInventory( newWeapon );
					newWeapon.GiveTo(Pawn);
					newWeapon.BringUp();
				}
			}
		}

	}*/
}

function Touch(Actor A)
{
	if (A != none && A.IsA('Pickup'))
	{
		HandleWeaponPickUp(Pickup(A));
	}

    Super.Touch(A);
}

//=============================================================================
// FIRE AT TARGET
//=============================================================================

function bool FireWeaponAt(Actor A)
{
    if (Pawn == None || Pawn.Weapon == None)
    {
        StopFiring();
        return false;
    }
    if (A == None) A = Enemy;
    if (A == None || (A.bDeleteMe || !CanAttack(A) || !LineOfSightTo(A)))
    {
        StopFiring();
        return false;
    }

    CheckWeaponStatus();

    Target = A;
    if (Pawn.Weapon.IsFiring())
        return true;

    NumShotsToGo = iRandRange(MinNumShots, MaxNumShots);
    CalculateMissVectorScale();
    return WeaponFireAgain(Pawn.Weapon.RefireRate(), false);
}

function CheckWeaponStatus()
{
    local Ammunition ammo;
    local Weapon W;
    /*local Vector Away;
    local Vector RetreatLocation;
    local float Dist;
    local Actor RetreatActor;*/

    if (Pawn == None || Pawn.Weapon == None)
    {
        StopFiring();
        return;
    }
    W = Pawn.Weapon;

    if (!W.HasAmmo())
    {
        ammo = W.AmmoType;
        if (ammo != None) ammo.AddAmmo(ammo.MaxAmmo);
    }

    if (W.NeedsToReload())
    {
		/*if (Enemy != None)
		{
			Dist = VSize(Enemy.Location - Pawn.Location);

			if (Dist <= 150.0)
			{
				// Direction from the enemy toward this 
				Away = Pawn.Location - Enemy.Location;

				// Avoid a zero-length direction when both actors overlap.
				if (VSize(Away) < 1.0)
					Away = vect(1,0,0);
				else
					Away = Normal(Away);

				// Aim beyond the minimum to prevent oscillation at the boundary.
				RetreatLocation = Enemy.Location
					+ Away * (250.0 + 40.0);

				RetreatActor = FindPathTo(RetreatLocation);

				if (RetreatActor != None)
					Perform_MoveToLocation(RetreatActor.Location, 40);
				else
					Perform_MoveToLocation(RetreatLocation, 40);
			}
		}*/

        ForceReload();
    }
        
}

//=============================================================================
// MOVEMENT
//=============================================================================

function Perform_NotEngaged_AtRest()
{
	CurBehaviour = "Rest";

	//
	// Otis should not remain permanently idle.
	// Use stand-ground only as a very short fallback.
	//
	Perform_Engaged_StandGround();
}

function bool ShouldWalk_Standalone()
{
    local PlayerController PC;

    if (Level.NetMode == NM_Standalone)
    {
        PC = Level.GetLocalPlayerController();
        if (PC != None && PC.Pawn != None && PC.Pawn.Health > 0)
		{
			return Pawn.FastTrace(PC.Pawn.Location, Pawn.Location);
		}
    }

    return false;
}

function bool ShouldWalk()
{
	if (Level.NetMode == NM_Standalone ){return ShouldWalk_Standalone();}

	return true;
	//return !bForceRun;
}

function bool ShouldStrafe()
{
	return true;
}


//=============================================================================
// MELEE / RANGED ATTACK DISPATCH
//=============================================================================

function Perform_MeleeAttack()
{
	if (Pawn == None ||
		Pawn.Weapon == None)
	{
		return;
	}

	if (bMeleeAttackCapable && (Pawn.Weapon.IsA('DOTZMeleeWeapon') || Pawn.Weapon.IsA('ChainsawWeapon')))
	{
		GotoState('MeleeAttack');
	}

	else if (bRangedAttackCapable)
	{
		GotoState('RangeAttack');
	}
}


function Perform_RangeAttack()
{
	if (Pawn == None ||
		Pawn.Weapon == None)
	{
		return;
	}

	if (Pawn.Weapon.IsA('DOTZMeleeWeapon'))
	{
		return;
	}

	if (!bRangedAttackCapable)
	{
		return;
	}

	GotoState('RangeAttack');
}


//=============================================================================
// MELEE ATTACK STATE
//=============================================================================

state MeleeAttack
{
BEGIN:

	CurBehaviour = "MeleeAttack";

	if (Pawn != None && Pawn.Weapon != None)
	{
		if (Enemy != None)
		{
			UpdateFocus(Enemy, true);
		}

		FinishRotation();

		Pawn.Acceleration = vect(0,0,0);
		Pawn.Velocity = vect(0,0,0);

        //Pawn.bWantsToCrouch = false;

		WeaponFireAgain(
			Pawn.Weapon.RefireRate(),
			false
		);

		//
		// Give the animation/notify system time to process the attack.
		//
		Sleep(1.5 + FRand() * 1.0);
	}

	if (MyAIRole != None)
	{
		MyAIRole.MeleeAttackSucceeded();
	}

	CurBehaviour = "MeleeAttack-done";
}


//=============================================================================
// RANGED ATTACK STATE
//=============================================================================

state RangeAttack
{
BEGIN:

	CurBehaviour = "RangeAttack";

	if (Pawn != None && Pawn.Weapon != None)
	{
		if (Enemy != None)
		{
			UpdateFocus(Enemy, true);
		}

		FinishRotation();

		Pawn.Acceleration = vect(0,0,0);
		Pawn.Velocity = vect(0,0,0);

        //Pawn.bWantsToCrouch = false;

		WeaponFireAgain( Pawn.Weapon.RefireRate(), false );

		Sleep(0.1);
		//Sleep(1.5 + FRand() * 1.0);
	}

	if (MyAIRole != None)
	{
		MyAIRole.MeleeAttackSucceeded();
	}

	CurBehaviour = "RangeAttack-done";
}

state MoveToPosition
{
    //ignores EnemyNotVisible;

BEGIN:

   if ( isBehindMe(MoveTarget) || Pawn.bWantsToCrouch || Enemy == None ) {
       UpdateFocus( MoveTarget );
       FinishRotation();

       /* OldAccel = Pawn.Acceleration;
        Pawn.Acceleration = NewAccel;
        if ( bDoubleJump && (bUpdating || Pawn.CanDoubleJump()) )
            Pawn.DoDoubleJump(bUpdating);
        else if ( bPressedJump )
            Pawn.DoJump(bUpdating);
        if ( Pawn.Physics != PHYS_Falling )
        {
            OldCrouch = Pawn.bWantsToCrouch;
            if (bDuck == 0)
                Pawn.ShouldCrouch(false);
            else if ( Pawn.bCanCrouch )
                Pawn.ShouldCrouch(true);
        }*/
		
       
	   //Pawn.DoJump(False);
	   
       MoveToward(MoveTarget,,, ShouldStrafe(), ShouldWalk() );
   }
   else {
       UpdateFocus( Enemy );
       MoveToward(MoveTarget, Enemy,, ShouldStrafe(), ShouldWalk() );
   }
   //NOTE maybe too soon to say success/fail?
   myAIRole.MoveToPositionSucceeded();
}


/**
 * BEHAVIOUR - MoveToLocation
 *
 * Move to the specified location.  The is the most general
 * move-behaviour.
 */
function Perform_MoveToLocation( vector location, optional float slop ) {
    moveDestination = location;
    moveSlop = slop;
    GotoState( 'MoveToLocation' );
}

function Continue_MoveToLocation() {
    if ( VSize(pawn.location - moveDestination)
             < pawn.CollisionRadius + 8 + moveSlop ) {
        // reached destination...
        GotoState( 'MoveToLocation', 'DONE' );
        myAIRole.MoveToLocationSucceeded();
        return;
    }
    else {
        //TODO: perhaps check if we're stuck?
        GotoState( 'MoveToLocation', 'MOVE' );
    }
}

state MoveToLocation {

BEGIN:
    curBehaviour = "MoveToLocation";
MOVE:
    FinishRotation();
    if ( pointReachable(moveDestination) ) {
        debugLog( "moving directly to" @ moveDestination );
        FocalPoint = moveDestination;
        moveTo( moveDestination,, ShouldWalk() );
    }
    else {
        moveTarget = FindPathTo( moveDestination );
        if ( moveTarget == none ) {
            debugLog( "can't find path to" @ moveDestination );
            if ( RouteGoal != none
                 && VSize(pawn.location - moveDestination)
                      > VSize(pawn.location - routeGoal.location) ) {
                debugLog( "falling back to" @ RouteGoal );
                //TODO: maybe insert a melee attack here?
                Sleep( RandRange(0.07, 0.15) );
                moveTarget = FindPathToward( routeGoal );
            }
            else {
                Sleep( 0.3 );
                if (myAIRole != none){
                  myAIRole.MoveToLocationFailed();
                }
                Goto( 'DONE' );
            }
        }
        if (MoveTarget !=None){

				if (Enemy == None || (Enemy.bDeleteMe || !CanAttack(Enemy)))
				{
					StopFiring();
				}

         // if we didn't hit the Goto, moveTarget should be okay now...
         debugLog( "moving to" @ moveTarget );
         FocalPoint = moveTarget.location;
         moveToward( moveTarget,,,ShouldStrafe(), ShouldWalk() );
        }
    }
    Sleep( RandRange(0.1, 0.3) );
    Continue_MoveToLocation();

DONE:
    curBehaviour      = "DoneMovingToLocation";
    Pawn.Acceleration = vect(0,0,0);
    Pawn.Velocity     = vect(0,0,0);

}


//=============================================================================
// AWARENESS
//=============================================================================

function bool InAwarenessRange(Actor EnemyActor)
{
	if (Pawn == None || EnemyActor == None)
	{
		return false;
	}

	return VSize(Pawn.Location - EnemyActor.Location) < iAwarenessRange;
}


function ForceReload()
{
    if ( (Pawn != None) && (Pawn.Weapon != None) )
    {
        Pawn.Weapon.ForceReload();
    }
}

function SpawnExclaimManager()
{
    if (exclaimMgr != None || TheExclaimManagerclass == None)
        return;

    exclaimMgr = Spawn(TheExclaimManagerclass, Self);
    if (exclaimMgr != None)
        exclaimMgr.Init(Self);
}

// Send a voice message of a certain type to a certain player.
function Speech( name Type, int Index, string Callsign )
{
    if(PlayerReplicationInfo.VoiceType != None)
        PlayerReplicationInfo.VoiceType.static.PlayerSpeech( Type, Index, Callsign, Self );
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

    if (Level.Game.IsA('UmodDOTZInvasion'))
    {
        return UmodDOTZInvasion(Level.Game).GetBotWanderTarget(
            Pawn, CurrentOriginIndex, CurrentRank,
            Target, TargetNode, NewOriginIndex, NewRank
        );
    }

    if (Level.Game.IsA('UmodDOTZDeathMatch'))
    {
        return UmodDOTZDeathMatch(Level.Game).GetBotWanderTarget(
            Pawn, CurrentOriginIndex, CurrentRank,
            Target, TargetNode, NewOriginIndex, NewRank
        );
    }

    if (Level.Game.IsA('UmodDOTZCaptureTheFlag'))
    {
        return UmodDOTZCaptureTheFlag(Level.Game).GetBotWanderTarget(
            Pawn, CurrentOriginIndex, CurrentRank,
            Target, TargetNode, NewOriginIndex, NewRank
        );
    }

    return false;
}

function float WeightStagePosition(StagePosition position)
{
    local float total;

    if (position == None || currentStage == None || Enemy == None || Pawn == None)
        return 0;

    total = m_BunchPenalty + m_BlockedPenalty + m_BlockingPenalty + m_NeedForCover
          + m_NeedForContact + m_NeedCohesion + m_NeedForIntel + m_NeedToAvoidCorpses
          + m_NeedForClosingIn + m_NeedForNearbyGoal;
    if (total <= 0.0)
        return 0;

    return (
        m_BunchPenalty       * ProjDistToBuddiesAsSeenFromThreat(position)
      + m_BlockedPenalty     * BlockedLineOfFireByBuddies(position)
      + m_BlockingPenalty    * BlockingLineOfFireOfBuddies(position)
      + m_NeedForCover       * DistanceToNearestFreeCoverSpot(position)
      + m_NeedForContact     * NumberOfLinesOfSightToBuddies(position)
      + m_NeedCohesion       * ProperDistanceToBuddies(position)
      + m_NeedForIntel       * NumberOfLinesOfSightToThreats(position)
      + m_NeedToAvoidCorpses * DistanceToDeadBuddies(position)
      + m_NeedForClosingIn   * MinimumDistanceToThreat(position)
      + m_NeedForNearbyGoal  * DistanceFromMe(position)
    ) / total;
}

// In ProjDistToBuddiesAsSeenFromThreat, BlockedLineOfFireByBuddies,
// BlockingLineOfFireOfBuddies, ProperDistanceToBuddies change
//     if( currentStage.StageAgents.Length == 1) return 1.0;
// to
//     if( currentStage.StageAgents.Length <= 1) return 1.0;
// (Length 0 divided by -1)

function bool PickClosestBetterSpot(float baseWeight, float baseDist,
                                    StagePosition oldPosition, out StagePosition newPosition)
{
    local StagePosition position;
    local float dist, bestDist;
    local int i;

    newPosition = None;
    if (currentStage == None || Enemy == None || Pawn == None)
        return false;

    bestDist = 99999;
    for (i = 0; i < currentStage.StagePositions.Length; i++)
    {
        position = currentStage.StagePositions[i];
        if (position == None || position == oldPosition || position.bIsClaimed)
            continue;
        if (VSize(position.Location - Enemy.Location) > baseDist)
            continue;
        dist = VSize(position.Location - Pawn.Location);
        if (dist >= bestDist)
            continue;
        if (!VerifyShootingPosition(position) || WeightStagePosition(position) < baseWeight)
            continue;
        bestDist = dist;
        newPosition = position;
    }
    return (newPosition != None);
}

function Perform_Engaged_AdvanceMove()
{
    local StagePosition oldPosition, bestPosition;
    local float oldWeight, oldDist;

    curBehaviour = "AdvanceMove";
    if (currentStage == None || Enemy == None || Pawn == None)
    {
        curBehaviour = "NoStageOrEnemy";
        Perform_Error_Stop();
        return;
    }

    oldPosition = claimedPosition;
    if (oldPosition == None) { oldWeight = 0; oldDist = 99999; }
    else
    {
        oldWeight = WeightStagePosition(oldPosition);
        oldDist   = VSize(oldPosition.Location - Enemy.Location);
    }

    UnClaimPosition();
    if (!PickClosestBetterSpot(oldWeight, oldDist, oldPosition, bestPosition))
    {
        ClaimPosition(oldPosition);          // keep what we had
        curBehaviour = "NoNewTacticalSpot";
        Perform_Error_Stop();
        return;                              // was missing
    }

    ClaimPosition(bestPosition);
    Continue_Engaged_AdvanceMove();
}

function Perform_Engaged_OutFromCover()
{
    local int i;
    local StagePosition position, shootDest;
    local float dist, tmpDist;

    curBehaviour = "OutFromCover";
    if (currentStage == None || Enemy == None || Pawn == None)
    {
        curBehaviour = "NoStageOrEnemy";
        Perform_Error_Stop();
        return;
    }

    if (claimedPosition != None && currentStage.positionHasLOFToEnemy(claimedPosition, Enemy))
    {
        GotoState('Engaged_OutFromCover', 'STANDUP');
        Pawn.bWantsToCrouch = false;
        return;
    }

    UnClaimPosition();
    tmpDist = 1200;
    for (i = 0; i < currentStage.StagePositions.Length; i++)
    {
        position = currentStage.StagePositions[i];
        if (position == None || position.bIsClaimed
            || !currentStage.positionHasLOFToEnemy(position, Enemy))
            continue;
        dist = VSize(position.Location - LastSeeingPos);
        if (dist < tmpDist) { tmpDist = dist; shootDest = position; }
    }

    if (shootDest == None)
    {
        curBehaviour = "NoOutFromCoverSpot";
        Perform_Error_Stop();
        return;                              // was missing
    }

    ClaimPosition(shootDest);
    Continue_Engaged_OutFromCover();
}

function bool NoLongerOnGoodPosition()
{
    if (claimedPosition == None || currentStage == None || Enemy == None || Pawn == None)
        return true;
    if (!currentStage.PositionHasLOFToEnemy(claimedPosition, Enemy)) return true;
    if (currentStage.calculateStagePosnBlocksLOS(Self, claimedPosition) > 0) return true;
    if (currentStage.calculateStagePosnLOSIsBlocked(Self, claimedPosition) > 0) return true;
    if (!VerifyShootingPosition(claimedPosition)) return true;
    return VSize(Enemy.Location - Pawn.Location) > GetMaxFiringRange();
}

function Perform_Engaged_StrafeMove_new()
{
    curBehaviour = "Strafe";

    if (Pawn == None || !PickStrafeDir_new())
        return;

    GotoState('Engaged_StrafeMove');
}

function bool PickStrafeDir_new()
{
    local Vector strafeDir;

    strafeDir = Normal(Vector(Rotation) cross vect(0,0,1));
    bStrafeDir = !bStrafeDir;
    if (bStrafeDir)
        strafeDir = -1 * strafeDir;

    if (!TestDirection(strafeDir, Pawn.CollisionRadius * RandRange(2.0, 5.0), strafeTarget))
    {
        curBehaviour = "NoStrafeDir";
        Perform_Error_Stop();
        return false;
    }
    return true;
}

function Continue_EngagedCharge()
{
    if (Enemy == None || Pawn == None)
    {
        GotoState('Engaged_Charge', 'DONE');
        if (myAIRole != None) myAIRole.ChargeFailed();
    }
    else if (VSize(Pawn.Location - Enemy.Location)
                 < (Pawn.CollisionRadius + Enemy.CollisionRadius + 8)
             || Pawn.ReachedDestination(Enemy))
    {
        GotoState('Engaged_Charge', 'DONE');
        if (myAIRole != None) myAIRole.ChargeSucceeded();
    }
    else if (Level.TimeSeconds > chargeEndTime)
    {
        GotoState('Engaged_Charge', 'DONE');
        if (myAIRole != None) myAIRole.ChargeFailed();
    }
    else if (ActorReachable(Enemy))
    {
        MoveTarget = Enemy;
        GotoState('Engaged_Charge', 'MOVE');
    }
    else if (FindBestPathToward(Enemy, false, true))
        GotoState('Engaged_Charge', 'MOVE');
    else
    {
        GotoState('Engaged_Charge', 'DONE');
        if (myAIRole != None) myAIRole.ChargeFailed();
    }
}

event ClientMessage( coerce string S, optional Name Type )
{
    if (Type == '')
        Type = 'Event';

    TeamMessage(PlayerReplicationInfo, S, Type);
}

event TeamMessage( PlayerReplicationInfo PRI, coerce string S, name Type  )
{
    //if ( myHUD != None )
    //myHUD.Message( PRI, S, Type );

    if ( ((Type == 'Say') || (Type == 'TeamSay')) && (PRI != None) )
        S = PRI.PlayerName$": "$S;

    //if ( Player != None )
    //Player.Console.Message( S, 6.0 );
}

function bool HasMeleeWeapon()
{
    return (Pawn != None && Pawn.Weapon != None && (Pawn.Weapon.IsA('DOTZMeleeWeapon') || Pawn.Weapon.IsA('ChainsawWeapon')));
}

/*Called if the reachspec doesn't support the pawn's current configuration.
By default, the pawn will crouch when it hits an actual obstruction. However,
Pawns with complex behaviors for setting up their smaller collision may want
to call that behavior from here
*/
//event PrepareForMove(NavigationPoint Goal, ReachSpec Path);

//native(523) final function vector EAdjustJump(float BaseZ, float XYSpeed);

/*exec function SwitchToBestWeapon()
{
	local float rating;

	if ( Pawn == None || Pawn.Inventory == None )
		return;

    if ( (Pawn.PendingWeapon == None) || (AIController(self) != None) )
    {
	Pawn.PendingWeapon = Pawn.Inventory.RecommendWeapon(rating);
	if ( Pawn.PendingWeapon == Pawn.Weapon )
		Pawn.PendingWeapon = None;
	if ( Pawn.PendingWeapon == None )
		return;
    }

	StopFiring();

	if ( Pawn.Weapon == None )
		Pawn.ChangedWeapon();
	else if ( Pawn.Weapon != Pawn.PendingWeapon )
    {
		Pawn.Weapon.PutDown();
    }
}*/

function Vector GetStrafeDir(Vector inLocation)
{
    local Vector strafeDir;

    strafeDir = Normal(Vector(Rotation) cross vect(0,0,1));
    bStrafeDir = !bStrafeDir;
    if (bStrafeDir)
        strafeDir = -1 * strafeDir;

    if (TestDirection(strafeDir, Pawn.CollisionRadius * RandRange(2.0, 5.0), inLocation))
    {
        return strafeDir;
    }

    return inLocation;
}

//=============================================================================
// DEFAULT PROPERTIES
//=============================================================================

defaultproperties
{
	PawnClass=Class'UMODDOTZGame.UmodHumanPawn'
	AIType=Class'UMODDOTZGame.UmodBotAIRole'

	//PlayerReplicationInfoClass=Class'Engine.PlayerReplicationInfo'
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

	iAwarenessRange=4000.000000

	bMeleeAttackCapable=True
	bRangedAttackCapable=True

	bAdvancedTactics=True
	bCanOpenDoors=True
	bCanDoSpecial=True
	bAdjusting=True
	bJumpOverWall=True

	bBotInstantRespawn = False
	bCoopGameMode=False

	CustomRefireRate=0.500000

	CurrentWeaponName = "DOTZWeapons.GlockWeapon"

}