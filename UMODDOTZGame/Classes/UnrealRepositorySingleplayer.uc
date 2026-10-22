///////////////////////////////////////////////////////////////////////////////
//UnrealRepositorySingleplayer
///////////////////////////////////////////////////////////////////////////////
class UnrealRepositorySingleplayer extends Object
  Config(UnrealRepository);

// Default weapons
const DefaultPrimaryWeaponType = "DOTZWeapons.M16Weapon";
const DefaultBackupWeaponType = "DOTZWeapons.RevolverWeapon";
const DefaultMeleeWeaponType = "DOTZWeapons.FireAxeWeapon";

//Bot skill 0-7
var(UnrealRepository) config float BotSkill;

// tag to set on the controller
var(UnrealRepository) config Name BotControllerTag;

// the Role class to spawn
var(UnrealRepository) config class<AIRole> AIRoleClass;

var(UnrealRepository) config class<AIController> ZombieControllerClass;

// the controller class to spawn for the pawns
var(UnrealRepository) config class<AIController> BotControllerClass;

// the controller class to spawn for the pawns
var(UnrealRepository) config class<Pawn> BotPawnClass;

var(UnrealRepository) config string BotControllerClassName;

var(UnrealRepository) config string PlayerControllerClassName;

var(UnrealRepository) config string PlayerPawnClassName;

var(UnrealRepository) config array<string> BotPawnClassNameList;

var(UnrealRepository) config array<string> AllWeaponClassList;

var(UnrealRepository) config array<string> AllWeaponPickupClassList;

var(UnrealRepository) config array<string> PrimaryWeaponNameList;
var(UnrealRepository) config array<string> BackupWeaponNameList;

var(UnrealRepository) config array<string> PrimaryWeaponPickupClassList;

var(UnrealRepository) config array<string> BackupWeaponPickupClassList;

var(UnrealRepository) config array<string> Tier1PickupClassList;
var(UnrealRepository) config array<string> Tier2PickupClassList;
var(UnrealRepository) config array<string> Tier3PickupClassList;
var(UnrealRepository) config array<string> Tier4PickupClassList;
var(UnrealRepository) config array<string> Tier5PickupClassList;

var(UnrealRepository) config array<string> SpecialWeaponNameList;
//-----------------------------------------------------------------------------

static function string GetBotControllerClassName(){return default.BotControllerClassName;}

//-----------------------------------------------------------------------------

defaultproperties
{
	BotSkill=7

	//"UmodPlayerController" "UmodPlayerPawn" 

	PlayerControllerClassName="DOTZEngine.DOTZPlayerController"

	PlayerPawnClassName="XDOTZCharacters.PlayerPawnBase"

	ZombieControllerClass=Class'UMODDOTZGame.UmodZombieAIController'

	BotPawnClass=Class'UMODDOTZGame.UmodHumanPawn'
	BotControllerClass=Class'UMODDOTZGame.UmodBotController'
	AIRoleClass=Class'UMODDOTZGame.UmodBotAIRole'

	BotControllerClassName="UMODDOTZGame.UmodBotController"
	//BotPawnClassName="UMODDOTZGame.UmodHumanPawn"

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

	AllWeaponClassList(0)="DOTZWeapons.RevolverWeapon"
	// AllWeaponClassList(1)="DOTZWeapons.GlockWeapon"
	// AllWeaponClassList(2)="DOTZWeapons.ShotgunWeapon"
	// AllWeaponClassList(3)="DOTZWeapons.M16Weapon"
	// AllWeaponClassList(4)="DOTZWeapons.SniperWeapon"
	// AllWeaponClassList(5)="DOTZWeapons.RifleWeapon"

	//AllWeaponPickupClassList(0)="UMODDOTZGame.KungFuWeaponPickup"
	// AllWeaponPickupClassList(1)="DOTZWeapons.M16AmmoPickup"
	// AllWeaponPickupClassList(2)="DOTZWeapons.SniperPickup"
	// AllWeaponPickupClassList(3)="DOTZWeapons.SniperAmmoPickup"
	// AllWeaponPickupClassList(4)="DOTZWeapons.M16Pickup"

	//PrimaryWeaponNameList(0)="DOTZWeapons.ShotgunWeapon"
	//PrimaryWeaponNameList(1)="DOTZWeapons.SniperWeapon"
	//PrimaryWeaponNameList(2)="DOTZWeapons.M16Weapon"
	//PrimaryWeaponNameList(3)="DOTZWeapons.RifleWeapon"

	BackupWeaponNameList(0)="DOTZWeapons.RevolverWeapon"
	//BackupWeaponNameList(0)="DOTZWeapons.GlockWeapon"
	//BackupWeaponNameList(1)="DOTZWeapons.RifleWeapon"

	SpecialWeaponNameList(0)="DOTZWeapons.KungFuWeapon"

}
