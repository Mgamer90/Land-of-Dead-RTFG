//=============================================================================
// UmodHumanMaleSwat.
//=============================================================================
class UmodHumanMaleSwat extends UmodHumanPawn
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
     HeadTextures(0)=Shader'DOTZTZombies.MaleSwat.MaleSwatHeadShaderA'
     HeadTextures(1)=Shader'DOTZTZombies.MaleSwat.MaleSwatHeadShaderB'
     HeadTextures(2)=Shader'DOTZTZombies.MaleSwat.MaleSwatHeadShaderC'
     HeadTextures(3)=Shader'DOTZTZombies.MaleSwat.MaleSwatHeadShaderD'
     HeadTextures(4)=Shader'DOTZTZombies.MaleSwat.MaleSwatHeadShaderE'
     HeadTextures(5)=Shader'DOTZTZombies.MaleSwat.MaleSwatHeadShaderF'
     HeadTextures(6)=Shader'DOTZTZombies.MaleSwat.MaleSwatHeadShaderG'
     HeadTextures(7)=Shader'DOTZTZombies.MaleSwat.MaleSwatHeadShaderH'
     HeadTextures(8)=Shader'DOTZTZombies.MaleSwat.MaleSwatHeadShaderI'
     HeadTextures(9)=Shader'DOTZTZombies.MaleSwat.MaleSwatHeadShaderJ'
     BodyTextures(0)=Shader'DOTZTZombies.MaleSwat.MaleSwatBodyShaderA'
     BodyTextures(1)=Shader'DOTZTZombies.MaleSwat.MaleSwatBodyShaderB'
     BodyTextures(2)=Shader'DOTZTZombies.MaleSwat.MaleSwatBodyShaderC'
     BodyTextures(3)=Shader'DOTZTZombies.MaleSwat.MaleSwatBodyShaderD'
     BodyTextures(4)=Shader'DOTZTZombies.MaleSwat.MaleSwatBodyShaderE'

	//Mesh=SkeletalMesh'DOTZAZombies.MaleSwat'
	Mesh=SkeletalMesh'UMODDOTZAHumans.MaleSwat'

	Skins(0)=Shader'DOTZTZombies.MaleSwat.MaleSwatBodyShaderA'
	Skins(1)=Shader'DOTZTZombies.MaleSwat.MaleSwatHeadShaderA'
	
}
