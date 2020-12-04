import subprocess
import json
import sys
import os
import traceback

persistantLog = open("/tmp/testrun.sh", "a")


def print_error_message(error_message):
    print("#################################")
    print("!!!!Error: ", error_message)
    print("#################################")
    traceback.print_stack()
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


def get_shell_output_json(command_line):
    output = get_shell_output(command_line)
    if not output:
        print_error_message(f"no result returned from {command_line}")
    return json.loads(output)


def get_user_account(user, network_password):
    print(f"qqr pword is {network_password}")
    command_line = "yes " + network_password + " | sifnodecli keys show " + user + " -a"
    return get_shell_output(command_line)


def get_password(network_definition_file):
    if not os.environ.get("MONIKER"):
        print_error_message("MONIKER environment var not set")
    command_line = f"cat {network_definition_file} | yq r - \"(*==$MONIKER).password\""
    return get_shell_output(command_line)


# get the balance for user in the denom currency from sifnodecli
def get_balance(user, denom, network_password):
    command_line = "sifnodecli q auth account " + get_user_account(user, network_password) + ' -o json'
    json_str = get_shell_output_json(command_line)
    coins = json_str["value"]["coins"]
    print(f"balancejson is {json_str}")
    for coin in coins:
        if coin["denom"] == denom:
            return coin["amount"]
    return 0