/**
 * dtrace.c - 
 *
 * $Author$
 *
 * Based on the patch for Ruby 1.8.6 by Joyent Inc.
 *
 * Copyright 2007 Joyent Inc.
 * Copyright 2009 Yuki Sonoda (Yugui).
 */
#include "ruby/ruby.h"

VALUE rb_mTracer;

static VALUE
dtrace_fire(int argc, VALUE *argv, VALUE klass)
{
    int args;
    VALUE name, data, ret;
    const char *probe_data;
    char *probe_name;

    args = rb_scan_args(argc, argv, "11", &name, &data);
    probe_data = args == 2 ? StringValuePtr(data) : "";
    probe_name = StringValuePtr(name);

    if (rb_block_given_p()) {
	char *start_probe = xmalloc(strlen(probe_name) + 7);
	char *end_probe   = xmalloc(strlen(probe_name) + 5);

	sprintf(start_probe, "%s-start", probe_name);
	sprintf(end_probe, "%s-end", probe_name);

	/* Build -start and -end strings for probe names */
	if (TRACE_RUBY_PROBE_ENABLED())
	    FIRE_RUBY_PROBE(start_probe, (char*)probe_data);

	ret = rb_yield(Qnil);

	if (TRACE_RUBY_PROBE_ENABLED())
	    FIRE_RUBY_PROBE(end_probe, (char*)probe_data);

	xfree(start_probe);
	xfree(end_probe);
    } else {
	if (TRACE_RUBY_PROBE_ENABLED())
	    FIRE_RUBY_PROBE(probe_name, (char*)probe_data);
	ret = Qnil;
    }
    return ret;
}

void Init_Tracer()
{
    rb_mTracer = rb_define_module("Tracer");
    rb_define_module_function(rb_mTracer, "fire", dtrace_fire, -1);
}
