//=============================================================================
// UmodHumanMilitaryMale.
//=============================================================================
class UmodHumanMilitaryMale extends UmodHumanPawn
	placeable;

simulated function String GetHumanReadableName()
{
	if ( PlayerReplicationInfo != None )
		return PlayerReplicationInfo.PlayerName;

	return "BOT Sgt Travis";

	//return GetItemName(String(self));
}

defaultproperties
{
	HeadTextures(0)=Texture'UMODDOTZTHumans.SgtDanielTravis.SgtTravisHade01'
	HeadTextures(1)=Texture'UMODDOTZTHumans.SgtDanielTravis.SgtTravisHade02'
	HeadTextures(2)=Texture'UMODDOTZTHumans.SgtDanielTravis.SgtTravisHade03'
	BodyTextures(0)=Texture'UMODDOTZTHumans.SgtDanielTravis.SgtTravisCamoBrn'
	BodyTextures(1)=Texture'UMODDOTZTHumans.SgtDanielTravis.SgtTravisCamoGrn'
	BodyTextures(2)=Texture'UMODDOTZTHumans.SgtDanielTravis.SgtTravisCamoGry'
	BodyTextures(3)=Texture'UMODDOTZTHumans.SgtDanielTravis.SgtTravisGrn'
	BodyTextures(4)=Texture'UMODDOTZTHumans.SgtDanielTravis.SgtTravisGry'

	Mesh=SkeletalMesh'UMODDOTZAHumans.SgtDanielTravis'

	Skins(0)=Texture'UMODDOTZTHumans.SgtDanielTravis.SgtTravisCamoBrn'
	Skins(1)=Texture'UMODDOTZTHumans.SgtDanielTravis.SgtTravisHade01'
	
}
