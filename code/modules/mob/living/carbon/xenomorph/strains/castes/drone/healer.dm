/datum/xeno_strain/healer
	name = DRONE_HEALER
	description = "You lose your choice of resin secretions, a chunk of your slash damage, and you will experience a slighty-increased difficulty in tackling tallhosts in exchange for strong pheromones, the ability to use a bit of your health to plant a maximum of three lesser resin fruits, and the ability to heal your sisters' wounds by secreting a regenerative resin salve by using your vital fluids and a fifth of your plasma. Be wary, this is a dangerous process; overexert yourself and you may exhaust yourself to unconsciousness, or die..."
	flavor_description = "To the very last drop, your blood belongs to The Hive; share it with your sisters to keep them fighting."
	icon_state_prefix = "Healer"

	actions_to_remove = list(
		/datum/action/ability/activable/xeno/secrete_resin,
		/datum/action/ability/activable/xeno/transfer_plasma/drone,
		/datum/action/ability/activable/xeno/plant_weeds
	)
	actions_to_add = list(
		/datum/action/ability/activable/xeno/plant_weeds, // so it doesn't break order
		/datum/action/ability/xeno_action/sow, // Resin fruits belong to Gardener, but Healer has a minor variant.
		/datum/action/ability/activable/xeno/psychic_cure/healer_acidic_salve, //Third macro, heal over time ability.
		/datum/action/ability/activable/xeno/transfer_plasma/drone/healer, // An improved plasma transfer.
		/datum/action/ability/activable/xeno/healer_sacrifice, //Fifth macro, the ultimate ability to sacrifice yourself
	)

	behavior_delegate_type = /datum/behavior_delegate/drone_healer

/datum/xeno_strain/healer/apply_strain(mob/living/carbon/xenomorph/drone/drone)
	//drone.phero_modifier += XENO_PHERO_MOD_LARGE
	//drone.plasma_types += PLASMA_PHEROMONE
	drone.xeno_caste.melee_damage -= 5

	//drone.max_placeable = 3
	//drone.available_fruits = list(/obj/effect/alien/resin/fruit)
	//drone.selected_fruit = /obj/effect/alien/resin/fruit

/*
	Improved Plasma Transfer
*/

/datum/action/ability/activable/xeno/transfer_plasma/drone/healer //Improved plasma transfer
	plasma_transfer_amount = PLASMA_TRANSFER_AMOUNT * 3

/*
	Apply Resin Salve
*/

/datum/action/ability/activable/xeno/psychic_cure/healer_acidic_salve
	name = "Healer Acidic Salve"
	action_icon_state = "heal_xeno"
	desc = "Apply a minor heal to the target and damage yourself."
	cooldown_duration = 5 SECONDS
	ability_cost = 150
	keybinding_signals = list(
		KEYBINDING_NORMAL = COMSIG_XENOABILITY_ACIDIC_SALVE,
	)
	heal_range = DRONE_HEAL_RANGE
	target_flags = ABILITY_MOB_TARGET

/datum/action/ability/activable/xeno/psychic_cure/healer_acidic_salve/use_ability(atom/target)
	var/mob/living/carbon/xenomorph/X = owner
	if(X.do_actions)
		return FALSE
	if(!do_after(X, 1 SECONDS, NONE, target, BUSY_ICON_FRIENDLY, BUSY_ICON_MEDICAL))
		return FALSE
	X.visible_message(span_xenowarning("\the [X] vomits acid over [target], mending their wounds!"))
	owner.changeNext_move(CLICK_CD_RANGE)
	salve_healing(target)
	succeed_activate()
	add_cooldown()
	if(owner.client)
		var/datum/personal_statistics/personal_statistics = GLOB.personal_statistics_list[owner.ckey]
		personal_statistics.heals++

/// Heals the target and gives them a regenerative buff, if applicable.
/datum/action/ability/activable/xeno/psychic_cure/healer_acidic_salve/proc/salve_healing(
		mob/living/carbon/xenomorph/target,
		heal_multiplier = 1,
		damage_taken_mod = 0.75)

	//Forces an equivalent exchange of health between healers so they do not spam heal each other to full health.
	var/target_is_healer = istype(target.strain, /datum/xeno_strain/healer)
	if(target_is_healer)
		damage_taken_mod = 1

	playsound(target, "alien_drool", 25)
	new /obj/effect/temp_visual/telekinesis(get_turf(target))

	var/heal_amount = (DRONE_BASE_SALVE_HEAL + target.recovery_aura * target.maxHealth * 0.01) * heal_multiplier
	target.adjustFireLoss(-max(0, heal_amount - target.getBruteLoss()), TRUE)
	target.adjustBruteLoss(-heal_amount)
	target.adjust_sunder(-heal_amount/10)

	var/mob/living/carbon/xenomorph/xeno_owner = owner
	xeno_owner.adjustBruteLoss(heal_amount*damage_taken_mod, updating_health = TRUE)

	var/datum/behavior_delegate/drone_healer/healer_delegate = xeno_owner.behavior_delegate
	healer_delegate.salve_applied_recently = TRUE
	if(!target_is_healer) // no cheap grinding
		healer_delegate.modify_transferred(heal_amount * damage_taken_mod)

	if(heal_multiplier > 1) // A signal depends on the above heals, so this has to be done here.
		playsound(target,'sound/effects/magic.ogg', 75, 1)

/datum/behavior_delegate/drone_healer
	name = "Healer Drone Behavior Delegate"

	var/salve_applied_recently = FALSE
	var/mutable_appearance/salve_applied_icon

	var/transferred_amount = 0
	var/required_transferred_amount = 7500

