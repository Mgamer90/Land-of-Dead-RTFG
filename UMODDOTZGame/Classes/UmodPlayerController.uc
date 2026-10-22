class UmodPlayerController extends DOTZPlayerController;

// const RUNNING_COUNTER   = 222;
// const RUNMAX            = 8;
// const REFALL_TIMER      = 223;
// const BREATH_INCREASE   = 35;
// const BREATH_DECREASE   = 15;
// const MIN_SPECTATE_TIME = 3;

/*****************************************************************
 * SetProfileConfiguration
 * Update the active configuration to reflect the currently loaded profile.
 *****************************************************************
 */
private function SetProfileConfiguration(){

    Log("Setting profile config from profile");

    //SET CURRENT PROFILE
    if (GetCurrentProfileName() != "" && IsLoadedProfileValid()){

        //Set the difficulty level
        AdvancedGameInfo(Level.Game).iDifficultyLevel = int(class'Profiler'.static.GetValue(constDIFFLEVEL));
        SetDifficultyLevel(AdvancedGameInfo(Level.Game).iDifficultyLevel);

   //DEFAULTS
    } else {
        SetDifficultyLevel(1);
    }

    SetUseSubtitles(true);
}

/*****************************************************************
 * SetInvertLook
 *****************************************************************
 */

function SetInvertLook(bool bShouldInvert){
   InvertLook(bShouldInvert);
}

/*****************************************************************
 *
 *****************************************************************
 */

state dead{
   exec function Fire( optional float F ) {
        HandlePlayerInput();
    }

    exec function AltFire( optional float F ) {
        HandlePlayerInput();
    }
    /**
     * Do clever stuff here to restart the game for the player...
     */
    function HandlePlayerInput() {

        if ( Level.NetMode == NM_Standalone ) {
            if ( Level.TimeSeconds - StartedSpectatingTime > MIN_SPECTATE_TIME ) {
                    AdvancedGameInfo(Level.Game).GameOver();
            }
        } else {
            //Log("MP game restarting player");
            ServerRestartPlayer();
        }
    }
}

exec function DEWeapons(){

    if (Level.NetMode != NM_Standalone){return;}

    //Level.GetLocalPlayerController().Pawn.PlaySound(ActionSound);

    Pawn.GiveWeapon("DEWeapons.ColtWeapon");
    Pawn.GiveWeapon("DEWeapons.DragunovWeapon");
    Pawn.GiveWeapon("DEWeapons2.RaptorWeapon");
    Pawn.GiveWeapon("DEWeapons2.M16A4Weapon");
    Pawn.GiveWeapon("DEWeapons2.Mac10Weapon");
    Pawn.GiveWeapon("DEWeapons2.Spas12Weapon");
    Pawn.GiveWeapon("DEWeapons2.GrenadeLauncherWeapon");
}

exec function BDWeapons(){

    if (Level.NetMode != NM_Standalone){return;}

    Pawn.GiveWeapon("AK74V2.AK74V2Weapon");
    Pawn.GiveWeapon("SteyrAUGV2.SAUGV2Weapon");
    Pawn.GiveWeapon("BDTommyGun.TommyWeapon");
    Pawn.GiveWeapon("BDUzi.UziWeapon");
    Pawn.GiveWeapon("BDMP5S.MP5SWeapon");
    Pawn.GiveWeapon("BDAshSawnOff.AshShotgunWeapon");
    Pawn.GiveWeapon("BDChainsawV1.ChainsawPickup");
    Pawn.GiveWeapon("BDdawnrifle.RifleWeapon");
    Pawn.GiveWeapon("BDFlameThrower.FlameTWeapon");
    Pawn.GiveWeapon("BDCrossbow.CrossbowWeapon");
    Pawn.GiveWeapon("BDSniper.BDSniperWeapon");


}

