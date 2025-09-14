extends Node

enum LogLevel { INFO, WARNING, ERROR, PERFORMANCE }

var performance_timers = {}

func log(level, message):
	var timestamp = Time.get_datetime_string_from_system(false, true)
	var log_level_str = LogLevel.keys()[level]
	var formatted_message = "[%s] [%s] %s" % [timestamp, log_level_str, message]
	
	match level:
		LogLevel.INFO:
			print(formatted_message)
		LogLevel.WARNING:
			print_rich("[color=yellow]%s[/color]" % formatted_message)
		LogLevel.ERROR:
			printerr(formatted_message)
		LogLevel.PERFORMANCE:
			print_rich("[color=cyan]%s[/color]" % formatted_message)

func info(message):
	self.log(LogLevel.INFO, message)

func warning(message):
	self.log(LogLevel.WARNING, message)

func error(message):
	self.log(LogLevel.ERROR, message)

func performance(message):
	self.log(LogLevel.PERFORMANCE, message)

func start_performance_check(check_name):
	performance_timers[check_name] = Time.get_ticks_usec()
	performance("Starting performance check: '%s'" % check_name)

func end_performance_check(check_name):
	if performance_timers.has(check_name):
		var start_time = performance_timers[check_name]
		var end_time = Time.get_ticks_usec()
		var duration_ms = (end_time - start_time) / 1000.0
		performance("'%s' took %.4f ms" % [check_name, duration_ms])
		performance_timers.erase(check_name)
	else:
		warning("Performance check '%s' ended without being started." % check_name)
