//=============================================================================
// UmodHumanPawn.
//=============================================================================
class UmodHumanPawn extends XDOTZPawnBase
	placeable;

var() class<PlayerReplicationInfo> BotReplicationInfoClass;

const MELEE_DAMAGE = 20;

var(Display) const Mesh DefaultPawnMesh;
var(Display) const Material DefaultHeadTexture;
var(Display) const Material DefaultBodyTexture;

var array<string> Names;
var class<emitter> InfectiousEmitterClass;
var emitter InfectiousEmitter;
var bool bInfectious;

struct MeleeInfo{
   var name MeleeAttackAnim;
   var bool bFunctional;
   var int DamageDelay;
   var array<name> ReqBones;
};

var int iMeleeDamageRadius;
var int iMeleeAttackRange;
var int iMeleeDamageAmount;

var array<MeleeInfo> MeleeAttacks;
var array<MeleeInfo> CrawlingMeleeAttacks;
var class<DamageType> ZombieDamage;

var array<name> Walks;
var array<name> LegBones;
var array<name> LeftArmBones;
var array<name> RightArmBones;

var bool bCrawlTransition;
var name AnimCrawlingTransition;
var bool bPlayedFallOnFace;

var sound SquiggleSound;

var array<sound> PlayerHitSound;
var array<sound> NonPlayerHitSound;

var array<sound> EnemySpottedSound;

var array<sound> HelpMeSound;

var array<sound> FallingSound;

var protected bool bPlayedEnemySpottedSound;

const SQUIRMTIMER = 334;

event PostBeginPlay()
{
    if (Level.NetMode != NM_Standalone)
    {
		bDontPossess = true;
    }

    if (Mesh == None)
	{
        //Mesh = SkeletalMesh(DynamicLoadObject("DOTZAHumans.JackSlade", class'SkeletalMesh', true));

		LinkMesh( DefaultPawnMesh );

		HeadTextures[0]=DefaultHeadTexture;
		HeadTextures[1]=DefaultHeadTexture;
		HeadTextures[2]=DefaultHeadTexture;
		BodyTextures[0]=DefaultBodyTexture;
		BodyTextures[1]=DefaultBodyTexture;
		BodyTextures[2]=DefaultBodyTexture;

		Skins[0]=DefaultBodyTexture;
		Skins[1]=DefaultHeadTexture;
    }

	BotReplicationInfoClass=Class'UMODDOTZGame.UmodBotReplicationInfoJack';
    Super.PostBeginPlay();
}

function TakeDamage( int Damage, Pawn instigatedBy, Vector hitlocation,
                        Vector momentum, class<DamageType> damageType)
{
	Super.TakeDamage( Damage, instigatedBy, hitlocation, momentum, damageType);

    /*if ( damagetype == None )
    {
        if ( InstigatedBy != None )
        warn("No damagetype for damage by "$instigatedby$" with weapon "$InstigatedBy.Weapon);
        DamageType = class'DamageType';
    }

        if ( Controller != None )
            Controller.NotifyTakeHit(instigatedBy, HitLocation, actualDamage, DamageType, Momentum);
    }
    MakeNoise(1.0);*/
}

/*event Touch( Actor Other )
{
	if (Other != none && Other.IsA('Pickup'))
	{
		HandlePickup(Pickup(Other));
	}

}*/

simulated function SetTeamAttachments()
{
	if (PlayerReplicationInfo == none) { return; }

   //team indicators
	if (PlayerReplicationInfo.Team != none)
	{
	  if (teamInd == none ||
		  (TeamInd.Class == BlueTeamIndicator && PlayerReplicationInfo.Team.TeamIndex == 0) ||
		  (TeamInd.class == RedTeamIndicator && PlayerReplicationInfo.Team.TeamIndex == 1)
	  )
	  {
			//remove the old one
			if (teamInd != none){teamInd.Destroy();}

			//make a new one
			if (PlayerReplicationInfo.Team.TeamIndex == 0)
			{
				teamInd = Spawn( RedTeamIndicator );
			}
			else if (PlayerReplicationInfo.Team.TeamIndex == 1)
			{
				teamInd = Spawn( BlueTeamIndicator );
			}
			else
			{
				teamInd = Spawn( RedTeamIndicator );
			}
	  }

	  if (teamInd !=None)
	  {
		 AttachToBone(teamInd, TeamBoneName);
	  }
	  else
	  {
		 Log("Could Not find a team for " $ self);
	  }
	}
	/*else if ( Level.NetMode != NM_Standalone )
	{
		//remove the old one
		if (teamInd != none){teamInd.Destroy();}

		teamInd = Spawn( RedTeamIndicator );

		if (teamInd !=None)
		{
			AttachToBone(teamInd, TeamBoneName);
		}
		else
		{
			Log("Could Not find a team for " $ self);
		}
	}*/
}

