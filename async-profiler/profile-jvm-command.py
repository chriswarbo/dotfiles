#!/usr/bin/env python3
from os import getenv
profiler = getenv("JVM_PROFILER")
assert profiler != "", "No JVM_PROFILER given"

warmup = getenv("WARMUP")
if warmup:
    warmup = float(warmup)
del(getenv)

from sys import argv, stderr, stdout
args = argv[1:]
try:
    i = args.index('--')
    profile_args = args[:i]
    command_args = args[i+1:]
    del(i)
except ValueError:
    assert False, '\n'.join([
        "No '--' argument found, aborting.",
        "",
        "Usage: profile-jvm-command P1 P2 P3 ... -- CMD ARG1 ARG2 ARG3 ...",
        "",
        "This script will invoke the given command CMD with any given ",
        "arguments (ARG1, ARG2, ARG3, ...). That command's process tree will",
        "be polled until a process with the name 'java' is found, then the",
        "'async-profiler' tool will be run against that java process's ID.",
        "",
        "Arguments before '--' (P1, P2, P3, ...) are given to the",
        "'async-profiler' tool, e.g. '-d' for duration.",
        "",
        "The following environment variables provide extra control:",
        " - WARMUP: An optional decimal number. If given, we will wait this",
        "   many seconds after invoking CMD until we start polling for its",
        "   'java' descendant. This is useful if CMD performs some preliminary",
        "   step, like compiling, which we don't want to profile.",
        " - FLAMEGRAPH: An optional file path, where 'async-profiler' will",
        "   write its output. If not given we use the name 'flamegraph-N.html'",
        "   in the current directory, where N is incremented until no existing",
        "   file has that name."
    ])
del(args, argv)

def msg(s):
    stderr.write(s + "\n")
    stderr.flush()

from psutil     import NoSuchProcess, Process
from subprocess import run, PIPE, Popen
from time       import sleep
command = Popen(command_args, stderr=PIPE, stdout=PIPE)

from atexit import register
register(command.kill)
del(register)

# Spawn threads to pass along profiled command's stdout and stderr. We do this
# because (a) having the subprocess inherit our stdout/err seems to prevent us
# writing to them (or at least buffers it unacceptably) and (b) we can't just
# poll these in a loop, since they may block or even deadlock due to buffering.
from threading import Thread
def copy(src, sink):
    for line in iter(src.readline, b""):
        sink.write(line.decode('utf-8'))
        sink.flush()

for args in [(command.stdout, stdout), (command.stderr, stderr)]:
    t        = Thread(target=copy, args=args)
    t.daemon = True
    t.start()
    del(t)

if warmup:
    msg("Giving command " + str(warmup) + " seconds to warm up")
    sleep(warmup)

# Look through the subprocess's spawned descendants for 'java'

def descendents(proc):
    try:
        children = proc.children()
    except NoSuchProcess:
        return []

    return [proc] + sum([descendents(child) for child in proc.children()], [])

def getJavaPid(parent):
    while True:
        procs = [proc for proc in descendents(parent)]
        java  = [proc.pid for proc in procs if proc.name() == 'java']
        if java == []:
            sleep(0.1)
        else:
            return java[0]

javaPid = getJavaPid(Process(command.pid))
msg('Found Java PID: ' + str(javaPid))

run([profiler] + profile_args + [str(javaPid)])
