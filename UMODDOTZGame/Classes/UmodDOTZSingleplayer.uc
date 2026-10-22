class UmodDOTZSingleplayer extends DOTZGameInfo;

// //these are in game variables that apply to the current game
// var int CurrentChapter;
// var int CurrentPage;
// var ObjectivesManager theObjMgr;

// //these are global values tha apply to the entire game
// var config int BestChapter;
// var config int BestPage;
// //var bool bPauseWithMenu;

// var bool bNameCheat;

// var config string PauseMenuSP;
// var config string DeadMenuSP;
// var config string DeadMenuSPParam;

// var config string ProfileMenu;
// var localized string PCMsg;

// var int tickcount;

// //dead message stuff
// var Material SpectatingOverlay;

// //===========================================================================
// // Internal data
// //===========================================================================

var UnrealRepositorySingleplayer ModRepo;

var config class<Pawn> OverridePawnClass;

var protected int PickupsQuality;

// Runaway loop detected (over 1000000 iteration
const MAX_LOOP = 1000000;

// Shared veteran-wander route cache. Built once per level/game mode and reused by all bots.
const BOT_ROUTE_MAX_TARGETS = 64;
const BOT_ROUTE_MAX_NAV_NODES = 768;
const BOT_ROUTE_INFINITY = 999999999.0;

var protected bool bBotInstantRespawn;

var protected array<Actor> BotRouteTargets;
var protected array<NavigationPoint> BotRouteTargetNodes;
var protected array<NavigationPoint> BotRouteNavNodes;
var protected array<float> BotRouteDistances;
var protected array<int> BotRouteOrder;
var protected bool bBotRouteCacheBuilt;

var protected int MinPlayers;
var protected bool bPlayersVsBots;
var protected bool bKillBots;

/*******************************************************************
 * Initialize the game.  The GameInfo's InitGame() function is called
 * before any other scripts (including PreBeginPlay() ), and is used
 * by the GameInfo to initialize parameters and spawn its helper
 * classes.  Warning: this is called before actors' PreBeginPlay.
 *******************************************************************
 */
event InitGame(String options, out String error){
   Super.InitGame(options, error);
   //Level.NetMode = NM_StandAlone;
   theObjMgr = Spawn( class'DOTZObjectivesManager' );

    ModRepo = new class'UMODDOTZGame.UnrealRepositorySingleplayer';

    if (ModRepo != None)
    {
		OverridePlayerControllerClass = class<PlayerController>(DynamicLoadObject(ModRepo.PlayerControllerClassName, class'Class'));

		if (OverridePlayerControllerClass != none){PlayerControllerClass = OverridePlayerControllerClass;}

		OverridePawnClass = class<Pawn>(DynamicLoadObject(ModRepo.PlayerPawnClassName, class'Class'));

		if (OverridePawnClass == none)
		{OverridePawnClass = class<Pawn>(DynamicLoadObject(DefaultPlayerClassName, class'Class'));}
	}

	PopulateWeaponPickUps();

    BuildBotRouteCache(true);
}


 /**
 * override normal hud with spectating overlay...
 */
function DrawToHud( Canvas c, float scaleX, float scaleY ) {
   local PlayerController pc;
   local float textWidth, textHeight;

   pc = Level.GetLocalPlayerController();


   if (pc.IsDead())
   {
      if (pc.IsA('XDotzPlayerController') == true){
        //set by the level
        //SpectatingMsg = "Game Over. Press START to continue.";
      } else {
        SpectatingMsg = PCMsg;
      }

      if ( SpectatingOverlay != none ) {
         c.SetPos( 384 * scaleX, 352 * scaleY );
         c.SetDrawColor( 255, 255, 255 );
         c.DrawTile( SpectatingOverlay, 512 * scaleX, 256 * scaleY,
                                              0, 0, 512, 256 );
      } else if ( SpectatingMsg != "" ) {
         c.TextSize( SpectatingMsg, textWidth, textHeight );
         c.SetPos( 640 * scaleX - (textWidth/2), 480 * scaleY );
         //c.Font = c.
         c.SetDrawColor( 255, 255, 255 );
//         c.bCenter = true;
         c.DrawText(SpectatingMsg );
  //       c.bCenter = false;
      }
   }
}

/*****************************************************************
 * SetPause
 *****************************************************************
 */
function bool SetPause( bool bPause, PlayerController pc ) {
   //if you are pausing and there is a pawn then bring up the menu
   // and pause the game, if you have no pawn and are still alive
   // (you are in a cinematic) then do nothing

   //short circuit the normal menu pause crap
   if (AdvancedPlayerController(pc).objVideoPlayer.VideoIsPlaying() )
   {
        if (AdvancedPlayerController(pc).objVideoPlayer.VideoIsPlaying() && bPause == false){
            AdvancedPlayerController(pc).objVideoPlayer.StopVideo();
        }
        return super.SetPause(bPause,pc);
   }

   //if you are dead
   if (pc.IsDead()){
      GuiController(pc.Player.InteractionMaster.GlobalInteractions[0])
           .OpenMenu(DeadMenuSP, DeadMenuSPParam);
      return Super.SetPause(bPause, pc);
   }

   //pausing and not in a cinematic
   if (bPause && !(pc.Pawn == None && pc.IsDead()==false))
   {
      GuiController(pc.Player.InteractionMaster.GlobalInteractions[0])
               .OpenMenu(PauseMenuSP);
      return Super.SetPause(bPause, pc);
   }
   //if you are unpausing then unpause
   else if (!bPause){
       return Super.SetPause(bPause, pc);
   }

   return true;
}