/* PossessedBy()
 Pawn is possessed by Controller
*/
function PossessedBy(Controller C)
{
    Super.PossessedBy(C);

   SetTeamAttachments();

    /*Controller = C;
    NetPriority = 3;

    if ( C.PlayerReplicationInfo != None )
    {
        PlayerReplicationInfo = C.PlayerReplicationInfo;
        OwnerName = PlayerReplicationInfo.PlayerName;
    }
    if ( C.IsA('PlayerController') )
    {
        if ( Level.NetMode != NM_Standalone )
            RemoteRole = ROLE_AutonomousProxy;
        BecomeViewTarget();
    }
    else
        RemoteRole = Default.RemoteRole;

    SetOwner(Controller);   // for network replication
    Eyeheight = BaseEyeHeight;
    ChangeAnimation();*/
}

function UnPossessed()
{
    PlayerReplicationInfo = None;
    SetOwner(None);
    Controller = None;
}

simulated function String GetHumanReadableName()
{
	if ( PlayerReplicationInfo != None )
		return PlayerReplicationInfo.PlayerName;

	return "BOT Jack Slade";

	//return GetItemName(String(self));
}

/*****************************************************************
 *
 *****************************************************************
 */
simulated function PostNetReceive()
{
    Super.PostNetReceive();

    if (Health <= 0 && InfectiousEmitter != None)
    {
        InfectiousEmitter.Destroy();
        InfectiousEmitter = None;
    }
}

/*****************************************************************
 * BeginPlay
 * Provides multiple walk cycles for the the zombies
 *****************************************************************
 */
function BeginPlay()
{
    Super.BeginPlay();

    if (Walks.Length > 0)
        AnimWalkForward = Walks[Rand(Walks.Length)];

    if (Level.NetMode == NM_Standalone && AdvancedGameInfo(Level.Game) != None)
        SetToughness(AdvancedGameInfo(Level.Game).iEnemyDiffLevel);
    else
        SetToughness(0);

    if (DOTZGameInfoBase(Level.Game) != None &&
        DOTZGameInfoBase(Level.Game).bNameCheat &&
        Names.Length > 0)
    {
        HudCaption = Names[Rand(Names.Length)];
    }

    if (bInfectious && InfectiousEmitter == None && InfectiousEmitterClass != None)
    {
        InfectiousEmitter = Spawn(InfectiousEmitterClass);

        if (InfectiousEmitter != None)
        {
            InfectiousEmitter.bHardAttach = true;
            InfectiousEmitter.SetBase(self);
        }
    }
}

/*****************************************************************
 * PostNetBeginPlay
 *****************************************************************
 */
//function PostNetBeginPlay(){
//   super.PostNetBeginPlay();

//}

/*****************************************************************
 *
 *****************************************************************
 */
function SetToughness(int toughness){
   switch(toughness){
   case 0:
      DiffDamageMultiplier = 2;
      break;
   case 1:
      DiffDamageMultiplier = 1;
       break;
   case 2:
      DiffDamageMultiplier = 0.3;
      break;
   }

}


/*****************************************************************
 * UpdateDifficultyLevel
 * zombies don't change toughness with difficulty level
 *****************************************************************
 */
function UpdateDifficultyLevel(int NewDifficulty){
   DifficultyLevel = NewDifficulty;
   switch NewDifficulty{
      case 0:
      DiffDamageMultiplier = 2;
      break;
      case 1:
      DiffDamageMultiplier = 1;
      break;
      case 3:
      DiffDamageMultiplier= 0.8;
      break;
   }
}

simulated function PostNetBeginPlay()
{
    Super.PostNetBeginPlay();

    if (bInfectious && InfectiousEmitter == None && InfectiousEmitterClass != None)
    {
        InfectiousEmitter = Spawn(InfectiousEmitterClass);

        if (InfectiousEmitter != None)
        {
            InfectiousEmitter.bHardAttach = true;
            InfectiousEmitter.SetBase(self);
        }
    }

    SetAppearance();
}

/*****************************************************************
 * SetAppearance
 * Crazy cool tech to randomize characters head/bodies. Might want
 * to add some attachment arrays here to do things like add hats/glasses
 * to some characters and not other,
 *****************************************************************
 */
