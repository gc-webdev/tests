#!/bin/bash

DEBUG=0
todays_date=$(date +%F)

test_file="/opt/tests/jmeter/old_site/test/loadtest_users_cart_cms_categories.jmx"

start_users="50"
end_users="300"
step_users="50"

num_loops="5"

jmeter_bin="/opt/jmeter/bin/jmeter"
log_dir="/opt/jmeter_results/$todays_date"

# Create the destination directory if it doesn't exist
if [[ ! -e $log_dir ]]; then
    echo "creating log dir: $log_dir"
    mkdir -p $log_dir
fi


# Loop through the users, from start to end increasing by step users each time
for users in $(seq $start_users $step_users $end_users); do

    # Update loop count
    sed -i -re "s/LoopController.loops\">[[:digit:]]+/LoopController.loops\">$num_loops/" $test_file

    # Update Thread count
    sed -i -re "s/ThreadGroup.num_threads\">[[:digit:]]+/ThreadGroup.num_threads\">$users/" $test_file

    CMD="${jmeter_bin} -n -t ${test_file} -l ${log_dir}/$(basename ${test_file} .jmx)_${users}u_${num_loops}l_${todays_date}.jtl"

    if [[ $DEBUG -eq 1 ]]; then
        echo "DEBUG: would run command: $CMD"
    else
        echo "# USERS: $users"
        echo "# LOOPS: $num_loops"
        echo
        time $CMD
        sleep 10
    fi
    echo "--------------------"
done
