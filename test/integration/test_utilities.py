import subprocess
import json
import time
import sys


persistantLog = open("/tmp/testrun.sh", "a")


def print_error_message(error_message):
    print("#################################")
    print("!!!!Error: ", error_message)
    print("#################################")
    sys.exit(error_message)


def test_log_line(s):
    test_log(s + "\n")


def test_log(s):
    persistantLog.write(s)


def get_shell_output(command_line):
    print(f"cmd: {command_line}")
    # we append all shell commands and output to /tmp/testrun.sh
    test_log(command_line + "\n")
    sub = subprocess.Popen(command_line, shell=True, stdout=subprocess.PIPE)
    subprocess_return = sub.stdout.read().rstrip().decode("utf-8")
    test_log(" qqr " + subprocess_return + "\n")
    return subprocess_return