/*****************************************************************
 * Tick
 *****************************************************************
 */
event Tick(float delta){
    super.Tick(delta);
    if (Tickcount == 0){
        Tickcount++;
    } else if (tickcount == 1){
        tickcount++;
        LevelStart();
    }
}


/*****************************************************************
 *
 *****************************************************************
 */
function PostLoad(){
    local Projector temp;

    super.PostLoad();

    foreach Allactors(class'Projector', temp){
            if (ShadowProjector(temp) == none){
                temp.AttachProjector();
            }
    }
}


/*****************************************************************
 * LevelStart
 *****************************************************************
 */
function LevelStart(){
    local PlayerController pc;
    //local DOTZCheckpoint cp;

   // local int ChapterNum, PageNum, RevealNum;

    pc = Level.GetLocalPlayerController();
   // bPauseWithMenu = false;
    //pc.SetPause(true);
   // bPauseWithMenu = true;

    //ChapterNum = GameSpecificLevelInfo(Level.GameSpecificLevelInfo).ChapterNumber;
   // PageNum = GameSpecificLevelInfo(Level.GameSpecificLevelInfo).PageNumber;
    //RevealNum = GameSpecificLevelInfo(Level.GameSpecificLevelInfo).RevealledTo;

    //close any loading screen menus
    GuiController(pc.Player.InteractionMaster.GlobalInteractions[0]).CloseAll(true);
    /*
    //ensure that menus are set to display proper chapters
    RevealChapter(ChapterNum, RevealNum);

    //open the level start page
    GuiController(pc.Player.InteractionMaster.GlobalInteractions[0])
          .OpenMenu("DOTZMenu.DOTZStoryPageMenu",
          string(ChapterNum),
          string(PageNum));
*/
/* commentted out because FindPlayerStart() below returns the checkpoint to load to
    // SV: lets move player to checkpoint
    if( Level.ActiveCheckPointID > 0 )
    {
        foreach AllActors( class'DOTZCheckPoint', cp )
        {
            if( Level.ActiveCheckPointID == cp.id )
            {
                cp.TransportPlayer();
                //Level.ActiveCheckPointID = cp.id;
                break;
            }
        }
    }
*/
}


/* Return the checkpoint to spawn at.
 */
function NavigationPoint FindPlayerStart( Controller Player, optional byte InTeam, optional string incomingName )
{
    local DOTZCheckPoint cp;

    foreach AllActors( class'DOTZCheckPoint', cp )
    {
        if( ( cp.id == 1 ) && ( Level.ActiveCheckPointID == -1 ) )
        {
            // If we are new to this level, then just return the first checkpoint
            cp.bTouchable = true;
            return cp;
        }

        if( Level.ActiveCheckPointID == cp.id )
        {
            cp.bTouchable = true;
            return cp;
        }
    }

    // If we didnt find anything, just return the playerstart
    //tmp.bTouchable = true;
    return super.FindPlayerStart( Player, InTeam, incomingName );
}

//===========================================================================
// Exec functions
//===========================================================================


/******************************************************************
 * TestEvent
 * Triggers the specified event.  Handy for debugging.
 ******************************************************************
 */
exec function TestEvent( Name eventName ) {
    Log( "Triggering [" $ eventName $ "]" );
    TriggerEvent( eventName, self, none );
}


/******************************************************************
 * NoMusic
 * Stops any music currently playing.
 ******************************************************************
 */
exec function NoMusic() {
   StopAllMusic( 2 );
}





/*****************************************************************
 *
 *****************************************************************
 */
exec function CheckSearchable(){
    local ActionableSkeletalMesh temp;
    foreach AllActors(class'ActionableSkeletalMesh', temp){
        temp.Check();
    }
}

function string GetCurrentProfileName(){
   return DOTZPlayerControllerBase(Level.GetLocalPlayerController()).GetCurrentProfileName();
}


/*****************************************************************
 * GameOver
 * Call to game over whenever a human pawn dies in singleplayer
 * set the local player controller to 'dead'
 *****************************************************************
 */
function GameOver(){
    AdvancedPlayerController(Level.GetLocalPlayerController()).GameOver();
    Level.Game.SetPause(true,Level.GetLocalPlayerController());
}

/*****************************************************************
 * GiveDefaultInventory
 *****************************************************************
 */