exec function ModWeapons(){

    if (Level.NetMode != NM_Standalone){return;}

    Pawn.GiveWeapon("UMODDOTZWeapons.M1911Weapon");
    Pawn.GiveWeapon("UMODDOTZWeapons.MarkarovWeapon");
    Pawn.GiveWeapon("UMODDOTZWeapons.DeagleWeapon");
    Pawn.GiveWeapon("UMODDOTZWeapons.M4A1Weapon");
    Pawn.GiveWeapon("UMODDOTZWeapons.AK47Weapon");
    Pawn.GiveWeapon("UMODDOTZWeapons.AR15ScopeWeapon");
    Pawn.GiveWeapon("UMODDOTZWeapons.M4Weapon");
    Pawn.GiveWeapon("UMODDOTZWeapons.NovaPumpWeapon");

}

/*****************************************************************
 * DoRunCalcs
 *****************************************************************
 */
function DoRunCalcs(){

    local float AffectRatio;

    AffectRatio = 1- (float(runningCounter)/(RUNMAX + 3));
   // Log ("Ground Speed: " $ Pawn.GroundSpeed);
    //Log ("Walking pct: " $ Pawn.WalkingPct $ " Walking Speed: " $ Pawn.WalkingPct * Pawn.GroundSpeed);
    //Log ("AffectRatio: " $ AffectRatio);

    //you are running check if you should stop
    if (AllowedToRun()){
        RunningCounter++;
        if (Pawn.SoundVolume + BREATH_INCREASE >= 255) {
            Pawn.SoundVolume = 255;
        } else {
            Pawn.SoundVolume += BREATH_INCREASE;
        }

        //running affects ground speed
        Pawn.GroundSpeed = Pawn.Default.GroundSpeed * AffectRatio;

        //ah, you ran too much
        if (RunningCounter > RUNMAX){
            Pawn.GroundSpeed = Pawn.Default.GroundSpeed;
            bRun = 0;
            bReadyToDash = false;
            Pawn.PlaySound(AdvancedPawn(Pawn).HitSounds[0]);

        }

    //you are not running
    } else if (class'ExtinguishVolume' == Pawn.PhysicsVolume.class ||
               Pawn.PhysicsVolume.IsA('WaterVolume')){
        //Log ("You are in water");
        bReadyToDash = false;
        bRun = 0;
        Pawn.AmbientSound = none;
    } else {
      //  bReadyToDash = false; //think we should remove this
        RunningCounter --;
        if (Pawn.SoundVolume - BREATH_DECREASE <= 0) {
            Pawn.SoundVolume = 0;
        } else {
            Pawn.SoundVolume -=BREATH_DECREASE;
        }


        if (bRun == 1){
            //running affects ground speed
            Pawn.GroundSpeed = Pawn.Default.GroundSpeed * AffectRatio;
        } else {
           Pawn.GroundSpeed = Pawn.Default.GroundSpeed;
        }

        if (RunningCounter <= -3){ //hack to ensure that it always takes at least 2 to recover
            bReadyToDash = true;
            RunningCounter = 0;
            SetMultiTimer(RUNNING_COUNTER,0,false);
            Pawn.AmbientSound = none;
        }
    }

    //safe guard to ensure that running is never slower than walking
    if (Pawn.GroundSpeed < Pawn.default.WalkingPct * Pawn.default.GroundSpeed){
        Pawn.GroundSpeed = (Pawn.default.WalkingPct * Pawn.default.GroundSpeed);
    }

    //Log("RUNNINGCOUNT: " $ RunningCounter $ "VOL:" $ Pawn.SoundVolume);
}

