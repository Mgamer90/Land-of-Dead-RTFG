//=============================================================================
// UmodHumanJackMilitary.
//=============================================================================
class UmodHumanJackMilitary extends UmodHumanPawn
	placeable;

defaultproperties
{
	HeadTextures(0)=Shader'DOTZTHumans.JackSlade.JackSladeHeadShaderA'
	HeadTextures(1)=Shader'DOTZTHumans.JackSlade.JackSladeHeadShaderB'
	HeadTextures(2)=Shader'DOTZTHumans.JackSlade.JackSladeHeadShaderC'

	BodyTextures(0)=Shader'UMODDOTZTHumans.MaleMilitary.MaleMilitaryBodyAShader'
	BodyTextures(1)=Shader'UMODDOTZTHumans.MaleMilitary.MaleMilitaryBodyBShader'
	BodyTextures(2)=Shader'UMODDOTZTHumans.MaleMilitary.MaleMilitaryBodyCShader'
	BodyTextures(3)=Shader'UMODDOTZTHumans.MaleMilitary.MaleMilitaryBodyDShader'
	BodyTextures(4)=Shader'UMODDOTZTHumans.MaleMilitary.MaleMilitaryBodyEShader'
	BodyTextures(5)=Shader'UMODDOTZTHumans.MaleMilitary.MaleMilitaryBodyFShader'

	Mesh=SkeletalMesh'UMODDOTZAHumans.JackMilitary'
	//Mesh=SkeletalMesh'DOTZAHumans.JackSlade'
	Skins(0)=Shader'UMODDOTZTHumans.MaleMilitary.MaleMilitaryBodyAShader'
	Skins(1)=Shader'DOTZTHumans.JackSlade.JackSladeHeadShaderA'

	BotReplicationInfoClass=Class'UMODDOTZGame.UmodBotReplicationInfoJack'
}