function GiveDefaultInventory(Pawn P){
   AdvancedPawn(P).SetInventoryLimit(1,'MeleeWeapon');
   AdvancedPawn(P).SetInventoryLimit(1,'GlockWeapon');
   AdvancedPawn(P).SetInventoryLimit(1,'M16Weapon');
   AdvancedPawn(P).SetInventoryLimit(1,'RevolverWeapon');
   AdvancedPawn(P).SetInventoryLimit(1,'RifleWeapon');
   AdvancedPawn(P).SetInventoryLimit(1,'ShotgunWeapon');
   AdvancedPawn(P).SetInventoryLimit(1,'SniperWeapon');
   AdvancedPawn(P).SetInventoryLimit(1,'GrenadeWeapon');
   AdvancedPawn(P).SetInventoryLimit(1,'MolotovWeapon');
   Log("Giving Weapon to the player");
   P.GiveWeapon(DefaultInventory);
}

/*****************************************************************
 * RevealChapter
 *****************************************************************
 */
function RevealChapter(int ChapterNumber, int PageNumber){

    //update the local game copies
    CurrentChapter = ChapterNumber;
    CurrentPage = PageNumber;

    //Update the global copies, set chapter if it is better
    if (ChapterNumber > class'DOTZGameInfoBase'.default.BestChapter){
        class'DOTZGameInfoBase'.default.BestChapter = ChapterNumber;
    }

    //make sure that an old chapter doesn't adjust this value
    if (CurrentChapter >= class'DOTZGameInfoBase'.default.BestChapter){
        //set page if it is better
        if (PageNumber > class'DOTZGameInfoBase'.default.BestPage || PageNumber == -1){
            class'DOTZGameInfoBase'.default.BestPage  = PageNumber;
        }
    }
    class'DOTZGameInfoBase'.static.StaticSaveConfig();
}

/*****************************************************************
 * GetCurrentChapter
 *****************************************************************
 */
static function int GetBestChapter(){
    return class'DOTZGameInfoBase'.default.BestChapter;
}

/*****************************************************************
 * GetCurrentPage
 *****************************************************************
 */
static function int GetBestPage(){
    return class'DOTZGameInfoBase'.default.BestPage;
}

//
// Spawn any default inventory for the player.
//
function AddDefaultInventory2( pawn PlayerPawn )
{
	local Weapon newWeapon;
	local class<Weapon> WeapClass;
	local int num, idx;

	if ( PlayerPawn == None )
		return;

	// Spawn default weapon.
	if( BaseMutator != None && BaseMutator.IsA('Weapon'))
	{
		WeapClass = BaseMutator.GetDefaultWeapon();

		if( (WeapClass!=None) && (PlayerPawn.FindInventoryType(WeapClass)==None) )
		{
			newWeapon = Spawn(WeapClass,,,PlayerPawn.Location);
			if( newWeapon != None )
			{
				newWeapon.GiveTo(PlayerPawn);
				//newWeapon.BringUp();
				newWeapon.bCanThrow = false; // don't allow default weapon to be thrown out
			}
		}
	}
	else
	{
		if(ModRepo != None)
		{
			if(WeapClass == None)
			{
				num = ModRepo.BackupWeaponNameList.Length;

				if (num > 0)
				{
					idx = Rand(num);

					WeapClass = class<Weapon>(DynamicLoadObject(ModRepo.BackupWeaponNameList[idx], class'Class'));
				}
			}
		}

		if(WeapClass == None)
		{
			WeapClass = class<Weapon>(DynamicLoadObject("DOTZWeapons.GlockWeapon", class'Class'));
		}

		newWeapon = Spawn(WeapClass,,,PlayerPawn.Location);
		if( newWeapon != None )
		{
			newWeapon.GiveTo(PlayerPawn);
			//newWeapon.BringUp();
			newWeapon.bCanThrow = false; // don't allow default weapon to be thrown out
		}
	}

	SetPlayerDefaults(PlayerPawn);
}

