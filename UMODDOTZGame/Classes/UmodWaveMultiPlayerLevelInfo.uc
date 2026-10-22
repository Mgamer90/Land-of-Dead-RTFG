class UmodWaveMultiPlayerLevelInfo extends MultiPlayerLevelInfo;

//===========================================================================
// Level Specific data
//===========================================================================

var() int InitialWaveSize;
var() int WaveSizeIncrement;

//===========================================================================
// defaultProperties
//===========================================================================

defaultproperties
{
     InitialWaveSize=5
     WaveSizeIncrement=2
     StartingWeapon(0)="DOTZWeapons.FistWeapon"
}
