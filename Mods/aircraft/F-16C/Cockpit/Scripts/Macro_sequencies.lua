dofile(LockOn_Options.script_path.."command_defs.lua")
dofile(LockOn_Options.script_path.."devices.lua")
-- timeouts and delays
std_message_timeout = 15

local	t_start	= 0.0
local	t_stop	= 0.0
local	dt		= 0.1
local	dt_mto	= 0.5
local	start_sequence_time	= 138.0
local	stop_sequence_time	= 60.0

--
start_sequence_full 	  = {}
stop_sequence_full		  = {}
cockpit_illumination_full = {}

function push_command(sequence, run_t, command)
    sequence[#sequence + 1] =  command
    sequence[#sequence]["time"] = run_t
end

function push_start_command(delta_t, command)
    t_start = t_start + delta_t
    push_command(start_sequence_full,t_start, command)
end
                
function push_stop_command(delta_t, command)
    t_stop = t_stop + delta_t
    push_command(stop_sequence_full,t_stop, command)
end

local function push_start_depress(delta_t, device, command, value_down)
    push_start_command(delta_t, {device=device, action=command, value=value_down})
    push_start_command(delta_t, {device=device, action=command, value=0.0})
end

local function push_ufc_depress(command, value_down)
    push_start_depress(dt, devices.UFC, command, value_down)
end

local text_to_ufc_map = {
    ["0"] = ufc_commands.DIG0_M_SEL,
    ["1"] = ufc_commands.DIG1_T_ILS,
    ["2"] = ufc_commands.DIG2_ALOW,
    ["3"] = ufc_commands.DIG3,
    ["4"] = ufc_commands.DIG4_STPT,
    ["5"] = ufc_commands.DIG5_CRUS,
    ["6"] = ufc_commands.DIG6_T_ILS,
    ["7"] = ufc_commands.DIG7_MARK,
    ["8"] = ufc_commands.DIG8_FIX,
    ["9"] = ufc_commands.DIG9_A_CAL
}

local function push_ufc_text(text, should_press_enter)
    for i = 1, #text do
        local char = text:sub(i,i)
        local command = text_to_ufc_map[char]
        push_ufc_depress(command, 1.0)
    end
    if (should_press_enter) then
        push_ufc_depress(ufc_commands.ENTR, 1.0)
    end
end

local function push_ufc_sequence(cmds)
    for _, cmd in ipairs(cmds) do
        if type(cmd[1]) == 'string' then
            local s = cmd[1]
            local should_press_enter = cmd[2]
            push_ufc_text(s, should_press_enter)
        else
            local action = cmd[1]
            local value = cmd[2]
            push_ufc_depress(action, value)
        end
    end
end

local OSB_PAGE_MAP = {
    BLANK = mfd_commands.OSB_1,
    HAD   = mfd_commands.OSB_2,
    RCCE  = mfd_commands.OSB_4,
    SMS   = mfd_commands.OSB_6,
    HSD   = mfd_commands.OSB_7,
    DTE   = mfd_commands.OSB_8,
    TEST  = mfd_commands.OSB_9,
    FLCS  = mfd_commands.OSB_10,
    FLIR  = mfd_commands.OSB_16,
    TFR   = mfd_commands.OSB_17,
    WPN   = mfd_commands.OSB_18,
    TGP   = mfd_commands.OSB_19,
    FCR   = mfd_commands.OSB_20
}

local OSB_ID_MAP = {
    [1] = mfd_commands.OSB_1,
    [2] = mfd_commands.OSB_2,
    [3] = mfd_commands.OSB_3,
    [4] = mfd_commands.OSB_4,
    [5] = mfd_commands.OSB_5,
    [6] = mfd_commands.OSB_6,
    [7] = mfd_commands.OSB_7,
    [8] = mfd_commands.OSB_8,
    [9] = mfd_commands.OSB_9,
    [10] = mfd_commands.OSB_10,
    [11] = mfd_commands.OSB_11,
    [12] = mfd_commands.OSB_12,
    [13] = mfd_commands.OSB_13,
    [14] = mfd_commands.OSB_14,
    [15] = mfd_commands.OSB_15,
    [16] = mfd_commands.OSB_16,
    [17] = mfd_commands.OSB_17,
    [18] = mfd_commands.OSB_18,
    [19] = mfd_commands.OSB_19,
    [20] = mfd_commands.OSB_20
}

local mfd_cfg_nav = {
    {"FCR", "TEST", "DTE"}, {"HSD", "TGP", "SMS"}
}

local mfd_cfg_aa = {
    {"FCR", "TEST", "DTE"}, {"HSD", "TGP", "SMS"}
}

local mfd_cfg_dogfight = {
    {"FCR", "TEST", "DTE"}, {"HSD", "TGP", "SMS"}
}

local mfd_cfg_mrm = {
    {"FCR", "TEST", "DTE"}, {"HSD", "TGP", "SMS"}
}

local mfd_cfg_ag = {
    {"FCR", "WPN", "TGP"}, {"HSD", "HAD", "SMS"}
}


local dt_mfd = .05
local function start_dgft_mode()
    push_start_command(dt_mfd, {device=devices.HOTAS, action=hotas_commands.THROTTLE_DOG_FIGHT, value=1.0})
end

local function start_mrm_mode()
    push_start_command(dt_mfd, {device=devices.HOTAS, action=hotas_commands.THROTTLE_DOG_FIGHT, value=-1.0})
end

local function end_dgft_mode()
    push_start_command(dt_mfd, {device=devices.HOTAS, action=hotas_commands.THROTTLE_DOG_FIGHT, value=0.0})
end


local function run_osb_sequence(mfd_device, osb_seq)
    for _, cmd_id in ipairs(osb_seq) do
        local osb_cmd = OSB_ID_MAP[cmd_id]
        push_start_depress(dt_mfd, mfd_device, osb_cmd, 1.0)
    end
end

local function blank_all_mfds_on_side(mfd_device)
    run_osb_sequence(mfd_device, {14, 1, 13, 13, 1, 12, 12, 1})
end

local function blank_all_mfds()
    -- iterate through all bottom OSBs on L and R mfds and set them to blank.
    -- PRECONDITIOIN: the first OSB on each MFD is already selected, so you need to only hit that OSB once.
    -- the other OSBs must be double-pressed (first to select, then to bring up menu) before hitting OSB1.
    blank_all_mfds_on_side(devices.MFD_LEFT)
    blank_all_mfds_on_side(devices.MFD_RIGHT)
end


local function setup_mfds_current_mode(mfd_sequence, mode_name)
    push_start_command(dt, {message="Setting up MFDs for " .. mode_name, message_timeout=3.5})
    blank_all_mfds()
    local l = mfd_sequence[1]
    local r = mfd_sequence[2]
    local bottom_osbs_order = {mfd_commands.OSB_14, mfd_commands.OSB_13, mfd_commands.OSB_12}
    for idx, page in ipairs(l) do
        local cmd = OSB_PAGE_MAP[page]
        -- push the menu OSB twice to select the menu
        push_start_depress(dt_mfd, devices.MFD_LEFT, bottom_osbs_order[idx], 1.0)
        push_start_depress(dt_mfd, devices.MFD_LEFT, bottom_osbs_order[idx], 1.0)
        push_start_depress(dt_mfd, devices.MFD_LEFT, cmd, 1.0)
    end
    for idx, page in ipairs(r) do
        local cmd = OSB_PAGE_MAP[page]
        -- push the menu OSB twice to select the menu
        push_start_depress(dt_mfd, devices.MFD_RIGHT, bottom_osbs_order[idx], 1.0)
        push_start_depress(dt_mfd, devices.MFD_RIGHT, bottom_osbs_order[idx], 1.0)
        push_start_depress(dt_mfd, devices.MFD_RIGHT, cmd, 1.0)
    end
    run_osb_sequence(devices.MFD_LEFT, {14})
    run_osb_sequence(devices.MFD_RIGHT, {14})
end

local function setup_mfds()
    -- first do nav mode since we're in nav
    setup_mfds_current_mode(mfd_cfg_nav, 'NAV')
    push_ufc_depress(ufc_commands.AA, 1.0)
    setup_mfds_current_mode(mfd_cfg_aa, 'A/A')
    -- depress AA mode again to go back to nav
    push_ufc_depress(ufc_commands.AA, 1.0)
    -- now do AG mode
    push_ufc_depress(ufc_commands.AG, 1.0)
    setup_mfds_current_mode(mfd_cfg_ag, 'A/G')
    -- depress AG mode again to go back to nav
    push_ufc_depress(ufc_commands.AG, 1.0)
    -- now dogfight mode
    start_dgft_mode()
    setup_mfds_current_mode(mfd_cfg_dogfight, 'DOGFIGHT override')
    end_dgft_mode()
    -- now MRM mode
    start_mrm_mode()
    setup_mfds_current_mode(mfd_cfg_mrm, 'MRM override')
    end_dgft_mode()
end

--
local count = 0
local function counter()
    count = count + 1
    return count
end

-- conditions
count = -1

F16_AD_NO_FAILURE				= counter()
F16_AD_ERROR					= counter()

F16_AD_THROTTLE_SET_TO_OFF		= counter()
F16_AD_THROTTLE_AT_OFF			= counter()
F16_AD_THROTTLE_SET_TO_IDLE		= counter()
F16_AD_THROTTLE_AT_IDLE			= counter()
F16_AD_THROTTLE_DOWN_TO_IDLE	= counter()

F16_AD_JFS_READY				= counter()
F16_AD_ENG_IDLE_RPM				= counter()
F16_AD_ENG_CHECK_IDLE			= counter()
F16_AD_JFS_VERIFY_OFF			= counter()

F16_AD_INS_CHECK_RDY			= counter()

F16_AD_LEFT_HDPT_CHECK_RDY		= counter()
F16_AD_RIGHT_HDPT_CHECK_RDY 	= counter()

F16_AD_HMCS_ALIGN				= counter()


--
alert_messages = {}

alert_messages[F16_AD_ERROR]					= { message = _("FM MODEL ERROR"),							message_timeout = std_message_timeout}

alert_messages[F16_AD_THROTTLE_SET_TO_OFF]		= { message = _("THROTTLE - TO OFF"),						message_timeout = std_message_timeout}
alert_messages[F16_AD_THROTTLE_AT_OFF]			= { message = _("THROTTLE MUST BE AT OFF"),					message_timeout = std_message_timeout}
alert_messages[F16_AD_THROTTLE_SET_TO_IDLE]		= { message = _("THROTTLE - TO IDLE"),						message_timeout = std_message_timeout}
alert_messages[F16_AD_THROTTLE_AT_IDLE]			= { message = _("THROTTLE MUST BE AT IDLE"),				message_timeout = std_message_timeout}
alert_messages[F16_AD_THROTTLE_DOWN_TO_IDLE]	= { message = _("THROTTLE - TO IDLE"),						message_timeout = std_message_timeout}

alert_messages[F16_AD_JFS_READY]				= { message = _("JFS RUN LIGHT MUST BE ON WITHIN 30 SEC"),	message_timeout = std_message_timeout}
alert_messages[F16_AD_ENG_IDLE_RPM]				= { message = _("ENGINE RPM FAILURE"),						message_timeout = std_message_timeout}
alert_messages[F16_AD_ENG_CHECK_IDLE]			= { message = _("ENGINE PARAMETERS FAILURE"),				message_timeout = std_message_timeout}
alert_messages[F16_AD_JFS_VERIFY_OFF]			= { message = _("JFS MUST BE OFF"),							message_timeout = std_message_timeout}

alert_messages[F16_AD_INS_CHECK_RDY]			= { message = _("INS NOT READY"),							message_timeout = std_message_timeout}

alert_messages[F16_AD_LEFT_HDPT_CHECK_RDY]		= { message = "",											message_timeout = std_message_timeout}
alert_messages[F16_AD_RIGHT_HDPT_CHECK_RDY]		= { message = "",											message_timeout = std_message_timeout}



----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
-- Start sequence
push_start_command(2.0,	{message = _("AUTOSTART SEQUENCE IS RUNNING"), message_timeout = start_sequence_time})

push_start_command(dt,		{device = devices.ENGINE_INTERFACE,		action = engine_commands.JfsSwStart2,			value = 0.0})

push_start_command(dt,		{message = _("- MAIN PWR SWITCH - BATT"),												message_timeout = dt_mto})
push_start_command(dt,		{device = devices.ELEC_INTERFACE,		action = elec_commands.MainPwrSw,				value = 0.0})
push_start_command(dt,		{message = _("- MAIN PWR SWITCH - MAIN PWR"),											message_timeout = dt_mto})
push_start_command(dt,		{device = devices.ELEC_INTERFACE,		action = elec_commands.MainPwrSw,				value = 1.0})
-- Starting Engine
push_start_command(dt,		{message = _("- JFS SWITCH - START 2"),													message_timeout = 1.0})
push_start_command(1.0,     {device = devices.ENGINE_INTERFACE,		action = engine_commands.JfsSwStart2,			value = -1.0})
push_start_command(1.0,     {device = devices.ENGINE_INTERFACE,		action = engine_commands.JfsSwStart2,			value = 0.0})

local t_jfs_started = t_start
push_start_command(dt,		{message = _("- CANOPY - CLOSE AND LOCK"),												message_timeout = 10.0})
push_start_command(dt,		{device = devices.CPT_MECH,		action = cpt_commands.CanopyHandle,						value = 0.0})
push_start_command(dt,		{device = devices.CPT_MECH,		action = cpt_commands.CanopySwitchClose,				value = -1.0})
push_start_command(8.0,		{device = devices.CPT_MECH,		action = cpt_commands.CanopySwitchClose,				value = 0.0})
push_start_command(1.0,		{device = devices.CPT_MECH,		action = cpt_commands.CanopyHandle,						value = 1.0})
push_start_command(dt,		{device = devices.SMS,					action = sms_commands.LeftHDPT,					value = 1.0}) -- used only for TGP and HTS
push_start_command(dt,		{device = devices.SMS,					action = sms_commands.RightHDPT,				value = 1.0}) -- used only for TGP and HTS

push_start_command(dt,		{message = _("- AVIONICS POWER PANEL - SET"),											message_timeout = 2.0})
push_start_command(dt,		{device = devices.MMC,					action = ecs_commands.AirSourceKnob,			value = 1.0})
push_start_command(dt,		{device = devices.SMS,					action = sms_commands.StStaSw,					value = 1.0})
push_start_command(dt,		{device = devices.MMC,					action = mmc_commands.MFD,						value = 1.0})
push_start_command(dt,		{device = devices.UFC,					action = ufc_commands.UFC_Sw,					value = 1.0})
push_start_command(dt,		{device = devices.GPS,					action = gps_commands.PwrSw,					value = 1.0})
push_start_command(dt,		{device = devices.IDM,					action = idm_commands.PwrSw,					value = 1.0})
push_start_command(dt,  	{device = devices.MIDS,					action = mids_commands.PwrSw,					value = 0.2})
push_start_command(dt,		{device = devices.INS,					action = ins_commands.ModeKnob,					value = 0.1})
push_start_command(dt,		{device = devices.RALT,					action = ralt_commands.PwrSw,					value = 1.0})
push_start_command(dt,		{device = devices.RALT,					action = ralt_commands.PwrSw,					value = 1.0})
push_start_command(dt,		{device = devices.FCR,					action = fcr_commands.PwrSw,					value = 1.0})
push_start_command(dt,		{message = _("- UHF RADIO BACKUP CONTROL PANEL: FUNCTION KNOB - BOTH"),					message_timeout = dt_mto})
push_start_command(dt,		{device = devices.UHF_CONTROL_PANEL,	action = uhf_commands.FunctionKnob,				value = 0.2})

push_start_command(dt,		{message = _("- HMCS SYMBOLOGY INT POWER KNOB - INT"),									message_timeout = dt_mto})
push_start_command(dt,		{device = devices.HMCS,					action = hmcs_commands.IntKnob,					value = 0.8})
-- AntiSkidSw set to parking brake on (1.0) ASAP.
push_start_depress(dt, devices.GEAR_INTERFACE, gear_commands.ParkingSw, 1.0)

local t_wait_jfs = 17.0 - (t_start - t_jfs_started)

push_start_command(t_wait_jfs,{message = _("- JFS RUN LIGHT - CHECK"),				check_condition = F16_AD_JFS_READY,				message_timeout = dt_mto})
push_start_command(1.0,		{message = _("- THROTTLE - IDLE (20% RPM MINIMUM)"),													message_timeout = 35.0})
for i = 0, 15, 1 do
    push_start_command(1.0,		{													check_condition = F16_AD_THROTTLE_SET_TO_IDLE,	message_timeout = 0.0})
end
local t_engine_pwr_avail = t_start
push_start_command(dt,		{														check_condition = F16_AD_THROTTLE_AT_IDLE,		message_timeout = dt_mto})
push_start_command(20.0,	{message = _("- JFS SWITCH - CONFIRM OFF"),				check_condition = F16_AD_JFS_VERIFY_OFF,		message_timeout = 5.0})
push_start_command(5.0,		{message = _("- ENGINE WARNING LIGHT - CONFIRM OFF"),	check_condition = F16_AD_ENG_IDLE_RPM,			message_timeout = 5.0})
push_start_command(5.0,		{message = _("- ENGINE AT IDLE - CHECK"),				check_condition = F16_AD_ENG_CHECK_IDLE,		message_timeout = dt_mto})

-- After Engine Start
-- push_start_command(dt,		{device = devices.MAP,					action = map_commands.PwrSw,					value = 1.0}) -- not used
push_start_command(dt,		{message = _("- INS - ALIGN"),															message_timeout = 5.0})
push_start_command(dt,		{message = _("- SNSR PWR PANEL - SET"),													message_timeout = dt_mto})


push_start_command(dt,      {message = " -Exterior lights",                                                         message_timeout =3.0})
push_start_command(dt,      {device = devices.EXTLIGHTS_SYSTEM,     action = extlights_commands.PosWingTail,        value = 1.0})
push_start_command(dt,      {device = devices.EXTLIGHTS_SYSTEM,     action = extlights_commands.PosFus,             value = 1.0})

push_start_command(dt,		{														check_condition = F16_AD_LEFT_HDPT_CHECK_RDY,		message_timeout = dt_mto})
push_start_command(dt,		{														check_condition = F16_AD_RIGHT_HDPT_CHECK_RDY,		message_timeout = dt_mto})
push_start_command(dt,		{message = _("- HUD"),																	message_timeout = dt_mto})
push_start_command(dt,		{device = devices.UFC,					action = ufc_commands.SYM_Knob,					value = 0.8})
push_start_command(dt,		{message = _("- C&I KNOB - UFC"),														message_timeout = dt_mto})
push_start_command(dt,		{device = devices.IFF_CONTROL_PANEL,	action = iff_commands.CNI_Knob,					value = 1.0})
push_start_command(dt,		{message = _("- IFF MASTER KNOB - NORM"),												message_timeout = dt_mto})
push_start_command(dt,		{device = devices.IFF_CONTROL_PANEL,	action = iff_commands.MasterKnob,				value = 0.3})

push_start_command(dt,		{message = _("- SAI - SET"),															message_timeout = dt_mto})
push_start_command(dt,		{device = devices.SAI,					action = sai_commands.reference,				value = 0.5})

--HMCS Align
push_start_command(dt,		{message = _("- HMCS - ALIGN"),															message_timeout = 1 + dt_mto})
push_start_command(1.0,		{device = devices.hmcs_commands,		check_condition = F16_AD_HMCS_ALIGN})
-- INS Knob - NAV (not switched automatically)

-- RWR and THREAT WARNING AUX panels
push_start_command(dt,      {message = "- RWR and countermeasures -",                                              message_timeout = 1 + dt_mto})
push_start_command(dt,      {device=devices.RWR,  action=rwr_commands.Power,   value=1.0})
push_start_command(dt,      {device=devices.CMDS, action=cmds_commands.RwrSrc, value=1.0})
push_start_command(dt,      {device=devices.CMDS, action=cmds_commands.JmrSrc, value=1.0})
push_start_command(dt,      {device=devices.CMDS, action=cmds_commands.MwsSrc, value=1.0})
push_start_command(dt,      {device=devices.CMDS, action=cmds_commands.O1Exp,  value=1.0})
push_start_command(dt,      {device=devices.CMDS, action=cmds_commands.O2Exp,  value=1.0})
push_start_command(dt,      {device=devices.CMDS, action=cmds_commands.ChExp,  value=1.0})
push_start_command(dt,      {device=devices.CMDS, action=cmds_commands.FlExp,  value=1.0})
push_start_command(dt,      {device=devices.CMDS, action=cmds_commands.Prgm,   value=0.1})
push_start_command(dt,      {device=devices.CMDS, action=cmds_commands.Mode,   value=0.2})

-- MFD setup
push_start_command(dt,		{message = _("- MFD setup "),															message_timeout = 1 + dt_mto})

push_start_depress(dt, devices.MFD_RIGHT, mfd_commands.OSB_6,   1.0)


push_start_command(dt,		{message = _("- DED setup "),															message_timeout = 1 + dt_mto})
push_ufc_sequence({
    -- turn on bullseye
    {ufc_commands.DCS_RTN,       -1.0},
    {ufc_commands.LIST,           1.0},
    {ufc_commands.DIG0_M_SEL,     1.0},
    {ufc_commands.DIG8_FIX,       1.0},
    {ufc_commands.DIG0_M_SEL,     1.0},
    {ufc_commands.DCS_RTN,       -1.0}
})

push_ufc_sequence({
    -- turn on TACAN A/A
    {ufc_commands.DCS_RTN,       -1.0},
    {ufc_commands.DCS_RTN,       -1.0},
    {ufc_commands.DIG1_T_ILS,     1.0},
    {ufc_commands.DCS_SEQ,        1.0},
    {ufc_commands.DCS_SEQ,        1.0},
    {ufc_commands.DCS_DOWN,      -1.0},
    {"69",                       true},
    {ufc_commands.DCS_RTN,       -1.0}
})

push_ufc_sequence({
    -- switch to radio presets
    {ufc_commands.COM1,           1.0},
    {ufc_commands.DIG1_T_ILS,     1.0},
    {ufc_commands.ENTR,           1.0},
    {ufc_commands.COM2,           1.0},
    {ufc_commands.DIG1_T_ILS,     1.0},
    {ufc_commands.ENTR,           1.0},
    -- back to INS
    {ufc_commands.LIST,           1.0},
    {ufc_commands.DIG6_TIME,      1.0}
})

-- IMPORTANT, must set the right MFD to OSB 14 in nav mode before setting up MFD pages
push_start_depress(dt, devices.MFD_RIGHT, mfd_commands.OSB_14,   1.0)

setup_mfds()

push_start_command(dt,      {message = _("- MFD setup - complete."),                                                message_timeout = dt_mto})

-- Taxi
-- Before Takeoff
push_start_command(dt,		{message = _("- EJECTION SAFETY LEVER - ARM (DOWN)"),									message_timeout = dt_mto})
push_start_command(dt,		{device = devices.CPT_MECH,				action = cpt_commands.EjectionSafetyLever,		value = 1.0})
push_start_command(38.0,    {message = _("- WAITING FOR INS ALIGN"),												message_timeout = 20.0})
push_start_command(3.0,     {message = _("- CHECK INS ALIGNMENT - READY"),  check_condition = F16_AD_INS_CHECK_RDY, message_timeout = 5.0})

push_start_command(dt,		{message = _("- INS KNOB - NAV"),														message_timeout = dt_mto})
push_start_command(dt,		{device = devices.INS,					action = ins_commands.ModeKnob,					value = 0.3})

push_start_depress(dt, devices.UFC,ufc_commands.DCS_RTN, -1.0)
--
push_start_command(3.0,	{message = _("AUTOSTART COMPLETE"),message_timeout = std_message_timeout})
--


----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
-- Stop sequence
push_stop_command(2.0,	{message = _("AUTOSTOP SEQUENCE IS RUNNING"),	message_timeout = stop_sequence_time})
--

-- After Landing
push_stop_command(dt,		{message = _("- PROBE HEAT SWITCH - OFF"),												message_timeout = dt_mto})
push_stop_command(dt,		{device = devices.ELEC_INTERFACE,		action = elec_commands.ProbeHeatSw,				value = 0.0})
-- ECM POWER - OFF
push_stop_command(dt,		{message = _("- SPEEDBRAKES - CLOSE"),													message_timeout = dt_mto})
push_stop_command(dt,		{device = devices.HOTAS,				action = hotas_commands.THROTTLE_SPEED_BRAKE,	value = 1.0})
push_stop_command(1.5,		{device = devices.HOTAS,				action = hotas_commands.THROTTLE_SPEED_BRAKE,	value = 0.0})
push_stop_command(dt,		{message = _("- EJECTION SAFETY LEVER - SAFE (UP)"),									message_timeout = dt_mto})
push_stop_command(dt,		{device = devices.CPT_MECH,				action = cpt_commands.EjectionSafetyLever,		value = 0.0})
push_stop_command(dt,		{message = _("- IFF MASTER KNOB - STBY"),												message_timeout = dt_mto})
push_stop_command(dt,		{device = devices.IFF_CONTROL_PANEL,	action = iff_commands.MasterKnob,				value = 0.1})
push_stop_command(dt,		{message = _("- IFF M-4 CODE SWITCH - HOLD"),											message_timeout = dt_mto})
push_stop_command(dt,		{device = devices.IFF_CONTROL_PANEL,	action = iff_commands.M4CodeSw,					value = -1.0})
push_stop_command(dt,		{message = _("- CANOPY HANDLE - UP"),													message_timeout = dt_mto})
push_stop_command(dt,		{device = devices.CPT_MECH,		action = cpt_commands.CanopyHandle,						value = 0.0})

push_stop_command(dt,		{message = _("- ARMAMENT SWITCH - OFF, SAFE OR NORMAL"),								message_timeout = dt_mto})
push_stop_command(dt,		{device = devices.MMC,					action = mmc_commands.MasterArmSw,				value = 0.0})
push_stop_command(dt,		{device = devices.SMS,					action = sms_commands.LaserSw,					value = 0.0})
-- NUCLEAR CONSENT SWITCH - OFF
-- Prior to Engine Shutdown
push_stop_command(dt,		{message = _("- EPU SWITCH - OFF"),														message_timeout = dt_mto})
push_stop_command(dt,		{device = devices.ENGINE_INTERFACE,		action = engine_commands.EpuSwCvrOff,			value = 1.0})
push_stop_command(dt,		{device = devices.ENGINE_INTERFACE,		action = engine_commands.EpuSw,					value = -1.0})
-- AVTR POWER SWITCH - UNTHRD
push_stop_command(dt,		{message = _("- C&I KNOB - BACKUP"),													message_timeout = 5.0})
push_stop_command(dt,		{device = devices.IFF_CONTROL_PANEL,	action = iff_commands.CNI_Knob,					value = 0.0})
push_stop_command(5.0,		{message = _("- INS KNOB - OFF"),														message_timeout = dt_mto})
push_stop_command(dt,		{device = devices.INS,					action = ins_commands.ModeKnob,					value = 0.0})
push_stop_command(dt,		{message = _("- AVIONICS - OFF"),														message_timeout = 10.0})
push_stop_command(dt,		{device = devices.UFC,					action = ufc_commands.SYM_Knob,					value = 0.0})
push_stop_command(dt,		{device = devices.SMS,					action = sms_commands.LeftHDPT,					value = 0.0})
push_stop_command(dt,		{device = devices.SMS,					action = sms_commands.RightHDPT,				value = 0.0})
push_stop_command(dt,		{device = devices.FCR,					action = fcr_commands.PwrSw,					value = 0.0})
push_stop_command(dt,		{device = devices.RALT,					action = ralt_commands.PwrSw,					value = -1.0})
push_stop_command(dt,		{device = devices.MMC,					action = ecs_commands.AirSourceKnob,			value = 0.0})
push_stop_command(dt,		{device = devices.SMS,					action = sms_commands.StStaSw,					value = 0.0})
push_stop_command(dt,		{device = devices.MMC,					action = mmc_commands.MFD,						value = 0.0})
push_stop_command(dt,		{device = devices.UFC,					action = ufc_commands.UFC_Sw,					value = 0.0})
push_stop_command(dt,		{device = devices.MAP,					action = map_commands.PwrSw,					value = 0.0})
push_stop_command(dt,		{device = devices.GPS,					action = gps_commands.PwrSw,					value = 0.0})
push_stop_command(dt,		{device = devices.IDM,					action = idm_commands.PwrSw,					value = 0.0})
push_stop_command(dt,		{device = devices.HMCS,					action = hmcs_commands.IntKnob,					value = 0.0})
push_stop_command(dt,		{device = devices.INTERCOM,				action = intercom_commands.COM1_ModeKnob,		value = 0.0})
push_stop_command(dt,		{device = devices.INTERCOM,				action = intercom_commands.COM2_ModeKnob,		value = 0.0})
-- Engine Shutdown
push_stop_command(8.0,		{message = _("- THROTTLE - OFF"),		check_condition = F16_AD_THROTTLE_DOWN_TO_IDLE,	message_timeout = 21.0})
push_stop_command(dt,		{										check_condition = F16_AD_THROTTLE_SET_TO_OFF,	message_timeout = dt_mto})
push_stop_command(1.0,		{										check_condition = F16_AD_THROTTLE_AT_OFF,		message_timeout = dt_mto})
push_stop_command(20.0,		{message = _("- MAIN PWR SWITCH - OFF"),												message_timeout = dt_mto})
push_stop_command(dt,		{device = devices.ELEC_INTERFACE,		action = elec_commands.MainPwrSw,				value = -1.0})
push_stop_command(dt,		{message = _("- OXYGEN REGULATOR - ON AND NORM"),										message_timeout = dt_mto})
push_stop_command(dt,		{device = devices.OXYGEN_INTERFACE,		action = oxygen_commands.SupplyLever,			value = 0.5})
push_stop_command(dt,		{device = devices.OXYGEN_INTERFACE,		action = oxygen_commands.DiluterLever,			value = 0.0})
push_stop_command(dt,		{device = devices.OXYGEN_INTERFACE,		action = oxygen_commands.EmergencyLever,		value = 0.0})
push_stop_command(dt,		{message = _("- CANOPY - OPEN"),														message_timeout = 14.0})
push_stop_command(dt,		{device = devices.CPT_MECH,				action = cpt_commands.CanopySwitchOpen,			value = 1.0})
push_stop_command(14.0,		{device = devices.CPT_MECH,				action = cpt_commands.CanopySwitchOpen,			value = 0.0})

--
push_stop_command(3.0,	{message = _("AUTOSTOP COMPLETE"),	message_timeout = std_message_timeout})
--ё