function PopulateWeaponPickUps()
{
	local Pickup newPickup;
	local class<Pickup> PickupClass;
	local int i;
    local Pickup Pickup;
    //local NavigationPoint N;
    local PlayerStart PS;
    local vector PickupLocation;
	local array<string> PickupList;
    local ZombieFactory ZF;

	if(ModRepo != None)
	{
		foreach AllActors(class'Pickup', Pickup)
		{
			if (Pickup != None)
			{
				if (Pickup.IsA('M16Pickup') || Pickup.IsA('M16AmmoPickup'))
				{
					PickupsQuality = 4;
					break;
				}
				else if (Pickup.IsA('SniperPickup') || Pickup.IsA('SniperAmmoPickup'))
				{
					PickupsQuality = 3;
					break;
				}
				else if (Pickup.IsA('ShotgunPickup')) /* || Pickup.IsA('ShotgunAmmoPickup'))*/
				{
					PickupsQuality = 2;
					break;
				}
				else if (Pickup.IsA('GlockPickup') || Pickup.IsA('GrenadePickup'))
				{
					PickupsQuality = 1;
					break;
				}
			}
		}

		if(PickupsQuality > 3)
		{
			PickupList = ModRepo.Tier1PickupClassList;
		}
		else if(PickupsQuality == 3)
		{
			PickupList = ModRepo.Tier2PickupClassList;
		}
		else if(PickupsQuality == 2)
		{
			PickupList = ModRepo.Tier3PickupClassList;
		}
		else if(PickupsQuality == 1)
		{
			PickupList = ModRepo.Tier4PickupClassList;
		}
		else
		{
			PickupList = ModRepo.Tier5PickupClassList;
			//PickupList = ModRepo.BackupWeaponPickupClassList;
		}

		if(PickupList.Length > 0 && PickupList.Length < 100)
		{
			foreach AllActors(class'PlayerStart', PS)
			{
				/*if (i < PickupList.Length)
				{
					PickupClass = class<Pickup>(DynamicLoadObject(PickupList[i], class'Class'));

					if(PickupClass != None)
					{
						PickupLocation = ZF.Location;
						PickupLocation.Z = PickupLocation.Z - 75.0;
						newPickup = Spawn(PickupClass,,,PickupLocation);
						i++;
					}
				}
				else{break;}*/
			}

			foreach AllActors(class'ZombieFactory', ZF)
			{
				if (i < PickupList.Length)
				{
					PickupClass = class<Pickup>(DynamicLoadObject(PickupList[i], class'Class'));

					if(PickupClass != None)
					{
						PickupLocation = ZF.Location;
						PickupLocation.Z = PickupLocation.Z - 75.0;
						newPickup = Spawn(PickupClass,,,PickupLocation);
						i++;
					}
				}
				else{break;}
			}

			/*for (N = Level.NavigationPointList; N != None; N = N.NextNavigationPoint)
			{
				if (i < PickupList.Length)
				{
					PickupClass = class<Pickup>(DynamicLoadObject(PickupList[i], class'Class'));

					if(PickupClass != None)
					{
						PickupLocation = N.Location;
						PickupLocation.Z = PickupLocation.Z - 75.0;
						newPickup = Spawn(PickupClass,,,PickupLocation);
						i++;
					}
				}
				else{break;}
			}*/
		}
	}
}

function int FindBotRouteNavIndex(NavigationPoint N)
{
    local int i;

    if (N == None)
        return -1;

    for (i = 0; i < BotRouteNavNodes.Length; i++)
    {
        if (BotRouteNavNodes[i] == N)
            return i;
    }

    return -1;
}

function NavigationPoint FindNearestBotRouteNav(vector Location)
{
    local NavigationPoint N;
    local NavigationPoint Best;
    local float BestDistSq;
    local float DistSq;

    BestDistSq = BOT_ROUTE_INFINITY;

    for (N = Level.NavigationPointList; N != None; N = N.NextNavigationPoint)
    {
        DistSq = (N.Location - Location) Dot (N.Location - Location);
        if (DistSq < BestDistSq)
        {
            BestDistSq = DistSq;
            Best = N;
        }
    }

    return Best;
}

function ClearBotRouteCache()
{
    BotRouteTargets.Length = 0;
    BotRouteTargetNodes.Length = 0;
    BotRouteNavNodes.Length = 0;
    BotRouteDistances.Length = 0;
    BotRouteOrder.Length = 0;
    bBotRouteCacheBuilt = false;
}

function BuildBotRouteDistances()
{
    local int TargetCount;
    local int SourceTarget;
    local int Target;
    local vector Delta;
    local float DistanceSq;

    TargetCount = BotRouteTargets.Length;

    if (TargetCount <= 0)
        return;

    // Do NOT walk the entire navigation graph here.  The previous implementation
    // ran a Dijkstra search over every navigation node for every target and then
    // performed a linear node lookup for every ReachSpec.  On large maps this can
    // take tens of millions of script iterations and look like an infinite loop
    // to the engine watchdog.
    //
    // The veteran route only needs a stable distance ordering between the static
    // landmarks.  Cache their geometric distances once; movement/pathfinding is
    // still handled by the normal bot navigation when the bot travels to a target.
    BotRouteDistances.Length = TargetCount * TargetCount;

    for (SourceTarget = 0; SourceTarget < TargetCount; SourceTarget++)
    {
        for (Target = 0; Target < TargetCount; Target++)
        {
            if (SourceTarget == Target)
            {
                BotRouteDistances[SourceTarget * TargetCount + Target] = 0.0;
                continue;
            }

            if (BotRouteTargets[SourceTarget] == None || BotRouteTargets[Target] == None)
            {
                BotRouteDistances[SourceTarget * TargetCount + Target] = BOT_ROUTE_INFINITY;
                continue;
            }

            Delta = BotRouteTargets[Target].Location - BotRouteTargets[SourceTarget].Location;
            DistanceSq = Delta Dot Delta;

            // Keep the cached value finite.  UnrealScript float overflow is not
            // useful here and could corrupt the route ordering.
            if (DistanceSq >= BOT_ROUTE_INFINITY)
                BotRouteDistances[SourceTarget * TargetCount + Target] = BOT_ROUTE_INFINITY;
            else
                BotRouteDistances[SourceTarget * TargetCount + Target] = DistanceSq;
        }
    }
}