function SetAppearance(){
   SetCustomAppearance(int(HeadTextures.length * Frand()),
                    int(BodyTextures.length * Frand()));
}

/*****************************************************************
 * Touch
 * An attempt to pass more info to the controller, to make it more
 * responsive to its environment
 *****************************************************************
 */
function Touch(Actor A)
{
    local DOTZAIController AIController;

    Super.Touch(A);

    AIController = DOTZAIController(Controller);
    if (AIController != None)
        AIController.Touch(A);
}

// return true if was controlled by a Player (AI or human)
simulated function bool WasPlayerPawn()
{
    return false;
}

// return true if controlled by a real live human
simulated function bool IsHumanControlled()
{
    return ( UmodBotController(Controller) != None );
    //return ( UmodBotControllerSurvivor(Controller) != None );
}

/*****************************************************************
 * Melee_Attack
 * Called by the controller to make the pawn do a melee attack
 *****************************************************************
 */
function Melee_Attack()
{
    local int Index;

    if (IsAnimating(FOCUSCHANNEL))
        return;

    SetBoredomTimer(false);

    if (!bIsCrawling)
    {
        if (MeleeAttacks.Length <= 0)
            return;

        Index = Rand(MeleeAttacks.Length);

        if (ConfirmBonesUnDamaged(MeleeAttacks[Index].ReqBones))
        {
            AnimBlendParams(FIRINGCHANNEL, 1,,, FIRINGBLENDBONE);
            AdvancedPlayAnim(MeleeAttacks[Index].MeleeAttackAnim, 1, 0.2, FIRINGCHANNEL);
        }
        else
        {
            MeleeAttacks.Remove(Index, 1);
        }
    }
    else if (Velocity.X == 0 && Velocity.Y == 0)
    {
        if (CrawlingMeleeAttacks.Length <= 0)
            return;

        Index = Rand(CrawlingMeleeAttacks.Length);

        if (ConfirmBonesUnDamaged(CrawlingMeleeAttacks[Index].ReqBones))
        {
            AnimBlendParams(FIRINGCHANNEL, 1,,,);
            AdvancedPlayAnim(CrawlingMeleeAttacks[Index].MeleeAttackAnim, 1, 0.2, FIRINGCHANNEL);
        }
        else
        {
            CrawlingMeleeAttacks.Remove(Index, 1);
        }
    }
}

/*****************************************************************
 * DoSpecialDamage
 * Overridden to check for leg damage to convert these guys into crawlers.
 *****************************************************************
 */
function int DoSpecialDamage( vector Hitlocation, vector HitDirection,
                                int Damage ) {
    local float newDamage;

    newDamage = Super.DoSpecialDamage(Hitlocation, HitDirection, Damage);

    if (!ConfirmBonesUndamaged(LegBones) || bIsCrawling == true){
        //SwitchToCrawling();

        //legs must have just been broken
        if (bIsCrawling == false){
            bIsCrawling = true;

            if (Controller != None)
                Controller.bRun = 0; // in case they are running
            Velocity = Velocity + (250 * (vector(Rotation) + vect(0,0,0.5)));

            if (AnimCrawlingTransition != '' && HasAnim(AnimCrawlingTransition)){
//                AnimBlendParams(FIRINGCHANNEL,0.8,,,FIRINGBLENDBONE);
                AnimBlendParams(FIRINGCHANNEL,0.8);
                //AdvancedPlayAnim(AnimCrawlingTransition,1,0.1);
                AdvancedPlayAnim(AnimCrawlingTransition, 1,0.1,FIRINGCHANNEL);
                bCrawlTransition = true;
            }
        }
        //both arms missing means fall on your face
        if ( (!ConfirmBonesUndamaged(RightArmBones)
                || !ConfirmBonesUndamaged(LeftArmBones))
                && bPlayedFallOnFace == false ) {
            bPlayedFallOnFace = true;
            AmbientSound      = SquiggleSound;
            //PlayFocusedAnimation('CrawlAttackSqwirm');
            bTakesDamageInFocused=true;
            AdvancedPlayAnim('CrawlAttackSqwirm',,,,,true);
            SetPhysics(PHYS_Falling);
            SetMultiTimer(SQUIRMTIMER, 30, false);
        }

    }
    return NewDamage;
}



/*****************************************************************
 * Died
 * turn off you timers
 *****************************************************************
 */
function Died(Controller killer, class<DamageType> type, vector hitlocation){
    super.Died(killer, type, hitlocation);
    SetMultiTimer(SQUIRMTIMER,0,false);
}

