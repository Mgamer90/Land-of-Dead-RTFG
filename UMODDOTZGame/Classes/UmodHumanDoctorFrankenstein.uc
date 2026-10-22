//=============================================================================
// UmodHumanDoctorFrankenstein.
//=============================================================================
class UmodHumanDoctorFrankenstein extends UmodHumanPawn
	placeable;

simulated function String GetHumanReadableName()
{
	if ( PlayerReplicationInfo != None )
		return PlayerReplicationInfo.PlayerName;

	return "BOT Doctor Frankenstein";

	//return GetItemName(String(self));
}

defaultproperties
{
	HeadTextures(0)=Shader'DOTZTHumans.DoctorBob.DoctorBobHead'
	HeadTextures(1)=Shader'DOTZTHumans.DoctorBob.DoctorBobHead'
	HeadTextures(2)=Shader'DOTZTHumans.DoctorBob.DoctorBobHead'
	BodyTextures(0)=Shader'DOTZTHumans.DoctorBob.DoctorBobBody'
	BodyTextures(1)=Shader'DOTZTHumans.DoctorBob.DoctorBobBody'
	BodyTextures(2)=Shader'DOTZTHumans.DoctorBob.DoctorBobBody'

	//BodyTextures(1)=Shader'DOTZTHumans.DoctorBob.DoctorBobZombieBodyShader'
	//Mesh=SkeletalMesh'DOTZAHumans.DoctorBob'
	Mesh=SkeletalMesh'UMODDOTZAHumans.DoctorBob'

	Skins(0)=Shader'DOTZTHumans.DoctorBob.DoctorBobBody'
	Skins(1)=Shader'DOTZTHumans.DoctorBob.DoctorBobHead'

	BotReplicationInfoClass=Class'UMODDOTZGame.UmodBotReplicationInfoDoctorMale'
}
