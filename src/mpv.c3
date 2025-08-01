module mpv;

fn Mpv create() => mpv_create();

fn void free(void* data) => mpv_free(data);

fn void? command(Mpv mpv, String[] args) => @pool()
{
	ZString[] argsz = mem::temp_array(ZString, args.len + 1);
	foreach (i, arg : args)
	{
		argsz[i] = arg.zstr_tcopy();
	}
	argsz[^1] = null;

	wrap_err(mpv_command(mpv, argsz))!;
}

fn void? load_file(Mpv mpv, String filename) => command(mpv, { "loadfile", filename });

fn MpvEvent* wait_event(Mpv mpv, double timeout) => mpv_wait_event(mpv, timeout);

// Mpv methods
fn void? Mpv.init(self)
{
	wrap_err(mpv_initialize(self))!;
}

fn void Mpv.destroy(self) => mpv_terminate_destroy(self);

fn void? Mpv.set_option_string(self, String option, String value) => @pool()
{
	return self.set_option(option, STRING, &&value.zstr_tcopy());
}

fn void? Mpv.set_option_flag(self, String option, bool value) => self.set_option(option, FLAG, &&bool_to_mpv(value));

fn void? Mpv.set_option_int(self, String option, long value) => self.set_option(option, INT64, &value);

fn void? Mpv.set_option_double(self, String option, double value) => self.set_option(option, DOUBLE, &value);

fn void? Mpv.set_option_byte_array(self, String option, char[] value) => self.set_option(option, BYTE_ARRAY, &&(MpvByteArray){value.ptr, value.len});

fn void? Mpv.set_option(self, String option, MpvFormat format, void* value) => @pool()
{
	wrap_err(mpv_set_option(self, option.zstr_tcopy(), format, value))!;
}

fn void? Mpv.set_prop_flag(self, String prop, bool value) => self.set_prop(prop, FLAG, &&bool_to_mpv(value));

fn void? Mpv.set_prop_int(self, String prop, long value) => self.set_prop(prop, INT64, &value);

fn void? Mpv.set_prop_double(self, String prop, double value) => self.set_prop(prop, DOUBLE, &value);

fn void? Mpv.set_prop_byte_array(self, String prop, char[] value) => self.set_prop(prop, BYTE_ARRAY, &&(MpvByteArray){value.ptr, value.len});

fn void? Mpv.set_prop(self, String prop, MpvFormat format, void* value) => @pool()
{
	wrap_err(mpv_set_property(self, prop.zstr_tcopy(), format, value))!;
}

fn void? Mpv.observe_property(self, String prop, MpvFormat format, MpvUserdata reply_userdata) => @pool()
{
	wrap_err(mpv_observe_property(self, reply_userdata, prop.zstr_tcopy(), format))!;
}

fn CInt? Mpv.unobserve_property(self, MpvUserdata registered_reply_userdata)
{
	MpvError ret = mpv_unobserve_property(self, registered_reply_userdata);
	return ret < 0 ? @catch(wrap_err(ret))? : (CInt)ret;
}

fn bool? Mpv.get_prop_flag(self, String prop)
{
	MpvBool b;
	self.get_prop(prop, FLAG, &b)!;
	return b.as_bool;
}

fn long? Mpv.get_prop_int(self, String prop)
{
	long l;
	self.get_prop(prop, INT64, &l)!;
	return l;
}

fn double? Mpv.get_prop_double(self, String prop)
{
	double d;
	self.get_prop(prop, DOUBLE, &d)!;
	return d;
}

fn String? Mpv.get_prop_string(self, String prop)
{
	ZString z;
	self.get_prop(prop, STRING, &z)!;
	return z.str_view();
}

fn void? Mpv.get_prop(self, String prop, MpvFormat format, void* data) => @pool()
{
	wrap_err(mpv_get_property(self, prop.zstr_tcopy(), format, data))!;
}

fn void? Mpv.pause(self) => self.set_prop_flag("pause", true);
fn void? Mpv.unpause(self) => self.set_prop_flag("pause", false);

// Other methods
fn String MpvEvent.name(&self) => mpv_event_name(self.event_id).str_view();

/*	 *  MPV_EVENT_GET_PROPERTY_REPLY:     MpvEventProperty*
	 *  MPV_EVENT_PROPERTY_CHANGE:        MpvEventProperty*
	 *  MPV_EVENT_LOG_MESSAGE:            MpvEventLogMessage*
	 *  MPV_EVENT_CLIENT_MESSAGE:         MpvEventClientMessage*
	 *  MPV_EVENT_START_FILE:             MpvEventStartFile* (since v1.108)
	 *  MPV_EVENT_END_FILE:               MpvEventEndFile*
	 *  MPV_EVENT_HOOK:                   MpvEventHook*
	 *  MPV_EVENT_COMMAND_REPLY*          MpvEventCommand*
	 *  other: NULL*/
<*
 @require self.event_id == PROPERTY_CHANGE
*>
fn MpvEventProperty* MpvEvent.get_property_change(&self) => self.data;
