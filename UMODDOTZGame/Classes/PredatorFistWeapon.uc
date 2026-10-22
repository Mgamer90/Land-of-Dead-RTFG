class PredatorFistWeapon extends DOTZMeleeWeapon
    config(user);


/*****************************************************************
 * PlayFiring
 * Normal fire has occured by this point, we just need to make it look
 * like it has now, so play an animation.
 *****************************************************************
 */
simulated function PlayFiring(){

   local DOTZPlayerControllerBase PlayerOwner;
   PlayerOwner = DOTZPlayerControllerBase(Instigator.Controller);

   if (bDoAltFire == true){
       PlayAnim(AltFireAnim, SingleFireRate);
   } else {
       PlayAnim(FireAnim, SingleFireRate);
   }
   IncrementFlashCount();
}


//===========================================================================
// DefaultProperties
//===========================================================================

defaultproperties
{
     StdTraceDist=110
     AltTraceDist=110
     AltFireAnimName="KungFuAltFire"
     FireAnimName="KungFuFire"
     StandIdleAnimName="KungFuStandIdle"
     CrouchIdleAnimName="KungFuCrouchIdle"
     HitAnimName="KungFuHit"
     OfficialName="Predator Fists"
     AmmoName=Class'UMODDOTZGame.PredatorFistAmmunition'
     AutoSwitchPriority=15
     ItemName="Fists"
     Mesh=SkeletalMesh'DOTZAWeapons.KungFu'
}
