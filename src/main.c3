module mplay_c3;
import mpv @public;
import std::io;

fn int main(String[] args)
{
	Mpv ctx = mpv::mpv_create();
	defer mpv::mpv_terminate_destroy(ctx);
	// mpv::mpv_set_property(ctx, "video", FLAG, &&MpvBool.FALSE);
	mpv::mpv_set_option_string(ctx, "input-default-bindings", "yes");
	mpv::mpv_set_option_string(ctx, "input-vo-keyboard", "yes");
	MpvBool val = TRUE;
	mpv::mpv_set_option(ctx, "osc", FLAG, &val);

	mpv::mpv_initialize(ctx);

	ZString[] cmd = {"loadfile", args[1].zstr_tcopy(), null};
	mpv::mpv_command(ctx, cmd);

	while (true)
	{
		MpvEvent* event = mpv::mpv_wait_event(ctx, 10000);
		io::printfn("event: %s\n", mpv::mpv_event_name(event.event_id));
		if (event.event_id == SHUTDOWN) break;
	}

	return 0;
}