function BuildBotRouteOrder()
{
    local int TargetCount;
    local int Origin;
    local int Rank;
    local int i;
    local int BestIndex;
    local float BestDistance;
    local float CandidateDistance;
    local int MatrixBase;
    local array<byte> Used;

    TargetCount = BotRouteTargets.Length;
    if (TargetCount <= 0)
        return;

    BotRouteOrder.Length = TargetCount * TargetCount;

    for (Origin = 0; Origin < TargetCount; Origin++)
    {
        Used.Length = TargetCount;
        for (i = 0; i < TargetCount; i++)
            Used[i] = 0;

        MatrixBase = Origin * TargetCount;

        // Rank targets from nearest to farthest using the cached path distances.
        // The origin itself is always rank 0.
        for (Rank = 0; Rank < TargetCount; Rank++)
        {
            BestIndex = -1;
            BestDistance = BOT_ROUTE_INFINITY;

            for (i = 0; i < TargetCount; i++)
            {
                if (Used[i] != 0)
                    continue;

                CandidateDistance = BotRouteDistances[MatrixBase + i];
                if (CandidateDistance < BestDistance)
                {
                    BestDistance = CandidateDistance;
                    BestIndex = i;
                }
            }

            if (BestIndex < 0)
            {
                // Keep the table deterministic even for disconnected nodes.
                for (i = 0; i < TargetCount; i++)
                {
                    if (Used[i] == 0)
                    {
                        BestIndex = i;
                        break;
                    }
                }
            }

            if (BestIndex < 0)
                break;

            Used[BestIndex] = 1;
            BotRouteOrder[MatrixBase + Rank] = BestIndex;
        }
    }
}

function BuildBotRouteCache(bool bUseZombieFactories)
{
    local NavigationPoint N;
    local NavigationPoint TargetNode;
    local ZombieFactory ZF;
    local int TargetCount;
    local int NavCount;

    ClearBotRouteCache();

    // Cache the complete navigation graph once. The graph is static for the map.
    for (N = Level.NavigationPointList; N != None; N = N.NextNavigationPoint)
    {
        if (BotRouteNavNodes.Length >= BOT_ROUTE_MAX_NAV_NODES)
            break;

        BotRouteNavNodes[BotRouteNavNodes.Length] = N;
    }

    NavCount = BotRouteNavNodes.Length;
    if (NavCount <= 0)
    {
        Log("[VeteranRoute] No navigation points found; route cache disabled.");
        return;
    }

    if (bUseZombieFactories)
    {
        // ZombieFactory is intentionally tested by name so this class does not
        // need a hard package dependency on the factory implementation.
        foreach AllActors(class'ZombieFactory', ZF)
        {
            if (ZF != None)
			{
				if (!bBotInstantRespawn && ZF.TheCreationPolicy != None && !ZF.TheCreationPolicy.IsA('MultiplayerPolicy'))
				{
					bBotInstantRespawn = true;
				}

				if (BotRouteTargets.Length >= BOT_ROUTE_MAX_TARGETS)
					break;

				TargetNode = FindNearestBotRouteNav(ZF.Location);
				if (TargetNode == None)
					continue;
	 
				BotRouteTargets[BotRouteTargets.Length] = ZF;
				BotRouteTargetNodes[BotRouteTargetNodes.Length] = TargetNode;
			}
        }

		// Some invasion maps may not expose the factory actors at the time InitGame
		// runs. Falling back to PlayerStarts keeps the AI functional rather than
		// disabling veteran wandering entirely.
		if (BotRouteTargets.Length == 0)
		{
			for (N = Level.NavigationPointList; N != None; N = N.NextNavigationPoint)
			{
				if (BotRouteTargets.Length >= BOT_ROUTE_MAX_TARGETS)
					break;

				if (PlayerStart(N) == None || !PlayerStart(N).bEnabled)
					continue;

				BotRouteTargets[BotRouteTargets.Length] = N;
				BotRouteTargetNodes[BotRouteTargetNodes.Length] = N;
			}
		}
    }
    else
    {
        for (N = Level.NavigationPointList; N != None; N = N.NextNavigationPoint)
        {
            if (BotRouteTargets.Length >= BOT_ROUTE_MAX_TARGETS)
                break;

            if (PlayerStart(N) == None)
                continue;

            if (!PlayerStart(N).bEnabled)
                continue;

            BotRouteTargets[BotRouteTargets.Length] = N;
            BotRouteTargetNodes[BotRouteTargetNodes.Length] = N;
        }
    }

    TargetCount = BotRouteTargets.Length;
    if (TargetCount <= 0)
    {
        Log("[VeteranRoute] No route targets found; route cache disabled.");
        return;
    }

    BuildBotRouteDistances();
    BuildBotRouteOrder();

    bBotRouteCacheBuilt = (BotRouteOrder.Length == TargetCount * TargetCount);

    Log("[VeteranRoute] Built shared route cache: " $ TargetCount $
        " targets, " $ NavCount $ " navigation nodes.");
}

