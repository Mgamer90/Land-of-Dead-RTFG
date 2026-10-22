//=============================================================================
// UmodHumanHeavyMale.
//=============================================================================
class UmodHumanHeavyMale extends UmodHumanPawn
	placeable;

simulated function String GetHumanReadableName()
{
	if ( PlayerReplicationInfo != None )
		return PlayerReplicationInfo.PlayerName;

	return "BOT Hogarth Morten";

	//return GetItemName(String(self));
}

defaultproperties
{
	HeadTextures(0)=Texture'UMODDOTZTHumans.Hogarth.HogarthMortenHade01'
	HeadTextures(1)=Texture'UMODDOTZTHumans.Hogarth.HogarthMortenHade01'
	HeadTextures(2)=Texture'UMODDOTZTHumans.Hogarth.HogarthMortenHade01'
	BodyTextures(0)=Texture'UMODDOTZTHumans.Hogarth.HogarthMortenBody01'
	BodyTextures(1)=Texture'UMODDOTZTHumans.Hogarth.HogarthMortenBody01'

	Mesh=SkeletalMesh'UMODDOTZAHumans.HogarthMorten'

	Skins(0)=Texture'UMODDOTZTHumans.Hogarth.HogarthMortenBody01'
	Skins(1)=Texture'UMODDOTZTHumans.Hogarth.HogarthMortenHade01'

	BotReplicationInfoClass=Class'UMODDOTZGame.UmodBotReplicationInfoHeavyMale'
}