/*****************************************************************
 * Destroyed
 *****************************************************************
 */
simulated function Destroyed()
{
    if (InfectiousEmitter != None)
    {
        InfectiousEmitter.Destroy();
        InfectiousEmitter = None;
    }

    Super.Destroyed();
}

function MultiTimer(int ID){

    if (ID ==SQUIRMTIMER){
        TakeDamage(200,self,vect(0,0,0),vect(0,0,0),none);
    }
    super.MultiTimer(ID);
}

/**
 */
function FocusedAnimEnd(){
   Super.FocusedAnimEnd();

   if (bPlayedFallOnFace == true){
      //PlayFocusedAnimation('CrawlAttackSqwirm');
      bTakesDamageInFocused=true;
      AdvancedPlayAnim('CrawlAttackSqwirm',,,,,true);
      AttemptMeleeDamage();
   }
}


/*****************************************************************
 * PlayTakeHit
 *****************************************************************
 */
function PlayTakeHit(vector HitLoc, int Damage, class<DamageType> damageType)
{
    local name HitAnim;
    local E_HitPart hitPart;

    SetBoredomTimer(false);
    hitPart = calcHitPart(HitLoc);

    Spawn(BloodEmitter,,,HitLoc);
    PlayHitSound();
    ViewKick(ViewKickMagnitude);

    switch (hitPart)
    {
        case HIT_Back:
            if (HitBack.Length > 0)
                HitAnim = HitBack[Rand(HitBack.Length)];
            break;
        case HIT_Head:
            if (HitHead.Length > 0)
                HitAnim = HitHead[Rand(HitHead.Length)];
            break;
        case HIT_Chest:
            if (HitFront.Length > 0)
                HitAnim = HitFront[Rand(HitFront.Length)];
            break;
        case HIT_Left:
            if (HitLeft.Length > 0)
                HitAnim = HitLeft[Rand(HitLeft.Length)];
            break;
        case HIT_Right:
        default:
            if (HitRight.Length > 0)
                HitAnim = HitRight[Rand(HitRight.Length)];
            break;
    }

    if (HitAnim != '' && !bCrawlTransition)
    {
        AnimBlendParams(TAKEHITCHANNEL, 1,,, FIRINGBLENDBONE);
        AdvancedPlayAnim(HitAnim, 1, hitblend, TAKEHITCHANNEL);
    }

    bCrawlTransition = false;
}

/*****************************************************************
 * Notify_MeleeDamage
 *****************************************************************
 */
function Notify_MeleeDamage(){
               // Log( self @ "MeleeDamage" )    ;
    //don't do anything while playing focus
   if (IsAnimating(FOCUSCHANNEL) == true){
                  // Log( self @ "Melee damage failed" )    ;
      return;
   }
   AttemptMeleeDamage();
}

/*****************************************************************
 * AttemptMeleeDamage
 *****************************************************************
 */
function AttemptMeleeDamage()
{
    local Actor Temp;
    local Pawn HitPawn;
    local Controller HitController;
    local vector DamageLocation;
    local bool bHitTest;
    local bool bHitPlayer;

    DamageLocation = Location + (Normal(vector(Rotation)) * iMeleeAttackRange);

    foreach CollidingActors(class'Actor', Temp, iMeleeDamageRadius, DamageLocation)
    {
        if (Temp == None || Temp == self)
            continue;

        //if (!bot.LineOfSightTo(Temp) /*!FastTrace(Location, Temp.Location)*/)
        //    continue;

        if (!FastTrace(Location, Temp.Location))
            continue;

        HitPawn = Pawn(Temp);

        if (HitPawn != None)
        {
            // Never damage friendly controlled pawns when both controllers expose team information.
            HitController = HitPawn.Controller;
            if (Controller != None && HitController != None && Controller.SameTeamAs(HitController))
                continue;

            bHitPlayer = true;
        }

        bHitTest = true;
        Temp.TakeDamage(
            iMeleeDamageAmount,
            self,
            vect(0,0,0),
            vect(0,0,0),
            ZombieDamage
        );
    }

    if (bHitTest)
    {
        if (bHitPlayer && PlayerHitSound.Length > 0)
            PlaySound(PlayerHitSound[Rand(PlayerHitSound.Length)]);
        else if (!bHitPlayer && NonPlayerHitSound.Length > 0)
            PlaySound(NonPlayerHitSound[Rand(NonPlayerHitSound.Length)]);
    }
}