function bool GetBotWanderTarget(
    Pawn P,
    int CurrentOriginIndex,
    int CurrentRank,
    out Actor Target,
    out NavigationPoint TargetNode,
    out int NewOriginIndex,
    out int NewRank)
{
    local int TargetCount;
    local int i;
    local int NearestIndex;
    local int CandidateIndex;
    local float NearestDistSq;
    local float DistSq;
    local float CachedDistance;

    Target = None;
    TargetNode = None;
    NewOriginIndex = -1;
    NewRank = 0;

    if (!bBotRouteCacheBuilt || P == None)
        return false;

    TargetCount = BotRouteTargets.Length;
    if (TargetCount <= 0)
        return false;

    // Start a fresh veteran route at the target physically closest to the bot.
    if (CurrentOriginIndex < 0 || CurrentOriginIndex >= TargetCount ||
        CurrentRank <= 0 || CurrentRank >= TargetCount)
    {
        NearestIndex = -1;
        NearestDistSq = BOT_ROUTE_INFINITY;

        for (i = 0; i < TargetCount; i++)
        {
            if (BotRouteTargets[i] == None)
                continue;

            DistSq = (BotRouteTargets[i].Location - P.Location) Dot (BotRouteTargets[i].Location - P.Location);
            if (DistSq < NearestDistSq)
            {
                NearestDistSq = DistSq;
                NearestIndex = i;
            }
        }

        if (NearestIndex < 0)
            return false;

        CurrentOriginIndex = NearestIndex;
        CurrentRank = 1;
    }

    // Walk the precomputed ordering from near to far. Skip disconnected targets.
    while (CurrentRank < TargetCount)
    {
        CandidateIndex = BotRouteOrder[
            CurrentOriginIndex * TargetCount + CurrentRank
        ];

        CachedDistance = BotRouteDistances[
            CurrentOriginIndex * TargetCount + CandidateIndex
        ];

        if (CandidateIndex != CurrentOriginIndex &&
            CachedDistance < BOT_ROUTE_INFINITY &&
            BotRouteTargets[CandidateIndex] != None &&
            BotRouteTargetNodes[CandidateIndex] != None)
        {
            Target = BotRouteTargets[CandidateIndex];
            TargetNode = BotRouteTargetNodes[CandidateIndex];
            NewOriginIndex = CurrentOriginIndex;
            NewRank = CurrentRank + 1;
            return true;
        }

        ++CurrentRank;
    }

    // We exhausted this route. Reinitialize from wherever the bot is now.
    NewOriginIndex = -1;
    NewRank = 0;
    return false;
}

/* Return the 'best' player start for this player to start from.
 */
function NavigationPoint FindBotStart( Controller Player, optional byte InTeam, optional string incomingName )
{
	local NavigationPoint N, BestStart;
	//local Teleporter Tel;
	local float BestRating, NewRating;
	//local byte Team;

	BestRating = -999999.0;

	// always pick StartSpot at start of match
    if ( (Player != None) && (Player.StartSpot != None) && (Level.NetMode == NM_Standalone)
		&& (bKeepSamePlayerStart || bWaitingToStartMatch || ((Player.PlayerReplicationInfo != None) && Player.PlayerReplicationInfo.bWaitingPlayer))  )
	{
		return Player.StartSpot;
	}

	/*if ( GameRulesModifiers != None )
	{
		N = GameRulesModifiers.FindPlayerStart(Player,InTeam,incomingName);
		if ( N != None )
		    return N;
	}

	// if incoming start is specified, then just use it
	if( incomingName!="" )
		foreach AllActors( class 'Teleporter', Tel )
			if( string(Tel.Tag)~=incomingName )
				return Tel;

	// use InTeam if player doesn't have a team yet
	if ( (Player != None) && (Player.PlayerReplicationInfo != None) )
	{
		if ( Player.PlayerReplicationInfo.Team != None )
			Team = Player.PlayerReplicationInfo.Team.TeamIndex;
		else
			Team = 0;
	}
	else
		Team = InTeam;

	for ( N=Level.NavigationPointList; N!=None; N=N.NextNavigationPoint )
	{
		NewRating = RatePlayerStart(N,InTeam,Player);
		if ( NewRating > BestRating )
		{
			BestRating = NewRating;
			BestStart = N;
		}
	}

	if ( BestStart == None )
	{
		log("Warning - PATHS NOT DEFINED or NO PLAYERSTART");
		foreach AllActors( class 'NavigationPoint', N )
		{
			NewRating = RatePlayerStart(N,0,Player);
			if ( NewRating > BestRating )
			{
				BestRating = NewRating;
				BestStart = N;
			}
		}
	}*/

	for ( N=Level.NavigationPointList; N!=None; N=N.NextNavigationPoint )
	{
		NewRating = RatePlayerStart(N,InTeam,Player);
		if ( NewRating > BestRating )
		{
			BestRating = NewRating;
			BestStart = N;
		}
	}

	return BestStart;
}