/*
	SACRIFICE
*/

/datum/behavior_delegate/drone_healer/proc/modify_transferred(amount)
	transferred_amount += amount

/datum/behavior_delegate/drone_healer/append_to_stat()
	. = list()
	. += "Transferred health amount: [transferred_amount]/[required_transferred_amount]"
	if(transferred_amount >= required_transferred_amount)
		. += "Sacrifice will grant you new life."

/* TODO:MAKE HUD
/datum/behavior_delegate/drone_healer/on_life()
	if(!bound_xeno)
		return
	if(bound_xeno.stat == DEAD)
		return
	var/image/holder = bound_xeno.hud_list[PLASMA_HUD]
	holder.overlays.Cut()
	var/percentage_transferred = min(round((transferred_amount / required_transferred_amount) * 100, 10), 100)
	if(percentage_transferred)
		holder.overlays += image('icons/mob/hud/hud.dmi', "xenoenergy[percentage_transferred]")
*/
/datum/behavior_delegate/drone_healer/handle_death(mob/M)
	var/image/holder = bound_xeno.hud_list[PLASMA_HUD]
	holder.overlays.Cut()


/datum/action/ability/activable/xeno/healer_sacrifice
	name = "Sacrifice"
	action_icon_state = "screech"
	desc = "Sacrifice yourself for the Hive!"
	cooldown_duration = 5 SECONDS
	ability_cost = 150
	keybinding_signals = list(
		KEYBINDING_NORMAL = COMSIG_XENOABILITY_SACRIFICE,
	)
	var/max_range = 1
	var/transfer_mod = 0.75 // only transfers 75% of current healer's health

/datum/action/ability/activable/xeno/healer_sacrifice/can_use_ability(atom/A, silent, override_flags)
	. = ..()
	var/mob/living/carbon/xenomorph/xeno = owner
	var/mob/living/carbon/xenomorph/target = A

	if(!istype(target))
		return FALSE

	if(target == xeno)
		to_chat(xeno, "We can't heal ourself!")
		return FALSE

	//if(isfacehugger(target) || islesserdrone(target))
	//	to_chat(xeno, "It would be a waste...")
	//	return

	if(!xeno.check_state())
		return FALSE

	if(!check_distance(target))
		return FALSE

	if(!isxeno(target))
		return FALSE

	if(target.stat == DEAD)
		to_chat(xeno, span_xenowarning("[target] is already dead!"))
		return FALSE

	if(target.health >= target.maxHealth)
		to_chat(xeno, span_xenowarning("[target] is already at max health!"))
		return FALSE

	if(!isturf(xeno.loc))
		to_chat(xeno, span_xenowarning("We cannot transfer health from here!"))
		return FALSE

	return TRUE

/datum/action/ability/activable/xeno/healer_sacrifice/use_ability(atom/atom)
	if(!can_use_ability(atom, FALSE))
		return
	var/mob/living/carbon/xenomorph/xeno = owner
	var/mob/living/carbon/xenomorph/target = atom

	xeno.say(";MY LIFE FOR THE QUEEN!!!")

	target.adjustBruteLoss(-xeno.health * transfer_mod)
	target.do_jitter_animation(1000)
	target.visible_message(span_xenonotice("[xeno] explodes in a deluge of regenerative resin salve, covering [target] in it!"))
	xeno_message(span_xenoannounce("[xeno] sacrifices itself to heal [target]!"), 2, target.hive.hivenumber)

	var/datum/behavior_delegate/drone_healer/behavior_delegate = xeno.behavior_delegate
	var/should_be_respawned = istype(behavior_delegate) && behavior_delegate.transferred_amount >= behavior_delegate.required_transferred_amount && xeno.client && xeno.hive
	if(should_be_respawned)
		var/datum/hive_status/hive_status = xeno.hive
		var/turf/spawning_turf = get_turf(xeno)
		var/client/client = xeno.client
		xeno.death(FALSE)
		if(!GLOB.xeno_resin_silos_by_hive[xeno.hive.hivenumber])
			hive_status.do_spawn_larva(client, spawning_turf, TRUE)
		else
			hive_status.do_spawn_larva(client, pick(GLOB.spawns_by_job[/datum/job/xenomorph]), TRUE)
	else
		xeno.death(TRUE)

/datum/action/ability/activable/xeno/healer_sacrifice/proc/check_distance(atom/target)
	var/dist = get_dist(owner, target)
	if(dist > max_range)
		to_chat(owner, span_warning("Too far for our reach... We need to be [dist - max_range] steps closer!"))
		return FALSE
	else if(!line_of_sight(owner, target))
		to_chat(owner, span_warning("We can't focus properly without a clear line of sight!"))
		return FALSE
	return TRUE


/datum/action/ability/activable/xeno/healer_sacrifice/action_activate()
	..()
	var/mob/living/carbon/xenomorph/xeno = owner
	if(xeno.selected_ability != src)
		return
	var/datum/behavior_delegate/drone_healer/behavior_delegate = xeno.behavior_delegate
	if(!istype(behavior_delegate))
		return
	if(behavior_delegate.transferred_amount < behavior_delegate.required_transferred_amount)
		to_chat(xeno, span_xenohighdanger("Warning: [name] is a last measure skill. Using it will kill us."))
	else
		to_chat(xeno, span_xenohighdanger("Warning: [name] is a last measure skill. Using it will kill us, but new life will be granted for our hard work for the hive."))
