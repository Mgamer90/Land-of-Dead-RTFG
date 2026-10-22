///////////////////////////////////////////////////////////////////////////////
//UnrealRepository
///////////////////////////////////////////////////////////////////////////////
class UnrealRepository extends Object
  Config(UnrealRepository);

// Default weapons
const DefaultPrimaryWeaponType = "DOTZWeapons.M16Weapon";
const DefaultBackupWeaponType = "DOTZWeapons.RevolverWeapon";
const DefaultMeleeWeaponType = "DOTZWeapons.FireAxeWeapon";

//-----------------------------------------------------------------------------
// Structures.

struct Reward
{
    var int Points;
    var string InventoryName;
    var string ExtraName;
    var bool PlayersOnly;
};

var(UnrealRepository) config array< Reward > RewardList;

// tag to set on the controller
var(UnrealRepository) config Name BotControllerTag;

//Bot skill 0-7
var(UnrealRepository) config float BotSkill;

var(UnrealRepository) config class<AIController> ZombieControllerClass;

// the Role class to spawn
var(UnrealRepository) config class<AIRole> AIRoleClass;

// the pawn class to spawn
var(UnrealRepository) config string BotPawnClassName;

// the controller class to spawn for the pawns
var(UnrealRepository) config class<AIController> BotControllerClass;
var(UnrealRepository) config class<AIController> DeathMatchBotControllerClass;
var(UnrealRepository) config class<AIController> TeamDeathMatchBotControllerClass;
var(UnrealRepository) config class<AIController> InvasionBotControllerClass;
var(UnrealRepository) config class<AIController> CaptureTheFlagBotControllerClass;

var(UnrealRepository) config string BotControllerClassName;
var(UnrealRepository) config string DeathMatchBotControllerClassName;
var(UnrealRepository) config string InvasionBotControllerClassName;
var(UnrealRepository) config string CaptureTheFlagBotControllerClassName;

var(UnrealRepository) config string PlayerControllerClassName;
var(UnrealRepository) config string DeathMatchPlayerControllerClassName;
var(UnrealRepository) config string InvasionPlayerControllerClassName;
var(UnrealRepository) config string CaptureTheFlagPlayerControllerClassName;

var(UnrealRepository) config string PlayerPawnClassName;
var(UnrealRepository) config string DeathMatchPawnClassName;
var(UnrealRepository) config string InvasionPawnClassName;
var(UnrealRepository) config string CaptureTheFlagPawnClassName;

var(UnrealRepository) config class<Pawn> BotPawnClass;

var(UnrealRepository) config array< class<Pawn> > BotPawnClassList;

var(UnrealRepository) config array< class<PlayerReplicationInfo> > BotReplicationInfoClassList;

var(UnrealRepository) config array<string> BotPawnClassNameList;

var(UnrealRepository) config array<string> InvasionBotPawnClassNameList;

var(UnrealRepository) string DeathMatchStartingWeaponName;

var(UnrealRepository) string InvasionStartingWeaponName;

var(UnrealRepository) config array<string> AllWeaponClassList;

var(UnrealRepository) config array<string> AllWeaponPickupClassList;

var(UnrealRepository) config array<string> PrimaryWeaponNameList;
var(UnrealRepository) config array<string> BackupWeaponNameList;

var(UnrealRepository) config array<string> SpecialWeaponNameList;
//-----------------------------------------------------------------------------

static function string GetBotPawnClassName(){return default.BotPawnClassName;}

//-----------------------------------------------------------------------------