// Add one or num bots
exec function AddNamedBot(string botname)
{
    if (Level.NetMode != NM_Standalone)
        MinPlayers = Max(MinPlayers + 1, NumPlayers + NumBots + 1);
    AddBot(botName);
}

exec function AddBots(int num)
{
    num = Clamp(num, 0, 6 - (NumPlayers + NumBots));

    while (--num >= 0)
    {
        if ( Level.NetMode != NM_Standalone )
            MinPlayers = Max(MinPlayers + 1, NumPlayers + NumBots + 1);
        AddBot();
    }
}

// Kill all or num bots
exec function KillBots(int num)
{
    local Controller c, nextC;

	bPlayersVsBots = false;

    if (num == 0)
        num = NumBots;

    c = Level.ControllerList;
    if ( Level.NetMode != NM_Standalone )
		MinPlayers = 0;
    bKillBots = true;
    while (c != None && num > 0)
    {
        nextC = c.NextController;
        if (KillBot(c))
            --num;
        c = nextC;
    }
    bKillBots = false;
}

function bool KillBot(Controller c)
{
    local UmodBotController b;

    b = UmodBotController(c);
    if (b != None)
    {
        if (Level.NetMode != NM_Standalone)
            MinPlayers = Max(MinPlayers - 1, NumPlayers + NumBots - 1);

		if ( (Vehicle(b.Pawn) != None) /*&& (Vehicle(b.Pawn).Driver != None)*/ )
            b.Pawn.KilledBy( b.Pawn );
			//Vehicle(b.Pawn).Driver.KilledBy(Vehicle(b.Pawn).Driver);
		else if (b.Pawn != None)
            b.Pawn.KilledBy( b.Pawn );
		if (b != None)
			b.Destroy();
        return true;
    }
    return false;
}

function bool AddBot(optional string botName)
{
    local NavigationPoint StartSpot;
    local AIController NewBot;
    local string InCharacter;
    local string Error, Portal;
    local byte InTeam;
    //local bool bSpectator;
    local UmodBotController NewUmodBot;
    local string NewBotPawnClassName;
    local int BotClassCount;
    local int inIndex;
    local Pawn OldPawn;
    local Pawn NewPawn;

    InTeam = PickTeam(InTeam, None);
    StartSpot = FindPlayerStart(None, InTeam, Portal);

    if (StartSpot == None)
    {
        StartSpot = FindBotStart(None, InTeam, Portal);
    }

    if (StartSpot == None)
    {
        Error = GameMessageClass.Default.FailedPlaceMessage;
        return false;
    }

    if (ModRepo != None && ModRepo.BotControllerClass != None)
        NewBot = Spawn(ModRepo.BotControllerClass,,,StartSpot.Location,StartSpot.Rotation);
    else
        NewBot = Spawn(class'UMODDOTZGame.UmodBotController',,,StartSpot.Location,StartSpot.Rotation);

    if (NewBot != None)
    {
		NewBot.StartSpot = StartSpot;
		NewUmodBot = UmodBotController(NewBot);

		if (NewUmodBot != None)
		{
			NewUmodBot.GameReplicationInfo = GameReplicationInfo;
			NewUmodBot.bCoopGameMode = true;
			NewUmodBot.bBotInstantRespawn = bBotInstantRespawn;
		}

		NewBot.GotoState('Spectating');

		if (ModRepo != None)
		{
			BotClassCount = ModRepo.BotPawnClassNameList.Length;
			if (BotClassCount <= 0)
			{
				NewBotPawnClassName = "UMODDOTZGame.UmodHumanOtis";
			}
			else
			{
				if (inIndex < 0 || inIndex >= BotClassCount)
					inIndex = Rand(BotClassCount);

				NewBotPawnClassName = ModRepo.BotPawnClassNameList[inIndex];
			}
		}

		if (NewBotPawnClassName == "")
			NewBotPawnClassName = "UMODDOTZGame.UmodHumanOtis";

		NewBot.SetPawnClass(NewBotPawnClassName, InCharacter);

		NumPlayers++;
		bWelcomePending = true;

			OldPawn = NewBot.Pawn;
			if (OldPawn != None)
			{
				if (OldPawn.Health > 0)
					return false;

				NewBot.UnPossess();
				if (!OldPawn.bDeleteMe)
					OldPawn.Destroy();
				NewBot.Pawn = None;
			}

			if (NewBot.PawnClass != None)
				NewPawn = Spawn(NewBot.PawnClass,,,StartSpot.Location,StartSpot.Rotation);

			if (NewPawn == None && ModRepo != None && ModRepo.BotPawnClass != None)
				NewPawn = Spawn(ModRepo.BotPawnClass,,,StartSpot.Location,StartSpot.Rotation);

			if (NewPawn == None)
			{
				Log("Couldn't spawn player of type " $ NewBot.PawnClass $ " at " $ StartSpot);
				NewBot.GotoState('Dead');
				return false;
			}

			NewBot.Pawn = NewPawn;
			NewPawn.Anchor = StartSpot;
			NewPawn.LastStartSpot = PlayerStart(StartSpot);
			NewPawn.LastStartTime = Level.TimeSeconds;
			NewBot.PreviousPawnClass = NewPawn.Class;

			NewBot.Possess(NewPawn);
			if (NewBot.Pawn == None)
			{
				if (!NewPawn.bDeleteMe)
					NewPawn.Destroy();
				return false;
			}

			NewBot.PawnClass = NewBot.Pawn.Class;
			NewBot.Pawn.PlayTeleportEffect(true, true);
			NewBot.ClientSetRotation(NewBot.Pawn.Rotation);
			AddDefaultInventory(NewBot.Pawn);
			TriggerEvent(StartSpot.Event, StartSpot, NewBot.Pawn);
		return true;
	}

	Log("Couldn't spawn Bot controller of class " $ ModRepo.BotControllerClass);
	Error = GameMessageClass.Default.FailedSpawnMessage;

    return false;
}

