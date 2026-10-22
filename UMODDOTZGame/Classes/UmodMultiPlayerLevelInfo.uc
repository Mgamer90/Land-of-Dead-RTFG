class UmodMultiPlayerLevelInfo extends ExtendedLevelInfo;

//===========================================================================
// Level Specific data
//===========================================================================
var() int   InitialInPlayLimit;
var() int   MaxInPlayLimit;
var() int   MinInPlayLimit;
var() float  PerPlayerInPlayLimitModifier;

var() array<string> StartingWeapon;

var() array<mesh> PreloadMesh;
var() array<MeshAnimation> PreloadAnimation;
var() array<Material> PreloadMaterial;

//===========================================================================
// defaultProperties
//===========================================================================

defaultproperties
{
     InitialInPlayLimit=4
     MaxInPlayLimit=5
     MinInPlayLimit=3
     PerPlayerInPlayLimitModifier=1.000000
     StartingWeapon(0)="DOTZWeapons.FistWeapon"
}
