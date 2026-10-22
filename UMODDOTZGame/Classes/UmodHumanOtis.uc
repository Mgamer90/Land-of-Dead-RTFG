//=============================================================================
// UmodHumanPawn.
//=============================================================================
class UmodHumanOtis extends UmodHumanPawn
	placeable;

simulated function String GetHumanReadableName()
{
	if ( PlayerReplicationInfo != None )
		return PlayerReplicationInfo.PlayerName;

	return "BOT Otis";

	//return GetItemName(String(self));
}

defaultproperties
{
	HeadTextures(0)=Shader'DOTZTHumans.Otis.OtisHeadShaderA'
	HeadTextures(1)=Shader'DOTZTHumans.Otis.OtisHeadShaderB'
	HeadTextures(2)=Shader'DOTZTHumans.Otis.OtisHeadShaderC'
	BodyTextures(0)=Shader'DOTZTHumans.Otis.OtisBodyShaderA'
	BodyTextures(1)=Shader'DOTZTHumans.Otis.OtisBodyShaderB'
	BodyTextures(2)=Shader'DOTZTHumans.Otis.OtisBodyShaderC'
	Mesh=SkeletalMesh'DOTZAHumans.Otis'

	Skins(0)=Shader'DOTZTHumans.Otis.OtisBodyShaderA'
	Skins(1)=Shader'DOTZTHumans.Otis.OtisHeadShaderA'

	BotReplicationInfoClass=Class'UMODDOTZGame.UmodBotReplicationInfoOtis'
}