/*****************************************************************
 * PlayEnemySpottedSound
 *****************************************************************
 */
function PlayEnemySpottedSound()
{
    if (EnemySpottedSound.Length > 0)
        PlaySound(EnemySpottedSound[Rand(EnemySpottedSound.Length)]);
}

/*****************************************************************
 * PlayHelpMeSound
 *****************************************************************
 */
function PlayHelpMeSound()
{
    if (HelpMeSound.Length > 0)
        PlaySound(HelpMeSound[Rand(HelpMeSound.Length)]);
}

/*
function bool LineOfSightTo(actor Other)
{
    return ( (Controller != None) && Controller.LineOfSightTo(Other) );
}

//Player Jumped
function bool DoJump( bool bUpdating )
{
    if ( !bIsCrouched && !bWantsToCrouch && ((Physics == PHYS_Walking) || (Physics == PHYS_Ladder) || (Physics == PHYS_Spider)) )
    {
        if ( Role == ROLE_Authority )
        {
            if ( (Level.Game != None) && (Level.Game.GameDifficulty > 2) )
                MakeNoise(0.1 * Level.Game.GameDifficulty);
            if ( bCountJumps && (Inventory != None) )
                Inventory.OwnerEvent('Jumped');
        }
        if ( Physics == PHYS_Spider )
            Velocity = JumpZ * Floor;
        else if ( Physics == PHYS_Ladder )
            Velocity.Z = 0;
        else if ( bIsWalking )
            Velocity.Z = Default.JumpZ;
        else
            Velocity.Z = JumpZ;
        if ( (Base != None) && !Base.bWorldGeometry )
            Velocity.Z += Base.Velocity.Z;
        SetPhysics(PHYS_Falling);
        return true;
    }
    return false;
}


event Tick( float DeltaTime )
{
	Super.Tick( DeltaTime );
	
	SpawnArrowsForVisiblePawns();
}

simulated function SpawnArrowsForVisiblePawns()
{
    local Pawn P;
    local vector Forward;
    local vector SpawnLocation;
    local vector ToPawn;
    local float DotProduct;
    local rotator ArrowRotation;

    Forward = Vector(Rotation);
    SpawnLocation = Location + Forward * 10.0;

    foreach RadiusActors(class'Pawn', P, 500.0)
    {
        if (P == Self)
            continue;

        ToPawn = P.Location - Location;
        DotProduct = Normal(ToPawn) Dot Forward;

        // 60-degree total field of vision.
        if (DotProduct < 0.8660)
            continue;

        //if (!bot.LineOfSightTo(Temp) /*!FastTrace(Location, Temp.Location)*/)
         //   continue;

        // Don't show through walls.
        if (!FastTrace(P.Location, Location))
            continue;

        ArrowRotation = Rotator(P.Location - SpawnLocation);

        Spawn(Class'DOTZEngine.DOTZRedIndicator', Self, ,SpawnLocation, ArrowRotation);
    }
}
*/

//event Touch( Actor Other );
//event Bump( Actor Other );
//===========================================================================
// Default Properties
//===========================================================================

