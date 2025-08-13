HOOKED_TAGS <- {};

local AVAILABLE_HOOKS =
[
	"OnSpawn",
	"OnTakeDamage",
	"OnDealDamage",
	"OnTakeDamagePost",
	"OnDealDamagePost",
	"OnDeath",
	"OnKill"
];

/**
 * Register a bot tag with game event hooks that fire on the bot.
 * Signatures of the hooks must match `HookName( handle bot, table params )`
 * except for OnSpawn, where the signature is `OnSpawn( handle bot )`
 * (you do not need to name them `bot` and `params` but it is recommended),
 * while `HookName` must match one of the following:
 *
 *   HookName           Game event     `handle` is...
 *   OnSpawn          | player_spawn | GetPlayerFromUserID( params.userid )
 *   OnTakeDamage     | OnTakeDamage | params.const_entity
 *   OnDealDamage     | OnTakeDamage | params.attacker
 *   OnTakeDamagePost | player_hurt  | GetPlayerFromUserID( params.userid )
 *   OnDealDamagePost | player_hurt  | GetPlayerFromUserID( params.attacker )
 *   OnDeath          | player_death | GetPlayerFromUserID( params.userid )
 *   OnKill           | player_death | GetPlayerFromUserID( params.attacker )
 *
 * Look at the Discord thread for an example usage.
 *
 * Tip:
 *   You can access the bot handle in the hooks via the `handle` argument,
 *   which is guaranteed to be non-null.
 * Warning:
 *   The OnSpawn hook is the only hook in which you cannot access the event params table.
 *   Workaround:
 *     `params.team` can be grabbed by GetTeam() and `params.class` can be grabbed by GetPlayerClass().
 * Warning:
 *   The hooks are fired otherwise completely the same as normal game events. This means
 *   that you still need to be aware of certain shortcomings such as params.inflictor possibly
 *   being null in the OnTakeDamage script hook.
 *   Tip:
 *     The only exception is the OnSpawn hook, because it is executed at the end of the frame.
 *     Many scripts that need to be otherwise delayed do not have to be in this hook, such as
 *     adding attributes via AddCustomAttribute().
 */
function AddHookedTag( tag, hooks )
{
	foreach ( hook_name, _ in hooks )
	{
		if ( AVAILABLE_HOOKS.find( hook_name ) == null )
			throw "hooked_tags.nut: invalid hook name";
	}
	HOOKED_TAGS[ tag ] <- hooks;
}

// Checks for tags and applies to scope, also runs the OnSpawn hook
// For internal use
function __TAGS_SpawnInit()
{
	foreach ( tag, hooks in HOOKED_TAGS )
	{
		if ( !self.HasBotTag( tag ) )
			continue;

		foreach ( hook_name, func in hooks )
		{
			hook_table[ hook_name ].append( func );
		}
	}

	foreach ( func in hook_table.OnSpawn )
		func( self );
}

// Fires hooks on a player if it exists in scope, except for the OnSpawn hook
// For internal use
function __TAGS_FireHooks( player, hook_name, params )
{
	foreach ( func in player.GetScriptScope().hook_table[ hook_name ] )
		func( player, params );
}

// Clears up each array in scope.hook_table
// For internal use
function __TAGS_ClearHookArrays( player )
{
	foreach ( hook_name, _ in player.GetScriptScope().hook_table )
		hook_name.clear();
}

CALLBACKS_HOOKED_TAGS <-
{
	function OnGameEvent_player_spawn( params )
	{
		local player = GetPlayerFromUserID( params.userid );
		if ( !player.IsBotOfType( 1337 ) )
			return;

		EntFireByHandle( player, "CallScriptFunction", "__TAGS_SpawnInit", -1.0, null, null );
	}

	function OnScriptHook_OnTakeDamage( params )
	{
		local victim = params.const_entity;
		if ( victim.IsPlayer() && victim.IsBotOfType( 1337 ) )
			__TAGS_FireHooks( victim, "OnTakeDamage", params );

		local attacker = params.attacker;
		if ( attacker && attacker.IsPlayer() && attacker.IsBotOfType( 1337 ) )
			__TAGS_FireHooks( attacker, "OnDealDamage", params );
	}

	function OnGameEvent_player_hurt( params )
	{
		local victim = GetPlayerFromUserID( params.userid );
		if ( victim && victim.IsBotOfType( 1337 ) )
			__TAGS_FireHooks( victim, "OnTakeDamagePost", params );

		local attacker = GetPlayerFromUserID( params.attacker );
		if ( attacker && attacker.IsBotOfType( 1337 ) )
			__TAGS_FireHooks( attacker, "OnDealDamagePost", params );
	}

	function OnGameEvent_player_death( params )
	{
		local casualty = GetPlayerFromUserID( params.userid );
		if ( casualty && casualty.IsBotOfType( 1337 ) )
		{
			__TAGS_FireHooks( casualty, "OnDeath", params );
			__TAGS_ClearHookArrays( casualty );
		}

		local attacker = GetPlayerFromUserID( params.attacker );
		if ( attacker && attacker.IsBotOfType( 1337 ) )
			__TAGS_FireHooks( attacker, "OnKill", params );
	}

	// cleanup
	function OnGameEvent_recalculate_holidays( _ )
	{
		if ( GetRoundState() != 3 )
			return;

		for ( local i = MaxClients().tointeger(); i > 0; i-- )
		{
			local player = PlayerInstanceFromIndex( i );
			if ( !player || !player.IsBotOfType( 1337 ) )
				continue;

			// not terminating script scope here, as this may clash with other scripts
			delete player.GetScriptScope().hook_table;
		}

		local __root = getroottable();
		local keys_to_cleanup =
		[
			"HOOKED_TAGS",
			"AddHookedTag",
			"__TAGS_SpawnInit",
			"__TAGS_FireHooks",
			"__TAGS_ClearHookArrays",
			"CALLBACKS_HOOKED_TAGS" // keep this at the end
		];
		foreach ( key in keys_to_cleanup )
		{
			delete __root[ key ];
		}
	}
};

for ( local i = MaxClients().tointeger(); i > 0; i-- )
{
	local player = PlayerInstanceFromIndex( i );
	if ( !player || !player.IsBotOfType( 1337 ) )
		continue;

	player.ValidateScriptScope();
	player.GetScriptScope().hook_table <-
	{
		OnSpawn          = [],
		OnTakeDamage     = [],
		OnDealDamage     = [],
		OnTakeDamagePost = [],
		OnDealDamagePost = [],
		OnDeath          = [],
		OnKill           = []
	};
}

__CollectGameEventCallbacks( CALLBACKS_HOOKED_TAGS );
