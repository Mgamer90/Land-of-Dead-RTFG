class KungFuWeaponPickup extends DOTZWeaponPickup
      placeable;


//===========================================================================
// DefaultProperties
//===========================================================================

defaultproperties
{
     WeaponType="'"
     ActionPickupMessage="Press Action to take the Kung Fu book"
     MaxDesireability=0.750000
     InventoryType=Class'DOTZWeapons.KungFuWeapon'
     PickupMessage="You got the Kung Fu book"
     DrawType=DT_StaticMesh
     StaticMesh=StaticMesh'DOTZSSpecial.Pickups.KungFu'

     PickupSound=Sound'DOTZXInterface.PickupKungFu'

     Skins(0)=Shader'UMODDOTZTWeapons.PickupShaders.KungFuShader'
}