defaultproperties
{
     IsMale=True
     InfectiousEmitterClass=Class'BBParticles.BBPPawnFlies'
     iMeleeDamageRadius=90
     iMeleeAttackRange=85
     iMeleeDamageAmount=20
     MeleeAttacks(0)=(MeleeAttackAnim="AttackRightA",bFunctional=True,ReqBones=("RUpperArm","RForearm"))
     MeleeAttacks(1)=(MeleeAttackAnim="AttackRightB",bFunctional=True,ReqBones=("RUpperArm","RForearm"))
     MeleeAttacks(2)=(MeleeAttackAnim="AttackRightC",bFunctional=True,ReqBones=("RUpperArm","RForearm"))
     MeleeAttacks(3)=(MeleeAttackAnim="AttackLeftA",bFunctional=True,ReqBones=("LUpperArm","LForearm"))
     MeleeAttacks(4)=(MeleeAttackAnim="AttackLeftB",bFunctional=True,ReqBones=("LUpperArm","LForearm"))
     MeleeAttacks(5)=(MeleeAttackAnim="AttackLeftC",bFunctional=True,ReqBones=("LUpperArm","LForearm"))
     MeleeAttacks(6)=(MeleeAttackAnim="AttackTwoHand",bFunctional=True,ReqBones=("RUpperArm","RForearm","LUpperArm","LForearm"))
     MeleeAttacks(7)=(MeleeAttackAnim="AttackBite",bFunctional=True)
     CrawlingMeleeAttacks(0)=(MeleeAttackAnim="CrawlAttackBite",bFunctional=True)
     CrawlingMeleeAttacks(1)=(MeleeAttackAnim="CrawlAttackFall",bFunctional=True,ReqBones=("RUpperArm","RForearm"))
     CrawlingMeleeAttacks(2)=(MeleeAttackAnim="CrawlAttackRight",bFunctional=True,ReqBones=("RUpperArm","RForearm"))
     ZombieDamage=Class'DOTZEngine.DOTZBluntImpactDamage'
     Walks(0)="WalkF"
     LegBones(0)="LCalf"
     LegBones(1)="RCalf"
     LeftArmBones(0)="LUpperArm"
     LeftArmBones(1)="LForearm"
     RightArmBones(0)="RUpperArm"
     RightArmBones(1)="RForearm"
     AnimCrawlingTransition="CrawlTrans"
     PlayerHitSound(0)=Sound'DOTZXCharacters.PlayerImpactSounds.MeleeImpact1'
     PlayerHitSound(1)=Sound'DOTZXCharacters.PlayerImpactSounds.MeleeImpact2'
     PlayerHitSound(2)=Sound'DOTZXCharacters.PlayerImpactSounds.MeleeImpact3'
     PlayerHitSound(3)=Sound'DOTZXCharacters.PlayerImpactSounds.MeleeImpact4'
     PlayerHitSound(4)=Sound'DOTZXCharacters.PlayerImpactSounds.MeleeImpact5'
     PlayerHitSound(5)=Sound'DOTZXCharacters.PlayerImpactSounds.MeleeImpact6'
     NonPlayerHitSound(0)=Sound'DOTZXDestruction.DoorImpactSounds.DoorImpact1'
     NonPlayerHitSound(1)=Sound'DOTZXDestruction.DoorImpactSounds.DoorImpact2'
     NonPlayerHitSound(2)=Sound'DOTZXDestruction.DoorImpactSounds.DoorImpact3'
     NonPlayerHitSound(3)=Sound'DOTZXDestruction.DoorImpactSounds.DoorImpact4'
     LyingAnims(0)="LyingPose"
     bUseNotifyFootStep=True
	AdditionalAnimPkg(0)=(AnimName="DOTZAHumans.HumanStandard")
	AdditionalAnimPkg(1)=(AnimName="DOTZAZombies.ZombieStandard")
	AdditionalAnimPkg(2)=(AnimName="DOTZAHumans.OtisScripted")
	AdditionalAnimPkg(3)=(AnimName="DOTZAHumans.OtisFaceAnim")
     //BoredStandingAnimList(0)="Bored"
     AnimStandHitRight(0)="HitRightSide"
     AnimStandHitLeft(0)="HitLeftSide"
     AnimStandHitBack(0)="HitBack"
     AnimStandHitHead(0)="HitHead"
     AnimStandHitFront(0)="HitFront"
     AnimCrouchHitRight(0)="CrouchHitRightSide"
     AnimCrouchHitLeft(0)="CrouchHitLeftSide"
     AnimCrouchHitBack(0)="CrouchHitBack"
     AnimCrouchHitHead(0)="CrouchHitHead"
     AnimCrouchHitFront(0)="CrouchHitFront"
     BoredCrawlAnimList(0)="CrawlBored"
     AnimCrawlHitRight(0)="CrawlHitRightSide"
     AnimCrawlHitLeft(0)="CrawlHitLeftSide"
     AnimCrawlHitBack(0)="CrawlHitBack"
     AnimCrawlHitHead(0)="CrawlHitHead"
     AnimCrawlHitFront(0)="CrawlHitFront"
     SplutEmitter=Class'BBParticles.BBPGibZombie'
     BoredomThreshold=1
     BoredomDeviation=1

     FootStepSound(0)=Sound'PlayerSounds.FootSteps.FootstepDefault1'
     FootStepSound(1)=Sound'PlayerSounds.FootSteps.FootstepDefault2'
     FootStepSound(2)=Sound'PlayerSounds.FootSteps.FootstepDefault3'
     FootStepDirt(0)=Sound'PlayerSounds.FootSteps.BFootstepDirt1'
     FootStepDirt(1)=Sound'PlayerSounds.FootSteps.BFootstepDirt2'
     FootStepDirt(2)=Sound'PlayerSounds.FootSteps.BFootstepDirt3'
     FootStepMetal(0)=Sound'PlayerSounds.FootSteps.BFootstepMetal1'
     FootStepMetal(1)=Sound'PlayerSounds.FootSteps.BFootstepMetal2'
     FootStepMetal(2)=Sound'PlayerSounds.FootSteps.BFootstepMetal3'
     FootStepPlant(0)=Sound'PlayerSounds.FootSteps.BFootstepPlant1'
     FootStepPlant(1)=Sound'PlayerSounds.FootSteps.BFootstepPlant2'
     FootStepPlant(2)=Sound'PlayerSounds.FootSteps.BFootstepPlant3'
     FootStepRock(0)=Sound'PlayerSounds.FootSteps.BFootstepRock1'
     FootStepRock(1)=Sound'PlayerSounds.FootSteps.BFootstepRock2'
     FootStepRock(2)=Sound'PlayerSounds.FootSteps.BFootstepRock3'
     FootStepWater(0)=Sound'PlayerSounds.FootSteps.FootStepWater'
     FootStepWater(1)=Sound'PlayerSounds.FootSteps.FootstepWater1'
     FootStepWater(2)=Sound'PlayerSounds.FootSteps.FootstepWater2'
     FootStepWood(0)=Sound'PlayerSounds.FootSteps.BFootstepWood1'
     FootStepWood(1)=Sound'PlayerSounds.FootSteps.BFootstepWood2'
     FootStepWood(2)=Sound'PlayerSounds.FootSteps.BFootstepWood3'
     FootStepSnow(0)=Sound'PlayerSounds.FootSteps.FootstepRustlingBrush1'
     FootStepSnow(1)=Sound'PlayerSounds.FootSteps.FootstepRustlingBrush2'
     FootStepSnow(2)=Sound'PlayerSounds.FootSteps.FootstepRustlingBrush3'
	 
     SpecialDamage(0)=(BoneName="LUpperArm",ReqMinHitDistance=15,DamageEmitter=Class'BBParticles.BBPGibBicep',SubDamageBones=("LForearm"),DamageMod=0.500000)
     SpecialDamage(1)=(BoneName="RUpperArm",ReqMinHitDistance=15,DamageEmitter=Class'BBParticles.BBPGibBicep',SubDamageBones=("RForearm"),DamageMod=0.500000)
     SpecialDamage(2)=(BoneName="LForearm",ReqMinHitDistance=20,DamageEmitter=Class'BBParticles.BBPGibForearm',DamageMod=0.300000)
     SpecialDamage(3)=(BoneName="RForearm",ReqMinHitDistance=20,DamageEmitter=Class'BBParticles.BBPGibForearm',DamageMod=0.300000)
     SpecialDamage(4)=(BoneName="Jaw",ReqMinHitDistance=6,DamageEmitter=Class'BBParticles.BBPGibJaw',DamageMod=0.400000)
     SpecialDamage(5)=(BoneName="Head",ReqMinHitDistance=20,offset=(Z=10.000000),AdvancedEmitter=Class'DOTZEngine.SkelHead',bFatal=True)
     SpecialDamage(6)=(BoneName="LCalf",ReqMinHitDistance=23,DamageEmitter=Class'BBParticles.BBPGibLeg',DamageMod=0.500000)
     SpecialDamage(7)=(BoneName="RCalf",ReqMinHitDistance=23,DamageEmitter=Class'BBParticles.BBPGibLeg',DamageMod=0.500000)
     bUseSpecialDamage=False
     //OnKilledEvent="ZombieKilled"
     MinimumDamageThreshold=2
     bCanCrouch=True
     bCanStrafe=True
     JumpZ=100.000000
     AirControl=0.050000
     WalkingPct=0.500000
     CrouchedPct=0.500000
     Health=100
     ControllerClass=Class'UMODDOTZGame.UmodBotControllerSurvivor'
     BaseMovementRate=300.000000
     MovementAnims(1)="WalkL"
     MovementAnims(2)="WalkR"
     BlendChangeTime=0.020000

     // infectionDamage=7
     // infectionFreq=2
     // InfectedEvent="PLAYER_INFECTED"
     // iMultiPlayerCorpseSecs=20
     //bNoDamageEffects=True
     FallSound=Sound'DOTZXCharacters.PlayerPainSounds.PlayerPainGrunt4'

     bDoFootsteps=True
     HitSounds(0)=Sound'DOTZXCharacters.PlayerPainSounds.PlayerPainGrunt1'
     HitSounds(1)=Sound'DOTZXCharacters.PlayerPainSounds.PlayerPainGrunt2'
     HitSounds(2)=Sound'DOTZXCharacters.PlayerPainSounds.PlayerPainGrunt3'
     HitSounds(3)=Sound'DOTZXCharacters.PlayerPainSounds.PlayerPainGrunt4'
     DeathSounds(0)=Sound'DOTZXCharacters.PlayerPainSounds.PlayerPainDeath1'
     DeathSounds(1)=Sound'DOTZXCharacters.PlayerPainSounds.PlayerPainDeath2'
     DeathSounds(2)=Sound'DOTZXCharacters.PlayerPainSounds.PlayerPainDeath3'
     DeathSounds(3)=Sound'DOTZXCharacters.PlayerPainSounds.PlayerPainDeath4'
     DeathSounds(4)=Sound'DOTZXCharacters.PlayerPainSounds.PlayerPainDeath5'
     bInfiniteAmmo=True
     bAlwaysPlayDying=True
     bDamageKicksView=false
     bJumpCapable=false
     bCanPickupInventory=false
     GroundSpeed=465.000000

     CollisionRadius=30.000000

     EnemySpottedSound(0)=Sound'DOTZXCharacters.OtisSounds.C08Otis5'
     EnemySpottedSound(1)=Sound'DOTZXCharacters.OtisSounds.C08Otis4'
     EnemySpottedSound(2)=Sound'DOTZXCharacters.OtisSounds.C08Otis2'
     EnemySpottedSound(3)=Sound'DOTZXCharacters.OtisSounds.C11Otis12'
     EnemySpottedSound(4)=Sound'DOTZXCharacters.OtisSounds.C11Otis2'

     HelpMeSound(0)=Sound'DOTZXCharacters.OtisSounds.C11Otis10'
     HelpMeSound(1)=Sound'DOTZXCharacters.OtisSounds.C11Otis11'
     HelpMeSound(2)=Sound'DOTZXCharacters.OtisSounds.C11Otis10'
     HelpMeSound(3)=Sound'DOTZXCharacters.OtisSounds.C11Otis10'

     FallingSound(0)=Sound'DOTZXCharacters.PlayerPainSounds.C08Otis3'
     FallingSound(1)=Sound'DOTZXCharacters.PlayerPainSounds.C08Otis3'
     FallingSound(2)=Sound'DOTZXCharacters.PlayerPainSounds.C08Otis3'
     FallingSound(3)=Sound'DOTZXCharacters.PlayerPainSounds.C08Otis3'

    // DyingSound(2)=Sound'DOTZXCharacters.OtisSounds.C11Otis13'
    // ReadySound(2)=Sound'DOTZXCharacters.OtisSounds.C11Otis1'
    // ReadySound(2)=Sound'DOTZXCharacters.OtisSounds.C08Otis2'
    // OverHereSound(2)=Sound'DOTZXCharacters.OtisSounds.C08Otis1'
	 
    // DoorLockedSound(2)=Sound'DOTZXCharacters.OtisSounds.C11Otis6'
    // GoodItemSound(2)=Sound'DOTZXCharacters.OtisSounds.C11Otis7'
	
    // WhistleSound(0)=Sound'DOTZXCharacters.OtisSounds.OtisWhistle1'
    // WhistleSound(1)=Sound'DOTZXCharacters.OtisSounds.OtisWhistle2'

	OwnerName="BOT Jack Slade"
	MenuName="BOT Jack Slade"

	HeadTextures(0)=Shader'DOTZTHumans.JackSlade.JackSladeHeadShaderA'
	BodyTextures(0)=Shader'DOTZTHumans.JackSlade.JackSladeBodyShaderA'
	
	DefaultPawnMesh=SkeletalMesh'DOTZAHumans.JackSlade'
	DefaultHeadTexture=Shader'DOTZTHumans.JackSlade.JackSladeHeadShaderA'
	DefaultBodyTexture=Shader'DOTZTHumans.JackSlade.JackSladeBodyShaderA'
	
	Mesh=SkeletalMesh'DOTZAHumans.JackSlade'
	Skins(0)=Shader'DOTZTHumans.JackSlade.JackSladeBodyShaderC'
	Skins(1)=Shader'DOTZTHumans.JackSlade.JackSladeHeadShaderA'

    RedTeamIndicator=Class'DOTZEngine.DOTZRedIndicator'
    BlueTeamIndicator=Class'DOTZEngine.DOTZBlueIndicator'
    TeamBoneName="ArrowSocket"
	BotReplicationInfoClass=Class'UMODDOTZGame.UmodBotReplicationInfo'
}
