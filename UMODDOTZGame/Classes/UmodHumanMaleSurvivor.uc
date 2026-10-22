//=============================================================================
// UmodHumanMaleSurvivor.
//=============================================================================
class UmodHumanMaleSurvivor extends UmodHumanPawn
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
     // HeadTextures(0)=Shader'DOTZTZombies.MaleMilitary.MaleMilitaryHeadShaderA'
     // HeadTextures(1)=Shader'DOTZTZombies.MaleMilitary.MaleMilitaryHeadShaderB'
     // HeadTextures(2)=Shader'DOTZTZombies.MaleMilitary.MaleMilitaryHeadShaderC'
     // HeadTextures(3)=Shader'DOTZTZombies.MaleMilitary.MaleMilitaryHeadShaderD'
     // HeadTextures(4)=Shader'DOTZTZombies.MaleMilitary.MaleMilitaryHeadShaderE'
     // HeadTextures(5)=Shader'DOTZTZombies.MaleMilitary.MaleMilitaryHeadShaderF'
     // HeadTextures(6)=Shader'DOTZTZombies.MaleMilitary.MaleMilitaryHeadShaderG'
     // HeadTextures(7)=Shader'DOTZTZombies.MaleMilitary.MaleMilitaryHeadShaderH'
     // HeadTextures(8)=Shader'DOTZTZombies.MaleMilitary.MaleMilitaryHeadShaderI'
     // HeadTextures(9)=Shader'DOTZTZombies.MaleMilitary.MaleMilitaryHeadShaderJ'

	 BodyTextures(0)=Shader'UMODDOTZTHumans.MaleMilitary.MaleMilitaryBodyAShader'
     BodyTextures(1)=Shader'UMODDOTZTHumans.MaleMilitary.MaleMilitaryBodyBShader'
     BodyTextures(2)=Shader'UMODDOTZTHumans.MaleMilitary.MaleMilitaryBodyCShader'
	 BodyTextures(3)=Shader'UMODDOTZTHumans.MaleMilitary.MaleMilitaryBodyDShader'
     BodyTextures(4)=Shader'UMODDOTZTHumans.MaleMilitary.MaleMilitaryBodyEShader'
     BodyTextures(5)=Shader'UMODDOTZTHumans.MaleMilitary.MaleMilitaryBodyFShader'

     HeadTextures(0)=Shader'UMODDOTZTHumans.MaleMilitary.MaleMilitaryHeadAShader'
     HeadTextures(1)=Shader'UMODDOTZTHumans.MaleMilitary.MaleMilitaryHeadAShader'
     HeadTextures(2)=Shader'UMODDOTZTHumans.MaleMilitary.MaleMilitaryHeadAShader'

	 Mesh=SkeletalMesh'UMODDOTZAHumans.MaleMilitary'
	 //Mesh=SkeletalMesh'DOTZAZombies.MaleMilitary'

	Skins(0)=Shader'DOTZTZombies.MaleMilitary.MaleMilitaryBodyShaderA'
	Skins(1)=Shader'DOTZTZombies.MaleMilitary.MaleMilitaryHeadShaderA'

     ControllerClass=Class'UMODDOTZGame.UmodBotControllerSurvivor'
	BotReplicationInfoClass=Class'UMODDOTZGame.UmodBotReplicationInfoMaleMilitary'
}