//===========================================================================
// DefaultProperties
//===========================================================================

defaultproperties
{
     PreloadObjects(0)="DOTZEngine.SkelHead"
     PreloadObjects(1)="DOTZMenu.XDOTZSPPause"
     PreloadMesh(0)=StaticMesh'DOTZSSpecial.Particles.Rock'
     PreloadMesh(1)=StaticMesh'DOTZSSpecial.Particles.Barrelpiece'
     PreloadMesh(2)=StaticMesh'DOTZSSpecial.Particles.splash'
     PreloadMesh(3)=StaticMesh'DOTZSSpecial.Particles.Woodshard'
     PreloadMesh(4)=StaticMesh'DOTZSSpecial.Particles.Concrete'
     PreloadMesh(5)=StaticMesh'DOTZSSpecial.Gore.BloodyChunk'
     PreloadMesh(6)=StaticMesh'DOTZSSpecial.GibForearm.GibForearmA'
     PreloadMesh(7)=StaticMesh'DOTZSSpecial.GibForearm.GibForearmB'
     PreloadMesh(8)=StaticMesh'DOTZSSpecial.GibForearm.GibForearmC'
     PreloadMesh(9)=StaticMesh'DOTZSSpecial.GibForearm.GibForearmD'
     PreloadMesh(10)=StaticMesh'DOTZSSpecial.GibUpperArm.UpperArmA'
     PreloadMesh(11)=StaticMesh'DOTZSSpecial.GibUpperArm.UpperArmB'
     PreloadMesh(12)=StaticMesh'DOTZSSpecial.GibUpperArm.UpperArmC'
     PreloadMesh(13)=StaticMesh'DOTZSSpecial.GibUpperArm.UpperArmD'
     PreloadMesh(14)=StaticMesh'DOTZSSpecial.GibUpperArm.UpperArmE'
     PreloadMesh(15)=StaticMesh'DOTZSSpecial.GibLeg.GibLegA'
     PreloadMesh(16)=StaticMesh'DOTZSSpecial.GibLeg.GibLegB'
     PreloadMesh(17)=StaticMesh'DOTZSSpecial.GibLeg.GibLegC'
     PreloadMesh(18)=StaticMesh'DOTZSSpecial.GibLeg.GibLegD'
     PreloadMesh(19)=StaticMesh'DOTZSSpecial.GibLeg.GibLegE'
     PreloadMaterial(0)=Texture'SpecialFX.Blood.BloodGlobs'
     PreloadMaterial(1)=Texture'SpecialFX.Blood.BloodHit'
     PreloadMaterial(2)=Texture'SpecialFX.Blood.BloodSplat'
     PreloadMaterial(3)=Texture'SpecialFX.Blood.Bloodsplatter'
     PreloadMaterial(4)=Texture'SpecialFX.Blood.Bone'
     PreloadMaterial(5)=Texture'SpecialFX.Blood.Muscle'
     PreloadMaterial(6)=Texture'SpecialFX.Coronas.Sunspot'
     PreloadMaterial(7)=Texture'SpecialFX.Fire.Explosion'
     PreloadMaterial(8)=Texture'SpecialFX.Fire.ExplosionFire'
     PreloadMaterial(9)=Texture'SpecialFX.Particles.dust2'
     PreloadMaterial(10)=Texture'SpecialFX.Smoke.smokelight_a'
     PreloadMaterial(11)=Texture'SpecialFX.Smoke.Smoke'
     PreloadMaterial(12)=Texture'SpecialFX.Fire.LargeFlames2'
     DefaultInventory="DOTZWeapons.FistWeapon"

     OverridePlayerControllerClass=Class'UMODDOTZGame.UmodPlayerController'

     OverridePawnClass=Class'UMODDOTZGame.UmodPlayerPawn'

     PickupsQuality=0

}