defaultproperties
{
	BotSkill=7

	//"UmodPlayerController" "UmodPlayerPawn" 

	PlayerControllerClassName="DOTZEngine.DOTZPlayerController"
	DeathMatchPlayerControllerClassName="XDOTZCharacters.DOTZPlayerController"
	InvasionPlayerControllerClassName="XDOTZCharacters.DOTZPlayerController"
	CaptureTheFlagPlayerControllerClassName="XDOTZCharacters.UmodPlayerController"

	PlayerPawnClassName="XDOTZCharacters.PlayerPawnBase"
	DeathMatchPawnClassName="UMODDOTZGame.UmodPlayerPawn"
	InvasionPawnClassName="UMODDOTZGame.UmodPlayerPawn"
	CaptureTheFlagPawnClassName="UMODDOTZGame.UmodPlayerPawn"

	ZombieControllerClass=Class'UMODDOTZGame.UmodZombieAIController'

	BotControllerClass=Class'UMODDOTZGame.UmodBotController'
	InvasionBotControllerClass=Class'UMODDOTZGame.UmodBotControllerInvasion'
	DeathMatchBotControllerClass=Class'UMODDOTZGame.UmodBotControllerDeathmatch'
	CaptureTheFlagBotControllerClass=Class'UMODDOTZGame.UmodBotControllerCaptureTheFlag'
	TeamDeathMatchBotControllerClass=Class'UMODDOTZGame.UmodBotControllerTeamDeathmatch'

	BotPawnClass=Class'UMODDOTZGame.UmodHumanPawn'
	AIRoleClass=Class'UMODDOTZGame.UmodBotAIRole'

	BotControllerClassName="UMODDOTZGame.UmodBotController"
	BotPawnClassName="UMODDOTZGame.UmodHumanPawn"

	DeathMatchBotControllerClassName="UMODDOTZGame.UmodBotControllerDeathmatch"
	InvasionBotControllerClassName="UMODDOTZGame.UmodBotControllerInvasion"
	CaptureTheFlagBotControllerClassName="UMODDOTZGame.UmodBotControllerCaptureTheFlag"

	BotPawnClassNameList(0)="UMODDOTZGame.UmodHumanOtis"
	BotPawnClassNameList(1)="UMODDOTZGame.UmodHumanMilitaryMale"
	BotPawnClassNameList(2)="UMODDOTZGame.UmodHumanHeavyMale"
	BotPawnClassNameList(3)="UMODDOTZGame.UmodHumanTeenagerMale"
	BotPawnClassNameList(4)="UMODDOTZGame.UmodHumanDoctorMale"
	BotPawnClassNameList(5)="UMODDOTZGame.UmodHumanJackMilitary"
	BotPawnClassNameList(6)="UMODDOTZGame.UmodHumanMaleSoldier"
	BotPawnClassNameList(7)="UMODDOTZGame.UmodHumanJack"
	BotPawnClassNameList(8)="UMODDOTZGame.UmodHumanFemaleYoungAdult"
	BotPawnClassNameList(9)="UMODDOTZGame.UmodHumanFemaleTeenager"
	BotPawnClassNameList(10)="UMODDOTZGame.UmodHumanMaleSwat"
	BotPawnClassNameList(11)="UMODDOTZGame.UmodHumanMaleCop"

	InvasionBotPawnClassNameList(0)="UMODDOTZGame.UmodHumanOtis"
	InvasionBotPawnClassNameList(1)="UMODDOTZGame.UmodHumanMilitaryMale"
	InvasionBotPawnClassNameList(2)="UMODDOTZGame.UmodHumanJackMilitary"
	InvasionBotPawnClassNameList(3)="UMODDOTZGame.UmodHumanTeenagerMale"
	InvasionBotPawnClassNameList(4)="UMODDOTZGame.UmodHumanHeavyMale"
	InvasionBotPawnClassNameList(5)="UMODDOTZGame.UmodHumanDoctorMale"
	InvasionBotPawnClassNameList(6)="UMODDOTZGame.UmodHumanMaleSoldier"
	InvasionBotPawnClassNameList(7)="UMODDOTZGame.UmodHumanJack"
	InvasionBotPawnClassNameList(8)="UMODDOTZGame.UmodHumanMaleSwat"
	InvasionBotPawnClassNameList(9)="UMODDOTZGame.UmodHumanMaleCop"
	InvasionBotPawnClassNameList(10)="UMODDOTZGame.UmodHumanFemaleYoungAdult"
	InvasionBotPawnClassNameList(11)="UMODDOTZGame.UmodHumanFemaleTeenager"

	BotReplicationInfoClassList(0)=Class'UMODDOTZGame.UmodBotReplicationInfoOtis'
	BotReplicationInfoClassList(1)=Class'UMODDOTZGame.UmodBotReplicationInfoMaleMilitary'
	BotReplicationInfoClassList(2)=Class'UMODDOTZGame.UmodBotReplicationInfoHeavyMale'
	BotReplicationInfoClassList(3)=Class'UMODDOTZGame.UmodBotReplicationInfoTeenagerMale'
	BotReplicationInfoClassList(4)=Class'UMODDOTZGame.UmodBotReplicationInfoDoctorMale'
	BotReplicationInfoClassList(5)=Class'UMODDOTZGame.UmodBotReplicationInfoJack'
	BotReplicationInfoClassList(6)=Class'UMODDOTZGame.UmodBotReplicationInfoRiley'
	BotReplicationInfoClassList(7)=Class'UMODDOTZGame.UmodBotReplicationInfoDoctorFrankenstein'
	BotReplicationInfoClassList(8)=Class'UMODDOTZGame.UmodBotReplicationInfoJohnGates'
	BotReplicationInfoClassList(9)=Class'UMODDOTZGame.UmodBotReplicationInfoSeniorMale'
	BotReplicationInfoClassList(10)=Class'UMODDOTZGame.UmodBotReplicationInfoCopMale'

	DeathMatchStartingWeaponName="DOTZWeapons.ShotgunWeapon"

	InvasionStartingWeaponName="DOTZWeapons.GlockWeapon"

	AllWeaponClassList(0)="DOTZWeapons.RevolverWeapon"
	AllWeaponClassList(1)="DOTZWeapons.GlockWeapon"
	AllWeaponClassList(2)="DOTZWeapons.ShotgunWeapon"
	AllWeaponClassList(3)="DOTZWeapons.M16Weapon"
	AllWeaponClassList(4)="DOTZWeapons.SniperWeapon"
	//AllWeaponClassList(5)="DOTZWeapons.RifleWeapon"

	AllWeaponPickupClassList(0)="UMODDOTZGame.KungFuWeaponPickup"
	// AllWeaponPickupClassList(1)="DOTZWeapons.M16AmmoPickup"
	// AllWeaponPickupClassList(2)="DOTZWeapons.SniperPickup"
	// AllWeaponPickupClassList(3)="DOTZWeapons.SniperAmmoPickup"
	// AllWeaponPickupClassList(4)="DOTZWeapons.M16Pickup"

	PrimaryWeaponNameList(0)="DOTZWeapons.ShotgunWeapon"
	PrimaryWeaponNameList(1)="DOTZWeapons.SniperWeapon"
	PrimaryWeaponNameList(2)="DOTZWeapons.M16Weapon"
	//PrimaryWeaponNameList(3)="DOTZWeapons.RifleWeapon"

	BackupWeaponNameList(0)="DOTZWeapons.GlockWeapon"
	//BackupWeaponNameList(1)="DOTZWeapons.RifleWeapon"

	SpecialWeaponNameList(0)="DOTZWeapons.KungFuWeapon"

}
