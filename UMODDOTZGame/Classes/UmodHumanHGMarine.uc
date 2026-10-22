//=============================================================================
// UmodHumanHGMarine.
//=============================================================================
class UmodHumanHGMarine extends UmodHumanPawn
	placeable;

simulated function String GetHumanReadableName()
{
	if ( PlayerReplicationInfo != None )
		return PlayerReplicationInfo.PlayerName;

	return "BOT Marine";

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
	Mesh=SkeletalMesh'UMODDOTZAHumans.SgtDanielTravis'

	Skins(0)=Texture'UMODDOTZTHumans.SgtDanielTravis.SgtTravisCamoBrn'
	Skins(1)=Texture'UMODDOTZTHumans.SgtDanielTravis.SgtTravisHade01'
	
	// AdditionalAnimPkg(0)=(AnimName="HGACharactersB.HGMarines")
	// HeadTextures(0)=Texture'HGTCharacters.Marines.HGbody'
	// HeadTextures(1)=Texture'HGTCharacters.Marines.HGbody'
	// HeadTextures(2)=Texture'HGTCharacters.Marines.HGbody'
	// BodyTextures(0)=Texture'HGTCharacters.Marines.HGHead'
	// BodyTextures(1)=Texture'HGTCharacters.Marines.HGHead'
	// BodyTextures(2)=Texture'HGTCharacters.Marines.HGHead'
	// Mesh=SkeletalMesh'HGACharactersB.HGMarine'

	// Skins(0)=Texture'HGTCharacters.Marines.HGHead'
	// Skins(1)=Texture'HGTCharacters.Marines.HGbody'
		// HeadTextures(0)=Texture'HGTCharacters.Marines.SgtTravisHade01'
	// HeadTextures(1)=Texture'HGTCharacters.Marines.SgtTravisHade02'
	// HeadTextures(2)=Texture'HGTCharacters.Marines.SgtTravisHade03'
	// BodyTextures(0)=Texture'HGTCharacters.Marines.SgtTravisCamoBrn'
	// BodyTextures(1)=Texture'HGTCharacters.Marines.SgtTravisCamoGrn'
	// BodyTextures(2)=Texture'HGTCharacters.Marines.SgtTravisCamoGry'
	// Mesh=SkeletalMesh'UMODDOTZAHumans.SgtDanielTravis'

	// Skins(0)=Texture'HGTCharacters.Marines.SgtTravisCamoBrn'
	// Skins(1)=Texture'HGTCharacters.Marines.SgtTravisHade01'
	
}