defaultproperties
{
	PlayerReplicationInfoClass=Class'UMODDOTZGame.UmodPlayerReplicationInfo'

     MyLifeBar=DOTZHealthBar'DOTZEngine.DOTZPlayerController.LifeBar0'
     AdvancedCheatClass=Class'UMODDOTZGame.UmodPCCheatManager'

     PreLoadActors(0)="XDOTZCharacters.JackSlade"
     PreLoadActors(1)="XDOTZCharacters.PlayerOtis"
     PreLoadActors(2)="DOTZWeapons.BaseBallBatAmmunition"
     PreLoadActors(3)="DOTZWeapons.BaseBallBatAttachment"
     PreLoadActors(4)="DOTZWeapons.BaseBallBatWeapon"
     PreLoadActors(5)="DOTZWeapons.FireAxeAmmunition"
     PreLoadActors(6)="DOTZWeapons.FireAxeAttachment"
     PreLoadActors(7)="DOTZWeapons.FireAxeWeapon"
     PreLoadActors(8)="DOTZWeapons.FistAmmunition"
     PreLoadActors(9)="DOTZWeapons.FistWeapon"
     PreLoadActors(10)="DOTZWeapons.GlockAmmunition"
     PreLoadActors(11)="DOTZWeapons.GlockAttachment"
     PreLoadActors(12)="DOTZWeapons.GlockWeapon"
     PreLoadActors(13)="DOTZWeapons.GolfClubAmmunition"
     PreLoadActors(14)="DOTZWeapons.GolfClubAttachment"
     PreLoadActors(15)="DOTZWeapons.GolfClubWeapon"
     PreLoadActors(16)="DOTZWeapons.GrenadeAmmunition"
     PreLoadActors(17)="DOTZWeapons.GrenadeAttachment"
     PreLoadActors(18)="DOTZWeapons.GrenadeWeapon"
     PreLoadActors(19)="DOTZWeapons.HammerAmmunition"
     PreLoadActors(20)="DOTZWeapons.HammerAttachment"
     PreLoadActors(21)="DOTZWeapons.HammerWeapon"
     PreLoadActors(22)="DOTZWeapons.KungFuAmmunition"
     PreLoadActors(23)="DOTZWeapons.KungFuWeapon"
     PreLoadActors(24)="DOTZWeapons.LeadPipeAmmunition"
     PreLoadActors(25)="DOTZWeapons.LeadPipeAttachment"
     PreLoadActors(26)="DOTZWeapons.LeadPipeWeapon"
     PreLoadActors(27)="DOTZWeapons.M16Ammunition"
     PreLoadActors(28)="DOTZWeapons.M16Attachment"
     PreLoadActors(29)="DOTZWeapons.M16Weapon"
     PreLoadActors(30)="DOTZWeapons.MolotovAmmunition"
     PreLoadActors(31)="DOTZWeapons.MolotovAttachment"
     PreLoadActors(32)="DOTZWeapons.MolotovWeapon"
     PreLoadActors(33)="DOTZWeapons.RevolverAmmunition"
     PreLoadActors(34)="DOTZWeapons.RevolverAttachment"
     PreLoadActors(35)="DOTZWeapons.RevolverWeapon"
     PreLoadActors(36)="DOTZWeapons.RifleAmmunition"
     PreLoadActors(37)="DOTZWeapons.RifleAttachment"
     PreLoadActors(38)="DOTZWeapons.RifleWeapon"
     PreLoadActors(39)="DOTZWeapons.ShotGunAmmunition"
     PreLoadActors(40)="DOTZWeapons.ShotgunAttachment"
     PreLoadActors(41)="DOTZWeapons.ShotgunWeapon"
     PreLoadActors(42)="DOTZWeapons.ShovelAmmunition"
     PreLoadActors(43)="DOTZWeapons.ShovelAttachment"
     PreLoadActors(44)="DOTZWeapons.ShovelWeapon"
     PreLoadActors(45)="DOTZWeapons.SniperAmmunition"
     PreLoadActors(46)="DOTZWeapons.SniperAttachment"
     PreLoadActors(47)="DOTZWeapons.SniperWeapon"
     PreLoadActors(48)="DOTZWeapons.MountedWeaponA"
     PreLoadActors(49)="DOTZWeapons.MountedWeaponAmmunitionA"
     PreLoadActors(50)="DOTZWeapons.MountedWeaponAttachmentA"
}
