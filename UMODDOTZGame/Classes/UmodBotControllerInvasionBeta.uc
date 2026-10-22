class UmodBotControllerInvasionBeta extends UmodBotController;

var UmodDOTZInvasion InvasionMode;

//
// Called after the actor has been spawned.
//
event PostBeginPlay()
{
    Super.PostBeginPlay();

    if (Level != None && Level.Game != None)
        InvasionMode = UmodDOTZInvasion(Level.Game);

	/*if (ZF.TheCreationPolicy != None && !ZF.TheCreationPolicy.IsA('MultiplayerPolicy'))
	{
		bBotInstantRespawn = true;
	}*/
}

function Possess(Pawn P)
{
    local int I;

	if (bBotInstantRespawn)
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

    if (InvasionMode == None && Level != None && Level.Game != None)
        InvasionMode = UmodDOTZInvasion(Level.Game);

}


function bool ShouldWalk()
{
	if (Level.NetMode == NM_Standalone ){return ShouldWalk_Standalone();}

	return false;
	return (Enemy != None);
	//return (!IsInState( 'Wander' ));
	return !bForceRun;
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
        if (exclaimMgr != None) exclaimMgr.Exclaim(EET_AcquireEnemy, 0);
        if (myAIRole != None)   myAIRole.OnEnemyAcquired();
        UpdateEnemyInfo();
    }

    SetCombatAttributes();
    if (myAIRole != None)
        myAIRole.AcquireEnemySucceeded();
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
        if (SameTeamAs(Other.Controller)){exclaimMgr.Exclaim(EET_FriendlyFire, 0);}
        else{exclaimMgr.Exclaim(EET_Pain, RandRange(0, 0.5));}
    }

    if (myAIRole != None)
        myAIRole.OnTakingDamage(Other, Damage);
		//ClientMessage("DamageAttitudeTo", 'Event');
}

function CheckWeaponStatus()
{
    local Ammunition ammo;
    local Weapon W;
    local Vector Away;
    local Vector RetreatLocation;
    local float Dist;

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
		if (Enemy != None)
		{
			Dist = VSize(Enemy.Location - Pawn.Location);

			if (Dist <= 300.0)
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
					+ Away * (300.0 + 40.0);

				Perform_MoveToLocation(RetreatLocation, 40);
			}
		}

        ForceReload();
    }
        
}

function HandleWeaponPickUp( Pickup inPickup )
{
	local AdvancedWeapon oldWeapon;
	local RangedWeapon newWeapon;
	local class<RangedWeapon> WeapClass;

	if (bBotInstantRespawn)
	{
		return;
	}

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

	}
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

    if (InvasionMode == None)
        return false;

	return InvasionMode.GetBotWanderTarget(
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
	AIType=Class'UMODDOTZGame.UmodBotAIRoleInvasionBeta'

	//PlayerReplicationInfoClass=Class'Engine.PlayerReplicationInfo'
	PlayerReplicationInfoClass=Class'UMODDOTZGame.UmodBotReplicationInfo'

    TheExclaimManagerclass=Class'UMODDOTZGame.UmodBotExclaimMgr'

	xboxMsg="Game Over. Press START to continue."
	PCMsg="Game Over. Press fire to continue."

	MinNumShots=4
	MaxNumShots=7

	MinShotPeriod=0.100000
	MaxShotPeriod=0.500000

	MaxAimRange=3000.000000
	MaxSecondsOfLOS=1.000000

	iAwarenessRange=4000

	bMeleeAttackCapable=True
	bRangedAttackCapable=True

	bAdvancedTactics=True
	bCanOpenDoors=True
	bCanDoSpecial=True
	bAdjusting=True
	bJumpOverWall=True

	bCoopGameMode=False

	CustomRefireRate=0.1

	CurrentWeaponName = "DOTZWeapons.GlockWeapon"

     bIsPlayer=True
}