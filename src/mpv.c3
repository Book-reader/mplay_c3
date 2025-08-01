module mpv;
// See https://github.com/mpv-player/mpv/blob/master/include/mpv/client.h for documentation on each function
macro ZString[] to_zstr_slice(String[] strs) @private
{
	ZString[] zstrs = mem::temp_array(ZString, strs.len + 1);
	foreach (i, str : strs)
	{
		zstrs[i] = str.zstr_tcopy();
	}
	zstrs[^1] = null;
	return zstrs;
}

fn MpvVersion api_version() => (MpvVersion)mpv_client_api_version();

fn Mpv create() => mpv_create();

fn Mpv create_client(Mpv ctx, String client_name) => @pool()
{
	return mpv_create_client(ctx, client_name.zstr_tcopy());
}

fn Mpv create_weak_client(Mpv ctx, String client_name) => @pool()
{
	return mpv_create_weak_client(ctx, client_name.zstr_tcopy());
}

fn void? load_config_file(Mpv ctx, String file_name) => @pool()
{
	return wrap_err(mpv_load_config_file(ctx, file_name.zstr_tcopy()));
}

fn void free(void* data) => mpv_free(data);

fn void? command(Mpv ctx, String[] args) => @pool()
{
	return wrap_err(mpv_command(ctx, to_zstr_slice(args)));
}

fn void? load_file(Mpv ctx, String file_name) => command(ctx, {"loadfile", file_name});

fn MpvNode? command_node(Mpv ctx, MpvNode* args)
{
	MpvNode result;
	wrap_err(mpv_command_node(ctx, args, &result))!;
	return result;
}

fn MpvNode? command_ret(Mpv ctx, String[] args) => @pool()
{
	MpvNode result;
	wrap_err(mpv_command_ret(ctx, to_zstr_slice(args), &result))!;
	return result;
}

fn void? command_string(Mpv ctx, String[] args) => @pool()
{
	return wrap_err(mpv_command_string(ctx, to_zstr_slice(args)));
}

fn void? command_async(Mpv ctx, MpvUserdata reply_userdata, String[] args) => @pool()
{
	return wrap_err(mpv_command_async(ctx, reply_userdata, to_zstr_slice(args)));
}

fn void? command_node_async(Mpv ctx, MpvUserdata reply_userdata, MpvNode* args) => @pool()
{
	return wrap_err(mpv_command_node_async(ctx, reply_userdata, args));
}

fn void abort_async_command(Mpv ctx, MpvUserdata reply_userdata) => mpv_abort_async_command(ctx, reply_userdata);

fn MpvEvent* wait_event(Mpv ctx, double timeout) => mpv_wait_event(ctx, timeout);

// Mpv methods
fn void? Mpv.init(self) => wrap_err(mpv_initialize(self));

fn void Mpv.destroy(self) => mpv_destroy(self);

fn void Mpv.terminate_destroy(self) => mpv_terminate_destroy(self);

fn String Mpv.client_name(self) => mpv_client_name(self).str_view();

fn long Mpv.client_id(self) => mpv_client_id(self);

fn long Mpv.get_time_ns(self) => mpv_get_time_ns(self);

fn long Mpv.get_time_us(self) => mpv_get_time_us(self);

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
	return wrap_err(mpv_set_option(self, option.zstr_tcopy(), format, value));
}

fn void? Mpv.set_prop_string(self, String prop, String value) => @pool()
{
	return self.set_prop(prop, STRING, &&value.zstr_tcopy());
}

fn void? Mpv.set_prop_flag(self, String prop, bool value) => self.set_prop(prop, FLAG, &&bool_to_mpv(value));

fn void? Mpv.set_prop_int(self, String prop, long value) => self.set_prop(prop, INT64, &value);

fn void? Mpv.set_prop_double(self, String prop, double value) => self.set_prop(prop, DOUBLE, &value);

fn void? Mpv.set_prop_byte_array(self, String prop, char[] value) => self.set_prop(prop, BYTE_ARRAY, &&(MpvByteArray){value.ptr, value.len});

fn void? Mpv.set_prop(self, String prop, MpvFormat format, void* value) => @pool()
{
	return wrap_err(mpv_set_property(self, prop.zstr_tcopy(), format, value));
}

fn void? Mpv.observe_prop(self, String prop, MpvFormat format, MpvUserdata reply_userdata) => @pool()
{
	return wrap_err(mpv_observe_property(self, reply_userdata, prop.zstr_tcopy(), format));
}

fn CInt? Mpv.unobserve_prop(self, MpvUserdata registered_reply_userdata)
{
	MpvError ret = mpv_unobserve_property(self, registered_reply_userdata);
	return ret < 0 ? @catch(wrap_err(ret))? : (CInt)ret;
}

fn void? Mpv.del_prop(self, String name) => @pool()
{
	return wrap_err(mpv_del_property(self, name.zstr_tcopy()));
}

fn String? Mpv.get_prop_string(self, String prop)
{
	ZString z;
	self.get_prop(prop, STRING, &z)!;
	return z.str_view();
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

fn void? Mpv.get_prop(self, String prop, MpvFormat format, void* data) => @pool()
{
	return wrap_err(mpv_get_property(self, prop.zstr_tcopy(), format, data));
}

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

fn void MpvNode.free_contents(&self) => mpv_free_node_contents(self);
