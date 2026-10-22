//=============================================================================
// UmodOtisPawn.
//=============================================================================
class UmodHumanJack extends UmodHumanPawn
	placeable;

defaultproperties
{
	HeadTextures(0)=Shader'DOTZTHumans.JackSlade.JackSladeHeadShaderA'
	HeadTextures(1)=Shader'DOTZTHumans.JackSlade.JackSladeHeadShaderB'
	HeadTextures(2)=Shader'DOTZTHumans.JackSlade.JackSladeHeadShaderC'
	BodyTextures(0)=Shader'DOTZTHumans.JackSlade.JackSladeBodyShaderA'
	BodyTextures(1)=Shader'DOTZTHumans.JackSlade.JackSladeBodyShaderB'
	BodyTextures(2)=Shader'DOTZTHumans.JackSlade.JackSladeBodyShaderC'
	
	BodyTextures(3)=Shader'UMODDOTZTHumans.JackSlade.JackSladeBodyShaderA'
	BodyTextures(4)=Shader'UMODDOTZTHumans.JackSlade.JackSladeBodyShaderB'
	BodyTextures(5)=Shader'UMODDOTZTHumans.JackSlade.JackSladeBodyShaderC'
	BodyTextures(6)=Shader'UMODDOTZTHumans.JackSlade.JackSladeBodyShaderD'
	BodyTextures(7)=Shader'UMODDOTZTHumans.JackSlade.JackSladeBodyShaderE'

	Mesh=SkeletalMesh'DOTZAHumans.JackSlade'
	Skins(0)=Shader'DOTZTHumans.JackSlade.JackSladeBodyShaderC'
	Skins(1)=Shader'DOTZTHumans.JackSlade.JackSladeHeadShaderA'

	BotReplicationInfoClass=Class'UMODDOTZGame.UmodBotReplicationInfoJack'
}
