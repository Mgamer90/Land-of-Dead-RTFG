//=============================================================================
// UmodHumanMaleCop.
//=============================================================================
class UmodHumanMaleCop extends UmodHumanPawn
	placeable;

simulated function String GetHumanReadableName()
{
	if ( PlayerReplicationInfo != None )
		return PlayerReplicationInfo.PlayerName;

	return "BOT Maxwell";

	//return GetItemName(String(self));
}

defaultproperties
{
	HeadTextures(1)=Shader'DOTZTZombies.MaleCop.MaleCopHeadShaderA'

	BodyTextures(0)=Shader'DOTZTZombies.MaleSwat.MaleSwatBodyShaderA'
	BodyTextures(1)=Shader'DOTZTZombies.MaleSwat.MaleSwatBodyShaderB'
	BodyTextures(2)=Shader'DOTZTZombies.MaleSwat.MaleSwatBodyShaderC'
	BodyTextures(3)=Shader'DOTZTZombies.MaleSwat.MaleSwatBodyShaderD'
	BodyTextures(4)=Shader'DOTZTZombies.MaleSwat.MaleSwatBodyShaderE'

	//Mesh=SkeletalMesh'DOTZAZombies.MaleCop'
	Mesh=SkeletalMesh'UMODDOTZAHumans.MaleCop'

	Skins(0)=Shader'DOTZTZombies.MaleCop.MaleCopBodyShaderA'
	Skins(1)=Shader'DOTZTZombies.MaleCop.MaleCopHeadShaderA'
	
}
